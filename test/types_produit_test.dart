import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_menu.dart';

const croque = FicheProduit(type: 'compose', ingredients: [
  Ingredient('Pain de mie', 2, 'tranche'),
  Ingredient('Jambon', 0.25, 'tranche'),
  Ingredient('Gruyère', 25, 'g'),
]);

void main() {
  group('fiche produit : saisies refusées', () {
    test('composé sans ingrédient', () {
      expect(const FicheProduit(type: 'compose').erreur(), contains('ingrédient'));
    });
    test('quantité à zéro ou négative', () {
      for (final q in [0.0, -1.0]) {
        final f = FicheProduit(
            type: 'compose', ingredients: [Ingredient('Pain', q, 'tranche')]);
        expect(f.erreur(), contains('supérieure à zéro'), reason: '$q');
      }
    });
    test('ratio à zéro, négatif ou absent', () {
      for (final v in [0.0, -2.0, null]) {
        expect(FicheProduit(type: 'litre', verresParLitre: v).erreur(),
            contains('verres par litre'),
            reason: '$v');
      }
    });
    test('plus de 20 ingrédients', () {
      final f = FicheProduit(type: 'compose', ingredients: [
        for (var i = 0; i < 21; i++) Ingredient('I$i', 1, 'g'),
      ]);
      expect(f.erreur(), contains('20 ingrédients'));
      expect(
          FicheProduit(type: 'compose', ingredients: [
            for (var i = 0; i < 20; i++) Ingredient('I$i', 1, 'g'),
          ]).erreur(),
          isNull);
    });
    test('nom d\'ingrédient vide ou consommation négative', () {
      expect(
          const FicheProduit(
              type: 'compose',
              ingredients: [Ingredient(' ', 1, 'g')]).erreur(),
          isNotNull);
      expect(const FicheProduit(conso: -1).erreur(), contains('Consommation'));
    });
    test('fiches correctes', () {
      expect(croque.erreur(), isNull);
      expect(
          const FicheProduit(type: 'litre', verresParLitre: 8, conso: 2)
              .erreur(),
          isNull);
      expect(FicheProduit.unite.erreur(), isNull);
    });
  });

  group('lecture et écriture', () {
    test('un document sans type est « unité »', () {
      final f = FicheProduit.depuis({'nom': 'Fruit', 'prixCentimes': 100});
      expect(f.type, 'unite');
      expect(f.ingredients, isEmpty);
      expect(f.conso, isNull);
    });
    test('un type inconnu retombe sur « unité »', () {
      expect(FicheProduit.depuis({'type': 'bizarre'}).type, 'unite');
    });
    test('la recette écrite se relit à l\'identique', () {
      final relue = FicheProduit.depuis(croque.versMap());
      expect(relue.type, 'compose');
      expect(relue.ingredients, croque.ingredients);
    });
    test('le café au litre se relit à l\'identique', () {
      const cafe = FicheProduit(type: 'litre', verresParLitre: 8, conso: 2);
      final relue = FicheProduit.depuis(cafe.versMap());
      expect(relue.verresParLitre, 8);
      expect(relue.conso, 2);
      expect(relue.ingredients, isEmpty);
    });
    test('un produit à l\'unité n\'écrit ni recette ni ratio', () {
      expect(FicheProduit.unite.versMap().keys, ['type']);
    });
  });

  group('saisie des nombres', () {
    test('virgule, point, fraction', () {
      expect(parserNombre('0,25'), 0.25);
      expect(parserNombre('1/4'), 0.25);
      expect(parserNombre(' 25 '), 25);
      expect(parserNombre('1/0'), isNull);
      expect(parserNombre('abc'), isNull);
      expect(parserNombre(''), isNull);
    });
    test('affichage sans zéros inutiles', () {
      expect(nombrePourSaisie(2), '2');
      expect(nombrePourSaisie(0.25), '0,25');
      expect(nombrePourSaisie(1.5), '1,5');
    });
  });

  group('ingrédient partagé', () {
    test('reconnu par son nom, sans casse ni accents ni espaces autour', () {
      expect(cleIngredient(' Pain de  MIÉ '), cleIngredient('pain de mie'));
      expect(const Ingredient('Gruyère', 1, 'g').cle,
          const Ingredient('gruyere', 5, 'kg').cle);
      expect(cleIngredient('Jambon'), isNot(cleIngredient('Pain')));
    });
  });

  test('les règles d\'accès imposent les mêmes types et unités', () {
    final regles = File('firestore.rules').readAsStringSync();
    List<String> liste(RegExp re) => RegExp(r"'([^']+)'")
        .allMatches(re.firstMatch(regles)!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
    expect(liste(RegExp(r"d\.type in \[([^\]]*)\]")), typesProduit);
    final unites = RegExp(r"unite\.matches\('([^']*)'\)")
        .firstMatch(regles)!
        .group(1)!
        .split('|');
    expect(unites, unitesIngredient);
    expect(regles, contains('l.size() <= $maxIngredients'));
  });

  group('formulaire produit', () {
    Future<void> ouvrir(
        WidgetTester tester, void Function(Future<ProduitSaisi?>) f,
        {ProduitMenu? produit}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => f(demanderProduit(c,
                produit: produit, selecteurPhoto: (_) async => null)),
            child: const Text('ouvrir'),
          ),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    Future<void> choisirType(WidgetTester tester, String type) async {
      await tester.ensureVisible(find.byKey(const Key('type_produit')));
      await tester.tap(find.byKey(const Key('type_produit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('type_$type')).last);
      await tester.pumpAndSettle();
    }

    Future<void> saisir(WidgetTester tester, String cle, String texte) async {
      await tester.ensureVisible(find.byKey(Key(cle)));
      await tester.enterText(find.byKey(Key(cle)), texte);
      await tester.pump();
    }

    Future<void> ajouterIngredient(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('ajouter_ingredient')));
      await tester.tap(find.byKey(const Key('ajouter_ingredient')));
      await tester.pump();
    }

    Future<void> valider(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('valider_produit')));
      await tester.tap(find.byKey(const Key('valider_produit')));
      await tester.pumpAndSettle();
    }

    testWidgets('croque-monsieur composé : 3 ingrédients saisis, 3 retrouvés',
        (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f);
      expect(find.byKey(const Key('ajouter_ingredient')), findsNothing);
      await saisir(tester, 'nom_produit', 'Croque-monsieur');
      await saisir(tester, 'prix_produit', '3');
      await choisirType(tester, 'compose');
      for (var i = 0; i < 3; i++) {
        await ajouterIngredient(tester);
      }
      await saisir(tester, 'ingredient_nom_0', 'Pain de mie');
      await saisir(tester, 'ingredient_qte_0', '2');
      await saisir(tester, 'ingredient_nom_1', 'Jambon');
      await saisir(tester, 'ingredient_qte_1', '1/4');
      await saisir(tester, 'ingredient_nom_2', 'Gruyère');
      await saisir(tester, 'ingredient_qte_2', '25');
      for (final (i, u) in [(0, 'tranche'), (1, 'tranche'), (2, 'g')]) {
        await tester.ensureVisible(find.byKey(Key('ingredient_unite_$i')));
        await tester.tap(find.byKey(Key('ingredient_unite_$i')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('unite_${i}_$u')).last);
        await tester.pumpAndSettle();
      }
      await valider(tester);
      final r = (await futur)!;
      expect(r.nom, 'Croque-monsieur');
      expect(r.fiche.type, 'compose');
      expect(r.fiche.ingredients, croque.ingredients);
    });

    testWidgets('café au litre : 8 verres par litre, consommation 2',
        (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f);
      await saisir(tester, 'nom_produit', 'Café');
      await saisir(tester, 'prix_produit', '1,5');
      await choisirType(tester, 'litre');
      await saisir(tester, 'verres_par_litre', '8');
      await saisir(tester, 'conso_produit', '2');
      await valider(tester);
      final r = (await futur)!;
      expect(r.fiche.type, 'litre');
      expect(r.fiche.verresParLitre, 8);
      expect(r.fiche.conso, 2);
    });

    testWidgets('rouvrir un produit retrouve exactement ses valeurs',
        (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f,
          produit: const ProduitMenu('p', 'Croque-monsieur', 300, null,
              fiche: FicheProduit(type: 'compose', conso: 2, ingredients: [
                Ingredient('Pain de mie', 2, 'tranche'),
                Ingredient('Jambon', 0.25, 'tranche'),
                Ingredient('Gruyère', 25, 'g'),
              ])));
      expect(find.text('Pain de mie'), findsOneWidget);
      expect(find.text('0,25'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      await valider(tester);
      final r = (await futur)!;
      expect(r.fiche.ingredients, croque.ingredients);
      expect(r.fiche.conso, 2);
    });

    testWidgets('un produit existant sans type reste « unité »',
        (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f,
          produit: const ProduitMenu('f', 'Fruit', 100, 12, icone: 'fruit'));
      expect(find.byKey(const Key('ajouter_ingredient')), findsNothing);
      expect(find.byKey(const Key('verres_par_litre')), findsNothing);
      await valider(tester);
      final r = (await futur)!;
      expect(r.fiche.type, 'unite');
      expect(r.prixCentimes, 100);
      expect(r.stock, 12);
      expect(r.icone, 'fruit');
    });

    testWidgets('saisies incohérentes : message clair, formulaire reste ouvert',
        (tester) async {
      var ferme = false;
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) {
        futur = f;
        f.then((_) => ferme = true);
      });
      await saisir(tester, 'nom_produit', 'Croque');
      await saisir(tester, 'prix_produit', '3');
      await choisirType(tester, 'compose');
      await valider(tester);
      expect(find.textContaining('au moins un ingrédient'), findsOneWidget);
      await ajouterIngredient(tester);
      await saisir(tester, 'ingredient_nom_0', 'Pain');
      await saisir(tester, 'ingredient_qte_0', '0');
      await valider(tester);
      expect(find.textContaining('supérieure à zéro'), findsOneWidget);
      await saisir(tester, 'ingredient_qte_0', '-2');
      await valider(tester);
      expect(find.textContaining('supérieure à zéro'), findsOneWidget);
      await saisir(tester, 'ingredient_qte_0', '1');
      for (var i = 0; i < 20; i++) {
        await ajouterIngredient(tester);
        await saisir(tester, 'ingredient_nom_${i + 1}', 'I$i');
        await saisir(tester, 'ingredient_qte_${i + 1}', '1');
      }
      await valider(tester);
      expect(find.textContaining('20 ingrédients'), findsOneWidget);
      await choisirType(tester, 'litre');
      await saisir(tester, 'verres_par_litre', '0');
      await valider(tester);
      expect(find.textContaining('verres par litre'), findsOneWidget);
      expect(ferme, isFalse);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(await futur, isNull);
    });
  });
}
