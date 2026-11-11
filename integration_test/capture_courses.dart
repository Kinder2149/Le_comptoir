// Prépare la page Courses avec des données de démonstration, puis attend 60 s : les
// captures se prennent de l'extérieur par « adb exec-out screencap -p » (jamais depuis le
// test). Nom sans « _test » : lancer_integration.ps1 ne le lance pas.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';

import 'outils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('courses de démonstration', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await ouvrir(tester, 'responsable', fauxGoogle('chef_capture_courses'));
    await creerAssociationParLInterface(tester);
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Croque',
        prixCentimes: 300,
        fiche: const FicheProduit(type: 'compose', conso: 2, ingredients: [
          Ingredient('Pain de mie', 2, 'tranche', 'boulangerie'),
          Ingredient('Jambon blanc', 1 / 3, 'tranche', 'frais'),
          Ingredient('Gruyère râpé', 7, 'g', 'frais'),
        ]));
    await menus.ajouterProduit(menuId,
        nom: 'Café',
        prixCentimes: 100,
        fiche: const FicheProduit(
            type: 'litre', conso: 2, verresParLitre: 8, rayon: 'boissons'));
    await menus.ajouterProduit(menuId,
        nom: 'Jus de pomme',
        prixCentimes: 150,
        fiche: const FicheProduit(
            type: 'litre', conso: 1, verresParLitre: 5, rayon: 'boissons'));
    await menus.ajouterProduit(menuId,
        nom: 'Tarte',
        prixCentimes: 250,
        fiche: const FicheProduit(type: 'part'));
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await creerOuvert(depotEv,
        nom: 'Tournoi',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    final gymnases = await depotEv.suivreGymnases(evtId).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    await depotEv.definirPersonnes(evtId, gA, 80);
    await depotEv.definirPersonnes(evtId, gB, 60);
    // Une série déjà validée : le bandeau affiche un coût cumulé. La liste est posée avec
    // ses quantités (écriture normale), puis le cumul est ajouté avec les droits
    // d'administrateur de la copie locale (les règles ne l'acceptent qu'après une validation).
    final produits = await depotEv.suivreProduits(evtId).first;
    final gymnasesLus = await depotEv.suivreGymnases(evtId).first;
    final base = listeParDefaut(
        produits: produits, gymnases: gymnasesLus, jours: joursParDefaut, stocks: const {});
    await depotEv.enregistrerListeCourses(evtId, base);
    await db.waitForPendingWrites();
    final code = await restEcrire(
        'PATCH',
        'associations/$assoId/evenements/$evtId/courses/liste'
            '?updateMask.fieldPaths=cumulSeries&updateMask.fieldPaths=cumulCout',
        'owner',
        {'cumulSeries': restEntier(1), 'cumulCout': restEntier(8450)});
    debugPrint('Cumul écrit : HTTP $code');
    // Relecture au serveur : sinon la première lecture de l'écran vient du cache local,
    // qui ne connaît pas encore le cumul posé « d'ailleurs ».
    await db
        .doc('associations/$assoId/evenements/$evtId/courses/liste')
        .get(const GetOptions(source: Source.server));
    await tester.pump(const Duration(seconds: 1));

    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_gymnases')));
    await tester.pump(const Duration(seconds: 1));
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(const Key('preparer_courses')));
    await tester.pump(const Duration(seconds: 1));
    await toucher(tester, find.byKey(const Key('preparer_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    debugPrint('PRET_POUR_CAPTURE');
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Bas de page : la liste défile, les actions restent fixées.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('PRET_BAS');
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
