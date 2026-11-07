import 'dart:async';
import 'dart:typed_data';


import 'package:cloud_firestore/cloud_firestore.dart';

import 'depot_caisses.dart';
import 'courses.dart';
import 'depot_menus.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'import_classeur.dart';
import 'mesure.dart';
import 'previsions.dart';
import 'restes.dart';
import 'ticket.dart';

/// Résultat de la vérification d'un QR code de gymnase.
enum ResultatLien { ok, evenementIntrouvable, gymnaseInconnu }

/// Le menu choisi ne contient aucun produit.
class MenuVide implements Exception {
  const MenuVide();
}

/// Événements d'une association (couche Données).
class DepotEvenements {
  DepotEvenements(this._db, this._assoId, this._menus);

  final FirebaseFirestore _db;
  final String _assoId;
  final DepotMenus _menus;

  /// Caisses d'un événement (une par membre).
  DepotCaisses caisses(String evenementId) =>
      DepotCaisses(_db, _assoId, evenementId);

  CollectionReference<Map<String, dynamic>> get _evenements =>
      _db.collection('associations').doc(_assoId).collection('evenements');

  /// Restes gardés à la clôture d'un événement pour le suivant (décision 48).
  CollectionReference<Map<String, dynamic>> get _restes =>
      _db.collection('associations').doc(_assoId).collection('restes');

  /// Les restes en attente d'un événement qui leur correspond. Illisibles (hors
  /// réseau, droits) : aucun, l'événement se crée sans reprise.
  Future<List<Reste>> _lireRestes() async {
    try {
      final s = await _restes.get();
      return [
        for (final d in s.docs)
          if (d.data()['nomGymnase'] is String &&
              d.data()['nomProduit'] is String &&
              d.data()['quantite'] is int)
            Reste(
              nomGymnase: d.data()['nomGymnase'] as String,
              nomProduit: d.data()['nomProduit'] as String,
              quantite: d.data()['quantite'] as int,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Evenement _depuis(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    return Evenement(
      id: d.id,
      nom: data['nom'] as String,
      date: data['date'] as String,
      statut: data['statut'] as String,
      modes: List<String>.from(data['modes'] as List),
      menuNom: data['menuNom'] as String,
      clotureLe: (data['clotureLe'] as Timestamp?)?.toDate(),
      clotureParPrenom: data['clotureParPrenom'] as String?,
      forcee: data['forcee'] == true,
      nbCaissesOuvertes: (data['nbCaissesOuvertes'] as int?) ?? 0,
      nbGymnases: (data['nbGymnases'] as int?) ?? 1,
      nbJours: (data['nbJours'] as num?)?.toDouble() ?? 2.0,
    );
  }

  /// [enCoursSeulement] est obligatoire pour un bénévole : les règles
  /// n'acceptent sa requête que si elle se limite aux événements en cours.
  Stream<List<Evenement>> suivreEvenements({required bool enCoursSeulement}) {
    Query<Map<String, dynamic>> q = _evenements;
    if (enCoursSeulement) q = q.where('statut', isEqualTo: 'en_cours');
    return q.snapshots().compte('evenements').map((s) {
      return trierEvenements([for (final d in s.docs) _depuis(d)]);
    });
  }

  Stream<Evenement?> suivreEvenement(String id) => _evenements
      .doc(id)
      .snapshots().compte('evenement')
      .map((d) => d.exists ? _depuis(d) : null);

  /// Gymnases de l'événement, par ordre alphabétique. Vide = événement créé
  /// avant les gymnases (ancien format).
  Stream<List<Gymnase>> suivreGymnases(String id) =>
      _evenements.doc(id).collection('gymnases').snapshots().compte('gymnases').map((s) {
        final liste = [
          for (final d in s.docs)
            Gymnase(d.id, d.data()['nom'] as String,
                (d.data()['personnes'] as int?) ?? 0),
        ];
        liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        return liste;
      });

  /// Quantités en stock par produit (un produit absent n'est pas suivi).
  /// Avec [gymnaseId] : le stock de ce gymnase ; avec [gymnases] : ces gymnases
  /// additionnés ; sans rien : tous les gymnases additionnés.
  Stream<Map<String, int>> suivreStocks(String id,
      {String? gymnaseId, Set<String>? gymnases}) {
    if (gymnaseId != null) {
      return _detailStocks(id, {gymnaseId}).map((d) => {
            for (final e in (d[gymnaseId]?.stocks ?? const {}).entries)
              e.key: e.value.quantite,
          });
    }
    return suivreStocksParGymnase(id, gymnases: gymnases).map((parGymnase) {
      final total = <String, int>{};
      for (final m in parGymnase.values) {
        for (final e in m.entries) {
          total[e.key] = (total[e.key] ?? 0) + e.value;
        }
      }
      return total;
    });
  }

  /// Le stock de chaque gymnase (gymnase -> produit -> quantité), pour afficher
  /// une vue distincte ou commune. [gymnases] limite aux gymnases voulus.
  Stream<Map<String, Map<String, int>>> suivreStocksParGymnase(String id,
          {Set<String>? gymnases}) =>
      _detailStocks(id, gymnases).map((d) => {
            for (final g in d.entries)
              g.key: {
                for (final e in g.value.stocks.entries) e.key: e.value.quantite,
              },
          });

  /// Le stock de départ de chaque gymnase (gymnase -> produit -> quantité et marque
  /// « repris »), pour l'écran de préparation. Mêmes lectures partagées que les autres.
  Stream<Map<String, Map<String, StockDepart>>> suivreStocksDepart(String id,
          {Set<String>? gymnases}) =>
      _detailStocks(id, gymnases).map((d) => {
            for (final g in d.entries)
              g.key: {
                for (final e in g.value.stocks.entries)
                  e.key: StockDepart(e.value.quantite, repris: e.value.repris),
              },
          });

  /// État du stock de chaque produit, gymnase par gymnase (gymnase -> produit ->
  /// état) : rupture, stock bas, vide. [gymnases] limite aux gymnases voulus.
  Stream<Map<String, Map<String, EtatStock>>> suivreEtats(String id,
          {Set<String>? gymnases}) =>
      _detailStocks(id, gymnases).map((d) => {
            for (final g in d.entries)
              g.key: {
                for (final p in {...g.value.stocks.keys, ...g.value.vides})
                  p: etatStock(
                    quantite: g.value.stocks[p]?.quantite,
                    reference: g.value.stocks[p]?.reference,
                    vide: g.value.vides.contains(p),
                  ),
              },
          });

  // Une seule écoute des stocks (et des signaux « vide ») par événement et par
  // ensemble de gymnases, partagée entre les quantités, les états et les produits :
  // chaque changement de stock n'est lu qu'une fois par téléphone (quota de lectures,
  // étape 8). Elle s'arrête quand plus personne ne l'écoute.
  final Map<String, _Partage<Map<String, _StocksGymnase>>> _partages = {};

  Stream<Map<String, _StocksGymnase>> _detailStocks(
      String id, Set<String>? gymnases) {
    final cle = '$id|${gymnases == null ? '*' : (gymnases.toList()..sort()).join(',')}';
    return _partages
        .putIfAbsent(cle, () => _Partage(() => _lireStocks(id, gymnases)))
        .flux;
  }

  /// Rien n'est émis tant que chaque gymnase n'a pas rendu ses stocks et ses
  /// signaux : pas de total partiel.
  Stream<Map<String, _StocksGymnase>> _lireStocks(
      String id, Set<String>? gymnases) {
    late final StreamController<Map<String, _StocksGymnase>> sortie;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? abonnementGymnases;
    final abonnements = <String, List<StreamSubscription<dynamic>>>{};
    final stocks =
        <String, Map<String, ({int quantite, int? reference, bool repris})>>{};
    final vides = <String, Set<String>>{};

    void emettre() {
      if (sortie.isClosed ||
          !abonnements.keys
              .every((g) => stocks.containsKey(g) && vides.containsKey(g))) {
        return;
      }
      sortie.add({
        for (final g in abonnements.keys)
          g: _StocksGymnase(Map.of(stocks[g]!), Set.of(vides[g]!)),
      });
    }

    sortie = StreamController<Map<String, _StocksGymnase>>(
      onListen: () {
        abonnementGymnases =
            _evenements.doc(id).collection('gymnases').snapshots().compte('gymnases').listen((s) {
          final presents = {
            for (final d in s.docs)
              if (gymnases == null || gymnases.contains(d.id)) d.id,
          };
          for (final g in abonnements.keys.toList()) {
            if (!presents.contains(g)) {
              for (final a in abonnements.remove(g)!) {
                a.cancel();
              }
              stocks.remove(g);
              vides.remove(g);
            }
          }
          for (final g in presents) {
            abonnements.putIfAbsent(g, () {
              final gymnase = _evenements.doc(id).collection('gymnases').doc(g);
              return [
                gymnase.collection('stocks').snapshots().compte('stocks').listen((st) {
                  stocks[g] = {
                    for (final d in st.docs)
                      d.id: (
                        quantite: d.data()['quantite'] as int,
                        reference: d.data()['reference'] as int?,
                        repris: d.data()['repris'] == true,
                      ),
                  };
                  emettre();
                }, onError: sortie.addError),
                gymnase.collection('vides').snapshots().compte('vides').listen((v) {
                  vides[g] = {for (final d in v.docs) d.id};
                  emettre();
                }, onError: sortie.addError),
              ];
            });
          }
          emettre();
        }, onError: sortie.addError);
      },
      onCancel: () async {
        await abonnementGymnases?.cancel();
        abonnementGymnases = null;
        for (final liste in abonnements.values) {
          for (final a in liste) {
            await a.cancel();
          }
        }
        abonnements.clear();
        stocks.clear();
        vides.clear();
      },
    );
    return sortie.stream;
  }

  /// Produits de l'événement avec leur stock : celui du gymnase [gymnaseId], ou
  /// le total des [gymnases], ou (sans rien) le total de tous les gymnases.
  /// Stock null = pas de suivi.
  Stream<List<ProduitEvenement>> suivreProduits(String id,
      {String? gymnaseId, Set<String>? gymnases}) {
    late final StreamController<List<ProduitEvenement>> sortie;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? abonnementProduits;
    StreamSubscription<Map<String, int>>? abonnementStocks;
    QuerySnapshot<Map<String, dynamic>>? produits;
    Map<String, int>? stocks;

    void emettre() {
      final p = produits;
      final q = stocks;
      if (sortie.isClosed || p == null || q == null) return;
      final liste = [
        for (final d in p.docs)
          ProduitEvenement(
            d.id,
            d.data()['nom'] as String,
            d.data()['prixCentimes'] as int,
            q[d.id],
            icone: d.data()['icone'] as String?,
            photo: (d.data()['photo'] as Blob?)?.bytes,
            fiche: FicheProduit.depuis(d.data()),
          ),
      ];
      liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      sortie.add(liste);
    }

    sortie = StreamController<List<ProduitEvenement>>.broadcast(
      onListen: () {
        abonnementProduits =
            _evenements.doc(id).collection('produits').snapshots().compte('produits').listen((s) {
          produits = s;
          emettre();
        }, onError: sortie.addError);
        abonnementStocks =
            suivreStocks(id, gymnaseId: gymnaseId, gymnases: gymnases).listen((s) {
          stocks = s;
          emettre();
        }, onError: sortie.addError);
      },
      onCancel: () async {
        await abonnementProduits?.cancel();
        await abonnementStocks?.cancel();
        abonnementProduits = null;
        abonnementStocks = null;
        produits = null;
        stocks = null;
      },
    );
    return sortie.stream;
  }

  /// Crée l'événement en copiant les produits du menu à cet instant : modifier
  /// le menu plus tard ne change pas un événement déjà lancé. Les gymnases
  /// ([gymnases], « Principal » par défaut) sont créés avec lui ; le stock du
  /// menu devient le stock de départ de chacun. Les restes gardés à la clôture d'un
  /// événement précédent sont repris dans le gymnase et pour le produit de même nom
  /// (puis effacés) ; [surReprises] reçoit ce qui a été repris.
  Future<String> creerEvenement({
    required String nom,
    required String date,
    required String menuId,
    required List<String> modes,
    List<String> gymnases = const [nomGymnaseParDefaut],
    void Function(List<Reprise> reprises)? surReprises,
  }) async {
    final menu = await _menus.suivreMenu(menuId).first;
    final produits = await _menus.suivreProduits(menuId).first;
    if (menu == null || produits.isEmpty) throw const MenuVide();
    final ref = _evenements.doc();
    final lot = _db.batch();
    lot.set(ref, {
      'nom': nom.trim(),
      'date': date,
      'statut': 'en_preparation',
      'modes': modes,
      'menuNom': menu.nom,
      'creeLe': FieldValue.serverTimestamp(),
      'nbGymnases': gymnases.length,
    });
    final refsGymnases = [
      for (var i = 0; i < gymnases.length; i++) ref.collection('gymnases').doc(),
    ];
    for (var i = 0; i < gymnases.length; i++) {
      lot.set(refsGymnases[i], {
        'nom': gymnases[i].trim(),
        'creeLe': FieldValue.serverTimestamp(),
      });
    }
    final produitsCrees = <String, String>{};
    for (final p in produits) {
      final produit = ref.collection('produits').doc();
      produitsCrees[produit.id] = p.nom;
      lot.set(produit, {
        'nom': p.nom,
        'prixCentimes': p.prixCentimes,
        'icone': ?p.icone,
        if (p.photo != null) 'photo': Blob(p.photo!),
        ...p.fiche.versMap(),
        'creeLe': FieldValue.serverTimestamp(),
      });
    }
    final reprises = repriseDesRestes(
      restes: await _lireRestes(),
      gymnases: {
        for (var i = 0; i < gymnases.length; i++)
          refsGymnases[i].id: gymnases[i].trim(),
      },
      produits: produitsCrees,
    );
    for (final r in reprises) {
      lot.set(
        ref.collection('gymnases').doc(r.gymnaseId).collection('stocks').doc(r.produitId),
        {'quantite': r.reste.quantite, 'reference': r.reste.quantite, 'repris': true},
      );
      lot.delete(_restes.doc(r.reste.id));
    }
    await lot.commit();
    surReprises?.call(reprises);
    return ref.id;
  }

  /// Change l'image (icône et/ou photo) d'un produit de l'événement. Le nom et
  /// le prix restent ceux de la copie : seule l'image se corrige après coup.
  Future<void> modifierImageProduit(
    String evenementId,
    String produitId, {
    String? icone,
    Uint8List? photo,
  }) =>
      _evenements.doc(evenementId).collection('produits').doc(produitId).update({
        'icone': icone ?? FieldValue.delete(),
        'photo': photo == null ? FieldValue.delete() : Blob(photo),
      });

  DocumentReference<Map<String, dynamic>> _gymnase(String id, String gymnaseId) =>
      _evenements.doc(id).collection('gymnases').doc(gymnaseId);

  /// Ajoute un gymnase. Il suit les mêmes produits que les autres, à zéro : la
  /// gestion règle ensuite les quantités. Gymnase et stocks partent dans le même
  /// lot.
  Future<void> ajouterGymnase(String evenementId, String nom) async {
    final suivis = await suivreStocks(evenementId).first;
    final evenement = _evenements.doc(evenementId);
    // Le compteur de l'événement monte de 1 dans le même lot (exigé par les règles).
    final actuel = ((await evenement.get(const GetOptions(source: Source.server)))
            .data()?['nbGymnases'] as int?) ??
        1;
    final ref = evenement.collection('gymnases').doc();
    final lot = _db.batch();
    lot.update(evenement, {'nbGymnases': actuel + 1, 'dernierGymnase': ref.id});
    lot.set(ref, {
      'nom': nom.trim(),
      'creeLe': FieldValue.serverTimestamp(),
    });
    for (final produitId in suivis.keys) {
      lot.set(ref.collection('stocks').doc(produitId),
          {'quantite': 0, 'reference': 0});
    }
    await lot.commit();
  }

  /// Réglages des courses : durée de l'événement et personnes attendues par gymnase.
  Future<void> definirJours(String evenementId, double jours) =>
      _evenements.doc(evenementId).update({'nbJours': jours});

  Future<void> definirPersonnes(
          String evenementId, String gymnaseId, int personnes) =>
      _gymnase(evenementId, gymnaseId).update({'personnes': personnes});

  // ---------- Prévision de consommation (mission « Préparer l'événement », P4) ----------

  CollectionReference<Map<String, dynamic>> _previsions(String evenementId) =>
      _evenements.doc(evenementId).collection('previsions');

  /// Les prévisions enregistrées (produit -> chiffre et source). Réservé à qui a accès
  /// à tout l'événement (règles d'accès). Un produit sans prévision garde le menu.
  Stream<Map<String, Prevision>> suivrePrevisions(String evenementId) =>
      _previsions(evenementId).snapshots().compte('previsions').map((s) => {
            for (final d in s.docs)
              if (d.data()['conso'] is num && d.data()['source'] is String)
                d.id: Prevision((d.data()['conso'] as num).toDouble(),
                    d.data()['source'] as String),
          });

  /// Enregistre le chiffre d'un produit, corrigé à la main (le menu ne change pas).
  Future<void> definirPrevision(String evenementId, String produitId, double conso) =>
      _previsions(evenementId)
          .doc(produitId)
          .set({'conso': conso, 'source': sourceMain});

  /// Écrit et efface des prévisions. Par groupes de 10 : les règles d'accès relisent
  /// chaque produit (limite de lectures par requête). Écrire est idempotent : en cas
  /// d'échec au milieu, recommencer donne le même résultat.
  Future<void> _appliquerPrevisions(String evenementId,
      {required Map<String, Prevision> ecrire,
      required Iterable<String> effacer}) async {
    final operations = <void Function(WriteBatch lot)>[
      for (final e in ecrire.entries)
        (lot) => lot.set(_previsions(evenementId).doc(e.key),
            {'conso': e.value.conso, 'source': e.value.source}),
      for (final id in effacer) (lot) => lot.delete(_previsions(evenementId).doc(id)),
    ];
    for (var i = 0; i < operations.length; i += 10) {
      final lot = _db.batch();
      for (final op in operations.skip(i).take(10)) {
        op(lot);
      }
      await lot.commit();
    }
  }

  Future<Set<String>> _idsPrevisions(String evenementId) async => {
        for (final d in (await _previsions(evenementId)
                .get(const GetOptions(source: Source.server)))
            .docs)
          d.id,
      };

  /// Remet tous les produits au chiffre du menu (efface les prévisions).
  Future<void> revenirAuMenu(String evenementId) async => _appliquerPrevisions(
        evenementId,
        ecrire: const {},
        effacer: await _idsPrevisions(evenementId),
      );

  /// Produits d'un événement, lus une fois sur le serveur (sans stock).
  Future<List<ProduitEvenement>> _lireProduits(String evenementId) async {
    final s = await _evenements
        .doc(evenementId)
        .collection('produits')
        .get(const GetOptions(source: Source.server));
    return [
      for (final d in s.docs)
        ProduitEvenement(d.id, d.data()['nom'] as String,
            d.data()['prixCentimes'] as int, null,
            fiche: FicheProduit.depuis(d.data())),
    ];
  }

  /// Les événements clôturés de l'association (sauf [sauf]) : ceux qui peuvent servir
  /// de référence, et le nombre de ceux écartés faute de personnes réglées. Nécessite
  /// le réseau.
  Future<EvenementsPasses> evenementsPasses({String? sauf}) async {
    const serveur = GetOptions(source: Source.server);
    final cloturees = await _evenements.where('statut', isEqualTo: 'cloture').get(serveur);
    final references = <ReferencePassee>[];
    for (final e in cloturees.docs) {
      if (e.id == sauf) continue;
      final gymnases = await e.reference.collection('gymnases').get(serveur);
      references.add(ReferencePassee(
        id: e.id,
        nom: e.data()['nom'] as String,
        date: e.data()['date'] as String,
        personnes: gymnases.docs
            .fold<int>(0, (t, g) => t + ((g.data()['personnes'] as int?) ?? 0)),
        jours: (e.data()['nbJours'] as num?)?.toDouble() ?? 2.0,
      ));
    }
    return selectionnerReferences(references);
  }

  /// Applique d'un coup la consommation calculée d'après l'événement [passe] : les
  /// produits retrouvés par leur nom prennent le chiffre calculé (source « Événement :
  /// nom »), les autres reviennent au menu. Si les ventes de l'événement passé ne sont
  /// pas lisibles avec les droits de la personne : [LectureRefusee], rien n'est écrit.
  Future<void> appliquerEvenementPasse(String evenementId, ReferencePassee passe) async {
    final produits = await _lireProduits(evenementId);
    final produitsPasses = {
      for (final p in await _lireProduits(passe.id)) p.id: p.nom,
    };
    final TableauDeBord tableau;
    try {
      tableau = await caisses(passe.id).lireTableauDeBord();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const LectureRefusee();
      rethrow;
    }
    final conso = consoDepuisEvenement(
      produits: produits,
      produitsPasses: produitsPasses,
      tableau: tableau,
      personnes: passe.personnes,
      jours: passe.jours,
    );
    final source = sourceEvenement(passe.nom);
    final existantes = await _idsPrevisions(evenementId);
    await _appliquerPrevisions(
      evenementId,
      ecrire: {for (final e in conso.entries) e.key: Prevision(e.value, source)},
      effacer: existantes.where((id) => !conso.containsKey(id)),
    );
  }

  // ---------- Références importées d'un classeur Excel (P6) ----------

  /// Références de consommation nommées, au niveau de l'association (réutilisables d'un
  /// événement à l'autre) : associations/{a}/references/{id}.
  CollectionReference<Map<String, dynamic>> get _references =>
      _db.collection('associations').doc(_assoId).collection('references');

  /// Les références importées, par ordre alphabétique. Une ligne invalide est ignorée.
  /// Nécessite le réseau ; illisibles (droits, réseau) : [LectureRefusee] ou l'erreur.
  Future<List<ReferenceImportee>> lireReferences() async {
    final s = await _references.get(const GetOptions(source: Source.server));
    final res = <ReferenceImportee>[];
    for (final d in s.docs) {
      final nom = d.data()['nom'];
      final lignes = d.data()['lignes'];
      if (nom is! String || lignes is! List) continue;
      res.add(ReferenceImportee(
        id: d.id,
        nom: nom,
        lignes: [
          for (final l in lignes)
            // Les règles ne vérifient que les premières lignes : on écarte ici toute
            // ligne hors format (nom de 1 à 40 caractères, chiffre de 0 à 1000).
            if (l is Map &&
                l['nom'] is String &&
                (l['nom'] as String).isNotEmpty &&
                (l['nom'] as String).length <= referenceProduitMax &&
                l['conso'] is num &&
                (l['conso'] as num) >= 0 &&
                (l['conso'] as num) <= consoPrevisionMax)
              LigneReference(l['nom'] as String, (l['conso'] as num).toDouble()),
        ],
      ));
    }
    res.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return res;
  }

  /// Applique d'un coup une référence importée : les produits retrouvés par leur nom
  /// prennent son chiffre (source = son nom), les autres reviennent au menu (comme
  /// [appliquerEvenementPasse]).
  Future<void> appliquerReference(
      String evenementId, ReferenceImportee reference) async {
    final produits = await _lireProduits(evenementId);
    final conso = consoDepuisReference(produits: produits, reference: reference);
    final source = reference.nom.length <= sourceLongueurMax
        ? reference.nom
        : reference.nom.substring(0, sourceLongueurMax);
    final existantes = await _idsPrevisions(evenementId);
    await _appliquerPrevisions(
      evenementId,
      ecrire: {for (final e in conso.entries) e.key: Prevision(e.value, source)},
      effacer: existantes.where((id) => !conso.containsKey(id)),
    );
  }

  /// Exécute un plan d'import : les références (une même clé est remplacée : rejouer est
  /// sans risque) puis les stocks de départ, comme la saisie à la main (la marque
  /// « repris » disparaît). Rien d'autre n'est écrit : aucune vente, aucun bilan.
  /// Les stocks partent par groupes de 20 (limite d'évaluation des règles d'accès) ;
  /// en cas d'échec au milieu, recommencer donne le même résultat.
  Future<void> appliquerImport(String evenementId, PlanImport plan) async {
    for (final r in plan.references) {
      await _references.doc(r.id).set({
        'nom': r.nom,
        'lignes': [
          for (final l in r.lignes) {'nom': l.nom, 'conso': l.conso},
        ],
        'creeLe': FieldValue.serverTimestamp(),
      });
    }
    for (var i = 0; i < plan.stocks.length; i += 20) {
      final lot = _db.batch();
      for (final s in plan.stocks.skip(i).take(20)) {
        lot.set(
          _gymnase(evenementId, s.gymnaseId).collection('stocks').doc(s.produitId),
          {'quantite': s.quantite, 'reference': s.quantite},
        );
      }
      await lot.commit();
    }
  }

  /// La liste de courses de l'événement (une seule, document « liste »), null
  /// tant qu'elle n'a pas été enregistrée.
  Stream<ListeCourses?> suivreListeCourses(String evenementId) => _evenements
      .doc(evenementId)
      .collection('courses')
      .doc('liste')
      .snapshots().compte('courses')
      .map((d) => d.exists ? ListeCourses.depuis(d.data()!) : null);

  Future<void> enregistrerListeCourses(
          String evenementId, ListeCourses liste) =>
      _evenements.doc(evenementId).collection('courses').doc('liste').set({
        ...liste.versMap(),
        'majLe': FieldValue.serverTimestamp(),
      });

  /// Valide les courses : ajoute les [rendements] au stock de chaque gymnase (et à
  /// son total de référence) et fige la liste, dans UN SEUL lot : tout est ajouté ou
  /// rien. Un produit sans suivi dans un gymnase commence à y être suivi. Demande le
  /// réseau (lit l'état réel des stocks) ; une liste déjà validée est refusée par les
  /// règles d'accès.
  Future<void> validerCourses(
    String evenementId, {
    required ListeCourses liste,
    required Map<String, double> achetes,
    required List<Rendement> rendements,
    required int coutCentimes,
  }) async {
    const serveur = GetOptions(source: Source.server);
    final lot = _db.batch();
    for (final r in rendements) {
      if (r.quantite <= 0) continue;
      final ref = _gymnase(evenementId, r.gymnaseId)
          .collection('stocks')
          .doc(r.produitId);
      final actuel = await ref.get(serveur);
      if (!actuel.exists) {
        lot.set(ref, {'quantite': r.quantite, 'reference': r.quantite});
      } else {
        final data = actuel.data()!;
        lot.update(ref, {
          'quantite': FieldValue.increment(r.quantite),
          // Un stock plus ancien n'a pas de total de référence : on le pose.
          'reference': data['reference'] != null
              ? FieldValue.increment(r.quantite)
              : (data['quantite'] as int) + r.quantite,
        });
      }
    }
    lot.set(
      _evenements.doc(evenementId).collection('courses').doc('liste'),
      {
        ...liste.versMap(),
        'statut': 'validee',
        'achats': [
          for (final e in achetes.entries) {'cle': e.key, 'quantite': e.value},
        ],
        'rendements': [
          for (final r in rendements)
            if (r.quantite > 0) r.versMap(),
        ],
        'coutCentimes': coutCentimes,
        'majLe': FieldValue.serverTimestamp(),
        'valideeLe': FieldValue.serverTimestamp(),
      },
    );
    await lot.commit();
  }

  /// Ouvre une nouvelle série de courses après une validation (mission C1) : la liste
  /// repart vide, le coût et les ajouts de stock déjà validés sont gardés dans le
  /// cumul. Rien n'est rejoué : le stock a déjà reçu les séries précédentes. Les
  /// règles n'acceptent le passage que depuis une liste validée.
  Future<void> nouvelleSerieCourses(
      String evenementId, ListeCourses validee) {
    assert(validee.validee);
    return _evenements.doc(evenementId).collection('courses').doc('liste').set({
      ...validee.nouvelleSerie().versMap(),
      'majLe': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renommerGymnase(
          String evenementId, String gymnaseId, String nom) =>
      _gymnase(evenementId, gymnaseId).update({'nom': nom.trim()});

  /// Fixe la quantité d'un produit dans un gymnase (et en démarre le suivi s'il
  /// n'y en avait pas).
  Future<void> definirStock(String evenementId, String gymnaseId,
          String produitId, int quantite) =>
      _gymnase(evenementId, gymnaseId)
          .collection('stocks')
          .doc(produitId)
          .set({'quantite': quantite, 'reference': quantite});

  /// Réapprovisionnement : ajoute [quantite] au stock du gymnase (écriture
  /// relative, donc sûre même si des ventes arrivent en même temps) et au total
  /// de référence.
  Future<void> reapprovisionner(String evenementId, String gymnaseId,
          String produitId, int quantite) =>
      _ajouter(evenementId, gymnaseId, produitId, quantite);

  /// Ajout de stock par un bénévole dont la caisse est ouverte dans ce gymnase :
  /// même écriture que le réapprovisionnement (les règles la limitent aux
  /// produits de type « part » ou apportés par les bénévoles).
  Future<void> ajouterParts(String evenementId, String gymnaseId,
          String produitId, int quantite) =>
      _ajouter(evenementId, gymnaseId, produitId, quantite);

  Future<void> _ajouter(String evenementId, String gymnaseId, String produitId,
      int quantite) async {
    final ref = _gymnase(evenementId, gymnaseId).collection('stocks').doc(produitId);
    final actuel = (await ref.get()).data();
    // Un stock plus ancien n'a pas de total de référence : on le pose d'après la
    // quantité connue.
    final reference = actuel != null && actuel['reference'] != null
        ? FieldValue.increment(quantite)
        : ((actuel?['quantite'] as int?) ?? 0) + quantite;
    await ref.update({
      'quantite': FieldValue.increment(quantite),
      'reference': reference,
    });
  }

  /// Les produits signalés « vides » dans un gymnase.
  Stream<Set<String>> suivreVides(String evenementId, String gymnaseId) =>
      _gymnase(evenementId, gymnaseId)
          .collection('vides')
          .snapshots().compte('vides')
          .map((s) => {for (final d in s.docs) d.id});

  /// Signale (ou retire le signal) qu'un produit est vide dans ce gymnase.
  Future<void> signalerVide(String evenementId, String gymnaseId,
      String produitId, bool vide) {
    final ref = _gymnase(evenementId, gymnaseId).collection('vides').doc(produitId);
    return vide
        ? ref.set({'creeLe': FieldValue.serverTimestamp()})
        : ref.delete();
  }

  /// Arrête le suivi d'un produit dans un gymnase.
  Future<void> arreterSuivi(
          String evenementId, String gymnaseId, String produitId) =>
      _gymnase(evenementId, gymnaseId)
          .collection('stocks')
          .doc(produitId)
          .delete();

  DocumentReference<Map<String, dynamic>> _rattachement(
          String evenementId, String uid) =>
      _evenements.doc(evenementId).collection('rattachements').doc(uid);

  Set<String> _gymnasesDe(DocumentSnapshot<Map<String, dynamic>> d) => {
        for (final g in (d.data()?['gymnases'] as List?) ?? const []) g as String,
      };

  /// Gymnases auxquels ce gestionnaire est rattaché (vide = aucun).
  Stream<Set<String>> suivreMesGymnases(String evenementId, String uid) =>
      _rattachement(evenementId, uid).snapshots().compte('rattachement').map(_gymnasesDe);

  /// Tous les rattachements, par gestionnaire (réservé au responsable).
  Stream<Map<String, Set<String>>> suivreRattachements(String evenementId) =>
      _evenements
          .doc(evenementId)
          .collection('rattachements')
          .snapshots().compte('rattachements')
          .map((s) => {for (final d in s.docs) d.id: _gymnasesDe(d)});

  /// Fixe les gymnases d'un gestionnaire (responsable seul).
  Future<void> definirRattachement(
          String evenementId, String uid, Set<String> gymnases) =>
      _rattachement(evenementId, uid)
          .set({'gymnases': (gymnases.toList()..sort())});

  /// Le QR code mène-t-il à un événement en cours et à un gymnase qui existe ?
  /// Un événement clôturé n'est plus lisible par un bénévole : il compte comme
  /// introuvable. Nécessite le réseau.
  Future<ResultatLien> verifierLien(
      String evenementId, String gymnaseId) async {
    const serveur = GetOptions(source: Source.server);
    try {
      final e = await _evenements.doc(evenementId).get(serveur);
      if (!e.exists || e.data()!['statut'] != 'en_cours') {
        return ResultatLien.evenementIntrouvable;
      }
    } on FirebaseException catch (ex) {
      if (ex.code == 'permission-denied') return ResultatLien.evenementIntrouvable;
      rethrow;
    }
    final g = await _gymnase(evenementId, gymnaseId).get(serveur);
    return g.exists ? ResultatLien.ok : ResultatLien.gymnaseInconnu;
  }

  /// Clôture l'événement (gestionnaire identifié). [nbCaissesOuvertes] > 0 =
  /// clôture forcée : le fait, son auteur et le nombre de caisses non
  /// clôturées sont conservés pour signaler les ventes éventuellement
  /// manquantes dans le bilan. Nécessite le réseau. [restes] : les produits gardés
  /// pour le prochain événement (écrits avec la clôture, tout ou rien) ; [ecartes] :
  /// identifiants de restes d'un report plus ancien à retirer.
  Future<void> cloturerEvenement(
    String id, {
    required String parUid,
    required String parPrenom,
    required int nbCaissesOuvertes,
    List<Reste> restes = const [],
    List<String> ecartes = const [],
  }) =>
      // Transaction : échoue tout de suite sans réseau au lieu d'attendre.
      _db.runTransaction((t) async {
        for (final r in restes) {
          t.set(_restes.doc(r.id), {
            'nomGymnase': r.nomGymnase,
            'nomProduit': r.nomProduit,
            'quantite': r.quantite,
            'evenementId': id,
            'majLe': Timestamp.now(),
          });
        }
        for (final e in ecartes) {
          t.delete(_restes.doc(e));
        }
        t.update(_evenements.doc(id), {
          'statut': 'cloture',
          'clotureLe': Timestamp.now(),
          'cloturePar': parUid,
          'clotureParPrenom': parPrenom,
          'forcee': nbCaissesOuvertes > 0,
          'nbCaissesOuvertes': nbCaissesOuvertes,
        });
      });

  /// Ouvre l'événement : « en préparation » devient « en cours » (les bénévoles le
  /// voient alors, les caisses peuvent s'ouvrir). Le responsable, ou un gestionnaire
  /// rattaché à tous les gymnases ; pas de retour en arrière. Nécessite le réseau.
  Future<void> ouvrirEvenement(String id) =>
      // Transaction : échoue tout de suite sans réseau au lieu d'attendre.
      _db.runTransaction((t) async {
        t.update(_evenements.doc(id), {
          'statut': 'en_cours',
          'ouvertLe': Timestamp.now(),
        });
      });

  Future<void> modifierEvenement(
    String id, {
    required String nom,
    required String date,
    required List<String> modes,
  }) =>
      _evenements
          .doc(id)
          .update({'nom': nom.trim(), 'date': date, 'modes': modes});
}

/// Stocks d'un gymnase : quantité et total de référence par produit, et produits
/// signalés « vides ».
class _StocksGymnase {
  const _StocksGymnase(this.stocks, this.vides);

  final Map<String, ({int quantite, int? reference, bool repris})> stocks;
  final Set<String> vides;
}

/// Partage une même écoute entre plusieurs abonnés : la source démarre au premier,
/// s'arrête au départ du dernier, et chaque nouvel abonné reçoit tout de suite le
/// dernier état connu.
class _Partage<T> {
  _Partage(this._demarrer);

  final Stream<T> Function() _demarrer;
  final List<MultiStreamController<T>> _abonnes = [];
  StreamSubscription<T>? _source;
  T? _dernier;
  bool _aUnDernier = false;

  Stream<T> get flux => Stream<T>.multi((c) {
        _abonnes.add(c);
        if (_aUnDernier) c.add(_dernier as T);
        if (_source == null) {
          _source = _demarrer().listen((v) {
            _dernier = v;
            _aUnDernier = true;
            for (final a in List.of(_abonnes)) {
              a.add(v);
            }
          }, onError: (Object e, StackTrace st) {
            for (final a in List.of(_abonnes)) {
              a.addError(e, st);
            }
          });
        }
        c.onCancel = () {
          _abonnes.remove(c);
          if (_abonnes.isEmpty) {
            _source?.cancel();
            _source = null;
            _dernier = null;
            _aUnDernier = false;
          }
        };
      }, isBroadcast: true);
}
