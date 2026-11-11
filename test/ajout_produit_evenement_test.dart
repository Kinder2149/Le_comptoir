import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/ticket.dart' show formaterEuros;

// Mission « Prêt pour le tournoi », T4 (décision 78) : « Ajouter un produit » dans
// « Produits et images ». La liste est testée seule ; l'écriture dans l'événement et le
// menu est prouvée par le parcours sur émulateur (integration_test/ajout_produit_test.dart)
// et les règles par tests_regles/ajout_produit.test.mjs.

const _p1 = ProduitEvenement('p1', 'Croque-monsieur', 300, null);
const _p2 = ProduitEvenement('p2', 'Café', 150, null);

Widget _liste({required bool modifiable, VoidCallback? onAjouter}) => MaterialApp(
      home: Scaffold(
        body: ListeProduitsEvenement(
          produits: const [_p1, _p2],
          modifiable: modifiable,
          onAjouter: onAjouter ?? () {},
          onImage: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('en préparation et en cours (modifiable) : le bouton est là et se touche',
      (tester) async {
    var appels = 0;
    await tester.pumpWidget(_liste(modifiable: true, onAjouter: () => appels++));
    expect(find.byKey(const Key('ajouter_produit_evenement')), findsOneWidget);
    expect(find.text('Ajouter un produit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ajouter_produit_evenement')));
    expect(appels, 1);
  });

  testWidgets('événement clôturé : pas de bouton, la liste se lit seulement',
      (tester) async {
    await tester.pumpWidget(_liste(modifiable: false));
    expect(find.byKey(const Key('ajouter_produit_evenement')), findsNothing);
    expect(find.text('Ajouter un produit'), findsNothing);
    expect(find.textContaining('clôturé'), findsOneWidget);
  });

  testWidgets('les produits existants gardent nom et prix affichés', (tester) async {
    await tester.pumpWidget(_liste(modifiable: true));
    expect(find.text('Croque-monsieur'), findsOneWidget);
    expect(find.textContaining(formaterEuros(300)), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.textContaining(formaterEuros(150)), findsOneWidget);
  });

  test('un événement en préparation ou en cours est modifiable, un clôturé non', () {
    Evenement ev(String statut) => Evenement(
        id: 'e', nom: 'T', date: '2026-11-11', statut: statut, modes: const [], menuNom: 'M');
    expect(ev('en_preparation').cloture, isFalse);
    expect(ev('en_cours').cloture, isFalse);
    expect(ev('cloture').cloture, isTrue);
  });

  test('la fiche d\'un produit ajouté suit la même validation que celle du menu', () {
    expect(const FicheProduit().erreur(), isNull);
    expect(const FicheProduit(famille: 'inconnue').erreur(), isNotNull);
    expect(const FicheProduit(type: 'litre').erreur(), isNotNull); // verres par litre manquant
    expect(cleIngredient('  Brownie '), cleIngredient('brownie')); // même nom = doublon refusé
  });
}
