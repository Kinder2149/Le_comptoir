import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'depot_menus.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'ticket.dart';

// Courses d'un événement, préparation (chantier Stock et courses, étape 5).
// Logique pure : aucune lecture de base ici, tout se calcule à partir des produits
// de l'événement, des réglages (jours, personnes) et de la saisie de la gestion.

/// Durée à couvrir, en jours, tant que la gestion ne l'a pas réglée : une
/// demi-journée vaut 0,5, un jour complet 1, « plus » un entier de 2 à [joursMax].
const joursParDefaut = 2.0;
const demiJournee = 0.5;
const joursMax = 30;
const personnesMax = 1000;

/// Arrondi à l'entier supérieur, sans que 3920,0000000001 devienne 3921.
int arrondiHaut(double x) => x <= 1e-6 ? 0 : (x - 1e-6).ceil();

/// Quantité de produits finaux prévue : personnes × jours × consommation.
int quantitePrevue(
        {required int personnes, required double jours, required double conso}) =>
    arrondiHaut(personnes * jours * conso);

/// Quantité à acheter pour un produit dans un gymnase : la quantité prévue moins
/// le stock actuel quand il est suivi, jamais en dessous de zéro (décision 46).
int quantiteAPrevoir({
  required int personnes,
  required double jours,
  required double conso,
  int? stock,
}) {
  final reste = quantitePrevue(personnes: personnes, jours: jours, conso: conso) -
      (stock != null && stock > 0 ? stock : 0);
  return reste > 0 ? reste : 0;
}

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
  const LigneLibre(this.nom, this.quantite, [this.rayon = 'autre']);

  final String nom;
  final double quantite;

  /// Rayon des courses (voir [rayonsCourses]).
  final String rayon;

  Map<String, dynamic> versMap() =>
      {'nom': nom, 'quantite': quantite, if (rayon != 'autre') 'rayon': rayon};
}

/// Ce que la validation ajoute au stock d'un gymnase pour un produit.
class Rendement {
  const Rendement(this.gymnaseId, this.produitId, this.quantite);

  final String gymnaseId;
  final String produitId;
  final int quantite;

  Map<String, dynamic> versMap() =>
      {'gymnaseId': gymnaseId, 'produitId': produitId, 'quantite': quantite};
}

/// Ce que la gestion a saisi à la validation, conservé avec la liste.
class ValidationCourses {
  const ValidationCourses({
    required this.achetes,
    required this.rendements,
    required this.coutCentimes,
    this.valideeLe,
  });

  /// Quantités réellement achetées, par clé d'achat, en unité de base.
  final Map<String, double> achetes;
  final List<Rendement> rendements;
  final int coutCentimes;
  final DateTime? valideeLe;
}

/// Ce que les séries de courses déjà validées ont apporté (mission C1) : une liste
/// validée est figée, puis la gestion ouvre une nouvelle série ; le coût et les
/// ajouts de stock des séries précédentes sont gardés ici, jamais rejoués.
class CumulCourses {
  const CumulCourses({
    this.series = 0,
    this.coutCentimes = 0,
    this.ajouts = const {},
  });

  /// Nombre de séries déjà validées avant la série en cours.
  final int series;
  final int coutCentimes;

  /// Ajouts de stock par produit (tous gymnases), séries précédentes cumulées.
  final Map<String, int> ajouts;

  /// Le cumul une fois la série [v] validée.
  CumulCourses avecValidation(ValidationCourses v) {
    final somme = {...ajouts};
    for (final r in v.rendements) {
      somme[r.produitId] = (somme[r.produitId] ?? 0) + r.quantite;
    }
    return CumulCourses(
      series: series + 1,
      coutCentimes: coutCentimes + v.coutCentimes,
      ajouts: somme,
    );
  }

  factory CumulCourses.depuis(Map<String, dynamic> d) => CumulCourses(
        series: (d['cumulSeries'] as num?)?.toInt() ?? 0,
        coutCentimes: (d['cumulCout'] as num?)?.toInt() ?? 0,
        ajouts: {
          for (final a in (d['cumulAjouts'] as List?) ?? const [])
            a['produitId'] as String: (a['quantite'] as num).toInt(),
        },
      );

  /// Rien n'est écrit tant qu'aucune série n'est validée (documents d'avant C1).
  Map<String, dynamic> versMap() => series == 0
      ? const {}
      : {
          'cumulSeries': series,
          'cumulCout': coutCentimes,
          'cumulAjouts': [
            for (final e in ajouts.entries)
              {'produitId': e.key, 'quantite': e.value},
          ],
        };
}

/// La liste de courses d'un événement : en préparation, puis validée (figée).
/// Après une validation, une nouvelle série repart d'une liste vide ([precedent]).
class ListeCourses {
  const ListeCourses({
    this.lignes = const [],
    this.libres = const [],
    this.restes = const {},
    this.validation,
    this.precedent = const CumulCourses(),
    this.articles = const [],
    this.coches = const {},
  });

  /// Clés des articles affichés (voir [clesArticles]) : les règles n'acceptent une
  /// case que pour l'une d'elles. Écrites par l'application à chaque enregistrement.
  final List<String> articles;

  /// Cases cochées en magasin (décision 65) : clés d'articles. Partagées par tous les
  /// téléphones de la gestion ; elles ne changent ni le stock ni le coût.
  final Set<String> coches;

  /// Séries précédentes déjà validées.
  final CumulCourses precedent;

  /// Séries validées, la série en cours comprise si elle l'est.
  int get seriesValidees => precedent.series + (validee ? 1 : 0);

  /// Coût de toutes les séries validées.
  int get coutTotalCentimes =>
      precedent.coutCentimes + (validation?.coutCentimes ?? 0);

  /// Ajouts de stock de toutes les séries validées, par produit.
  Map<String, int> get ajoutsTotaux => validation == null
      ? precedent.ajouts
      : precedent.avecValidation(validation!).ajouts;

  /// La liste vide d'une nouvelle série, une fois celle-ci validée.
  ListeCourses nouvelleSerie() => ListeCourses(
        precedent: validation == null
            ? precedent
            : precedent.avecValidation(validation!),
      );

  /// Renseignée quand la liste est validée : elle ne bouge plus.
  final ValidationCourses? validation;
  bool get validee => validation != null;

  /// Produits finaux voulus, par gymnase. Une ligne absente = produit non acheté.
  final List<LigneCourse> lignes;
  final List<LigneLibre> libres;

  /// « Ce qu'il reste », par clé d'achat (voir [Achat.cle]), dans l'unité de base
  /// de l'achat (g, cl, tranche, unité).
  final Map<String, double> restes;

  factory ListeCourses.depuis(Map<String, dynamic> d) => ListeCourses(
        precedent: CumulCourses.depuis(d),
        validation: d['statut'] != 'validee'
            ? null
            : ValidationCourses(
                achetes: {
                  for (final a in (d['achats'] as List?) ?? const [])
                    a['cle'] as String: (a['quantite'] as num).toDouble(),
                },
                rendements: [
                  for (final r in (d['rendements'] as List?) ?? const [])
                    Rendement(r['gymnaseId'] as String, r['produitId'] as String,
                        (r['quantite'] as num).toInt()),
                ],
                coutCentimes: (d['coutCentimes'] as num?)?.toInt() ?? 0,
                valideeLe: (d['valideeLe'] as Timestamp?)?.toDate(),
              ),
        lignes: [
          for (final l in (d['lignes'] as List?) ?? const [])
            LigneCourse(l['gymnaseId'] as String, l['produitId'] as String,
                (l['quantite'] as num).toInt()),
        ],
        libres: [
          for (final l in (d['libres'] as List?) ?? const [])
            LigneLibre(l['nom'] as String, (l['quantite'] as num).toDouble(),
                rayonDepuis(l['rayon'])),
        ],
        restes: {
          for (final r in (d['restes'] as List?) ?? const [])
            r['cle'] as String: (r['quantite'] as num).toDouble(),
        },
        articles: [
          for (final a in (d['articles'] as List?) ?? const []) a as String,
        ],
        coches: {
          for (final c in ((d['coches'] as Map?) ?? const {}).keys) c as String,
        },
      );

  Map<String, dynamic> versMap() => {
        'statut': 'preparation',
        ...precedent.versMap(),
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
    List<String>? articles,
    Set<String>? coches,
  }) =>
      ListeCourses(
        lignes: lignes ?? this.lignes,
        libres: libres ?? this.libres,
        restes: restes ?? this.restes,
        precedent: precedent,
        articles: articles ?? this.articles,
        coches: coches ?? this.coches,
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
/// acheté par l'association qui a une consommation, avec la quantité prévue
/// (modifiable ensuite). Un produit « apporté » par les bénévoles n'est pas
/// pré-coché (décision 45) ; la gestion peut le cocher à la main.
ListeCourses listeParDefaut({
  required List<ProduitEvenement> produits,
  required List<Gymnase> gymnases,
  required double jours,
  Map<String, Map<String, int>> stocks = const {},
}) {
  final lignes = <LigneCourse>[];
  for (final g in gymnases) {
    if (g.personnes <= 0) continue;
    for (final p in produits) {
      if (p.fiche.provenance == 'apporte') continue;
      final conso = p.fiche.conso;
      if (conso == null || conso <= 0) continue;
      final quantite = quantiteAPrevoir(
          personnes: g.personnes,
          jours: jours,
          conso: conso,
          stock: stocks[g.id]?[p.id]);
      // Le stock couvre déjà le besoin : rien à acheter, la ligne n'est pas cochée.
      if (quantite <= 0) continue;
      lignes.add(LigneCourse(g.id, p.id, quantite));
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
    this.rayon = 'autre',
  });

  /// Rayon où se trouve l'achat (décision 64) : celui de l'ingrédient (premier trouvé
  /// dans l'ordre des produits) ou celui du produit acheté tel quel.
  final String rayon;

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
  final rayons = <String, String>{};

  void ajouter(String cle, String nom, String uniteBase, double q, String rayon) {
    besoins[cle] = (besoins[cle] ?? 0) + q;
    noms.putIfAbsent(cle, () => nom);
    rayons.putIfAbsent(cle, () => rayon);
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
              versUniteDeBase(i.quantite, i.unite) * l.quantite, i.rayon);
        }
      case 'litre':
        // Des verres vendus -> des litres à acheter (stockés en cl).
        final verres = fiche.verresParLitre ?? 0;
        if (verres > 0) {
          ajouter('produit:${p.id}', p.nom, 'cl', l.quantite / verres * 100,
              fiche.rayon);
        }
      case 'part' when (fiche.partsParEntier ?? 0) > 0:
        // Des parts vendues -> des gâteaux entiers à acheter.
        ajouter('produit:${p.id}', p.nom, 'gateau',
            l.quantite / fiche.partsParEntier!, fiche.rayon);
      default:
        ajouter('produit:${p.id}', p.nom, 'unite', l.quantite.toDouble(),
            fiche.rayon);
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
        rayon: rayons[cle]!,
      ),
  ];
  achats.sort((a, b) => cleIngredient(a.nom).compareTo(cleIngredient(b.nom)));
  return achats;
}

/// Le texte de la liste « À acheter » à partager (mission C1) : une ligne par achat,
/// puis les lignes libres. Reprend les quantités affichées à l'écran.
/// Le texte est rangé par rayons (décision 64), dans l'ordre fixe des rayons ; un rayon
/// sans rien à acheter n'apparaît pas.
String texteListeCourses(String titre, List<Achat> achats, List<LigneLibre> libres) {
  final b = StringBuffer('$titre\n');
  final aAcheter = [for (final a in achats) if (a.aAcheter > 0) a];
  if (aAcheter.isEmpty && libres.isEmpty) {
    b.writeln('\nRien à acheter');
    return b.toString();
  }
  for (final r in rayonsCourses) {
    final lignes = [
      for (final a in aAcheter)
        if (a.rayon == r) '- ${a.nom} : ${formaterQuantite(a.aAcheter, a.uniteBase)}',
      for (final l in libres)
        if (rayonDepuis(l.rayon) == r)
          '- ${l.nom} × ${l.quantite == l.quantite.roundToDouble() ? l.quantite.toInt().toString() : _decimal(l.quantite)}',
    ];
    if (lignes.isEmpty) continue;
    b.writeln('\n${libellesRayons[r]}');
    lignes.forEach(b.writeln);
  }
  return b.toString();
}

/// Clé d'un achat comme article cochable (décision 65) : « p:PRODUIT » pour un
/// produit acheté tel quel, « i:INGREDIENT|UNITE » pour un ingrédient.
String cleArticleAchat(Achat a) => a.cle.startsWith('produit:')
    ? 'p:${a.cle.substring('produit:'.length)}'
    : 'i:${a.cle}';

/// Clés de tous les articles d'une liste, dans l'ordre affiché : d'abord les achats
/// (même ordre que [calculerAchats]), puis les lignes libres « l:NOM » (« #2 » pour
/// un deuxième article de même nom). Stables tant que la liste ne change pas.
List<String> clesArticles(List<Achat> achats, List<LigneLibre> libres) {
  final res = [for (final a in achats) cleArticleAchat(a)];
  final vus = <String, int>{};
  for (final l in libres) {
    final base = 'l:${l.nom.trim()}';
    final n = (vus[base] = (vus[base] ?? 0) + 1);
    res.add(n == 1 ? base : '$base#$n');
  }
  return res;
}

/// Pour chaque ingrédient (clé d'article), les recettes qui l'utilisent et dont une
/// ligne est prévue : « pour les croques » sous « Pain de mie ».
Map<String, List<String>> usagesAchats(
    List<ProduitEvenement> produits, ListeCourses liste) {
  final res = <String, List<String>>{};
  for (final p in produits) {
    if (p.fiche.type != 'compose') continue;
    if (!liste.lignes.any((l) => l.produitId == p.id && l.quantite > 0)) continue;
    for (final i in p.fiche.ingredients) {
      final cle = 'i:${i.cle}|${uniteDeBase(i.unite)}';
      final noms = res.putIfAbsent(cle, () => []);
      if (!noms.contains(p.nom)) noms.add(p.nom);
    }
  }
  return res;
}

/// Rendement d'un produit : ce que les achats permettent d'ajouter au stock.
class RendementProduit {
  const RendementProduit({
    required this.produitId,
    required this.total,
    required this.parGymnase,
    this.limitant,
  });

  final String produitId;
  final int total;

  /// Quantité ajoutée dans chaque gymnase (gymnase -> quantité), dans l'ordre des lignes.
  final Map<String, int> parGymnase;

  /// Nom de l'ingrédient qui limite (achat inférieur au besoin), s'il y en a un.
  final String? limitant;
}

/// Calcul inverse (décision 38) : le stock gagne ce que permet l'ingrédient LIMITANT.
/// [achetes] : quantités réellement achetées par clé d'achat, en unité de base ;
/// une clé absente vaut « ce qui était proposé ». Pour chaque ingrédient, le rapport
/// (acheté + reste) / (proposé + reste) dit quelle part du besoin est couverte ;
/// un produit gagne sa quantité prévue × le plus petit de ses rapports (un ingrédient
/// partagé se répartit donc proportionnellement entre toutes les lignes qui l'utilisent).
/// Arrondi vers le bas pour le total du produit, réparti entre gymnases au plus grand
/// reste : aucune unité perdue entre gymnases.
List<RendementProduit> calculerRendements(
  List<ProduitEvenement> produits,
  ListeCourses liste,
  Map<String, double> achetes,
) {
  final achats = {for (final a in calculerAchats(produits, liste)) a.cle: a};

  double? rapport(String cle) {
    final a = achats[cle];
    if (a == null) return null;
    final propose = a.aAcheter + a.reste;
    if (propose <= 0) return null; // rien n'était nécessaire
    return ((achetes[cle] ?? a.aAcheter.toDouble()) + a.reste) / propose;
  }

  final res = <RendementProduit>[];
  for (final p in produits) {
    final lignes = [
      for (final l in liste.lignes)
        if (l.produitId == p.id && l.quantite > 0) l,
    ];
    if (lignes.isEmpty) continue;
    final cles = p.fiche.type == 'compose'
        ? [for (final i in p.fiche.ingredients) '${i.cle}|${uniteDeBase(i.unite)}']
        : ['produit:${p.id}'];
    double? plusPetit;
    String? limitant;
    for (final cle in cles) {
      final r = rapport(cle);
      if (r != null && (plusPetit == null || r < plusPetit)) {
        plusPetit = r;
        limitant = achats[cle]!.nom;
      }
    }
    var facteur = plusPetit ?? 1.0;
    if (facteur >= 1 - 1e-9) limitant = null;
    final parts = p.fiche.type == 'part' ? (p.fiche.partsParEntier ?? 0) : 0;
    if (parts > 0 && achats['produit:${p.id}'] != null) {
      // Gâteaux entiers : le stock gagne les gâteaux achetés × leurs parts,
      // répartis entre gymnases au prorata des parts prévues.
      final a = achats['produit:${p.id}']!;
      final prevu = lignes.fold<int>(0, (s, l) => s + l.quantite);
      final gateaux = achetes['produit:${p.id}'] ?? a.aAcheter.toDouble();
      facteur = prevu > 0 ? gateaux * parts / prevu : 1.0;
      limitant = null;
    }
    final exacts = [for (final l in lignes) l.quantite * facteur];
    final bases = [for (final x in exacts) (x + 1e-6).floor()];
    final total = (exacts.fold<double>(0, (a, b) => a + b) + 1e-6).floor();
    var reste = total - bases.fold<int>(0, (a, b) => a + b);
    final ordre = List.generate(lignes.length, (i) => i)
      ..sort((a, b) => (exacts[b] - bases[b]).compareTo(exacts[a] - bases[a]));
    for (final i in ordre) {
      if (reste <= 0) break;
      bases[i]++;
      reste--;
    }
    res.add(RendementProduit(
      produitId: p.id,
      total: bases.fold<int>(0, (a, b) => a + b),
      parGymnase: {
        for (var i = 0; i < lignes.length; i++) lignes[i].gymnaseId: bases[i],
      },
      limitant: limitant,
    ));
  }
  return res;
}

/// Unité dans laquelle on saisit un achat : kg et L quand la quantité s'y prête.
({String libelle, double facteur}) uniteSaisie(Achat a) => switch (a.uniteBase) {
      'g' when a.aAcheter >= 1000 => (libelle: 'kg', facteur: 1000.0),
      'cl' when a.aAcheter >= 100 => (libelle: 'L', facteur: 100.0),
      'unite' => (libelle: '', facteur: 1.0),
      final u => (libelle: libelleUniteReste(u), facteur: 1.0),
    };

/// « 412,50 » -> 41250 ; null si le texte n'est pas un montant valide (0 à 1 000 000 €).
int? centimesDepuisTexte(String texte) {
  final t = texte.trim().replaceAll(',', '.').replaceAll(' ', '');
  final v = double.tryParse(t);
  if (v == null || v < 0 || v > 1000000) return null;
  return (v * 100).round();
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
      'gateau' => '${_groupes(n)} gâteau${n > 1 ? 'x' : ''}',
      _ => _groupes(n),
    };

/// Libellé de l'unité dans laquelle on saisit « ce qu'il reste ».
String libelleUniteReste(String uniteBase) => switch (uniteBase) {
      'unite' => 'unités',
      'tranche' => 'tranches',
      'gateau' => 'gâteaux',
      _ => uniteBase,
    };
