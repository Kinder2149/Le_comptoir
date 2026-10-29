import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';

import 'outils.dart';

// Chantier Stock et courses, étape 3 : un bénévole ajoute des parts et signale un
// produit vide depuis sa caisse ; la gestion règle le total de référence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('stock par rôle : ajout de parts et produit vide depuis la caisse',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : une tarte (part, 5), un croque (unité, 10), une crêpe sans quantité.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_stock_role'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Tarte',
        prixCentimes: 250,
        fiche: const FicheProduit(type: 'part'));
    await menus.ajouterProduit(menuId, nom: 'Croque', prixCentimes: 300);
    await menus.ajouterProduit(menuId, nom: 'Crêpe', prixCentimes: 200);
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
    );
    await donnerStock(depotEv, evtId, 'Tarte', 5);
    await donnerStock(depotEv, evtId, 'Croque', 10);
    final gym = await gymnaseUnique(depotEv, evtId);
    final produits = await depotEv.suivreProduits(evtId).first;
    final tarte = produits.firstWhere((p) => p.nom == 'Tarte').id;
    final croque = produits.firstWhere((p) => p.nom == 'Croque').id;
    final crepe = produits.firstWhere((p) => p.nom == 'Crêpe').id;

    Future<Map<String, dynamic>?> stock(String p) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('gymnases')
            .doc(gym)
            .collection('stocks')
            .doc(p)
            .get(serveur))
        .data();

    // Le stock de départ porte déjà son total de référence.
    expect((await stock(tarte))!['quantite'], 5);
    expect((await stock(tarte))!['reference'], 5);

    // --- La gestion règle un total : la référence le suit.
    await depotEv.definirStock(evtId, gym, croque, 30);
    expect((await stock(croque))!['reference'], 30);
    await depotEv.reapprovisionner(evtId, gym, croque, 5);
    final croqueApres = (await stock(croque))!;
    expect(croqueApres['quantite'], 35);
    expect(croqueApres['reference'], 35);

    // --- Un bénévole rejoint et ouvre sa caisse.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.text('Ouvrir ma caisse'));
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.text('Stock : 5'));

    // --- Écran « Stock » : seule la tarte (part) permet d'ajouter ; la crêpe se signale vide.
    await toucher(tester, find.byKey(const Key('ouvrir_stock')));
    await attendre(tester, find.byKey(Key('ajout_parts_$tarte')));
    expect(find.byKey(Key('ajout_parts_$croque')), findsNothing);
    expect(find.byKey(Key('vide_$crepe')), findsOneWidget);
    expect(find.byKey(Key('vide_$croque')), findsNothing);

    await toucher(tester, find.byKey(Key('ajout_parts_$tarte')));
    await tester.enterText(find.byKey(const Key('saisie_parts')), '0');
    await toucher(tester, find.byKey(const Key('valider_parts')));
    expect(find.text('Entrez un nombre entier de 1 à 1000.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('saisie_parts')), '6');
    await toucher(tester, find.byKey(const Key('valider_parts')));
    await attendre(tester, find.text('Stock : 11'));

    await toucher(tester, find.byKey(Key('vide_$crepe')));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await toucher(tester, find.byKey(const Key('fermer_stock')));

    // --- Côté serveur : quantité et référence ont monté ensemble ; la crêpe est vide ; le croque n'a pas bougé.
    final apres = (await stock(tarte))!;
    expect(apres['quantite'], 11);
    expect(apres['reference'], 11);
    expect((await stock(croque))!['quantite'], 35);
    expect((await depotEv.suivreVides(evtId, gym).first), {crepe});

    // --- Le bénévole retire le signal « vide ».
    await depotEv.signalerVide(evtId, gym, crepe, false);
    expect((await depotEv.suivreVides(evtId, gym).first), isEmpty);
  });
}
