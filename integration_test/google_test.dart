import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/connexion.dart';

import 'outils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets('fenêtre Google fermée : rien n\'est créé', (tester) async {
    await FirebaseAuth.instance.signOut();
    await ouvrir(tester, 'annule', googleAnnule);
    await attendre(tester, find.byKey(const Key('creer')));
    await tester.enterText(
        find.byKey(const Key('nom_association')), 'Club Fantôme');
    await tester.enterText(find.byKey(const Key('prenom_creation')), 'Chef');
    await tester.tap(find.byKey(const Key('creer')));
    await attendre(tester, find.byKey(const Key('erreur')));
    expect(texte(tester, 'erreur'), 'Connexion Google annulée.');
    expect(find.byKey(const Key('code')), findsNothing);
    expect(FirebaseAuth.instance.currentUser!.isAnonymous, isTrue);
  });

  testWidgets('créer rattache Google à l\'appareil, qu\'on retrouve ensuite',
      (tester) async {
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    // Création : l'identifiant anonyme devient un compte Google (même uid).
    await ouvrir(tester, 'creation', fauxGoogle('responsable_retrouve'));
    await attendre(tester, find.byKey(const Key('creer')));
    final uidAvant = auth.currentUser!.uid;
    expect(aGoogle(auth.currentUser), isFalse);
    await creerAssociationParLInterface(tester, nom: 'Club Retrouvé');
    expect(auth.currentUser!.uid, uidAvant);
    expect(aGoogle(auth.currentUser), isTrue);
    await attendre(tester, find.text('Responsable'));
    final code = texte(tester, 'code');

    // Nouveau téléphone : appareil neuf (nouvel anonyme) + même compte Google.
    await auth.signOut();
    await ouvrir(tester, 'nouveau_telephone',
        fauxGoogle('responsable_retrouve'));
    await attendre(tester, find.byKey(const Key('retrouver')));
    expect(auth.currentUser!.uid, isNot(uidAvant));
    await tester.tap(find.byKey(const Key('retrouver')));
    await attendre(tester, find.byKey(const Key('code')));

    expect(auth.currentUser!.uid, uidAvant);
    expect(texte(tester, 'nom'), 'Club Retrouvé');
    expect(texte(tester, 'code'), code);
    await attendre(tester, find.text('Responsable'));
    // Le responsable retrouvé a bien ses outils : Paramètres propose « Changer le code ».
    await tester.tap(find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('regenerer')));
  });
}
