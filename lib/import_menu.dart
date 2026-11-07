import 'classeur.dart';
import 'depot_menus.dart' show ProduitModele, cleIngredient;

// Importer un menu depuis la feuille « Menu » d'un classeur Excel (mission « Préparer
// l'événement », P7). Logique pure : on construit d'abord un PLAN (les produits qui
// seraient créés et les lignes laissées de côté), montré dans un résumé AVANT toute
// écriture. `lireClasseur` a déjà validé chaque ligne (prix, type, provenance, ratios,
// recette, consommation) : ici on écarte les doublons et on borne le nombre de produits.

/// Nombre maximal de produits d'un menu importé.
const produitsMenuMax = 200;

/// Message quand le fichier ne donne aucun produit de menu.
const messageMenuIllisible =
    'Ce fichier ne contient aucun produit de menu lisible. Téléchargez le modèle, '
    'remplissez la feuille Menu, puis réessayez.';

/// Message quand le fichier a trop de produits.
const messageMenuTropGrand =
    'Ce menu a plus de $produitsMenuMax produits : il n\'est pas importé. '
    'Réduisez la feuille Menu, puis réessayez.';

/// Ce que l'import d'un menu ferait, et ce qu'il laisserait de côté.
class PlanMenu {
  const PlanMenu({
    required this.produits,
    required this.ignorees,
    required this.erreurs,
    this.tropGrand = false,
  });

  /// Les produits qui seraient créés, dans l'ordre du fichier.
  final List<ProduitClasseur> produits;

  /// Lignes laissées de côté, avec la raison (« Feuille « Menu », ligne 4 : … »).
  final List<String> ignorees;

  /// Problèmes de lecture (feuille ou colonne absente).
  final List<String> erreurs;

  /// Plus de [produitsMenuMax] produits valides : rien n'est importé.
  final bool tropGrand;

  /// Aucun menu à créer : un menu n'est jamais créé vide.
  bool get vide => produits.isEmpty || tropGrand;

  /// Les produits sous la forme attendue par le dépôt (sans icône).
  List<ProduitModele> get aCreer => [
        for (final p in produits) ProduitModele(p.nom, p.prixCentimes, null, p.fiche),
      ];

  /// « Menu à créer : 5 produits ».
  String get phraseMenu => 'Menu à créer : ${produits.length} '
      'produit${produits.length > 1 ? 's' : ''}';

  /// Le message à montrer à la place du résumé quand il n'y a rien à créer.
  String get messageVide => tropGrand ? messageMenuTropGrand : messageMenuIllisible;
}

/// Construit le plan d'import du menu d'un classeur lu. Ne lit ni n'écrit rien.
PlanMenu preparerMenu(ClasseurLu lu) {
  final ignorees = <String>[];
  final erreurs = <String>[];
  final prefixe = 'Feuille « $feuilleMenu »';
  for (final e in lu.erreurs) {
    if (!e.startsWith(prefixe)) continue; // les autres feuilles ne concernent pas le menu
    (e.contains(', ligne ') ? ignorees : erreurs).add(e);
  }
  final produits = <ProduitClasseur>[];
  final vus = <String>{};
  for (final p in lu.produits) {
    if (vus.add(cleIngredient(p.nom))) {
      produits.add(p);
    } else {
      ignorees.add('Produit « ${p.nom} » : ignoré : doublon, le premier est gardé.');
    }
  }
  return PlanMenu(
    produits: produits.length > produitsMenuMax ? const [] : produits,
    ignorees: ignorees,
    erreurs: erreurs,
    tropGrand: produits.length > produitsMenuMax,
  );
}
