import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/ecran_personnes_duree.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

// Calcul du club, étape V3 (décisions 86 et 87) : l'écran « Personnes et durée » détaille les
// repas jour par jour. Sans détail, l'écran est celui d'avant (critère 1 à 3 de V3).

Evenement _ev({double nbJours = 2}) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: 'en_preparation',
    modes: const ['carte'],
    menuNom: 'M',
    nbJours: nbJours,
    previsionVerifiee: false);

const _gymnases = [Gymnase('g1', 'Gymnase 1', 100), Gymnase('g2', 'Gymnase 2', 20)];

PorteeGestion _tout() => const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);

void _grandEcran(WidgetTester tester, {Size taille = const Size(432, 3600), double dpr = 2.5}) {
  tester.view.physicalSize = Size(taille.width * dpr, taille.height * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Ouvre l'écran. [enregistres] reçoit les repas enregistrés, et le calcul relu est mis à jour
/// comme le ferait la base (le tableau apparaît après l'enregistrement).
Future<List<Map<String, Map<int, RepasGymnaseJour>>>> _ouvrir(
  WidgetTester tester, {
  CalculClub? calculInitial,
  double nbJours = 2,
  Size taille = const Size(432, 3600),
  double dpr = 2.5,
}) async {
  _grandEcran(tester, taille: taille, dpr: dpr);
  final enregistres = <Map<String, Map<int, RepasGymnaseJour>>>[];
  final calcul = StreamController<CalculClub?>.broadcast();
  Stream<CalculClub?> flux() async* {
    yield calculInitial;
    yield* calcul.stream;
  }

  await tester.pumpWidget(MaterialApp(
    home: EcranPersonnesDuree(
      evenement: Stream.value(_ev(nbJours: nbJours)),
      portee: _tout(),
      gymnases: Stream.value(_gymnases),
      definirJours: (j) async {},
      definirPersonnes: (g, n) async {},
      calcul: flux(),
      definirRepas: (repas) async {
        enregistres.add(repas);
        calcul.add(CalculClub(repas: repas));
      },
    ),
  ));
  await tester.pump();
  await tester.pump();
  addTearDown(calcul.close);
  return enregistres;
}

Future<void> _toucher(WidgetTester tester, Key cle) async {
  await tester.ensureVisible(find.byKey(cle));
  await tester.pump();
  await tester.tap(find.byKey(cle));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sans détail : les cartes « personnes » et le bouton « Détailler par jour »',
      (tester) async {
    await _ouvrir(tester);
    expect(find.byKey(const Key('detailler_repas')), findsOneWidget);
    expect(find.text('Détailler par jour (méthode du club)'), findsOneWidget);
    expect(find.textContaining('Personnes attendues'), findsNWidgets(2));
    expect(find.byKey(const Key('tableau_repas')), findsNothing);
  });

  testWidgets('en saisie : une carte par jour, trois catégories par gymnase, total du jour',
      (tester) async {
    await _ouvrir(tester);
    await _toucher(tester, const Key('detailler_repas'));

    expect(find.byKey(const Key('carte_jour_1')), findsOneWidget);
    expect(find.byKey(const Key('carte_jour_2')), findsOneWidget);
    // Deux gymnases × deux jours : trois catégories chacune.
    expect(find.text('Joueuses et accompagnateurs'), findsNWidgets(4));
    expect(find.text('Bénévoles et famille'), findsNWidgets(4));
    expect(find.text('Spectateurs'), findsNWidgets(4));
    // Les cartes « personnes × durée » sont remplacées par la saisie.
    expect(find.textContaining('Personnes attendues'), findsNothing);

    expect(find.text('Total du jour : 0'), findsNWidgets(2));
    await tester.enterText(find.byKey(const Key('repas_g1_1_joueuses_midi')), '49');
    await tester.pump();
    expect(find.text('Total du jour : 49'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('total_g1_1'))).data, '49');
    expect(tester.widget<Text>(find.byKey(const Key('total_g2_1'))).data, '0');
  });

  testWidgets('enregistrer : les repas partent, le tableau remplace « personnes × durée »',
      (tester) async {
    final enregistres = await _ouvrir(tester);
    await _toucher(tester, const Key('detailler_repas'));
    await tester.enterText(find.byKey(const Key('repas_g1_1_joueuses_midi')), '49');
    await tester.enterText(find.byKey(const Key('repas_g2_2_spectateurs_soir')), '5');
    await tester.pump();

    await _toucher(tester, const Key('enregistrer_repas'));

    expect(enregistres, hasLength(1));
    final r = enregistres.single;
    expect(r['g1']![1]!.joueusesMidi, 49);
    expect(r['g2']![2]!.spectateursSoir, 5);
    expect(r['g1']![2]!.total, 0);

    expect(find.byKey(const Key('tableau_repas')), findsOneWidget);
    expect(find.byKey(const Key('modifier_repas')), findsOneWidget);
    expect(find.byKey(const Key('detailler_repas')), findsNothing);
    expect(find.textContaining('Personnes attendues'), findsNothing);
    expect(find.byKey(const Key('carte_jour_1')), findsNothing);
  });

  testWidgets('une saisie hors bornes n\'est pas enregistrée', (tester) async {
    final enregistres = await _ouvrir(tester);
    await _toucher(tester, const Key('detailler_repas'));
    await tester.enterText(find.byKey(const Key('repas_g1_1_joueuses_midi')), '1500');
    await tester.pump();
    await _toucher(tester, const Key('enregistrer_repas'));

    expect(enregistres, isEmpty);
    expect(find.byKey(const Key('erreur_repas')), findsOneWidget);
  });

  testWidgets('détaillé : le tableau des jours, avec le total par gymnase et par jour',
      (tester) async {
    final club = CalculClub(repas: {
      'g1': {
        1: const RepasGymnaseJour(joueusesMidi: 49, joueusesSoir: 49, benevolesMidi: 10, benevolesSoir: 11),
        2: const RepasGymnaseJour(joueusesMidi: 56, joueusesSoir: 56, benevolesMidi: 9, benevolesSoir: 9),
      },
      'g2': {
        1: const RepasGymnaseJour(joueusesMidi: 63, joueusesSoir: 63, benevolesMidi: 7, benevolesSoir: 8),
      },
    });
    await _ouvrir(tester, calculInitial: club);

    expect(find.byKey(const Key('tableau_repas')), findsOneWidget);
    expect(find.byKey(const Key('modifier_repas')), findsOneWidget);
    expect(find.textContaining('Personnes attendues'), findsNothing);
    // Jour 1 : G1 119, G2 141, total 260 ; Jour 2 : G1 130, G2 0, total 130.
    expect(find.text('260'), findsOneWidget);
    expect(find.text('130'), findsNWidgets(2));
    expect(find.text('119'), findsOneWidget);
    expect(find.text('141'), findsOneWidget);
  });

  testWidgets('durée non entière : pas de détail, un message dit pourquoi', (tester) async {
    await _ouvrir(tester, nbJours: 1.5);
    expect(find.byKey(const Key('detailler_repas')), findsNothing);
    expect(find.byKey(const Key('aide_repas_jours')), findsOneWidget);
    expect(find.textContaining('Personnes attendues'), findsNWidgets(2));
  });

  testWidgets('largeur de téléphone : la saisie et le tableau ne débordent pas',
      (tester) async {
    const telephone = Size(360, 740);
    await _ouvrir(tester, taille: telephone, dpr: 3);
    await _toucher(tester, const Key('detailler_repas'));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('carte_jour_2')), findsOneWidget);

    final club = CalculClub(repas: {
      'g1': {1: const RepasGymnaseJour(joueusesMidi: 49, joueusesSoir: 49)},
      'g2': {1: const RepasGymnaseJour(joueusesMidi: 63, joueusesSoir: 63)},
    });
    await tester.pumpWidget(const SizedBox());
    await _ouvrir(tester, calculInitial: club, taille: telephone, dpr: 3);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('tableau_repas')), findsOneWidget);
  });
}
