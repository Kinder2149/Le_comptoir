import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'depot_associations.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart';
import 'ecran_bilan.dart';
import 'ecran_caisse.dart';
import 'ecran_gymnases.dart';
import 'ecran_menu.dart' show SelecteurPhoto, demanderImageProduit, selecteurPhotoReel;
import 'ecran_nouvel_evenement.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';
import 'ticket.dart';

/// Pastille « En cours » (vert) ou « Clôturé » (gris), visible d'un coup d'œil.
class PastilleEtat extends StatelessWidget {
  const PastilleEtat({super.key, required this.enCours});

  final bool enCours;

  @override
  Widget build(BuildContext context) {
    final texte = enCours ? Palette.saugeFonce : Palette.gris;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(enCours ? Icons.play_circle : Icons.lock, size: 18, color: texte),
      label: Text(enCours ? 'En cours' : 'Clôturé',
          style: TextStyle(color: texte, fontWeight: FontWeight.w700)),
      backgroundColor: enCours ? Palette.saugeDoux : Palette.sableDoux,
      side: BorderSide.none,
    );
  }
}

/// Détail d'un événement : date, modes de paiement, produits et prix copiés.
class EcranEvenement extends StatelessWidget {
  const EcranEvenement({
    super.key,
    required this.depot,
    required this.depotMenus,
    required this.evenementId,
    required this.peutModifier,
    required this.responsable,
    required this.membres,
    required this.codeAssociation,
    required this.uid,
    required this.prenom,
    this.gymnasePropose,
    this.selecteurPhoto = selecteurPhotoReel,
  });

  final DepotEvenements depot;
  final DepotMenus depotMenus;
  final String evenementId;
  final bool peutModifier;

  /// Responsable (gère tous les gymnases) ; sinon un gestionnaire ne gère que
  /// les gymnases auxquels il est rattaché.
  final bool responsable;
  final Stream<List<Membre>> membres;

  /// Le code d'accès actuel de l'association (QR codes à partager).
  final Stream<String> codeAssociation;
  final String uid;
  final String prenom;

  /// Gymnase d'un QR code qu'on vient de scanner : proposé en premier.
  final String? gymnasePropose;

  /// Choix d'une photo (remplaçable dans les tests).
  final SelecteurPhoto selecteurPhoto;

  Future<void> _changerImage(BuildContext context, ProduitEvenement p) async {
    final r = await demanderImageProduit(context,
        nom: p.nom,
        icone: p.icone,
        photo: p.photo,
        selecteurPhoto: selecteurPhoto);
    if (r == null) return;
    await depot.modifierImageProduit(evenementId, p.id,
        icone: r.icone, photo: r.photo);
  }

  /// Ouvre (ou reprend, ou rouvre) la caisse du membre dans [gymnase]. Si une
  /// caisse est ouverte dans un autre gymnase, on l'explique et on propose de la
  /// clôturer d'abord : jamais deux caisses ouvertes.
  Future<void> _ouvrirCaisse(
    BuildContext context,
    Evenement ev,
    Gymnase gymnase,
    String? ouverteId,
    Caisse? existante,
  ) async {
    final caisses = depot.caisses(ev.id);
    final id = idCaisse(uid, gymnase.id);
    if (ouverteId != null && ouverteId != id) {
      final ailleurs = RefCaisse.lire(ouverteId).gymnaseId;
      final nom =
          (await depot.suivreGymnases(ev.id).first)
              .where((g) => g.id == ailleurs)
              .map((g) => g.nom)
              .firstOrNull ??
          "l'autre gymnase";
      if (!context.mounted) return;
      final cloturer = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Une caisse est déjà ouverte'),
          content: Text(
            "Clôturez d'abord votre caisse à $nom, "
            'puis ouvrez-en une dans ${gymnase.nom}.',
            key: const Key('caisse_deja_ouverte'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Retour'),
            ),
            FilledButton(
              key: const Key('cloturer_caisse_precedente'),
              onPressed: () => Navigator.pop(c, true),
              child: Text('Clôturer ma caisse à $nom'),
            ),
          ],
        ),
      );
      if (cloturer == true && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => EcranCloture(
              caisseId: ouverteId,
              modes: ev.modes,
              depotCaisses: caisses,
            ),
          ),
        );
      }
      return;
    }
    if (existante == null) {
      await caisses.ouvrirCaisse(id, prenom);
    } else if (existante.cloturee) {
      caisses.rouvrirCaisse(id);
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcranCaisseEvenement(
          uid: uid,
          prenom: prenom,
          gymnase: gymnase,
          evenement: ev,
          depotEvenements: depot,
          depotCaisses: caisses,
        ),
      ),
    );
  }

  /// La gestion ouvre les ventes d'une caisse (pour annuler sous son nom).
  Future<void> _ouvrirVentesDe(
    BuildContext context,
    Evenement ev,
    Caisse caisse,
  ) async {
    final produits = await depot.suivreProduits(ev.id).first;
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EcranVentes(
          uid: uid,
          prenom: prenom,
          caisseId: caisse.id,
          titre: 'Ventes de ${caisse.prenom}',
          depotCaisses: depot.caisses(ev.id),
          stocks: () => {for (final p in produits) p.id: p.stock},
          onErreur: (_) {},
          verrouillee: !ev.enCours, // événement clôturé : figé
          peutCorriger: false,
        ),
      ),
    );
  }

  /// Clôture de l'événement ; forcée s'il reste des caisses non clôturées.
  Future<void> _cloturer(
    BuildContext context,
    Evenement ev,
    List<Caisse> caisses,
  ) async {
    final ouvertes = caisses.where((c) => !c.cloturee).toList();
    final forcee = ouvertes.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(forcee ? 'Forcer la clôture ?' : "Clôturer l'événement ?"),
        content: Text(
          forcee
              ? '${pluriel(ouvertes.length, 'caisse')} pas encore clôturée${accord(ouvertes.length)} : '
                    '${ouvertes.map((x) => x.prenom).join(', ')}. '
                    'Leurs ventes non envoyées seront signalées comme manquantes dans le bilan. '
                    'Cette clôture portera votre nom.'
              : "Toutes les caisses sont clôturées. L'événement ne sera plus modifiable.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const Key('confirmer_cloture_evenement'),
            style: (forcee ? TypeAction.danger : TypeAction.reussir).plein,
            onPressed: () => Navigator.pop(c, true),
            child: Text(forcee ? 'Forcer la clôture' : 'Clôturer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await depot.cloturerEvenement(
        ev.id,
        parUid: uid,
        parPrenom: prenom,
        nbCaissesOuvertes: ouvertes.length,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Clôture impossible. Vérifiez le réseau.',
              key: Key('erreur_cloture_evenement'),
            ),
          ),
        );
      }
    }
  }

  Widget _blocGestion(
    BuildContext context,
    Evenement ev,
    PorteeGestion portee,
  ) => _BlocGestion(
    depot: depot,
    evenement: ev,
    portee: portee,
    membres: membres,
    codeAssociation: codeAssociation,
    onOuvrirCaisse: (c) => _ouvrirVentesDe(context, ev, c),
    onCloturer: (caisses) => _cloturer(context, ev, caisses),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: depot.suivreEvenement(evenementId),
      builder: (context, e) {
        final ev = e.data;
        if (ev == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(ev.nom, key: const Key('titre_evenement')),
            actions: [
              if (peutModifier && ev.enCours)
                IconButton(
                  key: const Key('modifier_evenement'),
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EcranNouvelEvenement(
                        depot: depot,
                        depotMenus: depotMenus,
                        existant: ev,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Date : ${dateAffichee(ev.date)}',
                key: const Key('date_evenement'),
              ),
              Text('Menu : ${ev.menuNom}', key: const Key('menu_evenement')),
              Text(
                'Paiements : ${libelleModes(ev.modes)}',
                key: const Key('modes_evenement'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PastilleEtat(
                  key: const Key('etat_evenement'),
                  enCours: ev.enCours,
                ),
              ),
              if (!ev.enCours && ev.clotureLe != null)
                Text(
                  'Clôturé par ${ev.clotureParPrenom ?? '?'} le '
                  '${dateAffichee(dateIso(ev.clotureLe!))} à ${heureAffichee(ev.clotureLe!)}',
                  key: const Key('cloture_info'),
                ),
              if (!ev.enCours && ev.forcee)
                Text(
                  'Clôture forcée : ${pluriel(ev.nbCaissesOuvertes, 'caisse')} non clôturée${accord(ev.nbCaissesOuvertes)}. '
                  'Des ventes peuvent manquer.',
                  key: const Key('cloture_forcee'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (ev.enCours)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _BoutonsCaisse(
                    depot: depot,
                    evenementId: ev.id,
                    uid: uid,
                    proposeId: gymnasePropose,
                    onOuvrir: (g, ouverteId, existante) =>
                        _ouvrirCaisse(context, ev, g, ouverteId, existante),
                  ),
                ),
              if (peutModifier)
                if (responsable)
                  _blocGestion(
                    context,
                    ev,
                    PorteeGestion(
                      responsable: true,
                      gymnases: const {},
                      nbGymnases: ev.nbGymnases,
                    ),
                  )
                else
                  StreamBuilder<Set<String>>(
                    stream: depot.suivreMesGymnases(ev.id, uid),
                    builder: (context, g) {
                      final mes = g.data;
                      if (mes == null) return const SizedBox.shrink();
                      return _blocGestion(
                        context,
                        ev,
                        PorteeGestion(
                          responsable: false,
                          gymnases: mes,
                          nbGymnases: ev.nbGymnases,
                        ),
                      );
                    },
                  ),
              const Divider(height: 32),
              Text('Produits', style: Theme.of(context).textTheme.titleMedium),
              StreamBuilder<List<ProduitEvenement>>(
                stream: depot.suivreProduits(evenementId),
                builder: (context, s) {
                  final produits = s.data ?? const <ProduitEvenement>[];
                  return Column(
                    children: [
                      for (final p in produits)
                        ListTile(
                          key: Key('produit_evenement_${p.id}'),
                          leading: VignetteProduit(
                            key: Key('vignette_evenement_${p.id}'),
                            icone: p.icone,
                            photo: p.photo,
                          ),
                          title: Text(p.nom),
                          subtitle: Text(
                            formaterEuros(p.prixCentimes) +
                                (p.stock == null
                                    ? ''
                                    : ' · Stock : ${p.stock}'),
                          ),
                          // La gestion corrige l'image (pas le nom ni le prix).
                          trailing: peutModifier && ev.enCours
                              ? const Icon(Icons.image_outlined)
                              : null,
                          onTap: peutModifier && ev.enCours
                              ? () => _changerImage(context, p)
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Suivi, gymnases, bilan et clôture, limités à ce que le membre de la gestion a
/// le droit de voir. Les flux sont créés une fois (pas à chaque affichage).
class _BlocGestion extends StatefulWidget {
  const _BlocGestion({
    required this.depot,
    required this.evenement,
    required this.portee,
    required this.membres,
    required this.codeAssociation,
    required this.onOuvrirCaisse,
    required this.onCloturer,
  });

  final DepotEvenements depot;
  final Evenement evenement;
  final PorteeGestion portee;
  final Stream<List<Membre>> membres;
  final Stream<String> codeAssociation;
  final void Function(Caisse caisse) onOuvrirCaisse;
  final void Function(List<Caisse> caisses) onCloturer;

  @override
  State<_BlocGestion> createState() => _EtatBlocGestion();
}

/// Les flux d'un écran de suivi ou de bilan. Un flux Firestore n'« envoie » son
/// état qu'à l'abonnement : chaque écran (suivi, bilan) a donc les siens.
class _Flux {
  _Flux(this.tableau, this.produits, this.stocks, this.gymnases, this.caisses);

  final Stream<TableauDeBord> tableau;
  final Stream<List<ProduitEvenement>> produits;
  final Stream<Map<String, Map<String, int>>> stocks;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<Caisse>> caisses;
}

class _EtatBlocGestion extends State<_BlocGestion> {
  late _Flux _suivi;

  _Flux _creerFlux() {
    final filtre = widget.portee.filtre;
    final id = widget.evenement.id;
    final caisses = widget.depot.caisses(id);
    return _Flux(
      caisses.suivreTableauDeBord(gymnaseIds: filtre),
      widget.depot.suivreProduits(id, gymnases: filtre),
      widget.depot.suivreStocksParGymnase(id, gymnases: filtre),
      // Seuls les gymnases que ce membre gère apparaissent dans les vues.
      widget.depot
          .suivreGymnases(id)
          .map(
            (l) => [
              for (final g in l)
                if (widget.portee.gere(g.id)) g,
            ],
          ),
      caisses.suivreCaisses(gymnaseIds: filtre),
    );
  }

  void _abonner() => _suivi = _creerFlux();

  @override
  void initState() {
    super.initState();
    _abonner();
  }

  @override
  void didUpdateWidget(_BlocGestion ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.evenement.id != widget.evenement.id ||
        !setEquals(ancien.portee.filtre, widget.portee.filtre)) {
      _abonner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.evenement;
    final portee = widget.portee;
    if (portee.aucun) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 32),
          Text(
            'Aucun gymnase ne vous est rattaché : demandez au responsable de '
            'vous rattacher pour suivre les ventes.',
            key: const Key('aucun_gymnase_rattache'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        !portee.toutVoir
            ? const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Vue limitée à vos gymnases.',
                  key: Key('vue_limitee'),
                ),
              )
            : const SizedBox.shrink(),
        // Les accès (gymnases, bilan) passent AVANT le suivi, qui est long. Éléments
        // toujours présents (vides ou non) : le suivi garde sa place et son état.
        ev.enCours
            ? Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  key: const Key('voir_gymnases'),
                  style: TypeAction.gerer.contour,
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => EcranGymnases(
                        depot: widget.depot,
                        evenementId: ev.id,
                        portee: portee,
                        membres: widget.membres,
                        codeAssociation: widget.codeAssociation,
                      ),
                    ),
                  ),
                  child: const Text('Gymnases et stocks'),
                ),
              )
            : const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton(
            key: const Key('voir_bilan'),
            style: TypeAction.analyser.contour,
            onPressed: () {
              // Le bilan a ses propres flux, pas ceux du suivi.
              final flux = _creerFlux();
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => EcranBilan(
                    evenement: ev,
                    tableau: flux.tableau,
                    produits: flux.produits,
                    gymnases: flux.gymnases,
                    stocks: flux.stocks,
                    commun: portee.toutVoir,
                    limite: !portee.toutVoir,
                  ),
                ),
              );
            },
            child: const Text('Voir le bilan'),
          ),
        ),
        SuiviEnDirect(
          key: const Key('suivi_en_direct'),
          tableau: _suivi.tableau,
          produits: _suivi.produits,
          gymnases: _suivi.gymnases,
          stocks: _suivi.stocks,
          commun: portee.toutVoir,
          onOuvrirCaisse: widget.onOuvrirCaisse,
        ),
        if (ev.enCours && !portee.toutVoir)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              "Seul le responsable, ou un gestionnaire rattaché à tous les gymnases, "
              "peut clôturer l'événement.",
              key: Key('cloture_reservee'),
            ),
          ),
        if (ev.enCours && portee.toutVoir)
          StreamBuilder<List<Caisse>>(
            stream: _suivi.caisses,
            builder: (context, s) {
              final liste = s.data ?? const <Caisse>[];
              final ouvertes = liste.where((c) => !c.cloturee).length;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ouvertes == 0
                    ? FilledButton(
                        key: const Key('cloturer_evenement'),
                        style: TypeAction.reussir.plein,
                        onPressed: () => widget.onCloturer(liste),
                        child: const Text("Clôturer l'événement"),
                      )
                    : OutlinedButton(
                        key: const Key('cloturer_evenement'),
                        style: TypeAction.danger.contour,
                        onPressed: () => widget.onCloturer(liste),
                        child: const Text('Forcer la clôture'),
                      ),
              );
            },
          ),
      ],
    );
  }
}

/// Boutons d'ouverture de la caisse : un par gymnase (un seul bouton s'il n'y a
/// qu'un gymnase). Un événement créé avant les gymnases (ancien format) n'en a
/// pas : on l'explique au lieu de planter.
class _BoutonsCaisse extends StatelessWidget {
  const _BoutonsCaisse({
    required this.depot,
    required this.evenementId,
    required this.uid,
    required this.onOuvrir,
    this.proposeId,
  });

  final DepotEvenements depot;
  final String evenementId;
  final String uid;

  /// Gymnase d'un QR code scanné : mis en avant et placé en premier.
  final String? proposeId;

  /// [ouverteId] : la caisse déjà ouverte du membre (null = aucune) ;
  /// [existante] : sa caisse dans ce gymnase, si elle existe.
  final void Function(Gymnase gymnase, String? ouverteId, Caisse? existante)
  onOuvrir;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gymnase>>(
      stream: depot.suivreGymnases(evenementId),
      builder: (context, g) {
        final gymnases = g.data;
        if (gymnases == null) return const SizedBox.shrink();
        if (gymnases.isEmpty) {
          return Text(
            'Événement créé avant la mise à jour : recréez-le pour pouvoir '
            'ouvrir une caisse.',
            key: const Key('ancien_evenement'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        final caisses = depot.caisses(evenementId);
        // Le gymnase du QR code lu passe en premier.
        final ordonnes = [
          ...gymnases.where((x) => x.id == proposeId),
          ...gymnases.where((x) => x.id != proposeId),
        ];
        final propose = gymnases.where((x) => x.id == proposeId).firstOrNull;
        return StreamBuilder<String?>(
          stream: caisses.suivreCaisseOuverte(uid),
          builder: (context, o) {
            final ouverteId = o.data;
            final ouvert = ouverteId == null
                ? null
                : gymnases
                      .where((x) => x.id == RefCaisse.lire(ouverteId).gymnaseId)
                      .firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Des éléments toujours présents (vides ou non) : les boutons qui
                // suivent gardent leur place quand ils apparaissent ou disparaissent.
                gymnases.length > 1 && ouvert != null
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ma caisse : ${ouvert.nom} (ouverte)',
                          key: const Key('ma_caisse'),
                        ),
                      )
                    : const SizedBox.shrink(),
                propose == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'QR code lu : ${propose.nom}',
                          key: const Key('gymnase_scanne'),
                        ),
                      ),
                for (final gym in ordonnes)
                  StreamBuilder<Caisse?>(
                    key: Key('bouton_${gym.id}'),
                    stream: caisses.suivreCaisse(idCaisse(uid, gym.id)),
                    builder: (context, c) {
                      final existante = c.data;
                      final action = existante == null
                          ? 'Ouvrir ma caisse'
                          : existante.cloturee
                          ? 'Rouvrir ma caisse'
                          : 'Reprendre ma caisse';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton(
                          key: Key(
                            gymnases.length == 1
                                ? 'ouvrir_caisse_evenement'
                                : 'ouvrir_caisse_${gym.id}',
                          ),
                          onPressed: () => onOuvrir(gym, ouverteId, existante),
                          child: Text(
                            gymnases.length == 1
                                ? action
                                : '$action · ${gym.nom}',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Suivi en direct (gestion) : totaux, quantités vendues et stock par produit,
/// état et dernière activité de chaque caisse. Se met à jour tout seul.
class SuiviEnDirect extends StatefulWidget {
  const SuiviEnDirect({
    super.key,
    required this.tableau,
    required this.produits,
    required this.onOuvrirCaisse,
    this.gymnases,
    this.stocks,
    this.commun = true,
    this.maintenant = DateTime.now,
  });

  final Stream<TableauDeBord> tableau;
  final Stream<List<ProduitEvenement>> produits;
  final void Function(Caisse caisse) onOuvrirCaisse;

  /// Gymnases visibles et stock de chacun : avec eux (et plusieurs gymnases), un
  /// sélecteur propose la vue commune ou la vue d'un gymnase.
  final Stream<List<Gymnase>>? gymnases;
  final Stream<Map<String, Map<String, int>>>? stocks;

  /// La vue commune est-elle offerte (responsable, ou gestionnaire de tous) ?
  final bool commun;

  /// Horloge (remplaçable dans les tests).
  final DateTime Function() maintenant;

  @override
  State<SuiviEnDirect> createState() => _EtatSuivi();
}

class _EtatSuivi extends State<SuiviEnDirect> {
  Timer? _minuteur;
  String? _vue; // null = vue commune
  bool _choisie = false;

  @override
  void initState() {
    super.initState();
    // La « caisse silencieuse » se calcule avec l'heure : on réévalue.
    _minuteur = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gymnases == null) return _contenu(context, const [], null);
    return StreamBuilder<List<Gymnase>>(
      stream: widget.gymnases,
      builder: (context, g) => StreamBuilder<Map<String, Map<String, int>>>(
        stream: widget.stocks,
        builder: (context, s) => _contenu(context, g.data ?? const [], s.data),
      ),
    );
  }

  /// Stock restant d'un produit pour la vue choisie (le total en vue commune,
  /// avec le détail par gymnase quand plusieurs gymnases le suivent).
  String _texteStock(
    ProduitEvenement x,
    String? vue,
    Map<String, Map<String, int>>? stocks,
    List<Gymnase> gymnases,
  ) {
    if (stocks == null) return x.stock == null ? '' : ' · stock ${x.stock}';
    final concernes = vue == null ? stocks.keys.toList() : [vue];
    final detail = {
      for (final g in concernes)
        if (stocks[g]?[x.id] != null) g: stocks[g]![x.id]!,
    };
    if (detail.isEmpty) return '';
    final total = detail.values.fold<int>(0, (a, b) => a + b);
    final parGymnase = vue == null && detail.length > 1
        ? ' ${detailStockAffiche(detail, gymnases)}'
        : '';
    return ' · stock $total$parGymnase';
  }

  Widget _contenu(
    BuildContext context,
    List<Gymnase> gymnases,
    Map<String, Map<String, int>>? stocks,
  ) {
    final multiple = gymnases.length > 1;
    if (!_choisie ||
        !vueValide(_vue, commun: widget.commun, gymnases: gymnases)) {
      _vue = vueParDefaut(commun: widget.commun, gymnases: gymnases);
    }
    final vue = _vue;
    String nomGymnase(String id) =>
        gymnases.where((g) => g.id == id).firstOrNull?.nom ?? '?';
    return StreamBuilder<TableauDeBord>(
      stream: widget.tableau,
      builder: (context, t) {
        if (t.data == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Suivi en direct…', key: Key('direct_chargement')),
          );
        }
        final tab = t.data!.pour(vue);
        final maintenant = widget.maintenant();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suivi en direct',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // Toujours un élément à cet endroit (vide ou non) : les suivants gardent
            // leur place quand le sélecteur apparaît, donc leurs flux ne sont pas
            // réabonnés.
            multiple && gymnases.length + (widget.commun ? 1 : 0) >= 2
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelecteurVue(
                      gymnases: gymnases,
                      commun: widget.commun,
                      vue: vue,
                      onChanged: (v) => setState(() {
                        _vue = v;
                        _choisie = true;
                      }),
                    ),
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 4),
            Text(
              'Ventes : ${tab.nbVentes} · ${formaterEuros(tab.totalCentimes)}',
              key: const Key('direct_total'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            tab.nbAnnulees > 0
                ? Text(
                    'Ventes annulées : ${tab.nbAnnulees}',
                    key: const Key('direct_annulees'),
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 8),
            StreamBuilder<List<ProduitEvenement>>(
              key: const Key('produits_suivi'),
              stream: widget.produits,
              builder: (context, p) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final x in p.data ?? const <ProduitEvenement>[])
                    Text(
                      '${x.nom} : ${pluriel(tab.vendus(x.id), 'vendu')}'
                      '${_texteStock(x, vue, stocks, gymnases)}',
                      key: Key('direct_produit_${x.id}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Caisses', style: Theme.of(context).textTheme.titleSmall),
            tab.caisses.isEmpty
                ? const Text(
                    'Aucune caisse ouverte.',
                    key: Key('aucune_caisse'),
                  )
                : const SizedBox.shrink(),
            // Les cartes forment UN seul élément de la colonne : quand une caisse
            // disparaît d'une vue, les flux des éléments voisins ne sont pas réabonnés.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in tab.caisses)
                  Card(
                    key: Key('caisse_${r.caisse.id}'),
                    child: ListTile(
                      title: Text(r.caisse.prenom),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.caisse.cloturee ? 'Clôturée' : 'Ouverte'}'
                            ' · ${pluriel(r.recap.nbVentes, 'vente')}'
                            ' · ${formaterEuros(r.recap.totalCentimes)}',
                            key: Key('statut_caisse_${r.caisse.id}'),
                          ),
                          Text(
                            r.derniereVente == null
                                ? 'Aucune vente'
                                : 'Dernière vente à ${heureAffichee(r.derniereVente!)}',
                            key: Key('activite_${r.caisse.id}'),
                          ),
                          if (multiple)
                            Text(
                              nomGymnase(r.caisse.gymnaseId),
                              key: Key('gymnase_de_${r.caisse.id}'),
                            ),
                          if (r.silencieuse(maintenant))
                            Text(
                              'Pas de vente depuis '
                              '${dureeAffichee(maintenant.difference(r.derniereActivite!))}',
                              key: Key('silence_${r.caisse.id}'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOuvrirCaisse(r.caisse),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
