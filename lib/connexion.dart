import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Obtient les identifiants Google de l'utilisateur (fenêtre Google), ou
/// null s'il annule. Remplaçable dans les tests.
typedef FournisseurGoogle = Future<AuthCredential?> Function();

/// Vrai fournisseur : fenêtre de choix du compte Google.
Future<AuthCredential?> fournisseurGoogleReel() async {
  final compte = await GoogleSignIn().signIn();
  if (compte == null) return null;
  final jetons = await compte.authentication;
  return GoogleAuthProvider.credential(
    idToken: jetons.idToken,
    accessToken: jetons.accessToken,
  );
}

/// Garantit qu'un utilisateur (anonyme au besoin) est connecté et renvoie
/// son identifiant. Réutilise la session existante : l'identifiant reste le
/// même d'un lancement à l'autre.
Future<String> assurerConnexion(FirebaseAuth auth) async {
  final utilisateur =
      auth.currentUser ?? (await auth.signInAnonymously()).user;
  if (utilisateur == null) {
    throw StateError('Connexion anonyme refusée.');
  }
  return utilisateur.uid;
}

bool aGoogle(User? u) =>
    u != null && u.providerData.any((p) => p.providerId == 'google.com');

/// Connecte l'appareil avec Google.
/// - Appareil anonyme et compte Google neuf : le compte Google est rattaché
///   à l'identifiant actuel (rien n'est perdu).
/// - Compte Google déjà connu (autre téléphone, réinstallation) : on
///   retrouve ce compte, donc son association.
/// Renvoie false si l'utilisateur annule.
Future<bool> connecterGoogle(
  FirebaseAuth auth,
  FournisseurGoogle fournisseur,
) async {
  final identifiants = await fournisseur();
  if (identifiants == null) return false;
  final actuel = auth.currentUser;
  if (actuel == null) {
    await auth.signInWithCredential(identifiants);
  } else if (!aGoogle(actuel)) {
    try {
      await actuel.linkWithCredential(identifiants);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') rethrow;
      await auth.signInWithCredential(e.credential ?? identifiants);
    }
  }
  // Le jeton doit refléter le compte Google pour les règles d'accès.
  await auth.currentUser?.getIdToken(true);
  return true;
}
