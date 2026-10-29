import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';

import 'outils.dart';

// Un vrai PNG de 1 pixel, utilisé comme photo de produit.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> attendreProduits(
      WidgetTester tester, DepotMenus menus, String menuId, int n) async {
    for (var i = 0;
        i < 100 && (await menus.suivreProduits(menuId).first).length < n;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('menus : partir du modèle, copier un menu existant', (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await auth.signOut();
    await ouvrir(tester, 'chef', fauxGoogle('chef_copie_menu'));
    await creerAssociationParLInterface(tester);
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final menus = DepotAssociations(db).menus(assoId);

    // --- Un menu source, avec recette, ratio, provenance et photo.
    final source = await menus.creerMenu('Menu source');
    await menus.ajouterProduit(source,
        nom: 'Croque',
        prixCentimes: 300,
        icone: 'croque',
        photo: _png,
        fiche: const FicheProduit(type: 'compose', conso: 2, ingredients: [
          Ingredient('Pain de mie', 2, 'tranche'),
          Ingredient('Gruyère', 7, 'g'),
        ]));
    await menus.ajouterProduit(source,
        nom: 'Café',
        prixCentimes: 100,
        fiche: const FicheProduit(
            type: 'litre', verresParLitre: 8, provenance: 'apporte'));

    // --- Nouveau menu : copie du menu source.
    await attendre(tester, find.byKey(const Key('menus')));
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.text('Menu source'));
    await toucher(tester, find.byKey(const Key('nouveau_menu')));
    await attendre(tester, find.byKey(const Key('copie_menu')));
    await tester.enterText(find.byKey(const Key('nom_menu')), 'Copie du menu');
    await toucher(tester, find.byKey(const Key('copie_menu')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(Key('copie_$source')).last);
    await tester.pump(const Duration(seconds: 1));
    await toucher(tester, find.byKey(const Key('valider_nom')));
    await attendre(tester, find.text('Copie du menu'));
    final copie = (await menus.suivreMenus().first).firstWhere((m) => m.nom == 'Copie du menu');
    await attendreProduits(tester, menus, copie.id, 2);
    var produits = {for (final p in await menus.suivreProduits(copie.id).first) p.nom: p};
    expect(produits.length, 2);
    final croque = produits['Croque']!;
    expect(croque.prixCentimes, 300);
    // La copie ne reprend aucun stock (le menu n'en a plus) mais garde la provenance.
    expect(croque.fiche.provenance, 'achete');
    expect(croque.photo, isNotNull);
    expect(croque.icone, 'croque');
    expect(croque.fiche.type, 'compose');
    expect(croque.fiche.conso, 2);
    expect(croque.fiche.ingredients.length, 2);
    expect(produits['Café']!.fiche.verresParLitre, 8);
    expect(produits['Café']!.fiche.provenance, 'apporte');
    // Les deux menus sont indépendants : modifier la copie ne change pas la source.
    await menus.modifierProduit(copie.id, croque.id,
        nom: 'Croque', prixCentimes: 350, icone: 'croque', photo: _png, fiche: croque.fiche);
    final sourceApres = await menus.suivreProduits(source).first;
    expect(sourceApres.firstWhere((p) => p.nom == 'Croque').prixCentimes, 300);

    // --- Nouveau menu : à partir du modèle (recettes, ratios, consommations).
    await toucher(tester, find.byKey(const Key('nouveau_menu')));
    await attendre(tester, find.byKey(const Key('menu_type')));
    await tester.enterText(find.byKey(const Key('nom_menu')), 'Menu du modèle');
    await toucher(tester, find.byKey(const Key('menu_type')));
    await toucher(tester, find.byKey(const Key('valider_nom')));
    await attendre(tester, find.text('Menu du modèle'));
    final modele = (await menus.suivreMenus().first).firstWhere((m) => m.nom == 'Menu du modèle');
    await attendreProduits(tester, menus, modele.id, 13);
    produits = {for (final p in await menus.suivreProduits(modele.id).first) p.nom: p};
    expect(produits.length, 13);
    final c = produits['Croque-monsieur']!;
    expect(c.fiche.type, 'compose');
    expect(c.fiche.conso, 2);
    expect(c.fiche.ingredients.map((i) => i.nom), ['Pain de mie', 'Jambon blanc', 'Gruyère râpé']);
    expect(produits['Café']!.fiche.verresParLitre, 8);
    expect(produits['Café']!.fiche.provenance, 'apporte');
    expect(produits['Tartiflette']!.fiche.type, 'part');
    expect(produits['Bonbons (offerts)']!.prixCentimes, 0);
    expect(produits['Tarte']!.icone, 'tarte');
    // Le modèle d'origine n'a pas bougé : le menu copié du modèle est indépendant.
    await menus.modifierProduit(modele.id, c.id,
        nom: 'Croque-monsieur', prixCentimes: 999, icone: 'croque', fiche: c.fiche);
    final autre = await menus.suivreProduits(copie.id).first;
    expect(autre.any((p) => p.prixCentimes == 999), isFalse);
    final json = await rootBundle.loadString('assets/menu_type.json');
    expect(lireMenuType(json).firstWhere((p) => p.nom == 'Croque-monsieur').prixCentimes, 300);
  });
}
