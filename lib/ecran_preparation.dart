import 'dart:async';

import 'package:flutter/material.dart';

import 'courses.dart' show demiJournee, joursMax, personnesMax;
import 'ecran_caisse.dart' show VignetteProduit;
import 'evenement.dart';
import 'gymnase.dart';
import 'previsions.dart';
import 'theme.dart';

/// Préparation d'un événement (gestion). Étape 1 : le stock de départ, par gymnase et
/// par produit fini (jamais d'ingrédient : ils n'ont pas de stock). La saisie écrit
/// le même stock que « Gymnases et stocks ». Une fois l'événement ouvert, le stock de
/// départ se lit seulement et renvoie vers « Gymnases et stocks ».
class EcranPreparation extends StatelessWidget {
  const EcranPreparation({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.produits,
    required this.stocks,
    required this.definirStock,
    required this.definirJours,
    required this.definirPersonnes,
    required this.onVoirGymnases,
    required this.previsions,
    required this.definirPrevision,
    required this.chargerPasses,
    required this.appliquerPasse,
    required this.revenirAuMenu,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<ProduitEvenement>> produits;

  /// Stock de départ : gymnase -> produit -> quantité (et marque « repris »).
  final Stream<Map<String, Map<String, StockDepart>>> stocks;

  /// Fixe la quantité d'un produit dans un gymnase (efface la marque « repris »).
  final Future<void> Function(String gymnaseId, String produitId, int quantite)
      definirStock;
  final VoidCallback onVoirGymnases;

  /// Étape 2 : durée de l'événement (jours) et personnes attendues par gymnase.
  final Future<void> Function(double jours) definirJours;
  final Future<void> Function(String gymnaseId, int personnes) definirPersonnes;

  /// Étape 3 : prévision de consommation (produit -> chiffre et source). Écrite et lue
  /// par ceux qui ont accès à tout l'événement ; les autres ne voient qu'une phrase.
  final Stream<Map<String, Prevision>> previsions;
  final Future<void> Function(String produitId, double conso) definirPrevision;

  /// Les événements passés proposés comme source, et l'application de l'un d'eux
  /// (lève [LectureRefusee] si ses ventes ne sont pas lisibles : rien n'est écrit).
  final Future<EvenementsPasses> Function() chargerPasses;
  final Future<void> Function(ReferencePassee passe) appliquerPasse;
  final Future<void> Function() revenirAuMenu;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: evenement,
      builder: (context, sEv) => StreamBuilder<List<Gymnase>>(
        stream: gymnases,
        builder: (context, sG) => StreamBuilder<List<ProduitEvenement>>(
          stream: produits,
          builder: (context, sP) =>
              StreamBuilder<Map<String, Map<String, StockDepart>>>(
            stream: stocks,
            builder: (context, sS) {
              final ev = sEv.data;
              final tous = sG.data;
              final liste = sP.data;
              final stock = sS.data;
              final charge =
                  ev != null && tous != null && liste != null && stock != null;
              final modifiable = ev?.enPreparation ?? false;
              return Scaffold(
                appBar: AppBar(title: const Text('Préparation')),
                body: !charge
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text('Étape 1 · Stock de départ',
                              key: const Key('titre_etape_stock'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            modifiable
                                ? 'Combien de produits y a-t-il dans chaque gymnase '
                                    'au départ ? Un produit sans quantité n\'est pas '
                                    'suivi.'
                                : 'L\'événement est ouvert : le stock de départ se lit '
                                    'seulement. Il se corrige dans « Gymnases et '
                                    'stocks ».',
                            key: const Key('aide_stock_depart'),
                          ),
                          if (!modifiable)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: OutlinedButton(
                                key: const Key('aller_gymnases_stocks'),
                                style: TypeAction.gerer.contour,
                                onPressed: onVoirGymnases,
                                child: const Text('Voir Gymnases et stocks'),
                              ),
                            ),
                          const SizedBox(height: 12),
                          for (final g in tous.where((x) => portee.gere(x.id)))
                            _CarteDepart(
                              key: Key('depart_gymnase_${g.id}'),
                              gymnase: g,
                              produits: liste,
                              stocks: stock[g.id] ?? const {},
                              modifiable: modifiable,
                              definirStock: definirStock,
                            ),
                          const Divider(height: 32),
                          _EtapePersonnes(
                            evenement: ev,
                            gymnases: [
                              for (final g in tous)
                                if (portee.gere(g.id)) g
                            ],
                            reglable: portee.toutVoir && !ev.cloture,
                            definirJours: definirJours,
                            definirPersonnes: definirPersonnes,
                          ),
                          const Divider(height: 32),
                          _EtapePrevision(
                            evenement: ev,
                            produits: liste,
                            voit: portee.toutVoir,
                            reglable: portee.toutVoir && !ev.cloture,
                            previsions: previsions,
                            definirPrevision: definirPrevision,
                            chargerPasses: chargerPasses,
                            appliquerPasse: appliquerPasse,
                            revenirAuMenu: revenirAuMenu,
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CarteDepart extends StatelessWidget {
  const _CarteDepart({
    super.key,
    required this.gymnase,
    required this.produits,
    required this.stocks,
    required this.modifiable,
    required this.definirStock,
  });

  final Gymnase gymnase;
  final List<ProduitEvenement> produits;
  final Map<String, StockDepart> stocks;
  final bool modifiable;
  final Future<void> Function(String gymnaseId, String produitId, int quantite)
      definirStock;

  @override
  Widget build(BuildContext context) {
    final g = gymnase.id;
    final nonSuivis = [for (final p in produits) if (!stocks.containsKey(p.id)) p];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(gymnase.nom,
                key: Key('nom_depart_$g'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (modifiable && nonSuivis.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: Key('suivre_tous_depart_$g'),
                  style: TypeAction.gerer.contour,
                  onPressed: () async {
                    try {
                      for (final p in nonSuivis) {
                        await definirStock(g, p.id, 0);
                      }
                    } catch (_) {
                      if (context.mounted) _montrerErreur(context);
                    }
                  },
                  child: const Text('Suivre tous les produits'),
                ),
              ),
            for (final p in produits)
              _LigneDepart(
                key: Key('ligne_depart_${g}_${p.id}'),
                gymnaseId: g,
                produit: p,
                stock: stocks[p.id],
                modifiable: modifiable,
                definirStock: definirStock,
              ),
          ],
        ),
      ),
    );
  }
}

void _montrerErreur(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Enregistrement impossible. Vérifiez le réseau.',
        key: Key('erreur_preparation')),
  ));
}

/// Un produit dans le stock de départ d'un gymnase : quantité saisie (enregistrée
/// quand on valide, qu'on quitte le champ ou après une courte pause) ou lue.
class _LigneDepart extends StatefulWidget {
  const _LigneDepart({
    super.key,
    required this.gymnaseId,
    required this.produit,
    required this.stock,
    required this.modifiable,
    required this.definirStock,
  });

  final String gymnaseId;
  final ProduitEvenement produit;
  final StockDepart? stock;
  final bool modifiable;
  final Future<void> Function(String gymnaseId, String produitId, int quantite)
      definirStock;

  @override
  State<_LigneDepart> createState() => _EtatLigneDepart();
}

class _EtatLigneDepart extends State<_LigneDepart> {
  late final TextEditingController _texte =
      TextEditingController(text: widget.stock?.quantite.toString() ?? '');
  final FocusNode _focus = FocusNode();
  Timer? _pause;
  bool _modifie = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _enregistrer();
    });
  }

  @override
  void didUpdateWidget(_LigneDepart ancien) {
    super.didUpdateWidget(ancien);
    // Une valeur venue d'ailleurs remplace le champ, sauf pendant qu'on le modifie.
    if (!_modifie && !_focus.hasFocus) {
      final attendu = widget.stock?.quantite.toString() ?? '';
      if (_texte.text != attendu) _texte.text = attendu;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    if (_modifie) _ecrireSiValide();
    _texte.dispose();
    _focus.dispose();
    super.dispose();
  }

  static int? _lire(String saisie) {
    final n = int.tryParse(saisie.trim());
    return n == null || n < 0 || n > 100000 ? null : n;
  }

  /// Écrit la saisie si elle est valide (sans toucher à l'écran).
  void _ecrireSiValide() {
    final n = _lire(_texte.text);
    if (n == null || n == widget.stock?.quantite) return;
    widget.definirStock(widget.gymnaseId, widget.produit.id, n).catchError((_) {});
  }

  Future<void> _enregistrer() async {
    _pause?.cancel();
    if (!_modifie) return;
    final saisie = _texte.text.trim();
    if (saisie.isEmpty) {
      // Pas de quantité : rien à écrire, on remet ce qui est enregistré.
      setState(() {
        _modifie = false;
        _erreur = null;
        _texte.text = widget.stock?.quantite.toString() ?? '';
      });
      return;
    }
    final n = _lire(saisie);
    if (n == null) {
      setState(() => _erreur = 'Entrez un nombre entier de 0 à 100 000.');
      return;
    }
    // Marqué « envoyé » avant l'attente : valider puis quitter le champ n'écrit qu'une fois.
    setState(() {
      _erreur = null;
      _modifie = false;
    });
    if (n != widget.stock?.quantite) {
      try {
        await widget.definirStock(widget.gymnaseId, widget.produit.id, n);
      } catch (_) {
        _modifie = true;
        if (mounted) _montrerErreur(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final g = widget.gymnaseId;
    final stock = widget.stock;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.filet),
      ),
      child: Row(
        children: [
          VignetteProduit(icone: p.icone, photo: p.photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nom, style: Theme.of(context).textTheme.titleSmall),
                if (!widget.modifiable)
                  Text(
                    stock == null ? 'Stock non suivi' : 'Stock : ${stock.quantite}',
                    key: Key('lecture_depart_${g}_${p.id}'),
                  ),
                if (stock != null && stock.repris)
                  Text(
                    'Repris de l\'événement précédent',
                    key: Key('repris_${g}_${p.id}'),
                    style: const TextStyle(
                        color: Palette.ocreFonce, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          if (widget.modifiable)
            SizedBox(
              width: 112,
              child: TextField(
                key: Key('depart_${g}_${p.id}'),
                controller: _texte,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  hintText: 'Non suivi',
                  errorText: _erreur,
                  errorMaxLines: 3,
                ),
                onChanged: (_) {
                  _modifie = true;
                  _pause?.cancel();
                  _pause = Timer(const Duration(milliseconds: 900), _enregistrer);
                },
                onSubmitted: (_) => _enregistrer(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Étape 2 : durée de l'événement et personnes attendues par gymnase. Les courses
/// les lisent sans les régler. Seuls le responsable et le gestionnaire rattaché à
/// tous les gymnases les règlent (comme les règles d'accès) ; les autres les lisent.
class _EtapePersonnes extends StatelessWidget {
  const _EtapePersonnes({
    required this.evenement,
    required this.gymnases,
    required this.reglable,
    required this.definirJours,
    required this.definirPersonnes,
  });

  final Evenement evenement;
  final List<Gymnase> gymnases;
  final bool reglable;
  final Future<void> Function(double jours) definirJours;
  final Future<void> Function(String gymnaseId, int personnes) definirPersonnes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Étape 2 · Personnes et durée',
            key: const Key('titre_etape_personnes'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          reglable
              ? 'Combien de personnes sont attendues dans chaque gymnase, et '
                  'combien de jours dure l\'événement ? Les courses s\'en servent.'
              : evenement.cloture
                  ? 'L\'événement est clôturé : ces réglages se lisent seulement.'
                  : 'Seul le responsable, ou un gestionnaire rattaché à tous les '
                      'gymnases, règle les personnes et la durée.',
          key: const Key('aide_personnes_duree'),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _ChampReglage<double>(
              id: 'duree',
              etiquette: 'Durée de l\'événement (jours)',
              messageErreur: 'Entrez une durée de 0,5 à $joursMax jours.',
              valeur: evenement.nbJours,
              reglable: reglable,
              lire: _lireJours,
              afficher: _afficherJours,
              enregistrer: definirJours,
            ),
          ),
        ),
        for (final g in gymnases)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ChampReglage<int>(
                id: 'personnes_${g.id}',
                etiquette: gymnases.length > 1
                    ? 'Personnes attendues : ${g.nom}'
                    : 'Personnes attendues',
                messageErreur:
                    'Entrez un nombre entier de personnes de 0 à $personnesMax.',
                valeur: g.personnes,
                reglable: reglable,
                lire: _lirePersonnes,
                afficher: (n) => '$n',
                enregistrer: (n) => definirPersonnes(g.id, n),
              ),
            ),
          ),
      ],
    );
  }
}

/// Étape 3 : la prévision de consommation, un chiffre par produit (par personne et par
/// jour) avec sa source. Par défaut le menu ; un événement passé ou une correction à
/// la main le remplacent pour cet événement seulement. Les courses s'en servent.
class _EtapePrevision extends StatelessWidget {
  const _EtapePrevision({
    required this.evenement,
    required this.produits,
    required this.voit,
    required this.reglable,
    required this.previsions,
    required this.definirPrevision,
    required this.chargerPasses,
    required this.appliquerPasse,
    required this.revenirAuMenu,
  });

  final Evenement evenement;
  final List<ProduitEvenement> produits;

  /// Peut lire les prévisions (accès à tout l'événement) ; [reglable] = peut aussi les écrire.
  final bool voit;
  final bool reglable;
  final Stream<Map<String, Prevision>> previsions;
  final Future<void> Function(String produitId, double conso) definirPrevision;
  final Future<EvenementsPasses> Function() chargerPasses;
  final Future<void> Function(ReferencePassee passe) appliquerPasse;
  final Future<void> Function() revenirAuMenu;

  @override
  Widget build(BuildContext context) {
    final titre = Text('Étape 3 · Prévision de consommation',
        key: const Key('titre_etape_prevision'),
        style: Theme.of(context).textTheme.titleMedium);
    if (!voit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titre,
          const SizedBox(height: 4),
          const Text(
            'Seul le responsable, ou un gestionnaire rattaché à tous les gymnases, '
            'voit et règle la prévision de consommation.',
            key: Key('aide_prevision'),
          ),
        ],
      );
    }
    return StreamBuilder<Map<String, Prevision>>(
      stream: previsions,
      builder: (context, s) {
        final enregistrees = s.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titre,
            const SizedBox(height: 4),
            Text(
              reglable
                  ? 'Combien chaque personne consomme-t-elle de chaque produit, par '
                      'jour ? Par défaut, les chiffres du menu. Les courses s\'en '
                      'servent ; le menu ne change jamais.'
                  : 'L\'événement est clôturé : la prévision se lit seulement.',
              key: const Key('aide_prevision'),
            ),
            const SizedBox(height: 12),
            if (s.hasError)
              const Text('Impossible de lire la prévision. Vérifiez le réseau.',
                  key: Key('erreur_lecture_prevision'))
            else if (enregistrees == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (reglable) ..._actions(context, enregistrees),
              for (final l in fusionnerPrevisions(produits, enregistrees))
                Card(
                  key: Key('prevision_${l.produitId}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.nom, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        _ChampReglage<double>(
                          id: 'conso_${l.produitId}',
                          etiquette: 'Par personne et par jour',
                          messageErreur:
                              'Entrez une consommation de 0 à ${consoPrevisionMax.toInt()}.',
                          valeur: l.conso,
                          reglable: reglable,
                          lire: lireConso,
                          afficher: consoAffichee,
                          enregistrer: (v) => definirPrevision(l.produitId, v),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Source : ${l.source}',
                          key: Key('source_${l.produitId}'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: l.modifieALaMain
                                ? Palette.ocreFonce
                                : Palette.anthracite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context, Map<String, Prevision> enregistrees) {
    final aLaMain = enregistrees.values.any((p) => p.source == sourceMain);
    return [
      OutlinedButton(
        key: const Key('prevision_evenement_passe'),
        style: TypeAction.gerer.contour,
        onPressed: () => _choisirEvenementPasse(context, aLaMain),
        child: const Text('D\'après un événement passé'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('prevision_revenir_menu'),
        style: TypeAction.gerer.contour,
        onPressed:
            enregistrees.isEmpty ? null : () => _revenir(context, aLaMain),
        child: const Text('Revenir au menu'),
      ),
      const SizedBox(height: 12),
    ];
  }

  void _dire(BuildContext context, String message, Key cle) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message, key: cle)));
  }

  Future<bool> _confirmer(BuildContext context, String question) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(question, key: const Key('question_prevision')),
          actions: [
            TextButton(
              key: const Key('annuler_prevision'),
              style: TypeAction.gerer.texte,
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const Key('confirmer_prevision'),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      ) ??
      false;

  static const _perteCorrections =
      'Des chiffres corrigés à la main seront remplacés. Continuer ?';

  Future<void> _revenir(BuildContext context, bool aLaMain) async {
    if (aLaMain && !await _confirmer(context, _perteCorrections)) return;
    try {
      await revenirAuMenu();
      if (context.mounted) {
        _dire(context, 'Tous les produits sont revenus aux chiffres du menu.',
            const Key('prevision_faite'));
      }
    } catch (_) {
      if (context.mounted) _montrerErreur(context);
    }
  }

  Future<void> _choisirEvenementPasse(BuildContext context, bool aLaMain) async {
    final EvenementsPasses passes;
    try {
      passes = await chargerPasses();
    } catch (_) {
      if (context.mounted) {
        _dire(context, 'Impossible de lire les événements passés. Vérifiez le réseau.',
            const Key('erreur_prevision'));
      }
      return;
    }
    if (!context.mounted) return;
    final choisi = await showDialog<ReferencePassee>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('D\'après un événement passé'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (passes.utilisables.isEmpty)
                const Text('Aucun événement passé ne peut servir de référence.',
                    key: Key('aucun_evenement_passe')),
              for (final r in passes.utilisables)
                ListTile(
                  key: Key('choix_passe_${r.id}'),
                  minVerticalPadding: 12,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.nom),
                  subtitle: Text('${dateAffichee(r.date)} · '
                      '${r.personnes} personne${r.personnes > 1 ? 's' : ''} · '
                      '${consoAffichee(r.jours)} jour${r.jours > 1 ? 's' : ''}'),
                  onTap: () => Navigator.of(c).pop(r),
                ),
              if (passes.sansPersonnes > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(messageSansPersonnes,
                      key: Key('message_sans_personnes')),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('fermer_evenements_passes'),
            style: TypeAction.gerer.texte,
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    if (choisi == null || !context.mounted) return;
    if (aLaMain && !await _confirmer(context, _perteCorrections)) return;
    try {
      await appliquerPasse(choisi);
      if (context.mounted) {
        _dire(context, 'Prévision calculée d\'après « ${choisi.nom} ».',
            const Key('prevision_faite'));
      }
    } on LectureRefusee {
      if (context.mounted) {
        _dire(
            context,
            'Les ventes de « ${choisi.nom} » ne peuvent pas être lues avec vos droits. '
            'Rien n\'a été modifié.',
            const Key('erreur_prevision'));
      }
    } catch (_) {
      if (context.mounted) _montrerErreur(context);
    }
  }
}

/// Durée valide : 0,5 à [joursMax] jours (virgule ou point). Sinon null.
double? _lireJours(String saisie) {
  final n = double.tryParse(saisie.trim().replaceAll(',', '.'));
  return n == null || n < demiJournee || n > joursMax ? null : n;
}

String _afficherJours(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');

/// Personnes valides : entier de 0 à [personnesMax]. Sinon null.
int? _lirePersonnes(String saisie) {
  final n = int.tryParse(saisie.trim());
  return n == null || n < 0 || n > personnesMax ? null : n;
}

/// Un réglage numérique : saisi (enregistré quand on valide, qu'on quitte le champ
/// ou après une courte pause) ou lu. Une valeur hors limites affiche un message et
/// n'écrit rien. Clés : `champ_<id>`, `lecture_<id>`, `enregistre_<id>`.
class _ChampReglage<T extends num> extends StatefulWidget {
  const _ChampReglage({
    required this.id,
    required this.etiquette,
    required this.messageErreur,
    required this.valeur,
    required this.reglable,
    required this.lire,
    required this.afficher,
    required this.enregistrer,
  });

  final String id;
  final String etiquette;
  final String messageErreur;
  final T valeur;
  final bool reglable;
  final T? Function(String saisie) lire;
  final String Function(T valeur) afficher;
  final Future<void> Function(T valeur) enregistrer;

  @override
  State<_ChampReglage<T>> createState() => _EtatChampReglage<T>();
}

class _EtatChampReglage<T extends num> extends State<_ChampReglage<T>> {
  late final TextEditingController _texte =
      TextEditingController(text: widget.afficher(widget.valeur));
  final FocusNode _focus = FocusNode();
  Timer? _pause;
  bool _modifie = false;
  String? _erreur;
  bool _enregistre = false;

  /// Dernière valeur écrite, tant que la valeur lue n'a pas rattrapé (évite de
  /// prendre un retour à l'ancienne valeur pour « rien à écrire »).
  T? _ecrit;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _valider();
    });
  }

  @override
  void didUpdateWidget(_ChampReglage<T> ancien) {
    super.didUpdateWidget(ancien);
    if (widget.valeur != ancien.valeur) _ecrit = null;
    // Une valeur venue d'ailleurs remplace le champ, sauf pendant qu'on le modifie.
    if (!_modifie && !_focus.hasFocus) {
      final attendu = widget.afficher(widget.valeur);
      if (_texte.text != attendu) _texte.text = attendu;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    if (_modifie) {
      final n = widget.lire(_texte.text);
      if (n != null && n != (_ecrit ?? widget.valeur)) {
        widget.enregistrer(n).catchError((_) {});
      }
    }
    _texte.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    _pause?.cancel();
    if (!_modifie) return;
    final n = widget.lire(_texte.text);
    if (n == null) {
      setState(() {
        _erreur = widget.messageErreur;
        _enregistre = false;
      });
      return;
    }
    // Marqué « envoyé » avant l'attente : valider puis quitter le champ n'écrit qu'une fois.
    setState(() {
      _erreur = null;
      _modifie = false;
    });
    if (n == (_ecrit ?? widget.valeur)) return;
    try {
      await widget.enregistrer(n);
      _ecrit = n;
      if (mounted) setState(() => _enregistre = true);
    } catch (_) {
      _modifie = true;
      if (mounted) _montrerErreur(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.reglable) {
      return Text('${widget.etiquette} : ${widget.afficher(widget.valeur)}',
          key: Key('lecture_${widget.id}'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: Key('champ_${widget.id}'),
          controller: _texte,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.etiquette,
            errorText: _erreur,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            _modifie = true;
            _enregistre = false;
            _pause?.cancel();
            _pause = Timer(const Duration(milliseconds: 900), _valider);
          },
          onSubmitted: (_) => _valider(),
        ),
        if (_enregistre && !_modifie && _erreur == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Enregistré', key: Key('enregistre_${widget.id}')),
          ),
      ],
    );
  }
}
