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

    test('gâteau avec parts par gâteau : gâteaux entiers, arrondis au-dessus (B2)', () {
      const flan = ProduitEvenement('flan', 'Flan', 200, null,
          fiche: FicheProduit(type: 'part', partsParEntier: 8));
      // 12 + 8 = 20 parts / 8 = 2,5 -> 3 gâteaux.
      final l = const ListeCourses(
          lignes: [LigneCourse('a', 'flan', 12), LigneCourse('b', 'flan', 8)]);
      final f = achat(calculerAchats(const [flan], l), 'Flan');
      expect(f.aAcheter, 3);
      expect(f.uniteBase, 'gateau');
      expect(formaterQuantite(3, 'gateau'), '3 gâteaux');
      expect(formaterQuantite(1, 'gateau'), '1 gâteau');
      // « Il reste » 1 gâteau : 2 à acheter.
      final avecReste = l.avec(restes: {f.cle: 1});
      expect(achat(calculerAchats(const [flan], avecReste), 'Flan').aAcheter, 2);
    });

    test('gâteau sans parts par gâteau : acheté tel quel, comme avant (B2)', () {
      const sans = ProduitEvenement('t', 'Tarte', 200, null,
          fiche: FicheProduit(type: 'part'));
      final t = achat(
          calculerAchats(const [sans], const ListeCourses(lignes: [LigneCourse('a', 't', 5)])),
          'Tarte');
      expect((t.aAcheter, t.uniteBase), (5, 'unite'));
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

  group('calcul inverse (validation)', () {
    Map<String, int> par(List<RendementProduit> r, String id) =>
        r.firstWhere((x) => x.produitId == id).parGymnase;
    RendementProduit de(List<RendementProduit> r, String id) =>
        r.firstWhere((x) => x.produitId == id);

    test('tout acheté comme proposé : le stock gagne exactement les quantités prévues',
        () {
      final liste = listeParDefaut(produits: produits, gymnases: gymnases, jours: 2);
      final r = calculerRendements(produits, liste, const {});
      expect(par(r, 'croque'), {'a': 320, 'b': 240});
      expect(par(r, 'chevre'), {'a': 160, 'b': 120});
      expect(par(r, 'cafe'), {'a': 320, 'b': 240});
      expect(de(r, 'croque').limitant, isNull);
    });

    test('gâteaux entiers achetés : le stock gagne gâteaux × parts, au prorata (B2)', () {
      const flan = ProduitEvenement('flan', 'Flan', 200, null,
          fiche: FicheProduit(type: 'part', partsParEntier: 8));
      const liste = ListeCourses(
          lignes: [LigneCourse('a', 'flan', 12), LigneCourse('b', 'flan', 8)]);
      // Tout acheté comme proposé : 3 gâteaux = 24 parts (A 14,4 -> 14 + B 9,6 -> 10).
      final r = calculerRendements(const [flan], liste, const {});
      expect(de(r, 'flan').total, 24);
      expect(par(r, 'flan').values.fold<int>(0, (a, b) => a + b), 24);
      expect(par(r, 'flan'), {'a': 14, 'b': 10});
      // 2 gâteaux seulement : 16 parts.
      final cle = calculerAchats(const [flan], liste).first.cle;
      final deux = calculerRendements(const [flan], liste, {cle: 2});
      expect(de(deux, 'flan').total, 16);
    });

    test('l’ingrédient limitant décide : moitié du gruyère, moitié des croques', () {
      // 300 + 240 = 540 croques -> 3780 g de gruyère ; on en achète 1890 g.
      const liste = ListeCourses(
          lignes: [LigneCourse('a', 'croque', 300), LigneCourse('b', 'croque', 240)]);
      final gruyere = calculerAchats(produits, liste).firstWhere((a) => a.nom == 'Gruyère râpé');
      expect(gruyere.aAcheter, 3780);
      final r = calculerRendements(produits, liste, {gruyere.cle: 1890});
      expect(de(r, 'croque').total, 270);
      expect(par(r, 'croque'), {'a': 150, 'b': 120});
      expect(de(r, 'croque').limitant, 'Gruyère râpé');
    });

    test('café : des litres achetés aux verres', () {
      final liste = listeParDefaut(produits: produits, gymnases: gymnases, jours: 2);
      final cle = calculerAchats(produits, liste).firstWhere((a) => a.nom == 'Café').cle;
      // 70 L proposés ; 35 L achetés -> 280 verres.
      final r = calculerRendements(produits, liste, {cle: 3500});
      expect(par(r, 'cafe'), {'a': 160, 'b': 120});
    });

    test('à la part : le total est conservé entre gymnases (plus grand reste)', () {
      const liste = ListeCourses(
          lignes: [LigneCourse('a', 'tarte', 12), LigneCourse('b', 'tarte', 8)]);
      // 20 prévues, 21 achetées : 12,6 et 8,4 -> 13 et 8.
      final r = calculerRendements(produits, liste, {'produit:tarte': 21});
      expect(de(r, 'tarte').total, 21);
      expect(par(r, 'tarte'), {'a': 13, 'b': 8});
    });

    test('ingrédient partagé : réparti entre toutes les recettes qui l’utilisent', () {
      // Pain de mie : 2 × 100 (croque) + 2 × 100 (chèvre) = 400 ; on en achète 200.
      const liste = ListeCourses(
          lignes: [LigneCourse('a', 'croque', 100), LigneCourse('a', 'chevre', 100)]);
      final pain = calculerAchats(produits, liste).firstWhere((a) => a.nom == 'Pain de mie');
      expect(pain.aAcheter, 400);
      final r = calculerRendements(produits, liste, {pain.cle: 200});
      expect(de(r, 'croque').total, 50);
      expect(de(r, 'chevre').total, 50);
    });

    test('« il reste » compte comme disponible', () {
      // 100 croques : 200 tranches de pain, dont 50 déjà là -> 150 à acheter.
      final base = const ListeCourses(lignes: [LigneCourse('a', 'croque', 100)]);
      final pain0 = calculerAchats(produits, base).firstWhere((a) => a.nom == 'Pain de mie');
      final liste = base.avec(restes: {pain0.cle: 50});
      expect(calculerRendements(produits, liste, const {}).single.total, 100);
      // Seulement 75 achetées : (75 + 50) / 200 = 0,625 -> 62 croques.
      expect(calculerRendements(produits, liste, {pain0.cle: 75}).single.total, 62);
    });

    test('acheter plus d’un seul ingrédient ne donne rien de plus', () {
      const liste = ListeCourses(lignes: [LigneCourse('a', 'croque', 100)]);
      final gruyere = calculerAchats(produits, liste).firstWhere((a) => a.nom == 'Gruyère râpé');
      final r = calculerRendements(produits, liste, {gruyere.cle: gruyere.aAcheter * 2});
      expect(r.single.total, 100);
      // Tout doublé : le double.
      final double = {
        for (final a in calculerAchats(produits, liste)) a.cle: a.aAcheter * 2.0,
      };
      expect(calculerRendements(produits, liste, double).single.total, 200);
    });

    test('unité de saisie d’un achat et montant en euros', () {
      const kg = Achat(cle: 'x|g', nom: 'X', uniteBase: 'g', besoin: 3780, reste: 0);
      const g = Achat(cle: 'x|g', nom: 'X', uniteBase: 'g', besoin: 250, reste: 0);
      const l = Achat(cle: 'x|cl', nom: 'X', uniteBase: 'cl', besoin: 7000, reste: 0);
      expect((uniteSaisie(kg).libelle, uniteSaisie(kg).facteur), ('kg', 1000.0));
      expect((uniteSaisie(g).libelle, uniteSaisie(g).facteur), ('g', 1.0));
      expect((uniteSaisie(l).libelle, uniteSaisie(l).facteur), ('L', 100.0));
      expect(centimesDepuisTexte('412,50'), 41250);
      expect(centimesDepuisTexte(' 0 '), 0);
      expect(centimesDepuisTexte('12.3'), 1230);
      expect(centimesDepuisTexte('abc'), isNull);
      expect(centimesDepuisTexte('-1'), isNull);
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
