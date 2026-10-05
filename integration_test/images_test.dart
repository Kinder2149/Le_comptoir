import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/evenement.dart';

import 'outils.dart';

// Un vrai PNG de 1 pixel (67 octets), utilisé comme « photo choisie ».
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('images : menu type, icône, photo, copie à l\'événement, caisse, hors réseau',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // La « photo choisie » par le faux sélecteur (modifiable d'une étape à l'autre).
    Uint8List? aRenvoyer = _png;
    Future<Uint8List?> faux(source) async => aRenvoyer;

    // --- Le responsable crée l'association puis un menu depuis le menu type.
    await ouvrir(tester, 'chef', fauxGoogle('chef_images'), selecteurPhoto: faux);
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);

    await attendre(tester, find.byKey(const Key('menus')));
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.byKey(const Key('nouveau_menu')));
    await toucher(tester, find.byKey(const Key('nouveau_menu')));
    await tester.enterText(find.byKey(const Key('nom_menu')), 'Menu Tournoi');
    await toucher(tester, find.byKey(const Key('menu_type'))); // partir du menu type
    await toucher(tester, find.byKey(const Key('valider_nom')));
    await attendre(tester, find.text('Menu Tournoi'));
    await finTransition(tester);
    final menu = (await menus.suivreMenus().first).single;
    for (var i = 0; i < 100 && (await menus.suivreProduits(menu.id).first).length < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    var produits = await menus.suivreProduits(menu.id).first;
    expect(produits.length, 10);
    expect(produits.map((p) => p.nom),
        containsAll(['Croque-monsieur', 'Thé', 'Café', 'Crêpe', 'Soda']));
    expect(produits.every((p) => p.icone != null && p.photo == null), isTrue);
    expect(produits.firstWhere((p) => p.nom == 'Thé').icone, 'the');
    // Côté serveur aussi, avec leurs icônes.
    final serveurProduits = await db
        .collection('associations')
        .doc(assoId)
        .collection('menus')
        .doc(menu.id)
        .collection('produits')
        .get(serveur);
    expect(serveurProduits.docs.length, 10);
    expect(serveurProduits.docs.every((d) => d.data()['icone'] != null), isTrue);

    // --- Dans le menu : la vignette de chaque produit est son icône.
    await toucher(tester, find.text('Menu Tournoi'));
    await attendre(tester, find.byKey(const Key('nouveau_produit')));
    await finTransition(tester);
    final cafe = produits.firstWhere((p) => p.nom == 'Café');
    expect(
        find.descendant(
            of: find.byKey(Key('produit_${cafe.id}')),
            matching: find.byIcon(Icons.coffee)),
        findsOneWidget);

    // --- Changer l'icône du café et lui ajouter une photo.
    await toucher(tester, find.byKey(Key('produit_${cafe.id}')));
    await attendre(tester, find.byKey(const Key('ajouter_photo')));
    await toucher(tester, find.byKey(const Key('icone_the')));
    await toucher(tester, find.byKey(const Key('ajouter_photo')));
    await toucher(tester, find.byKey(const Key('photo_galerie')));
    await attendre(tester, find.byKey(const Key('retirer_photo')));
    expect(find.text('Changer la photo'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('valider_produit')));
    await finTransition(tester);
    produits = await menus.suivreProduits(menu.id).first;
    final cafeApres = produits.firstWhere((p) => p.id == cafe.id);
    expect(cafeApres.icone, 'the');
    expect(cafeApres.photo, _png);
    final docCafe = (await db
            .collection('associations')
            .doc(assoId)
            .collection('menus')
            .doc(menu.id)
            .collection('produits')
            .doc(cafe.id)
            .get(serveur))
        .data()!;
    expect((docCafe['photo'] as Blob).bytes, _png);
    expect(docCafe['icone'], 'the');
    // La liste affiche maintenant la photo (plus l'icône).
    expect(
        find.descendant(
            of: find.byKey(Key('produit_${cafe.id}')), matching: find.byType(Image)),
        findsOneWidget);

    // --- Photo trop lourde : refusée avec un message, rien n'est enregistré.
    final soda = produits.firstWhere((p) => p.nom == 'Soda');
    aRenvoyer = Uint8List(40000);
    await toucher(tester, find.byKey(Key('produit_${soda.id}')));
    await attendre(tester, find.byKey(const Key('ajouter_photo')));
    await toucher(tester, find.byKey(const Key('ajouter_photo')));
    await toucher(tester, find.byKey(const Key('photo_galerie')));
    await attendre(tester, find.byKey(const Key('erreur_produit')));
    expect(texte(tester, 'erreur_produit'), 'Photo trop lourde. Choisissez-en une autre.');
    expect(find.byKey(const Key('retirer_photo')), findsNothing);
    await toucher(tester, find.text('Annuler'));
    await finTransition(tester);
    expect((await menus.suivreProduits(menu.id).first).firstWhere((p) => p.id == soda.id).photo,
        isNull);

    // --- Ajouter puis retirer une photo (soda).
    aRenvoyer = _png;
    await toucher(tester, find.byKey(Key('produit_${soda.id}')));
    await attendre(tester, find.byKey(const Key('ajouter_photo')));
    await toucher(tester, find.byKey(const Key('ajouter_photo')));
    await toucher(tester, find.byKey(const Key('photo_galerie')));
    await attendre(tester, find.byKey(const Key('retirer_photo')));
    await toucher(tester, find.byKey(const Key('valider_produit')));
    await finTransition(tester);
    expect((await menus.suivreProduits(menu.id).first).firstWhere((p) => p.id == soda.id).photo, _png);
    await toucher(tester, find.byKey(Key('produit_${soda.id}')));
    await attendre(tester, find.byKey(const Key('retirer_photo')));
    await toucher(tester, find.byKey(const Key('retirer_photo')));
    expect(find.byKey(const Key('retirer_photo')), findsNothing);
    await toucher(tester, find.byKey(const Key('valider_produit')));
    await finTransition(tester);
    expect((await menus.suivreProduits(menu.id).first).firstWhere((p) => p.id == soda.id).photo, isNull);
    expect((await menus.suivreProduits(menu.id).first).firstWhere((p) => p.id == soda.id).icone, 'soda');

    // --- Un événement copie les images avec les produits.
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menu.id,
      modes: ['carte'],
    );
    final copies = await depotEv.suivreProduits(evt).first;
    final cafeEvt = copies.firstWhere((p) => p.nom == 'Café');
    final croqueEvt = copies.firstWhere((p) => p.nom == 'Croque-monsieur');
    expect(cafeEvt.photo, _png);
    expect(cafeEvt.icone, 'the');
    expect(croqueEvt.photo, isNull);
    expect(croqueEvt.icone, 'croque');
    final copieServeur = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt)
            .collection('produits')
            .doc(cafeEvt.id)
            .get(serveur))
        .data()!;
    expect((copieServeur['photo'] as Blob).bytes, _png);

    // --- Un bénévole voit les images dans sa caisse.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
        email: 'lea.images@test.fr', password: 'secret12');
    await depotAsso.rejoindre(
        uid: auth.currentUser!.uid, codeSaisi: code, prenom: 'Lea');

    Future<void> ouvrirLaCaisse(String cle) async {
      await ouvrir(tester, cle, googleAnnule);
      await attendre(tester, find.text('Tournoi'));
      await finTransition(tester);
      await toucher(tester, find.text('Tournoi'));
      await attendre(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
      await finTransition(tester);
      await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
      await attendre(tester, find.byKey(Key('produit_${cafeEvt.id}')));
      await finTransition(tester);
    }

    void verifierVignettes() {
      expect(
          find.descendant(
              of: find.byKey(Key('produit_${cafeEvt.id}')),
              matching: find.byType(Image)),
          findsOneWidget); // le café : sa photo
      expect(
          find.descendant(
              of: find.byKey(Key('produit_${croqueEvt.id}')),
              matching: find.byIcon(Icons.lunch_dining)),
          findsOneWidget); // le croque-monsieur : son icône
      expect(
          find.descendant(
              of: find.byKey(Key('produit_${croqueEvt.id}')),
              matching: find.byType(Image)),
          findsNothing);
    }

    await ouvrirLaCaisse('benevole1');
    verifierVignettes();

    // --- Hors réseau : la photo reste affichée (elle est dans la base du téléphone).
    await db.disableNetwork();
    await tester.pumpWidget(const SizedBox());
    await ouvrirLaCaisse('benevole2');
    verifierVignettes();
    await db.enableNetwork();
  });
}
