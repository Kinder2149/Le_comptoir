import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// « Glisser vers le bas pour actualiser » (mission Retours du terrain, F2, décision 70).
// Les écrans restent en direct ; le geste relit en plus les données sur le serveur
// et les affiche. Hors réseau, il ne bloque rien et le dit en clair.

const messageHorsReseau =
    'Hors réseau : affichage des dernières données reçues';
const messageActualisationImpossible =
    "Actualisation impossible pour l'instant. Réessayez.";

/// Délai après lequel on considère qu'il n'y a pas de réseau.
const delaiActualisation = Duration(seconds: 10);

/// Lance [relire] (lectures sur le serveur) puis, si elle échoue, dit pourquoi dans un
/// message court. Ne lève jamais d'erreur : le geste se termine toujours.
Future<void> actualiserEcran(
  BuildContext context,
  Future<void> Function() relire, {
  Duration delai = delaiActualisation,
}) async {
  final messager = ScaffoldMessenger.maybeOf(context);
  String? message;
  try {
    await relire().timeout(delai);
  } on TimeoutException {
    message = messageHorsReseau;
  } on FirebaseException catch (e) {
    message = e.code == 'unavailable'
        ? messageHorsReseau
        : messageActualisationImpossible;
  } catch (_) {
    message = messageActualisationImpossible;
  }
  if (message != null && messager != null) {
    messager
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, key: const Key('message_actualisation')),
      ));
  }
}

/// Ajoute « glisser vers le bas pour actualiser » à une liste. Sans [relire], la liste
/// est rendue telle quelle.
Widget actualisable({
  required Future<void> Function()? relire,
  required Widget child,
}) =>
    relire == null ? child : Actualisable(relire: relire, child: child);

class Actualisable extends StatelessWidget {
  const Actualisable({super.key, required this.relire, required this.child});

  final Future<void> Function() relire;

  /// Une liste qui défile toujours (`AlwaysScrollableScrollPhysics`), même courte.
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => actualiserEcran(context, relire),
        child: child,
      );
}
