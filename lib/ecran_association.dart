import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'actualisation.dart';

import 'code_association.dart';
import 'connexion.dart';
import 'depot_associations.dart';
import 'depot_evenements.dart' show ResultatLien;
import 'ecran_evenement.dart';
import 'ecran_extraction.dart';
import 'ecran_import.dart';
import 'ecran_menu.dart' show SelecteurPhoto, selecteurPhotoReel;
import 'ecran_menus.dart';
import 'ecran_nouvel_evenement.dart';
import 'ecran_qr.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';

/// Écran de l'association : nom, code, membres, accès à la caisse.
class EcranAssociation extends StatelessWidget {
  const EcranAssociation({
    super.key,
    required this.depot,
    required this.uid,
    required this.assoId,
    required this.auth,
    required this.fournisseurGoogle,
    this.selecteurPhoto = selecteurPhotoReel,
    this.lecteurQr = lecteurQrReel,
    this.lien,
    this.lienTraite,
  });

  final DepotAssociations depot;
  final String uid;
  final String assoId;
  final FirebaseAuth auth;
  final FournisseurGoogle fournisseurGoogle;
  final SelecteurPhoto selecteurPhoto;
  final LecteurQr lecteurQr;

  /// QR code scanné pour arriver ici : l'événement s'ouvre sur son gymnase.
  final LienGymnase? lien;
  final VoidCallback? lienTraite;

  void _message(BuildContext context, String texte) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texte, key: const Key('erreur_qr'))));
  }

  /// Scanner un QR code (déjà membre).
  Future<void> _scanner(BuildContext context, Membre moi) async {
    final texte = await lecteurQr(context);
    if (texte == null || !context.mounted) return;
    final LienGymnase lien;
    try {
      lien = lireLienGymnase(texte);
    } on FormatException {
      _message(context,
          "QR code illisible : ce n'est pas un QR code du Comptoir.");
      return;
    }
    await _ouvrirLien(context, moi, lien);
  }

  /// Vérifie le QR code (même association, événement en cours, gymnase connu)
  /// puis ouvre l'événement sur ce gymnase.
  Future<void> _ouvrirLien(
      BuildContext context, Membre moi, LienGymnase lien) async {
    final depotEv = depot.evenements(assoId);
    String? probleme;
    try {
      final cible = await depot.associationDuCode(lien.codeAssociation);
      if (cible == null) {
        probleme = "Ce QR code n'est plus valable : le code de l'association "
            'a changé. Demandez-en un nouveau.';
      } else if (cible != assoId) {
        probleme = "Ce QR code est celui d'une autre association que la vôtre.";
      } else {
        switch (await depotEv.verifierLien(lien.evenementId, lien.gymnaseId)) {
          case ResultatLien.ok:
            break;
          case ResultatLien.evenementIntrouvable:
            probleme = "Cet événement est clôturé ou n'existe plus.";
          case ResultatLien.gymnaseInconnu:
            probleme = "Ce gymnase n'existe plus dans cet événement.";
        }
      }
    } catch (_) {
      probleme = 'Lecture impossible. Vérifiez le réseau.';
    }
    if (!context.mounted) return;
    if (probleme != null) {
      _message(context, probleme);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcranEvenement(
          depot: depotEv,
          depotMenus: depot.menus(assoId),
          evenementId: lien.evenementId,
          peutModifier: moi.role != 'benevole',
          responsable: moi.estResponsable,
          membres: depot.suivreMembres(assoId),
          codeAssociation: depot.suivreAssociation(assoId).map((a) => a?.code ?? ''),
          uid: uid,
          prenom: moi.prenom,
          gymnasePropose: lien.gymnaseId,
          selecteurPhoto: selecteurPhoto,
        ),
      ),
    );
  }

  /// Événements : un bénévole ne voit que ceux en cours.
  Widget _evenements(BuildContext context, Membre moi) {
    final gestion = moi.role != 'benevole';
    final depotEv = depot.evenements(assoId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Événements', style: Theme.of(context).textTheme.titleMedium),
        if (gestion)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('nouvel_evenement'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EcranNouvelEvenement(
                    depot: depotEv,
                    depotMenus: depot.menus(assoId),
                  ),
                ),
              ),
              child: const Text('Nouvel événement'),
            ),
          ),
        StreamBuilder<List<Evenement>>(
          stream: depotEv.suivreEvenements(enCoursSeulement: !gestion),
          builder: (context, s) {
            final liste = s.data;
            if (liste == null) return const SizedBox.shrink();
            if (liste.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun événement en cours.',
                    key: Key('aucun_evenement')),
              );
            }
            return Column(
              children: [
                for (final e in liste)
                  ListTile(
                    key: Key('evenement_${e.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.nom),
                    subtitle: Text(
                        '${dateAffichee(e.date)} · ${libelleModes(e.modes)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PastilleEtat(
                            key: Key('etat_${e.id}'),
                            enCours: e.enCours,
                            enPreparation: e.enPreparation),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EcranEvenement(
                          depot: depotEv,
                          depotMenus: depot.menus(assoId),
                          evenementId: e.id,
                          peutModifier: gestion,
                          responsable: moi.estResponsable,
                          membres: depot.suivreMembres(assoId),
                          codeAssociation: depot
                              .suivreAssociation(assoId)
                              .map((a) => a?.code ?? ''),
                          uid: uid,
                          prenom: moi.prenom,
                          selecteurPhoto: selecteurPhoto,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Association?>(
      stream: depot.suivreAssociation(assoId),
      builder: (context, a) {
        // Association supprimée, ou membre retiré (lecture refusée) : retour à l'accueil.
        if (a.hasError ||
            (a.connectionState == ConnectionState.active && a.data == null)) {
          return _Quitte(depot: depot, uid: uid);
        }
        final asso = a.data;
        if (asso == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return StreamBuilder<List<Membre>>(
          stream: depot.suivreMembres(assoId),
          builder: (context, m) {
            if (m.hasError) return _Quitte(depot: depot, uid: uid);
            final membres = m.data ?? const <Membre>[];
            final moi = membres.where((x) => x.uid == uid).firstOrNull;
            return Scaffold(
              appBar: AppBar(
                title: Text(asso.nom, key: const Key('nom')),
                actions: [
                  IconButton(
                    key: const Key('parametres'),
                    tooltip: 'Paramètres',
                    // Pastille « +1 » : j'ai été nommé gestionnaire, à activer.
                    icon: Badge(
                      key: const Key('pastille_parametres'),
                      isLabelVisible: moi?.enAttente ?? false,
                      label: const Text('+1'),
                      child: const Icon(Icons.settings),
                    ),
                    onPressed: moi == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EcranParametres(
                                  depot: depot,
                                  uid: uid,
                                  assoId: assoId,
                                  auth: auth,
                                  fournisseurGoogle: fournisseurGoogle,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
              body: actualisable(
                relire: () => depot.actualiser(assoId, enCoursSeulement: moi == null || moi.role == 'benevole'),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text("Code d'accès"),
                  Text(
                    asso.code,
                    key: const Key('code'),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4),
                  ),
                  const SizedBox(height: 16),
                  if (moi != null && moi.role != 'benevole')
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            key: const Key('menus'),
                            style: TypeAction.gerer.contour,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EcranMenus(
                                  depot: depot.menus(assoId),
                                  selecteurPhoto: selecteurPhoto,
                                  assistant: (_) => EcranImport(
                                    sources: SourcesImport.depuis(
                                      menus: depot.menus(assoId),
                                      evenements: depot.evenements(assoId),
                                      uid: uid,
                                      responsable: moi.estResponsable,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: const Text('Menus'),
                          ),
                          OutlinedButton(
                            key: const Key('extraction'),
                            style: TypeAction.gerer.contour,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EcranExtraction(
                                  depot: depot,
                                  uid: uid,
                                  assoId: assoId,
                                  responsable: moi.estResponsable,
                                ),
                              ),
                            ),
                            child: const Text('Extraction et modèle'),
                          ),
                        ],
                      ),
                    ),
                  moi == null
                      ? const SizedBox.shrink()
                      : OutlinedButton.icon(
                          key: const Key('scanner_qr'),
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () => _scanner(context, moi),
                          label: const Text('Scanner un QR code'),
                        ),
                  // Arrivé par un QR code : on ouvre l'événement visé (une seule fois).
                  moi == null || lien == null
                      ? const SizedBox.shrink()
                      : _OuvreurLien(
                          key: ValueKey(lien),
                          ouvrir: () async {
                            lienTraite?.call();
                            await _ouvrirLien(context, moi, lien!);
                          },
                        ),
                  const Divider(height: 40),
                  if (moi != null) _evenements(context, moi),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Paramètres du membre : son statut, et l'activation du statut de
/// gestionnaire (connexion Google) quand le responsable l'a nommé.
class EcranParametres extends StatefulWidget {
  const EcranParametres({
    super.key,
    required this.depot,
    required this.uid,
    required this.assoId,
    required this.auth,
    required this.fournisseurGoogle,
  });

  final DepotAssociations depot;
  final String uid;
  final String assoId;
  final FirebaseAuth auth;
  final FournisseurGoogle fournisseurGoogle;

  @override
  State<EcranParametres> createState() => _EtatParametres();
}

class _EtatParametres extends State<EcranParametres> {
  String? _erreur;
  String? _erreurAutre;
  String? _erreurSuppression;
  bool _occupe = false;
  bool _suppression = false;

  Future<void> _regenerer(Association asso) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Changer le code ?'),
        content: const Text(
            "L'ancien code ne fonctionnera plus pour les nouveaux arrivants. "
            "Les membres actuels restent dans l'association."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              style: TypeAction.gerer.plein,
              key: const Key('confirmer_regeneration'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Changer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.depot.regenererCode(assoId: asso.id, ancienCode: asso.code);
    } catch (_) {
      if (mounted) {
        setState(() => _erreurAutre = 'Changement impossible. Vérifiez le réseau.');
      }
    }
  }

  Future<void> _sortir(Membre x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Retirer ${x.prenom} de l'association ?"),
        content: const Text(
            "Il n'aura plus accès à l'association ; ses ventes passées restent "
            "dans les bilans. Il pourra revenir avec le code d'accès, sauf si "
            'vous changez aussi le code.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              key: const Key('confirmer_sortie'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.depot.retirerMembre(widget.assoId, x.uid);
    } catch (_) {
      if (mounted) {
        setState(() => _erreurAutre = 'Retrait impossible. Vérifiez le réseau.');
      }
    }
  }

  Future<void> _retirerGestion(Membre x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer le statut de gestionnaire à ${x.prenom} ?'),
        content: const Text(
            'Il redevient bénévole : il ne voit plus les menus ni les bilans et ne gère plus les événements.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              style: TypeAction.danger.plein,
              key: const Key('confirmer_retrait'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.depot.retirerGestionnaire(widget.assoId, x.uid);
    } catch (_) {
      if (mounted) {
        setState(() => _erreurAutre = 'Changement impossible. Vérifiez le réseau.');
      }
    }
  }

  /// Il faut retaper le nom de l'association pour confirmer.
  Future<bool> _confirmerSuppression(String nom) async {
    final champ = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setEtat) => AlertDialog(
          title: const Text("Supprimer l'association ?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Action définitive : menus, événements, caisses, ventes, bilans '
                'et membres seront effacés pour tout le monde.',
                key: Key('avertissement_suppression'),
              ),
              const SizedBox(height: 12),
              Text('Pour confirmer, tapez le nom : $nom'),
              TextField(
                key: const Key('confirmation_nom'),
                controller: champ,
                onChanged: (_) => setEtat(() {}),
                decoration:
                    const InputDecoration(labelText: "Nom de l'association"),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler')),
            FilledButton(
              style: TypeAction.danger.plein,
              key: const Key('confirmer_suppression_asso'),
              onPressed: confirmationSuppression(champ.text, nom)
                  ? () => Navigator.pop(c, true)
                  : null,
              child: const Text('Supprimer définitivement'),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _supprimer(Association asso) async {
    if (!await _confirmerSuppression(asso.nom)) return;
    setState(() {
      _suppression = true;
      _erreurSuppression = null;
    });
    try {
      await widget.depot.supprimerAssociation(asso.id);
      await widget.depot.oublierAssociation(widget.uid);
      // Retour à l'écran d'accueil.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      if (mounted) {
        setState(() {
          _suppression = false;
          _erreurSuppression = "La suppression n'a pas pu aller au bout. "
              "Vérifiez le réseau puis recommencez : elle reprend là où elle s'est arrêtée.";
        });
      }
    }
  }

  /// Carte de l'écran (même style que les autres écrans) ; la zone dangereuse a un bord brique.
  Widget _carte(
    BuildContext context, {
    Key? key,
    required String titre,
    required List<Widget> enfants,
    bool danger = false,
  }) =>
      Card(
        key: key,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: danger ? Palette.brique : Palette.filet),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: danger
                    ? Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Palette.briqueFonce)
                    : Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...enfants,
            ],
          ),
        ),
      );

  /// Couleurs du badge de statut (décision 31).
  (Color, Color) _couleursStatut(Membre x) {
    if (x.estResponsable) return (Palette.anthracite, Colors.white);
    if (x.enAttente) return (Palette.ocreDoux, Palette.ocreFonce);
    if (x.role == 'gestionnaire') return (Palette.pruneDoux, Palette.pruneFonce);
    return (Palette.anthraciteDoux, Palette.anthraciteFonce);
  }

  /// Carte réservée au responsable : nom et code de l'association.
  Widget _sectionAssociation(BuildContext context) => StreamBuilder<Association?>(
        stream: widget.depot.suivreAssociation(widget.assoId),
        builder: (context, a) {
          final asso = a.data;
          if (asso == null) return const SizedBox.shrink();
          return _carte(
            context,
            titre: 'Association et code',
            enfants: [
              Text(asso.nom,
                  key: const Key('param_nom'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text("Code d'accès"),
              Text(
                asso.code,
                key: const Key('param_code'),
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('regenerer'),
                  style: TypeAction.gerer.contour,
                  onPressed: () => _regenerer(asso),
                  child: const Text('Changer le code'),
                ),
              ),
            ],
          );
        },
      );

  /// Carte des membres, pour le responsable et les gestionnaires actifs.
  /// Seul le responsable a « Changer le statut », sur les autres membres.
  Widget _sectionMembres(
          BuildContext context, List<Membre> membres, bool responsable) =>
      _carte(
        context,
        titre: 'Membres (${membres.length})',
        enfants: [
          for (final x in membres)
            Padding(
              key: Key('param_membre_${x.uid}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(x.prenom, overflow: TextOverflow.ellipsis),
                      ),
                      BadgeComptoir(
                        texte: libelleStatut(x),
                        cleTexte: Key('param_statut_${x.uid}'),
                        fond: _couleursStatut(x).$1,
                        encre: _couleursStatut(x).$2,
                      ),
                    ],
                  ),
                  if (responsable && !x.estResponsable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: Key('param_changer_${x.uid}'),
                        style: TypeAction.gerer.texte,
                        onPressed: () => _changerStatut(x),
                        child: const Text('Changer le statut'),
                      ),
                    ),
                ],
              ),
            ),
          if (membres.every((x) => x.estResponsable)) ...[
            const Text('Aucun autre membre.', key: Key('aucun_autre_membre')),
            if (responsable) ...[
              const SizedBox(height: 8),
              const Text(
                "Pour inviter des membres, partagez le code d'accès (carte "
                "« Association et code ») : ils le saisissent à leur arrivée.",
                key: Key('aide_invitation'),
              ),
            ],
          ],
        ],
      );

  /// Feuille « Changer le statut » (responsable seul). Chaque choix passe
  /// par sa confirmation, puis par la méthode d'origine.
  Future<void> _changerStatut(Membre x) async {
    final benevoleActuel = x.role == 'benevole' && !x.enAttente;
    final enGestion = x.role == 'gestionnaire' || x.enAttente;
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Changer le statut de ${x.prenom}',
                  style: Theme.of(c).textTheme.titleMedium),
            ),
            ListTile(
              key: Key('param_nommer_${x.uid}'),
              enabled: benevoleActuel,
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Gestionnaire'),
              subtitle: Text(x.enAttente
                  ? 'Déjà nommé : en attente de son activation'
                  : x.role == 'gestionnaire'
                      ? 'Statut actuel'
                      : 'Il gère les menus, les événements et le stock'),
              onTap: () => Navigator.pop(c, 'gestionnaire'),
            ),
            ListTile(
              key: Key('param_retirer_gestion_${x.uid}'),
              enabled: enGestion,
              leading: const Icon(Icons.person_outline),
              title: const Text('Bénévole'),
              subtitle: Text(benevoleActuel
                  ? 'Statut actuel'
                  : 'Il ne gère plus les menus ni les événements'),
              onTap: () => Navigator.pop(c, 'benevole'),
            ),
            ListTile(
              key: Key('param_sortir_${x.uid}'),
              leading: Icon(Icons.person_remove_outlined,
                  color: Palette.brique),
              title: Text("Retirer de l'association",
                  style: TextStyle(color: Palette.briqueFonce)),
              subtitle: const Text("Il n'a plus accès à l'association"),
              onTap: () => Navigator.pop(c, 'retirer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choix == 'gestionnaire') {
      await _nommer(x);
    } else if (choix == 'benevole') {
      await _retirerGestion(x);
    } else if (choix == 'retirer') {
      await _sortir(x);
    }
  }

  /// Confirmation avant de nommer un gestionnaire (il reste en attente
  /// jusqu'à son activation avec Google).
  Future<void> _nommer(Membre x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Nommer ${x.prenom} gestionnaire ?'),
        content: const Text(
            "Il est « en attente » : il devient gestionnaire quand il active "
            "son statut avec Google depuis ses Paramètres. D'ici là, il garde "
            "les droits d'un bénévole."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              style: TypeAction.gerer.plein,
              key: const Key('confirmer_nomination'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Nommer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.depot.nommerGestionnaire(widget.assoId, x.uid);
    } catch (_) {
      if (mounted) {
        setState(() => _erreurAutre = 'Changement impossible. Vérifiez le réseau.');
      }
    }
  }

  /// Note « Qui peut quoi » : les droits des trois rôles, repliable.
  Widget _quiPeutQuoi(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Palette.filet),
        ),
        child: ExpansionTile(
          key: const Key('qui_peut_quoi'),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text('Qui peut quoi',
              style: Theme.of(context).textTheme.titleMedium),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: const [
            Text(
              "Responsable : nomme et retire les gestionnaires, retire un membre, "
              "change le code d'accès et supprime l'association.\n"
              'Gestionnaire : gère les menus, les événements, le stock et les bilans '
              'des gymnases qui lui sont rattachés ; voit la liste des membres sans '
              'pouvoir la modifier.\n'
              'Bénévole : tient sa caisse et voit les événements en cours ; ne voit ni '
              'les menus ni la liste des membres.',
            ),
          ],
        ),
      );

  /// Carte réservée au responsable : suppression de l'association.
  Widget _sectionZone(BuildContext context) => StreamBuilder<Association?>(
        stream: widget.depot.suivreAssociation(widget.assoId),
        builder: (context, a) {
          final asso = a.data;
          if (asso == null) return const SizedBox.shrink();
          return _carte(
            context,
            titre: 'Zone dangereuse',
            danger: true,
            enfants: [
              if (_suppression)
                const Text('Suppression en cours…',
                    key: Key('suppression_en_cours'))
              else
                OutlinedButton(
                  key: const Key('supprimer_association'),
                  style: TypeAction.danger.contour,
                  onPressed: () => _supprimer(asso),
                  child: const Text("Supprimer l'association"),
                ),
              if (_erreurSuppression != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_erreurSuppression!,
                      key: const Key('erreur_suppression'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
            ],
          );
        },
      );

  Future<void> _activer() async {
    setState(() {
      _erreur = null;
      _occupe = true;
    });
    try {
      final ok = await connecterGoogle(widget.auth, widget.fournisseurGoogle);
      if (!ok) {
        _erreur = 'Connexion Google annulée.';
      } else if (widget.auth.currentUser?.uid != widget.uid) {
        // Ce compte Google était déjà relié à une autre identité.
        _erreur = 'Ce compte Google est déjà utilisé ailleurs. '
            'Utilisez un autre compte Google.';
      } else {
        await widget.depot.activerGestionnaire(widget.assoId, widget.uid);
      }
    } catch (_) {
      _erreur = 'Activation impossible. Vérifiez le réseau.';
    }
    if (mounted) setState(() => _occupe = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: StreamBuilder<List<Membre>>(
        stream: widget.depot.suivreMembres(widget.assoId),
        builder: (context, s) {
          final membres = s.data ?? const <Membre>[];
          final moi = membres.where((x) => x.uid == widget.uid).firstOrNull;
          if (moi == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final google = aGoogle(widget.auth.currentUser);
          final responsable = moi.estResponsable;
          // Liste des membres : responsable et gestionnaires actifs (pas les bénévoles).
          final voirMembres =
              responsable || (moi.role == 'gestionnaire' && !moi.enAttente);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _carte(
                context,
                titre: 'Mon compte',
                enfants: [
                  Text(moi.prenom,
                      key: const Key('mon_prenom'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Statut : ${libelleStatut(moi)}',
                      key: const Key('mon_statut')),
                  Text(
                      google ? 'Connexion Google : active' : 'Connexion Google : non',
                      key: const Key('ma_connexion')),
                  if (moi.enAttente) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Le responsable vous a nommé gestionnaire. Activez votre '
                      'connexion Google pour obtenir les droits de gestion.',
                      key: Key('invitation_gestionnaire'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('activer_gestionnaire'),
                      onPressed: _occupe ? null : _activer,
                      child: const Text('Activer avec Google'),
                    ),
                  ],
                  if (_erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_erreur!,
                          key: const Key('erreur_activation'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
              if (_erreurAutre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_erreurAutre!,
                      key: const Key('erreur_parametres'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              if (responsable) _sectionAssociation(context),
              if (voirMembres) _sectionMembres(context, membres, responsable),
              _quiPeutQuoi(context),
              if (responsable) _sectionZone(context),
            ],
          );
        },
      ),
    );
  }
}

/// L'association n'existe plus pour cet appareil (supprimée, ou membre retiré) :
/// on l'oublie et on revient à l'écran d'accueil.
class _Quitte extends StatefulWidget {
  const _Quitte({required this.depot, required this.uid});

  final DepotAssociations depot;
  final String uid;

  @override
  State<_Quitte> createState() => _EtatQuitte();
}

class _EtatQuitte extends State<_Quitte> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst); // ferme les écrans ouverts par-dessus
      try {
        await widget.depot.oublierAssociation(widget.uid);
      } catch (_) {
        // Sans réseau : on réessaiera au prochain lancement.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Cette association n'est plus accessible. Retour à l'accueil…",
                key: Key('association_disparue'), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Lance une action une seule fois, juste après l'affichage (ouverture de
/// l'événement d'un QR code scanné).
class _OuvreurLien extends StatefulWidget {
  const _OuvreurLien({super.key, required this.ouvrir});

  final Future<void> Function() ouvrir;

  @override
  State<_OuvreurLien> createState() => _EtatOuvreurLien();
}

class _EtatOuvreurLien extends State<_OuvreurLien> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.ouvrir();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
