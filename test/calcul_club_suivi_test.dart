import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';

// Calcul du club, étape V3 : les courses et la prévision suivent le calcul du club quand il
// existe, et gardent exactement l'ancien calcul sans lui (critère 4 de V3).
// Chiffres du classeur d'origine (aucun nom) : croque standard, Gymnase 1 (g1) et Gymnase 2 (g2).
// G1 : 70 (33,32 + 36,4 = 69,72) ; G2 : 74 (39,48 + 33,88 = 73,36).

const _calcul = CalculClub(
  repas: {
    'g1': {
      1: RepasGymnaseJour(
          joueusesMidi: 49, joueusesSoir: 49, benevolesMidi: 10, benevolesSoir: 11),
      2: RepasGymnaseJour(
          joueusesMidi: 56, joueusesSoir: 56, benevolesMidi: 9, benevolesSoir: 9),
    },
    'g2': {
      1: RepasGymnaseJour(
          joueusesMidi: 63, joueusesSoir: 63, benevolesMidi: 7, benevolesSoir: 8),
      2: RepasGymnaseJour(
          joueusesMidi: 56, joueusesSoir: 56, benevolesMidi: 6, benevolesSoir: 3),
    },
  },
  groupes: [
    GroupeConso(
      nom: 'Plat',
      pourcentages: {1: 0.70, 2: 0.80},
      produits: {
        'croque': {1: 0.40, 2: 0.35},
      },
    ),
  ],
);

const _croque = ProduitEvenement('croque', 'Croque-monsieur', 300, null,
    fiche: FicheProduit(famille: 'croques', conso: 0.65));

void main() {
  group('point d\'entrée des quantités', () {
    test('sans calcul : l\'ancien calcul (100 personnes, 2 jours, 0,65 = 130)', () {
      expect(
          quantitePrevueClub(
              calcul: null,
              gymnaseId: 'g1',
              produitId: 'croque',
              personnes: 100,
              jours: 2,
              conso: 0.65),
          130);
    });

    test('avec calcul : le calcul du club, quel que soit le nombre de personnes', () {
      expect(
          quantitePrevueClub(
              calcul: _calcul,
              gymnaseId: 'g2',
              produitId: 'croque',
              personnes: 0,
              jours: 2,
              conso: 0.65),
          74);
    });

    test('produit hors groupe : l\'ancien calcul, même avec un calcul', () {
      expect(
          quantitePrevueClub(
              calcul: _calcul,
              gymnaseId: 'g1',
              produitId: 'coca',
              personnes: 100,
              jours: 2,
              conso: 2),
          400);
    });

    test('gymnase sans repas détaillés : l\'ancien calcul', () {
      expect(
          quantitePrevueClub(
              calcul: _calcul,
              gymnaseId: 'g9',
              produitId: 'croque',
              personnes: 100,
              jours: 2,
              conso: 0.65),
          130);
    });

    test('total pour le tournoi : somme des gymnases (70 + 74)', () {
      expect(
          totalClubProduit(
              calcul: _calcul,
              produitId: 'croque',
              personnesParGymnase: {'g1': 100, 'g2': 20},
              jours: 2,
              conso: 0.65),
          144);
    });

    test('total pour le tournoi : un gymnase sans détail garde son ancien calcul', () {
      // G3 : 20 personnes, 2 jours, 0,65 = 26 (ancien calcul).
      expect(
          totalClubProduit(
              calcul: _calcul,
              produitId: 'croque',
              personnesParGymnase: {'g1': 100, 'g3': 20},
              jours: 2,
              conso: 0.65),
          96);
    });

    test('total pour le tournoi : null sans calcul ou pour un produit hors groupe', () {
      expect(
          totalClubProduit(
              calcul: null,
              produitId: 'croque',
              personnesParGymnase: {'g1': 100},
              jours: 2,
              conso: 0.65),
          isNull);
      expect(
          totalClubProduit(
              calcul: _calcul,
              produitId: 'coca',
              personnesParGymnase: {'g1': 100},
              jours: 2,
              conso: 2),
          isNull);
    });
  });

  group('courses', () {
    final produits = [_croque];
    final deuxGymnases = [Gymnase('g1', 'Gymnase 1', 100), Gymnase('g2', 'Gymnase 2', 20)];

    test('sans calcul : la liste de départ est celle d\'avant (130 et 26)', () {
      final liste = listeParDefaut(
          produits: produits, gymnases: deuxGymnases, jours: 2, calcul: null);
      final quantites = {for (final l in liste.lignes) l.gymnaseId: l.quantite};
      expect(quantites, {'g1': 130, 'g2': 26});
    });

    test('avec calcul : les quantités du club, même sans personnes réglées', () {
      final sansPersonnes = [Gymnase('g1', 'Gymnase 1', 0), Gymnase('g2', 'Gymnase 2', 0)];
      final liste = listeParDefaut(
          produits: produits, gymnases: sansPersonnes, jours: 2, calcul: _calcul);
      final quantites = {for (final l in liste.lignes) l.gymnaseId: l.quantite};
      expect(quantites, {'g1': 70, 'g2': 74});
    });

    test('sans calcul et sans personnes : rien, comme avant', () {
      final sansPersonnes = [Gymnase('g1', 'Gymnase 1', 0), Gymnase('g2', 'Gymnase 2', 0)];
      final liste =
          listeParDefaut(produits: produits, gymnases: sansPersonnes, jours: 2);
      expect(liste.lignes, isEmpty);
    });

    test('quantité à acheter : le stock se retire de la quantité prévue du club', () {
      expect(
          quantiteAPrevoir(
              personnes: 0, jours: 2, conso: 0.65, stock: 10, prevue: 70),
          60);
    });
  });

  group('prévision', () {
    final gymnases = [Gymnase('g1', 'Gymnase 1', 100), Gymnase('g2', 'Gymnase 2', 20)];

    Evenement ev() => Evenement(
        id: 'e',
        nom: 'Tournoi',
        date: '2026-10-03',
        statut: 'en_preparation',
        modes: const ['carte'],
        menuNom: 'M',
        nbJours: 2,
        previsionVerifiee: false);

    Future<void> ouvrir(WidgetTester tester, CalculClub? calcul) async {
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranPrevision(
          evenement: Stream.value(ev()),
          portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
          gymnases: Stream.value(gymnases),
          produits: Stream.value(const [_croque]),
          previsions: Stream.value(const {}),
          definirPrevision: (p, c) async {},
          chargerPasses: () async => const EvenementsPasses([], 0),
          appliquerPasse: (r) async {},
          revenirAuMenu: () async {},
          chargerReferences: () async => const [],
          appliquerReference: (r) async {},
          calcul: calcul == null ? null : Stream<CalculClub?>.value(calcul),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('sans calcul : le total est celui d\'avant (120 personnes, 2 jours : 156)',
        (tester) async {
      await ouvrir(tester, null);
      final texte = tester.widget<Text>(find.byKey(const Key('total_croque'))).data!;
      expect(texte, contains('156'));
    });

    testWidgets('avec calcul : le total suit le calcul du club (70 + 74 = 144)',
        (tester) async {
      await ouvrir(tester, _calcul);
      final texte = tester.widget<Text>(find.byKey(const Key('total_croque'))).data!;
      expect(texte, contains('144'));
    });
  });
}
