import 'package:flutter/material.dart';

import 'champ_reglage.dart';
import 'courses.dart' show joursMax, personnesMax;
import 'evenement.dart';
import 'gymnase.dart';

/// Écran « Personnes et durée » (mission « Ergonomie de la gestion », E5, décision 55).
/// Ouvert par la tâche « Personnes et durée » d'Avant. La durée de l'événement et les
/// personnes attendues de chaque gymnase, avec le total. Les courses les lisent sans les
/// régler. Seuls le responsable et le gestionnaire rattaché à tous les gymnases les règlent
/// (comme les règles d'accès) ; les autres, et tout événement clôturé, les lisent.
class EcranPersonnesDuree extends StatelessWidget {
  const EcranPersonnesDuree({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.definirJours,
    required this.definirPersonnes,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;

  /// Tous les gymnases de l'événement ; l'écran ne montre que ceux de la portée.
  final Stream<List<Gymnase>> gymnases;
  final Future<void> Function(double jours) definirJours;
  final Future<void> Function(String gymnaseId, int personnes) definirPersonnes;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: evenement,
      builder: (context, sEv) => StreamBuilder<List<Gymnase>>(
        stream: gymnases,
        builder: (context, sG) {
          final ev = sEv.data;
          final tous = sG.data;
          return Scaffold(
            appBar: AppBar(title: const Text('Personnes et durée')),
            body: ev == null || tous == null
                ? const Center(child: CircularProgressIndicator())
                : _corps(context, ev, tous),
          );
        },
      ),
    );
  }

  Widget _corps(BuildContext context, Evenement ev, List<Gymnase> tous) {
    final reglable = portee.toutVoir && !ev.cloture;
    final visibles = [
      for (final g in tous)
        if (portee.gere(g.id)) g,
    ];
    final total = tous.fold<int>(0, (s, g) => s + g.personnes);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          reglable
              ? 'Combien de personnes sont attendues dans chaque gymnase, et '
                  'combien de jours dure l\'événement ? Les courses s\'en servent.'
              : ev.cloture
                  ? 'L\'événement est clôturé : ces réglages se lisent seulement.'
                  : 'Seul le responsable, ou un gestionnaire rattaché à tous les '
                      'gymnases, règle les personnes et la durée.',
          key: const Key('aide_personnes_duree'),
        ),
        const SizedBox(height: 12),
        Text(
          'Total de l\'événement : $total personne${total > 1 ? 's' : ''}',
          key: const Key('total_personnes'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ChampReglage<double>(
              id: 'duree',
              etiquette: 'Durée de l\'événement (jours)',
              messageErreur: 'Entrez une durée de 0,5 à $joursMax jours.',
              valeur: ev.nbJours,
              reglable: reglable,
              lire: lireJours,
              afficher: afficherJours,
              enregistrer: definirJours,
            ),
          ),
        ),
        for (final g in visibles)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ChampReglage<int>(
                id: 'personnes_${g.id}',
                etiquette: visibles.length > 1
                    ? 'Personnes attendues : ${g.nom}'
                    : 'Personnes attendues',
                messageErreur:
                    'Entrez un nombre entier de personnes de 0 à $personnesMax.',
                valeur: g.personnes,
                reglable: reglable,
                lire: lirePersonnes,
                afficher: (n) => '$n',
                enregistrer: (n) => definirPersonnes(g.id, n),
              ),
            ),
          ),
      ],
    );
  }
}
