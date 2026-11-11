import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_personnes_duree.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/tableau_bord.dart';

// Mission « Ergonomie de la gestion », E5 : les écrans « Personnes et durée » et
// « Prévision ». Gymnases A (100 personnes) et B (20) : 120 personnes, 2 jours.
//   Croque (famille Croques, 0,65), Café (Boissons chaudes, 1,3, 4 verres par litre),
//   Coca (Boissons fraîches, 2), Tarte (Fait maison, 1).

Evenement _ev({bool verifiee = false, bool cloture = false}) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: cloture ? 'cloture' : 'en_preparation',
    modes: const ['carte'],
    menuNom: 'M',
    nbJours: 2,
    previsionVerifiee: verifiee);

const _gymnases = [Gymnase('gA', 'Gymnase A', 100), Gymnase('gB', 'Gymnase B', 20)];

const _produits = [
  ProduitEvenement('croque', 'Croque-monsieur', 300, null,
      fiche: FicheProduit(famille: 'croques', conso: 0.65)),
  ProduitEvenement('cafe', 'Café', 150, null,
      fiche: FicheProduit(
          famille: 'boissons_chaudes', conso: 1.3, verresParLitre: 4)),
  ProduitEvenement('coca', 'Coca', 200, null,
      fiche: FicheProduit(famille: 'boissons_fraiches', conso: 2)),
  ProduitEvenement('tarte', 'Tarte', 250, null,
      fiche: FicheProduit(famille: 'fait_maison', conso: 1)),
];

PorteeGestion _tout() =>
    const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);

// Appels reçus par les écrans.
final _verifieesEcrites = <bool>[];
final _previsionsEcrites = <(String, double)>[];
final _passesAppliquees = <String>[];
final _referencesAppliquees = <String>[];
var _retoursAuMenu = 0;

void _reinitialiser() {
  _verifieesEcrites.clear();
  _previsionsEcrites.clear();
  _passesAppliquees.clear();
  _referencesAppliquees.clear();
  _retoursAuMenu = 0;
}

Future<void> _ouvrirPersonnes(WidgetTester tester, {bool verifiee = false}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: EcranPersonnesDuree(
      evenement: Stream.value(_ev(verifiee: verifiee)),
      portee: _tout(),
      gymnases: Stream.value(_gymnases),
      definirJours: (j) async {},
      definirPersonnes: (g, n) async {},
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _ouvrirPrevision(
  WidgetTester tester, {
  Map<String, Prevision> previsions = const {},
  EvenementsPasses passes = const EvenementsPasses([], 0),
  List<ReferenceImportee> references = const [],
  bool verifiee = false,
  bool cloture = false,
}) async {
  _reinitialiser();
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: EcranPrevision(
      evenement: Stream.value(_ev(verifiee: verifiee, cloture: cloture)),
      portee: _tout(),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      previsions: Stream.value(previsions),
      definirPrevision: (p, c) async => _previsionsEcrites.add((p, c)),
      chargerPasses: () async => passes,
      appliquerPasse: (r) async => _passesAppliquees.add(r.id),
      revenirAuMenu: () async => _retoursAuMenu++,
      chargerReferences: () async => references,
      appliquerReference: (r) async => _referencesAppliquees.add(r.id),
      definirPrevisionVerifiee: (v) async => _verifieesEcrites.add(v),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('Personnes et durée', () {
    testWidgets('le total et chaque gymnase sont affichés et réglables', (tester) async {
      await _ouvrirPersonnes(tester);
      expect(find.textContaining('120 personnes'), findsOneWidget);
      expect(find.byKey(const Key('champ_duree')), findsOneWidget);
      expect(find.byKey(const Key('champ_personnes_gA')), findsOneWidget);
      expect(find.byKey(const Key('champ_personnes_gB')), findsOneWidget);
    });

    testWidgets('événement clôturé : lecture seule, aucun champ à saisir', (tester) async {
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranPersonnesDuree(
          evenement: Stream.value(_ev(cloture: true)),
          portee: _tout(),
          gymnases: Stream.value(_gymnases),
          definirJours: (j) async {},
          definirPersonnes: (g, n) async {},
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('champ_duree')), findsNothing);
      expect(find.byKey(const Key('lecture_duree')), findsOneWidget);
    });
  });

  group('Prévision', () {
    // Critère 1 : le bandeau dit « 120 personnes × 2 jours ».
    testWidgets('critère 1 : le bandeau affiche « 120 personnes × 2 jours »', (tester) async {
      await _ouvrirPrevision(tester);
      expect(find.textContaining('120 personnes × 2 jours'), findsOneWidget);
    });

    // Critère 2 : 156 pour le croque-monsieur, 312 verres et 78 L pour le café.
    testWidgets('critère 2 : Croque-monsieur 0,65 donne 156 ; Café 1,3 donne 312 verres et 78 L',
        (tester) async {
      await _ouvrirPrevision(tester);
      expect(tester.widget<Text>(find.byKey(const Key('total_croque'))).data, '156');
      expect(tester.widget<Text>(find.byKey(const Key('total_cafe'))).data, '312 verres');
      expect(tester.widget<Text>(find.byKey(const Key('litres_cafe'))).data, '78 L');
    });

    // Critère 3 : la source se lit sur chaque ligne.
    testWidgets('critère 3 : Menu, événement passé et correction à la main se lisent sur chaque ligne',
        (tester) async {
      await _ouvrirPrevision(tester, previsions: const {
        'cafe': Prevision(1.3, 'Événement : Tournoi 2025'),
        'coca': Prevision(1.5, sourceMain),
      });
      expect(tester.widget<Text>(find.byKey(const Key('source_croque'))).data,
          'Source : Menu');
      expect(tester.widget<Text>(find.byKey(const Key('source_cafe'))).data,
          'Source : Événement : Tournoi 2025');
      expect(tester.widget<Text>(find.byKey(const Key('source_coca'))).data,
          'Source : Modifié à la main');
    });

    // Critère 4 : changer de source se fait depuis le bandeau.
    testWidgets('critère 4 : « D\'après une source » et « Revenir au menu » sont dans le bandeau',
        (tester) async {
      final passe = ReferencePassee(
          id: 'p1', nom: 'Tournoi 2025', date: '2025-10-01', personnes: 100, jours: 2);
      await _ouvrirPrevision(
        tester,
        passes: EvenementsPasses([passe], 0),
        previsions: const {'cafe': Prevision(1.3, 'Événement : Tournoi 2025')},
      );
      expect(find.descendant(
              of: find.byKey(const Key('bandeau_prevision')),
              matching: find.byKey(const Key('prevision_evenement_passe'))),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('prevision_revenir_menu')));
      await tester.pumpAndSettle();
      expect(_retoursAuMenu, 1);
      await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('choix_passe_p1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('choix_passe_p1')));
      await tester.pumpAndSettle();
      expect(_passesAppliquees, ['p1']);
    });

    testWidgets('critère 4 : une référence importée d\'un classeur s\'applique depuis le bandeau',
        (tester) async {
      const ref = ReferenceImportee(
          id: 'tournoi-2025-excel',
          nom: 'Tournoi 2025 (Excel)',
          lignes: [LigneReference('Croque-monsieur', 2.0)]);
      await _ouvrirPrevision(tester, references: const [ref]);
      await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choix_reference_tournoi-2025-excel')));
      await tester.pumpAndSettle();
      expect(_referencesAppliquees, ['tournoi-2025-excel']);
    });

    // Critère 5 : le fait maison n'a pas de ligne, et une phrase le dit.
    testWidgets('critère 5 : le fait maison n\'a pas de ligne de prévision et une phrase le dit',
        (tester) async {
      await _ouvrirPrevision(tester);
      expect(find.byKey(const Key('source_tarte')), findsNothing);
      expect(find.byKey(const Key('total_tarte')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('aide_fait_maison'))).data,
          contains('apporté le jour même'));
    });

    // Critère 6 : « C'est vérifié » coche la tâche Prévision.
    testWidgets('critère 6 : « C\'est vérifié » écrit la case, la tâche Prévision se coche',
        (tester) async {
      await _ouvrirPrevision(tester);
      await tester.tap(find.byKey(const Key('prevision_verifiee')));
      await tester.pump();
      expect(_verifieesEcrites, [true]);
      final cochee = tachesAvant(
        ev: _ev(verifiee: true),
        gymnases: _gymnases,
        stocksDepart: const {},
        seriesValidees: 0,
      ).firstWhere((t) => t.cle == 'prevision');
      expect(cochee.faite, isTrue);
    });

    testWidgets('critère 6 : une prévision déjà vérifiée l\'affiche et propose de la revoir',
        (tester) async {
      await _ouvrirPrevision(tester, verifiee: true);
      expect(find.byKey(const Key('prevision_verifiee_ok')), findsOneWidget);
      await tester.tap(find.byKey(const Key('prevision_a_revoir')));
      await tester.pump();
      expect(_verifieesEcrites, [false]);
    });

    testWidgets('événement clôturé : lecture seule, pas de « C\'est vérifié »', (tester) async {
      await _ouvrirPrevision(tester, cloture: true);
      expect(find.byKey(const Key('prevision_verifiee')), findsNothing);
      expect(find.byKey(const Key('champ_conso_croque')), findsNothing);
      expect(find.byKey(const Key('lecture_conso_croque')), findsOneWidget);
    });
  });
}
