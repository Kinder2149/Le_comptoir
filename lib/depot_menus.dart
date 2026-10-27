import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'ticket.dart';

class Menu {
  const Menu(this.id, this.nom);

  final String id;
  final String nom;
}

/// Types de produit (décision 36). Absent = « unite » : les produits existants ne changent pas.
const typesProduit = ['compose', 'unite', 'part', 'litre'];

const libellesTypes = {
  'compose': 'Composé (recette)',
  'unite': 'À l\'unité',
  'part': 'À la part',
  'litre': 'Au litre',
};

/// Unités d'un ingrédient (liste fixe, la même dans les règles d'accès).
const unitesIngredient = ['unite', 'tranche', 'g', 'kg', 'cl', 'L'];

const libellesUnites = {
  'unite': 'unité',
  'tranche': 'tranche',
  'g': 'g',
  'kg': 'kg',
  'cl': 'cl',
  'L': 'L',
};

const maxIngredients = 20;

/// Un ingrédient d'une recette : quantité pour UNE unité du produit (fraction permise).
class Ingredient {
  const Ingredient(this.nom, this.quantite, this.unite);

  final String nom;
  final double quantite;
  final String unite;

  /// Deux ingrédients sont « le même » si leur nom ne diffère ni par la casse,
  /// ni par les accents, ni par les espaces autour (reconnaissance des courses).
  String get cle => cleIngredient(nom);

  Map<String, dynamic> versMap() =>
      {'nom': nom, 'quantite': quantite, 'unite': unite};

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.nom == nom &&
      other.quantite == quantite &&
      other.unite == unite;

  @override
  int get hashCode => Object.hash(nom, quantite, unite);
}

/// « Pain de Mié » et « pain de mie » donnent la même clé.
String cleIngredient(String nom) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'œ': 'oe', 'æ': 'ae',
  };
  final bas = nom.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return bas.split('').map((c) => accents[c] ?? c).join();
}

/// Ce qui décrit un produit au-delà de son nom et de son prix : type, recette,
/// ratio litres -> verres et consommation. Copié dans l'événement (décision 13).
class FicheProduit {
  const FicheProduit({
    this.type = 'unite',
    this.conso,
    this.ingredients = const [],
    this.verresParLitre,
  });

  static const unite = FicheProduit();

  final String type;

  /// Consommation par personne et par jour (facultative).
  final double? conso;
  final List<Ingredient> ingredients;
  final double? verresParLitre;

  /// Lit les champs d'un document ; un document sans type est « unité ».
  factory FicheProduit.depuis(Map<String, dynamic> d) {
    final type = d['type'] as String?;
    return FicheProduit(
      type: type != null && typesProduit.contains(type) ? type : 'unite',
      conso: (d['conso'] as num?)?.toDouble(),
      ingredients: [
        for (final i in (d['ingredients'] as List?) ?? const [])
          Ingredient(i['nom'] as String, (i['quantite'] as num).toDouble(),
              i['unite'] as String),
      ],
      verresParLitre: (d['verresParLitre'] as num?)?.toDouble(),
    );
  }

  /// Champs à écrire. Pour une mise à jour ([supprimerLeReste]), les champs
  /// qui ne concernent plus le type sont effacés.
  Map<String, dynamic> versMap({bool supprimerLeReste = false}) => {
        'type': type,
        if (conso != null)
          'conso': conso
        else if (supprimerLeReste)
          'conso': FieldValue.delete(),
        if (type == 'compose')
          'ingredients': [for (final i in ingredients) i.versMap()]
        else if (supprimerLeReste)
          'ingredients': FieldValue.delete(),
        if (type == 'litre')
          'verresParLitre': verresParLitre
        else if (supprimerLeReste)
          'verresParLitre': FieldValue.delete(),
      };

  /// Message d'erreur en français si la fiche est incohérente, sinon null.
  /// Les règles d'accès refusent les mêmes cas.
  String? erreur() {
    if (conso != null && (conso! < 0 || conso! > 1000)) {
      return 'Consommation invalide (0 à 1000 par personne et par jour).';
    }
    if (type == 'compose') {
      if (ingredients.isEmpty) {
        return 'Un produit composé a besoin d\'au moins un ingrédient.';
      }
      if (ingredients.length > maxIngredients) {
        return '$maxIngredients ingrédients au plus.';
      }
      for (final i in ingredients) {
        if (i.nom.trim().isEmpty || i.nom.trim().length > 40) {
          return 'Chaque ingrédient a un nom (40 caractères max).';
        }
        if (!(i.quantite > 0) || i.quantite > 100000) {
          return 'La quantité de « ${i.nom.trim()} » doit être supérieure à zéro.';
        }
      }
    }
    if (type == 'litre') {
      final v = verresParLitre;
      if (v == null || !(v > 0) || v > 100) {
        return 'Le nombre de verres par litre doit être supérieur à zéro.';
      }
    }
    return null;
  }
}

/// Lit un nombre saisi (« 0,25 », « 1/4 », « 25 »). Null si illisible.
double? parserNombre(String texte) {
  final t = texte.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final f = RegExp(r'^(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)$').firstMatch(t);
  if (f != null) {
    final d = double.parse(f.group(2)!);
    return d == 0 ? null : double.parse(f.group(1)!) / d;
  }
  return double.tryParse(t);
}

/// Affiche un nombre sans zéros inutiles (« 2 », « 0,25 »).
String nombrePourSaisie(double n) {
  final s = n == n.roundToDouble()
      ? n.toInt().toString()
      : n.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  return s.replaceAll('.', ',');
}

/// Texte court de la fiche (sauts de ligne compris), vide pour un produit à
/// l'unité sans consommation : « Composé : 2 tranche pain de mie, … ».
String resumeFiche(FicheProduit f) {
  final lignes = <String>[
    if (f.type == 'compose')
      'Recette : ${f.ingredients.map((i) => '${nombrePourSaisie(i.quantite)} ${libellesUnites[i.unite]} ${i.nom}').join(', ')}'
    else if (f.type == 'litre')
      'Au litre : ${nombrePourSaisie(f.verresParLitre ?? 0)} verres par litre'
    else if (f.type == 'part')
      'À la part',
    if (f.conso != null)
      'Consommation : ${nombrePourSaisie(f.conso!)} par personne et par jour',
  ];
  return lignes.isEmpty ? '' : '\n${lignes.join('\n')}';
}

/// Produit d'un menu. [stock] null = pas de suivi du stock.
class ProduitMenu {
  const ProduitMenu(this.id, this.nom, this.prixCentimes, this.stock,
      {this.icone, this.photo, this.fiche = FicheProduit.unite});

  final String id;
  final String nom;
  final int prixCentimes;
  final int? stock;
  final FicheProduit fiche;

  /// Icône modèle (clé de [cleIcones]) et photo (vignette), facultatives.
  final String? icone;
  final Uint8List? photo;
}

/// Un produit du menu type (nom, prix, icône), lu dans assets/menu_type.json.
class ProduitModele {
  const ProduitModele(this.nom, this.prixCentimes, this.icone);

  final String nom;
  final int prixCentimes;
  final String? icone;
}

/// Lit le menu type. Refuse (FormatException) tout ce que les règles refuseraient :
/// nom vide ou trop long, prix hors limites, icône inconnue.
List<ProduitModele> lireMenuType(String json) {
  final liste = jsonDecode(json);
  if (liste is! List || liste.isEmpty) {
    throw const FormatException('Le menu type est vide.');
  }
  return [
    for (final e in liste)
      if (e is Map &&
          e['nom'] is String &&
          (e['nom'] as String).trim().isNotEmpty &&
          (e['nom'] as String).trim().length <= 40 &&
          e['prixCentimes'] is int &&
          (e['prixCentimes'] as int) >= 0 &&
          (e['prixCentimes'] as int) <= 100000 &&
          (e['icone'] == null || cleIcones.contains(e['icone'])))
        ProduitModele((e['nom'] as String).trim(), e['prixCentimes'] as int,
            e['icone'] as String?)
      else
        throw FormatException('Produit invalide dans le menu type : $e'),
  ];
}

/// Menus et produits d'une association (couche Données).
class DepotMenus {
  DepotMenus(this._db, this._assoId);

  final FirebaseFirestore _db;
  final String _assoId;

  CollectionReference<Map<String, dynamic>> get _menus =>
      _db.collection('associations').doc(_assoId).collection('menus');

  CollectionReference<Map<String, dynamic>> _produits(String menuId) =>
      _menus.doc(menuId).collection('produits');

  int _parNom(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  Stream<List<Menu>> suivreMenus() => _menus.snapshots().map((s) {
        final liste = [
          for (final d in s.docs) Menu(d.id, d.data()['nom'] as String),
        ];
        liste.sort((a, b) => _parNom(a.nom, b.nom));
        return liste;
      });

  Stream<Menu?> suivreMenu(String menuId) =>
      _menus.doc(menuId).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : Menu(d.id, data['nom'] as String);
      });

  Stream<List<ProduitMenu>> suivreProduits(String menuId) =>
      _produits(menuId).snapshots().map((s) {
        final liste = [
          for (final d in s.docs)
            ProduitMenu(
              d.id,
              d.data()['nom'] as String,
              d.data()['prixCentimes'] as int,
              d.data()['stock'] as int?,
              icone: d.data()['icone'] as String?,
              photo: (d.data()['photo'] as Blob?)?.bytes,
              fiche: FicheProduit.depuis(d.data()),
            ),
        ];
        liste.sort((a, b) => _parNom(a.nom, b.nom));
        return liste;
      });

  Future<String> creerMenu(String nom) async {
    final ref = _menus.doc();
    await ref.set({'nom': nom.trim(), 'creeLe': FieldValue.serverTimestamp()});
    return ref.id;
  }

  Future<void> renommerMenu(String menuId, String nom) =>
      _menus.doc(menuId).update({'nom': nom.trim()});

  /// Supprime le menu et tous ses produits.
  Future<void> supprimerMenu(String menuId) async {
    final lot = _db.batch();
    for (final p in (await _produits(menuId).get()).docs) {
      lot.delete(p.reference);
    }
    lot.delete(_menus.doc(menuId));
    await lot.commit();
  }

  /// Crée un menu déjà rempli avec les produits d'un modèle (menu type).
  Future<String> creerMenuDepuisModele(
      String nom, List<ProduitModele> modele) async {
    final ref = _menus.doc();
    final lot = _db.batch();
    lot.set(ref, {'nom': nom.trim(), 'creeLe': FieldValue.serverTimestamp()});
    for (final p in modele) {
      lot.set(ref.collection('produits').doc(), {
        'nom': p.nom,
        'prixCentimes': p.prixCentimes,
        'icone': ?p.icone,
        'creeLe': FieldValue.serverTimestamp(),
      });
    }
    await lot.commit();
    return ref.id;
  }

  Future<void> ajouterProduit(
    String menuId, {
    required String nom,
    required int prixCentimes,
    int? stock,
    String? icone,
    Uint8List? photo,
    FicheProduit fiche = FicheProduit.unite,
  }) =>
      _produits(menuId).doc().set({
        'nom': nom.trim(),
        'prixCentimes': prixCentimes,
        'stock': ?stock,
        'icone': ?icone,
        ...fiche.versMap(),
        if (photo != null) 'photo': Blob(photo),
        'creeLe': FieldValue.serverTimestamp(),
      });

  Future<void> modifierProduit(
    String menuId,
    String produitId, {
    required String nom,
    required int prixCentimes,
    int? stock,
    String? icone,
    Uint8List? photo,
    FicheProduit fiche = FicheProduit.unite,
  }) =>
      _produits(menuId).doc(produitId).update({
        'nom': nom.trim(),
        'prixCentimes': prixCentimes,
        ...fiche.versMap(supprimerLeReste: true),
        'stock': stock ?? FieldValue.delete(),
        'icone': icone ?? FieldValue.delete(),
        'photo': photo == null ? FieldValue.delete() : Blob(photo),
      });

  Future<void> supprimerProduit(String menuId, String produitId) =>
      _produits(menuId).doc(produitId).delete();
}
