import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_courses.dart';
import 'package:le_comptoir/ecran_classeur.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_classeur.dart';

import '../test/classeur_aides.dart';
import 'outils.dart';

// Mission « Préparer l'événement », étape P6 : importer un classeur dans la Préparation.
//
// Événement « Tournoi 2026 » en préparation (menu Croque 1,5 + Soda 0,5 + Salade 0,5),
// gymnases A (80 personnes) et B, 2 jours. Classeur : stock de départ (A : Croque 20 ;
// B : Soda 6 ; deux lignes inconnues) et historique « Tournoi 2025 » (A et B : 20 personnes
// chacun, 2 jours ; 100 + 60 croques, 80 sodas) : Croque 160 ÷ 40 ÷ 2 = 2,0 ; Soda 1,0.
// Le sélecteur de fichier du système ne se pilote pas : un sélecteur factice rend les octets.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'importer : résumé avant écriture, stocks du fichier, référence dans les sources, '
      'fichier illisible, ventes et bilans inchangés', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_import'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu 2026');
    await menus.ajouterProduit(menuId,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 1.5));
    await menus.ajouterProduit(menuId,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 0.5));
    await menus.ajouterProduit(menuId,
        nom: 'Salade', prixCentimes: 400, fiche: const FicheProduit(conso: 0.5));
    final depotEv = depotAsso.evenements(assoId);

    // ---------- L'événement en préparation.
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi 2026',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    await db.waitForPendingWrites();
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evt).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final soda = produits.firstWhere((p) => p.nom == 'Soda').id;
    final salade = produits.firstWhere((p) => p.nom == 'Salade').id;
    await depotEv.definirPersonnes(evt, gA, 80);
    await depotEv.definirJours(evt, 2);
    await db.waitForPendingWrites();

    final classeur = classeurDeTest(stock: [
      ['Gymnase A', 'Croque', 20],
      ['gymnase b', 'SODA', 6],
      ['Gymnase A', 'Pizza', 3],
      ['Gymnase Z', 'Soda', 1],
      ['Gymnase B', 'Salade', null],
    ], historique: [
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100],
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', 80],
      ['Tournoi 2025', 'Gymnase B', 20, 2, 'Croque', 60],
    ]);
    Uint8List? aChoisir = classeur;

    Future<void> afficherPreparation(String evenementId) async {
      await tester.pumpWidget(MaterialApp(
        key: UniqueKey(),
        home: EcranClasseur(
          evenement: depotEv.suivreEvenement(evenementId),
          portee:
              const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
          gymnases: depotEv.suivreGymnases(evenementId),
          produits: depotEv.suivreProduits(evenementId),
          stocks: depotEv.suivreStocksDepart(evenementId),
          assistant: assistantImport(
              depot: depotAsso,
              assoId: assoId,
              uid: chefUid,
              classeur: () => aChoisir,
              evenementId: evenementId,
              menuPropose: 'Menu 2026'),
        ),
      ));
      await attendre(tester, find.byKey(const Key('importer_classeur')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<Map<String, Map<String, StockDepart>>> stocksDepart(String e) =>
        depotEv.suivreStocksDepart(e).first;
    Future<int> nbReferences() async =>
        (await db.collection('associations/$assoId/references').get(serveur))
            .docs
            .length;
    Future<Map<String, dynamic>?> previsionDoc(String p) async => (await db
            .collection('associations/$assoId/evenements/$evt/previsions')
            .doc(p)
            .get(serveur))
        .data();
    String champQte(String cle) => tester
        .widget<TextField>(find.descendant(
            of: find.byKey(Key(cle)), matching: find.byType(TextField)))
        .controller!
        .text;

    await afficherPreparation(evt);

    // ---------- 5. Un fichier illisible : message clair, rien n'est appliqué.
    aChoisir = Uint8List.fromList(List.filled(500, 9));
    await toucher(tester, find.byKey(const Key('importer_classeur')));
    await attendre(tester, find.byKey(const Key('import_choisir_classeur')));
    await toucherCle(tester, 'import_choisir_classeur');
    await attendre(tester, find.byKey(const Key('erreur_import_assistant')));
    expect(texte(tester, 'erreur_import_assistant'), messageClasseurIllisible);
    expect(find.byKey(const Key('resume_import')), findsNothing);
    expect(await stocksDepart(evt), {
      gA: <String, StockDepart>{},
      gB: <String, StockDepart>{},
    });
    expect(await nbReferences(), 0);
    // Un vrai classeur Excel d'un autre format : même message.
    aChoisir = classeurAutreFormat();
    await toucherCle(tester, 'import_choisir_classeur');
    await attendre(tester, find.byKey(const Key('erreur_import_assistant')));
    expect(texte(tester, 'erreur_import_assistant'), messageClasseurIllisible);
    expect(await nbReferences(), 0);

    // ---------- 1. Le résumé AVANT d'appliquer : rien n'est écrit.
    aChoisir = classeur;
    await assistantJusquAuResume(tester);
    expect(find.textContaining('2 stocks seront appliqués.'), findsOneWidget);
    expect(find.textContaining('Référence créée : Tournoi 2025 (Excel) — 2 produits'),
        findsOneWidget);
    // 4. Gymnase et produit inconnus : listés « ignorés ».
    expect(find.textContaining('« Gymnase A » / « Pizza » : produit inconnu'),
        findsOneWidget);
    expect(find.textContaining('« Gymnase Z » / « Soda » : gymnase inconnu'),
        findsOneWidget);
    expect(await stocksDepart(evt), {
      gA: <String, StockDepart>{},
      gB: <String, StockDepart>{},
    });
    expect(await nbReferences(), 0);

    // ---------- Annuler : toujours rien.
    await toucher(tester, find.byKey(const Key('annuler_import')));
    await finTransition(tester);
    expect(await nbReferences(), 0);
    expect(await stocksDepart(evt), {
      gA: <String, StockDepart>{},
      gB: <String, StockDepart>{},
    });

    // ---------- 2. Appliquer : le stock de départ est celui du fichier.
    await toucherCle(tester, 'import_voir_resume');
    await attendre(tester, find.byKey(const Key('appliquer_import_assistant')));
    await finTransition(tester);
    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    expect(texte(tester, 'confirmation_import_assistant'),
        contains('stocks appliqués : 2'));
    await db.waitForPendingWrites();
    final depart = await stocksDepart(evt);
    expect(depart[gA]!.keys, {croque});
    expect(depart[gA]![croque]!.quantite, 20);
    expect(depart[gB]!.keys, {soda});
    expect(depart[gB]![soda]!.quantite, 6);
    expect(depart[gA]![croque]!.repris, isFalse);
    // « Gymnases et stocks » lit le même chiffre.
    expect(await depotEv.suivreStocks(evt, gymnaseId: gA).first, {croque: 20});
    expect(await depotEv.suivreStocks(evt, gymnaseId: gB).first, {soda: 6});
    // La référence est rangée au niveau de l'association.
    final refDoc = await db
        .doc('associations/$assoId/references/tournoi-2025-excel')
        .get(serveur);
    expect(refDoc.data()!['nom'], 'Tournoi 2025 (Excel)');
    expect((refDoc.data()!['lignes'] as List).length, 2);

    // Rejouer l'import ne crée pas de doublon (même identifiant) et ne change rien.
    await toucherCle(tester, 'import_voir_resume');
    await attendre(tester, find.byKey(const Key('appliquer_import_assistant')));
    await finTransition(tester);
    await toucherCle(tester, 'appliquer_import_assistant');
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();
    expect(await nbReferences(), 1);
    expect((await stocksDepart(evt))[gA]![croque]!.quantite, 20);

    Future<void> afficherPrevision() async {
      await tester.pumpWidget(MaterialApp(
        key: UniqueKey(),
        home: EcranPrevision(
          evenement: depotEv.suivreEvenement(evt),
          portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
          gymnases: depotEv.suivreGymnases(evt),
          produits: depotEv.suivreProduits(evt),
          previsions: depotEv.suivrePrevisions(evt),
          definirPrevision: (p, c) => depotEv.definirPrevision(evt, p, c),
          chargerPasses: () => depotEv.evenementsPasses(sauf: evt),
          appliquerPasse: (r) => depotEv.appliquerEvenementPasse(evt, r),
          revenirAuMenu: () => depotEv.revenirAuMenu(evt),
          chargerReferences: depotEv.lireReferences,
          appliquerReference: (r) => depotEv.appliquerReference(evt, r),
          definirPrevisionVerifiee: (v) => depotEv.definirPrevisionVerifiee(evt, v),
        ),
      ));
      await attendre(tester, find.byKey(const Key('bandeau_prevision')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await afficherPrevision();

    // ---------- 3. La référence est dans les sources de la prévision : 160 ÷ 40 ÷ 2 = 2,0.
    // L\'assistant a déjà réglé la prévision du tournoi sur la référence importée.
    for (final p in [croque, soda]) {
      expect(texte(tester, 'source_$p'), 'Source : Tournoi 2025 (Excel)');
    }
    expect(texte(tester, 'source_$salade'), 'Source : Menu');
    await toucher(tester, find.byKey(const Key('prevision_evenement_passe')));
    await attendre(
        tester, find.byKey(const Key('choix_reference_tournoi-2025-excel')));
    expect(find.text('Importée d\'un classeur Excel · 2 produits'), findsOneWidget);
    await toucher(
        tester, find.byKey(const Key('choix_reference_tournoi-2025-excel')));
    for (var i = 0;
        i < 100 &&
            texte(tester, 'source_$croque') != 'Source : Tournoi 2025 (Excel)';
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(texte(tester, 'source_$croque'), 'Source : Tournoi 2025 (Excel)');
    expect(texte(tester, 'source_$soda'), 'Source : Tournoi 2025 (Excel)');
    // Salade n'est pas dans la référence : elle garde le menu.
    expect(texte(tester, 'source_$salade'), 'Source : Menu');
    expect((await previsionDoc(croque))!['conso'], 2);
    expect((await previsionDoc(soda))!['conso'], 1);
    expect((await previsionDoc(croque))!['source'], 'Tournoi 2025 (Excel)');
    expect(await previsionDoc(salade), isNull);

    // Les courses calculent avec ce chiffre : 80 × 2 × 2,0 = 320, moins 20 en stock = 300.
    await tester.pumpWidget(MaterialApp(
        key: UniqueKey(),
      home: EcranCourses(depot: depotEv, evenementId: evt),
    ));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await finTransition(tester);
    await ouvrirReglagesCourses(tester);
    await toucher(tester, find.byKey(const Key('recalculer')));
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    for (var i = 0; i < 100 && champQte('qte_${gA}_$croque') != '300'; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(champQte('qte_${gA}_$croque'), '300');

    // ---------- 6. Aucune vente créée, bilans inchangés : un événement déjà ouvert,
    // avec ses ventes, reçoit le même classeur ; son tableau de bord ne bouge pas.
    final evtOuvert = await creerOuvert(depotEv,
        nom: 'Tournoi en cours',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    final gymOuvert = await gymnaseUnique(depotEv, evtOuvert);
    final produitsOuvert = await depotEv.suivreProduits(evtOuvert).first;
    final croqueO = produitsOuvert.firstWhere((p) => p.nom == 'Croque').id;
    final sodaO = produitsOuvert.firstWhere((p) => p.nom == 'Soda').id;
    final caisses = depotEv.caisses(evtOuvert);
    final caisseId = idCaisse(chefUid, gymOuvert);
    await caisses.ouvrirCaisse(caisseId, 'Chef');
    await db.waitForPendingWrites();
    caisses.enregistrerVente(
        caisseId, [LigneVente(croqueO, 'Croque', 300, 3)], 'especes',
        stocks: const {});
    caisses.enregistrerVente(
        caisseId, [LigneVente(sodaO, 'Soda', 100, 2)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();
    final avant = await caisses.lireTableauDeBord();
    final nbCaissesAvant =
        (await db.collection('associations/$assoId/evenements/$evtOuvert/caisses').get(serveur))
            .docs
            .length;
    expect(avant.nbVentes, 2);
    expect(avant.totalCentimes, 1100);

    // Événement ouvert : le stock de départ est en lecture seule, seul l'historique s'importe.
    aChoisir = classeurDeTest(stock: [
      ['Gymnase A', 'Croque', 20],
    ], historique: [
      ['Tournoi 2024', 'Gymnase A', 40, 2, 'Croque', 160],
    ]);
    await afficherPreparation(evtOuvert);
    await toucher(tester, find.byKey(const Key('importer_classeur')));
    await assistantJusquAuResume(tester);
    // Un tournoi déjà ouvert n\'est pas proposé : le stock n\'est pas utilisé, la référence si.
    expect(find.textContaining('Aucun tournoi choisi'), findsOneWidget);
    expect(find.textContaining('stocks seront appliqués'), findsNothing);
    expect(find.textContaining('Référence créée : Tournoi 2024 (Excel) — 1 produit'),
        findsOneWidget);
    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();
    // Aucun stock réécrit ; la référence est créée.
    expect((await stocksDepart(evtOuvert))[gymOuvert], isEmpty);
    expect(await nbReferences(), 2);
    expect(
        (await db.doc('associations/$assoId/references/tournoi-2024-excel').get(serveur))
            .exists,
        isTrue);

    final apres = await caisses.lireTableauDeBord();
    expect(apres.nbVentes, avant.nbVentes);
    expect(apres.nbAnnulees, avant.nbAnnulees);
    expect(apres.totalCentimes, avant.totalCentimes);
    expect(apres.vendus(croqueO), 3);
    expect(apres.vendus(sodaO), 2);
    expect(
        (await db.collection('associations/$assoId/evenements/$evtOuvert/caisses').get(serveur))
            .docs
            .length,
        nbCaissesAvant);
  });
}
