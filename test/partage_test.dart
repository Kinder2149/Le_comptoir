import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/partage.dart';

/// Pose une page qui ouvre la feuille de choix au toucher d'un bouton.
Future<void> _ouvrir(
  WidgetTester tester, {
  required Enregistreur enregistrer,
  required PartageurOctets partager,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (contexte) => Center(
          child: ElevatedButton(
            key: const Key('ouvrir'),
            onPressed: () => ouvrirFeuilleRemise(
              contexte,
              nomFichier: 'test.xlsx',
              octets: Uint8List.fromList([1, 2, 3]),
              typeMime: 'application/octet-stream',
              enregistrer: enregistrer,
              partager: partager,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('ouvrir')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la feuille propose « Enregistrer sur le téléphone » et « Partager »',
      (tester) async {
    await _ouvrir(
      tester,
      enregistrer: (nom, octets, mime) async => null,
      partager: (nom, octets, mime) async {},
    );
    expect(find.text('Enregistrer sur le téléphone'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
  });

  testWidgets('annuler le choix de dossier ne montre aucune erreur',
      (tester) async {
    var appele = false;
    await _ouvrir(
      tester,
      enregistrer: (nom, octets, mime) async {
        appele = true;
        return null; // la personne ferme le sélecteur sans rien choisir
      },
      partager: (nom, octets, mime) async {},
    );
    await tester.tap(find.byKey(const Key('choix_enregistrer')));
    await tester.pumpAndSettle();
    expect(appele, isTrue);
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('un fichier enregistré confirme son nom', (tester) async {
    Uint8List? recu;
    await _ouvrir(
      tester,
      enregistrer: (nom, octets, mime) async {
        recu = octets;
        return '/stockage/Download/$nom';
      },
      partager: (nom, octets, mime) async {},
    );
    await tester.tap(find.byKey(const Key('choix_enregistrer')));
    await tester.pumpAndSettle();
    expect(recu, Uint8List.fromList([1, 2, 3]));
    expect(find.text('Fichier enregistré : test.xlsx'), findsOneWidget);
  });

  testWidgets('un échec réel montre un message simple', (tester) async {
    await _ouvrir(
      tester,
      enregistrer: (nom, octets, mime) async => throw StateError('disque'),
      partager: (nom, octets, mime) async {},
    );
    await tester.tap(find.byKey(const Key('choix_enregistrer')));
    await tester.pumpAndSettle();
    expect(find.text("Le fichier n'a pas pu être enregistré."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Partager » passe par le partageur, sans enregistrer',
      (tester) async {
    var partage = false;
    var enregistrement = false;
    await _ouvrir(
      tester,
      enregistrer: (nom, octets, mime) async {
        enregistrement = true;
        return null;
      },
      partager: (nom, octets, mime) async {
        partage = true;
      },
    );
    await tester.tap(find.byKey(const Key('choix_partager')));
    await tester.pumpAndSettle();
    expect(partage, isTrue);
    expect(enregistrement, isFalse);
  });
}
