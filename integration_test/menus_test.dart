import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'outils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saisir(WidgetTester tester, String cle, String valeur) =>
      tester.enterText(find.byKey(Key(cle)), valeur);

  Future<void> ajouterProduit(
    WidgetTester tester,
    String nom,
    String prix, {
    String? stock,
  }) async {
    await toucher(tester, find.byKey(const Key('nouveau_produit')));
    await saisir(tester, 'nom_produit', nom);
    await saisir(tester, 'prix_produit', prix);
    if (stock != null) {
      await toucher(tester, find.byKey(const Key('suivi_stock')));
      await saisir(tester, 'quantite_stock', stock);
    }
    await toucher(tester, find.byKey(const Key('valider_produit')));
  }

  testWidgets('menus : créer, remplir, modifier, retrouver, supprimer',
      (tester) async {
    await FirebaseAuth.instance.signOut();
    await ouvrir(tester, 'responsable', fauxGoogle('chef_menus'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');

    // --- Aucun menu au départ.
    await attendre(tester, find.byKey(const Key('menus')));
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.byKey(const Key('aucun_menu')));

    // --- Création d'un menu.
    await toucher(tester, find.byKey(const Key('nouveau_menu')));
    await saisir(tester, 'nom_menu', 'Menu Tournoi');
    await toucher(tester, find.byKey(const Key('valider_nom')));
    await attendre(tester, find.text('Menu Tournoi'));
    await toucher(tester, find.text('Menu Tournoi'));
    await attendre(tester, find.byKey(const Key('aucun_produit')));

    // --- Produits : avec stock, sans stock.
    await ajouterProduit(tester, 'Croque-monsieur', '3', stock: '20');
    await attendre(tester, find.text('3,00 € · Stock : 20'));
    await ajouterProduit(tester, 'Café', '1,5');
    await attendre(tester, find.text('1,50 €'));
    expect(find.text('Croque-monsieur'), findsOneWidget);

    // --- Prix invalide : refusé avec un message, rien n'est créé.
    await toucher(tester, find.byKey(const Key('nouveau_produit')));
    await saisir(tester, 'nom_produit', 'Raté');
    await saisir(tester, 'prix_produit', 'abc');
    await toucher(tester, find.byKey(const Key('valider_produit')));
    expect(texte(tester, 'erreur_produit'), 'Prix invalide (exemple : 2,50).');
    await toucher(tester, find.text('Annuler'));
    await tester.pump(const Duration(seconds: 1)); // fin de l'animation de fermeture
    expect(find.text('Raté'), findsNothing);

    // --- Modifier : nouveau prix, fin du suivi du stock.
    await toucher(tester, find.text('Croque-monsieur'));
    await saisir(tester, 'prix_produit', '3,5');
    await toucher(tester, find.byKey(const Key('suivi_stock')));
    await toucher(tester, find.byKey(const Key('valider_produit')));
    await attendre(tester, find.text('3,50 €'));
    expect(find.textContaining('Stock'), findsNothing);

    // --- Supprimer un produit.
    await toucher(tester, find.text('Café'));
    await toucher(tester, find.byKey(const Key('supprimer_produit')));
    for (var i = 0; i < 100 && find.text('Café').evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Café'), findsNothing);

    // --- Renommer le menu.
    await toucher(tester, find.byKey(const Key('renommer_menu')));
    await saisir(tester, 'nom_menu', 'Menu Final');
    await toucher(tester, find.byKey(const Key('valider_nom')));
    await attendre(tester, find.text('Menu Final'));

    // --- Rouvrir l'application : tout est retrouvé.
    await ouvrir(tester, 'reouverture', fauxGoogle('chef_menus'));
    await attendre(tester, find.byKey(const Key('menus')));
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.text('Menu Final'));
    await toucher(tester, find.text('Menu Final'));
    await attendre(tester, find.text('3,50 €'));
    expect(find.text('Croque-monsieur'), findsOneWidget);

    // --- Supprimer le menu : retour à la liste vide.
    await toucher(tester, find.byKey(const Key('supprimer_menu')));
    await toucher(tester, find.byKey(const Key('confirmer_suppression')));
    await attendre(tester, find.byKey(const Key('aucun_menu')));

    // --- Un bénévole n'a pas accès aux menus.
    await FirebaseAuth.instance.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await saisir(tester, 'code_saisi', code);
    await saisir(tester, 'prenom_rejoindre', 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.byKey(const Key('code')));
    await attendre(tester, find.text('Membres (2)'));
    expect(find.byKey(const Key('menus')), findsNothing);
  });
}
