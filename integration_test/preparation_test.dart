import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/restes.dart';

import 'outils.dart';

// Mission « Préparer l'événement », étape P2 : l'onglet Préparation, étape 1 « Stock de départ ».
// Un reste repris est pré-rempli, marqué, corrigeable (la marque disparaît) ; 24 sodas
// saisis au gymnase A se relisent dans « Gymnases et stocks » ; aucun ingrédient dans la
// liste ; une fois l'événement ouvert, le stock de départ se lit seulement.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
    }
    final f = find.byKey(Key(cle));
    throw TestFailure('« $cle » : attendu « $attendu », obtenu '
        '« ${f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f)} »');
  }

  testWidgets(
      'stock de départ : reprise marquée, correction, lecture dans Gymnases et stocks, '
      'lecture seule après ouverture', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // ---------- Préparation : un menu (Soda ; Croque avec ingrédients), un premier
    // événement clôturé qui garde 6 sodas au Gymnase A.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_preparation'));
    await creerAssociationParLInterface(tester);
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId, nom: 'Soda', prixCentimes: 100);
    await menus.ajouterProduit(menuId,
        nom: 'Croque',
        prixCentimes: 300,
        fiche: const FicheProduit(ingredients: [
          Ingredient('Pain de mie', 2, 'tranche'),
          Ingredient('Jambon', 1, 'tranche'),
        ]));
    final depotEv = depotAsso.evenements(assoId);
    final aujourdhui = dateIso(DateTime.now());
    final evt1 = await creerOuvert(depotEv,
        nom: 'Tournoi 1',
        date: aujourdhui,
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    await depotEv.cloturerEvenement(evt1,
        parUid: auth.currentUser!.uid,
        parPrenom: 'Chef',
        nbCaissesOuvertes: 0,
        restes: const [
          Reste(nomGymnase: 'Gymnase A', nomProduit: 'Soda', quantite: 6)
        ]);
    await db.waitForPendingWrites();

    // ---------- L'événement suivant naît en préparation, avec le reste repris.
    final evt2 = await depotEv.creerEvenement(
        nom: 'Tournoi 2',
        date: aujourdhui,
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    await db.waitForPendingWrites();
    final gymnases = await depotEv.suivreGymnases(evt2).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evt2).first;
    final soda = produits.firstWhere((p) => p.nom == 'Soda').id;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;

    Future<Map<String, dynamic>?> stockDoc(String g, String p) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt2)
            .collection('gymnases')
            .doc(g)
            .collection('stocks')
            .doc(p)
            .get(serveur))
        .data();
    expect((await stockDoc(gA, soda))!['repris'], isTrue);

    // ---------- 1. Le responsable ouvre la Préparation (onglet de la gestion).
    await attendre(tester, find.text('Tournoi 2'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi 2'));
    await attendre(tester, find.byKey(const Key('voir_preparation')));
    await finTransition(tester);
    // La tâche « Stock de départ » ouvre son écran (E4) ; Soda et Croque sont dans « Autre ».
    await toucher(tester, find.byKey(const Key('voir_preparation')));
    await attendre(tester, find.byKey(const Key('aide_stock_depart')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('entete_famille_autre')));
    await finTransition(tester);

    // Aucun ingrédient dans la liste : seulement Soda et Croque.
    expect(find.text('Pain de mie'), findsNothing);
    expect(find.text('Jambon'), findsNothing);
    expect(find.byKey(Key('depart_${gA}_$soda')), findsOneWidget);

    // ---------- 2. Le reste repris est pré-rempli et marqué.
    await attendre(tester, find.byKey(Key('repris_${gA}_$soda')));
    expect(find.text('Repris'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(Key('depart_${gA}_$soda')))
            .controller!
            .text,
        '6');
    expect(find.byKey(Key('repris_${gA}_$croque')), findsNothing);

    // ---------- 3. Corriger le reste : 24 sodas ; la marque disparaît.
    await tester.enterText(find.byKey(Key('depart_${gA}_$soda')), '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0;
        i < 100 && find.byKey(Key('repris_${gA}_$soda')).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(Key('repris_${gA}_$soda')), findsNothing);
    final apres = (await stockDoc(gA, soda))!;
    expect((apres['quantite'], apres['reference']), (24, 24));
    expect(apres.containsKey('repris'), isFalse);

    // Un onglet par gymnase (E4) : on passe au Gymnase B.
    await toucher(tester, find.byKey(Key('onglet_gymnase_$gB')));
    await finTransition(tester);
    if (find.byKey(Key('depart_${gB}_$croque')).evaluate().isEmpty) {
      await toucher(tester, find.byKey(const Key('entete_famille_autre')));
      await finTransition(tester);
    }
    expect(find.byKey(Key('depart_${gB}_$croque')), findsOneWidget);
    // Un croque au Gymnase B (saisie sans marque).
    await tester.enterText(find.byKey(Key('depart_${gB}_$croque')), '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 100 && (await stockDoc(gB, croque)) == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await stockDoc(gB, croque))!['quantite'], 15);
    await db.waitForPendingWrites();

    // ---------- 4. « Gymnases et stocks » affiche 24.
    await retour(tester);
    await attendre(tester, find.byKey(const Key('voir_gymnases')));
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendreTexte(tester, 'stock_${gA}_$soda', 'Stock : 24');
    await retour(tester);

    // ---------- 5. Ouverture : le stock de départ se lit seulement et renvoie vers
    // « Gymnases et stocks ».
    await toucher(tester, find.byKey(const Key('ouvrir_evenement')));
    await attendre(
        tester, find.byKey(const Key('confirmer_ouverture_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_ouverture_evenement')));
    await attendre(
        tester,
        find.descendant(
            of: find.byKey(const Key('etat_evenement')),
            matching: find.text('En cours')));
    await attendre(tester, find.byKey(const Key('onglet_avant')));
    await toucher(tester, find.byKey(const Key('onglet_avant')));
    await attendre(tester, find.byKey(const Key('voir_preparation')));
    await toucher(tester, find.byKey(const Key('voir_preparation')));
    await attendre(tester, find.byKey(const Key('aller_gymnases_stocks')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('entete_famille_autre')));
    await finTransition(tester);
    expect(find.byKey(Key('depart_${gA}_$soda')), findsNothing); // plus de saisie de stock
    await attendreTexte(tester, 'lecture_depart_${gA}_$soda', 'Stock : 24');
    await toucher(tester, find.byKey(Key('onglet_gymnase_$gB')));
    await finTransition(tester);
    if (find.byKey(Key('lecture_depart_${gB}_$croque')).evaluate().isEmpty) {
      await toucher(tester, find.byKey(const Key('entete_famille_autre')));
      await finTransition(tester);
    }
    expect(texte(tester, 'lecture_depart_${gB}_$croque'), 'Stock : 15');
    await toucher(tester, find.byKey(const Key('aller_gymnases_stocks')));
    await attendre(tester, find.byKey(const Key('titre_stock_evenement')));
    await attendreTexte(tester, 'stock_${gA}_$soda', 'Stock : 24');
  });

  testWidgets(
      'personnes et durée : réglées dans la Préparation, lues par les courses, '
      'durée des courses locale', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_personnes_duree'));
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
          Ingredient('Pain de mie', 2, 'tranche'),
        ]));
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi P3',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    await db.waitForPendingWrites();
    final gA = (await depotEv.suivreGymnases(evt).first).single.id;
    final croque = (await depotEv.suivreProduits(evt).first).single.id;

    Future<Map<String, dynamic>> docEvt() async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .get(serveur))
        .data()!;
    Future<Map<String, dynamic>> docGym() async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('gymnases')
            .doc(gA)
            .get(serveur))
        .data()!;
    Future<void> saisirChamp(String cle, String valeur) async {
      // On touche le champ d'abord : après un « ok », il a perdu le focus.
      await tester.tap(find.byKey(Key(cle)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byKey(Key(cle)), valeur);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
    }

    String champ(String cle) =>
        tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;
    String champQte(String cle) => tester
        .widget<TextField>(find.descendant(
            of: find.byKey(Key(cle)), matching: find.byType(TextField)))
        .controller!
        .text;

    // ---------- Préparation, étape 2.
    await attendre(tester, find.text('Tournoi P3'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi P3'));
    await attendre(tester, find.byKey(const Key('onglet_avant')));
    await toucher(tester, find.byKey(const Key('onglet_avant')));
    await attendre(tester, find.byKey(const Key('tache_personnes')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('tache_personnes')));
    await attendre(tester, find.byKey(const Key('aide_personnes_duree')));
    await finTransition(tester);
    // Mission P5 : le bouton du modèle Excel est sur l'écran Classeur (bouton Excel d'Avant).
    await retour(tester);
    await toucher(tester, find.byKey(const Key('ouvrir_classeur')));
    await attendre(tester, find.byKey(const Key('telecharger_modele')));
    expect(find.byKey(const Key('telecharger_modele')), findsOneWidget);
    await retour(tester);
    await toucher(tester, find.byKey(const Key('tache_personnes')));
    await attendre(tester, find.byKey(const Key('aide_personnes_duree')));
    await finTransition(tester);
    expect(champ('champ_duree'), '2');
    expect(champ('champ_personnes_$gA'), '0');

    // Valeurs refusées : message, rien d'écrit.
    await saisirChamp('champ_duree', '31');
    expect(find.text('Entrez une durée de 0,5 à 30 jours.'), findsOneWidget);
    await saisirChamp('champ_duree', '0,4');
    expect(find.text('Entrez une durée de 0,5 à 30 jours.'), findsOneWidget);
    await saisirChamp('champ_personnes_$gA', '1001');
    expect(find.text('Entrez un nombre entier de personnes de 0 à 1000.'),
        findsOneWidget);
    await saisirChamp('champ_personnes_$gA', '-1');
    expect(find.text('Entrez un nombre entier de personnes de 0 à 1000.'),
        findsOneWidget);
    expect((await docEvt())['nbJours'] ?? 2, 2);
    expect((await docGym())['personnes'] ?? 0, 0);

    // 3 jours (virgule acceptée pour 0,5 plus loin), puis 2 jours ; 80 personnes.
    await saisirChamp('champ_duree', '3');
    await attendre(tester, find.byKey(const Key('enregistre_duree')));
    expect((await docEvt())['nbJours'], 3);
    await saisirChamp('champ_duree', '2');
    for (var i = 0; i < 100 && (await docEvt())['nbJours'] != 2; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await docEvt())['nbJours'], 2);
    await saisirChamp('champ_personnes_$gA', '80');
    await attendre(tester, find.byKey(Key('enregistre_personnes_$gA')));
    expect((await docGym())['personnes'], 80);
    await db.waitForPendingWrites();

    // ---------- Courses : 80 personnes et 2 jours, sans champ « personnes ».
    await retour(tester);
    await attendre(tester, find.byKey(const Key('voir_courses')));
    await toucher(tester, find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await finTransition(tester);
    expect(find.byKey(Key('personnes_$gA')), findsNothing);
    await ouvrirReglagesCourses(tester);
    expect(texte(tester, 'lecture_personnes_$gA'), 'Personnes attendues : 80');
    expect(find.text('Tout l’événement (2 j)'), findsOneWidget);
    expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('duree_tout'))).selected,
        isTrue);
    await ouvrirReglagesCourses(tester);
    await toucher(tester, find.byKey(const Key('recalculer')));
    // A8 : « Quantités par produit » est dans la Préparation (écran Prévision).
    await versPrevision(tester);
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    for (var i = 0;
        i < 100 && champQte('qte_${gA}_$croque') != '320';
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(champQte('qte_${gA}_$croque'), '320'); // 80 x 2 jours x 2

    // Un jour complet : choix local, la durée de l'événement ne bouge pas.
    await versCourses(tester);
    await ouvrirReglagesCourses(tester);
    await toucher(tester, find.byKey(const Key('duree_jour')));
    await ouvrirReglagesCourses(tester);
    await toucher(tester, find.byKey(const Key('recalculer')));
    await versPrevision(tester);
    for (var i = 0;
        i < 100 && champQte('qte_${gA}_$croque') != '160';
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(champQte('qte_${gA}_$croque'), '160');
    await versCourses(tester);
    await attendreTexte(tester, 'etat_courses', 'Enregistré');
    expect((await docEvt())['nbJours'], 2);

    // On quitte et on rouvre : « Tout l'événement » par défaut, toujours 2 jours.
    await retour(tester);
    await attendre(tester, find.byKey(const Key('voir_courses')));
    await toucher(tester, find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await finTransition(tester);
    await ouvrirReglagesCourses(tester);
    expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('duree_tout'))).selected,
        isTrue);
    expect(find.text('Tout l’événement (2 j)'), findsOneWidget);
    expect((await docEvt())['nbJours'], 2);
  });
}
