import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_extraction.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/firebase_options.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Retours du terrain », étape F7 (critère de fin, décision 68 à 74) : le parcours
// complet sur deux téléphones simulés.
//   Téléphone B = l'application affichée (le responsable, compte Google simulé).
//   Téléphone A = une seconde connexion (autre instance Firebase, compte e-mail de Léa).
// Déroulé : caisse avec message de stock, ligne retirée (message disparu), ligne remise
// (message revenu), vente encaissée ; la vente de A se voit sur B, et après « glisser vers
// le bas » ; Paramètres du responsable (liste des membres et ses actions) ; Paramètres d'un
// gestionnaire (liste sans aucun bouton) ; écran « Extraction et modèle » (quatre cartes) ;
// modèle, classeur d'un menu et export d'un tournoi téléchargés (remise simulée, relus) ;
// comparaison de deux tournois (chiffres à la main, comme F6).
// Captures : /sdcard/Pictures/lc_captures, à récupérer vers audit_front/retours_terrain/apres/.
const captures = bool.fromEnvironment('CAPTURES');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets(
      'critère de fin « Retours du terrain » : deux téléphones, caisse sans message fantôme, '
      'ventes de l\'autre téléphone, membres dans Paramètres, Extraction et modèle, comparaison',
      (tester) async {
    debugPrint('ETAPE surface');
    WidgetsApp.debugAllowBannerOverride = false; // pas de bandeau « DEBUG » sur les captures
    // Les captures sont facultatives (--dart-define=CAPTURES=true) : sur l'émulateur du poste, la
    // conversion de la surface en image fige le parcours après le démarrage. L'autre IA de
    // vérification photographie les écrans elle-même (R9).
    if (captures) await binding.convertFlutterSurfaceToImage();
    debugPrint('ETAPE surface ok');
    final db = FirebaseFirestore.instance; // téléphone B
    final auth = FirebaseAuth.instance;
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await auth.signOut();

    Future<void> pause([int ms = 500]) => tester.pump(Duration(milliseconds: ms));

    Future<void> photo(String nom) async {
      if (!captures) return;
      await pause(700);
      final octets = await binding.takeScreenshot(nom);
      final dossier = Directory('/sdcard/Pictures/lc_captures')..createSync(recursive: true);
      File('${dossier.path}/$nom.png').writeAsBytesSync(octets);
      debugPrint('CAPTURE $nom');
    }

    /// Fait défiler jusqu'à [cible] (dans [defil] si donné), puis la rend visible.
    Future<void> montrer(Finder cible, {Finder? defil}) async {
      final liste = defil ?? find.byType(Scrollable).first;
      if (cible.evaluate().isEmpty) {
        try {
          await tester.scrollUntilVisible(cible, 150, scrollable: liste, maxScrolls: 40);
        } catch (_) {
          await tester.scrollUntilVisible(cible, -150, scrollable: liste, maxScrolls: 80);
        }
      }
      await tester.ensureVisible(cible);
      await pause(300);
    }

    Future<void> toucher(Finder cible, {Finder? defil}) async {
      await montrer(cible, defil: defil);
      await tester.tap(cible);
      await pause(400);
    }

    Future<void> retour() async {
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await pause(800);
    }

    /// Attend que [cle] affiche exactement [attendu] (lecture en direct).
    Future<void> attendreTexte(String cle, String attendu) async {
      for (var i = 0; i < 150; i++) {
        await pause(100);
        final f = find.byKey(Key(cle));
        if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
      }
      final f = find.byKey(Key(cle));
      final actuel = f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
      throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
    }

    /// Attend qu'un élément apparaisse ou disparaisse ([present]).
    Future<void> attendrePresence(Finder cible, bool present, String quoi) async {
      for (var i = 0; i < 150; i++) {
        await pause(100);
        if (cible.evaluate().isNotEmpty == present) return;
      }
      throw TestFailure('$quoi : ${present ? 'jamais affiché' : 'toujours affiché'}');
    }

    /// Changement de téléphone (session) sur le téléphone B.
    Future<void> changerDeSession(Future<void> Function() connexion) async {
      await tester.pumpWidget(const SizedBox());
      await auth.signOut();
      await connexion();
    }

    /// Ouvre Paramètres depuis l'écran de l'association (le bouton reste inactif tant que le
    /// membre n'est pas chargé : on retente le geste).
    Future<void> ouvrirParametres() async {
      for (var i = 0; i < 60; i++) {
        if (find.byKey(const Key('mon_statut')).evaluate().isNotEmpty) break;
        if (find.byKey(const Key('parametres')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('parametres')));
        }
        await pause(300);
      }
      await attendre(tester, find.byKey(const Key('mon_statut')));
    }

    /// Glisser vers le bas sur l'écran affiché : relit le serveur, rien ne se bloque, aucun
    /// message d'erreur (en ligne).
    Future<void> glisser() async {
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      for (var i = 0; i < 10; i++) {
        await pause(500);
      }
      expect(find.byKey(const Key('message_actualisation')), findsNothing);
    }

    // ---------- 1. Téléphone B (responsable) : association, menus, tournoi ouvert, stock.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_retours'));
    await creerAssociationParLInterface(tester, nom: 'Club Retours', prenom: 'Chef');
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu retours');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, fiche: const FicheProduit(type: 'part'));
    await menus.ajouterProduit(menuId,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit());
    final depotEv = depotAsso.evenements(assoId);
    final evt = await creerOuvert(depotEv,
        nom: 'Tournoi retours',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes', 'carte']);
    await donnerStock(depotEv, evt, 'Croque-monsieur', 1); // le dernier exemplaire
    final gym = await gymnaseUnique(depotEv, evt);
    final produits = await depotEv.suivreProduits(evt).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    final soda = produits.firstWhere((p) => p.nom == 'Soda').id;
    await db.waitForPendingWrites();

    // ---------- 2. Caisse de B : le dernier croque déclenche le message de stock.
    await attendre(tester, find.text('Tournoi retours'));
    await toucher(find.text('Tournoi retours'));
    await attendre(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await toucher(find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await toucher(find.byKey(Key('produit_$croque')));
    await attendre(tester, find.byKey(const Key('alerte_stock')));
    expect(contenuDe(tester, find.byKey(const Key('alerte_stock'))).contains('Croque-monsieur'),
        isTrue);
    await photo('01_caisse_message_stock');

    // Ligne retirée : le message disparaît avec elle.
    await toucher(find.byKey(Key('retirer_$croque')));
    await attendrePresence(find.byKey(const Key('alerte_stock')), false,
        'message de stock après retrait de la ligne');
    await photo('02_caisse_ligne_retiree');

    // Ligne remise : le message revient.
    await toucher(find.byKey(Key('produit_$croque')));
    await attendre(tester, find.byKey(const Key('alerte_stock')));
    await photo('03_caisse_ligne_remise');

    // Vente encaissée malgré le message (jamais bloquée) : le ticket repart à zéro, sans message.
    await toucher(find.byKey(const Key('encaisser_carte')));
    await attendrePresence(find.byKey(const Key('alerte_stock')), false,
        'message de stock après encaissement');
    await db.waitForPendingWrites();
    await photo('04_caisse_vente_encaissee');
    await retour();

    // ---------- 3. Téléphone A (Léa) : rejoint, ouvre sa caisse, vend deux sodas.
    final appA = await Firebase.initializeApp(
        name: 'telephoneA', options: DefaultFirebaseOptions.android);
    final authA = FirebaseAuth.instanceFor(app: appA);
    await authA.useAuthEmulator('10.0.2.2', 9099);
    final dbA = FirebaseFirestore.instanceFor(app: appA);
    dbA.useFirestoreEmulator('10.0.2.2', 8080);
    await authA.createUserWithEmailAndPassword(
        email: 'lea.retours@test.fr', password: 'secret12');
    final leaUid = authA.currentUser!.uid;
    await DepotAssociations(dbA).rejoindre(uid: leaUid, codeSaisi: code, prenom: 'Lea');
    await dbA.waitForPendingWrites();
    final depotEvA = DepotAssociations(dbA).evenements(assoId);
    final caisseLea = idCaisse(leaUid, gym);
    await depotEvA.caisses(evt).ouvrirCaisse(caisseLea, 'Lea');
    await dbA.waitForPendingWrites();
    depotEvA.caisses(evt).enregistrerVente(
        caisseLea, [LigneVente(soda, 'Soda', 100, 2)], 'especes', stocks: const {});
    await dbA.waitForPendingWrites();

    // ---------- 4. Téléphone B : la vente de A se voit sur le Pendant, puis après glisser.
    await toucher(find.byKey(const Key('onglet_pendant')));
    await attendre(tester, find.byKey(const Key('pendant_total')));
    await attendreTexte('pendant_total', 'Ventes : 2 · 5,00 €');
    await photo('05_pendant_vente_autre_telephone');
    await glisser();
    await attendreTexte('pendant_total', 'Ventes : 2 · 5,00 €');
    await photo('06_pendant_apres_glisser');
    for (var i = 0; i < 4 && find.byKey(const Key('parametres')).evaluate().isEmpty; i++) {
      await retour();
    }

    // ---------- 5. Paramètres du responsable : la liste des membres et ses actions.
    await ouvrirParametres();
    await attendre(tester, find.byKey(Key('param_membre_$leaUid')));
    expect(find.byKey(Key('param_nommer_$leaUid')), findsOneWidget);
    expect(find.byKey(Key('param_sortir_$leaUid')), findsOneWidget);
    await toucher(find.byKey(Key('param_nommer_$leaUid')));
    await attendreTexte('param_statut_$leaUid', 'Gestionnaire en attente');
    expect(find.byKey(Key('param_retirer_gestion_$leaUid')), findsOneWidget);
    expect(find.byKey(Key('param_nommer_$leaUid')), findsNothing);
    await photo('07_parametres_responsable');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await pause(800);

    // ---------- 6. Léa devient gestionnaire (Google, depuis ses Paramètres) : liste sans bouton.
    await changerDeSession(() async {
      await auth.signInWithEmailAndPassword(
          email: 'lea.retours@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'lea_gestion', fauxGoogle('lea_google'));
    await attendre(tester, find.byKey(const Key('parametres')));
    await toucher(find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('activer_gestionnaire')));
    await toucher(find.byKey(const Key('activer_gestionnaire')));
    await attendreTexte('mon_statut', 'Statut : Gestionnaire');
    await attendre(tester, find.byKey(Key('param_membre_$chefUid')));
    expect(find.byKey(Key('param_nommer_$chefUid')), findsNothing);
    expect(find.byKey(Key('param_sortir_$chefUid')), findsNothing);
    expect(find.byKey(Key('param_retirer_gestion_$leaUid')), findsNothing);
    expect(find.byKey(Key('param_sortir_$leaUid')), findsNothing);
    expect(find.byKey(Key('param_nommer_$leaUid')), findsNothing);
    expect(find.byKey(const Key('qui_peut_quoi')), findsOneWidget);
    await photo('08_parametres_gestionnaire');

    // ---------- 7. Retour au téléphone B (responsable) : Extraction et modèle.
    await changerDeSession(() async {
      await auth.signInWithCredential((await fauxGoogle('chef_retours')())!);
    });
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'responsable_fin', googleAnnule);
    await attendre(tester, find.byKey(const Key('extraction')));
    await toucher(find.byKey(const Key('extraction')));
    await attendre(tester, find.byKey(const Key('carte_modele_vierge')));
    expect(find.byKey(const Key('carte_donnees_association')), findsOneWidget);
    expect(find.byKey(const Key('carte_export_tournoi')), findsOneWidget);
    expect(find.byKey(const Key('carte_comparateur')), findsOneWidget);
    await photo('09_extraction_quatre_cartes');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await pause(800);

    // Deux tournois clôturés (chiffres de la comparaison à la main, comme F6).
    final menuComp = await menus.creerMenu('Menu comparaison');
    await menus.ajouterProduit(menuComp,
        nom: 'Croque-monsieur', prixCentimes: 300, fiche: const FicheProduit(conso: 1));
    await menus.ajouterProduit(menuComp,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 1));
    final un = await creerOuvert(depotEv,
        nom: 'Tournoi un',
        date: '2025-10-03',
        menuId: menuComp,
        modes: ['especes'],
        gymnases: ['Gymnase A', 'Gymnase B']);
    final gymnasesUn = await depotEv.suivreGymnases(un).first;
    final gymA = gymnasesUn.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gymB = gymnasesUn.firstWhere((g) => g.nom == 'Gymnase B').id;
    await depotEv.definirPersonnes(un, gymA, 40);
    await depotEv.definirPersonnes(un, gymB, 30);
    await depotEv.definirJours(un, 2);
    final produitsUn = await depotEv.suivreProduits(un).first;
    final croqueUn = produitsUn.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    final sodaUn = produitsUn.firstWhere((p) => p.nom == 'Soda').id;
    await depotEv.definirStock(un, gymA, croqueUn, 500);
    await depotEv.definirStock(un, gymA, sodaUn, 500);
    final caissesUn = depotEv.caisses(un);
    final caisseUn = idCaisse(chefUid, gymA);
    await caissesUn.ouvrirCaisse(caisseUn, 'Chef');
    await db.waitForPendingWrites();
    caissesUn.enregistrerVente(
        caisseUn, [LigneVente(croqueUn, 'Croque-monsieur', 300, 60)], 'especes',
        stocks: const {});
    caissesUn.enregistrerVente(
        caisseUn, [LigneVente(sodaUn, 'Soda', 100, 40)], 'especes', stocks: const {});
    await db.waitForPendingWrites();
    await caissesUn.cloturerCaisse(caisseUn);
    await depotEv.cloturerEvenement(un, parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    final deux = await creerOuvert(depotEv,
        nom: 'Tournoi deux',
        date: '2025-10-10',
        menuId: menuComp,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    final gymA2 = (await depotEv.suivreGymnases(deux).first).first.id;
    await depotEv.definirPersonnes(deux, gymA2, 25);
    await depotEv.definirJours(deux, 1);
    final produitsDeux = await depotEv.suivreProduits(deux).first;
    final croqueDeux = produitsDeux.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    await depotEv.definirStock(deux, gymA2, croqueDeux, 500);
    final caissesDeux = depotEv.caisses(deux);
    final caisseDeux = idCaisse(chefUid, gymA2);
    await caissesDeux.ouvrirCaisse(caisseDeux, 'Chef');
    await db.waitForPendingWrites();
    caissesDeux.enregistrerVente(
        caisseDeux, [LigneVente(croqueDeux, 'Croque-monsieur', 300, 10)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();
    await caissesDeux.cloturerCaisse(caisseDeux);
    await depotEv.cloturerEvenement(deux, parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    // ---------- 8. Écran Extraction et modèle : téléchargements relus, puis comparaison.
    final remis = <List<int>>[];
    await tester.pumpWidget(MaterialApp(
      home: EcranExtraction(
        depot: depotAsso,
        uid: chefUid,
        assoId: assoId,
        responsable: true,
        partager: (nom, octets, type) async => remis.add(octets),
      ),
    ));
    await attendre(tester, find.byKey(const Key('telecharger_modele_vierge')));

    // Modèle vierge : téléchargé, relu (toutes ses feuilles présentes).
    await toucher(find.byKey(const Key('telecharger_modele_vierge')));
    for (var i = 0; i < 100 && remis.isEmpty; i++) {
      await pause(100);
    }
    expect(remis, hasLength(1));
    final modele = Excel.decodeBytes(remis[0]);
    expect(modele.tables.keys, containsAll(feuillesModele));
    await photo('10_extraction_modele_telecharge');

    // Données de l'association : le menu, sa composition et sa prévision.
    await toucher(find.byKey(const Key('choix_menu')));
    await toucher(find.byKey(Key('menu_$menuId')).last);
    await toucher(find.byKey(const Key('telecharger_donnees_menu')));
    for (var i = 0; i < 100 && remis.length < 2; i++) {
      await pause(100);
    }
    expect(remis, hasLength(2));
    final donnees = lireClasseur(remis[1]);
    expect(donnees.produits.map((p) => p.nom), containsAll(['Croque-monsieur', 'Soda']));
    await photo('11_extraction_donnees_menu_telechargees');

    // Export d'un tournoi clôturé : le même classeur que l'onglet Après.
    await toucher(find.byKey(Key('tournoi_$un')));
    for (var i = 0; i < 100 && remis.length < 3; i++) {
      await pause(100);
    }
    expect(remis, hasLength(3));
    final export = Excel.decodeBytes(remis[2]);
    expect(export.tables.keys, containsAll(feuillesExport));
    await photo('12_extraction_export_tournoi');

    // Comparaison : deux tournois clôturés, chiffres égaux au calcul à la main.
    tester.view.physicalSize = const Size(1080, 9000);
    await pause(300);
    for (var i = 0; i < 100; i++) {
      await pause(100);
      if (tester.widget<OutlinedButton>(find.byKey(const Key('comparateur'))).onPressed !=
          null) {
        break;
      }
    }
    await toucher(find.byKey(const Key('comparateur')));
    await attendre(tester, find.byKey(const Key('choix_tournoi_a')));
    await tester.tap(find.byKey(const Key('choix_tournoi_a')));
    await pause(400);
    await tester.tap(find.byKey(Key('a_$un')).last);
    await pause(400);
    await tester.tap(find.byKey(ValueKey('choix_tournoi_b_$un')));
    await pause(400);
    await tester.tap(find.byKey(Key('b_$deux')).last);
    await attendre(tester, find.byKey(const Key('synthese')));
    expect(texte(tester, 'valeur_0_a'), '70');
    expect(texte(tester, 'valeur_0_b'), '25');
    expect(texte(tester, 'valeur_3_a'), '220,00 €');
    expect(texte(tester, 'valeur_3_b'), '30,00 €');
    expect(texte(tester, 'vendus_0_a'), '60');
    expect(texte(tester, 'vendus_0_b'), '10');
    expect(texte(tester, 'conso_0_a'), '0,43');
    expect(texte(tester, 'conso_0_b'), '0,4');
    expect(texte(tester, 'ecart_0'), 'Écart : -0,03');
    expect(texte(tester, 'ecart_1'), 'Écart : -0,29');
    await photo('13_comparaison_deux_tournois');
  });
}
