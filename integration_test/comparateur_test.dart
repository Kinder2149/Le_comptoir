import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_extraction.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Retours du terrain », étape F6 (décision 74) : parcours du comparateur, depuis
// la carte « Comparer deux tournois » de l'écran « Extraction et modèle ». Deux tournois
// clôturés de test ; les chiffres attendus sont calculés à la main ici.
//
// Tournoi « Tournoi un » : gymnases A (40 personnes) et B (30), 2 jours.
//   Croque-monsieur 60 vendus (300 centimes) ; Soda 40 vendus (100 centimes).
//   Total 220,00 € ; 2 ventes. Consommation : Croque 60 / 70 / 2 = 0,43 ; Soda 40 / 70 / 2 = 0,29.
// Tournoi « Tournoi deux » : gymnase A seul (25 personnes), 1 jour.
//   Croque-monsieur 10 vendus ; Soda rien vendu.
//   Total 30,00 € ; 1 vente. Consommation : Croque 10 / 25 / 1 = 0,4 ; Soda 0.
// Écarts (deux moins un) : Croque -0,03 ; Soda -0,29.
// Courses non validées dans ce parcours : coût et résultat affichés « — ».
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets(
      'comparateur : deux tournois clôturés choisis, chiffres côte à côte égaux au calcul '
      'à la main, puis export Excel relu', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'parcours_comparateur', fauxGoogle('chef_comparateur'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu comparateur');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, fiche: const FicheProduit(conso: 1));
    await menus.ajouterProduit(menuId,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 1));
    final depotEv = depotAsso.evenements(assoId);

    // Tournoi un : deux gymnases, 70 personnes, 2 jours.
    final un = await creerOuvert(depotEv,
        nom: 'Tournoi un',
        date: '2025-10-03',
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    final gymnasesUn = await depotEv.suivreGymnases(un).first;
    final gymA = gymnasesUn.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gymB = gymnasesUn.firstWhere((g) => g.nom == 'Gymnase B').id;
    await depotEv.definirPersonnes(un, gymA, 40);
    await depotEv.definirPersonnes(un, gymB, 30);
    await depotEv.definirJours(un, 2);
    final produitsUn = await depotEv.suivreProduits(un).first;
    final croqueUn = produitsUn.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    final sodaUn = produitsUn.firstWhere((p) => p.nom == 'Soda').id;
    await depotEv.definirStock(un, gymA, croqueUn, 500);
    await depotEv.definirStock(un, gymA, sodaUn, 500);
    final caissesUn = depotEv.caisses(un);
    final caisseUn = idCaisse(chefUid, gymA);
    await caissesUn.ouvrirCaisse(caisseUn, 'Chef');
    await db.waitForPendingWrites();
    caissesUn.enregistrerVente(
        caisseUn, [LigneVente(croqueUn, 'Croque-monsieur', 300, 60)], 'especes',
        stocks: const {});
    caissesUn.enregistrerVente(
        caisseUn, [LigneVente(sodaUn, 'Soda', 100, 40)], 'especes', stocks: const {});
    await db.waitForPendingWrites();
    await caissesUn.cloturerCaisse(caisseUn);
    await depotEv.cloturerEvenement(un,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    // Tournoi deux : un seul gymnase, 25 personnes, 1 jour.
    final deux = await creerOuvert(depotEv,
        nom: 'Tournoi deux',
        date: '2025-10-10',
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    final gymnasesDeux = await depotEv.suivreGymnases(deux).first;
    final gymA2 = gymnasesDeux.first.id;
    await depotEv.definirPersonnes(deux, gymA2, 25);
    await depotEv.definirJours(deux, 1);
    final produitsDeux = await depotEv.suivreProduits(deux).first;
    final croqueDeux = produitsDeux.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    await depotEv.definirStock(deux, gymA2, croqueDeux, 500);
    final caissesDeux = depotEv.caisses(deux);
    final caisseDeux = idCaisse(chefUid, gymA2);
    await caissesDeux.ouvrirCaisse(caisseDeux, 'Chef');
    await db.waitForPendingWrites();
    caissesDeux.enregistrerVente(
        caisseDeux, [LigneVente(croqueDeux, 'Croque-monsieur', 300, 10)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();
    await caissesDeux.cloturerCaisse(caisseDeux);
    await depotEv.cloturerEvenement(deux,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    // L'écran Extraction : le bouton du comparateur s'active dès deux tournois clôturés.
    Uint8List? exporte;
    await tester.pumpWidget(MaterialApp(
      home: EcranExtraction(
        depot: depotAsso,
        uid: chefUid,
        assoId: assoId,
        responsable: true,
        partager: (nom, octets, type) async => exporte = octets,
      ),
    ));
    await attendre(tester, find.byKey(const Key('comparateur')));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.widget<OutlinedButton>(find.byKey(const Key('comparateur')))
              .onPressed !=
          null) {
        break;
      }
    }
    await tester.ensureVisible(find.byKey(const Key('comparateur')));
    await tester.tap(find.byKey(const Key('comparateur')));
    await attendre(tester, find.byKey(const Key('choix_tournoi_a')));

    // Critère 1 : je choisis deux tournois clôturés.
    await tester.tap(find.byKey(const Key('choix_tournoi_a')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(Key('a_$un')).last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ValueKey('choix_tournoi_b_$un')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(Key('b_$deux')).last);
    await attendre(tester, find.byKey(const Key('synthese')));

    // Critères 2 et 4 : personnes, jours, ventes, total ; coût et résultat « — ».
    expect(texte(tester, 'valeur_0_a'), '70');
    expect(texte(tester, 'valeur_0_b'), '25');
    expect(texte(tester, 'valeur_1_a'), '2');
    expect(texte(tester, 'valeur_1_b'), '1');
    expect(texte(tester, 'valeur_2_a'), '2');
    expect(texte(tester, 'valeur_2_b'), '1');
    expect(texte(tester, 'valeur_3_a'), '220,00 €');
    expect(texte(tester, 'valeur_3_b'), '30,00 €');
    expect(texte(tester, 'valeur_4_a'), '—');
    expect(texte(tester, 'valeur_5_b'), '—');

    // Critère 3 et 4 : par produit, ventes, consommation et écart calculés à la main.
    expect(texte(tester, 'vendus_0_a'), '60');
    expect(texte(tester, 'vendus_0_b'), '10');
    expect(texte(tester, 'conso_0_a'), '0,43');
    expect(texte(tester, 'conso_0_b'), '0,4');
    expect(texte(tester, 'ecart_0'), 'Écart : -0,03');
    expect(texte(tester, 'vendus_1_a'), '40');
    expect(texte(tester, 'conso_1_a'), '0,29');
    expect(texte(tester, 'conso_1_b'), '0');
    expect(texte(tester, 'ecart_1'), 'Écart : -0,29');

    // Critère 5 : export Excel, qui se relit sans erreur, aux bons chiffres.
    await tester.ensureVisible(find.byKey(const Key('exporter_comparaison')));
    await tester.tap(find.byKey(const Key('exporter_comparaison')));
    for (var i = 0; i < 100 && exporte == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Si l'export échoue, l'écran affiche la raison : on la fait remonter dans le rapport.
    expect(find.byKey(const Key('erreur_comparaison')), findsNothing,
        reason: 'l\'export affiche une erreur');
    expect(exporte, isNotNull);
    final classeur = Excel.decodeBytes(exporte!);
    expect(classeur.tables.keys,
        containsAll([feuilleComparaisonSynthese, feuilleComparaisonProduits]));
    final synth = classeur.tables[feuilleComparaisonSynthese]!.rows;
    expect(synth[5][1]?.value.toString(), 'Tournoi un');
    expect(synth[6][1]?.value.toString(), '70');
    final prod = classeur.tables[feuilleComparaisonProduits]!.rows;
    expect(prod[6][0]?.value.toString(), 'Croque-monsieur');
  });
}
