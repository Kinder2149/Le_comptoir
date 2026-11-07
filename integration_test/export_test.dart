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
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';

import 'outils.dart';

// Mission « Préparer l'événement », étape P8 : l'export complet du tournoi.
//
// Événement « Tournoi 2025 » (menu Croque 3,00 € + Soda 1,00 €) : 40 personnes, 2 jours,
// 500 croques au départ. Ventes : 100 + 60 croques, 20 croques ANNULÉS, 80 sodas.
//   Total à la main : 100 × 3 + 60 × 3 + 80 × 1 = 560,00 € en 3 ventes, 1 annulée.
//   Croque : 160 ÷ 40 ÷ 2 = 2,0 ; Soda : 80 ÷ 40 ÷ 2 = 1,0.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'export : le classeur du tournoi, ses chiffres, et la même consommation '
      "que l'événement passé une fois réimporté", (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_export'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuPasse = await menus.creerMenu('Menu 2025');
    await menus.ajouterProduit(menuPasse,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 1));
    await menus.ajouterProduit(menuPasse,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 1));
    final menuNouveau = await menus.creerMenu('Menu 2026');
    await menus.ajouterProduit(menuNouveau,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 1.5));
    await menus.ajouterProduit(menuNouveau,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 0.5));

    final depotEv = depotAsso.evenements(assoId);
    final evt0 = await creerOuvert(depotEv,
        nom: 'Tournoi 2025',
        date: '2025-10-03',
        menuId: menuPasse,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    final gym0 = await gymnaseUnique(depotEv, evt0);
    await depotEv.definirPersonnes(evt0, gym0, 40);
    await depotEv.definirJours(evt0, 2);
    final produits0 = await depotEv.suivreProduits(evt0).first;
    final croque0 = produits0.firstWhere((p) => p.nom == 'Croque').id;
    final soda0 = produits0.firstWhere((p) => p.nom == 'Soda').id;
    await depotEv.definirStock(evt0, gym0, croque0, 500);
    final caisses0 = depotEv.caisses(evt0);
    final caisseId = idCaisse(chefUid, gym0);
    await caisses0.ouvrirCaisse(caisseId, 'Chef');
    await db.waitForPendingWrites();
    for (final q in [100, 20, 60]) {
      caisses0.enregistrerVente(
          caisseId, [LigneVente(croque0, 'Croque', 300, q)], 'especes',
          stocks: const {});
    }
    caisses0.enregistrerVente(
        caisseId, [LigneVente(soda0, 'Soda', 100, 80)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();
    final ventes0 = await caisses0.suivreVentes(caisseId).first;
    caisses0.annulerVente(
        caisseId, ventes0.firstWhere((v) => v.lignes.single.quantite == 20),
        parUid: chefUid, parPrenom: 'Chef', stocks: const {});
    await db.waitForPendingWrites();
    await caisses0.cloturerCaisse(caisseId);
    await depotEv.cloturerEvenement(evt0,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    // ---------- Le bilan de l'événement clôturé : « Exporter (Excel) ».
    final evenement =
        (await depotEv.suivreEvenement(evt0).firstWhere((e) => e?.cloture ?? false))!;
    String? nom, mime;
    Uint8List? octets;
    await tester.pumpWidget(MaterialApp(
      home: EcranBilan(
        evenement: evenement,
        tableau: caisses0.suivreTableauDeBord(),
        produits: depotEv.suivreProduits(evt0),
        gymnases: depotEv.suivreGymnases(evt0),
        stocks: depotEv.suivreStocksParGymnase(evt0),
        stocksReference: depotEv.suivreStocksReference(evt0),
        courses: depotEv.suivreListeCourses(evt0),
        partager: (n, o, m) async {
          nom = n;
          octets = o;
          mime = m;
        },
      ),
    ));
    await attendre(tester, find.byKey(const Key('exporter_excel')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(contenuDe(tester, find.byKey(const Key('bilan_total'))),
        'Total des ventes | 560,00 € | 3 ventes');
    expect(find.textContaining('CSV'), findsNothing);
    await toucher(tester, find.byKey(const Key('exporter_excel')));
    expect(nom, 'tournoi-tournoi-2025-2025-10-03.xlsx');
    expect(mime, typeMimeClasseur);

    // ---------- Critères 1 et 2 : cinq feuilles, chiffres du calcul à la main.
    final x = Excel.decodeBytes(octets!);
    expect(x.tables.keys.toList(), feuillesExport);
    List<String> lignes(String f) => [
          for (final l in x.tables[f]!.rows.skip(2))
            l
                .where((d) => d?.value != null)
                .map((d) => d!.value.toString())
                .join(' | '),
        ];
    expect(
        lignes('Menu').map((l) => l.split(' | ').first).toSet(), {'Croque', 'Soda'});
    expect(lignes('Stock de départ'), contains('Gymnase A | Croque | 500'));
    expect(lignes('Historique'), [
      'Tournoi 2025 | Gymnase A | 40 | 2 | Croque | 160',
      'Tournoi 2025 | Gymnase A | 40 | 2 | Soda | 80',
    ]);
    expect(lignes('Courses'), ['1 | Courses non validées']);
    final bilan = lignes('Bilan');
    expect(bilan, contains('Total des ventes | 560'));
    expect(bilan, contains('État | Définitif (événement clôturé)'));
    expect(bilan, contains('Ventes | 3'));
    expect(bilan, contains('Ventes annulées | 1'));
    expect(bilan, contains('Espèces | 560'));
    expect(bilan, contains('Croque | 160 | 480 | 500')); // ventes sans baisse de stock (stocks: {})
    expect(bilan, contains('Soda | 80 | 80'));

    // ---------- Critère 3 : réimporté, même consommation que « événement passé ».
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi 2026',
        date: dateIso(DateTime.now()),
        menuId: menuNouveau,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    await db.waitForPendingWrites();
    final produits = await depotEv.suivreProduits(evt).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final soda = produits.firstWhere((p) => p.nom == 'Soda').id;
    Future<Map<String, double>> previsions() async => {
          for (final e in (await depotEv.suivrePrevisions(evt).first).entries)
            e.key: e.value.conso,
        };

    final passes = await depotEv.evenementsPasses(sauf: evt);
    await depotEv.appliquerEvenementPasse(
        evt, passes.utilisables.firstWhere((p) => p.id == evt0));
    await db.waitForPendingWrites();
    final parPasse = await previsions();

    final lu = lireClasseur(octets!);
    expect(lu.erreurs, isEmpty);
    final calculees = calculerReferences(lu.historique);
    expect(calculees.erreurs, isEmpty);
    await depotEv.revenirAuMenu(evt);
    await depotEv.appliquerReference(evt, calculees.references.single);
    await db.waitForPendingWrites();
    final parClasseur = await previsions();

    expect(parPasse, {croque: 2.0, soda: 1.0}); // 160 ÷ 40 ÷ 2 et 80 ÷ 40 ÷ 2
    expect(parClasseur, parPasse);
  });
}
