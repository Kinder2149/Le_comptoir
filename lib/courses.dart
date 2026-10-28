import 'depot_menus.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'ticket.dart';

// Courses d'un événement, préparation (chantier Stock et courses, étape 5).
// Logique pure : aucune lecture de base ici, tout se calcule à partir des produits
// de l'événement, des réglages (jours, personnes) et de la saisie de la gestion.

/// Nombre de jours d'un événement tant que la gestion ne l'a pas réglé.
const joursParDefaut = 2;
const joursMax = 30;
const personnesMax = 1000;

/// Arrondi à l'entier supérieur, sans que 3920,0000000001 devienne 3921.
int arrondiHaut(double x) => x <= 1e-6 ? 0 : (x - 1e-6).ceil();

/// Quantité de produits finaux prévue : personnes × jours × consommation.
int quantitePrevue(
        {required int personnes, required int jours, required double conso}) =>
    arrondiHaut(personnes * jours * conso);

/// Quantité de produits finaux à acheter pour un gymnase (pour un produit au
/// litre : des verres).
class LigneCourse {
  const LigneCourse(this.gymnaseId, this.produitId, this.quantite);

  final String gymnaseId;
  final String produitId;
  final int quantite;

  Map<String, dynamic> versMap() =>
      {'gymnaseId': gymnaseId, 'produitId': produitId, 'quantite': quantite};
}

/// Ligne libre (décision 43) : matériel d'organisation, etc. Elle n'entre ni
/// dans le stock ni dans le calcul.
class LigneLibre {
  const LigneLibre(this.nom, this.quantite);

  final String nom;
  final double quantite;

  Map<String, dynamic> versMap() => {'nom': nom, 'quantite': quantite};
}

/// La liste de courses d'un événement, en préparation.
class ListeCourses {
  const ListeCourses({
    this.lignes = const [],
    this.libres = const [],
    this.restes = const {},
  });

  /// Produits finaux voulus, par gymnase. Une ligne absente = produit non acheté.
  final List<LigneCourse> lignes;
  final List<LigneLibre> libres;

  /// « Ce qu'il reste », par clé d'achat (voir [Achat.cle]), dans l'unité de base
  /// de l'achat (g, cl, tranche, unité).
  final Map<String, double> restes;

  factory ListeCourses.depuis(Map<String, dynamic> d) => ListeCourses(
        lignes: [
          for (final l in (d['lignes'] as List?) ?? const [])
            LigneCourse(l['gymnaseId'] as String, l['produitId'] as String,
                (l['quantite'] as num).toInt()),
        ],
        libres: [
          for (final l in (d['libres'] as List?) ?? const [])
            LigneLibre(l['nom'] as String, (l['quantite'] as num).toDouble()),
        ],
        restes: {
          for (final r in (d['restes'] as List?) ?? const [])
            r['cle'] as String: (r['quantite'] as num).toDouble(),
        },
      );

  Map<String, dynamic> versMap() => {
        'statut': 'preparation',
        'lignes': [for (final l in lignes) l.versMap()],
        'libres': [for (final l in libres) l.versMap()],
        'restes': [
          for (final e in restes.entries)
            {'cle': e.key, 'quantite': e.value},
        ],
      };

  ListeCourses avec({
    List<LigneCourse>? lignes,
    List<LigneLibre>? libres,
    Map<String, double>? restes,
  }) =>
      ListeCourses(
        lignes: lignes ?? this.lignes,
        libres: libres ?? this.libres,
        restes: restes ?? this.restes,
      );

  /// Quantité voulue d'un produit pour un gymnase, null si le produit n'est pas acheté.
  int? quantite(String gymnaseId, String produitId) {
    for (final l in lignes) {
      if (l.gymnaseId == gymnaseId && l.produitId == produitId) return l.quantite;
    }
    return null;
  }

  /// Remplace (ou ajoute) la ligne d'un produit ; [quantite] null la retire.
  ListeCourses avecQuantite(String gymnaseId, String produitId, int? quantite) {
    final autres = [
      for (final l in lignes)
        if (!(l.gymnaseId == gymnaseId && l.produitId == produitId)) l,
    ];
    return avec(lignes: [
      ...autres,
      if (quantite != null) LigneCourse(gymnaseId, produitId, quantite),
    ]);
  }
}

/// La liste de départ : pour chaque gymnase qui a des personnes, chaque produit
/// qui a une consommation, avec la quantité prévue (modifiable ensuite).
ListeCourses listeParDefaut({
  required List<ProduitEvenement> produits,
  required List<Gymnase> gymnases,
  required int jours,
}) {
  final lignes = <LigneCourse>[];
  for (final g in gymnases) {
    if (g.personnes <= 0) continue;
    for (final p in produits) {
      final conso = p.fiche.conso;
      if (conso == null || conso <= 0) continue;
      lignes.add(LigneCourse(
          g.id, p.id, quantitePrevue(personnes: g.personnes, jours: jours, conso: conso)));
    }
  }
  return ListeCourses(lignes: lignes);
}

/// Unité de base d'une unité d'ingrédient : g (g, kg), cl (cl, L), tranche, unite.
String uniteDeBase(String unite) => switch (unite) {
      'kg' || 'g' => 'g',
      'L' || 'cl' => 'cl',
      _ => unite,
    };

double versUniteDeBase(double quantite, String unite) => switch (unite) {
      'kg' => quantite * 1000,
      'L' => quantite * 100,
      _ => quantite,
    };

/// Un achat : ce qu'il faut acheter au total (tous gymnases), ingrédient ou produit.
class Achat {
  const Achat({
    required this.cle,
    required this.nom,
    required this.uniteBase,
    required this.besoin,
    required this.reste,
  });

  /// Reconnaît le même achat d'une recette à l'autre : nom sans casse ni accents,
  /// et unité de base (« gruyère » en g et « gruyère » en tranches restent séparés).
  /// Un produit acheté tel quel (au litre, à l'unité, à la part) a la clé « produit:id ».
  final String cle;
  final String nom;
  final String uniteBase;

  /// Besoin brut, et ce qu'il reste déjà, dans l'unité de base.
  final double besoin;
  final double reste;

  int get aAcheter => arrondiHaut(besoin - reste);
}

/// Les achats d'une liste : ingrédients additionnés d'une recette à l'autre,
/// litres pour les produits au litre, produits à l'unité ou à la part tels quels.
/// Triés par nom.
List<Achat> calculerAchats(List<ProduitEvenement> produits, ListeCourses liste) {
  final parId = {for (final p in produits) p.id: p};
  final besoins = <String, double>{};
  final noms = <String, String>{};
  final unites = <String, String>{};

  void ajouter(String cle, String nom, String uniteBase, double q) {
    besoins[cle] = (besoins[cle] ?? 0) + q;
    noms.putIfAbsent(cle, () => nom);
    unites[cle] = uniteBase;
  }

  // Dans l'ordre des produits du menu : le nom affiché d'un ingrédient partagé ne
  // dépend pas de l'ordre de saisie.
  final rang = {for (var i = 0; i < produits.length; i++) produits[i].id: i};
  final lignes = [...liste.lignes]
    ..sort((a, b) => (rang[a.produitId] ?? 0).compareTo(rang[b.produitId] ?? 0));
  for (final l in lignes) {
    final p = parId[l.produitId];
    if (p == null || l.quantite <= 0) continue;
    final fiche = p.fiche;
    switch (fiche.type) {
      case 'compose':
        for (final i in fiche.ingredients) {
          final base = uniteDeBase(i.unite);
          ajouter('${i.cle}|$base', i.nom.trim(), base,
              versUniteDeBase(i.quantite, i.unite) * l.quantite);
        }
      case 'litre':
        // Des verres vendus -> des litres à acheter (stockés en cl).
        final verres = fiche.verresParLitre ?? 0;
        if (verres > 0) {
          ajouter('produit:${p.id}', p.nom, 'cl', l.quantite / verres * 100);
        }
      default:
        ajouter('produit:${p.id}', p.nom, 'unite', l.quantite.toDouble());
    }
  }

  final achats = [
    for (final cle in besoins.keys)
      Achat(
        cle: cle,
        nom: noms[cle]!,
        uniteBase: unites[cle]!,
        besoin: besoins[cle]!,
        reste: liste.restes[cle] ?? 0,
      ),
  ];
  achats.sort((a, b) => cleIngredient(a.nom).compareTo(cleIngredient(b.nom)));
  return achats;
}

/// Produits à réapprovisionner, par produit : les gymnases où il est en stock bas,
/// épuisé ou vide (dans l'ordre des gymnases).
Map<String, List<String>> produitsSuggeres(
  Map<String, Map<String, EtatStock>> etats,
  List<Gymnase> gymnases,
) {
  final res = <String, List<String>>{};
  for (final g in gymnases) {
    for (final e in (etats[g.id] ?? const <String, EtatStock>{}).entries) {
      if (e.value == EtatStock.bas ||
          e.value == EtatStock.epuise ||
          e.value == EtatStock.vide) {
        res.putIfAbsent(e.key, () => []).add(g.nom);
      }
    }
  }
  return res;
}

String _groupes(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// 3,92 plutôt que 3.92, sans zéros inutiles.
String _decimal(double v) {
  var t = v.toStringAsFixed(2);
  if (t.contains('.')) {
    t = t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return t.replaceAll('.', ',');
}

/// « 1 120 tranches », « 3,92 kg », « 70 L », « 12 ».
String formaterQuantite(int n, String uniteBase) => switch (uniteBase) {
      'g' => n >= 1000 ? '${_decimal(n / 1000)} kg' : '${_groupes(n)} g',
      'cl' => n >= 100 ? '${_decimal(n / 100)} L' : '${_groupes(n)} cl',
      'tranche' => '${_groupes(n)} tranche${n > 1 ? 's' : ''}',
      _ => _groupes(n),
    };

/// Libellé de l'unité dans laquelle on saisit « ce qu'il reste ».
String libelleUniteReste(String uniteBase) => switch (uniteBase) {
      'unite' => 'unités',
      'tranche' => 'tranches',
      _ => uniteBase,
    };
