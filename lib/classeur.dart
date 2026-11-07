import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'depot_menus.dart';
import 'evenement.dart';
import 'gymnase.dart';

// Le classeur Excel de l'association (décision 57) : un fichier .xlsx à quatre
// feuilles. Chaque feuille commence par une ligne d'aide (ligne 1) puis une ligne
// d'en-têtes (ligne 2) ; les données commencent à la ligne 3. Logique pure : aucune
// lecture ni écriture dans Firestore. Les produits et les gymnases se retrouvent par
// leur NOM (sans casse ni accents, comme le report de stock).

const feuilleMenu = 'Menu';
const feuilleStock = 'Stock de départ';
const feuilleHistorique = 'Historique';
const feuilleCourses = 'Courses';

/// Les feuilles du modèle, dans l'ordre.
const feuillesModele = [feuilleMenu, feuilleStock, feuilleHistorique, feuilleCourses];

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
    List<List<CellValue?>> lignes) {
  final f = classeur[nom];
  f.appendRow([TextCellValue(_aides[nom]!)]);
  f.appendRow([for (final e in entetes) TextCellValue(e)]);
  for (final l in lignes) {
    f.appendRow(l);
  }
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
  _ecrireFeuille(classeur, feuilleMenu, entetesMenu, [
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
  ]);
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
  classeur.setDefaultSheet(feuilleMenu);
  final octets = classeur.encode();
  if (octets == null) {
    throw const ClasseurIllisible('Le classeur n\'a pas pu être construit.');
  }
  return Uint8List.fromList(octets);
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
