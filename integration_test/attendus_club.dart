import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/courses.dart' show arrondiHaut;
import 'package:le_comptoir/depot_caisses.dart';

// Attendus de la preuve 1 de la simulation V7 (mission « Calcul du club »).
// Quantité de chaque produit du menu du club, par gymnase et par jour, recalculée à part
// depuis le classeur d'origine (repas × % du groupe × part du produit ; jour 1 = bloc Samedi,
// jour 2 = bloc Dimanche, décision de Kinder du 12/11/2026), NON arrondie. Clés « Gymnase N|jour ».
// Un produit sans valeur un jour vaut 0. Aucun nom de personne.
const attendusClub = <String, Map<String, double>>{
  'Croque-monsieur': {
    'Gymnase 1|1': 33.32,
    'Gymnase 2|1': 39.48,
    'Gymnase 1|2': 36.4,
    'Gymnase 2|2': 33.88,
  },
  'Croque végé': {
    'Gymnase 1|1': 20.825,
    'Gymnase 2|1': 24.675,
    'Gymnase 1|2': 31.2,
    'Gymnase 2|2': 29.04,
  },
  'Croque tartiflette': {
    'Gymnase 1|1': 29.155,
    'Gymnase 2|1': 34.545,
    'Gymnase 1|2': 36.4,
    'Gymnase 2|2': 33.88,
  },
  'Crêpe sucre': {
    'Gymnase 1|1': 32.725,
    'Gymnase 2|1': 38.775,
    'Gymnase 1|2': 32.5,
    'Gymnase 2|2': 30.25,
  },
  'Crêpe Nutella': {
    'Gymnase 1|1': 65.45,
    'Gymnase 2|1': 77.55,
    'Gymnase 1|2': 58.5,
    'Gymnase 2|2': 54.45,
  },
  'Croque Monsieur Chocolat': {
    'Gymnase 1|1': 32.725,
    'Gymnase 2|1': 38.775,
    'Gymnase 1|2': 39.0,
    'Gymnase 2|2': 36.3,
  },
  'Mars': {
    'Gymnase 1|1': 3.57,
    'Gymnase 2|1': 4.23,
    'Gymnase 1|2': 4.875,
    'Gymnase 2|2': 4.5375,
  },
  'Twix': {
    'Gymnase 1|1': 3.57,
    'Gymnase 2|1': 4.23,
    'Gymnase 1|2': 4.875,
    'Gymnase 2|2': 4.5375,
  },
  'Barre de céréales chocolat': {
    'Gymnase 1|1': 8.33,
    'Gymnase 2|1': 9.87,
    'Gymnase 1|2': 11.375,
    'Gymnase 2|2': 10.5875,
  },
  'Barre de céréales fruit': {
    'Gymnase 1|1': 8.33,
    'Gymnase 2|1': 9.87,
    'Gymnase 1|2': 11.375,
    'Gymnase 2|2': 10.5875,
  },
  'Coca': {
    'Gymnase 1|1': 80.325,
    'Gymnase 2|1': 95.175,
    'Gymnase 1|2': 87.75,
    'Gymnase 2|2': 81.675,
  },
  'Ice Tea': {
    'Gymnase 1|1': 35.7,
    'Gymnase 2|1': 42.3,
    'Gymnase 1|2': 39.0,
    'Gymnase 2|2': 36.3,
  },
  'Orangina': {
    'Gymnase 1|1': 17.85,
    'Gymnase 2|1': 21.15,
    'Gymnase 1|2': 19.5,
    'Gymnase 2|2': 18.15,
  },
  'Oasis': {
    'Gymnase 1|1': 44.625,
    'Gymnase 2|1': 52.875,
    'Gymnase 1|2': 48.75,
    'Gymnase 2|2': 45.375,
  },
  'Bière': {
    'Gymnase 1|1': 35.7,
    'Gymnase 2|1': 42.3,
  },
  'Thé': {
    'Gymnase 1|1': 39.27,
    'Gymnase 2|1': 46.53,
    'Gymnase 1|2': 48.75,
    'Gymnase 2|2': 45.375,
  },
  'Infusion': {
    'Gymnase 1|1': 13.09,
    'Gymnase 2|1': 15.51,
    'Gymnase 1|2': 9.75,
    'Gymnase 2|2': 9.075,
  },
  'Café': {
    'Gymnase 1|1': 78.54,
    'Gymnase 2|1': 93.06,
    'Gymnase 1|2': 136.5,
    'Gymnase 2|2': 127.05,
  },
};

/// Un écart de la preuve 1 : produit, gymnase, jour (0 = total des jours), attendu, vu.
class EcartClub {
  const EcartClub(this.produit, this.gymnase, this.jour, this.attendu, this.vu);
  final String produit;
  final String gymnase;
  final int jour;
  final double attendu;
  final double vu;

  @override
  String toString() =>
      '$produit | $gymnase | ${jour == 0 ? 'total' : 'jour $jour'} | attendu $attendu | vu $vu';
}

/// Valeur attendue (non arrondie) d'un produit pour un gymnase et un jour ; 0 si absente.
double attenduClub(String produit, String gymnase, int jour) =>
    attendusClub[produit]?['$gymnase|$jour'] ?? 0.0;

const gymnasesClub = ['Gymnase 1', 'Gymnase 2'];
const joursClub = [1, 2];

/// Arrondi à l'unité supérieure, le même que celui de l'application.
int arrondiClub(double x) => arrondiHaut(x);

/// Preuve 1 : compare, produit par produit, gymnase par gymnase et jour par jour, ce que
/// l'application calcule ([calcul], relu depuis la base) aux attendus du classeur d'origine.
/// Chaque jour est comparé arrondi à l'unité supérieure ET non arrondi (à 1e-6), puis le total
/// des jours de chaque gymnase (un seul arrondi, comme l'application). Liste vide = preuve verte.
List<EcartClub> comparerAttendus({
  required CalculClub calcul,
  required Map<String, String> idProduit,
  required Map<String, String> idGymnase,
}) {
  final ecarts = <EcartClub>[];
  for (final nom in attendusClub.keys) {
    final p = idProduit[nom];
    for (final g in gymnasesClub) {
      final gid = idGymnase[g];
      var sommeAttendue = 0.0;
      for (final j in joursClub) {
        final a = attenduClub(nom, g, j);
        sommeAttendue += a;
        final brut = (p == null || gid == null) ? null : quantiteClubJour(calcul, gid, p, j);
        if (brut == null) {
          ecarts.add(EcartClub(nom, g, j, a, -1));
          continue;
        }
        if (arrondiClub(a) != arrondiClub(brut) || (a - brut).abs() > 1e-6) {
          ecarts.add(EcartClub(nom, g, j, a, brut));
        }
      }
      final total = (p == null || gid == null) ? null : quantiteClub(calcul, gid, p);
      if (total == null || total != arrondiClub(sommeAttendue)) {
        ecarts.add(EcartClub(nom, g, 0, arrondiClub(sommeAttendue).toDouble(),
            (total ?? -1).toDouble()));
      }
    }
  }
  return ecarts;
}

/// Une vente émise par la simulation (preuve 3), notée à part pour la preuve 4.
class VenteSimulee {
  const VenteSimulee({
    required this.caisseId,
    required this.gymnaseId,
    required this.date,
    required this.mode,
    required this.lignes,
    this.annulee = false,
  });

  final String caisseId;
  final String gymnaseId;

  /// « AAAA-MM-JJ » (jour de la vente).
  final String date;
  final String mode;
  final List<LigneVente> lignes;
  final bool annulee;

  int get totalCentimes =>
      lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite);

  VenteSimulee annuler() => VenteSimulee(
      caisseId: caisseId,
      gymnaseId: gymnaseId,
      date: date,
      mode: mode,
      lignes: lignes,
      annulee: true);
}

/// Sommes des ventes simulées non annulées, faites à part (sans passer par le Bilan).
class SommesVentes {
  SommesVentes(Iterable<VenteSimulee> ventes) {
    for (final v in ventes) {
      if (v.annulee) {
        nbAnnulees++;
        continue;
      }
      nbVentes++;
      totalCentimes += v.totalCentimes;
      parMode[v.mode] = (parMode[v.mode] ?? 0) + v.totalCentimes;
      final c = parCaisse.putIfAbsent(v.caisseId, () => [0, 0]);
      c[0]++;
      c[1] += v.totalCentimes;
      final j = parJour.putIfAbsent(v.date, () => [0, 0]);
      j[0]++;
      j[1] += v.totalCentimes;
      for (final l in v.lignes) {
        final p = parProduit.putIfAbsent(l.produitId, () => [0, 0]);
        p[0] += l.quantite;
        p[1] += l.quantite * l.prixCentimes;
      }
    }
  }

  int nbVentes = 0;
  int nbAnnulees = 0;
  int totalCentimes = 0;
  final Map<String, int> parMode = {};

  /// caisse -> [nombre de ventes, total].
  final Map<String, List<int>> parCaisse = {};

  /// jour -> [nombre de ventes, total].
  final Map<String, List<int>> parJour = {};

  /// produit -> [quantité, montant].
  final Map<String, List<int>> parProduit = {};
}

/// Preuve 4 : compare le Bilan de l'application aux [sommes] faites à part (par produit, mode,
/// caisse, jour, total, annulations). Liste vide = preuve verte.
List<String> comparerBilan(SommesVentes s, Bilan b) {
  final r = <String>[];
  void egal(String quoi, Object? attendu, Object? vu) {
    if (attendu != vu) r.add('$quoi : attendu $attendu, vu $vu');
  }

  egal('total', s.totalCentimes, b.totalCentimes);
  egal('nombre de ventes', s.nbVentes, b.nbVentes);
  egal('annulées', s.nbAnnulees, b.nbAnnulees);
  for (final m in {...s.parMode.keys, ...b.parMode.keys}) {
    egal('mode $m', s.parMode[m] ?? 0, b.parMode[m] ?? 0);
  }
  final caisses = {for (final c in b.caisses) c.id: c};
  for (final id in {...s.parCaisse.keys, ...caisses.keys}) {
    egal('caisse $id (ventes)', s.parCaisse[id]?[0] ?? 0, caisses[id]?.nbVentes ?? 0);
    egal('caisse $id (total)', s.parCaisse[id]?[1] ?? 0, caisses[id]?.totalCentimes ?? 0);
  }
  final jours = {for (final j in b.jours) j.jour: j};
  for (final d in {...s.parJour.keys, ...jours.keys}) {
    egal('jour $d (ventes)', s.parJour[d]?[0] ?? 0, jours[d]?.nbVentes ?? 0);
    egal('jour $d (total)', s.parJour[d]?[1] ?? 0, jours[d]?.totalCentimes ?? 0);
  }
  final produits = {for (final p in b.produits) p.id: p};
  for (final id in {...s.parProduit.keys, ...produits.keys}) {
    egal('produit $id (quantité)', s.parProduit[id]?[0] ?? 0, produits[id]?.quantite ?? 0);
    egal('produit $id (montant)', s.parProduit[id]?[1] ?? 0, produits[id]?.montantCentimes ?? 0);
  }
  return r;
}
