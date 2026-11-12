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

import 'outils.dart';

// Mission « Prêt pour le tournoi », T3 puis A3 : le classeur du club (recette/classeur-notre-club.xlsx)
// est importé par l'assistant avec le vrai moteur de données local. Le classeur a des feuilles
// Menu et Recettes remplies (A3). L'association a déjà le menu « Les Discjonctés » (créé ici avec
// les mêmes 19 produits) : il est repris sans aucune modification, aucun menu n'est créé, et les
// recettes du classeur ne sont pas reprises. L'historique devient une référence et règle la
// prévision ; le stock de départ est sans quantité (produits non suivis). Les consommations
// attendues sont celles du relevé T3 de PLAN_STOCK_COURSES.md (ventes totales / somme personnes x
// jours). Octets = le fichier.
const _classeurClubBase64 =
    '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';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  const attendu = <String, double>{
    'Barre de céréales chocolat': 0.1549,
    'Barre de céréales fruit': 0.1549,
    'Bière': 0.6814,
    'Café': 1.4912,
    'Coca': 1.5265,
    'Croque Monsieur Chocolat': 0.6195,
    'Croque tartiflette': 0.5531,
    'Croque végé': 0.3982,
    'Croque-monsieur': 0.6327,
    'Crêpe Nutella': 1.2434,
    'Crêpe sucre': 0.6195,
    'Fruit': 1.1327,
    'Ice Tea': 0.6814,
    'Infusion': 0.2478,
    'Mars': 0.0664,
    'Oasis': 0.8451,
    'Orangina': 0.3363,
    'Thé': 0.7434,
    'Twix': 0.0664,
  };

  testWidgets('classeur du club : aucune création de menu, références, prévision égale au relevé',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await ouvrir(tester, 'club_chef', fauxGoogle('chef_club_t3'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Les Discjonctés');
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
    final produitsEvt = await depotEv.suivreProduits(evt).first;
    final idDe = {for (final p in produitsEvt) p.nom: p.id};
    final classeur = base64Decode(_classeurClubBase64);
    final lu = lireClasseur(classeur);
    expect(lu.erreurs, isEmpty);
    expect(lu.produits.length, 19);
    expect(lu.produits.where((p) => p.fiche.ingredients.isNotEmpty).length, 4);
    expect(lu.historique.length, 38);

    await tester.pumpWidget(MaterialApp(
      home: EcranImport(
        sources: SourcesImport.depuis(
            menus: menus, evenements: depotEv, uid: chefUid, responsable: true),
        evenementId: evt,
        menuPropose: 'Les Discjonctés',
        choisirClasseur: () async => classeur,
      ),
    ));
    await assistantJusquAuResume(tester);
    expect(find.textContaining('repris sans aucune modification'), findsOneWidget);
    expect(find.textContaining('ne sont pas reprises'), findsOneWidget);
    expect(find.textContaining('Référence créée : Tournoi de l\'an passé (Excel)'),
        findsOneWidget);
    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();

    expect((await menus.suivreMenus().first).map((m) => m.nom), ['Les Discjonctés']);
    final refs = await db.collection('associations/$assoId/references').get(serveur);
    expect(refs.docs.single.data()['nom'], 'Tournoi de l\'an passé (Excel)');
    for (final e in attendu.entries) {
      final doc = await db
          .collection('associations/$assoId/evenements/$evt/previsions')
          .doc(idDe[e.key])
          .get(serveur);
      expect((doc.data()!['conso'] as num).toDouble(), closeTo(e.value, 0.0001),
          reason: e.key);
    }
  });
}
