import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_menu.dart';
import 'package:le_comptoir/evenement.dart';

// Mission « Ergonomie de la gestion », étape E1 : familles et rayons.
List<ProduitModele> modele() =>
    lireMenuType(File('assets/menu_type.json').readAsStringSync());

void main() {
  group('listes fixes', () {
    test('familles et rayons : ordre et libellés', () {
      expect(famillesProduit, [
        'croques', 'boissons_chaudes', 'boissons_fraiches', 'snacks_fruits',
        'fait_maison', 'autre',
      ]);
      expect([for (final f in famillesProduit) libellesFamilles[f]], [
        'Croques', 'Boissons chaudes', 'Boissons fraîches', 'Snacks et fruits',
        'Fait maison', 'Autre',
      ]);
      expect(rayonsCourses,
          ['boulangerie', 'frais', 'boissons', 'epicerie', 'entretien', 'autre']);
      expect([for (final r in rayonsCourses) libellesRayons[r]], [
        'Boulangerie', 'Frais et crèmerie', 'Boissons', 'Épicerie',
        'Entretien et matériel', 'Autre',
      ]);
    });
  });

  group('critère 1 : le modèle donne une famille à chaque produit', () {
    test('menu type : familles des produits', () {
      String fam(String n) => modele().firstWhere((p) => p.nom == n).fiche.famille;
      expect(libellesFamilles[fam('Croque-monsieur')], 'Croques');
      expect(libellesFamilles[fam('Café')], 'Boissons chaudes');
      expect(libellesFamilles[fam('Cola')], 'Boissons fraîches');
      expect(libellesFamilles[fam('Barre caramel')], 'Snacks et fruits');
      expect(libellesFamilles[fam('Tarte')], 'Fait maison');
    });
    test('menu type : aucun produit sans famille précise', () {
      for (final p in modele()) {
        expect(p.fiche.famille, isNot('autre'), reason: p.nom);
      }
    });
  });

  group('critère 4 : le modèle donne un rayon aux ingrédients', () {
    test('Pain de mie : Boulangerie ; Gruyère : Frais et crèmerie', () {
      final croque = modele().firstWhere((p) => p.nom == 'Croque-monsieur').fiche;
      String ray(String n) =>
          libellesRayons[croque.ingredients.firstWhere((i) => i.nom == n).rayon]!;
      expect(ray('Pain de mie'), 'Boulangerie');
      expect(ray('Gruyère râpé'), 'Frais et crèmerie');
    });
    test('tous les ingrédients ont un rayon ; produits achetés tels quels aussi', () {
      for (final p in modele()) {
        for (final i in p.fiche.ingredients) {
          expect(i.rayon, isNot('autre'), reason: '${p.nom} / ${i.nom}');
        }
        if (p.fiche.type != 'compose' && p.fiche.provenance == 'achete') {
          expect(p.fiche.rayon, isNot('autre'), reason: p.nom);
        }
      }
      expect(
          libellesRayons[modele().firstWhere((p) => p.nom == 'Cola').fiche.rayon],
          'Boissons');
    });
  });

  group('critère 2 : la famille est retrouvée et copiée', () {
    test('écriture puis relecture de la fiche', () {
      const f = FicheProduit(
          type: 'compose',
          famille: 'croques',
          ingredients: [Ingredient('Pain de mie', 2, 'tranche', 'boulangerie')]);
      final relue = FicheProduit.depuis(f.versMap());
      expect(relue.famille, 'croques');
      expect(relue.ingredients.single.rayon, 'boulangerie');
      const coca = FicheProduit(
          type: 'litre',
          verresParLitre: 3,
          famille: 'boissons_fraiches',
          rayon: 'boissons');
      final c = FicheProduit.depuis(coca.versMap());
      expect(c.famille, 'boissons_fraiches');
      expect(c.rayon, 'boissons');
    });
    test('copie dans l\'événement avec la fiche', () {
      const p = ProduitEvenement('p', 'Café', 100, null,
          fiche: FicheProduit(
              type: 'litre',
              verresParLitre: 8,
              famille: 'boissons_chaudes',
              rayon: 'epicerie'));
      final copie = p.avecConso(2);
      expect(copie.fiche.famille, 'boissons_chaudes');
      expect(copie.fiche.rayon, 'epicerie');
      // C'est versMap de la fiche qui est écrit dans l'événement.
      expect(p.fiche.versMap()['famille'], 'boissons_chaudes');
      expect(p.fiche.versMap()['rayon'], 'epicerie');
    });
    test('ligne libre : rayon écrit et relu', () {
      const l = LigneLibre('Sacs poubelle', 2, 'entretien');
      expect(l.versMap()['rayon'], 'entretien');
      final liste = ListeCourses.depuis({
        'statut': 'preparation',
        'lignes': [],
        'libres': [l.versMap()],
        'restes': [],
      });
      expect(liste.libres.single.rayon, 'entretien');
    });
  });

  group('critère 3 : un produit d\'avant E1 est rangé dans « Autre »', () {
    test('sans famille ni rayon : aucune erreur', () {
      final f = FicheProduit.depuis({'nom': 'Vieux', 'prixCentimes': 100});
      expect(f.famille, 'autre');
      expect(f.rayon, 'autre');
      expect(f.erreur(), isNull);
      final c = FicheProduit.depuis({
        'type': 'compose',
        'ingredients': [
          {'nom': 'Pain', 'quantite': 2, 'unite': 'tranche'}
        ],
      });
      expect(c.ingredients.single.rayon, 'autre');
      expect(c.erreur(), isNull);
    });
    test('ligne libre ancienne : rayon « autre »', () {
      final liste = ListeCourses.depuis({
        'statut': 'preparation',
        'lignes': [],
        'libres': [
          {'nom': 'Gobelets', 'quantite': 3}
        ],
        'restes': [],
      });
      expect(liste.libres.single.rayon, 'autre');
    });
    test('menu type sans famille : accepté', () {
      final m = lireMenuType('[{"nom":"Eau","prixCentimes":50}]');
      expect(m.single.fiche.famille, 'autre');
    });
  });

  group('critère 5 : hors liste refusé côté application', () {
    test('fiche : famille ou rayon inconnu', () {
      expect(const FicheProduit(famille: 'desserts').erreur(), isNotNull);
      expect(const FicheProduit(rayon: 'surgeles').erreur(), isNotNull);
      expect(
          const FicheProduit(type: 'compose', ingredients: [
            Ingredient('Pain', 1, 'g', 'surgeles')
          ]).erreur(),
          isNotNull);
    });
    test('menu type : famille ou rayon inconnu refusé', () {
      for (final faux in [
        '[{"nom":"X","prixCentimes":1,"famille":"desserts"}]',
        '[{"nom":"X","prixCentimes":1,"rayon":"surgeles"}]',
        '[{"nom":"X","prixCentimes":1,"type":"compose","ingredients":[{"nom":"a","quantite":1,"unite":"g","rayon":"surgeles"}]}]',
      ]) {
        expect(() => lireMenuType(faux), throwsFormatException, reason: faux);
      }
    });
    test('les règles reprennent les mêmes listes', () {
      final regles = File('firestore.rules').readAsStringSync();
      expect(regles, contains("d.famille.matches('${famillesProduit.join('|')}')"));
      expect(regles, contains("d.rayon.matches('${rayonsCourses.join('|')}')"));
      expect(regles,
          contains("[|](${rayonsCourses.join('|')})')"));
      expect(regles, contains("x.get('rayon', 'autre').matches('${rayonsCourses.join('|')}')"));
    });
  });

  group('formulaire produit', () {
    Future<void> ouvrir(
        WidgetTester tester, void Function(Future<ProduitSaisi?>) f,
        {ProduitMenu? produit}) async {
      tester.view.physicalSize = const Size(1500, 2400);
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

    Future<void> choisir(WidgetTester tester, String liste, String option) async {
      await tester.ensureVisible(find.byKey(Key(liste)));
      await tester.tap(find.byKey(Key(liste)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(option)).last);
      await tester.pumpAndSettle();
    }

    Future<void> valider(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('valider_produit')));
      await tester.tap(find.byKey(const Key('valider_produit')));
      await tester.pumpAndSettle();
    }

    testWidgets('famille et rayon choisis, puis retrouvés à la réouverture',
        (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f);
      await tester.enterText(find.byKey(const Key('nom_produit')), 'Cola');
      await tester.enterText(find.byKey(const Key('prix_produit')), '1');
      await choisir(tester, 'famille_produit', 'famille_boissons_fraiches');
      await choisir(tester, 'rayon_produit', 'rayon_boissons');
      await valider(tester);
      final r = (await futur)!;
      expect(r.fiche.famille, 'boissons_fraiches');
      expect(r.fiche.rayon, 'boissons');

      await ouvrir(tester, (f) => futur = f,
          produit: ProduitMenu('p', 'Cola', 100, fiche: r.fiche));
      expect(find.text('Boissons fraîches'), findsOneWidget);
      await valider(tester);
      final r2 = (await futur)!;
      expect(r2.fiche.famille, 'boissons_fraiches');
      expect(r2.fiche.rayon, 'boissons');
    });

    testWidgets('produit composé : rayon de chaque ingrédient', (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f);
      await tester.enterText(find.byKey(const Key('nom_produit')), 'Croque');
      await tester.enterText(find.byKey(const Key('prix_produit')), '3');
      await choisir(tester, 'type_produit', 'type_compose');
      expect(find.byKey(const Key('rayon_produit')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('ajouter_ingredient')));
      await tester.tap(find.byKey(const Key('ajouter_ingredient')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('ingredient_nom_0')), 'Pain de mie');
      await tester.enterText(find.byKey(const Key('ingredient_qte_0')), '2');
      await choisir(tester, 'ingredient_rayon_0', 'rayon_0_boulangerie');
      await valider(tester);
      final r = (await futur)!;
      expect(r.fiche.ingredients.single.rayon, 'boulangerie');
      expect(r.fiche.famille, 'autre');
    });

    testWidgets('produit sans famille (d\'avant E1) : « Autre », sans erreur',
        (tester) async {
      late Future<ProduitSaisi?> futur;
      await ouvrir(tester, (f) => futur = f,
          produit: const ProduitMenu('f', 'Fruit', 100));
      expect(find.text('Autre'), findsWidgets);
      await valider(tester);
      final r = (await futur)!;
      expect(r.fiche.famille, 'autre');
    });
  });
}
