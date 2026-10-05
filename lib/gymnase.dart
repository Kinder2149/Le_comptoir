/// Un gymnase : un lieu de vente d'un événement, avec son propre stock.
class Gymnase {
  const Gymnase(this.id, this.nom);

  final String id;
  final String nom;
}

/// Nom du gymnase créé automatiquement avec un événement.
const nomGymnaseParDefaut = 'Principal';

/// Séparateur de l'identifiant d'une caisse : « uid__gymnase ». Les identifiants
/// Firebase (membres) et Firestore (gymnases) sont alphanumériques : le séparateur
/// ne peut pas s'y trouver, et les règles d'accès relisent la caisse avec lui.
const separateurCaisse = '__';

/// Identifiant de la caisse d'un membre dans un gymnase.
String idCaisse(String uid, String gymnaseId) =>
    '$uid$separateurCaisse$gymnaseId';

/// Un identifiant de caisse lu : à qui elle est, dans quel gymnase.
class RefCaisse {
  const RefCaisse(this.uid, this.gymnaseId);

  final String uid;
  final String gymnaseId;

  /// Lit « uid__gymnase ». Lève [FormatException] si l'identifiant est mal formé
  /// (vide, sans gymnase, ou avec plus de deux parties).
  factory RefCaisse.lire(String id) {
    final morceaux = id.split(separateurCaisse);
    if (morceaux.length != 2 ||
        !_alphanumerique.hasMatch(morceaux[0]) ||
        !_alphanumerique.hasMatch(morceaux[1])) {
      throw FormatException('Identifiant de caisse invalide', id);
    }
    return RefCaisse(morceaux[0], morceaux[1]);
  }

  String get id => idCaisse(uid, gymnaseId);
}

final _alphanumerique = RegExp(r'^[A-Za-z0-9]+$');

/// Longueur maximale du nom d'un gymnase (la même limite que dans les règles).
const longueurMaxNomGymnase = 40;

/// Nombre maximal de gymnases par événement (la même limite que dans les règles).
const maxGymnases = 8;

/// Vérifie les noms de gymnases d'un événement : au moins un, tous remplis,
/// 40 caractères au plus, tous différents (sans tenir compte des majuscules).
/// Renvoie le message à afficher, ou null si tout est correct.
String? erreurNomsGymnases(Iterable<String> noms) {
  final propres = [for (final n in noms) n.trim()];
  if (propres.isEmpty) return 'Il faut au moins un gymnase.';
  if (propres.length > maxGymnases) {
    return '$maxGymnases gymnases au maximum par événement.';
  }
  if (propres.any((n) => n.isEmpty)) return 'Donnez un nom à chaque gymnase.';
  if (propres.any((n) => n.length > longueurMaxNomGymnase)) {
    return 'Un nom de gymnase fait $longueurMaxNomGymnase caractères au maximum.';
  }
  final vus = <String>{};
  for (final n in propres) {
    if (!vus.add(n.toLowerCase())) {
      return 'Deux gymnases ne peuvent pas porter le même nom.';
    }
  }
  return null;
}

/// Ce qu'un membre de la gestion peut voir et faire sur un événement : le
/// responsable gère tous les gymnases ; un gestionnaire seulement ceux auxquels
/// le responsable l'a rattaché.
class PorteeGestion {
  const PorteeGestion({
    required this.responsable,
    required this.gymnases,
    required this.nbGymnases,
  });

  final bool responsable;

  /// Gymnases du gestionnaire (sans objet pour le responsable).
  final Set<String> gymnases;

  /// Nombre de gymnases de l'événement.
  final int nbGymnases;

  /// Peut-il voir et corriger les ventes et le stock de ce gymnase ?
  bool gere(String gymnaseId) => responsable || gymnases.contains(gymnaseId);

  /// Voit-il tout l'événement (suivi, bilan commun, clôture) ?
  bool get toutVoir => responsable || gymnases.length >= nbGymnases;

  /// Aucun gymnase : un gestionnaire non rattaché ne voit aucune vente.
  bool get aucun => !responsable && gymnases.isEmpty;

  /// Gymnases à interroger : null = tous (une seule requête, sans filtre).
  Set<String>? get filtre => responsable ? null : gymnases;
}

/// Valeur du segment « Commun » dans le sélecteur de vue.
const vueCommune = '*';

/// Vue (distincte ou commune) proposée au départ : la commune si elle est
/// offerte, sinon le premier gymnase. null = vue commune.
String? vueParDefaut({required bool commun, required List<Gymnase> gymnases}) =>
    commun ? null : gymnases.firstOrNull?.id;

/// La vue choisie existe-t-elle encore parmi celles qu'on propose ?
bool vueValide(String? vue,
        {required bool commun, required List<Gymnase> gymnases}) =>
    vue == null ? commun : gymnases.any((g) => g.id == vue);

/// « (Gymnase A : 4 · Gymnase B : 3) » : le stock de chaque gymnase, dans l'ordre
/// des gymnases ; vide s'il n'y a rien à détailler.
String detailStockAffiche(Map<String, int> detail, List<Gymnase> gymnases) {
  final morceaux = [
    for (final g in gymnases)
      if (detail.containsKey(g.id)) '${g.nom} : ${detail[g.id]}',
  ];
  return morceaux.isEmpty ? '' : '(${morceaux.join(' · ')})';
}

/// Ce que contient le QR code d'un gymnase : l'association (par son code d'accès),
/// l'événement et le gymnase.
class LienGymnase {
  const LienGymnase(this.codeAssociation, this.evenementId, this.gymnaseId);

  final String codeAssociation;
  final String evenementId;
  final String gymnaseId;

  @override
  bool operator ==(Object other) =>
      other is LienGymnase &&
      other.codeAssociation == codeAssociation &&
      other.evenementId == evenementId &&
      other.gymnaseId == gymnaseId;

  @override
  int get hashCode => Object.hash(codeAssociation, evenementId, gymnaseId);
}

/// Version actuelle du contenu des QR codes (pour pouvoir le faire évoluer).
const versionLien = '1';

/// Le texte du QR code d'un gymnase :
/// `lecomptoir://rejoindre?v=1&c=<code>&e=<événement>&g=<gymnase>`.
String ecrireLienGymnase(LienGymnase lien) => Uri(
      scheme: 'lecomptoir',
      host: 'rejoindre',
      queryParameters: {
        'v': versionLien,
        'c': lien.codeAssociation,
        'e': lien.evenementId,
        'g': lien.gymnaseId,
      },
    ).toString();

final _codeLien = RegExp(r'^[A-Z0-9]{6}$');
final _idLien = RegExp(r'^[A-Za-z0-9]{1,40}$');

/// Lit le texte d'un QR code. Lève [FormatException] si ce n'est pas un QR code du
/// Comptoir, d'une autre version, ou si un champ est absent ou mal formé.
LienGymnase lireLienGymnase(String texte) {
  final Uri uri;
  try {
    uri = Uri.parse(texte.trim());
  } on FormatException {
    throw FormatException('Lien illisible', texte);
  }
  final q = uri.queryParameters;
  final c = (q['c'] ?? '').toUpperCase();
  final e = q['e'] ?? '';
  final g = q['g'] ?? '';
  if (uri.scheme != 'lecomptoir' ||
      uri.host != 'rejoindre' ||
      q['v'] != versionLien ||
      !_codeLien.hasMatch(c) ||
      !_idLien.hasMatch(e) ||
      !_idLien.hasMatch(g)) {
    throw FormatException('Ce n\u2019est pas un QR code du Comptoir', texte);
  }
  return LienGymnase(c, e, g);
}
