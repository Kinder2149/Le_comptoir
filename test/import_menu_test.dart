import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/import_menu.dart';

import 'classeur_aides.dart';

// Mission « Préparer l'événement », étape P7 : importer un menu depuis la feuille Menu.
// Logique pure : le plan d'import (produits à créer, lignes ignorées avec raison,
// doublons, limite de 200 produits). Colonnes : Produit, Prix, Type, Provenance,
// Verres par litre, Parts par gâteau, Recette, Consommation.
List<Object?> _ligne(String nom, Object? prix,
        {String? type, String? prov, Object? verres, Object? parts, String? recette, Object? conso}) =>
    [nom, prix, type, prov, verres, parts, recette, conso];

PlanMenu _plan(List<List<Object?>> menu) =>
    preparerMenu(lireClasseur(classeurDeTest(menu: menu)));

void main() {
  group('critère 1 : types, prix, recettes, ratios et consommations conservés', () {
    final plan = _plan([
      _ligne('Croque-monsieur', 3.5,
          type: 'Composé (recette)',
          recette: '2 tranche Pain de mie ; 0,25 tranche Jambon ; 25 g Gruyère',
          conso: 2),
      _ligne('Café', 1, type: 'Au litre', verres: 8, conso: 1.5),
      _ligne('Tarte', 2.5,
          type: 'À la part', prov: 'Apporté par les bénévoles', parts: 8, conso: 0.75),
      _ligne('Barre', 0.8, type: 'À l\'unité'),
    ]);

    test('quatre produits à créer, rien d\'ignoré', () {
      expect(plan.vide, isFalse);
      expect(plan.produits.length, 4);
      expect(plan.ignorees, isEmpty);
      expect(plan.erreurs, isEmpty);
      expect(plan.phraseMenu, 'Menu à créer : 4 produits');
    });

    test('le composé garde sa recette et sa consommation', () {
      final p = plan.produits.firstWhere((p) => p.nom == 'Croque-monsieur');
      expect(p.prixCentimes, 350);
      expect(p.fiche.type, 'compose');
      expect(p.fiche.conso, 2);
      expect(p.fiche.ingredients, const [
        Ingredient('Pain de mie', 2, 'tranche'),
        Ingredient('Jambon', 0.25, 'tranche'),
        Ingredient('Gruyère', 25, 'g'),
      ]);
    });

    test('le litre, la part (apportée) et l\'unité gardent leurs ratios', () {
      final cafe = plan.produits.firstWhere((p) => p.nom == 'Café');
      expect(cafe.fiche.type, 'litre');
      expect(cafe.fiche.verresParLitre, 8);
      expect(cafe.fiche.conso, 1.5);
      final tarte = plan.produits.firstWhere((p) => p.nom == 'Tarte');
      expect(tarte.fiche.type, 'part');
      expect(tarte.fiche.partsParEntier, 8);
      expect(tarte.fiche.provenance, 'apporte');
      expect(tarte.fiche.conso, 0.75);
      final barre = plan.produits.firstWhere((p) => p.nom == 'Barre');
      expect(barre.prixCentimes, 80);
      expect(barre.fiche.type, 'unite');
      expect(barre.fiche.conso, isNull);
    });

    test('les produits à écrire (dépôt) sont les mêmes, sans icône', () {
      final a = plan.aCreer;
      expect(a.map((p) => p.nom), ['Croque-monsieur', 'Café', 'Tarte', 'Barre']);
      expect(a.every((p) => p.icone == null), isTrue);
      expect(a.first.prixCentimes, 350);
    });

    test('un seul produit : « 1 produit » au singulier', () {
      expect(_plan([_ligne('Fruit', 0.5)]).phraseMenu, 'Menu à créer : 1 produit');
    });
  });

  group('critère 2 : une ligne invalide est listée et ignorée', () {
    final plan = _plan([
      _ligne('Soda', 1),
      _ligne('Gratuit négatif', -2),
      _ligne('Mystère', 1, type: 'Fantaisie'),
      _ligne('Fruit', 0.5),
    ]);

    test('prix négatif et type inconnu sont listés avec leur raison', () {
      expect(plan.ignorees.length, 2);
      expect(plan.ignorees[0], contains('ligne 4'));
      expect(plan.ignorees[0], contains('prix'));
      expect(plan.ignorees[1], contains('ligne 5'));
      expect(plan.ignorees[1], contains('type inconnu'));
    });

    test('le reste est créé', () {
      expect(plan.produits.map((p) => p.nom), ['Soda', 'Fruit']);
      expect(plan.vide, isFalse);
    });

    test('une recette cassée est ignorée aussi', () {
      final p = _plan([
        _ligne('Cassé', 2, type: 'Composé (recette)', recette: 'beaucoup de sel'),
        _ligne('Bon', 1),
      ]);
      expect(p.produits.map((x) => x.nom), ['Bon']);
      expect(p.ignorees.single, contains('ligne 3'));
    });
  });

  group('doublons, limite et fichier vide', () {
    test('un nom en double (sans casse ni accents) : le premier est gardé', () {
      final p = _plan([
        _ligne('Café', 1),
        _ligne('cafe', 2),
        _ligne('Thé', 1),
      ]);
      expect(p.produits.map((x) => x.nom), ['Café', 'Thé']);
      expect(p.produits.first.prixCentimes, 100);
      expect(p.ignorees.single, contains('doublon'));
      expect(p.ignorees.single, contains('cafe'));
    });

    test('200 produits passent, 201 sont refusés sans rien créer', () {
      List<List<Object?>> n(int k) => [for (var i = 0; i < k; i++) _ligne('P$i', 1)];
      final ok = _plan(n(200));
      expect(ok.produits.length, 200);
      expect(ok.tropGrand, isFalse);
      final trop = _plan(n(201));
      expect(trop.tropGrand, isTrue);
      expect(trop.vide, isTrue);
      expect(trop.produits, isEmpty);
      expect(trop.messageVide, messageMenuTropGrand);
    });

    test('feuille Menu sans aucune ligne valide : message clair, jamais de menu vide', () {
      final vide = _plan(const []);
      expect(vide.vide, isTrue);
      expect(vide.messageVide, messageMenuIllisible);
      final toutInvalide = _plan([_ligne('Mauvais', -1)]);
      expect(toutInvalide.vide, isTrue);
      expect(toutInvalide.ignorees.length, 1);
    });

    test('les problèmes des autres feuilles ne concernent pas le menu', () {
      final p = _plan([
        _ligne('Soda', 1),
      ]);
      // La feuille Stock ou Historique n'est pas lue ici : aucune erreur ne remonte.
      expect(p.erreurs, isEmpty);
    });

    test('un classeur d\'un autre format n\'a pas de feuille Menu : rien à créer', () {
      final p = preparerMenu(lireClasseur(classeurAutreFormat()));
      expect(p.vide, isTrue);
      expect(p.erreurs, isNotEmpty);
    });

    test('des octets quelconques sont illisibles', () {
      expect(() => lireClasseur([1, 2, 3]), throwsA(isA<ClasseurIllisible>()));
    });
  });
}
