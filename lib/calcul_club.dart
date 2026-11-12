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

// ---------- Enregistrement (mission « Calcul du club », V2, décision 88) ----------
// Deux documents dans evenements/{e}/calcul_club, identifiants « repas » et « groupes » :
//   repas   = { jours: {"1": {gymnaseId: {joueusesMidi, joueusesSoir, benevolesMidi,
//               benevolesSoir, spectateursMidi, spectateursSoir}}} } (entiers)
//   groupes = { groupes: [{nom, pourcentages: {"1": 0.7}, produits: {produitId: {"1": 0.4}}}] }
// Les clés de jours sont des textes (Firestore). Une entrée hors format est ignorée à la
// lecture ; un document absent donne null. Aucune fonction de calcul ci-dessus n'est modifiée.

const _champsRepas = [
  'joueusesMidi',
  'joueusesSoir',
  'benevolesMidi',
  'benevolesSoir',
  'spectateursMidi',
  'spectateursSoir',
];

/// Le document « repas » : gymnase -> jour -> repas devient jour -> gymnase -> repas.
Map<String, dynamic> repasVersMap(Map<String, Map<int, RepasGymnaseJour>> repas) {
  final jours = <String, Map<String, Map<String, int>>>{};
  repas.forEach((gymnaseId, parJour) {
    parJour.forEach((jour, r) {
      jours.putIfAbsent('$jour', () => {})[gymnaseId] = {
        'joueusesMidi': r.joueusesMidi,
        'joueusesSoir': r.joueusesSoir,
        'benevolesMidi': r.benevolesMidi,
        'benevolesSoir': r.benevolesSoir,
        'spectateursMidi': r.spectateursMidi,
        'spectateursSoir': r.spectateursSoir,
      };
    });
  });
  return {'jours': jours};
}

/// Le document « repas » relu. Null si absent ; une entrée hors format est ignorée.
Map<String, Map<int, RepasGymnaseJour>>? repasDepuisMap(Map<String, dynamic>? doc) {
  if (doc == null) return null;
  final repas = <String, Map<int, RepasGymnaseJour>>{};
  final jours = doc['jours'];
  if (jours is! Map) return repas;
  jours.forEach((cleJour, parGymnase) {
    final jour = cleJour is String ? int.tryParse(cleJour) : null;
    if (jour == null || parGymnase is! Map) return;
    parGymnase.forEach((gymnaseId, valeurs) {
      final r = _repasDepuis(valeurs);
      if (gymnaseId is String && gymnaseId.isNotEmpty && r != null) {
        repas.putIfAbsent(gymnaseId, () => {})[jour] = r;
      }
    });
  });
  return repas;
}

/// Six entiers positifs ou nuls, sinon null (l'entrée est ignorée).
RepasGymnaseJour? _repasDepuis(Object? valeurs) {
  if (valeurs is! Map) return null;
  final n = <String, int>{};
  for (final champ in _champsRepas) {
    final v = valeurs[champ];
    if (v is! int || v < 0) return null;
    n[champ] = v;
  }
  return RepasGymnaseJour(
    joueusesMidi: n['joueusesMidi']!,
    joueusesSoir: n['joueusesSoir']!,
    benevolesMidi: n['benevolesMidi']!,
    benevolesSoir: n['benevolesSoir']!,
    spectateursMidi: n['spectateursMidi']!,
    spectateursSoir: n['spectateursSoir']!,
  );
}

/// Le document « groupes » : pourcentages et parts par jour, en fractions.
Map<String, dynamic> groupesVersMap(List<GroupeConso> groupes) => {
      'groupes': [
        for (final g in groupes)
          {
            'nom': g.nom,
            'pourcentages': {
              for (final e in g.pourcentages.entries) '${e.key}': e.value,
            },
            'produits': {
              for (final p in g.produits.entries)
                p.key: {for (final e in p.value.entries) '${e.key}': e.value},
            },
          },
      ],
    };

/// Le document « groupes » relu. Null si absent ; un groupe sans nom est ignoré, une part
/// qui n'est pas un nombre aussi.
List<GroupeConso>? groupesDepuisMap(Map<String, dynamic>? doc) {
  if (doc == null) return null;
  final liste = doc['groupes'];
  if (liste is! List) return const [];
  final groupes = <GroupeConso>[];
  for (final g in liste) {
    if (g is! Map || g['nom'] is! String || (g['nom'] as String).isEmpty) continue;
    groupes.add(GroupeConso(
      nom: g['nom'] as String,
      pourcentages: _partsDepuis(g['pourcentages']),
      produits: _produitsDepuis(g['produits']),
    ));
  }
  return groupes;
}

Map<int, double> _partsDepuis(Object? v) {
  final parts = <int, double>{};
  if (v is! Map) return parts;
  v.forEach((cle, x) {
    final jour = cle is String ? int.tryParse(cle) : null;
    if (jour != null && x is num) parts[jour] = x.toDouble();
  });
  return parts;
}

Map<String, Map<int, double>> _produitsDepuis(Object? v) {
  final produits = <String, Map<int, double>>{};
  if (v is! Map) return produits;
  v.forEach((cle, parts) {
    if (cle is String && cle.isNotEmpty) produits[cle] = _partsDepuis(parts);
  });
  return produits;
}

/// Le calcul du club d'un événement à partir de ses deux documents. Null si aucun des deux
/// n'existe (l'événement garde l'ancien calcul) ; s'il n'en existe qu'un, l'autre est vide.
CalculClub? calculClubDepuis(
    Map<String, dynamic>? repas, Map<String, dynamic>? groupes) {
  if (repas == null && groupes == null) return null;
  return CalculClub(
    repas: repasDepuisMap(repas) ?? const {},
    groupes: groupesDepuisMap(groupes) ?? const [],
  );
}
