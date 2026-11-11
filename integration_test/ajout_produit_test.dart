import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/ecran_caisse.dart';
import 'package:le_comptoir/ecran_courses.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/ecran_prevision.dart';
import 'package:le_comptoir/ecran_stock_depart.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Prêt pour le tournoi », T4 (décision 78) : en cours, la gestion ajoute un produit
// depuis « Produits et images » ; il est dans l'événement ET le menu d'origine, les produits
// existants ne changent pas, et il se retrouve dans le stock de départ, la prévision, les
// courses et la caisse (vrai moteur de données local).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets("ajout d'un produit en cours : événement, menu, stock, prévision, courses, caisse",
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'ajout_chef', fauxGoogle('chef_ajout_t4'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId, nom: 'Croque-monsieur', prixCentimes: 300);
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await creerOuvert(depotEv,
        nom: 'Tournoi', date: '2026-11-14', menuId: menuId, modes: ['especes']);
    await db.waitForPendingWrites();
    final gym = await gymnaseUnique(depotEv, evt);
    final avant = await depotEv.suivreProduits(evt).first;
    expect(avant.map((p) => p.nom), ['Café', 'Croque-monsieur']);

    // ---- L'écran « Produits et images » d'un événement en cours : bouton visible, ajout.
    await tester.pumpWidget(MaterialApp(
      home: EcranProduitsEvenement(depot: depotEv, evenementId: evt, modifiable: true),
    ));
    await attendre(tester, find.byKey(const Key('ajouter_produit_evenement')));
    await toucherCle(tester, 'ajouter_produit_evenement');
    await attendre(tester, find.byKey(const Key('nom_produit')));
    await tester.enterText(find.byKey(const Key('nom_produit')), 'Brownie');
    await tester.enterText(find.byKey(const Key('prix_produit')), '2,50');
    await tester.enterText(find.byKey(const Key('conso_produit')), '1');
    await toucherCle(tester, 'valider_produit');
    await attendre(tester, find.byKey(const Key('message_ajout_produit')));
    await db.waitForPendingWrites();
    expect(find.text("« Brownie » est ajouté à l'événement et au menu."), findsOneWidget);

    // ---- Dans l'événement ET dans le menu (même identifiant), existants intacts.
    final apres = await depotEv.suivreProduits(evt).first;
    expect(apres.map((p) => p.nom), ['Brownie', 'Café', 'Croque-monsieur']);
    final brownie = apres.firstWhere((p) => p.nom == 'Brownie');
    expect(brownie.prixCentimes, 250);
    expect(brownie.fiche.conso, 1);
    final duMenu = await menus.suivreProduits(menuId).first;
    final auMenu = duMenu.firstWhere((p) => p.nom == 'Brownie');
    expect(auMenu.id, brownie.id);
    expect(auMenu.prixCentimes, 250);
    for (final (nom, prix) in [('Croque-monsieur', 300), ('Café', 150)]) {
      expect(apres.firstWhere((p) => p.nom == nom).prixCentimes, prix);
      expect(duMenu.firstWhere((p) => p.nom == nom).prixCentimes, prix);
    }
    expect(duMenu.length, 3);

    // ---- Même nom : refusé, rien n'est écrit.
    await toucherCle(tester, 'ajouter_produit_evenement');
    await attendre(tester, find.byKey(const Key('nom_produit')));
    await tester.enterText(find.byKey(const Key('nom_produit')), ' brownie ');
    await tester.enterText(find.byKey(const Key('prix_produit')), '3');
    await toucherCle(tester, 'valider_produit');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('existe déjà'), findsWidgets);
    expect((await depotEv.suivreProduits(evt).first).length, 3);

    // ---- Stock de départ : le produit a sa ligne.
    await depotEv.definirPersonnes(evt, gym, 10);
    await depotEv.definirJours(evt, 1);
    await depotEv.definirStock(evt, gym, brownie.id, 4);
    await db.waitForPendingWrites();
    const portee = PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 1);
    await tester.pumpWidget(MaterialApp(
      home: EcranStockDepart(
        evenement: depotEv.suivreEvenement(evt),
        portee: portee,
        gymnases: depotEv.suivreGymnases(evt),
        produits: depotEv.suivreProduits(evt),
        stocks: depotEv.suivreStocksDepart(evt),
        definirStock: (g, p, q) => depotEv.definirStock(evt, g, p, q),
        onVoirGymnases: () {},
      ),
    ));
    await attendre(tester, find.byKey(const Key('entete_famille_autre')));
    await toucherCle(tester, 'entete_famille_autre'); // famille « Autre » dépliée
    await attendre(tester, find.byKey(Key('ligne_depart_${gym}_${brownie.id}')));

    // ---- Prévision : le produit a sa ligne, avec sa source.
    await tester.pumpWidget(MaterialApp(
      home: EcranPrevision(
        evenement: depotEv.suivreEvenement(evt),
        portee: portee,
        gymnases: depotEv.suivreGymnases(evt),
        produits: depotEv.suivreProduits(evt),
        previsions: depotEv.suivrePrevisions(evt),
        definirPrevision: (p, c) => depotEv.definirPrevision(evt, p, c),
        chargerPasses: () => depotEv.evenementsPasses(sauf: evt),
        appliquerPasse: (r) => depotEv.appliquerEvenementPasse(evt, r),
        revenirAuMenu: () => depotEv.revenirAuMenu(evt),
        chargerReferences: depotEv.lireReferences,
        appliquerReference: (r) => depotEv.appliquerReference(evt, r),
      ),
    ));
    await attendre(tester, find.byKey(Key('source_${brownie.id}')));

    // ---- Courses : « Brownie » (10 personnes x 1 jour x 1, moins 4 en stock) est à acheter.
    await tester.pumpWidget(MaterialApp(
      home: EcranCourses(depot: depotEv, evenementId: evt),
    ));
    await attendre(tester, find.textContaining('Brownie'));

    // ---- Caisse : le produit se vend.
    final caisseId = idCaisse(chefUid, gym);
    await depotEv.caisses(evt).ouvrirCaisse(caisseId, 'Chef');
    await db.waitForPendingWrites();
    final ev = (await depotEv.suivreEvenement(evt).first)!;
    final gymnase = (await depotEv.suivreGymnases(evt).first).single;
    await tester.pumpWidget(MaterialApp(
      home: EcranCaisseEvenement(
        uid: chefUid,
        prenom: 'Chef',
        gymnase: gymnase,
        evenement: ev,
        depotEvenements: depotEv,
        depotCaisses: depotEv.caisses(evt),
      ),
    ));
    await attendre(tester, find.byKey(Key('produit_${brownie.id}')));
  });
}
