import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Remet un fichier texte à l'utilisateur (feuille de partage d'Android : Drive,
/// messagerie, tableur…). Remplaçable dans les tests, où il n'y a pas de feuille de partage.
typedef Partageur = Future<void> Function(String nomFichier, String contenu);

Future<void> partagerFichierTexte(String nomFichier, String contenu) async {
  final octets = utf8.encode(contenu);
  await Share.shareXFiles(
    [XFile.fromData(octets, mimeType: 'text/csv', name: nomFichier)],
    fileNameOverrides: [nomFichier],
    subject: nomFichier,
  );
}
