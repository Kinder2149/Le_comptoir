import 'dart:typed_data';

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
  });

  final String id;
  final String nom;
  final String date;
  final String statut; // 'en_cours' | 'cloture'
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

  bool get enCours => statut == 'en_cours';
}

/// Produit tel qu'il était dans le menu au moment de la création de l'événement.
class ProduitEvenement {
  const ProduitEvenement(this.id, this.nom, this.prixCentimes, this.stock,
      {this.icone, this.photo});

  final String id;
  final String nom;
  final int prixCentimes;
  final int? stock;

  /// Copiées avec le produit : la caisse les affiche même sans réseau.
  final String? icone;
  final Uint8List? photo;
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

/// Événements à afficher : ceux en cours d'abord, puis les plus récents.
List<Evenement> trierEvenements(Iterable<Evenement> evenements) {
  final liste = List.of(evenements);
  liste.sort((a, b) {
    if (a.enCours != b.enCours) return a.enCours ? -1 : 1;
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
  });
  return liste;
}
