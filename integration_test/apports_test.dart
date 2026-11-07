import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Préparer l'événement », étape P10 : « Ajouter un apport » depuis la caisse.
// « Quiche, 8 parts » ajoutée à « Gâteau salé » (stock 4) : stock 12, la caisse vend
// « Gâteau salé » comme avant (stock 11), l'apport est listé avec prénom et gymnase.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('apport nommé : stock +8, vente inchangée, apport listé, saisies refusées',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    await ouvrir(tester, 'responsable', fauxGoogle('chef_apports'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Gâteau salé',
        prixCentimes: 250,
        fiche: const FicheProduit(type: 'part'));
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await creerOuvert(depotEv,
        nom: 'Tournoi',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes']);
    await donnerStock(depotEv, evtId, 'Gâteau salé', 4);
    final gym = await gymnaseUnique(depotEv, evtId);
    final gateau =
        (await depotEv.suivreProduits(evtId).first).firstWhere((p) => p.nom == 'Gâteau salé').id;
    Future<Map<String, dynamic>?> stock() async => (await db
            .collection('associations/$assoId/evenements/$evtId/gymnases/$gym/stocks')
            .doc(gateau)
            .get(serveur))
        .data();

    // --- Un bénévole rejoint et ouvre sa caisse.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.text('Ouvrir ma caisse'));
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.text('Stock : 4'));

    // --- Critère 4 : nom vide, puis parts hors 1 à 1000 : refusés, rien n'est écrit.
    await toucher(tester, find.byKey(const Key('ouvrir_stock')));
    await attendre(tester, find.byKey(Key('ajout_apport_$gateau')));
    await toucher(tester, find.byKey(Key('ajout_apport_$gateau')));
    await tester.enterText(find.byKey(const Key('saisie_apport_parts')), '8');
    await toucher(tester, find.byKey(const Key('valider_apport')));
    expect(find.byKey(const Key('erreur_apport')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('saisie_apport_nom')), 'Quiche');
    await tester.enterText(find.byKey(const Key('saisie_apport_parts')), '0');
    await toucher(tester, find.byKey(const Key('valider_apport')));
    expect(find.byKey(const Key('erreur_apport')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('saisie_apport_parts')), '1001');
    await toucher(tester, find.byKey(const Key('valider_apport')));
    expect(find.byKey(const Key('erreur_apport')), findsOneWidget);
    expect((await stock())!['quantite'], 4);

    // --- Critère 1 : « Quiche, 8 parts » : le stock passe de 4 à 12.
    await tester.enterText(find.byKey(const Key('saisie_apport_parts')), '8');
    await toucher(tester, find.byKey(const Key('valider_apport')));
    await attendre(tester, find.text('Stock : 12'));
    await toucher(tester, find.byKey(const Key('fermer_stock')));
    await db.waitForPendingWrites();
    final apres = (await stock())!;
    expect(apres['quantite'], 12);
    expect(apres['reference'], 12);

    // --- Critère 2 : la caisse vend « Gâteau salé » comme avant.
    await toucher(tester, find.text('Gâteau salé'));
    await toucher(tester, find.byKey(const Key('encaisser_especes')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await db.waitForPendingWrites();
    expect((await stock())!['quantite'], 11);

    // --- Critère 3 : l'apport est listé avec son prénom et son gymnase (côté gestion).
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_apports')())!);
    final liste = await depotEv.suivreApports(evtId).first;
    expect(liste.length, 1);
    expect(liste.single.ligne, 'Quiche, 8 parts, Lea, $nomGymnaseParDefaut');
    final brut = await db
        .collection('associations/$assoId/evenements/$evtId/apports')
        .get(serveur);
    expect(brut.docs.length, 1);
    final d = brut.docs.single.data();
    expect(d['nom'], 'Quiche');
    expect(d['parts'], 8);
    expect(d['prenom'], 'Lea');
    expect(d['gymnaseNom'], nomGymnaseParDefaut);
    expect(d['produitNom'], 'Gâteau salé');
  });
}
