import 'depot_menus.dart' show cleIngredient;

/// Un produit gardé pour le prochain événement (décision 48) : le stock restant
/// d'un produit dans un gymnase, retrouvé plus tard par les NOMS du gymnase et du
/// produit (sans casse, accents ni espaces autour). La quantité est dans l'unité du
/// stock (des verres pour un produit au litre).
class Reste {
  const Reste({
    required this.nomGymnase,
    required this.nomProduit,
    required this.quantite,
  });

  final String nomGymnase;
  final String nomProduit;
  final int quantite;

  /// Identifiant du document : le même couple gymnase/produit donne le même
  /// identifiant, donc un nouveau report remplace l'ancien.
  String get id => idReste(nomGymnase, nomProduit);

  @override
  bool operator ==(Object other) =>
      other is Reste &&
      other.nomGymnase == nomGymnase &&
      other.nomProduit == nomProduit &&
      other.quantite == quantite;

  @override
  int get hashCode => Object.hash(nomGymnase, nomProduit, quantite);
}

String _tranche(String nom) {
  final t = cleIngredient(nom)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return t.isEmpty ? 'x' : t;
}

/// « gymnase-1__cafe » : lettres et chiffres seulement (identifiant de document).
String idReste(String nomGymnase, String nomProduit) =>
    '${_tranche(nomGymnase)}__${_tranche(nomProduit)}';

/// Un reste retrouvé dans le nouvel événement : où il va et combien.
class Reprise {
  const Reprise({
    required this.gymnaseId,
    required this.produitId,
    required this.reste,
  });

  final String gymnaseId;
  final String produitId;
  final Reste reste;
}

/// Ce que le nouvel événement reprend. [gymnases] et [produits] vont de
/// l'identifiant au nom. Un reste n'est repris qu'une fois (si deux gymnases ou deux
/// produits portent le même nom, le premier l'emporte). Les autres restes
/// attendent un événement qui leur correspond.
List<Reprise> repriseDesRestes({
  required Iterable<Reste> restes,
  required Map<String, String> gymnases,
  required Map<String, String> produits,
}) {
  final parId = {for (final r in restes) r.id: r};
  final pris = <String>{};
  final reprises = <Reprise>[];
  for (final g in gymnases.entries) {
    for (final p in produits.entries) {
      final id = idReste(g.value, p.value);
      final reste = parId[id];
      if (reste == null || reste.quantite <= 0 || !pris.add(id)) continue;
      reprises.add(Reprise(gymnaseId: g.key, produitId: p.key, reste: reste));
    }
  }
  return reprises;
}

/// Des litres saisis -> des verres de stock.
int verresDepuisLitres(double litres, double verresParLitre) =>
    (litres * verresParLitre).round();

/// Des verres de stock -> des litres (pour l'affichage et la saisie).
double litresDepuisVerres(int verres, double verresParLitre) =>
    verres / verresParLitre;
