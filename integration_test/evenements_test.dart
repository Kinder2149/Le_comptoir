import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/evenement.dart';

import 'outils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  /// Les listes ne construisent que ce qui est visible : on défile (vers le
  /// bas, puis vers le haut) jusqu'à trouver l'élément.
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
    // Le formulaire se met encore en page (liste de menus qui se charge) : on laisse faire,
    // puis on recadre le bouton avant d'appuyer.
    await tester.pump(const Duration(milliseconds: 500));
    await montrer(tester, cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saisir(WidgetTester tester, String cle, String valeur) async {
    await montrer(tester, find.byKey(Key(cle)));
    await tester.enterText(find.byKey(Key(cle)), valeur);
    await tester.pump();
  }

  Future<void> laisserArriver(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('événements : créer avec copie du menu, modifier, vue bénévole',
      (tester) async {
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await ouvrir(tester, 'responsable', fauxGoogle('chef_evenements'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');

    // --- Préparation : deux menus (un rempli, un vide), via la couche Données.
    final uid = auth.currentUser!.uid;
    final assoId = (await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get())
        .data()!['assoId'] as String;
    final menus = DepotAssociations(FirebaseFirestore.instance).menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    final menuVideId = await menus.creerMenu('Menu Vide');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur', prixCentimes: 300, stock: 20);
    await menus.ajouterProduit(menuId, nom: 'Café', prixCentimes: 150);
    final produitCroque =
        (await menus.suivreProduits(menuId).first).firstWhere((p) => p.nom == 'Croque-monsieur');

    await attendre(tester, find.byKey(const Key('aucun_evenement')));
    await attendre(tester, find.byKey(const Key('nouvel_evenement')));

    // --- Formulaire : contrôles de saisie.
    await toucher(tester, find.byKey(const Key('nouvel_evenement')));
    await attendre(tester, find.byKey(Key('choix_menu_$menuId')));
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await montrer(tester, find.byKey(const Key('erreur_evenement')));
    expect(texte(tester, 'erreur_evenement'), "Donnez un nom à l'événement.");

    await saisir(tester, 'nom_evenement', 'Tournoi du week-end');
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await montrer(tester, find.byKey(const Key('erreur_evenement')));
    expect(texte(tester, 'erreur_evenement'), 'Choisissez un menu.');

    await toucher(tester, find.byKey(Key('choix_menu_$menuVideId')));
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await montrer(tester, find.byKey(const Key('erreur_evenement')));
    expect(texte(tester, 'erreur_evenement'), 'Ce menu ne contient aucun produit.');

    // Espèces est coché par défaut : on le décoche, puis plus aucun mode.
    await toucher(tester, find.byKey(const Key('mode_especes')));
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await montrer(tester, find.byKey(const Key('erreur_evenement')));
    expect(texte(tester, 'erreur_evenement'),
        'Choisissez au moins un mode de paiement.');

    // --- Création valide : menu rempli, Espèces + Carte.
    await toucher(tester, find.byKey(Key('choix_menu_$menuId')));
    await toucher(tester, find.byKey(const Key('mode_especes')));
    await toucher(tester, find.byKey(const Key('mode_carte')));
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await attendre(tester, find.byKey(const Key('nouvel_evenement')));
    await tester.pump(const Duration(seconds: 1)); // fin de l'animation de retour
    await attendre(tester, find.text('Tournoi du week-end'));
    expect(find.byKey(const Key('aucun_evenement')), findsNothing);
    final aujourdhui = dateAffichee(dateIso(DateTime.now()));
    expect(find.text('$aujourdhui · Espèces, Carte'), findsOneWidget);

    // --- Détail : produits copiés avec leurs prix.
    await toucher(tester, find.text('Tournoi du week-end'));
    await attendre(tester, find.byKey(const Key('titre_evenement')));
    expect(texte(tester, 'menu_evenement'), 'Menu : Menu Tournoi');
    expect(texte(tester, 'modes_evenement'), 'Paiements : Espèces, Carte');
    expect(texte(tester, 'date_evenement'), 'Date : $aujourdhui');
    await attendre(tester, find.text('3,00 € · Stock : 20'));
    expect(find.text('Croque-monsieur'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('1,50 €'), findsOneWidget);

    // --- Un gymnase « Principal » a été créé avec l'événement ; le stock du menu
    // est son stock de départ (et les produits eux-mêmes n'ont plus de stock).
    final serveur = const GetOptions(source: Source.server);
    final refEvt = FirebaseFirestore.instance
        .collection('associations')
        .doc(assoId)
        .collection('evenements');
    final evtId = (await refEvt.get(serveur)).docs.single.id;
    final gymnases = await refEvt.doc(evtId).collection('gymnases').get(serveur);
    expect(gymnases.docs.length, 1);
    expect(gymnases.docs.single.data()['nom'], 'Principal');
    final stocksGym =
        await gymnases.docs.single.reference.collection('stocks').get(serveur);
    expect(stocksGym.docs.length, 1); // seul le croque-monsieur est suivi
    expect(stocksGym.docs.single.data()['quantite'], 20);
    for (final p in (await refEvt.doc(evtId).collection('produits').get(serveur)).docs) {
      expect(p.data().containsKey('stock'), isFalse);
    }

    // --- Le menu d'origine change : l'événement garde ses prix.
    await menus.modifierProduit(menuId, produitCroque.id,
        nom: 'Croque-monsieur', prixCentimes: 500, stock: 20);
    await laisserArriver(tester);
    expect(find.text('3,00 € · Stock : 20'), findsOneWidget);
    expect(find.text('5,00 € · Stock : 20'), findsNothing);

    // --- Modification : nom et modes (le menu n'est pas modifiable).
    await toucher(tester, find.byKey(const Key('modifier_evenement')));
    await attendre(tester, find.byKey(const Key('valider_evenement')));
    expect(find.byKey(Key('choix_menu_$menuId')), findsNothing);
    await saisir(tester, 'nom_evenement', "Tournoi d'automne");
    await toucher(tester, find.byKey(const Key('mode_carte')));
    await toucher(tester, find.byKey(const Key('mode_cheque')));
    await toucher(tester, find.byKey(const Key('valider_evenement')));
    await attendre(tester, find.byKey(const Key('modifier_evenement')));
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.text("Tournoi d'automne"));
    await attendre(tester, find.text('Paiements : Espèces, Chèque'));

    // --- Un bénévole : voit l'événement en cours et ses produits, rien d'autre.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await saisir(tester, 'code_saisi', code);
    await saisir(tester, 'prenom_rejoindre', 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Membres (2)'));
    await attendre(tester, find.text("Tournoi d'automne"));
    expect(find.byKey(const Key('nouvel_evenement')), findsNothing);
    expect(find.byKey(const Key('menus')), findsNothing);
    await toucher(tester, find.text("Tournoi d'automne"));
    await attendre(tester, find.byKey(const Key('titre_evenement')));
    await attendre(tester, find.text('3,00 € · Stock : 20'));
    expect(find.text('Café'), findsOneWidget);
    expect(find.byKey(const Key('modifier_evenement')), findsNothing);
    expect(find.byKey(const Key('ancien_evenement')), findsNothing);

    // --- Un événement de l'ancien format (sans gymnase) : message clair, pas de
    // plantage, pas de caisse.
    expect(
        await restEcrire('PATCH', 'associations/$assoId/evenements/ancien', 'owner', {
          'nom': restTexte('Ancien tournoi'),
          'date': restTexte(dateIso(DateTime.now())),
          'statut': restTexte('en_cours'),
          'modes': {
            'arrayValue': {
              'values': [restTexte('especes')]
            }
          },
          'menuNom': restTexte('Menu'),
          'creeLe': restTs(DateTime.now()),
        }),
        200);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(seconds: 1));
    await attendre(tester, find.text('Ancien tournoi'));
    await toucher(tester, find.text('Ancien tournoi'));
    await attendre(tester, find.byKey(const Key('ancien_evenement')));
    expect(find.byKey(const Key('ouvrir_caisse_evenement')), findsNothing);
  });
}
