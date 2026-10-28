import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/theme.dart';

import 'outils.dart';

// Chantier Stock et courses, étape 4 : rupture, stock bas et « vide » en caisse ;
// la vente et la baisse de stock partent ensemble.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
    }
    final f = find.byKey(Key(cle));
    final actuel = f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  Color? fond(WidgetTester tester, String produit) => tester
      .widget<Card>(find.ancestor(
          of: find.byKey(Key('produit_$produit')), matching: find.byType(Card)))
      .color;

  testWidgets('caisse : stock bas, rupture et produit vide', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Préparation : tarte (part, 5), crêpe sans quantité.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_rupture'));
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
        stock: 5,
        fiche: const FicheProduit(type: 'part'));
    await menus.ajouterProduit(menuId, nom: 'Crêpe', prixCentimes: 200);
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
    );
    final gym = await gymnaseUnique(depotEv, evtId);
    final produits = await depotEv.suivreProduits(evtId).first;
    final tarte = produits.firstWhere((p) => p.nom == 'Tarte').id;
    final crepe = produits.firstWhere((p) => p.nom == 'Crêpe').id;

    // Total de référence 50 ; la quantité descend à 7 (comme après des ventes).
    await depotEv.definirStock(evtId, gym, tarte, 50);
    await db
        .collection('associations')
        .doc(assoId)
        .collection('evenements')
        .doc(evtId)
        .collection('gymnases')
        .doc(gym)
        .collection('stocks')
        .doc(tarte)
        .update({'quantite': 7});

    // --- Un bénévole ouvre sa caisse.
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
    await attendreTexte(tester, 'stock_$tarte', 'Stock : 7');
    expect(fond(tester, tarte), isNull);

    Future<void> vendreTarte(int n) async {
      for (var i = 0; i < n; i++) {
        await toucher(tester, find.byKey(Key('produit_$tarte')));
      }
      await toucher(tester, find.byKey(const Key('encaisser_especes')));
    }

    // --- 7 -> 5 : sous 10 % de 50, donc « Stock bas ».
    await vendreTarte(2);
    await attendreTexte(tester, 'stock_$tarte', 'Stock bas : 5');
    expect(fond(tester, tarte), Palette.ocreDoux);

    // --- Jusqu'à zéro, puis une vente de plus : « Épuisé », la vente passe quand même.
    await vendreTarte(5);
    await attendreTexte(tester, 'stock_$tarte', 'Épuisé');
    expect(fond(tester, tarte), Palette.briqueDoux);
    await vendreTarte(1);
    await attendreTexte(tester, 'stock_$tarte', 'Épuisé');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 20,00 €');

    // --- Produit sans quantité : « Vide » quand il est signalé, normal sinon.
    expect(find.byKey(Key('stock_$crepe')), findsNothing);
    await toucher(tester, find.byKey(const Key('ouvrir_stock')));
    await toucher(tester, find.byKey(Key('vide_$crepe')));
    await toucher(tester, find.byKey(const Key('fermer_stock')));
    await attendreTexte(tester, 'stock_$crepe', 'Vide');
    expect(fond(tester, crepe), Palette.briqueDoux);
    await toucher(tester, find.byKey(const Key('ouvrir_stock')));
    await toucher(tester, find.byKey(Key('vide_$crepe')));
    await toucher(tester, find.byKey(const Key('fermer_stock')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(Key('stock_$crepe')), findsNothing);
    expect(fond(tester, crepe), isNull);

    // --- Côté serveur : 8 parts vendues (7 + une en rupture), stock à -1.
    final stock = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('gymnases')
            .doc(gym)
            .collection('stocks')
            .doc(tarte)
            .get(serveur))
        .data()!;
    expect(stock['quantite'], -1);
  });
}
