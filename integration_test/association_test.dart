import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'outils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets('créer, changer le code, puis rejoindre depuis un autre appareil',
      (tester) async {
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    // --- Appareil 1 : le responsable crée l'association (via Google).
    await ouvrir(tester, 'appareil1', fauxGoogle('chef_asso'));
    await creerAssociationParLInterface(tester);

    expect(texte(tester, 'nom'), 'Club Test');
    final code1 = texte(tester, 'code');
    expect(code1.length, 6);
    // La liste des membres est dans Paramètres : on y vérifie le responsable.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('parametres')));
    await attendre(tester, find.text('Chef'));
    expect(find.text('Responsable'), findsOneWidget);
    // « Changer le code » n'est plus sur l'écran principal : il est dans Paramètres.
    expect(find.byKey(const Key('regenerer')), findsNothing);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(milliseconds: 500));

    // --- Le responsable change le code, depuis Paramètres.
    await tester.tap(find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('regenerer')));
    await tester.pump(const Duration(seconds: 1));
    expect(texte(tester, 'param_code'), code1);
    await tester.tap(find.byKey(const Key('regenerer')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('confirmer_regeneration')));
    for (var i = 0; i < 150 && texte(tester, 'param_code') == code1; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final code2 = texte(tester, 'param_code');
    expect(code2, isNot(code1));
    // De retour sur l'écran principal, le nouveau code est affiché.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(texte(tester, 'code'), code2);
    // Le nouveau code doit être confirmé par le serveur avant de changer d'appareil.
    await FirebaseFirestore.instance.waitForPendingWrites();

    // --- Appareil 2 : un bénévole anonyme (sans Google).
    await auth.signOut();
    await ouvrir(tester, 'appareil2', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));

    // L'ancien code est refusé (saisi en minuscules avec espaces).
    await tester.enterText(
        find.byKey(const Key('code_saisi')), ' ${code1.toLowerCase()} ');
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await tester.tap(find.byKey(const Key('rejoindre')));
    await attendre(tester, find.byKey(const Key('erreur')));
    expect(texte(tester, 'erreur'), 'Code inconnu ou périmé.');
    expect(find.byKey(const Key('code')), findsNothing);

    // Le nouveau code est accepté.
    await tester.enterText(find.byKey(const Key('code_saisi')), code2);
    await tester.tap(find.byKey(const Key('rejoindre')));
    await attendre(tester, find.byKey(const Key('code')));
    expect(texte(tester, 'nom'), 'Club Test');
    expect(texte(tester, 'code'), code2);
    // Un bénévole ne voit pas la liste des membres (Paramètres : droits seulement).
    // Le bouton reste inactif tant que le membre n'est pas chargé : on retente le geste.
    for (var i = 0; i < 60; i++) {
      if (find.byKey(const Key('qui_peut_quoi')).evaluate().isNotEmpty) break;
      if (find.byKey(const Key('parametres')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('parametres')));
      }
      await tester.pump(const Duration(milliseconds: 300));
    }
    await attendre(tester, find.byKey(const Key('qui_peut_quoi')));
    expect(find.text('Chef'), findsNothing);
    expect(find.text('Bénévole'), findsNothing);
    // Un bénévole ne peut pas changer le code, et n'a pas de compte Google.
    expect(find.byKey(const Key('regenerer')), findsNothing);
    expect(auth.currentUser!.isAnonymous, isTrue);
  });
}
