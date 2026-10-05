import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'outils.dart';

// Mission M5 : QR code par gymnase. Le vrai scan à la caméra n'est pas testé ici
// (un faux lecteur renvoie le texte voulu) : il est à la recette de Kinder.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  /// Les listes ne construisent que ce qui est visible : on défile jusqu'à trouver
  /// l'élément.
  Future<void> montrer(WidgetTester tester, Finder cible) async {
    final defil = find.byType(Scrollable).first;
    for (final sens in [-300.0, 300.0]) {
      for (var i = 0; i < 15 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, Offset(0, sens));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await tester.ensureVisible(cible);
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await montrer(tester, cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
  }

  testWidgets('QR code : afficher, scanner (non-membre puis membre), erreurs',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    // --- Préparation : association, menu, deux événements (un clôturé), deux gymnases.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_qr'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    final depotAsso = DepotAssociations(db);
    final menuId = await depotAsso.menus(assoId).creerMenu('Menu');
    await depotAsso.menus(assoId).ajouterProduit(menuId,
        nom: 'Café', prixCentimes: 150, stock: 10);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final ancien = await depotEv.creerEvenement(
      nom: 'Ancien tournoi',
      date: '2026-01-10',
      menuId: menuId,
      modes: ['especes'],
    );
    await depotEv.cloturerEvenement(ancien,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final gAncien = (await depotEv.suivreGymnases(ancien).first).single.id;

    // Une autre association (autre responsable) : son code ne doit pas ouvrir celle-ci.
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('autre_chef_qr')())!);
    final autreAsso = await depotAsso.creerAssociation(
        uid: auth.currentUser!.uid, nom: 'Autre club', prenom: 'Zed');
    final codeAutre = (await db.collection('associations').doc(autreAsso).get())
        .data()!['code'] as String;
    expect(codeAutre, isNot(code));

    String lien(String c, String e, String g) =>
        ecrireLienGymnase(LienGymnase(c, e, g));

    // --- Le responsable affiche le QR code du gymnase B.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_qr')())!);
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_gymnases')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(Key('partager_gymnase_$gB')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('partager_gymnase_$gB')));
    await attendre(tester, find.byKey(const Key('code_qr')));
    await finTransition(tester);
    expect(texte(tester, 'code_qr'), code);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect((qr.key! as ValueKey<String>).value, lien(code, evt, gB));
    expect(find.byKey(const Key('avertissement_qr')), findsOneWidget);

    // --- Non-membre : QR illisible, puis QR périmé, puis QR valable.
    String? aLire;
    Future<String?> lecteur(BuildContext _) async => aLire;
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await ouvrir(tester, 'lea', googleAnnule, lecteurQr: lecteur);
    await attendre(tester, find.byKey(const Key('scanner_qr')));
    await finTransition(tester);

    aLire = 'bonjour, ceci n’est pas un QR du Comptoir';
    await toucher(tester, find.byKey(const Key('scanner_qr')));
    await attendre(tester, find.byKey(const Key('erreur')));
    expect(texte(tester, 'erreur'),
        "QR code illisible : ce n'est pas un QR code du Comptoir.");

    aLire = null; // il renonce (ferme la caméra)
    await toucher(tester, find.byKey(const Key('scanner_qr')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('prenom_qr')), findsNothing);

    aLire = lien('ZZ99ZZ', evt, gB); // code d'accès périmé
    await toucher(tester, find.byKey(const Key('scanner_qr')));
    await attendre(tester, find.byKey(const Key('prenom_qr')));
    await tester.enterText(find.byKey(const Key('prenom_qr')), 'Lea');
    await tester.tap(find.byKey(const Key('valider_prenom_qr')));
    await attendre(tester, find.byKey(const Key('erreur')));
    expect(texte(tester, 'erreur'),
        "Ce QR code n'est plus valable : le code de l'association a changé. "
        'Demandez-en un nouveau.');

    aLire = lien(code, evt, gB);
    await toucher(tester, find.byKey(const Key('scanner_qr')));
    await attendre(tester, find.byKey(const Key('prenom_qr')));
    await tester.tap(find.byKey(const Key('valider_prenom_qr'))); // prénom vide
    await tester.pump();
    expect(find.text('Renseignez votre prénom.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('prenom_qr')), 'Lea');
    await tester.tap(find.byKey(const Key('valider_prenom_qr')));

    // Elle a rejoint l'association et arrive dans l'événement, gymnase B proposé.
    await attendre(tester, find.byKey(const Key('gymnase_scanne')));
    await finTransition(tester);
    final leaUid = auth.currentUser!.uid;
    expect(texte(tester, 'gymnase_scanne'), 'QR code lu : Gymnase B');
    // Le bouton du gymnase B est le premier.
    final boutons = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('ouvrir_caisse_'));
    expect((boutons.evaluate().first.widget.key! as ValueKey<String>).value,
        'ouvrir_caisse_$gB');
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gB')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_caisse'), 'Gymnase B');
    expect(
        (await db
                .collection('associations')
                .doc(assoId)
                .collection('membres')
                .doc(leaUid)
                .get(const GetOptions(source: Source.server)))
            .data()!['prenom'],
        'Lea');
    await retour(tester); // l'événement
    await retour(tester); // l'association

    // --- Membre : scanner depuis l'association, avec ses erreurs.
    await attendre(tester, find.byKey(const Key('scanner_qr')));
    Future<void> scannerEtLire(String texteQr, String attendu) async {
      aLire = texteQr;
      await toucher(tester, find.byKey(const Key('scanner_qr')));
      await attendre(tester, find.byKey(const Key('erreur_qr')));
      expect(texte(tester, 'erreur_qr'), attendu);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
          .clearSnackBars();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await scannerEtLire('pas un QR du Comptoir',
        "QR code illisible : ce n'est pas un QR code du Comptoir.");
    await scannerEtLire(lien('ZZ99ZZ', evt, gA),
        "Ce QR code n'est plus valable : le code de l'association a changé. "
        'Demandez-en un nouveau.');
    await scannerEtLire(lien(codeAutre, evt, gA),
        "Ce QR code est celui d'une autre association que la vôtre.");
    await scannerEtLire(lien(code, ancien, gAncien),
        "Cet événement est clôturé ou n'existe plus.");
    await scannerEtLire(lien(code, 'evenementInconnu1', gA),
        "Cet événement est clôturé ou n'existe plus.");
    await scannerEtLire(lien(code, evt, 'gymnaseInconnu1'),
        "Ce gymnase n'existe plus dans cet événement.");

    // --- QR valable du gymnase A alors que sa caisse du gymnase B est ouverte :
    // l'événement s'ouvre sur A, et l'ouverture est refusée tant que B n'est pas clôturée.
    aLire = lien(code, evt, gA);
    await toucher(tester, find.byKey(const Key('scanner_qr')));
    await attendre(tester, find.byKey(const Key('gymnase_scanne')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_scanne'), 'QR code lu : Gymnase A');
    expect((boutons.evaluate().first.widget.key! as ValueKey<String>).value,
        'ouvrir_caisse_$gA');
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('caisse_deja_ouverte')));
    expect(texte(tester, 'caisse_deja_ouverte'),
        "Clôturez d'abord votre caisse à Gymnase B, puis ouvrez-en une dans Gymnase A.");
  });
}
