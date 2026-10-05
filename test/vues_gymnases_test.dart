import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

// Deux gymnases, bilans calculés À LA MAIN.
//
//   Gymnase A (g1) — Léa (caisse clôturée)
//     L1  sam 03/10 14:05  espèces  2 croque-monsieur            = 6,00
//     L2  sam 03/10 14:40  carte    3 cafés                      = 4,50
//     L3  dim 04/10 14:20  carte    2 sodas (ANNULÉE)            = 3,00
//   Gymnase B (g2) — Max (caisse ouverte)
//     M1  sam 03/10 14:55  carte    2 cafés                      = 3,00
//     M2  dim 04/10 10:50  espèces  2 croque-monsieur            = 6,00
//     M3  dim 04/10 10:15  chèque   1 gâteau                     = 2,50
//
//   Stocks restants : A : croque 4, gâteau 6 — B : croque 3, gâteau 1 (café : pas de suivi).
//
//   VUE A       : 10,50 € en 2 ventes, 1 annulée.
//     modes : espèces 6,00 · carte 4,50 · chèque 0 ; café 3 (4,50) · croque 2 (6,00)
//     jours : 03/10 → 2 ventes 10,50 ; heures : 14 h → 2 ventes ; caisses : Léa seule (clôturée).
//   VUE B       : 11,50 € en 3 ventes, 0 annulée.
//     modes : espèces 6,00 · carte 3,00 · chèque 2,50 ; café 2 (3,00) · croque 2 (6,00) · gâteau 1 (2,50)
//     jours : 03/10 → 1 vente 3,00 · 04/10 → 2 ventes 8,50 ; heures : 10 h → 2 · 14 h → 1
//     caisses : Max seul (ouverte).
//   VUE COMMUNE : 22,00 € en 5 ventes, 1 annulée (A + B).
//     modes : espèces 12,00 · carte 7,50 · chèque 2,50 ; café 5 (7,50) · croque 4 (12,00) · gâteau 1 (2,50)
//     jours : 03/10 → 3 ventes 13,50 · 04/10 → 2 ventes 8,50 ; heures : 14 h → 3 · 10 h → 2
//     stock : croque 7 (A 4 + B 3) · gâteau 7 (A 6 + B 1) · café sans suivi.
DateTime _t(int jour, int h, int m) => DateTime(2026, 10, jour, h, m);

Vente _v(String id, List<LigneVente> lignes, String mode, DateTime quand,
    {bool annulee = false, DateTime? annuleeLe, String? par}) {
  return Vente(
    id: id,
    lignes: lignes,
    totalCentimes:
        lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite),
    mode: mode,
    creeLe: quand,
    enAttente: false,
    annulee: annulee,
    annuleeLe: annuleeLe,
    annuleeParPrenom: par,
  );
}

LigneVente _l(String id, String nom, int prix, int q) =>
    LigneVente(id, nom, prix, q);

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

const _modes = ['especes', 'carte', 'cheque'];

TableauDeBord _jeu() {
  const lea =
      Caisse(uid: 'lea', gymnaseId: 'g1', prenom: 'Lea', statut: 'cloturee');
  const max =
      Caisse(uid: 'max', gymnaseId: 'g2', prenom: 'Max', statut: 'ouverte');
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

Bilan _bilan(String? gymnaseId) => Bilan.depuis(_jeu(), _produits, _modes,
    gymnaseId: gymnaseId, stocks: _stocks);

void main() {
  group('vue distincte du gymnase A', () {
    final b = _bilan('g1');

    test('totaux', () {
      expect((b.totalCentimes, b.nbVentes, b.nbAnnulees), (1050, 2, 1));
      expect(b.parMode, {'especes': 600, 'carte': 450, 'cheque': 0});
    });

    test('produits, stock du gymnase A seulement', () {
      expect([for (final p in b.produits) (p.nom, p.quantite, p.montantCentimes)], [
        ('Café', 3, 450),
        ('Croque-monsieur', 2, 600),
        ('Gâteau', 0, 0),
        ('Salade', 0, 0),
        ('Soda', 0, 0),
      ]);
      final stock = {for (final p in b.produits) p.nom: p.stock};
      expect(stock, {
        'Café': null,
        'Croque-monsieur': 4,
        'Gâteau': 6,
        'Salade': null,
        'Soda': null,
      });
      expect(b.produits.every((p) => p.detailStock.isEmpty), isTrue);
    });

    test('caisses, jours, heures, annulations', () {
      expect([for (final c in b.caisses) (c.id, c.gymnaseId, c.totalCentimes)],
          [('lea__g1', 'g1', 1050)]);
      expect(b.caissesNonCloturees, isEmpty);
      expect([for (final j in b.jours) (j.jour, j.nbVentes, j.totalCentimes)],
          [('2026-10-03', 2, 1050)]);
      expect([for (final h in b.heures) (h.heure, h.nbVentes)], [(14, 2)]);
      expect(b.annulations.length, 1);
    });
  });

  group('vue distincte du gymnase B', () {
    final b = _bilan('g2');

    test('totaux', () {
      expect((b.totalCentimes, b.nbVentes, b.nbAnnulees), (1150, 3, 0));
      expect(b.parMode, {'especes': 600, 'carte': 300, 'cheque': 250});
    });

    test('produits, stock du gymnase B seulement', () {
      expect([for (final p in b.produits) (p.nom, p.quantite, p.montantCentimes)], [
        ('Café', 2, 300),
        ('Croque-monsieur', 2, 600),
        ('Gâteau', 1, 250),
        ('Salade', 0, 0),
        ('Soda', 0, 0),
      ]);
      expect({for (final p in b.produits) p.nom: p.stock}, {
        'Café': null,
        'Croque-monsieur': 3,
        'Gâteau': 1,
        'Salade': null,
        'Soda': null,
      });
    });

    test('caisses, jours, heures, annulations', () {
      expect([for (final c in b.caisses) (c.id, c.gymnaseId)], [('max__g2', 'g2')]);
      expect(b.caissesNonCloturees, ['Max']);
      expect([for (final j in b.jours) (j.jour, j.nbVentes, j.totalCentimes)],
          [('2026-10-03', 1, 300), ('2026-10-04', 2, 850)]);
      expect([for (final h in b.heures) (h.heure, h.nbVentes)], [(10, 2), (14, 1)]);
      expect(b.annulations, isEmpty);
    });
  });

  group('vue commune', () {
    final b = _bilan(null);

    test('totaux = A + B', () {
      expect((b.totalCentimes, b.nbVentes, b.nbAnnulees), (2200, 5, 1));
      expect(b.parMode, {'especes': 1200, 'carte': 750, 'cheque': 250});
      expect(b.parMode.values.fold<int>(0, (a, c) => a + c), b.totalCentimes);
    });

    test('produits : quantités additionnées, stock total et détail par gymnase', () {
      expect([for (final p in b.produits) (p.nom, p.quantite, p.montantCentimes)], [
        ('Café', 5, 750),
        ('Croque-monsieur', 4, 1200),
        ('Gâteau', 1, 250),
        ('Salade', 0, 0),
        ('Soda', 0, 0),
      ]);
      expect(b.produits.fold<int>(0, (a, p) => a + p.montantCentimes), 2200);
      final croque = b.produits.firstWhere((p) => p.id == 'croque');
      final gateau = b.produits.firstWhere((p) => p.id == 'gateau');
      final cafe = b.produits.firstWhere((p) => p.id == 'cafe');
      expect(croque.stock, 7);
      expect(croque.detailStock, {'g1': 4, 'g2': 3});
      expect(gateau.stock, 7);
      expect(gateau.detailStock, {'g1': 6, 'g2': 1});
      expect(cafe.stock, isNull);
      expect(cafe.detailStock, isEmpty);
    });

    test('plus et moins vendus', () {
      expect([for (final p in b.plusVendus) p.nom], ['Café', 'Croque-monsieur']);
      expect([for (final p in b.moinsVendus) p.nom], ['Salade', 'Soda']);
    });

    test('caisses des deux gymnases, jours, heures de pointe', () {
      expect([for (final c in b.caisses) c.gymnaseId], ['g1', 'g2']);
      expect(b.caissesNonCloturees, ['Max']);
      expect([for (final j in b.jours) (j.jour, j.nbVentes, j.totalCentimes)],
          [('2026-10-03', 3, 1350), ('2026-10-04', 2, 850)]);
      expect([for (final h in b.heures) (h.heure, h.nbVentes, h.totalCentimes)],
          [(10, 2, 850), (14, 3, 1350)]);
      expect([for (final h in b.heuresDePointe) h.heure], [14, 10]);
      expect(b.annulations.length, 1);
    });
  });

  test('A + B = commun (ventes, modes, produits, jours)', () {
    final a = _bilan('g1'), b = _bilan('g2'), c = _bilan(null);
    expect(a.totalCentimes + b.totalCentimes, c.totalCentimes);
    expect(a.nbVentes + b.nbVentes, c.nbVentes);
    expect(a.nbAnnulees + b.nbAnnulees, c.nbAnnulees);
    for (final m in _modes) {
      expect(a.parMode[m]! + b.parMode[m]!, c.parMode[m]);
    }
    for (final p in c.produits) {
      final qa = a.produits.firstWhere((x) => x.id == p.id).quantite;
      final qb = b.produits.firstWhere((x) => x.id == p.id).quantite;
      expect(qa + qb, p.quantite, reason: p.nom);
    }
    expect(a.jours.fold<int>(0, (s, j) => s + j.nbVentes) +
            b.jours.fold<int>(0, (s, j) => s + j.nbVentes),
        c.jours.fold<int>(0, (s, j) => s + j.nbVentes));
  });

  test('sans stocks fournis, le bilan garde le stock des produits (ancien usage)', () {
    final b = Bilan.depuis(_jeu(), const [
      ProduitEvenement('croque', 'Croque-monsieur', 300, 9),
    ], _modes);
    expect(b.produits.single.stock, 9);
    expect(b.produits.single.detailStock, isEmpty);
  });

  test('le tableau d’un gymnase ne garde que ses caisses', () {
    final t = _jeu().pour('g2');
    expect([for (final c in t.caisses) c.caisse.id], ['max__g2']);
    expect(t.nbVentes, 3);
    expect(_jeu().pour(null).caisses.length, 2);
  });

  const gymnases = [Gymnase('g1', 'Gymnase A'), Gymnase('g2', 'Gymnase B')];
  const evt = Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: 'en_cours',
    modes: _modes,
    menuNom: 'Menu',
    nbGymnases: 2,
  );

  String texte(WidgetTester tester, String cle) =>
      tester.widget<Text>(find.byKey(Key(cle))).data!;

  String contenu(WidgetTester tester, String cle) => tester
      .widgetList<Text>(find.descendant(
          of: find.byKey(Key(cle)), matching: find.byType(Text)))
      .map((t) => t.data!)
      .join(' | ');

  Future<void> grandEcran(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 10000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  group('écran du bilan avec deux gymnases', () {
    Future<void> afficher(WidgetTester tester, {bool commun = true}) async {
      await grandEcran(tester);
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: evt,
          tableau: Stream.value(_jeu()),
          produits: Stream.value(_produits),
          gymnases: Stream.value(gymnases),
          stocks: Stream.value(_stocks),
          commun: commun,
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    testWidgets('commun par défaut, puis chaque gymnase : mêmes chiffres que le calcul à la main',
        (tester) async {
      await afficher(tester);
      expect(find.byKey(const Key('vue_commune')), findsOneWidget);
      expect(contenu(tester, 'bilan_total'), 'Total des ventes | 22,00 € | 5 ventes');
      expect(contenu(tester, 'bilan_produit_croque'), 'Croque-monsieur | 4 vendus | Stock 7 | (Gymnase A : 4 · Gymnase B : 3) | 12,00 €');
      expect(contenu(tester, 'bilan_produit_cafe'), 'Café | 5 vendus | 7,50 €');
      expect(contenu(tester, 'bilan_caisse_lea__g1'), 'Lea | Gymnase A | Clôturée | 2 ventes | 1 annulée | 10,50 €');
      expect(contenu(tester, 'bilan_caisse_max__g2'), 'Max | Gymnase B | Ouverte | 3 ventes | 11,50 €');

      await tester.tap(find.byKey(const Key('vue_g1')));
      await tester.pump();
      expect(contenu(tester, 'bilan_total'), 'Total des ventes | 10,50 € | 2 ventes');
      expect(contenu(tester, 'bilan_produit_croque'), 'Croque-monsieur | 2 vendus | Stock 4 | 6,00 €');
      expect(find.byKey(const Key('bilan_caisse_max__g2')), findsNothing);
      expect(texte(tester, 'bilan_annulees'), 'Ventes annulées : 1');

      await tester.tap(find.byKey(const Key('vue_g2')));
      await tester.pump();
      expect(contenu(tester, 'bilan_total'), 'Total des ventes | 11,50 € | 3 ventes');
      expect(contenu(tester, 'bilan_produit_croque'), 'Croque-monsieur | 2 vendus | Stock 3 | 6,00 €');
      expect(contenu(tester, 'bilan_produit_gateau'), 'Gâteau | 1 vendu | Stock 1 | 2,50 €');
      expect(find.byKey(const Key('bilan_annulees')), findsNothing);

      await tester.tap(find.byKey(const Key('vue_commune')));
      await tester.pump();
      expect(contenu(tester, 'bilan_total'), 'Total des ventes | 22,00 € | 5 ventes');
    });

    testWidgets('sans vue commune (gestionnaire de quelques gymnases) : le premier gymnase',
        (tester) async {
      await afficher(tester, commun: false);
      expect(find.byKey(const Key('vue_commune')), findsNothing);
      expect(find.byKey(const Key('vue_g1')), findsOneWidget);
      expect(contenu(tester, 'bilan_total'), 'Total des ventes | 10,50 € | 2 ventes');
    });

    testWidgets('un seul gymnase : pas de sélecteur, comme avant', (tester) async {
      await grandEcran(tester);
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: evt,
          tableau: Stream.value(_jeu().pour('g1')),
          produits: Stream.value(_produits),
          gymnases: Stream.value(const [Gymnase('g1', 'Gymnase A')]),
          stocks: Stream.value(const {'g1': {'croque': 4}}),
          commun: false,
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.byType(SelecteurVue), findsNothing);
      expect(contenu(tester, 'bilan_total'), 'Total des ventes | 10,50 € | 2 ventes');
      expect(contenu(tester, 'bilan_caisse_lea__g1'), 'Lea | Clôturée | 2 ventes | 1 annulée | 10,50 €');
    });
  });

  group('suivi en direct avec deux gymnases', () {
    testWidgets('vue commune, puis un gymnase', (tester) async {
      await grandEcran(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuiviEnDirect(
              tableau: Stream.value(_jeu()),
              produits: Stream.value(_produits),
              gymnases: Stream.value(gymnases),
              stocks: Stream.value(_stocks),
              onOuvrirCaisse: (_) {},
              maintenant: () => _t(4, 18, 0),
            ),
          ),
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(texte(tester, 'direct_total'), 'Ventes : 5 · 22,00 €');
      expect(texte(tester, 'direct_produit_croque'),
          'Croque-monsieur : 4 vendus · stock 7 (Gymnase A : 4 · Gymnase B : 3)');
      expect(texte(tester, 'gymnase_de_lea__g1'), 'Gymnase A');
      expect(texte(tester, 'gymnase_de_max__g2'), 'Gymnase B');

      await tester.tap(find.byKey(const Key('vue_g2')));
      await tester.pump();
      expect(texte(tester, 'direct_total'), 'Ventes : 3 · 11,50 €');
      expect(texte(tester, 'direct_produit_croque'),
          'Croque-monsieur : 2 vendus · stock 3');
      expect(find.byKey(const Key('caisse_lea__g1')), findsNothing);
      expect(find.byKey(const Key('caisse_max__g2')), findsOneWidget);
      expect(find.byKey(const Key('direct_annulees')), findsNothing);

      await tester.tap(find.byKey(const Key('vue_g1')));
      await tester.pump();
      expect(texte(tester, 'direct_total'), 'Ventes : 2 · 10,50 €');
      expect(texte(tester, 'direct_annulees'), 'Ventes annulées : 1');
    });
  });
}
