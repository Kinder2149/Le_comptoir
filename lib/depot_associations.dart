import 'package:cloud_firestore/cloud_firestore.dart';

import 'code_association.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart';

class Association {
  const Association(this.id, this.nom, this.code);

  final String id;
  final String nom;
  final String code;
}

class Membre {
  const Membre(this.uid, this.prenom, this.role, {this.enAttente = false});

  final String uid;
  final String prenom;
  final String role; // 'responsable' | 'gestionnaire' | 'benevole'

  /// Nommé gestionnaire par le responsable, pas encore activé : il garde les
  /// droits d'un bénévole jusqu'à son activation.
  final bool enAttente;

  bool get estResponsable => role == 'responsable';
}

/// « Responsable », « Gestionnaire », « Gestionnaire en attente », « Bénévole ».
String libelleStatut(Membre m) =>
    m.enAttente ? 'Gestionnaire en attente' : libelleRole(m.role);

String libelleRole(String role) => switch (role) {
      'responsable' => 'Responsable',
      'gestionnaire' => 'Gestionnaire',
      _ => 'Bénévole',
    };

/// Le code saisi n'existe pas ou n'est plus valable.
class CodeInvalide implements Exception {
  const CodeInvalide();
}

/// Accès aux données de l'association (couche Données).
class DepotAssociations {
  DepotAssociations(this._db);

  final FirebaseFirestore _db;

  /// Menus d'une association (même base de données).
  DepotMenus menus(String assoId) => DepotMenus(_db, assoId);

  /// Événements d'une association (copient les produits d'un menu).
  DepotEvenements evenements(String assoId) =>
      DepotEvenements(_db, assoId, menus(assoId));

  DocumentReference<Map<String, dynamic>> _asso(String id) =>
      _db.collection('associations').doc(id);
  DocumentReference<Map<String, dynamic>> _code(String code) =>
      _db.collection('codes').doc(code);
  DocumentReference<Map<String, dynamic>> _utilisateur(String uid) =>
      _db.collection('users').doc(uid);

  /// Identifiant de l'association de cet appareil, ou null.
  /// On attend la confirmation du serveur : sinon l'écran de l'association
  /// s'ouvre avant que l'appartenance existe, et le serveur refuse la lecture.
  Stream<String?> suivreAssociationId(String uid) => _utilisateur(uid)
      .snapshots(includeMetadataChanges: true)
      .where((d) => !d.metadata.hasPendingWrites)
      .map((d) => d.data()?['assoId'] as String?)
      .distinct();

  Stream<Association?> suivreAssociation(String id) =>
      _asso(id).snapshots().map((d) {
        final data = d.data();
        if (data == null) return null;
        return Association(d.id, data['nom'] as String, data['code'] as String);
      });

  Stream<List<Membre>> suivreMembres(String id) =>
      _asso(id).collection('membres').snapshots().map((s) {
        final liste = [
          for (final d in s.docs)
            Membre(
              d.id,
              d.data()['prenom'] as String,
              d.data()['role'] as String,
              enAttente: d.data()['role'] == 'benevole' &&
                  d.data()['nomme'] == true,
            ),
        ];
        liste.sort((a, b) {
          if (a.estResponsable != b.estResponsable) {
            return a.estResponsable ? -1 : 1;
          }
          return a.prenom.toLowerCase().compareTo(b.prenom.toLowerCase());
        });
        return liste;
      });

  /// Génère un code qui n'est pas déjà pris.
  Future<String> _codeLibre() async {
    for (var i = 0; i < 10; i++) {
      final code = genererCode();
      if (!(await _code(code).get()).exists) return code;
    }
    throw StateError('Aucun code libre trouvé.');
  }

  /// Crée l'association ; le créateur en devient le responsable.
  Future<String> creerAssociation({
    required String uid,
    required String nom,
    required String prenom,
  }) async {
    final code = await _codeLibre();
    final asso = _db.collection('associations').doc();
    final lot = _db.batch();
    lot.set(asso, {
      'nom': nom.trim(),
      'code': code,
      'responsableUid': uid,
      'creeLe': FieldValue.serverTimestamp(),
    });
    lot.set(asso.collection('membres').doc(uid), {
      'prenom': prenom.trim(),
      'role': 'responsable',
      'rejointLe': FieldValue.serverTimestamp(),
      'codeUtilise': '',
    });
    lot.set(_code(code), {'assoId': asso.id});
    lot.set(_utilisateur(uid), {'assoId': asso.id});
    await lot.commit();
    return asso.id;
  }

  /// L'association à laquelle mène ce code d'accès (null si le code est inconnu
  /// ou périmé : il a été changé depuis).
  Future<String?> associationDuCode(String codeSaisi) async {
    final code = normaliserCode(codeSaisi);
    if (!codeBienForme(code)) return null;
    final annuaire = await _code(code).get(const GetOptions(source: Source.server));
    return annuaire.data()?['assoId'] as String?;
  }

  /// Rejoint une association avec son code, en tant que bénévole.
  Future<String> rejoindre({
    required String uid,
    required String codeSaisi,
    required String prenom,
  }) async {
    final code = normaliserCode(codeSaisi);
    if (!codeBienForme(code)) throw const CodeInvalide();
    final annuaire = await _code(code).get();
    final assoId = annuaire.data()?['assoId'] as String?;
    if (assoId == null) throw const CodeInvalide();
    final lot = _db.batch();
    lot.set(_asso(assoId).collection('membres').doc(uid), {
      'prenom': prenom.trim(),
      'role': 'benevole',
      'rejointLe': FieldValue.serverTimestamp(),
      'codeUtilise': code,
    });
    lot.set(_utilisateur(uid), {'assoId': assoId});
    try {
      await lot.commit();
    } on FirebaseException catch (e) {
      // Code régénéré entre la lecture et l'écriture, ou déjà membre.
      if (e.code == 'permission-denied') throw const CodeInvalide();
      rethrow;
    }
    return assoId;
  }

  DocumentReference<Map<String, dynamic>> _membre(String assoId, String uid) =>
      _asso(assoId).collection('membres').doc(uid);

  /// Le responsable nomme un bénévole gestionnaire : « en attente » jusqu'à ce
  /// que le membre l'active lui-même. Nécessite le réseau.
  Future<void> nommerGestionnaire(String assoId, String membreUid) =>
      _db.runTransaction((t) async {
        t.update(_membre(assoId, membreUid), {'nomme': true});
      });

  /// Le responsable retire le statut de gestionnaire (actif ou en attente) :
  /// le membre redevient bénévole. Nécessite le réseau.
  Future<void> retirerGestionnaire(String assoId, String membreUid) =>
      _db.runTransaction((t) async {
        t.update(_membre(assoId, membreUid),
            {'role': 'benevole', 'nomme': FieldValue.delete()});
      });

  /// Le membre nommé active son statut (après connexion Google). Nécessite le
  /// réseau.
  Future<void> activerGestionnaire(String assoId, String uid) =>
      _db.runTransaction((t) async {
        t.update(_membre(assoId, uid),
            {'role': 'gestionnaire', 'nomme': FieldValue.delete()});
      });

  /// Le responsable retire un membre de l'association. Ses ventes passées
  /// restent dans les bilans. Il peut revenir avec le code d'accès, sauf si
  /// le code a changé. Nécessite le réseau.
  Future<void> retirerMembre(String assoId, String membreUid) =>
      _db.runTransaction((t) async {
        t.delete(_membre(assoId, membreUid));
      });

  /// Cet appareil n'appartient plus à son association (supprimée, ou membre
  /// retiré) : il l'oublie et revient à l'écran d'accueil.
  Future<void> oublierAssociation(String uid) => _utilisateur(uid).delete();

  static const _serveur = GetOptions(source: Source.server);

  /// Efface tous les documents d'une collection, par petits lots (les règles
  /// limitent le nombre de vérifications par lot).
  Future<void> _effacerCollection(CollectionReference<Map<String, dynamic>> ref) async {
    while (true) {
      final docs = (await ref.limit(300).get(_serveur)).docs;
      if (docs.isEmpty) return;
      for (var i = 0; i < docs.length; i += 15) {
        final lot = _db.batch();
        for (final d in docs.skip(i).take(15)) {
          lot.delete(d.reference);
        }
        await lot.commit();
      }
    }
  }

  /// Supprime l'association et TOUT son contenu (menus, événements, gymnases,
  /// stocks, rattachements, caisses, ventes, membres, code). Le responsable la marque d'abord « en cours de
  /// suppression » : c'est ce qui autorise les règles à effacer le reste. Si
  /// l'opération est interrompue, on peut la relancer : elle reprend où elle
  /// s'était arrêtée. Nécessite le réseau.
  Future<void> supprimerAssociation(String assoId) async {
    final asso = _asso(assoId);
    final code = (await asso.get(_serveur)).data()?['code'] as String?;
    await _db.runTransaction((t) async {
      t.update(asso, {'suppression': true});
    });
    for (final e in (await asso.collection('evenements').get(_serveur)).docs) {
      for (final c in (await e.reference.collection('caisses').get(_serveur)).docs) {
        await _effacerCollection(c.reference.collection('ventes'));
        await c.reference.delete();
      }
      for (final g in (await e.reference.collection('gymnases').get(_serveur)).docs) {
        await _effacerCollection(g.reference.collection('stocks'));
        await g.reference.delete();
      }
      await _effacerCollection(e.reference.collection('ouvertes'));
      await _effacerCollection(e.reference.collection('rattachements'));
      await _effacerCollection(e.reference.collection('produits'));
      await e.reference.delete();
    }
    for (final m in (await asso.collection('menus').get(_serveur)).docs) {
      await _effacerCollection(m.reference.collection('produits'));
      await m.reference.delete();
    }
    // Les membres en dernier, lus UNE seule fois : dès que le responsable n'est plus
    // membre, il ne peut plus relire cette liste (il lui reste le droit d'effacer).
    final membres = (await asso.collection('membres').get(_serveur)).docs;
    for (var i = 0; i < membres.length; i += 15) {
      final lot = _db.batch();
      for (final d in membres.skip(i).take(15)) {
        lot.delete(d.reference);
      }
      await lot.commit();
    }
    if (code != null && (await _code(code).get(_serveur)).exists) {
      await _code(code).delete();
    }
    await asso.delete();
  }

  /// Remplace le code : l'ancien cesse immédiatement de fonctionner.
  Future<String> regenererCode({
    required String assoId,
    required String ancienCode,
  }) async {
    final nouveau = await _codeLibre();
    final lot = _db.batch();
    lot.update(_asso(assoId), {'code': nouveau});
    lot.delete(_code(ancienCode));
    lot.set(_code(nouveau), {'assoId': assoId});
    await lot.commit();
    return nouveau;
  }
}
