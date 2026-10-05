import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'depot_caisses.dart';
import 'depot_menus.dart';
import 'evenement.dart';
import 'gymnase.dart';

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
    );
  }

  /// [enCoursSeulement] est obligatoire pour un bénévole : les règles
  /// n'acceptent sa requête que si elle se limite aux événements en cours.
  Stream<List<Evenement>> suivreEvenements({required bool enCoursSeulement}) {
    Query<Map<String, dynamic>> q = _evenements;
    if (enCoursSeulement) q = q.where('statut', isEqualTo: 'en_cours');
    return q.snapshots().map((s) {
      return trierEvenements([for (final d in s.docs) _depuis(d)]);
    });
  }

  Stream<Evenement?> suivreEvenement(String id) => _evenements
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? _depuis(d) : null);

  /// Gymnases de l'événement, par ordre alphabétique. Vide = événement créé
  /// avant les gymnases (ancien format).
  Stream<List<Gymnase>> suivreGymnases(String id) =>
      _evenements.doc(id).collection('gymnases').snapshots().map((s) {
        final liste = [
          for (final d in s.docs) Gymnase(d.id, d.data()['nom'] as String),
        ];
        liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        return liste;
      });

  /// Quantités en stock par produit (un produit absent n'est pas suivi).
  /// Avec [gymnaseId] : le stock de ce gymnase ; avec [gymnases] : ces gymnases
  /// additionnés ; sans rien : tous les gymnases additionnés.
  Stream<Map<String, int>> suivreStocks(String id,
      {String? gymnaseId, Set<String>? gymnases}) {
    if (gymnaseId != null) return _stocksDe(id, gymnaseId);
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

  Stream<Map<String, int>> _stocksDe(String id, String gymnaseId) => _evenements
      .doc(id)
      .collection('gymnases')
      .doc(gymnaseId)
      .collection('stocks')
      .snapshots()
      .map((s) => {
            for (final d in s.docs) d.id: d.data()['quantite'] as int,
          });

  /// Le stock de chaque gymnase (gymnase -> produit -> quantité), pour afficher
  /// une vue distincte ou commune. [gymnases] limite aux gymnases voulus.
  Stream<Map<String, Map<String, int>>> suivreStocksParGymnase(String id,
      {Set<String>? gymnases}) {
    late final StreamController<Map<String, Map<String, int>>> sortie;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? abonnementGymnases;
    final abonnements = <String, StreamSubscription<Map<String, int>>>{};
    final parGymnase = <String, Map<String, int>>{};

    // Rien n'est émis tant que chaque gymnase n'a pas rendu son stock : pas de
    // total partiel.
    void emettre() {
      if (sortie.isClosed || !abonnements.keys.every(parGymnase.containsKey)) {
        return;
      }
      sortie.add({
        for (final e in parGymnase.entries) e.key: Map.of(e.value),
      });
    }

    sortie = StreamController<Map<String, Map<String, int>>>.broadcast(
      onListen: () {
        abonnementGymnases =
            _evenements.doc(id).collection('gymnases').snapshots().listen((s) {
          final presents = {
            for (final d in s.docs)
              if (gymnases == null || gymnases.contains(d.id)) d.id,
          };
          for (final g in abonnements.keys.toList()) {
            if (!presents.contains(g)) {
              abonnements.remove(g)?.cancel();
              parGymnase.remove(g);
            }
          }
          for (final g in presents) {
            abonnements.putIfAbsent(
              g,
              () => _stocksDe(id, g).listen((m) {
                parGymnase[g] = m;
                emettre();
              }, onError: sortie.addError),
            );
          }
          emettre();
        }, onError: sortie.addError);
      },
      onCancel: () async {
        await abonnementGymnases?.cancel();
        abonnementGymnases = null;
        for (final a in abonnements.values) {
          await a.cancel();
        }
        abonnements.clear();
        parGymnase.clear();
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
          ),
      ];
      liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      sortie.add(liste);
    }

    sortie = StreamController<List<ProduitEvenement>>.broadcast(
      onListen: () {
        abonnementProduits =
            _evenements.doc(id).collection('produits').snapshots().listen((s) {
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
  /// menu devient le stock de départ de chacun.
  Future<String> creerEvenement({
    required String nom,
    required String date,
    required String menuId,
    required List<String> modes,
    List<String> gymnases = const [nomGymnaseParDefaut],
  }) async {
    final menu = await _menus.suivreMenu(menuId).first;
    final produits = await _menus.suivreProduits(menuId).first;
    if (menu == null || produits.isEmpty) throw const MenuVide();
    final ref = _evenements.doc();
    final lot = _db.batch();
    lot.set(ref, {
      'nom': nom.trim(),
      'date': date,
      'statut': 'en_cours',
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
    for (final p in produits) {
      final produit = ref.collection('produits').doc();
      lot.set(produit, {
        'nom': p.nom,
        'prixCentimes': p.prixCentimes,
        'icone': ?p.icone,
        if (p.photo != null) 'photo': Blob(p.photo!),
        'creeLe': FieldValue.serverTimestamp(),
      });
      // Chaque gymnase part du stock du menu.
      if (p.stock != null) {
        for (final g in refsGymnases) {
          lot.set(g.collection('stocks').doc(produit.id), {'quantite': p.stock});
        }
      }
    }
    await lot.commit();
    return ref.id;
  }

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
    lot.update(evenement, {'nbGymnases': actuel + 1});
    lot.set(ref, {
      'nom': nom.trim(),
      'creeLe': FieldValue.serverTimestamp(),
    });
    for (final produitId in suivis.keys) {
      lot.set(ref.collection('stocks').doc(produitId), {'quantite': 0});
    }
    await lot.commit();
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
          .set({'quantite': quantite});

  /// Réapprovisionnement : ajoute [quantite] au stock du gymnase (écriture
  /// relative, donc sûre même si des ventes arrivent en même temps).
  Future<void> reapprovisionner(String evenementId, String gymnaseId,
          String produitId, int quantite) =>
      _gymnase(evenementId, gymnaseId)
          .collection('stocks')
          .doc(produitId)
          .update({'quantite': FieldValue.increment(quantite)});

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
      _rattachement(evenementId, uid).snapshots().map(_gymnasesDe);

  /// Tous les rattachements, par gestionnaire (réservé au responsable).
  Stream<Map<String, Set<String>>> suivreRattachements(String evenementId) =>
      _evenements
          .doc(evenementId)
          .collection('rattachements')
          .snapshots()
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
  /// manquantes dans le bilan. Nécessite le réseau.
  Future<void> cloturerEvenement(
    String id, {
    required String parUid,
    required String parPrenom,
    required int nbCaissesOuvertes,
  }) =>
      // Transaction : échoue tout de suite sans réseau au lieu d'attendre.
      _db.runTransaction((t) async {
        t.update(_evenements.doc(id), {
          'statut': 'cloture',
          'clotureLe': Timestamp.now(),
          'cloturePar': parUid,
          'clotureParPrenom': parPrenom,
          'forcee': nbCaissesOuvertes > 0,
          'nbCaissesOuvertes': nbCaissesOuvertes,
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
