import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/calcul_club.dart';
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
// jours). Octets = le fichier. V5 (décision 91) : le classeur porte aussi les feuilles Repas (4 lignes)
// et Groupes (41 lignes, 7 groupes) : le résumé les annonce, les écritures posent les repas et
// les groupes du tournoi (documents calcul_club/repas et calcul_club/groupes), Pomme, Banane et
// Clémentine (absents du menu) sont ignorés, et « Annuler ce changement » retire les groupes.
const _classeurClubBase64 =
    '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'
    'f4qKDjl7x6DCHW8lXenjJ+y9Sl2+Ukvrf+HYxU4nDMrWkq578pRBLVT35He9x08IsxAh7gnxC8L0XYCQ9ITkJWEWIMx6wuwFIZ4HCGlP8KVHXe3euDUn'
    'XmRGH8G46CIr3cC77wuhnLmOjMoe+RBEVkFkHUQ2Y0hk9HGQFA+SYh+a+FCh3LG4JsOKTNgio2KlW2PRZhEVWeSWHhXHQcVBZB1ENvH/FCeD4sSHzgKK'
    'r7BupICGG5BnvGmkKLk/GK9fxfFsCfIM7xptCKoWSLdGaQELKBFuWwHcRSXJkroH8PKA/fgcDL/358t0o4sxU5KgKUFkHUQ2yf9MmTFwR2/o5+EsDmbN'
    'fIp0pOOCyCqIrIPIZgx5JjXtpM7jsNbU55gHNvYLWrcfnCxUZ63fzyRZ/u4eCmtUBAuw3dwIPIfG6KoVBG90C1LsFYIUNwbfnsNtyxWJkV3Gcyj161dx'
    'Ol0SoAJsjbaA1G85dN2Fp5ppCWKvtOnzPUaK2kW+6JpnFs0HJ+beicuAE9dDjWMteJq77T15bslIntXpPN+CDo7kWp/OtXpwfIS6OU29ctsyZml3l3Wf'
    '4RrN3t9/Fkrdqr7nhtX++k4Xm+4z/hje3f1fudkLZUHijnI2ubhMGZiud7sJ6cZfCd2l64cH5BUaF5Ay2GlNDxP3guFPTfEXUEsDBBQAAAAIAAKtbF2x'
    'BVnPFwMAAIIPAAANAAAAeGwvc3R5bGVzLnhtbN1XUW+bMBD+K4gfMAi0XpgAaWWKNGmbKrUPe3WCIZaMzYzTkf766WySQMNVXZe8LCjBvs/fd2ff2VbS'
    'zuwFe9gyZry+EbLL/K0x7acg6DZb1tDug2qZ7BtRKd1Q031Qug66VjNadkBqRBCFIQkayqWfp3LXrBrTeRu1kybzQz/I00rJk4X4zpCnkjbMe6Ii8wsq'
    '+FpzO5Y2XOydOQLDRgmlPbNlDcv8BVi6ZwcvXA+iHHQaLpUGY+A8uN/1MHzCJa8Oc051vc78MFzZz5gdhWfsCeNLcheS1XmsEwbH/JE7svpIJuzwPdEO'
    '4+2ry9OKC3HMwi1kgQuRpy01hmm54kJYjjWeQd7Qfty3LPNrTfeL6NZ/M6FTgpfgsi7GsUar+CYurMyI+o+ip8W/oCgpblZLgoraV5ena6VLpo+rvPAP'
    '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'
    'eG1sUEsFBgAAAAASABIAtQQAACtLAAAAAA==';

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
    expect(lu.repas.length, 4);
    expect(lu.groupes.length, 41);

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
    expect(find.text('Repas : 2 jours, 2 gymnases.'), findsOneWidget);
    expect(find.text('Groupes : 7 groupes, 18 produits.'), findsOneWidget);
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

    // V5 : les repas et les groupes du classeur sont posés dans le tournoi.
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final idGymnase = {for (final g in gymnases) g.nom: g.id};
    final calcul = (await depotEv.suivreCalculClub(evt).first)!;
    expect({
      for (final g in ['Gymnase 1', 'Gymnase 2'])
        for (final j in [1, 2]) '$g|$j': repasDuJour(calcul, idGymnase[g]!, j),
    }, {
      'Gymnase 1|1': 119,
      'Gymnase 1|2': 130,
      'Gymnase 2|1': 141,
      'Gymnase 2|2': 121,
    });
    expect(calcul.groupes.map((g) => g.nom), [
      'Plat',
      'Dessert',
      'Fruit',
      'Barres de céréales',
      'Boissons froides',
      'Boissons alcoolisées',
      'Boissons chaudes',
    ]);
    expect(ecartsGroupes(calcul), isEmpty);
    // Croque standard, Gymnase 1 : 119 x 70 % x 40 % + 130 x 80 % x 35 % = 69,72 -> 70.
    expect(quantiteClub(calcul, idGymnase['Gymnase 1']!, idDe['Croque-monsieur']!), 70);
    expect(calcul.groupes.firstWhere((g) => g.nom == 'Plat').pourcentages, {1: 0.7, 2: 0.8});

    // « Annuler ce changement » couvre aussi les groupes (il n'y en avait pas avant : liste vide).
    final annulation = await db
        .collection('associations/$assoId/evenements/$evt/previsions_annulation')
        .doc('dernier')
        .get(serveur);
    expect(annulation.data()!['groupes'], isEmpty);
    await depotEv.annulerChangementPrevision(evt);
    await db.waitForPendingWrites();
    final apres = (await depotEv.suivreCalculClub(evt).first)!;
    expect(apres.groupes, isEmpty);
    expect(apres.repas, isNotEmpty);
  });
}
