import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_preparation.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'an_passe_octets.dart';
import 'outils.dart';

// Mission « Préparer l'événement », étape P9 : le classeur de l'an passé (quantités
// ESTIMÉES, validées par Kinder) s'importe sans erreur et donne les consommations du
// calcul à la main noté dans PLAN_STOCK_COURSES.md (« Cadrage et relevé P9 »).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Consommation par personne et par jour : (gymnase 1 + gymnase 2) ÷ 113 ÷ 2.
  const attendu = <String, double>{
    'Croque-monsieur': 0.6327,
    'Croque végé': 0.3982,
    'Croque tartiflette': 0.5531,
    'Coca': 1.5265,
    'Ice Tea': 0.6814,
    'Oasis': 0.8451,
    'Bière': 0.6814,
    'Thé': 0.7434,
    'Café': 1.4912,
    'Mars': 0.0664,
    'Twix': 0.0664,
    'Fruit': 1.1327,
    'Barre de céréales chocolat': 0.1549,
    'Croque Monsieur Chocolat': 0.6195,
    'Crêpe sucre': 0.6195,
    'Crêpe Nutella': 1.2434,
    'Orangina': 0.3363,
    'Infusion': 0.2478,
    'Barre de céréales fruit': 0.1549,
  };

  testWidgets(
      'classeur de l\'an passé : import sans erreur, consommations du calcul à la main',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'responsable', fauxGoogle('chef_an_passe'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu 2026');
    // Le menu a une partie seulement des produits du fichier (les autres sont ignorés).
    const dansLeMenu = [
      'Croque-monsieur', 'Croque végé', 'Croque tartiflette', 'Coca', 'Ice Tea',
      'Oasis', 'Bière', 'Thé', 'Café', 'Mars', 'Twix', 'Fruit',
      'Barre de céréales chocolat', 'Crêpes (3 petites)',
    ];
    for (final nom in dansLeMenu) {
      await menus.ajouterProduit(menuId,
          nom: nom, prixCentimes: 100, fiche: const FicheProduit(conso: 0.5));
    }
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi 2026',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    await db.waitForPendingWrites();
    final produits = await depotEv.suivreProduits(evt).first;
    final idDe = {for (final p in produits) p.nom: p.id};
    final Uint8List classeur = base64Decode(anPasseBase64);

    await tester.pumpWidget(MaterialApp(
      home: EcranPreparation(
        evenement: depotEv.suivreEvenement(evt),
        portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 1),
        gymnases: depotEv.suivreGymnases(evt),
        produits: depotEv.suivreProduits(evt),
        stocks: depotEv.suivreStocksDepart(evt),
        definirJours: (j) => depotEv.definirJours(evt, j),
        definirPersonnes: (g, n) => depotEv.definirPersonnes(evt, g, n),
        previsions: depotEv.suivrePrevisions(evt),
        definirPrevision: (p, c) => depotEv.definirPrevision(evt, p, c),
        chargerPasses: () => depotEv.evenementsPasses(sauf: evt),
        appliquerPasse: (r) => depotEv.appliquerEvenementPasse(evt, r),
        revenirAuMenu: () => depotEv.revenirAuMenu(evt),
        chargerReferences: depotEv.lireReferences,
        appliquerReference: (r) => depotEv.appliquerReference(evt, r),
        importer: (plan) => depotEv.appliquerImport(evt, plan),
        choisirClasseur: () async => classeur,
      ),
    ));
    await attendre(tester, find.byKey(const Key('importer_classeur')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // ---------- Import sans erreur : le résumé annonce la référence.
    await toucher(tester, find.byKey(const Key('importer_classeur')));
    await attendre(tester, find.byKey(const Key('appliquer_import')));
    expect(find.byKey(const Key('erreur_import')), findsNothing);
    expect(texte(tester, 'resume_reference_0'),
        'Référence créée : Tournoi de l\'an passé (Excel) — ${attendu.length} produits');
    await toucher(tester, find.byKey(const Key('appliquer_import')));
    await attendre(tester, find.byKey(const Key('confirmation_import')));
    await db.waitForPendingWrites();

    // ---------- La référence enregistrée = le calcul à la main (à 0,0001 près).
    final refs = await db.collection('associations/$assoId/references').get(serveur);
    expect(refs.docs.length, 1);
    expect(refs.docs.first.data()['nom'], 'Tournoi de l\'an passé (Excel)');
    final lignes = {
      for (final l in refs.docs.first.data()['lignes'] as List)
        (l as Map)['nom'] as String: (l['conso'] as num).toDouble()
    };
    expect(lignes.keys.toSet(), attendu.keys.toSet());
    for (final e in attendu.entries) {
      expect(lignes[e.key]!, closeTo(e.value, 0.0001), reason: e.key);
    }

    // ---------- Appliquée à l'événement : les produits du menu reçoivent le chiffre,
    // ceux du fichier absents du menu sont ignorés sans erreur.
    final cle = 'choix_reference_${refs.docs.first.id}';
    await toucher(tester, find.byKey(const Key('prevision_evenement_passe')));
    await attendre(tester, find.byKey(Key(cle)));
    await toucher(tester, find.byKey(Key(cle)));
    final cible = idDe['Coca']!;
    for (var i = 0;
        i < 100 &&
            texte(tester, 'source_$cible') != 'Source : Tournoi de l\'an passé (Excel)';
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await db.waitForPendingWrites();
    for (final nom in dansLeMenu) {
      final doc = await db
          .collection('associations/$assoId/evenements/$evt/previsions')
          .doc(idDe[nom])
          .get(serveur);
      if (attendu.containsKey(nom)) {
        expect((doc.data()!['conso'] as num).toDouble(), closeTo(attendu[nom]!, 0.0001),
            reason: nom);
      } else {
        expect(doc.exists, isFalse, reason: '$nom n\'est pas dans le fichier');
      }
    }
  });
}
