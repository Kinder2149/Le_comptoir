import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';

// Mission « Ergonomie de la gestion », étape E6 : courses par rayons et cases partagées.
List<ProduitModele> modele() =>
    lireMenuType(File('assets/menu_type.json').readAsStringSync());

const _croque = ProduitEvenement('croque', 'Croque', 300, null,
    fiche: FicheProduit(type: 'compose', conso: 2, ingredients: [
      Ingredient('Pain de mie', 2, 'tranche', 'boulangerie'),
      Ingredient('Gruyère râpé', 7, 'g', 'frais'),
    ]));
const _cafe = ProduitEvenement('cafe', 'Café', 100, null,
    fiche: FicheProduit(
        type: 'litre', conso: 2, verresParLitre: 8, rayon: 'boissons'));
const _produits = [_croque, _cafe];

void main() {
  group('rayons (critère 1)', () {
    test('Pain de mie sous Boulangerie, Café sous Boissons (menu type)', () {
      final m = modele();
      final cafe = m.firstWhere((p) => p.nom == 'Café');
      expect(cafe.fiche.rayon, 'boissons');
      final pain = [
        for (final p in m)
          for (final i in p.fiche.ingredients)
            if (i.cle == cleIngredient('Pain de mie')) i.rayon,
      ];
      expect(pain, isNotEmpty);
      expect(pain.every((r) => r == 'boulangerie'), isTrue);
    });

    test('un achat prend le rayon de son ingrédient ou de son produit', () {
      const liste = ListeCourses(lignes: [
        LigneCourse('a', 'croque', 10),
        LigneCourse('a', 'cafe', 8),
      ]);
      final achats = calculerAchats(_produits, liste);
      expect(achats.firstWhere((a) => a.nom == 'Pain de mie').rayon, 'boulangerie');
      expect(achats.firstWhere((a) => a.nom == 'Gruyère râpé').rayon, 'frais');
      expect(achats.firstWhere((a) => a.nom == 'Café').rayon, 'boissons');
    });
  });

  group('texte partagé rangé par rayons (critère 5)', () {
    test('une section par rayon, dans l’ordre fixe, rayons vides absents', () {
      const liste = ListeCourses(
        lignes: [LigneCourse('a', 'croque', 10), LigneCourse('a', 'cafe', 8)],
        libres: [
          LigneLibre('Liquide vaisselle', 2, 'entretien'),
          LigneLibre('Papier', 1),
        ],
      );
      expect(
        texteListeCourses('Liste de courses', calculerAchats(_produits, liste), liste.libres),
        'Liste de courses\n\nBoulangerie\n- Pain de mie : 20 tranches\n'
        '\nFrais et crèmerie\n- Gruyère râpé : 70 g\n'
        '\nBoissons\n- Café : 1 L\n'
        '\nEntretien et matériel\n- Liquide vaisselle × 2\n'
        '\nAutre\n- Papier × 1\n',
      );
    });

    test('rien à acheter', () {
      expect(texteListeCourses('T', const [], const []), 'T\n\nRien à acheter\n');
    });
  });

  group('cases partagées (critère 2, côté données)', () {
    test('les cases et les articles se lisent et se réécrivent sans rien perdre', () {
      final d = {
        'statut': 'preparation',
        'lignes': <Map<String, dynamic>>[],
        'libres': <Map<String, dynamic>>[],
        'restes': <Map<String, dynamic>>[],
        'articles': ['p:cafe', 'l:Papier'],
        'coches': {'p:cafe': true},
      };
      // Deux lectures du même flux donnent les mêmes cases (deux téléphones).
      final telephoneA = ListeCourses.depuis(d);
      final telephoneB = ListeCourses.depuis(d);
      expect(telephoneA.coches, {'p:cafe'});
      expect(telephoneB.coches, telephoneA.coches);
      expect(telephoneA.articles, ['p:cafe', 'l:Papier']);
      // L'écriture de la liste n'envoie pas les cases : elles sont cochées à part.
      expect(telephoneA.versMap().containsKey('coches'), isFalse);
      expect(telephoneA.versMap().containsKey('articles'), isFalse);
    });

    test('une case n’entre pas dans le stock ni dans le coût', () {
      final l = const ListeCourses(lignes: [LigneCourse('a', 'cafe', 8)])
          .avec(coches: {'p:cafe'});
      expect(l.coches, {'p:cafe'});
      expect(l.coutTotalCentimes, 0);
      expect(l.validee, isFalse);
    });
  });

  group('clés d’articles', () {
    test('achats d’abord, puis lignes libres ; doublon numéroté', () {
      const liste = ListeCourses(lignes: [
        LigneCourse('a', 'croque', 10),
        LigneCourse('a', 'cafe', 8),
      ]);
      final achats = calculerAchats(_produits, liste);
      final libres = [
        const LigneLibre('Liquide vaisselle', 2, 'entretien'),
        const LigneLibre('Liquide vaisselle', 1, 'entretien'),
      ];
      expect(clesArticles(achats, libres), [
        'p:cafe',
        'i:gruyere rape|g',
        'i:pain de mie|tranche',
        'l:Liquide vaisselle',
        'l:Liquide vaisselle#2',
      ]);
    });

    test('un ingrédient garde la clé de son achat, un produit « p: »', () {
      const liste = ListeCourses(lignes: [LigneCourse('a', 'croque', 10)]);
      final usages = usagesAchats(_produits, liste);
      expect(usages['i:pain de mie|tranche'], ['Croque']);
      expect(usages.containsKey('p:cafe'), isFalse);
    });
  });
}
