import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/ticket.dart';

// Calculs à la main (chantier Stock et courses, étape 5).
//
// Croque-monsieur : 2 tranches de pain de mie, 1/3 de tranche de jambon, 7 g de
// gruyère, consommation 2 par personne et par jour.
// Croque chèvre   : 2 tranches de pain de mie, 30 g de bûche de chèvre, conso 1.
// Café            : 8 verres par litre, conso 2.   Tarte : à la part, sans conso.
// Gymnase A : 80 personnes, gymnase B : 60 personnes, 2 jours.
//   croque     : 80×2×2 = 320 (A), 60×2×2 = 240 (B)  -> 560
//   pain       : 2×560 = 1120 tranches ; jambon : 560/3 = 186,67 -> 187 ; gruyère : 7×560 = 3920 g
//   café       : A 320 verres, B 240 verres -> 560 verres / 8 = 70 L
const croque = ProduitEvenement('croque', 'Croque-monsieur', 300, null,
    fiche: FicheProduit(type: 'compose', conso: 2, ingredients: [
      Ingredient('Pain de mie', 2, 'tranche'),
      Ingredient('Jambon blanc', 1 / 3, 'tranche'),
      Ingredient('Gruyère râpé', 7, 'g'),
    ]));
const chevre = ProduitEvenement('chevre', 'Croque chèvre', 350, null,
    fiche: FicheProduit(type: 'compose', conso: 1, ingredients: [
      Ingredient('pain de MIE ', 2, 'tranche'),
      Ingredient('Bûche de chèvre', 30, 'g'),
    ]));
const cafe = ProduitEvenement('cafe', 'Café', 100, null,
    fiche: FicheProduit(type: 'litre', conso: 2, verresParLitre: 8));
const tarte = ProduitEvenement('tarte', 'Tarte', 250, null,
    fiche: FicheProduit(type: 'part'));
const produits = [croque, chevre, cafe, tarte];
const gymnases = [Gymnase('a', 'Gymnase A', 80), Gymnase('b', 'Gymnase B', 60)];

Achat achat(List<Achat> l, String nom) => l.firstWhere((a) => a.nom == nom);

void main() {
  group('quantités prévues', () {
    test('personnes × jours × consommation, arrondi au-dessus', () {
      expect(quantitePrevue(personnes: 80, jours: 2, conso: 2), 320);
      expect(quantitePrevue(personnes: 60, jours: 2, conso: 2), 240);
      expect(quantitePrevue(personnes: 70, jours: 2, conso: 0.25), 35);
      expect(quantitePrevue(personnes: 7, jours: 1, conso: 0.5), 4); // 3,5
      expect(quantitePrevue(personnes: 0, jours: 2, conso: 2), 0);
    });

    test('la liste de départ : produits avec consommation, gymnases avec personnes',
        () {
      final l = listeParDefaut(produits: produits, gymnases: gymnases, jours: 2);
      // Tarte : pas de consommation, donc pas de ligne.
      expect(l.quantite('a', 'croque'), 320);
      expect(l.quantite('b', 'croque'), 240);
      expect(l.quantite('a', 'chevre'), 160);
      expect(l.quantite('b', 'chevre'), 120);
      expect(l.quantite('a', 'cafe'), 320);
      expect(l.quantite('a', 'tarte'), isNull);
      // Un gymnase sans personnes n'a aucune ligne.
      final sans = listeParDefaut(
          produits: produits, gymnases: const [Gymnase('c', 'C')], jours: 2);
      expect(sans.lignes, isEmpty);
    });
  });

  group('achats', () {
    final liste = listeParDefaut(produits: produits, gymnases: gymnases, jours: 2);
    final achats = calculerAchats(produits, liste);

    test('ingrédients additionnés d’une recette à l’autre (nom sans casse)', () {
      // Croque 560 + chèvre 280 : pain = 2×560 + 2×280 = 1680 tranches.
      expect(achat(achats, 'Pain de mie').besoin, 1680);
      expect(achat(achats, 'Pain de mie').aAcheter, 1680);
      expect(achat(achats, 'Pain de mie').uniteBase, 'tranche');
      // Jambon : 560/3 = 186,67 -> 187.
      expect(achat(achats, 'Jambon blanc').aAcheter, 187);
      // Gruyère : 7×560 = 3920 g ; chèvre : 30×280 = 8400 g.
      expect(achat(achats, 'Gruyère râpé').aAcheter, 3920);
      expect(achat(achats, 'Bûche de chèvre').aAcheter, 8400);
    });

    test('produit au litre : verres -> litres (en cl)', () {
      // 320 + 240 = 560 verres / 8 = 70 L = 7000 cl.
      final c = achat(achats, 'Café');
      expect(c.uniteBase, 'cl');
      expect(c.aAcheter, 7000);
      expect(formaterQuantite(c.aAcheter, c.uniteBase), '70 L');
    });

    test('les achats sont triés par nom', () {
      final noms = [for (final a in achats) a.nom];
      expect(noms, ['Bûche de chèvre', 'Café', 'Gruyère râpé', 'Jambon blanc', 'Pain de mie']);
    });

    test('« ce qu’il reste » réduit l’achat, sans passer sous zéro', () {
      final avecReste = liste.avec(restes: {
        achat(achats, 'Pain de mie').cle: 100,
        achat(achats, 'Jambon blanc').cle: 500,
      });
      final a = calculerAchats(produits, avecReste);
      expect(achat(a, 'Pain de mie').aAcheter, 1580);
      expect(achat(a, 'Jambon blanc').aAcheter, 0);
    });

    test('modifier une quantité recalcule les totaux', () {
      // 320 -> 300 croques à A : 540 croques ; pain = 2×540 + 560 = 1640.
      final l = liste.avecQuantite('a', 'croque', 300);
      expect(achat(calculerAchats(produits, l), 'Pain de mie').aAcheter, 1640);
      // Retirer le produit d'un gymnase le retire du calcul.
      final sans = liste.avecQuantite('a', 'croque', null);
      expect(sans.quantite('a', 'croque'), isNull);
      expect(achat(calculerAchats(produits, sans), 'Pain de mie').aAcheter,
          2 * 240 + 2 * 280);
    });

    test('produit à la part ou à l’unité : acheté tel quel', () {
      final l = liste.avecQuantite('a', 'tarte', 12).avecQuantite('b', 'tarte', 8);
      final t = achat(calculerAchats(produits, l), 'Tarte');
      expect(t.aAcheter, 20);
      expect(t.uniteBase, 'unite');
    });

    test('kg et g, L et cl s’additionnent dans l’unité de base', () {
      const sauce = ProduitEvenement('s', 'Sauce', 100, null,
          fiche: FicheProduit(type: 'compose', ingredients: [
            Ingredient('Farine', 0.5, 'kg'),
            Ingredient('farine', 250, 'g'),
            Ingredient('Lait', 1, 'L'),
            Ingredient('Lait', 25, 'cl'),
          ]));
      final a = calculerAchats(const [sauce],
          const ListeCourses(lignes: [LigneCourse('a', 's', 4)]));
      expect(achat(a, 'Farine').aAcheter, 3000); // (500 + 250) × 4
      expect(achat(a, 'Lait').aAcheter, 500); // (100 + 25) × 4
      expect(formaterQuantite(3000, 'g'), '3 kg');
      expect(formaterQuantite(500, 'cl'), '5 L');
    });
  });

  test('affichage des quantités', () {
    expect(formaterQuantite(3920, 'g'), '3,92 kg');
    expect(formaterQuantite(250, 'g'), '250 g');
    expect(formaterQuantite(1500, 'g'), '1,5 kg');
    expect(formaterQuantite(150, 'cl'), '1,5 L');
    expect(formaterQuantite(50, 'cl'), '50 cl');
    expect(formaterQuantite(1120, 'tranche'), '1 120 tranches');
    expect(formaterQuantite(1, 'tranche'), '1 tranche');
    expect(formaterQuantite(187, 'unite'), '187');
  });

  test('stock bas, épuisé ou vide : produit suggéré avec ses gymnases', () {
    final s = produitsSuggeres({
      'a': {'croque': EtatStock.bas, 'cafe': EtatStock.normal},
      'b': {'croque': EtatStock.epuise, 'tarte': EtatStock.vide},
    }, gymnases);
    expect(s, {
      'croque': ['Gymnase A', 'Gymnase B'],
      'tarte': ['Gymnase B'],
    });
  });

  test('la liste s’écrit et se relit à l’identique', () {
    const l = ListeCourses(
      lignes: [LigneCourse('a', 'croque', 300), LigneCourse('b', 'cafe', 240)],
      libres: [LigneLibre('Liquide vaisselle', 2)],
      restes: {'pain de mie|tranche': 100},
    );
    final relue = ListeCourses.depuis(l.versMap());
    expect(relue.lignes.map((x) => (x.gymnaseId, x.produitId, x.quantite)),
        [('a', 'croque', 300), ('b', 'cafe', 240)]);
    expect(relue.libres.single.nom, 'Liquide vaisselle');
    expect(relue.libres.single.quantite, 2);
    expect(relue.restes, {'pain de mie|tranche': 100});
    expect(l.versMap()['statut'], 'preparation');
  });
}
