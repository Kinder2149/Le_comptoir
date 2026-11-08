import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/ecran_classeur.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_classeur.dart';
import 'package:le_comptoir/partage.dart';

import 'classeur_aides.dart';

// L'écran « Classeur Excel » (mission « Ergonomie de la gestion », E5 : la Préparation
// n'existe plus). Télécharger le modèle et importer un classeur rempli. Les écrans
// « Personnes et durée » et « Prévision » sont testés dans personnes_prevision_test.dart.
//   Gymnases A et B ; produits finis Soda et Croque (jamais d'ingrédient dans la liste).
//   Stock au départ : A : Soda 6 (repris), Croque 10 ; B : rien.
Evenement _ev(String statut) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: statut,
    modes: const ['carte'],
    menuNom: 'M',
    nbJours: 3);

const _gymnases = [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B')];

// Import d'un classeur (P6) : plans appliqués et le fichier que le sélecteur factice rend.
final _plansImportes = <PlanImport>[];
Uint8List? _classeurChoisi;
Object? _echecImport;
const _produits = [
  ProduitEvenement('soda', 'Soda', 100, null),
  ProduitEvenement('croque', 'Croque', 300, null),
];
const _stocks = {
  'gA': {'soda': StockDepart(6, repris: true), 'croque': StockDepart(10)},
  'gB': <String, StockDepart>{},
};

PorteeGestion _tout() =>
    const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);

Future<void> _afficher(
  WidgetTester tester, {
  String statut = 'en_preparation',
  PorteeGestion? portee,
  PartageurOctets? partagerModele,
  Uint8List? classeur,
  Object? echecImport,
}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  _plansImportes.clear();
  _classeurChoisi = classeur;
  _echecImport = echecImport;
  await tester.pumpWidget(MaterialApp(
    home: EcranClasseur(
      evenement: Stream.value(_ev(statut)),
      portee: portee ?? _tout(),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      stocks: Stream.value(_stocks),
      importer: (plan) async {
        if (_echecImport != null) throw _echecImport!;
        _plansImportes.add(plan);
      },
      choisirClasseur: () async => _classeurChoisi,
      partagerModele: partagerModele ?? (n, o, m) async {},
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('télécharger le modèle : un .xlsx part à la feuille de partage, '
      'avec le menu et les stocks affichés', (tester) async {
    final recus = <(String, Uint8List, String)>[];
    await _afficher(tester,
        partagerModele: (n, o, m) async => recus.add((n, o, m)));
    expect(find.byKey(const Key('titre_classeur')), findsOneWidget);
    final bouton = find.byKey(const Key('telecharger_modele'));
    expect(bouton, findsOneWidget);
    expect(tester.getSize(bouton).height, greaterThanOrEqualTo(48));
    await tester.tap(bouton);
    await tester.pump();
    expect(recus.length, 1);
    expect(recus.single.$1, 'modele-tournoi-2026-10-03.xlsx');
    expect(recus.single.$3, typeMimeClasseur);
    final lu = lireClasseur(recus.single.$2);
    expect(lu.erreurs, isEmpty);
    expect(lu.produits.map((p) => p.nom), ['Soda', 'Croque']);
    expect(
        lu.stocks.map((s) => (s.gymnase, s.produit, s.quantite)),
        containsAll([
          ('Gymnase A', 'Soda', 6),
          ('Gymnase A', 'Croque', 10),
          ('Gymnase B', 'Soda', null),
        ]));
  });

  testWidgets('un gestionnaire partiel ne reçoit que ses gymnases dans le modèle',
      (tester) async {
    final recus = <Uint8List>[];
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gB'}, nbGymnases: 2),
        partagerModele: (n, o, m) async => recus.add(o));
    await tester.tap(find.byKey(const Key('telecharger_modele')));
    await tester.pump();
    expect({for (final s in lireClasseur(recus.single).stocks) s.gymnase},
        {'Gymnase B'});
  });

  testWidgets('échec de la feuille de partage : message, le bouton redevient actif',
      (tester) async {
    await _afficher(tester, partagerModele: (n, o, m) async => throw Exception('x'));
    await tester.tap(find.byKey(const Key('telecharger_modele')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Le partage n\'a pas pu s\'ouvrir. Réessayez.'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('telecharger_modele')))
            .onPressed,
        isNotNull);
  });

  testWidgets('le modèle se télécharge aussi quand l\'événement est ouvert',
      (tester) async {
    await _afficher(tester, statut: 'en_cours');
    expect(find.byKey(const Key('telecharger_modele')), findsOneWidget);
  });

  group('P6 : importer un classeur', () {
    // Historique : Tournoi 2025, 2 gymnases de 20 personnes (valeur répétée), 2 jours.
    Uint8List fichier({
      List<List<Object?>> stock = const [],
      List<List<Object?>> histo = const [],
    }) =>
        classeurDeTest(stock: stock, historique: histo);
    final stockOk = <List<Object?>>[
      ['Gymnase A', 'Soda', 24],
      ['gymnase b', 'CROQUE', 12],
      ['Gymnase A', 'Café', 5],
      ['Gymnase C', 'Soda', 3],
      ['Gymnase B', 'Soda', null],
    ];
    final histoOk = <List<Object?>>[
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100],
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', 40],
      ['Tournoi 2025', 'Gymnase B', 20, 2, 'Croque', 60],
    ];

    testWidgets('critère 1 : le résumé annonce les stocks et la référence AVANT d\'appliquer',
        (tester) async {
      await _afficher(tester, classeur: fichier(stock: stockOk, histo: histoOk));
      expect(find.byKey(const Key('importer_classeur')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('importer_classeur'))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '2 stocks seront appliqués.');
      expect(texte(tester, 'resume_reference_0'),
          'Référence créée : Tournoi 2025 (Excel) — 2 produits');
      // Rien n'est écrit tant que « Appliquer » n'est pas touché.
      expect(_plansImportes, isEmpty);
      expect(find.byKey(const Key('appliquer_import')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('appliquer_import'))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.length, 1);
      final plan = _plansImportes.single;
      expect(plan.stocks.map((s) => (s.gymnaseId, s.produitId, s.quantite)),
          [('gA', 'soda', 24), ('gB', 'croque', 12)]);
      expect(plan.references.single.nom, 'Tournoi 2025 (Excel)');
      expect(texte(tester, 'confirmation_import'),
          'Stocks appliqués : 2. Références enregistrées : Tournoi 2025 (Excel).');
    });

    testWidgets('critère 4 : un produit ou un gymnase inconnu est listé « ignoré », '
        'le reste s\'applique', (tester) async {
      await _afficher(tester, classeur: fichier(stock: stockOk));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '2 stocks seront appliqués.');
      expect(find.byKey(const Key('resume_ignorees')), findsOneWidget);
      expect(find.textContaining('« Gymnase A » / « Café » : produit inconnu'),
          findsOneWidget);
      expect(find.textContaining('« Gymnase C » / « Soda » : gymnase inconnu'),
          findsOneWidget);
      expect(find.byKey(const Key('resume_aucune_reference')), findsOneWidget);
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.single.stocks.length, 2);
    });

    testWidgets('événement ouvert : 0 stock appliqué (raison dite), la référence s\'importe',
        (tester) async {
      await _afficher(tester,
          statut: 'en_cours',
          classeur: fichier(stock: stockOk, histo: histoOk));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), 'Aucun stock ne sera appliqué.');
      expect(texte(tester, 'resume_reference_0'),
          'Référence créée : Tournoi 2025 (Excel) — 2 produits');
      expect(find.textContaining(messageStockFerme), findsWidgets);
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.single.stocks, isEmpty);
      expect(_plansImportes.single.references.length, 1);
      expect(texte(tester, 'confirmation_import'),
          'Stocks appliqués : 0. Références enregistrées : Tournoi 2025 (Excel).');
    });

    testWidgets('annuler le résumé : rien n\'est écrit', (tester) async {
      await _afficher(tester, classeur: fichier(stock: stockOk, histo: histoOk));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('annuler_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes, isEmpty);
      expect(find.byKey(const Key('confirmation_import')), findsNothing);
      expect(find.byKey(const Key('erreur_import')), findsNothing);
    });

    testWidgets('choix du fichier annulé : rien ne se passe', (tester) async {
      await _afficher(tester);
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resume_import')), findsNothing);
      expect(find.byKey(const Key('erreur_import')), findsNothing);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('critère 5 : octets quelconques, message clair, aucun résumé',
        (tester) async {
      await _afficher(tester, classeur: Uint8List.fromList(List.filled(300, 7)));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'), messageClasseurIllisible);
      expect(find.byKey(const Key('resume_import')), findsNothing);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('critère 5 : un classeur d\'un autre format (sans feuille Stock ni '
        'Historique) est refusé de la même façon', (tester) async {
      await _afficher(tester, classeur: classeurAutreFormat());
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'), messageClasseurIllisible);
      expect(find.byKey(const Key('resume_import')), findsNothing);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('un modèle vide (aucune donnée) est refusé aussi', (tester) async {
      await _afficher(tester, classeur: fichier());
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'), messageClasseurIllisible);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('échec à l\'écriture : message clair, le bouton redevient actif',
        (tester) async {
      await _afficher(tester,
          classeur: fichier(stock: stockOk), echecImport: Exception('réseau'));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'),
          startsWith('L\'import n\'a pas pu être terminé.'));
      expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('importer_classeur')))
              .onPressed,
          isNotNull);
    });

    testWidgets('événement clôturé : pas de bouton d\'import', (tester) async {
      await _afficher(tester, statut: 'cloture');
      expect(find.byKey(const Key('importer_classeur')), findsNothing);
      expect(find.byKey(const Key('telecharger_modele')), findsOneWidget);
    });

    testWidgets('gestionnaire partiel : un gymnase hors de sa portée est ignoré, '
        'avec la raison', (tester) async {
      await _afficher(tester,
          portee: const PorteeGestion(
              responsable: false, gymnases: {'gB'}, nbGymnases: 2),
          classeur: fichier(stock: [
            ['Gymnase A', 'Soda', 24],
            ['Gymnase B', 'Soda', 8],
          ]));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '1 stock sera appliqué.');
      expect(find.textContaining('ne fait pas partie de vos gymnases'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.single.stocks.map((s) => s.gymnaseId), ['gB']);
    });

    testWidgets('plus de 10 lignes ignorées : la liste est repliée', (tester) async {
      await _afficher(tester, classeur: fichier(stock: [
        for (var i = 0; i < 12; i++) ['Gymnase A', 'Produit $i', 1],
      ]));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Lignes ignorées (12)'), findsOneWidget);
      expect(find.textContaining('Produit 3'), findsNothing);
      await tester.tap(find.text('Lignes ignorées (12)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Produit 3'), findsOneWidget);
    });

    testWidgets('les erreurs de lecture sont dites (ligne invalide), le reste s\'applique',
        (tester) async {
      await _afficher(tester, classeur: fichier(stock: [
        ['Gymnase A', 'Soda', 24],
        ['Gymnase A', 'Croque', 'beaucoup'],
      ]));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '1 stock sera appliqué.');
      expect(find.byKey(const Key('resume_erreurs')), findsOneWidget);
      expect(find.textContaining('n\'est pas un nombre'), findsOneWidget);
    });
  });
}

String texte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;
