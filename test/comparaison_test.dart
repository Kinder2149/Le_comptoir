import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/comparaison.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/export_bilan.dart';
import 'package:le_comptoir/previsions.dart' show consoAffichee;

// Mission « Retours du terrain », étape F6 (décision 74) : comparateur de deux tournois.
// Tous les chiffres attendus sont calculés à la main et écrits en dur (critère 4).

TableauDeBord _tableau(int ventes, int total, Map<String, QuantiteProduit> produits) =>
    TableauDeBord(
      caisses: const [],
      nbVentes: ventes,
      nbAnnulees: 0,
      totalCentimes: total,
      parProduit: produits,
      parMode: const {},
    );

// Tournoi « Samedi » : 150 personnes (100 + 50), 2 jours.
//   Cola : 60 vendus -> 60 / 150 / 2 = 0,2 par personne et par jour.
//   Croque-monsieur : 30 vendus -> 30 / 150 / 2 = 0,1.
//   Thé glacé : 10 vendus -> 10 / 150 / 2 = 1/30 (0,033...).
//   Total des ventes 225,00 € ; 10 ventes ; courses 90,00 € ; résultat 135,00 €.
PhotoTournoi _samedi({int personnes = 150, bool courses = true}) => PhotoTournoi(
      nom: 'Samedi',
      personnes: personnes,
      jours: 2,
      tableau: _tableau(10, 22500, const {
        'cola': QuantiteProduit('Cola', 60, 12000),
        'croque': QuantiteProduit('Croque-monsieur', 30, 9000),
        'the': QuantiteProduit('Thé glacé', 10, 1500),
      }),
      produits: const [
        ProduitEvenement('cola', 'Cola', 200, null),
        ProduitEvenement('croque', 'Croque-monsieur', 300, null),
        ProduitEvenement('the', 'Thé glacé', 150, null),
      ],
      cout: courses ? CoutConnu(9000, 13500) : null,
    );

// Tournoi « Dimanche » : 80 personnes, 1 jour.
//   Cola : 40 vendus -> 40 / 80 / 1 = 0,5.
//   Fanta : 16 vendus -> 16 / 80 = 0,2 (absent du samedi).
//   « THE GLACE » (même produit que « Thé glacé », sans accents ni majuscules) : 4 -> 4 / 80 = 0,05.
//   Croque-monsieur absent : « — ».
//   Total des ventes 118,00 € ; 8 ventes ; courses 50,00 € ; résultat 68,00 €.
PhotoTournoi _dimanche() => PhotoTournoi(
      nom: 'Dimanche',
      personnes: 80,
      jours: 1,
      tableau: _tableau(8, 11800, const {
        'cola': QuantiteProduit('Cola', 40, 8000),
        'fanta': QuantiteProduit('Fanta', 16, 3200),
        'the2': QuantiteProduit('THE GLACE', 4, 600),
      }),
      produits: const [
        ProduitEvenement('cola', 'Cola', 200, null),
        ProduitEvenement('fanta', 'Fanta', 200, null),
        ProduitEvenement('the2', 'THE GLACE', 150, null),
      ],
      cout: CoutConnu(5000, 6800),
    );

/// Un nombre relu : Excel rend un montant entier en entier, sinon en décimal.
num _nombre(Data? d) => switch (d?.value) {
      IntCellValue v => v.value,
      DoubleCellValue v => v.value,
      _ => throw StateError('pas un nombre'),
    };

void main() {
  group('Synthèse côte à côte', () {
    test('personnes, jours, ventes, total, coût et résultat sont ceux calculés à la main', () {
      final lignes = synthese(_samedi(), _dimanche());
      final parLibelle = {for (final l in lignes) l.libelle: l};
      expect(parLibelle['Personnes']!.a, 150);
      expect(parLibelle['Personnes']!.b, 80);
      expect(parLibelle['Jours']!.a, 2);
      expect(parLibelle['Jours']!.b, 1);
      expect(parLibelle['Ventes']!.a, 10);
      expect(parLibelle['Ventes']!.b, 8);
      // En centimes : 225,00 € et 118,00 €.
      expect(parLibelle['Total des ventes']!.a, 22500);
      expect(parLibelle['Total des ventes']!.b, 11800);
      // Coût : 90,00 € et 50,00 € ; résultat : 135,00 € et 68,00 €.
      expect(parLibelle['Coût des courses']!.a, 9000);
      expect(parLibelle['Coût des courses']!.b, 5000);
      expect(parLibelle['Résultat']!.a, 13500);
      expect(parLibelle['Résultat']!.b, 6800);
    });

    test('la synthèse se lit à l\'écran : 225,00 € et « — » si absent', () {
      final lignes = synthese(_samedi(), _dimanche());
      final total = lignes.firstWhere((l) => l.libelle == 'Total des ventes');
      expect(texteValeur(total.a, total.unite), '225,00 €');
      expect(texteValeur(null, Unite.euros), '—');
    });

    test('sans accès aux courses : coût et résultat sont « — »', () {
      final lignes = synthese(_samedi(courses: false), _dimanche());
      final cout = lignes.firstWhere((l) => l.libelle == 'Coût des courses');
      final resultat = lignes.firstWhere((l) => l.libelle == 'Résultat');
      expect(cout.a, isNull);
      expect(resultat.a, isNull);
      expect(texteValeur(cout.a, cout.unite), '—');
      // Le total, lui, reste visible.
      expect(lignes.firstWhere((l) => l.libelle == 'Total des ventes').a, 22500);
    });
  });

  group('Comparaison par produit', () {
    late List<ComparaisonProduit> produits;

    setUp(() {
      produits = comparerProduits(_samedi(), _dimanche());
    });

    test('ordre : ceux du premier tournoi, puis ceux du second seulement', () {
      expect(produits.map((p) => p.nom),
          ['Cola', 'Croque-monsieur', 'Thé glacé', 'Fanta']);
    });

    test('Cola : quantités 60 et 40, consommation 0,2 et 0,5, écart +0,3', () {
      final cola = produits[0];
      expect(cola.vendusA, 60);
      expect(cola.vendusB, 40);
      expect(cola.consoA, closeTo(0.2, 1e-9));
      expect(cola.consoB, closeTo(0.5, 1e-9));
      expect(cola.ecart, closeTo(0.3, 1e-9));
      expect(texteEcart(cola.ecart), '+0,3');
    });

    test('Croque-monsieur, présent d\'un seul côté : « — » de l\'autre, écart absent', () {
      final croque = produits[1];
      expect(croque.vendusA, 30);
      expect(croque.consoA, closeTo(0.1, 1e-9));
      expect(croque.vendusB, isNull);
      expect(croque.consoB, isNull);
      expect(croque.ecart, isNull);
      expect(texteEcart(croque.ecart), '—');
    });

    test('Thé glacé retrouvé par son nom malgré casse et accents : 10 et 4, 1/30 et 0,05', () {
      final the = produits[2];
      expect(the.nom, 'Thé glacé');
      expect(the.vendusA, 10);
      expect(the.vendusB, 4);
      expect(the.consoA, closeTo(1 / 30, 1e-9));
      expect(the.consoB, closeTo(0.05, 1e-9));
      expect(the.ecart, closeTo(0.05 - 1 / 30, 1e-9));
      expect(consoAffichee(the.consoA!), '0,03');
    });

    test('Fanta, présent seulement dans le second : « — » du premier côté', () {
      final fanta = produits[3];
      expect(fanta.vendusA, isNull);
      expect(fanta.vendusB, 16);
      expect(fanta.consoA, isNull);
      expect(fanta.consoB, closeTo(0.2, 1e-9));
      expect(fanta.ecart, isNull);
    });

    test('personnes à zéro : aucune consommation, aucune division par zéro', () {
      final sansPersonnes = comparerProduits(_samedi(personnes: 0), _dimanche());
      final cola = sansPersonnes.first;
      expect(cola.vendusA, 60);
      expect(cola.consoA, isNull);
      expect(cola.ecart, isNull);
      expect(cola.consoB, closeTo(0.5, 1e-9));
    });
  });

  group('Classeur du comparateur', () {
    test('le fichier s\'ouvre, avec les feuilles Synthèse et Produits et les bons chiffres', () {
      final octets = construireComparaison(
        nomA: 'Samedi',
        nomB: 'Dimanche',
        synthese: synthese(_samedi(), _dimanche()),
        produits: comparerProduits(_samedi(), _dimanche()),
      );
      final classeur = Excel.decodeBytes(octets);
      expect(classeur.tables.keys,
          containsAll([feuilleComparaisonSynthese, feuilleComparaisonProduits]));

      final synth = classeur.tables[feuilleComparaisonSynthese]!.rows;
      // En-tête à la ligne 6, premier indicateur à la ligne 7.
      expect(synth[5][1]?.value.toString(), 'Samedi');
      expect(synth[5][2]?.value.toString(), 'Dimanche');
      expect(synth[6][0]?.value.toString(), 'Personnes');
      expect(_nombre(synth[6][1]), 150);
      expect(_nombre(synth[6][2]), 80);
      final total = synth.firstWhere((r) => r[0]?.value.toString() == 'Total des ventes');
      expect(_nombre(total[1]), 225.0);
      expect(_nombre(total[2]), 118.0);

      final prod = classeur.tables[feuilleComparaisonProduits]!.rows;
      expect(prod[6][0]?.value.toString(), 'Cola');
      expect(_nombre(prod[6][1]), 60);
      expect(_nombre(prod[6][3]), closeTo(0.2, 1e-9));
      // Croque-monsieur : « — » côté Dimanche.
      expect(prod[7][2]?.value.toString(), '—');
    });
  });
}
