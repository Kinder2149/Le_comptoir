import 'package:flutter/material.dart';

import 'depot_menus.dart' show nombrePourSaisie, parserNombre;
import 'evenement.dart';
import 'gymnase.dart';
import 'restes.dart';

/// Un produit qui a du stock à la clôture : candidat au report sur le prochain
/// événement (décision 48).
class CandidatReste {
  const CandidatReste({
    required this.gymnaseId,
    required this.nomGymnase,
    required this.produitId,
    required this.nomProduit,
    required this.quantite,
    this.verresParLitre,
  });

  final String gymnaseId;
  final String nomGymnase;
  final String produitId;
  final String nomProduit;

  /// Stock actuel, dans l'unité du stock (des verres pour un produit au litre).
  final int quantite;

  /// Produit au litre : on saisit des litres, le stock compte des verres.
  final double? verresParLitre;

  String get cle => '${gymnaseId}_$produitId';
  String get id => idReste(nomGymnase, nomProduit);
}

/// Les produits suivis qui ont encore du stock, gymnase par gymnase (dans l'ordre
/// des gymnases, puis des produits du menu).
List<CandidatReste> candidatsRestes({
  required List<Gymnase> gymnases,
  required List<ProduitEvenement> produits,
  required Map<String, Map<String, int>> stocks,
}) {
  return [
    for (final g in gymnases)
      for (final p in produits)
        if ((stocks[g.id]?[p.id] ?? 0) > 0)
          CandidatReste(
            gymnaseId: g.id,
            nomGymnase: g.nom,
            produitId: p.id,
            nomProduit: p.nom,
            quantite: stocks[g.id]![p.id]!,
            verresParLitre: p.fiche.type == 'litre' &&
                    (p.fiche.verresParLitre ?? 0) > 0
                ? p.fiche.verresParLitre
                : null,
          ),
  ];
}

/// Ce que la gestion a choisi de garder, et les restes d'un report plus ancien à
/// retirer (produits non gardés cette fois).
class ChoixRestes {
  const ChoixRestes({required this.gardes, required this.ecartes});

  final List<Reste> gardes;
  final List<String> ecartes;
}

/// Demande quoi garder pour le prochain événement. Null = retour (la clôture
/// n'a pas lieu).
Future<ChoixRestes?> demanderRestes(
  BuildContext context,
  List<CandidatReste> candidats,
) =>
    showDialog<ChoixRestes>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogueRestes(candidats: candidats),
    );

class _DialogueRestes extends StatefulWidget {
  const _DialogueRestes({required this.candidats});

  final List<CandidatReste> candidats;

  @override
  State<_DialogueRestes> createState() => _EtatDialogueRestes();
}

class _EtatDialogueRestes extends State<_DialogueRestes> {
  final _coches = <String, bool>{};
  final _saisies = <String, TextEditingController>{};
  String? _erreur;

  @override
  void initState() {
    super.initState();
    for (final c in widget.candidats) {
      _coches[c.cle] = false;
      _saisies[c.cle] = TextEditingController(text: _initiale(c));
    }
  }

  @override
  void dispose() {
    for (final s in _saisies.values) {
      s.dispose();
    }
    super.dispose();
  }

  String _initiale(CandidatReste c) => c.verresParLitre != null
      ? nombrePourSaisie(litresDepuisVerres(c.quantite, c.verresParLitre!))
      : '${c.quantite}';

  /// La quantité saisie, en unité de stock. Null si illisible ou hors limites.
  int? _quantite(CandidatReste c) {
    final n = parserNombre(_saisies[c.cle]!.text);
    if (n == null) return null;
    final q = c.verresParLitre != null
        ? verresDepuisLitres(n, c.verresParLitre!)
        : (n == n.roundToDouble() ? n.toInt() : null);
    return q != null && q >= 1 && q <= 100000 ? q : null;
  }

  void _garder() {
    final gardes = <Reste>[];
    final ecartes = <String>[];
    for (final c in widget.candidats) {
      if (_coches[c.cle] != true) {
        ecartes.add(c.id);
        continue;
      }
      final q = _quantite(c);
      if (q == null) {
        setState(() => _erreur =
            'Quantité à corriger : ${c.nomProduit} (${c.nomGymnase}).');
        return;
      }
      gardes.add(Reste(
          nomGymnase: c.nomGymnase, nomProduit: c.nomProduit, quantite: q));
    }
    Navigator.pop(context, ChoixRestes(gardes: gardes, ecartes: ecartes));
  }

  void _rienGarder() => Navigator.pop(
        context,
        ChoixRestes(gardes: const [], ecartes: [
          for (final c in widget.candidats) c.id,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final lignes = <Widget>[
      const Text(
        'Cochez ce qui se conserve (soda, café…). Ces restes seront repris au '
        'prochain événement, dans le gymnase du même nom.',
        key: Key('restes_aide'),
      ),
    ];
    String? courant;
    for (final c in widget.candidats) {
      if (c.nomGymnase != courant) {
        courant = c.nomGymnase;
        lignes.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(c.nomGymnase, style: theme.titleSmall),
        ));
      }
      final coche = _coches[c.cle] == true;
      lignes.add(Row(
        children: [
          Checkbox(
            key: Key('reste_coche_${c.cle}'),
            value: coche,
            onChanged: (v) => setState(() => _coches[c.cle] = v ?? false),
          ),
          Expanded(
            child: Text(
              c.verresParLitre != null
                  ? '${c.nomProduit}\nStock : ${c.quantite} verres'
                  : '${c.nomProduit}\nStock : ${c.quantite}',
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              key: Key('reste_qte_${c.cle}'),
              controller: _saisies[c.cle],
              enabled: coche,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                suffixText: c.verresParLitre != null ? 'L' : null,
              ),
            ),
          ),
        ],
      ));
    }
    if (_erreur != null) {
      lignes.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_erreur!,
            key: const Key('erreur_restes'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ));
    }
    return AlertDialog(
      title: const Text('Garder pour le prochain événement ?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: lignes),
      ),
      actions: [
        TextButton(
          key: const Key('retour_restes'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        TextButton(
          key: const Key('ne_rien_garder'),
          onPressed: _rienGarder,
          child: const Text('Ne rien garder'),
        ),
        FilledButton(
          key: const Key('garder_restes'),
          onPressed: _garder,
          child: const Text('Garder la sélection'),
        ),
      ],
    );
  }
}
