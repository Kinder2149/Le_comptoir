import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_caisse.dart';
import 'package:le_comptoir/ticket.dart';

// Un vrai PNG de 1 pixel (67 octets).
final pngMinuscule = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  group('icônes modèles', () {
    test('chaque clé a son illustration, et inversement', () {
      expect(iconesModeles.keys.toSet(), cleIcones.toSet());
      expect(cleIcones.toSet().length, cleIcones.length); // pas de doublon
    });

    test('les règles d\'accès imposent EXACTEMENT la même liste', () {
      final regles = File('firestore.rules').readAsStringSync();
      final bloc = RegExp(r"d\.icone in \[([^\]]*)\]").firstMatch(regles);
      expect(bloc, isNotNull, reason: 'liste des icônes introuvable dans les règles');
      final clesRegles = RegExp(r"'([a-z_]+)'")
          .allMatches(bloc!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      expect(clesRegles, cleIcones.toSet());
    });

    test('la taille maximale de photo est la même que dans les règles', () {
      final regles = File('firestore.rules').readAsStringSync();
      expect(regles, contains('d.photo.size() <= $tailleMaxPhoto'));
    });

    test('icône inconnue ou absente : icône générique', () {
      expect(iconeDe(null), Icons.restaurant);
      expect(iconeDe('nexistepas'), Icons.restaurant);
      expect(iconeDe('cafe'), Icons.coffee);
      expect(iconeDe('crepe'), Icons.breakfast_dining);
    });
  });

  group('menu type', () {
    test('le fichier fourni est valide et complet', () {
      final modele =
          lireMenuType(File('assets/menu_type.json').readAsStringSync());
      expect(modele.length, 10);
      expect(modele.map((p) => p.nom).toSet().length, 10); // noms distincts
      expect(
          modele.map((p) => p.nom),
          containsAll([
            'Croque-monsieur', 'Salade', 'Fruit', 'Thé', 'Café',
            'Barre chocolatée', 'Soda', 'Part de gâteau sucrée',
            'Part de gâteau salée', 'Crêpe',
          ]));
      // Tous les produits ont une icône valide et un prix raisonnable.
      for (final p in modele) {
        expect(cleIcones, contains(p.icone), reason: p.nom);
        expect(p.prixCentimes, inInclusiveRange(0, 100000), reason: p.nom);
      }
    });

    test('accepte un produit sans icône', () {
      final m = lireMenuType('[{"nom":"Eau","prixCentimes":50}]');
      expect(m.single.nom, 'Eau');
      expect(m.single.icone, isNull);
    });

    test('refuse ce que les règles refuseraient', () {
      for (final faux in [
        '[]',
        '{}',
        'pas du json',
        '[{"nom":"","prixCentimes":100}]',
        '[{"nom":"${'x' * 41}","prixCentimes":100}]',
        '[{"nom":"A","prixCentimes":-1}]',
        '[{"nom":"A","prixCentimes":100001}]',
        '[{"nom":"A","prixCentimes":"3"}]',
        '[{"nom":"A","prixCentimes":2.5}]',
        '[{"nom":"A","prixCentimes":100,"icone":"licorne"}]',
        '[{"prixCentimes":100}]',
        '["texte"]',
      ]) {
        expect(() => lireMenuType(faux), throwsFormatException, reason: faux);
      }
    });
  });

  group('vignette de produit', () {
    Future<void> afficher(WidgetTester tester, Widget w) => tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: w))));

    testWidgets('sans photo : l\'icône du produit', (tester) async {
      await afficher(tester, const VignetteProduit(icone: 'cafe'));
      expect(find.byIcon(Icons.coffee), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('icône absente : icône générique', (tester) async {
      await afficher(tester, const VignetteProduit());
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('avec photo : l\'image, pas l\'icône', (tester) async {
      await afficher(
          tester, VignetteProduit(icone: 'cafe', photo: pngMinuscule, taille: 48));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.coffee), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 48);
      expect(image.height, 48);
    });

    testWidgets('photo illisible : retour à l\'icône, sans planter', (tester) async {
      await afficher(
          tester,
          VignetteProduit(
              icone: 'cafe', photo: Uint8List.fromList([1, 2, 3, 4, 5])));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.coffee), findsOneWidget);
    });
  });

  group('caisse avec images', () {
    testWidgets('chaque tuile affiche sa photo ou son icône', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranCaisse(produits: [
          Produit('a', 'Avec photo', 300, null, 'croque', pngMinuscule),
          const Produit('b', 'Avec icône', 150, null, 'cafe'),
          const Produit('c', 'Sans rien', 100),
          // Démo : l'identifiant sert d'icône quand aucune n'est choisie.
          const Produit('soda', 'Soda démo', 150),
        ]),
      ));
      expect(find.byKey(const Key('vignette_a')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('produit_a')), matching: find.byType(Image)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('produit_b')),
              matching: find.byIcon(Icons.coffee)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('produit_c')),
              matching: find.byIcon(Icons.restaurant)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('produit_soda')),
              matching: find.byIcon(Icons.local_drink)),
          findsOneWidget);
    });

    test('un produit est toujours identifié par son id, photo ou pas', () {
      final sans = const Produit('x', 'X', 100);
      final avec = Produit('x', 'X', 100, 5, 'cafe', pngMinuscule);
      expect(sans == avec, isTrue);
      expect(avec.photo, isNotNull);
      expect(avec.icone, 'cafe');
    });
  });
}
