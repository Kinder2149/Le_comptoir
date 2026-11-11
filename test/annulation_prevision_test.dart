import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_evenements.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';

// Mission « Annuler un changement de source », T5 (décision 79 a).
// Le scénario complet (source, corrections à la main, annulation) est joué ici sur les
// fonctions pures que le dépôt utilise pour écrire et relire le document d'annulation ; les
// écritures Firestore sont couvertes par tests_regles/annulation_previsions.test.mjs.

/// Ce que la base fait : on efface, puis on écrit (écrire remplace).
Map<String, Prevision> _appliquer(
  Map<String, Prevision> base,
  Map<String, Prevision> ecrire,
  Iterable<String> effacer,
) =>
    {
      for (final e in base.entries)
        if (!effacer.contains(e.key)) e.key: e.value,
    }..addAll(ecrire);

/// Mêmes produits, mêmes chiffres, mêmes sources.
bool _memes(Map<String, Prevision> a, Map<String, Prevision> b) =>
    a.length == b.length &&
    a.entries.every((e) =>
        b[e.key] != null &&
        b[e.key]!.conso == e.value.conso &&
        b[e.key]!.source == e.value.source);

void main() {
  group('scénario d\'annulation (fonctions du dépôt)', () {
    test('source, corrections à la main, annuler = état d\'avant exact', () {
      // Avant le changement : Croque corrigé à la main, Coca au menu (aucune ligne).
      final avant = {'croque': const Prevision(0.8, sourceMain)};
      // Rangé avant le changement de source.
      final doc = lignesAnnulation(avant);
      // « D'après une source » : Croque et Coca reçoivent le chiffre de l'événement passé.
      var base = _appliquer(
          avant,
          {
            'croque': const Prevision(1.2, 'Événement : Tournoi'),
            'coca': const Prevision(2, 'Événement : Tournoi'),
          },
          const []);
      // Corrections à la main après le changement : Coca et un Café ajouté.
      base = _appliquer(
          base,
          {
            'coca': const Prevision(3, sourceMain),
            'cafe': const Prevision(1.3, sourceMain),
          },
          const []);
      expect(_memes(base, avant), isFalse);
      // « Annuler ce changement » : on relit le document, on remet, on efface le reste.
      final voulues = previsionsDepuisAnnulation(doc);
      base = _appliquer(base, voulues, base.keys.where((k) => !voulues.containsKey(k)).toList());
      expect(_memes(base, avant), isTrue);
      expect(base.keys.toList(), ['croque']);
    });

    test('sans prévision avant le changement : annuler remet le menu (aucune prévision)', () {
      // Sans aucune prévision avant le changement : le document est une carte vide.
      final doc = lignesAnnulation(const {});
      var base = _appliquer(
          const {},
          {'coca': const Prevision(2, 'Événement : Tournoi')},
          const []);
      final voulues = previsionsDepuisAnnulation(doc);
      base = _appliquer(base, voulues, base.keys.where((k) => !voulues.containsKey(k)).toList());
      expect(base, isEmpty);
    });

    test('les chiffres reviennent exactement, décimales comprises', () {
      final avant = {
        'a': Prevision(1 / 3, sourceMain),
        'b': const Prevision(0.65, 'Menu'),
      };
      expect(_memes(previsionsDepuisAnnulation(lignesAnnulation(avant)), avant), isTrue);
    });

    test('une entrée hors format est ignorée ; absent ou vide = aucune prévision', () {
      expect(previsionsDepuisAnnulation(null), isEmpty);
      expect(previsionsDepuisAnnulation(const {}), isEmpty);
      expect(
          previsionsDepuisAnnulation({
            'a': {'conso': 'x', 'source': 'S'},
            'b': {'conso': 1, 'source': 'S'},
            'c': 'x',
          }).keys.toList(),
          ['b']);
    });
  });

  group('écran : bouton « Annuler ce changement »', () {
    late int revenirAppels;
    late int annulations;

    Future<void> ouvrir(
      WidgetTester tester, {
      Map<String, Prevision> previsions = const {},
      Stream<bool>? annulable,
      bool cloture = false,
    }) async {
      revenirAppels = 0;
      annulations = 0;
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranPrevision(
          evenement: Stream.value(Evenement(
              id: 'e',
              nom: 'Tournoi',
              date: '2026-10-03',
              statut: cloture ? 'cloture' : 'en_preparation',
              modes: const ['carte'],
              menuNom: 'M',
              nbJours: 2,
              previsionVerifiee: false)),
          portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 1),
          gymnases: Stream.value(const [Gymnase('gA', 'Gymnase A', 100)]),
          produits: Stream.value(const [
            ProduitEvenement('croque', 'Croque-monsieur', 300, null,
                fiche: FicheProduit(famille: 'croques', conso: 0.65)),
            ProduitEvenement('coca', 'Coca', 200, null,
                fiche: FicheProduit(famille: 'boissons_fraiches', conso: 2)),
          ]),
          previsions: Stream.value(previsions),
          definirPrevision: (p, c) async {},
          chargerPasses: () async => const EvenementsPasses([], 0),
          appliquerPasse: (r) async {},
          revenirAuMenu: () async => revenirAppels++,
          chargerReferences: () async => const [],
          appliquerReference: (r) async {},
          annulable: annulable,
          annulerChangement: () async => annulations++,
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('sans document d\'annulation : pas de bouton, « Revenir au menu » marche comme avant',
        (tester) async {
      await ouvrir(tester,
          previsions: const {'coca': Prevision(3, 'Événement : Tournoi')},
          annulable: Stream.value(false));
      expect(find.byKey(const Key('prevision_annuler_changement')), findsNothing);
      await tester.tap(find.byKey(const Key('prevision_revenir_menu')));
      await tester.pump();
      await tester.pump();
      expect(revenirAppels, 1);
      expect(find.byKey(const Key('prevision_faite')), findsOneWidget);
    });

    testWidgets('avec document : le bouton annule le changement et le dit', (tester) async {
      await ouvrir(tester,
          previsions: const {'coca': Prevision(3, 'Événement : Tournoi')},
          annulable: Stream.value(true));
      await tester.tap(find.byKey(const Key('prevision_annuler_changement')));
      await tester.pump();
      await tester.pump();
      expect(annulations, 1);
      expect(find.byKey(const Key('prevision_annulee')), findsOneWidget);
    });

    testWidgets('des corrections à la main sont signalées avant d\'être remplacées', (tester) async {
      await ouvrir(tester,
          previsions: const {'croque': Prevision(0.8, sourceMain)},
          annulable: Stream.value(true));
      await tester.tap(find.byKey(const Key('prevision_annuler_changement')));
      await tester.pump();
      expect(find.byKey(const Key('question_prevision')), findsOneWidget);
      await tester.tap(find.byKey(const Key('annuler_prevision')));
      await tester.pump();
      await tester.pump();
      expect(annulations, 0);
      await tester.tap(find.byKey(const Key('prevision_annuler_changement')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirmer_prevision')));
      await tester.pump();
      await tester.pump();
      expect(annulations, 1);
    });

    testWidgets('le flux en direct : le bouton apparaît et disparaît avec le document (autre téléphone)',
        (tester) async {
      final flux = StreamController<bool>(sync: true);
      addTearDown(flux.close);
      await ouvrir(tester, annulable: flux.stream);
      expect(find.byKey(const Key('prevision_annuler_changement')), findsNothing);
      flux.add(true);
      await tester.pump();
      expect(find.byKey(const Key('prevision_annuler_changement')), findsOneWidget);
      flux.add(false);
      await tester.pump();
      expect(find.byKey(const Key('prevision_annuler_changement')), findsNothing);
    });

    testWidgets('événement clôturé : pas de bouton, même avec un document', (tester) async {
      await ouvrir(tester, annulable: Stream.value(true), cloture: true);
      expect(find.byKey(const Key('prevision_annuler_changement')), findsNothing);
    });
  });
}
