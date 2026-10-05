// AUDIT VISUEL (temporaire) : crée des données de démonstration réalistes sur la copie locale
// de Firebase et photographie chaque écran et chaque état important.
// Lancement : voir audit_front/lancer.ps1
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/gymnase.dart';

import '../integration_test/outils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets('audit visuel', (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final depotAsso = DepotAssociations(db);
    await auth.signOut();
    await binding.convertFlutterSurfaceToImage();

    Future<void> photo(String nom) async {
      await tester.pump(const Duration(milliseconds: 600));
      await binding.takeScreenshot(nom);
      debugPrint('PHOTO $nom');
    }

    Future<void> attendreTexte(WidgetTester t, String cle, String attendu) async {
      for (var i = 0; i < 300; i++) {
        await t.pump(const Duration(milliseconds: 100));
        final f = find.byKey(Key(cle));
        if (f.evaluate().isNotEmpty && t.widget<Text>(f).data == attendu) return;
      }
      throw TestFailure('$cle != $attendu');
    }

    Future<void> fin() async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> toucher(Finder cible) async {
      await tester.ensureVisible(cible);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(cible);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> retour() async {
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await fin();
    }

    Future<void> haut() async {
      final defil = find.byType(Scrollable).first;
      for (var i = 0; i < 30; i++) {
        await tester.drag(defil, const Offset(0, 600));
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    /// Photographie la page puis la fait défiler (une photo par écran de téléphone).
    Future<void> defiler(String prefixe, {int max = 6}) async {
      await haut();
      await photo('${prefixe}_1');
      final defil = find.byType(Scrollable).first;
      var avant = tester.state<ScrollableState>(defil).position.pixels;
      for (var i = 2; i <= max; i++) {
        await tester.drag(defil, const Offset(0, -520));
        await tester.pump(const Duration(milliseconds: 500));
        final apres = tester.state<ScrollableState>(defil).position.pixels;
        if (apres == avant) break;
        avant = apres;
        await photo('${prefixe}_$i');
      }
      await haut();
    }

    Future<void> section(String nom, Future<void> Function() corps) async {
      debugPrint('SECTION $nom');
      try {
        await corps();
      } catch (e) {
        debugPrint('ECHEC $nom : $e');
        try {
          await photo('ECHEC_$nom');
        } catch (_) {}
      }
    }

    Future<void> changer(Future<void> Function() connexion) async {
      await tester.pumpWidget(const SizedBox());
      await auth.signOut();
      await connexion();
    }

    Future<void> vendre(List<String> articles, String mode) async {
      for (final a in articles) {
        final cible = find.text(a);
        if (cible.evaluate().isEmpty) {
          await tester.scrollUntilVisible(cible, 150,
              scrollable: find
                  .descendant(of: find.byType(GridView), matching: find.byType(Scrollable))
                  .first);
        }
        await toucher(cible);
      }
      await toucher(find.byKey(Key('encaisser_$mode')));
      await tester.pump(const Duration(seconds: 2));
    }

    // ============ 0. Téléphone neuf : accueil ============
    await section('accueil', () async {
      await ouvrir(tester, 'p0', googleAnnule);
      await tester.pump(const Duration(milliseconds: 50));
      await photo('00_chargement_demarrage');
      await attendre(tester, find.byKey(const Key('creer')));
      await fin();
      await defiler('01_accueil');
      await tester.enterText(find.byKey(const Key('code_saisi')), 'ZZZZZZ');
      await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Test');
      await toucher(find.byKey(const Key('rejoindre')));
      await tester.pump(const Duration(seconds: 3));
      await photo('02_accueil_erreur_code');
      await toucher(find.byKey(const Key('creer')));
      await tester.pump(const Duration(seconds: 2));
      await photo('03_accueil_creer_champs_vides');
    });

    // ============ 1. Le responsable ============
    late String code, assoId, chefUid;
    await ouvrir(tester, 'chef1', fauxGoogle('chef_audit'));
    await creerAssociationParLInterface(tester, nom: 'Club des Aigles', prenom: 'Chef');
    code = texte(tester, 'code');
    chefUid = auth.currentUser!.uid;
    assoId = (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotEv = depotAsso.evenements(assoId);
    final menus = depotAsso.menus(assoId);
    await fin();

    await section('association_vide', () async {
      await defiler('10_association_vide');
    });

    await section('menus', () async {
      await toucher(find.byKey(const Key('menus')));
      await attendre(tester, find.byKey(const Key('nouveau_menu')));
      await fin();
      await photo('11_menus_vide');
      await toucher(find.byKey(const Key('nouveau_menu')));
      await tester.pump(const Duration(seconds: 1));
      await photo('12_menu_nouveau_dialogue');
      await tester.enterText(find.byKey(const Key('nom_menu')), 'Menu Tournoi');
      await toucher(find.byKey(const Key('menu_type')));
      await toucher(find.byKey(const Key('valider_nom')));
      await attendre(tester, find.text('Menu Tournoi'));
      final menu = (await menus.suivreMenus().first).single;
      for (var i = 0;
          i < 100 && (await menus.suivreProduits(menu.id).first).length < 10;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await fin();
      await photo('13_menus_liste');
      await toucher(find.byKey(Key('menu_${menu.id}')));
      await attendre(tester, find.byKey(const Key('nouveau_produit')));
      await fin();
      await defiler('14_menu_produits', max: 4);
      await toucher(find.byKey(const Key('nouveau_produit')));
      await tester.pump(const Duration(seconds: 1));
      await photo('15_produit_nouveau');
      await retour();
      await retour();
      await retour();
    });

    final menu = (await menus.suivreMenus().first).single;

    Future<void> creerEvenement(String nom, List<String> gym, {bool photos = false}) async {
      await toucher(find.byKey(const Key('nouvel_evenement')));
      await attendre(tester, find.byKey(Key('choix_menu_${menu.id}')));
      await fin();
      if (photos) await photo('20_evenement_formulaire_1');
      await tester.enterText(find.byKey(const Key('nom_evenement')), nom);
      await toucher(find.byKey(Key('choix_menu_${menu.id}')));
      Future<void> vers(Finder f) async {
        final defil = find.byType(Scrollable).first;
        for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
          await tester.drag(defil, const Offset(0, -300));
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await vers(find.byKey(const Key('nom_gymnase_0')));
      await tester.enterText(find.byKey(const Key('nom_gymnase_0')), gym.first);
      for (var i = 1; i < gym.length; i++) {
        await vers(find.byKey(const Key('ajouter_gymnase_formulaire')));
        await toucher(find.byKey(const Key('ajouter_gymnase_formulaire')));
        await vers(find.byKey(Key('nom_gymnase_$i')));
        await tester.enterText(find.byKey(Key('nom_gymnase_$i')), gym[i]);
      }
      await vers(find.byKey(const Key('mode_carte')));
      await toucher(find.byKey(const Key('mode_carte')));
      await toucher(find.byKey(const Key('mode_cheque')));
      if (photos) {
        await photo('21_evenement_formulaire_bas');
      }
      await vers(find.byKey(const Key('valider_evenement')));
      await toucher(find.byKey(const Key('valider_evenement')));
      await fin();
      await attendre(tester, find.text(nom));
    }

    await section('evenements', () async {
      await creerEvenement('Tournoi du week-end', ['Gymnase A', 'Gymnase B'], photos: true);
      await creerEvenement('Loto du vendredi', ['Salle des fêtes']);
      await photo('22_association_evenements');
    });

    final evts = await depotEv.suivreEvenements(enCoursSeulement: false).first;
    final evt = evts.firstWhere((e) => e.nom == 'Tournoi du week-end');
    final gymnases = await depotEv.suivreGymnases(evt.id).first;
    final gA = gymnases[0].id, gB = gymnases[1].id;
    final base = 'associations/$assoId/evenements/${evt.id}';
    final produits = await depotEv.suivreProduits(evt.id).first;
    String idp(String nom) => produits.firstWhere((p) => p.nom == nom).id;

    await section('evenement_vide', () async {
      await toucher(find.text('Tournoi du week-end'));
      await attendre(tester, find.byKey(const Key('titre_evenement')));
      await fin();
      await defiler('23_evenement_chef_avant_ventes', max: 8);
      await toucher(find.byKey(const Key('voir_gymnases')));
      await tester.pump(const Duration(seconds: 2));
      await defiler('24_gymnases_stocks', max: 4);
      await toucher(find.byKey(Key('partager_gymnase_$gA')));
      await tester.pump(const Duration(seconds: 2));
      await photo('25_qr_gymnase');
      await retour();
      await retour();
      await retour();
    });

    // ============ 2. Gestionnaires et bénévole ============
    await changer(() async {
      await auth.createUserWithEmailAndPassword(email: 'gus.audit@test.fr', password: 'secret12');
    });
    final gusUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: gusUid, codeSaisi: code, prenom: 'Gus');
    await changer(() async {
      await auth.createUserWithEmailAndPassword(email: 'zed.audit@test.fr', password: 'secret12');
    });
    final zedUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: zedUid, codeSaisi: code, prenom: 'Zed');
    await changer(() async {
      await auth.signInWithCredential((await fauxGoogle('chef_audit')())!);
    });
    await depotAsso.nommerGestionnaire(assoId, gusUid);
    await depotAsso.nommerGestionnaire(assoId, zedUid);
    await depotEv.definirRattachement(evt.id, gusUid, {gA});
    await depotEv.definirRattachement(evt.id, zedUid, {gA, gB});
    await changer(() async {
      await auth.signInWithEmailAndPassword(email: 'gus.audit@test.fr', password: 'secret12');
      await auth.currentUser!.linkWithCredential((await fauxGoogle('gus_audit')())!);
      await auth.currentUser!.getIdToken(true);
    });
    await depotAsso.activerGestionnaire(assoId, gusUid);

    // ============ 3. Léa (bénévole) : caisse du gymnase A ============
    await changer(() async {
      await auth.createUserWithEmailAndPassword(email: 'lea.audit@test.fr', password: 'secret12');
    });
    final leaUid = auth.currentUser!.uid;
    await section('lea', () async {
      await ouvrir(tester, 'lea1', googleAnnule);
      await attendre(tester, find.byKey(const Key('rejoindre')));
      await tester.enterText(find.byKey(const Key('code_saisi')), code);
      await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Léa');
      await photo('30_accueil_rejoindre_rempli');
      await toucher(find.byKey(const Key('rejoindre')));
      await attendre(tester, find.text('Tournoi du week-end'));
      await fin();
      await defiler('31_benevole_liste_evenements', max: 2);
      await toucher(find.text('Tournoi du week-end'));
      await attendre(tester, find.byKey(Key('ouvrir_caisse_$gA')));
      await fin();
      await defiler('32_benevole_evenement', max: 3);
      await toucher(find.byKey(Key('ouvrir_caisse_$gA')));
      await attendre(tester, find.byKey(const Key('recap_caisse')));
      await fin();
      await photo('33_caisse_vide');
      await toucher(find.text('Croque-monsieur'));
      await toucher(find.text('Croque-monsieur'));
      await toucher(find.text('Café'));
      await photo('34_caisse_ticket');
      await toucher(find.byKey(const Key('monnaie')));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byKey(const Key('somme_recue')), '20');
      await tester.pump(const Duration(milliseconds: 500));
      await photo('35_caisse_monnaie_a_rendre');
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await fin();
      await toucher(find.byKey(const Key('encaisser_especes')));
      await tester.pump(const Duration(seconds: 2));
      await photo('36_caisse_apres_vente');
      await vendre(['Crêpe', 'Crêpe'], 'carte');
      await vendre(['Soda'], 'especes');
      await vendre(['Thé', 'Barre chocolatée'], 'especes');
      await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
      await photo('37_caisse_apres_4_ventes');
      await toucher(find.byKey(const Key('voir_ventes')));
      await tester.pump(const Duration(seconds: 2));
      await photo('38_caisse_mes_ventes');
      final ventes = await depotEv.caisses(evt.id).suivreVentes(idCaisse(leaUid, gA)).first;
      final v = ventes.firstWhere((x) => x.totalCentimes == 150);
      await toucher(find.byKey(Key('annuler_${v.id}')));
      await tester.pump(const Duration(seconds: 1));
      await photo('39_caisse_annulation_dialogue');
      await toucher(find.byKey(const Key('confirmer_annulation')));
      await tester.pump(const Duration(seconds: 2));
      await photo('40_caisse_vente_annulee');
      await retour();
      await toucher(find.byKey(const Key('ouvrir_cloture')));
      await attendre(tester, find.byKey(const Key('cloturer_caisse')));
      await fin();
      await defiler('41_cloture_recapitulatif', max: 3);
      await toucher(find.byKey(const Key('cloturer_caisse')));
      await attendre(tester, find.byKey(const Key('cloture_ok')));
      await fin();
      await defiler('42_cloture_ok', max: 3);
      await toucher(find.byKey(const Key('fermer_cloture')));
      await fin();
      await photo('43_caisse_cloturee');
      await retour();
      await photo('44_benevole_evenement_caisse_cloturee');
    });

    // ============ 4. Zoé (gymnase B), ventes envoyées « depuis son téléphone » ============
    await changer(() async {
      await auth.createUserWithEmailAndPassword(email: 'zoe.audit@test.fr', password: 'secret12');
    });
    final zoeUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: zoeUid, codeSaisi: code, prenom: 'Zoé');
    final jeton = (await auth.currentUser!.getIdToken())!;
    final maintenant = DateTime.now();
    await restOuvrirCaisse(base, zoeUid, gB, jeton, 'Zoé', maintenant);
    final caisseZoe = idCaisse(zoeUid, gB);
    final demain = maintenant.add(const Duration(days: 1));
    final heures = [10, 11, 12, 12, 13, 14, 14, 15];
    final modes = ['especes', 'carte', 'especes', 'cheque', 'especes', 'carte', 'especes', 'especes'];
    for (var i = 0; i < heures.length; i++) {
      final jour = i < 5 ? maintenant : demain;
      final d = DateTime(jour.year, jour.month, jour.day, heures[i], 5 + i * 3);
      final art = [
        ['Croque-monsieur', 300, 1],
        ['Café', 100, 2],
        ['Crêpe', 250, 2],
        ['Soda', 150, 1],
        ['Salade', 400, 1],
      ][i % 5];
      final q = art[2] as int, p = art[1] as int;
      await restEcrire(
          'POST',
          '$base/caisses/$caisseZoe/ventes',
          jeton,
          restVente([restLigne(idp(art[0] as String), art[0] as String, p, q)], p * q,
              modes[i], d, gB));
    }

    // ============ 5. Le responsable : événement vivant, bilan, clôture ============
    await changer(() async {
      await auth.signInWithCredential((await fauxGoogle('chef_audit')())!);
    });
    await ouvrir(tester, 'chef3', googleAnnule);
    await attendre(tester, find.text('Tournoi du week-end'));
    await fin();
    await section('association_riche', () async {
      await defiler('50_association_riche', max: 6);
    });
    await section('evenement_vivant', () async {
      await toucher(find.text('Tournoi du week-end'));
      await attendre(tester, find.byKey(const Key('vue_commune')));
      await tester.pump(const Duration(seconds: 3));
      await defiler('51_evenement_chef_en_cours', max: 10);
      await toucher(find.byKey(Key('vue_$gB')));
      await tester.pump(const Duration(seconds: 2));
      await defiler('52_evenement_vue_gymnase_b', max: 3);
      await toucher(find.byKey(const Key('vue_commune')));
      await tester.pump(const Duration(seconds: 2));
    });
    await section('bilan_en_cours', () async {
      final defil = find.byType(Scrollable).first;
      final cible = find.byKey(const Key('voir_bilan'));
      for (var i = 0; i < 60 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await toucher(cible);
      await attendre(tester, find.byKey(const Key('bilan_total')));
      await tester.pump(const Duration(seconds: 2));
      await defiler('53_bilan_provisoire', max: 10);
      await retour();
    });
    await section('cloture_evenement', () async {
      final defil = find.byType(Scrollable).first;
      final cible = find.byKey(const Key('cloturer_evenement'));
      for (var i = 0; i < 60 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await toucher(cible);
      await tester.pump(const Duration(seconds: 1));
      await photo('54_cloture_evenement_dialogue');
      await toucher(find.byKey(const Key('confirmer_cloture_evenement')));
      await tester.pump(const Duration(seconds: 3));
      await defiler('55_evenement_cloture', max: 10);
      final c2 = find.byKey(const Key('voir_bilan'));
      for (var i = 0; i < 60 && c2.evaluate().isEmpty; i++) {
        await tester.drag(defil, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await toucher(c2);
      await attendre(tester, find.byKey(const Key('bilan_total')));
      await tester.pump(const Duration(seconds: 2));
      await defiler('56_bilan_definitif', max: 10);
      await retour();
      await retour();
    });
    await section('parametres', () async {
      await toucher(find.byKey(const Key('parametres')));
      await tester.pump(const Duration(seconds: 2));
      await defiler('57_parametres', max: 6);
      await retour();
    });

    // ============ 6. Un gestionnaire rattaché à un seul gymnase ============
    await changer(() async {
      await auth.signInWithEmailAndPassword(email: 'gus.audit@test.fr', password: 'secret12');
    });
    await section('gestionnaire_limite', () async {
      await ouvrir(tester, 'gus3', googleAnnule);
      await attendre(tester, find.text('Loto du vendredi'));
      await fin();
      await photo('60_gestionnaire_association');
      await toucher(find.text('Loto du vendredi'));
      await attendre(tester, find.byKey(const Key('titre_evenement')));
      await tester.pump(const Duration(seconds: 3));
      await defiler('61_gestionnaire_evenement', max: 6);
      await retour();
    });

    // ============ 7. Zed en attente d'activation : Paramètres ============
    await changer(() async {
      await auth.signInWithEmailAndPassword(email: 'zed.audit@test.fr', password: 'secret12');
    });
    await section('zed_attente', () async {
      await ouvrir(tester, 'zed1', fauxGoogle('zed_audit'));
      await attendre(tester, find.byKey(const Key('parametres')));
      await fin();
      await photo('62_gestionnaire_en_attente_accueil');
      await toucher(find.byKey(const Key('parametres')));
      await tester.pump(const Duration(seconds: 2));
      await defiler('63_parametres_membre', max: 3);
    });

    // ============ 8. Scan de QR code (vraie caméra de l'émulateur) ============
    await changer(() async {
      await auth.createUserWithEmailAndPassword(email: 'max.audit@test.fr', password: 'secret12');
    });
    final maxUid = auth.currentUser!.uid;
    await section('scan', () async {
      await ouvrir(tester, 'max0', googleAnnule);
      await attendre(tester, find.byKey(const Key('scanner_qr')));
      await fin();
      await toucher(find.byKey(const Key('scanner_qr')));
      await tester.pump(const Duration(seconds: 4));
      await photo('70_scan_qr');
    });

    // ============ 9. Hors réseau (événement en cours : le loto) ============
    await section('hors_reseau', () async {
      await depotAsso.rejoindre(uid: maxUid, codeSaisi: code, prenom: 'Max');
      await ouvrir(tester, 'max1', googleAnnule);
      await attendre(tester, find.text('Loto du vendredi'));
      await fin();
      await toucher(find.text('Loto du vendredi'));
      await attendre(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
      await fin();
      await toucher(find.byKey(const Key('ouvrir_caisse_evenement')));
      await attendre(tester, find.byKey(const Key('recap_caisse')));
      await fin();
      await db.waitForPendingWrites();
      await db.disableNetwork();
      await vendre(['Crêpe', 'Soda'], 'especes');
      await vendre(['Café'], 'carte');
      await tester.pump(const Duration(seconds: 2));
      await photo('71_caisse_hors_reseau');
      await db.enableNetwork();
    });
    debugPrint('AUDIT TERMINE');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
