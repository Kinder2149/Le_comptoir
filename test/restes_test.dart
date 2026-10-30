import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_restes.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/restes.dart';

// Chantier Menu, événement et courses, étape B5 : stock gardé à la clôture.
void main() {
  group('identifiant et reprise des restes', () {
    test('le même gymnase et le même produit donnent le même identifiant', () {
      expect(idReste('Gymnase 1', 'Café'), 'gymnase-1__cafe');
      expect(idReste(' gymnase 1 ', 'CAFÉ'), 'gymnase-1__cafe');
      expect(idReste('Gymnase 2', 'Café'), isNot(idReste('Gymnase 1', 'Café')));
      expect(idReste('Gymnase 1', 'Coca Zéro'), 'gymnase-1__coca-zero');
    });

    test('un nom sans lettre ni chiffre garde un identifiant valide', () {
      expect(idReste('***', '---'), 'x__x');
      expect(RegExp(r'^[a-z0-9_-]{1,200}$').hasMatch(idReste('Bière à 2 €', 'Œufs')),
          isTrue);
    });

    const restes = [
      Reste(nomGymnase: 'Gymnase 1', nomProduit: 'Soda', quantite: 24),
      Reste(nomGymnase: 'Gymnase 2', nomProduit: 'Café', quantite: 8),
      Reste(nomGymnase: 'Gymnase 3', nomProduit: 'Café', quantite: 5),
    ];

    test('le bon gymnase et le bon produit par leur nom, sans casse ni accents', () {
      final r = repriseDesRestes(
        restes: restes,
        gymnases: {'a': 'GYMNASE 1', 'b': ' gymnase 2 '},
        produits: {'p1': 'soda', 'p2': 'Café', 'p3': 'Thé'},
      );
      expect(r.map((x) => (x.gymnaseId, x.produitId, x.reste.quantite)),
          [('a', 'p1', 24), ('b', 'p2', 8)]);
    });

    test('un gymnase ou un produit inconnu ne reprend rien, le reste attend', () {
      final r = repriseDesRestes(
        restes: restes,
        gymnases: {'a': 'Annexe'},
        produits: {'p1': 'Soda'},
      );
      expect(r, isEmpty);
    });

    test('un reste n\'est repris qu\'une fois, même si deux gymnases portent le même nom', () {
      final r = repriseDesRestes(
        restes: restes,
        gymnases: {'a': 'Gymnase 1', 'b': 'gymnase 1'},
        produits: {'p1': 'Soda', 'p2': 'SODA'},
      );
      expect(r.length, 1);
      expect(r.single.gymnaseId, 'a');
      expect(r.single.produitId, 'p1');
    });

    test('une quantité nulle n\'est pas reprise', () {
      final r = repriseDesRestes(
        restes: const [Reste(nomGymnase: 'G', nomProduit: 'P', quantite: 0)],
        gymnases: {'a': 'G'},
        produits: {'p': 'P'},
      );
      expect(r, isEmpty);
    });

    test('litres et verres', () {
      expect(verresDepuisLitres(6, 4), 24);
      expect(verresDepuisLitres(6.5, 4), 26);
      expect(verresDepuisLitres(0.1, 4), 0);
      expect(litresDepuisVerres(26, 4), 6.5);
    });
  });

  group('candidats au report', () {
    const g1 = Gymnase('g1', 'Gymnase 1');
    const g2 = Gymnase('g2', 'Gymnase 2');
    final soda = ProduitEvenement('soda', 'Soda', 100, null,
        fiche: const FicheProduit(type: 'litre', verresParLitre: 4));
    const croque = ProduitEvenement('croque', 'Croque', 100, null);

    test('seuls les produits avec du stock, gymnase par gymnase', () {
      final c = candidatsRestes(
        gymnases: const [g1, g2],
        produits: [soda, croque],
        stocks: {
          'g1': {'soda': 24, 'croque': 0},
          'g2': {'croque': 7, 'soda': -2},
        },
      );
      expect(c.map((x) => x.cle), ['g1_soda', 'g2_croque']);
      expect(c.first.verresParLitre, 4);
      expect(c.last.verresParLitre, isNull);
      expect(c.first.id, 'gymnase-1__soda');
    });

    test('rien à garder sans stock suivi', () {
      expect(
          candidatsRestes(
              gymnases: const [g1], produits: [soda], stocks: const {}),
          isEmpty);
    });
  });

  group('feuille « Garder pour le prochain événement »', () {
    const soda = CandidatReste(
      gymnaseId: 'g1',
      nomGymnase: 'Gymnase 1',
      produitId: 'soda',
      nomProduit: 'Soda',
      quantite: 26,
      verresParLitre: 4,
    );
    const croque = CandidatReste(
      gymnaseId: 'g1',
      nomGymnase: 'Gymnase 1',
      produitId: 'croque',
      nomProduit: 'Croque',
      quantite: 7,
    );
    const cafe2 = CandidatReste(
      gymnaseId: 'g2',
      nomGymnase: 'Gymnase 2',
      produitId: 'cafe',
      nomProduit: 'Café',
      quantite: 8,
      verresParLitre: 4,
    );

    Future<ChoixRestes?> ouvrir(WidgetTester tester) async {
      ChoixRestes? choix;
      var fini = false;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('ouvrir'),
              onPressed: () async {
                choix = await demanderRestes(context, const [soda, croque, cafe2]);
                fini = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('ouvrir')));
      await tester.pumpAndSettle();
      expect(fini, isFalse);
      return choix;
    }

    testWidgets('rien n\'est coché d\'avance ; les litres sont proposés en litres', (tester) async {
      await ouvrir(tester);
      expect(find.text('Garder pour le prochain événement ?'), findsOneWidget);
      for (final k in ['g1_soda', 'g1_croque', 'g2_cafe']) {
        expect(tester.widget<Checkbox>(find.byKey(Key('reste_coche_$k'))).value, isFalse);
        expect(tester.widget<TextField>(find.byKey(Key('reste_qte_$k'))).enabled, isFalse);
      }
      expect(tester.widget<TextField>(find.byKey(const Key('reste_qte_g1_soda'))).controller!.text,
          '6,5'); // 26 verres / 4
      expect(tester.widget<TextField>(find.byKey(const Key('reste_qte_g1_croque'))).controller!.text,
          '7');
      expect(find.text('Gymnase 1'), findsOneWidget);
      expect(find.text('Gymnase 2'), findsOneWidget);
    });

    testWidgets('on coche, on corrige, on garde : litres en verres, le reste est écarté', (tester) async {
      ChoixRestes? choix;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('ouvrir'),
            onPressed: () async =>
                choix = await demanderRestes(context, const [soda, croque, cafe2]),
            child: const Text('ouvrir'),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('ouvrir')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reste_coche_g1_soda')));
      await tester.tap(find.byKey(const Key('reste_coche_g2_cafe')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('reste_qte_g1_soda')), '6');
      await tester.enterText(find.byKey(const Key('reste_qte_g2_cafe')), '2');
      await tester.tap(find.byKey(const Key('garder_restes')));
      await tester.pumpAndSettle();
      expect(choix!.gardes, const [
        Reste(nomGymnase: 'Gymnase 1', nomProduit: 'Soda', quantite: 24),
        Reste(nomGymnase: 'Gymnase 2', nomProduit: 'Café', quantite: 8),
      ]);
      expect(choix!.ecartes, ['gymnase-1__croque']);
    });

    testWidgets('quantité illisible ou nulle : message, la feuille reste ouverte', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.byKey(const Key('reste_coche_g1_croque')));
      await tester.pump();
      for (final saisie in ['0', 'abc', '', '2,5', '-3']) {
        await tester.enterText(find.byKey(const Key('reste_qte_g1_croque')), saisie);
        await tester.tap(find.byKey(const Key('garder_restes')));
        await tester.pump();
        expect(find.byKey(const Key('erreur_restes')), findsOneWidget, reason: saisie);
        expect(find.text('Quantité à corriger : Croque (Gymnase 1).'), findsOneWidget);
      }
      expect(find.text('Garder pour le prochain événement ?'), findsOneWidget);
    });

    testWidgets('« Ne rien garder » écarte tout ; « Retour » annule', (tester) async {
      ChoixRestes? choix;
      var retour = false;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('ouvrir'),
            onPressed: () async {
              choix = await demanderRestes(context, const [soda, croque]);
              retour = choix == null;
            },
            child: const Text('ouvrir'),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('ouvrir')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ne_rien_garder')));
      await tester.pumpAndSettle();
      expect(choix!.gardes, isEmpty);
      expect(choix!.ecartes, ['gymnase-1__soda', 'gymnase-1__croque']);

      await tester.tap(find.byKey(const Key('ouvrir')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('retour_restes')));
      await tester.pumpAndSettle();
      expect(retour, isTrue);
    });
  });
}
