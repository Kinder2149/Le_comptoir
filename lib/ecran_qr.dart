import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'gymnase.dart';

/// Lit un QR code avec la caméra et renvoie son texte (null si l'utilisateur
/// renonce). Remplaçable dans les tests par un faux lecteur.
typedef LecteurQr = Future<String?> Function(BuildContext context);

/// Le vrai lecteur : ouvre l'écran de la caméra.
Future<String?> lecteurQrReel(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EcranScan()),
    );

/// Écran de la caméra : se ferme dès qu'un QR code est lu.
class EcranScan extends StatefulWidget {
  const EcranScan({super.key});

  @override
  State<EcranScan> createState() => _EtatScan();
}

class _EtatScan extends State<EcranScan> {
  final _controleur = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _lu = false;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _surLecture(BarcodeCapture capture) {
    if (_lu) return;
    final texte = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (texte == null) return;
    _lu = true;
    Navigator.of(context).pop(texte);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un QR code')),
      body: Stack(
        children: [
          MobileScanner(
            key: const Key('camera_qr'),
            controller: _controleur,
            onDetect: _surLecture,
            errorBuilder: (context, erreur) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  erreur.errorCode == MobileScannerErrorCode.permissionDenied
                      ? "L'accès à la caméra est refusé : autorisez-le dans les "
                          "réglages du téléphone pour scanner un QR code."
                      : "La caméra n'est pas disponible sur ce téléphone.",
                  key: const Key('erreur_camera'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Visez le QR code du gymnase.',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6)]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// QR code d'un gymnase à faire scanner : il contient le code d'accès de
/// l'association, l'événement et le gymnase. Il se met à jour tout seul si le
/// responsable change le code (les anciens QR cessent alors de fonctionner).
class EcranQr extends StatelessWidget {
  const EcranQr({
    super.key,
    required this.codeAssociation,
    required this.evenementId,
    required this.gymnase,
  });

  /// Le code d'accès actuel de l'association.
  final Stream<String> codeAssociation;
  final String evenementId;
  final Gymnase gymnase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Partager — ${gymnase.nom}')),
      body: StreamBuilder<String>(
        stream: codeAssociation,
        builder: (context, s) {
          final code = s.data;
          if (code == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final lien = ecrireLienGymnase(
              LienGymnase(code, evenementId, gymnase.id));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Faites scanner ce QR code : le bénévole rejoint l’association '
                '(son prénom lui est demandé) et arrive directement dans ce gymnase.',
                key: const Key('explication_qr'),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    // La clé porte le texte du QR : les tests vérifient ce qu'il contient.
                    key: ValueKey(lien),
                    data: lien,
                    size: 260,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Code d'accès de l'association"),
              Text(
                code,
                key: const Key('code_qr'),
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('copier_code'),
                icon: const Icon(Icons.copy),
                label: const Text('Copier le code'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Code copié.', key: Key('code_copie'))));
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Si le responsable change le code de l’association, ce QR code '
                'ne fonctionnera plus : il faudra en afficher un nouveau.',
                key: Key('avertissement_qr'),
              ),
            ],
          );
        },
      ),
    );
  }
}
