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
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 200; i++) {
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

  Future<void> retour(WidgetTester tester) async {
    // Retour à l'écran précédent (celui du dessus se ferme).
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1)); // l'ancien écran est retiré
  }

  testWidgets('annuler (n\'importe quelle vente), corriger, hors réseau, gestion',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final serveur = const GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : association, menu (croque-monsieur : stock 5), événement.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_annul'));
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
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
    );
    final depotCaisses = depotEv.caisses(evtId);
    final gym = await gymnaseUnique(depotEv, evtId);
    final refEvt =
        db.collection('associations').doc(assoId).collection('evenements').doc(evtId);

    // --- Le bénévole ouvre sa caisse et fait trois ventes.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    final uid = auth.currentUser!.uid;
    final caisseId = idCaisse(uid, gym);
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.text('Ouvrir ma caisse'));
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    // Fin de la transition : l'écran du dessous n'est plus affiché.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.text('Stock : 5'));

    Future<void> vendre(
        List<String> articles, String mode) async {
      for (final a in articles) {
        await toucher(tester, find.text(a));
      }
      await toucher(tester, find.byKey(Key('encaisser_$mode')));
    }

    await vendre(['Croque-monsieur', 'Café'], 'especes'); // A : 4,50
    await vendre(['Café', 'Café'], 'carte'); // B : 3,00
    await vendre(['Croque-monsieur'], 'carte'); // C : 3,00
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 10,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await attendre(tester, find.text('Stock : 3'));

    final ventes = await depotCaisses.suivreVentes(caisseId).first;
    final a = ventes.firstWhere((v) => v.totalCentimes == 450);
    final b = ventes.firstWhere(
        (v) => v.totalCentimes == 300 && v.lignes.first.nom == 'Café');
    final c = ventes.firstWhere(
        (v) => v.totalCentimes == 300 && v.lignes.first.nom == 'Croque-monsieur');
    Future<Map<String, dynamic>> surServeur(String venteId) async => (await refEvt
            .collection('caisses')
            .doc(caisseId)
            .collection('ventes')
            .doc(venteId)
            .get(serveur))
        .data()!;

    // --- Annuler la PREMIÈRE vente (pas la dernière), avec confirmation.
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await attendre(tester, find.byKey(Key('vente_${a.id}')));
    await toucher(tester, find.byKey(Key('annuler_${a.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(Key('trace_${a.id}')));
    expect(
      RegExp(r'^Annulée par Lea à \d{2}:\d{2}$')
          .hasMatch(texte(tester, 'trace_${a.id}')),
      isTrue,
    );
    // La vente annulée reste listée, sans boutons ; les autres gardent les leurs.
    expect(find.byKey(Key('annuler_${a.id}')), findsNothing);
    expect(find.byKey(Key('annuler_${b.id}')), findsOneWidget);
    await retour(tester);
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 6,00 €');
    await attendreTexte(tester, 'annulees_caisse', 'Ventes annulées : 1');
    await attendre(tester, find.text('Stock : 4')); // le croque-monsieur revient
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    var sa = await surServeur(a.id);
    expect(sa['annulee'], isTrue);
    expect(sa['annuleePar'], uid);
    expect(sa['annuleeParPrenom'], 'Lea');
    expect(sa['annuleeLe'], isNotNull);
    expect(sa['totalCentimes'], 450); // le montant d'origine est conservé

    // --- Corriger la vente C : annulée, ses articles reviennent au ticket.
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await toucher(tester, find.byKey(Key('corriger_${c.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(const Key('correction_en_cours')));
    expect(texte(tester, 'total'), 'Total : 3,00 €');
    await toucher(tester, find.text('Café')); // ressaisie : on ajoute un café
    expect(texte(tester, 'total'), 'Total : 4,50 €');
    await toucher(tester, find.byKey(const Key('encaisser_especes')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 7,50 €');
    await attendreTexte(tester, 'annulees_caisse', 'Ventes annulées : 2');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    await attendre(tester, find.text('Stock : 4')); // 5 -2 +1 +1 -1

    final apres = await depotCaisses.suivreVentes(caisseId).first;
    final correction = apres.firstWhere((v) => v.corrigeDe == c.id);
    expect(correction.totalCentimes, 450);
    expect((await surServeur(correction.id))['corrigeDe'], c.id);
    expect((await surServeur(c.id))['annulee'], isTrue);
    // La liste montre le lien entre l'ancienne et la nouvelle vente.
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await attendre(tester, find.byKey(Key('trace_${c.id}')));
    expect(texte(tester, 'trace_${c.id}'), endsWith('· remplacée'));
    expect(find.text('Remplace une vente annulée'), findsOneWidget);
    await retour(tester);

    // --- Annuler sans réseau : tracé sur le téléphone, envoyé au retour du réseau.
    await db.disableNetwork();
    await toucher(tester, find.byKey(const Key('voir_ventes')));
    await toucher(tester, find.byKey(Key('annuler_${b.id}')));
    await toucher(tester, find.byKey(const Key('confirmer_annulation')));
    await attendre(tester, find.byKey(Key('trace_${b.id}')));
    await retour(tester);
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 4,50 €');
    await attendreTexte(tester, 'annulees_caisse', 'Ventes annulées : 3');
    await attendreTexte(tester, 'envoi_caisse', "En attente d'envoi : 1");
    await db.enableNetwork();
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    final sb = await surServeur(b.id);
    expect(sb['annulee'], isTrue);
    expect(sb['annuleeParPrenom'], 'Lea');

    // --- La gestion annule une vente d'une autre caisse, sous son nom.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_annul')())!);
    expect(auth.currentUser!.uid, chefUid);
    final aAnnuler = (await depotCaisses.suivreVentes(caisseId).first)
        .firstWhere((v) => v.id == correction.id);
    depotCaisses.annulerVente(
      caisseId,
      aAnnuler,
      parUid: chefUid,
      parPrenom: 'Chef',
      stocks: {},
    );
    Map<String, dynamic>? sg;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      sg = await surServeur(correction.id);
      if (sg['annulee'] == true) break;
    }
    expect(sg!['annulee'], isTrue);
    expect(sg['annuleePar'], chefUid);
    expect(sg['annuleeParPrenom'], 'Chef');
  });
}
