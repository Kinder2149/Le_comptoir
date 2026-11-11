import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'classeur.dart';
import 'depot_associations.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart';
import 'evenement.dart';
import 'export_bilan.dart';
import 'gymnase.dart';
import 'partage.dart';
import 'theme.dart';

/// Le classeur d'un tournoi clôturé, lu comme l'écran Après (EcranBilan) : mêmes données,
/// même portée. Un gestionnaire limité n'a que ses gymnases (et pas les courses, qui
/// concernent tout l'événement). Le classeur est construit par [construireExport], comme
/// le bouton d'export de l'onglet Après.
Future<Uint8List> construireExportTournoi({
  required DepotEvenements depot,
  required Evenement evenement,
  required PorteeGestion portee,
}) async {
  final id = evenement.id;
  final filtre = portee.filtre;
  // Relit le serveur d'abord (comme « glisser pour actualiser ») : les lectures qui suivent
  // partent alors d'une copie complète, et non d'une première valeur partielle.
  await depot.actualiser(id,
      gymnases: filtre, avecCourses: portee.toutVoir, avecApports: true);
  // Le tableau : chaque caisse et ses ventes, lus une fois (une requête complète chacune).
  // Le flux du tableau ne convient pas ici : sa première valeur peut ne pas avoir les ventes.
  final caisses = depot.caisses(id);
  final resumes = <ResumeCaisse>[];
  for (final c in await caisses.suivreCaisses(gymnaseIds: filtre).first) {
    resumes.add(ResumeCaisse(c, await caisses.suivreVentes(c.id).first));
  }
  final tableau = TableauDeBord.depuis(resumes);
  final produits = await depot.suivreProduits(id, gymnases: filtre).first;
  final tous = await depot.suivreGymnases(id).first;
  final gymnases = [
    for (final g in tous)
      if (portee.gere(g.id)) g
  ];
  final stocks = await depot.suivreStocksParGymnase(id, gymnases: filtre).first;
  final reference =
      await depot.suivreStocksReference(id, gymnases: filtre).first;
  final courses =
      portee.toutVoir ? await depot.suivreListeCourses(id).first : null;
  final tousApports = await depot.suivreApports(id).first;
  final visibles = {for (final g in gymnases) g.id};
  return construireExport(
    evenement: evenement,
    produits: produits,
    gymnases: gymnases,
    stocksReference: reference,
    stocksActuels: stocks,
    tableau: tableau,
    courses: courses,
    coursesVisibles: portee.toutVoir,
    limite: !portee.toutVoir,
    apports: [
      for (final a in tousApports)
        if (visibles.contains(a.gymnaseId)) a
    ],
  );
}

/// Écran « Extraction et modèle » (décision 72) : depuis l'écran de l'association, la gestion
/// télécharge le modèle vierge, les données d'un menu, l'export d'un tournoi clôturé et,
/// plus tard, le comparateur. Ouvert au responsable et aux gestionnaires seulement.
class EcranExtraction extends StatefulWidget {
  const EcranExtraction({
    super.key,
    required this.depot,
    required this.uid,
    required this.assoId,
    required this.responsable,
    this.partager = partagerFichier,
  });

  final DepotAssociations depot;
  final String uid;
  final String assoId;

  /// Responsable (tout voir) ou gestionnaire (ses gymnases seulement dans l'export).
  final bool responsable;

  /// Remise du fichier à la feuille de partage (remplaçable dans les tests).
  final PartageurOctets partager;

  @override
  State<EcranExtraction> createState() => _EtatExtraction();
}

class _EtatExtraction extends State<EcranExtraction> {
  bool _occupe = false;
  String? _erreur;
  String? _menuId;

  /// Lance une remise de fichier : une seule à la fois, erreur affichée si elle échoue.
  Future<void> _executer(Future<void> Function() action, String erreur) async {
    if (_occupe) return;
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _erreur = erreur);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _modeleVierge() => _executer(() async {
        final json = await rootBundle.loadString('assets/menu_type.json');
        final modele = lireMenuType(json);
        final produits = [
          for (final (i, p) in modele.indexed)
            ProduitEvenement('modele_$i', p.nom, p.prixCentimes, null,
                icone: p.icone, fiche: p.fiche),
        ];
        final octets = construireModele(
          produits: produits,
          gymnases: const [],
          stocks: const {},
        );
        await widget.partager('modele-vierge.xlsx', octets, typeMimeClasseur);
      }, 'Le modèle n\'a pas pu être préparé. Réessayez.');

  Future<void> _donneesDuMenu(Menu menu) => _executer(() async {
        final lus = await widget.depot.menus(widget.assoId).suivreProduits(menu.id).first;
        final octets = construireDonneesMenu(produits: [
          for (final p in lus)
            ProduitEvenement(p.id, p.nom, p.prixCentimes, null,
                icone: p.icone, photo: p.photo, fiche: p.fiche),
        ]);
        await widget.partager(
            'menu-${nomPourFichier(menu.nom)}.xlsx', octets, typeMimeClasseur);
      }, 'Le classeur du menu n\'a pas pu être préparé. Réessayez.');

  Future<void> _exporterTournoi(Evenement ev) => _executer(() async {
        final dev = widget.depot.evenements(widget.assoId);
        final mesGymnases = widget.responsable
            ? const <String>{}
            : await dev.suivreMesGymnases(ev.id, widget.uid).first;
        final portee = PorteeGestion(
          responsable: widget.responsable,
          gymnases: mesGymnases,
          nbGymnases: ev.nbGymnases,
        );
        final octets = await construireExportTournoi(
            depot: dev, evenement: ev, portee: portee);
        await widget.partager(nomFichierExport(ev), octets, typeMimeClasseur);
      }, 'Le tournoi n\'a pas pu être exporté. Vérifiez le réseau puis réessayez.');

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Extraction et modèle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Carte(
            cle: const Key('carte_modele_vierge'),
            titre: 'Modèle vierge',
            texte: 'Le classeur à remplir pour un nouveau menu : chaque feuille '
                'a un exemple et une explication.',
            enfant: OutlinedButton.icon(
              key: const Key('telecharger_modele_vierge'),
              style: TypeAction.gerer.contour,
              onPressed: _occupe ? null : _modeleVierge,
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le modèle'),
            ),
            titreStyle: titre,
          ),
          _Carte(
            cle: const Key('carte_donnees_association'),
            titre: 'Données de l\'association',
            texte: 'Un menu de l\'association en classeur : son menu, sa '
                'composition (recettes) et sa prévision.',
            enfant: StreamBuilder<List<Menu>>(
              stream: widget.depot.menus(widget.assoId).suivreMenus(),
              builder: (context, s) {
                final menus = s.data;
                if (menus == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (menus.isEmpty) {
                  return const Text('Aucun menu : créez-en un dans Menus.',
                      key: Key('aucun_menu_extraction'));
                }
                final choisi = menus.where((m) => m.id == _menuId).firstOrNull;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const Key('choix_menu'),
                      isExpanded: true,
                      initialValue: choisi?.id,
                      decoration: const InputDecoration(labelText: 'Menu'),
                      items: [
                        for (final m in menus)
                          DropdownMenuItem<String>(
                              key: Key('menu_${m.id}'),
                              value: m.id,
                              child: Text(m.nom)),
                      ],
                      onChanged: (v) => setState(() => _menuId = v),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('telecharger_donnees_menu'),
                      style: TypeAction.gerer.contour,
                      onPressed: _occupe || choisi == null
                          ? null
                          : () => _donneesDuMenu(choisi),
                      icon: const Icon(Icons.download),
                      label: const Text('Télécharger le classeur du menu'),
                    ),
                  ],
                );
              },
            ),
            titreStyle: titre,
          ),
          _Carte(
            cle: const Key('carte_export_tournoi'),
            titre: 'Export d\'un tournoi',
            texte: 'Un tournoi clôturé, en classeur complet : le même que '
                'l\'export de l\'onglet Après. Vos gymnases seulement si vous '
                'êtes gestionnaire limité.',
            enfant: StreamBuilder<List<Evenement>>(
              stream: widget.depot
                  .evenements(widget.assoId)
                  .suivreEvenements(enCoursSeulement: false),
              builder: (context, s) {
                final liste = s.data;
                if (liste == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final clotures = [
                  for (final e in liste)
                    if (e.cloture) e
                ];
                if (clotures.isEmpty) {
                  return const Text('Aucun tournoi clôturé.',
                      key: Key('aucun_tournoi'));
                }
                return Column(
                  children: [
                    for (final e in clotures)
                      ListTile(
                        key: Key('tournoi_${e.id}'),
                        contentPadding: EdgeInsets.zero,
                        enabled: !_occupe,
                        title: Text(e.nom),
                        subtitle: Text(dateAffichee(e.date)),
                        trailing: const Icon(Icons.ios_share),
                        onTap: () => _exporterTournoi(e),
                      ),
                  ],
                );
              },
            ),
            titreStyle: titre,
          ),
          _Carte(
            cle: const Key('carte_comparateur'),
            titre: 'Comparer deux tournois',
            texte: 'Deux tournois clôturés côte à côte. Bientôt disponible.',
            enfant: const OutlinedButton(
              key: Key('comparateur'),
              onPressed: null,
              child: Text('Comparer deux tournois'),
            ),
            titreStyle: titre,
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _erreur!,
                key: const Key('erreur_extraction'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une carte de l'écran : titre, phrase d'explication et l'action.
class _Carte extends StatelessWidget {
  const _Carte({
    required this.cle,
    required this.titre,
    required this.texte,
    required this.enfant,
    required this.titreStyle,
  });

  final Key cle;
  final String titre;
  final String texte;
  final Widget enfant;
  final TextStyle? titreStyle;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cle,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: titreStyle),
            const SizedBox(height: 4),
            Text(texte),
            const SizedBox(height: 12),
            enfant,
          ],
        ),
      ),
    );
  }
}
