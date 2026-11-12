import 'classeur.dart';
import 'depot_menus.dart' show Menu, cleIngredient;
import 'evenement.dart';
import 'gymnase.dart';
import 'import_classeur.dart';
import 'import_menu.dart';
import 'previsions.dart';

// Assistant d'import unique (mission « Prêt pour le tournoi », T2, décision 77).
// Logique pure : on enchaîne les plans existants (le menu de `preparerMenu`, les références
// et le stock de départ de `preparerImport`) en UN SEUL plan, montré dans un résumé AVANT
// toute écriture. Aucune lecture de classeur ni aucun calcul n'est refait ici.

/// Nom proposé pour un menu importé quand rien d'autre ne le suggère.
const nomMenuImporteParDefaut = 'Menu importé';

/// Ce que l'assistant fait du menu du classeur.
enum ActionMenu {
  /// Un nouveau menu est créé avec les produits du classeur.
  creer,

  /// Un menu de même nom existe : il est repris tel quel, sans aucune modification.
  reprendre,

  /// Le classeur n'a pas de menu lisible : aucun menu n'est créé ni repris.
  aucune,
}

/// Ce qu'il faut savoir d'un tournoi en préparation pour y poser le stock de départ :
/// ses gymnases, ses produits finis et ce que la personne gère.
class ContexteTournoi {
  const ContexteTournoi({
    required this.gymnases,
    required this.produits,
    required this.portee,
  });

  final List<Gymnase> gymnases;
  final List<ProduitEvenement> produits;
  final PorteeGestion portee;
}

/// Le menu existant de même nom (sans casse ni accents), ou null.
Menu? menuDeMemeNom(List<Menu> menus, String nom) {
  final cle = cleIngredient(nom.trim());
  if (cle.isEmpty) return null;
  for (final m in menus) {
    if (cleIngredient(m.nom.trim()) == cle) return m;
  }
  return null;
}

/// Tout ce que l'assistant écrirait, et ce qu'il laisse de côté.
class PlanAssistant {
  const PlanAssistant({
    required this.actionMenu,
    required this.nomMenu,
    required this.menu,
    required this.menuRepris,
    required this.produitsNonRepris,
    required this.import,
    required this.tournoi,
    required this.referencePrevision,
    required this.stocksIgnoresSansTournoi,
    required this.ignorees,
    required this.erreurs,
  });

  final ActionMenu actionMenu;
  final String nomMenu;

  /// Le plan du menu (produits à créer, lignes ignorées).
  final PlanMenu menu;

  /// Le menu existant repris sans modification (si [actionMenu] = reprendre).
  final Menu? menuRepris;

  /// Produits du classeur absents du menu repris : ils ne sont PAS ajoutés.
  final List<String> produitsNonRepris;

  /// Références et stock de départ (le stock est vide sans tournoi).
  final PlanImport import;

  /// Le tournoi en préparation qui reçoit le stock et la prévision (facultatif).
  final Evenement? tournoi;

  /// La référence importée sur laquelle la prévision du tournoi est réglée.
  final ReferenceImportee? referencePrevision;

  /// Lignes de stock lues mais non utilisées faute de tournoi choisi.
  final int stocksIgnoresSansTournoi;

  final List<String> ignorees;
  final List<String> erreurs;

  /// Rien à écrire : ni menu, ni référence, ni stock.
  bool get vide => actionMenu == ActionMenu.aucune && import.vide;

  /// Les phrases du résumé, dans l'ordre : menu, références, stock, prévision.
  List<String> get phrases {
    final res = <String>[];
    switch (actionMenu) {
      case ActionMenu.creer:
        res.add('Menu « $nomMenu » : sera créé (${menu.produits.length} '
            'produit${menu.produits.length > 1 ? 's' : ''}).');
      case ActionMenu.reprendre:
        res.add('Menu « ${menuRepris!.nom} » : existe déjà, repris sans aucune modification.');
        if (menu.produits.any((p) => p.fiche.ingredients.isNotEmpty)) {
          res.add('Les recettes du classeur ne sont pas reprises : aucune recette n\'est écrite.');
        }
      case ActionMenu.aucune:
        res.add('Menu : aucun menu lisible dans ce classeur, rien n\'est créé.');
    }
    if (import.references.isEmpty) {
      res.add('Aucune référence de consommation ne sera créée.');
    } else {
      res.addAll(import.phrasesReferences);
    }
    if (tournoi == null) {
      res.add(stocksIgnoresSansTournoi > 0
          ? 'Aucun tournoi choisi : les $stocksIgnoresSansTournoi lignes de stock '
              'de départ du classeur ne sont pas utilisées, la prévision ne change pas.'
          : 'Aucun tournoi choisi : pas de stock de départ ni de prévision.');
    } else {
      res.add('Tournoi « ${tournoi!.nom} » : ${import.phraseStocks}');
      res.add(referencePrevision == null
          ? 'Prévision : inchangée.'
          : 'Prévision : réglée sur « ${referencePrevision!.nom} ».');
    }
    return res;
  }

  /// Phrase de confirmation après « Appliquer ».
  String get phraseConfirmation {
    final parts = <String>[
      switch (actionMenu) {
        ActionMenu.creer => 'Menu « $nomMenu » créé',
        ActionMenu.reprendre => 'Menu « ${menuRepris!.nom} » repris',
        ActionMenu.aucune => 'Aucun menu',
      },
      'références : ${import.references.length}',
      if (tournoi != null) 'stocks appliqués : ${import.stocks.length}',
      if (referencePrevision != null) 'prévision réglée sur « ${referencePrevision!.nom} »',
    ];
    return '${parts.join(' ; ')}.';
  }
}

/// Construit le plan unique de l'assistant. [menuExistant] et [produitsExistants] = le
/// menu de même nom et ses produits (null si aucun). [tournoi] et [contexte] = le tournoi en
/// préparation choisi (facultatif) ; [referenceId] = la référence choisie pour la prévision
/// (par défaut la première lue). Ne lit ni n'écrit rien.
PlanAssistant preparerAssistant(
  ClasseurLu lu, {
  required String nomMenu,
  Menu? menuExistant,
  List<String> produitsExistants = const [],
  Evenement? tournoi,
  ContexteTournoi? contexte,
  String? referenceId,
}) {
  final menu = preparerMenu(lu);
  final nom = nomMenu.trim();

  final actionMenu = menu.vide
      ? ActionMenu.aucune
      : menuExistant != null
          ? ActionMenu.reprendre
          : ActionMenu.creer;

  // Un menu repris n'est jamais modifié : on dit seulement ce qui n'y est pas.
  final nonRepris = <String>[];
  if (actionMenu == ActionMenu.reprendre) {
    final presents = {for (final n in produitsExistants) cleIngredient(n)};
    for (final p in menu.produits) {
      if (!presents.contains(cleIngredient(p.nom))) nonRepris.add(p.nom);
    }
  }

  // Sans tournoi, le stock de départ n'est pas utilisé : on ne le range pas en « ignoré ».
  final avecTournoi = tournoi != null && contexte != null;
  final stocksLus = lu.stocks.where((s) => s.quantite != null).length;
  final luSansStock = avecTournoi
      ? lu
      : ClasseurLu(
          produits: lu.produits,
          historique: lu.historique,
          erreurs: lu.erreurs,
        );
  final import = preparerImport(
    luSansStock,
    tous: contexte?.gymnases ?? const [],
    produits: contexte?.produits ?? const [],
    portee: contexte?.portee ??
        const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 0),
    stockModifiable: tournoi?.enPreparation ?? true,
  );

  ReferenceImportee? reference;
  if (avecTournoi && import.references.isNotEmpty) {
    reference = import.references.firstWhere(
      (r) => r.id == referenceId,
      orElse: () => import.references.first,
    );
  }

  final ignorees = <String>[
    ...menu.ignorees,
    for (final n in nonRepris)
      'Produit « $n » : pas dans le menu « ${menuExistant!.nom} », qui n\'est pas modifié.',
    ...import.ignorees,
  ];
  final erreurs = <String>[
    ...menu.erreurs,
    if (menu.tropGrand) menu.messageVide,
    ...import.erreurs,
  ];

  return PlanAssistant(
    actionMenu: actionMenu,
    nomMenu: nom,
    menu: menu,
    menuRepris: actionMenu == ActionMenu.reprendre ? menuExistant : null,
    produitsNonRepris: nonRepris,
    import: import,
    tournoi: avecTournoi ? tournoi : null,
    referencePrevision: reference,
    stocksIgnoresSansTournoi: avecTournoi ? 0 : stocksLus,
    ignorees: ignorees,
    erreurs: erreurs,
  );
}
