import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Archive, ArchiveFile, ZipDecoder, ZipEncoder;

import 'package:excel/excel.dart';

import 'courses.dart';
import 'depot_caisses.dart';
import 'depot_menus.dart';
import 'evenement.dart';
import 'export_bilan.dart';
import 'gymnase.dart';
import 'ticket.dart';

// Le classeur Excel de l'association (décisions 57 et 66) : un fichier .xlsx à six
// feuilles (Accueil, Menu, Recettes, Stock de départ, Historique, Courses), sept à
// l'export du tournoi (avec le Bilan). Chaque feuille de données a un bandeau (lignes
// 1 à 4), une ligne d'aide (ligne 5), puis une ligne d'en-têtes (ligne 6) ; les données
// commencent à la ligne 7. La lecture repère la ligne d'en-têtes par son contenu, donc
// les classeurs à l'ancien format (aide en ligne 1, en-têtes en ligne 2) restent lisibles.
// Logique pure : aucune lecture ni écriture dans Firestore. Les produits et les gymnases
// se retrouvent par leur NOM (sans casse ni accents, comme le report de stock).

const feuilleAccueil = 'Accueil';
const feuilleMenu = 'Menu';
const feuilleRecettes = 'Recettes';
const feuilleStock = 'Stock de départ';
const feuilleHistorique = 'Historique';
const feuilleCourses = 'Courses';
const feuilleBilan = 'Bilan';

/// Les feuilles du modèle, dans l'ordre (Accueil d'abord).
const feuillesModele = [
  feuilleAccueil,
  feuilleMenu,
  feuilleRecettes,
  feuilleStock,
  feuilleHistorique,
  feuilleCourses,
];

/// Les feuilles de l'export du tournoi : celles du modèle, puis le Bilan (qui
/// n'existe qu'à l'export et que l'import ignore).
const feuillesExport = [...feuillesModele, feuilleBilan];

const typeMimeClasseur =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const enteteProduit = 'Produit';
const enteteConsommation = 'Consommation par personne et par jour';
const enteteFamille = 'Famille';
const enteteRayon = 'Rayon';
const enteteRecette = 'Recette';
const enteteIngredient = 'Ingrédient';
const enteteQuantiteProduit = 'Quantité par produit';
const enteteUnite = 'Unité';

/// Feuille Menu : colonnes lues (Famille, Rayon et l'ancienne Recette sont facultatives).
const entetesMenu = [
  enteteFamille,
  enteteProduit,
  'Prix',
  'Type',
  'Provenance',
  'Verres par litre',
  'Parts par gâteau',
  enteteRayon,
  enteteConsommation,
];
const _entetesMenuRequis = [
  enteteProduit,
  'Prix',
  'Type',
  'Provenance',
  'Verres par litre',
  'Parts par gâteau',
  enteteConsommation,
];
const _entetesMenuFacultatifs = [enteteFamille, enteteRayon, enteteRecette];

const entetesRecettes = [
  enteteProduit,
  enteteIngredient,
  enteteQuantiteProduit,
  enteteUnite,
  enteteRayon,
];
const _entetesRecettesRequis = [
  enteteProduit,
  enteteIngredient,
  enteteQuantiteProduit,
  enteteUnite,
];

const entetesStock = ['Gymnase', enteteProduit, 'Quantité'];

const entetesHistorique = [
  'Événement',
  'Gymnase',
  'Personnes',
  'Jours',
  enteteProduit,
  'Quantité vendue',
  enteteConsommation,
];
const _entetesHistoriqueRequis = [
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
  enteteRayon,
];

/// Lignes prévues pour le calcul de consommation dans le modèle vide (Historique).
const _lignesHistoriqueModele = 200;

/// Première ligne de données (ligne 7 du classeur, index 6).
const _premiereLigne = 6;

/// Au-delà de cette ligne, l'en-tête n'est plus cherché.
const _lignesEnteteMax = 12;

const _aides = {
  feuilleAccueil: '',
  feuilleMenu:
      'Une ligne par produit du menu. Famille et Type se choisissent dans la liste '
          '(Type : Composé (recette), À l\'unité, À la part ou Au litre). Prix en euros. '
          'Rayon : seulement pour un produit acheté tel quel. Consommation : par personne '
          'et par jour (0,5 = un produit pour deux personnes par jour).',
  feuilleRecettes:
      'Ce qu\'il faut pour faire UN produit composé : une ligne par ingrédient, avec '
          'la quantité par produit, l\'unité (unité, tranche, g, kg, cl, L) et le rayon des '
          'courses. Les courses en déduisent les ingrédients à acheter.',
  feuilleStock:
      'Une ligne par gymnase et par produit : la quantité au départ de '
          'l\'événement. Une quantité vide veut dire « produit non suivi ». Les noms '
          'doivent être ceux de l\'événement (majuscules et accents sans importance).',
  feuilleHistorique:
      'Les ventes d\'un événement passé : une ligne par gymnase et par produit, '
          'avec le nombre de personnes et de jours de cet événement. Sert de '
          'référence pour la prévision ; ne crée aucune vente. La dernière colonne se '
          'calcule toute seule.',
  feuilleCourses:
      'Les achats d\'un événement : série, produit (ou ligne libre), quantité '
          'achetée, coût en euros et rayon. Remplie à l\'export du tournoi ; ignorée à '
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
          'euros, son rayon, les lignes libres. Les détails des séries précédentes ne '
          'sont pas conservés : seul leur cumul (nombre de séries et coût) l\'est. '
          'Ignorée à l\'import.',
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
/// ignorée, le reste est lu. Une valeur inconnue dans une liste (famille, rayon) est
/// rangée dans « Autre » et signalée dans [erreurs] sans être bloquante.
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

// ------------------------------------------------------------------ mise en forme

const _anthracite = 'FF2F343C';
const _blanc = 'FFFFFFFF';
const _sable = 'FFD9B06F';
const _prune = 'FF6C4F86';
const _sauge = 'FF5A7D4F';
const _beige = 'FFE8DFD0';
const _gris = 'FF6B6F76';
const _bordure = 'FFD8CFC0';

ExcelColor _couleur(String argb) => ExcelColor.fromHexString(argb);

Border _filet() =>
    Border(borderStyle: BorderStyle.Thin, borderColorHex: _couleur(_bordure));

/// Format « 2,50 € ».
NumFormat get _formatEuros => NumFormat.custom(formatCode: '#,##0.00 "€"');

/// Format « 0,75 » (consommation, jours).
NumFormat get _formatDecimal => NumFormat.custom(formatCode: '0.00');

CellStyle _styleBandeauFond() => CellStyle(backgroundColorHex: _couleur(_anthracite));

CellStyle _styleTitre() => CellStyle(
      backgroundColorHex: _couleur(_anthracite),
      fontColorHex: _couleur(_blanc),
      bold: true,
      fontSize: 20,
      verticalAlign: VerticalAlign.Center,
    );

CellStyle _styleSousTitre() => CellStyle(
      backgroundColorHex: _couleur(_anthracite),
      fontColorHex: _couleur(_sable),
      fontSize: 11,
      verticalAlign: VerticalAlign.Center,
    );

CellStyle _styleFiletSable() => CellStyle(backgroundColorHex: _couleur(_sable));

CellStyle _styleAide() => CellStyle(
      fontColorHex: _couleur(_gris),
      italic: true,
      fontSize: 10,
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Center,
    );

CellStyle _styleSection() => CellStyle(
      fontColorHex: _couleur(_prune),
      bold: true,
      fontSize: 13,
      verticalAlign: VerticalAlign.Center,
    );

CellStyle _styleEntete() => CellStyle(
      backgroundColorHex: _couleur(_prune),
      fontColorHex: _couleur(_blanc),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: _filet(),
      rightBorder: _filet(),
      topBorder: _filet(),
      bottomBorder: _filet(),
    );

/// Case blanche à remplir.
CellStyle _styleSaisie({bool nombre = false, NumFormat? format}) => CellStyle(
      fontColorHex: _couleur(_anthracite),
      backgroundColorHex: _couleur(_blanc),
      horizontalAlign: nombre ? HorizontalAlign.Right : HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _filet(),
      rightBorder: _filet(),
      topBorder: _filet(),
      bottomBorder: _filet(),
      numberFormat: format ?? NumFormat.standard_0,
    );

/// Case beige en italique : calculée, ne pas la modifier.
CellStyle _styleCalcul({bool nombre = false, NumFormat? format}) => CellStyle(
      fontColorHex: _couleur(_gris),
      backgroundColorHex: _couleur(_beige),
      italic: true,
      horizontalAlign: nombre ? HorizontalAlign.Right : HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _filet(),
      rightBorder: _filet(),
      topBorder: _filet(),
      bottomBorder: _filet(),
      numberFormat: format ?? NumFormat.standard_0,
    );

void _poser(Sheet f, int ligne, int colonne, CellValue? v, CellStyle? style) {
  f.updateCell(
    CellIndex.indexByColumnRow(columnIndex: colonne, rowIndex: ligne),
    v,
    cellStyle: style,
  );
}

/// Bandeau anthracite (lignes 1 à 3) avec titre et sous-titre, filet sable (ligne 4).
void _bandeau(Sheet f, int largeur, String titre, String sousTitre) {
  f.setRowHeight(0, 10);
  f.setRowHeight(1, 34);
  f.setRowHeight(2, 22);
  f.setRowHeight(3, 4);
  for (var c = 0; c < largeur; c++) {
    _poser(f, 0, c, null, _styleBandeauFond());
    _poser(f, 1, c, null, _styleBandeauFond());
    _poser(f, 2, c, null, _styleBandeauFond());
    _poser(f, 3, c, null, _styleFiletSable());
  }
  _poser(f, 1, 0, TextCellValue(titre), _styleTitre());
  _poser(f, 2, 0, TextCellValue(sousTitre), _styleSousTitre());
}

/// Ligne d'aide (ligne 5), étirée sur la largeur de la feuille.
void _aideLigne(Sheet f, int largeur, String texte) {
  f.setRowHeight(4, 32);
  for (var c = 0; c < largeur; c++) {
    _poser(f, 4, c, null, _styleAide());
  }
  f.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4),
    CellIndex.indexByColumnRow(columnIndex: largeur - 1, rowIndex: 4),
    customValue: TextCellValue(texte),
  );
  f.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4), _styleAide());
}

/// Une feuille de données : bandeau, aide, en-têtes (ligne 6) et lignes à partir de
/// la ligne 7. Les colonnes de [calcul] sont calculées (beige) ; [formats] donne le
/// format des nombres par colonne.
void _feuilleDonnees(
  Excel classeur,
  String nom, {
  required String titre,
  required String sousTitre,
  required String aide,
  required List<String> entetes,
  required List<double> largeurs,
  required List<List<CellValue?>> lignes,
  Set<int> calcul = const {},
  Map<int, NumFormat> formats = const {},
}) {
  final f = classeur[nom];
  final n = entetes.length;
  _bandeau(f, n, titre, sousTitre);
  _aideLigne(f, n, aide);
  f.setRowHeight(5, 30);
  for (var c = 0; c < n; c++) {
    _poser(f, 5, c, TextCellValue(entetes[c]), _styleEntete());
    f.setColumnWidth(c, largeurs[c]);
  }
  for (var r = 0; r < lignes.length; r++) {
    final ligne = lignes[r];
    for (var c = 0; c < n; c++) {
      final v = c < ligne.length ? ligne[c] : null;
      final nombre =
          v is IntCellValue || v is DoubleCellValue || v is FormulaCellValue;
      final style = calcul.contains(c)
          ? _styleCalcul(nombre: nombre, format: formats[c])
          : _styleSaisie(nombre: nombre, format: formats[c]);
      _poser(f, _premiereLigne + r, c, v, style);
    }
  }
}

/// La première feuille, renommée « Accueil » : explique l'usage et les couleurs.
Excel _nouveauClasseur() {
  final classeur = Excel.createExcel();
  final defaut = classeur.getDefaultSheet() ?? 'Sheet1';
  classeur.rename(defaut, feuilleAccueil);
  return classeur;
}

void _feuilleAccueil(Excel classeur) {
  const largeur = 6;
  final f = classeur[feuilleAccueil];
  _bandeau(f, largeur, 'Le Comptoir : classeur de l\'association',
      'Le modèle de la buvette : à remplir, puis à importer dans l\'application.');
  f.setColumnWidth(0, 8);
  f.setColumnWidth(1, 28);
  for (var c = 2; c < largeur; c++) {
    f.setColumnWidth(c, 18);
  }
  _poser(f, 5, 0, TextCellValue('Comment s\'en servir'), _styleSection());
  f.setRowHeight(5, 26);
  const etapes = [
    ('1', 'Menu', 'Vos produits, leur famille, leur prix et ce que chaque personne consomme par jour.'),
    ('2', 'Recettes', 'Les ingrédients d\'un produit composé (croque…), une ligne par ingrédient, avec son rayon des courses.'),
    ('3', 'Stock de départ', 'Ce que vous avez déjà, gymnase par gymnase, avant le tournoi. Vide = produit non suivi.'),
    ('4', 'Historique', 'Les ventes d\'un tournoi passé : l\'application en tire la prévision du prochain. La dernière colonne se calcule.'),
    ('5', 'Courses', 'Rempli par l\'application à l\'export du tournoi : ce qui a été acheté, rayon par rayon. Ignoré à l\'import.'),
    ('6', 'Importer', 'Dans l\'application, à l\'écran de l\'événement : bouton « Excel ».'),
  ];
  for (var i = 0; i < etapes.length; i++) {
    final r = 6 + i * 2;
    final (numero, nom, texte) = etapes[i];
    f.setRowHeight(r, 26);
    _poser(
        f,
        r,
        0,
        TextCellValue(numero),
        CellStyle(
          backgroundColorHex: _couleur(_sauge),
          fontColorHex: _couleur(_blanc),
          bold: true,
          fontSize: 14,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        ));
    _poser(
        f,
        r,
        1,
        TextCellValue(nom),
        CellStyle(
          fontColorHex: _couleur(_anthracite),
          bold: true,
          fontSize: 12,
          verticalAlign: VerticalAlign.Center,
        ));
    final styleTexte = CellStyle(
      fontColorHex: _couleur(_anthracite),
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Center,
    );
    f.merge(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r),
      CellIndex.indexByColumnRow(columnIndex: largeur - 1, rowIndex: r),
      customValue: TextCellValue(texte),
    );
    f.setMergedCellStyle(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r), styleTexte);
  }
  final rl = 6 + etapes.length * 2 + 1;
  _poser(f, rl, 0, TextCellValue('Les couleurs'), _styleSection());
  f.setRowHeight(rl, 26);
  final lignesLegende = [
    (_couleur(_blanc), 'Case blanche : à remplir ou à corriger.'),
    (_couleur(_beige), 'Case beige en italique : calculée, ne pas la modifier.'),
    (_couleur(_prune), 'En-tête violet : ne pas renommer (l\'application le lit).'),
  ];
  for (var i = 0; i < lignesLegende.length; i++) {
    final r = rl + 1 + i;
    final (fond, texte) = lignesLegende[i];
    _poser(
        f,
        r,
        0,
        null,
        CellStyle(
          backgroundColorHex: fond,
          leftBorder: _filet(),
          rightBorder: _filet(),
          topBorder: _filet(),
          bottomBorder: _filet(),
        ));
    final styleLegende = CellStyle(
      fontColorHex: _couleur(_anthracite),
      verticalAlign: VerticalAlign.Center,
    );
    f.merge(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r),
      CellIndex.indexByColumnRow(columnIndex: largeur - 1, rowIndex: r),
      customValue: TextCellValue(texte),
    );
    f.setMergedCellStyle(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r), styleLegende);
  }
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

/// Ancienne écriture d'une recette dans la colonne « Recette » du Menu (lecture
/// seulement depuis la version 2 du modèle) : « 2 tranche Pain de mie ; 25 g Gruyère ».
/// Un « ; » dans un nom devient une virgule.
String recetteEnTexte(List<Ingredient> ingredients) => ingredients
    .map((i) =>
        '${_nombreTexte(i.quantite)} ${libellesUnites[i.unite] ?? i.unite} '
        '${i.nom.replaceAll(';', ',')}')
    .join(' ; ');

CellValue? _nombre(num? n) {
  if (n == null) return null;
  return n is int || n == n.roundToDouble()
      ? IntCellValue(n.toInt())
      : DoubleCellValue(n.toDouble());
}

/// Formule de consommation par personne et par jour d'une ligne de l'Historique
/// (colonnes C personnes, D jours, F quantité vendue ; [ligne] = numéro Excel).
FormulaCellValue _formuleConso(int ligne) => FormulaCellValue(
    'IF(OR(C$ligne="",D$ligne="",F$ligne=""),"",IF(C$ligne*D$ligne=0,"",F$ligne/(C$ligne*D$ligne)))');

/// Les lignes de la feuille Menu : une par produit de l'événement (consommation du
/// MENU, pas de la prévision).
List<List<CellValue?>> _lignesMenu(List<ProduitEvenement> produits) => [
      for (final p in produits)
        [
          TextCellValue(libellesFamilles[p.fiche.famille] ?? 'Autre'),
          TextCellValue(p.nom),
          _nombre(p.prixCentimes / 100),
          TextCellValue(libellesTypes[p.fiche.type] ?? p.fiche.type),
          TextCellValue(
              libellesProvenances[p.fiche.provenance] ?? p.fiche.provenance),
          _nombre(p.fiche.verresParLitre),
          _nombre(p.fiche.partsParEntier),
          // Le rayon ne sert qu'aux produits achetés tels quels (comme l'application).
          p.fiche.type != 'compose' && p.fiche.provenance == 'achete'
              ? TextCellValue(libellesRayons[p.fiche.rayon] ?? 'Autre')
              : null,
          _nombre(p.fiche.conso),
        ],
    ];

/// Les lignes de la feuille Recettes : un ingrédient par ligne, pour les produits
/// composés de [produits].
List<List<CellValue?>> _lignesRecettes(List<ProduitEvenement> produits) => [
      for (final p in produits)
        for (final i in p.fiche.ingredients)
          [
            TextCellValue(p.nom),
            TextCellValue(i.nom.replaceAll(';', ',')),
            _nombre(i.quantite),
            TextCellValue(libellesUnites[i.unite] ?? i.unite),
            TextCellValue(libellesRayons[i.rayon] ?? 'Autre'),
          ],
    ];

Uint8List _octets(Excel classeur) {
  classeur.setDefaultSheet(feuilleAccueil);
  final octets = classeur.encode();
  if (octets == null) {
    throw const ClasseurIllisible('Le classeur n\'a pas pu être construit.');
  }
  return _avecVolets(Uint8List.fromList(octets));
}

// ------------------------------------- volets figés et listes déroulantes (E8)
// Le paquet excel 4.0.6 n'écrit ni volets figés ni listes : on ajoute ces éléments au
// XML des feuilles après l'écriture (les feuilles restent des feuilles Excel ordinaires).

/// Feuilles dont les en-têtes restent visibles : volets figés sous la ligne 6.
const _voletsFiges = {
  feuilleMenu: 6,
  feuilleRecettes: 6,
  feuilleStock: 6,
  feuilleHistorique: 6,
  feuilleCourses: 6,
};

/// Lignes Excel couvertes par les listes déroulantes (de la première donnée à la 500e).
const _ligneListeDebut = 7;
const _ligneListeFin = 500;

/// Une liste déroulante : colonne (lettre) et valeurs fixes.
typedef _Liste = ({String colonne, List<String> valeurs});

/// Les listes déroulantes de chaque feuille, avec les libellés des listes fixes.
Map<String, List<_Liste>> get _listesDeroulantes => {
      feuilleMenu: [
        (colonne: 'A', valeurs: [for (final k in famillesProduit) libellesFamilles[k]!]),
        (colonne: 'D', valeurs: libellesTypes.values.toList()),
        (colonne: 'E', valeurs: libellesProvenances.values.toList()),
        (colonne: 'H', valeurs: [for (final k in rayonsCourses) libellesRayons[k]!]),
      ],
      feuilleRecettes: [
        (colonne: 'D', valeurs: [for (final u in unitesIngredient) libellesUnites[u]!]),
        (colonne: 'E', valeurs: [for (final k in rayonsCourses) libellesRayons[k]!]),
      ],
    };

String _echapper(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Chemin, dans le zip, de la feuille XML de chaque feuille (nom -> « xl/worksheets/… »).
Map<String, String> _cheminsFeuilles(Archive archive) {
  String texteDe(String chemin) {
    for (final f in archive.files) {
      if (f.name == chemin) return utf8.decode(f.content as List<int>);
    }
    return '';
  }

  final cibles = <String, String>{};
  for (final m in RegExp(r'<Relationship\b[^>]*>')
      .allMatches(texteDe('xl/_rels/workbook.xml.rels'))) {
    final tag = m.group(0)!;
    final id = RegExp(r'\bId="([^"]+)"').firstMatch(tag)?.group(1);
    final cible = RegExp(r'\bTarget="([^"]+)"').firstMatch(tag)?.group(1);
    if (id != null && cible != null) {
      cibles[id] = cible.startsWith('/') ? cible.substring(1) : 'xl/$cible';
    }
  }
  final chemins = <String, String>{};
  for (final m in RegExp(r'<sheet\b[^>]*>').allMatches(texteDe('xl/workbook.xml'))) {
    final tag = m.group(0)!;
    final nom = RegExp(r'\bname="([^"]+)"').firstMatch(tag)?.group(1);
    final id = RegExp(r'\br:id="([^"]+)"').firstMatch(tag)?.group(1);
    if (nom != null && id != null && cibles[id] != null) {
      chemins[nom] = cibles[id]!;
    }
  }
  return chemins;
}

/// Le XML d'une feuille du classeur (pour contrôle) ; vide si la feuille n'existe pas.
String xmlDeFeuille(List<int> octets, String nom) {
  final archive = ZipDecoder().decodeBytes(octets);
  final chemin = _cheminsFeuilles(archive)[nom];
  if (chemin == null) return '';
  for (final f in archive.files) {
    if (f.name == chemin) return utf8.decode(f.content as List<int>);
  }
  return '';
}

/// Ajoute volets figés et listes déroulantes aux feuilles concernées du classeur.
Uint8List _avecVolets(Uint8List octets) {
  final archive = ZipDecoder().decodeBytes(octets);
  final parChemin = {for (final e in _cheminsFeuilles(archive).entries) e.value: e.key};
  final sortie = Archive();
  for (final f in archive.files) {
    var contenu = f.content as List<int>;
    final nom = parChemin[f.name];
    if (nom != null) {
      var xml = utf8.decode(contenu);
      final ligne = _voletsFiges[nom];
      if (ligne != null) xml = _insererVolets(xml, ligne);
      final listes = _listesDeroulantes[nom];
      if (listes != null) xml = _insererListes(xml, listes);
      contenu = utf8.encode(xml);
    }
    sortie.addFile(ArchiveFile(f.name, contenu.length, contenu));
  }
  return Uint8List.fromList(ZipEncoder().encode(sortie)!);
}

/// Volets figés sous la ligne [ligne] (les lignes au-dessus ne défilent pas).
String _insererVolets(String xml, int ligne) {
  final vue = '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="$ligne" topLeftCell="A${ligne + 1}" activePane="bottomLeft" state="frozen"/>'
      '<selection pane="bottomLeft" activeCell="A${ligne + 1}" sqref="A${ligne + 1}"/>'
      '</sheetView></sheetViews>';
  final existant = RegExp(r'<sheetViews>[\s\S]*?</sheetViews>');
  if (existant.hasMatch(xml)) return xml.replaceFirst(existant, vue);
  for (final balise in ['<sheetFormatPr', '<cols>', '<sheetData']) {
    final i = xml.indexOf(balise);
    if (i >= 0) return xml.substring(0, i) + vue + xml.substring(i);
  }
  return xml;
}

/// Listes déroulantes (validation de données) sur les colonnes de données.
String _insererListes(String xml, List<_Liste> listes) {
  final buf = StringBuffer('<dataValidations count="${listes.length}">');
  for (final l in listes) {
    final formule = _echapper('"${l.valeurs.join(',')}"');
    buf.write('<dataValidation type="list" allowBlank="1" showErrorMessage="1" '
        'errorTitle="Valeur inconnue" error="Choisissez une valeur dans la liste." '
        'sqref="${l.colonne}$_ligneListeDebut:${l.colonne}$_ligneListeFin">'
        '<formula1>$formule</formula1></dataValidation>');
  }
  buf.write('</dataValidations>');
  for (final balise in ['<pageMargins', '</worksheet>']) {
    final i = xml.indexOf(balise);
    if (i >= 0) return xml.substring(0, i) + buf.toString() + xml.substring(i);
  }
  return xml;
}

void _feuilleMenu(Excel classeur, List<ProduitEvenement> produits, String aide) =>
    _feuilleDonnees(
      classeur,
      feuilleMenu,
      titre: 'Menu',
      sousTitre:
          'Le catalogue de la buvette : ce qu\'on vend, à quel prix, et ce qu\'une personne consomme par jour.',
      aide: aide,
      entetes: entetesMenu,
      largeurs: const [24, 32, 13, 20, 26, 16, 16, 24, 22],
      lignes: _lignesMenu(produits),
      formats: {2: _formatEuros, 8: _formatDecimal},
    );

void _feuilleRecettes(
        Excel classeur, List<ProduitEvenement> produits, String aide) =>
    _feuilleDonnees(
      classeur,
      feuilleRecettes,
      titre: 'Recettes',
      sousTitre:
          'Ce qu\'il faut pour faire UN produit composé. Les courses en déduisent les ingrédients à acheter.',
      aide: aide,
      entetes: entetesRecettes,
      largeurs: const [32, 30, 22, 14, 26],
      lignes: _lignesRecettes(produits),
      formats: {2: NumFormat.custom(formatCode: '0.###')},
    );

/// Le modèle du classeur rempli avec les données de l'événement : le menu (consommation
/// du MENU, pas de la prévision), les recettes et le stock de départ des [gymnases]
/// donnés. L'Historique ne contient que les formules de consommation ; les Courses
/// ne contiennent que leurs en-têtes.
Uint8List construireModele({
  required List<ProduitEvenement> produits,
  required List<Gymnase> gymnases,
  required Map<String, Map<String, StockDepart>> stocks,
}) {
  final classeur = _nouveauClasseur();
  _feuilleAccueil(classeur);
  _feuilleMenu(classeur, produits, _aides[feuilleMenu]!);
  _feuilleRecettes(classeur, produits, _aides[feuilleRecettes]!);
  _feuilleDonnees(
    classeur,
    feuilleStock,
    titre: 'Stock de départ',
    sousTitre: 'Ce que vous avez déjà avant le tournoi. Vide = produit non suivi.',
    aide: _aides[feuilleStock]!,
    entetes: entetesStock,
    largeurs: const [26, 32, 14],
    lignes: [
      for (final g in gymnases)
        for (final p in produits)
          [
            TextCellValue(g.nom),
            TextCellValue(p.nom),
            _nombre(stocks[g.id]?[p.id]?.quantite),
          ],
    ],
  );
  _feuilleDonnees(
    classeur,
    feuilleHistorique,
    titre: 'Historique',
    sousTitre:
        'Les ventes d\'un tournoi passé : l\'application en tire la prévision du prochain.',
    aide: _aides[feuilleHistorique]!,
    entetes: entetesHistorique,
    largeurs: const [26, 24, 13, 10, 32, 16, 24],
    calcul: const {6},
    formats: {6: _formatDecimal},
    lignes: [
      for (var k = 0; k < _lignesHistoriqueModele; k++)
        [
          null,
          null,
          null,
          null,
          null,
          null,
          _formuleConso(_premiereLigne + k + 1),
        ],
    ],
  );
  _feuilleDonnees(
    classeur,
    feuilleCourses,
    titre: 'Courses',
    sousTitre:
        'Rempli par l\'application à l\'export du tournoi : ce qui a été acheté, rayon par rayon.',
    aide: _aides[feuilleCourses]!,
    entetes: entetesCourses,
    largeurs: const [10, 40, 18, 14, 26],
    lignes: const [],
    formats: {3: _formatEuros},
  );
  return _octets(classeur);
}

// ------------------------------------------------------- export du tournoi (P8)

/// Le classeur complet d'un tournoi (décision 57), à relire ou à réimporter : les
/// feuilles du modèle et le Bilan, avec les chiffres de l'écran du bilan. Il contient ce
/// que la personne voit : [gymnases] sont ceux de sa portée et [tableau] leurs seules
/// ventes ; [limite] l'indique sur la feuille Bilan. [stocksReference] : le total de
/// référence du stock de chaque gymnase (stock de départ plus réapprovisionnements),
/// [stocksActuels] : ce qu'il en reste (pour le bilan). [courses] : la liste de courses ;
/// [coursesVisibles] faux = la personne n'y a pas droit (ni séries, ni coût, ni résultat).
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
  List<Apport> apports = const [],
}) {
  final classeur = _nouveauClasseur();
  _feuilleAccueil(classeur);
  _feuilleMenu(classeur, produits, _aides[feuilleMenu]!);
  _feuilleRecettes(classeur, produits, _aides[feuilleRecettes]!);
  _feuilleDonnees(
    classeur,
    feuilleStock,
    titre: 'Stock de départ',
    sousTitre: 'Le stock de référence de chaque gymnase à la fin du tournoi.',
    aide: _aidesExport[feuilleStock]!,
    entetes: entetesStock,
    largeurs: const [26, 32, 14],
    lignes: [
      for (final g in gymnases)
        for (final p in produits)
          if (stocksReference[g.id]?[p.id] != null)
            [
              TextCellValue(g.nom),
              TextCellValue(p.nom),
              _nombre(stocksReference[g.id]![p.id]),
            ],
    ],
  );
  _feuilleDonnees(
    classeur,
    feuilleHistorique,
    titre: 'Historique',
    sousTitre: evenement.nom,
    aide: _aidesExport[feuilleHistorique]!,
    entetes: entetesHistorique,
    largeurs: const [26, 24, 13, 10, 32, 16, 24],
    calcul: const {6},
    formats: {6: _formatDecimal},
    lignes: _lignesHistoriqueExport(evenement, produits, gymnases, tableau),
  );
  _feuilleDonnees(
    classeur,
    feuilleCourses,
    titre: 'Courses',
    sousTitre: 'Les achats de la série validée, rayon par rayon.',
    aide: _aidesExport[feuilleCourses]!,
    entetes: entetesCourses,
    largeurs: const [10, 40, 18, 14, 26],
    lignes: _lignesCourses(evenement, produits, courses, coursesVisibles),
    formats: {3: _formatEuros},
  );
  _ecrireBilan(classeur, evenement, produits, gymnases, stocksActuels, tableau,
      courses, coursesVisibles, limite, apports);
  return _octets(classeur);
}

/// Les lignes de l'Historique de l'export : une par gymnase et par produit.
List<List<CellValue?>> _lignesHistoriqueExport(Evenement evenement,
    List<ProduitEvenement> produits, List<Gymnase> gymnases, TableauDeBord tableau) {
  final lignes = <List<CellValue?>>[];
  for (final g in gymnases) {
    for (final p in produits) {
      lignes.add([
        TextCellValue(evenement.nom),
        TextCellValue(g.nom),
        _nombre(g.personnes),
        _nombre(evenement.nbJours),
        TextCellValue(p.nom),
        _nombre(tableau.pour(g.id).vendus(p.id)),
        _formuleConso(_premiereLigne + lignes.length + 1),
      ]);
    }
  }
  return lignes;
}

/// Le texte de l'unité de base d'un achat, pour le nom de la ligne : « Gruyère (g) ».
String _uniteAchat(String uniteBase) => switch (uniteBase) {
      'unite' => 'unité',
      'gateau' => 'gâteau',
      _ => uniteBase,
    };

/// Le libellé du rayon d'un achat, ou null pour une ligne sans rayon.
String? _libelleRayon(String? rayon) =>
    rayon == null ? null : libellesRayons[rayon] ?? 'Autre';

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
        TextCellValue(libellesRayons[a.rayon] ?? 'Autre'),
      ]);
    }
    lignes.add([
      _nombre(serie),
      TextCellValue('Total de la série $serie'),
      null,
      _nombre(validation.coutCentimes / 100),
      null,
    ]);
  } else {
    lignes.add([
      _nombre(serie),
      TextCellValue('Courses non validées'),
      null,
      null,
      null,
    ]);
  }
  for (final l in liste.libres) {
    lignes.add([
      _nombre(serie),
      TextCellValue(l.nom),
      _nombre(l.quantite),
      null,
      TextCellValue(_libelleRayon(l.rayon) ?? 'Autre'),
    ]);
  }
  return lignes;
}

/// La feuille Bilan : les rubriques de l'écran du bilan en tableaux successifs
/// séparés d'une ligne vide. Même bandeau et mêmes couleurs que les autres feuilles.
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
  List<Apport> apports,
) {
  final b = Bilan.depuis(tableau, produits, evenement.modes, stocks: stocksActuels);
  final f = classeur[feuilleBilan];
  const largeur = 6;
  _bandeau(f, largeur, 'Bilan', evenement.nom);
  _aideLigne(f, largeur, _aidesExport[feuilleBilan]!);
  const largeurs = [30.0, 20.0, 16.0, 16.0, 18.0, 22.0];
  for (var c = 0; c < largeur; c++) {
    f.setColumnWidth(c, largeurs[c]);
  }
  var r = 6;
  void ligne(List<CellValue?> cellules, {bool section = false, bool tete = false}) {
    for (var c = 0; c < cellules.length; c++) {
      final v = cellules[c];
      if (v == null && !tete) continue;
      final nombre = v is IntCellValue || v is DoubleCellValue;
      final style = section
          ? _styleSection()
          : tete
              ? _styleEntete()
              : _styleSaisie(nombre: nombre);
      _poser(f, r, c, v, style);
    }
    r++;
  }

  void vide() => r++;
  CellValue t(String s) => TextCellValue(s);
  CellValue? euros(int centimes) => _nombre(centimes / 100);
  String nomGymnase(String id) =>
      gymnases.where((g) => g.id == id).firstOrNull?.nom ?? '?';

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

  ligne([t('Totaux')], section: true);
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

  ligne([t('Par mode de paiement')], section: true);
  ligne([t('Mode'), t('Montant')], tete: true);
  for (final e in b.parMode.entries) {
    ligne([t(modesPaiement[e.key] ?? e.key), euros(e.value)]);
  }
  vide();

  ligne([t('Par produit')], section: true);
  ligne([t('Produit'), t('Vendus'), t('Montant'), t('Stock restant')], tete: true);
  for (final l in b.produits) {
    ligne([t(l.nom), _nombre(l.quantite), euros(l.montantCentimes), _nombre(l.stock)]);
  }
  vide();

  ligne([t('Par caisse')], section: true);
  ligne([
    t('Caisse'),
    t('Gymnase'),
    t('État'),
    t('Ventes'),
    t('Annulées'),
    t('Montant')
  ], tete: true);
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

  ligne([t('Par jour')], section: true);
  ligne([t('Jour'), t('Ventes'), t('Montant')], tete: true);
  for (final j in b.jours) {
    ligne([t(dateAffichee(j.jour)), _nombre(j.nbVentes), euros(j.totalCentimes)]);
  }
  vide();

  ligne([t('Par heure')], section: true);
  ligne([t('Heure'), t('Ventes'), t('Montant')], tete: true);
  for (final h in b.heures) {
    ligne([t(trancheAffichee(h.heure)), _nombre(h.nbVentes), euros(h.totalCentimes)]);
  }

  if (apports.isNotEmpty) {
    vide();
    ligne([t('Apports')], section: true);
    ligne([t('Apport'), t('Parts'), t('Prénom'), t('Gymnase'), t('Produit')], tete: true);
    for (final a in apports) {
      ligne([
        t(a.nom),
        _nombre(a.parts),
        t(a.prenom),
        t(a.gymnaseNom),
        t(a.produitNom),
      ]);
    }
  }

  if (b.annulations.isNotEmpty) {
    vide();
    ligne([t('Ventes annulées')], section: true);
    ligne([
      t('Caisse'),
      t('Vendue le'),
      t('Montant'),
      t('Mode'),
      t('Annulée par'),
      t('Annulée le')
    ], tete: true);
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

/// Le texte d'une cellule ; une formule (valeur calculée) n'est pas une saisie.
String? _texteDe(Data? d) {
  final v = d?.value;
  if (v == null || v is FormulaCellValue) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

/// Un nombre : cellule numérique, ou texte avec virgule décimale et espaces
/// (« 1,5 », « 1 200 »). Null si la cellule est vide ; lève [FormatException] sinon.
double? _nombreDe(Data? d) {
  final v = d?.value;
  if (v == null || v is FormulaCellValue) return null;
  if (v is IntCellValue) return v.value.toDouble();
  if (v is DoubleCellValue) return v.value;
  final t = v.toString().replaceAll(RegExp(r'[\s  ]'), '');
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

/// Les ingrédients d'une recette écrite « quantité unité nom ; … » (ancienne colonne
/// « Recette » du Menu).
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

/// La clé d'une table de libellés (« Boissons chaudes » -> « boissons_chaudes »).
String? _valeurDe(Map<String, String> table, String texte) {
  final cle = cleIngredient(texte);
  for (final e in table.entries) {
    if (cleIngredient(e.key) == cle || cleIngredient(e.value) == cle) {
      return e.key;
    }
  }
  return null;
}

/// La position d'un en-tête : ligne (index) et colonnes par nom.
class _Entete {
  const _Entete(this.ligne, this.colonnes);

  final int ligne;
  final Map<String, int> colonnes;
}

/// Colonnes d'une ligne par leur contenu (clé sans casse ni accents).
Map<String, int> _clesDe(List<Data?> ligne) {
  final cles = <String, int>{};
  for (var c = 0; c < ligne.length; c++) {
    final t = _texteDe(ligne[c]);
    if (t != null) cles.putIfAbsent(cleIngredient(t), () => c);
  }
  return cles;
}

/// La ligne d'en-têtes d'une feuille : celle des [_lignesEnteteMax] premières qui
/// contient le plus d'en-têtes requis. Un en-tête requis absent est signalé dans
/// [erreurs] ; null si l'un manque.
_Entete? _entete(
    Sheet feuille, List<String> requis, List<String> facultatifs, List<String> erreurs) {
  final lignes = feuille.rows;
  var meilleure = 0;
  var meilleurScore = -1;
  final fin = lignes.length < _lignesEnteteMax ? lignes.length : _lignesEnteteMax;
  for (var r = 0; r < fin; r++) {
    final cles = _clesDe(lignes[r]);
    final score = requis.where((a) => cles.containsKey(cleIngredient(a))).length;
    if (score > meilleurScore) {
      meilleurScore = score;
      meilleure = r;
    }
  }
  final cles = lignes.isEmpty ? <String, int>{} : _clesDe(lignes[meilleure]);
  final res = <String, int>{};
  var complet = true;
  for (final a in requis) {
    final c = cles[cleIngredient(a)];
    if (c == null) {
      erreurs.add(
          'Feuille « ${feuille.sheetName} » : colonne « $a » introuvable.');
      complet = false;
    } else {
      res[a] = c;
    }
  }
  for (final a in facultatifs) {
    final c = cles[cleIngredient(a)];
    if (c != null) res[a] = c;
  }
  return complet ? _Entete(meilleure, res) : null;
}

Data? _cellule(List<Data?> ligne, int c) => c < ligne.length ? ligne[c] : null;

/// Une ligne sans saisie (une formule seule ne compte pas comme une saisie).
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

  Sheet? feuille(String nom, {bool facultative = false}) {
    for (final e in classeur.tables.entries) {
      if (cleIngredient(e.key) == cleIngredient(nom)) return e.value;
    }
    if (!facultative) erreurs.add('Feuille « $nom » introuvable.');
    return null;
  }

  /// Un libellé lu dans une liste fixe ; inconnu = [defaut] et une ligne signalée.
  String libelle(String feuilleNom, List<Data?> l, _Entete t, String colonne,
      Map<String, String> table, String defaut, String quoi, String produit) {
    final c = t.colonnes[colonne];
    final texte = c == null ? null : _texteDe(_cellule(l, c));
    if (texte == null) return defaut;
    final cle = _valeurDe(table, texte);
    if (cle != null) return cle;
    erreurs.add('Feuille « $feuilleNom » : $quoi « $texte » inconnue, rangée '
        'dans « ${table[defaut]} » (« $produit »).');
    return defaut;
  }

  // ---------- Recettes (facultative : l'ancien format n'en a pas)
  final recettes = <String, List<Ingredient>>{};
  final lignesRecette = <(int, String)>[];
  final fRecettes = feuille(feuilleRecettes, facultative: true);
  final tRecettes = fRecettes == null
      ? null
      : _entete(fRecettes, _entetesRecettesRequis, const [enteteRayon], erreurs);
  if (fRecettes != null && tRecettes != null) {
    final lignes = fRecettes.rows;
    for (var i = tRecettes.ligne + 1; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final p = _texteDe(_cellule(l, tRecettes.colonnes[enteteProduit]!));
        final ing = _texteDe(_cellule(l, tRecettes.colonnes[enteteIngredient]!));
        if (p == null || ing == null) {
          throw const FormatException(
              'le produit et l\'ingrédient sont obligatoires');
        }
        final q = _nombreDe(_cellule(l, tRecettes.colonnes[enteteQuantiteProduit]!));
        if (q == null || q <= 0 || q > 100000) {
          throw const FormatException(
              'la quantité par produit doit être un nombre positif');
        }
        final uniteTexte =
            _texteDe(_cellule(l, tRecettes.colonnes[enteteUnite]!));
        final unite =
            uniteTexte == null ? null : _valeurDe(libellesUnites, uniteTexte);
        if (unite == null) {
          throw FormatException(
              'unité inconnue « $uniteTexte » (unité, tranche, g, kg, cl, L)');
        }
        final rayon = libelle(feuilleRecettes, l, tRecettes, enteteRayon,
            libellesRayons, 'autre', 'rayon', ing);
        recettes
            .putIfAbsent(cleIngredient(p), () => [])
            .add(Ingredient(ing, q, unite, rayon));
        lignesRecette.add((i + 1, p));
      } on FormatException catch (e) {
        erreurs.add('Feuille « $feuilleRecettes », ligne ${i + 1} : ${e.message}');
      }
    }
  }

  // ---------- Menu
  final produits = <ProduitClasseur>[];
  final fMenu = feuille(feuilleMenu);
  final tMenu = fMenu == null
      ? null
      : _entete(fMenu, _entetesMenuRequis, _entetesMenuFacultatifs, erreurs);
  if (fMenu != null && tMenu != null) {
    final lignes = fMenu.rows;
    for (var i = tMenu.ligne + 1; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final nom = _texteDe(_cellule(l, tMenu.colonnes[enteteProduit]!));
        if (nom == null || nom.length > 40) {
          throw const FormatException(
              'le nom du produit est vide ou dépasse 40 caractères');
        }
        final prix = _nombreDe(_cellule(l, tMenu.colonnes['Prix']!));
        if (prix == null) throw const FormatException('le prix est vide');
        final centimes = (prix * 100).round();
        if (prix < 0 || centimes > 100000) {
          throw const FormatException('le prix doit être entre 0 et 1 000 €');
        }
        final typeTexte = _texteDe(_cellule(l, tMenu.colonnes['Type']!));
        final type =
            typeTexte == null ? 'unite' : _valeurDe(libellesTypes, typeTexte);
        if (type == null) throw FormatException('type inconnu « $typeTexte »');
        final provTexte = _texteDe(_cellule(l, tMenu.colonnes['Provenance']!));
        final prov = provTexte == null
            ? 'achete'
            : _valeurDe(libellesProvenances, provTexte);
        if (prov == null) {
          throw FormatException('provenance inconnue « $provTexte »');
        }
        final verres = _nombreDe(_cellule(l, tMenu.colonnes['Verres par litre']!));
        final parts = _entierDe(_cellule(l, tMenu.colonnes['Parts par gâteau']!),
            'le nombre de parts par gâteau');
        final conso =
            _nombreDe(_cellule(l, tMenu.colonnes[enteteConsommation]!));
        final famille = libelle(feuilleMenu, l, tMenu, enteteFamille,
            libellesFamilles, 'autre', 'famille', nom);
        final rayon = libelle(feuilleMenu, l, tMenu, enteteRayon,
            libellesRayons, 'autre', 'rayon', nom);
        // Recettes de la feuille Recettes ; à défaut, l'ancienne colonne « Recette ».
        final recetteAncienne = tMenu.colonnes[enteteRecette] == null
            ? null
            : _texteDe(_cellule(l, tMenu.colonnes[enteteRecette]!));
        final ingredients = recettes[cleIngredient(nom)] ??
            (recetteAncienne == null
                ? const <Ingredient>[]
                : recetteDepuisTexte(recetteAncienne));
        final fiche = FicheProduit(
          type: type,
          provenance: prov,
          verresParLitre: verres,
          partsParEntier: parts,
          ingredients: ingredients,
          conso: conso,
          famille: famille,
          rayon: rayon,
        );
        final erreur = fiche.erreur();
        if (erreur != null) throw FormatException(erreur);
        produits.add(ProduitClasseur(nom, centimes, fiche));
      } on FormatException catch (e) {
        erreurs.add('Feuille « $feuilleMenu », ligne ${i + 1} : ${e.message}');
      }
    }
  }

  // Une recette qui vise un produit absent du Menu est ignorée, et dite.
  final nomsMenu = {for (final p in produits) cleIngredient(p.nom)};
  for (final (ligne, p) in lignesRecette) {
    if (!nomsMenu.contains(cleIngredient(p))) {
      erreurs.add('Feuille « $feuilleRecettes », ligne $ligne : produit « $p » '
          'absent du Menu.');
    }
  }

  // ---------- Stock de départ
  final stocks = <StockClasseur>[];
  final fStock = feuille(feuilleStock);
  final tStock = fStock == null
      ? null
      : _entete(fStock, entetesStock, const [], erreurs);
  if (fStock != null && tStock != null) {
    final lignes = fStock.rows;
    for (var i = tStock.ligne + 1; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final g = _texteDe(_cellule(l, tStock.colonnes['Gymnase']!));
        final p = _texteDe(_cellule(l, tStock.colonnes[enteteProduit]!));
        if (g == null || p == null) {
          throw const FormatException(
              'le gymnase et le produit sont obligatoires');
        }
        final q = _entierDe(_cellule(l, tStock.colonnes['Quantité']!), 'la quantité');
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
  final tHisto = fHisto == null
      ? null
      : _entete(fHisto, _entetesHistoriqueRequis, const [], erreurs);
  if (fHisto != null && tHisto != null) {
    final lignes = fHisto.rows;
    for (var i = tHisto.ligne + 1; i < lignes.length; i++) {
      final l = lignes[i];
      if (_vide(l)) continue;
      try {
        final ev = _texteDe(_cellule(l, tHisto.colonnes['Événement']!));
        final g = _texteDe(_cellule(l, tHisto.colonnes['Gymnase']!));
        final p = _texteDe(_cellule(l, tHisto.colonnes[enteteProduit]!));
        if (ev == null || g == null || p == null) {
          throw const FormatException(
              'l\'événement, le gymnase et le produit sont obligatoires');
        }
        final pers = _entierDe(
            _cellule(l, tHisto.colonnes['Personnes']!), 'le nombre de personnes');
        final jours = _nombreDe(_cellule(l, tHisto.colonnes['Jours']!));
        final vendu = _entierDe(
            _cellule(l, tHisto.colonnes['Quantité vendue']!), 'la quantité vendue');
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
