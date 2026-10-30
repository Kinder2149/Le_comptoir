import 'courses.dart';
import 'depot_caisses.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'ticket.dart';

// Export du bilan en CSV (chantier Stock et courses, étape 7). Logique pure :
// le texte produit reprend exactement les chiffres affichés à l'écran.

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

/// Un champ de CSV : entre guillemets s'il contient « ; », un guillemet ou un
/// saut de ligne (les guillemets s'y doublent).
String champCsv(String valeur) {
  final besoin = valeur.contains(';') ||
      valeur.contains('"') ||
      valeur.contains('\n') ||
      valeur.contains('\r');
  return besoin ? '"${valeur.replaceAll('"', '""')}"' : valeur;
}

/// 600 -> « 6,00 », -39050 -> « -390,50 » (sans symbole, pour un tableur).
String montantCsv(int centimes) {
  final signe = centimes < 0 ? '-' : '';
  final a = centimes.abs();
  return '$signe${a ~/ 100},${(a % 100).toString().padLeft(2, '0')}';
}

/// « bilan-tournoi-2026-10-03.csv » (nom de l'événement nettoyé).
String nomFichierBilan(Evenement evenement) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'œ': 'oe', 'æ': 'ae',
  };
  final nom = evenement.nom
      .toLowerCase()
      .split('')
      .map((c) => accents[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'bilan-${nom.isEmpty ? 'evenement' : nom}-${evenement.date}.csv';
}

/// Le bilan de la vue choisie, en CSV pour Excel (séparateur « ; », virgule
/// décimale, fins de ligne Windows, marque UTF-8 en tête). [vue] : « Commun » ou le
/// nom du gymnase. [cout] : null hors vue commune (le coût des courses concerne
/// tout l'événement).
String bilanEnCsv({
  required Evenement evenement,
  required Bilan bilan,
  required String vue,
  required List<Gymnase> gymnases,
  CoutBilan? cout,
}) {
  final lignes = <List<String>>[];
  void ligne(List<String> champs) => lignes.add(champs);
  void vide() => lignes.add(const []);
  String nomGymnase(String id) =>
      gymnases.where((g) => g.id == id).firstOrNull?.nom ?? '?';

  ligne(['Bilan', evenement.nom]);
  ligne(['Date', dateAffichee(evenement.date)]);
  ligne(['Vue', vue]);
  ligne(['État', evenement.enCours ? 'Provisoire (événement en cours)' : 'Définitif (événement clôturé)']);
  if (!evenement.enCours && evenement.forcee) {
    ligne(['Clôture forcée', '${pluriel(evenement.nbCaissesOuvertes, 'caisse')} non clôturée${accord(evenement.nbCaissesOuvertes)} : des ventes peuvent manquer']);
  }
  vide();

  ligne(['Totaux']);
  ligne(['Ventes', '${bilan.nbVentes}']);
  ligne(['Ventes annulées', '${bilan.nbAnnulees}']);
  ligne(['Total des ventes', montantCsv(bilan.totalCentimes)]);
  switch (cout) {
    case CoutConnu c:
      ligne(['Coût des courses', montantCsv(c.coutCentimes)]);
      ligne(['Résultat', montantCsv(c.resultatCentimes)]);
    case CoursesNonValidees():
      ligne(['Coût des courses', 'Courses non validées']);
    case null:
      break;
  }
  vide();

  ligne(['Par mode de paiement']);
  ligne(['Mode', 'Montant']);
  for (final e in bilan.parMode.entries) {
    ligne([modesPaiement[e.key] ?? e.key, montantCsv(e.value)]);
  }
  vide();

  ligne(['Par produit']);
  ligne(['Produit', 'Vendus', 'Montant', 'Stock restant']);
  for (final l in bilan.produits) {
    ligne([l.nom, '${l.quantite}', montantCsv(l.montantCentimes), l.stock == null ? '' : '${l.stock}']);
  }
  vide();

  ligne(['Par caisse']);
  ligne(['Caisse', 'Gymnase', 'État', 'Ventes', 'Annulées', 'Montant']);
  for (final c in bilan.caisses) {
    ligne([
      c.prenom,
      nomGymnase(c.gymnaseId),
      c.cloturee ? 'Clôturée' : 'Ouverte',
      '${c.nbVentes}',
      '${c.nbAnnulees}',
      montantCsv(c.totalCentimes),
    ]);
  }
  vide();

  ligne(['Par jour']);
  ligne(['Jour', 'Ventes', 'Montant']);
  for (final j in bilan.jours) {
    ligne([dateAffichee(j.jour), '${j.nbVentes}', montantCsv(j.totalCentimes)]);
  }
  vide();

  ligne(['Par heure']);
  ligne(['Heure', 'Ventes', 'Montant']);
  for (final h in bilan.heures) {
    ligne([trancheAffichee(h.heure), '${h.nbVentes}', montantCsv(h.totalCentimes)]);
  }

  if (bilan.annulations.isNotEmpty) {
    vide();
    ligne(['Ventes annulées']);
    ligne(['Caisse', 'Vendue le', 'Montant', 'Mode', 'Annulée par', 'Annulée le']);
    for (final a in bilan.annulations) {
      ligne([
        a.caissePrenom,
        _dateHeure(a.venteLe),
        montantCsv(a.totalCentimes),
        modesPaiement[a.mode] ?? a.mode,
        a.parPrenom ?? '',
        a.annuleeLe == null ? '' : _dateHeure(a.annuleeLe!),
      ]);
    }
  }

  // La marque UTF-8 (BOM) permet à Excel de lire les accents.
  return '﻿${lignes.map((l) => l.map(champCsv).join(';')).join('\r\n')}\r\n';
}

String _dateHeure(DateTime d) =>
    '${dateAffichee(dateIso(d))} ${heureAffichee(d)}';
