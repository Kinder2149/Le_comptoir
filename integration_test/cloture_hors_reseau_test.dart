import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/evenement.dart';

import 'package:le_comptoir/gymnase.dart';
import 'outils.dart';

// La coupure du réseau est simulée dans l'application (disableNetwork). Ce
// scénario reste dans son propre fichier : après une coupure, l'émulateur local
// renvoie parfois des erreurs internes sur les documents concernés, ce qui
// fausserait les autres parcours (clotures_test.dart).
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

  Future<void> vendre(
      WidgetTester tester, List<String> articles, String mode) async {
    for (final a in articles) {
      await toucher(tester, find.text(a));
    }
    await toucher(tester, find.byKey(Key('encaisser_$mode')));
  }

  testWidgets('clôture sans réseau : elle attend l\'envoi final des ventes',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : association, menu, événement.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_hors_reseau'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menuId = await depotAsso.menus(assoId).creerMenu('Menu Tournoi');
    await depotAsso.menus(assoId).ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300);
    await depotAsso.menus(assoId).ajouterProduit(menuId,
        nom: 'Café', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
    );
    final gym = await gymnaseUnique(depotEv, evt);
    final refEvt =
        db.collection('associations').doc(assoId).collection('evenements').doc(evt);

    // --- Lea ouvre sa caisse et fait deux ventes en ligne.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    final leaUid = auth.currentUser!.uid;
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.text('Ouvrir ma caisse'));
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    await vendre(tester, ['Croque-monsieur', 'Café'], 'especes'); // A : 4,50
    await vendre(tester, ['Café', 'Café'], 'carte'); // B : 3,00
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 7,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');

    // --- Sans réseau : une vente reste sur le téléphone ; la clôture attend.
    await db.disableNetwork();
    await vendre(tester, ['Café'], 'especes'); // D : 1,50
    await attendreTexte(tester, 'envoi_caisse', "En attente d'envoi : 1");
    await toucher(tester, find.byKey(const Key('ouvrir_cloture')));
    await attendre(tester, find.byKey(const Key('cloturer_caisse')));
    await finTransition(tester);
    expect(texte(tester, 'cloture_attente'),
        "1 vente en attente d'envoi : la clôture attend le réseau.");
    expect(texte(tester, 'cloture_total'), 'Ventes : 3 · 9,00 €');
    await toucher(tester, find.byKey(const Key('cloturer_caisse')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('cloture_envoi')), findsOneWidget);
    expect(find.byKey(const Key('cloture_ok')), findsNothing); // pas confirmée sans réseau

    // --- Retour du réseau : envoi final, puis clôture confirmée.
    await db.enableNetwork();
    await attendre(tester, find.byKey(const Key('cloture_ok')));
    expect(texte(tester, 'cloture_total'), 'Ventes : 3 · 9,00 €');
    expect(texte(tester, 'recap_mode_especes'), 'Espèces : 6,00 €');
    expect(texte(tester, 'recap_mode_carte'), 'Carte : 3,00 €');
    expect(texte(tester, 'a_remettre'), 'Espèces à remettre : 6,00 €');
    // Côté serveur : la vente faite hors réseau est arrivée AVANT la clôture.
    final ventes = await refEvt
        .collection('caisses')
        .doc(idCaisse(leaUid, gym))
        .collection('ventes')
        .get(serveur);
    expect(ventes.docs.length, 3);
    final caisse =
        (await refEvt.collection('caisses').doc(idCaisse(leaUid, gym)).get(serveur)).data()!;
    expect(caisse['statut'], 'cloturee');
    expect(caisse['nbVentes'], 3);
    expect(caisse['totalCentimes'], 900);
    expect(caisse['parMode'], {'especes': 600, 'carte': 300});
  });
}
