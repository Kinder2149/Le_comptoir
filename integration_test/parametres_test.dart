import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/evenement.dart';

import 'outils.dart';

// Paramètres du responsable : changer le code, retirer un membre, supprimer
// l'association (retour à l'accueil sur tous les téléphones).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> defilerJusqua(WidgetTester tester, Finder cible) async {
    final defil = find.byType(Scrollable).first;
    for (final sens in [-300.0, 300.0]) {
      for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
        await tester.drag(defil, Offset(0, sens));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> changerDeSession(
      WidgetTester tester, Future<void> Function() connexion) async {
    await tester.pumpWidget(const SizedBox());
    await FirebaseAuth.instance.signOut();
    await connexion();
  }

  testWidgets('paramètres : changer le code, retirer un membre, supprimer l\'association',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final depotAsso = DepotAssociations(db);
    await auth.signOut();

    // ====== Préparation : une association bien remplie ======
    await ouvrir(tester, 'chef1', fauxGoogle('chef_param'));
    await creerAssociationParLInterface(tester, nom: 'Club Param', prenom: 'Chef');
    final code1 = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu');
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150, stock: 10);
    await menus.ajouterProduit(menuId, nom: 'Soda', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
    );
    final gym = await gymnaseUnique(depotEv, evt);
    final cafeId = (await depotEv.suivreProduits(evt).first).firstWhere((p) => p.nom == 'Café').id;

    // Léa : membre avec une caisse et deux ventes. Max : simple membre.
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(email: 'lea.param@test.fr', password: 'secret12');
    });
    final leaUid = auth.currentUser!.uid;
    final caisseLea = idCaisse(leaUid, gym);
    await depotAsso.rejoindre(uid: leaUid, codeSaisi: code1, prenom: 'Lea');
    final caisses = depotEv.caisses(evt);
    await caisses.ouvrirCaisse(caisseLea, 'Lea');
    // La caisse est enregistrée avant la première vente (sinon l'émulateur peut
    // évaluer la vente avant la caisse et la refuser).
    await db.waitForPendingWrites();
    for (var i = 0; i < 2; i++) {
      caisses.enregistrerVente(caisseLea, [LigneVente(cafeId, 'Café', 150, 1)], 'especes',
          stocks: {cafeId: 10});
    }
    await db.waitForPendingWrites();
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_param')())!);
    });
    await depotEv.definirRattachement(evt, leaUid, {gym}); // doit disparaître avec l'association
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(email: 'max.param@test.fr', password: 'secret12');
    });
    final maxUid = auth.currentUser!.uid;
    await depotAsso.rejoindre(uid: maxUid, codeSaisi: code1, prenom: 'Max');

    // ====== 1. Paramètres du responsable : association, code, membres ======
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_param')())!);
    });
    await ouvrir(tester, 'chef2', googleAnnule);
    await attendre(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.text('Membres (3)'));
    expect(find.byKey(const Key('regenerer')), findsNothing); // plus sur l'écran principal
    await toucher(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('param_nom')));
    await finTransition(tester);
    expect(texte(tester, 'param_nom'), 'Club Param');
    expect(texte(tester, 'param_code'), code1);
    await defilerJusqua(tester, find.byKey(Key('sortir_$leaUid')));
    expect(find.byKey(Key('sortir_$leaUid')), findsOneWidget);
    expect(find.byKey(Key('sortir_$maxUid')), findsOneWidget);
    expect(find.byKey(Key('sortir_$chefUid')), findsNothing); // pas sur le responsable

    // ====== 2. Changer le code : l'ancien est refusé aux nouveaux arrivants ======
    await defilerJusqua(tester, find.byKey(const Key('regenerer')));
    await toucher(tester, find.byKey(const Key('regenerer')));
    await toucher(tester, find.byKey(const Key('confirmer_regeneration')));
    for (var i = 0; i < 150 && texte(tester, 'param_code') == code1; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final code2 = texte(tester, 'param_code');
    expect(code2, isNot(code1));
    await db.waitForPendingWrites();

    // ====== 3. Retirer Max ======
    await defilerJusqua(tester, find.byKey(Key('sortir_$maxUid')));
    await toucher(tester, find.byKey(Key('sortir_$maxUid')));
    await toucher(tester, find.byKey(const Key('confirmer_sortie')));
    for (var i = 0; i < 150 && find.byKey(Key('sortir_$maxUid')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(Key('sortir_$maxUid')), findsNothing);
    expect(find.byKey(Key('sortir_$leaUid')), findsOneWidget); // Léa est toujours là
    expect(await restStatutDocument('associations/$assoId/membres/$maxUid'), 404);
    expect(await restStatutDocument('associations/$assoId/membres/$leaUid'), 200);
    // Ses ventes passées restent (bilans) : Léa, elle, n'a pas bougé.
    expect(await restNbDocuments('associations/$assoId/evenements/$evt/caisses/$caisseLea/ventes'), 2);
    // Le gymnase, son stock et le pointeur de la caisse ouverte existent avant la suppression.
    expect(await restNbDocuments('associations/$assoId/evenements/$evt/gymnases'), 1);
    expect(await restNbDocuments('associations/$assoId/evenements/$evt/gymnases/$gym/stocks'), 1);
    expect(await restNbDocuments('associations/$assoId/evenements/$evt/ouvertes'), 1);
    expect(await restNbDocuments('associations/$assoId/evenements/$evt/rattachements'), 1);

    // Max, retiré, revient à l'écran d'accueil.
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(email: 'max.param@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'max2', googleAnnule);
    await attendre(tester, find.byKey(const Key('creer')));
    // L'ancien code est refusé (il a changé), le nouveau est accepté.
    await tester.enterText(find.byKey(const Key('code_saisi')), code1);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Max');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.byKey(const Key('erreur')));
    expect(texte(tester, 'erreur'), 'Code inconnu ou périmé.');

    // ====== 4. Supprimer l'association ======
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_param')())!);
    });
    await ouvrir(tester, 'chef3', googleAnnule);
    await attendre(tester, find.byKey(const Key('parametres')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('param_nom')));
    await finTransition(tester);
    await defilerJusqua(tester, find.byKey(const Key('supprimer_association')));
    await toucher(tester, find.byKey(const Key('supprimer_association')));
    await attendre(tester, find.byKey(const Key('confirmation_nom')));
    expect(find.byKey(const Key('avertissement_suppression')), findsOneWidget);
    FilledButton confirmer() =>
        tester.widget<FilledButton>(find.byKey(const Key('confirmer_suppression_asso')));
    expect(confirmer().onPressed, isNull); // rien tapé : bouton inactif
    await tester.enterText(find.byKey(const Key('confirmation_nom')), 'Autre nom');
    await tester.pump();
    expect(confirmer().onPressed, isNull); // mauvais nom : toujours inactif
    await tester.enterText(find.byKey(const Key('confirmation_nom')), 'club param');
    await tester.pump();
    expect(confirmer().onPressed, isNotNull); // bon nom : actif
    // Pas d'annulation par erreur : « Annuler » ne supprime rien.
    await toucher(tester, find.text('Annuler'));
    await finTransition(tester);
    expect(await restStatutDocument('associations/$assoId'), 200);

    await toucher(tester, find.byKey(const Key('supprimer_association')));
    await attendre(tester, find.byKey(const Key('confirmation_nom')));
    await tester.enterText(find.byKey(const Key('confirmation_nom')), 'Club Param');
    await tester.pump();
    await toucher(tester, find.byKey(const Key('confirmer_suppression_asso')));
    // Retour à l'écran d'accueil (Créer / Rejoindre).
    await attendre(tester, find.byKey(const Key('creer')));
    await finTransition(tester);
    expect(find.byKey(const Key('rejoindre')), findsOneWidget);
    expect(find.byKey(const Key('param_nom')), findsNothing);

    // Il ne reste RIEN sur le serveur (les dernières suppressions finissent juste après
    // le retour à l'accueil : on attend un peu).
    for (var i = 0; i < 100 && await restStatutDocument('associations/$assoId') != 404; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(await restStatutDocument('associations/$assoId'), 404);
    for (final c in [
      'associations/$assoId/membres',
      'associations/$assoId/menus',
      'associations/$assoId/menus/$menuId/produits',
      'associations/$assoId/evenements',
      'associations/$assoId/evenements/$evt/produits',
      'associations/$assoId/evenements/$evt/caisses',
      'associations/$assoId/evenements/$evt/caisses/$caisseLea/ventes',
      'associations/$assoId/evenements/$evt/gymnases',
      'associations/$assoId/evenements/$evt/gymnases/$gym/stocks',
      'associations/$assoId/evenements/$evt/ouvertes',
      'associations/$assoId/evenements/$evt/rattachements',
    ]) {
      expect(await restNbDocuments(c), 0, reason: c);
    }
    expect(await restStatutDocument('codes/$code2'), 404);
    expect(await restStatutDocument('users/$chefUid'), 404);

    // ====== 5. Léa, sur son téléphone : retour à l'accueil, ancien code refusé ======
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(email: 'lea.param@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'lea2', googleAnnule);
    await attendre(tester, find.byKey(const Key('creer')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code2);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.byKey(const Key('erreur')));
    expect(texte(tester, 'erreur'), 'Code inconnu ou périmé.');
  });
}
