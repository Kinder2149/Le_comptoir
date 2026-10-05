import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/ecran_qr.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const gymnase = Gymnase('g1', 'Gymnase A');

  Future<void> afficher(WidgetTester tester, Stream<String> code) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: EcranQr(
        codeAssociation: code,
        evenementId: 'evt1',
        gymnase: gymnase,
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  /// Le texte du QR affiché (porté par la clé du QR).
  String donnees(WidgetTester tester) {
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    return (qr.key! as ValueKey<String>).value;
  }

  testWidgets('le QR contient bien le lien du gymnase, et le code est écrit en clair',
      (tester) async {
    await afficher(tester, Stream.value('AB12CD'));
    expect(donnees(tester), 'lecomptoir://rejoindre?v=1&c=AB12CD&e=evt1&g=g1');
    // Ce que le QR contient se relit exactement.
    expect(lireLienGymnase(donnees(tester)),
        const LienGymnase('AB12CD', 'evt1', 'g1'));
    expect(tester.widget<Text>(find.byKey(const Key('code_qr'))).data, 'AB12CD');
    expect(find.text('Partager — Gymnase A'), findsOneWidget);
    expect(find.byKey(const Key('avertissement_qr')), findsOneWidget);
  });

  testWidgets('« Copier le code » met le code dans le presse-papiers',
      (tester) async {
    String? copie;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (appel) async {
        if (appel.method == 'Clipboard.setData') {
          copie = (appel.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await afficher(tester, Stream.value('AB12CD'));
    await tester.tap(find.byKey(const Key('copier_code')));
    await tester.pump();
    expect(copie, 'AB12CD');
    expect(find.byKey(const Key('code_copie')), findsOneWidget);
  });

  testWidgets('si le responsable change le code, le QR affiché suit', (tester) async {
    final flux = StreamController<String>();
    addTearDown(flux.close);
    await afficher(tester, flux.stream);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    flux.add('AB12CD');
    await tester.pump();
    expect(donnees(tester), contains('c=AB12CD'));
    flux.add('ZZ99YY');
    await tester.pump();
    expect(donnees(tester), contains('c=ZZ99YY'));
    expect(tester.widget<Text>(find.byKey(const Key('code_qr'))).data, 'ZZ99YY');
  });
}
