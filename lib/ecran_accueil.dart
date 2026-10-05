import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'connexion.dart';
import 'depot_associations.dart';
import 'ecran_qr.dart';
import 'gymnase.dart';

/// Premier écran : créer son association ou rejoindre celle d'un club.
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({
    super.key,
    required this.depot,
    required this.auth,
    required this.fournisseurGoogle,
    this.lecteurQr = lecteurQrReel,
    this.surLien,
  });

  final DepotAssociations depot;
  final FirebaseAuth auth;
  final FournisseurGoogle fournisseurGoogle;
  final LecteurQr lecteurQr;

  /// Appelée quand on a rejoint l'association grâce à un QR code de gymnase.
  final void Function(LienGymnase lien)? surLien;

  @override
  State<EcranAccueil> createState() => _EtatAccueil();
}

class _EtatAccueil extends State<EcranAccueil> {
  final _nomAsso = TextEditingController();
  final _prenomCreation = TextEditingController();
  final _code = TextEditingController();
  final _prenomRejoindre = TextEditingController();
  String? _erreur;
  bool _occupe = false;

  @override
  void dispose() {
    _nomAsso.dispose();
    _prenomCreation.dispose();
    _code.dispose();
    _prenomRejoindre.dispose();
    super.dispose();
  }

  Future<void> _lancer(Future<void> Function() action) async {
    setState(() {
      _erreur = null;
      _occupe = true;
    });
    try {
      await action();
    } on CodeInvalide {
      if (mounted) setState(() => _erreur = 'Code inconnu ou périmé.');
    } catch (_) {
      if (mounted) {
        setState(() => _erreur = 'Action impossible. Vérifiez le réseau.');
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _creer() async {
    if (_nomAsso.text.trim().isEmpty || _prenomCreation.text.trim().isEmpty) {
      setState(() => _erreur = 'Renseignez le nom et votre prénom.');
      return;
    }
    await _lancer(() async {
      // Le responsable doit être identifié : connexion Google obligatoire.
      if (!aGoogle(widget.auth.currentUser)) {
        final ok = await connecterGoogle(widget.auth, widget.fournisseurGoogle);
        if (!ok) {
          if (mounted) setState(() => _erreur = 'Connexion Google annulée.');
          return;
        }
      }
      await widget.depot.creerAssociation(
        uid: widget.auth.currentUser!.uid,
        nom: _nomAsso.text,
        prenom: _prenomCreation.text,
      );
    });
  }

  /// Nouveau téléphone : on retrouve son association via son compte Google.
  Future<void> _retrouver() async {
    await _lancer(() async {
      final ok = await connecterGoogle(widget.auth, widget.fournisseurGoogle);
      if (!ok && mounted) {
        setState(() => _erreur = 'Connexion Google annulée.');
      }
    });
  }

  Future<void> _rejoindre() async {
    if (_code.text.trim().isEmpty || _prenomRejoindre.text.trim().isEmpty) {
      setState(() => _erreur = 'Renseignez le code et votre prénom.');
      return;
    }
    await _lancer(() => widget.depot.rejoindre(
          uid: widget.auth.currentUser!.uid,
          codeSaisi: _code.text,
          prenom: _prenomRejoindre.text,
        ));
  }

  /// Scanner le QR code d'un gymnase : on demande le prénom, on rejoint
  /// l'association, puis l'événement s'ouvre sur ce gymnase.
  Future<void> _scanner() async {
    final texte = await widget.lecteurQr(context);
    if (texte == null || !mounted) return;
    final LienGymnase lien;
    try {
      lien = lireLienGymnase(texte);
    } on FormatException {
      setState(() => _erreur =
          "QR code illisible : ce n'est pas un QR code du Comptoir.");
      return;
    }
    final prenom = await showDialog<String>(
      context: context,
      builder: (_) => const _DialoguePrenom(),
    );
    if (prenom == null || !mounted) return;
    setState(() {
      _erreur = null;
      _occupe = true;
    });
    try {
      await widget.depot.rejoindre(
        uid: widget.auth.currentUser!.uid,
        codeSaisi: lien.codeAssociation,
        prenom: prenom,
      );
      widget.surLien?.call(lien);
    } on CodeInvalide {
      if (mounted) {
        setState(() => _erreur =
            "Ce QR code n'est plus valable : le code de l'association a changé. "
            'Demandez-en un nouveau.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erreur = 'Action impossible. Vérifiez le réseau.');
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Le Comptoir')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // L'erreur s'affiche en haut : sur un petit écran, celle du bas passait inaperçue.
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _erreur!,
                key: const Key('erreur'),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Text('Créer mon association',
              style: Theme.of(context).textTheme.titleMedium),
          TextField(
            key: const Key('nom_association'),
            controller: _nomAsso,
            decoration:
                const InputDecoration(labelText: "Nom de l'association"),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('prenom_creation'),
            controller: _prenomCreation,
            decoration: const InputDecoration(labelText: 'Votre prénom'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('creer'),
            onPressed: _occupe ? null : _creer,
            child: const Text('Créer avec Google'),
          ),
          const Divider(height: 40),
          Text('Rejoindre une association',
              style: Theme.of(context).textTheme.titleMedium),
          TextField(
            key: const Key('code_saisi'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Code de l'association"),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('prenom_rejoindre'),
            controller: _prenomRejoindre,
            decoration: const InputDecoration(labelText: 'Votre prénom'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('rejoindre'),
            onPressed: _occupe ? null : _rejoindre,
            child: const Text('Rejoindre'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('scanner_qr'),
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _occupe ? null : _scanner,
            label: const Text('Scanner un QR code'),
          ),
          const Divider(height: 40),
          Text('Responsable ou gestionnaire ?',
              style: Theme.of(context).textTheme.titleMedium),
          const Text('Retrouvez votre association depuis un autre téléphone.'),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('retrouver'),
            onPressed: _occupe ? null : _retrouver,
            child: const Text('Me connecter avec Google'),
          ),
        ],
      ),
    );
  }
}

/// Le prénom, demandé quand on rejoint en scannant un QR code.
class _DialoguePrenom extends StatefulWidget {
  const _DialoguePrenom();

  @override
  State<_DialoguePrenom> createState() => _EtatDialoguePrenom();
}

class _EtatDialoguePrenom extends State<_DialoguePrenom> {
  final _prenom = TextEditingController();
  bool _vide = false;

  @override
  void dispose() {
    _prenom.dispose();
    super.dispose();
  }

  void _valider() {
    if (_prenom.text.trim().isEmpty) {
      setState(() => _vide = true);
    } else {
      Navigator.pop(context, _prenom.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rejoindre ce gymnase'),
      content: TextField(
        key: const Key('prenom_qr'),
        controller: _prenom,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Votre prénom',
          errorText: _vide ? 'Renseignez votre prénom.' : null,
        ),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_prenom_qr'),
            onPressed: _valider,
            child: const Text('Rejoindre')),
      ],
    );
  }
}
