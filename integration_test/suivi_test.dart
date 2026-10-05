import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Le responsable regarde pendant que d'autres téléphones vendent (voir
// restEcrire dans outils.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && tester.widget<Text>(f).data == attendu) {
        return;
      }
    }
    final f = find.byKey(Key(cle));
    final actuel =
        f.evaluate().isEmpty ? '(absent)' : tester.widget<Text>(f).data;
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  testWidgets('suivi en direct : totaux, quantités, caisses, silence, annulation',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : association, menu (croque-monsieur : stock 10), événement.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_suivi'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    final depotAsso = DepotAssociations(db);
    final menuId = await depotAsso.menus(assoId).creerMenu('Menu Tournoi');
    await depotAsso.menus(assoId).ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 10);
    await depotAsso.menus(assoId).ajouterProduit(menuId,
        nom: 'Café', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
    );
    final gym = await gymnaseUnique(depotEv, evt);
    final produits = await depotEv.suivreProduits(evt).first;
    final croqueId = produits.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    final cafeId = produits.firstWhere((p) => p.nom == 'Café').id;
    final caisses = depotEv.caisses(evt);
    final cheminCaisse = 'associations/$assoId/evenements/$evt/caisses';

    // --- Léa (e-mail) : rejoint, ouvre sa caisse, fait deux ventes normalement.
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'lea.suivi@test.fr', password: 'secret12');
    final leaUid = auth.currentUser!.uid;
    final caisseLea = idCaisse(leaUid, gym);
    await depotAsso.rejoindre(uid: leaUid, codeSaisi: code, prenom: 'Lea');
    await caisses.ouvrirCaisse(caisseLea, 'Lea');
    // La caisse est enregistrée avant la première vente (sinon l'émulateur peut
    // évaluer la vente avant la caisse et la refuser).
    await db.waitForPendingWrites();
    caisses.enregistrerVente(
      caisseLea,
      [LigneVente(croqueId, 'Croque-monsieur', 300, 2)],
      'especes',
      stocks: {croqueId: 10},
    );
    caisses.enregistrerVente(
      caisseLea,
      [LigneVente(cafeId, 'Café', 150, 1)],
      'carte',
      stocks: {},
    );
    await db.waitForPendingWrites();
    final jetonLea = (await auth.currentUser!.getIdToken())!;

    // --- Zoé (e-mail) : caisse ouverte il y a 2 h, dernière vente il y a 90 min.
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'zoe.suivi@test.fr', password: 'secret12');
    final zoeUid = auth.currentUser!.uid;
    final caisseZoe = idCaisse(zoeUid, gym);
    await depotAsso.rejoindre(uid: zoeUid, codeSaisi: code, prenom: 'Zoe');
    final jetonZoe = (await auth.currentUser!.getIdToken())!;
    final maintenant = DateTime.now();
    expect(
        await restOuvrirCaisse(
            'associations/$assoId/evenements/$evt', zoeUid, gym, jetonZoe, 'Zoe',
            maintenant.subtract(const Duration(minutes: 120))),
        200);
    expect(
        await restEcrire(
            'POST',
            '$cheminCaisse/$caisseZoe/ventes',
            jetonZoe,
            restVente([restLigne(cafeId, 'Café', 150, 2)], 300, 'carte',
                maintenant.subtract(const Duration(minutes: 90)), gym)),
        200);

    // --- Le responsable ouvre le suivi de l'événement.
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_suivi')())!);
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('direct_total')));
    await attendreTexte(tester, 'direct_total', 'Ventes : 3 · 10,50 €');
    await finTransition(tester);

    // Quantités vendues et stock restant (le stock du croque-monsieur a baissé de 2).
    expect(texte(tester, 'direct_produit_$croqueId'),
        'Croque-monsieur : 2 vendus · stock 8');
    expect(texte(tester, 'direct_produit_$cafeId'), 'Café : 3 vendus');
    // Chaque caisse : état, ventes, total, dernière vente.
    expect(texte(tester, 'statut_caisse_$caisseLea'), 'Ouverte · 2 ventes · 7,50 €');
    expect(texte(tester, 'statut_caisse_$caisseZoe'), 'Ouverte · 1 vente · 3,00 €');
    expect(texte(tester, 'activite_$caisseLea'), startsWith('Dernière vente à '));
    expect(texte(tester, 'activite_$caisseZoe'), startsWith('Dernière vente à '));
    // Silence : Zoé (90 min) oui, Léa (à l'instant) non.
    expect(texte(tester, 'silence_$caisseZoe'), startsWith('Pas de vente depuis 1 h'));
    expect(find.byKey(Key('silence_$caisseLea')), findsNothing);

    // --- Pendant qu'il regarde, Léa vend encore (depuis son téléphone) : tout bouge.
    expect(
        await restEcrire(
            'POST',
            '$cheminCaisse/$caisseLea/ventes',
            jetonLea,
            restVente([restLigne(cafeId, 'Café', 150, 1)], 150, 'carte', DateTime.now(), gym)),
        200);
    await attendreTexte(tester, 'direct_total', 'Ventes : 4 · 12,00 €');
    expect(texte(tester, 'direct_produit_$cafeId'), 'Café : 4 vendus');
    expect(texte(tester, 'statut_caisse_$caisseLea'), 'Ouverte · 3 ventes · 9,00 €');

    // --- Il ouvre la caisse de Léa et annule SA vente de croque-monsieur, sous son nom.
    final ventesLea = await caisses.suivreVentes(caisseLea).first;
    final croque = ventesLea.firstWhere((v) => v.totalCentimes == 600);
    await toucher(tester, find.byKey(Key('caisse_$caisseLea')));
    await attendre(tester, find.byKey(Key('vente_${croque.id}')));
    await finTransition(tester);
    expect(find.text('Ventes de Lea'), findsOneWidget);
    expect(find.byKey(Key('corriger_${croque.id}')), findsNothing); // pas à la gestion
    await toucher(tester, find.byKey(Key('annuler_${croque.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(Key('trace_${croque.id}')));
    expect(
      RegExp(r'^Annulée par Chef à \d{2}:\d{2}$')
          .hasMatch(texte(tester, 'trace_${croque.id}')),
      isTrue,
    );
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);

    // --- Les chiffres se corrigent : total, annulée, stock remis.
    await attendreTexte(tester, 'direct_total', 'Ventes : 3 · 6,00 €');
    expect(texte(tester, 'direct_annulees'), 'Ventes annulées : 1');
    await attendreTexte(tester, 'direct_produit_$croqueId',
        'Croque-monsieur : 0 vendu · stock 10');
    await attendreTexte(tester, 'statut_caisse_$caisseLea', 'Ouverte · 2 ventes · 3,00 €');
    final cote = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('caisses')
            .doc(caisseLea)
            .collection('ventes')
            .doc(croque.id)
            .get(serveur))
        .data()!;
    expect(cote['annulee'], isTrue);
    expect(cote['annuleePar'], chefUid);
    expect(cote['annuleeParPrenom'], 'Chef');
    expect(cote['totalCentimes'], 600); // montant d'origine conservé
  });
}
