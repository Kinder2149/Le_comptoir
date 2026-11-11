import 'dart:async';

import 'package:flutter/material.dart';

import 'classeur.dart' show construireModele, typeMimeClasseur;
import 'evenement.dart';
import 'export_bilan.dart' show nomFichierModele;
import 'gymnase.dart';
import 'partage.dart';
import 'theme.dart';

/// Écran « Classeur Excel » (mission « Ergonomie de la gestion », E5) : le modèle à
/// télécharger et le classeur rempli à importer. Ouvert par le bouton « Excel » de
/// l'événement (la Préparation n'existe plus). Son fonctionnement ne change pas.
class EcranClasseur extends StatelessWidget {
  const EcranClasseur({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.produits,
    required this.stocks,
    this.assistant,
    this.partagerModele = partagerFichier,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<ProduitEvenement>> produits;

  /// Stock de départ : gymnase -> produit -> quantité (et marque « repris »).
  final Stream<Map<String, Map<String, StockDepart>>> stocks;

  /// L'assistant d'import (T2, décision 77), avec le tournoi déjà choisi : « Importer un
  /// classeur » y renvoie. Absent : pas de bouton d'import.
  final WidgetBuilder? assistant;

  /// Remet le modèle Excel à la feuille de partage (remplaçable dans les tests).
  final PartageurOctets partagerModele;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: evenement,
      builder: (context, sEv) => StreamBuilder<List<Gymnase>>(
        stream: gymnases,
        builder: (context, sG) => StreamBuilder<List<ProduitEvenement>>(
          stream: produits,
          builder: (context, sP) =>
              StreamBuilder<Map<String, Map<String, StockDepart>>>(
            stream: stocks,
            builder: (context, sS) {
              final ev = sEv.data;
              final tous = sG.data;
              final liste = sP.data;
              final stock = sS.data;
              final charge =
                  ev != null && tous != null && liste != null && stock != null;
              return Scaffold(
                appBar: AppBar(title: const Text('Classeur Excel')),
                body: !charge
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _CarteClasseur(
                            evenement: ev,
                            gymnases: [
                              for (final g in tous)
                                if (portee.gere(g.id)) g
                            ],
                            tousGymnases: tous,
                            portee: portee,
                            produits: liste,
                            stocks: stock,
                            partager: partagerModele,
                            assistant: assistant,
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Le classeur Excel de l'événement : télécharger le modèle (menu et stock de départ
/// remplis, remis à la feuille de partage d'Android) et importer un classeur rempli
/// (stock de départ et références de consommation, après un résumé).
class _CarteClasseur extends StatefulWidget {
  const _CarteClasseur({
    required this.evenement,
    required this.gymnases,
    required this.tousGymnases,
    required this.portee,
    required this.produits,
    required this.stocks,
    required this.partager,
    required this.assistant,
  });

  final Evenement evenement;

  /// Les gymnases de la portée de la personne (modèle) et tous ceux de l'événement (import).
  final List<Gymnase> gymnases;
  final List<Gymnase> tousGymnases;
  final PorteeGestion portee;
  final List<ProduitEvenement> produits;
  final Map<String, Map<String, StockDepart>> stocks;
  final PartageurOctets partager;
  final WidgetBuilder? assistant;

  @override
  State<_CarteClasseur> createState() => _EtatCarteClasseur();
}

class _EtatCarteClasseur extends State<_CarteClasseur> {
  bool _enCours = false;

  Future<void> _telecharger() async {
    setState(() => _enCours = true);
    try {
      final octets = construireModele(
        produits: widget.produits,
        gymnases: widget.gymnases,
        stocks: widget.stocks,
      );
      await widget.partager(
          nomFichierModele(widget.evenement), octets, typeMimeClasseur);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Le partage n\'a pas pu s\'ouvrir. Réessayez.',
              key: Key('erreur_partage_modele')),
        ));
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Classeur Excel',
                key: const Key('titre_classeur'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Téléchargez le modèle : il contient le menu et le stock de départ '
              'de cet événement. Remplissez-le avec les chiffres de l\'an passé.',
              key: Key('aide_classeur'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('telecharger_modele'),
              style: TypeAction.gerer.contour,
              onPressed: _enCours ? null : _telecharger,
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le modèle Excel'),
            ),
            if (!widget.evenement.cloture && widget.assistant != null) ...[
              const SizedBox(height: 8),
              const Text(
                'L\'assistant d\'import lit le classeur rempli : son menu, son '
                'historique (références de prévision) et son stock de départ, qui '
                's\'applique à cet événement. Un résumé s\'affiche avant toute écriture.',
                key: Key('aide_import'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('importer_classeur'),
                style: TypeAction.gerer.contour,
                onPressed: () => Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: widget.assistant!)),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer un classeur'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
