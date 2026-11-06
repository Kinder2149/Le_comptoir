import 'dart:async';

import 'package:flutter/material.dart';

import 'ecran_caisse.dart' show VignetteProduit;
import 'evenement.dart';
import 'gymnase.dart';
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
    required this.onVoirGymnases,
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
