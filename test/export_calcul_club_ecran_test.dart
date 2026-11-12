import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

// V5 (complément) : l'export réel (bouton de l'écran Bilan) remplit les feuilles Repas et Groupes
// avec le calcul du club de l'événement ; sans détail, l'export est celui d'avant.

const _gymnases = [Gymnase('g1', 'Gymnase 1')];
const _produits = [ProduitEvenement('croque', 'Croque-monsieur', 100, null)];
const _tournoi = Evenement(
    id: 'e',
    nom: 'Tournoi 2026',
    date: '2026-11-14',
    statut: 'cloture',
    modes: ['carte'],
    menuNom: 'Menu 2026');
const _calcul = CalculClub(
  repas: {
    'g1': {
      1: RepasGymnaseJour(
          joueusesMidi: 49, joueusesSoir: 49, benevolesMidi: 10, benevolesSoir: 11),
    },
  },
  groupes: [
    GroupeConso(nom: 'Plat', pourcentages: {
      1: 0.7
    }, produits: {
      'croque': {1: 1.0},
    }),
  ],
);

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

Future<Uint8List> _exporter(WidgetTester tester, Stream<CalculClub?>? calcul) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  Uint8List? recu;
  await tester.pumpWidget(MaterialApp(
    home: EcranBilan(
      evenement: _tournoi,
      tableau: Stream.value(TableauDeBord.depuis(const [])),
      produits: Stream.value(_produits),
      gymnases: Stream.value(_gymnases),
      stocks: Stream.value(const {}),
      stocksReference: Stream.value(const {}),
      calculClub: calcul,
      partager: (_, o, _) async => recu = o,
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('exporter_excel')));
  await tester.pump();
  await tester.pump();
  return recu!;
}

void main() {
  testWidgets('tournoi aux repas et groupes détaillés : les deux feuilles sont remplies',
      (tester) async {
    final o = await _exporter(tester, Stream.value(_calcul));
    expect(_donnees(o, 'Repas'), [
      [1, 'Gymnase 1', 49, 49, 10, 11, 0, 0],
    ]);
    expect(_donnees(o, 'Groupes'), [
      ['Plat', 1, 70, 'Croque-monsieur', 100],
    ]);
  });

  testWidgets('tournoi sans détail : export identique à avant, feuilles vides', (tester) async {
    for (final flux in <Stream<CalculClub?>?>[null, Stream.value(null)]) {
      final o = await _exporter(tester, flux);
      expect(_donnees(o, 'Repas'), isEmpty);
      expect(_donnees(o, 'Groupes'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
