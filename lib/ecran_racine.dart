import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'connexion.dart';
import 'depot_associations.dart';
import 'ecran_accueil.dart';
import 'ecran_association.dart';
import 'ecran_menu.dart' show SelecteurPhoto, selecteurPhotoReel;
import 'ecran_qr.dart';
import 'gymnase.dart';

/// Point d'entrée : connexion invisible, puis écran d'accueil (pas encore
/// d'association) ou écran de l'association de cet appareil.
class EcranRacine extends StatefulWidget {
  const EcranRacine({
    super.key,
    required this.auth,
    required this.depot,
    required this.fournisseurGoogle,
    this.selecteurPhoto = selecteurPhotoReel,
    this.lecteurQr = lecteurQrReel,
  });

  final FirebaseAuth auth;
  final DepotAssociations depot;
  final FournisseurGoogle fournisseurGoogle;
  final SelecteurPhoto selecteurPhoto;
  final LecteurQr lecteurQr;

  @override
  State<EcranRacine> createState() => _EtatRacine();
}

class _EtatRacine extends State<EcranRacine> {
  late Future<String> _connexion = assurerConnexion(widget.auth);

  // Le suivi de l'association de cet appareil est créé UNE fois par utilisateur.
  // Le recréer à chaque reconstruction (ex. renouvellement automatique du jeton de
  // connexion) remettait l'écran en « chargement » : ce qu'on venait de taper
  // disparaissait et un message d'erreur en cours pouvait se perdre.
  String? _uidSuivi;
  Stream<String?>? _suivi;
  Stream<String?> _associationDe(String uid) {
    if (_uidSuivi != uid) {
      _uidSuivi = uid;
      _suivi = widget.depot.suivreAssociationId(uid);
    }
    return _suivi!;
  }

  // QR code scanné avant de rejoindre : l'événement s'ouvre dès que l'association
  // de cet appareil est connue.
  LienGymnase? _lien;

  Widget _chargement() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _erreur() => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connexion impossible. Vérifiez le réseau.',
                  key: Key('erreur_connexion'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('reessayer'),
                  onPressed: () => setState(
                      () => _connexion = assurerConnexion(widget.auth)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _connexion,
      builder: (context, connexion) {
        if (connexion.hasError) return _erreur();
        if (connexion.data == null) return _chargement();
        // L'identifiant peut changer (retour sur un compte Google connu).
        return StreamBuilder<User?>(
          stream: widget.auth.userChanges(),
          initialData: widget.auth.currentUser,
          builder: (context, u) {
            final uid = u.data?.uid;
            if (uid == null) return _chargement();
            return StreamBuilder<String?>(
              key: ValueKey(uid),
              stream: _associationDe(uid),
              builder: (context, asso) {
                if (asso.hasError) return _erreur();
                if (asso.connectionState == ConnectionState.waiting) {
                  return _chargement();
                }
                final id = asso.data;
                return id == null
                    ? EcranAccueil(
                        depot: widget.depot,
                        auth: widget.auth,
                        fournisseurGoogle: widget.fournisseurGoogle,
                        lecteurQr: widget.lecteurQr,
                        surLien: (lien) => setState(() => _lien = lien),
                      )
                    : EcranAssociation(
                        depot: widget.depot,
                        uid: uid,
                        assoId: id,
                        auth: widget.auth,
                        fournisseurGoogle: widget.fournisseurGoogle,
                        selecteurPhoto: widget.selecteurPhoto,
                        lecteurQr: widget.lecteurQr,
                        lien: _lien,
                        lienTraite: () => setState(() => _lien = null),
                      );
              },
            );
          },
        );
      },
    );
  }
}
