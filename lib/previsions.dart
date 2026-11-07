import 'classeur.dart' show LigneHistorique;
import 'depot_caisses.dart' show TableauDeBord;
import 'depot_menus.dart' show cleIngredient;
import 'evenement.dart';

// Prévision de consommation d'un événement (mission « Préparer l'événement », P4,
// décision 56). Logique pure : aucune lecture de base ici. Un chiffre par produit, la
// consommation par personne et par jour, propre à l'événement, avec sa source. Le menu
// et le produit de l'événement ne changent jamais ; un produit sans prévision garde le
// chiffre du menu.

/// Source d'un chiffre qui vient du menu (aucune prévision enregistrée).
const sourceMenu = 'Menu';

/// Source d'un chiffre corrigé par la gestion.
const sourceMain = 'Modifié à la main';

/// Plafond d'une consommation par personne et par jour (le même que dans le menu).
const consoPrevisionMax = 1000.0;

/// Longueur maximale d'une source (la même limite que dans les règles).
const sourceLongueurMax = 80;

/// « Événement : Tournoi 2025 » (coupé à [sourceLongueurMax] caractères).
String sourceEvenement(String nom) {
  final s = 'Événement : ${nom.trim()}';
  return s.length <= sourceLongueurMax ? s : s.substring(0, sourceLongueurMax);
}

/// Message quand des événements passés ne peuvent pas servir de référence.
const messageSansPersonnes =
    'Les événements passés sans nombre de personnes réglé ne peuvent pas servir de référence.';

/// Une prévision enregistrée pour un produit : le chiffre et d'où il vient.
class Prevision {
  const Prevision(this.conso, this.source);

  final double conso;
  final String source;
}

/// Une ligne du tableau de prévision : un produit, son chiffre et sa source.
class PrevisionProduit {
  const PrevisionProduit(this.produitId, this.nom, this.conso, this.source);

  final String produitId;
  final String nom;
  final double conso;
  final String source;

  bool get modifieALaMain => source == sourceMain;
}

/// Le tableau : un produit par ligne, dans l'ordre des produits. Le chiffre est celui
/// de la prévision, sinon celui du menu (0 s'il n'en a pas), avec la source « Menu ».
List<PrevisionProduit> fusionnerPrevisions(
        List<ProduitEvenement> produits, Map<String, Prevision> previsions) =>
    [
      for (final p in produits)
        if (previsions[p.id] case final prev?)
          PrevisionProduit(p.id, p.nom, prev.conso, prev.source)
        else
          PrevisionProduit(p.id, p.nom, p.fiche.conso ?? 0, sourceMenu),
    ];

/// Les produits avec la consommation de la prévision quand il y en a une (c'est ce
/// que les courses utilisent) ; les autres gardent celle du menu.
List<ProduitEvenement> produitsAvecPrevisions(
        List<ProduitEvenement> produits, Map<String, Prevision> previsions) =>
    [
      for (final p in produits)
        if (previsions[p.id] case final prev?) p.avecConso(prev.conso) else p,
    ];

/// Un événement passé clôturé qui peut servir de référence.
class ReferencePassee {
  const ReferencePassee({
    required this.id,
    required this.nom,
    required this.date,
    required this.personnes,
    required this.jours,
  });

  final String id;
  final String nom;
  final String date;

  /// Somme des personnes réglées de tous ses gymnases.
  final int personnes;
  final double jours;
}

/// Les événements passés : ceux qui peuvent servir de référence, et combien en sont
/// écartés faute de nombre de personnes réglé.
class EvenementsPasses {
  const EvenementsPasses(this.utilisables, this.sansPersonnes);

  final List<ReferencePassee> utilisables;
  final int sansPersonnes;
}

/// Trie les événements clôturés : ceux dont la somme des personnes réglées est
/// positive (et la durée connue) sont proposés, les plus récents d'abord ; les autres
/// sont seulement comptés.
EvenementsPasses selectionnerReferences(Iterable<ReferencePassee> clotures) {
  final bons = [
    for (final r in clotures)
      if (r.personnes > 0 && r.jours > 0) r,
  ]..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
    });
  return EvenementsPasses(bons, clotures.length - bons.length);
}

/// La consommation par personne et par jour d'après un événement passé : les ventes
/// non annulées du produit (le tableau de bord les exclut déjà) divisées par les
/// personnes de l'événement passé puis par sa durée. Le produit est retrouvé par son
/// nom (sans casse ni accents) ; [produitsPasses] = identifiant -> nom des produits de
/// l'événement passé. Un produit absent de l'événement passé n'est pas dans le
/// résultat : il garde le chiffre du menu.
Map<String, double> consoDepuisEvenement({
  required List<ProduitEvenement> produits,
  required Map<String, String> produitsPasses,
  required TableauDeBord tableau,
  required int personnes,
  required double jours,
}) {
  if (personnes <= 0 || jours <= 0) return const {};
  final vendusParNom = <String, int>{};
  for (final e in produitsPasses.entries) {
    final cle = cleIngredient(e.value);
    vendusParNom[cle] = (vendusParNom[cle] ?? 0) + tableau.vendus(e.key);
  }
  return {
    for (final p in produits)
      if (vendusParNom[cleIngredient(p.nom)] case final vendus?)
        p.id: consoParPersonneEtParJour(vendus, personnes, jours),
  };
}

/// LA formule de la consommation : quantité vendue ÷ personnes ÷ jours. Utilisée par
/// la source « événement passé » (P4) et par les références importées d'un classeur
/// Excel (P6) : un seul calcul.
double consoParPersonneEtParJour(int vendus, int personnes, double jours) =>
    vendus / personnes / jours;

/// Le chiffre tel qu'on l'écrit à l'écran : « 2 », « 1,5 », « 1,67 » (2 décimales
/// au plus).
String consoAffichee(double v) {
  if (v == v.roundToDouble()) return '${v.toInt()}';
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s.replaceAll('.', ',');
}

/// Une consommation saisie : 0 à [consoPrevisionMax], virgule ou point. Sinon null.
double? lireConso(String saisie) {
  final n = double.tryParse(saisie.trim().replaceAll(',', '.'));
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n < 0 || n > consoPrevisionMax ? null : n;
}

/// Les ventes d'un événement passé ne peuvent pas être lues avec les droits de la
/// personne (elle n'est pas rattachée à tous ses gymnases). Rien n'est écrit.
class LectureRefusee implements Exception {
  const LectureRefusee();
}

// ---------------------------------------------------- références importées (P6)

/// Nombre maximal de produits dans une référence (limite des règles d'accès).
const referenceLignesMax = 200;

/// Longueurs maximales (mêmes limites que les règles d'accès).
const referenceNomMax = 60;
const referenceProduitMax = 40;

const suffixeReference = ' (Excel)';

/// Un produit d'une référence : son nom tel qu'écrit dans le classeur et sa
/// consommation par personne et par jour.
class LigneReference {
  const LigneReference(this.nom, this.conso);

  final String nom;
  final double conso;
}

/// Une référence de consommation nommée, calculée d'après la feuille Historique d'un
/// classeur et rangée au niveau de l'association (réutilisable d'une année sur l'autre).
class ReferenceImportee {
  const ReferenceImportee({
    required this.id,
    required this.nom,
    required this.lignes,
  });

  /// Clé normalisée du nom : réimporter le même nom remplace la référence.
  final String id;

  /// « Tournoi 2025 (Excel) » : c'est aussi la source affichée dans la prévision.
  final String nom;
  final List<LigneReference> lignes;
}

/// L'identifiant d'une référence : minuscules sans accents, `[a-z0-9_-]`, 1 à 100
/// caractères. Vide si le nom ne contient rien d'exploitable.
String cleReference(String nom) {
  var s = cleIngredient(nom)
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.length > 100) s = s.substring(0, 100);
  return s;
}

/// Les références calculées d'un classeur et ce qui n'a pas pu l'être.
class ReferencesCalculees {
  const ReferencesCalculees(this.references, this.erreurs);

  final List<ReferenceImportee> references;
  final List<String> erreurs;
}

/// Calcule UNE référence par événement distinct de la feuille Historique, nommée
/// « <Événement> (Excel) ». Par produit (retrouvé par sa clé sans casse ni accents, nom
/// gardé tel qu'écrit) : somme des quantités vendues ÷ personnes de l'événement ÷ jours
/// ([consoParPersonneEtParJour]). Les personnes sont la somme des gymnases distincts :
/// la valeur d'un gymnase est répétée sur ses lignes, on la prend une fois. Un événement
/// aux valeurs contradictoires, sans personnes, ou dont une consommation dépasse
/// [consoPrevisionMax] n'est pas retenu et l'erreur est dite.
ReferencesCalculees calculerReferences(List<LigneHistorique> lignes) {
  final groupes = <String, List<LigneHistorique>>{};
  final noms = <String, String>{};
  final erreurs = <String>[];
  for (final l in lignes) {
    final base = l.evenement.trim();
    final id = cleReference('$base$suffixeReference');
    if (id.isEmpty) {
      erreurs.add('Historique : le nom d\'événement « $base » est inutilisable.');
      continue;
    }
    (groupes[id] ??= []).add(l);
    noms.putIfAbsent(id, () => base);
  }
  final references = <ReferenceImportee>[];
  for (final e in groupes.entries) {
    final base = noms[e.key]!;
    final etiquette = 'Historique « $base »';
    final personnesParGymnase = <String, int>{};
    double? jours;
    String? probleme;
    for (final l in e.value) {
      final g = cleIngredient(l.gymnase);
      final deja = personnesParGymnase[g];
      if (deja != null && deja != l.personnes) {
        probleme = 'le nombre de personnes du gymnase « ${l.gymnase} » '
            'n\'est pas le même sur toutes ses lignes';
        break;
      }
      personnesParGymnase[g] = l.personnes;
      if (jours != null && jours != l.jours) {
        probleme = 'la durée n\'est pas la même sur toutes les lignes';
        break;
      }
      jours = l.jours;
    }
    final personnes = personnesParGymnase.values.fold<int>(0, (t, n) => t + n);
    if (probleme == null && (personnes <= 0)) {
      probleme = 'aucun nombre de personnes renseigné';
    }
    final vendus = <String, int>{};
    final nomsProduits = <String, String>{};
    if (probleme == null) {
      for (final l in e.value) {
        final p = cleIngredient(l.produit);
        vendus[p] = (vendus[p] ?? 0) + l.quantiteVendue;
        nomsProduits.putIfAbsent(p, () => l.produit);
      }
      if (vendus.length > referenceLignesMax) {
        probleme = 'plus de $referenceLignesMax produits';
      }
    }
    final calcul = <LigneReference>[];
    if (probleme == null) {
      for (final p in vendus.entries) {
        final conso = consoParPersonneEtParJour(p.value, personnes, jours!);
        if (conso > consoPrevisionMax) {
          probleme = 'la consommation de « ${nomsProduits[p.key]} » dépasse '
              '${consoPrevisionMax.toInt()} par personne et par jour';
          break;
        }
        var nom = nomsProduits[p.key]!;
        if (nom.length > referenceProduitMax) {
          nom = nom.substring(0, referenceProduitMax);
        }
        calcul.add(LigneReference(nom, conso));
      }
    }
    if (probleme != null) {
      erreurs.add('$etiquette : $probleme. Cet événement n\'est pas retenu comme référence.');
      continue;
    }
    var nomBase = base;
    final reste = referenceNomMax - suffixeReference.length;
    if (nomBase.length > reste) nomBase = nomBase.substring(0, reste);
    references.add(ReferenceImportee(
        id: e.key, nom: '$nomBase$suffixeReference', lignes: calcul));
  }
  references.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
  return ReferencesCalculees(references, erreurs);
}

/// La consommation de chaque produit de l'événement d'après une référence importée :
/// produit retrouvé par son nom (sans casse ni accents). Un produit absent de la
/// référence n'est pas dans le résultat : il garde le chiffre du menu (comme P4).
Map<String, double> consoDepuisReference({
  required List<ProduitEvenement> produits,
  required ReferenceImportee reference,
}) {
  final parNom = <String, double>{};
  for (final l in reference.lignes) {
    parNom.putIfAbsent(cleIngredient(l.nom), () => l.conso);
  }
  return {
    for (final p in produits)
      p.id: ?parNom[cleIngredient(p.nom)],
  };
}
