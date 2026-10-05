import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'ticket.dart';

class Menu {
  const Menu(this.id, this.nom);

  final String id;
  final String nom;
}

/// Produit d'un menu. [stock] null = pas de suivi du stock.
class ProduitMenu {
  const ProduitMenu(this.id, this.nom, this.prixCentimes, this.stock,
      {this.icone, this.photo});

  final String id;
  final String nom;
  final int prixCentimes;
  final int? stock;

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
  }) =>
      _produits(menuId).doc().set({
        'nom': nom.trim(),
        'prixCentimes': prixCentimes,
        'stock': ?stock,
        'icone': ?icone,
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
  }) =>
      _produits(menuId).doc(produitId).update({
        'nom': nom.trim(),
        'prixCentimes': prixCentimes,
        'stock': stock ?? FieldValue.delete(),
        'icone': icone ?? FieldValue.delete(),
        'photo': photo == null ? FieldValue.delete() : Blob(photo),
      });

  Future<void> supprimerProduit(String menuId, String produitId) =>
      _produits(menuId).doc(produitId).delete();
}
