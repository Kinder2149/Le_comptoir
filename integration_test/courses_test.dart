import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';

import 'outils.dart';

// Chantier Stock et courses, étape 5 : réglages, quantités pré-remplies, achats
// calculés, « il reste », lignes libres, enregistrement et reprise.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  // La liste ne construit que ce qui est visible : on défile jusqu'à l'élément.
  Future<void> montrer(WidgetTester tester, Finder cible) async {
    if (cible.evaluate().isEmpty) {
      await tester.scrollUntilVisible(cible, 300,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(cible);
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await montrer(tester, cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
    }
    final f = find.byKey(Key(cle));
    final actuel = f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  Future<void> saisir(WidgetTester tester, String cle, String valeur) async {
    final f = find.byKey(Key(cle));
    await montrer(tester, f);
    await tester.enterText(f, valeur);
    await tester.pump(const Duration(milliseconds: 200));
  }

  String valeurChamp(WidgetTester tester, String cle) => tester
      .widget<TextField>(find.descendant(
          of: find.byKey(Key(cle)), matching: find.byType(TextField)))
      .controller!
      .text;

  testWidgets('courses : pré-remplissage, achats, reste, lignes libres, reprise',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : croque (composé), café (litre), tarte (part, stock bas à A).
    await ouvrir(tester, 'responsable', fauxGoogle('chef_courses'));
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
          Ingredient('Jambon blanc', 1 / 3, 'tranche'),
          Ingredient('Gruyère râpé', 7, 'g'),
        ]));
    await menus.ajouterProduit(menuId,
        nom: 'Café',
        prixCentimes: 100,
        fiche: const FicheProduit(type: 'litre', conso: 2, verresParLitre: 8));
    await menus.ajouterProduit(menuId,
        nom: 'Tarte',
        prixCentimes: 250,
        stock: 50,
        fiche: const FicheProduit(type: 'part'));
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final gymnases = await depotEv.suivreGymnases(evtId).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evtId).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final cafe = produits.firstWhere((p) => p.nom == 'Café').id;
    final tarte = produits.firstWhere((p) => p.nom == 'Tarte').id;
    // La tarte est en stock bas à A (3 sur un total de 50).
    await db
        .collection('associations')
        .doc(assoId)
        .collection('evenements')
        .doc(evtId)
        .collection('gymnases')
        .doc(gA)
        .collection('stocks')
        .doc(tarte)
        .update({'quantite': 3});

    Future<void> ouvrirCourses() async {
      await attendre(tester, find.text('Tournoi'));
      await toucher(tester, find.text('Tournoi'));
      await attendre(tester, find.byKey(const Key('voir_courses')));
      await tester.pump(const Duration(seconds: 1));
      await toucher(tester, find.byKey(const Key('voir_courses')));
      await attendre(tester, find.byKey(const Key('etat_courses')));
    }

    // Un écran très haut : toute la liste est construite, rien à défiler.
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(seconds: 1));

    await ouvrirCourses();

    // --- Rien n'est réglé : aide, pas de produit pré-rempli.
    expect(find.byKey(const Key('aide_personnes')), findsOneWidget);
    expect(find.byKey(Key('qte_${gA}_$croque')), findsNothing);

    // --- 80 et 60 personnes, 2 jours (par défaut) : 320 et 240 croques.
    await saisir(tester, 'personnes_$gA', '80');
    await saisir(tester, 'personnes_$gB', '60');
    await toucher(tester, find.byKey(const Key('recalculer')));
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    expect(valeurChamp(tester, 'qte_${gA}_$croque'), '320');
    expect(valeurChamp(tester, 'qte_${gB}_$croque'), '240');
    expect(valeurChamp(tester, 'qte_${gA}_$cafe'), '320');
    // La tarte n'a pas de consommation : décochée, mais suggérée à A (stock bas).
    expect(find.byKey(Key('qte_${gA}_$tarte')), findsNothing);
    expect(find.byKey(Key('suggere_${gA}_$tarte')), findsOneWidget);
    expect(find.byKey(Key('suggere_${gB}_$tarte')), findsNothing);

    // --- Achats : 560 croques et 560 verres de café.
    await attendreTexte(tester, 'achat_pain de mie|tranche', 'Pain de mie : 1 120 tranches');
    expect(texte(tester, 'achat_jambon blanc|tranche'), 'Jambon blanc : 187 tranches');
    expect(texte(tester, 'achat_gruyere rape|g'), 'Gruyère râpé : 3,92 kg');
    expect(texte(tester, 'achat_produit:$cafe'), 'Café : 70 L');

    // --- 320 -> 300 à A : 540 croques, pain 1 080.
    await saisir(tester, 'qte_${gA}_$croque', '300');
    await attendreTexte(tester, 'achat_pain de mie|tranche', 'Pain de mie : 1 080 tranches');

    // --- Il reste 100 tranches de pain : 980 à acheter.
    await saisir(tester, 'reste_pain de mie|tranche', '100');
    await attendreTexte(tester, 'achat_pain de mie|tranche', 'Pain de mie : 980 tranches');

    // --- Une tarte à A : cochée, puis quantité réglée.
    await toucher(tester, find.byKey(Key('coche_${gA}_$tarte')));
    await saisir(tester, 'qte_${gA}_$tarte', '12');
    await attendreTexte(tester, 'achat_produit:$tarte', 'Tarte : 12');

    // --- Ligne libre.
    await toucher(tester, find.byKey(const Key('ajouter_libre')));
    await tester.enterText(find.byKey(const Key('nom_libre')), 'Liquide vaisselle');
    await tester.enterText(find.byKey(const Key('quantite_libre')), '2');
    await toucher(tester, find.byKey(const Key('valider_libre')));
    await attendreTexte(tester, 'libre_0', 'Liquide vaisselle × 2');

    // --- Tout s'enregistre.
    await attendreTexte(tester, 'etat_courses', 'Enregistré');
    final doc = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('courses')
            .doc('liste')
            .get(serveur))
        .data()!;
    expect(doc['statut'], 'preparation');
    expect((doc['libres'] as List).single['nom'], 'Liquide vaisselle');
    expect((doc['restes'] as List).single['quantite'], 100);
    final evt = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .get(serveur))
        .data()!;
    expect(evt['nbJours'] ?? 2, 2);
    final gym = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('gymnases')
            .doc(gA)
            .get(serveur))
        .data()!;
    expect(gym['personnes'], 80);

    // --- On quitte puis on rouvre : tout est retrouvé.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await toucher(tester, find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    expect(valeurChamp(tester, 'qte_${gA}_$croque'), '300');
    expect(valeurChamp(tester, 'qte_${gB}_$croque'), '240');
    expect(valeurChamp(tester, 'personnes_$gA'), '80');
    expect(valeurChamp(tester, 'reste_pain de mie|tranche'), '100');
    expect(texte(tester, 'achat_pain de mie|tranche'), 'Pain de mie : 980 tranches');
    expect(texte(tester, 'libre_0'), 'Liquide vaisselle × 2');

    // --- Retirer la ligne libre.
    await toucher(tester, find.byKey(const Key('retirer_libre_0')));
    expect(find.byKey(const Key('libre_0')), findsNothing);
  });

  testWidgets('courses : validation, calcul inverse, ajout au stock, liste figée',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    await ouvrir(tester, 'responsable', fauxGoogle('chef_validation'));
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
          Ingredient('Jambon blanc', 1 / 3, 'tranche'),
          Ingredient('Gruyère râpé', 7, 'g'),
        ]));
    await menus.ajouterProduit(menuId,
        nom: 'Café',
        prixCentimes: 100,
        fiche: const FicheProduit(type: 'litre', conso: 2, verresParLitre: 8));
    await menus.ajouterProduit(menuId,
        nom: 'Tarte',
        prixCentimes: 250,
        stock: 4,
        fiche: const FicheProduit(type: 'part'));
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final gymnases = await depotEv.suivreGymnases(evtId).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evtId).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final cafe = produits.firstWhere((p) => p.nom == 'Café').id;
    final tarte = produits.firstWhere((p) => p.nom == 'Tarte').id;

    Future<Map<String, dynamic>?> stock(String g, String p) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('gymnases')
            .doc(g)
            .collection('stocks')
            .doc(p)
            .get(serveur))
        .data();

    expect(await stock(gA, croque), isNull); // pas de suivi avant la validation

    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_courses')));
    await tester.pump(const Duration(seconds: 1));
    await toucher(tester, find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));

    // --- La liste : 320/240 croques (A passe à 300), 320/240 verres, 12 tartes à A.
    await saisir(tester, 'personnes_$gA', '80');
    await saisir(tester, 'personnes_$gB', '60');
    await toucher(tester, find.byKey(const Key('recalculer')));
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    await saisir(tester, 'qte_${gA}_$croque', '300');
    await toucher(tester, find.byKey(Key('coche_${gA}_$tarte')));
    await saisir(tester, 'qte_${gA}_$tarte', '12');
    await attendreTexte(tester, 'achat_gruyere rape|g', 'Gruyère râpé : 3,78 kg');

    // --- Validation : tout acheté comme proposé.
    await toucher(tester, find.byKey(const Key('valider_courses')));
    await attendre(tester, find.byKey(const Key('confirmer_validation')));
    expect(texte(tester, 'rendement_$croque'),
        'Croque : +540 (Gymnase A +300 · Gymnase B +240)');
    expect(texte(tester, 'rendement_$cafe'),
        'Café : +560 (Gymnase A +320 · Gymnase B +240)');
    expect(texte(tester, 'rendement_$tarte'), 'Tarte : +12');

    // --- Moitié du gruyère (1,89 kg sur 3,78) : 270 croques, limités par le gruyère.
    await saisir(tester, 'achete_gruyere rape|g', '1,89');
    await tester.pump(const Duration(milliseconds: 300));
    expect(texte(tester, 'rendement_$croque'),
        'Croque : +270 (Gymnase A +150 · Gymnase B +120) — limité par Gruyère râpé');

    // --- Sans coût : refusé avec un message.
    await toucher(tester, find.byKey(const Key('confirmer_validation')));
    expect(find.byKey(const Key('erreur_validation')), findsOneWidget);
    expect(await stock(gA, croque), isNull); // rien n'a été ajouté

    // --- Coût saisi : validation.
    await saisir(tester, 'cout_courses', '412,50');
    await toucher(tester, find.byKey(const Key('confirmer_validation')));
    await attendre(tester, find.byKey(const Key('courses_validee')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // --- Stock : suivi démarré pour le croque et le café, tarte augmentée.
    final cA = (await stock(gA, croque))!, cB = (await stock(gB, croque))!;
    expect((cA['quantite'], cA['reference']), (150, 150));
    expect((cB['quantite'], cB['reference']), (120, 120));
    final fA = (await stock(gA, cafe))!, fB = (await stock(gB, cafe))!;
    expect((fA['quantite'], fB['quantite']), (320, 240));
    final tA = (await stock(gA, tarte))!;
    expect((tA['quantite'], tA['reference']), (16, 16)); // 4 + 12
    expect((await stock(gB, tarte))!['quantite'], 4); // pas dans les courses de B

    // --- Liste figée : bandeau, coût, ajouts, plus de bouton de validation.
    expect(texte(tester, 'cout_valide'), 'Coût : 412,50 €');
    expect(texte(tester, 'ajout_$croque'), 'Croque +270');
    expect(find.byKey(const Key('valider_courses')), findsNothing);
    final doc = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('courses')
            .doc('liste')
            .get(serveur))
        .data()!;
    expect(doc['statut'], 'validee');
    expect(doc['coutCentimes'], 41250);
    expect(doc['valideeLe'], isNotNull);

    // --- Le bilan affiche le coût (aucune vente : le résultat est négatif).
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_cout')));
    expect(texte(tester, 'bilan_cout'), 'Coût des courses : 412,50 €');
    expect(texte(tester, 'bilan_resultat'), 'Résultat : -412,50 €');
    expect(find.byKey(const Key('exporter_csv')), findsOneWidget);
    // En vue d'un gymnase : la mention, pas de coût.
    await toucher(tester, find.byKey(Key('vue_$gA')));
    expect(find.byKey(const Key('bilan_cout_commun')), findsOneWidget);
    expect(find.byKey(const Key('bilan_cout')), findsNothing);
  });
}
