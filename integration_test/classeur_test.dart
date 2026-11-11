import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_classeur.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Préparer l'événement », étape P5 : « Télécharger le modèle Excel ».
// Un événement en préparation (menu riche, stock de départ réglé), l'écran Préparation
// branché sur les vraies données ; le bouton remet un .xlsx à un partageur factice
// (la feuille de partage d'Android ne se pilote pas dans un test). Le fichier reçu, relu
// par l'application, donne exactement les produits et les stocks de l'événement.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets('le modèle téléchargé redonne les produits et les stocks de l\'événement',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_classeur'));
    await creerAssociationParLInterface(tester);
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur',
        prixCentimes: 300,
        fiche: const FicheProduit(type: 'compose', conso: 2, ingredients: [
          Ingredient('Pain de mie', 2, 'tranche'),
          Ingredient('Jambon', 0.25, 'tranche'),
          Ingredient('Gruyère', 25, 'g'),
        ]));
    await menus.ajouterProduit(menuId,
        nom: 'Café',
        prixCentimes: 100,
        fiche: const FicheProduit(type: 'litre', verresParLitre: 8, conso: 2));
    await menus.ajouterProduit(menuId,
        nom: 'Gâteau salé',
        prixCentimes: 250,
        fiche: const FicheProduit(
            type: 'part', partsParEntier: 8, provenance: 'apporte', conso: 0.75));
    await menus.ajouterProduit(menuId, nom: 'Fruit', prixCentimes: 50);

    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi Été',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    await db.waitForPendingWrites();
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evt).first;
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    await depotEv.definirStock(evt, gA, id('Croque-monsieur'), 40);
    await depotEv.definirStock(evt, gA, id('Café'), 0);
    await depotEv.definirStock(evt, gB, id('Fruit'), 25);
    await db.waitForPendingWrites();

    // ---------- Le bouton remet un .xlsx à la feuille de partage.
    String? nomFichier, typeMime;
    List<int>? octets;
    await tester.pumpWidget(MaterialApp(
      home: EcranClasseur(
        evenement: depotEv.suivreEvenement(evt),
        portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
        gymnases: depotEv.suivreGymnases(evt),
        produits: depotEv.suivreProduits(evt),
        stocks: depotEv.suivreStocksDepart(evt),
        partagerModele: (n, o, m) async {
          nomFichier = n;
          octets = o;
          typeMime = m;
        },
      ),
    ));
    await attendre(tester, find.byKey(const Key('telecharger_modele')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const Key('telecharger_modele')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(nomFichier, 'modele-tournoi-ete-${dateIso(DateTime.now())}.xlsx');
    expect(typeMime, typeMimeClasseur);
    expect(octets!.sublist(0, 2), [0x50, 0x4B]); // un zip : un vrai .xlsx

    // ---------- Aller-retour : le fichier relu donne les données de l'événement.
    final lu = lireClasseur(octets!);
    expect(lu.erreurs, isEmpty);
    final attendus = await depotEv.suivreProduits(evt).first;
    expect(lu.produits.map((p) => p.nom).toSet(),
        attendus.map((p) => p.nom).toSet());
    for (final a in attendus) {
      final b = lu.produits.firstWhere((p) => p.nom == a.nom);
      expect(b.prixCentimes, a.prixCentimes, reason: a.nom);
      expect(b.fiche.type, a.fiche.type, reason: a.nom);
      expect(b.fiche.provenance, a.fiche.provenance, reason: a.nom);
      expect(b.fiche.verresParLitre, a.fiche.verresParLitre, reason: a.nom);
      expect(b.fiche.partsParEntier, a.fiche.partsParEntier, reason: a.nom);
      expect(b.fiche.conso, a.fiche.conso, reason: a.nom);
      expect(b.fiche.ingredients, a.fiche.ingredients, reason: a.nom);
    }
    final stocks = await depotEv.suivreStocksDepart(evt).first;
    final nomGym = {gA: 'Gymnase A', gB: 'Gymnase B'};
    expect(lu.stocks.length, 2 * attendus.length);
    for (final s in lu.stocks) {
      final gid = nomGym.entries.firstWhere((e) => e.value == s.gymnase).key;
      final pid = attendus.firstWhere((p) => p.nom == s.produit).id;
      expect(s.quantite, stocks[gid]?[pid]?.quantite,
          reason: '${s.gymnase} / ${s.produit}');
    }
    int? q(String g, String p) => lu.stocks
        .firstWhere((s) => s.gymnase == g && s.produit == p)
        .quantite;
    expect(q('Gymnase A', 'Café'), 0);
    expect(q('Gymnase B', 'Fruit'), 25);
    expect(q('Gymnase B', 'Café'), isNull);
  });
}
