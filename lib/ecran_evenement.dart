import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import 'actualisation.dart';

import 'courses.dart';
import 'depot_associations.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart';
import 'ecran_bilan.dart';
import 'ecran_courses.dart';
import 'ecran_caisse.dart';
import 'ecran_gymnases.dart';
import 'ecran_menu.dart'
    show SelecteurPhoto, demanderImageProduit, demanderProduit, selecteurPhotoReel;
import 'ecran_nouvel_evenement.dart';
import 'ecran_classeur.dart';
import 'ecran_import.dart';
import 'ecran_personnes_duree.dart';
import 'ecran_prevision.dart';
import 'ecran_restes.dart';
import 'ecran_stock_depart.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'restes.dart';
import 'tableau_bord.dart';
import 'theme.dart';
import 'ticket.dart';

/// Pastille à trois états, visible d'un coup d'œil : « En préparation » (couleur
/// d'attention), « En cours » (vert) ou « Clôturé » (gris).
class PastilleEtat extends StatelessWidget {
  const PastilleEtat({super.key, required this.enCours, this.enPreparation = false});

  final bool enCours;
  final bool enPreparation;

  @override
  Widget build(BuildContext context) {
    final Color texte;
    final Color fond;
    final IconData icone;
    final String libelle;
    if (enPreparation) {
      texte = Palette.ocreFonce;
      fond = Palette.ocreDoux;
      icone = Icons.edit_calendar;
      libelle = 'En préparation';
    } else if (enCours) {
      texte = Palette.saugeFonce;
      fond = Palette.saugeDoux;
      icone = Icons.play_circle;
      libelle = 'En cours';
    } else {
      texte = Palette.gris;
      fond = Palette.sableDoux;
      icone = Icons.lock;
      libelle = 'Clôturé';
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icone, size: 18, color: texte),
      label: Text(libelle, style: TextStyle(color: texte, fontWeight: FontWeight.w700)),
      backgroundColor: fond,
      side: BorderSide.none,
    );
  }
}

/// Qui peut ouvrir un événement « en préparation » : comme pour la clôture, le
/// responsable ou un gestionnaire rattaché à tous les gymnases.
bool peutOuvrirEvenement(Evenement ev, PorteeGestion portee) =>
    ev.enPreparation && portee.toutVoir;

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
          verrouillee: ev.cloture, // événement clôturé : figé
          peutCorriger: false,
        ),
      ),
    );
  }

  /// Ouverture de l'événement (« en préparation » -> « en cours »), après confirmation.
  Future<void> _ouvrirEvenement(BuildContext context, Evenement ev) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Ouvrir l'événement ?"),
        content: const Text(
          "Les bénévoles verront l'événement et pourront ouvrir leur caisse. "
          'Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const Key('confirmer_ouverture_evenement'),
            style: TypeAction.reussir.plein,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await depot.ouvrirEvenement(ev.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ouverture impossible. Vérifiez le réseau.',
              key: Key('erreur_ouverture_evenement'),
            ),
          ),
        );
      }
    }
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
      // Produits à garder pour le prochain événement (décision 48) : seulement
      // ceux qui ont encore du stock.
      var gardes = const <Reste>[];
      var ecartes = const <String>[];
      final candidats = candidatsRestes(
        gymnases: await depot.suivreGymnases(ev.id).first,
        produits: await depot.suivreProduits(ev.id).first,
        stocks: await depot.suivreStocksParGymnase(ev.id).first,
      );
      if (candidats.isNotEmpty) {
        if (!context.mounted) return;
        final choix = await demanderRestes(context, candidats);
        if (choix == null) return;
        gardes = choix.gardes;
        ecartes = choix.ecartes;
      }
      await depot.cloturerEvenement(
        ev.id,
        parUid: uid,
        parPrenom: prenom,
        nbCaissesOuvertes: ouvertes.length,
        restes: gardes,
        ecartes: ecartes,
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
    depotMenus: depotMenus,
    uid: uid,
    evenement: ev,
    portee: portee,
    membres: membres,
    codeAssociation: codeAssociation,
    selecteurPhoto: selecteurPhoto,
    onOuvrirCaisse: (c) => _ouvrirVentesDe(context, ev, c),
    onCloturer: (caisses) => _cloturer(context, ev, caisses),
    onOuvrirEvenement: () => _ouvrirEvenement(context, ev),
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
              if (peutModifier && !ev.cloture)
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
          body: actualisable(
            relire: () async {
              Set<String>? gymnases;
              if (peutModifier && !responsable) {
                gymnases = await depot.suivreMesGymnases(ev.id, uid).first;
              }
              await depot.actualiser(ev.id,
                  gymnases: gymnases,
                  avecCaisses: peutModifier,
                  avecCourses: peutModifier && responsable);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                  enPreparation: ev.enPreparation,
                ),
              ),
              if (ev.cloture && ev.clotureLe != null)
                Text(
                  'Clôturé par ${ev.clotureParPrenom ?? '?'} le '
                  '${dateAffichee(dateIso(ev.clotureLe!))} à ${heureAffichee(ev.clotureLe!)}',
                  key: const Key('cloture_info'),
                ),
              if (ev.cloture && ev.forcee)
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
              // Le bénévole voit la liste des produits ici ; la gestion la trouve dans
              // « Produits et images » (tableau de bord).
              if (!peutModifier) ...[
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
                                      : ' · Stock : ${p.stock}') +
                                  resumeFiche(p.fiche),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
          ),
        );
      },
    );
  }
}

/// Le tableau de bord de la gestion (décision 62) : trois temps, Avant (préparer),
/// Pendant (suivre le tournoi) et Après (clôturer, bilan, export). Chaque temps lit ses
/// propres flux, créés quand on l'ouvre : un flux Firestore ne s'écoute qu'une fois.
class _BlocGestion extends StatefulWidget {
  const _BlocGestion({
    required this.depot,
    required this.depotMenus,
    required this.uid,
    required this.evenement,
    required this.portee,
    required this.membres,
    required this.codeAssociation,
    required this.selecteurPhoto,
    required this.onOuvrirCaisse,
    required this.onCloturer,
    required this.onOuvrirEvenement,
  });

  final DepotEvenements depot;
  final DepotMenus depotMenus;
  final String uid;
  final Evenement evenement;
  final PorteeGestion portee;
  final Stream<List<Membre>> membres;
  final Stream<String> codeAssociation;
  final SelecteurPhoto selecteurPhoto;
  final void Function(Caisse caisse) onOuvrirCaisse;
  final void Function(List<Caisse> caisses) onCloturer;
  final VoidCallback onOuvrirEvenement;

  @override
  State<_BlocGestion> createState() => _EtatBlocGestion();
}

/// Les flux d'un écran de suivi ou de bilan. Un flux Firestore n'« envoie » son
/// état qu'à l'abonnement : chaque écran (suivi, bilan) a donc les siens.
class _Flux {
  _Flux(this.tableau, this.produits, this.stocks, this.etats, this.gymnases,
      this.caisses, this.courses, this.stocksDepart);

  final Stream<TableauDeBord> tableau;
  final Stream<List<ProduitEvenement>> produits;
  final Stream<Map<String, Map<String, int>>> stocks;
  final Stream<Map<String, Map<String, EtatStock>>> etats;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<Caisse>> caisses;

  /// La liste de courses (coût au bilan) : seulement pour qui y a accès.
  final Stream<ListeCourses?>? courses;

  /// Le stock de départ (tâche « Stock de départ » d'Avant).
  final Stream<Map<String, Map<String, StockDepart>>> stocksDepart;
}

class _EtatBlocGestion extends State<_BlocGestion> {
  late _Flux _suivi;
  late OngletEvenement _onglet;

  _Flux _creerFlux() {
    final filtre = widget.portee.filtre;
    final id = widget.evenement.id;
    final caisses = widget.depot.caisses(id);
    return _Flux(
      caisses.suivreTableauDeBord(gymnaseIds: filtre),
      widget.depot.suivreProduits(id, gymnases: filtre),
      widget.depot.suivreStocksParGymnase(id, gymnases: filtre),
      widget.depot.suivreEtats(id, gymnases: filtre),
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
      widget.portee.toutVoir ? widget.depot.suivreListeCourses(id) : null,
      widget.depot.suivreStocksDepart(id, gymnases: filtre),
    );
  }

  void _abonner() => _suivi = _creerFlux();

  /// Changer d'onglet relit les flux (un onglet ouvert reçoit des flux neufs).
  void _ouvrirOnglet(OngletEvenement o) => setState(() {
        _onglet = o;
        _suivi = _creerFlux();
      });

  /// Personnes et durée : son écran court, ouvert par la tâche d'Avant (et par les courses).
  void _ouvrirPersonnes(BuildContext context, Evenement ev, PorteeGestion portee) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranPersonnesDuree(
            evenement: widget.depot.suivreEvenement(ev.id),
            portee: portee,
            gymnases: widget.depot.suivreGymnases(ev.id),
            definirJours: (j) => widget.depot.definirJours(ev.id, j),
            definirPersonnes: (g, n) =>
                widget.depot.definirPersonnes(ev.id, g, n),
          ),
        ),
      );

  /// Prévision : son écran, ouvert par la tâche d'Avant.
  void _ouvrirPrevision(BuildContext context, Evenement ev, PorteeGestion portee) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranPrevision(
            evenement: widget.depot.suivreEvenement(ev.id),
            portee: portee,
            gymnases: widget.depot.suivreGymnases(ev.id),
            produits: widget.depot.suivreProduits(ev.id),
            previsions: widget.depot.suivrePrevisions(ev.id),
            definirPrevision: (p, c) => widget.depot.definirPrevision(ev.id, p, c),
            chargerPasses: () => widget.depot.evenementsPasses(sauf: ev.id),
            appliquerPasse: (r) => widget.depot.appliquerEvenementPasse(ev.id, r),
            revenirAuMenu: () => widget.depot.revenirAuMenu(ev.id),
            chargerReferences: widget.depot.lireReferences,
            appliquerReference: (r) => widget.depot.appliquerReference(ev.id, r),
            definirPrevisionVerifiee: (v) =>
                widget.depot.definirPrevisionVerifiee(ev.id, v),
            onVoirCourses: portee.toutVoir
                ? () => _ouvrirCourses(context, ev, portee)
                : null,
          ),
        ),
      );

  /// Classeur Excel : le modèle à télécharger et le classeur rempli à importer.
  void _ouvrirClasseur(BuildContext context, Evenement ev, PorteeGestion portee) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranClasseur(
            evenement: widget.depot.suivreEvenement(ev.id),
            portee: portee,
            gymnases: widget.depot.suivreGymnases(ev.id),
            produits: widget.depot.suivreProduits(ev.id),
            stocks:
                widget.depot.suivreStocksDepart(ev.id, gymnases: portee.filtre),
            assistant: (_) => EcranImport(
              sources: SourcesImport.depuis(
                menus: widget.depotMenus,
                evenements: widget.depot,
                uid: widget.uid,
                responsable: portee.responsable,
              ),
              evenementId: ev.id,
              menuPropose: ev.menuNom,
            ),
          ),
        ),
      );

  /// Stock de départ : son écran (un onglet par gymnase), ouvert par la tâche d'Avant.
  void _ouvrirStockDepart(BuildContext context, Evenement ev, PorteeGestion portee) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranStockDepart(
            evenement: widget.depot.suivreEvenement(ev.id),
            portee: portee,
            gymnases: widget.depot.suivreGymnases(ev.id),
            produits: widget.depot.suivreProduits(ev.id),
            stocks:
                widget.depot.suivreStocksDepart(ev.id, gymnases: portee.filtre),
            definirStock: (g, p, q) => widget.depot.definirStock(ev.id, g, p, q),
            onVoirGymnases: () => _voirGymnases(context, ev, portee),
          ),
        ),
      );

  void _voirGymnases(BuildContext context, Evenement ev, PorteeGestion portee) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranGymnases(
            depot: widget.depot,
            evenementId: ev.id,
            evenementNom: ev.nom,
            portee: portee,
            membres: widget.membres,
            codeAssociation: widget.codeAssociation,
          ),
        ),
      );

  void _ouvrirProduits(BuildContext context, Evenement ev) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranProduitsEvenement(
            depot: widget.depot,
            evenementId: ev.id,
            modifiable: !ev.cloture,
            selecteurPhoto: widget.selecteurPhoto,
          ),
        ),
      );

  void _ouvrirCourses(BuildContext context, Evenement ev, PorteeGestion portee) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EcranCourses(
            depot: widget.depot,
            evenementId: ev.id,
            onAllerPreparation: () async => _ouvrirPersonnes(context, ev, portee),
          ),
        ),
      );

  /// Caisses en direct : le suivi (totaux, produits, caisses) sur son propre écran.
  void _ouvrirCaisses(BuildContext context, PorteeGestion portee) {
    final flux = _creerFlux();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Caisses en direct')),
          body: actualisable(
            relire: () => widget.depot.actualiser(widget.evenement.id, gymnases: portee.filtre),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SuiviEnDirect(
                key: const Key('suivi_en_direct'),
                tableau: flux.tableau,
                produits: flux.produits,
                gymnases: flux.gymnases,
                stocks: flux.stocks,
                etats: flux.etats,
                commun: portee.toutVoir,
                onOuvrirCaisse: widget.onOuvrirCaisse,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _ouvrirBilan(BuildContext context, Evenement ev, PorteeGestion portee) {
    // Le bilan a ses propres flux, pas ceux du suivi.
    final flux = _creerFlux();
    final evenementEnDirect = widget.depot.suivreEvenement(ev.id);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EcranBilan(
          evenement: ev,
          evenementEnDirect: evenementEnDirect,
          actualiser: () => widget.depot.actualiser(ev.id,
              gymnases: portee.filtre,
              avecCourses: portee.toutVoir,
              avecApports: true),
          tableau: flux.tableau,
          produits: flux.produits,
          gymnases: flux.gymnases,
          stocks: flux.stocks,
          stocksReference: widget.depot
              .suivreStocksReference(ev.id, gymnases: portee.filtre),
          courses: flux.courses,
          apports: widget.depot.suivreApports(ev.id),
          commun: portee.toutVoir,
          limite: !portee.toutVoir,
        ),
      ),
    );
  }

  /// Ajoute au stock d'un produit suivi (même écriture que « Ajouter » dans Gymnases et stocks).
  Future<void> _ajouterStock(BuildContext context, Evenement ev, ASurveiller x) async {
    final n = await showDialog<int>(
      context: context,
      builder: (_) => DialogueNombre(titre: 'Ajouter au stock de ${x.nomProduit}'),
    );
    if (n == null) return;
    try {
      await widget.depot.reapprovisionner(ev.id, x.gymnaseId, x.produitId, n);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ajout impossible. Vérifiez le réseau.',
              key: Key('erreur_ajout_stock'),
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _onglet = ongletInitial(widget.evenement);
    _abonner();
  }

  @override
  void didUpdateWidget(_BlocGestion ancien) {
    super.didUpdateWidget(ancien);
    // Ouvrir l'événement (préparation -> en cours) ou le clôturer change le temps affiché.
    final statutChange = ancien.evenement.statut != widget.evenement.statut;
    if (statutChange) _onglet = ongletInitial(widget.evenement);
    if (statutChange ||
        ancien.evenement.id != widget.evenement.id ||
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
        SegmentedButton<OngletEvenement>(
          key: const Key('onglets_evenement'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: OngletEvenement.avant,
              label: Text('Avant', key: Key('onglet_avant')),
            ),
            ButtonSegment(
              value: OngletEvenement.pendant,
              label: Text('Pendant', key: Key('onglet_pendant')),
            ),
            ButtonSegment(
              value: OngletEvenement.apres,
              label: Text('Après', key: Key('onglet_apres')),
            ),
          ],
          selected: {_onglet},
          onSelectionChanged: (s) {
            if (s.first != _onglet) _ouvrirOnglet(s.first);
          },
        ),
        const SizedBox(height: 12),
        switch (_onglet) {
          OngletEvenement.avant => _avant(context, ev, portee),
          OngletEvenement.pendant => _pendant(context, ev, portee),
          OngletEvenement.apres => _apres(context, ev, portee),
        },
      ],
    );
  }

  // ---------- Avant : préparer le tournoi ----------

  Widget _avant(BuildContext context, Evenement ev, PorteeGestion portee) {
    final courses = _suivi.courses;
    return StreamBuilder<List<Gymnase>>(
      stream: _suivi.gymnases,
      builder: (context, g) => StreamBuilder<Map<String, Map<String, StockDepart>>>(
        stream: _suivi.stocksDepart,
        builder: (context, s) {
          if (g.connectionState == ConnectionState.waiting ||
              s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final gymnases = g.data ?? const <Gymnase>[];
          final stocks = s.data ?? const <String, Map<String, StockDepart>>{};
          if (courses == null) {
            return _contenuAvant(context, ev, portee, gymnases, stocks, null);
          }
          return StreamBuilder<ListeCourses?>(
            stream: courses,
            builder: (context, c) => c.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : _contenuAvant(context, ev, portee, gymnases, stocks,
                    c.data?.seriesValidees ?? 0),
          );
        },
      ),
    );
  }

  Widget _contenuAvant(
    BuildContext context,
    Evenement ev,
    PorteeGestion portee,
    List<Gymnase> gymnases,
    Map<String, Map<String, StockDepart>> stocks,
    int? series,
  ) {
    final taches = tachesAvant(
      ev: ev,
      gymnases: gymnases,
      stocksDepart: stocks,
      seriesValidees: series,
    );
    final faites = taches.where((t) => t.faite).length;
    final par = {for (final t in taches) t.cle: t};
    // Une tâche ouvre son écran ; la clé du bouton reste celle de l'écran qu'elle ouvre.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Préparer le tournoi',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text('$faites sur ${taches.length} faits', key: const Key('avancement_avant')),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          key: const Key('progression_avant'),
          value: faites / taches.length,
        ),
        const SizedBox(height: 12),
        _ligneTache(
          par['stock']!,
          cle: const Key('voir_preparation'),
          surClic: () => _ouvrirStockDepart(context, ev, portee),
        ),
        _ligneTache(
          par['personnes']!,
          cle: const Key('tache_personnes'),
          surClic: () => _ouvrirPersonnes(context, ev, portee),
        ),
        _ligneTache(
          par['prevision']!,
          cle: const Key('tache_prevision'),
          surClic: () => _ouvrirPrevision(context, ev, portee),
        ),
        _ligneTache(
          par['courses']!,
          cle: portee.toutVoir ? const Key('voir_courses') : const Key('tache_courses'),
          surClic: portee.toutVoir ? () => _ouvrirCourses(context, ev, portee) : null,
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: const ListTile(
            key: Key('tache_materiel'),
            leading: Icon(Icons.build_outlined),
            title: Text('Matériel'),
            subtitle: Text('Bientôt'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('voir_produits'),
          style: TypeAction.gerer.contour,
          onPressed: () => _ouvrirProduits(context, ev),
          child: const Text('Produits et images'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('voir_gymnases'),
          style: TypeAction.gerer.contour,
          onPressed: () => _voirGymnases(context, ev, portee),
          child: const Text('Gymnases et stocks'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('ouvrir_classeur'),
          style: TypeAction.gerer.contour,
          onPressed: () => _ouvrirClasseur(context, ev, portee),
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Excel'),
        ),
        if (peutOuvrirEvenement(ev, portee)) ...[
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('ouvrir_evenement'),
            style: TypeAction.reussir.plein,
            onPressed: widget.onOuvrirEvenement,
            child: const Text('Ouvrir le tournoi aux bénévoles'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Les bénévoles ne voient pas encore ce tournoi.',
            key: Key('ouverture_info'),
            textAlign: TextAlign.center,
          ),
        ],
        if (ev.enPreparation && !portee.toutVoir)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              "Seul le responsable, ou un gestionnaire rattaché à tous les gymnases, "
              "peut ouvrir l'événement.",
              key: Key('ouverture_reservee'),
            ),
          ),
      ],
    );
  }

  /// Une tâche d'Avant : une coche (faite ou non), son titre et ce qu'on y lit.
  Widget _ligneTache(TacheAvant t, {required Key cle, VoidCallback? surClic}) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          key: cle,
          leading: Icon(
            t.faite ? Icons.check_circle : Icons.radio_button_unchecked,
            color: t.faite ? Palette.saugeFonce : Palette.gris,
          ),
          title: Text(t.titre),
          subtitle: Text(t.detail, key: Key('detail_${t.cle}')),
          trailing: surClic == null ? null : const Icon(Icons.chevron_right),
          onTap: surClic,
        ),
      );

  // ---------- Pendant : suivre le tournoi ----------

  Widget _pendant(BuildContext context, Evenement ev, PorteeGestion portee) {
    if (ev.enPreparation) {
      return const Text(
        "Le tournoi n'est pas encore ouvert : ses chiffres apparaissent à l'ouverture.",
        key: Key('pendant_attente'),
      );
    }
    if (ev.cloture) {
      return const Text(
        'Le tournoi est clôturé : voir l’onglet Après.',
        key: Key('pendant_cloture'),
      );
    }
    return StreamBuilder<TableauDeBord>(
      stream: _suivi.tableau,
      builder: (context, t) {
        final tableau = t.data;
        if (tableau == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final ouvertes = tableau.caisses.where((r) => !r.caisse.cloturee).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chiffres du jour',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Ventes : ${tableau.nbVentes} · ${formaterEuros(tableau.totalCentimes)}',
              key: const Key('pendant_total'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Caisses ouvertes : $ouvertes',
              key: const Key('pendant_caisses'),
            ),
            const SizedBox(height: 16),
            _aSurveiller(context, ev),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('voir_gymnases'),
              style: TypeAction.gerer.contour,
              onPressed: () => _voirGymnases(context, ev, portee),
              child: const Text('Stock'),
            ),
            const SizedBox(height: 8),
            if (portee.toutVoir) ...[
              OutlinedButton(
                key: const Key('voir_courses'),
                style: TypeAction.gerer.contour,
                onPressed: () => _ouvrirCourses(context, ev, portee),
                child: const Text("Courses d'appoint"),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              key: const Key('voir_caisses'),
              style: TypeAction.gerer.contour,
              onPressed: () => _ouvrirCaisses(context, portee),
              child: const Text('Caisses en direct'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('voir_bilan'),
              style: TypeAction.analyser.contour,
              onPressed: () => _ouvrirBilan(context, ev, portee),
              child: const Text('Bilan provisoire'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('voir_produits'),
              style: TypeAction.gerer.contour,
              onPressed: () => _ouvrirProduits(context, ev),
              child: const Text('Produits et images'),
            ),
            if (ev.enCours && !portee.toutVoir)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  "Seul le responsable, ou un gestionnaire rattaché à tous les "
                  "gymnases, peut clôturer l'événement.",
                  key: Key('cloture_reservee'),
                ),
              ),
            if (ev.enCours && portee.toutVoir)
              StreamBuilder<List<Caisse>>(
                stream: _suivi.caisses,
                builder: (context, s) {
                  final liste = s.data ?? const <Caisse>[];
                  final ouvertesCaisses = liste.where((c) => !c.cloturee).length;
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ouvertesCaisses == 0
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
      },
    );
  }

  /// « À surveiller » : produits épuisés, vides ou à stock bas, avec un « + » pour ajouter.
  Widget _aSurveiller(BuildContext context, Evenement ev) {
    return StreamBuilder<List<ProduitEvenement>>(
      stream: _suivi.produits,
      builder: (context, p) => StreamBuilder<Map<String, Map<String, EtatStock>>>(
        stream: _suivi.etats,
        builder: (context, e) => StreamBuilder<List<Gymnase>>(
          stream: _suivi.gymnases,
          builder: (context, g) {
            final produits = p.data;
            final etats = e.data;
            final gymnases = g.data;
            if (produits == null || etats == null || gymnases == null) {
              return const SizedBox.shrink();
            }
            final liste = aSurveiller(
              produits: produits,
              gymnases: gymnases,
              etats: etats,
            );
            final plusieurs = gymnases.length > 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'À surveiller',
                  key: const Key('titre_a_surveiller'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (liste.isEmpty)
                  const Text(
                    'Rien à surveiller pour l’instant.',
                    key: Key('rien_a_surveiller'),
                  ),
                for (final x in liste)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      key: Key('surveiller_${x.gymnaseId}_${x.produitId}'),
                      title: Text(x.nomProduit),
                      subtitle: Text(
                        plusieurs
                            ? '${x.nomGymnase} · ${_libelleEtat(x.etat)}'
                            : _libelleEtat(x.etat),
                        style: TextStyle(
                          color: couleurEtat(x.etat),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton.filledTonal(
                        key: Key('ajout_surveiller_${x.gymnaseId}_${x.produitId}'),
                        tooltip: 'Ajouter au stock',
                        icon: const Icon(Icons.add),
                        onPressed: () => _ajouterStock(context, ev, x),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _libelleEtat(EtatStock e) => switch (e) {
        EtatStock.epuise => 'Épuisé',
        EtatStock.vide => 'Vide',
        _ => 'Stock bas',
      };

  // ---------- Après : clôture, bilan, export ----------

  Widget _apres(BuildContext context, Evenement ev, PorteeGestion portee) {
    if (ev.enPreparation) {
      return const Text(
        "Le bilan et l'export apparaissent une fois le tournoi ouvert.",
        key: Key('apres_attente'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ev.cloture
              ? 'Tournoi clôturé. Le bilan et l’export Excel sont ci-dessous.'
              : 'Tournoi en cours : la clôture se fait dans l’onglet Pendant.',
          key: const Key('apres_etat'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('voir_bilan'),
          style: TypeAction.analyser.contour,
          onPressed: () => _ouvrirBilan(context, ev, portee),
          child: Text(ev.cloture ? 'Voir le bilan et exporter' : 'Voir le bilan provisoire'),
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
    this.etats,
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

  /// Rupture, stock bas et « vide » de chaque gymnase.
  final Stream<Map<String, Map<String, EtatStock>>>? etats;

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
    if (widget.gymnases == null) return _contenu(context, const [], null, null);
    return StreamBuilder<List<Gymnase>>(
      stream: widget.gymnases,
      builder: (context, g) => StreamBuilder<Map<String, Map<String, int>>>(
        stream: widget.stocks,
        builder: (context, s) =>
            StreamBuilder<Map<String, Map<String, EtatStock>>>(
          stream: widget.etats,
          builder: (context, e) =>
              _contenu(context, g.data ?? const [], s.data, e.data),
        ),
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

  /// Signal « Épuisé », « Vide » ou « Stock bas » d'un produit pour la vue
  /// choisie, avec les gymnases concernés quand la vue est commune.
  ({String texte, EtatStock pire})? _signal(
    ProduitEvenement x,
    String? vue,
    Map<String, Map<String, EtatStock>>? etats,
    List<Gymnase> gymnases,
  ) {
    if (etats == null) return null;
    final concernes = vue == null ? etats.keys.toList() : [vue];
    final parts = <String>[];
    EtatStock? pire;
    for (final etat in [EtatStock.epuise, EtatStock.vide, EtatStock.bas]) {
      final noms = [
        for (final g in concernes)
          if (etats[g]?[x.id] == etat)
            gymnases.where((y) => y.id == g).firstOrNull?.nom ?? '?',
      ];
      if (noms.isEmpty) continue;
      pire ??= etat;
      final libelle = switch (etat) {
        EtatStock.epuise => 'Épuisé',
        EtatStock.vide => 'Vide',
        _ => 'Stock bas',
      };
      parts.add(vue == null && gymnases.length > 1
          ? '$libelle : ${noms.join(', ')}'
          : libelle);
    }
    return pire == null ? null : (texte: parts.join(' · '), pire: pire);
  }

  Widget _contenu(
    BuildContext context,
    List<Gymnase> gymnases,
    Map<String, Map<String, int>>? stocks,
    Map<String, Map<String, EtatStock>>? etats,
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
                  for (final x in p.data ?? const <ProduitEvenement>[]) ...[
                    Text(
                      '${x.nom} : ${pluriel(tab.vendus(x.id), 'vendu')}'
                      '${_texteStock(x, vue, stocks, gymnases)}',
                      key: Key('direct_produit_${x.id}'),
                    ),
                    if (_signal(x, vue, etats, gymnases) case final s?)
                      Text(
                        s.texte,
                        key: Key('direct_signal_${x.id}'),
                        style: TextStyle(
                          color: couleurEtat(s.pire),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
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

/// « Produits et images » (gestion, décision 61) : la liste des produits de l'événement,
/// la correction de leur image et, tant que l'événement n'est pas clôturé, l'ajout d'un
/// produit (décision 78). Le nom et le prix d'un produit déjà là ne changent pas.
class EcranProduitsEvenement extends StatelessWidget {
  const EcranProduitsEvenement({
    super.key,
    required this.depot,
    required this.evenementId,
    required this.modifiable,
    this.selecteurPhoto = selecteurPhotoReel,
  });

  final DepotEvenements depot;
  final String evenementId;

  /// Faux une fois l'événement clôturé : la liste se lit seulement.
  final bool modifiable;

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

  Future<void> _ajouter(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    final r = await demanderProduit(context, selecteurPhoto: selecteurPhoto);
    if (r == null) return;
    String message;
    try {
      final res = await depot.ajouterProduit(evenementId,
          nom: r.nom,
          prixCentimes: r.prixCentimes,
          icone: r.icone,
          photo: r.photo,
          fiche: r.fiche);
      message = res.auMenu
          ? "« ${r.nom} » est ajouté à l'événement et au menu."
          : "« ${r.nom} » est ajouté à l'événement seulement : le menu d'origine "
              "est introuvable ou complet.";
    } on ProduitDejaPresent {
      message = 'Un produit « ${r.nom} » existe déjà dans cet événement.';
    } on FirebaseException {
      message = "Le produit n'a pas pu être ajouté. Réessayez.";
    }
    messager.showSnackBar(SnackBar(
      key: const Key('message_ajout_produit'),
      content: Text(message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produits et images')),
      body: StreamBuilder<List<ProduitEvenement>>(
        stream: depot.suivreProduits(evenementId),
        builder: (context, s) {
          final produits = s.data;
          if (produits == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListeProduitsEvenement(
            produits: produits,
            modifiable: modifiable,
            onAjouter: () => _ajouter(context),
            onImage: (p) => _changerImage(context, p),
          );
        },
      ),
    );
  }
}

/// La liste de « Produits et images », sans accès à la base : testable seule.
/// Le bouton « Ajouter un produit » n'existe que si [modifiable] (événement non clôturé).
class ListeProduitsEvenement extends StatelessWidget {
  const ListeProduitsEvenement({
    super.key,
    required this.produits,
    required this.modifiable,
    required this.onAjouter,
    required this.onImage,
  });

  final List<ProduitEvenement> produits;
  final bool modifiable;
  final VoidCallback onAjouter;
  final void Function(ProduitEvenement produit) onImage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          modifiable
              ? 'Touchez un produit pour corriger son image. Son nom et son '
                  'prix ne changent pas.'
              : "L'événement est clôturé : les images se lisent seulement.",
          key: const Key('aide_produits'),
        ),
        if (modifiable) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('ajouter_produit_evenement'),
              onPressed: onAjouter,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un produit'),
            ),
          ),
        ],
        const SizedBox(height: 8),
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
                  (p.stock == null ? '' : ' · Stock : ${p.stock}') +
                  resumeFiche(p.fiche),
            ),
            trailing: modifiable ? const Icon(Icons.image_outlined) : null,
            onTap: modifiable ? () => onImage(p) : null,
          ),
      ],
    );
  }
}
