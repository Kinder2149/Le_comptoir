import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'outils.dart';

// Léa est un compte e-mail créé par le test (pas Google, pas anonyme) : on peut
// donc se reconnecter à son compte après avoir changé d'utilisateur.
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

  Future<void> attendreTexte(
      WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) {
        return;
      }
    }
    final f = find.byKey(Key(cle));
    final actuel =
        f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  Future<void> changerDeSession(
      WidgetTester tester, Future<void> Function() connexion) async {
    await tester.pumpWidget(const SizedBox());
    await FirebaseAuth.instance.signOut();
    await connexion();
  }

  testWidgets('gestionnaires : nommer, activer avec Google, retirer',
      (tester) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();

    // --- Le responsable crée l'association.
    await ouvrir(tester, 'chef1', fauxGoogle('chef_membres'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    DocumentReference<Map<String, dynamic>> refLea(String uid) =>
        db.collection('associations').doc(assoId).collection('membres').doc(uid);

    // --- Léa rejoint comme bénévole : rien à gérer, pas de pastille.
    await changerDeSession(tester, () async {
      await auth.createUserWithEmailAndPassword(
          email: 'lea@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'lea1', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.text('Membres (2)'));
    final leaUid = auth.currentUser!.uid;
    expect(find.text('+1'), findsNothing);
    expect(find.byKey(const Key('menus')), findsNothing);
    expect(find.byKey(Key('nommer_$leaUid')), findsNothing); // pas son rôle
    await toucher(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('mon_statut')));
    expect(texte(tester, 'mon_statut'), 'Statut : Bénévole');
    expect(texte(tester, 'ma_connexion'), 'Connexion Google : non');
    expect(find.byKey(const Key('activer_gestionnaire')), findsNothing);

    // --- Le responsable nomme Léa : « en attente ».
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_membres')())!);
    });
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef2', googleAnnule);
    await attendre(tester, find.byKey(Key('nommer_$leaUid')));
    await finTransition(tester);
    expect(texte(tester, 'statut_$leaUid'), 'Bénévole');
    expect(find.byKey(Key('nommer_$chefUid')), findsNothing); // pas sur soi
    expect(find.byKey(Key('retirer_$chefUid')), findsNothing);
    await toucher(tester, find.byKey(Key('nommer_$leaUid')));
    await attendreTexte(tester, 'statut_$leaUid', 'Gestionnaire en attente');
    expect(find.byKey(Key('nommer_$leaUid')), findsNothing);
    expect(find.byKey(Key('retirer_$leaUid')), findsOneWidget);
    // Côté serveur : elle reste bénévole tant qu'elle n'a pas activé.
    var doc = (await refLea(leaUid).get(serveur)).data()!;
    expect(doc['role'], 'benevole');
    expect(doc['nomme'], true);

    // --- Léa voit la pastille « +1 », sans droits de gestion pour l'instant.
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'lea@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'lea2', fauxGoogle('lea_google'));
    await attendre(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.text('+1'));
    expect(find.byKey(const Key('menus')), findsNothing);
    expect(find.byKey(const Key('nouvel_evenement')), findsNothing);

    // --- Elle active son statut avec Google depuis Paramètres.
    await toucher(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('activer_gestionnaire')));
    expect(texte(tester, 'mon_statut'), 'Statut : Gestionnaire en attente');
    expect(find.byKey(const Key('invitation_gestionnaire')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('activer_gestionnaire')));
    await attendreTexte(tester, 'mon_statut', 'Statut : Gestionnaire');
    expect(texte(tester, 'ma_connexion'), 'Connexion Google : active');
    expect(find.byKey(const Key('activer_gestionnaire')), findsNothing);
    expect(auth.currentUser!.uid, leaUid); // même identifiant, Google rattaché
    doc = (await refLea(leaUid).get(serveur)).data()!;
    expect(doc['role'], 'gestionnaire');
    expect(doc.containsKey('nomme'), isFalse);

    // --- Ses droits de gestion apparaissent ; mais elle ne gère pas les gestionnaires.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
    await attendre(tester, find.byKey(const Key('menus')));
    expect(find.text('+1'), findsNothing);
    expect(find.byKey(const Key('nouvel_evenement')), findsOneWidget);
    expect(find.byKey(Key('nommer_$chefUid')), findsNothing);
    expect(find.byKey(Key('retirer_$chefUid')), findsNothing);
    expect(find.byKey(Key('retirer_$leaUid')), findsNothing);
    // Et elle peut réellement gérer un menu (droit effectif côté serveur).
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.byKey(const Key('nouveau_menu')));
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);

    // --- Le responsable voit « Gestionnaire », puis la retire.
    await changerDeSession(tester, () async {
      await auth.signInWithCredential((await fauxGoogle('chef_membres')())!);
    });
    await ouvrir(tester, 'chef3', googleAnnule);
    await attendreTexte(tester, 'statut_$leaUid', 'Gestionnaire');
    await toucher(tester, find.byKey(Key('retirer_$leaUid')));
    await toucher(tester, find.byKey(const Key('confirmer_retrait')));
    await attendreTexte(tester, 'statut_$leaUid', 'Bénévole');
    expect(find.byKey(Key('nommer_$leaUid')), findsOneWidget); // renommable
    doc = (await refLea(leaUid).get(serveur)).data()!;
    expect(doc['role'], 'benevole');
    expect(doc.containsKey('nomme'), isFalse);

    // --- Léa a perdu ses droits de gestion.
    await changerDeSession(tester, () async {
      await auth.signInWithEmailAndPassword(
          email: 'lea@test.fr', password: 'secret12');
    });
    await ouvrir(tester, 'lea3', googleAnnule);
    await attendre(tester, find.byKey(const Key('parametres')));
    await attendre(tester, find.text('Membres (2)'));
    expect(find.byKey(const Key('menus')), findsNothing);
    expect(find.byKey(const Key('nouvel_evenement')), findsNothing);
  });
}
