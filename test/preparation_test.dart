import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/ecran_classeur.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/partage.dart';


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
  bool avecAssistant = true,
}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: EcranClasseur(
      evenement: Stream.value(_ev(statut)),
      portee: portee ?? _tout(),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      stocks: Stream.value(_stocks),
      assistant: avecAssistant
          ? (_) => const Scaffold(body: Text('Assistant', key: Key('assistant_factice')))
          : null,
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

  group('T2 : « Importer un classeur » renvoie vers l\'assistant', () {
    testWidgets('le bouton ouvre l\'assistant (construit pour ce tournoi)',
        (tester) async {
      await _afficher(tester);
      expect(find.byKey(const Key('importer_classeur')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('importer_classeur'))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_factice')), findsOneWidget);
    });

    testWidgets('événement clôturé : pas de bouton d\'import', (tester) async {
      await _afficher(tester, statut: 'cloture');
      expect(find.byKey(const Key('importer_classeur')), findsNothing);
      expect(find.byKey(const Key('telecharger_modele')), findsOneWidget);
    });

    testWidgets('sans assistant fourni : pas de bouton d\'import', (tester) async {
      await _afficher(tester, avecAssistant: false);
      expect(find.byKey(const Key('importer_classeur')), findsNothing);
    });
  });
}

String texte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;
