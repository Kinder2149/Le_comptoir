import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'evenement.dart';
import 'gymnase.dart';
import 'ticket.dart';

/// Une ligne d'une vente : le produit tel qu'il était vendu (nom et prix figés).
class LigneVente {
  const LigneVente(this.produitId, this.nom, this.prixCentimes, this.quantite);

  final String produitId;
  final String nom;
  final int prixCentimes;
  final int quantite;

  Map<String, dynamic> versDonnees() => {
        'produitId': produitId,
        'nom': nom,
        'prixCentimes': prixCentimes,
        'quantite': quantite,
      };
}

class Vente {
  const Vente({
    required this.id,
    required this.lignes,
    required this.totalCentimes,
    required this.mode,
    required this.creeLe,
    required this.enAttente,
    this.annulee = false,
    this.annuleeParPrenom,
    this.annuleeLe,
    this.corrigeDe,
  });

  final String id;
  final List<LigneVente> lignes;
  final int totalCentimes;
  final String mode;
  final DateTime creeLe;

  /// Enregistrée sur ce téléphone, pas encore confirmée par le serveur.
  final bool enAttente;

  /// Annulation tracée : qui et quand. Une vente annulée reste dans la liste.
  final bool annulee;
  final String? annuleeParPrenom;
  final DateTime? annuleeLe;

  /// Si cette vente en remplace une autre (annulée), l'identifiant de celle-ci.
  final String? corrigeDe;
}

/// Résultat d'une correction : la vente annulée et ses lignes, à ressaisir.
class Correction {
  const Correction(this.venteId, this.lignes);

  final String venteId;
  final List<LigneVente> lignes;
}

/// Récapitulatif d'une caisse : ce que le bénévole compte et remet.
/// Seules les ventes non annulées comptent.
class RecapCaisse {
  const RecapCaisse({
    required this.nbVentes,
    required this.nbAnnulees,
    required this.totalCentimes,
    required this.parMode,
  });

  factory RecapCaisse.depuis(Iterable<Vente> ventes) {
    var nb = 0;
    var annulees = 0;
    var total = 0;
    final parMode = <String, int>{};
    for (final v in ventes) {
      if (v.annulee) {
        annulees++;
        continue;
      }
      nb++;
      total += v.totalCentimes;
      parMode[v.mode] = (parMode[v.mode] ?? 0) + v.totalCentimes;
    }
    return RecapCaisse(
        nbVentes: nb,
        nbAnnulees: annulees,
        totalCentimes: total,
        parMode: parMode);
  }

  final int nbVentes;
  final int nbAnnulees;
  final int totalCentimes;

  /// Total en centimes pour chaque mode de paiement utilisé.
  final Map<String, int> parMode;

  /// Montant d'un mode (0 s'il n'a pas servi).
  int pour(String mode) => parMode[mode] ?? 0;

  Map<String, dynamic> versDonnees() => {
        'nbVentes': nbVentes,
        'nbAnnulees': nbAnnulees,
        'totalCentimes': totalCentimes,
        'parMode': parMode,
      };
}

/// État d'une caisse. [recap] n'existe que si elle est clôturée.
class Caisse {
  const Caisse({
    required this.uid,
    required this.gymnaseId,
    required this.prenom,
    required this.statut,
    this.ouverteLe,
    this.rouverteLe,
    this.clotureLe,
    this.recap,
  });

  /// Le membre à qui appartient la caisse, et le gymnase où elle est ouverte.
  final String uid;
  final String gymnaseId;

  /// Identifiant du document : une caisse par (membre, gymnase).
  String get id => idCaisse(uid, gymnaseId);

  final String prenom;
  final String statut; // 'ouverte' | 'cloturee'
  final DateTime? ouverteLe;
  final DateTime? rouverteLe;
  final DateTime? clotureLe;
  final RecapCaisse? recap;

  bool get cloturee => statut == 'cloturee';
}

/// Au-delà de ce délai sans activité, une caisse ouverte est signalée
/// « silencieuse » à la gestion.
const seuilSilence = Duration(minutes: 60);

/// Une caisse vue par la gestion : son état et ses ventes.
class ResumeCaisse {
  const ResumeCaisse(this.caisse, this.ventes);

  final Caisse caisse;
  final List<Vente> ventes;

  RecapCaisse get recap => RecapCaisse.depuis(ventes);

  /// Dernière vente (ou annulation), sinon ouverture ou réouverture de la caisse.
  DateTime? get derniereActivite {
    DateTime? plusRecent;
    void voir(DateTime? d) {
      if (d != null && (plusRecent == null || d.isAfter(plusRecent!))) {
        plusRecent = d;
      }
    }

    for (final v in ventes) {
      voir(v.creeLe);
      voir(v.annuleeLe);
    }
    voir(caisse.ouverteLe);
    voir(caisse.rouverteLe);
    return plusRecent;
  }

  /// Dernière vente seule (null s'il n'y en a aucune).
  DateTime? get derniereVente {
    DateTime? plusRecent;
    for (final v in ventes) {
      if (plusRecent == null || v.creeLe.isAfter(plusRecent)) {
        plusRecent = v.creeLe;
      }
    }
    return plusRecent;
  }

  /// Caisse ouverte sans activité depuis [seuil] (60 min par défaut).
  bool silencieuse(DateTime maintenant, {Duration seuil = seuilSilence}) {
    final d = derniereActivite;
    return !caisse.cloturee &&
        d != null &&
        maintenant.difference(d) >= seuil;
  }
}

/// Quantité vendue d'un produit sur tout l'événement (ventes non annulées).
class QuantiteProduit {
  const QuantiteProduit(this.nom, this.quantite, this.montantCentimes);

  final String nom;
  final int quantite;
  final int montantCentimes;
}

/// Vue d'ensemble d'un événement pour la gestion.
class TableauDeBord {
  const TableauDeBord({
    required this.caisses,
    required this.nbVentes,
    required this.nbAnnulees,
    required this.totalCentimes,
    required this.parProduit,
    required this.parMode,
  });

  factory TableauDeBord.depuis(List<ResumeCaisse> caisses) {
    var nb = 0;
    var annulees = 0;
    var total = 0;
    final parMode = <String, int>{};
    final quantites = <String, int>{};
    final montants = <String, int>{};
    final noms = <String, String>{};
    for (final c in caisses) {
      for (final v in c.ventes) {
        if (v.annulee) {
          annulees++;
          continue;
        }
        nb++;
        total += v.totalCentimes;
        parMode[v.mode] = (parMode[v.mode] ?? 0) + v.totalCentimes;
        for (final l in v.lignes) {
          noms[l.produitId] = l.nom;
          quantites[l.produitId] = (quantites[l.produitId] ?? 0) + l.quantite;
          montants[l.produitId] =
              (montants[l.produitId] ?? 0) + l.quantite * l.prixCentimes;
        }
      }
    }
    return TableauDeBord(
      caisses: caisses,
      nbVentes: nb,
      nbAnnulees: annulees,
      totalCentimes: total,
      parMode: parMode,
      parProduit: {
        for (final id in quantites.keys)
          id: QuantiteProduit(noms[id]!, quantites[id]!, montants[id]!),
      },
    );
  }

  final List<ResumeCaisse> caisses;
  final int nbVentes;
  final int nbAnnulees;
  final int totalCentimes;
  final Map<String, int> parMode;

  /// Ce tableau restreint au gymnase [gymnaseId] (la vue distincte), ou lui-même
  /// pour la vue commune (null).
  TableauDeBord pour(String? gymnaseId) => gymnaseId == null
      ? this
      : TableauDeBord.depuis([
          for (final r in caisses)
            if (r.caisse.gymnaseId == gymnaseId) r,
        ]);

  /// Par identifiant de produit de l'événement.
  final Map<String, QuantiteProduit> parProduit;

  int vendus(String produitId) => parProduit[produitId]?.quantite ?? 0;
}

/// Une ligne du bilan par produit.
class LigneProduitBilan {
  const LigneProduitBilan(
      this.id, this.nom, this.quantite, this.montantCentimes, this.stock,
      {this.detailStock = const {}});

  final String id;
  final String nom;
  final int quantite;
  final int montantCentimes;

  /// Stock restant (null = pas de suivi). En vue commune : le total des gymnases.
  final int? stock;

  /// En vue commune : le stock de chaque gymnase qui suit ce produit
  /// (identifiant du gymnase -> quantité). Vide en vue distincte.
  final Map<String, int> detailStock;
}

class JourBilan {
  const JourBilan(this.jour, this.nbVentes, this.totalCentimes);

  /// « AAAA-MM-JJ ».
  final String jour;
  final int nbVentes;
  final int totalCentimes;
}

/// Tranche d'une heure : [heure] h – [heure]+1 h.
class TrancheBilan {
  const TrancheBilan(this.heure, this.nbVentes, this.totalCentimes);

  final int heure;
  final int nbVentes;
  final int totalCentimes;
}

class CaisseBilan {
  const CaisseBilan({
    required this.id,
    required this.gymnaseId,
    required this.prenom,
    required this.cloturee,
    required this.nbVentes,
    required this.totalCentimes,
    required this.nbAnnulees,
  });

  final String id;
  final String gymnaseId;
  final String prenom;
  final bool cloturee;
  final int nbVentes;
  final int totalCentimes;
  final int nbAnnulees;
}

/// Une vente annulée, avec sa trace.
class AnnulationBilan {
  const AnnulationBilan({
    required this.caissePrenom,
    required this.venteLe,
    required this.totalCentimes,
    required this.mode,
    required this.parPrenom,
    required this.annuleeLe,
  });

  final String caissePrenom;
  final DateTime venteLe;
  final int totalCentimes;
  final String mode;
  final String? parPrenom;
  final DateTime? annuleeLe;
}

/// Bilan d'un événement : calculé sur les ventes NON annulées ; les annulations
/// sont listées à part avec leur trace.
class Bilan {
  const Bilan({
    required this.nbVentes,
    required this.nbAnnulees,
    required this.totalCentimes,
    required this.produits,
    required this.plusVendus,
    required this.moinsVendus,
    required this.parMode,
    required this.caisses,
    required this.jours,
    required this.heures,
    required this.heuresDePointe,
    required this.annulations,
    required this.caissesNonCloturees,
  });

  /// [modes] : modes de paiement de l'événement (tous affichés, même à zéro).
  ///
  /// [gymnaseId] : la vue distincte d'un gymnase ; null = la vue commune (tous les
  /// gymnases du tableau, additionnés). [stocks] : le stock de chaque gymnase
  /// (gymnase -> produit -> quantité) ; sans lui, le stock affiché est celui de
  /// [produitsEvenement].
  factory Bilan.depuis(
    TableauDeBord tableau,
    List<ProduitEvenement> produitsEvenement,
    List<String> modes, {
    String? gymnaseId,
    Map<String, Map<String, int>>? stocks,
  }) {
    final t = tableau.pour(gymnaseId);

    // Stock d'un produit pour cette vue : celui du gymnase, ou le total.
    int? stockDe(ProduitEvenement p) {
      if (stocks == null) return p.stock;
      final suivis = [
        for (final g in (gymnaseId == null ? stocks.keys : [gymnaseId]))
          ?stocks[g]?[p.id],
      ];
      return suivis.isEmpty ? null : suivis.fold<int>(0, (a, b) => a + b);
    }

    Map<String, int> detailDe(ProduitEvenement p) => {
          if (stocks != null && gymnaseId == null)
            for (final g in stocks.keys)
              if (stocks[g]?[p.id] != null) g: stocks[g]![p.id]!,
        };

    // Produits : tous ceux de l'événement, vendus ou non.
    final lignes = [
      for (final p in produitsEvenement)
        LigneProduitBilan(
          p.id,
          p.nom,
          t.vendus(p.id),
          t.parProduit[p.id]?.montantCentimes ?? 0,
          stockDe(p),
          detailStock: detailDe(p),
        ),
    ]..sort((a, b) {
        final c = b.quantite.compareTo(a.quantite);
        return c != 0 ? c : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
      });

    // Plus / moins vendus : jamais le même produit dans les deux listes.
    final k = lignes.length ~/ 2 < 3 ? lignes.length ~/ 2 : 3;
    final plus = [
      for (final l in lignes.take(k))
        if (l.quantite > 0) l,
    ];
    final moins = (List.of(lignes)
          ..sort((a, b) {
            final c = a.quantite.compareTo(b.quantite);
            return c != 0
                ? c
                : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
          }))
        .take(k)
        .toList();

    // Modes : ceux de l'événement d'abord (même à zéro), puis tout autre utilisé.
    final parMode = <String, int>{
      for (final m in modes) m: t.parMode[m] ?? 0,
      for (final e in t.parMode.entries)
        if (!modes.contains(e.key)) e.key: e.value,
    };

    // Jours et heures (heure locale) sur les ventes non annulées.
    final jours = <String, List<int>>{}; // jour -> [nb, total]
    final heures = <int, List<int>>{}; // heure -> [nb, total]
    final annulations = <AnnulationBilan>[];
    for (final r in t.caisses) {
      for (final v in r.ventes) {
        if (v.annulee) {
          annulations.add(AnnulationBilan(
            caissePrenom: r.caisse.prenom,
            venteLe: v.creeLe,
            totalCentimes: v.totalCentimes,
            mode: v.mode,
            parPrenom: v.annuleeParPrenom,
            annuleeLe: v.annuleeLe,
          ));
          continue;
        }
        final j = jours.putIfAbsent(dateIso(v.creeLe), () => [0, 0]);
        j[0]++;
        j[1] += v.totalCentimes;
        final h = heures.putIfAbsent(v.creeLe.hour, () => [0, 0]);
        h[0]++;
        h[1] += v.totalCentimes;
      }
    }
    annulations.sort((a, b) => (a.annuleeLe ?? a.venteLe)
        .compareTo(b.annuleeLe ?? b.venteLe));
    final tranches = [
      for (final e in heures.entries) TrancheBilan(e.key, e.value[0], e.value[1]),
    ]..sort((a, b) => a.heure.compareTo(b.heure));
    final pointe = List.of(tranches)
      ..sort((a, b) {
        final c = b.nbVentes.compareTo(a.nbVentes);
        return c != 0 ? c : a.heure.compareTo(b.heure);
      });

    return Bilan(
      nbVentes: t.nbVentes,
      nbAnnulees: t.nbAnnulees,
      totalCentimes: t.totalCentimes,
      produits: lignes,
      plusVendus: plus,
      moinsVendus: moins,
      parMode: parMode,
      caisses: [
        for (final r in t.caisses)
          CaisseBilan(
            id: r.caisse.id,
            gymnaseId: r.caisse.gymnaseId,
            prenom: r.caisse.prenom,
            cloturee: r.caisse.cloturee,
            nbVentes: r.recap.nbVentes,
            totalCentimes: r.recap.totalCentimes,
            nbAnnulees: r.recap.nbAnnulees,
          ),
      ],
      jours: [
        for (final e in (jours.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))))
          JourBilan(e.key, e.value[0], e.value[1]),
      ],
      heures: tranches,
      heuresDePointe: pointe.take(3).toList(),
      annulations: annulations,
      caissesNonCloturees: [
        for (final r in t.caisses)
          if (!r.caisse.cloturee) r.caisse.prenom,
      ],
    );
  }

  final int nbVentes;
  final int nbAnnulees;
  final int totalCentimes;

  /// Tous les produits de l'événement, du plus au moins vendu.
  final List<LigneProduitBilan> produits;
  final List<LigneProduitBilan> plusVendus;
  final List<LigneProduitBilan> moinsVendus;
  final Map<String, int> parMode;
  final List<CaisseBilan> caisses;
  final List<JourBilan> jours;

  /// Toutes les tranches d'une heure où il y a eu des ventes, dans l'ordre.
  final List<TrancheBilan> heures;

  /// Les 3 tranches les plus chargées.
  final List<TrancheBilan> heuresDePointe;
  final List<AnnulationBilan> annulations;
  final List<String> caissesNonCloturees;
}

/// Caisses d'un événement (couche Données). Il y a une caisse par (membre,
/// gymnase) : son identifiant est « uid__gymnase » (voir gymnase.dart). Un
/// document « ouvertes/uid » dit quelle caisse est ouverte pour ce membre : il est
/// créé à l'ouverture et supprimé à la clôture, dans la même écriture groupée, ce
/// qui interdit (règles d'accès) d'avoir deux caisses ouvertes sur un événement.
/// Le stock vit dans le gymnase : `gymnases/{g}/stocks/{produit}`.
class DepotCaisses {
  DepotCaisses(this._db, this._assoId, this._evenementId);

  final FirebaseFirestore _db;
  final String _assoId;
  final String _evenementId;

  DocumentReference<Map<String, dynamic>> get _evenement => _db
      .collection('associations')
      .doc(_assoId)
      .collection('evenements')
      .doc(_evenementId);

  DocumentReference<Map<String, dynamic>> _caisse(String caisseId) =>
      _evenement.collection('caisses').doc(caisseId);

  DocumentReference<Map<String, dynamic>> _pointeur(String uid) =>
      _evenement.collection('ouvertes').doc(uid);

  DocumentReference<Map<String, dynamic>> _stock(
          String gymnaseId, String produitId) =>
      _evenement
          .collection('gymnases')
          .doc(gymnaseId)
          .collection('stocks')
          .doc(produitId);

  /// Identifiant de la caisse actuellement ouverte de ce membre sur l'événement
  /// (null = aucune), d'après son pointeur.
  Stream<String?> suivreCaisseOuverte(String uid) => _pointeur(uid)
      .snapshots()
      .map((d) => d.data()?['caisseId'] as String?);

  Caisse? _caisseDe(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    if (data == null) return null;
    final RefCaisse ref;
    try {
      ref = RefCaisse.lire(d.id);
    } on FormatException {
      return null; // caisse d'un ancien événement (avant les gymnases)
    }
    final parMode = data['parMode'];
    return Caisse(
      uid: ref.uid,
      gymnaseId: ref.gymnaseId,
      prenom: data['prenom'] as String,
      statut: data['statut'] as String,
      ouverteLe: (data['ouverteLe'] as Timestamp?)?.toDate(),
      rouverteLe: (data['rouverteLe'] as Timestamp?)?.toDate(),
      clotureLe: (data['clotureLe'] as Timestamp?)?.toDate(),
      recap: data['nbVentes'] == null
          ? null
          : RecapCaisse(
              nbVentes: data['nbVentes'] as int,
              nbAnnulees: data['nbAnnulees'] as int,
              totalCentimes: data['totalCentimes'] as int,
              parMode: {
                if (parMode is Map)
                  for (final e in parMode.entries)
                    e.key as String: e.value as int,
              },
            ),
    );
  }

  Stream<Caisse?> suivreCaisse(String caisseId) =>
      _caisse(caisseId).snapshots().map(_caisseDe);

  void _trier(List<Caisse> liste) => liste.sort(
      (a, b) => a.prenom.toLowerCase().compareTo(b.prenom.toLowerCase()));

  /// Caisses de l'événement vues par la gestion. [gymnaseIds] null = toutes (le
  /// responsable) ; sinon seulement celles de ces gymnases : une requête par
  /// gymnase, car les règles n'acceptent une liste que si elle se limite déjà à
  /// un gymnase du gestionnaire. Un ensemble vide ne lit rien.
  Stream<List<Caisse>> suivreCaisses({Set<String>? gymnaseIds}) {
    List<Caisse> lire(QuerySnapshot<Map<String, dynamic>> s) =>
        [for (final d in s.docs) ?_caisseDe(d)];
    if (gymnaseIds == null) {
      return _evenement.collection('caisses').snapshots().map((s) {
        final liste = lire(s);
        _trier(liste);
        return liste;
      });
    }
    late final StreamController<List<Caisse>> sortie;
    final abonnements = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final parGymnase = <String, List<Caisse>>{};
    void emettre() {
      if (sortie.isClosed || parGymnase.length < gymnaseIds.length) return;
      final liste = [for (final l in parGymnase.values) ...l];
      _trier(liste);
      sortie.add(liste);
    }

    sortie = StreamController<List<Caisse>>.broadcast(
      onListen: () {
        if (gymnaseIds.isEmpty) emettre();
        for (final g in gymnaseIds) {
          abonnements.add(_evenement
              .collection('caisses')
              .where('gymnaseId', isEqualTo: g)
              .snapshots()
              .listen((s) {
            parGymnase[g] = lire(s);
            emettre();
          }, onError: sortie.addError));
        }
      },
      onCancel: () async {
        for (final a in abonnements) {
          await a.cancel();
        }
        abonnements.clear();
        parGymnase.clear();
      },
    );
    return sortie.stream;
  }

  /// Suivi en direct (gestion) : toutes les caisses de l'événement avec leurs
  /// ventes, recalculé à chaque vente, annulation ou clôture.
  ///
  /// Le flux peut être écouté, abandonné puis réécouté (un écran qui défile
  /// sort de l'affichage puis revient) : à chaque nouvelle écoute il repart de
  /// zéro et émet tout de suite l'état courant.
  Stream<TableauDeBord> suivreTableauDeBord({Set<String>? gymnaseIds}) {
    late final StreamController<TableauDeBord> sortie;
    StreamSubscription<List<Caisse>>? abonnementCaisses;
    final abonnementsVentes = <String, StreamSubscription<List<Vente>>>{};
    var caisses = <Caisse>[];
    final ventes = <String, List<Vente>>{};

    void emettre() {
      if (sortie.isClosed) return;
      sortie.add(TableauDeBord.depuis([
        for (final c in caisses) ResumeCaisse(c, ventes[c.id] ?? const []),
      ]));
    }

    sortie = StreamController<TableauDeBord>.broadcast(
      onListen: () {
        abonnementCaisses =
            suivreCaisses(gymnaseIds: gymnaseIds).listen((liste) {
          caisses = liste;
          final presentes = {for (final c in liste) c.id};
          for (final id in abonnementsVentes.keys.toList()) {
            if (!presentes.contains(id)) {
              abonnementsVentes.remove(id)?.cancel();
              ventes.remove(id);
            }
          }
          for (final c in liste) {
            abonnementsVentes.putIfAbsent(
              c.id,
              () => suivreVentes(c.id).listen((v) {
                ventes[c.id] = v;
                emettre();
              }, onError: sortie.addError),
            );
          }
          emettre();
        }, onError: sortie.addError);
      },
      onCancel: () async {
        await abonnementCaisses?.cancel();
        abonnementCaisses = null;
        for (final a in abonnementsVentes.values) {
          await a.cancel();
        }
        // Prêt pour une prochaine écoute : rien ne doit rester de l'ancienne.
        abonnementsVentes.clear();
        ventes.clear();
        caisses = [];
      },
    );
    return sortie.stream;
  }

  /// Ouvre la caisse si elle n'existe pas (sinon la reprend) : la caisse et son
  /// pointeur partent dans la même écriture groupée. N'attend pas le serveur :
  /// fonctionne sans réseau.
  Future<void> ouvrirCaisse(String caisseId, String prenom) async {
    final ref = RefCaisse.lire(caisseId);
    try {
      if ((await _caisse(caisseId).get()).exists) return;
    } catch (_) {
      // Hors réseau et caisse jamais vue sur ce téléphone : on la crée.
    }
    final lot = _db.batch();
    lot.set(_caisse(caisseId), {
      'prenom': prenom,
      'statut': 'ouverte',
      'ouverteLe': Timestamp.now(),
      'membreUid': ref.uid,
      'gymnaseId': ref.gymnaseId,
    });
    lot.set(_pointeur(ref.uid),
        {'gymnaseId': ref.gymnaseId, 'caisseId': caisseId});
    _enFile(lot.commit());
  }

  Vente _venteDe(QueryDocumentSnapshot<Map<String, dynamic>> d) => Vente(
        id: d.id,
        lignes: [
          for (final l in d.data()['lignes'] as List)
            LigneVente(
              l['produitId'] as String,
              l['nom'] as String,
              l['prixCentimes'] as int,
              l['quantite'] as int,
            ),
        ],
        totalCentimes: d.data()['totalCentimes'] as int,
        mode: d.data()['mode'] as String,
        // Pendant l'écriture locale, l'heure est celle du téléphone.
        creeLe: (d.data()['creeLe'] as Timestamp).toDate(),
        enAttente: d.metadata.hasPendingWrites,
        annulee: d.data()['annulee'] == true,
        annuleeParPrenom: d.data()['annuleeParPrenom'] as String?,
        annuleeLe: (d.data()['annuleeLe'] as Timestamp?)?.toDate(),
        corrigeDe: d.data()['corrigeDe'] as String?,
      );

  Stream<List<Vente>> suivreVentes(String caisseId) => _caisse(caisseId)
      .collection('ventes')
      .snapshots(includeMetadataChanges: true)
      .map((s) {
        final liste = [for (final d in s.docs) _venteDe(d)];
        liste.sort((a, b) => b.creeLe.compareTo(a.creeLe));
        return liste;
      });

  /// Clôture la caisse : attend que TOUTES les écritures du téléphone soient
  /// confirmées par le serveur, relit les ventes côté serveur, calcule le
  /// récapitulatif, l'enregistre et libère le pointeur du membre. Nécessite le
  /// réseau : la clôture confirme l'envoi final. Renvoie null si [annule]
  /// devient vrai pendant l'attente.
  Future<RecapCaisse?> cloturerCaisse(
    String caisseId, {
    bool Function()? annule,
  }) async {
    final ref = RefCaisse.lire(caisseId);
    await _db.waitForPendingWrites();
    if (annule?.call() ?? false) return null;
    final ventes = await _caisse(caisseId)
        .collection('ventes')
        .get(const GetOptions(source: Source.server));
    final recap = RecapCaisse.depuis([for (final d in ventes.docs) _venteDe(d)]);
    // Transaction : échoue tout de suite sans réseau au lieu d'attendre.
    await _db.runTransaction((t) async {
      t.update(_caisse(caisseId), {
        'statut': 'cloturee',
        'clotureLe': Timestamp.now(),
        ...recap.versDonnees(),
      });
      t.delete(_pointeur(ref.uid));
    });
    return recap;
  }

  /// Rouvre une caisse clôturée (ex. vente oubliée). Le récapitulatif est
  /// effacé : il sera recalculé à la prochaine clôture. Le pointeur du membre
  /// est recréé (refusé s'il a déjà une autre caisse ouverte). Fonctionne sans
  /// réseau.
  void rouvrirCaisse(String caisseId,
      {void Function(Object erreur)? onErreur}) {
    final ref = RefCaisse.lire(caisseId);
    final lot = _db.batch();
    lot.update(_caisse(caisseId), {
      'statut': 'ouverte',
      'rouverteLe': Timestamp.now(),
      'clotureLe': FieldValue.delete(),
      'nbVentes': FieldValue.delete(),
      'nbAnnulees': FieldValue.delete(),
      'totalCentimes': FieldValue.delete(),
      'parMode': FieldValue.delete(),
    });
    lot.set(_pointeur(ref.uid),
        {'gymnaseId': ref.gymnaseId, 'caisseId': caisseId});
    _enFile(lot.commit(), onErreur);
  }

  /// Enregistre la vente et fait baisser les stocks du gymnase de la caisse,
  /// SANS attendre le réseau : tout est mis en file sur le téléphone et part au
  /// retour du réseau. [onErreur] est appelée si le serveur refuse plus tard
  /// une écriture.
  void enregistrerVente(
    String caisseId,
    List<LigneVente> lignes,
    String mode, {
    required Map<String, int?> stocks,
    String? corrigeDe,
    void Function(Object erreur)? onErreur,
  }) {
    final gymnaseId = RefCaisse.lire(caisseId).gymnaseId;
    final total =
        lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite);
    _enFile(
      _caisse(caisseId).collection('ventes').doc().set({
        'lignes': [for (final l in lignes) l.versDonnees()],
        'totalCentimes': total,
        'mode': mode,
        'creeLe': Timestamp.now(),
        'gymnaseId': gymnaseId,
        'corrigeDe': ?corrigeDe,
      }),
      onErreur,
    );
    // Stock : une écriture par produit suivi (augmentation relative, donc
    // plusieurs caisses hors réseau se cumulent correctement).
    for (final l in lignes) {
      if (stocks[l.produitId] == null) continue;
      _enFile(
        _stock(gymnaseId, l.produitId)
            .update({'quantite': FieldValue.increment(-l.quantite)}),
        onErreur,
      );
    }
  }

  /// Annule une vente (la sienne, ou celle d'une autre caisse pour la
  /// gestion) : la vente reste, marquée annulée avec qui et quand, et les
  /// quantités reviennent dans le stock du gymnase de la caisse. Fonctionne
  /// sans réseau.
  void annulerVente(
    String caisseId,
    Vente vente, {
    required String parUid,
    required String parPrenom,
    required Map<String, int?> stocks,
    void Function(Object erreur)? onErreur,
  }) {
    final gymnaseId = RefCaisse.lire(caisseId).gymnaseId;
    _enFile(
      _caisse(caisseId).collection('ventes').doc(vente.id).update({
        'annulee': true,
        'annuleePar': parUid,
        'annuleeParPrenom': parPrenom,
        'annuleeLe': Timestamp.now(),
      }),
      onErreur,
    );
    for (final l in vente.lignes) {
      if (stocks[l.produitId] == null) continue;
      _enFile(
        _stock(gymnaseId, l.produitId)
            .update({'quantite': FieldValue.increment(l.quantite)}),
        onErreur,
      );
    }
  }

  void _enFile(Future<void> ecriture, [void Function(Object)? onErreur]) {
    ecriture.catchError((Object e) {
      onErreur?.call(e);
    });
  }
}

/// Convertit un ticket en lignes de vente.
List<LigneVente> lignesDuTicket(Ticket ticket) => [
      for (final e in ticket.lignes.entries)
        LigneVente(e.key.id, e.key.nom, e.key.prixCentimes, e.value),
    ];
