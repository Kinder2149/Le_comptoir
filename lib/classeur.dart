import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'courses.dart';
import 'depot_caisses.dart';
import 'depot_menus.dart';
import 'evenement.dart';
import 'export_bilan.dart';
import 'gymnase.dart';
import 'ticket.dart';

// Le classeur Excel de l'association (décision 57) : un fichier .xlsx à quatre
// feuilles (cinq à l'export du tournoi, avec le Bilan). Chaque feuille commence par une
// ligne d'aide (ligne 1) puis une ligne d'en-têtes (ligne 2) ; les données commencent
// à la ligne 3. Logique pure : aucune
// lecture ni écriture dans Firestore. Les produits et les gymnases se retrouvent par
// leur NOM (sans casse ni accents, comme le report de stock).

const feuilleMenu = 'Menu';
const feuilleStock = 'Stock de départ';
const feuilleHistorique = 'Historique';
const feuilleCourses = 'Courses';
const feuilleBilan = 'Bilan';

/// Les feuilles du modèle, dans l'ordre.
const feuillesModele = [feuilleMenu, feuilleStock, feuilleHistorique, feuilleCourses];

/// Les feuilles de l'export du tournoi : celles du modèle, puis le Bilan (qui
/// n'existe qu'à l'export et que l'import ignore).
const feuillesExport = [...feuillesModele, feuilleBilan];

const typeMimeClasseur =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const enteteProduit = 'Produit';
const enteteConsommation = 'Consommation par personne et par jour';

const entetesMenu = [
  enteteProduit,
  'Prix',
  'Type',
  'Provenance',
  'Verres par litre',
  'Parts par gâteau',
  'Recette',
  enteteConsommation,
];
const entetesStock = ['Gymnase', enteteProduit, 'Quantité'];
const entetesHistorique = [
  'Événement',
  'Gymnase',
  'Personnes',
  'Jours',
  enteteProduit,
  'Quantité vendue',
];
const entetesCourses = [
  'Série',
  'Produit ou ligne libre',
  'Quantité achetée',
  'Coût',
];

const _aides = {
  feuilleMenu:
      'Une ligne par produit du menu. Prix en euros ; Type : Composé (recette), '
          'À l\'unité, À la part ou Au litre ; Provenance : Acheté par l\'association '
          'ou Apporté par les bénévoles. Recette : ingrédients séparés par « ; », '
          'chacun écrit « quantité unité nom » (unités : unité, tranche, g, kg, cl, L), '
          'par exemple « 2 tranche Pain de mie ; 25 g Gruyère ».',
  feuilleStock:
      'Une ligne par gymnase et par produit : la quantité au départ de '
          'l\'événement. Une quantité vide veut dire « produit non suivi ». Les noms '
          'doivent être ceux de l\'événement (majuscules et accents sans importance).',
  feuilleHistorique:
      'Les ventes d\'un événement passé : une ligne par gymnase et par produit, '
          'avec le nombre de personnes et de jours de cet événement. Sert de '
          'référence pour la prévision ; ne crée aucune vente.',
  feuilleCourses:
      'Les achats d\'un événement : série, produit (ou ligne libre), quantité '
          'achetée et coût en euros. Remplie à l\'export du tournoi ; ignorée à '
          'l\'import.',
};

// Aides propres à l'export du tournoi (les autres feuilles gardent celle du modèle).
const _aidesExport = {
  feuilleStock:
      'Une ligne par gymnase et par produit suivi : la quantité de référence du '
          'stock (stock de départ plus réapprovisionnements par les courses, sinon '
          'la quantité). Une feuille réutilisable comme stock de départ d\'un '
          'prochain événement.',
  feuilleHistorique:
      'Les ventes de cet événement : une ligne par gymnase et par produit, avec le '
          'nombre de personnes et de jours de l\'événement et la quantité vendue '
          '(ventes annulées exclues). Ré-importable comme référence de prévision ; '
          'ne crée aucune vente.',
  feuilleCourses:
      'Les achats de la série validée (quantité réellement achetée), son coût en '
          'euros, les lignes libres. Les détails des séries précédentes ne sont pas '
          'conservés : seul leur cumul (nombre de séries et coût) l\'est. Ignorée à '
          'l\'import.',
  feuilleBilan:
      'Le bilan de l\'événement, tel qu\'il s\'affiche dans l\'application : '
          'totaux, modes de paiement, produits, caisses, jours, heures et ventes '
          'annulées. Montants en euros. Ignoré à l\'import.',
};

/// Le fichier n'est pas un classeur Excel lisible.
class ClasseurIllisible implements Exception {
  const ClasseurIllisible(
      [this.message = 'Ce fichier n\'est pas un classeur Excel lisible.']);

  final String message;

  @override
  String toString() => message;
}

/// Un produit lu dans la feuille Menu.
class ProduitClasseur {
  const ProduitClasseur(this.nom, this.prixCentimes, this.fiche);

  final String nom;
  final int prixCentimes;
  final FicheProduit fiche;
}

/// Une ligne de la feuille Stock de départ ([quantite] null = produit non suivi).
class StockClasseur {
  const StockClasseur(this.gymnase, this.produit, this.quantite);

  final String gymnase;
  final String produit;
  final int? quantite;
}

/// Une ligne de la feuille Historique.
class LigneHistorique {
  const LigneHistorique({
    required this.evenement,
    required this.gymnase,
    required this.personnes,
    required this.jours,
    required this.produit,
    required this.quantiteVendue,
  });

  final String evenement;
  final String gymnase;
  final int personnes;
  final double jours;
  final String produit;
  final int quantiteVendue;
}

/// Ce qu'un classeur contient. Une feuille ou une colonne absente, ou une ligne
/// invalide, est signalée dans [erreurs] (en français) ; la ligne invalide est
/// ignorée, le reste est lu.
class ClasseurLu {
  const ClasseurLu({
    this.produits = const [],
    this.stocks = const [],
    this.historique = const [],
    this.erreurs = const [],
  });

  final List<ProduitClasseur> produits;
  final List<StockClasseur> stocks;
  final List<LigneHistorique> historique;
  final List<String> erreurs;

  /// Y a-t-il de quoi importer dans la Préparation ? Des lignes de stock ou d'historique,
  /// ou au moins une ligne invalide à signaler. Sinon le fichier n'est pas un classeur
  /// Le Comptoir (feuilles absentes ou vides).
  bool get contenuUtile =>
      stocks.isNotEmpty ||
      historique.isNotEmpty ||
      erreurs.any((e) => e.contains(', ligne '));
}

// ------------------------------------------------------------------ écriture

String _nombreTexte(double n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  var s = n.toString();
  if (s.contains('e')) {
    s = n.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '');
  }
  return s.replaceAll('.', ',');
}

/// « 2 tranche Pain de mie ; 25 g Gruyère » (un « ; » dans un nom devient une virgule).
String recetteEnTexte(List<Ingredient> ingredients) => ingredients
    .map((i) =>
        '${_nombreTexte(i.quantite)} ${libellesUnites[i.unite] ?? i.unite} '
        '${i.nom.replaceAll(';', ',')}')
    .join(' ; ');

CellValue? _texte(String? t) => t == null || t.isEmpty ? null : TextCellValue(t);

CellValue? _nombre(num? n) {
  if (n == null) return null;
  return n is int || n == n.roundToDouble()
      ? IntCellValue(n.toInt())
      : DoubleCellValue(n.toDouble());
}

void _ecrireFeuille(Excel classeur, String nom, List<String> entetes,
    List<List<CellValue?>> lignes,
    {String? aide}) {
  final f = classeur[nom];
  f.appendRow([TextCellValue(aide ?? _aides[nom]!)]);
  f.appendRow([for (final e in entetes) TextCellValue(e)]);
  for (final l in lignes) {
    f.appendRow(l);
  }
}

/// Les lignes de la feuille Menu : une par produit de l'événement (consommation du
/// MENU, pas de la prévision).
List<List<CellValue?>> _lignesMenu(List<ProduitEvenement> produits) => [
      for (final p in produits)
        [
          TextCellValue(p.nom),
          _nombre(p.prixCentimes / 100),
          TextCellValue(libellesTypes[p.fiche.type] ?? p.fiche.type),
          TextCellValue(
              libellesProvenances[p.fiche.provenance] ?? p.fiche.provenance),
          _nombre(p.fiche.verresParLitre),
          _nombre(p.fiche.partsParEntier),
          _texte(recetteEnTexte(p.fiche.ingredients)),
          _nombre(p.fiche.conso),
        ],
    ];

Uint8List _octets(Excel classeur) {
  classeur.setDefaultSheet(feuilleMenu);
  final octets = classeur.encode();
  if (octets == null) {
    throw const ClasseurIllisible('Le classeur n\'a pas pu être construit.');
  }
  return Uint8List.fromList(octets);
}

/// Le modèle du classeur rempli avec les données de l'événement : le menu (consommation
/// du MENU, pas de la prévision) et le stock de départ des [gymnases] donnés.
/// Historique et Courses ne contiennent que l'aide et les en-têtes.
Uint8List construireModele({
  required List<ProduitEvenement> produits,
  required List<Gymnase> gymnases,
  required Map<String, Map<String, StockDepart>> stocks,
}) {
  final classeur = Excel.createExcel();
  final defaut = classeur.getDefaultSheet() ?? 'Sheet1';
  classeur.rename(defaut, feuilleMenu);
  _ecrireFeuille(classeur, feuilleMenu, entetesMenu, _lignesMenu(produits));
  _ecrireFeuille(classeur, feuilleStock, entetesStock, [
    for (final g in gymnases)
      for (final p in produits)
        [
          TextCellValue(g.nom),
          TextCellValue(p.nom),
          _nombre(stocks[g.id]?[p.id]?.quantite),
        ],
  ]);
  _ecrireFeuille(classeur, feuilleHistorique, entetesHistorique, const []);
  _ecrireFeuille(classeur, feuilleCourses, entetesCourses, const []);
  return _octets(classeur);
}

// ------------------------------------------------------- export du tournoi (P8)

/// Le classeur complet d'un tournoi (décision 57), à relire ou à réimporter : les
/// feuilles Menu, Stock de départ, Historique, Courses et Bilan, avec les chiffres de
/// l'écran du bilan. Il contient ce que la personne voit : [gymnases] sont ceux de sa
/// portée et [tableau] leurs seules ventes ; [limite] l'indique sur la feuille Bilan.
/// [stocksReference] : le total de référence du stock de chaque gymnase (stock de
/// départ plus réapprovisionnements), [stocksActuels] : ce qu'il en reste (pour le
/// bilan). [courses] : la liste de courses ; [coursesVisibles] faux = la personne n'y a
/// pas droit (ni séries, ni coût, ni résultat).
Uint8List construireExport({
  required Evenement evenement,
  required List<ProduitEvenement> produits,
  required List<Gymnase> gymnases,
  required Map<String, Map<String, int>> stocksReference,
  required Map<String, Map<String, int>> stocksActuels,
  required TableauDeBord tableau,
  ListeCourses? courses,
  bool coursesVisibles = true,
  bool limite = false,
}) {
  final classeur = Excel.createExcel();
  final defaut = classeur.getDefaultSheet() ?? 'Sheet1';
  classeur.rename(defaut, feuilleMenu);
  _ecrireFeuille(classeur, feuilleMenu, entetesMenu, _lignesMenu(produits));
  _ecrireFeuille(
      classeur,
      feuilleStock,
      entetesStock,
      [
        for (final g in gymnases)
          for (final p in produits)
            if (stocksReference[g.id]?[p.id] != null)
              [
                TextCellValue(g.nom),
                TextCellValue(p.nom),
                _nombre(stocksReference[g.id]![p.id]),
              ],
      ],
      aide: _aidesExport[feuilleStock]);
  _ecrireFeuille(
      classeur,
      feuilleHistorique,
      entetesHistorique,
      [
        for (final g in gymnases)
          for (final p in produits)
            [
              TextCellValue(evenement.nom),
              TextCellValue(g.nom),
              _nombre(g.personnes),
              _nombre(evenement.nbJours),
              TextCellValue(p.nom),
              _nombre(tableau.pour(g.id).vendus(p.id)),
            ],
      ],
      aide: _aidesExport[feuilleHistorique]);
  _ecrireFeuille(classeur, feuilleCourses, entetesCourses,
      _lignesCourses(evenement, produits, courses, coursesVisibles),
      aide: _aidesExport[feuilleCourses]);
  _ecrireBilan(classeur, evenement, produits, gymnases, stocksActuels, tableau,
      courses, coursesVisibles, limite);
  return _octets(classeur);
}

/// Le texte de l'unité de base d'un achat, pour le nom de la ligne : « Gruyère (g) ».
String _uniteAchat(String uniteBase) => switch (uniteBase) {
      'unite' => 'unité',
      'gateau' => 'gâteau',
      _ => uniteBase,
    };

/// La feuille Courses : cumul des séries précédentes, achats de la série validée
/// (quantité réellement achetée) et son total, lignes libres de la série en cours.
List<List<CellValue?>> _lignesCourses(Evenement evenement,
    List<ProduitEvenement> produits, ListeCourses? courses, bool visibles) {
  if (!visibles) {
    return [
      [null, TextCellValue('Courses non visibles avec vos droits')],
    ];
  }
  final liste = courses ?? const ListeCourses();
  final precedentes = liste.precedent.series;
  final serie = precedentes + 1;
  final lignes = <List<CellValue?>>[];
  if (precedentes > 0) {
    // Le détail des séries précédentes n'est pas conservé : seul leur cumul l'est.
    lignes.add([
      null,
      TextCellValue(precedentes == 1
          ? 'Série 1 (cumul)'
          : 'Séries 1 à $precedentes (cumul)'),
      _nombre(precedentes),
      _nombre(liste.precedent.coutCentimes / 100),
    ]);
  }
  final validation = liste.validation;
  if (validation != null) {
    for (final a in calculerAchats(produits, liste)) {
      lignes.add([
        _nombre(serie),
        TextCellValue('${a.nom} (${_uniteAchat(a.uniteBase)})'),
        _nombre(validation.achetes[a.cle] ?? a.aAcheter.toDouble()),
        null,
      ]);
    }
    lignes.add([
      _nombre(serie),
      TextCellValue('Total de la série $serie'),
      null,
      _nombre(validation.coutCentimes / 100),
    ]);
  } else {
    lignes.add([_nombre(serie), TextCellValue('Courses non validées'), null, null]);
  }
  for (final l in liste.libres) {
    lignes.add([_nombre(serie), TextCellValue(l.nom), _nombre(l.quantite), null]);
  }
  return lignes;
}

/// La feuille Bilan : les rubriques de l'écran du bilan en tableaux successifs
/// séparés d'une ligne vide, montants en euros dans des cellules numériques.
void _ecrireBilan(
  Excel classeur,
  Evenement evenement,
  List<ProduitEvenement> produits,
  List<Gymnase> gymnases,
  Map<String, Map<String, int>> stocksActuels,
  TableauDeBord tableau,
  ListeCourses? courses,
  bool coursesVisibles,
  bool limite,
) {
  final b = Bilan.depuis(tableau, produits, evenement.modes, stocks: stocksActuels);
  final f = classeur[feuilleBilan];
  var r = 0;
  void ligne(List<CellValue?> cellules) {
    for (var c = 0; c < cellules.length; c++) {
      final v = cellules[c];
      if (v != null) {
        f.updateCell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r), v);
      }
    }
    r++;
  }

  void vide() => r++;
  CellValue t(String s) => TextCellValue(s);
  CellValue? euros(int centimes) => _nombre(centimes / 100);
  String nomGymnase(String id) =>
      gymnases.where((g) => g.id == id).firstOrNull?.nom ?? '?';

  ligne([t(_aidesExport[feuilleBilan]!)]);
  ligne([t('Bilan'), t(evenement.nom)]);
  ligne([t('Date'), t(dateAffichee(evenement.date))]);
  ligne([
    t('Portée'),
    t(limite
        ? 'Export limité aux gymnases : ${gymnases.map((g) => g.nom).join(', ')}'
        : 'Tous les gymnases'),
  ]);
  ligne([
    t('État'),
    t(!evenement.cloture
        ? 'Provisoire (événement en cours)'
        : 'Définitif (événement clôturé)'),
  ]);
  if (evenement.cloture && evenement.forcee) {
    ligne([
      t('Clôture forcée'),
      t('${pluriel(evenement.nbCaissesOuvertes, 'caisse')} non clôturée'
          '${accord(evenement.nbCaissesOuvertes)} : des ventes peuvent manquer'),
    ]);
  }
  vide();

  ligne([t('Totaux')]);
  ligne([t('Ventes'), _nombre(b.nbVentes)]);
  ligne([t('Ventes annulées'), _nombre(b.nbAnnulees)]);
  ligne([t('Total des ventes'), euros(b.totalCentimes)]);
  if (coursesVisibles) {
    switch (CoutBilan.depuis(courses, b.totalCentimes)) {
      case CoutConnu c:
        ligne([t('Coût des courses'), euros(c.coutCentimes)]);
        ligne([t('Résultat'), euros(c.resultatCentimes)]);
      case CoursesNonValidees():
        ligne([t('Coût des courses'), t('Courses non validées')]);
    }
  }
  vide();

  ligne([t('Par mode de paiement')]);
  ligne([t('Mode'), t('Montant')]);
  for (final e in b.parMode.entries) {
    ligne([t(modesPaiement[e.key] ?? e.key), euros(e.value)]);
  }
  vide();

  ligne([t('Par produit')]);
  ligne([t('Produit'), t('Vendus'), t('Montant'), t('Stock restant')]);
  for (final l in b.produits) {
    ligne([t(l.nom), _nombre(l.quantite), euros(l.montantCentimes), _nombre(l.stock)]);
  }
  vide();

  ligne([t('Par caisse')]);
  ligne([
    t('Caisse'),
    t('Gymnase'),
    t('État'),
    t('Ventes'),
    t('Annulées'),
    t('Montant')
  ]);
  for (final c in b.caisses) {
    ligne([
      t(c.prenom),
      t(nomGymnase(c.gymnaseId)),
      t(c.cloturee ? 'Clôturée' : 'Ouverte'),
      _nombre(c.nbVentes),
      _nombre(c.nbAnnulees),
      euros(c.totalCentimes),
    ]);
  }
  vide();

  ligne([t('Par jour')]);
  ligne([t('Jour'), t('Ventes'), t('Montant')]);
  for (final j in b.jours) {
    ligne([t(dateAffichee(j.jour)), _nombre(j.nbVentes), euros(j.totalCentimes)]);
  }
  vide();

  ligne([t('Par heure')]);
  ligne([t('Heure'), t('Ventes'), t('Montant')]);
  for (final h in b.heures) {
    ligne([t(trancheAffichee(h.heure)), _nombre(h.nbVentes), euros(h.totalCentimes)]);
  }

  if (b.annulations.isNotEmpty) {
    vide();
    ligne([t('Ventes annulées')]);
    ligne([
      t('Caisse'),
      t('Vendue le'),
      t('Montant'),
      t('Mode'),
      t('Annulée par'),
      t('Annulée le')
    ]);
    for (final a in b.annulations) {
      ligne([
        t(a.caissePrenom),
        t(dateHeureAffichee(a.venteLe)),
        euros(a.totalCentimes),
        t(modesPaiement[a.mode] ?? a.mode),
        a.parPrenom == null ? null : t(a.parPrenom!),
        a.annuleeLe == null ? null : t(dateHeureAffichee(a.annuleeLe!)),
      ]);
    }
  }
}

// ------------------------------------------------------------------- lecture

String? _texteDe(Data? d) {
  final v = d?.value;
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

/// Un nombre : cellule numérique, ou texte avec virgule décimale et espaces
/// (« 1,5 », « 1 200 »). Null si la cellule est vide ; lève [FormatException] sinon.
double? _nombreDe(Data? d) {
  final v = d?.value;
  if (v == null) return null;
  if (v is IntCellValue) return v.value.toDouble();
  if (v is DoubleCellValue) return v.value;
  final t = v.toString().replaceAll(RegExp(r'[\s  ]'), '');
  if (t.isEmpty) return null;
  final n = double.tryParse(t.replaceAll(',', '.'));
  if (n == null || n.isNaN || n.isInfinite) {
    throw FormatException('« ${v.toString().trim()} » n\'est pas un nombre');
  }
  return n;
}

int? _entierDe(Data? d, String quoi) {
  final n = _nombreDe(d);
  if (n == null) return null;
  if (n != n.roundToDouble()) {
    throw FormatException('$quoi doit être un nombre entier');
  }
  return n.toInt();
}

/// Les ingrédients d'une recette écrite « quantité unité nom ; … ».
List<Ingredient> recetteDepuisTexte(String texte) {
  final res = <Ingredient>[];
  for (final morceau in texte.split(';')) {
    final m = morceau.trim();
    if (m.isEmpty) continue;
    final f = RegExp(r'^(\S+)\s+(\S+)\s+(.+)$').firstMatch(m);
    if (f == null) {
      throw FormatException(
          'recette illisible : « $m » (écrire « quantité unité nom »)');
    }
    final q = parserNombre(f.group(1)!);
    if (q == null) {
      throw FormatException('quantité illisible dans la recette : « $m »');
    }
    final uniteTexte = cleIngredient(f.group(2)!);
    String? unite;
    for (final u in unitesIngredient) {
      if (cleIngredient(u) == uniteTexte ||
          cleIngredient(libellesUnites[u]!) == uniteTexte ||
          (u == 'tranche' && uniteTexte == 'tranches')) {
        unite = u;
      }
    }
    if (unite == null) {
      throw FormatException(
          'unité inconnue dans la recette : « ${f.group(2)} » (unité, tranche, g, kg, cl, L)');
    }
    res.add(Ingredient(f.group(3)!.trim(), q, unite));
  }
  return res;
}

String? _valeurDe(Map<String, String> table, String texte) {
  final cle = cleIngredient(texte);
  for (final e in table.entries) {
    if (cleIngredient(e.key) == cle || cleIngredient(e.value) == cle) {
      return e.key;
    }
  }
  return null;
}

/// Colonnes d'une feuille par leur en-tête (ligne 2) ; une colonne absente est
/// signalée dans [erreurs].
Map<String, int>? _colonnes(
    Sheet feuille, List<String> attendus, List<String> erreurs) {
  final lignes = feuille.rows;
  final cles = <String, int>{};
  if (lignes.length >= 2) {
    for (var c = 0; c < lignes[1].length; c++) {
      final t = _texteDe(lignes[1][c]);
      if (t != null) cles.putIfAbsent(cleIngredient(t), () => c);
    }
  }
  final res = <String, int>{};
  var complet = true;
  for (final a in attendus) {
    final c = cles[cleIngredient(a)];
    if (c == null) {
      erreurs
          .add('Feuille « ${feuille.sheetName} » : colonne « $a » introuvable.');
      complet = false;
    } else {
      res[a] = c;
    }
  }
  return complet ? res : null;
}

Data? _cellule(List<Data?> ligne, int c) => c < ligne.length ? ligne[c] : null;

bool _vide(List<Data?> ligne) => ligne.every((d) => _texteDe(d) == null);

/// Lit un classeur. Lève [ClasseurIllisible] si le fichier n'est pas un classeur
/// Excel. Feuille ou colonne manquante, ligne invalide : signalés dans
/// [ClasseurLu.erreurs] (« Feuille « Menu » introuvable. »), jamais d'exception.
ClasseurLu lireClasseur(List<int> octets) {
  final Excel classeur;
  try {
    classeur = Excel.decodeBytes(octets);
  } catch (_) {
    throw const ClasseurIllisible();
  }
  final erreurs = <String>[];

  Sheet? feuille(String nom) {
    for (final e in classeur.tables.entries) {
      if (cleIngredient(e.key) == cleIngredient(nom)) return e.value;
    }
    erreurs.add('Feuille « $nom » introuvable.');
    return null;
  }

  // ---------- Menu
  final produits = <ProduitClasseur>[];
  final fMenu = feuille(feuilleMenu);
  final cMenu = fMenu == null ? null : _colonnes(fMenu, entetesMenu, erreurs);
  if (fMenu != null && cMenu != null) {
    final lignes = fMenu.rows;
    for (var i = 2; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final nom = _texteDe(_cellule(l, cMenu[enteteProduit]!));
        if (nom == null || nom.length > 40) {
          throw const FormatException(
              'le nom du produit est vide ou dépasse 40 caractères');
        }
        final prix = _nombreDe(_cellule(l, cMenu['Prix']!));
        if (prix == null) throw const FormatException('le prix est vide');
        final centimes = (prix * 100).round();
        if (prix < 0 || centimes > 100000) {
          throw const FormatException('le prix doit être entre 0 et 1 000 €');
        }
        final typeTexte = _texteDe(_cellule(l, cMenu['Type']!));
        final type =
            typeTexte == null ? 'unite' : _valeurDe(libellesTypes, typeTexte);
        if (type == null) throw FormatException('type inconnu « $typeTexte »');
        final provTexte = _texteDe(_cellule(l, cMenu['Provenance']!));
        final prov = provTexte == null
            ? 'achete'
            : _valeurDe(libellesProvenances, provTexte);
        if (prov == null) {
          throw FormatException('provenance inconnue « $provTexte »');
        }
        final verres = _nombreDe(_cellule(l, cMenu['Verres par litre']!));
        final parts = _entierDe(_cellule(l, cMenu['Parts par gâteau']!),
            'le nombre de parts par gâteau');
        final recette = _texteDe(_cellule(l, cMenu['Recette']!));
        final conso = _nombreDe(_cellule(l, cMenu[enteteConsommation]!));
        final fiche = FicheProduit(
          type: type,
          provenance: prov,
          verresParLitre: verres,
          partsParEntier: parts,
          ingredients: recette == null ? const [] : recetteDepuisTexte(recette),
          conso: conso,
        );
        final erreur = fiche.erreur();
        if (erreur != null) throw FormatException(erreur);
        produits.add(ProduitClasseur(nom, centimes, fiche));
      } on FormatException catch (e) {
        erreurs.add('Feuille « $feuilleMenu », ligne ${i + 1} : ${e.message}');
      }
    }
  }

  // ---------- Stock de départ
  final stocks = <StockClasseur>[];
  final fStock = feuille(feuilleStock);
  final cStock = fStock == null ? null : _colonnes(fStock, entetesStock, erreurs);
  if (fStock != null && cStock != null) {
    final lignes = fStock.rows;
    for (var i = 2; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final g = _texteDe(_cellule(l, cStock['Gymnase']!));
        final p = _texteDe(_cellule(l, cStock[enteteProduit]!));
        if (g == null || p == null) {
          throw const FormatException(
              'le gymnase et le produit sont obligatoires');
        }
        final q = _entierDe(_cellule(l, cStock['Quantité']!), 'la quantité');
        if (q != null && (q < 0 || q > 100000)) {
          throw const FormatException('la quantité doit être entre 0 et 100 000');
        }
        stocks.add(StockClasseur(g, p, q));
      } on FormatException catch (e) {
        erreurs.add('Feuille « $feuilleStock », ligne ${i + 1} : ${e.message}');
      }
    }
  }

  // ---------- Historique
  final historique = <LigneHistorique>[];
  final fHisto = feuille(feuilleHistorique);
  final cHisto =
      fHisto == null ? null : _colonnes(fHisto, entetesHistorique, erreurs);
  if (fHisto != null && cHisto != null) {
    final lignes = fHisto.rows;
    for (var i = 2; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final ev = _texteDe(_cellule(l, cHisto['Événement']!));
        final g = _texteDe(_cellule(l, cHisto['Gymnase']!));
        final p = _texteDe(_cellule(l, cHisto[enteteProduit]!));
        if (ev == null || g == null || p == null) {
          throw const FormatException(
              'l\'événement, le gymnase et le produit sont obligatoires');
        }
        final pers = _entierDe(
            _cellule(l, cHisto['Personnes']!), 'le nombre de personnes');
        final jours = _nombreDe(_cellule(l, cHisto['Jours']!));
        final vendu = _entierDe(
            _cellule(l, cHisto['Quantité vendue']!), 'la quantité vendue');
        if (pers == null || pers < 0 || pers > 100000) {
          throw const FormatException(
              'le nombre de personnes est manquant ou invalide');
        }
        if (jours == null || jours < 0.5 || jours > 30) {
          throw const FormatException('la durée doit être entre 0,5 et 30 jours');
        }
        if (vendu == null || vendu < 0) {
          throw const FormatException(
              'la quantité vendue est manquante ou invalide');
        }
        historique.add(LigneHistorique(
            evenement: ev,
            gymnase: g,
            personnes: pers,
            jours: jours,
            produit: p,
            quantiteVendue: vendu));
      } on FormatException catch (e) {
        erreurs.add(
            'Feuille « $feuilleHistorique », ligne ${i + 1} : ${e.message}');
      }
    }
  }

  return ClasseurLu(
    produits: produits,
    stocks: stocks,
    historique: historique,
    erreurs: erreurs,
  );
}
