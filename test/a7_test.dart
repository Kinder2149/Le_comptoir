import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/ecran_accueil.dart';
import 'package:le_comptoir/ecran_association.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _Depot implements DepotAssociations {
  _Depot(this.membres);

  final List<Membre> membres;
  final List<String> appels = [];

  @override
  Stream<List<Membre>> suivreMembres(String id) => Stream.value(membres);

  @override
  Stream<Association?> suivreAssociation(String id) =>
      Stream.value(const Association('a1', 'Club Test', 'ABC234'));

  @override
  Future<String> rejoindre({
    required String uid,
    required String codeSaisi,
    required String prenom,
  }) async {
    appels.add('rejoindre:$uid:$codeSaisi:$prenom');
    return 'a1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Utilisateur implements User {
  @override
  String get uid => 'nouveau';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthSansCompte implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? get currentUser => _Utilisateur();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("lien de l'association", () {
    test('écriture et lecture : code seul, sans événement ni gymnase', () {
      expect(ecrireLienAssociation('AB12CD'),
          'lecomptoir://rejoindre?v=1&c=AB12CD');
      final lien = lireLienGymnase(ecrireLienAssociation('AB12CD'));
      expect(lien, const LienGymnase('AB12CD', '', ''));
      expect(lien.sansGymnase, isTrue);
    });

    test('les anciens liens de gymnase fonctionnent inchangés', () {
      const l = LienGymnase('AB12CD', 'evt1', 'g1');
      expect(ecrireLienGymnase(l),
          'lecomptoir://rejoindre?v=1&c=AB12CD&e=evt1&g=g1');
      expect(lireLienGymnase(ecrireLienGymnase(l)), l);
      expect(l.sansGymnase, isFalse);
    });

    test('un lien illisible ou incomplet est refusé', () {
      for (final mauvais in [
        'n importe quoi',
        'lecomptoir://rejoindre?v=1',
        'lecomptoir://rejoindre?v=1&c=AB1',
        'lecomptoir://rejoindre?v=2&c=AB12CD',
        'lecomptoir://rejoindre?v=1&c=AB12CD&e=evt1', // gymnase manquant
        'lecomptoir://rejoindre?v=1&c=AB12CD&g=g1', // événement manquant
        'autre://rejoindre?v=1&c=AB12CD',
      ]) {
        expect(() => lireLienGymnase(mauvais), throwsFormatException,
            reason: mauvais);
      }
    });
  });

  group('Paramètres', () {
    const chef = Membre('chef', 'Marc', 'responsable');
    const max = Membre('max', 'Max', 'gestionnaire');
    const lea = Membre('lea', 'Léa', 'benevole');
    const nina = Membre('nina', 'Nina', 'benevole', enAttente: true);

    Future<void> ouvrir(WidgetTester tester, String moi) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: themeComptoir(),
        home: EcranParametres(
          depot: _Depot([chef, max, lea, nina]),
          uid: moi,
          assoId: 'a1',
          auth: _AuthSansCompte(),
          fournisseurGoogle: () async => null,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Color fondBadge(WidgetTester tester, Key cle) {
      final c = tester.widget<Container>(find
          .ancestor(of: find.byKey(cle), matching: find.byType(Container))
          .first);
      return (c.decoration! as BoxDecoration).color!;
    }

    testWidgets('un badge de couleur différente par rôle, le même partout',
        (tester) async {
      await ouvrir(tester, 'chef');
      final fonds = {
        for (final u in ['chef', 'max', 'lea', 'nina'])
          u: fondBadge(tester, Key('param_statut_$u')),
      };
      expect(fonds.values.toSet().length, 4, reason: '$fonds');
      expect(fonds['chef'], couleursRole('responsable').$1);
      expect(fonds['max'], couleursRole('gestionnaire').$1);
      expect(fonds['lea'], couleursRole('benevole').$1);
      expect(fonds['nina'], couleursRole('benevole', enAttente: true).$1);

      // Les badges de « Qui peut quoi » reprennent les mêmes couleurs.
      await tester.tap(find.byKey(const Key('qui_peut_quoi')));
      await tester.pumpAndSettle();
      for (final r in ['responsable', 'gestionnaire', 'benevole']) {
        expect(fondBadge(tester, Key('droits_badge_$r')), couleursRole(r).$1,
            reason: r);
      }
    });

    testWidgets('« Qui peut quoi » : une carte par rôle avec une liste à puces',
        (tester) async {
      await ouvrir(tester, 'lea');
      await tester.tap(find.byKey(const Key('qui_peut_quoi')));
      await tester.pumpAndSettle();
      for (final r in ['responsable', 'gestionnaire', 'benevole']) {
        final carte = find.byKey(Key('droits_$r'));
        expect(carte, findsOneWidget, reason: r);
        expect(find.byKey(Key('droits_badge_$r')), findsOneWidget);
        expect(find.descendant(of: carte, matching: find.text('•  ')),
            findsAtLeastNWidgets(2),
            reason: r);
      }
      expect(
          find.descendant(
              of: find.byKey(const Key('droits_benevole')),
              matching: find.text('Tient sa caisse')),
          findsOneWidget);
    });

    testWidgets("le responsable voit le QR de l'association avec le bon contenu",
        (tester) async {
      await ouvrir(tester, 'chef');
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect((qr.key! as ValueKey<String>).value, 'lecomptoir://rejoindre?v=1&c=ABC234');
      expect(lireLienGymnase((qr.key! as ValueKey<String>).value).codeAssociation, 'ABC234');
      expect(find.byKey(const Key('explication_qr_asso')), findsOneWidget);
    });

    testWidgets('gestionnaire et bénévole ne voient pas le QR', (tester) async {
      for (final u in ['max', 'lea', 'nina']) {
        await ouvrir(tester, u);
        expect(find.byType(QrImageView), findsNothing, reason: u);
        expect(find.byKey(const Key('explication_qr_asso')), findsNothing);
      }
    });
  });

  Future<List<LienGymnase>> scanner(
      WidgetTester tester, _Depot depot, String texteQr,
      String titreDialogue) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final liens = <LienGymnase>[];
    await tester.pumpWidget(MaterialApp(
      home: EcranAccueil(
        depot: depot,
        auth: _Auth(),
        fournisseurGoogle: () async => null,
        lecteurQr: (_) async => texteQr,
        surLien: liens.add,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('scanner_qr')));
    await tester.tap(find.byKey(const Key('scanner_qr')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(titreDialogue)),
        findsOneWidget);
    await tester.enterText(find.byKey(const Key('prenom_qr')), 'Zoé');
    await tester.tap(find.byKey(const Key('valider_prenom_qr')));
    await tester.pumpAndSettle();
    return liens;
  }

  testWidgets(
      "accueil : scanner le QR de l'association = entrer comme bénévole, sans événement",
      (tester) async {
    final depot = _Depot(const []);
    final liens = await scanner(tester, depot, ecrireLienAssociation('ABC234'),
        "Rejoindre l'association");
    expect(depot.appels, ['rejoindre:nouveau:ABC234:Zoé']);
    expect(liens, isEmpty, reason: "aucun événement ne doit s'ouvrir");
  });

  testWidgets("accueil : un QR de gymnase ouvre toujours l'événement",
      (tester) async {
    final depot = _Depot(const []);
    final liens = await scanner(tester, depot,
        ecrireLienGymnase(const LienGymnase('ABC234', 'evt1', 'g1')),
        'Rejoindre ce gymnase');
    expect(depot.appels, ['rejoindre:nouveau:ABC234:Zoé']);
    expect(liens, [const LienGymnase('ABC234', 'evt1', 'g1')]);
  });
}
