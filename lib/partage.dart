import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Remet un fichier texte à l'utilisateur (feuille de partage d'Android : Drive,
/// messagerie, tableur…). Remplaçable dans les tests, où il n'y a pas de feuille de partage.
typedef Partageur = Future<void> Function(String nomFichier, String contenu);

Future<void> partagerFichierTexte(String nomFichier, String contenu) async {
  final octets = utf8.encode(contenu);
  await Share.shareXFiles(
    [
      XFile.fromData(octets,
          mimeType: 'text/plain',
          name: nomFichier)
    ],
    fileNameOverrides: [nomFichier],
    subject: nomFichier,
  );
}

/// Remet un fichier binaire (classeur Excel) à l'utilisateur. Remplaçable dans les tests.
typedef PartageurOctets = Future<void> Function(
    String nomFichier, Uint8List octets, String typeMime);

Future<void> partagerFichier(
    String nomFichier, Uint8List octets, String typeMime) async {
  await Share.shareXFiles(
    [XFile.fromData(octets, mimeType: typeMime, name: nomFichier)],
    fileNameOverrides: [nomFichier],
    subject: nomFichier,
  );
}
