// Pilote d'audit visuel (temporaire) : enregistre les captures prises par le parcours.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dossier = Platform.environment['CAPTURES'] ?? 'audit_front/avant';
  await integrationDriver(
    onScreenshot: (String nom, List<int> octets, [Map<String, Object?>? args]) async {
      final f = File('$dossier/$nom.png');
      await f.create(recursive: true);
      await f.writeAsBytes(octets);
      return true;
    },
  );
}
