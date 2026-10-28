import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_caisse.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/theme.dart';
import 'package:le_comptoir/ticket.dart';

// Chantier Stock et courses, étape 4 : rupture, stock bas et « vide ».
void main() {
  group('état du stock', () {
    test('seuil de 10 % du dernier total, calculé à la main', () {
      // Total de référence 50 : bas jusqu'à 5 inclus, normal à partir de 6.
      expect(etatStock(quantite: 6, reference: 50), EtatStock.normal);
      expect(etatStock(quantite: 5, reference: 50), EtatStock.bas);
      expect(etatStock(quantite: 1, reference: 50), EtatStock.bas);
      expect(etatStock(quantite: 0, reference: 50), EtatStock.epuise);
      expect(etatStock(quantite: -3, reference: 50), EtatStock.epuise);
      // Total de 10 : bas à 1 seulement.
      expect(etatStock(quantite: 2, reference: 10), EtatStock.normal);
      expect(etatStock(quantite: 1, reference: 10), EtatStock.bas);
    });

    test('sans total de référence ou à zéro : pas de stock bas', () {
      expect(etatStock(quantite: 1), EtatStock.normal);
      expect(etatStock(quantite: 1, reference: 0), EtatStock.normal);
      expect(etatStock(quantite: 4, reference: null), EtatStock.normal);
    });

    test('sans quantité suivie : vide ou rien', () {
      expect(etatStock(), EtatStock.aucun);
      expect(etatStock(vide: true), EtatStock.vide);
      // La quantité l'emporte sur le signal « vide ».
      expect(etatStock(quantite: 8, reference: 8, vide: true), EtatStock.normal);
    });

    test('un produit sans état explicite le déduit de son stock', () {
      expect(const Produit('a', 'A', 100, 0).etatAffiche, EtatStock.epuise);
      expect(const Produit('a', 'A', 100, 3).etatAffiche, EtatStock.normal);
      expect(const Produit('a', 'A', 100).etatAffiche, EtatStock.aucun);
      expect(
          const Produit('a', 'A', 100, 3, null, null, EtatStock.bas).etatAffiche,
          EtatStock.bas);
    });
  });

  group('caisse', () {
    Future<void> ouvrir(WidgetTester tester, List<Produit> produits) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranCaisse(produits: produits, modes: const ['especes']),
      ));
    }

    Color? fond(WidgetTester tester, String id) => tester
        .widget<Card>(find.ancestor(
            of: find.byKey(Key('produit_$id')), matching: find.byType(Card)))
        .color;

    testWidgets('normal, bas, épuisé, vide : couleur et libellé', (tester) async {
      await ouvrir(tester, const [
        Produit('tarte', 'Tarte', 250, 6, null, null, EtatStock.normal),
        Produit('flan', 'Flan', 200, 5, null, null, EtatStock.bas),
        Produit('salade', 'Salade', 300, 0, null, null, EtatStock.epuise),
        Produit('crepe', 'Crêpe', 200, null, null, null, EtatStock.vide),
        Produit('cafe', 'Café', 100),
      ]);
      expect(contenuTexte(tester, 'stock_tarte'), 'Stock : 6');
      expect(contenuTexte(tester, 'stock_flan'), 'Stock bas : 5');
      expect(contenuTexte(tester, 'stock_salade'), 'Épuisé');
      expect(contenuTexte(tester, 'stock_crepe'), 'Vide');
      expect(find.byKey(const Key('stock_cafe')), findsNothing);
      expect(fond(tester, 'tarte'), isNull);
      expect(fond(tester, 'flan'), Palette.ocreDoux);
      expect(fond(tester, 'salade'), Palette.briqueDoux);
      expect(fond(tester, 'crepe'), Palette.briqueDoux);
      expect(fond(tester, 'cafe'), isNull);
    });

    testWidgets('la vente reste possible en rupture et pour un produit vide',
        (tester) async {
      await ouvrir(tester, const [
        Produit('salade', 'Salade', 300, 0, null, null, EtatStock.epuise),
        Produit('crepe', 'Crêpe', 200, null, null, null, EtatStock.vide),
      ]);
      await tester.tap(find.byKey(const Key('produit_salade')));
      await tester.tap(find.byKey(const Key('produit_crepe')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('total'))).data,
          'Total : 5,00 €');
    });
  });

  testWidgets('double appui sur l’encaissement : une seule vente', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    var ventes = 0;
    await tester.pumpWidget(MaterialApp(
      home: EcranCaisse(
        produits: const [Produit('cafe', 'Café', 100)],
        modes: const ['especes'],
        onEncaisser: (_, _, _) => ventes++,
      ),
    ));
    await tester.tap(find.byKey(const Key('produit_cafe')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('encaisser_especes')));
    await tester.tap(find.byKey(const Key('encaisser_especes')), warnIfMissed: false);
    await tester.pump();
    expect(ventes, 1);
  });

  group('suivi en direct', () {
    const gymnases = [Gymnase('g1', 'Gymnase A'), Gymnase('g2', 'Gymnase B')];
    const produits = [
      ProduitEvenement('tarte', 'Tarte', 250, null),
      ProduitEvenement('crepe', 'Crêpe', 200, null),
      ProduitEvenement('cafe', 'Café', 100, null),
    ];
    const etats = {
      'g1': {'tarte': EtatStock.bas, 'crepe': EtatStock.normal},
      'g2': {'tarte': EtatStock.epuise, 'crepe': EtatStock.vide},
    };

    Future<void> afficher(WidgetTester tester, {bool commun = true}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuiviEnDirect(
              tableau: Stream.value(TableauDeBord.depuis(const [])),
              produits: Stream.value(produits),
              gymnases: Stream.value(gymnases),
              etats: Stream.value(etats),
              commun: commun,
              onOuvrirCaisse: (_) {},
            ),
          ),
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    testWidgets('vue commune : les gymnases concernés', (tester) async {
      await afficher(tester);
      expect(contenuTexte(tester, 'direct_signal_tarte'),
          'Épuisé : Gymnase B · Stock bas : Gymnase A');
      expect(contenuTexte(tester, 'direct_signal_crepe'), 'Vide : Gymnase B');
      expect(find.byKey(const Key('direct_signal_cafe')), findsNothing);
    });

    testWidgets('vue d’un gymnase : le signal de ce gymnase seul', (tester) async {
      await afficher(tester);
      await tester.tap(find.byKey(const Key('vue_g1')));
      await tester.pump();
      expect(contenuTexte(tester, 'direct_signal_tarte'), 'Stock bas');
      expect(find.byKey(const Key('direct_signal_crepe')), findsNothing);
      await tester.tap(find.byKey(const Key('vue_g2')));
      await tester.pump();
      expect(contenuTexte(tester, 'direct_signal_tarte'), 'Épuisé');
      expect(contenuTexte(tester, 'direct_signal_crepe'), 'Vide');
    });
  });
}

String contenuTexte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;
