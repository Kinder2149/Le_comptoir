import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/ecran_preparation.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_classeur.dart';
import 'package:le_comptoir/partage.dart';
import 'package:le_comptoir/previsions.dart';

import 'classeur_aides.dart';

// Étapes P2 et P3 : l'écran Préparation, étape 1 « Stock de départ » et étape 2
// « Personnes et durée ».
//   Gymnases A et B ; produits finis Soda et Croque (jamais d'ingrédient dans la liste).
//   Stock au départ : A : Soda 6 (repris), Croque 10 ; B : rien.
Evenement _ev(String statut, {bool verifiee = false}) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: statut,
    modes: const ['carte'],
    menuNom: 'M',
    nbJours: 3,
    previsionVerifiee: verifiee);

const _gymnases = [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B')];

// Réglages écrits par l'écran (étape 2), remis à zéro à chaque affichage.
final _joursEcrits = <double>[];
final _personnesEcrites = <(String, int)>[];

// Étape 3 : prévisions écrites, événements passés appliqués, retours au menu.
final _previsionsEcrites = <(String, double)>[];
// « C'est vérifié » (E3) : valeurs écrites dans la case de l'événement.
final _verifieesEcrites = <bool>[];
final _passesAppliquees = <String>[];
var _retoursAuMenu = 0;

// Import d'un classeur (P6) : références proposées, références appliquées, plans appliqués,
// et le fichier que le sélecteur factice rend.
var _references = <ReferenceImportee>[];
final _referencesAppliquees = <String>[];
final _plansImportes = <PlanImport>[];
Uint8List? _classeurChoisi;
Object? _echecImport;
const _produits = [
  ProduitEvenement('soda', 'Soda', 100, null),
  ProduitEvenement('croque', 'Croque', 300, null),
];
const _stocks = {
  'gA': {'soda': StockDepart(6, repris: true), 'croque': StockDepart(10)},
  'gB': <String, StockDepart>{},
};

PorteeGestion _tout() =>
    const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);

Future<List<(String, String, int)>> _afficher(
  WidgetTester tester, {
  String statut = 'en_preparation',
  PorteeGestion? portee,
  VoidCallback? voirGymnases,
  Map<String, Prevision> previsions = const {},
  EvenementsPasses passes = const EvenementsPasses([], 0),
  bool refus = false,
  PartageurOctets? partagerModele,
  List<ReferenceImportee> references = const [],
  Uint8List? classeur,
  Object? echecImport,
  bool verifiee = false,
}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  _joursEcrits.clear();
  _personnesEcrites.clear();
  _previsionsEcrites.clear();
  _verifieesEcrites.clear();
  _passesAppliquees.clear();
  _retoursAuMenu = 0;
  _references = references;
  _referencesAppliquees.clear();
  _plansImportes.clear();
  _classeurChoisi = classeur;
  _echecImport = echecImport;
  final ecrits = <(String, String, int)>[];
  await tester.pumpWidget(MaterialApp(
    home: EcranPreparation(
      evenement: Stream.value(_ev(statut, verifiee: verifiee)),
      portee: portee ?? _tout(),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      stocks: Stream.value(_stocks),
      definirStock: (g, p, q) async => ecrits.add((g, p, q)),
      definirJours: (j) async => _joursEcrits.add(j),
      definirPersonnes: (g, n) async => _personnesEcrites.add((g, n)),
      onVoirGymnases: voirGymnases ?? () {},
      previsions: Stream.value(previsions),
      definirPrevision: (p, c) async => _previsionsEcrites.add((p, c)),
      definirPrevisionVerifiee: (v) async => _verifieesEcrites.add(v),
      chargerPasses: () async => passes,
      appliquerPasse: (r) async {
        if (refus) throw const LectureRefusee();
        _passesAppliquees.add(r.id);
      },
      revenirAuMenu: () async => _retoursAuMenu++,
      chargerReferences: () async => _references,
      appliquerReference: (r) async => _referencesAppliquees.add(r.id),
      importer: (plan) async {
        if (_echecImport != null) throw _echecImport!;
        _plansImportes.add(plan);
      },
      choisirClasseur: () async => _classeurChoisi,
      partagerModele: partagerModele ?? (n, o, m) async {},
    ),
  ));
  await tester.pump();
  await tester.pump();
  return ecrits;
}

void main() {
  testWidgets('télécharger le modèle : un .xlsx part à la feuille de partage, '
      'avec le menu et les stocks affichés', (tester) async {
    final recus = <(String, Uint8List, String)>[];
    await _afficher(tester,
        partagerModele: (n, o, m) async => recus.add((n, o, m)));
    expect(find.byKey(const Key('titre_classeur')), findsOneWidget);
    final bouton = find.byKey(const Key('telecharger_modele'));
    expect(bouton, findsOneWidget);
    expect(tester.getSize(bouton).height, greaterThanOrEqualTo(48));
    await tester.tap(bouton);
    await tester.pump();
    expect(recus.length, 1);
    expect(recus.single.$1, 'modele-tournoi-2026-10-03.xlsx');
    expect(recus.single.$3, typeMimeClasseur);
    final lu = lireClasseur(recus.single.$2);
    expect(lu.erreurs, isEmpty);
    expect(lu.produits.map((p) => p.nom), ['Soda', 'Croque']);
    expect(
        lu.stocks.map((s) => (s.gymnase, s.produit, s.quantite)),
        containsAll([
          ('Gymnase A', 'Soda', 6),
          ('Gymnase A', 'Croque', 10),
          ('Gymnase B', 'Soda', null),
        ]));
  });

  testWidgets('un gestionnaire partiel ne reçoit que ses gymnases dans le modèle',
      (tester) async {
    final recus = <Uint8List>[];
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gB'}, nbGymnases: 2),
        partagerModele: (n, o, m) async => recus.add(o));
    await tester.tap(find.byKey(const Key('telecharger_modele')));
    await tester.pump();
    expect({for (final s in lireClasseur(recus.single).stocks) s.gymnase},
        {'Gymnase B'});
  });

  testWidgets('échec de la feuille de partage : message, le bouton redevient actif',
      (tester) async {
    await _afficher(tester, partagerModele: (n, o, m) async => throw Exception('x'));
    await tester.tap(find.byKey(const Key('telecharger_modele')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Le partage n\'a pas pu s\'ouvrir. Réessayez.'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('telecharger_modele')))
            .onPressed,
        isNotNull);
  });

  testWidgets('le modèle se télécharge aussi quand l\'événement est ouvert',
      (tester) async {
    await _afficher(tester, statut: 'en_cours');
    expect(find.byKey(const Key('telecharger_modele')), findsOneWidget);
  });
  testWidgets('en préparation : une carte par gymnase, les produits finis seulement, '
      'le stock repris est pré-rempli et marqué', (tester) async {
    await _afficher(tester);
    expect(find.byKey(const Key('titre_etape_stock')), findsOneWidget);
    expect(find.text('Gymnase A'), findsOneWidget);
    expect(find.text('Gymnase B'), findsOneWidget);
    // Soda et Croque dans chaque gymnase (étape 1) et une fois dans la prévision (étape 3).
    expect(find.text('Soda'), findsNWidgets(3));
    expect(find.text('Croque'), findsNWidgets(3));
    // 4 quantités de stock + 3 réglages de l'étape 2 (durée, personnes de A et de B)
    // + 2 consommations de l'étape 3 (une par produit).
    expect(find.byType(TextField), findsNWidgets(9));
    String champ(String cle) =>
        tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;
    expect(champ('depart_gA_soda'), '6');
    expect(champ('depart_gA_croque'), '10');
    expect(champ('depart_gB_soda'), '');
    // La marque n'apparaît que sur le stock repris.
    expect(find.text("Repris de l'événement précédent"), findsOneWidget);
    expect(find.byKey(const Key('repris_gA_soda')), findsOneWidget);
    expect(find.byKey(const Key('repris_gA_croque')), findsNothing);
    // Saisie modifiable : pas de renvoi vers « Gymnases et stocks ».
    expect(find.byKey(const Key('aller_gymnases_stocks')), findsNothing);
  });

  testWidgets('saisir 24 sodas au gymnase B enregistre 24 pour ce gymnase et ce produit',
      (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gB_soda')), '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(ecrits, [('gB', 'soda', 24)]);
  });

  testWidgets('une valeur invalide est refusée avec un message, sans écriture',
      (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gB_soda')), '100001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Entrez un nombre entier de 0 à 100 000.'), findsOneWidget);
    expect(ecrits, isEmpty);
  });

  testWidgets('une saisie laissée un instant est enregistrée sans valider', (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gA_croque')), '12');
    await tester.pump(const Duration(seconds: 2));
    expect(ecrits, [('gA', 'croque', 12)]);
  });

  testWidgets('une quantité identique à celle enregistrée n\'écrit rien', (tester) async {
    final ecrits = await _afficher(tester);
    await tester.enterText(find.byKey(const Key('depart_gA_croque')), '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(ecrits, isEmpty);
  });

  testWidgets('« Suivre tous » met à zéro les produits non suivis du gymnase',
      (tester) async {
    final ecrits = await _afficher(tester);
    // Gymnase A suit déjà tout : pas de bouton ; gymnase B : deux produits à suivre.
    expect(find.byKey(const Key('suivre_tous_depart_gA')), findsNothing);
    await tester.tap(find.byKey(const Key('suivre_tous_depart_gB')));
    await tester.pump();
    expect(ecrits.toSet(), {('gB', 'soda', 0), ('gB', 'croque', 0)});
  });

  testWidgets('un gestionnaire ne voit que ses gymnases', (tester) async {
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gB'}, nbGymnases: 2));
    expect(find.text('Gymnase B'), findsOneWidget);
    expect(find.text('Gymnase A'), findsNothing);
    expect(find.byKey(const Key('depart_gA_soda')), findsNothing);
    expect(find.byKey(const Key('depart_gB_soda')), findsOneWidget);
  });

  for (final statut in ['en_cours', 'cloture']) {
    testWidgets('événement $statut : lecture seule et renvoi vers « Gymnases et stocks »',
        (tester) async {
      var renvoi = 0;
      await _afficher(tester, statut: statut, voirGymnases: () => renvoi++);
      // Plus de quantité de stock à saisir : seuls restent les 3 réglages de l'étape 2 et
      // les 2 consommations de l'étape 3 (lisibles seulement une fois l'événement clôturé).
      expect(find.byType(TextField), statut == 'cloture' ? findsNothing : findsNWidgets(5));
      expect(find.byKey(const Key('depart_gA_soda')), findsNothing);
      expect(find.byKey(const Key('suivre_tous_depart_gB')), findsNothing);
      expect(
          tester.widget<Text>(find.byKey(const Key('lecture_depart_gA_soda'))).data,
          'Stock : 6');
      expect(
          tester.widget<Text>(find.byKey(const Key('lecture_depart_gB_soda'))).data,
          'Stock non suivi');
      await tester.tap(find.byKey(const Key('aller_gymnases_stocks')));
      expect(renvoi, 1);
    });
  }

  // ---------- Étape 2 : personnes et durée.
  Future<void> saisirEtValider(WidgetTester tester, String cle, String valeur) async {
    await tester.enterText(find.byKey(Key(cle)), valeur);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('étape 2 : durée et personnes de chaque gymnase sont affichées et réglables',
      (tester) async {
    await _afficher(tester);
    expect(find.byKey(const Key('titre_etape_personnes')), findsOneWidget);
    String champ(String cle) =>
        tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;
    expect(champ('champ_duree'), '3');
    expect(champ('champ_personnes_gA'), '40');
    expect(champ('champ_personnes_gB'), '0');
  });

  testWidgets('durée : 0,5 et 30 acceptés (virgule ou point), 0,4 et 31 refusés',
      (tester) async {
    await _afficher(tester);
    const message = 'Entrez une durée de 0,5 à 30 jours.';
    await saisirEtValider(tester, 'champ_duree', '0,4');
    expect(find.text(message), findsOneWidget);
    await saisirEtValider(tester, 'champ_duree', '31');
    expect(find.text(message), findsOneWidget);
    expect(_joursEcrits, isEmpty);
    await saisirEtValider(tester, 'champ_duree', '0,5');
    expect(find.text(message), findsNothing);
    await saisirEtValider(tester, 'champ_duree', '30');
    await saisirEtValider(tester, 'champ_duree', '1.5');
    expect(_joursEcrits, [0.5, 30.0, 1.5]);
  });

  testWidgets('personnes : 0 et 1000 acceptés, 1001, -1 et 12,5 refusés', (tester) async {
    await _afficher(tester);
    const message = 'Entrez un nombre entier de personnes de 0 à 1000.';
    for (final mauvais in ['1001', '-1', '12,5']) {
      await saisirEtValider(tester, 'champ_personnes_gB', mauvais);
      expect(find.text(message), findsOneWidget, reason: mauvais);
    }
    expect(_personnesEcrites, isEmpty);
    await saisirEtValider(tester, 'champ_personnes_gB', '1000');
    expect(find.text(message), findsNothing);
    await saisirEtValider(tester, 'champ_personnes_gA', '0');
    expect(_personnesEcrites, [('gB', 1000), ('gA', 0)]);
  });

  testWidgets('une valeur identique à celle enregistrée ne s’écrit pas', (tester) async {
    await _afficher(tester);
    await saisirEtValider(tester, 'champ_duree', '3');
    await saisirEtValider(tester, 'champ_personnes_gA', '40');
    expect(_joursEcrits, isEmpty);
    expect(_personnesEcrites, isEmpty);
  });

  testWidgets('une saisie laissée un instant est enregistrée et signalée', (tester) async {
    await _afficher(tester);
    await tester.enterText(find.byKey(const Key('champ_personnes_gB')), '80');
    await tester.pump(const Duration(seconds: 2));
    expect(_personnesEcrites, [('gB', 80)]);
    expect(find.byKey(const Key('enregistre_personnes_gB')), findsOneWidget);
  });

  testWidgets('gestionnaire non rattaché à tous les gymnases : étape 2 en lecture seule',
      (tester) async {
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gA'}, nbGymnases: 2));
    expect(find.byKey(const Key('champ_duree')), findsNothing);
    expect(find.byKey(const Key('champ_personnes_gA')), findsNothing);
    expect(texte(tester, 'lecture_duree'), "Durée de l'événement (jours) : 3");
    expect(texte(tester, 'lecture_personnes_gA'), 'Personnes attendues : 40');
    expect(find.byKey(const Key('lecture_personnes_gB')), findsNothing);
    expect(find.text(
        'Seul le responsable, ou un gestionnaire rattaché à tous les gymnases, '
        'règle les personnes et la durée.'), findsOneWidget);
  });

  testWidgets('gestionnaire rattaché à tous les gymnases : étape 2 réglable',
      (tester) async {
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gA', 'gB'}, nbGymnases: 2));
    expect(find.byKey(const Key('champ_duree')), findsOneWidget);
    expect(find.byKey(const Key('champ_personnes_gB')), findsOneWidget);
  });

  testWidgets('événement ouvert : étape 2 encore réglable ; clôturé : lecture seule',
      (tester) async {
    await _afficher(tester, statut: 'en_cours');
    expect(find.byKey(const Key('champ_duree')), findsOneWidget);
    expect(find.byKey(const Key('champ_personnes_gA')), findsOneWidget);
    await _afficher(tester, statut: 'cloture');
    expect(find.byKey(const Key('champ_duree')), findsNothing);
    expect(find.byKey(const Key('champ_personnes_gA')), findsNothing);
    expect(texte(tester, 'lecture_duree'), "Durée de l'événement (jours) : 3");
  });

  // ---------- Étape 3 : prévision à sources.
  testWidgets('étape 3 : par défaut, les chiffres du menu, source « Menu »', (tester) async {
    await _afficher(tester);
    expect(find.byKey(const Key('titre_etape_prevision')), findsOneWidget);
    expect(find.byKey(const Key('prevision_evenement_passe')), findsOneWidget);
    // Aucune prévision enregistrée : rien à remettre au menu.
    expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('prevision_revenir_menu'))).onPressed,
        isNull);
    expect(texte(tester, 'source_soda'), 'Source : Menu');
    expect(texte(tester, 'source_croque'), 'Source : Menu');
    // Ni soda ni croque n'ont de chiffre au menu ici : 0.
    expect(tester.widget<TextField>(find.byKey(const Key('champ_conso_soda'))).controller!.text,
        '0');
  });

  testWidgets('étape 3 : le chiffre et la source de la prévision sont affichés',
      (tester) async {
    await _afficher(tester, previsions: const {
      'soda': Prevision(2, 'Événement : Tournoi 2025'),
      'croque': Prevision(1.5, sourceMain),
    });
    expect(tester.widget<TextField>(find.byKey(const Key('champ_conso_soda'))).controller!.text,
        '2');
    expect(texte(tester, 'source_soda'), 'Source : Événement : Tournoi 2025');
    expect(tester.widget<TextField>(find.byKey(const Key('champ_conso_croque'))).controller!.text,
        '1,5');
    expect(texte(tester, 'source_croque'), 'Source : Modifié à la main');
  });

  testWidgets('étape 3 : corriger un chiffre l\'enregistre (virgule ou point), '
      'une valeur invalide n\'écrit rien', (tester) async {
    await _afficher(tester);
    const message = 'Entrez une consommation de 0 à 1000.';
    for (final mauvais in ['', '-1', '1000,5', 'abc']) {
      await saisirEtValider(tester, 'champ_conso_soda', mauvais);
      expect(find.text(message), findsOneWidget, reason: '"$mauvais"');
    }
    expect(_previsionsEcrites, isEmpty);
    await saisirEtValider(tester, 'champ_conso_soda', '1,5');
    await saisirEtValider(tester, 'champ_conso_croque', '2.25');
    await saisirEtValider(tester, 'champ_conso_soda', '3');
    expect(_previsionsEcrites, [('soda', 1.5), ('croque', 2.25), ('soda', 3.0)]);
  });

  testWidgets('étape 3 : retaper le chiffre déjà affiché n\'écrit rien', (tester) async {
    await _afficher(tester, previsions: const {'soda': Prevision(2, 'Événement : T')});
    await saisirEtValider(tester, 'champ_conso_soda', '2');
    expect(_previsionsEcrites, isEmpty);
  });

  testWidgets('étape 3 : « D\'après un événement passé » propose les événements '
      'utilisables et signale les autres', (tester) async {
    const passes = EvenementsPasses([
      ReferencePassee(
          id: 'ep1', nom: 'Tournoi 2025', date: '2025-10-03', personnes: 40, jours: 2),
    ], 2);
    await _afficher(tester, passes: passes);
    await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('choix_passe_ep1')), findsOneWidget);
    expect(find.text('03/10/2025 · 40 personnes · 2 jours'), findsOneWidget);
    expect(texte(tester, 'message_sans_personnes'), messageSansPersonnes);
    await tester.tap(find.byKey(const Key('choix_passe_ep1')));
    await tester.pumpAndSettle();
    // Aucun chiffre corrigé à la main : pas de confirmation, appliqué tout de suite.
    expect(find.byKey(const Key('confirmer_prevision')), findsNothing);
    expect(_passesAppliquees, ['ep1']);
    expect(find.byKey(const Key('prevision_faite')), findsOneWidget);
  });

  testWidgets('étape 3 : aucun événement passé utilisable, seulement le message',
      (tester) async {
    await _afficher(tester, passes: const EvenementsPasses([], 1));
    await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aucun_evenement_passe')), findsOneWidget);
    expect(texte(tester, 'message_sans_personnes'), messageSansPersonnes);
    expect(_passesAppliquees, isEmpty);
  });

  testWidgets('étape 3 : des chiffres corrigés à la main demandent une confirmation',
      (tester) async {
    const passes = EvenementsPasses([
      ReferencePassee(
          id: 'ep1', nom: 'Tournoi 2025', date: '2025-10-03', personnes: 40, jours: 2),
    ], 0);
    await _afficher(tester,
        previsions: const {'soda': Prevision(2, sourceMain)}, passes: passes);
    await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choix_passe_ep1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('question_prevision')), findsOneWidget);
    await tester.tap(find.byKey(const Key('annuler_prevision')));
    await tester.pumpAndSettle();
    expect(_passesAppliquees, isEmpty);
    // « Revenir au menu » demande la même confirmation.
    await tester.tap(find.byKey(const Key('prevision_revenir_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmer_prevision')));
    await tester.pumpAndSettle();
    expect(_retoursAuMenu, 1);
  });

  testWidgets('étape 3 : ventes de l\'événement passé illisibles, message clair et '
      'rien d\'écrit', (tester) async {
    const passes = EvenementsPasses([
      ReferencePassee(
          id: 'ep1', nom: 'Tournoi 2025', date: '2025-10-03', personnes: 40, jours: 2),
    ], 0);
    await _afficher(tester, passes: passes, refus: true);
    await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choix_passe_ep1')));
    await tester.pumpAndSettle();
    expect(texte(tester, 'erreur_prevision'),
        'Les ventes de « Tournoi 2025 » ne peuvent pas être lues avec vos droits. '
        'Rien n\'a été modifié.');
    expect(_passesAppliquees, isEmpty);
    expect(_previsionsEcrites, isEmpty);
  });

  testWidgets('étape 3 : gestionnaire non rattaché à tous les gymnases, une phrase '
      'et aucun chiffre', (tester) async {
    await _afficher(tester,
        portee: const PorteeGestion(
            responsable: false, gymnases: {'gA'}, nbGymnases: 2));
    expect(find.byKey(const Key('titre_etape_prevision')), findsOneWidget);
    expect(find.byKey(const Key('champ_conso_soda')), findsNothing);
    expect(find.byKey(const Key('prevision_evenement_passe')), findsNothing);
    expect(find.text(
        'Seul le responsable, ou un gestionnaire rattaché à tous les gymnases, '
        'voit et règle la prévision de consommation.'), findsOneWidget);
  });

  testWidgets('étape 3 : événement clôturé, lecture seule avec la source',
      (tester) async {
    await _afficher(tester,
        statut: 'cloture', previsions: const {'soda': Prevision(2, 'Événement : T')});
    expect(find.byKey(const Key('champ_conso_soda')), findsNothing);
    expect(find.byKey(const Key('prevision_evenement_passe')), findsNothing);
    expect(texte(tester, 'lecture_conso_soda'), 'Par personne et par jour : 2');
    expect(texte(tester, 'source_soda'), 'Source : Événement : T');
  });

  testWidgets('étape 3 : encore réglable quand l\'événement est en cours', (tester) async {
    await _afficher(tester, statut: 'en_cours');
    expect(find.byKey(const Key('champ_conso_soda')), findsOneWidget);
    expect(find.byKey(const Key('prevision_evenement_passe')), findsOneWidget);
  });

  // ------------------------------------------------------------ P6 : importer
  group('P6 : importer un classeur', () {
    // Historique : Tournoi 2025, 2 gymnases de 20 personnes (valeur répétée), 2 jours.
    Uint8List fichier({
      List<List<Object?>> stock = const [],
      List<List<Object?>> histo = const [],
    }) =>
        classeurDeTest(stock: stock, historique: histo);
    final stockOk = <List<Object?>>[
      ['Gymnase A', 'Soda', 24],
      ['gymnase b', 'CROQUE', 12],
      ['Gymnase A', 'Café', 5],
      ['Gymnase C', 'Soda', 3],
      ['Gymnase B', 'Soda', null],
    ];
    final histoOk = <List<Object?>>[
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 100],
      ['Tournoi 2025', 'Gymnase A', 20, 2, 'Soda', 40],
      ['Tournoi 2025', 'Gymnase B', 20, 2, 'Croque', 60],
    ];

    testWidgets('critère 1 : le résumé annonce les stocks et la référence AVANT d\'appliquer',
        (tester) async {
      await _afficher(tester, classeur: fichier(stock: stockOk, histo: histoOk));
      expect(find.byKey(const Key('importer_classeur')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('importer_classeur'))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '2 stocks seront appliqués.');
      expect(texte(tester, 'resume_reference_0'),
          'Référence créée : Tournoi 2025 (Excel) — 2 produits');
      // Rien n'est écrit tant que « Appliquer » n'est pas touché.
      expect(_plansImportes, isEmpty);
      expect(find.byKey(const Key('appliquer_import')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('appliquer_import'))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.length, 1);
      final plan = _plansImportes.single;
      expect(plan.stocks.map((s) => (s.gymnaseId, s.produitId, s.quantite)),
          [('gA', 'soda', 24), ('gB', 'croque', 12)]);
      expect(plan.references.single.nom, 'Tournoi 2025 (Excel)');
      expect(texte(tester, 'confirmation_import'),
          'Stocks appliqués : 2. Références enregistrées : Tournoi 2025 (Excel).');
    });

    testWidgets('critère 4 : un produit ou un gymnase inconnu est listé « ignoré », '
        'le reste s\'applique', (tester) async {
      await _afficher(tester, classeur: fichier(stock: stockOk));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '2 stocks seront appliqués.');
      expect(find.byKey(const Key('resume_ignorees')), findsOneWidget);
      expect(find.textContaining('« Gymnase A » / « Café » : produit inconnu'),
          findsOneWidget);
      expect(find.textContaining('« Gymnase C » / « Soda » : gymnase inconnu'),
          findsOneWidget);
      expect(find.byKey(const Key('resume_aucune_reference')), findsOneWidget);
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.single.stocks.length, 2);
    });

    testWidgets('événement ouvert : 0 stock appliqué (raison dite), la référence s\'importe',
        (tester) async {
      await _afficher(tester,
          statut: 'en_cours',
          classeur: fichier(stock: stockOk, histo: histoOk));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), 'Aucun stock ne sera appliqué.');
      expect(texte(tester, 'resume_reference_0'),
          'Référence créée : Tournoi 2025 (Excel) — 2 produits');
      expect(find.textContaining(messageStockFerme), findsWidgets);
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.single.stocks, isEmpty);
      expect(_plansImportes.single.references.length, 1);
      expect(texte(tester, 'confirmation_import'),
          'Stocks appliqués : 0. Références enregistrées : Tournoi 2025 (Excel).');
    });

    testWidgets('annuler le résumé : rien n\'est écrit', (tester) async {
      await _afficher(tester, classeur: fichier(stock: stockOk, histo: histoOk));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('annuler_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes, isEmpty);
      expect(find.byKey(const Key('confirmation_import')), findsNothing);
      expect(find.byKey(const Key('erreur_import')), findsNothing);
    });

    testWidgets('choix du fichier annulé : rien ne se passe', (tester) async {
      await _afficher(tester);
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resume_import')), findsNothing);
      expect(find.byKey(const Key('erreur_import')), findsNothing);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('critère 5 : octets quelconques, message clair, aucun résumé',
        (tester) async {
      await _afficher(tester, classeur: Uint8List.fromList(List.filled(300, 7)));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'), messageClasseurIllisible);
      expect(find.byKey(const Key('resume_import')), findsNothing);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('critère 5 : un classeur d\'un autre format (sans feuille Stock ni '
        'Historique) est refusé de la même façon', (tester) async {
      await _afficher(tester, classeur: classeurAutreFormat());
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'), messageClasseurIllisible);
      expect(find.byKey(const Key('resume_import')), findsNothing);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('un modèle vide (aucune donnée) est refusé aussi', (tester) async {
      await _afficher(tester, classeur: fichier());
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'), messageClasseurIllisible);
      expect(_plansImportes, isEmpty);
    });

    testWidgets('échec à l\'écriture : message clair, le bouton redevient actif',
        (tester) async {
      await _afficher(tester,
          classeur: fichier(stock: stockOk), echecImport: Exception('réseau'));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'erreur_import'),
          startsWith('L\'import n\'a pas pu être terminé.'));
      expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('importer_classeur')))
              .onPressed,
          isNotNull);
    });

    testWidgets('événement clôturé : pas de bouton d\'import', (tester) async {
      await _afficher(tester, statut: 'cloture');
      expect(find.byKey(const Key('importer_classeur')), findsNothing);
      expect(find.byKey(const Key('telecharger_modele')), findsOneWidget);
    });

    testWidgets('gestionnaire partiel : un gymnase hors de sa portée est ignoré, '
        'avec la raison', (tester) async {
      await _afficher(tester,
          portee: const PorteeGestion(
              responsable: false, gymnases: {'gB'}, nbGymnases: 2),
          classeur: fichier(stock: [
            ['Gymnase A', 'Soda', 24],
            ['Gymnase B', 'Soda', 8],
          ]));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '1 stock sera appliqué.');
      expect(find.textContaining('ne fait pas partie de vos gymnases'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('appliquer_import')));
      await tester.pumpAndSettle();
      expect(_plansImportes.single.stocks.map((s) => s.gymnaseId), ['gB']);
    });

    testWidgets('plus de 10 lignes ignorées : la liste est repliée', (tester) async {
      await _afficher(tester, classeur: fichier(stock: [
        for (var i = 0; i < 12; i++) ['Gymnase A', 'Produit $i', 1],
      ]));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Lignes ignorées (12)'), findsOneWidget);
      expect(find.textContaining('Produit 3'), findsNothing);
      await tester.tap(find.text('Lignes ignorées (12)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Produit 3'), findsOneWidget);
    });

    testWidgets('les erreurs de lecture sont dites (ligne invalide), le reste s\'applique',
        (tester) async {
      await _afficher(tester, classeur: fichier(stock: [
        ['Gymnase A', 'Soda', 24],
        ['Gymnase A', 'Croque', 'beaucoup'],
      ]));
      await tester.tap(find.byKey(const Key('importer_classeur')));
      await tester.pumpAndSettle();
      expect(texte(tester, 'resume_stocks'), '1 stock sera appliqué.');
      expect(find.byKey(const Key('resume_erreurs')), findsOneWidget);
      expect(find.textContaining('n\'est pas un nombre'), findsOneWidget);
    });

    testWidgets('critère 3 (écran) : la référence importée est proposée dans '
        '« D\'après une source » et s\'applique', (tester) async {
      const ref = ReferenceImportee(
        id: 'tournoi-2025-excel',
        nom: 'Tournoi 2025 (Excel)',
        lignes: [LigneReference('Croque', 2.0)],
      );
      await _afficher(tester, references: const [ref]);
      await tester.tap(find.byKey(const Key('prevision_evenement_passe')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('choix_reference_tournoi-2025-excel')),
          findsOneWidget);
      expect(find.byKey(const Key('aucun_evenement_passe')), findsNothing);
      await tester.tap(find.byKey(const Key('choix_reference_tournoi-2025-excel')));
      await tester.pumpAndSettle();
      expect(_referencesAppliquees, ['tournoi-2025-excel']);
      expect(_passesAppliquees, isEmpty);
      expect(texte(tester, 'prevision_faite'),
          'Prévision calculée d\'après « Tournoi 2025 (Excel) ».');
    });
  });
  // Mission « Ergonomie de la gestion », E3 : « C'est vérifié » dans l'étape Prévision.
  testWidgets("étape 3 : « C'est vérifié » écrit la case ; « Revoir » la remet à vérifier", (tester) async {
    await _afficher(tester);
    expect(find.byKey(const Key('prevision_verifiee')), findsOneWidget);
    await tester.tap(find.byKey(const Key('prevision_verifiee')));
    await tester.pump();
    expect(_verifieesEcrites, [true]);
  });

  testWidgets("étape 3 : une prévision déjà vérifiée l'affiche et propose de la revoir", (tester) async {
    await _afficher(tester, verifiee: true);
    expect(find.byKey(const Key('prevision_verifiee')), findsNothing);
    expect(find.byKey(const Key('prevision_verifiee_ok')), findsOneWidget);
    await tester.tap(find.byKey(const Key('prevision_a_revoir')));
    await tester.pump();
    expect(_verifieesEcrites, [false]);
  });

  testWidgets("étape 3 : événement clôturé, pas de « C'est vérifié »", (tester) async {
    await _afficher(tester, statut: 'cloture', verifiee: true);
    expect(find.byKey(const Key('prevision_verifiee')), findsNothing);
    expect(find.byKey(const Key('prevision_a_revoir')), findsNothing);
    expect(find.byKey(const Key('prevision_verifiee_ok')), findsOneWidget);
  });
}

String texte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;
