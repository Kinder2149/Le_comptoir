import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'outils.dart';

// A7 critère 8 : le QR de l'association (carte « Association et code » des
// Paramètres) est visible du responsable ; un second compte « scanne » le lien
// (faux lecteur) et devient bénévole, sans événement ouvert ; un bénévole ne
// voit pas le QR. Le vrai scan à la caméra reste à la recette de Kinder.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets("QR de l'association : le responsable l'affiche, un second compte le scanne",
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    // --- Le responsable crée l'association et ouvre ses Paramètres.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_qr_asso'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId']
            as String;
    await tester.tap(find.byKey(const Key('parametres')));
    await attendre(tester, find.byKey(const Key('explication_qr_asso')));
    await fin(tester);
    await tester.ensureVisible(find.byType(QrImageView));
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    final lienQr = (qr.key! as ValueKey<String>).value;
    expect(lienQr, ecrireLienAssociation(code));
    expect(lireLienGymnase(lienQr).codeAssociation, code);
    expect(lireLienGymnase(lienQr).sansGymnase, isTrue);

    // --- Un second compte scanne ce lien depuis l'accueil.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    Future<String?> lecteur(BuildContext _) async => lienQr;
    await ouvrir(tester, 'benevole', fauxGoogle('benevole_qr_asso'),
        lecteurQr: lecteur);
    await attendre(tester, find.byKey(const Key('scanner_qr')));
    await fin(tester);
    await tester.ensureVisible(find.byKey(const Key('scanner_qr')));
    await tester.tap(find.byKey(const Key('scanner_qr')));
    await attendre(tester, find.byKey(const Key('prenom_qr')));
    expect(find.text("Rejoindre l'association"), findsOneWidget);
    await tester.enterText(find.byKey(const Key('prenom_qr')), 'Lea');
    await tester.tap(find.byKey(const Key('valider_prenom_qr')));

    // Il arrive dans l'association, sans événement ouvert, comme bénévole.
    await attendre(tester, find.byKey(const Key('parametres')));
    await fin(tester);
    expect(find.byKey(const Key('gymnase_scanne')), findsNothing);
    final leaUid = auth.currentUser!.uid;
    expect(leaUid, isNot(chefUid));
    final membre = (await db
            .collection('associations')
            .doc(assoId)
            .collection('membres')
            .doc(leaUid)
            .get(const GetOptions(source: Source.server)))
        .data()!;
    expect(membre['prenom'], 'Lea');
    expect(membre['role'], 'benevole');

    // --- Le bénévole ne voit pas le QR dans ses Paramètres.
    await tester.tap(find.byKey(const Key('parametres')));
    await fin(tester);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const Key('explication_qr_asso')), findsNothing);
  });
}
