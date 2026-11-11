import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_evenements.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_courses.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/theme.dart';
import 'package:le_comptoir/ticket.dart' show EtatStock;

// Mission « Prêt pour le tournoi », étape T8 (décision 79 d) : la page Courses est rangée
// en cartes : bandeau résumé, rayons repliables avec compteur, actions fixées en bas.

class _FausseCaisses implements DepotCaisses {
  @override
  Stream<TableauDeBord> suivreTableauDeBord({Set<String>? gymnaseIds}) =>
      Stream.value(TableauDeBord.depuis(const <ResumeCaisse>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Faux dépôt : les lectures rendent des données fixes, les écritures sont notées.
class _FauxDepot implements DepotEvenements {
  _FauxDepot(this.liste);

  final ListeCourses liste;
  final List<String> appels = [];

  static const croque = ProduitEvenement('croque', 'Croque', 300, null,
      fiche: FicheProduit(type: 'compose', conso: 2, ingredients: [
        Ingredient('Pain de mie', 2, 'tranche', 'boulangerie'),
        Ingredient('Gruyère râpé', 7, 'g', 'frais'),
      ]));
  static const cafe = ProduitEvenement('cafe', 'Café', 100, null,
      fiche: FicheProduit(
          type: 'litre', conso: 2, verresParLitre: 8, rayon: 'boissons'));

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
      Stream.value(const [croque, cafe]);

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
      Stream.value(const {});

  @override
  Stream<Map<String, Prevision>> suivrePrevisions(String evenementId) =>
      Stream.value(const {});

  @override
  Stream<ListeCourses?> suivreListeCourses(String evenementId) =>
      Stream.value(liste);

  @override
  DepotCaisses caisses(String evenementId) => _FausseCaisses();

  @override
  Future<void> enregistrerListeCourses(String evenementId, ListeCourses l) async =>
      appels.add('enregistrer');

  @override
  Future<void> cocherArticle(String evenementId, String cle, bool coche) async =>
      appels.add('cocher:$cle:$coche');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _liste = ListeCourses(
  lignes: [LigneCourse('g1', 'croque', 100), LigneCourse('g1', 'cafe', 80)],
  precedent: CumulCourses(series: 1, coutCentimes: 8450),
);

Future<_FauxDepot> _afficher(WidgetTester tester,
    {ListeCourses liste = _liste, Size taille = const Size(400, 1600)}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final depot = _FauxDepot(liste);
  await tester.pumpWidget(MaterialApp(
    theme: themeComptoir(),
    home: EcranCourses(depot: depot, evenementId: 'e'),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return depot;
}

String _texte(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(Key(cle))).data!;

void main() {
  testWidgets('bandeau résumé : durée, personnes et coût cumulé', (tester) async {
    await _afficher(tester);
    expect(find.byKey(const Key('bandeau_resume')), findsOneWidget);
    expect(_texte(tester, 'resume_duree'), '2 j');
    expect(_texte(tester, 'resume_personnes'), '80');
    expect(_texte(tester, 'resume_cout'), '84,50 €');
  });

  testWidgets('bandeau résumé : sans série validée, le coût cumulé n\'est pas chiffré',
      (tester) async {
    await _afficher(tester,
        liste: const ListeCourses(lignes: [LigneCourse('g1', 'cafe', 80)]));
    expect(_texte(tester, 'resume_cout'), '—');
  });

  testWidgets('rayons : cartes avec compteur, qui suit les cases cochées',
      (tester) async {
    final depot = await _afficher(tester);
    for (final r in ['boulangerie', 'frais', 'boissons']) {
      expect(find.byKey(Key('rayon_$r')), findsOneWidget);
      expect(_texte(tester, 'compteur_rayon_$r'), '0/1');
    }
    await tester.tap(find.descendant(
        of: find.byKey(const Key('rayon_boulangerie')),
        matching: find.byType(Checkbox)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_texte(tester, 'compteur_rayon_boulangerie'), '1/1');
    expect(_texte(tester, 'compteur_rayon_boissons'), '0/1');
    expect(depot.appels.where((a) => a.startsWith('cocher:')), hasLength(1));
  });

  testWidgets('rayons : une carte se replie et se rouvre', (tester) async {
    await _afficher(tester);
    final case1 = find.descendant(
        of: find.byKey(const Key('rayon_boissons')), matching: find.byType(Checkbox));
    expect(case1, findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('rayon_boissons')),
        matching: find.text('Boissons')));
    await tester.pumpAndSettle();
    expect(case1.hitTestable(), findsNothing); // repliée : la ligne n'est plus visible
    expect(_texte(tester, 'compteur_rayon_boissons'), '0/1'); // le compteur reste
    await tester.tap(find.text('Boissons'));
    await tester.pumpAndSettle();
    expect(case1.hitTestable(), findsOneWidget);
  });

  testWidgets('actions fixées en bas, même quand la liste défile', (tester) async {
    await _afficher(tester, taille: const Size(400, 600));
    final barre = find.byKey(const Key('barre_actions'));
    expect(barre, findsOneWidget);
    final avant = tester.getRect(barre);
    expect(avant.bottom, 600);
    for (final cle in ['ajouter_libre', 'partager_liste', 'valider_courses']) {
      expect(find.byKey(Key(cle)).hitTestable(), findsOneWidget, reason: cle);
    }
    expect(find.text('Enregistrer ou partager'), findsOneWidget);
    // La liste défile jusqu'en bas : la barre ne bouge pas, les boutons restent là.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getRect(barre), avant);
    for (final cle in ['ajouter_libre', 'partager_liste', 'valider_courses']) {
      expect(find.byKey(Key(cle)).hitTestable(), findsOneWidget, reason: cle);
    }
  });

  testWidgets('les actions de la barre font ce qu\'elles faisaient', (tester) async {
    final partages = <String>[];
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: themeComptoir(),
      home: EcranCourses(
        depot: _FauxDepot(_liste),
        evenementId: 'e',
        partager: (nom, contenu) async => partages.add(nom),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const Key('partager_liste')));
    await tester.pump();
    expect(partages, ['liste-de-courses.txt']);
    await tester.tap(find.byKey(const Key('ajouter_libre')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nom_libre')), findsOneWidget);
  });

  testWidgets('onglet « Déjà acheté » : pas de barre d\'actions', (tester) async {
    await _afficher(tester);
    await tester.tap(find.byKey(const Key('onglet_achete')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('barre_actions')), findsNothing);
    expect(find.byKey(const Key('bandeau_resume')), findsOneWidget);
    expect(find.byKey(const Key('series_validees')), findsOneWidget);
  });
}
