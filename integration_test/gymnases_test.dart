import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission M2 : plusieurs gymnases pour un événement, stock distinct, caisse
// rattachée à un gymnase, changement de gymnase après clôture.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  /// Les listes ne construisent que ce qui est visible : on défile jusqu'à
  /// trouver l'élément.
  Future<void> montrer(WidgetTester tester, Finder cible) async {
    final defil = find.byType(Scrollable).first;
    for (final sens in [-300.0, 300.0]) {
      for (var i = 0; i < 15 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, Offset(0, sens));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await tester.ensureVisible(cible);
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await montrer(tester, cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saisir(WidgetTester tester, String cle, String valeur) async {
    await montrer(tester, find.byKey(Key(cle)));
    await tester.enterText(find.byKey(Key(cle)), valeur);
    await tester.pump();
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && tester.widget<Text>(f).data == attendu) {
        return;
      }
    }
    final f = find.byKey(Key(cle));
    final actuel =
        f.evaluate().isEmpty ? '(absent)' : tester.widget<Text>(f).data;
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
  }

  Future<void> vendre(
      WidgetTester tester, List<String> articles, String mode) async {
    for (final a in articles) {
      await attendre(tester, find.text(a));
      await tester.ensureVisible(find.text(a));
      await tester.tap(find.text(a));
      await tester.pump(const Duration(milliseconds: 300));
    }
    final payer = find.byKey(Key('encaisser_$mode'));
    await tester.ensureVisible(payer);
    await tester.tap(payer);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'gymnases : création, stocks distincts, ouverture par gymnase, changement de gymnase',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : association et menu (croque-monsieur : stock 10).
    await ouvrir(tester, 'responsable', fauxGoogle('chef_gymnases'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 10);
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);

    // --- Création par le formulaire : deux gymnases (noms distincts exigés).
    await attendre(tester, find.byKey(const Key('nouvel_evenement')));
    await toucher(tester, find.byKey(const Key('nouvel_evenement')));
    await attendre(tester, find.byKey(Key('choix_menu_$menuId')));
    await saisir(tester, 'nom_evenement', 'Tournoi');
    await toucher(tester, find.byKey(Key('choix_menu_$menuId')));
    expect(find.byKey(const Key('nom_gymnase_0')), findsOneWidget);
    expect(find.byKey(const Key('retirer_gymnase_0')), findsNothing); // au moins un
    await saisir(tester, 'nom_gymnase_0', 'Gymnase A');
    await toucher(tester, find.byKey(const Key('ajouter_gymnase_formulaire')));
    await saisir(tester, 'nom_gymnase_1', 'gymnase a ');
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await attendre(tester, find.byKey(const Key('erreur_evenement')));
    expect(texte(tester, 'erreur_evenement'),
        'Deux gymnases ne peuvent pas porter le même nom.');
    await saisir(tester, 'nom_gymnase_1', 'Gymnase B');
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await attendre(tester, find.byKey(const Key('nouvel_evenement')));
    await finTransition(tester);
    final evt = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .get(serveur))
        .docs
        .single
        .id;
    final gymnases = await depotEv.suivreGymnases(evt).first;
    expect([for (final g in gymnases) g.nom], ['Gymnase A', 'Gymnase B']);
    final gA = gymnases[0].id, gB = gymnases[1].id;
    final produits = await depotEv.suivreProduits(evt).first;
    final croque = produits.firstWhere((p) => p.nom == 'Croque-monsieur').id;
    final cafe = produits.firstWhere((p) => p.nom == 'Café').id;

    Future<int?> stock(String g, String p) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('gymnases')
            .doc(g)
            .collection('stocks')
            .doc(p)
            .get(serveur))
        .data()?['quantite'] as int?;

    // Chaque gymnase part du stock du menu.
    expect(await stock(gA, croque), 10);
    expect(await stock(gB, croque), 10);
    expect(await stock(gA, cafe), isNull); // pas de suivi

    // --- Écran « Gymnases et stocks » : régler, réapprovisionner, suivre, ajouter, renommer.
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_gymnases')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(Key('gymnase_$gA')));
    await finTransition(tester);

    await toucher(tester, find.byKey(Key('modifier_stock_${gA}_$croque')));
    await saisir(tester, 'saisie_quantite', '20');
    await toucher(tester, find.byKey(const Key('valider_quantite')));
    await attendreTexte(tester, 'stock_${gA}_$croque', 'Stock : 20');

    await toucher(tester, find.byKey(Key('reappro_${gB}_$croque')));
    await saisir(tester, 'saisie_quantite', '5');
    await toucher(tester, find.byKey(const Key('valider_quantite')));
    await attendreTexte(tester, 'stock_${gB}_$croque', 'Stock : 15');
    expect(await stock(gA, croque), 20);
    expect(await stock(gB, croque), 15); // chaque gymnase a son stock

    await toucher(tester, find.byKey(Key('suivi_${gA}_$cafe'))); // suivre le café
    await attendreTexte(tester, 'stock_${gA}_$cafe', 'Stock : 0');
    await toucher(tester, find.byKey(Key('suivi_${gA}_$cafe'))); // ne plus le suivre
    await attendreTexte(tester, 'stock_${gA}_$cafe', 'Pas de suivi');
    expect(await stock(gA, cafe), isNull);

    await toucher(tester, find.byKey(Key('modifier_stock_${gA}_$croque')));
    await saisir(tester, 'saisie_quantite', 'abc');
    await toucher(tester, find.byKey(const Key('valider_quantite')));
    expect(find.text('Entrez un nombre entier de 0 à 100 000.'), findsOneWidget);
    await toucher(tester, find.text('Retour'));
    await finTransition(tester);

    await toucher(tester, find.byKey(const Key('ajouter_gymnase')));
    await saisir(tester, 'saisie_nom_gymnase', 'Gymnase A');
    await toucher(tester, find.byKey(const Key('valider_nom_gymnase')));
    expect(find.text('Deux gymnases ne peuvent pas porter le même nom.'),
        findsOneWidget);
    await saisir(tester, 'saisie_nom_gymnase', 'Gymnase C');
    await toucher(tester, find.byKey(const Key('valider_nom_gymnase')));
    await finTransition(tester);
    final gC = (await depotEv.suivreGymnases(evt).first)
        .firstWhere((g) => g.nom == 'Gymnase C')
        .id;
    expect(await stock(gC, croque), 0); // même suivi que les autres, à zéro
    expect(await stock(gC, cafe), isNull);

    await toucher(tester, find.byKey(Key('renommer_gymnase_$gB')));
    await saisir(tester, 'saisie_nom_gymnase', 'Annexe');
    await toucher(tester, find.byKey(const Key('valider_nom_gymnase')));
    await finTransition(tester);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Annexe').evaluate().isNotEmpty) break;
    }
    expect(find.text('Annexe'), findsOneWidget);
    await retour(tester);

    // --- Léa (bénévole) : une caisse dans le gymnase A.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    final leaUid = auth.currentUser!.uid;
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await finTransition(tester);
    // Un bouton par gymnase, avec son nom.
    expect(find.text('Ouvrir ma caisse · Gymnase A'), findsOneWidget);
    expect(find.text('Ouvrir ma caisse · Annexe'), findsOneWidget);
    expect(find.text('Ouvrir ma caisse · Gymnase C'), findsOneWidget);
    expect(find.byKey(const Key('ma_caisse')), findsNothing);
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(find.text('Caisse de Lea'), findsOneWidget);
    expect(texte(tester, 'gymnase_caisse'), 'Gymnase A');
    await attendre(tester, find.text('Stock : 20'));
    await vendre(tester, ['Croque-monsieur', 'Croque-monsieur'], 'especes');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 6,00 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await attendre(tester, find.text('Stock : 18'));
    expect(await stock(gA, croque), 18);
    expect(await stock(gB, croque), 15); // l'autre gymnase n'a pas bougé
    await retour(tester);

    // --- Changer de gymnase : refusé tant que la caisse est ouverte.
    await attendreTexte(tester, 'ma_caisse', 'Ma caisse : Gymnase A (ouverte)');
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gB')));
    await attendre(tester, find.byKey(const Key('caisse_deja_ouverte')));
    expect(texte(tester, 'caisse_deja_ouverte'),
        "Clôturez d'abord votre caisse à Gymnase A, puis ouvrez-en une dans Annexe.");
    await toucher(tester, find.byKey(const Key('cloturer_caisse_precedente')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    await toucher(tester, find.byKey(const Key('fermer_cloture')));
    await finTransition(tester);
    for (var i = 0; i < 100 && find.byKey(const Key('ma_caisse')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('ma_caisse')), findsNothing);
    expect(
        await restStatutDocument(
            'associations/$assoId/evenements/$evt/ouvertes/$leaUid'),
        404);

    // --- Ouvrir dans l'Annexe (gymnase B) : son stock à elle.
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gB')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_caisse'), 'Annexe');
    await attendre(tester, find.text('Stock : 15'));
    await vendre(tester, ['Croque-monsieur'], 'especes');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 3,00 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await attendre(tester, find.text('Stock : 14'));
    expect(await stock(gA, croque), 18);
    expect(await stock(gB, croque), 14);
    await retour(tester);

    // --- Retour dans le premier gymnase : clôturer l'Annexe, puis rouvrir la caisse de A.
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('caisse_deja_ouverte')));
    expect(texte(tester, 'caisse_deja_ouverte'),
        "Clôturez d'abord votre caisse à Annexe, puis ouvrez-en une dans Gymnase A.");
    await toucher(tester, find.byKey(const Key('cloturer_caisse_precedente')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    await toucher(tester, find.byKey(const Key('fermer_cloture')));
    await finTransition(tester);
    await attendre(tester, find.text('Rouvrir ma caisse · Gymnase A'));
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'gymnase_caisse'), 'Gymnase A');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 6,00 €');
    expect(find.byKey(const Key('caisse_cloturee')), findsNothing); // rouverte
    await attendre(tester, find.text('Stock : 18'));
    final caisseA = idCaisse(leaUid, gA);
    final doc = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('caisses')
            .doc(caisseA)
            .get(serveur))
        .data()!;
    expect(doc['statut'], 'ouverte');
    expect(doc['gymnaseId'], gA);
    expect(doc['rouverteLe'], isNotNull);

    // --- Max, dans le gymnase C, en même temps : seul le stock de C bouge.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'max.gymnases@test.fr', password: 'secret12');
    final maxUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: maxUid, codeSaisi: code, prenom: 'Max');
    final caisses = depotEv.caisses(evt);
    final caisseC = idCaisse(maxUid, gC);
    await caisses.ouvrirCaisse(caisseC, 'Max');
    // La caisse est enregistrée avant la première vente (sinon l'émulateur peut
    // évaluer la vente avant la caisse et la refuser).
    await db.waitForPendingWrites();
    caisses.enregistrerVente(
      caisseC,
      [LigneVente(croque, 'Croque-monsieur', 300, 1)],
      'especes',
      stocks: {croque: 0},
    );
    await db.waitForPendingWrites();
    expect(await stock(gC, croque), -1); // le stock peut passer sous zéro
    expect(await stock(gA, croque), 18);
    expect(await stock(gB, croque), 14);
    expect(
        await restStatutDocument(
            'associations/$assoId/evenements/$evt/ouvertes/$maxUid'),
        200);
  });
}
