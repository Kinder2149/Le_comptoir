import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/ecran_preparation.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

// Étape P2 : l'écran Préparation, étape 1 « Stock de départ ».
//   Gymnases A et B ; produits finis Soda et Croque (jamais d'ingrédient dans la liste).
//   Stock au départ : A : Soda 6 (repris), Croque 10 ; B : rien.
Evenement _ev(String statut) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: statut,
    modes: const ['carte'],
    menuNom: 'M');

const _gymnases = [Gymnase('gA', 'Gymnase A'), Gymnase('gB', 'Gymnase B')];
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

Future<List<(String, String, int)>> _afficher(
  WidgetTester tester, {
  String statut = 'en_preparation',
  PorteeGestion? portee,
  VoidCallback? voirGymnases,
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final ecrits = <(String, String, int)>[];
  await tester.pumpWidget(MaterialApp(
    home: EcranPreparation(
      evenement: Stream.value(_ev(statut)),
      portee: portee ?? _tout(),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      stocks: Stream.value(_stocks),
      definirStock: (g, p, q) async => ecrits.add((g, p, q)),
      onVoirGymnases: voirGymnases ?? () {},
    ),
  ));
  await tester.pump();
  await tester.pump();
  return ecrits;
}

void main() {
  testWidgets('en préparation : une carte par gymnase, les produits finis seulement, '
      'le stock repris est pré-rempli et marqué', (tester) async {
    await _afficher(tester);
    expect(find.byKey(const Key('titre_etape_stock')), findsOneWidget);
    expect(find.text('Gymnase A'), findsOneWidget);
    expect(find.text('Gymnase B'), findsOneWidget);
    // Soda et Croque dans chaque gymnase, et rien d'autre.
    expect(find.text('Soda'), findsNWidgets(2));
    expect(find.text('Croque'), findsNWidgets(2));
    expect(find.byType(TextField), findsNWidgets(4));
    String champ(String cle) =>
        tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;
    expect(champ('depart_gA_soda'), '6');
    expect(champ('depart_gA_croque'), '10');
    expect(champ('depart_gB_soda'), '');
    // La marque n'apparaît que sur le stock repris.
    expect(find.text("Repris de l'événement précédent"), findsOneWidget);
    expect(find.byKey(const Key('repris_gA_soda')), findsOneWidget);
    expect(find.byKey(const Key('repris_gA_croque')), findsNothing);
    // Saisie modifiable : pas de renvoi vers « Gymnases et stocks ».
    expect(find.byKey(const Key('aller_gymnases_stocks')), findsNothing);
  });

  testWidgets('saisir 24 sodas au gymnase B enregistre 24 pour ce gymnase et ce produit',
      (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gB_soda')), '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(ecrits, [('gB', 'soda', 24)]);
  });

  testWidgets('une valeur invalide est refusée avec un message, sans écriture',
      (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gB_soda')), '100001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Entrez un nombre entier de 0 à 100 000.'), findsOneWidget);
    expect(ecrits, isEmpty);
  });

  testWidgets('une saisie laissée un instant est enregistrée sans valider', (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gA_croque')), '12');
    await tester.pump(const Duration(seconds: 2));
    expect(ecrits, [('gA', 'croque', 12)]);
  });

  testWidgets('une quantité identique à celle enregistrée n\'écrit rien', (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gA_croque')), '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(ecrits, isEmpty);
  });

  testWidgets('« Suivre tous » met à zéro les produits non suivis du gymnase',
      (tester) async {
    final ecrits = await _afficher(tester);
    // Gymnase A suit déjà tout : pas de bouton ; gymnase B : deux produits à suivre.
    expect(find.byKey(const Key('suivre_tous_depart_gA')), findsNothing);
    await tester.tap(find.byKey(const Key('suivre_tous_depart_gB')));
    await tester.pump();
    expect(ecrits.toSet(), {('gB', 'soda', 0), ('gB', 'croque', 0)});
  });

  testWidgets('un gestionnaire ne voit que ses gymnases', (tester) async {
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gB'}, nbGymnases: 2));
    expect(find.text('Gymnase B'), findsOneWidget);
    expect(find.text('Gymnase A'), findsNothing);
    expect(find.byKey(const Key('depart_gA_soda')), findsNothing);
    expect(find.byKey(const Key('depart_gB_soda')), findsOneWidget);
  });

  for (final statut in ['en_cours', 'cloture']) {
    testWidgets('événement $statut : lecture seule et renvoi vers « Gymnases et stocks »',
        (tester) async {
      var renvoi = 0;
      await _afficher(tester, statut: statut, voirGymnases: () => renvoi++);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('suivre_tous_depart_gB')), findsNothing);
      expect(
          tester.widget<Text>(find.byKey(const Key('lecture_depart_gA_soda'))).data,
          'Stock : 6');
      expect(
          tester.widget<Text>(find.byKey(const Key('lecture_depart_gB_soda'))).data,
          'Stock non suivi');
      await tester.tap(find.byKey(const Key('aller_gymnases_stocks')));
      expect(renvoi, 1);
    });
  }
}
