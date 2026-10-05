import 'dart:typed_data';

/// Icônes modèles proposées pour un produit (clés stockées avec le produit).
/// L'illustration de chaque clé est dans ecran_caisse.dart ; la même liste est
/// imposée par les règles d'accès (un test vérifie qu'elles concordent).
const cleIcones = <String>[
  'croque', 'salade', 'fruit', 'the', 'cafe', 'barre', 'soda',
  'gateau_sucre', 'gateau_sale', 'crepe', 'biere', 'eau', 'frites', 'glace',
];

/// Photo d'un produit : vignette en octets (30 Ko max, comme dans les règles).
const tailleMaxPhoto = 30000;

/// Produit vendu à la caisse. Prix en centimes pour éviter les erreurs
/// d'arrondi. [stock] null = pas de suivi. Deux produits de même [id] sont
/// le même produit (le stock affiché change, pas le produit).
class Produit {
  const Produit(this.id, this.nom, this.prixCentimes,
      [this.stock, this.icone, this.photo]);

  final String id;
  final String nom;
  final int prixCentimes;
  final int? stock;

  /// Icône modèle (clé de [cleIcones]) et photo (vignette), facultatives.
  final String? icone;
  final Uint8List? photo;

  @override
  bool operator ==(Object other) => other is Produit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Menu générique de l'étape 1 (remplacé plus tard par le menu réel).
const menuGenerique = <Produit>[
  Produit('croque', 'Croque-monsieur', 300),
  Produit('salade', 'Salade', 400),
  Produit('fruit', 'Fruit', 100),
  Produit('cafe', 'Café', 100),
  Produit('soda', 'Soda', 150),
  Produit('barre', 'Barre chocolatée', 100),
  Produit('gateau_sucre', 'Part de gâteau sucrée', 200),
  Produit('gateau_sale', 'Part de gâteau salée', 250),
  Produit('crepe', 'Crêpe', 250),
];

/// Ticket en cours : quantité par produit et total.
class Ticket {
  final Map<Produit, int> _quantites = {};

  Map<Produit, int> get lignes => Map.unmodifiable(_quantites);

  bool get estVide => _quantites.isEmpty;

  int get totalCentimes => _quantites.entries
      .fold(0, (somme, e) => somme + e.key.prixCentimes * e.value);

  void ajouter(Produit p) => _quantites[p] = (_quantites[p] ?? 0) + 1;

  void retirer(Produit p) {
    final q = _quantites[p] ?? 0;
    if (q <= 1) {
      _quantites.remove(p);
    } else {
      _quantites[p] = q - 1;
    }
  }

  void vider() => _quantites.clear();
}

/// 350 -> « 3,50 € ».
String formaterEuros(int centimes) {
  final euros = centimes ~/ 100;
  final reste = (centimes % 100).toString().padLeft(2, '0');
  return '$euros,$reste €';
}

/// Le « s » du pluriel quand [n] vaut plus de 1 (en français, 0 et 1 restent au singulier).
String accord(int n) => n > 1 ? 's' : '';

/// 1 -> « 1 vente », 4 -> « 4 ventes ».
String pluriel(int n, String mot) => '$n $mot${accord(n)}';

/// Saisie d'un prix (« 2,5 », « 2.50 », « 3 ») -> centimes ; null si invalide.
int? parserPrix(String saisie) {
  final m = RegExp(r'^(\d{1,3})(?:[.,](\d{1,2}))?$').firstMatch(saisie.trim());
  if (m == null) return null;
  final euros = int.parse(m.group(1)!);
  final decimales = (m.group(2) ?? '').padRight(2, '0');
  return euros * 100 + int.parse(decimales.isEmpty ? '0' : decimales);
}

/// 250 -> « 2,50 » (pour pré-remplir un champ de saisie).
String prixPourSaisie(int centimes) =>
    '${centimes ~/ 100},${(centimes % 100).toString().padLeft(2, '0')}';

/// Monnaie à rendre pour un ticket de [totalCentimes] payé avec [recuCentimes] ;
/// null si la somme reçue ne couvre pas le total.
int? monnaieARendre(int totalCentimes, int recuCentimes) =>
    recuCentimes >= totalCentimes ? recuCentimes - totalCentimes : null;
