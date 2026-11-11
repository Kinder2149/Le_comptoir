import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/ecran_gymnases.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/tableau_bord.dart';
import 'package:le_comptoir/ticket.dart';

// Mission « Ergonomie de la gestion », étape E7 (décision 62) : le stock pendant le
// tournoi. Logique de rangement (pure), liste repliée et ligne (widgets).

const _coca = ProduitEvenement('coca', 'Coca', 150, 0);
const _cafe = ProduitEvenement('cafe', 'Café', 100, 3);
const _eau = ProduitEvenement('eau', 'Eau', 100, 10);
const _mars = ProduitEvenement('mars', 'Mars', 120, null);
const _chips = ProduitEvenement('chips', 'Chips', 120, null);

void main() {
  group('rangement par urgence (critère 1)', () {
    test('Coca épuisé et Café en stock bas : Coca puis Café en tête', () {
      final r = rangerStocks(
        produits: const [_eau, _cafe, _coca],
        etats: const {
          'coca': EtatStock.epuise,
          'cafe': EtatStock.bas,
          'eau': EtatStock.normal,
        },
      );
      expect([for (final p in r.suivis) p.id], ['coca', 'cafe', 'eau']);
    });

    test('épuisé avant stock bas, puis le reste ; à rang égal, ordre alphabétique', () {
      final r = rangerStocks(
        produits: const [_eau, _cafe, _coca],
        etats: const {
          'coca': EtatStock.bas,
          'cafe': EtatStock.epuise,
          'eau': EtatStock.normal,
        },
      );
      expect([for (final p in r.suivis) p.id], ['cafe', 'coca', 'eau']);
    });

    test('les produits non suivis sont à part, sans toucher aux suivis', () {
      final r = rangerStocks(
        produits: const [_mars, _coca, _chips],
        etats: const {'coca': EtatStock.epuise},
      );
      expect([for (final p in r.suivis) p.id], ['coca']);
      expect([for (final p in r.nonSuivis) p.id], ['chips', 'mars']);
    });
  });

  group('liste repliée (critère 2)', () {
    Future<void> monter(WidgetTester tester) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ListeStocks(
              gymnaseId: 'gA',
              produits: const [_coca, _cafe, _mars, _chips],
              etats: const {
                'coca': EtatStock.epuise,
                'cafe': EtatStock.bas,
                'mars': EtatStock.aucun,
                'chips': EtatStock.aucun,
              },
              ligne: (p, etat) =>
                  Text(p.nom, key: Key('nom_${p.id}')),
            ),
          ),
        ));

    testWidgets('les non suivis sont repliés sous une ligne qui les compte',
        (tester) async {
      await monter(tester);
      expect(find.byKey(const Key('nom_coca')), findsOneWidget);
      expect(find.byKey(const Key('nom_cafe')), findsOneWidget);
      expect(find.text('2 produits non suivis'), findsOneWidget);
      expect(find.byKey(const Key('nom_mars')), findsNothing);
      expect(find.byKey(const Key('nom_chips')), findsNothing);
    });

    testWidgets('la ligne se déplie et replie les non suivis', (tester) async {
      await monter(tester);
      await tester.tap(find.byKey(const Key('non_suivis_gA')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nom_mars')), findsOneWidget);
      expect(find.byKey(const Key('nom_chips')), findsOneWidget);
      await tester.tap(find.byKey(const Key('non_suivis_gA')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nom_mars')), findsNothing);
    });

    testWidgets('les suivis sont dans l\'ordre d\'urgence à l\'écran',
        (tester) async {
      await monter(tester);
      final yCoca = tester.getTopLeft(find.byKey(const Key('nom_coca'))).dy;
      final yCafe = tester.getTopLeft(find.byKey(const Key('nom_cafe'))).dy;
      expect(yCoca < yCafe, isTrue);
    });
  });

  group('ligne de stock (critères 3 et 4)', () {
    Future<({List<String> appels})> monter(WidgetTester tester,
        {required ProduitEvenement produit, required EtatStock etat}) async {
      final appels = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LigneStock(
            key: const Key('ligne_test'),
            produit: produit,
            gymnaseId: 'gA',
            etat: etat,
            vendu: 0,
            onAjouter: () => appels.add('ajouter'),
            onCorriger: () => appels.add('corriger'),
            onSuivre: (v) => appels.add('suivre:$v'),
            onVide: (v) => appels.add('vide:$v'),
          ),
        ),
      ));
      return (appels: appels);
    }

    testWidgets('« + » ouvre la même saisie qu\'Ajouter (même action)',
        (tester) async {
      final r = await monter(tester,
          produit: _cafe, etat: EtatStock.bas);
      await tester.tap(find.byKey(const Key('reappro_gA_cafe')));
      await tester.pump();
      expect(r.appels, ['ajouter']);
      expect(find.byKey(const Key('modifier_stock_gA_cafe')), findsOneWidget);
    });

    testWidgets('« Vide » et « Suivre le stock » depuis le menu de la ligne',
        (tester) async {
      final r = await monter(tester,
          produit: _mars, etat: EtatStock.aucun);
      expect(find.byKey(const Key('reappro_gA_mars')), findsNothing);
      await tester.tap(find.byKey(const Key('menu_gA_mars')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vide_gA_mars')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_gA_mars')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suivi_gA_mars')));
      await tester.pumpAndSettle();
      expect(r.appels, ['vide:true', 'suivre:true']);
    });

    testWidgets('un produit suivi : « Ne plus suivre le stock » dans le menu',
        (tester) async {
      final r = await monter(tester,
          produit: _cafe, etat: EtatStock.bas);
      await tester.tap(find.byKey(const Key('menu_gA_cafe')));
      await tester.pumpAndSettle();
      expect(find.text('Ne plus suivre le stock'), findsOneWidget);
      await tester.tap(find.byKey(const Key('suivi_gA_cafe')));
      await tester.pumpAndSettle();
      expect(r.appels, ['suivre:false']);
    });
  });
}
