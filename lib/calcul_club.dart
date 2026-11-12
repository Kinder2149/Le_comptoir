import 'courses.dart' show arrondiHaut;

// Calcul du club (mission Calcul du club, étape V1, décisions 86 à 88).
// Logique pure : aucun accès à la base, aucun écran. La quantité prévue d'un
// produit = Σ jours (repas du jour du gymnase × % du groupe ce jour × part du
// produit dans son groupe ce jour), arrondie une seule fois à l'unité supérieure
// par gymnase. Les pourcentages sont des fractions : 70 % s'écrit 0.7.
// Un événement sans CalculClub garde l'ancien calcul (courses.dart, inchangé).

/// Tolérance de comparaison à 100 % pour les parts d'un groupe.
const toleranceParts = 1e-9;

/// Repas d'un gymnase pour un jour : trois catégories, chacune midi et soir.
class RepasGymnaseJour {
  final int joueusesMidi;
  final int joueusesSoir;
  final int benevolesMidi;
  final int benevolesSoir;
  final int spectateursMidi;
  final int spectateursSoir;

  const RepasGymnaseJour({
    this.joueusesMidi = 0,
    this.joueusesSoir = 0,
    this.benevolesMidi = 0,
    this.benevolesSoir = 0,
    this.spectateursMidi = 0,
    this.spectateursSoir = 0,
  });

  /// Joueuses et accompagnateurs, bénévoles et famille, spectateurs : midi + soir.
  int get total =>
      joueusesMidi +
      joueusesSoir +
      benevolesMidi +
      benevolesSoir +
      spectateursMidi +
      spectateursSoir;
}

/// Un groupe de consommation du club (Plat, Dessert, Boissons froides…) : un
/// pourcentage par jour, et ses produits avec une part par jour.
class GroupeConso {
  final String nom;

  /// Jour (1, 2, …) → pourcentage du groupe ce jour (fraction).
  final Map<int, double> pourcentages;

  /// Id du produit → (jour → part du produit dans le groupe ce jour, fraction).
  final Map<String, Map<int, double>> produits;

  const GroupeConso({
    required this.nom,
    this.pourcentages = const {},
    this.produits = const {},
  });
}

/// Réglages du calcul du club pour un événement.
class CalculClub {
  /// Id du gymnase → (jour → repas).
  final Map<String, Map<int, RepasGymnaseJour>> repas;
  final List<GroupeConso> groupes;

  const CalculClub({this.repas = const {}, this.groupes = const []});
}

/// Un groupe dont les parts d'un jour ne font pas 100 %.
class EcartGroupe {
  final String groupe;
  final int jour;

  /// Somme réelle des parts des produits ce jour-là (1.0 = 100 %).
  final double somme;

  const EcartGroupe(
      {required this.groupe, required this.jour, required this.somme});

  /// Écart à 100 %, en fraction (positif = trop, négatif = pas assez).
  double get ecart => somme - 1.0;
}

/// Total des repas d'un gymnase pour un jour (0 si rien n'est saisi).
int repasDuJour(CalculClub calcul, String gymnaseId, int jour) =>
    calcul.repas[gymnaseId]?[jour]?.total ?? 0;

GroupeConso? _groupeDuProduit(CalculClub calcul, String produitId) {
  for (final g in calcul.groupes) {
    if (g.produits.containsKey(produitId)) return g;
  }
  return null;
}

/// Quantité d'un produit pour un gymnase et un jour, en nombre décimal non
/// arrondi. Null si le produit n'est dans aucun groupe : l'appelant garde alors
/// l'ancien calcul. Un jour sans pourcentage ou sans part compte pour 0.
double? quantiteClubJour(
    CalculClub calcul, String gymnaseId, String produitId, int jour) {
  final groupe = _groupeDuProduit(calcul, produitId);
  if (groupe == null) return null;
  final pct = groupe.pourcentages[jour] ?? 0.0;
  final part = groupe.produits[produitId]?[jour] ?? 0.0;
  return repasDuJour(calcul, gymnaseId, jour) * pct * part;
}

/// Quantité prévue d'un produit dans un gymnase : somme sur les jours, puis un
/// seul arrondi à l'unité supérieure. Null si le produit n'est dans aucun groupe
/// ou si le gymnase n'a aucun repas détaillé.
int? quantiteClub(CalculClub calcul, String gymnaseId, String produitId) {
  if (_groupeDuProduit(calcul, produitId) == null) return null;
  final jours = calcul.repas[gymnaseId]?.keys;
  if (jours == null || jours.isEmpty) return null;
  var somme = 0.0;
  for (final jour in jours) {
    somme += quantiteClubJour(calcul, gymnaseId, produitId, jour) ?? 0.0;
  }
  return arrondiHaut(somme);
}

/// Groupes dont les parts d'un jour ne font pas 100 % (tolérance 1e-9). Ne
/// corrige rien : la liste dit seulement où est l'écart. Un jour n'est examiné
/// que si au moins un produit du groupe y a une part.
List<EcartGroupe> ecartsGroupes(CalculClub calcul) {
  final ecarts = <EcartGroupe>[];
  for (final g in calcul.groupes) {
    final jours = <int>{
      for (final parts in g.produits.values) ...parts.keys,
    }.toList()
      ..sort();
    for (final jour in jours) {
      var somme = 0.0;
      for (final parts in g.produits.values) {
        somme += parts[jour] ?? 0.0;
      }
      if ((somme - 1.0).abs() > toleranceParts) {
        ecarts.add(EcartGroupe(groupe: g.nom, jour: jour, somme: somme));
      }
    }
  }
  return ecarts;
}
