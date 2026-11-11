import 'package:flutter/material.dart';

import 'champ_reglage.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'liste_familles.dart';
import 'previsions.dart';
import 'tableau_bord.dart' show formaterJours;
import 'theme.dart';

/// Écran « Prévision » (mission « Ergonomie de la gestion », E5, décisions 55, 56 et 63).
/// Ouvert par la tâche « Prévision » d'Avant. Un bandeau dit pour combien de personnes et
/// de jours la prévision est calculée, avec sa source et les deux changements de source.
/// Puis une ligne par produit, rangée par familles : le chiffre par personne et par jour,
/// sa source, et le total pour le tournoi. Le fait maison n'a pas de ligne. Les calculs
/// ([fusionnerPrevisions]) ne changent pas.
class EcranPrevision extends StatelessWidget {
  const EcranPrevision({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.produits,
    required this.previsions,
    required this.definirPrevision,
    required this.chargerPasses,
    required this.appliquerPasse,
    required this.revenirAuMenu,
    required this.chargerReferences,
    required this.appliquerReference,
    this.definirPrevisionVerifiee,
    this.onVoirCourses,
    this.annulable,
    this.annulerChangement,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<ProduitEvenement>> produits;

  /// Prévision de l'événement (produit -> chiffre et source).
  final Stream<Map<String, Prevision>> previsions;
  final Future<void> Function(String produitId, double conso) definirPrevision;

  /// Les événements passés proposés comme source, et l'application de l'un d'eux
  /// (lève [LectureRefusee] si ses ventes ne sont pas lisibles : rien n'est écrit).
  final Future<EvenementsPasses> Function() chargerPasses;
  final Future<void> Function(ReferencePassee passe) appliquerPasse;
  final Future<void> Function() revenirAuMenu;

  /// Références importées d'un classeur et l'application de l'une d'elles.
  final Future<List<ReferenceImportee>> Function() chargerReferences;
  final Future<void> Function(ReferenceImportee reference) appliquerReference;

  /// « C'est vérifié » : écrit la case « prévision vérifiée » (null = pas de bouton).
  final Future<void> Function(bool verifiee)? definirPrevisionVerifiee;

  /// Renvoi vers la liste de courses (null = pas de renvoi).
  final VoidCallback? onVoirCourses;

  /// « Annuler ce changement » : le flux dit si un changement de source est annulable (il
  /// suit les autres téléphones), et l'action qui le remet (null = pas de bouton).
  final Stream<bool>? annulable;
  final Future<void> Function()? annulerChangement;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: evenement,
      builder: (context, sEv) => StreamBuilder<List<Gymnase>>(
        stream: gymnases,
        builder: (context, sG) => StreamBuilder<List<ProduitEvenement>>(
          stream: produits,
          builder: (context, sP) => StreamBuilder<Map<String, Prevision>>(
            stream: previsions,
            builder: (context, sPrev) => StreamBuilder<bool>(
              stream: annulable ?? Stream.value(false),
              builder: (context, sAnn) {
                final ev = sEv.data;
                final tous = sG.data;
                final liste = sP.data;
                final charge = ev != null && tous != null && liste != null;
                final peutAnnuler = sAnn.data == true && annulerChangement != null;
                return Scaffold(
                  appBar: AppBar(title: const Text('Prévision')),
                  body: !charge
                      ? const Center(child: CircularProgressIndicator())
                      : _corps(context, ev, tous, liste, sPrev.data, sPrev.hasError,
                          peutAnnuler),
                  bottomNavigationBar:
                      !charge || !portee.toutVoir ? null : _pied(ev),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _corps(
    BuildContext context,
    Evenement ev,
    List<Gymnase> tous,
    List<ProduitEvenement> liste,
    Map<String, Prevision>? enregistrees,
    bool erreur,
    bool peutAnnuler,
  ) {
    if (!portee.toutVoir) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Seul le responsable, ou un gestionnaire rattaché à tous les gymnases, '
            'voit et règle la prévision de consommation.',
            key: Key('aide_prevision'),
          ),
        ],
      );
    }
    final reglable = !ev.cloture;
    final personnes = tous.fold<int>(0, (s, g) => s + g.personnes);
    final produitDe = {for (final p in liste) p.id: p};
    // Le fait maison n'a pas de ligne de prévision.
    final avecPrevision = [
      for (final p in liste)
        if (p.fiche.famille != 'fait_maison') p,
    ];
    final lignes = enregistrees == null
        ? const <PrevisionProduit>[]
        : fusionnerPrevisions(avecPrevision, enregistrees);
    return ListeFamilles<PrevisionProduit>(
      elements: lignes,
      ouvertesAuDepart: true,
      familleDe: (l) => produitDe[l.produitId]?.fiche.famille ?? 'autre',
      nomDe: (l) => l.nom,
      ligne: (ctx, l, couleur) => _ligne(
        ctx,
        l,
        couleur,
        produitDe[l.produitId]!,
        personnes,
        ev.nbJours,
        reglable,
      ),
      enTete: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bandeau(context, ev, personnes, enregistrees, lignes, reglable, peutAnnuler),
          const SizedBox(height: 12),
          Text(
            reglable
                ? 'Combien chaque personne consomme-t-elle de chaque produit, par '
                    'jour ? Par défaut, les chiffres du menu. Les courses s\'en '
                    'servent ; le menu ne change jamais.'
                : 'L\'événement est clôturé : la prévision se lit seulement.',
            key: const Key('aide_prevision'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le fait maison n\'a pas de prévision : il est apporté le jour même.',
            key: Key('aide_fait_maison'),
          ),
          const SizedBox(height: 12),
          if (erreur)
            const Text('Impossible de lire la prévision. Vérifiez le réseau.',
                key: Key('erreur_lecture_prevision'))
          else if (enregistrees == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  /// Le bandeau : pour combien de personnes et de jours, la source, et les deux
  /// changements de source (quand on peut les faire).
  Widget _bandeau(
    BuildContext context,
    Evenement ev,
    int personnes,
    Map<String, Prevision>? enregistrees,
    List<PrevisionProduit> lignes,
    bool reglable,
    bool peutAnnuler,
  ) {
    final nPersonnes = '$personnes personne${personnes > 1 ? 's' : ''}';
    final nJours = '${formaterJours(ev.nbJours)} jour${ev.nbJours == 1 ? '' : 's'}';
    final sources = {for (final l in lignes) l.source};
    final source = sources.isEmpty
        ? sourceMenu
        : sources.length == 1
            ? sources.first
            : 'Plusieurs sources';
    final aLaMain = lignes.any((l) => l.modifieALaMain);
    return Container(
      key: const Key('bandeau_prevision'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.anthracite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calculée pour $nPersonnes × $nJours',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Source : $source',
            key: const Key('source_bandeau'),
            style: const TextStyle(color: Colors.white70),
          ),
          if (reglable) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('prevision_evenement_passe'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () => _choisirEvenementPasse(context, aLaMain),
                  child: const Text('D\'après une source'),
                ),
                OutlinedButton(
                  key: const Key('prevision_revenir_menu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: enregistrees == null || enregistrees.isEmpty
                      ? null
                      : () => _revenir(context, aLaMain),
                  child: const Text('Revenir au menu'),
                ),
                if (peutAnnuler)
                  OutlinedButton(
                    key: const Key('prevision_annuler_changement'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: () => _annuler(context, aLaMain),
                    child: const Text('Annuler ce changement'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Une ligne : pastille, nom, source colorée, total pour le tournoi (en verres et en
  /// litres pour un produit au litre), puis le champ « par personne et par jour ».
  Widget _ligne(
    BuildContext context,
    PrevisionProduit l,
    Color couleur,
    ProduitEvenement p,
    int personnes,
    double jours,
    bool reglable,
  ) {
    final total = arrondi(l.conso * personnes * jours);
    final verresParLitre = p.fiche.verresParLitre;
    final enVerres = verresParLitre != null && verresParLitre > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PastilleProduit(nom: l.nom, couleur: couleur, taille: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.nom, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      'Source : ${l.source}',
                      key: Key('source_${l.produitId}'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: l.modifieALaMain ? Palette.ocreFonce : Palette.gris,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    enVerres
                        ? '${consoAffichee(total)} ${total == 1 ? 'verre' : 'verres'}'
                        : consoAffichee(total),
                    key: Key('total_${l.produitId}'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  if (enVerres)
                    Text(
                      '${consoAffichee(arrondi(total / verresParLitre))} L',
                      key: Key('litres_${l.produitId}'),
                      style: const TextStyle(color: Palette.gris, fontSize: 13),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ChampReglage<double>(
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
        ],
      ),
    );
  }

  /// Le pied : « C'est vérifié » (ou la mention) et le renvoi vers la liste de courses.
  Widget _pied(Evenement ev) {
    final definir = definirPrevisionVerifiee;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ev.cloture && definir != null)
              _verification(ev, definir)
            else if (ev.previsionVerifiee)
              const Text('Prévision vérifiée', key: Key('prevision_verifiee_ok')),
            if (onVoirCourses != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('prevision_vers_courses'),
                style: TypeAction.gerer.contour,
                onPressed: onVoirCourses,
                child: const Text('Voir la liste de courses'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// « C'est vérifié » : coche la tâche Prévision du tableau de bord. Une fois cochée,
  /// on peut la remettre à vérifier (si le menu ou une source change).
  Widget _verification(Evenement ev, Future<void> Function(bool verifiee) definir) {
    if (ev.previsionVerifiee) {
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

  static const _perteAnnulation =
      'Les chiffres corrigés à la main depuis ce changement seront remplacés. Continuer ?';

  /// « Annuler ce changement » : remet les chiffres d'avant le dernier changement de source.
  Future<void> _annuler(BuildContext context, bool aLaMain) async {
    final annuler = annulerChangement;
    if (annuler == null) return;
    if (aLaMain && !await _confirmer(context, _perteAnnulation)) return;
    try {
      await annuler();
      if (context.mounted) {
        _dire(context, 'Le changement de source est annulé : les chiffres d\'avant sont revenus.',
            const Key('prevision_annulee'));
      }
    } catch (_) {
      if (context.mounted) montrerErreurEnregistrement(context);
    }
  }

  Future<void> _revenir(BuildContext context, bool aLaMain) async {
    if (aLaMain && !await _confirmer(context, _perteCorrections)) return;
    try {
      await revenirAuMenu();
      if (context.mounted) {
        _dire(context, 'Tous les produits sont revenus aux chiffres du menu.',
            const Key('prevision_faite'));
      }
    } catch (_) {
      if (context.mounted) montrerErreurEnregistrement(context);
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
      if (context.mounted) montrerErreurEnregistrement(context);
    }
  }
}

/// Arrondi au centième : evite que 156,00000000000003 s ecrive "156,".
double arrondi(double v) => (v * 100).round() / 100;
