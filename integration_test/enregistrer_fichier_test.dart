// Parcours N2 (T1 « Enregistrer sur le téléphone ») : sur l'émulateur, la feuille de choix
// ouvre le sélecteur Android réel ; le fichier choisi est enregistré, puis relu.
// Le sélecteur système ne se pilote pas depuis le test : il faut le valider à la main
// ou par un pilotage externe (adb), pendant que le test attend son retour.
// Lancement : flutter test integration_test/enregistrer_fichier_test.dart -d emulator-5554
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/partage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enregistrer un fichier via le sélecteur Android et le relire',
      (tester) async {
    const nom = 'comptoir-essai-t1.txt';
    const contenu = 'Le Comptoir : essai d\'enregistrement T1\n';
    String? chemin;

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorCle,
      home: Scaffold(
        body: Builder(
          builder: (contexte) => Center(
            child: ElevatedButton(
              key: const Key('ouvrir'),
              onPressed: () => ouvrirFeuilleRemise(
                contexte,
                nomFichier: nom,
                octets: Uint8List.fromList(utf8.encode(contenu)),
                typeMime: 'text/plain',
                enregistrer: (n, o, m) async => chemin = await enregistrerSysteme(n, o, m),
                partager: partageSysteme,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('ouvrir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choix_enregistrer')));

    // Attend le retour du sélecteur (jusqu'à 4 minutes).
    final confirmation = find.text('Fichier enregistré : $nom');
    for (var i = 0; i < 1200 && confirmation.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(confirmation, findsOneWidget,
        reason: 'Aucune confirmation : sélecteur annulé, non ouvert, ou échec');
    expect(tester.takeException(), isNull);

    // Le sélecteur rend un identifiant de document (pas un chemin lisible par Dart) :
    // la relecture du contenu se fait hors test, par adb sur le dossier Téléchargements.
    expect(chemin, isNotNull);
  });
}
