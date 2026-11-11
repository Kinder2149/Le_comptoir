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

// Mission « Prêt pour le tournoi », T3 : le classeur du club (recette/classeur-notre-club.xlsx)
// est importé par l'assistant avec le vrai moteur de données local. Menu vide dans le classeur :
// aucun menu créé ; l'historique devient une référence et règle la prévision ; le stock de départ
// est sans quantité (produits non suivis). Les consommations attendues sont celles du relevé T3
// de PLAN_STOCK_COURSES.md (ventes totales / somme personnes x jours). Octets = le fichier.
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
    final produitsEvt = await depotEv.suivreProduits(evt).first;
    final idDe = {for (final p in produitsEvt) p.nom: p.id};
    final classeur = base64Decode(_classeurClubBase64);
    final lu = lireClasseur(classeur);
    expect(lu.erreurs, isEmpty);
    expect(lu.produits, isEmpty);
    expect(lu.historique.length, 38);

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
    expect(find.textContaining('aucun menu lisible'), findsOneWidget);
    expect(find.textContaining('Référence créée : Tournoi de l\'an passé (Excel)'),
        findsOneWidget);
    await toucherCle(tester, 'appliquer_import_assistant');
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();

    expect((await menus.suivreMenus().first).map((m) => m.nom), ['Menu 2026']);
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
