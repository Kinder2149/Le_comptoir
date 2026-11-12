import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/theme.dart';

import 'calcul_club_test.dart' show calculClasseur, g1Dimanche, g1Samedi;

// Calcul du club, étape V4 (décisions 86 et 88) : les groupes dans l'écran Prévision, sur une
// largeur de téléphone de 360 px.

const _produits = [
  ProduitEvenement('croque', 'Croque standard', 300, null),
  ProduitEvenement('vege', 'Croque végé', 300, null),
  ProduitEvenement('tartiflette', 'Tartiflette', 400, null),
  ProduitEvenement('fruit', 'Fruit', 100, null),
  ProduitEvenement('quiche', 'Quiche maison', 400, null,
      fiche: FicheProduit(famille: 'fait_maison')),
];

const _gymnases = [Gymnase('g1', 'Gymnase 1', 100), Gymnase('g2', 'Gymnase 2', 20)];

Evenement _ev({double nbJours = 2}) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: 'en_preparation',
    modes: const ['carte'],
    menuNom: 'M',
    nbJours: nbJours,
    previsionVerifiee: false);

class _Banc {
  final List<List<GroupeConso>> ecrits = [];
  late final StreamController<CalculClub?> flux;
}

/// Ouvre la Prévision avec [calcul] ; chaque enregistrement de groupes est relu comme le
/// ferait la base.
Future<_Banc> _ouvrir(
  WidgetTester tester, {
  CalculClub? calcul,
  double nbJours = 2,
  bool echec = false,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 7000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final banc = _Banc();
  banc.flux = StreamController<CalculClub?>.broadcast();
  addTearDown(banc.flux.close);
  Stream<CalculClub?> flux() async* {
    yield calcul;
    yield* banc.flux.stream;
  }

  await tester.pumpWidget(MaterialApp(
    home: EcranPrevision(
      evenement: Stream.value(_ev(nbJours: nbJours)),
      portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      previsions: Stream.value(const {}),
      definirPrevision: (p, c) async {},
      chargerPasses: () async => const EvenementsPasses([], 0),
      appliquerPasse: (r) async {},
      revenirAuMenu: () async {},
      chargerReferences: () async => const [],
      appliquerReference: (r) async {},
      calcul: flux(),
      definirGroupes: (g) async {
        if (echec) throw Exception('réseau');
        banc.ecrits.add(g);
        banc.flux.add(CalculClub(repas: calcul?.repas ?? const {}, groupes: g));
      },
    ),
  ));
  await tester.pump();
  await tester.pump();
  return banc;
}

Future<void> _toucher(WidgetTester tester, Key cle) async {
  await tester.ensureVisible(find.byKey(cle));
  await tester.pump();
  await tester.tap(find.byKey(cle));
  await tester.pumpAndSettle();
}

Future<void> _saisir(WidgetTester tester, String cle, String texte) async {
  await tester.enterText(find.byKey(Key(cle)), texte);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

String _texte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;

Color? _couleur(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).style?.color;

String _champ(WidgetTester tester, String cle) =>
    tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;

void main() {
  group('une carte par groupe (critère 1)', () {
    testWidgets('nom, pourcentage de chaque jour, produits et parts de chaque jour',
        (tester) async {
      await _ouvrir(tester, calcul: calculClasseur());
      expect(find.byKey(const Key('carte_groupe_0')), findsOneWidget);
      expect(find.byKey(const Key('carte_groupe_1')), findsOneWidget);
      expect(_texte(tester, 'nom_groupe_0'), 'Plat');
      expect(_texte(tester, 'nom_groupe_1'), 'Fruit');
      // Pourcentages de chaque jour.
      expect(_champ(tester, 'champ_pct_0_1'), '70');
      expect(_champ(tester, 'champ_pct_0_2'), '80');
      expect(_champ(tester, 'champ_pct_1_1'), '50');
      expect(_champ(tester, 'champ_pct_1_2'), '60');
      // Produits du groupe Plat et leur part de chaque jour.
      expect(find.byKey(const Key('produit_0_croque')), findsOneWidget);
      expect(find.byKey(const Key('produit_0_vege')), findsOneWidget);
      expect(find.byKey(const Key('produit_0_tartiflette')), findsOneWidget);
      expect(_champ(tester, 'champ_part_0_croque_1'), '40');
      expect(_champ(tester, 'champ_part_0_croque_2'), '35');
      expect(_champ(tester, 'champ_part_0_vege_1'), '25');
      expect(_champ(tester, 'champ_part_0_vege_2'), '30');
      expect(_champ(tester, 'champ_part_1_fruit_1'), '100');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans groupe : un message et le bouton pour en créer', (tester) async {
      await _ouvrir(tester);
      expect(find.byKey(const Key('aucun_groupe')), findsOneWidget);
      expect(find.byKey(const Key('creer_groupe')), findsOneWidget);
    });

    testWidgets('durée non entière : message, pas de groupes', (tester) async {
      await _ouvrir(tester, nbJours: 1.5, calcul: calculClasseur());
      expect(find.byKey(const Key('aide_groupes_jours')), findsOneWidget);
      expect(find.byKey(const Key('carte_groupe_0')), findsNothing);
      expect(find.byKey(const Key('creer_groupe')), findsNothing);
    });
  });

  group('« 100 % » en vert ou l\'écart en ocre (critère 2)', () {
    testWidgets('parts justes : 100 % en vert ; parts qui manquent : l\'écart en ocre',
        (tester) async {
      const calcul = CalculClub(repas: {
        'g1': {1: g1Samedi, 2: g1Dimanche},
      }, groupes: [
        GroupeConso(
          nom: 'Plat',
          pourcentages: {1: 0.7, 2: 0.8},
          produits: {
            'croque': {1: 0.4, 2: 0.35},
            'vege': {1: 0.25, 2: 0.3},
            'tartiflette': {1: 0.35, 2: 0.30},
          },
        ),
      ]);
      await _ouvrir(tester, calcul: calcul);
      // Jour 1 : 40 + 25 + 35 = 100 %. Jour 2 : 35 + 30 + 30 = 95 %.
      expect(_texte(tester, 'verif_0_1'), '100 %');
      expect(_couleur(tester, 'verif_0_1'), Palette.saugeFonce);
      expect(_texte(tester, 'verif_0_2'), '95 % : il manque 5 %');
      expect(_couleur(tester, 'verif_0_2'), Palette.ocreFonce);

      // On règle la part : l'indicateur passe au vert, rien n'avait été corrigé en silence.
      await _saisir(tester, 'champ_part_0_tartiflette_2', '35');
      expect(_texte(tester, 'verif_0_2'), '100 %');
      expect(_couleur(tester, 'verif_0_2'), Palette.saugeFonce);

      // Trop : l'écart est dit aussi.
      await _saisir(tester, 'champ_part_0_tartiflette_2', '40');
      expect(_texte(tester, 'verif_0_2'), '105 % : 5 % de trop');
      expect(_couleur(tester, 'verif_0_2'), Palette.ocreFonce);
    });

    testWidgets('un produit rangé sans part : 0 % et le manque, en ocre', (tester) async {
      await _ouvrir(tester, calcul: const CalculClub(groupes: [GroupeConso(nom: 'Plat')]));
      await _toucher(tester, const Key('ranger_produit_0'));
      await _toucher(tester, const Key('choix_produit_croque'));
      expect(_texte(tester, 'verif_0_1'), '0 % : il manque 100 %');
      expect(_couleur(tester, 'verif_0_1'), Palette.ocreFonce);
    });
  });

  group('créer, renommer, supprimer, ranger (critère 3)', () {
    testWidgets('créer un groupe, le renommer, le supprimer', (tester) async {
      final banc = await _ouvrir(tester);
      await _toucher(tester, const Key('creer_groupe'));
      await tester.enterText(find.byKey(const Key('nom_groupe')), 'Dessert');
      await _toucher(tester, const Key('confirmer_nom_groupe'));
      expect(banc.ecrits.last.map((g) => g.nom), ['Dessert']);
      expect(_texte(tester, 'nom_groupe_0'), 'Dessert');

      await _toucher(tester, const Key('renommer_groupe_0'));
      await tester.enterText(find.byKey(const Key('nom_groupe')), 'Desserts et 4 h');
      await _toucher(tester, const Key('confirmer_nom_groupe'));
      expect(banc.ecrits.last.map((g) => g.nom), ['Desserts et 4 h']);
      expect(_texte(tester, 'nom_groupe_0'), 'Desserts et 4 h');

      await _toucher(tester, const Key('supprimer_groupe_0'));
      expect(find.byKey(const Key('question_suppression_groupe')), findsOneWidget);
      await _toucher(tester, const Key('confirmer_suppression_groupe'));
      expect(banc.ecrits.last, isEmpty);
      expect(find.byKey(const Key('carte_groupe_0')), findsNothing);
      expect(find.byKey(const Key('aucun_groupe')), findsOneWidget);
    });

    testWidgets('nom vide ou trop long : refusé, rien n\'est écrit', (tester) async {
      final banc = await _ouvrir(tester);
      await _toucher(tester, const Key('creer_groupe'));
      await tester.enterText(find.byKey(const Key('nom_groupe')), '   ');
      await _toucher(tester, const Key('confirmer_nom_groupe'));
      expect(find.text('Le nom doit faire de 1 à 40 caractères.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('nom_groupe')), 'x' * 41);
      await _toucher(tester, const Key('confirmer_nom_groupe'));
      expect(find.text('Le nom doit faire de 1 à 40 caractères.'), findsOneWidget);
      expect(banc.ecrits, isEmpty);
      await _toucher(tester, const Key('annuler_nom_groupe'));
      expect(banc.ecrits, isEmpty);
    });

    testWidgets('annuler la suppression : le groupe reste', (tester) async {
      final banc = await _ouvrir(tester, calcul: calculClasseur());
      await _toucher(tester, const Key('supprimer_groupe_1'));
      await _toucher(tester, const Key('annuler_suppression_groupe'));
      expect(banc.ecrits, isEmpty);
      expect(find.byKey(const Key('carte_groupe_1')), findsOneWidget);
    });

    testWidgets('ranger un produit : un seul groupe, retiré de l\'ancien ; fait maison absent',
        (tester) async {
      final banc = await _ouvrir(tester, calcul: calculClasseur());
      // Le fruit est dans « Fruit » ; on le range dans « Plat » : le choix le dit.
      await _toucher(tester, const Key('ranger_produit_0'));
      expect(find.byKey(const Key('choix_produit_fruit')), findsOneWidget);
      expect(find.text('Dans « Fruit » : il y sera retiré'), findsOneWidget);
      // Déjà dans le groupe : non proposé ; fait maison : jamais proposé.
      expect(find.byKey(const Key('choix_produit_croque')), findsNothing);
      expect(find.byKey(const Key('choix_produit_quiche')), findsNothing);
      await tester.tap(find.byKey(const Key('choix_produit_fruit')));
      await tester.pumpAndSettle();

      final groupes = banc.ecrits.last;
      expect(groupes[0].produits.keys, containsAll(['croque', 'vege', 'tartiflette', 'fruit']));
      expect(groupes[0].produits['fruit'], {1: 0.0, 2: 0.0});
      expect(groupes[1].produits, isEmpty);
      // Un produit n'est dans qu'un seul groupe.
      for (final id in ['croque', 'vege', 'tartiflette', 'fruit']) {
        expect(groupes.where((g) => g.produits.containsKey(id)), hasLength(1));
      }
      expect(find.byKey(const Key('produit_0_fruit')), findsOneWidget);
      expect(find.byKey(const Key('produit_1_fruit')), findsNothing);
      expect(find.byKey(const Key('aucun_produit_1')), findsOneWidget);
    });

    testWidgets('retirer un produit d\'un groupe', (tester) async {
      final banc = await _ouvrir(tester, calcul: calculClasseur());
      await _toucher(tester, const Key('retirer_produit_0_vege'));
      expect(banc.ecrits.last[0].produits.keys, ['croque', 'tartiflette']);
      expect(find.byKey(const Key('produit_0_vege')), findsNothing);
    });

    testWidgets('pourcentage et part saisis : enregistrés en fractions, bornes tenues',
        (tester) async {
      final banc = await _ouvrir(tester, calcul: calculClasseur());
      await _saisir(tester, 'champ_pct_0_1', '75,5');
      expect(banc.ecrits.last[0].pourcentages[1], closeTo(0.755, 1e-12));
      expect(banc.ecrits.last[0].pourcentages[2], 0.8);
      final avant = banc.ecrits.length;
      // Hors bornes : message, rien n'est écrit.
      await _saisir(tester, 'champ_pct_0_1', '501');
      expect(find.text('Entrez un pourcentage de 0 à 500.'), findsOneWidget);
      await _saisir(tester, 'champ_part_0_croque_1', '101');
      expect(find.text('Entrez une part de 0 à 100.'), findsOneWidget);
      expect(banc.ecrits.length, avant);
    });

    testWidgets('40 groupes au plus : le bouton se grise', (tester) async {
      await _ouvrir(tester, calcul: CalculClub(groupes: [
        for (var i = 0; i < 40; i++) GroupeConso(nom: 'G$i'),
      ]));
      await tester.ensureVisible(find.byKey(const Key('creer_groupe')));
      expect(
          tester.widget<OutlinedButton>(find.byKey(const Key('creer_groupe'))).onPressed,
          isNull);
    });

    testWidgets('écriture refusée : message d\'erreur, le groupe n\'apparaît pas',
        (tester) async {
      await _ouvrir(tester, echec: true);
      await _toucher(tester, const Key('creer_groupe'));
      await tester.enterText(find.byKey(const Key('nom_groupe')), 'Dessert');
      await _toucher(tester, const Key('confirmer_nom_groupe'));
      expect(find.byKey(const Key('erreur_preparation')), findsOneWidget);
      expect(find.byKey(const Key('carte_groupe_0')), findsNothing);
    });
  });

  group('quantité prévue par jour sous chaque produit (critère 5)', () {
    testWidgets('somme des gymnases, jour par jour (classeur d\'origine)', (tester) async {
      await _ouvrir(tester, calcul: calculClasseur());
      // Croque standard : jour 1 = 33,32 + 39,48 ; jour 2 = 36,4 + 33,88.
      expect(_texte(tester, 'quantite_croque_1'), 'Prévu jour 1 : 72,8');
      expect(_texte(tester, 'quantite_croque_2'), 'Prévu jour 2 : 70,28');
    });

    testWidgets('elle suit les parts saisies', (tester) async {
      await _ouvrir(tester, calcul: calculClasseur());
      await _saisir(tester, 'champ_part_0_croque_1', '50');
      // (119 + 141) × 0,7 × 0,5 = 91.
      expect(_texte(tester, 'quantite_croque_1'), 'Prévu jour 1 : 91');
    });
  });

  group('sans zone', () {
    testWidgets('sans l\'écriture des groupes, l\'écran est celui d\'avant', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 3000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranPrevision(
          evenement: Stream.value(_ev()),
          portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
          gymnases: Stream.value(_gymnases),
          produits: Stream.value(_produits),
          previsions: Stream.value(const {}),
          definirPrevision: (p, c) async {},
          chargerPasses: () async => const EvenementsPasses([], 0),
          appliquerPasse: (r) async {},
          revenirAuMenu: () async {},
          chargerReferences: () async => const [],
          appliquerReference: (r) async {},
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('groupes_club')), findsNothing);
    });
  });
}
