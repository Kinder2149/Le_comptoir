import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_classeur.dart';
import 'package:le_comptoir/previsions.dart';

import 'classeur_aides.dart';

// Mission « Préparer l'événement », étape P6 : importer un classeur dans la Préparation.
// Logique pure : références calculées d'après la feuille Historique, plan d'import
// (stocks de départ, lignes ignorées), formule commune avec l'événement passé (P4).
const _gymnases = [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B')];
const _produits = [
  ProduitEvenement('soda', 'Soda', 100, null),
  ProduitEvenement('croque', 'Croque', 300, null),
  ProduitEvenement('cafe', 'Café', 100, null),
];
const _tout = PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);

LigneHistorique _l(String ev, String gym, int pers, double jours, String prod, int vendu) =>
    LigneHistorique(
        evenement: ev,
        gymnase: gym,
        personnes: pers,
        jours: jours,
        produit: prod,
        quantiteVendue: vendu);

void main() {
  group('formule commune (critère 3)', () {
    test('160 vendus ÷ 40 personnes ÷ 2 jours = 2,0', () {
      expect(consoParPersonneEtParJour(160, 40, 2), 2.0);
    });

    test('la source « événement passé » (P4) utilise la même formule', () {
      // consoDepuisEvenement et calculerReferences rendent le même chiffre : voir le
      // test de previsions_test pour le premier ; ici la référence donne 2,0.
      final r = calculerReferences([
        _l('Tournoi 2025', 'Gymnase A', 40, 2, 'Croque', 160),
      ]);
      expect(r.erreurs, isEmpty);
      expect(r.references.single.lignes.single.conso, 2.0);
    });

    test('la valeur de personnes d\'un gymnase, répétée sur ses lignes, compte une fois',
        () {
      final r = calculerReferences([
        _l('Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100),
        _l('Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', 40),
        _l('Tournoi 2025', 'gymnase b', 20, 2, 'Croque', 60),
      ]);
      expect(r.erreurs, isEmpty);
      final ref = r.references.single;
      expect(ref.nom, 'Tournoi 2025 (Excel)');
      expect(ref.id, 'tournoi-2025-excel');
      // 40 personnes au total : Croque 160 ÷ 40 ÷ 2 = 2,0 ; Soda 40 ÷ 40 ÷ 2 = 0,5.
      expect({for (final l in ref.lignes) l.nom: l.conso}, {'Croque': 2.0, 'Soda': 0.5});
    });

    test('un produit retrouvé sans casse ni accents garde le nom tel qu\'écrit', () {
      final r = calculerReferences([
        _l('T', 'A', 10, 1, 'Café', 10),
        _l('T', 'B', 10, 1, 'CAFE', 10),
      ]);
      expect(r.references.single.lignes.length, 1);
      expect(r.references.single.lignes.single.nom, 'Café');
      expect(r.references.single.lignes.single.conso, 1.0); // 20 ÷ 20 ÷ 1
    });
  });

  group('références : un événement par nom, erreurs dites', () {
    test('deux événements donnent deux références, triées', () {
      final r = calculerReferences([
        _l('Tournoi 2025', 'A', 40, 2, 'Croque', 160),
        _l('Ancien tournoi', 'A', 20, 1, 'Croque', 20),
      ]);
      expect(r.references.map((x) => x.nom),
          ['Ancien tournoi (Excel)', 'Tournoi 2025 (Excel)']);
    });

    test('personnes contradictoires pour un gymnase : événement non retenu', () {
      final r = calculerReferences([
        _l('T', 'A', 20, 2, 'Croque', 10),
        _l('T', 'A', 25, 2, 'Soda', 10),
      ]);
      expect(r.references, isEmpty);
      expect(r.erreurs.single, contains('« T »'));
      expect(r.erreurs.single, contains('pas le même'));
    });

    test('durée contradictoire : événement non retenu, les autres le sont', () {
      final r = calculerReferences([
        _l('T', 'A', 20, 2, 'Croque', 10),
        _l('T', 'B', 20, 3, 'Croque', 10),
        _l('Bon', 'A', 20, 2, 'Croque', 10),
      ]);
      expect(r.references.map((x) => x.nom), ['Bon (Excel)']);
      expect(r.erreurs.length, 1);
    });

    test('zéro personne : événement non retenu (comme P4)', () {
      final r = calculerReferences([_l('T', 'A', 0, 2, 'Croque', 10)]);
      expect(r.references, isEmpty);
      expect(r.erreurs.single, contains('aucun nombre de personnes'));
    });

    test('consommation au-delà de 1000 : événement non retenu', () {
      final r = calculerReferences([_l('T', 'A', 1, 0.5, 'Croque', 600)]);
      expect(r.references, isEmpty);
      expect(r.erreurs.single, contains('dépasse 1000'));
    });

    test('plus de 200 produits : événement non retenu', () {
      final r = calculerReferences([
        for (var i = 0; i < 201; i++) _l('T', 'A', 100, 2, 'P$i', 1),
      ]);
      expect(r.references, isEmpty);
      expect(r.erreurs.single, contains('200 produits'));
    });

    test('un nom d\'événement trop long est coupé : référence de 60 caractères au plus',
        () {
      final r = calculerReferences([_l('N' * 80, 'A', 10, 1, 'Croque', 10)]);
      expect(r.references.single.nom.length, 60);
      expect(r.references.single.nom, endsWith(' (Excel)'));
      expect(r.references.single.id.length, lessThanOrEqualTo(100));
    });

    test('cleReference : minuscules sans accents, [a-z0-9_-]', () {
      expect(cleReference('Tournoi Été 2025 (Excel)'), 'tournoi-ete-2025-excel');
      expect(cleReference('  A/B*C  '), 'a-b-c');
      expect(cleReference('???'), '');
      expect(cleReference('x' * 150).length, 100);
    });

    test('réimporter le même nom donne le même identifiant (remplacement)', () {
      final a = calculerReferences([_l('Tournoi 2025', 'A', 10, 1, 'Croque', 10)]);
      final b = calculerReferences([_l('tournoi 2025', 'A', 10, 1, 'Croque', 30)]);
      expect(a.references.single.id, b.references.single.id);
    });
  });

  group('consoDepuisReference (critère 3)', () {
    final ref = ReferenceImportee(
      id: 'r',
      nom: 'Tournoi 2025 (Excel)',
      lignes: const [LigneReference('CROQUE', 2.0), LigneReference('cafe', 1.5)],
    );

    test('produit retrouvé par son nom (sans casse ni accents), absent = menu', () {
      final conso = consoDepuisReference(produits: _produits, reference: ref);
      expect(conso, {'croque': 2.0, 'cafe': 1.5});
      expect(conso.containsKey('soda'), isFalse);
    });

    test('80 personnes × 2 jours × 2,0 = 320 (même chiffre qu\'en P4)', () {
      final conso = consoDepuisReference(produits: _produits, reference: ref);
      expect(80 * 2 * conso['croque']!, 320);
    });
  });

  group('plan d\'import', () {
    ClasseurLu lire(Uint8List b) => lireClasseur(b);

    test('critère 1 : n stocks et la référence « nom (Excel) » sont annoncés', () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', 24],
          ['gymnase b', 'CROQUE', 12],
          ['Gymnase A', 'Café', 0],
        ], historique: [
          ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100],
          ['Tournoi 2025', 'Gymnase B', 20, 2, 'Croque', 60],
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: _tout,
      );
      expect(plan.phraseStocks, '3 stocks seront appliqués.');
      expect(plan.phrasesReferences,
          ['Référence créée : Tournoi 2025 (Excel) — 1 produit']);
      expect(plan.stocks.map((s) => (s.gymnaseId, s.produitId, s.quantite)),
          [('gA', 'soda', 24), ('gB', 'croque', 12), ('gA', 'cafe', 0)]);
      expect(plan.ignorees, isEmpty);
      expect(plan.erreurs, isEmpty);
      expect(plan.vide, isFalse);
    });

    test('critère 4 : gymnase ou produit inconnu listé « ignoré », le reste s\'applique',
        () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', 24],
          ['Gymnase Z', 'Soda', 5],
          ['Gymnase A', 'Pizza', 5],
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: _tout,
      );
      expect(plan.stocks.length, 1);
      expect(plan.ignorees.length, 2);
      expect(plan.ignorees[0], contains('gymnase inconnu'));
      expect(plan.ignorees[1], contains('produit inconnu'));
    });

    test('événement ouvert : toutes les lignes de stock sont ignorées avec la raison, '
        'les références s\'importent', () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', 24],
          ['Gymnase B', 'Croque', 12],
          ['Gymnase A', 'Soda', null],
        ], historique: [
          ['Tournoi 2025', 'Gymnase A', 40, 2, 'Croque', 160],
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: _tout,
        stockModifiable: false,
      );
      expect(plan.stocks, isEmpty);
      expect(plan.phraseStocks, 'Aucun stock ne sera appliqué.');
      expect(plan.ignorees.length, 2);
      expect(plan.ignorees.every((l) => l.endsWith(messageStockFerme)), isTrue);
      expect(messageStockFerme,
          'Le stock de départ ne se modifie plus : l\'événement est ouvert.');
      expect(plan.references.single.nom, 'Tournoi 2025 (Excel)');
      expect(plan.vide, isFalse);
    });

    test('une quantité vide est ignorée sans erreur ni mention', () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', null],
          ['Gymnase A', 'Croque', 3],
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: _tout,
      );
      expect(plan.stocks.length, 1);
      expect(plan.ignorees, isEmpty);
      expect(plan.erreurs, isEmpty);
    });

    test('quantité invalide : ligne signalée par la lecture, le reste s\'applique', () {
      final lu = lire(classeurDeTest(stock: [
        ['Gymnase A', 'Soda', -4],
        ['Gymnase A', 'Croque', 100001],
        ['Gymnase A', 'Café', 2.5],
        ['Gymnase B', 'Soda', 7],
      ]));
      final plan = preparerImport(lu, tous: _gymnases, produits: _produits, portee: _tout);
      expect(plan.stocks.map((s) => s.quantite), [7]);
      expect(plan.erreurs.length, 3);
      expect(plan.erreurs.every((e) => e.contains('ligne')), isTrue);
    });

    test('doublon gymnase / produit : la première ligne est retenue', () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', 1],
          ['gymnase a', 'SODA', 9],
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: _tout,
      );
      expect(plan.stocks.single.quantite, 1);
      expect(plan.ignorees.single, contains('en double'));
    });

    test('gestionnaire partiel : seulement ses gymnases, les autres sont ignorés', () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', 1],
          ['Gymnase B', 'Soda', 2],
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: const PorteeGestion(responsable: false, gymnases: {'gB'}, nbGymnases: 2),
      );
      expect(plan.stocks.map((s) => s.gymnaseId), ['gB']);
      expect(plan.ignorees.single, contains('ne fait pas partie de vos gymnases'));
    });

    test('critère 5 : octets quelconques = ClasseurIllisible, rien à planifier', () {
      expect(() => lireClasseur(List.filled(200, 3)), throwsA(isA<ClasseurIllisible>()));
    });

    test('critère 5 : un classeur d\'un autre format n\'a pas de contenu utile', () {
      final lu = lireClasseur(classeurAutreFormat());
      expect(lu.contenuUtile, isFalse);
    });

    test('un modèle vide n\'a pas de contenu utile ; avec une ligne invalide, si', () {
      expect(lireClasseur(classeurDeTest()).contenuUtile, isFalse);
      expect(
          lireClasseur(classeurDeTest(stock: [
            ['Gymnase A', 'Soda', 'x']
          ])).contenuUtile,
          isTrue);
    });

    test('la feuille Menu est signalée comme ignorée, et ses manques ne sont pas des erreurs',
        () {
      final modele = construireModele(
        produits: _produits,
        gymnases: _gymnases,
        stocks: const {
          'gA': {'soda': StockDepart(6), 'croque': StockDepart(10)},
        },
      );
      final plan = preparerImport(lireClasseur(modele),
          tous: _gymnases, produits: _produits, portee: _tout);
      expect(plan.menuIgnore, isTrue);
      // Aller-retour : le stock du modèle est exactement ce qui sera appliqué.
      expect(
          plan.stocks.map((s) => (s.gymnaseId, s.produitId, s.quantite)).toSet(),
          {('gA', 'soda', 6), ('gA', 'croque', 10)});
      expect(plan.references, isEmpty);
      expect(plan.erreurs, isEmpty);
    });

    test('critère 6 : un plan ne contient ni vente ni donnée de bilan', () {
      final plan = preparerImport(
        lire(classeurDeTest(stock: [
          ['Gymnase A', 'Soda', 1]
        ], historique: [
          ['T', 'Gymnase A', 10, 1, 'Soda', 500]
        ])),
        tous: _gymnases,
        produits: _produits,
        portee: _tout,
      );
      // Seuls des stocks de départ et des références : rien d'autre à écrire.
      expect(plan.stocks.length, 1);
      expect(plan.references.length, 1);
      expect(plan.phraseConfirmation,
          'Stocks appliqués : 1. Références enregistrées : T (Excel).');
    });

    test('phrases : singulier, aucun stock, aucune référence', () {
      const vide = PlanImport(
          stocks: [], references: [], ignorees: [], erreurs: [], menuIgnore: false);
      expect(vide.phraseStocks, 'Aucun stock ne sera appliqué.');
      expect(vide.phraseConfirmation,
          'Stocks appliqués : 0. Références enregistrées : aucune.');
      expect(vide.vide, isTrue);
    });
  });
}
