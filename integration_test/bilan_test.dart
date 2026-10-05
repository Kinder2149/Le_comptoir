import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/gymnase.dart';
import 'outils.dart';

// Le même jeu de ventes que test/bilan_test.dart (chiffres calculés à la main),
// mais posé pour de vrai sur le serveur local, avec ses dates : l'écran doit
// afficher exactement les mêmes résultats.
DateTime _t(int jour, int h, int m) => DateTime(2026, 10, jour, h, m);

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

  /// Vérifie, texte par texte, le bilan du jeu de ventes.
  /// Le défilement : la liste ne construit que ce qui est visible.
  Future<void> verifierChiffres(WidgetTester tester, Map<String, String> attendus) async {
    final defil = find.byType(Scrollable).first;
    for (final e in attendus.entries) {
      final cible = find.byKey(Key(e.key));
      for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await attendreTexte(tester, e.key, e.value);
    }
  }

  testWidgets('bilan : mêmes chiffres que le calcul à la main, puis clôture forcée',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await auth.signOut();

    // --- Association, menu de 5 produits, événement (3 modes).
    await ouvrir(tester, 'responsable', fauxGoogle('chef_bilan'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 10);
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150);
    await menus.ajouterProduit(menuId, nom: 'Salade', prixCentimes: 400);
    await menus.ajouterProduit(menuId, nom: 'Gâteau', prixCentimes: 250);
    await menus.ajouterProduit(menuId, nom: 'Soda', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: '2026-10-03',
      menuId: menuId,
      modes: ['especes', 'carte', 'cheque'],
    );
    final gym = await gymnaseUnique(depotEv, evt);
    final produits = await depotEv.suivreProduits(evt).first;
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    final croque = id('Croque-monsieur'), cafe = id('Café'), gateau = id('Gâteau');
    final soda = id('Soda'), salade = id('Salade');
    final caisses = depotEv.caisses(evt);
    final base = 'associations/$assoId/evenements/$evt';

    // --- Léa : 5 ventes (la dernière annulée par elle), stock du croque -5, clôture.
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'lea.bilan@test.fr', password: 'secret12');
    final leaUid = auth.currentUser!.uid;
    final caisseLea = idCaisse(leaUid, gym);
    await depotAsso.rejoindre(uid: leaUid, codeSaisi: code, prenom: 'Lea');
    await caisses.ouvrirCaisse(caisseLea, 'Lea');
    await db.waitForPendingWrites();
    final jetonLea = (await auth.currentUser!.getIdToken())!;
    Future<void> venteLea(List<Map<String, dynamic>> l, int total, String mode,
            DateTime quand) async =>
        expect(
            await restEcrire('POST', '$base/caisses/$caisseLea/ventes', jetonLea,
                restVente(l, total, mode, quand, gym)),
            200);
    await venteLea([restLigne(croque, 'Croque-monsieur', 300, 2)], 600, 'especes', _t(3, 14, 5));
    await venteLea([restLigne(cafe, 'Café', 150, 3)], 450, 'carte', _t(3, 14, 40));
    await venteLea([
      restLigne(croque, 'Croque-monsieur', 300, 1),
      restLigne(cafe, 'Café', 150, 1),
    ], 450, 'especes', _t(3, 15, 10));
    await venteLea([restLigne(gateau, 'Gâteau', 250, 1)], 250, 'cheque', _t(4, 10, 15));
    await venteLea([restLigne(soda, 'Soda', 150, 2)], 300, 'carte', _t(4, 14, 20));
    expect(
        await restEcrire('PATCH', '$base/gymnases/$gym/stocks/$croque?updateMask.fieldPaths=quantite',
            jetonLea, {'quantite': restEntier(5)}),
        200);
    final l5 = (await caisses.suivreVentes(caisseLea).first)
        .firstWhere((v) => v.totalCentimes == 300);
    caisses.annulerVente(caisseLea, l5,
        parUid: leaUid, parPrenom: 'Lea', stocks: {});
    await db.waitForPendingWrites();
    final recapLea = await caisses.cloturerCaisse(caisseLea);
    expect(recapLea!.nbVentes, 4);
    expect(recapLea.totalCentimes, 1750);

    // --- Zoé : 2 ventes, caisse laissée ouverte.
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'zoe.bilan@test.fr', password: 'secret12');
    final zoeUid = auth.currentUser!.uid;
    final caisseZoe = idCaisse(zoeUid, gym);
    await depotAsso.rejoindre(uid: zoeUid, codeSaisi: code, prenom: 'Zoe');
    final jetonZoe = (await auth.currentUser!.getIdToken())!;
    expect(
        await restOuvrirCaisse(base, zoeUid, gym, jetonZoe, 'Zoe', _t(3, 13, 0)),
        200);
    for (final v in [
      restVente([restLigne(cafe, 'Café', 150, 2)], 300, 'carte', _t(3, 14, 55), gym),
      restVente([restLigne(croque, 'Croque-monsieur', 300, 2)], 600, 'especes', _t(4, 10, 50), gym),
    ]) {
      expect(await restEcrire('POST', '$base/caisses/$caisseZoe/ventes', jetonZoe, v), 200);
    }

    // --- Le responsable ouvre le bilan (événement en cours : provisoire).
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_bilan')())!);
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_bilan')));
    await attendreTexte(tester, 'direct_total', 'Ventes : 6 · 26,50 €');
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await finTransition(tester);

    final chiffres = {
      'bilan_etat': 'Bilan provisoire : événement en cours',
      'bilan_total': 'Total : 26,50 € · 6 ventes',
      'bilan_annulees': 'Ventes annulées : 1',
      'bilan_caisses_ouvertes': '1 caisse pas encore clôturée : Zoe',
      'bilan_produit_$cafe': 'Café : 6 vendus · 9,00 €',
      'bilan_produit_$croque': 'Croque-monsieur : 5 vendus · 15,00 € · stock 5',
      'bilan_produit_$gateau': 'Gâteau : 1 vendu · 2,50 €',
      'bilan_produit_$salade': 'Salade : 0 vendu · 0,00 €',
      'bilan_produit_$soda': 'Soda : 0 vendu · 0,00 €',
      'plus_1': '1. Café (6)',
      'plus_2': '2. Croque-monsieur (5)',
      'moins_1': '1. Salade (0)',
      'moins_2': '2. Soda (0)',
      'bilan_mode_especes': 'Espèces : 16,50 €',
      'bilan_mode_carte': 'Carte : 7,50 €',
      'bilan_mode_cheque': 'Chèque : 2,50 €',
      'bilan_caisse_$caisseLea': 'Lea : 4 ventes · 17,50 € · Clôturée · 1 annulée',
      'bilan_caisse_$caisseZoe': 'Zoe : 2 ventes · 9,00 € · Ouverte',
      'bilan_jour_2026-10-03': '03/10/2026 : 4 ventes · 18,00 €',
      'bilan_jour_2026-10-04': '04/10/2026 : 2 ventes · 8,50 €',
      'pointe_1': '14 h–15 h : 3 ventes',
      'pointe_2': '10 h–11 h : 2 ventes',
      'pointe_3': '15 h–16 h : 1 vente',
    };
    await verifierChiffres(tester, chiffres);
    // La vente annulée est listée avec sa trace.
    await verifierChiffres(tester, {'bilan_total': chiffres['bilan_total']!});
    final trace = find.byKey(const Key('annulation_0'));
    for (var i = 0; i < 40 && trace.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      RegExp(r'^Lea · 14:20 · 3,00 € \(Carte\) — annulée par Lea à \d{2}:\d{2}$')
          .hasMatch(texte(tester, 'annulation_0')),
      isTrue,
    );
    expect(find.byKey(const Key('bilan_forcee')), findsNothing);

    // --- Clôture forcée de l'événement : le bilan devient définitif et le dit.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    await attendre(tester, find.byKey(const Key('cloture_forcee')));
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await finTransition(tester);
    await verifierChiffres(tester, {
      'bilan_etat': 'Bilan définitif : événement clôturé',
      'bilan_total': 'Total : 26,50 € · 6 ventes', // mêmes chiffres
    });
    final forcee = texte(tester, 'bilan_forcee');
    expect(forcee, startsWith('Clôture forcée par Chef le '));
    expect(forcee, endsWith('1 caisse non clôturée (Zoe). Des ventes peuvent manquer.'));
    expect(find.byKey(const Key('bilan_caisses_ouvertes')), findsNothing);
  });
}
