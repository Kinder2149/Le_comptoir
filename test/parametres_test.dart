import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/ecran_association.dart';
import 'package:le_comptoir/theme.dart';

/// Faux dépôt : enregistre les actions demandées, sans Firestore.
class FauxDepot implements DepotAssociations {
  FauxDepot(this.membres);

  final List<Membre> membres;
  final List<String> appels = [];

  static const asso = Association('a1', 'Club Test', 'ABC123');

  @override
  Stream<List<Membre>> suivreMembres(String id) => Stream.value(membres);

  @override
  Stream<Association?> suivreAssociation(String id) => Stream.value(asso);

  @override
  Future<void> nommerGestionnaire(String assoId, String membreUid) async =>
      appels.add('nommer:$membreUid');

  @override
  Future<void> retirerGestionnaire(String assoId, String membreUid) async =>
      appels.add('retirer_gestion:$membreUid');

  @override
  Future<void> retirerMembre(String assoId, String membreUid) async =>
      appels.add('sortir:$membreUid');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Faux compte : aucun compte Google connecté.
class FauxAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const chef = Membre('chef', 'Marc', 'responsable');
  const lea = Membre('lea', 'Léa', 'benevole');
  const max = Membre('max', 'Max', 'gestionnaire');
  const nina = Membre('nina', 'Nina', 'benevole', enAttente: true);

  Future<void> ouvrir(
    WidgetTester tester,
    List<Membre> membres,
    String moi,
    FauxDepot depot,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: themeComptoir(),
      home: EcranParametres(
        depot: depot,
        uid: moi,
        assoId: 'a1',
        auth: FauxAuth(),
        fournisseurGoogle: () async => null,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> ouvrirFeuille(WidgetTester tester, String uid) async {
    await tester.tap(find.byKey(Key('param_changer_$uid')));
    await tester.pumpAndSettle();
  }

  String texteBadge(WidgetTester tester, String uid) =>
      tester.widget<Text>(find.byKey(Key('param_statut_$uid'))).data!;

  testWidgets('responsable : cinq cartes, badges, bouton sur les autres seulement',
      (tester) async {
    final depot = FauxDepot([chef, lea, max]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Association et code'), findsOneWidget);
    expect(find.text('Membres (3)'), findsOneWidget);
    expect(find.byKey(const Key('qui_peut_quoi')), findsOneWidget);
    expect(find.text('Zone dangereuse'), findsOneWidget);

    expect(texteBadge(tester, 'chef'), 'Responsable');
    expect(texteBadge(tester, 'lea'), 'Bénévole');
    expect(texteBadge(tester, 'max'), 'Gestionnaire');
    expect(find.text('Changer le statut'), findsNWidgets(2));
    expect(find.byKey(const Key('param_changer_chef')), findsNothing);
    expect(find.byKey(const Key('aide_invitation')), findsNothing);
  });

  testWidgets('responsable seul : phrase sur l\'invitation par code', (tester) async {
    final depot = FauxDepot([chef]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    expect(find.byKey(const Key('aucun_autre_membre')), findsOneWidget);
    expect(find.byKey(const Key('aide_invitation')), findsOneWidget);
    expect(find.text('Changer le statut'), findsNothing);
  });

  testWidgets('gestionnaire : liste avec badges, sans action, sans zone dangereuse',
      (tester) async {
    final depot = FauxDepot([chef, lea, max]);
    await ouvrir(tester, depot.membres, 'max', depot);

    expect(find.text('Membres (3)'), findsOneWidget);
    expect(texteBadge(tester, 'lea'), 'Bénévole');
    expect(find.text('Changer le statut'), findsNothing);
    expect(find.text('Association et code'), findsNothing);
    expect(find.text('Zone dangereuse'), findsNothing);
    expect(find.byKey(const Key('qui_peut_quoi')), findsOneWidget);
  });

  testWidgets('bénévole : pas de liste des membres', (tester) async {
    final depot = FauxDepot([chef, lea, max]);
    await ouvrir(tester, depot.membres, 'lea', depot);

    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.textContaining('Membres ('), findsNothing);
    expect(find.text('Changer le statut'), findsNothing);
    expect(find.text('Zone dangereuse'), findsNothing);
    expect(find.byKey(const Key('qui_peut_quoi')), findsOneWidget);
  });

  testWidgets('badge « Gestionnaire en attente » pour un membre nommé', (tester) async {
    final depot = FauxDepot([chef, nina]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    expect(texteBadge(tester, 'nina'), 'Gestionnaire en attente');
  });

  testWidgets('nommer un bénévole : feuille, confirmation, puis nommerGestionnaire',
      (tester) async {
    final depot = FauxDepot([chef, lea]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    await ouvrirFeuille(tester, 'lea');
    expect(find.text('Changer le statut de Léa'), findsOneWidget);
    await tester.tap(find.byKey(const Key('param_nommer_lea')));
    await tester.pumpAndSettle();
    expect(depot.appels, isEmpty); // rien sans confirmation
    await tester.tap(find.byKey(const Key('confirmer_nomination')));
    await tester.pumpAndSettle();
    expect(depot.appels, ['nommer:lea']);
  });

  testWidgets('annuler la nomination ne change rien', (tester) async {
    final depot = FauxDepot([chef, lea]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    await ouvrirFeuille(tester, 'lea');
    await tester.tap(find.byKey(const Key('param_nommer_lea')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(depot.appels, isEmpty);
  });

  testWidgets('retirer le statut de gestion : bénévole, confirmation, retirerGestionnaire',
      (tester) async {
    final depot = FauxDepot([chef, max]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    await ouvrirFeuille(tester, 'max');
    await tester.tap(find.byKey(const Key('param_retirer_gestion_max')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmer_retrait')));
    await tester.pumpAndSettle();
    expect(depot.appels, ['retirer_gestion:max']);
  });

  testWidgets('retirer de l\'association : confirmation, retirerMembre', (tester) async {
    final depot = FauxDepot([chef, lea]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    await ouvrirFeuille(tester, 'lea');
    await tester.tap(find.byKey(const Key('param_sortir_lea')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmer_sortie')));
    await tester.pumpAndSettle();
    expect(depot.appels, ['sortir:lea']);
  });

  testWidgets('la feuille grise le statut actuel : pas de nomination pour un gestionnaire',
      (tester) async {
    final depot = FauxDepot([chef, max]);
    await ouvrir(tester, depot.membres, 'chef', depot);

    await ouvrirFeuille(tester, 'max');
    final nommer = tester.widget<ListTile>(find.byKey(const Key('param_nommer_max')));
    expect(nommer.enabled, isFalse);
    final benevole = tester.widget<ListTile>(find.byKey(const Key('param_retirer_gestion_max')));
    expect(benevole.enabled, isTrue);
  });
}
