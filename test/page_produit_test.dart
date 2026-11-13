import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_menu.dart';

// Mission « Calcul du club », V8 : la page de l'article en cinq cartes (décision 90).

const _croque = FicheProduit(type: 'compose', ingredients: [
  Ingredient('Pain de mie', 2, 'tranche'),
  Ingredient('Jambon', 0.25, 'tranche'),
  Ingredient('Gruyère', 25, 'g'),
]);

void main() {
  Future<void> ouvrir(
    WidgetTester tester,
    void Function(Future<ProduitSaisi?>) f, {
    ProduitMenu? produit,
    double largeur = 1500,
  }) async {
    tester.view.physicalSize = Size(largeur, largeur >= 1000 ? 2400 : 800);
    tester.view.devicePixelRatio = largeur >= 1000 ? 2.5 : 1;
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

  Future<void> saisir(WidgetTester tester, String cle, String texte) async {
    await tester.ensureVisible(find.byKey(Key(cle)));
    await tester.enterText(find.byKey(Key(cle)), texte);
    await tester.pump();
  }

  Future<void> toucher(WidgetTester tester, String cle) async {
    await tester.ensureVisible(find.byKey(Key(cle)));
    await tester.tap(find.byKey(Key(cle)));
    await tester.pumpAndSettle();
  }

  testWidgets('la saisie est une page entière, pas une boîte de dialogue',
      (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f);
    expect(find.byType(PageProduit), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Nouveau produit'), findsOneWidget);
    futur.ignore();
  });

  testWidgets('cinq cartes, dans l\'ordre, avec leur titre', (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f);
    const cartes = {
      'carte_identite': 'Identité',
      'carte_mesure': 'Mesure',
      'carte_composition': 'Composition',
      'carte_provenance': 'Provenance et rayon',
      'carte_consommation': 'Consommation habituelle',
    };
    final hauteurs = <double>[];
    for (final e in cartes.entries) {
      expect(find.byKey(Key(e.key)), findsOneWidget, reason: e.key);
      expect(find.descendant(of: find.byKey(Key(e.key)), matching: find.text(e.value)),
          findsOneWidget,
          reason: e.value);
      hauteurs.add(tester.getTopLeft(find.byKey(Key(e.key))).dy);
    }
    expect(hauteurs, [...hauteurs]..sort());
    // Identité : nom, prix, famille.
    for (final cle in ['nom_produit', 'prix_produit', 'famille_produit']) {
      expect(find.descendant(
              of: find.byKey(const Key('carte_identite')), matching: find.byKey(Key(cle))),
          findsOneWidget,
          reason: cle);
    }
    // Consommation : la mention « sert quand les repas ne sont pas détaillés ».
    expect(find.text('Sert quand les repas ne sont pas détaillés.'), findsOneWidget);
    futur.ignore();
  });

  testWidgets('litre : la conversion est écrite en clair', (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f);
    await toucher(tester, 'type_produit');
    await toucher(tester, 'type_litre');
    await saisir(tester, 'verres_par_litre', '4');
    expect(find.byKey(const Key('conversion_litre')), findsOneWidget);
    expect(find.text('1 litre = 4 verres'), findsOneWidget);
    futur.ignore();
  });

  testWidgets('produit existant : Enregistrer principal, Supprimer en brique avec confirmation',
      (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f,
        produit: const ProduitMenu('p1', 'Croque-monsieur', 300, fiche: _croque));
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.byKey(const Key('valider_produit')), findsOneWidget);
    expect(find.byKey(const Key('supprimer_produit')), findsOneWidget);

    // Annuler la suppression : on reste sur la page, rien n'est supprimé.
    await toucher(tester, 'supprimer_produit');
    expect(find.text('Supprimer ce produit ?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Annuler')));
    await tester.pumpAndSettle();
    expect(find.byType(PageProduit), findsOneWidget);

    // Confirmer : la page renvoie une demande de suppression.
    await toucher(tester, 'supprimer_produit');
    await toucher(tester, 'confirmer_suppression_produit');
    final r = await futur;
    expect(r?.supprimer, isTrue);
  });

  testWidgets('nouveau produit : pas de bouton Supprimer', (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f);
    expect(find.byKey(const Key('supprimer_produit')), findsNothing);
    futur.ignore();
  });

  testWidgets('téléphone 360 px : croque-monsieur à 3 ingrédients, sans chevauchement',
      (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f,
        largeur: 360,
        produit: const ProduitMenu('p1', 'Croque-monsieur', 300, fiche: _croque));
    expect(tester.takeException(), isNull);

    const champs = [
      'ingredient_nom_0',
      'ingredient_qte_0',
      'ingredient_unite_0',
      'ingredient_rayon_0',
      'retirer_ingredient_0',
      'ingredient_nom_2',
      'ingredient_qte_2',
      'ingredient_unite_2',
      'ingredient_rayon_2',
    ];
    final rects = {
      for (final c in champs) c: tester.getRect(find.byKey(Key(c))),
    };
    for (final e in rects.entries) {
      expect(e.value.left, greaterThanOrEqualTo(0), reason: e.key);
      expect(e.value.right, lessThanOrEqualTo(360), reason: e.key);
    }
    for (var i = 0; i < champs.length; i++) {
      for (var j = i + 1; j < champs.length; j++) {
        final a = rects[champs[i]]!;
        final b = rects[champs[j]]!;
        expect(a.overlaps(b), isFalse, reason: '${champs[i]} chevauche ${champs[j]}');
      }
    }
    // Les pages entières défilent : aucune erreur de mise en page.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    futur.ignore();
  });

  testWidgets('mêmes données enregistrées qu\'avant', (tester) async {
    late Future<ProduitSaisi?> futur;
    await ouvrir(tester, (f) => futur = f);
    await saisir(tester, 'nom_produit', 'Cidre');
    await saisir(tester, 'prix_produit', '2,50');
    await toucher(tester, 'type_produit');
    await toucher(tester, 'type_litre');
    await saisir(tester, 'verres_par_litre', '4');
    await toucher(tester, 'valider_produit');
    final r = await futur;
    expect(r, isNotNull);
    expect(r!.nom, 'Cidre');
    expect(r.prixCentimes, 250);
    expect(r.fiche.type, 'litre');
    expect(r.fiche.verresParLitre, 4);
    expect(r.supprimer, isFalse);
  });
}
