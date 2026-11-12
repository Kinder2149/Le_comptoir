import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_import.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_assistant.dart';
import 'package:le_comptoir/import_classeur.dart';
import 'package:le_comptoir/partage.dart';
import 'package:le_comptoir/previsions.dart';

import 'classeur_aides.dart';

// Mission « Prêt pour le tournoi », T2 (décision 77) : l'écran de l'assistant d'import
// unique, avec des sources factices (rien n'est écrit pour de vrai). Les classeurs de test
// sont à l'ANCIEN format (critère 8).
const _gymnases = [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B')];
const _produits = [
  ProduitEvenement('soda', 'Soda', 100, null),
  ProduitEvenement('croque', 'Croque', 300, null),
];

Evenement _ev(String statut) => Evenement(
    id: 'e',
    nom: 'Tournoi 2026',
    date: '2026-11-14',
    statut: statut,
    modes: const ['carte'],
    menuNom: 'Menu 2026');

/// Les écritures reçues et ce que les sources factices répondent.
class _Faux {
  final menusCrees = <(String, List<ProduitModele>)>[];
  final imports = <(String?, PlanImport)>[];
  final references = <(String, ReferenceImportee)>[];
  List<Menu> menus = const [];
  Object? echec;
  PorteeGestion portee =
      const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);
  String statut = 'en_preparation';

  int get ecritures => menusCrees.length + imports.length + references.length;

  SourcesImport get sources => SourcesImport(
        menus: () async => menus,
        nomsProduits: (id) async => ['Soda'],
        creerMenu: (nom, produits) async {
          if (echec != null) throw echec!;
          menusCrees.add((nom, produits));
          return 'nouveau';
        },
        tournois: Stream.value([_ev(statut)]),
        contexte: (t) async =>
            ContexteTournoi(gymnases: _gymnases, produits: _produits, portee: portee),
        appliquerImport: (id, plan) async {
          if (echec != null) throw echec!;
          imports.add((id, plan));
        },
        appliquerReference: (id, r) async => references.add((id, r)),
      );
}

final _menuClasseur = <List<Object?>>[
  ['Soda', 1, null, null, null, null, null, null],
  ['Gaufre', 2, null, null, null, null, null, null],
];
final _stockOk = <List<Object?>>[
  ['Gymnase A', 'Soda', 24],
  ['gymnase b', 'CROQUE', 12],
  ['Gymnase A', 'Café', 5],
  ['Gymnase C', 'Soda', 3],
];
final _histoOk = <List<Object?>>[
  ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100],
  ['Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', 40],
  ['Tournoi 2025', 'Gymnase B', 20, 2, 'Croque', 60],
];

final _menuCompose = <List<Object?>>[
  ['Croque', 3, 'Composé (recette)', 'Acheté par l\'association', null, null, null, null],
  ['Soda', 1, null, null, null, null, null, null],
];
final _recettesCroque = <List<Object?>>[
  ['Croque', 'Pain', 2, 'tranche', null],
  ['Croque', 'Fromage', 30, 'g', null],
];

Uint8List _fichier({
  List<List<Object?>> menu = const [],
  List<List<Object?>> stock = const [],
  List<List<Object?>> histo = const [],
  List<List<Object?>> recettes = const [],
}) =>
    classeurDeTest(menu: menu, stock: stock, historique: histo, recettes: recettes);

Future<void> _afficher(
  WidgetTester tester,
  _Faux faux, {
  Uint8List? classeur,
  String? evenementId = 'e',
  String? menuPropose = 'Menu 2026',
  PartageurOctets? partager,
}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: EcranImport(
      sources: faux.sources,
      evenementId: evenementId,
      menuPropose: menuPropose,
      choisirClasseur: () async => classeur,
      partager: partager ?? (n, o, m) async {},
    ),
  ));
  await tester.pump();
}

Future<void> _choisir(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('import_choisir_classeur')));
  await tester.pumpAndSettle();
}

Future<void> _voirResume(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('import_voir_resume')));
  await tester.tap(find.byKey(const Key('import_voir_resume')));
  await tester.pumpAndSettle();
}

Future<void> _appliquer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('appliquer_import_assistant')));
  await tester.pumpAndSettle();
}

String _texte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;

void main() {
  testWidgets('critère 1 : départ par le modèle générique (un .xlsx lisible part au partage)',
      (tester) async {
    final recus = <(String, Uint8List, String)>[];
    await _afficher(tester, _Faux(),
        partager: (n, o, m) async => recus.add((n, o, m)));
    expect(find.byKey(const Key('import_telecharger_modele')), findsOneWidget);
    expect(find.byKey(const Key('import_choisir_classeur')), findsOneWidget);
    // Avant le choix d'un classeur : ni menu, ni tournoi, ni résumé.
    expect(find.byKey(const Key('import_menu')), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('import_telecharger_modele')));
      for (var i = 0; i < 50 && recus.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(recus.single.$1, 'modele-vierge.xlsx');
    expect(recus.single.$3, typeMimeClasseur);
    expect(lireClasseur(recus.single.$2).produits, isNotEmpty);
  });

  testWidgets('critères 2 et 5 : menu de même nom repris SANS modification, résumé '
      'AVANT toute écriture, puis tout est écrit', (tester) async {
    final faux = _Faux()..menus = const [Menu('m1', 'Menu 2026')];
    await _afficher(tester, faux,
        classeur: _fichier(menu: _menuClasseur, stock: _stockOk, histo: _histoOk));
    await _choisir(tester);
    expect(find.byKey(const Key('import_classeur_lu')), findsOneWidget);
    expect(_texte(tester, 'import_menu_etat'),
        contains('existe déjà : il sera repris sans aucune modification'));
    await _voirResume(tester);
    // Le résumé est là, rien n'est écrit.
    expect(find.byKey(const Key('resume_import')), findsOneWidget);
    expect(find.textContaining('repris sans aucune modification'), findsWidgets);
    expect(find.textContaining('Référence créée : Tournoi 2025 (Excel) — 2 produits'),
        findsOneWidget);
    expect(find.textContaining('2 stocks seront appliqués.'), findsOneWidget);
    expect(find.textContaining('Prévision : réglée sur « Tournoi 2025 (Excel) ».'),
        findsOneWidget);
    // Les lignes ignorées, avec leur raison.
    expect(find.textContaining('« Gymnase A » / « Café » : produit inconnu'),
        findsOneWidget);
    expect(find.textContaining('« Gymnase C » / « Soda » : gymnase inconnu'),
        findsOneWidget);
    expect(find.textContaining('Gaufre'), findsWidgets);
    expect(faux.ecritures, 0);
    await _appliquer(tester);
    expect(faux.menusCrees, isEmpty); // menu existant : jamais modifié
    final (idTournoi, plan) = faux.imports.single;
    expect(idTournoi, 'e');
    expect(plan.stocks.map((s) => (s.gymnaseId, s.produitId, s.quantite)),
        [('gA', 'soda', 24), ('gB', 'croque', 12)]);
    expect(faux.references.single.$1, 'e');
    expect(faux.references.single.$2.nom, 'Tournoi 2025 (Excel)');
    expect(_texte(tester, 'confirmation_import_assistant'), contains('repris'));
  });

  testWidgets('critère 2 : un nom nouveau crée un nouveau menu', (tester) async {
    final faux = _Faux()..menus = const [Menu('m1', 'Menu 2026')];
    await _afficher(tester, faux,
        classeur: _fichier(menu: _menuClasseur, histo: _histoOk),
        evenementId: null,
        menuPropose: null);
    await _choisir(tester);
    expect(find.byKey(const Key('nom_menu_import')), findsOneWidget);
    expect(_texte(tester, 'import_menu_etat'), 'Un nouveau menu « Menu importé » sera créé.');
    await tester.enterText(find.byKey(const Key('nom_menu_import')), 'Menu 2027');
    await tester.pump();
    expect(_texte(tester, 'import_menu_etat'), 'Un nouveau menu « Menu 2027 » sera créé.');
    await _voirResume(tester);
    expect(find.textContaining('Menu « Menu 2027 » : sera créé (2 produits).'),
        findsOneWidget);
    expect(faux.ecritures, 0);
    await _appliquer(tester);
    expect(faux.menusCrees.single.$1, 'Menu 2027');
    expect(faux.menusCrees.single.$2.map((p) => p.nom), ['Soda', 'Gaufre']);
    // Critère 3 : la référence est écrite sans tournoi ; pas de stock, pas de prévision.
    expect(faux.imports.single.$1, isNull);
    expect(faux.imports.single.$2.references.single.nom, 'Tournoi 2025 (Excel)');
    expect(faux.references, isEmpty);
  });

  testWidgets('critère 4 : choisir « Aucun » tournoi : ni stock ni prévision', (tester) async {
    final faux = _Faux();
    await _afficher(tester, faux, classeur: _fichier(stock: _stockOk, histo: _histoOk));
    await _choisir(tester);
    await tester.ensureVisible(find.byKey(const Key('choix_tournoi')));
    await tester.tap(find.byKey(const Key('choix_tournoi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tournoi_aucun')).last);
    await tester.pumpAndSettle();
    await _voirResume(tester);
    expect(find.textContaining('Aucun tournoi choisi'), findsOneWidget);
    expect(find.textContaining('stocks seront appliqués'), findsNothing);
    await _appliquer(tester);
    expect(faux.imports.single.$1, isNull);
    expect(faux.imports.single.$2.stocks, isEmpty);
    expect(faux.references, isEmpty);
  });

  testWidgets('un tournoi déjà ouvert n\'est pas proposé : pas de stock appliqué',
      (tester) async {
    final faux = _Faux()..statut = 'en_cours';
    await _afficher(tester, faux, classeur: _fichier(stock: _stockOk, histo: _histoOk));
    await _choisir(tester);
    await _voirResume(tester);
    expect(find.textContaining('Aucun tournoi choisi'), findsOneWidget);
    await _appliquer(tester);
    expect(faux.imports.single.$2.stocks, isEmpty);
  });

  testWidgets('annuler le résumé : rien n\'est écrit', (tester) async {
    final faux = _Faux();
    await _afficher(tester, faux, classeur: _fichier(stock: _stockOk, histo: _histoOk));
    await _choisir(tester);
    await _voirResume(tester);
    await tester.tap(find.byKey(const Key('annuler_import')));
    await tester.pumpAndSettle();
    expect(faux.ecritures, 0);
    expect(find.byKey(const Key('confirmation_import_assistant')), findsNothing);
    expect(find.byKey(const Key('erreur_import_assistant')), findsNothing);
  });

  testWidgets('choix du fichier annulé : rien ne se passe', (tester) async {
    await _afficher(tester, _Faux());
    await _choisir(tester);
    expect(find.byKey(const Key('import_menu')), findsNothing);
    expect(find.byKey(const Key('erreur_import_assistant')), findsNothing);
  });

  testWidgets('octets quelconques, autre format, modèle vide : message clair, aucun menu',
      (tester) async {
    for (final f in [
      Uint8List.fromList(List.filled(300, 7)),
      classeurAutreFormat(),
      _fichier(),
    ]) {
      final faux = _Faux();
      await _afficher(tester, faux, classeur: f);
      await _choisir(tester);
      expect(_texte(tester, 'erreur_import_assistant'), messageClasseurIllisible);
      expect(find.byKey(const Key('import_menu')), findsNothing);
      expect(faux.ecritures, 0);
    }
  });

  testWidgets('critère 8 : un classeur à l\'ancien format reste importable',
      (tester) async {
    // classeurDeTest écrit l'ancien Menu (sans Famille ni Rayon) : tout s'importe.
    final faux = _Faux();
    await _afficher(tester, faux,
        classeur: _fichier(menu: _menuClasseur, stock: _stockOk, histo: _histoOk));
    await _choisir(tester);
    await _voirResume(tester);
    expect(find.byKey(const Key('resume_import')), findsOneWidget);
    expect(find.byKey(const Key('resume_erreurs')), findsNothing);
  });

  testWidgets('rien à importer : message, pas de résumé', (tester) async {
    // Un classeur avec seulement une ligne de stock vide (non suivie) et pas de menu.
    final faux = _Faux();
    await _afficher(tester, faux,
        classeur: _fichier(stock: [
          ['Gymnase A', 'Soda', null]
        ], histo: [
          ['Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', null]
        ]));
    await _choisir(tester);
    if (find.byKey(const Key('import_voir_resume')).evaluate().isNotEmpty) {
      await _voirResume(tester);
      expect(find.byKey(const Key('resume_import')), findsNothing);
    }
    expect(faux.ecritures, 0);
  });

  testWidgets('échec à l\'écriture : message clair, rejouable', (tester) async {
    final faux = _Faux()..echec = Exception('réseau');
    await _afficher(tester, faux, classeur: _fichier(stock: _stockOk, histo: _histoOk));
    await _choisir(tester);
    await _voirResume(tester);
    await _appliquer(tester);
    expect(_texte(tester, 'erreur_import_assistant'),
        startsWith('L\'import n\'a pas pu être terminé.'));
    expect(tester.widget<FilledButton>(find.byKey(const Key('import_voir_resume'))).onPressed,
        isNotNull);
  });

  testWidgets('gestionnaire limité : un gymnase hors de sa portée est ignoré, avec la raison',
      (tester) async {
    final faux = _Faux()
      ..portee = const PorteeGestion(responsable: false, gymnases: {'gB'}, nbGymnases: 2);
    await _afficher(tester, faux, classeur: _fichier(stock: [
      ['Gymnase A', 'Soda', 24],
      ['Gymnase B', 'Soda', 8],
    ]));
    await _choisir(tester);
    await _voirResume(tester);
    expect(find.textContaining('1 stock sera appliqué.'), findsOneWidget);
    expect(find.textContaining('ne fait pas partie de vos gymnases'), findsOneWidget);
    await _appliquer(tester);
    expect(faux.imports.single.$2.stocks.map((s) => s.gymnaseId), ['gB']);
  });

  testWidgets('plus de 10 lignes ignorées : la liste est repliée', (tester) async {
    await _afficher(tester, _Faux(), classeur: _fichier(stock: [
      for (var i = 0; i < 12; i++) ['Gymnase A', 'Produit $i', 1],
    ], histo: _histoOk));
    await _choisir(tester);
    await _voirResume(tester);
    expect(find.text('Lignes ignorées (12)'), findsOneWidget);
    expect(find.textContaining('Produit 3'), findsNothing);
    await tester.tap(find.text('Lignes ignorées (12)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Produit 3'), findsOneWidget);
  });

  testWidgets('critère 9 : menu de même nom, classeur Menu et Recettes remplis : aucun menu '
      'créé, aucune recette écrite, le résumé dit que les recettes ne sont pas reprises',
      (tester) async {
    final faux = _Faux()..menus = const [Menu('m1', 'Menu 2026')];
    await _afficher(tester, faux,
        classeur: _fichier(menu: _menuCompose, recettes: _recettesCroque, histo: _histoOk));
    await _choisir(tester);
    expect(_texte(tester, 'import_menu_etat'),
        contains('existe déjà : il sera repris sans aucune modification'));
    await _voirResume(tester);
    expect(find.textContaining('repris sans aucune modification'), findsWidgets);
    expect(find.textContaining('Les recettes du classeur ne sont pas reprises'), findsOneWidget);
    expect(faux.ecritures, 0);
    await _appliquer(tester);
    expect(faux.menusCrees, isEmpty); // ni menu ni recette créés
    expect(faux.imports.single.$2.stocks, isEmpty);
    expect(faux.imports.single.$2.references.single.nom, 'Tournoi 2025 (Excel)');
    expect(_texte(tester, 'confirmation_import_assistant'), contains('repris'));
  });

  testWidgets('un nom de menu vide à créer est refusé avant le résumé', (tester) async {
    final faux = _Faux();
    await _afficher(tester, faux,
        classeur: _fichier(menu: _menuClasseur, histo: _histoOk), menuPropose: null);
    await _choisir(tester);
    await tester.enterText(find.byKey(const Key('nom_menu_import')), '  ');
    await tester.pump();
    await _voirResume(tester);
    expect(_texte(tester, 'erreur_import_assistant'), 'Donnez un nom au menu à créer.');
    expect(find.byKey(const Key('resume_import')), findsNothing);
  });
}
