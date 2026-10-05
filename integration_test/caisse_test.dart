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
      if (f.evaluate().isNotEmpty &&
          tester.widget<Text>(f).data == attendu) {
        return;
      }
    }
    final f = find.byKey(Key(cle));
    final actuel =
        f.evaluate().isEmpty ? '(absent)' : tester.widget<Text>(f).data;
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  String total(WidgetTester tester) => texte(tester, 'total');

  testWidgets('caisse : ventes, monnaie, stock, coupure du réseau, reprise',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    // --- Préparation : association, menu, événement (modes : espèces, carte).
    await ouvrir(tester, 'responsable', fauxGoogle('chef_caisse'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 2);
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150);
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
    );
    final gym = await gymnaseUnique(depotEv, evtId);
    final croqueId = (await depotEv.suivreProduits(evtId).first)
        .firstWhere((p) => p.nom == 'Croque-monsieur')
        .id;

    // --- Un bénévole rejoint et ouvre sa caisse.
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
    expect(find.text('Caisse de Lea'), findsOneWidget);
    await attendre(tester, find.text('Stock : 2'));

    // Seuls les modes de l'événement sont proposés.
    expect(find.byKey(const Key('encaisser_especes')), findsOneWidget);
    expect(find.byKey(const Key('encaisser_carte')), findsOneWidget);
    expect(find.byKey(const Key('encaisser_cheque')), findsNothing);
    expect(find.byKey(const Key('encaisser_autre')), findsNothing);

    // --- Vente 1 : 2 croque-monsieur + 1 café, avec la monnaie à rendre.
    await toucher(tester, find.text('Croque-monsieur'));
    await toucher(tester, find.text('Croque-monsieur'));
    await toucher(tester, find.text('Café'));
    expect(total(tester), 'Total : 7,50 €');
    await toucher(tester, find.byKey(const Key('monnaie')));
    await tester.enterText(find.byKey(const Key('somme_recue')), '10');
    await tester.pump();
    expect(texte(tester, 'a_rendre'), 'À rendre : 2,50 €');
    await tester.enterText(find.byKey(const Key('somme_recue')), '5');
    await tester.pump();
    expect(texte(tester, 'a_rendre'), 'Somme insuffisante.');
    await toucher(tester, find.text('Fermer'));
    expect(total(tester), 'Total : 7,50 €'); // rien n'a été validé
    await toucher(tester, find.byKey(const Key('encaisser_especes')));
    expect(total(tester), 'Total : 0,00 €');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 7,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    // Le stock du croque-monsieur est tombé à zéro.
    await attendre(tester, find.text('Épuisé'));

    // --- Vente 2 : stock épuisé, avertissement mais vente possible.
    await toucher(tester, find.text('Croque-monsieur'));
    expect(find.byKey(const Key('alerte_stock')), findsOneWidget);
    expect(total(tester), 'Total : 3,00 €');
    await toucher(tester, find.byKey(const Key('encaisser_carte')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 2 · 10,50 €');
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');

    // --- Côté serveur : ventes et stock sont bien arrivés.
    final serveur = const GetOptions(source: Source.server);
    final refCaisse = db
        .collection('associations')
        .doc(assoId)
        .collection('evenements')
        .doc(evtId);
    var ventes =
        (await refCaisse.collection('caisses').doc(caisseId).collection('ventes').get(serveur))
            .docs
            .map((d) => d.data())
            .toList();
    expect(ventes.length, 2);
    expect(ventes.map((v) => v['mode']).toSet(), {'especes', 'carte'});
    expect(ventes.fold<int>(0, (s, v) => s + (v['totalCentimes'] as int)), 1050);
    expect(
        (await refCaisse
                .collection('gymnases')
                .doc(gym)
                .collection('stocks')
                .doc(croqueId)
                .get(serveur))
            .data()!['quantite'],
        -1);

    // --- Coupure du réseau : les ventes restent sur le téléphone.
    await db.disableNetwork();
    await toucher(tester, find.text('Café'));
    await toucher(tester, find.text('Café'));
    expect(total(tester), 'Total : 3,00 €');
    await toucher(tester, find.byKey(const Key('encaisser_carte')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 13,50 €');
    await attendreTexte(tester, 'envoi_caisse', "En attente d'envoi : 1");
    await toucher(tester, find.text('Café'));
    await toucher(tester, find.text('Croque-monsieur'));
    expect(total(tester), 'Total : 4,50 €');
    await toucher(tester, find.byKey(const Key('encaisser_especes')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 4 · 18,00 €');
    await attendreTexte(tester, 'envoi_caisse', "En attente d'envoi : 2");

    // --- Retour du réseau : tout part tout seul.
    await db.enableNetwork();
    await attendreTexte(tester, 'envoi_caisse', 'Tout est envoyé');
    ventes =
        (await refCaisse.collection('caisses').doc(caisseId).collection('ventes').get(serveur))
            .docs
            .map((d) => d.data())
            .toList();
    expect(ventes.length, 4);
    expect(ventes.fold<int>(0, (s, v) => s + (v['totalCentimes'] as int)), 1800);
    // Le stock cumule les ventes faites hors réseau (-1 puis -1 : -2).
    expect(
        (await refCaisse
                .collection('gymnases')
                .doc(gym)
                .collection('stocks')
                .doc(croqueId)
                .get(serveur))
            .data()!['quantite'],
        -2);

    // --- Fermeture puis réouverture de l'application : la caisse est reprise.
    await ouvrir(tester, 'reouverture', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.text('Reprendre ma caisse'));
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 4 · 18,00 €');
  });
}
