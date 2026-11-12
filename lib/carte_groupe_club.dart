import 'package:flutter/material.dart';

import 'calcul_club.dart';
import 'champ_reglage.dart';
import 'evenement.dart';
import 'previsions.dart' show consoAffichee;
import 'theme.dart';

/// « Groupes du club » (mission « Calcul du club », V4, décisions 86 et 88) : une carte par
/// groupe dans l'écran Prévision. Dans chaque carte : le nom, le pourcentage de chaque jour,
/// les produits rangés avec leur part de chaque jour et, sous chacun, la quantité prévue de
/// chaque jour ; en bas, pour chaque jour, « 100 % » en vert ou l'écart en ocre. Un produit
/// n'est que dans un seul groupe. Rien n'est corrigé en silence : l'écart est seulement dit.
class ZoneGroupesClub extends StatefulWidget {
  const ZoneGroupesClub({
    super.key,
    required this.jours,
    required this.groupes,
    required this.calcul,
    required this.produits,
    required this.reglable,
    required this.definir,
  });

  /// Nombre de jours de l'événement (entier), ou null s'il n'est pas entier.
  final int? jours;
  final List<GroupeConso> groupes;

  /// Le calcul du club complet (pour les quantités prévues) ; null = pas de repas détaillés.
  final CalculClub? calcul;

  /// Les produits que l'on peut ranger (le fait maison est déjà exclu).
  final List<ProduitEvenement> produits;
  final bool reglable;
  final Future<void> Function(List<GroupeConso> groupes) definir;

  @override
  State<ZoneGroupesClub> createState() => _EtatZoneGroupesClub();
}

double _arrondi2(double v) => (v * 100).round() / 100;

/// Pourcentage saisi (virgule ou point) de 0 à [max]. Sinon null.
double? Function(String) _lirePourcent(double max) => (saisie) {
      final n = double.tryParse(saisie.trim().replaceAll(',', '.'));
      return n == null || n < 0 || n > max ? null : n;
    };

class _EtatZoneGroupesClub extends State<ZoneGroupesClub> {
  /// Les groupes juste après un enregistrement, tant que la base n'a pas répondu (deux champs
  /// réglés de suite ne s'écrasent pas).
  List<GroupeConso>? _local;

  List<GroupeConso> get _courant => _local ?? widget.groupes;

  @override
  void didUpdateWidget(ZoneGroupesClub ancien) {
    super.didUpdateWidget(ancien);
    if (!identical(widget.groupes, ancien.groupes)) _local = null;
  }

  Future<void> _ecrire(List<GroupeConso> nouveaux) async {
    setState(() => _local = nouveaux);
    try {
      await widget.definir(nouveaux);
    } catch (_) {
      if (mounted) setState(() => _local = null);
      rethrow;
    }
  }

  Future<void> _ecrireAvecMessage(List<GroupeConso> nouveaux) async {
    try {
      await _ecrire(nouveaux);
    } catch (_) {
      if (mounted) montrerErreurEnregistrement(context);
    }
  }

  List<GroupeConso> _remplacer(int i, GroupeConso g) => [
        for (var k = 0; k < _courant.length; k++) k == i ? g : _courant[k],
      ];

  Future<void> _creer() async {
    final nom = await _demanderNom(null);
    if (nom == null) return;
    await _ecrireAvecMessage([..._courant, GroupeConso(nom: nom)]);
  }

  Future<void> _renommer(int i) async {
    final nom = await _demanderNom(_courant[i].nom);
    if (nom == null || i >= _courant.length) return;
    await _ecrireAvecMessage(_remplacer(i, groupeRenomme(_courant[i], nom)));
  }

  Future<String?> _demanderNom(String? actuel) => showDialog<String>(
        context: context,
        builder: (c) => _DialogNomGroupe(actuel: actuel),
      );

  Future<void> _supprimer(int i) async {
    final nom = _courant[i].nom;
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'Supprimer le groupe « $nom » ? Ses produits retrouvent l\'ancien calcul.',
          key: const Key('question_suppression_groupe'),
        ),
        actions: [
          TextButton(
            key: const Key('annuler_suppression_groupe'),
            style: TypeAction.gerer.texte,
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            key: const Key('confirmer_suppression_groupe'),
            style: TypeAction.danger.contour,
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (oui != true || i >= _courant.length) return;
    await _ecrireAvecMessage([
      for (var k = 0; k < _courant.length; k++)
        if (k != i) _courant[k],
    ]);
  }

  Future<void> _ranger(int i) async {
    final deja = _courant[i].produits.keys.toSet();
    String? groupeDe(String produitId) {
      for (final g in _courant) {
        if (g.produits.containsKey(produitId)) return g.nom;
      }
      return null;
    }

    final choisi = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ranger un produit dans « ${_courant[i].nom} »'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (widget.produits.every((p) => deja.contains(p.id)))
                const Text('Tous les produits de l\'événement sont déjà dans ce groupe.',
                    key: Key('aucun_produit_a_ranger')),
              for (final p in widget.produits)
                if (!deja.contains(p.id))
                  ListTile(
                    key: Key('choix_produit_${p.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.nom),
                    subtitle: groupeDe(p.id) == null
                        ? null
                        : Text('Dans « ${groupeDe(p.id)} » : il y sera retiré'),
                    onTap: () => Navigator.of(c).pop(p.id),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('fermer_choix_produit'),
            style: TypeAction.gerer.texte,
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    final jours = widget.jours;
    if (choisi == null || jours == null || i >= _courant.length) return;
    await _ecrireAvecMessage(rangerProduit(_courant, i, choisi, jours));
  }

  @override
  Widget build(BuildContext context) {
    final jours = widget.jours;
    return Column(
      key: const Key('groupes_club'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Groupes du club', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Un groupe a un pourcentage par jour ; ses produits se partagent ce groupe '
          '(leurs parts font 100 %). Un produit rangé dans un groupe suit les repas du '
          'jour. Un produit hors groupe garde le chiffre par personne.',
          key: Key('aide_groupes'),
        ),
        const SizedBox(height: 12),
        if (jours == null)
          const Text(
            'La durée n\'est pas un nombre entier de jours : les groupes ne se règlent pas ici.',
            key: Key('aide_groupes_jours'),
          )
        else ...[
          if (_courant.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Aucun groupe pour l\'instant.', key: Key('aucun_groupe')),
            ),
          for (var i = 0; i < _courant.length; i++) _carte(context, i, jours),
          if (widget.reglable)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('creer_groupe'),
                style: TypeAction.gerer.contour,
                onPressed: _courant.length >= groupesMax ? null : _creer,
                child: const Text('Ajouter un groupe'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _carte(BuildContext context, int i, int jours) {
    final g = _courant[i];
    final produitDe = {for (final p in widget.produits) p.id: p};
    return Card(
      key: Key('carte_groupe_$i'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.nom,
                    key: Key('nom_groupe_$i'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (widget.reglable) ...[
                  IconButton(
                    key: Key('renommer_groupe_$i'),
                    tooltip: 'Renommer le groupe',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _renommer(i),
                  ),
                  IconButton(
                    key: Key('supprimer_groupe_$i'),
                    tooltip: 'Supprimer le groupe',
                    icon: const Icon(Icons.delete_outline, color: Palette.brique),
                    onPressed: () => _supprimer(i),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            const Text('Pourcentage du groupe', style: TextStyle(color: Palette.gris)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var j = 1; j <= jours; j++)
                  SizedBox(
                    width: 128,
                    child: ChampReglage<double>(
                      id: 'pct_${i}_$j',
                      etiquette: 'Jour $j (%)',
                      messageErreur: 'Entrez un pourcentage de 0 à '
                          '${(pourcentageGroupeMax * 100).toInt()}.',
                      valeur: _arrondi2((g.pourcentages[j] ?? 0.0) * 100),
                      reglable: widget.reglable,
                      lire: _lirePourcent(pourcentageGroupeMax * 100),
                      afficher: consoAffichee,
                      enregistrer: (v) => _ecrire(_remplacer(
                          i, groupeAvecPourcentage(_courant[i], j, v / 100))),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (g.produits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Aucun produit dans ce groupe.', key: Key('aucun_produit_$i')),
              ),
            for (final pid in g.produits.keys)
              _produit(context, i, pid, produitDe[pid]?.nom ?? 'Produit retiré', jours),
            if (widget.reglable)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: Key('ranger_produit_$i'),
                  style: TypeAction.gerer.contour,
                  onPressed: () => _ranger(i),
                  child: const Text('Ranger un produit'),
                ),
              ),
            if (g.produits.isNotEmpty) ...[
              const SizedBox(height: 12),
              _verification(i, g, jours),
            ],
          ],
        ),
      ),
    );
  }

  Widget _produit(BuildContext context, int i, String pid, String nom, int jours) {
    final g = _courant[i];
    return Padding(
      key: Key('produit_${i}_$pid'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (widget.reglable)
                IconButton(
                  key: Key('retirer_produit_${i}_$pid'),
                  tooltip: 'Retirer du groupe',
                  icon: const Icon(Icons.close),
                  onPressed: () => _ecrireAvecMessage(
                      retirerProduit(_courant, pid)),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (var j = 1; j <= jours; j++)
                SizedBox(
                  width: 128,
                  child: ChampReglage<double>(
                    id: 'part_${i}_${pid}_$j',
                    etiquette: 'Part jour $j (%)',
                    messageErreur: 'Entrez une part de 0 à '
                        '${(partProduitMax * 100).toInt()}.',
                    valeur: _arrondi2((g.produits[pid]?[j] ?? 0.0) * 100),
                    reglable: widget.reglable,
                    lire: _lirePourcent(partProduitMax * 100),
                    afficher: consoAffichee,
                    enregistrer: (v) => _ecrire(_remplacer(
                        i, groupeAvecPart(_courant[i], pid, j, v / 100))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              for (var j = 1; j <= jours; j++)
                Text(
                  'Prévu jour $j : ${consoAffichee(_quantite(pid, j))}',
                  key: Key('quantite_${pid}_$j'),
                  style: const TextStyle(color: Palette.gris, fontSize: 13),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Quantité prévue du jour, d'après les groupes affichés (et les repas détaillés).
  double _quantite(String produitId, int jour) {
    final base = widget.calcul ?? const CalculClub();
    return quantiteClubProduitJour(
            CalculClub(repas: base.repas, groupes: _courant), produitId, jour) ??
        0.0;
  }

  /// Pour chaque jour : « 100 % » en vert, ou l'écart en ocre (comme la case « Verif » du club).
  Widget _verification(int i, GroupeConso g, int jours) {
    final ecarts = {for (final e in ecartsDuGroupe(g)) e.jour: e};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parts des produits', style: TextStyle(color: Palette.gris)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var j = 1; j <= jours; j++) _pastille(i, j, ecarts[j]),
          ],
        ),
      ],
    );
  }

  Widget _pastille(int i, int jour, EcartGroupe? e) {
    final ok = e == null;
    final type = ok ? TypeAction.reussir : TypeAction.attention;
    final somme = ok ? 100.0 : _arrondi2(e.somme * 100);
    final texte = ok
        ? '100 %'
        : e.ecart < 0
            ? '${consoAffichee(somme)} % : il manque ${consoAffichee(_arrondi2(-e.ecart * 100))} %'
            : '${consoAffichee(somme)} % : ${consoAffichee(_arrondi2(e.ecart * 100))} % de trop';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: type.doux,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded,
              size: 18, color: type.fonce),
          const SizedBox(width: 6),
          Text('Jour $jour : ', style: TextStyle(color: type.fonce)),
          Flexible(
            child: Text(
              texte,
              key: Key('verif_${i}_$jour'),
              style: TextStyle(color: type.fonce, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le nom d'un groupe : créer (actuel null) ou renommer. 1 à [nomGroupeMax] caractères.
class _DialogNomGroupe extends StatefulWidget {
  const _DialogNomGroupe({required this.actuel});
  final String? actuel;

  @override
  State<_DialogNomGroupe> createState() => _EtatDialogNomGroupe();
}

class _EtatDialogNomGroupe extends State<_DialogNomGroupe> {
  late final TextEditingController _texte =
      TextEditingController(text: widget.actuel ?? '');
  String? _erreur;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  void _valider() {
    final nom = _texte.text.trim();
    if (nom.isEmpty || nom.length > nomGroupeMax) {
      setState(() => _erreur = 'Le nom doit faire de 1 à $nomGroupeMax caractères.');
      return;
    }
    Navigator.of(context).pop(nom);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.actuel == null ? 'Nouveau groupe' : 'Renommer le groupe'),
      content: TextField(
        key: const Key('nom_groupe'),
        controller: _texte,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Nom du groupe', errorText: _erreur),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
          key: const Key('annuler_nom_groupe'),
          style: TypeAction.gerer.texte,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('confirmer_nom_groupe'),
          style: TypeAction.gerer.plein,
          onPressed: _valider,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
