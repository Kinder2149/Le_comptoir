import 'package:flutter/material.dart';

import 'depot_menus.dart';

/// Affichage des unités d'un stock (décision 83). Le stock est compté dans l'unité de
/// vente (verres, parts, unités) ; cette fonction y ajoute l'unité d'achat quand le
/// produit en a une. Affichage seulement : rien n'est saisi, stocké ni calculé ici.
String _mot(num n, String singulier, String pluriel) =>
    n.abs() < 2 ? singulier : pluriel;

String _nombre(num n) => nombrePourSaisie(n.toDouble());

/// « 6 L · 24 verres » (au litre, verres par litre connu), « 2 gâteaux · 16 parts »
/// (à la part, parts par gâteau connu). Fiche incomplète : l'unité de vente seule
/// (« 24 verres », « 16 parts »). Autres produits : la quantité seule (« 24 »).
String libelleStockUnites(FicheProduit fiche, num quantiteEnUniteDeVente) {
  final q = quantiteEnUniteDeVente;
  switch (fiche.type) {
    case 'litre':
      final vente = '${_nombre(q)} ${_mot(q, 'verre', 'verres')}';
      final r = fiche.verresParLitre;
      if (r == null || r <= 0) return vente;
      return '${_nombre(q / r)} L · $vente';
    case 'part':
      final vente = '${_nombre(q)} ${_mot(q, 'part', 'parts')}';
      final r = fiche.partsParEntier;
      if (r == null || r <= 0) return vente;
      final entiers = q / r;
      return '${_nombre(entiers)} ${_mot(entiers, 'gâteau', 'gâteaux')} · $vente';
    default:
      return _nombre(q);
  }
}

/// Vrai si le produit a une unité à montrer en plus de la quantité (au litre ou à la part).
bool aUnitesAffichees(FicheProduit fiche) =>
    fiche.type == 'litre' || fiche.type == 'part';

/// Petite ligne « 6 L · 24 verres » à placer sous une quantité de stock ; rien pour
/// un produit sans autre unité.
class UnitesStock extends StatelessWidget {
  const UnitesStock({
    super.key,
    required this.fiche,
    required this.quantite,
    this.style,
  });

  final FicheProduit fiche;
  final num? quantite;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final q = quantite;
    if (q == null || !aUnitesAffichees(fiche)) return const SizedBox.shrink();
    return Text(libelleStockUnites(fiche, q),
        style: style ?? const TextStyle(fontSize: 12));
  }
}
