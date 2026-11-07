import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/export_bilan.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/partage.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/ticket.dart';

// Étape P8 : l'export complet du tournoi (classeur Excel). Mêmes ventes que
// test/vues_gymnases_test.dart, chiffres calculés à la main et écrits dans le test :
//   Gymnase A (40 personnes) — Léa (clôturée) : L1 espèces 2 croques 6,00 · L2 carte
//                                3 cafés 4,50 · L3 carte 2 sodas 3,00 ANNULÉE
//   Gymnase B (30 personnes) — Max (ouverte)  : M1 carte 2 cafés 3,00 · M2 espèces
//                                2 croques 6,00 · M3 chèque 1 gâteau 2,50
//   Commun : 22,00 € en 5 ventes, 1 annulée ; espèces 12,00 · carte 7,50 · chèque 2,50 ;
//            café 5 (7,50), croque 4 (12,00), gâteau 1 (2,50) ; 03/10 : 3 ventes 13,50,
//            04/10 : 2 ventes 8,50 ; 10 h : 2 ventes 8,50, 14 h : 3 ventes 13,50.
//   Quantités vendues par gymnase : A croque 2, café 3 (soda annulé : 0) ;
//                                   B croque 2, café 2, gâteau 1.
DateTime _t(int jour, int h, int m) => DateTime(2026, 10, jour, h, m);

Vente _v(String id, List<LigneVente> lignes, String mode, DateTime quand,
        {bool annulee = false, DateTime? annuleeLe, String? par}) =>
    Vente(
      id: id,
      lignes: lignes,
      totalCentimes: lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite),
      mode: mode,
      creeLe: quand,
      enAttente: false,
      annulee: annulee,
      annuleeLe: annuleeLe,
      annuleeParPrenom: par,
    );

LigneVente _l(String id, String nom, int prix, int q) => LigneVente(id, nom, prix, q);

const _produits = [
  ProduitEvenement('croque', 'Croque-monsieur', 300, null),
  ProduitEvenement('cafe', 'Café', 150, null),
  ProduitEvenement('salade', 'Salade', 400, null),
  ProduitEvenement('gateau', 'Gâteau', 250, null),
  ProduitEvenement('soda', 'Soda', 150, null),
];
// Ce qu'il reste (le bilan) et le total de référence (la feuille Stock de départ).
const _stocks = {
  'g1': {'croque': 4, 'gateau': 6},
  'g2': {'croque': 3, 'gateau': 1},
};
const _reference = {
  'g1': {'croque': 50, 'gateau': 8},
  'g2': {'croque': 40, 'gateau': 6},
};
const _gymnases = [
  Gymnase('g1', 'Gymnase A', 40),
  Gymnase('g2', 'Gymnase B', 30),
];

TableauDeBord _jeu() {
  const lea = Caisse(uid: 'lea', gymnaseId: 'g1', prenom: 'Lea', statut: 'cloturee');
  const max = Caisse(uid: 'max', gymnaseId: 'g2', prenom: 'Max', statut: 'ouverte');
  return TableauDeBord.depuis([
    ResumeCaisse(lea, [
      _v('L1', [_l('croque', 'Croque-monsieur', 300, 2)], 'especes', _t(3, 14, 5)),
      _v('L2', [_l('cafe', 'Café', 150, 3)], 'carte', _t(3, 14, 40)),
      _v('L3', [_l('soda', 'Soda', 150, 2)], 'carte', _t(4, 14, 20),
          annulee: true, annuleeLe: _t(4, 14, 25), par: 'Lea'),
    ]),
    ResumeCaisse(max, [
      _v('M1', [_l('cafe', 'Café', 150, 2)], 'carte', _t(3, 14, 55)),
      _v('M2', [_l('croque', 'Croque-monsieur', 300, 2)], 'especes', _t(4, 10, 50)),
      _v('M3', [_l('gateau', 'Gâteau', 250, 1)], 'cheque', _t(4, 10, 15)),
    ]),
  ]);
}

const _evenement = Evenement(
  id: 'e1',
  nom: 'Tournoi d’automne',
  date: '2026-10-03',
  statut: 'en_cours',
  modes: ['especes', 'carte', 'cheque'],
  menuNom: 'Menu',
);

// Courses : une série déjà validée avant (1 série, 25,00 €), puis la série 2 validée à
// 10,00 € : 60 croques prévus mais 55 réellement achetés, 30 cafés achetés comme
// proposés (aucune quantité saisie), une ligne libre.
const _validee = ListeCourses(
  precedent: CumulCourses(series: 1, coutCentimes: 2500),
  lignes: [
    LigneCourse('g1', 'croque', 40),
    LigneCourse('g2', 'croque', 20),
    LigneCourse('g1', 'cafe', 30),
  ],
  libres: [LigneLibre('Gobelets', 200)],
  validation: ValidationCourses(
      achetes: {'produit:croque': 55}, rendements: [], coutCentimes: 1000),
);

Uint8List _export({
  Evenement evenement = _evenement,
  List<Gymnase> gymnases = _gymnases,
  TableauDeBord? tableau,
  ListeCourses? courses = _validee,
  bool coursesVisibles = true,
  bool limite = false,
  Map<String, Map<String, int>> stocks = _stocks,
}) =>
    construireExport(
      evenement: evenement,
      produits: _produits,
      gymnases: gymnases,
      stocksReference: _reference,
      stocksActuels: stocks,
      tableau: tableau ?? _jeu(),
      courses: courses,
      coursesVisibles: coursesVisibles,
      limite: limite,
    );

/// Les lignes d'une feuille, cellules vides de fin retirées (nombres tels qu'écrits).
List<List<Object?>> _lignes(List<int> octets, String feuille) {
  final f = Excel.decodeBytes(octets).tables[feuille]!;
  return [
    for (final ligne in f.rows)
      () {
        final cellules = <Object?>[
          for (final d in ligne)
            switch (d?.value) {
              null => null,
              IntCellValue v => v.value,
              DoubleCellValue v => v.value,
              final v => v.toString(),
            },
        ];
        while (cellules.isNotEmpty && cellules.last == null) {
          cellules.removeLast();
        }
        return cellules;
      }(),
  ];
}

void main() {
  group('critère 1 : le contenu du classeur', () {
    test('cinq feuilles, dans l’ordre : Menu, Stock de départ, Historique, Courses, Bilan',
        () {
      final x = Excel.decodeBytes(_export());
      expect(x.tables.keys.toList(),
          ['Menu', 'Stock de départ', 'Historique', 'Courses', 'Bilan']);
      expect(feuillesExport, x.tables.keys.toList());
      // Un vrai fichier .xlsx (archive zip).
      expect(_export().sublist(0, 2), [0x50, 0x4B]);
    });

    test('chaque feuille : ligne 1 = aide, ligne 2 = en-têtes du modèle, données dès la ligne 3',
        () {
      final octets = _export();
      expect(_lignes(octets, 'Menu')[1], entetesMenu);
      expect(_lignes(octets, 'Stock de départ')[1], entetesStock);
      expect(_lignes(octets, 'Historique')[1], entetesHistorique);
      expect(_lignes(octets, 'Courses')[1], entetesCourses);
      for (final f in feuillesExport) {
        final aide = _lignes(octets, f)[0];
        expect(aide.length, 1, reason: f);
        expect((aide.single as String).length, greaterThan(40), reason: f);
      }
    });

    test('Menu : les produits de l’événement ; Stock de départ : gymnase × produit suivi, '
        'total de référence', () {
      final octets = _export();
      final menu = _lignes(octets, 'Menu').skip(2).toList();
      expect(menu.map((l) => l[0]).toList(),
          ['Croque-monsieur', 'Café', 'Salade', 'Gâteau', 'Soda']);
      expect(menu.map((l) => l[1]).toList(), [3, 1.5, 4, 2.5, 1.5]);
      expect(_lignes(octets, 'Stock de départ').skip(2).toList(), [
        ['Gymnase A', 'Croque-monsieur', 50],
        ['Gymnase A', 'Gâteau', 8],
        ['Gymnase B', 'Croque-monsieur', 40],
        ['Gymnase B', 'Gâteau', 6],
      ]);
    });

    test('Historique : personnes, jours et quantités vendues de CET événement '
        '(vente annulée exclue, produit non vendu à 0)', () {
      const ev = 'Tournoi d’automne';
      expect(_lignes(_export(), 'Historique').skip(2).toList(), [
        [ev, 'Gymnase A', 40, 2, 'Croque-monsieur', 2],
        [ev, 'Gymnase A', 40, 2, 'Café', 3],
        [ev, 'Gymnase A', 40, 2, 'Salade', 0],
        [ev, 'Gymnase A', 40, 2, 'Gâteau', 0],
        [ev, 'Gymnase A', 40, 2, 'Soda', 0], // 2 sodas vendus puis annulés
        [ev, 'Gymnase B', 30, 2, 'Croque-monsieur', 2],
        [ev, 'Gymnase B', 30, 2, 'Café', 2],
        [ev, 'Gymnase B', 30, 2, 'Salade', 0],
        [ev, 'Gymnase B', 30, 2, 'Gâteau', 1],
        [ev, 'Gymnase B', 30, 2, 'Soda', 0],
      ]);
    });

    test('Courses : cumul des séries précédentes, achats réellement achetés, total, '
        'ligne libre', () {
      expect(_lignes(_export(), 'Courses').skip(2).toList(), [
        [null, 'Série 1 (cumul)', 1, 25],
        [2, 'Café (unité)', 30],
        [2, 'Croque-monsieur (unité)', 55], // 55 achetés, 60 prévus
        [2, 'Total de la série 2', null, 10],
        [2, 'Gobelets', 200],
      ]);
    });

    test('Courses : non validées, vide ou non visibles', () {
      const enPreparation = ListeCourses(
          lignes: [LigneCourse('g1', 'croque', 40)],
          libres: [LigneLibre('Nappes', 3.5)]);
      expect(
          _lignes(_export(courses: enPreparation), 'Courses').skip(2).toList(), [
        [1, 'Courses non validées'],
        [1, 'Nappes', 3.5],
      ]);
      expect(_lignes(_export(courses: null), 'Courses').skip(2).toList(), [
        [1, 'Courses non validées'],
      ]);
      // Une nouvelle série ouverte après deux séries validées (cumul 70,00 €).
      const nouvelle = ListeCourses(
          precedent: CumulCourses(series: 2, coutCentimes: 7000));
      expect(_lignes(_export(courses: nouvelle), 'Courses').skip(2).toList(), [
        [null, 'Séries 1 à 2 (cumul)', 2, 70],
        [3, 'Courses non validées'],
      ]);
      expect(
          _lignes(_export(coursesVisibles: false), 'Courses').skip(2).toList(), [
        [null, 'Courses non visibles avec vos droits'],
      ]);
    });
  });

  group('critère 2 : le Bilan égale le calcul fait à la main', () {
    test('vue commune, courses validées : chaque total est celui du calcul noté '
        'en tête de fichier', () {
      final bilan = _lignes(_export(), 'Bilan');
      expect(bilan[0].single as String, startsWith("Le bilan de l'événement"));
      expect(bilan.skip(1).toList(), [
        ['Bilan', 'Tournoi d’automne'],
        ['Date', '03/10/2026'],
        ['Portée', 'Tous les gymnases'],
        ['État', 'Provisoire (événement en cours)'],
        [],
        ['Totaux'],
        ['Ventes', 5],
        ['Ventes annulées', 1],
        ['Total des ventes', 22],
        ['Coût des courses', 35], // 25,00 (série 1) + 10,00 (série 2)
        ['Résultat', -13], // 22,00 - 35,00
        [],
        ['Par mode de paiement'],
        ['Mode', 'Montant'],
        ['Espèces', 12],
        ['Carte', 7.5],
        ['Chèque', 2.5],
        [],
        ['Par produit'],
        ['Produit', 'Vendus', 'Montant', 'Stock restant'],
        ['Café', 5, 7.5],
        ['Croque-monsieur', 4, 12, 7],
        ['Gâteau', 1, 2.5, 7],
        ['Salade', 0, 0],
        ['Soda', 0, 0],
        [],
        ['Par caisse'],
        ['Caisse', 'Gymnase', 'État', 'Ventes', 'Annulées', 'Montant'],
        ['Lea', 'Gymnase A', 'Clôturée', 2, 1, 10.5],
        ['Max', 'Gymnase B', 'Ouverte', 3, 0, 11.5],
        [],
        ['Par jour'],
        ['Jour', 'Ventes', 'Montant'],
        ['03/10/2026', 3, 13.5],
        ['04/10/2026', 2, 8.5],
        [],
        ['Par heure'],
        ['Heure', 'Ventes', 'Montant'],
        ['10 h–11 h', 2, 8.5],
        ['14 h–15 h', 3, 13.5],
        [],
        ['Ventes annulées'],
        ['Caisse', 'Vendue le', 'Montant', 'Mode', 'Annulée par', 'Annulée le'],
        ['Lea', '04/10/2026 14:20', 3, 'Carte', 'Lea', '04/10/2026 14:25'],
      ]);
    });

    test('courses non validées : ligne le disant, ni résultat ; sans droit : aucun coût',
        () {
      final non = _lignes(_export(courses: null), 'Bilan');
      expect(non, anyElement(equals(['Coût des courses', 'Courses non validées'])));
      expect(non.where((l) => l.isNotEmpty && l[0] == 'Résultat'), isEmpty);
      final sans = _lignes(_export(coursesVisibles: false), 'Bilan');
      expect(sans.where((l) => l.isNotEmpty && l[0].toString().startsWith('Co')),
          isEmpty);
      expect(sans.where((l) => l.isNotEmpty && l[0] == 'Résultat'), isEmpty);
    });

    test('événement clôturé par force : définitif et la clôture forcée est dite', () {
      final b = _lignes(
          _export(
              evenement: const Evenement(
                  id: 'x',
                  nom: 'Fête',
                  date: '2026-10-03',
                  statut: 'cloture',
                  modes: ['especes', 'carte', 'cheque'],
                  menuNom: 'm',
                  forcee: true,
                  nbCaissesOuvertes: 2)),
          'Bilan');
      expect(b, anyElement(equals(['État', 'Définitif (événement clôturé)'])));
      expect(
          b,
          anyElement(equals([
            'Clôture forcée',
            '2 caisses non clôturées : des ventes peuvent manquer'
          ])));
    });

    test('un gestionnaire limité à Gymnase B : ses seules données, la portée est dite',
        () {
      final octets = _export(
        gymnases: [_gymnases[1]],
        tableau: _jeu().pour('g2'),
        limite: true,
        coursesVisibles: false,
        stocks: {'g2': _stocks['g2']!},
      );
      // Gymnase B : 3 ventes, 11,50 € (croque 2 = 6,00 ; café 2 = 3,00 ; gâteau 1 = 2,50).
      final bilan = _lignes(octets, 'Bilan');
      expect(bilan, anyElement(equals(['Portée', 'Export limité aux gymnases : Gymnase B'])));
      expect(bilan, anyElement(equals(['Ventes', 3])));
      expect(bilan, anyElement(equals(['Total des ventes', 11.5])));
      expect(bilan, anyElement(equals(['Croque-monsieur', 2, 6, 3])));
      expect(bilan, anyElement(equals(['Max', 'Gymnase B', 'Ouverte', 3, 0, 11.5])));
      expect(bilan.any((l) => l.contains('Lea')), isFalse);
      final histo = _lignes(octets, 'Historique').skip(2);
      expect(histo.every((l) => l[1] == 'Gymnase B'), isTrue);
      expect(histo.length, 5);
      expect(_lignes(octets, 'Stock de départ').skip(2).map((l) => l[0]).toSet(),
          {'Gymnase B'});
    });

    test('noms de fichier : modèle et tournoi', () {
      expect(nomFichierExport(_evenement), 'tournoi-tournoi-d-automne-2026-10-03.xlsx');
      expect(
          nomFichierExport(const Evenement(
              id: 'x', nom: 'Été !!', date: '2026-07-01', statut: 'cloture',
              modes: ['especes'], menuNom: 'm')),
          'tournoi-ete-2026-07-01.xlsx');
      expect(nomFichierModele(_evenement), 'modele-tournoi-d-automne-2026-10-03.xlsx');
    });

    test('affichage en euros d’un résultat négatif', () {
      expect(formaterEuros(1200), '12,00 €');
      expect(formaterEuros(-39050), '-390,50 €');
      expect(formaterEuros(-5), '-0,05 €');
    });
  });

  group('critère 3 : réimporté, il donne la même consommation que la source '
      '« événement passé »', () {
    test('mêmes consommations par les deux chemins, sur le même événement', () {
      // Le nouvel événement : les mêmes produits (autres identifiants), retrouvés par nom.
      const nouveaux = [
        ProduitEvenement('n1', 'croque-monsieur', 300, null),
        ProduitEvenement('n2', 'CAFE', 150, null),
        ProduitEvenement('n3', 'Salade', 400, null),
        ProduitEvenement('n4', 'Gâteau', 250, null),
        ProduitEvenement('n5', 'Soda', 150, null),
        ProduitEvenement('n6', 'Nouveauté', 100, null),
      ];
      // Chemin 1 (P4) : l'événement passé lui-même, 70 personnes pendant 2 jours.
      final passe = consoDepuisEvenement(
        produits: nouveaux,
        produitsPasses: {for (final p in _produits) p.id: p.nom},
        tableau: _jeu(),
        personnes: 70,
        jours: 2,
      );
      // Chemin 2 (P6) : le classeur exporté, relu puis transformé en référence.
      final lu = lireClasseur(_export());
      expect(lu.erreurs, isEmpty);
      final calculees = calculerReferences(lu.historique);
      expect(calculees.erreurs, isEmpty);
      expect(calculees.references.single.nom, 'Tournoi d’automne (Excel)');
      final reimporte = consoDepuisReference(
          produits: nouveaux, reference: calculees.references.single);

      // Le calcul à la main : ventes non annulées ÷ 70 personnes ÷ 2 jours.
      final attendu = {
        'n1': 4 / 70 / 2, // croques : 2 + 2
        'n2': 5 / 70 / 2, // cafés : 3 + 2
        'n3': 0.0,
        'n4': 1 / 70 / 2, // gâteaux : 1
        'n5': 0.0, // les 2 sodas ont été annulés
      };
      expect(passe, attendu);
      expect(reimporte, attendu);
      expect(reimporte, passe);
      // Le produit absent de l'événement reste au menu dans les deux cas.
      expect(passe.containsKey('n6'), isFalse);
      expect(reimporte.containsKey('n6'), isFalse);
    });

    test('le classeur exporté se relit sans erreur : Menu, Stock et Historique lus, '
        'Courses et Bilan ignorés', () {
      final lu = lireClasseur(_export());
      expect(lu.erreurs, isEmpty);
      expect(lu.produits.map((p) => p.nom).toList(),
          ['Croque-monsieur', 'Café', 'Salade', 'Gâteau', 'Soda']);
      expect(lu.stocks.length, 4);
      expect(lu.historique.length, 10);
      expect(lu.historique.fold<int>(0, (t, l) => t + l.quantiteVendue), 10);
    });
  });

  group('critère 4 : l’ancien export CSV a disparu', () {
    test('plus de « CSV » dans l’écran du bilan, plus de bilanEnCsv dans le code', () {
      final ecran = File('lib/ecran_bilan.dart').readAsStringSync();
      expect(ecran.toLowerCase(), isNot(contains('csv')));
      expect(ecran, isNot(contains('exporter_csv')));
      for (final f in Directory('lib').listSync().whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final code = f.readAsStringSync();
        expect(code, isNot(contains('bilanEnCsv')), reason: f.path);
        expect(code, isNot(contains('champCsv')), reason: f.path);
        expect(code, isNot(contains('montantCsv')), reason: f.path);
        expect(code, isNot(contains('nomFichierBilan')), reason: f.path);
      }
    });
  });

  group('coût des courses', () {
    test('validées : coût et résultat ; sinon « non validées »', () {
      const validee = ListeCourses(
          validation: ValidationCourses(
              achetes: {}, rendements: [], coutCentimes: 1000));
      final c = CoutBilan.depuis(validee, 2200) as CoutConnu;
      expect((c.coutCentimes, c.resultatCentimes), (1000, 1200));
      expect(CoutBilan.depuis(const ListeCourses(), 2200), isA<CoursesNonValidees>());
      expect(CoutBilan.depuis(null, 2200), isA<CoursesNonValidees>());
      // Perte : résultat négatif.
      final perte = CoutBilan.depuis(validee, 400) as CoutConnu;
      expect(perte.resultatCentimes, -600);
    });
  });

  group('écran du bilan', () {
    const validee = ListeCourses(
        validation:
            ValidationCourses(achetes: {}, rendements: [], coutCentimes: 1000));

    Future<void> afficher(
      WidgetTester tester, {
      Stream<ListeCourses?>? courses,
      PartageurOctets? partager,
      List<Gymnase> gymnases = _gymnases,
      TableauDeBord? tableau,
      bool limite = false,
    }) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: _evenement,
          tableau: Stream.value(tableau ?? _jeu()),
          produits: Stream.value(_produits),
          gymnases: Stream.value(gymnases),
          stocks: Stream.value(_stocks),
          stocksReference: Stream.value(_reference),
          courses: courses,
          limite: limite,
          partager: partager ?? (_, _, _) async {},
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    String texte(WidgetTester tester, String cle) =>
        tester.widget<Text>(find.byKey(Key(cle))).data!;

    testWidgets('courses validées : coût et résultat en vue commune', (tester) async {
      await afficher(tester, courses: Stream.value(validee));
      expect(texte(tester, 'bilan_cout'), 'Coût des courses : 10,00 €');
      expect(texte(tester, 'bilan_resultat'), 'Résultat : 12,00 €');
      expect(find.byKey(const Key('bilan_cout_commun')), findsNothing);
    });

    testWidgets('courses non validées : pas de coût ni de résultat', (tester) async {
      await afficher(tester, courses: Stream.value(null));
      expect(find.byKey(const Key('bilan_courses_non_validees')), findsOneWidget);
      expect(find.byKey(const Key('bilan_cout')), findsNothing);
      expect(find.byKey(const Key('bilan_resultat')), findsNothing);
    });

    testWidgets('vue d’un gymnase : la mention, pas de coût', (tester) async {
      await afficher(tester, courses: Stream.value(validee));
      await tester.tap(find.byKey(const Key('vue_g1')));
      await tester.pump();
      expect(find.byKey(const Key('bilan_cout_commun')), findsOneWidget);
      expect(find.byKey(const Key('bilan_cout')), findsNothing);
      expect(find.byKey(const Key('bilan_resultat')), findsNothing);
    });

    testWidgets('sans accès aux courses : aucun coût', (tester) async {
      await afficher(tester);
      expect(find.byKey(const Key('bilan_cout')), findsNothing);
      expect(find.byKey(const Key('bilan_cout_commun')), findsNothing);
      expect(find.byKey(const Key('bilan_courses_non_validees')), findsNothing);
    });

    testWidgets('le bouton s’appelle « Exporter (Excel) » et il n’y a plus de CSV',
        (tester) async {
      await afficher(tester);
      expect(find.text('Exporter (Excel)'), findsOneWidget);
      expect(find.byKey(const Key('exporter_excel')), findsOneWidget);
      expect(find.byKey(const Key('exporter_csv')), findsNothing);
      expect(find.textContaining('CSV'), findsNothing);
      expect(find.byKey(const Key('aide_export')), findsOneWidget);
    });

    testWidgets('exporter : un .xlsx part, ses chiffres sont ceux de l’écran, même '
        'depuis la vue d’un gymnase', (tester) async {
      String? nom, mime;
      Uint8List? octets;
      await afficher(tester,
          courses: Stream.value(validee),
          partager: (n, o, m) async {
            nom = n;
            octets = o;
            mime = m;
          });
      final totalEcran = tester
          .widgetList<Text>(find.descendant(
              of: find.byKey(const Key('bilan_total')), matching: find.byType(Text)))
          .map((t) => t.data!)
          .join(' | ');
      expect(totalEcran, contains('22,00 €'));
      await tester.tap(find.byKey(const Key('exporter_excel')));
      await tester.pump();
      await tester.pump();
      expect(nom, 'tournoi-tournoi-d-automne-2026-10-03.xlsx');
      expect(mime, typeMimeClasseur);
      var bilan = _lignes(octets!, 'Bilan');
      expect(bilan, anyElement(equals(['Total des ventes', 22])));
      expect(bilan, anyElement(equals(['Coût des courses', 10])));
      expect(bilan, anyElement(equals(['Résultat', 12])));
      expect(texte(tester, 'bilan_cout'), 'Coût des courses : 10,00 €');
      // Vue d'un gymnase affichée : le classeur contient quand même toute la portée.
      await tester.tap(find.byKey(const Key('vue_g2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('exporter_excel')));
      await tester.pump();
      await tester.pump();
      bilan = _lignes(octets!, 'Bilan');
      expect(bilan, anyElement(equals(['Total des ventes', 22])));
      expect(bilan, anyElement(equals(['Portée', 'Tous les gymnases'])));
      // La feuille Stock de départ prend le total de référence du flux dédié.
      expect(_lignes(octets!, 'Stock de départ')[2], ['Gymnase A', 'Croque-monsieur', 50]);
    });

    testWidgets('gestionnaire limité : classeur limité à ses gymnases, sans coût',
        (tester) async {
      Uint8List? octets;
      await afficher(tester,
          gymnases: [_gymnases[1]],
          tableau: _jeu().pour('g2'),
          limite: true,
          partager: (n, o, m) async => octets = o);
      await tester.tap(find.byKey(const Key('exporter_excel')));
      await tester.pump();
      await tester.pump();
      final bilan = _lignes(octets!, 'Bilan');
      expect(bilan, anyElement(equals(['Portée', 'Export limité aux gymnases : Gymnase B'])));
      expect(bilan, anyElement(equals(['Total des ventes', 11.5])));
      expect(bilan.any((l) => l.isNotEmpty && l[0] == 'Coût des courses'), isFalse);
    });

    testWidgets('un partage qui échoue affiche un message', (tester) async {
      await afficher(tester, partager: (_, _, _) async => throw Exception('non'));
      await tester.tap(find.byKey(const Key('exporter_excel')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('erreur_export')), findsOneWidget);
    });
  });
}
