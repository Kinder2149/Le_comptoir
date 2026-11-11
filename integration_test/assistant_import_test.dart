import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_import.dart';
import 'package:le_comptoir/evenement.dart' show dateIso;

import '../test/classeur_aides.dart';
import 'an_passe_octets.dart';
import 'outils.dart';

// Mission « Prêt pour le tournoi », T2 (décision 77) : l'assistant d'import unique, avec le
// vrai moteur de données local. L'historique est celui du classeur de l'an passé
// (recette/historique-tournoi-an-passe.xlsx) ; son menu et son stock sont vides : on y
// ajoute un menu (dont un produit absent du menu existant) et un stock de départ. Le
// sélecteur de fichier du système ne se pilote pas : un sélecteur factice rend les octets.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  // Consommation par personne et par jour du calcul à la main (import_an_passe_test).
  const attendu = <String, double>{
    'Croque-monsieur': 0.6327,
    'Coca': 1.5265,
    'Café': 1.4912,
  };

  testWidgets(
      'assistant : menu repris sans modification, références, stock par noms, prévision '
      'réglée ; un bénévole ne voit pas l\'assistant', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'assistant_chef', fauxGoogle('chef_assistant_t2'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu 2026');
    for (final nom in attendu.keys) {
      await menus.ajouterProduit(menuId,
          nom: nom, prixCentimes: 150, fiche: const FicheProduit(conso: 0.5));
    }
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi 2026',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: ['Gymnase 1', 'Gymnase 2']);
    await db.waitForPendingWrites();
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final g1 = gymnases.firstWhere((g) => g.nom == 'Gymnase 1').id;
    final g2 = gymnases.firstWhere((g) => g.nom == 'Gymnase 2').id;
    final produitsEvt = await depotEv.suivreProduits(evt).first;
    final idDe = {for (final p in produitsEvt) p.nom: p.id};
    final avantMenu = [
      for (final p in await menus.suivreProduits(menuId).first)
        (p.id, p.nom, p.prixCentimes)
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    // ---------- Le bouton « Importer » d'« Extraction et modèle » ouvre l'assistant.
    await attendre(tester, find.byKey(const Key('extraction')));
    await tester.tap(find.byKey(const Key('extraction')));
    await attendre(tester, find.byKey(const Key('carte_import')));
    await toucherCle(tester, 'importer');
    await attendre(tester, find.byKey(const Key('import_assistant')));
    expect(find.byKey(const Key('import_choisir_classeur')), findsOneWidget);
    expect(find.byKey(const Key('import_telecharger_modele')), findsOneWidget);

    // ---------- L'assistant sur l'historique de l'an passé (+ menu et stock ajoutés).
    final histo = lireClasseur(base64Decode(anPasseBase64)).historique;
    expect(histo, isNotEmpty);
    final classeur = classeurDeTest(
      menu: [
        for (final nom in [...attendu.keys, 'Gaufre'])
          [nom, 1.5, null, null, null, null, null, null],
      ],
      stock: [
        ['Gymnase 1', 'Croque-monsieur', 40],
        ['gymnase 2', 'COCA', 30],
        ['Gymnase 3', 'Coca', 1],
      ],
      historique: [
        for (final h in histo)
          [h.evenement, h.gymnase, h.personnes, h.jours, h.produit, h.quantiteVendue],
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: EcranImport(
        sources: SourcesImport.depuis(
            menus: menus, evenements: depotEv, uid: chefUid, responsable: true),
        evenementId: evt,
        menuPropose: 'Menu 2026',
        choisirClasseur: () async => classeur,
      ),
    ));
    await assistantJusquAuResume(tester);

    // Le résumé dit tout, avant toute écriture.
    expect(find.textContaining('repris sans aucune modification'), findsWidgets);
    expect(find.textContaining('Référence créée : Tournoi de l\'an passé (Excel)'),
        findsOneWidget);
    expect(find.textContaining('2 stocks seront appliqués.'), findsOneWidget);
    expect(find.textContaining('Prévision : réglée sur « Tournoi de l\'an passé (Excel) »'),
        findsOneWidget);
    expect(find.textContaining('Gaufre'), findsOneWidget); // produit absent du menu repris
    expect(find.textContaining('« Gymnase 3 » / « Coca » : gymnase inconnu'),
        findsOneWidget);
    expect(await db.collection('associations/$assoId/references').get(serveur)
            .then((s) => s.docs.length),
        0);
    expect((await menus.suivreMenus().first).length, 1);

    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();

    // ---------- Le menu de même nom n'a pas bougé (ni nouveau menu, ni produit changé).
    expect((await menus.suivreMenus().first).map((m) => m.nom), ['Menu 2026']);
    final apresMenu = [
      for (final p in await menus.suivreProduits(menuId).first)
        (p.id, p.nom, p.prixCentimes)
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    expect(apresMenu, avantMenu);

    // ---------- La référence de l'an passé est enregistrée.
    final refs = await db.collection('associations/$assoId/references').get(serveur);
    expect(refs.docs.single.data()['nom'], 'Tournoi de l\'an passé (Excel)');

    // ---------- Le stock de départ est rempli par les noms de gymnases et de produits.
    final depart = await depotEv.suivreStocksDepart(evt).first;
    expect(depart[g1]![idDe['Croque-monsieur']!]!.quantite, 40);
    expect(depart[g2]![idDe['Coca']!]!.quantite, 30);
    expect(depart[g1]!.length + depart[g2]!.length, 2);

    // ---------- La prévision est réglée sur la référence importée.
    for (final e in attendu.entries) {
      final doc = await db
          .collection('associations/$assoId/evenements/$evt/previsions')
          .doc(idDe[e.key])
          .get(serveur);
      expect((doc.data()!['conso'] as num).toDouble(), closeTo(e.value, 0.0001),
          reason: e.key);
      expect(doc.data()!['source'], 'Tournoi de l\'an passé (Excel)');
    }

    // ---------- Un bénévole ne voit pas l'assistant (ni Menus, ni Extraction).
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'benevole-assistant-t2@test.fr', password: 'secret12');
    await ouvrir(tester, 'assistant_benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucherCle(tester, 'rejoindre');
    await attendre(tester, find.byKey(const Key('parametres')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('extraction')), findsNothing);
    expect(find.byKey(const Key('menus')), findsNothing);
    expect(find.byKey(const Key('importer')), findsNothing);
  });
}
