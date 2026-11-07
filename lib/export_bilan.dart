import 'courses.dart';
import 'evenement.dart';

// Coût des courses affiché au bilan et noms des fichiers de classeur (le classeur
// lui-même se construit dans classeur.dart). Logique pure.

/// Le coût des courses tel que le bilan l'affiche, pour la vue choisie.
sealed class CoutBilan {
  const CoutBilan();

  /// Vue commune, courses validées : coût et résultat (ventes moins coût). Le coût
  /// est celui de toutes les séries validées (mission C1), même si une nouvelle
  /// série est en préparation.
  factory CoutBilan.depuis(ListeCourses? courses, int ventesCentimes) {
    if (courses == null || courses.seriesValidees == 0) {
      return const CoursesNonValidees();
    }
    final cout = courses.coutTotalCentimes;
    return CoutConnu(cout, ventesCentimes - cout);
  }
}

class CoutConnu extends CoutBilan {
  const CoutConnu(this.coutCentimes, this.resultatCentimes);

  final int coutCentimes;
  final int resultatCentimes;
}

/// La liste de courses n'est pas (encore) validée : pas de coût, pas de résultat.
class CoursesNonValidees extends CoutBilan {
  const CoursesNonValidees();
}

/// Nom d'événement nettoyé pour un nom de fichier (minuscules, sans accents, tirets).
String nomPourFichier(String nom) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'œ': 'oe', 'æ': 'ae',
  };
  final propre = nom
      .toLowerCase()
      .split('')
      .map((c) => accents[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return propre.isEmpty ? 'evenement' : propre;
}

/// « modele-tournoi-2026-10-03.xlsx » (le modèle de classeur Excel de l'événement).
String nomFichierModele(Evenement evenement) =>
    'modele-${nomPourFichier(evenement.nom)}-${evenement.date}.xlsx';

/// « tournoi-tournoi-2026-10-03.xlsx » : l'export complet du tournoi (nom de
/// l'événement nettoyé).
String nomFichierExport(Evenement evenement) =>
    'tournoi-${nomPourFichier(evenement.nom)}-${evenement.date}.xlsx';

/// « 04/10/2026 14:20 ».
String dateHeureAffichee(DateTime d) =>
    '${dateAffichee(dateIso(d))} ${heureAffichee(d)}';
