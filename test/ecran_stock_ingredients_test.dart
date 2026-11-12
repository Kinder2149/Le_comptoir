import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_evenements.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_courses.dart';
import 'package:le_comptoir/ecran_stock_depart.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/theme.dart';
import 'package:le_comptoir/ticket.dart' show EtatStock;

// Mission « Calcul du club », V6 (décision 89) : les ingrédients en stock se saisissent dans
// la carte « Stock de départ » de la Préparation, et c'est le même chiffre que « En stock »
// de la page Courses (même liste, même champ).

class _FausseCaisses implements DepotCaisses {
  @override
  Stream<TableauDeBord> suivreTableauDeBord({Set<String>? gymnaseIds}) =>
      Stream.value(TableauDeBord.depuis(const <ResumeCaisse>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxDepot implements DepotEvenements {
  _FauxDepot(this.liste);

  ListeCourses liste;
  final _flux = StreamController<ListeCourses?>.broadcast();

  static const croque = ProduitEvenement('croque', 'Croque', 300, null,
      fiche: FicheProduit(type: 'compose', conso: 2, ingredients: [
        Ingredient('Pain de mie', 2, 'tranche', 'boulangerie'),
        Ingredient('Gruyère râpé', 7, 'g', 'frais'),
      ]));

  @override
  Stream<Evenement?> suivreEvenement(String id) => Stream.value(const Evenement(
        id: 'e',
        nom: 'Tournoi',
        date: '2026-10-03',
        statut: 'preparation',
        modes: ['especes'],
        menuNom: 'Menu',
      ));

  @override
  Stream<List<ProduitEvenement>> suivreProduits(String id,
          {String? gymnaseId, Set<String>? gymnases}) =>
      Stream.value(const [croque]);

  @override
  Stream<List<Gymnase>> suivreGymnases(String id) => Stream.value(
      [Gymnase('g1', 'Gymnase A', 80), Gymnase('g2', 'Gymnase B', 40)]);

  @override
  Stream<Map<String, Map<String, EtatStock>>> suivreEtats(String id,
          {Set<String>? gymnases}) =>
      Stream.value(const {});

  @override
  Stream<Map<String, Map<String, int>>> suivreStocksParGymnase(String id,
          {Set<String>? gymnases}) =>
      Stream.value(const {});

  @override
  Stream<Map<String, Map<String, StockDepart>>> suivreStocksDepart(String id,
          {Set<String>? gymnases}) =>
      Stream.value(const {});

  @override
  Stream<Map<String, Prevision>> suivrePrevisions(String evenementId) =>
      Stream.value(const {});

  @override
  Stream<ListeCourses?> suivreListeCourses(String evenementId) async* {
    yield liste;
    yield* _flux.stream;
  }

  @override
  DepotCaisses caisses(String evenementId) => _FausseCaisses();

  @override
  Future<void> enregistrerListeCourses(String evenementId, ListeCourses l) async {
    liste = l;
    _flux.add(l);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _liste = ListeCourses(lignes: [LigneCourse('g1', 'croque', 100)]);
const _clePain = 'pain de mie|tranche';
const _cleGruyere = 'gruyere rape|g';

Future<void> _attendre(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _preparation(WidgetTester tester, _FauxDepot depot,
    {Size taille = const Size(360, 800)}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeComptoir(),
    home: EcranStockDepart(
      evenement: depot.suivreEvenement('e'),
      portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
      gymnases: depot.suivreGymnases('e'),
      produits: depot.suivreProduits('e'),
      stocks: depot.suivreStocksDepart('e'),
      definirStock: (g, p, q) async {},
      onVoirGymnases: () {},
      ingredients: StockIngredients(depot: depot, evenementId: 'e'),
    ),
  ));
  await _attendre(tester);
  await tester.tap(find.byKey(const Key('stock_ingredients')));
  await _attendre(tester);
}

String _champ(WidgetTester tester, String cle) =>
    tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;

void main() {
  testWidgets('partie « Ingrédients et emballages » : chaque article avec son unité',
      (tester) async {
    await _preparation(tester, _FauxDepot(_liste));
    expect(find.text('Ingrédients et emballages'), findsOneWidget);
    expect(find.byKey(const Key('nom_ing_$_clePain')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('unite_ing_$_clePain'))).data,
        'tranches');
    expect(tester.widget<Text>(find.byKey(const Key('unite_ing_$_cleGruyere'))).data,
        'g');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saisi à la Préparation, vu dans Courses, et inversement',
      (tester) async {
    final depot = _FauxDepot(_liste);
    await _preparation(tester, depot);
    await tester.enterText(find.byKey(const Key('stock_ing_$_clePain')), '50');
    await tester.pump(const Duration(seconds: 1));
    expect(depot.liste.restes[_clePain], 50);
    expect(depot.liste.lignes.length, 1); // le reste de la liste est gardé

    tester.view.physicalSize = const Size(400, 1600);
    await tester.pumpWidget(MaterialApp(
      theme: themeComptoir(),
      home: EcranCourses(depot: depot, evenementId: 'e'),
    ));
    await _attendre(tester);
    expect(tester.widget<Text>(find.byKey(const Key('en_stock_$_clePain'))).data,
        'En stock : 50 tranches');

    // Dans l'autre sens : un chiffre saisi dans Courses apparaît à la Préparation.
    await tester.tap(find.byKey(const Key('modifier_reste_$_clePain')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('reste_$_clePain')), '80');
    await tester.tap(find.byKey(const Key('valider_reste')));
    await tester.pump(const Duration(seconds: 1));
    expect(depot.liste.restes[_clePain], 80);

    await _preparation(tester, depot);
    expect(_champ(tester, 'stock_ing_$_clePain'), '80');
  });

  testWidgets("un seul bloc pour tout l'événement, quel que soit l'onglet",
      (tester) async {
    final depot = _FauxDepot(_liste);
    await _preparation(tester, depot);
    expect(find.byKey(const Key('stock_ingredients')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('stock_ing_$_clePain')), '12');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('onglet_gymnase_g2')));
    await _attendre(tester);
    expect(find.byKey(const Key('stock_ingredients')), findsOneWidget);
    expect(find.byKey(const Key('stock_ing_$_clePain')), findsOneWidget);
    expect(_champ(tester, 'stock_ing_$_clePain'), '12');
  });

  testWidgets('360 px : aucun débordement, bloc ouvert', (tester) async {
    await _preparation(tester, _FauxDepot(_liste), taille: const Size(360, 640));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onglet_gymnase_g2')));
    await _attendre(tester);
    expect(tester.takeException(), isNull);
  });
}
