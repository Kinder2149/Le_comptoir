import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';

// Mission « Retours du terrain », étape F5 (décision 72) : les classeurs de l'écran
// « Extraction et modèle », relus avec lireClasseur. Logique pure.

const _menu = [
  ProduitEvenement('croque', 'Croque-monsieur', 300, null,
      fiche: FicheProduit(
        type: 'compose',
        conso: 2,
        famille: 'croques',
        ingredients: [
          Ingredient('Pain de mie', 2, 'tranche', 'boulangerie'),
          Ingredient('Gruyère râpé', 25, 'g', 'frais'),
        ],
      )),
  ProduitEvenement('cola', 'Cola', 200, null,
      fiche: FicheProduit(
          type: 'litre',
          verresParLitre: 4,
          conso: 1,
          famille: 'boissons_fraiches',
          rayon: 'boissons')),
];

void main() {
  group('Données de l\'association (menu, recettes, prévision)', () {
    test('le classeur relit le menu, la prévision et la composition', () {
      final lu = lireClasseur(construireDonneesMenu(produits: _menu));
      // Seules les feuilles absentes par conception (Stock, Historique) sont signalées.
      expect(lu.erreurs.where((e) => !e.contains('introuvable')), isEmpty);
      expect(lu.produits.map((p) => p.nom), ['Croque-monsieur', 'Cola']);
      expect(lu.produits.map((p) => p.prixCentimes), [300, 200]);
      // La prévision du menu : la consommation par personne et par jour.
      expect(lu.produits[0].fiche.conso, 2);
      expect(lu.produits[1].fiche.conso, 1);
      // La composition du croque : ses deux ingrédients, avec leurs quantités.
      final ingredients = lu.produits[0].fiche.ingredients;
      expect(ingredients.map((i) => i.nom), ['Pain de mie', 'Gruyère râpé']);
      expect(ingredients.map((i) => i.quantite), [2, 25]);
    });

    test('pas de stock ni de ventes dans ce classeur', () {
      final lu = lireClasseur(construireDonneesMenu(produits: _menu));
      expect(lu.stocks, isEmpty);
      expect(lu.historique, isEmpty);
    });
  });

  group('Modèle vierge', () {
    late List<ProduitEvenement> produits;

    setUp(() {
      final json = File('assets/menu_type.json').readAsStringSync();
      final modele = lireMenuType(json);
      produits = [
        for (final (i, p) in modele.indexed)
          ProduitEvenement('modele_$i', p.nom, p.prixCentimes, null,
              icone: p.icone, fiche: p.fiche),
      ];
    });

    test('le modèle relit tous les produits du modèle générique', () {
      final lu = lireClasseur(
          construireModele(produits: produits, gymnases: const [], stocks: const {}));
      expect(lu.erreurs, isEmpty);
      expect(lu.produits.map((p) => p.nom), produits.map((p) => p.nom));
    });

    test('aucun nom de marque connue dans le modèle vierge', () {
      final lu = lireClasseur(
          construireModele(produits: produits, gymnases: const [], stocks: const {}));
      const marques = ['coca', 'fanta', 'ice tea', 'oasis', 'mars', 'twix', 'snickers'];
      for (final p in lu.produits) {
        final nom = p.nom.toLowerCase();
        for (final m in marques) {
          expect(nom.contains(m), isFalse, reason: '« ${p.nom} » contient « $m »');
        }
      }
    });
  });
}
