import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/actualisation.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';

// Mission « Retours du terrain », étape F2 (décision 70) : le bilan suit l'événement en
// direct (défaut relevé sur deux téléphones) et « glisser vers le bas pour actualiser ».

Evenement _evenement(String statut) => Evenement(
      id: 'e',
      nom: 'Tournoi',
      date: '2026-10-03',
      statut: statut,
      modes: const ['especes'],
      menuNom: 'Menu',
      clotureLe: statut == 'cloture' ? DateTime(2026, 10, 4, 18, 30) : null,
      clotureParPrenom: statut == 'cloture' ? 'Chef' : null,
    );

Future<void> _glisser(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 400));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Widget _liste(Future<void> Function() relire) => MaterialApp(
      home: Scaffold(
        body: Actualisable(
          relire: relire,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [Text('Contenu')],
          ),
        ),
      ),
    );

void main() {
  group('bilan : suit l\'événement en direct (critère 2)', () {
    Future<void> afficher(
        WidgetTester tester, Stream<Evenement?>? direct) async {
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: _evenement('en_cours'),
          evenementEnDirect: direct,
          tableau: Stream.value(TableauDeBord.depuis(const <ResumeCaisse>[])),
          produits: Stream.value(const <ProduitEvenement>[]),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    String etat(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('bilan_etat'))).data!;

    testWidgets('un autre téléphone clôture : « provisoire » devient « définitif »',
        (tester) async {
      final flux = StreamController<Evenement?>();
      addTearDown(flux.close);
      await afficher(tester, flux.stream);
      expect(etat(tester), 'Bilan provisoire : événement en cours');
      flux.add(_evenement('cloture'));
      await tester.pump();
      await tester.pump();
      expect(etat(tester), 'Bilan définitif : événement clôturé');
    });

    testWidgets('sans flux, l\'événement reçu à l\'ouverture est affiché',
        (tester) async {
      await afficher(tester, null);
      expect(etat(tester), 'Bilan provisoire : événement en cours');
    });
  });

  group('glisser vers le bas pour actualiser (critères 3 et 4)', () {
    testWidgets('relit une fois, sans message quand tout va bien', (tester) async {
      var appels = 0;
      await tester.pumpWidget(_liste(() async => appels++));
      await _glisser(tester);
      expect(appels, 1);
      expect(find.byKey(const Key('message_actualisation')), findsNothing);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('hors réseau (unavailable) : message clair, le geste se termine',
        (tester) async {
      await tester.pumpWidget(_liste(() async =>
          throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')));
      await _glisser(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('message_actualisation'))).data,
        'Hors réseau : affichage des dernières données reçues',
      );
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.text('Contenu'), findsOneWidget); // rien n'est bloqué
    });

    testWidgets('réseau muet (délai dépassé) : même message, pas de rotation sans fin',
        (tester) async {
      await tester.pumpWidget(_liste(() => Completer<void>().future));
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<Text>(find.byKey(const Key('message_actualisation'))).data,
        messageHorsReseau,
      );
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('autre erreur : message d\'échec, sans fermer l\'écran', (tester) async {
      await tester.pumpWidget(_liste(() async => throw StateError('x')));
      await _glisser(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('message_actualisation'))).data,
        messageActualisationImpossible,
      );
    });

    testWidgets('le bilan relit le serveur avec le geste', (tester) async {
      var appels = 0;
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: _evenement('en_cours'),
          tableau: Stream.value(TableauDeBord.depuis(const <ResumeCaisse>[])),
          produits: Stream.value(const <ProduitEvenement>[]),
          actualiser: () async => appels++,
        ),
      ));
      await tester.pump();
      await tester.pump();
      await _glisser(tester);
      expect(appels, 1);
    });
  });
}
