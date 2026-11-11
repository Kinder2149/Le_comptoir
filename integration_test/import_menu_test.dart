import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_menus.dart';
import 'package:le_comptoir/evenement.dart';

import '../test/classeur_aides.dart';
import 'outils.dart';

// Mission « Préparer l'événement », étape P7 : « Importer un menu ». Un classeur construit
// en octets (une ligne de chaque type + 2 lignes invalides) est « choisi » par un sélecteur
// factice (celui du système ne se pilote pas dans un test). Le résumé s'affiche AVANT toute
// écriture ; « Annuler » ne crée rien ; « Créer le menu » crée un NOUVEAU menu ; ce menu crée
// ensuite un événement sans erreur, dont les produits portent types, recettes, ratios et
// consommations.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  List<List<Object?>> lignes() => [
        ['Croque-monsieur', 3.5, 'Composé (recette)', null, null, null,
          '2 tranche Pain de mie ; 0,25 tranche Jambon ; 25 g Gruyère', 2],
        ['Café', 1, 'Au litre', null, 8, null, null, 1.5],
        ['Tarte aux pommes', 2.5, 'À la part', 'Apporté par les bénévoles', null, 8, null, 0.75],
        ['Fruit', 0.5, 'À l\'unité', null, null, null, null, null],
        ['Prix négatif', -2, null, null, null, null, null, null],
        ['Type inconnu', 1, 'Fantaisie', null, null, null, null, null],
      ];

  testWidgets('importer un menu : résumé, création, puis un événement depuis ce menu',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_import_menu'));
    await creerAssociationParLInterface(tester);
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);

    var octets = classeurDeTest(menu: lignes());
    final uid = auth.currentUser!.uid;
    await tester.pumpWidget(MaterialApp(
      home: EcranMenus(
        depot: menus,
        assistant: assistantImport(
            depot: depotAsso, assoId: assoId, uid: uid, classeur: () => octets),
      ),
    ));
    await attendre(tester, find.byKey(const Key('aucun_menu')));

    // ---------- « Importer un menu depuis Excel » ouvre l'assistant. Un fichier d'un
    // autre format : message clair, rien de créé.
    octets = classeurAutreFormat();
    await tester.tap(find.byKey(const Key('importer_menu')));
    await attendre(tester, find.byKey(const Key('import_choisir_classeur')));
    await toucherCle(tester, 'import_choisir_classeur');
    await attendre(tester, find.byKey(const Key('erreur_import_assistant')));
    expect(find.byKey(const Key('resume_import')), findsNothing);
    expect(await menus.suivreMenus().first, isEmpty);

    // ---------- Le résumé s'affiche AVANT d'écrire ; « Annuler » ne crée rien.
    octets = classeurDeTest(menu: lignes());
    await assistantJusquAuResume(tester);
    expect(find.textContaining('sera créé (4 produits)'), findsOneWidget);
    final ignorees = contenuDe(tester, find.byKey(const Key('resume_ignorees')));
    expect(ignorees, contains('ligne 7'));
    expect(ignorees, contains('ligne 8'));
    expect(ignorees, contains('type inconnu'));
    expect(await menus.suivreMenus().first, isEmpty, reason: 'rien n\'est écrit avant');
    await tester.tap(find.byKey(const Key('annuler_import')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('resume_import')), findsNothing);
    expect(await menus.suivreMenus().first, isEmpty, reason: 'Annuler ne crée rien');

    // ---------- Un nom, puis « Appliquer » : un NOUVEAU menu avec ses produits.
    await tester.enterText(find.byKey(const Key('nom_menu_import')), 'Menu Excel');
    await tester.pump();
    await toucherCle(tester, 'import_voir_resume');
    await attendre(tester, find.byKey(const Key('appliquer_import_assistant')));
    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    expect(texte(tester, 'confirmation_import_assistant'),
        contains('Menu « Menu Excel » créé'));
    await db.waitForPendingWrites();

    final liste = await menus.suivreMenus().first;
    expect(liste.map((m) => m.nom), ['Menu Excel']);
    final menuId = liste.single.id;
    final produits = await menus.suivreProduits(menuId).first;
    expect(produits.map((p) => p.nom).toSet(),
        {'Croque-monsieur', 'Café', 'Tarte aux pommes', 'Fruit'});
    ProduitMenu p(String nom) => produits.firstWhere((x) => x.nom == nom);
    expect(p('Croque-monsieur').prixCentimes, 350);
    expect(p('Croque-monsieur').fiche.type, 'compose');
    expect(p('Croque-monsieur').fiche.conso, 2);
    expect(p('Croque-monsieur').fiche.ingredients, const [
      Ingredient('Pain de mie', 2, 'tranche'),
      Ingredient('Jambon', 0.25, 'tranche'),
      Ingredient('Gruyère', 25, 'g'),
    ]);
    expect(p('Café').fiche.type, 'litre');
    expect(p('Café').fiche.verresParLitre, 8);
    expect(p('Café').fiche.conso, 1.5);
    expect(p('Tarte aux pommes').fiche.type, 'part');
    expect(p('Tarte aux pommes').fiche.partsParEntier, 8);
    expect(p('Tarte aux pommes').fiche.provenance, 'apporte');
    expect(p('Tarte aux pommes').fiche.conso, 0.75);
    expect(p('Fruit').prixCentimes, 50);

    // ---------- Le menu importé crée un événement sans erreur, produits relus.
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi Import',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    await db.waitForPendingWrites();
    final deEvt = await depotEv.suivreProduits(evt).first;
    expect(deEvt.length, 4);
    ProduitEvenement e(String nom) => deEvt.firstWhere((x) => x.nom == nom);
    expect(e('Croque-monsieur').prixCentimes, 350);
    expect(e('Croque-monsieur').fiche.type, 'compose');
    expect(e('Croque-monsieur').fiche.ingredients.length, 3);
    expect(e('Croque-monsieur').fiche.conso, 2);
    expect(e('Café').fiche.verresParLitre, 8);
    expect(e('Tarte aux pommes').fiche.partsParEntier, 8);
    expect(e('Tarte aux pommes').fiche.provenance, 'apporte');
    expect(e('Tarte aux pommes').fiche.conso, 0.75);

    // ---------- Réimporter sous le même nom reprend le menu existant SANS le modifier ;
    // sous un autre nom, un second menu s'ajoute.
    await toucherCle(tester, 'import_voir_resume');
    await attendre(tester, find.byKey(const Key('appliquer_import_assistant')));
    expect(find.textContaining('repris sans aucune modification'), findsWidgets);
    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();
    expect((await menus.suivreMenus().first).length, 1);
    expect((await menus.suivreProduits(menuId).first).length, 4);
    await tester.enterText(find.byKey(const Key('nom_menu_import')), 'Menu Excel 2');
    await tester.pump();
    await toucherCle(tester, 'import_voir_resume');
    await attendre(tester, find.byKey(const Key('appliquer_import_assistant')));
    await toucherCle(tester, 'appliquer_import_assistant');
    await tester.pump(const Duration(seconds: 1));
    await db.waitForPendingWrites();
    final deux = await menus.suivreMenus().first;
    expect(deux.map((m) => m.nom), containsAll(['Menu Excel', 'Menu Excel 2']));
    expect((await menus.suivreProduits(menuId).first).length, 4);
  });
}
