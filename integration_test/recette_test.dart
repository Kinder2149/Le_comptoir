// RECETTE FINALE — un week-end de buvette sur DEUX gymnases, de bout en bout, avec tous
// les rôles.
//
// Scénario (menu type, prix génériques : croque-monsieur 3,00 · salade 4,00 ·
// fruit 1,00 · thé 1,00 · café 1,00 · barre 1,00 · soda 1,50 · gâteau sucré 2,00 ·
// gâteau salé 2,50 · crêpe 2,50), modes : espèces, carte, chèque.
//
//   Chef (responsable) crée l'association, le menu type et l'événement à deux gymnases
//   (Gymnase A, Gymnase B) ; nomme Gus (gymnase A, activé avec Google) et Zed (gymnase B).
//   Léa (bénévole, gymnase A) : L1 2 croque + 1 café = 7,00 espèces · L2 2 crêpes = 5,00
//     carte · L3 1 soda = 1,50 espèces, ANNULÉE · L4 thé + barre = 2,00 espèces, CORRIGÉE en
//     L4b thé + gâteau sucré = 3,00 espèces · clôture (3 ventes 15,00) · RÉOUVERTURE ·
//     L5 1 café = 1,00 carte · nouvelle clôture (4 ventes 16,00).
//   Zoé (bénévole, arrive par le QR code du gymnase B) ouvre PAR ERREUR une caisse dans le
//     gymnase A, la clôture sans vente, puis ouvre dans le gymnase B (changement de gymnase) :
//     Z1 salade + fruit = 5,00 carte (ANNULÉE par Zed) · Z2 gâteau salé = 2,50 espèces ·
//     jour 2 : ZD1 1 croque = 3,00 espèces · ZD2 2 cafés = 2,00 chèque · sa caisse du
//     gymnase B reste OUVERTE.
//   Chef force la clôture et ouvre le bilan.
//
//   Bilan COMMUN attendu (calculé à la main) : 23,50 € en 7 ventes, 3 annulées · espèces
//   15,50 · carte 6,00 · chèque 2,00 · café 4 · croque 3 · crêpe 2 · thé 1 · gâteau
//   sucré 1 · gâteau salé 1 · soda/barre/salade/fruit 0 · jour 1 : 5 ventes 18,50 ·
//   jour 2 : 2 ventes 5,00.
//   Bilan GYMNASE A (Léa) : 16,00 € en 4 ventes, 2 annulées · espèces 10,00 · carte 6,00 ·
//     chèque 0 · café 2 · croque 2 · crêpe 2 · thé 1 · gâteau sucré 1 · le reste 0 ·
//     jour 1 : 4 ventes 16,00 · caisses : Léa 4 ventes clôturée, Zoé 0 vente clôturée.
//   Bilan GYMNASE B (Zoé) : 7,50 € en 3 ventes, 1 annulée · espèces 5,50 · carte 0 ·
//     chèque 2,00 · café 2 · croque 1 · gâteau salé 1 · le reste 0 · jour 1 : 1 vente 2,50 ·
//     jour 2 : 2 ventes 5,00 · caisse : Zoé 3 ventes ouverte.
//   A + B = commun : 16,00 + 7,50 = 23,50 · espèces 10,00 + 5,50 = 15,50 · carte 6,00 + 0 ·
//   chèque 0 + 2,00 · café 2 + 2 = 4 · croque 2 + 1 = 3.
//
// Pour finir, une coupure de réseau simulée sur un second événement.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    // L'écran peut encore se mettre en page (listes qui se chargent) : on laisse faire.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> attendreTexte(WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && tester.widget<Text>(f).data == attendu) return;
    }
    final f = find.byKey(Key(cle));
    final actuel = f.evaluate().isEmpty ? '(absent)' : tester.widget<Text>(f).data;
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
  }

  /// Les listes ne construisent que ce qui est visible : on défile jusqu'à l'élément.
  Future<void> defilerJusqua(WidgetTester tester, Finder cible) async {
    final defil = find.byType(Scrollable).first;
    for (final sens in [300.0, -300.0]) {
      for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, Offset(0, sens));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  /// Touche un produit de la grille (elle défile : les tuiles sont construites à la demande).
  Future<void> toucherProduit(WidgetTester tester, String nom) async {
    final cible = find.text(nom);
    if (cible.evaluate().isEmpty) {
      await tester.scrollUntilVisible(cible, 150,
          scrollable: find
              .descendant(of: find.byType(GridView), matching: find.byType(Scrollable))
              .first);
    }
    await toucher(tester, cible);
  }

  Future<void> vendre(WidgetTester tester, List<String> articles, String mode) async {
    for (final a in articles) {
      await toucherProduit(tester, a);
    }
    await toucher(tester, find.byKey(Key('encaisser_$mode')));
  }

  /// Change d'utilisateur : l'écran du précédent est retiré, puis on se connecte.
  Future<void> changerDeSession(
      WidgetTester tester, Future<void> Function() connexion) async {
    await tester.pumpWidget(const SizedBox());
    await FirebaseAuth.instance.signOut();
    await connexion();
  }

  void etape(String t) => debugPrint('ETAPE $t');

  testWidgets('recette : un week-end de buvette, tous les rôles, du début au bilan',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    const serveur = GetOptions(source: Source.server);
    final depotAsso = DepotAssociations(db);
    await auth.signOut();

    etape('1 chef');
    // ============ 1. Le responsable : association, menu type, événement ============
    await ouvrir(tester, 'chef1', fauxGoogle('chef_recette'));
    await creerAssociationParLInterface(tester, nom: 'Club de la Recette', prenom: 'Chef');
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final menus = depotAsso.menus(assoId);
    final depotEv = depotAsso.evenements(assoId);

    await attendre(tester, find.byKey(const Key('menus')));
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.byKey(const Key('nouveau_menu')));
    await toucher(tester, find.byKey(const Key('nouveau_menu')));
    await tester.enterText(find.byKey(const Key('nom_menu')), 'Menu Tournoi');
    await toucher(tester, find.byKey(const Key('menu_type')));
    await toucher(tester, find.byKey(const Key('valider_nom')));
    await attendre(tester, find.text('Menu Tournoi'));
    final menu = (await menus.suivreMenus().first).single;
    for (var i = 0; i < 100 && (await menus.suivreProduits(menu.id).first).length < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await menus.suivreProduits(menu.id).first).length, 10);
    await retour(tester); // retour à l'association

    await toucher(tester, find.byKey(const Key('nouvel_evenement')));
    await attendre(tester, find.byKey(Key('choix_menu_${menu.id}')));
    await tester.enterText(
        find.byKey(const Key('nom_evenement')), 'Tournoi du week-end');
    await toucher(tester, find.byKey(Key('choix_menu_${menu.id}')));
    // Deux gymnases (le formulaire est long : on défile jusqu'à chaque champ).
    await defilerJusqua(tester, find.byKey(const Key('nom_gymnase_0')));
    await tester.enterText(find.byKey(const Key('nom_gymnase_0')), 'Gymnase A');
    await defilerJusqua(tester, find.byKey(const Key('ajouter_gymnase_formulaire')));
    await toucher(tester, find.byKey(const Key('ajouter_gymnase_formulaire')));
    await defilerJusqua(tester, find.byKey(const Key('nom_gymnase_1')));
    await tester.enterText(find.byKey(const Key('nom_gymnase_1')), 'Gymnase B');
    await defilerJusqua(tester, find.byKey(const Key('mode_carte')));
    await toucher(tester, find.byKey(const Key('mode_carte')));
    await defilerJusqua(tester, find.byKey(const Key('mode_cheque')));
    await toucher(tester, find.byKey(const Key('mode_cheque')));
    await defilerJusqua(tester, find.byKey(const Key('valider_evenement')));
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await finTransition(tester);
    await attendre(tester, find.text('Tournoi du week-end'));
    final evt = (await depotEv.suivreEvenements(enCoursSeulement: false).first).single;
    // L'état de l'événement est visible dans la liste, et il n'y a plus de bouton
    // « Ouvrir la caisse » sur l'écran de l'association (seulement depuis un événement).
    expect(
        find.descendant(
            of: find.byKey(Key('etat_${evt.id}')), matching: find.text('En cours')),
        findsOneWidget);
    expect(find.byKey(const Key('ouvrir_caisse')), findsNothing);
    expect(find.text('Ouvrir la caisse'), findsNothing);
    expect(evt.modes, ['especes', 'carte', 'cheque']);
    final produits = await depotEv.suivreProduits(evt.id).first;
    expect(produits.length, 10);
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    final croque = id('Croque-monsieur'), cafe = id('Café'), crepe = id('Crêpe');
    final the = id('Thé'), barre = id('Barre chocolatée'), soda = id('Soda');
    final sucre = id('Part de gâteau sucrée'), sale = id('Part de gâteau salée');
    final caisses = depotEv.caisses(evt.id);
    final gymnases = await depotEv.suivreGymnases(evt.id).first;
    expect([for (final g in gymnases) g.nom], ['Gymnase A', 'Gymnase B']);
    expect(evt.nbGymnases, 2);
    final gA = gymnases[0].id, gB = gymnases[1].id;
    final base = 'associations/$assoId/evenements/${evt.id}';

    etape('2 gus');
    // ============ 2. Gus rejoint ; le responsable le nomme ; Gus active (Google) ============
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(
          email: 'gus.recette@test.fr', password: 'secret12');
    });
    final gusUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: gusUid, codeSaisi: code, prenom: 'Gus');

    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_recette')())!);
    });
    expect(auth.currentUser!.uid, chefUid);
    // Gus est rattaché au gymnase A : sans cela il ne verrait aucune vente.
    await depotEv.definirRattachement(evt.id, gusUid, {gA});
    await ouvrir(tester, 'chef2', googleAnnule);
    await attendre(tester, find.byKey(Key('nommer_$gusUid')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('nommer_$gusUid')));
    await attendreTexte(tester, 'statut_$gusUid', 'Gestionnaire en attente');

    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'gus.recette@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'gus1', fauxGoogle('gus_google'));
    await attendre(tester, find.text('+1'));
    await toucher(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('activer_gestionnaire')));
    await toucher(tester, find.byKey(const Key('activer_gestionnaire')));
    await attendreTexte(tester, 'mon_statut', 'Statut : Gestionnaire');

    // Zed : gestionnaire du gymnase B (nommé par le responsable, activé avec Google).
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(
          email: 'zed.recette@test.fr', password: 'secret12');
    });
    final zedUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: zedUid, codeSaisi: code, prenom: 'Zed');
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_recette')())!);
    });
    await depotAsso.nommerGestionnaire(assoId, zedUid);
    await depotEv.definirRattachement(evt.id, zedUid, {gB});
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'zed.recette@test.fr', password: 'secret12');
      await auth.currentUser!.linkWithCredential((await fauxGoogle('zed_google')())!);
      await auth.currentUser!.getIdToken(true);
    });
    await depotAsso.activerGestionnaire(assoId, zedUid);

    etape('3 lea');
    // ============ 3. Léa : ventes, annulation, correction, clôture, réouverture ============
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(
          email: 'lea.recette@test.fr', password: 'secret12');
    });
    final leaUid = auth.currentUser!.uid;
    final caisseLea = idCaisse(leaUid, gA);
    await ouvrir(tester, 'lea1', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi du week-end'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi du week-end'));
    await attendre(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_caisse'), 'Gymnase A');

    await vendre(tester, ['Croque-monsieur', 'Croque-monsieur', 'Café'], 'especes'); // L1
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 7,00 €');
    await vendre(tester, ['Crêpe', 'Crêpe'], 'carte'); // L2
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 12,00 €');
    await vendre(tester, ['Soda'], 'especes'); // L3
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 13,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');

    // L3 annulée par Léa.
    final l3 = (await caisses.suivreVentes(caisseLea).first)
        .firstWhere((v) => v.totalCentimes == 150);
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await attendre(tester, find.byKey(Key('annuler_${l3.id}')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('annuler_${l3.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(Key('trace_${l3.id}')));
    await retour(tester);
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 12,00 €');

    // L4 (thé + barre) puis correction en L4b (thé + gâteau sucré).
    await vendre(tester, ['Thé', 'Barre chocolatée'], 'especes'); // L4
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 14,00 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    final l4 = (await caisses.suivreVentes(caisseLea).first)
        .firstWhere((v) => v.totalCentimes == 200 && !v.annulee);
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await attendre(tester, find.byKey(Key('corriger_${l4.id}')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('corriger_${l4.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(const Key('correction_en_cours')));
    await finTransition(tester);
    expect(texte(tester, 'total'), 'Total : 2,00 €');
    await toucher(tester, find.byKey(Key('retirer_$barre')));
    await toucherProduit(tester, 'Part de gâteau sucrée');
    expect(texte(tester, 'total'), 'Total : 3,00 €');
    await toucher(tester, find.byKey(const Key('encaisser_especes'))); // L4b
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 15,00 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');

    // Première clôture : 3 ventes, 15,00 € (espèces 10,00 · carte 5,00), 2 annulées.
    await toucher(tester, find.byKey(const Key('ouvrir_cloture')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    expect(texte(tester, 'cloture_total'), 'Ventes : 3 · 15,00 €');
    expect(texte(tester, 'recap_mode_especes'), 'Espèces : 10,00 €');
    expect(texte(tester, 'recap_mode_carte'), 'Carte : 5,00 €');
    expect(texte(tester, 'recap_mode_cheque'), 'Chèque : 0,00 €');
    expect(texte(tester, 'cloture_annulees'), 'Ventes annulées : 2');
    expect(texte(tester, 'a_remettre'), 'Espèces à remettre : 10,00 €');
    await toucher(tester, find.byKey(const Key('fermer_cloture')));
    await finTransition(tester);
    expect(find.byKey(const Key('caisse_cloturee')), findsOneWidget);

    // Réouverture (vente oubliée), L5, nouvelle clôture : 4 ventes, 16,00 €.
    await toucher(tester, find.byKey(const Key('rouvrir_caisse')));
    await attendre(tester, find.byKey(const Key('ouvrir_cloture')));
    await vendre(tester, ['Café'], 'carte'); // L5
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 4 · 16,00 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await toucher(tester, find.byKey(const Key('ouvrir_cloture')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    expect(texte(tester, 'cloture_total'), 'Ventes : 4 · 16,00 €');
    expect(texte(tester, 'recap_mode_carte'), 'Carte : 6,00 €');
    expect(texte(tester, 'a_remettre'), 'Espèces à remettre : 10,00 €');

    etape('4 zoe');
    // ============ 4. Zoé : arrive par le QR code du gymnase B, se trompe de gymnase,
    // corrige, vend, jour 2, caisse laissée ouverte ============
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(
          email: 'zoe.recette@test.fr', password: 'secret12');
    });
    final zoeUid = auth.currentUser!.uid;
    final caisseZoeA = idCaisse(zoeUid, gA);
    final caisseZoe = idCaisse(zoeUid, gB);
    // Le QR code du gymnase B (faux lecteur : le vrai scan est à la recette de Kinder).
    final qrGymnaseB = ecrireLienGymnase(LienGymnase(code, evt.id, gB));
    await ouvrir(tester, 'zoe1', googleAnnule, lecteurQr: (_) async => qrGymnaseB);
    await attendre(tester, find.byKey(const Key('scanner_qr')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('scanner_qr')));
    await attendre(tester, find.byKey(const Key('prenom_qr')));
    await tester.enterText(find.byKey(const Key('prenom_qr')), 'Zoe');
    await tester.tap(find.byKey(const Key('valider_prenom_qr')));
    await attendre(tester, find.byKey(const Key('gymnase_scanne')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_scanne'), 'QR code lu : Gymnase B');
    // Elle ouvre PAR ERREUR dans le gymnase A, clôture sans vente, puis ouvre dans B.
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_caisse'), 'Gymnase A');
    await toucher(tester, find.byKey(const Key('ouvrir_cloture')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    expect(texte(tester, 'cloture_total'), 'Ventes : 0 · 0,00 €');
    await toucher(tester, find.byKey(const Key('fermer_cloture')));
    await finTransition(tester);
    await retour(tester); // l'écran de l'événement
    for (var i = 0; i < 100 && find.byKey(const Key('ma_caisse')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gB')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_caisse'), 'Gymnase B');
    await vendre(tester, ['Salade', 'Fruit'], 'carte'); // Z1
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 5,00 €');
    await vendre(tester, ['Part de gâteau salée'], 'especes'); // Z2
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 7,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    // Jour 2 : deux ventes datées de demain (envoyées comme le ferait son téléphone).
    final jetonZoe = (await auth.currentUser!.getIdToken())!;
    final demain = DateTime.now().add(const Duration(days: 1));
    DateTime demainA(int h, int m) => DateTime(demain.year, demain.month, demain.day, h, m);
    expect(
        await restEcrire('POST', '$base/caisses/$caisseZoe/ventes', jetonZoe,
            restVente([restLigne(croque, 'Croque-monsieur', 300, 1)], 300, 'especes', demainA(10, 20), gB)),
        200);
    expect(
        await restEcrire('POST', '$base/caisses/$caisseZoe/ventes', jetonZoe,
            restVente([restLigne(cafe, 'Café', 100, 2)], 200, 'cheque', demainA(10, 50), gB)),
        200);

    etape('5 gus-suivi');
    // ============ 5. Gus ne voit que le gymnase A ; Zed, que le B, annule la vente Z1 de Zoé ====
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'gus.recette@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'gus2', googleAnnule);
    await attendre(tester, find.text('Tournoi du week-end'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi du week-end'));
    await attendreTexte(tester, 'direct_total', 'Ventes : 4 · 16,00 €');
    expect(texte(tester, 'statut_caisse_$caisseLea'), 'Clôturée · 4 ventes · 16,00 €');
    expect(texte(tester, 'direct_annulees'), 'Ventes annulées : 2');
    expect(find.byKey(Key('caisse_$caisseZoe')), findsNothing); // gymnase B : pas le sien
    expect(find.byKey(const Key('vue_limitee')), findsOneWidget);
    expect(find.byKey(const Key('cloture_reservee')), findsOneWidget);

    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'zed.recette@test.fr', password: 'secret12');
    });
    final ventesZoe = await caisses.suivreVentes(caisseZoe).first
        .timeout(const Duration(seconds: 30));
    final z1 = ventesZoe.firstWhere((v) => v.totalCentimes == 500);
    await ouvrir(tester, 'zed2', googleAnnule);
    await attendre(tester, find.text('Tournoi du week-end'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi du week-end'));
    await attendreTexte(tester, 'direct_total', 'Ventes : 4 · 12,50 €');
    expect(texte(tester, 'statut_caisse_$caisseZoe'), 'Ouverte · 4 ventes · 12,50 €');
    expect(find.byKey(const Key('direct_annulees')), findsNothing);
    expect(find.byKey(Key('caisse_$caisseLea')), findsNothing); // gymnase A : pas le sien
    expect(find.byKey(Key('caisse_$caisseZoeA')), findsNothing);
    await toucher(tester, find.byKey(Key('caisse_$caisseZoe')));
    await attendre(tester, find.byKey(Key('annuler_${z1.id}')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('annuler_${z1.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(Key('trace_${z1.id}')));
    expect(RegExp(r'^Annulée par Zed à \d{2}:\d{2}$').hasMatch(texte(tester, 'trace_${z1.id}')),
        isTrue);
    await retour(tester);
    await attendreTexte(tester, 'direct_total', 'Ventes : 3 · 7,50 €');
    expect(texte(tester, 'direct_annulees'), 'Ventes annulées : 1');

    etape('6 bilan');
    // ============ 6. Le responsable force la clôture et lit le bilan ============
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_recette')())!);
    });
    await ouvrir(tester, 'chef3', googleAnnule);
    await attendre(tester, find.text('Tournoi du week-end'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi du week-end'));
    await attendre(tester, find.byKey(const Key('cloturer_evenement')));
    await attendreTexte(tester, 'direct_total', 'Ventes : 7 · 23,50 €'); // vue commune
    expect(find.byKey(const Key('vue_commune')), findsOneWidget);
    await finTransition(tester);
    expect(find.text('Forcer la clôture'), findsOneWidget); // la caisse de Zoé (B) est ouverte
    await toucher(tester, find.byKey(const Key('cloturer_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    // La page est longue : le message de clôture, en haut, n'est plus affiché.
    await tester.pump(const Duration(seconds: 2));
    await defilerJusqua(tester, find.byKey(const Key('cloture_forcee')));
    await attendre(tester, find.byKey(const Key('cloture_forcee')));
    expect(texte(tester, 'cloture_forcee'),
        'Clôture forcée : 1 caisse non clôturée. Des ventes peuvent manquer.');
    expect(
        find.descendant(
            of: find.byKey(const Key('etat_evenement')), matching: find.text('Clôturé')),
        findsOneWidget);
    await defilerJusqua(tester, find.byKey(const Key('voir_bilan')));
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await finTransition(tester);

    final defil = find.byType(Scrollable).first;
    Future<void> verifier(Map<String, String> attendus) async {
      for (final e in attendus.entries) {
        final cible = find.byKey(Key(e.key));
        for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
          await tester.drag(defil, const Offset(0, -300));
          await tester.pump(const Duration(milliseconds: 50));
        }
        for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
          await tester.drag(defil, const Offset(0, 300));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await attendreTexte(tester, e.key, e.value);
      }
    }

    String jour(DateTime d) => dateAffichee(dateIso(d));
    await verifier({
      'bilan_etat': 'Bilan définitif : événement clôturé',
      'bilan_total': 'Total : 23,50 € · 7 ventes',
      'bilan_annulees': 'Ventes annulées : 3',
      'bilan_mode_especes': 'Espèces : 15,50 €',
      'bilan_mode_carte': 'Carte : 6,00 €',
      'bilan_mode_cheque': 'Chèque : 2,00 €',
      'bilan_produit_$cafe': 'Café : 4 vendus · 4,00 €',
      'bilan_produit_$croque': 'Croque-monsieur : 3 vendus · 9,00 €',
      'bilan_produit_$crepe': 'Crêpe : 2 vendus · 5,00 €',
      'bilan_produit_$the': 'Thé : 1 vendu · 1,00 €',
      'bilan_produit_$sucre': 'Part de gâteau sucrée : 1 vendu · 2,00 €',
      'bilan_produit_$sale': 'Part de gâteau salée : 1 vendu · 2,50 €',
      'bilan_produit_$soda': 'Soda : 0 vendu · 0,00 €',
      'bilan_produit_$barre': 'Barre chocolatée : 0 vendu · 0,00 €',
      'bilan_produit_${id('Salade')}': 'Salade : 0 vendu · 0,00 €',
      'bilan_produit_${id('Fruit')}': 'Fruit : 0 vendu · 0,00 €',
      'plus_1': '1. Café (4)',
      'plus_2': '2. Croque-monsieur (3)',
      'plus_3': '3. Crêpe (2)',
      'moins_1': '1. Barre chocolatée (0)',
      'moins_2': '2. Fruit (0)',
      'moins_3': '3. Salade (0)',
      'bilan_caisse_$caisseLea':
          'Lea : 4 ventes · 16,00 € · Clôturée · 2 annulées · Gymnase A',
      'bilan_caisse_$caisseZoeA': 'Zoe : 0 vente · 0,00 € · Clôturée · Gymnase A',
      'bilan_caisse_$caisseZoe':
          'Zoe : 3 ventes · 7,50 € · Ouverte · 1 annulée · Gymnase B',
      'bilan_jour_${dateIso(DateTime.now())}':
          '${jour(DateTime.now())} : 5 ventes · 18,50 €',
      'bilan_jour_${dateIso(demain)}': '${jour(demain)} : 2 ventes · 5,00 €',
    });
    // La clôture forcée est annoncée en toutes lettres.
    await defilerJusqua(tester, find.byKey(const Key('bilan_forcee')));
    final forcee = texte(tester, 'bilan_forcee');
    expect(forcee, startsWith('Clôture forcée par Chef le '));
    expect(forcee, endsWith('1 caisse non clôturée (Zoe). Des ventes peuvent manquer.'));
    // Les trois annulations sont listées avec leur auteur.
    final traces = <String>[];
    for (var i = 0; i < 3; i++) {
      final cible = find.byKey(Key('annulation_$i'));
      await defilerJusqua(tester, cible);
      traces.add(texte(tester, 'annulation_$i'));
    }
    expect(traces.where((t) => t.contains('annulée par Lea')).length, 2);
    expect(traces.where((t) => t.contains('annulée par Zed')).length, 1);
    expect(find.byKey(const Key('annulation_3')), findsNothing);
    // Heures de pointe : la tranche la plus chargée compte au moins 2 ventes.
    await defilerJusqua(tester, find.byKey(const Key('pointe_1')));
    final pointe = RegExp(r'^\d{1,2} h–\d{1,2} h : (\d+) ventes?$')
        .firstMatch(texte(tester, 'pointe_1'));
    expect(pointe, isNotNull);
    expect(int.parse(pointe!.group(1)!), greaterThanOrEqualTo(2));

    // Vue distincte du gymnase A (Léa) : chiffres écrits à la main.
    await defilerJusqua(tester, find.byKey(Key('vue_$gA')));
    await toucher(tester, find.byKey(Key('vue_$gA')));
    await verifier({
      'bilan_total': 'Total : 16,00 € · 4 ventes',
      'bilan_annulees': 'Ventes annulées : 2',
      'bilan_mode_especes': 'Espèces : 10,00 €',
      'bilan_mode_carte': 'Carte : 6,00 €',
      'bilan_mode_cheque': 'Chèque : 0,00 €',
      'bilan_produit_$cafe': 'Café : 2 vendus · 2,00 €',
      'bilan_produit_$croque': 'Croque-monsieur : 2 vendus · 6,00 €',
      'bilan_produit_$crepe': 'Crêpe : 2 vendus · 5,00 €',
      'bilan_produit_$the': 'Thé : 1 vendu · 1,00 €',
      'bilan_produit_$sucre': 'Part de gâteau sucrée : 1 vendu · 2,00 €',
      'bilan_produit_$sale': 'Part de gâteau salée : 0 vendu · 0,00 €',
      'bilan_produit_$soda': 'Soda : 0 vendu · 0,00 €',
      'bilan_produit_$barre': 'Barre chocolatée : 0 vendu · 0,00 €',
      'plus_1': '1. Café (2)',
      'plus_2': '2. Croque-monsieur (2)',
      'plus_3': '3. Crêpe (2)',
      'moins_1': '1. Barre chocolatée (0)',
      'moins_2': '2. Fruit (0)',
      'moins_3': '3. Part de gâteau salée (0)',
      'bilan_caisse_$caisseLea':
          'Lea : 4 ventes · 16,00 € · Clôturée · 2 annulées · Gymnase A',
      'bilan_caisse_$caisseZoeA': 'Zoe : 0 vente · 0,00 € · Clôturée · Gymnase A',
      'bilan_jour_${dateIso(DateTime.now())}':
          '${jour(DateTime.now())} : 4 ventes · 16,00 €',
    });
    expect(find.byKey(Key('bilan_caisse_$caisseZoe')), findsNothing); // caisse du gymnase B
    expect(find.byKey(Key('bilan_jour_${dateIso(demain)}')), findsNothing);
    expect(find.byKey(const Key('annulation_2')), findsNothing); // 2 annulations ici

    // Vue distincte du gymnase B (Zoé).
    await defilerJusqua(tester, find.byKey(Key('vue_$gB')));
    await toucher(tester, find.byKey(Key('vue_$gB')));
    await verifier({
      'bilan_total': 'Total : 7,50 € · 3 ventes',
      'bilan_annulees': 'Ventes annulées : 1',
      'bilan_mode_especes': 'Espèces : 5,50 €',
      'bilan_mode_carte': 'Carte : 0,00 €',
      'bilan_mode_cheque': 'Chèque : 2,00 €',
      'bilan_produit_$cafe': 'Café : 2 vendus · 2,00 €',
      'bilan_produit_$croque': 'Croque-monsieur : 1 vendu · 3,00 €',
      'bilan_produit_$sale': 'Part de gâteau salée : 1 vendu · 2,50 €',
      'bilan_produit_$crepe': 'Crêpe : 0 vendu · 0,00 €',
      'bilan_produit_${id('Salade')}': 'Salade : 0 vendu · 0,00 €',
      'plus_1': '1. Café (2)',
      'plus_2': '2. Croque-monsieur (1)',
      'plus_3': '3. Part de gâteau salée (1)',
      'moins_1': '1. Barre chocolatée (0)',
      'moins_2': '2. Crêpe (0)',
      'moins_3': '3. Fruit (0)',
      'bilan_caisse_$caisseZoe':
          'Zoe : 3 ventes · 7,50 € · Ouverte · 1 annulée · Gymnase B',
      'bilan_jour_${dateIso(DateTime.now())}':
          '${jour(DateTime.now())} : 1 vente · 2,50 €',
      'bilan_jour_${dateIso(demain)}': '${jour(demain)} : 2 ventes · 5,00 €',
    });
    expect(find.byKey(Key('bilan_caisse_$caisseLea')), findsNothing); // gymnase A
    expect(find.byKey(Key('bilan_caisse_$caisseZoeA')), findsNothing);
    expect(find.byKey(const Key('annulation_1')), findsNothing); // 1 annulation ici

    // Retour à la vue commune : les chiffres de départ.
    await defilerJusqua(tester, find.byKey(const Key('vue_commune')));
    await toucher(tester, find.byKey(const Key('vue_commune')));
    await verifier({'bilan_total': 'Total : 23,50 € · 7 ventes'});

    // Côté serveur : l'événement est bien clôturé de façon forcée, la caisse de Zoé reste ouverte.
    final evtServeur =
        (await db.collection('associations').doc(assoId).collection('evenements').doc(evt.id).get(serveur)).data()!;
    expect(evtServeur['statut'], 'cloture');
    expect(evtServeur['forcee'], true);
    expect(evtServeur['nbCaissesOuvertes'], 1);
    expect(evtServeur['clotureParPrenom'], 'Chef');
    expect(
        (await db.collection('associations').doc(assoId).collection('evenements').doc(evt.id).collection('caisses').doc(caisseZoe).get(serveur)).data()!['statut'],
        'ouverte');

    etape('7 coupure');
    // ============ 7. Coupure de réseau (second événement, pour ne pas fausser le bilan) ============
    final evt2 = await depotEv.creerEvenement(
      nom: 'Buvette du dimanche',
      date: dateIso(demain),
      menuId: menu.id,
      modes: ['especes'],
    );
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'zoe.recette@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'zoe2', googleAnnule);
    await attendre(tester, find.text('Buvette du dimanche'));
    expect(find.text('Tournoi du week-end'), findsNothing); // clôturé : invisible du bénévole
    await finTransition(tester);
    await toucher(tester, find.text('Buvette du dimanche'));
    await attendre(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await db.disableNetwork();
    await vendre(tester, ['Crêpe'], 'especes');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 2,50 €');
    await attendreTexte(tester, 'envoi_caisse', "En attente d'envoi : 1");
    await db.enableNetwork();
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    final gym2 = await gymnaseUnique(depotEv, evt2);
    final ventes2 = await db
        .collection('associations')
        .doc(assoId)
        .collection('evenements')
        .doc(evt2)
        .collection('caisses')
        .doc(idCaisse(zoeUid, gym2))
        .collection('ventes')
        .get(serveur);
    expect(ventes2.docs.length, 1);
    expect(ventes2.docs.single.data()['totalCentimes'], 250);
  });
}
