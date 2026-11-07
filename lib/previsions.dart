import 'depot_caisses.dart' show TableauDeBord;
import 'depot_menus.dart' show cleIngredient;
import 'evenement.dart';

// Prévision de consommation d'un événement (mission « Préparer l'événement », P4,
// décision 56). Logique pure : aucune lecture de base ici. Un chiffre par produit, la
// consommation par personne et par jour, propre à l'événement, avec sa source. Le menu
// et le produit de l'événement ne changent jamais ; un produit sans prévision garde le
// chiffre du menu.

/// Source d'un chiffre qui vient du menu (aucune prévision enregistrée).
const sourceMenu = 'Menu';

/// Source d'un chiffre corrigé par la gestion.
const sourceMain = 'Modifié à la main';

/// Plafond d'une consommation par personne et par jour (le même que dans le menu).
const consoPrevisionMax = 1000.0;

/// Longueur maximale d'une source (la même limite que dans les règles).
const sourceLongueurMax = 80;

/// « Événement : Tournoi 2025 » (coupé à [sourceLongueurMax] caractères).
String sourceEvenement(String nom) {
  final s = 'Événement : ${nom.trim()}';
  return s.length <= sourceLongueurMax ? s : s.substring(0, sourceLongueurMax);
}

/// Message quand des événements passés ne peuvent pas servir de référence.
const messageSansPersonnes =
    'Les événements passés sans nombre de personnes réglé ne peuvent pas servir de référence.';

/// Une prévision enregistrée pour un produit : le chiffre et d'où il vient.
class Prevision {
  const Prevision(this.conso, this.source);

  final double conso;
  final String source;
}

/// Une ligne du tableau de prévision : un produit, son chiffre et sa source.
class PrevisionProduit {
  const PrevisionProduit(this.produitId, this.nom, this.conso, this.source);

  final String produitId;
  final String nom;
  final double conso;
  final String source;

  bool get modifieALaMain => source == sourceMain;
}

/// Le tableau : un produit par ligne, dans l'ordre des produits. Le chiffre est celui
/// de la prévision, sinon celui du menu (0 s'il n'en a pas), avec la source « Menu ».
List<PrevisionProduit> fusionnerPrevisions(
        List<ProduitEvenement> produits, Map<String, Prevision> previsions) =>
    [
      for (final p in produits)
        if (previsions[p.id] case final prev?)
          PrevisionProduit(p.id, p.nom, prev.conso, prev.source)
        else
          PrevisionProduit(p.id, p.nom, p.fiche.conso ?? 0, sourceMenu),
    ];

/// Les produits avec la consommation de la prévision quand il y en a une (c'est ce
/// que les courses utilisent) ; les autres gardent celle du menu.
List<ProduitEvenement> produitsAvecPrevisions(
        List<ProduitEvenement> produits, Map<String, Prevision> previsions) =>
    [
      for (final p in produits)
        if (previsions[p.id] case final prev?) p.avecConso(prev.conso) else p,
    ];

/// Un événement passé clôturé qui peut servir de référence.
class ReferencePassee {
  const ReferencePassee({
    required this.id,
    required this.nom,
    required this.date,
    required this.personnes,
    required this.jours,
  });

  final String id;
  final String nom;
  final String date;

  /// Somme des personnes réglées de tous ses gymnases.
  final int personnes;
  final double jours;
}

/// Les événements passés : ceux qui peuvent servir de référence, et combien en sont
/// écartés faute de nombre de personnes réglé.
class EvenementsPasses {
  const EvenementsPasses(this.utilisables, this.sansPersonnes);

  final List<ReferencePassee> utilisables;
  final int sansPersonnes;
}

/// Trie les événements clôturés : ceux dont la somme des personnes réglées est
/// positive (et la durée connue) sont proposés, les plus récents d'abord ; les autres
/// sont seulement comptés.
EvenementsPasses selectionnerReferences(Iterable<ReferencePassee> clotures) {
  final bons = [
    for (final r in clotures)
      if (r.personnes > 0 && r.jours > 0) r,
  ]..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
    });
  return EvenementsPasses(bons, clotures.length - bons.length);
}

/// La consommation par personne et par jour d'après un événement passé : les ventes
/// non annulées du produit (le tableau de bord les exclut déjà) divisées par les
/// personnes de l'événement passé puis par sa durée. Le produit est retrouvé par son
/// nom (sans casse ni accents) ; [produitsPasses] = identifiant -> nom des produits de
/// l'événement passé. Un produit absent de l'événement passé n'est pas dans le
/// résultat : il garde le chiffre du menu.
Map<String, double> consoDepuisEvenement({
  required List<ProduitEvenement> produits,
  required Map<String, String> produitsPasses,
  required TableauDeBord tableau,
  required int personnes,
  required double jours,
}) {
  if (personnes <= 0 || jours <= 0) return const {};
  final vendusParNom = <String, int>{};
  for (final e in produitsPasses.entries) {
    final cle = cleIngredient(e.value);
    vendusParNom[cle] = (vendusParNom[cle] ?? 0) + tableau.vendus(e.key);
  }
  return {
    for (final p in produits)
      if (vendusParNom[cleIngredient(p.nom)] case final vendus?)
        p.id: vendus / personnes / jours,
  };
}

/// Le chiffre tel qu'on l'écrit à l'écran : « 2 », « 1,5 », « 1,67 » (2 décimales
/// au plus).
String consoAffichee(double v) {
  if (v == v.roundToDouble()) return '${v.toInt()}';
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s.replaceAll('.', ',');
}

/// Une consommation saisie : 0 à [consoPrevisionMax], virgule ou point. Sinon null.
double? lireConso(String saisie) {
  final n = double.tryParse(saisie.trim().replaceAll(',', '.'));
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n < 0 || n > consoPrevisionMax ? null : n;
}

/// Les ventes d'un événement passé ne peuvent pas être lues avec les droits de la
/// personne (elle n'est pas rattachée à tous ses gymnases). Rien n'est écrit.
class LectureRefusee implements Exception {
  const LectureRefusee();
}
