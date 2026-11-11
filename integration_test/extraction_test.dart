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
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/ecran_extraction.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Retours du terrain », étape F5 (décision 72) : parcours de l'écran
// « Extraction et modèle ». Le téléchargement est simulé par une remise de fichier
// factice (pas de feuille de partage sur l'émulateur).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets(
      'extraction : le bouton depuis l\'association, les quatre cartes, et le classeur '
      'd\'un menu téléchargé et relu', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'parcours_extraction', fauxGoogle('chef_extraction'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depot = DepotAssociations(db);
    final menus = depot.menus(assoId);
    final menuId = await menus.creerMenu('Menu test');
    await menus.ajouterProduit(menuId,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 2));
    await menus.ajouterProduit(menuId,
        nom: 'Cola', prixCentimes: 200, fiche: const FicheProduit(conso: 1));

    // 1. Le bouton, à côté de « Menus », mène à l'écran.
    await attendre(tester, find.byKey(const Key('extraction')));
    await tester.tap(find.byKey(const Key('extraction')));
    await attendre(tester, find.byKey(const Key('carte_modele_vierge')));

    // 2. Quatre cartes ; le comparateur est présent mais pas encore branché (F6).
    expect(find.byKey(const Key('carte_modele_vierge')), findsOneWidget);
    expect(find.byKey(const Key('carte_donnees_association')), findsOneWidget);
    expect(find.byKey(const Key('carte_export_tournoi')), findsOneWidget);
    expect(find.byKey(const Key('carte_comparateur')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('comparateur'))).onPressed,
        isNull);
    await attendre(tester, find.byKey(const Key('aucun_tournoi')));

    // 3. Le classeur d'un menu : on le choisit, on télécharge (remise simulée), on le relit.
    final remis = <Uint8List>[];
    await tester.pumpWidget(MaterialApp(
      home: EcranExtraction(
        depot: depot,
        uid: chefUid,
        assoId: assoId,
        responsable: true,
        partager: (nom, octets, type) async => remis.add(octets),
      ),
    ));
    await attendre(tester, find.byKey(const Key('choix_menu')));
    await tester.tap(find.byKey(const Key('choix_menu')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(Key('menu_$menuId')).last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('telecharger_donnees_menu')));
    await tester.tap(find.byKey(const Key('telecharger_donnees_menu')));
    for (var i = 0; i < 100 && remis.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(remis, hasLength(1));
    final lu = lireClasseur(remis.single);
    expect(lu.produits.map((p) => p.nom), ['Cola', 'Croque']);
    expect(lu.produits.firstWhere((p) => p.nom == 'Croque').fiche.conso, 2);
  });

  testWidgets(
      'export d\'un tournoi clôturé : identique à l\'onglet Après (critère 5), et un '
      'gestionnaire limité ne voit que ses gymnases (critère 6)', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'parcours_export_extraction', fauxGoogle('chef_export_extr'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu export');
    await menus.ajouterProduit(menuId,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 1));
    await menus.ajouterProduit(menuId,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 1));

    final depotEv = depotAsso.evenements(assoId);
    final evt = await creerOuvert(depotEv,
        nom: 'Tournoi clôturé',
        date: '2025-10-03',
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gymA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gymB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    await depotEv.definirPersonnes(evt, gymA, 40);
    await depotEv.definirPersonnes(evt, gymB, 30);
    await depotEv.definirJours(evt, 2);
    final produits = await depotEv.suivreProduits(evt).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final soda = produits.firstWhere((p) => p.nom == 'Soda').id;
    await depotEv.definirStock(evt, gymA, croque, 500);
    await depotEv.definirStock(evt, gymB, croque, 300);

    final caisses = depotEv.caisses(evt);
    final caisseId = idCaisse(chefUid, gymA);
    await caisses.ouvrirCaisse(caisseId, 'Chef');
    await db.waitForPendingWrites();
    caisses.enregistrerVente(
        caisseId, [LigneVente(croque, 'Croque', 300, 60)], 'especes',
        stocks: const {});
    caisses.enregistrerVente(
        caisseId, [LigneVente(soda, 'Soda', 100, 40)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();
    await caisses.cloturerCaisse(caisseId);
    await depotEv.cloturerEvenement(evt,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);
    final cloture =
        (await depotEv.suivreEvenement(evt).firstWhere((e) => e?.cloture ?? false))!;

    // Critère 5 : l'onglet Après exporte ; l'écran Extraction exporte le même tournoi.
    Uint8List? apres;
    await tester.pumpWidget(MaterialApp(
      home: EcranBilan(
        evenement: cloture,
        tableau: caisses.suivreTableauDeBord(),
        produits: depotEv.suivreProduits(evt),
        gymnases: depotEv.suivreGymnases(evt),
        stocks: depotEv.suivreStocksParGymnase(evt),
        stocksReference: depotEv.suivreStocksReference(evt),
        courses: depotEv.suivreListeCourses(evt),
        partager: (n, o, m) async => apres = o,
      ),
    ));
    await attendre(tester, find.byKey(const Key('exporter_excel')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.byKey(const Key('exporter_excel')));
    await tester.tap(find.byKey(const Key('exporter_excel')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(apres, isNotNull);

    final responsable = PorteeGestion(
        responsable: true, gymnases: const {}, nbGymnases: cloture.nbGymnases);
    final extrait = await construireExportTournoi(
        depot: depotEv, evenement: cloture, portee: responsable);
    expect(_empreinte(extrait), _empreinte(apres!),
        reason: 'le classeur de l\'écran Extraction doit être celui de l\'onglet Après');

    // Critère 6 : un gestionnaire limité au gymnase B ne voit que ce gymnase.
    final limite = PorteeGestion(
        responsable: false, gymnases: {gymB}, nbGymnases: cloture.nbGymnases);
    final lu = lireClasseur(await construireExportTournoi(
        depot: depotEv, evenement: cloture, portee: limite));
    expect(lu.stocks, isNotEmpty);
    expect(lu.stocks.every((s) => s.gymnase == 'Gymnase B'), isTrue,
        reason: 'stock de départ hors du gymnase du gestionnaire');
    expect(lu.historique, isNotEmpty);
    expect(lu.historique.every((h) => h.gymnase == 'Gymnase B'), isTrue,
        reason: 'historique hors du gymnase du gestionnaire');
  });
}

/// Empreinte d'un classeur : chaque feuille et chaque cellule, sous forme de texte. Deux
/// classeurs égaux ont la même empreinte.
String _empreinte(Uint8List octets) {
  final x = Excel.decodeBytes(octets);
  final b = StringBuffer();
  for (final f in x.tables.entries) {
    b.writeln('## ${f.key}');
    for (final ligne in f.value.rows) {
      b.writeln(ligne.map((c) => c?.value?.toString() ?? '').join(' | '));
    }
  }
  return b.toString();
}
