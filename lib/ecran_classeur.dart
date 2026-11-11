import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'classeur.dart';
import 'evenement.dart';
import 'export_bilan.dart' show nomFichierModele;
import 'gymnase.dart';
import 'import_classeur.dart';
import 'partage.dart';
import 'resume_import.dart';
import 'selecteur.dart';
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
    required this.importer,
    this.partagerModele = partagerFichier,
    this.choisirClasseur = choisirClasseurSysteme,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;
  final Stream<List<Gymnase>> gymnases;
  final Stream<List<ProduitEvenement>> produits;

  /// Stock de départ : gymnase -> produit -> quantité (et marque « repris »).
  final Stream<Map<String, Map<String, StockDepart>>> stocks;

  /// Exécute un plan d'import (stocks de départ et références), après le résumé.
  final Future<void> Function(PlanImport plan) importer;

  /// Remet le modèle Excel à la feuille de partage (remplaçable dans les tests).
  final PartageurOctets partagerModele;

  /// Choisit le classeur à importer (remplaçable dans les tests).
  final SelecteurClasseur choisirClasseur;

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
                            choisir: choisirClasseur,
                            importer: importer,
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
    required this.choisir,
    required this.importer,
  });

  final Evenement evenement;

  /// Les gymnases de la portée de la personne (modèle) et tous ceux de l'événement (import).
  final List<Gymnase> gymnases;
  final List<Gymnase> tousGymnases;
  final PorteeGestion portee;
  final List<ProduitEvenement> produits;
  final Map<String, Map<String, StockDepart>> stocks;
  final PartageurOctets partager;
  final SelecteurClasseur choisir;
  final Future<void> Function(PlanImport plan) importer;

  @override
  State<_CarteClasseur> createState() => _EtatCarteClasseur();
}

class _EtatCarteClasseur extends State<_CarteClasseur> {
  bool _enCours = false;
  bool _importEnCours = false;

  /// Dernier résultat d'import : la phrase et si c'est une erreur.
  String? _resultat;
  bool _resultatErreur = false;

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

  void _dire(String phrase, {bool erreur = false}) {
    if (!mounted) return;
    setState(() {
      _resultat = phrase;
      _resultatErreur = erreur;
    });
  }

  Future<void> _importer() async {
    setState(() {
      _importEnCours = true;
      _resultat = null;
    });
    try {
      final Uint8List? octets;
      try {
        octets = await widget.choisir();
      } catch (_) {
        _dire('Le choix du fichier n\'a pas pu s\'ouvrir. Réessayez.', erreur: true);
        return;
      }
      if (octets == null) return; // annulé : rien ne change
      final ClasseurLu lu;
      try {
        lu = lireClasseur(octets);
      } on ClasseurIllisible {
        _dire(messageClasseurIllisible, erreur: true);
        return;
      }
      if (!lu.contenuUtile) {
        _dire(messageClasseurIllisible, erreur: true);
        return;
      }
      final plan = preparerImport(
        lu,
        tous: widget.tousGymnases,
        produits: widget.produits,
        portee: widget.portee,
        stockModifiable: widget.evenement.enPreparation,
      );
      if (!mounted) return;
      final accepte = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _EcranResumeImport(plan: plan)),
      );
      if (accepte != true) return;
      try {
        await widget.importer(plan);
        _dire(plan.phraseConfirmation);
      } catch (_) {
        _dire(
            'L\'import n\'a pas pu être terminé. Vérifiez le réseau puis réessayez : '
            'le rejouer est sans risque.',
            erreur: true);
      }
    } finally {
      if (mounted) setState(() => _importEnCours = false);
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
            if (!widget.evenement.cloture) ...[
              const SizedBox(height: 8),
              const Text(
                'Importez le classeur rempli : son stock de départ s\'applique à '
                'cet événement et son historique devient une source de prévision. '
                'Un résumé s\'affiche avant toute écriture.',
                key: Key('aide_import'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('importer_classeur'),
                style: TypeAction.gerer.contour,
                onPressed: _importEnCours ? null : _importer,
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer un classeur'),
              ),
            ],
            if (_resultat != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _resultat!,
                  key: Key(_resultatErreur ? 'erreur_import' : 'confirmation_import'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _resultatErreur ? Palette.ocreFonce : Palette.anthracite,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le résumé d'un import dans la Préparation (voir [EcranResumeImport]) : stocks appliqués
/// et références créées.
class _EcranResumeImport extends StatelessWidget {
  const _EcranResumeImport({required this.plan});

  final PlanImport plan;

  @override
  Widget build(BuildContext context) {
    return EcranResumeImport(
      titre: 'Résumé de l\'import',
      cleAppliquer: const Key('appliquer_import'),
      libelleAppliquer: 'Appliquer',
      ignorees: plan.ignorees,
      erreurs: plan.erreurs,
      corps: [
        Text(plan.phraseStocks,
            key: const Key('resume_stocks'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (plan.references.isEmpty)
          const Text('Aucune référence de consommation ne sera créée.',
              key: Key('resume_aucune_reference'))
        else
          for (final (i, phrase) in plan.phrasesReferences.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(phrase,
                  key: Key('resume_reference_$i'),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
        if (plan.menuIgnore)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
                'La feuille Menu est ignorée ici : elle s\'importe depuis l\'écran Menus.',
                key: Key('resume_menu_ignore')),
          ),
      ],
    );
  }
}
