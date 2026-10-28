import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/export_bilan.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/partage.dart';
import 'package:le_comptoir/ticket.dart';

// Mêmes ventes que test/vues_gymnases_test.dart, chiffres calculés à la main :
//   Gymnase A — Léa (clôturée) : L1 espèces 2 croques 6,00 · L2 carte 3 cafés 4,50 ·
//                                L3 carte 2 sodas 3,00 ANNULÉE
//   Gymnase B — Max (ouverte)  : M1 carte 2 cafés 3,00 · M2 espèces 2 croques 6,00 ·
//                                M3 chèque 1 gâteau 2,50
//   Commun : 22,00 € en 5 ventes, 1 annulée ; espèces 12,00 · carte 7,50 · chèque 2,50 ;
//            café 5 (7,50), croque 4 (12,00), gâteau 1 (2,50) ; 03/10 : 3 ventes 13,50,
//            04/10 : 2 ventes 8,50 ; 10 h : 2 ventes 8,50, 14 h : 3 ventes 13,50.
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
const _stocks = {
  'g1': {'croque': 4, 'gateau': 6},
  'g2': {'croque': 3, 'gateau': 1},
};
const _gymnases = [Gymnase('g1', 'Gymnase A'), Gymnase('g2', 'Gymnase B')];

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

Bilan _bilan(String? g) => Bilan.depuis(_jeu(), _produits, _evenement.modes,
    gymnaseId: g, stocks: _stocks);

String _csv(List<String> lignes) => '﻿${lignes.join('\r\n')}\r\n';

void main() {
  group('champs et montants', () {
    test('un champ à risque est entre guillemets', () {
      expect(champCsv('Café'), 'Café');
      expect(champCsv('a;b'), '"a;b"');
      expect(champCsv('dit "oui"'), '"dit ""oui"""');
      expect(champCsv('deux\nlignes'), '"deux\nlignes"');
    });

    test('montants avec virgule décimale et signe', () {
      expect(montantCsv(600), '6,00');
      expect(montantCsv(5), '0,05');
      expect(montantCsv(41250), '412,50');
      expect(montantCsv(-39050), '-390,50');
      expect(montantCsv(0), '0,00');
    });

    test('affichage en euros d’un résultat négatif', () {
      expect(formaterEuros(1200), '12,00 €');
      expect(formaterEuros(-39050), '-390,50 €');
      expect(formaterEuros(-5), '-0,05 €');
    });

    test('nom du fichier', () {
      expect(nomFichierBilan(_evenement), 'bilan-tournoi-d-automne-2026-10-03.csv');
      expect(
          nomFichierBilan(const Evenement(
              id: 'x', nom: 'Été !!', date: '2026-07-01', statut: 'cloture',
              modes: ['especes'], menuNom: 'm')),
          'bilan-ete-2026-07-01.csv');
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

  test('CSV de la vue commune, avec coût et résultat', () {
    const validee = ListeCourses(
        validation:
            ValidationCourses(achetes: {}, rendements: [], coutCentimes: 1000));
    final csv = bilanEnCsv(
      evenement: _evenement,
      bilan: _bilan(null),
      vue: 'Commun',
      gymnases: _gymnases,
      cout: CoutBilan.depuis(validee, 2200),
    );
    expect(
      csv,
      _csv([
        'Bilan;Tournoi d’automne',
        'Date;03/10/2026',
        'Vue;Commun',
        'État;Provisoire (événement en cours)',
        '',
        'Totaux',
        'Ventes;5',
        'Ventes annulées;1',
        'Total des ventes;22,00',
        'Coût des courses;10,00',
        'Résultat;12,00',
        '',
        'Par mode de paiement',
        'Mode;Montant',
        'Espèces;12,00',
        'Carte;7,50',
        'Chèque;2,50',
        '',
        'Par produit',
        'Produit;Vendus;Montant;Stock restant',
        'Café;5;7,50;',
        'Croque-monsieur;4;12,00;7',
        'Gâteau;1;2,50;7',
        'Salade;0;0,00;',
        'Soda;0;0,00;',
        '',
        'Par caisse',
        'Caisse;Gymnase;État;Ventes;Annulées;Montant',
        'Lea;Gymnase A;Clôturée;2;1;10,50',
        'Max;Gymnase B;Ouverte;3;0;11,50',
        '',
        'Par jour',
        'Jour;Ventes;Montant',
        '03/10/2026;3;13,50',
        '04/10/2026;2;8,50',
        '',
        'Par heure',
        'Heure;Ventes;Montant',
        '10 h–11 h;2;8,50',
        '14 h–15 h;3;13,50',
        '',
        'Ventes annulées',
        'Caisse;Vendue le;Montant;Mode;Annulée par;Annulée le',
        'Lea;04/10/2026 14:20;3,00;Carte;Lea;04/10/2026 14:25',
      ]),
    );
  });

  test('CSV d’un gymnase : pas de coût, son stock, ses caisses', () {
    final csv = bilanEnCsv(
      evenement: _evenement,
      bilan: _bilan('g2'),
      vue: 'Gymnase B',
      gymnases: _gymnases,
    );
    // Gymnase B : 11,50 € en 3 ventes, croque 2 (6,00) stock 3, café 2 (3,00),
    // gâteau 1 (2,50) stock 1 ; pas d'annulation, pas de ligne de coût.
    expect(csv, contains('Vue;Gymnase B'));
    expect(csv, contains('Ventes;3\r\nVentes annulées;0\r\nTotal des ventes;11,50\r\n\r\n'));
    expect(csv, isNot(contains('Coût')));
    expect(csv, contains('Croque-monsieur;2;6,00;3'));
    expect(csv, contains('Gâteau;1;2,50;1'));
    expect(csv, contains('Max;Gymnase B;Ouverte;3;0;11,50'));
    expect(csv, isNot(contains('Lea;')));
    expect(csv, isNot(contains('Ventes annulées\r\nCaisse')));
  });

  test('courses non validées : la ligne le dit, sans résultat', () {
    final csv = bilanEnCsv(
      evenement: _evenement,
      bilan: _bilan(null),
      vue: 'Commun',
      gymnases: _gymnases,
      cout: const CoursesNonValidees(),
    );
    expect(csv, contains('Total des ventes;22,00\r\nCoût des courses;Courses non validées\r\n\r\n'));
    expect(csv, isNot(contains('Résultat')));
  });

  test('un nom avec « ; » ou un guillemet reste dans sa colonne', () {
    final csv = bilanEnCsv(
      evenement: const Evenement(
          id: 'x', nom: 'Fête; "été"', date: '2026-10-03', statut: 'cloture',
          modes: ['especes'], menuNom: 'm', forcee: true, nbCaissesOuvertes: 2),
      bilan: _bilan(null),
      vue: 'Commun',
      gymnases: _gymnases,
    );
    expect(csv, startsWith('﻿Bilan;"Fête; ""été"""\r\n'));
    expect(csv, contains('État;Définitif (événement clôturé)'));
    expect(csv, contains('Clôture forcée;2 caisses non clôturées : des ventes peuvent manquer'));
  });

  group('écran du bilan', () {
    const validee = ListeCourses(
        validation:
            ValidationCourses(achetes: {}, rendements: [], coutCentimes: 1000));

    Future<void> afficher(
      WidgetTester tester, {
      Stream<ListeCourses?>? courses,
      Partageur? partager,
    }) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: _evenement,
          tableau: Stream.value(_jeu()),
          produits: Stream.value(_produits),
          gymnases: Stream.value(_gymnases),
          stocks: Stream.value(_stocks),
          courses: courses,
          partager: partager ?? (_, _) async {},
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

    testWidgets('exporter : le fichier porte le bon nom et les chiffres de l’écran',
        (tester) async {
      String? nom, contenu;
      await afficher(tester,
          courses: Stream.value(validee),
          partager: (n, c) async {
            nom = n;
            contenu = c;
          });
      await tester.tap(find.byKey(const Key('exporter_csv')));
      await tester.pump();
      expect(nom, 'bilan-tournoi-d-automne-2026-10-03.csv');
      expect(contenu, contains('Total des ventes;22,00'));
      expect(contenu, contains('Coût des courses;10,00\r\nRésultat;12,00'));
      // Vue d'un gymnase : son fichier, sans coût.
      await tester.tap(find.byKey(const Key('vue_g2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('exporter_csv')));
      await tester.pump();
      expect(contenu, contains('Vue;Gymnase B'));
      expect(contenu, contains('Total des ventes;11,50'));
      expect(contenu, isNot(contains('Coût')));
    });

    testWidgets('un partage qui échoue affiche un message', (tester) async {
      await afficher(tester, partager: (_, _) async => throw Exception('non'));
      await tester.tap(find.byKey(const Key('exporter_csv')));
      await tester.pump();
      expect(find.byKey(const Key('erreur_export')), findsOneWidget);
    });
  });
}
