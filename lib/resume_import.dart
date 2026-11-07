import 'package:flutter/material.dart';

import 'theme.dart';

/// Le résumé d'un import Excel, montré AVANT toute écriture (P6 : stock et références ;
/// P7 : menu). [corps] = les phrases propres à l'import ; viennent ensuite les lignes
/// ignorées avec leur raison et les problèmes de lecture (repliés au-delà de 10 lignes).
/// Le bouton d'application rend vrai ; « Annuler » (ou retour) rend faux : rien n'est écrit.
class EcranResumeImport extends StatelessWidget {
  const EcranResumeImport({
    super.key,
    required this.titre,
    required this.corps,
    required this.ignorees,
    required this.erreurs,
    required this.cleAppliquer,
    required this.libelleAppliquer,
    this.cleAnnuler = const Key('annuler_import'),
  });

  final String titre;
  final List<Widget> corps;
  final List<String> ignorees;
  final List<String> erreurs;
  final Key cleAppliquer;
  final String libelleAppliquer;
  final Key cleAnnuler;

  /// Au-delà de ce nombre, une liste est repliée.
  static const _seuil = 10;

  Widget _liste(BuildContext context, String titre, List<String> lignes, String cle) {
    if (lignes.isEmpty) return const SizedBox.shrink();
    final contenu = [for (final l in lignes) Text('• $l')];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: lignes.length <= _seuil
          ? Column(
              key: Key(cle),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                ...contenu,
              ],
            )
          : ExpansionTile(
              key: Key(cle),
              tilePadding: EdgeInsets.zero,
              title: Text('$titre (${lignes.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: contenu,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: ListView(
        key: const Key('resume_import'),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Rien n\'est écrit tant que vous n\'avez pas touché '
              '« Appliquer » ou « Créer le menu ».'),
          const SizedBox(height: 12),
          ...corps,
          _liste(context, 'Lignes ignorées', ignorees, 'resume_ignorees'),
          _liste(context, 'Problèmes de lecture', erreurs, 'resume_erreurs'),
          const SizedBox(height: 24),
          FilledButton(
            key: cleAppliquer,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(libelleAppliquer),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: cleAnnuler,
            style: TypeAction.gerer.contour,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
