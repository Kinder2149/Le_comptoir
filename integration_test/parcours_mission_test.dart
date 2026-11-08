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
import 'package:le_comptoir/ecran_courses.dart';
import 'package:le_comptoir/ecran_classeur.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Préparer l'événement », étape P11 : le critère de fin de Kinder, d'un bout à l'autre.
// « Je crée un événement, je télécharge le modèle Excel, je le remplis avec les chiffres de
// l'an passé et je l'importe ; dans Préparation, je retrouve mon stock de départ et une
// prévision calculée d'après l'an passé, je corrige un chiffre, je lance les courses ; à la fin
// du tournoi, j'exporte le même classeur rempli. »
//
// Chiffres du calcul à la main (menu : Croque 3,00 € conso 1,5 ; Soda 1,00 € conso 0,5 ;
// gymnase A 80 personnes, gymnase B 0 ; 2 jours) :
//  - classeur rempli : stock de départ A Croque 20, B Soda 6 ; historique « Tournoi 2025 » :
//    A (20 personnes, 2 jours) Croque 100 + Soda 80, B (20 personnes, 2 jours) Croque 60 ;
//  - prévision d'après l'an passé : Croque 160 ÷ 40 ÷ 2 = 2,0 ; Soda 80 ÷ 40 ÷ 2 = 1,0 ;
//  - chiffre corrigé : Croque 2,5 ; courses du gymnase A : 80 × 2 × 2,5 = 400 - 20 en stock = 380 ;
//  - ventes (gymnase A) : 3 croques (9,00 €) + 2 sodas (2,00 €) = 11,00 € en 2 ventes.
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

  testWidgets('parcours complet : créer, modèle, import, préparation, courses, vente, export',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_parcours'));
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
    final depotEv = depotAsso.evenements(assoId);

    // ---------- 1. Créer l'événement (en préparation), réglé dans la Préparation.
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
    await depotEv.definirPersonnes(evt, gA, 80);
    await depotEv.definirJours(evt, 2);
    await db.waitForPendingWrites();

    Uint8List? modele;
    Uint8List? aImporter;
    Future<void> afficherPreparation() async {
      await tester.pumpWidget(MaterialApp(
        home: EcranClasseur(
          evenement: depotEv.suivreEvenement(evt),
          portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
          gymnases: depotEv.suivreGymnases(evt),
          produits: depotEv.suivreProduits(evt),
          stocks: depotEv.suivreStocksDepart(evt),
          importer: (plan) => depotEv.appliquerImport(evt, plan),
          partagerModele: (n, o, m) async => modele = Uint8List.fromList(o),
          choisirClasseur: () async => aImporter,
        ),
      ));
      await attendre(tester, find.byKey(const Key('importer_classeur')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    String texteDe(String cle) => tester.widget<Text>(find.byKey(Key(cle))).data!;
    String champ(String cle) =>
        tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;
    Future<void> attendreTexte(String cle, String attendu) async {
      for (var i = 0; i < 100 && texteDe(cle) != attendu; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(texteDe(cle), attendu);
    }

    await afficherPreparation();

    // ---------- 2. Télécharger le modèle : un .xlsx, relisible, aux produits de l'événement.
    await toucher(tester, find.byKey(const Key('telecharger_modele')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(modele, isNotNull);
    expect(modele!.sublist(0, 2), [0x50, 0x4B]);
    expect(lireClasseur(modele!).erreurs, isEmpty);
    expect(lireClasseur(modele!).produits.map((p) => p.nom).toSet(), {'Croque', 'Soda'});

    // ---------- 3. Le remplir avec les chiffres de l'an passé (stock de départ et historique).
    final x = Excel.decodeBytes(modele!);
    final stock = x.tables[feuilleStock]!;
    for (var r = 2; r < stock.rows.length; r++) {
      final ligne = stock.rows[r];
      final cle = '${ligne[0]?.value}|${ligne[1]?.value}';
      final qte = switch (cle) {
        'Gymnase A|Croque' => 20,
        'Gymnase B|Soda' => 6,
        _ => null,
      };
      if (qte != null) {
        stock.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r), IntCellValue(qte));
      }
    }
    final histo = x.tables[feuilleHistorique]!;
    for (final l in [
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100],
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', 80],
      ['Tournoi 2025', 'Gymnase B', 20, 2, 'Croque', 60],
    ]) {
      histo.appendRow([
        for (final c in l) c is int ? IntCellValue(c) : TextCellValue('$c'),
      ]);
    }
    aImporter = Uint8List.fromList(x.encode()!);

    // ---------- 4. L'importer : résumé, puis « Appliquer ».
    await toucher(tester, find.byKey(const Key('importer_classeur')));
    await attendre(tester, find.byKey(const Key('appliquer_import')));
    await finTransition(tester);
    expect(find.byKey(const Key('erreur_import')), findsNothing);
    expect(texteDe('resume_stocks'), '2 stocks seront appliqués.');
    expect(texteDe('resume_reference_0'),
        'Référence créée : Tournoi 2025 (Excel) — 2 produits');
    await toucher(tester, find.byKey(const Key('appliquer_import')));
    await attendre(tester, find.byKey(const Key('confirmation_import')));
    await db.waitForPendingWrites();

    // ---------- 5. Dans la Préparation : le stock de départ est celui du fichier.
    final depart = await depotEv.suivreStocksDepart(evt).first;
    expect(depart[gA]![croque]!.quantite, 20);
    expect(depart[gB]![soda]!.quantite, 6);

    // ---------- 6. Prévision d'après l'an passé : Croque 2,0 et Soda 1,0 (160 ÷ 40 ÷ 2, 80 ÷ 40 ÷ 2).
    Future<void> afficherPrevision() async {
      await tester.pumpWidget(MaterialApp(
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
    await toucher(tester, find.byKey(const Key('prevision_evenement_passe')));
    await attendre(
        tester, find.byKey(const Key('choix_reference_tournoi-2025-excel')));
    await toucher(
        tester, find.byKey(const Key('choix_reference_tournoi-2025-excel')));
    await attendreTexte('source_$croque', 'Source : Tournoi 2025 (Excel)');
    await attendreTexte('source_$soda', 'Source : Tournoi 2025 (Excel)');
    expect(champ('champ_conso_$croque'), '2');
    expect(champ('champ_conso_$soda'), '1');

    // ---------- 7. Corriger un chiffre : Croque 2,5, « Modifié à la main ».
    await tester.tap(find.byKey(Key('champ_conso_$croque')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(Key('champ_conso_$croque')), '2,5');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 500));
    await attendreTexte('source_$croque', 'Source : Modifié à la main');
    await attendreTexte('source_$soda', 'Source : Tournoi 2025 (Excel)');
    await db.waitForPendingWrites();

    // ---------- 8. Lancer les courses : 80 × 2 × 2,5 = 400 - 20 en stock = 380.
    await tester.pumpWidget(MaterialApp(
      home: EcranCourses(depot: depotEv, evenementId: evt),
    ));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await finTransition(tester);
    await ouvrirReglagesCourses(tester);
    await toucher(tester, find.byKey(const Key('recalculer')));
    final cleQte = Key('qte_${gA}_$croque');
    await attendre(tester, find.byKey(cleQte));
    String qte() => tester
        .widget<TextField>(find.descendant(
            of: find.byKey(cleQte), matching: find.byType(TextField)))
        .controller!
        .text;
    for (var i = 0; i < 100 && qte() != '380'; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(qte(), '380');

    // ---------- 9. Ouvrir l'événement, vendre : 3 croques + 2 sodas = 11,00 €.
    await depotEv.ouvrirEvenement(evt);
    final caisses = depotEv.caisses(evt);
    final caisseId = idCaisse(chefUid, gA);
    await caisses.ouvrirCaisse(caisseId, 'Chef');
    await db.waitForPendingWrites();
    caisses.enregistrerVente(
        caisseId, [LigneVente(croque, 'Croque', 300, 3)], 'especes',
        stocks: const {});
    caisses.enregistrerVente(
        caisseId, [LigneVente(soda, 'Soda', 100, 2)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();

    // ---------- 10. Clôturer la caisse et l'événement.
    await caisses.cloturerCaisse(caisseId);
    await depotEv.cloturerEvenement(evt,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);
    final evenement =
        (await depotEv.suivreEvenement(evt).firstWhere((e) => e?.cloture ?? false))!;

    // ---------- 11. Exporter le même classeur, rempli.
    Uint8List? exporte;
    await tester.pumpWidget(MaterialApp(
      home: EcranBilan(
        evenement: evenement,
        tableau: caisses.suivreTableauDeBord(),
        produits: depotEv.suivreProduits(evt),
        gymnases: depotEv.suivreGymnases(evt),
        stocks: depotEv.suivreStocksParGymnase(evt),
        stocksReference: depotEv.suivreStocksReference(evt),
        courses: depotEv.suivreListeCourses(evt),
        partager: (n, o, m) async => exporte = o,
      ),
    ));
    await attendre(tester, find.byKey(const Key('exporter_excel')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(contenuDe(tester, find.byKey(const Key('bilan_total'))),
        'Total des ventes | 11,00 € | 2 ventes');
    await toucher(tester, find.byKey(const Key('exporter_excel')));
    expect(exporte, isNotNull);

    final f = Excel.decodeBytes(exporte!);
    expect(f.tables.keys.toList(), feuillesExport);
    List<String> lignes(String feuille) => [
          for (final l in f.tables[feuille]!.rows.skip(2))
            l
                .where((d) => d?.value != null)
                .map((d) => d!.value.toString())
                .join(' | '),
        ];
    // Stock de départ : celui importé. Historique : personnes, jours et quantités vendues.
    expect(lignes(feuilleStock),
        containsAll(['Gymnase A | Croque | 20', 'Gymnase B | Soda | 6']));
    final historique = lignes(feuilleHistorique);
    expect(historique, contains('Tournoi 2026 | Gymnase A | 80 | 2 | Croque | 3'));
    expect(historique, contains('Tournoi 2026 | Gymnase A | 80 | 2 | Soda | 2'));
    // Le fichier exporté se relit sans erreur par l'import de l'application.
    final relu = lireClasseur(exporte!);
    expect(relu.erreurs, isEmpty);
    expect(relu.produits.map((p) => p.nom).toSet(), {'Croque', 'Soda'});
    // Les ventes n'ont pas été créées par l'import ni changées par l'export.
    final tab = await caisses.lireTableauDeBord();
    expect(tab.nbVentes, 2);
    expect(tab.totalCentimes, 1100);
    expect(
        (await db.collection('associations/$assoId/references').get(serveur))
            .docs
            .length,
        1);
  });
}
