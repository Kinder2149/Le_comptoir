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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
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

  Future<void> vendre(
      WidgetTester tester, List<String> articles, String mode) async {
    for (final a in articles) {
      await toucher(tester, find.text(a));
    }
    await toucher(tester, find.byKey(Key('encaisser_$mode')));
  }

  testWidgets('clôtures : caisse (récapitulatif, réouverture) puis événement (normale et forcée)',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : association, menu, deux événements.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_clotures'));
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
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 5);
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt1 = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
    );
    final evt2 = await depotEv.creerEvenement(
      nom: 'Tournoi 2',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
    );
    final caisses1 = depotEv.caisses(evt1);
    final gym1 = await gymnaseUnique(depotEv, evt1);
    final refEvt1 =
        db.collection('associations').doc(assoId).collection('evenements').doc(evt1);

    // --- Lea ouvre sa caisse ; 3 ventes dont une annulée.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    final leaUid = auth.currentUser!.uid;
    final caisseLea = idCaisse(leaUid, gym1);
    final caisseChef = idCaisse(chefUid, gym1);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.text('Ouvrir ma caisse'));
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);

    await vendre(tester, ['Croque-monsieur', 'Café'], 'especes'); // A : 4,50
    await vendre(tester, ['Café', 'Café'], 'carte'); // B : 3,00
    await vendre(tester, ['Croque-monsieur'], 'especes'); // C : 3,00 (annulée)
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 10,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    final c = (await caisses1.suivreVentes(caisseLea).first)
        .firstWhere((v) => v.totalCentimes == 300 && v.mode == 'especes');
    caisses1.annulerVente(caisseLea, c,
        parUid: leaUid, parPrenom: 'Lea', stocks: {});
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 7,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');

    // --- Clôture : récapitulatif à compter, puis envoi final confirmé.
    await vendre(tester, ['Café'], 'especes'); // D : 1,50
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 9,00 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await toucher(tester, find.byKey(const Key('ouvrir_cloture')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    expect(find.byKey(const Key('cloture_attente')), findsNothing); // rien en attente
    expect(texte(tester, 'cloture_total'), 'Ventes : 3 · 9,00 €');
    expect(texte(tester, 'cloture_annulees'), 'Ventes annulées : 1');
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    expect(texte(tester, 'cloture_total'), 'Ventes : 3 · 9,00 €');
    expect(texte(tester, 'recap_mode_especes'), 'Espèces : 6,00 €');
    expect(texte(tester, 'recap_mode_carte'), 'Carte : 3,00 €');
    expect(texte(tester, 'a_remettre'), 'Espèces à remettre : 6,00 €');
    // Côté serveur : toutes les ventes sont arrivées avant la clôture.
    final ventesServeur = await refEvt1
        .collection('caisses')
        .doc(caisseLea)
        .collection('ventes')
        .get(serveur);
    expect(ventesServeur.docs.length, 4); // A, B, C (annulée), D
    var caisseDoc =
        (await refEvt1.collection('caisses').doc(caisseLea).get(serveur)).data()!;
    expect(caisseDoc['statut'], 'cloturee');
    expect(caisseDoc['nbVentes'], 3);
    expect(caisseDoc['nbAnnulees'], 1);
    expect(caisseDoc['totalCentimes'], 900);
    expect(caisseDoc['parMode'], {'especes': 600, 'carte': 300});
    expect(caisseDoc['clotureLe'], isNotNull);

    // --- Caisse verrouillée : on regarde, on ne vend plus ni n'annule.
    await toucher(tester, find.byKey(const Key('fermer_cloture')));
    await finTransition(tester);
    expect(find.byKey(const Key('caisse_cloturee')), findsOneWidget);
    await toucher(tester, find.text('Café'));
    expect(texte(tester, 'total'), 'Total : 0,00 €');
    expect(find.byKey(const Key('ouvrir_cloture')), findsNothing);
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await attendre(tester, find.text('Mes ventes'));
    await finTransition(tester);
    expect(
        find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('annuler_')),
        findsNothing);
    await retour(tester);

    // --- Le bénévole rouvre sa caisse (vente oubliée), vend, reclôture.
    await toucher(tester, find.byKey(const Key('rouvrir_caisse')));
    for (var i = 0; i < 100 && find.byKey(const Key('caisse_cloturee')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('caisse_cloturee')), findsNothing);
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await vendre(tester, ['Café'], 'carte'); // E : 1,50
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 4 · 10,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await toucher(tester, find.byKey(const Key('ouvrir_cloture')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    expect(texte(tester, 'cloture_total'), 'Ventes : 4 · 10,50 €');
    expect(texte(tester, 'recap_mode_carte'), 'Carte : 4,50 €');
    caisseDoc =
        (await refEvt1.collection('caisses').doc(caisseLea).get(serveur)).data()!;
    expect(caisseDoc['statut'], 'cloturee');
    expect(caisseDoc['nbVentes'], 4);
    expect(caisseDoc['rouverteLe'], isNotNull); // la réouverture est tracée

    // --- Le responsable : événement 2 (aucune caisse) = clôture normale.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_clotures')())!);
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi 2'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi 2'));
    await attendre(tester, find.byKey(const Key('aucune_caisse')));
    await attendre(tester, find.byKey(const Key('cloturer_evenement')));
    await finTransition(tester);
    expect(find.text("Clôturer l'événement"), findsOneWidget);
    await toucher(tester, find.byKey(const Key('cloturer_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    await attendre(tester, find.byKey(const Key('cloture_info')));
    expect(texte(tester, 'cloture_info'), startsWith('Clôturé par Chef le '));
    expect(find.byKey(const Key('cloture_forcee')), findsNothing);
    final e2 = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt2)
            .get(serveur))
        .data()!;
    expect(e2['statut'], 'cloture');
    expect(e2['forcee'], false);
    expect(e2['nbCaissesOuvertes'], 0);
    expect(e2['cloturePar'], chefUid);
    expect(e2['clotureParPrenom'], 'Chef');
    await retour(tester);

    // --- Événement 1 : la caisse du responsable reste ouverte = clôture forcée.
    await caisses1.ouvrirCaisse(caisseChef, 'Chef');
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(Key('caisse_$caisseLea')));
    await attendre(tester, find.byKey(Key('caisse_$caisseChef')));
    await finTransition(tester);
    expect(texte(tester, 'statut_caisse_$caisseLea'), startsWith('Clôturée')); // Lea
    expect(texte(tester, 'statut_caisse_$caisseChef'), startsWith('Ouverte')); // Chef
    expect(find.text('Forcer la clôture'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('cloturer_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    await attendre(tester, find.byKey(const Key('cloture_forcee')));
    expect(texte(tester, 'cloture_forcee'),
        'Clôture forcée : 1 caisse non clôturée. Des ventes peuvent manquer.');
    expect(texte(tester, 'cloture_info'), startsWith('Clôturé par Chef le '));
    final e1 = (await refEvt1.get(serveur)).data()!;
    expect(e1['statut'], 'cloture');
    expect(e1['forcee'], true);
    expect(e1['nbCaissesOuvertes'], 1);

    // --- Événement figé : une vente tardive de la caisse restée ouverte est refusée.
    Object? refus;
    caisses1.enregistrerVente(
      caisseChef,
      [const LigneVente('x', 'Café', 150, 1)],
      'carte',
      stocks: {},
      onErreur: (e) => refus = e,
    );
    for (var i = 0; i < 100 && refus == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(refus, isNotNull);
    expect(
        (await refEvt1.collection('caisses').doc(caisseChef).collection('ventes').get(serveur))
            .docs,
        isEmpty);
  });
}
