import 'dart:async';

import 'package:flutter/material.dart';

import 'ecran_caisse.dart' show VignetteProduit;
import 'evenement.dart';
import 'gymnase.dart';
import 'liste_familles.dart';
import 'theme.dart';

/// Écran « Stock de départ » (mission « Ergonomie de la gestion », étape E4, décisions 54
/// et 63). Ouvert par la tâche « Stock de départ » d'Avant. Un onglet par gymnase (nom et
/// nombre de produits comptés) ; sous l'onglet, les produits finis par familles. Pour chaque
/// produit : − et +, et un champ au clavier (vide = non compté). « Copier vers » recopie les
/// quantités du gymnase affiché dans un autre, sans toucher aux produits déjà comptés là-bas.
/// Écriture par [definirStock] : la même que « Gymnases et stocks ».
class EcranStockDepart extends StatefulWidget {
  const EcranStockDepart({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.produits,
    required this.stocks,
    required this.definirStock,
    required this.onVoirGymnases,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;
  final Stream<List<Gymnase>> gymnases;

  /// Produits finis de l'événement (jamais d'ingrédient : ils n'ont pas de stock).
  final Stream<List<ProduitEvenement>> produits;

  /// Stock de départ : gymnase -> produit -> quantité (et marque « repris »).
  final Stream<Map<String, Map<String, StockDepart>>> stocks;

  /// Fixe la quantité d'un produit dans un gymnase (efface la marque « repris »).
  final Future<void> Function(String gymnaseId, String produitId, int quantite)
      definirStock;

  /// Renvoi vers « Gymnases et stocks » (événement ouvert : lecture seule ici).
  final VoidCallback onVoirGymnases;

  @override
  State<EcranStockDepart> createState() => _EtatEcranStockDepart();
}

class _EtatEcranStockDepart extends State<EcranStockDepart> {
  /// Gymnase affiché (null = le premier des gymnases gérés).
  String? _choisi;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: widget.evenement,
      builder: (context, sEv) => StreamBuilder<List<Gymnase>>(
        stream: widget.gymnases,
        builder: (context, sG) => StreamBuilder<List<ProduitEvenement>>(
          stream: widget.produits,
          builder: (context, sP) =>
              StreamBuilder<Map<String, Map<String, StockDepart>>>(
            stream: widget.stocks,
            builder: (context, sS) {
              final ev = sEv.data;
              final tous = sG.data;
              final liste = sP.data;
              final stock = sS.data;
              if (ev == null || tous == null || liste == null || stock == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final geres = [
                for (final g in tous)
                  if (widget.portee.gere(g.id)) g,
              ];
              if (geres.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Stock de départ')),
                  body: const Center(
                    child: Text('Aucun gymnase à gérer.',
                        key: Key('aucun_gymnase_stock')),
                  ),
                );
              }
              final courant = geres.firstWhere(
                (g) => g.id == _choisi,
                orElse: () => geres.first,
              );
              return _corps(context, ev, liste, stock, geres, courant);
            },
          ),
        ),
      ),
    );
  }

  Widget _corps(
    BuildContext context,
    Evenement ev,
    List<ProduitEvenement> liste,
    Map<String, Map<String, StockDepart>> stock,
    List<Gymnase> geres,
    Gymnase courant,
  ) {
    final modifiable = ev.enPreparation;
    final autres = [
      for (final g in geres)
        if (g.id != courant.id) g,
    ];
    final stockCourant = stock[courant.id] ?? const <String, StockDepart>{};

    int comptes(String gymnaseId) {
      final s = stock[gymnaseId] ?? const <String, StockDepart>{};
      return liste.where((p) => s.containsKey(p.id)).length;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stock de départ')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in geres)
                    g.id == courant.id
                        ? FilledButton(
                            key: Key('onglet_gymnase_${g.id}'),
                            style: TypeAction.gerer.plein,
                            onPressed: () => setState(() => _choisi = g.id),
                            child: Text('${g.nom} · ${comptes(g.id)}'),
                          )
                        : OutlinedButton(
                            key: Key('onglet_gymnase_${g.id}'),
                            style: TypeAction.gerer.contour,
                            onPressed: () => setState(() => _choisi = g.id),
                            child: Text('${g.nom} · ${comptes(g.id)}'),
                          ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Text(
                modifiable
                    ? "Ce qu'il y a déjà sur place. Laissez vide ce que vous ne "
                        'comptez pas. Les boissons se comptent en verres.'
                    : "L'événement est ouvert : le stock de départ se lit seulement. "
                        "Il se corrige dans « Gymnases et stocks ».",
                key: const Key('aide_stock_depart'),
              ),
            ),
            if (!modifiable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton(
                  key: const Key('aller_gymnases_stocks'),
                  style: TypeAction.gerer.contour,
                  onPressed: widget.onVoirGymnases,
                  child: const Text('Voir Gymnases et stocks'),
                ),
              ),
            Expanded(
              child: liste.isEmpty
                  ? const Center(
                      child: Text('Aucun produit dans cet événement.',
                          key: Key('aucun_produit_stock')),
                    )
                  : ListeFamilles<ProduitEvenement>(
                      key: Key('familles_stock_${courant.id}'),
                      elements: liste,
                      familleDe: (p) => p.fiche.famille,
                      nomDe: (p) => p.nom,
                      avecRecherche: false,
                      mentions: const {'fait_maison': 'Apporté le jour même'},
                      compteurDe: (items, _) =>
                          '${items.where((p) => stockCourant.containsKey(p.id)).length}'
                          ' sur ${items.length} comptés',
                      ligne: (context, p, couleur) => _LigneStockDepart(
                        key: Key('ligne_depart_${courant.id}_${p.id}'),
                        gymnaseId: courant.id,
                        produit: p,
                        couleur: couleur,
                        stock: stockCourant[p.id],
                        modifiable: modifiable,
                        definirStock: widget.definirStock,
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Palette.filet)),
              ),
              child: Row(
                children: [
                  if (modifiable && autres.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('copier_stock_depart'),
                        style: TypeAction.gerer.contour,
                        onPressed: () => _copier(context, courant, autres, stock, liste),
                        child: Text(autres.length == 1
                            ? 'Copier vers ${autres.first.nom}'
                            : 'Copier vers…'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      key: const Key('stock_depart_fait'),
                      style: TypeAction.reussir.plein,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("C'est fait"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Copie les quantités de [source] dans un autre gymnase, après confirmation. Les produits
  /// déjà comptés dans l'autre ne sont pas touchés.
  Future<void> _copier(
    BuildContext context,
    Gymnase source,
    List<Gymnase> autres,
    Map<String, Map<String, StockDepart>> stock,
    List<ProduitEvenement> liste,
  ) async {
    Gymnase? cible = autres.length == 1 ? autres.first : null;
    cible ??= await showDialog<Gymnase>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Copier vers quel gymnase ?'),
          children: [
            for (final g in autres)
              SimpleDialogOption(
                key: Key('choix_copie_${g.id}'),
                onPressed: () => Navigator.of(c).pop(g),
                child: Text(g.nom),
              ),
          ],
        ),
      );
    if (cible == null || !context.mounted) return;
    final destination = cible;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Copier le stock ?'),
        content: Text(
          'Les quantités de ${source.nom} sont recopiées dans ${destination.nom}. '
          'Les produits déjà comptés dans ${destination.nom} ne changent pas.',
          key: const Key('question_copie_stock'),
        ),
        actions: [
          TextButton(
            key: const Key('annuler_copie_stock'),
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('confirmer_copie_stock'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Copier'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final dejaDans = stock[destination.id] ?? const <String, StockDepart>{};
    final lues = stock[source.id] ?? const <String, StockDepart>{};
    final aCopier = [
      for (final p in liste)
        if (lues.containsKey(p.id) && !dejaDans.containsKey(p.id)) p,
    ];
    var copies = 0;
    try {
      for (final p in aCopier) {
        await widget.definirStock(destination.id, p.id, lues[p.id]!.quantite);
        copies++;
      }
    } catch (_) {
      if (context.mounted) _montrerErreur(context);
      return;
    }
    if (!context.mounted) return;
    final message = copies == 0
        ? 'Rien à copier : aucun produit compté ici n\'est libre dans '
            '${destination.nom}.'
        : '$copies produit${copies > 1 ? 's' : ''} copié${copies > 1 ? 's' : ''} '
            'dans ${destination.nom}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, key: const Key('copie_stock_faite'))),
    );
  }
}

void _montrerErreur(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Enregistrement impossible. Vérifiez le réseau.',
        key: Key('erreur_stock_depart')),
  ));
}

/// Une ligne de produit : image ou pastille, nom, « Repris » si la quantité vient d'un
/// report, puis − / champ / + (événement en préparation) ou la quantité lue.
class _LigneStockDepart extends StatefulWidget {
  const _LigneStockDepart({
    super.key,
    required this.gymnaseId,
    required this.produit,
    required this.couleur,
    required this.stock,
    required this.modifiable,
    required this.definirStock,
  });

  final String gymnaseId;
  final ProduitEvenement produit;
  final Color couleur;
  final StockDepart? stock;
  final bool modifiable;
  final Future<void> Function(String gymnaseId, String produitId, int quantite)
      definirStock;

  @override
  State<_LigneStockDepart> createState() => _EtatLigneStockDepart();
}

class _EtatLigneStockDepart extends State<_LigneStockDepart> {
  late final TextEditingController _texte =
      TextEditingController(text: _textePour(widget.stock));
  final FocusNode _focus = FocusNode();
  Timer? _pause;
  bool _modifie = false;
  String? _erreur;

  static String _textePour(StockDepart? s) => s?.quantite.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _enregistrer();
    });
  }

  @override
  void didUpdateWidget(_LigneStockDepart ancien) {
    super.didUpdateWidget(ancien);
    // Une valeur venue d'ailleurs remplace le champ, sauf pendant qu'on le modifie.
    if (!_modifie && !_focus.hasFocus) {
      final attendu = _textePour(widget.stock);
      if (_texte.text != attendu) _texte.text = attendu;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    if (_modifie) {
      final n = _lire(_texte.text);
      if (n != null) {
        widget.definirStock(widget.gymnaseId, widget.produit.id, n).catchError((_) {});
      }
    }
    _texte.dispose();
    _focus.dispose();
    super.dispose();
  }

  static int? _lire(String saisie) {
    final n = int.tryParse(saisie.trim());
    return n == null || n < 0 || n > 100000 ? null : n;
  }

  /// Écrit [n] si la quantité change. Un échec se dit à l'écran.
  Future<void> _ecrire(int n) async {
    if (n == widget.stock?.quantite) return;
    try {
      await widget.definirStock(widget.gymnaseId, widget.produit.id, n);
    } catch (_) {
      if (mounted) _montrerErreur(context);
    }
  }

  /// Saisie au clavier : enregistrée à la validation, en quittant le champ, ou après une pause.
  Future<void> _enregistrer() async {
    _pause?.cancel();
    if (!_modifie) return;
    final saisie = _texte.text.trim();
    if (saisie.isEmpty) {
      // Pas de quantité : rien à écrire, on remet ce qui est enregistré.
      setState(() {
        _modifie = false;
        _erreur = null;
        _texte.text = _textePour(widget.stock);
      });
      return;
    }
    final n = _lire(saisie);
    if (n == null) {
      setState(() => _erreur = 'Entrez un nombre entier de 0 à 100 000.');
      return;
    }
    setState(() {
      _erreur = null;
      _modifie = false;
    });
    await _ecrire(n);
  }

  /// Boutons − et + : la quantité affichée change d'un cran et s'enregistre tout de suite.
  Future<void> _ajuster(int delta) async {
    _pause?.cancel();
    final saisie = _texte.text.trim();
    final actuel = saisie.isEmpty ? 0 : _lire(saisie);
    if (actuel == null) {
      setState(() => _erreur = 'Entrez un nombre entier de 0 à 100 000.');
      return;
    }
    final n = actuel + delta;
    if (n < 0 || n > 100000) return;
    setState(() {
      _erreur = null;
      _modifie = false;
      _texte.text = n.toString();
    });
    await _ecrire(n);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final g = widget.gymnaseId;
    final stock = widget.stock;
    final image = p.photo != null || p.icone != null
        ? VignetteProduit(
            key: Key('vignette_depart_${g}_${p.id}'), icone: p.icone, photo: p.photo)
        : PastilleProduit(
            key: Key('pastille_depart_${g}_${p.id}'),
            nom: p.nom,
            couleur: widget.couleur,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          image,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nom,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                if (!widget.modifiable)
                  Text(
                    stock == null ? 'Stock non suivi' : 'Stock : ${stock.quantite}',
                    key: Key('lecture_depart_${g}_${p.id}'),
                  ),
                if (stock != null && stock.repris)
                  Text(
                    'Repris',
                    key: Key('repris_${g}_${p.id}'),
                    style: const TextStyle(
                        color: Palette.ocreFonce,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                if (_erreur != null)
                  Text(_erreur!,
                      key: Key('erreur_depart_${g}_${p.id}'),
                      style: const TextStyle(color: Palette.briqueFonce, fontSize: 12)),
              ],
            ),
          ),
          if (widget.modifiable) ...[
            IconButton.outlined(
              key: Key('moins_${g}_${p.id}'),
              tooltip: 'Moins',
              icon: const Icon(Icons.remove),
              onPressed: () => _ajuster(-1),
            ),
            SizedBox(
              width: 64,
              child: TextField(
                key: Key('depart_${g}_${p.id}'),
                controller: _texte,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: '—'),
                onChanged: (_) {
                  _modifie = true;
                  _pause?.cancel();
                  _pause = Timer(const Duration(milliseconds: 900), _enregistrer);
                },
                onSubmitted: (_) => _enregistrer(),
              ),
            ),
            IconButton.outlined(
              key: Key('plus_${g}_${p.id}'),
              tooltip: 'Plus',
              icon: const Icon(Icons.add),
              onPressed: () => _ajuster(1),
            ),
          ],
        ],
      ),
    );
  }
}
