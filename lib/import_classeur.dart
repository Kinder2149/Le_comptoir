import 'classeur.dart';
import 'depot_menus.dart' show cleIngredient;
import 'evenement.dart';
import 'gymnase.dart';
import 'previsions.dart';

// Importer un classeur Excel dans la Préparation (mission « Préparer l'événement », P6,
// décisions 56 et 57). Logique pure : on construit d'abord un PLAN (ce qui serait écrit
// et ce qui est ignoré), montré dans un résumé AVANT toute écriture ; « Appliquer »
// l'exécute. Le stock de départ vient de la feuille « Stock de départ », la consommation
// de la feuille « Historique » (une référence par événement). La feuille Menu est
// ignorée ici (elle sert à l'écran Menus), Courses et Bilan aussi.

/// Message quand le fichier n'est pas un classeur Le Comptoir lisible.
const messageClasseurIllisible =
    'Ce fichier n\'est pas un classeur Le Comptoir lisible. Téléchargez le modèle, '
    'remplissez-le, puis réessayez.';

/// Raison donnée aux lignes de stock quand l'événement est déjà ouvert.
const messageStockFerme =
    'Le stock de départ ne se modifie plus : l\'événement est ouvert.';

/// Un stock de départ à écrire (gymnase et produit déjà retrouvés dans l'événement).
class StockAEcrire {
  const StockAEcrire({
    required this.gymnaseId,
    required this.produitId,
    required this.gymnaseNom,
    required this.produitNom,
    required this.quantite,
  });

  final String gymnaseId;
  final String produitId;
  final String gymnaseNom;
  final String produitNom;
  final int quantite;
}

/// Ce que l'import ferait, et ce qu'il laisserait de côté.
class PlanImport {
  const PlanImport({
    required this.stocks,
    required this.references,
    required this.ignorees,
    required this.erreurs,
    required this.menuIgnore,
  });

  final List<StockAEcrire> stocks;
  final List<ReferenceImportee> references;

  /// Lignes laissées de côté, avec la raison (« Feuille « Stock de départ », ligne 4 : … »).
  final List<String> ignorees;

  /// Erreurs de lecture et événements d'historique non retenus.
  final List<String> erreurs;

  /// La feuille Menu contenait des produits : elle n'est pas importée ici.
  final bool menuIgnore;

  bool get vide => stocks.isEmpty && references.isEmpty;

  /// « 3 stocks seront appliqués » / « Aucun stock ne sera appliqué ».
  String get phraseStocks => stocks.isEmpty
      ? 'Aucun stock ne sera appliqué.'
      : stocks.length == 1
          ? '1 stock sera appliqué.'
          : '${stocks.length} stocks seront appliqués.';

  /// « Référence créée : Tournoi 2025 (Excel) — 4 produits ».
  List<String> get phrasesReferences => [
        for (final r in references)
          'Référence créée : ${r.nom} — ${r.lignes.length} '
              'produit${r.lignes.length > 1 ? 's' : ''}',
      ];

  /// Phrase de confirmation après « Appliquer ».
  String get phraseConfirmation {
    final refs = references.isEmpty
        ? 'aucune'
        : references.map((r) => r.nom).join(', ');
    return 'Stocks appliqués : ${stocks.length}. Références enregistrées : $refs.';
  }
}

/// Construit le plan d'import d'un classeur lu pour un événement. [tous] = tous les
/// gymnases de l'événement, [produits] = ses produits finis, [portee] = ce que le
/// membre gère (un gestionnaire partiel n'écrit que ses gymnases). Ne lit ni n'écrit
/// rien.
PlanImport preparerImport(
  ClasseurLu lu, {
  required List<Gymnase> tous,
  required List<ProduitEvenement> produits,
  required PorteeGestion portee,
  bool stockModifiable = true,
}) {
  final gymnasParCle = <String, Gymnase>{};
  for (final g in tous) {
    gymnasParCle.putIfAbsent(cleIngredient(g.nom), () => g);
  }
  final produitsParCle = <String, ProduitEvenement>{};
  for (final p in produits) {
    produitsParCle.putIfAbsent(cleIngredient(p.nom), () => p);
  }

  final stocks = <StockAEcrire>[];
  final ignorees = <String>[];
  final vues = <String>{};
  for (var i = 0; i < lu.stocks.length; i++) {
    final s = lu.stocks[i];
    // Quantité vide = produit non suivi : rien à écrire, ce n'est pas une erreur.
    if (s.quantite == null) continue;
    final etiquette = '« ${s.gymnase} » / « ${s.produit} »';
    // Événement ouvert : le stock de départ ne se modifie plus (lecture seule, P2).
    if (!stockModifiable) {
      ignorees.add('Stock $etiquette : $messageStockFerme');
      continue;
    }
    final g = gymnasParCle[cleIngredient(s.gymnase)];
    final p = produitsParCle[cleIngredient(s.produit)];
    if (g == null) {
      ignorees.add('Stock $etiquette : gymnase inconnu dans cet événement.');
    } else if (p == null) {
      ignorees.add('Stock $etiquette : produit inconnu dans cet événement.');
    } else if (!portee.gere(g.id)) {
      ignorees.add('Stock $etiquette : ce gymnase ne fait pas partie de vos gymnases.');
    } else if (!vues.add('${g.id}/${p.id}')) {
      ignorees.add('Stock $etiquette : ligne en double, la première est retenue.');
    } else {
      stocks.add(StockAEcrire(
        gymnaseId: g.id,
        produitId: p.id,
        gymnaseNom: g.nom,
        produitNom: p.nom,
        quantite: s.quantite!,
      ));
    }
  }

  final calcul = calculerReferences(lu.historique);
  return PlanImport(
    stocks: stocks,
    references: calcul.references,
    ignorees: ignorees,
    // La feuille Menu n'est pas lue par cet import : ses problèmes ne concernent pas ici.
    erreurs: [
      for (final e in lu.erreurs)
        if (!e.startsWith('Feuille « $feuilleMenu »')) e,
      ...calcul.erreurs,
    ],
    menuIgnore: lu.produits.isNotEmpty,
  );
}
