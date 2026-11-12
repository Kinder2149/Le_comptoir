import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_import.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_assistant.dart';

import 'classeur_aides.dart';

// Mission « Calcul du club », V5 (décision 91) : les feuilles « Repas » et « Groupes » du
// classeur. Modèle (vides, expliquées), export (remplies), lecture, assistant d'import
// (résumé, ignorés, bornes) et classeur du club (recette/classeur-notre-club.xlsx).

const _gymnases = [Gymnase('g1', 'Gymnase 1'), Gymnase('g2', 'Gymnase 2')];
const _produits = [
  ProduitEvenement('croque', 'Croque-monsieur', 100, null),
  ProduitEvenement('vege', 'Croque végé', 100, null),
  ProduitEvenement('coca', 'Coca', 100, null),
];
const _ctx = ContexteTournoi(
  gymnases: _gymnases,
  produits: _produits,
  portee: PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
);
const _tournoi = Evenement(
    id: 'e',
    nom: 'Tournoi 2026',
    date: '2026-11-14',
    statut: 'en_preparation',
    modes: ['carte'],
    menuNom: 'Menu 2026');

const _calcul = CalculClub(
  repas: {
    'g1': {
      1: RepasGymnaseJour(
          joueusesMidi: 49,
          joueusesSoir: 49,
          benevolesMidi: 10,
          benevolesSoir: 11),
      2: RepasGymnaseJour(
          joueusesMidi: 56,
          joueusesSoir: 56,
          benevolesMidi: 9,
          benevolesSoir: 9),
    },
    'g2': {
      1: RepasGymnaseJour(
          joueusesMidi: 63,
          joueusesSoir: 63,
          benevolesMidi: 7,
          benevolesSoir: 8),
    },
  },
  groupes: [
    GroupeConso(nom: 'Plat', pourcentages: {
      1: 0.7,
      2: 0.8
    }, produits: {
      'croque': {1: 0.4, 2: 0.35},
      'vege': {1: 0.6, 2: 0.65},
    }),
    GroupeConso(nom: 'Boissons froides', pourcentages: {
      1: 1.5,
      2: 1.5
    }, produits: {
      'coca': {1: 1.0, 2: 1.0},
    }),
  ],
);

Uint8List _modele() =>
    construireModele(produits: _produits, gymnases: _gymnases, stocks: const {});

Uint8List _export({CalculClub? calcul}) => construireExport(
      evenement: _tournoi,
      produits: _produits,
      gymnases: _gymnases,
      stocksReference: const {},
      stocksActuels: const {},
      tableau: TableauDeBord.depuis(const []),
      calculClub: calcul,
    );

/// Les valeurs des lignes de données (dès la ligne 7) d'une feuille, texte ou nombre.
List<List<Object?>> _donnees(Uint8List octets, String feuille) => [
      for (final l in Excel.decodeBytes(octets).tables[feuille]!.rows.skip(6))
        if (l.any((d) => d?.value != null))
          [
            for (final d in l)
              switch (d?.value) {
                null => null,
                IntCellValue v => v.value,
                DoubleCellValue v => v.value,
                final v => v.toString(),
              }
          ]
    ];

List<Object?> _entetes(Uint8List octets, String feuille) => [
      for (final d in Excel.decodeBytes(octets).tables[feuille]!.rows[5])
        d?.value.toString()
    ];

/// Un classeur à l'ancien format (Menu, Stock, Historique) auquel on ajoute des feuilles.
Uint8List _avecFeuilles({
  List<List<Object?>>? repas,
  List<List<Object?>>? groupes,
  List<String>? entetesRepasFeuille,
  List<String>? entetesGroupesFeuille,
}) {
  final x = Excel.decodeBytes(classeurDeTest(
    menu: [
      ['Croque-monsieur', 1, null, null, null, null, null, null],
    ],
    stock: [
      ['Gymnase 1', 'Croque-monsieur', 12],
    ],
  ));
  CellValue? v(Object? o) => switch (o) {
        null => null,
        int n => IntCellValue(n),
        double n => DoubleCellValue(n),
        _ => TextCellValue(o.toString()),
      };
  void feuille(String nom, List<String> entetes, List<List<Object?>> lignes) {
    final f = x[nom];
    f.appendRow([TextCellValue('aide')]);
    f.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final l in lignes) {
      f.appendRow([for (final c in l) v(c)]);
    }
  }

  if (repas != null) feuille(feuilleRepas, entetesRepasFeuille ?? entetesRepas, repas);
  if (groupes != null) {
    feuille(feuilleGroupes, entetesGroupesFeuille ?? entetesGroupes, groupes);
  }
  return Uint8List.fromList(x.encode()!);
}

void main() {
  group('critère 1 : le modèle a les feuilles Repas et Groupes, vides et expliquées', () {
    test('feuilles dans l\'ordre, en-têtes lus par nom, aucune ligne de données', () {
      final o = _modele();
      expect(Excel.decodeBytes(o).tables.keys.toList(), feuillesModele);
      expect(feuillesModele, [
        'Accueil',
        'Menu',
        'Recettes',
        'Stock de départ',
        'Historique',
        'Repas',
        'Groupes',
        'Courses',
      ]);
      expect(_entetes(o, 'Repas'), entetesRepas);
      expect(_entetes(o, 'Groupes'), entetesGroupes);
      expect(_donnees(o, 'Repas'), isEmpty);
      expect(_donnees(o, 'Groupes'), isEmpty);
    });

    test('l\'Accueil les explique, chaque feuille a son explication et son exemple', () {
      final x = Excel.decodeBytes(_modele());
      final accueil = [
        for (final l in x.tables['Accueil']!.rows)
          for (final d in l)
            if (d?.value != null) d!.value.toString()
      ];
      expect(accueil.any((t) => t == 'Repas'), isTrue);
      expect(accueil.any((t) => t == 'Groupes'), isTrue);
      expect(accueil.any((t) => t.contains('jour par jour') && t.contains('midi et soir')),
          isTrue);
      for (final nom in [feuilleRepas, feuilleGroupes]) {
        final aide = x.tables[nom]!.rows[4][0]!.value.toString();
        expect(aide.contains('Exemple :'), isTrue, reason: nom);
        expect(aide.indexOf('Exemple :') > 20, isTrue, reason: nom);
      }
    });

    test('mise en forme du modèle : bandeau anthracite, en-têtes violets, volets figés', () {
      final o = _modele();
      final x = Excel.decodeBytes(o);
      for (final nom in [feuilleRepas, feuilleGroupes]) {
        expect(x.tables[nom]!.rows[1][0]?.cellStyle?.backgroundColor.colorHex, 'FF2F343C');
        expect(x.tables[nom]!.rows[5][0]?.cellStyle?.backgroundColor.colorHex, 'FF6C4F86');
        expect(xmlDeFeuille(o, nom), contains('state="frozen"'));
      }
    });

    test('le modèle se relit sans erreur et sans repas ni groupes', () {
      final lu = lireClasseur(_modele());
      expect(lu.erreurs, isEmpty);
      expect(lu.repas, isEmpty);
      expect(lu.groupes, isEmpty);
    });
  });

  group('critère 2 : l\'export d\'un tournoi remplit les deux feuilles', () {
    test('neuf feuilles, Repas par jour puis gymnase, Groupes en pourcentages', () {
      final o = _export(calcul: _calcul);
      expect(Excel.decodeBytes(o).tables.keys.toList(), feuillesExport);
      expect(_donnees(o, 'Repas'), [
        [1, 'Gymnase 1', 49, 49, 10, 11, 0, 0],
        [1, 'Gymnase 2', 63, 63, 7, 8, 0, 0],
        [2, 'Gymnase 1', 56, 56, 9, 9, 0, 0],
      ]);
      expect(_donnees(o, 'Groupes'), [
        ['Plat', 1, 70, 'Croque-monsieur', 40],
        ['Plat', 1, 70, 'Croque végé', 60],
        ['Plat', 2, 80, 'Croque-monsieur', 35],
        ['Plat', 2, 80, 'Croque végé', 65],
        ['Boissons froides', 1, 150, 'Coca', 100],
        ['Boissons froides', 2, 150, 'Coca', 100],
      ]);
    });

    test('ce qui est exporté se relit à l\'identique (aller-retour)', () {
      final lu = lireClasseur(_export(calcul: _calcul));
      expect(lu.erreurs, isEmpty);
      expect(lu.repas.length, 3);
      expect(lu.repas.first.gymnase, 'Gymnase 1');
      expect(lu.repas.first.repas.total, 119);
      expect(lu.groupes.length, 6);
      expect(lu.groupes.first.pourcentage, 0.7);
      expect(lu.groupes.first.part, 0.4);
      final plan = preparerCalculClub(lu, _tournoi, _ctx);
      expect(repasVersMap(plan.repas!)['jours'], repasVersMap(_calcul.repas)['jours']);
      expect(groupesVersMap(plan.groupes!), groupesVersMap(_calcul.groupes));
    });

    test('un tournoi sans calcul du club : les deux feuilles sont là, vides', () {
      final o = _export();
      expect(_donnees(o, 'Repas'), isEmpty);
      expect(_donnees(o, 'Groupes'), isEmpty);
      expect(_entetes(o, 'Repas'), entetesRepas);
    });
  });

  group('critère 3 : l\'assistant règle les repas et les groupes du tournoi', () {
    final lu = lireClasseur(_export(calcul: _calcul));

    test('résumé : « Repas : 2 jours, 2 gymnases. » et « Groupes : 2 groupes, 3 produits. »', () {
      final p = preparerAssistant(lu,
          nomMenu: 'Menu 2026', tournoi: _tournoi, contexte: _ctx);
      expect(p.calculClub.repas!['g1']![2]!.total, 130);
      expect(p.vide, isFalse);
      expect(p.phrases,
          containsAllInOrder(['Repas : 2 jours, 2 gymnases.', 'Groupes : 2 groupes, 3 produits.']));
      expect(p.phraseConfirmation, contains('repas posés : 2 jours'));
      expect(p.phraseConfirmation, contains('groupes posés : 2'));
    });

    test('les repas et groupes seuls suffisent à importer (rien d\'autre dans le classeur)', () {
      final seul = lireClasseur(_avecFeuilles(repas: [
        [1, 'Gymnase 1', 10, 10, 0, 0, 0, 0],
      ]));
      expect(seul.contenuUtile, isTrue);
      final p = preparerAssistant(seul, nomMenu: 'M', tournoi: _tournoi, contexte: _ctx);
      expect(p.calculClub.repas, isNotNull);
      expect(p.calculClub.groupes, isNull);
      expect(p.phrases.where((x) => x.startsWith('Groupes')), isEmpty);
    });

    test('gymnase, produit ou jour introuvable : listé et ignoré, jamais créé', () {
      final lu2 = lireClasseur(_avecFeuilles(repas: [
        [1, 'Gymnase 1', 10, 10, 0, 0, 0, 0],
        [1, 'Gymnase 9', 5, 5, 0, 0, 0, 0],
        [5, 'Gymnase 1', 5, 5, 0, 0, 0, 0],
      ], groupes: [
        ['Plat', 1, 70, 'Croque-monsieur', 50],
        ['Plat', 1, 70, 'Croque nutella', 50],
        ['Dessert', 1, 100, 'Croque-monsieur', 100],
      ]));
      final p = preparerAssistant(lu2, nomMenu: 'M', tournoi: _tournoi, contexte: _ctx);
      expect(p.calculClub.repas!.keys, ['g1']);
      expect(p.calculClub.repas!['g1']!.keys, [1]);
      expect(p.calculClub.groupes!.map((g) => g.nom), ['Plat', 'Dessert']);
      expect(p.calculClub.groupes!.first.produits.keys, ['croque']);
      expect(p.calculClub.groupes!.last.produits, isEmpty);
      expect(p.ignorees, [
        'Repas : gymnase « Gymnase 9 » introuvable dans le tournoi, ses lignes sont ignorées.',
        'Repas : le jour 5 dépasse la durée du tournoi (2 jours), ses lignes sont ignorées.',
        'Groupes : produit « Croque nutella » introuvable dans le tournoi, ignoré (groupe « Plat »).',
        'Groupes : produit « Croque-monsieur » déjà rangé dans le groupe « Plat », ignoré dans « Dessert ».',
      ]);
    });

    test('des parts qui ne font pas 100 % sont reprises telles quelles', () {
      final lu2 = lireClasseur(_avecFeuilles(groupes: [
        ['Plat', 1, 70, 'Croque-monsieur', 40],
        ['Plat', 1, 70, 'Croque végé', 55],
      ]));
      final p = preparerAssistant(lu2, nomMenu: 'M', tournoi: _tournoi, contexte: _ctx);
      final g = p.calculClub.groupes!.single;
      expect(g.produits['vege']![1], 0.55);
      expect(ecartsDuGroupe(g).single.somme, closeTo(0.95, 1e-9));
      expect(p.erreurs, isEmpty);
    });

    test('sans tournoi choisi : dit, rien n\'est posé ; gestionnaire partiel : réservé', () {
      final p = preparerAssistant(lu, nomMenu: 'M');
      expect(p.calculClub.vide, isTrue);
      expect(p.calculClubSansTournoi, isTrue);
      expect(p.phrases.last, contains('repas et les groupes du classeur ne sont pas utilisés'));
      const partielle = ContexteTournoi(
        gymnases: _gymnases,
        produits: _produits,
        portee: PorteeGestion(responsable: false, gymnases: {'g1'}, nbGymnases: 2),
      );
      final q = preparerAssistant(lu, nomMenu: 'M', tournoi: _tournoi, contexte: partielle);
      expect(q.calculClub.vide, isTrue);
      expect(q.ignorees.single, contains('réservés à la personne qui gère tout'));
    });

    test('un classeur sans ces feuilles, ou avec elles vides, s\'importe comme avant', () {
      final ancien = lireClasseur(classeurDeTest(
        menu: [
          ['Croque-monsieur', 1, null, null, null, null, null, null],
        ],
        stock: [
          ['Gymnase 1', 'Croque-monsieur', 12],
        ],
      ));
      final vide = lireClasseur(_avecFeuilles(repas: const [], groupes: const []));
      for (final l in [ancien, vide]) {
        expect(l.repas, isEmpty);
        expect(l.groupes, isEmpty);
        final p = preparerAssistant(l, nomMenu: 'M', tournoi: _tournoi, contexte: _ctx);
        expect(p.calculClub.vide, isTrue);
        expect(p.calculClub.ignorees, isEmpty);
        expect(p.phrases.any((x) => x.startsWith('Repas') || x.startsWith('Groupes')), isFalse);
        expect(p.phraseConfirmation, isNot(contains('repas')));
        expect(p.erreurs, isEmpty);
      }
    });

    test('un nombre illisible ou hors borne refuse la feuille entière, avec un message clair',
        () {
      final mauvais = lireClasseur(_avecFeuilles(repas: [
        [1, 'Gymnase 1', 10, 10, 0, 0, 0, 0],
        [2, 'Gymnase 1', 'beaucoup', 10, 0, 0, 0, 0],
        [2, 'Gymnase 2', 1001, 10, 0, 0, 0, 0],
        [0, 'Gymnase 2', 1, 1, 0, 0, 0, 0],
        [1, 'Gymnase 1', 1, 1, 0, 0, 0, 0],
      ], groupes: [
        ['Plat', 1, 70, 'Croque-monsieur', 40],
        ['Plat', 1, 700, 'Croque végé', 40],
        ['Plat', 1, 70, 'Coca', 101],
        ['Plat', 1, 80, 'Croque nutella', 10],
      ]));
      expect(mauvais.repas, isEmpty);
      expect(mauvais.groupes, isEmpty);
      expect(mauvais.erreurs, [
        'Feuille « Repas », ligne 4 : « beaucoup » n\'est pas un nombre',
        'Feuille « Repas », ligne 5 : le nombre de repas doit être entre 0 et 1000',
        'Feuille « Repas », ligne 6 : le jour doit être entre 1 et 30',
        'Feuille « Repas », ligne 7 : le jour 1 et le gymnase « Gymnase 1 » sont déjà donnés plus haut',
        'Feuille « Repas » refusée : corrigez ces lignes, aucun repas n\'est repris tant que la '
            'feuille n\'est pas juste.',
        'Feuille « Groupes », ligne 4 : le pourcentage du groupe doit être entre 0 et 500 %',
        'Feuille « Groupes », ligne 5 : la part dans le groupe doit être entre 0 et 100 %',
        'Feuille « Groupes », ligne 6 : le groupe « Plat » a deux pourcentages différents pour le jour 1',
        'Feuille « Groupes » refusée : corrigez ces lignes, aucun groupe n\'est repris tant que la '
            'feuille n\'est pas juste.',
      ]);
      expect(mauvais.contenuUtile, isTrue);
      final p = preparerAssistant(mauvais, nomMenu: 'M', tournoi: _tournoi, contexte: _ctx);
      expect(p.calculClub.vide, isTrue);
      expect(p.erreurs, containsAll(mauvais.erreurs));
    });

    test('une colonne manquante est signalée, la feuille n\'est pas lue', () {
      final lu2 = lireClasseur(_avecFeuilles(
          repas: [
            [1, 'Gymnase 1', 10]
          ],
          entetesRepasFeuille: ['Jour', 'Gymnase', 'Joueuses et accompagnateurs midi']));
      expect(lu2.repas, isEmpty);
      expect(lu2.erreurs.first, 'Feuille « Repas » : colonne « Joueuses et accompagnateurs soir » introuvable.');
    });
  });

  group('critère 3 (écran) : le résumé, puis les écritures dans le tournoi', () {
    testWidgets('résumé avec les deux lignes, puis repas et groupes écrits une fois « Appliquer »',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final ecrits = <(String, Map<String, Map<int, RepasGymnaseJour>>?, List<GroupeConso>?, bool)>[];
      final classeur = _export(calcul: _calcul);
      final sources = SourcesImport(
        menus: () async => const [],
        nomsProduits: (id) async => const [],
        creerMenu: (nom, produits) async => 'nouveau',
        tournois: Stream.value(const [_tournoi]),
        contexte: (t) async => _ctx,
        appliquerImport: (id, plan) async {},
        appliquerReference: (id, r) async {},
        appliquerCalculClub: (id, {repas, groupes, annulationRangee = false}) async =>
            ecrits.add((id, repas, groupes, annulationRangee)),
      );
      await tester.pumpWidget(MaterialApp(
        home: EcranImport(
          sources: sources,
          evenementId: 'e',
          menuPropose: 'Menu 2026',
          choisirClasseur: () async => classeur,
        ),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const Key('import_choisir_classeur')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.byKey(const Key('import_classeur_lu'))).data,
          contains('3 lignes de repas, 6 lignes de groupes'));
      await tester.ensureVisible(find.byKey(const Key('import_voir_resume')));
      await tester.tap(find.byKey(const Key('import_voir_resume')));
      await tester.pumpAndSettle();
      expect(find.text('Repas : 2 jours, 2 gymnases.'), findsOneWidget);
      expect(find.text('Groupes : 2 groupes, 3 produits.'), findsOneWidget);
      expect(ecrits, isEmpty); // rien n'est écrit avant « Appliquer »
      await tester.tap(find.byKey(const Key('appliquer_import_assistant')));
      await tester.pumpAndSettle();
      expect(ecrits.length, 1);
      expect(ecrits.single.$1, 'e');
      expect(ecrits.single.$2!['g1']![1]!.total, 119);
      expect(ecrits.single.$3!.map((g) => g.nom), ['Plat', 'Boissons froides']);
      // Pas d'historique dans le classeur : aucune prévision rangée, l'écriture range l'annulation.
      expect(ecrits.single.$4, isFalse);
    });
  });

  group('critère 4 : le classeur du club porte les repas et les groupes de l\'an dernier', () {
    final octets = File('recette/classeur-notre-club.xlsx').readAsBytesSync();
    final lu = lireClasseur(octets);

    test('lecture sans erreur : 4 lignes de repas, 7 groupes, aucune ligne perdue', () {
      expect(lu.erreurs, isEmpty);
      expect(lu.produits.length, 19);
      expect(lu.repas.length, 4);
      expect({for (final r in lu.repas) '${r.jour}|${r.gymnase}'},
          {'1|Gymnase 1', '2|Gymnase 1', '1|Gymnase 2', '2|Gymnase 2'});
      final totaux = {for (final r in lu.repas) '${r.jour}|${r.gymnase}': r.repas.total};
      // Chiffres du classeur d'origine : 119, 130, 141, 121 repas.
      expect(totaux, {
        '1|Gymnase 1': 119,
        '2|Gymnase 1': 130,
        '1|Gymnase 2': 141,
        '2|Gymnase 2': 121,
      });
      expect({for (final l in lu.groupes) l.groupe}, {
        'Plat',
        'Dessert',
        'Fruit',
        'Barres de céréales',
        'Boissons froides',
        'Boissons alcoolisées',
        'Boissons chaudes',
      });
      expect(lu.groupes.length, 41);
    });

    test('bloc Dimanche pour le jour 2 (décision de Kinder) : pourcentages et parts', () {
      double pct(String g, int j) => lu.groupes.firstWhere((l) => l.groupe == g && l.jour == j).pourcentage;
      expect([for (final g in ['Plat', 'Dessert', 'Fruit', 'Barres de céréales', 'Boissons froides', 'Boissons chaudes']) pct(g, 2)],
          [0.8, 1.0, 0.6, 0.25, 1.5, 1.5]);
      expect([for (final g in ['Plat', 'Dessert', 'Fruit', 'Barres de céréales', 'Boissons froides', 'Boissons chaudes']) pct(g, 1)],
          [0.7, 1.1, 0.5, 0.2, 1.5, 1.1]);
      // La bière n'existe que le samedi dans le classeur d'origine.
      expect(lu.groupes.where((l) => l.groupe == 'Boissons alcoolisées').map((l) => l.jour), [1]);
      double part(int j, String p) =>
          lu.groupes.firstWhere((l) => l.groupe == 'Plat' && l.jour == j && l.produit == p).part;
      expect(part(1, 'Croque-monsieur'), 0.4);
      expect(part(2, 'Croque-monsieur'), 0.35);
      expect(part(2, 'Croque végé'), 0.3);
    });

    test('aucun nom de personne : seulement des gymnases, des groupes et des produits du menu', () {
      final x = Excel.decodeBytes(octets);
      final autorisesProduits = {
        for (final p in lu.produits) p.nom,
        'Pomme',
        'Banane',
        'Clémentine',
      };
      for (final l in x.tables[feuilleRepas]!.rows.skip(6)) {
        if (l.every((d) => d?.value == null)) continue;
        expect(['Gymnase 1', 'Gymnase 2'], contains(l[1]!.value.toString()));
      }
      for (final l in x.tables[feuilleGroupes]!.rows.skip(6)) {
        if (l.every((d) => d?.value == null)) continue;
        expect(autorisesProduits, contains(l[3]!.value.toString()));
      }
      final textes = [
        for (final f in [feuilleRepas, feuilleGroupes])
          for (final l in x.tables[f]!.rows.skip(6))
            for (final d in l)
              if (d?.value is TextCellValue) d!.value.toString()
      ];
      final connus = {
        'Gymnase 1',
        'Gymnase 2',
        'Plat',
        'Dessert',
        'Fruit',
        'Barres de céréales',
        'Boissons froides',
        'Boissons alcoolisées',
        'Boissons chaudes',
        ...autorisesProduits,
      };
      expect(textes.toSet().difference(connus), isEmpty);
    });

    test('importé par l\'assistant : seuls Pomme, Banane et Clémentine (absents du menu) sont ignorés',
        () {
      final ids = {for (final (i, p) in lu.produits.indexed) p.nom: 'p$i'};
      final ctx = ContexteTournoi(
        gymnases: _gymnases,
        produits: [
          for (final p in lu.produits)
            ProduitEvenement(ids[p.nom]!, p.nom, p.prixCentimes, null),
        ],
        portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
      );
      final p = preparerAssistant(lu,
          nomMenu: 'Les Discjonctés', tournoi: _tournoi, contexte: ctx);
      expect(p.calculClub.ignorees, [
        'Groupes : produit « Pomme » introuvable dans le tournoi, ignoré (groupe « Fruit »).',
        'Groupes : produit « Banane » introuvable dans le tournoi, ignoré (groupe « Fruit »).',
        'Groupes : produit « Clémentine » introuvable dans le tournoi, ignoré (groupe « Fruit »).',
      ]);
      expect(p.phrases,
          containsAllInOrder(['Repas : 2 jours, 2 gymnases.', 'Groupes : 7 groupes, 18 produits.']));
      final calcul = CalculClub(repas: p.calculClub.repas!, groupes: p.calculClub.groupes!);
      // Aucune part ne s'écarte de 100 % (les « Verif » du classeur d'origine sont toutes « Ok »).
      expect(ecartsGroupes(calcul), isEmpty);
      // Même quantité que le test V1 : croque standard, Gymnase 1 = 33,32 + 36,4 -> 70.
      expect(quantiteClubJour(calcul, 'g1', ids['Croque-monsieur']!, 1), closeTo(33.32, 1e-9));
      expect(quantiteClubJour(calcul, 'g1', ids['Croque-monsieur']!, 2), closeTo(36.4, 1e-9));
      expect(quantiteClub(calcul, 'g1', ids['Croque-monsieur']!), 70);
    });
  });
}
