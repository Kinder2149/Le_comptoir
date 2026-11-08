import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/depot_caisses.dart';

import 'outils.dart';

// Mission « Préparer l'événement », étape P4 : la prévision à sources.
//
// Événement passé « Tournoi 2025 » (menu Croque + Soda) : 40 personnes, 2 jours, clôturé.
//   Ventes : 100 + 60 croques, 20 croques ANNULÉS, 80 sodas.
//   Croque : 160 ÷ 40 ÷ 2 = 2,0 ; Soda : 80 ÷ 40 ÷ 2 = 1,0.
// Autre événement passé « Tournoi sans personnes » : clôturé, aucune personne réglée.
// Nouvel événement « Tournoi 2026 » (menu Croque 1,5 + Soda 0,5 + Salade 0,5) : 80 personnes,
// 2 jours, 20 croques en stock au départ.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
    }
    final f = find.byKey(Key(cle));
    throw TestFailure('« $cle » : attendu « $attendu », obtenu '
        '« ${f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f)} »');
  }

  testWidgets(
      'prévision : menu par défaut, événement passé (annulées exclues), produit absent, '
      'correction à la main, courses', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // ---------- Préparation : deux menus, deux événements passés clôturés.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_previsions'));
    await creerAssociationParLInterface(tester);
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuPasse = await menus.creerMenu('Menu 2025');
    await menus.ajouterProduit(menuPasse,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 1));
    await menus.ajouterProduit(menuPasse,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 1));
    final menuNouveau = await menus.creerMenu('Menu 2026');
    await menus.ajouterProduit(menuNouveau,
        nom: 'Croque', prixCentimes: 300, fiche: const FicheProduit(conso: 1.5));
    await menus.ajouterProduit(menuNouveau,
        nom: 'Soda', prixCentimes: 100, fiche: const FicheProduit(conso: 0.5));
    await menus.ajouterProduit(menuNouveau,
        nom: 'Salade', prixCentimes: 400, fiche: const FicheProduit(conso: 0.5));

    final depotEv = depotAsso.evenements(assoId);
    final evt0 = await creerOuvert(depotEv,
        nom: 'Tournoi 2025',
        date: '2025-10-03',
        menuId: menuPasse,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    final gym0 = await gymnaseUnique(depotEv, evt0);
    await depotEv.definirPersonnes(evt0, gym0, 40);
    await depotEv.definirJours(evt0, 2);
    final produits0 = await depotEv.suivreProduits(evt0).first;
    final croque0 = produits0.firstWhere((p) => p.nom == 'Croque').id;
    final soda0 = produits0.firstWhere((p) => p.nom == 'Soda').id;
    final caisses0 = depotEv.caisses(evt0);
    final caisseId = idCaisse(chefUid, gym0);
    await caisses0.ouvrirCaisse(caisseId, 'Chef');
    await db.waitForPendingWrites();
    caisses0.enregistrerVente(
        caisseId, [LigneVente(croque0, 'Croque', 300, 100)], 'especes',
        stocks: const {});
    caisses0.enregistrerVente(
        caisseId, [LigneVente(croque0, 'Croque', 300, 20)], 'especes',
        stocks: const {});
    caisses0.enregistrerVente(
        caisseId, [LigneVente(croque0, 'Croque', 300, 60)], 'especes',
        stocks: const {});
    caisses0.enregistrerVente(
        caisseId, [LigneVente(soda0, 'Soda', 100, 80)], 'especes',
        stocks: const {});
    await db.waitForPendingWrites();
    final ventes0 = await caisses0.suivreVentes(caisseId).first;
    // Les 20 croques sont annulés : ils ne comptent pas.
    caisses0.annulerVente(
        caisseId, ventes0.firstWhere((v) => v.lignes.single.quantite == 20),
        parUid: chefUid, parPrenom: 'Chef', stocks: const {});
    await db.waitForPendingWrites();
    await caisses0.cloturerCaisse(caisseId);
    await depotEv.cloturerEvenement(evt0,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    final evtVide = await creerOuvert(depotEv,
        nom: 'Tournoi sans personnes',
        date: '2025-09-01',
        menuId: menuPasse,
        modes: ['especes']);
    await depotEv.cloturerEvenement(evtVide,
        parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 0);

    // ---------- Le nouvel événement : 80 personnes, 2 jours, 20 croques au départ.
    final evt = await depotEv.creerEvenement(
        nom: 'Tournoi 2026',
        date: dateIso(DateTime.now()),
        menuId: menuNouveau,
        modes: ['especes'],
        gymnases: ['Gymnase A']);
    await db.waitForPendingWrites();
    final gA = await gymnaseUnique(depotEv, evt);
    final produits = await depotEv.suivreProduits(evt).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final soda = produits.firstWhere((p) => p.nom == 'Soda').id;
    final salade = produits.firstWhere((p) => p.nom == 'Salade').id;
    await depotEv.definirPersonnes(evt, gA, 80);
    await depotEv.definirJours(evt, 2);
    await depotEv.definirStock(evt, gA, croque, 20);
    await db.waitForPendingWrites();

    Future<Map<String, dynamic>?> previsionDoc(String p) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('previsions')
            .doc(p)
            .get(serveur))
        .data();
    String champ(String cle) =>
        tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;
    String champQte(String cle) => tester
        .widget<TextField>(find.descendant(
            of: find.byKey(Key(cle)), matching: find.byType(TextField)))
        .controller!
        .text;
    Future<void> saisirChamp(String cle, String valeur) async {
      await tester.tap(find.byKey(Key(cle)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byKey(Key(cle)), valeur);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> ouvrirPreparation() async {
      await attendre(tester, find.byKey(const Key('onglet_avant')));
      await toucher(tester, find.byKey(const Key('onglet_avant')));
      await attendre(tester, find.byKey(const Key('tache_prevision')));
      await finTransition(tester);
      await toucher(tester, find.byKey(const Key('tache_prevision')));
      await attendre(tester, find.byKey(const Key('bandeau_prevision')));
      await finTransition(tester);
    }

    Future<void> verifierCourses(String attendu, {required String quand}) async {
      await retour(tester);
      await attendre(tester, find.byKey(const Key('voir_courses')));
      await toucher(tester, find.byKey(const Key('voir_courses')));
      await attendre(tester, find.byKey(const Key('etat_courses')));
      await finTransition(tester);
      await toucher(tester, find.byKey(const Key('recalculer')));
      await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
      for (var i = 0; i < 100 && champQte('qte_${gA}_$croque') != attendu; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(champQte('qte_${gA}_$croque'), attendu, reason: quand);
      await retour(tester);
    }

    // ---------- 1. Par défaut : les chiffres du menu, source « Menu ».
    await attendre(tester, find.text('Tournoi 2026'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi 2026'));
    await ouvrirPreparation();
    for (final p in [croque, soda, salade]) {
      expect(texte(tester, 'source_$p'), 'Source : Menu');
    }
    expect(champ('champ_conso_$croque'), '1,5');
    expect(champ('champ_conso_$soda'), '0,5');
    expect(champ('champ_conso_$salade'), '0,5');

    // ---------- 5. Les événements passés : celui sans personnes n'est pas proposé.
    await toucher(tester, find.byKey(const Key('prevision_evenement_passe')));
    await attendre(tester, find.byKey(Key('choix_passe_$evt0')));
    expect(find.byKey(Key('choix_passe_$evtVide')), findsNothing);
    expect(texte(tester, 'message_sans_personnes'), messageSansPersonnes);
    expect(find.text('03/10/2025 · 40 personnes · 2 jours'), findsOneWidget);

    // ---------- 2, 3, 6. Choisir « Tournoi 2025 » : 160 ÷ 40 ÷ 2 = 2,0 (annulées exclues).
    await toucher(tester, find.byKey(Key('choix_passe_$evt0')));
    await attendreTexte(tester, 'source_$croque', 'Source : Événement : Tournoi 2025');
    await attendreTexte(tester, 'source_$soda', 'Source : Événement : Tournoi 2025');
    expect(champ('champ_conso_$croque'), '2');
    expect(champ('champ_conso_$soda'), '1');
    // Salade n'existait pas en 2025 : elle garde le menu.
    expect(texte(tester, 'source_$salade'), 'Source : Menu');
    expect(champ('champ_conso_$salade'), '0,5');
    expect((await previsionDoc(croque))!['conso'], 2);
    expect((await previsionDoc(salade)), isNull);

    // ---------- 7. Les courses calculent avec ces chiffres : 80 × 2 × 2,0 = 320 - 20 = 300.
    await verifierCourses('300', quand: 'source événement passé');

    // ---------- 4. Un chiffre corrigé reste, le menu ne change pas.
    await ouvrirPreparation();
    await saisirChamp('champ_conso_$croque', '2,5');
    await attendre(tester, find.byKey(Key('enregistre_conso_$croque')));
    await attendreTexte(tester, 'source_$croque', 'Source : Modifié à la main');
    expect((await previsionDoc(croque))!['conso'], 2.5);
    expect((await previsionDoc(croque))!['source'], 'Modifié à la main');
    expect(texte(tester, 'source_$soda'), 'Source : Événement : Tournoi 2025');
    final produitMenu = (await menus.suivreProduits(menuNouveau).first)
        .firstWhere((p) => p.nom == 'Croque');
    expect(produitMenu.fiche.conso, 1.5);
    final produitEvt = (await depotEv.suivreProduits(evt).first)
        .firstWhere((p) => p.nom == 'Croque');
    expect(produitEvt.fiche.conso, 1.5);
    // Une valeur invalide n'écrit rien.
    await saisirChamp('champ_conso_$soda', '1001');
    expect(find.text('Entrez une consommation de 0 à 1000.'), findsOneWidget);
    expect((await previsionDoc(soda))!['conso'], 1);
    await db.waitForPendingWrites();
    // 80 × 2 × 2,5 = 400 - 20 = 380.
    await verifierCourses('380', quand: 'chiffre corrigé à la main');

    // ---------- « Revenir au menu » (avec confirmation : un chiffre est corrigé à la main).
    await ouvrirPreparation();
    await toucher(tester, find.byKey(const Key('prevision_revenir_menu')));
    await attendre(tester, find.byKey(const Key('confirmer_prevision')));
    await toucher(tester, find.byKey(const Key('confirmer_prevision')));
    await attendreTexte(tester, 'source_$croque', 'Source : Menu');
    expect(champ('champ_conso_$croque'), '1,5');
    expect(await previsionDoc(croque), isNull);
    expect(await previsionDoc(soda), isNull);
    // 80 × 2 × 1,5 = 240 - 20 = 220.
    await verifierCourses('220', quand: 'retour au menu');
  });
}
