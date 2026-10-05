import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/main.dart';

void main() {
  Future<void> ouvrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LeComptoir());
  }

  String total(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('total'))).data!;

  testWidgets('les 9 produits sont affichés, total à zéro', (tester) async {
    await ouvrir(tester);
    expect(find.text('Part de gâteau sucrée'), findsOneWidget);
    expect(find.text('Part de gâteau salée'), findsOneWidget);
    expect(find.text('Crêpe'), findsOneWidget);
    expect(find.byKey(const Key('produit_croque')), findsOneWidget);
    expect(total(tester), 'Total : 0,00 €');
  });

  testWidgets('appuyer sur des produits met à jour le total', (tester) async {
    await ouvrir(tester);
    await tester.tap(find.byKey(const Key('produit_croque'))); // 3,00
    await tester.tap(find.byKey(const Key('produit_croque'))); // 3,00
    await tester.tap(find.byKey(const Key('produit_crepe'))); // 2,50
    await tester.pump();
    expect(total(tester), 'Total : 8,50 €');
    expect(find.text('2 × Croque-monsieur'), findsOneWidget);
  });

  testWidgets('retirer un article diminue le total', (tester) async {
    await ouvrir(tester);
    await tester.tap(find.byKey(const Key('produit_cafe')));
    await tester.tap(find.byKey(const Key('produit_cafe')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('retirer_cafe')));
    await tester.pump();
    expect(total(tester), 'Total : 1,00 €');
  });

  testWidgets('remise à zéro vide le ticket', (tester) async {
    await ouvrir(tester);
    await tester.tap(find.byKey(const Key('produit_soda')));
    await tester.pump();
    expect(total(tester), 'Total : 1,50 €');
    await tester.tap(find.byKey(const Key('remise_a_zero')));
    await tester.pump();
    expect(total(tester), 'Total : 0,00 €');
    expect(find.byKey(const Key('retirer_soda')), findsNothing);
  });
}
