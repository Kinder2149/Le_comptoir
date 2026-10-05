import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission M3 : gestionnaires rattachés à des gymnases. Deux gymnases, une caisse et
// une vente dans chacun ; Gus est rattaché au gymnase A, Zed au gymnase B.
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

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) {
        return;
      }
    }
    final f = find.byKey(Key(cle));
    final actuel =
        f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
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

  Future<void> changerDeSession(
      WidgetTester tester, Future<void> Function() connexion) async {
    await tester.pumpWidget(const SizedBox());
    await FirebaseAuth.instance.signOut();
    await connexion();
  }

  testWidgets(
      'gestionnaires rattachés : chacun ne voit que son gymnase ; clôture réservée',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : association, menu, événement à deux gymnases.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_gestionnaires'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    final depotAsso = DepotAssociations(db);
    final menuId = await depotAsso.menus(assoId).creerMenu('Menu Tournoi');
    await depotAsso.menus(assoId).ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 10);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final croque = (await depotEv.suivreProduits(evt).first).single.id;
    expect(
        (await db
                .collection('associations')
                .doc(assoId)
                .collection('evenements')
                .doc(evt)
                .get(serveur))
            .data()!['nbGymnases'],
        2);
    final caisses = depotEv.caisses(evt);

    // --- Léa (gymnase A, 2 croque = 6,00 €) et Max (gymnase B, 1 croque = 3,00 €).
    Future<String> benevole(String email, String prenom, String gym, int qte) async {
      await changerDeSession(tester, () async {
        await auth.createUserWithEmailAndPassword(
            email: email, password: 'secret12');
      });
      final uid = auth.currentUser!.uid;
      await depotAsso.rejoindre(uid: uid, codeSaisi: code, prenom: prenom);
      final caisseId = idCaisse(uid, gym);
      await caisses.ouvrirCaisse(caisseId, prenom);
      // La caisse est enregistrée avant la première vente (sinon l'émulateur peut
      // évaluer la vente avant la caisse et la refuser).
      await db.waitForPendingWrites();
      caisses.enregistrerVente(
        caisseId,
        [LigneVente(croque, 'Croque-monsieur', 300, qte)],
        'especes',
        stocks: {croque: 10},
      );
      await db.waitForPendingWrites();
      return caisseId;
    }

    final caisseLea = await benevole('lea.gest@test.fr', 'Lea', gA, 2);
    final caisseMax = await benevole('max.gest@test.fr', 'Max', gB, 1);

    // --- Gus et Zed : bénévoles nommés par le responsable, puis activés avec Google.
    final uids = <String, String>{};
    Future<void> candidat(String email, String prenom) async {
      await changerDeSession(tester, () async {
        await auth.createUserWithEmailAndPassword(
            email: email, password: 'secret12');
      });
      uids[prenom] = auth.currentUser!.uid;
      await depotAsso.rejoindre(
          uid: uids[prenom]!, codeSaisi: code, prenom: prenom);
    }

    await candidat('gus.gest@test.fr', 'Gus');
    await candidat('zed.gest@test.fr', 'Zed');
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_gestionnaires')())!);
    });
    await depotAsso.nommerGestionnaire(assoId, uids['Gus']!);
    await depotAsso.nommerGestionnaire(assoId, uids['Zed']!);
    for (final (prenom, email, google) in [
      ('Gus', 'gus.gest@test.fr', 'gus_g'),
      ('Zed', 'zed.gest@test.fr', 'zed_g'),
    ]) {
      await changerDeSession(tester, () async {
        await auth.signInWithEmailAndPassword(email: email, password: 'secret12');
        await auth.currentUser!.linkWithCredential((await fauxGoogle(google)())!);
        await auth.currentUser!.getIdToken(true);
      });
      await depotAsso.activerGestionnaire(assoId, uids[prenom]!);
    }
    final gusUid = uids['Gus']!, zedUid = uids['Zed']!;

    // --- Sans rattachement : un gestionnaire ne voit aucune vente.
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'gus.gest@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'gus0', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('aucun_gymnase_rattache')));
    expect(find.byKey(const Key('direct_total')), findsNothing);
    expect(find.byKey(const Key('cloturer_evenement')), findsNothing);

    // --- Le responsable rattache Gus au gymnase A et Zed au gymnase B (par l'écran).
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_gestionnaires')())!);
    });
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_gymnases')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(Key('rattachement_$gusUid')));
    await finTransition(tester);
    await toucher(tester, find.byKey(Key('rattacher_${gusUid}_$gA')));
    await toucher(tester, find.byKey(Key('rattacher_${zedUid}_$gB')));
    Future<Set<String>> rattaches(String uid) async {
      final doc = await db
          .collection('associations')
          .doc(assoId)
          .collection('evenements')
          .doc(evt)
          .collection('rattachements')
          .doc(uid)
          .get(serveur);
      final liste = (doc.data()?['gymnases'] as List?) ?? const [];
      return {for (final g in liste) g as String};
    }

    for (var i = 0; i < 100 && (await rattaches(zedUid)).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await rattaches(gusUid), {gA});
    expect(await rattaches(zedUid), {gB});

    // --- Gus : ne voit que le gymnase A.
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'gus.gest@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'gus1', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendreTexte(tester, 'direct_total', 'Ventes : 1 · 6,00 €');
    expect(find.byKey(Key('caisse_$caisseLea')), findsOneWidget);
    expect(find.byKey(Key('caisse_$caisseMax')), findsNothing);
    expect(find.byKey(const Key('vue_limitee')), findsOneWidget);
    expect(find.byKey(const Key('cloturer_evenement')), findsNothing);
    expect(find.byKey(const Key('cloture_reservee')), findsOneWidget);
    // Bilan limité à son gymnase.
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_limite')));
    await finTransition(tester);
    expect(texte(tester, 'bilan_total'), 'Total des ventes | 6,00 € | 1 vente');
    await retour(tester);
    // Écran des gymnases : seulement le sien, aucun rattachement ni ajout.
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(Key('gymnase_$gA')));
    await finTransition(tester);
    expect(find.byKey(Key('gymnase_$gB')), findsNothing);
    expect(find.byKey(const Key('ajouter_gymnase')), findsNothing);
    expect(find.byKey(Key('rattachement_$gusUid')), findsNothing);
    await retour(tester);

    // Le serveur refuse les lectures hors de son gymnase (et sans filtre).
    await tester.pumpWidget(const SizedBox());
    Future<bool> refuse(Future<Object?> lecture) async {
      try {
        await lecture;
        return false;
      } on FirebaseException catch (e) {
        return e.code == 'permission-denied';
      }
    }

    // (lectures directes sur le serveur : le cache local du téléphone ne compte pas)
    final refEvt = db
        .collection('associations')
        .doc(assoId)
        .collection('evenements')
        .doc(evt);
    expect(
        await refuse(refEvt
            .collection('caisses')
            .where('gymnaseId', isEqualTo: gB)
            .get(serveur)),
        isTrue);
    expect(await refuse(refEvt.collection('caisses').get(serveur)), isTrue);
    expect(
        (await refEvt
                .collection('caisses')
                .where('gymnaseId', isEqualTo: gA)
                .get(serveur))
            .docs
            .length,
        1);
    expect(
        await refuse(
            refEvt.collection('caisses').doc(caisseMax).collection('ventes').get(serveur)),
        isTrue);
    expect(await refuse(refEvt.collection('rattachements').get(serveur)), isTrue);

    // --- Zed : ne voit que le gymnase B.
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'zed.gest@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'zed1', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendreTexte(tester, 'direct_total', 'Ventes : 1 · 3,00 €');
    expect(find.byKey(Key('caisse_$caisseMax')), findsOneWidget);
    expect(find.byKey(Key('caisse_$caisseLea')), findsNothing);

    // --- Rattaché aux deux gymnases : vue complète et clôture possible.
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_gestionnaires')())!);
    });
    await depotEv.definirRattachement(evt, gusUid, {gA, gB});
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'gus.gest@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'gus2', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendreTexte(tester, 'direct_total', 'Ventes : 2 · 9,00 €');
    expect(find.byKey(const Key('vue_limitee')), findsNothing);
    expect(find.byKey(const Key('cloturer_evenement')), findsOneWidget);
    expect(find.byKey(const Key('cloture_reservee')), findsNothing);

    // --- Retrait du statut de gestionnaire : le rattachement ne donne plus rien.
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_gestionnaires')())!);
    });
    await depotAsso.retirerGestionnaire(assoId, gusUid);
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'gus.gest@test.fr', password: 'secret12');
    });
    expect(
        await refuse(db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('caisses')
            .where('gymnaseId', isEqualTo: gA)
            .get(serveur)),
        isTrue);
    await ouvrir(tester, 'gus3', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('titre_evenement')));
    await finTransition(tester);
    expect(find.byKey(const Key('direct_total')), findsNothing);
  });
}
