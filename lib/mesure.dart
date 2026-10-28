import 'package:cloud_firestore/cloud_firestore.dart';

// Mesure des lectures Firestore (chantier Stock et courses, étape 8). Le quota
// gratuit est de 50 000 lectures par jour : on compte les documents reçus du serveur
// par chaque écoute en direct. En production [surLecture] reste null : rien n'est compté.

/// Appelée avec le nom de l'écoute et le nombre de documents lus.
void Function(String source, int documents)? surLecture;

/// Un document reçu du serveur (ni lu dans le cache, ni écrit par ce téléphone).
bool _lectureServeur(DocumentSnapshot<Map<String, dynamic>> d) =>
    !d.metadata.isFromCache && !d.metadata.hasPendingWrites;

extension MesureRequete on Stream<QuerySnapshot<Map<String, dynamic>>> {
  /// Compte les documents lus par cette écoute, sous le nom [source].
  Stream<QuerySnapshot<Map<String, dynamic>>> compte(String source) =>
      map((s) {
        final f = surLecture;
        if (f != null) {
          f(source, s.docChanges.where((c) => _lectureServeur(c.doc)).length);
        }
        return s;
      });
}

extension MesureDocument on Stream<DocumentSnapshot<Map<String, dynamic>>> {
  Stream<DocumentSnapshot<Map<String, dynamic>>> compte(String source) =>
      map((d) {
        final f = surLecture;
        if (f != null && _lectureServeur(d)) f(source, 1);
        return d;
      });
}
