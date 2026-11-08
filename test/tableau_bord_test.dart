import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/tableau_bord.dart';
import 'package:le_comptoir/ticket.dart';

// Mission « Ergonomie de la gestion », étape E3 (décision 62) : le tableau de bord
// en trois temps. Logique pure : l'onglet ouvert, les quatre tâches d'Avant, « À surveiller ».

Evenement _ev(String statut,
        {double nbJours = 2, bool verifiee = false}) =>
    Evenement(
      id: 'e1',
      nom: 'Tournoi',
      date: '2026-11-07',
      statut: statut,
      modes: const ['carte'],
      menuNom: 'Menu',
      nbJours: nbJours,
      previsionVerifiee: verifiee,
    );

const _gA = Gymnase('gA', 'Gymnase A', 40);
const _gB = Gymnase('gB', 'Gymnase B');

TacheAvant _tache(List<TacheAvant> l, String cle) =>
    l.firstWhere((t) => t.cle == cle);

List<TacheAvant> _taches({
  Evenement? ev,
  List<Gymnase> gymnases = const [_gA, _gB],
  Map<String, Map<String, StockDepart>> stocks = const {},
  int? series = 0,
}) =>
    tachesAvant(
      ev: ev ?? _ev('en_preparation'),
      gymnases: gymnases,
      stocksDepart: stocks,
      seriesValidees: series,
    );

void main() {
  group("l'onglet ouvert d'emblée suit l'état de l'événement", () {
    test('en préparation : Avant', () {
      expect(ongletInitial(_ev('en_preparation')), OngletEvenement.avant);
    });

    test('en cours : Pendant', () {
      expect(ongletInitial(_ev('en_cours')), OngletEvenement.pendant);
    });

    test('clôturé : Après', () {
      expect(ongletInitial(_ev('cloture')), OngletEvenement.apres);
    });
  });

  group('Avant : quatre tâches, une règle « faite » chacune', () {
    test('rien de fait au départ : 0 sur 4', () {
      final t = _taches(gymnases: const [_gA, _gB]);
      expect(t.map((x) => x.cle), ['stock', 'personnes', 'prevision', 'courses']);
      expect(t.where((x) => x.faite), isEmpty);
      expect(_tache(t, 'stock').detail, 'Aucun produit compté');
      expect(_tache(t, 'personnes').detail, 'À compléter : Gymnase B');
      expect(_tache(t, 'prevision').detail, 'À vérifier');
      expect(_tache(t, 'courses').detail, 'Pas encore de série validée');
    });

    test('stock de départ : fait dès qu’un produit est compté, dans un gymnase', () {
      final t = _taches(stocks: const {
        'gA': {'soda': StockDepart(6)},
      });
      expect(_tache(t, 'stock').faite, isTrue);
      expect(_tache(t, 'stock').detail, '1 produit compté');
    });

    test('personnes et durée : faites seulement si chaque gymnase a ses personnes', () {
      final partiel = _taches(gymnases: const [Gymnase('gA', 'Gymnase A', 40), _gB]);
      expect(_tache(partiel, 'personnes').faite, isFalse);
      expect(_tache(partiel, 'personnes').detail, 'À compléter : Gymnase B');

      final tous = _taches(
        ev: _ev('en_preparation', nbJours: 2),
        gymnases: const [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B', 80)],
      );
      expect(_tache(tous, 'personnes').faite, isTrue);
      expect(_tache(tous, 'personnes').detail, '120 personnes · 2 jours');
    });

    test('prévision : faite quand « C\'est vérifié » a été appuyé', () {
      final t = _taches(ev: _ev('en_preparation', verifiee: true));
      expect(_tache(t, 'prevision').faite, isTrue);
      expect(_tache(t, 'prevision').detail, 'Vérifiée');
    });

    test('courses : faites dès une série validée, réservées sans vue complète', () {
      expect(_tache(_taches(series: 1), 'courses').faite, isTrue);
      expect(_tache(_taches(series: 1), 'courses').detail, '1 série validée');
      expect(_tache(_taches(series: 2), 'courses').detail, '2 séries validées');
      final reservee = _taches(series: null);
      expect(_tache(reservee, 'courses').faite, isFalse);
      expect(_tache(reservee, 'courses').detail, 'Réservé au responsable');
    });

    test('avancement : le compte des tâches faites sur quatre', () {
      final t = _taches(
        ev: _ev('en_preparation', nbJours: 3, verifiee: true),
        gymnases: const [Gymnase('gA', 'Gymnase A', 40)],
        stocks: const {'gA': {'soda': StockDepart(6)}},
        series: 1,
      );
      expect(t.where((x) => x.faite).length, 4);
      expect(t.length, 4);
    });
  });

  test('durée affichée sans zéro inutile', () {
    expect(formaterJours(2), '2');
    expect(formaterJours(2.5), '2,5');
    expect(formaterJours(0.5), '0,5');
  });

  group('À surveiller : épuisé, vide, stock bas ; le reste n’y est pas', () {
    const soda = ProduitEvenement('soda', 'Soda', 100, null);
    const cafe = ProduitEvenement('cafe', 'Café', 150, null);
    const croque = ProduitEvenement('croque', 'Croque', 300, null);

    test('ordre : épuisé, puis vide, puis stock bas ; normal et aucun exclus', () {
      final liste = aSurveiller(
        produits: const [soda, cafe, croque],
        gymnases: const [_gA],
        etats: const {
          'gA': {
            'soda': EtatStock.bas,
            'cafe': EtatStock.epuise,
            'croque': EtatStock.normal,
          },
        },
      );
      expect(liste.map((x) => x.produitId), ['cafe', 'soda']);
      expect(liste.first.etat, EtatStock.epuise);
      expect(liste.first.nomGymnase, 'Gymnase A');
    });

    test('rien à surveiller : liste vide', () {
      expect(
        aSurveiller(
          produits: const [soda],
          gymnases: const [_gA],
          etats: const {'gA': {'soda': EtatStock.normal}},
        ),
        isEmpty,
      );
    });

    test('un produit épuisé dans deux gymnases donne deux lignes', () {
      final liste = aSurveiller(
        produits: const [soda],
        gymnases: const [_gA, _gB],
        etats: const {
          'gA': {'soda': EtatStock.epuise},
          'gB': {'soda': EtatStock.vide},
        },
      );
      expect(liste.map((x) => x.gymnaseId), ['gA', 'gB']);
    });
  });
}
