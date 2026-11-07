import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Choisit un classeur Excel sur le téléphone et rend son contenu, ou null si la
/// personne annule. Remplaçable dans les tests, où le sélecteur du système ne se pilote pas.
typedef SelecteurClasseur = Future<Uint8List?> Function();

/// Le sélecteur de fichiers du système (aucune permission de stockage demandée).
Future<Uint8List?> choisirClasseurSysteme() async {
  final r = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );
  return r?.files.single.bytes;
}
