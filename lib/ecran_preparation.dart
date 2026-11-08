import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'classeur.dart';
import 'courses.dart' show demiJournee, joursMax, personnesMax;
import 'evenement.dart';
import 'export_bilan.dart' show nomFichierModele;
import 'gymnase.dart';
import 'import_classeur.dart';
import 'partage.dart';
import 'previsions.dart';
import 'resume_import.dart';
import 'selecteur.dart';
import 'theme.dart';

/// Préparation d'un événement (gestion) : étape 1 « Stock de départ » (son écran propre,
/// [EcranStockDepart], ouvert d'ici), étape 2 « Personnes et durée », étape 3 « Prévision »,
/// et le classeur Excel.
class EcranPreparation extends StatelessWidget {
  const EcranPreparation({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.produits,
    required this.stocks,
    required this.definirJours,
    required this.definirPersonnes,
    this.onVoirStockDepart,
    required this.previsions,
    required this.definirPrevision,
    required this.chargerPasses,
    required this.appliquerPasse,
    required this.revenirAuMenu,
    required this.chargerReferences,
    required this.appliquerReference,
    required this.importer,
    this.partagerModele = partagerFichier,
    this.choisirClasseur = choisirClasseurSysteme,
    this.definirPrevisionVerifiee,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<ProduitEvenement>> produits;

  /// Stock de départ : gymnase -> produit -> quantité (et marque « repris »), pour le
  /// résumé du classeur à l'import.
  final Stream<Map<String, Map<String, StockDepart>>> stocks;

  /// Ouvre l'écran « Stock de départ » (absent = pas de lien).
  final VoidCallback? onVoirStockDepart;

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

  /// Références de consommation importées d'un classeur (au niveau de l'association) et
  /// l'application de l'une d'elles à la prévision de l'événement.
  final Future<List<ReferenceImportee>> Function() chargerReferences;
  final Future<void> Function(ReferenceImportee reference) appliquerReference;

  /// Exécute un plan d'import (stocks de départ et références), après le résumé.
  final Future<void> Function(PlanImport plan) importer;

  /// Remet le modèle Excel à la feuille de partage (remplaçable dans les tests).
  final PartageurOctets partagerModele;

  /// Choisit le classeur à importer : rend son contenu, ou null si on annule
  /// (remplaçable dans les tests).
  final SelecteurClasseur choisirClasseur;

  /// « C'est vérifié » (étape 3) : écrit la case « prévision vérifiée » de l'événement
  /// (absent = pas de bouton, comme dans les tests sans réseau).
  final Future<void> Function(bool verifiee)? definirPrevisionVerifiee;

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
              return Scaffold(
                appBar: AppBar(title: const Text('Préparation')),
                body: !charge
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _CarteClasseur(
                            evenement: ev,
                            gymnases: [
                              for (final g in tous)
                                if (portee.gere(g.id)) g
                            ],
                            tousGymnases: tous,
                            portee: portee,
                            produits: liste,
                            stocks: stock,
                            partager: partagerModele,
                            choisir: choisirClasseur,
                            importer: importer,
                          ),
                          const SizedBox(height: 16),
                          if (onVoirStockDepart != null) ...[
                            Text('Stock de départ',
                                key: const Key('titre_etape_stock'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            const Text(
                              'Combien de produits y a-t-il dans chaque gymnase au '
                              'départ ? Chaque gymnase a son écran.',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              key: const Key('voir_stock_depart'),
                              style: TypeAction.gerer.contour,
                              onPressed: onVoirStockDepart,
                              child: const Text('Ouvrir le stock de départ'),
                            ),
                          ],
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
                            chargerReferences: chargerReferences,
                            appliquerReference: appliquerReference,
                            definirVerifiee: definirPrevisionVerifiee,
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

void _montrerErreur(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Enregistrement impossible. Vérifiez le réseau.',
        key: Key('erreur_preparation')),
  ));
}

/// Le classeur Excel de l'événement : télécharger le modèle (menu et stock de départ
/// remplis, remis à la feuille de partage d'Android) et importer un classeur rempli
/// (stock de départ et références de consommation, après un résumé).
class _CarteClasseur extends StatefulWidget {
  const _CarteClasseur({
    required this.evenement,
    required this.gymnases,
    required this.tousGymnases,
    required this.portee,
    required this.produits,
    required this.stocks,
    required this.partager,
    required this.choisir,
    required this.importer,
  });

  final Evenement evenement;

  /// Les gymnases de la portée de la personne (modèle) et tous ceux de l'événement (import).
  final List<Gymnase> gymnases;
  final List<Gymnase> tousGymnases;
  final PorteeGestion portee;
  final List<ProduitEvenement> produits;
  final Map<String, Map<String, StockDepart>> stocks;
  final PartageurOctets partager;
  final SelecteurClasseur choisir;
  final Future<void> Function(PlanImport plan) importer;

  @override
  State<_CarteClasseur> createState() => _EtatCarteClasseur();
}

class _EtatCarteClasseur extends State<_CarteClasseur> {
  bool _enCours = false;
  bool _importEnCours = false;

  /// Dernier résultat d'import : la phrase et si c'est une erreur.
  String? _resultat;
  bool _resultatErreur = false;

  Future<void> _telecharger() async {
    setState(() => _enCours = true);
    try {
      final octets = construireModele(
        produits: widget.produits,
        gymnases: widget.gymnases,
        stocks: widget.stocks,
      );
      await widget.partager(
          nomFichierModele(widget.evenement), octets, typeMimeClasseur);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Le partage n\'a pas pu s\'ouvrir. Réessayez.',
              key: Key('erreur_partage_modele')),
        ));
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _dire(String phrase, {bool erreur = false}) {
    if (!mounted) return;
    setState(() {
      _resultat = phrase;
      _resultatErreur = erreur;
    });
  }

  Future<void> _importer() async {
    setState(() {
      _importEnCours = true;
      _resultat = null;
    });
    try {
      final Uint8List? octets;
      try {
        octets = await widget.choisir();
      } catch (_) {
        _dire('Le choix du fichier n\'a pas pu s\'ouvrir. Réessayez.', erreur: true);
        return;
      }
      if (octets == null) return; // annulé : rien ne change
      final ClasseurLu lu;
      try {
        lu = lireClasseur(octets);
      } on ClasseurIllisible {
        _dire(messageClasseurIllisible, erreur: true);
        return;
      }
      if (!lu.contenuUtile) {
        _dire(messageClasseurIllisible, erreur: true);
        return;
      }
      final plan = preparerImport(
        lu,
        tous: widget.tousGymnases,
        produits: widget.produits,
        portee: widget.portee,
        stockModifiable: widget.evenement.enPreparation,
      );
      if (!mounted) return;
      final accepte = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _EcranResumeImport(plan: plan)),
      );
      if (accepte != true) return;
      try {
        await widget.importer(plan);
        _dire(plan.phraseConfirmation);
      } catch (_) {
        _dire(
            'L\'import n\'a pas pu être terminé. Vérifiez le réseau puis réessayez : '
            'le rejouer est sans risque.',
            erreur: true);
      }
    } finally {
      if (mounted) setState(() => _importEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Classeur Excel',
                key: const Key('titre_classeur'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Téléchargez le modèle : il contient le menu et le stock de départ '
              'de cet événement. Remplissez-le avec les chiffres de l\'an passé.',
              key: Key('aide_classeur'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('telecharger_modele'),
              style: TypeAction.gerer.contour,
              onPressed: _enCours ? null : _telecharger,
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le modèle Excel'),
            ),
            if (!widget.evenement.cloture) ...[
              const SizedBox(height: 8),
              const Text(
                'Importez le classeur rempli : son stock de départ s\'applique à '
                'cet événement et son historique devient une source de prévision. '
                'Un résumé s\'affiche avant toute écriture.',
                key: Key('aide_import'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('importer_classeur'),
                style: TypeAction.gerer.contour,
                onPressed: _importEnCours ? null : _importer,
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer un classeur'),
              ),
            ],
            if (_resultat != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _resultat!,
                  key: Key(_resultatErreur ? 'erreur_import' : 'confirmation_import'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _resultatErreur ? Palette.ocreFonce : Palette.anthracite,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le résumé d'un import dans la Préparation (voir [EcranResumeImport]) : stocks appliqués
/// et références créées.
class _EcranResumeImport extends StatelessWidget {
  const _EcranResumeImport({required this.plan});

  final PlanImport plan;

  @override
  Widget build(BuildContext context) {
    return EcranResumeImport(
      titre: 'Résumé de l\'import',
      cleAppliquer: const Key('appliquer_import'),
      libelleAppliquer: 'Appliquer',
      ignorees: plan.ignorees,
      erreurs: plan.erreurs,
      corps: [
        Text(plan.phraseStocks,
            key: const Key('resume_stocks'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (plan.references.isEmpty)
          const Text('Aucune référence de consommation ne sera créée.',
              key: Key('resume_aucune_reference'))
        else
          for (final (i, phrase) in plan.phrasesReferences.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(phrase,
                  key: Key('resume_reference_$i'),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
        if (plan.menuIgnore)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
                'La feuille Menu est ignorée ici : elle s\'importe depuis l\'écran Menus.',
                key: Key('resume_menu_ignore')),
          ),
      ],
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
    required this.chargerReferences,
    required this.appliquerReference,
    this.definirVerifiee,
  });

  final Evenement evenement;
  final List<ProduitEvenement> produits;

  /// « C'est vérifié » : null = pas de bouton.
  final Future<void> Function(bool verifiee)? definirVerifiee;

  /// Peut lire les prévisions (accès à tout l'événement) ; [reglable] = peut aussi les écrire.
  final bool voit;
  final bool reglable;
  final Stream<Map<String, Prevision>> previsions;
  final Future<void> Function(String produitId, double conso) definirPrevision;
  final Future<EvenementsPasses> Function() chargerPasses;
  final Future<void> Function(ReferencePassee passe) appliquerPasse;
  final Future<void> Function() revenirAuMenu;
  final Future<List<ReferenceImportee>> Function() chargerReferences;
  final Future<void> Function(ReferenceImportee reference) appliquerReference;

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
            if (reglable && definirVerifiee != null) ...[
              _verification(),
              const SizedBox(height: 12),
            ] else if (evenement.previsionVerifiee) ...[
              const Text('Prévision vérifiée',
                  key: Key('prevision_verifiee_ok')),
              const SizedBox(height: 12),
            ],
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

  /// « C'est vérifié » : coche la tâche Prévision du tableau de bord. Une fois cochée,
  /// on peut la remettre à vérifier (si le menu ou une source change).
  Widget _verification() {
    final definir = definirVerifiee!;
    if (evenement.previsionVerifiee) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Palette.saugeFonce),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Prévision vérifiée', key: Key('prevision_verifiee_ok')),
          ),
          OutlinedButton(
            key: const Key('prevision_a_revoir'),
            style: TypeAction.gerer.contour,
            onPressed: () => definir(false),
            child: const Text('Revoir'),
          ),
        ],
      );
    }
    return FilledButton(
      key: const Key('prevision_verifiee'),
      style: TypeAction.reussir.plein,
      onPressed: () => definir(true),
      child: const Text("C'est vérifié"),
    );
  }

  List<Widget> _actions(BuildContext context, Map<String, Prevision> enregistrees) {
    final aLaMain = enregistrees.values.any((p) => p.source == sourceMain);
    return [
      OutlinedButton(
        key: const Key('prevision_evenement_passe'),
        style: TypeAction.gerer.contour,
        onPressed: () => _choisirEvenementPasse(context, aLaMain),
        child: const Text('D\'après une source'),
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
    // Les références importées d'un classeur : illisibles, elles sont seulement absentes
    // de la liste (les événements passés restent proposés).
    var references = const <ReferenceImportee>[];
    try {
      references = await chargerReferences();
    } catch (_) {}
    if (!context.mounted) return;
    final choisi = await showDialog<Object>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('D\'après une source'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (passes.utilisables.isEmpty && references.isEmpty)
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
              for (final r in references)
                ListTile(
                  key: Key('choix_reference_${r.id}'),
                  minVerticalPadding: 12,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.nom),
                  subtitle: Text('Importée d\'un classeur Excel · '
                      '${r.lignes.length} produit${r.lignes.length > 1 ? 's' : ''}'),
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
      if (choisi is ReferenceImportee) {
        await appliquerReference(choisi);
        if (context.mounted) {
          _dire(context, 'Prévision calculée d\'après « ${choisi.nom} ».',
              const Key('prevision_faite'));
        }
      } else if (choisi is ReferencePassee) {
        await appliquerPasse(choisi);
        if (context.mounted) {
          _dire(context, 'Prévision calculée d\'après « ${choisi.nom} ».',
              const Key('prevision_faite'));
        }
      }
    } on LectureRefusee {
      if (context.mounted) {
        _dire(
            context,
            'Les ventes de « ${(choisi as ReferencePassee).nom} » ne peuvent pas être '
            'lues avec vos droits. Rien n\'a été modifié.',
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
