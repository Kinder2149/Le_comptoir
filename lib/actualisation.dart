import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// « Glisser vers le bas pour actualiser » (mission Retours du terrain, F2, décision 70).
// Les écrans restent en direct ; le geste relit en plus les données sur le serveur
// et les affiche. Hors réseau, il ne bloque rien et le dit en clair.
// Mission T6 (décision 79 b) : sous le titre, une ligne « Actualisé le JJ/MM à HH:MM »,
// mise à jour à chaque actualisation réussie ; hors réseau, elle ne change pas.

const messageHorsReseau =
    'Hors réseau : affichage des dernières données reçues';
const messageActualisationImpossible =
    "Actualisation impossible pour l'instant. Réessayez.";

/// Délai après lequel on considère qu'il n'y a pas de réseau.
const delaiActualisation = Duration(seconds: 10);

/// Lance [relire] (lectures sur le serveur) puis, si elle échoue, dit pourquoi dans un
/// message court. Ne lève jamais d'erreur : le geste se termine toujours.
/// Renvoie vrai si la relecture a réussi, faux sinon.
Future<bool> actualiserEcran(
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
  return message == null;
}

/// Libellé de la ligne d'heure, au format français : « Actualisé le 11/11 à 09:05 ».
String libelleActualisation(DateTime d) {
  String deux(int n) => n.toString().padLeft(2, '0');
  return 'Actualisé le ${deux(d.day)}/${deux(d.month)} à '
      '${deux(d.hour)}:${deux(d.minute)}';
}

/// Ajoute « glisser vers le bas pour actualiser » à une liste. Sans [relire], la liste
/// est rendue telle quelle.
Widget actualisable({
  required Future<void> Function()? relire,
  required Widget child,
}) =>
    relire == null ? child : Actualisable(relire: relire, child: child);

class Actualisable extends StatefulWidget {
  const Actualisable({
    super.key,
    required this.relire,
    required this.child,
    this.horloge,
  });

  final Future<void> Function() relire;

  /// Une liste qui défile toujours (`AlwaysScrollableScrollPhysics`), même courte.
  final Widget child;

  /// Heure courante ; injectable pour les tests.
  final DateTime Function()? horloge;

  @override
  State<Actualisable> createState() => _EtatActualisable();
}

class _EtatActualisable extends State<Actualisable> {
  late DateTime _derniere;

  DateTime _maintenant() => (widget.horloge ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // Les écrans sont en direct : à l'ouverture, les données sont celles de cet instant.
    _derniere = _maintenant();
  }

  Future<void> _actualiser() async {
    final reussi = await actualiserEcran(context, widget.relire);
    if (reussi && mounted) setState(() => _derniere = _maintenant());
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              libelleActualisation(_derniere),
              key: const Key('heure_actualisation'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _actualiser,
              child: widget.child,
            ),
          ),
        ],
      );
}
