import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_evenements.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/ecran_caisse.dart';
import 'package:le_comptoir/ecran_courses.dart';
import 'package:le_comptoir/ecran_gymnases.dart';
import 'package:le_comptoir/ecran_stock_depart.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/theme.dart';
import 'package:le_comptoir/ticket.dart';
import 'package:le_comptoir/unites_affichees.dart';

// Mission A9 (décision 83) : l'unité d'achat et l'unité de vente à côté de chaque stock.
// Le stock est compté en unité de vente ; seul l'affichage est testé ici.

const _litre = FicheProduit(type: 'litre', verresParLitre: 4);
const _gateau = FicheProduit(type: 'part', partsParEntier: 8);

const _coca = ProduitEvenement('coca', 'Coca', 150, 24, fiche: _litre);
const _tarte = ProduitEvenement('tarte', 'Tarte', 250, 16,
    fiche: FicheProduit(type: 'part', partsParEntier: 8, famille: 'fait_maison'));

/// Le texte d'une clé : celle du Text lui-même, ou d'une ligne d'unités qui le contient.
String _t(WidgetTester tester, String cle) {
  final f = find.byKey(Key(cle));
  final w = tester.widget(f);
  if (w is Text) return w.data!;
  return tester.widget<Text>(find.descendant(of: f, matching: find.byType(Text))).data!;
}

void main() {
  group('libelleStockUnites (critère 2)', () {
    test('au litre : 24 verres à 4 verres par litre = 6 L', () {
      expect(libelleStockUnites(_litre, 24), '6 L · 24 verres');
    });

    test('au litre : arrondis comme nombrePourSaisie (10 verres = 2,5 L)', () {
      expect(libelleStockUnites(_litre, 10), '2,5 L · 10 verres');
      expect(libelleStockUnites(_litre, 1), '0,25 L · 1 verre');
      expect(
          libelleStockUnites(const FicheProduit(type: 'litre', verresParLitre: 3), 1),
          '0,333 L · 1 verre');
    });

    test('à la part : 16 parts à 8 parts par gâteau = 2 gâteaux', () {
      expect(libelleStockUnites(_gateau, 16), '2 gâteaux · 16 parts');
      expect(libelleStockUnites(_gateau, 8), '1 gâteau · 8 parts');
      expect(libelleStockUnites(_gateau, 12), '1,5 gâteau · 12 parts');
    });

    test('fiche incomplète : l\'unité de vente seule', () {
      expect(libelleStockUnites(const FicheProduit(type: 'litre'), 24), '24 verres');
      expect(libelleStockUnites(const FicheProduit(type: 'part'), 16), '16 parts');
      expect(libelleStockUnites(const FicheProduit(type: 'part'), 1), '1 part');
    });

    test('produit à l\'unité ou composé : la quantité seule', () {
      expect(libelleStockUnites(FicheProduit.unite, 24), '24');
      expect(libelleStockUnites(const FicheProduit(type: 'compose'), 5), '5');
      expect(aUnitesAffichees(FicheProduit.unite), isFalse);
      expect(aUnitesAffichees(_litre), isTrue);
    });
  });

  group('un écran par écran (critère 1)', () {
    testWidgets('Stock de départ : 24 verres = 6 L, 16 parts = 2 gâteaux',
        (tester) async {
      const gymnases = [Gymnase('gA', 'Gymnase A', 40)];
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: themeComptoir(),
        home: EcranStockDepart(
          evenement: Stream.value(const Evenement(
              id: 'e',
              nom: 'Tournoi',
              date: '2026-10-03',
              statut: 'en_preparation',
              modes: ['carte'],
              menuNom: 'M',
              nbJours: 3)),
          portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 1),
          gymnases: Stream.value(gymnases),
          produits: Stream.value(const [
            ProduitEvenement('coca', 'Coca', 200, null,
                fiche: FicheProduit(
                    type: 'litre', verresParLitre: 4, famille: 'boissons_fraiches')),
            _tarte,
          ]),
          stocks: Stream.value({
            'gA': {'coca': const StockDepart(24), 'tarte': const StockDepart(16)},
          }),
          definirStock: (g, p, q) async {},
          onVoirGymnases: () {},
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('entete_famille_boissons_fraiches')));
      await tester.tap(find.byKey(const Key('entete_famille_fait_maison')));
      await tester.pump();
      expect(_t(tester, 'unites_depart_gA_coca'), '6 L · 24 verres');
      expect(_t(tester, 'unites_depart_gA_tarte'), '2 gâteaux · 16 parts');
    });

    testWidgets('Gymnases et stock : la ligne d\'un produit suivi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LigneStock(
            produit: _coca,
            gymnaseId: 'gA',
            etat: EtatStock.normal,
            vendu: 0,
            onAjouter: () {},
            onCorriger: () {},
            onSuivre: (_) {},
            onVide: (_) {},
          ),
        ),
      ));
      expect(_t(tester, 'stock_gA_coca'), 'Stock : 24');
      expect(_t(tester, 'unites_gA_coca'), '6 L · 24 verres');
    });

    testWidgets('caisse : le stock restant en litres et verres', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: themeComptoir(),
        home: EcranCaisse(
          produits: const [Produit('coca', 'Coca', 150, 24)],
          fiches: const {'coca': _litre},
        ),
      ));
      expect(_t(tester, 'stock_coca'), 'Stock : 24');
      expect(_t(tester, 'unites_coca'), '6 L · 24 verres');
    });

    testWidgets('Bilan : le stock restant en litres, verres, gâteaux et parts',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: const Evenement(
              id: 'e',
              nom: 'Tournoi',
              date: '2026-10-03',
              statut: 'en_cours',
              modes: ['especes'],
              menuNom: 'M'),
          tableau: Stream.value(TableauDeBord.depuis(const <ResumeCaisse>[])),
          produits: Stream.value(const [_coca, _tarte]),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(_t(tester, 'unites_bilan_produit_coca'), '6 L · 24 verres');
      expect(_t(tester, 'unites_bilan_produit_tarte'), '2 gâteaux · 16 parts');
    });

    // A8 : le bloc « Quantités par produit » est en Préparation (même widget, même texte).
    testWidgets('Préparation : « En stock » complété par les unités', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: themeComptoir(),
        home: Scaffold(
          body: SingleChildScrollView(
              child: QuantitesParProduit(depot: _FauxDepot(), evenementId: 'e')),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_t(tester, 'info_g1_coca'), startsWith('En stock : 24'));
      expect(_t(tester, 'unites_g1_coca'), '6 L · 24 verres');
    });
  });
}

class _FausseCaisses implements DepotCaisses {
  @override
  Stream<TableauDeBord> suivreTableauDeBord({Set<String>? gymnaseIds}) =>
      Stream.value(TableauDeBord.depuis(const <ResumeCaisse>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxDepot implements DepotEvenements {
  @override
  Stream<Evenement?> suivreEvenement(String id) => Stream.value(const Evenement(
        id: 'e',
        nom: 'Tournoi',
        date: '2026-10-03',
        statut: 'en_cours',
        modes: ['especes'],
        menuNom: 'Menu',
      ));

  @override
  Stream<List<ProduitEvenement>> suivreProduits(String id,
          {String? gymnaseId, Set<String>? gymnases}) =>
      Stream.value(const [
        ProduitEvenement('coca', 'Coca', 150, null,
            fiche: FicheProduit(
                type: 'litre', conso: 2, verresParLitre: 4, rayon: 'boissons')),
      ]);

  @override
  Stream<List<Gymnase>> suivreGymnases(String id) =>
      Stream.value([Gymnase('g1', 'Gymnase A', 80)]);

  @override
  Stream<Map<String, Map<String, EtatStock>>> suivreEtats(String id,
          {Set<String>? gymnases}) =>
      Stream.value(const {});

  @override
  Stream<Map<String, Map<String, int>>> suivreStocksParGymnase(String id,
          {Set<String>? gymnases}) =>
      Stream.value(const {
        'g1': {'coca': 24}
      });

  @override
  Stream<Map<String, Prevision>> suivrePrevisions(String evenementId) =>
      Stream.value(const {});

  @override
  Stream<ListeCourses?> suivreListeCourses(String evenementId) => Stream.value(
      const ListeCourses(lignes: [LigneCourse('g1', 'coca', 100)]));

  @override
  DepotCaisses caisses(String evenementId) => _FausseCaisses();

  @override
  Future<void> enregistrerListeCourses(String evenementId, ListeCourses l) async {}

  @override
  Future<void> cocherArticle(String evenementId, String cle, bool coche) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
