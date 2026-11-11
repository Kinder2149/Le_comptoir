import 'depot_caisses.dart' show TableauDeBord;
import 'depot_menus.dart' show cleIngredient;
import 'evenement.dart';
import 'export_bilan.dart' show CoutBilan, CoutConnu;
import 'previsions.dart' show consoAffichee, consoDepuisEvenement;
import 'ticket.dart' show formaterEuros;

// Mission « Retours du terrain », étape F6 (décision 74) : comparateur de deux tournois
// clôturés. Logique pure : aucune lecture de base ici (la lecture est dans
// ecran_extraction.dart, comme pour l'export). Aucun calcul de bilan nouveau : les
// chiffres viennent du tableau de bord, la consommation de previsions.dart.

/// Un tournoi clôturé, tel qu'il sert à la comparaison.
class PhotoTournoi {
  const PhotoTournoi({
    required this.nom,
    required this.personnes,
    required this.jours,
    required this.tableau,
    required this.produits,
    required this.cout,
  });

  final String nom;

  /// Somme des personnes des gymnases visibles par la personne.
  final int personnes;

  /// Durée de l'événement en jours.
  final double jours;

  final TableauDeBord tableau;
  final List<ProduitEvenement> produits;

  /// Coût et résultat des courses. Null = la personne n'y a pas accès (affiché « — »).
  final CoutBilan? cout;

  int get nbVentes => tableau.nbVentes;
  int get totalCentimes => tableau.totalCentimes;

  int? get coutCentimes => switch (cout) {
        CoutConnu c => c.coutCentimes,
        _ => null,
      };

  int? get resultatCentimes => switch (cout) {
        CoutConnu c => c.resultatCentimes,
        _ => null,
      };

  /// Consommation par personne et par jour de chaque produit (par identifiant), d'après
  /// ses ventes. Vide si le nombre de personnes ou de jours n'est pas réglé.
  Map<String, double> get consos => consoDepuisEvenement(
        produits: produits,
        produitsPasses: {for (final p in produits) p.id: p.nom},
        tableau: tableau,
        personnes: personnes,
        jours: jours,
      );
}

/// Une ligne par produit : le produit est retrouvé par son nom (sans casse ni accents).
/// Null = le produit est absent de ce tournoi, ou sa consommation n'est pas calculable.
class ComparaisonProduit {
  const ComparaisonProduit({
    required this.nom,
    this.vendusA,
    this.vendusB,
    this.consoA,
    this.consoB,
  });

  /// Nom tel qu'écrit dans le premier tournoi, sinon dans le second.
  final String nom;
  final int? vendusA;
  final int? vendusB;
  final double? consoA;
  final double? consoB;

  /// Écart : second tournoi moins premier, en consommation par personne et par jour.
  double? get ecart =>
      consoA == null || consoB == null ? null : consoB! - consoA!;
}

/// Compare les produits des deux tournois. L'ordre : ceux du premier tournoi, puis ceux
/// présents seulement dans le second.
List<ComparaisonProduit> comparerProduits(PhotoTournoi a, PhotoTournoi b) {
  final consosA = a.consos;
  final consosB = b.consos;
  final parCleA = {for (final p in a.produits) cleIngredient(p.nom): p};
  final parCleB = {for (final p in b.produits) cleIngredient(p.nom): p};
  final cles = [
    ...parCleA.keys,
    for (final k in parCleB.keys)
      if (!parCleA.containsKey(k)) k,
  ];
  final lignes = <ComparaisonProduit>[];
  for (final cle in cles) {
    final pa = parCleA[cle];
    final pb = parCleB[cle];
    lignes.add(ComparaisonProduit(
      nom: (pa ?? pb)!.nom,
      vendusA: pa == null ? null : a.tableau.vendus(pa.id),
      vendusB: pb == null ? null : b.tableau.vendus(pb.id),
      consoA: pa == null ? null : consosA[pa.id],
      consoB: pb == null ? null : consosB[pb.id],
    ));
  }
  return lignes;
}

/// Comment une valeur de la synthèse s'écrit.
enum Unite { nombre, decimal, euros }

/// Une ligne de la synthèse : la valeur de chaque tournoi (null = « — »). Les euros sont
/// en centimes.
class LigneSynthese {
  const LigneSynthese(this.libelle, this.unite, this.a, this.b);

  final String libelle;
  final Unite unite;
  final num? a;
  final num? b;
}

/// La synthèse côte à côte : personnes, jours, ventes, total, coût des courses, résultat.
List<LigneSynthese> synthese(PhotoTournoi a, PhotoTournoi b) => [
      LigneSynthese('Personnes', Unite.nombre, a.personnes, b.personnes),
      LigneSynthese('Jours', Unite.decimal, a.jours, b.jours),
      LigneSynthese('Ventes', Unite.nombre, a.nbVentes, b.nbVentes),
      LigneSynthese('Total des ventes', Unite.euros, a.totalCentimes, b.totalCentimes),
      LigneSynthese(
          'Coût des courses', Unite.euros, a.coutCentimes, b.coutCentimes),
      LigneSynthese(
          'Résultat', Unite.euros, a.resultatCentimes, b.resultatCentimes),
    ];

/// Le texte d'une valeur à l'écran : « — » si absente.
String texteValeur(num? v, Unite unite) {
  if (v == null) return '—';
  return switch (unite) {
    Unite.nombre => '${v.toInt()}',
    Unite.decimal => consoAffichee(v.toDouble()),
    Unite.euros => formaterEuros(v.toInt()),
  };
}

/// Le texte d'un écart : « +0,3 », « -0,5 », « 0 », ou « — » si absent.
String texteEcart(double? e) {
  if (e == null) return '—';
  if (e > 0) return '+${consoAffichee(e)}';
  return consoAffichee(e);
}
