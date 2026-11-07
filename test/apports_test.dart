import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

// Mission « Préparer l'événement », étape P10 : les apports nommés (décision 59).
// « Quiche, 8 parts » (Léa, Gymnase A) et « Cake aux olives, 1 part » (Max, Gymnase B)
// pour le produit « Gâteau salé ».
const _quiche = Apport(
  id: 'a1',
  produitId: 'gs',
  produitNom: 'Gâteau salé',
  nom: 'Quiche',
  parts: 8,
  prenom: 'Léa',
  gymnaseId: 'g1',
  gymnaseNom: 'Gymnase A',
);
const _cake = Apport(
  id: 'a2',
  produitId: 'gs',
  produitNom: 'Gâteau salé',
  nom: 'Cake aux olives',
  parts: 1,
  prenom: 'Max',
  gymnaseId: 'g2',
  gymnaseNom: 'Gymnase B',
);

const _gymnases = [Gymnase('g1', 'Gymnase A', 40), Gymnase('g2', 'Gymnase B', 30)];
const _produits = [ProduitEvenement('gs', 'Gâteau salé', 250, null)];
const _evenement = Evenement(
  id: 'e1',
  nom: 'Tournoi d’automne',
  date: '2026-10-03',
  statut: 'en_cours',
  modes: ['especes'],
  menuNom: 'Menu',
);

Uint8List _export(List<Apport> apports, {List<Gymnase> gymnases = _gymnases}) =>
    construireExport(
      evenement: _evenement,
      produits: _produits,
      gymnases: gymnases,
      stocksReference: const {},
      stocksActuels: const {},
      tableau: TableauDeBord.depuis(const []),
      apports: apports,
    );

List<List<String?>> _bilan(Uint8List octets) => [
      for (final l in Excel.decodeBytes(octets).tables['Bilan']!.rows)
        [for (final d in l) d?.value?.toString()],
    ];

void main() {
  group('critère 4 : nom vide ou parts hors 1 à 1000 refusés', () {
    test('la règle de l\'application', () {
      expect(erreurApport('Quiche', 8), isNull);
      expect(erreurApport('  Quiche  ', 1), isNull);
      expect(erreurApport('Quiche', 1000), isNull);
      expect(erreurApport('x' * 40, 5), isNull);
      expect(erreurApport('', 8), isNotNull);
      expect(erreurApport('   ', 8), isNotNull);
      expect(erreurApport('x' * 41, 8), isNotNull);
      expect(erreurApport('Quiche', 0), isNotNull);
      expect(erreurApport('Quiche', -3), isNotNull);
      expect(erreurApport('Quiche', 1001), isNotNull);
      expect(erreurApport('Quiche', null), isNotNull);
    });
  });

  group('critère 3 : « Quiche, 8 parts, prénom, gymnase »', () {
    test('la ligne d\'un apport', () {
      expect(_quiche.ligne, 'Quiche, 8 parts, Léa, Gymnase A');
      expect(_cake.ligne, 'Cake aux olives, 1 part, Max, Gymnase B');
    });

    test('l\'export liste les apports dans la feuille Bilan', () {
      final lignes = _bilan(_export([_quiche, _cake]));
      final i = lignes.indexWhere((l) => l.first == 'Apports');
      expect(i, greaterThan(0));
      expect(lignes[i + 1].take(5), ['Apport', 'Parts', 'Prénom', 'Gymnase', 'Produit']);
      expect(lignes[i + 2].take(5), ['Quiche', '8', 'Léa', 'Gymnase A', 'Gâteau salé']);
      expect(lignes[i + 3].take(5),
          ['Cake aux olives', '1', 'Max', 'Gymnase B', 'Gâteau salé']);
    });

    test('sans apport, la rubrique n\'existe pas', () {
      expect(_bilan(_export(const [])).any((l) => l.first == 'Apports'), isFalse);
    });

    testWidgets('le bilan affiche la rubrique ; la vue d\'un gymnase filtre ; limité aux visibles',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      Uint8List? octets;
      Future<void> afficher(List<Gymnase> gymnases) async {
        await tester.pumpWidget(MaterialApp(
          home: EcranBilan(
            evenement: _evenement,
            tableau: Stream.value(TableauDeBord.depuis(const [])),
            produits: Stream.value(_produits),
            gymnases: Stream.value(gymnases),
            stocks: Stream.value(const {}),
            apports: Stream.value([_quiche, _cake]),
            partager: (n, o, m) async => octets = o,
          ),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }
      }

      String texte(String cle) => tester.widget<Text>(find.byKey(Key(cle))).data!;

      await afficher(_gymnases);
      expect(texte('bilan_apport_a1'), 'Quiche, 8 parts, Léa, Gymnase A (Gâteau salé)');
      expect(texte('bilan_apport_a2'),
          'Cake aux olives, 1 part, Max, Gymnase B (Gâteau salé)');
      // Vue d'un gymnase : seulement ses apports.
      await tester.tap(find.byKey(const Key('vue_g1')));
      await tester.pump();
      expect(find.byKey(const Key('bilan_apport_a1')), findsOneWidget);
      expect(find.byKey(const Key('bilan_apport_a2')), findsNothing);
      // L'export part de la vue commune, quelle que soit la vue affichée.
      await tester.tap(find.byKey(const Key('exporter_excel')));
      await tester.pump();
      await tester.pump();
      final lignes = _bilan(octets!);
      expect(lignes.where((l) => l.first == 'Quiche' || l.first == 'Cake aux olives').length, 2);

      // Un gestionnaire d'un seul gymnase ne voit pas les apports de l'autre.
      await afficher([_gymnases[1]]);
      expect(find.byKey(const Key('bilan_apport_a1')), findsNothing);
      expect(find.byKey(const Key('bilan_apport_a2')), findsOneWidget);
    });
  });
}
