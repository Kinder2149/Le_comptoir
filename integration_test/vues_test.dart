import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission M4 : vues distincte et commune. Le même jeu de ventes que
// test/vues_gymnases_test.dart (bilans calculés à la main), posé pour de vrai sur
// le serveur local avec ses dates :
//
//   Gymnase A — Léa (clôturée)   L1 03/10 14:05 espèces 2 croque = 6,00
//                                L2 03/10 14:40 carte 3 cafés = 4,50
//                                L3 04/10 14:20 carte 2 sodas = 3,00 (ANNULÉE)
//   Gymnase B — Max (ouverte)    M1 03/10 14:55 carte 2 cafés = 3,00
//                                M2 04/10 10:50 espèces 2 croque = 6,00
//                                M3 04/10 10:15 chèque 1 gâteau = 2,50
//   Stocks : A croque 4, gâteau 6 — B croque 3, gâteau 1.
//   A = 10,50 (2 ventes) · B = 11,50 (3 ventes) · commun = 22,00 (5 ventes).
DateTime _t(int jour, int h, int m) => DateTime(2026, 10, jour, h, m);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    // L'écran peut encore se mettre en page (le contenu au-dessus du bouton bouge) : on
    // laisse faire, puis on recadre avant d'appuyer.
    await tester.pump(const Duration(milliseconds: 500));
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
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) {
        return;
      }
    }
    final f = find.byKey(Key(cle));
    final actuel =
        f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  /// La liste ne construit que ce qui est visible : on défile jusqu'à l'élément.
  Future<void> verifier(WidgetTester tester, Map<String, String> attendus) async {
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

  Future<void> choisirVue(WidgetTester tester, String cle) async {
    final defil = find.byType(Scrollable).first;
    final cible = find.byKey(Key(cle));
    for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
      await tester.drag(defil, const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await toucher(tester, cible);
  }

  testWidgets('vues distincte et commune : mêmes chiffres que le calcul à la main',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await auth.signOut();

    // --- Association, menu, événement à deux gymnases.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_vues'));
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
    await menus.ajouterProduit(menuId,
        nom: 'Gâteau', prixCentimes: 250, stock: 10);
    await menus.ajouterProduit(menuId, nom: 'Soda', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: '2026-10-03',
      menuId: menuId,
      modes: ['especes', 'carte', 'cheque'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evt).first;
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    final croque = id('Croque-monsieur'), cafe = id('Café'), gateau = id('Gâteau');
    final soda = id('Soda'), salade = id('Salade');
    // Stocks restants distincts (le menu donnait 10 partout).
    await depotEv.definirStock(evt, gA, croque, 4);
    await depotEv.definirStock(evt, gB, croque, 3);
    await depotEv.definirStock(evt, gA, gateau, 6);
    await depotEv.definirStock(evt, gB, gateau, 1);
    final caisses = depotEv.caisses(evt);
    final base = 'associations/$assoId/evenements/$evt';

    // --- Léa, gymnase A : trois ventes dont une annulée par elle, puis clôture.
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'lea.vues@test.fr', password: 'secret12');
    final leaUid = auth.currentUser!.uid;
    final caisseLea = idCaisse(leaUid, gA);
    await depotAsso.rejoindre(uid: leaUid, codeSaisi: code, prenom: 'Lea');
    await caisses.ouvrirCaisse(caisseLea, 'Lea');
    await db.waitForPendingWrites();
    final jetonLea = (await auth.currentUser!.getIdToken())!;
    for (final v in [
      restVente([restLigne(croque, 'Croque-monsieur', 300, 2)], 600, 'especes', _t(3, 14, 5), gA),
      restVente([restLigne(cafe, 'Café', 150, 3)], 450, 'carte', _t(3, 14, 40), gA),
      restVente([restLigne(soda, 'Soda', 150, 2)], 300, 'carte', _t(4, 14, 20), gA),
    ]) {
      expect(await restEcrire('POST', '$base/caisses/$caisseLea/ventes', jetonLea, v), 200);
    }
    final l3 = (await caisses.suivreVentes(caisseLea).first)
        .firstWhere((v) => v.totalCentimes == 300);
    caisses.annulerVente(caisseLea, l3,
        parUid: leaUid, parPrenom: 'Lea', stocks: {});
    await db.waitForPendingWrites();
    final recapLea = await caisses.cloturerCaisse(caisseLea);
    expect(recapLea!.nbVentes, 2);
    expect(recapLea.totalCentimes, 1050);

    // --- Max, gymnase B : trois ventes, caisse laissée ouverte.
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'max.vues@test.fr', password: 'secret12');
    final maxUid = auth.currentUser!.uid;
    final caisseMax = idCaisse(maxUid, gB);
    await depotAsso.rejoindre(uid: maxUid, codeSaisi: code, prenom: 'Max');
    final jetonMax = (await auth.currentUser!.getIdToken())!;
    expect(
        await restOuvrirCaisse(base, maxUid, gB, jetonMax, 'Max', _t(3, 13, 0)),
        200);
    for (final v in [
      restVente([restLigne(cafe, 'Café', 150, 2)], 300, 'carte', _t(3, 14, 55), gB),
      restVente([restLigne(croque, 'Croque-monsieur', 300, 2)], 600, 'especes', _t(4, 10, 50), gB),
      restVente([restLigne(gateau, 'Gâteau', 250, 1)], 250, 'cheque', _t(4, 10, 15), gB),
    ]) {
      expect(await restEcrire('POST', '$base/caisses/$caisseMax/ventes', jetonMax, v), 200);
    }

    // --- Le responsable : suivi en direct, vue commune puis chaque gymnase.
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_vues')())!);
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('vue_commune')));
    await attendreTexte(tester, 'direct_total', 'Ventes : 5 · 22,00 €');
    await attendreTexte(tester, 'direct_produit_$croque',
        'Croque-monsieur : 4 vendus · stock 7 (Gymnase A : 4 · Gymnase B : 3)');
    expect(texte(tester, 'gymnase_de_$caisseLea'), 'Gymnase A');
    expect(texte(tester, 'gymnase_de_$caisseMax'), 'Gymnase B');
    expect(find.byKey(const Key('vue_limitee')), findsNothing);

    await choisirVue(tester, 'vue_$gA');
    await attendreTexte(tester, 'direct_total', 'Ventes : 2 · 10,50 €');
    await attendreTexte(tester, 'direct_produit_$croque', 'Croque-monsieur : 2 vendus · stock 4');
    expect(texte(tester, 'direct_annulees'), 'Ventes annulées : 1');
    expect(find.byKey(Key('caisse_$caisseMax')), findsNothing);

    await choisirVue(tester, 'vue_$gB');
    await attendreTexte(tester, 'direct_total', 'Ventes : 3 · 11,50 €');
    await attendreTexte(tester, 'direct_produit_$croque', 'Croque-monsieur : 2 vendus · stock 3');
    expect(find.byKey(const Key('direct_annulees')), findsNothing);
    expect(find.byKey(Key('caisse_$caisseLea')), findsNothing);

    await choisirVue(tester, 'vue_commune');
    await attendreTexte(tester, 'direct_total', 'Ventes : 5 · 22,00 €');

    // --- Bilan : commun, A, B (chiffres écrits à la main).
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await finTransition(tester);
    await verifier(tester, {
      'bilan_etat': 'Bilan provisoire : événement en cours',
      'bilan_total': 'Total des ventes | 22,00 € | 5 ventes',
      'bilan_annulees': 'Ventes annulées : 1',
      'bilan_caisses_ouvertes': '1 caisse pas encore clôturée : Max',
      'bilan_produit_$cafe': 'Café | 5 vendus | 7,50 €',
      'bilan_produit_$croque':
          'Croque-monsieur | 4 vendus | Stock 7 | (Gymnase A : 4 · Gymnase B : 3) | 12,00 €',
      'bilan_produit_$gateau':
          'Gâteau | 1 vendu | Stock 7 | (Gymnase A : 6 · Gymnase B : 1) | 2,50 €',
      'bilan_produit_$salade': 'Salade | 0 vendu | 0,00 €',
      'bilan_mode_especes': 'Espèces | 12,00 €',
      'bilan_mode_carte': 'Carte | 7,50 €',
      'bilan_mode_cheque': 'Chèque | 2,50 €',
      'bilan_caisse_$caisseLea':
          'Lea | Gymnase A | Clôturée | 2 ventes | 1 annulée | 10,50 €',
      'bilan_caisse_$caisseMax': 'Max | Gymnase B | Ouverte | 3 ventes | 11,50 €',
      'bilan_jour_2026-10-03': '03/10/2026 | 3 ventes | 13,50 €',
      'bilan_jour_2026-10-04': '04/10/2026 | 2 ventes | 8,50 €',
      'pointe_1': '14 h–15 h | 3 ventes',
      'pointe_2': '10 h–11 h | 2 ventes',
    });

    await choisirVue(tester, 'vue_$gA');
    await verifier(tester, {
      'bilan_total': 'Total des ventes | 10,50 € | 2 ventes',
      'bilan_annulees': 'Ventes annulées : 1',
      'bilan_produit_$cafe': 'Café | 3 vendus | 4,50 €',
      'bilan_produit_$croque': 'Croque-monsieur | 2 vendus | Stock 4 | 6,00 €',
      'bilan_produit_$gateau': 'Gâteau | 0 vendu | Stock 6 | 0,00 €',
      'bilan_mode_especes': 'Espèces | 6,00 €',
      'bilan_mode_carte': 'Carte | 4,50 €',
      'bilan_mode_cheque': 'Chèque | 0,00 €',
      'bilan_caisse_$caisseLea':
          'Lea | Gymnase A | Clôturée | 2 ventes | 1 annulée | 10,50 €',
      'bilan_jour_2026-10-03': '03/10/2026 | 2 ventes | 10,50 €',
      'pointe_1': '14 h–15 h | 2 ventes',
    });
    expect(find.byKey(Key('bilan_caisse_$caisseMax')), findsNothing);
    expect(find.byKey(const Key('bilan_caisses_ouvertes')), findsNothing);

    await choisirVue(tester, 'vue_$gB');
    await verifier(tester, {
      'bilan_total': 'Total des ventes | 11,50 € | 3 ventes',
      'bilan_caisses_ouvertes': '1 caisse pas encore clôturée : Max',
      'bilan_produit_$cafe': 'Café | 2 vendus | 3,00 €',
      'bilan_produit_$croque': 'Croque-monsieur | 2 vendus | Stock 3 | 6,00 €',
      'bilan_produit_$gateau': 'Gâteau | 1 vendu | Stock 1 | 2,50 €',
      'bilan_mode_especes': 'Espèces | 6,00 €',
      'bilan_mode_carte': 'Carte | 3,00 €',
      'bilan_mode_cheque': 'Chèque | 2,50 €',
      'bilan_caisse_$caisseMax': 'Max | Gymnase B | Ouverte | 3 ventes | 11,50 €',
      'bilan_jour_2026-10-03': '03/10/2026 | 1 vente | 3,00 €',
      'bilan_jour_2026-10-04': '04/10/2026 | 2 ventes | 8,50 €',
      'pointe_1': '10 h–11 h | 2 ventes',
      'pointe_2': '14 h–15 h | 1 vente',
    });
    expect(find.byKey(const Key('bilan_annulees')), findsNothing);
    expect(find.byKey(Key('bilan_caisse_$caisseLea')), findsNothing);
  });
}
