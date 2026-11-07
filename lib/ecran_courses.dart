import 'dart:async';

import 'package:flutter/material.dart';

import 'courses.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'ecran_caisse.dart' show couleurEtat;
import 'ecran_validation_courses.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'partage.dart';
import 'ticket.dart';

/// Courses d'un événement, en préparation : durée à couvrir (choix local à l'écran,
/// jamais écrit dans l'événement), personnes attendues (lues, réglées dans la
/// Préparation), quantités de produits finaux par gymnase (pré-remplies,
/// modifiables), liste « À acheter » calculée, « ce qu'il reste » et lignes libres.
/// Tout s'enregistre tout seul.
class EcranCourses extends StatefulWidget {
  const EcranCourses({
    super.key,
    required this.depot,
    required this.evenementId,
    this.partager = partagerFichierTexte,
    this.onAllerPreparation,
  });

  final DepotEvenements depot;
  final String evenementId;

  /// Remet la liste à partager à la feuille de partage (remplaçable dans les tests).
  final Partageur partager;

  /// Ouvre la Préparation (où se règlent personnes et durée) ; null = pas de renvoi.
  final Future<void> Function()? onAllerPreparation;

  @override
  State<EcranCourses> createState() => _EtatCourses();
}

class _EtatCourses extends State<EcranCourses> {
  bool _charge = false;
  Object? _erreurChargement;

  List<ProduitEvenement> _produits = const [];
  List<Gymnase> _gymnases = const [];
  Map<String, List<String>> _suggeres = const {};

  /// Durée de l'événement (réglée dans la Préparation) et choix local de durée à
  /// couvrir : 'tout' (= durée de l'événement, par défaut), 'demi', 'jour' ou 'plus'.
  double _joursEvenement = joursParDefaut;
  String _choixDuree = 'tout';
  int _joursPlus = 2;
  final Map<String, int> _personnes = {};

  double get _jours => switch (_choixDuree) {
        'demi' => demiJournee,
        'jour' => 1.0,
        'plus' => _joursPlus.toDouble(),
        _ => _joursEvenement,
      };

  /// Stock actuel (gymnase -> produit -> quantité), relu à chaque « Recalculer ».
  Map<String, Map<String, int>> _stocks = const {};

  /// Le « vendu » de chaque gymnase, écouté une seule fois pour tout l'écran
  /// (réécouter à chaque recalcul relancerait la lecture des ventes).
  final Map<String, StreamSubscription<TableauDeBord>> _abonnementsVendus = {};
  final Map<String, TableauDeBord> _tableaux = {};
  ListeCourses _liste = const ListeCourses();

  Timer? _minuteur;
  bool _listeModifiee = false;
  bool _enregistre = true;
  bool _erreurEnregistrement = false;

  /// Change quand la liste est recalculée : les champs sont reconstruits.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    if (_minuteur?.isActive ?? false) {
      _minuteur!.cancel();
      _enregistrer();
    }
    for (final a in _abonnementsVendus.values) {
      a.cancel();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final id = widget.evenementId;
      final evenement = await widget.depot.suivreEvenement(id).first;
      final produits = await widget.depot.suivreProduits(id).first;
      final gymnases = await widget.depot.suivreGymnases(id).first;
      final etats = await widget.depot.suivreEtats(id).first;
      final stocks = await widget.depot.suivreStocksParGymnase(id).first;
      final enregistree = await widget.depot.suivreListeCourses(id).first;
      if (!mounted) return;
      setState(() {
        _produits = produits;
        _gymnases = gymnases;
        _stocks = stocks;
        for (final g in gymnases) {
          _abonnementsVendus[g.id] ??= widget.depot
              .caisses(id)
              .suivreTableauDeBord(gymnaseIds: {g.id})
              .listen((t) {
            if (mounted) setState(() => _tableaux[g.id] = t);
          });
        }
        _suggeres = produitsSuggeres(etats, gymnases);
        _joursEvenement = evenement?.nbJours ?? joursParDefaut;
        for (final g in gymnases) {
          _personnes[g.id] = g.personnes;
        }
        _liste = enregistree ??
            listeParDefaut(
                produits: produits,
                gymnases: gymnases,
                jours: _jours,
                stocks: stocks);
        _charge = true;
      });
    } catch (e) {
      if (mounted) setState(() => _erreurChargement = e);
    }
  }

  void _planifier() {
    setState(() => _enregistre = false);
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 700), _enregistrer);
  }

  Future<void> _enregistrer() async {
    final id = widget.evenementId;
    final liste = _listeModifiee;
    _listeModifiee = false;
    try {
      if (liste) await widget.depot.enregistrerListeCourses(id, _liste);
      if (mounted) {
        setState(() {
          _enregistre = true;
          _erreurEnregistrement = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _erreurEnregistrement = true);
    }
  }

  /// Enregistre tout de suite ce qui est en attente, puis ouvre la validation.
  Future<void> _valider() async {
    _minuteur?.cancel();
    _listeModifiee = true; // le document doit exister avant la validation
    await _enregistrer();
    if (!mounted) return;
    if (_erreurEnregistrement) return;
    final fait = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranValidationCourses(
          depot: widget.depot,
          evenementId: widget.evenementId,
          produits: _produits,
          gymnases: _gymnases,
          liste: _liste,
        ),
      ),
    );
    if (fait == true && mounted) {
      setState(() => _charge = false);
      await _charger();
    }
  }

  /// Partage la liste « À acheter » et les lignes libres, en texte.
  Future<void> _partagerListe() async {
    final texte = texteListeCourses(
        'Liste de courses', calculerAchats(_produits, _liste), _liste.libres);
    try {
      await widget.partager('liste-de-courses.txt', texte);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Le partage n'a pas pu s'ouvrir. Réessayez.")));
    }
  }

  /// Après une validation : la liste repart vide, le cumul garde coût et ajouts.
  Future<void> _nouvelleSerie() async {
    try {
      await widget.depot.nouvelleSerieCourses(widget.evenementId, _liste);
      if (!mounted) return;
      setState(() => _charge = false);
      await _charger();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "La nouvelle série n'a pas pu s'ouvrir. Vérifiez la connexion et réessayez.")));
    }
  }

  void _modifierListe(ListeCourses l) {
    _liste = l;
    _listeModifiee = true;
    _planifier();
  }

  /// « Plus » : un nombre entier de jours, de 2 à [joursMax]. Choix local : il ne
  /// change jamais la durée de l'événement.
  void _surJours(String texte) {
    final n = int.tryParse(texte.trim());
    if (n == null || n < 2 || n > joursMax) return;
    setState(() => _joursPlus = n);
  }

  /// Tout l'événement (par défaut), demi-journée, jour complet ou plus.
  void _choisirDuree(String choix) => setState(() => _choixDuree = choix);

  /// Va régler personnes et durée dans la Préparation, puis relit ces réglages.
  Future<void> _allerPreparation() async {
    await widget.onAllerPreparation?.call();
    if (!mounted) return;
    try {
      final id = widget.evenementId;
      final evenement = await widget.depot.suivreEvenement(id).first;
      final gymnases = await widget.depot.suivreGymnases(id).first;
      if (!mounted) return;
      setState(() {
        _joursEvenement = evenement?.nbJours ?? joursParDefaut;
        _gymnases = gymnases;
        for (final g in gymnases) {
          _personnes[g.id] = g.personnes;
        }
      });
    } catch (_) {}
  }

  Future<void> _recalculer() async {
    // Le stock est relu : l'estimation tient compte de ce qu'il reste maintenant.
    try {
      final stocks = await widget.depot.suivreStocksParGymnase(widget.evenementId).first;
      if (!mounted) return;
      _stocks = stocks;
    } catch (_) {
      if (!mounted) return;
    }
    final base = listeParDefaut(
      produits: _produits,
      gymnases: [for (final g in _gymnases) Gymnase(g.id, g.nom, _personnes[g.id] ?? 0)],
      jours: _jours,
      stocks: _stocks,
    );
    setState(() {
      _version++;
      _modifierListe(_liste.avec(lignes: base.lignes));
    });
  }

  void _cocher(Gymnase g, ProduitEvenement p, bool oui) {
    int? quantite;
    if (oui) {
      final conso = p.fiche.conso ?? 0;
      quantite = quantiteAPrevoir(
          personnes: _personnes[g.id] ?? 0,
          jours: _jours,
          conso: conso,
          stock: _stocks[g.id]?[p.id]);
    }
    setState(() {
      _version++;
      _modifierListe(_liste.avecQuantite(g.id, p.id, quantite));
    });
  }

  void _surQuantite(Gymnase g, ProduitEvenement p, String texte) {
    final n = int.tryParse(texte.trim());
    if (n == null || n < 0 || n > 100000) return;
    setState(() => _modifierListe(_liste.avecQuantite(g.id, p.id, n)));
  }

  void _surReste(String cle, String texte) {
    final t = texte.trim().replaceAll(',', '.');
    final restes = {..._liste.restes};
    if (t.isEmpty) {
      restes.remove(cle);
    } else {
      final v = double.tryParse(t);
      if (v == null || v < 0 || v > 1000000) return;
      restes[cle] = v;
    }
    setState(() => _modifierListe(_liste.avec(restes: restes)));
  }

  Future<void> _ajouterLibre() async {
    final ligne = await showDialog<LigneLibre>(
      context: context,
      builder: (_) => const _DialogueLibre(),
    );
    if (ligne == null || !mounted) return;
    setState(() => _modifierListe(_liste.avec(libres: [..._liste.libres, ligne])));
  }

  void _retirerLibre(int i) {
    final libres = [..._liste.libres]..removeAt(i);
    setState(() => _modifierListe(_liste.avec(libres: libres)));
  }

  String _nombre(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: _erreurChargement != null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Impossible de charger les courses.',
                  key: Key('erreur_courses')),
            )
          : !_charge
              ? const Center(child: CircularProgressIndicator())
              : _contenu(context),
    );
  }

  Widget _contenu(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    final achats = calculerAchats(_produits, _liste);
    final aucunePersonne = _gymnases.every((g) => (_personnes[g.id] ?? 0) == 0);
    final validee = _liste.validation;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (validee != null) _bandeauValidee(context, validee),
        if (validee == null && _liste.precedent.series > 0)
          _bandeauSeries(context),
        // Une liste validée ne bouge plus : on la relit seulement.
        AbsorbPointer(
          absorbing: validee != null,
          child: Opacity(
            opacity: validee != null ? 0.6 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _corps(context, titre, achats, aucunePersonne),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('partager_liste'),
          onPressed: _partagerListe,
          icon: const Icon(Icons.ios_share),
          label: const Text('Partager la liste'),
        ),
        if (validee == null) ...[
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('valider_courses'),
            onPressed: _liste.lignes.isEmpty ? null : _valider,
            child: const Text('Valider les courses'),
          ),
        ] else ...[
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('nouvelle_serie'),
            onPressed: _nouvelleSerie,
            child: const Text('Nouvelle série de courses'),
          ),
        ],
      ],
    );
  }

  /// Les séries déjà validées pendant que la suivante se prépare : coût cumulé
  /// et ce que le stock a déjà reçu.
  Widget _bandeauSeries(BuildContext context) {
    final p = _liste.precedent;
    final noms = {for (final x in _produits) x.id: x.nom};
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.series == 1
                  ? '1 série déjà validée'
                  : '${p.series} séries déjà validées',
              key: const Key('series_validees'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Coût cumulé : ${coutAffiche(p.coutCentimes)}',
                key: const Key('cout_cumule')),
            const Text('Déjà ajouté au stock :'),
            for (final e in p.ajouts.entries)
              Text('${noms[e.key] ?? '?'} +${e.value}', key: Key('ajout_${e.key}')),
          ],
        ),
      ),
    );
  }

  Widget _bandeauValidee(BuildContext context, ValidationCourses v) {
    final noms = {for (final p in _produits) p.id: p.nom};
    // Toutes les séries validées : celles d'avant et celle-ci (mission C1).
    final parProduit = _liste.ajoutsTotaux;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v.valideeLe == null
                  ? 'Courses validées'
                  : 'Courses validées le ${dateHeureAffichee(v.valideeLe!)}',
              key: const Key('courses_validee'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
                _liste.seriesValidees > 1
                    ? 'Coût cumulé (${_liste.seriesValidees} séries) : ${coutAffiche(_liste.coutTotalCentimes)}'
                    : 'Coût : ${coutAffiche(v.coutCentimes)}',
                key: const Key('cout_valide')),
            const Text('Ajouté au stock :'),
            for (final e in parProduit.entries)
              Text('${noms[e.key] ?? '?'} +${e.value}', key: Key('ajout_${e.key}')),
          ],
        ),
      ),
    );
  }

  List<Widget> _corps(
    BuildContext context,
    TextStyle? titre,
    List<Achat> achats,
    bool aucunePersonne,
  ) {
    return [
        Text(
          _erreurEnregistrement
              ? "L'enregistrement a échoué : vérifiez votre connexion."
              : _enregistre
                  ? 'Enregistré'
                  : 'Enregistrement…',
          key: const Key('etat_courses'),
          style: TextStyle(
              color: _erreurEnregistrement
                  ? Theme.of(context).colorScheme.error
                  : null),
        ),
        const SizedBox(height: 12),
        Text('Réglages', style: titre),
        const SizedBox(height: 8),
        Text('Durée à couvrir', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          key: const Key('duree_courses'),
          spacing: 8,
          children: [
            for (final (valeur, cle, texte) in [
              ('tout', 'duree_tout', 'Tout l\u2019événement (${_nombre(_joursEvenement)} j)'),
              ('demi', 'duree_demi', 'Demi-journée'),
              ('jour', 'duree_jour', 'Jour complet'),
              ('plus', 'duree_plus', 'Plus'),
            ])
              ChoiceChip(
                key: Key(cle),
                label: Text(texte),
                selected: _choixDuree == valeur,
                onSelected: (_) => _choisirDuree(valeur),
              ),
          ],
        ),
        if (_choixDuree == 'plus')
          TextFormField(
            key: const Key('jours_courses'),
            initialValue: '$_joursPlus',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nombre de jours (2 à 30)'),
            onChanged: _surJours,
          ),
        const SizedBox(height: 8),
        for (final g in _gymnases)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _gymnases.length > 1
                  ? 'Personnes attendues (${g.nom}) : ${_personnes[g.id] ?? 0}'
                  : 'Personnes attendues : ${_personnes[g.id] ?? 0}',
              key: Key('lecture_personnes_${g.id}'),
            ),
          ),
        const Text('Réglé dans la Préparation.', key: Key('mention_preparation')),
        if (aucunePersonne)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aucune personne attendue : réglez-les dans la Préparation, '
                  'puis « Recalculer » : les quantités se remplissent.',
                  key: Key('aide_personnes'),
                ),
                if (widget.onAllerPreparation != null)
                  OutlinedButton(
                    key: const Key('aller_preparation'),
                    onPressed: _allerPreparation,
                    child: const Text('Aller à la Préparation'),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('recalculer'),
            onPressed: _recalculer,
            child: const Text('Recalculer les quantités (remplace vos changements)'),
          ),
        ),
        const Divider(),
        KeyedSubtree(
          key: ValueKey(_version),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final g in _gymnases) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                      _gymnases.length > 1 ? 'Produits : ${g.nom}' : 'Produits',
                      style: titre),
                ),
                for (final p in _produits) _ligneProduit(g, p, _tableaux[g.id]),
              ],
              const Divider(),
              Text('À acheter', style: titre),
              if (achats.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Rien à acheter pour l’instant.',
                      key: Key('aucun_achat')),
                ),
              for (final a in achats) _ligneAchat(a),
            ],
          ),
        ),
        const Divider(),
        Text('Autres achats (lignes libres)', style: titre),
        const Text(
            'Matériel, produits d’entretien… Gardés ici pour tout centraliser ; '
            'ils n’entrent pas dans le stock.'),
        for (var i = 0; i < _liste.libres.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_liste.libres[i].nom} × ${_nombre(_liste.libres[i].quantite)}',
              key: Key('libre_$i'),
            ),
            trailing: IconButton(
              key: Key('retirer_libre_$i'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Retirer',
              onPressed: () => _retirerLibre(i),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('ajouter_libre'),
            onPressed: _ajouterLibre,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une ligne'),
          ),
        ),
    ];
  }

  Widget _ligneProduit(Gymnase g, ProduitEvenement p, TableauDeBord? tableau) {
    final quantite = _liste.quantite(g.id, p.id);
    final stock = _stocks[g.id]?[p.id];
    final info = [
      stock == null ? 'Stock non suivi' : 'En stock : $stock',
      'Vendu : ${tableau == null ? '…' : tableau.vendus(p.id)}',
    ].join(' · ');
    final suggere = _suggeres[p.id]?.contains(g.nom) ?? false;
    return Row(
      children: [
        Checkbox(
          key: Key('coche_${g.id}_${p.id}'),
          value: quantite != null,
          onChanged: (v) => _cocher(g, p, v ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nom),
              Text(info,
                  key: Key('info_${g.id}_${p.id}'),
                  style: const TextStyle(fontSize: 12)),
              if (suggere)
                Text(
                  'Suggéré : stock bas',
                  key: Key('suggere_${g.id}_${p.id}'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: couleurEtat(EtatStock.bas)),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 128,
          child: quantite == null
              ? const SizedBox.shrink()
              : TextFormField(
                  key: Key('qte_${g.id}_${p.id}'),
                  initialValue: '$quantite',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: p.fiche.type == 'litre' ? ' verres' : null,
                  ),
                  onChanged: (t) => _surQuantite(g, p, t),
                ),
        ),
      ],
    );
  }

  Widget _ligneAchat(Achat a) {
    final reste = _liste.restes[a.cle];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${a.nom} : ${formaterQuantite(a.aAcheter, a.uniteBase)}',
              key: Key('achat_${a.cle}'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 130,
            child: TextFormField(
              key: Key('reste_${a.cle}'),
              initialValue: reste == null ? '' : _nombre(reste),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Il reste',
                suffixText: libelleUniteReste(a.uniteBase),
              ),
              onChanged: (t) => _surReste(a.cle, t),
            ),
          ),
        ],
      ),
    );
  }
}

/// Saisie d'une ligne libre : un nom et une quantité.
class _DialogueLibre extends StatefulWidget {
  const _DialogueLibre();

  @override
  State<_DialogueLibre> createState() => _EtatDialogueLibre();
}

class _EtatDialogueLibre extends State<_DialogueLibre> {
  final _nom = TextEditingController();
  final _quantite = TextEditingController(text: '1');
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _quantite.dispose();
    super.dispose();
  }

  void _valider() {
    final nom = _nom.text.trim();
    final q = double.tryParse(_quantite.text.trim().replaceAll(',', '.'));
    if (nom.isEmpty || nom.length > 60) {
      setState(() => _erreur = 'Entrez un nom (60 caractères au plus).');
    } else if (q == null || q <= 0 || q > 100000) {
      setState(() => _erreur = 'Entrez une quantité supérieure à zéro.');
    } else {
      Navigator.pop(context, LigneLibre(nom, q));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une ligne'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('nom_libre'),
            controller: _nom,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          TextField(
            key: const Key('quantite_libre'),
            controller: _quantite,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Quantité', errorText: _erreur),
            onSubmitted: (_) => _valider(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_libre'),
            onPressed: _valider,
            child: const Text('Ajouter')),
      ],
    );
  }
}
