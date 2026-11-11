import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'theme.dart';

/// Clé de navigation de l'application (branchée sur le MaterialApp de main.dart).
/// Elle donne le contexte où afficher la feuille « Enregistrer / Partager ».
final GlobalKey<NavigatorState> navigatorCle = GlobalKey<NavigatorState>();

/// Remet un fichier texte à l'utilisateur (feuille de choix, puis Drive, messagerie…).
/// Remplaçable dans les tests, où il n'y a pas de feuille de partage.
typedef Partageur = Future<void> Function(String nomFichier, String contenu);

/// Remet un fichier binaire (classeur Excel) à l'utilisateur. Remplaçable dans les tests.
typedef PartageurOctets = Future<void> Function(
    String nomFichier, Uint8List octets, String typeMime);

/// Enregistre un fichier dans un dossier choisi par la personne. Rend le chemin
/// enregistré, ou null si la personne ferme le choix de dossier sans rien choisir.
typedef Enregistreur = Future<String?> Function(
    String nomFichier, Uint8List octets, String typeMime);

enum _Choix { enregistrer, partager }

/// Le sélecteur de dossier du système (Android : « Enregistrer sous »).
Future<String?> enregistrerSysteme(
    String nomFichier, Uint8List octets, String typeMime) {
  return FilePicker.saveFile(fileName: nomFichier, bytes: octets);
}

/// La feuille de partage du système (Drive, messagerie, tableur…).
Future<void> partageSysteme(
    String nomFichier, Uint8List octets, String typeMime) async {
  await Share.shareXFiles(
    [XFile.fromData(octets, mimeType: typeMime, name: nomFichier)],
    fileNameOverrides: [nomFichier],
    subject: nomFichier,
  );
}

/// Feuille de choix : « Enregistrer sur le téléphone » ou « Partager ».
/// Fermer la feuille sans choisir, ou annuler le choix de dossier, ne montre aucune erreur.
Future<void> ouvrirFeuilleRemise(
  BuildContext contexte, {
  required String nomFichier,
  required Uint8List octets,
  required String typeMime,
  required Enregistreur enregistrer,
  required PartageurOctets partager,
}) async {
  final choix = await showModalBottomSheet<_Choix>(
    context: contexte,
    backgroundColor: Palette.papier,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              nomFichier,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.gris),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('choix_enregistrer'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.anthracite,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(ctx).pop(_Choix.enregistrer),
              child: const Text('Enregistrer sur le téléphone'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('choix_partager'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.prune,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(ctx).pop(_Choix.partager),
              child: const Text('Partager'),
            ),
          ],
        ),
      ),
    ),
  );
  if (choix == null || !contexte.mounted) return;

  if (choix == _Choix.partager) {
    await partager(nomFichier, octets, typeMime);
    return;
  }

  try {
    final chemin = await enregistrer(nomFichier, octets, typeMime);
    if (chemin == null || !contexte.mounted) return; // annulé : silence
    ScaffoldMessenger.maybeOf(contexte)?.showSnackBar(
      SnackBar(content: Text('Fichier enregistré : $nomFichier')),
    );
  } catch (_) {
    if (!contexte.mounted) return;
    ScaffoldMessenger.maybeOf(contexte)?.showSnackBar(
      const SnackBar(
          content: Text("Le fichier n'a pas pu être enregistré.")),
    );
  }
}

/// Remet un fichier binaire : feuille de choix, ou partage direct si l'application
/// n'a pas encore d'écran affiché.
Future<void> partagerFichier(
    String nomFichier, Uint8List octets, String typeMime) async {
  final overlay = navigatorCle.currentState?.overlay;
  if (overlay == null) {
    await partageSysteme(nomFichier, octets, typeMime);
    return;
  }
  await ouvrirFeuilleRemise(
    overlay.context,
    nomFichier: nomFichier,
    octets: octets,
    typeMime: typeMime,
    enregistrer: enregistrerSysteme,
    partager: partageSysteme,
  );
}

/// Remet un fichier texte (liste de courses) : même feuille de choix que les classeurs.
Future<void> partagerFichierTexte(String nomFichier, String contenu) {
  return partagerFichier(
    nomFichier,
    Uint8List.fromList(utf8.encode(contenu)),
    'text/plain',
  );
}
