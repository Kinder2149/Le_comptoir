import 'dart:typed_data';

import 'depot_menus.dart';

/// Modes de paiement : liste fixe (clé stockée -> libellé affiché).
const modesPaiement = <String, String>{
  'especes': 'Espèces',
  'carte': 'Carte',
  'cheque': 'Chèque',
  'autre': 'Autre',
};

/// « Espèces, Carte » — toujours dans l'ordre de la liste fixe.
String libelleModes(Iterable<String> modes) => modesPaiement.entries
    .where((e) => modes.contains(e.key))
    .map((e) => e.value)
    .join(', ');

/// Date stockée : « AAAA-MM-JJ ».
String dateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? dateDepuisIso(String iso) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)
    ? DateTime.tryParse(iso)
    : null;

/// « 2026-10-03 » -> « 03/10/2026 ».
String dateAffichee(String iso) {
  final d = dateDepuisIso(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class Evenement {
  const Evenement({
    required this.id,
    required this.nom,
    required this.date,
    required this.statut,
    required this.modes,
    required this.menuNom,
    this.clotureLe,
    this.clotureParPrenom,
    this.forcee = false,
    this.nbCaissesOuvertes = 0,
    this.nbGymnases = 1,
    this.nbJours = 2.0,
  });

  final String id;
  final String nom;
  final String date;
  final String statut; // 'en_preparation' | 'en_cours' | 'cloture'
  final List<String> modes;
  final String menuNom;

  /// Renseignés quand l'événement est clôturé.
  final DateTime? clotureLe;
  final String? clotureParPrenom;

  /// Clôture forcée : des caisses n'étaient pas clôturées (ventes
  /// éventuellement manquantes). [nbCaissesOuvertes] = combien.
  final bool forcee;
  final int nbCaissesOuvertes;

  /// Nombre de gymnases (les événements plus anciens n'en ont qu'un).
  final int nbGymnases;

  /// Durée de l'événement en jours (réglage des courses).
  final double nbJours;

  /// Créé mais pas encore ouvert : seule la gestion le voit, aucune caisse ne s'y ouvre.
  bool get enPreparation => statut == 'en_preparation';

  /// Ouvert : les bénévoles le voient et les caisses s'ouvrent.
  bool get enCours => statut == 'en_cours';

  /// Terminé : l'événement est figé.
  bool get cloture => statut == 'cloture';
}

/// Stock d'un produit dans un gymnase, vu de la préparation : [repris] = posé à la
/// création d'après les restes de l'événement précédent (effacé dès qu'on le corrige).
class StockDepart {
  const StockDepart(this.quantite, {this.repris = false});

  final int quantite;
  final bool repris;
}

/// Produit tel qu'il était dans le menu au moment de la création de l'événement.
class ProduitEvenement {
  const ProduitEvenement(this.id, this.nom, this.prixCentimes, this.stock,
      {this.icone, this.photo, this.fiche = FicheProduit.unite});

  final String id;
  final String nom;
  final int prixCentimes;
  final int? stock;

  /// Type, recette, ratio et consommation, figés comme le prix.
  final FicheProduit fiche;

  /// Copiées avec le produit : la caisse les affiche même sans réseau.
  final String? icone;
  final Uint8List? photo;

  /// Le même produit avec une autre consommation par personne et par jour (celle de
  /// la prévision de l'événement). Le produit lui-même, comme le menu, ne change pas.
  ProduitEvenement avecConso(double conso) => ProduitEvenement(
        id,
        nom,
        prixCentimes,
        stock,
        icone: icone,
        photo: photo,
        fiche: FicheProduit(
          type: fiche.type,
          conso: conso,
          ingredients: fiche.ingredients,
          verresParLitre: fiche.verresParLitre,
          provenance: fiche.provenance,
          partsParEntier: fiche.partsParEntier,
          famille: fiche.famille,
          rayon: fiche.rayon,
        ),
      );
}

/// « 14:05 » (heure locale).
String heureAffichee(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// « 45 min », « 1 h 20 », « 2 h » (durée écoulée, arrondie à la minute).
String dureeAffichee(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// 14 -> « 14 h–15 h », 23 -> « 23 h–0 h ».
String trancheAffichee(int heure) => '$heure h–${(heure + 1) % 24} h';

/// Rang d'affichage : en cours, puis en préparation, puis clôturés.
int _rang(Evenement e) => e.enCours ? 0 : (e.enPreparation ? 1 : 2);

/// Événements à afficher : en cours, en préparation, clôturés ; dans chaque groupe,
/// les plus récents d'abord.
List<Evenement> trierEvenements(Iterable<Evenement> evenements) {
  final liste = List.of(evenements);
  liste.sort((a, b) {
    if (_rang(a) != _rang(b)) return _rang(a).compareTo(_rang(b));
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
  });
  return liste;
}

/// Limites d'un apport nommé (mission « Préparer l'événement », P10, décision 59).
const apportPartsMax = 1000;
const apportNomMax = 40;

/// Ce qui ne va pas dans un apport (nom vide ou trop long, parts hors 1 à 1000), ou null.
/// La même règle est dans `firestore.rules`.
String? erreurApport(String nom, int? parts) {
  final n = nom.trim();
  if (n.isEmpty) return 'Donnez un nom à l\'apport (par exemple « Quiche »).';
  if (n.length > apportNomMax) {
    return 'Le nom est trop long ($apportNomMax caractères au plus).';
  }
  if (parts == null || parts < 1 || parts > apportPartsMax) {
    return 'Entrez un nombre entier de parts, de 1 à $apportPartsMax.';
  }
  return null;
}

/// Un apport nommé : ce qu'un bénévole a apporté dans un gymnase pour un produit
/// (« Quiche, 8 parts » pour « Gâteau salé »). Le stock du produit a monté du même nombre.
class Apport {
  const Apport({
    required this.id,
    required this.produitId,
    required this.produitNom,
    required this.nom,
    required this.parts,
    required this.prenom,
    required this.gymnaseId,
    required this.gymnaseNom,
  });

  final String id;
  final String produitId;
  final String produitNom;
  final String nom;
  final int parts;
  final String prenom;
  final String gymnaseId;
  final String gymnaseNom;

  /// « Quiche, 8 parts, Léa, Gymnase A » (produit entre parenthèses si utile ailleurs).
  String get ligne =>
      '$nom, ${parts == 1 ? '1 part' : '$parts parts'}, $prenom, $gymnaseNom';
}
