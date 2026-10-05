import 'dart:math';

/// Sans 0/O et 1/I/L pour éviter les confusions à la saisie.
const alphabetCode = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const longueurCode = 6;

String genererCode([Random? hasard]) {
  final r = hasard ?? Random.secure();
  return List.generate(
    longueurCode,
    (_) => alphabetCode[r.nextInt(alphabetCode.length)],
  ).join();
}

/// Ce que l'utilisateur a tapé -> forme comparable (majuscules, sans espaces).
String normaliserCode(String saisie) =>
    saisie.replaceAll(RegExp(r'\s+'), '').toUpperCase();

bool codeBienForme(String code) =>
    code.length == longueurCode &&
    code.split('').every(alphabetCode.contains);

/// Confirmation d'une suppression : on doit retaper le nom de l'association
/// (sans tenir compte des majuscules ni des espaces autour).
bool confirmationSuppression(String saisie, String nom) {
  final attendu = nom.trim().toLowerCase();
  return attendu.isNotEmpty && saisie.trim().toLowerCase() == attendu;
}
