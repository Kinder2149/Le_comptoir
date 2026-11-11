import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'classeur.dart';
import 'depot_associations.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'courses.dart';
import 'depot_menus.dart';
import 'ecran_comparateur.dart';
import 'ecran_import.dart';
import 'evenement.dart';
import 'export_bilan.dart';
import 'gymnase.dart';
import 'partage.dart';
import 'theme.dart';

/// Ce qu'on lit d'un tournoi clôturé selon la portée de la personne : la lecture de
/// l'export (F5) et celle du comparateur (F6) sont la même.
class DonneesTournoi {
  const DonneesTournoi({
    required this.evenement,
    required this.produits,
    required this.gymnases,
    required this.stocksReference,
    required this.stocks,
    required this.tableau,
    required this.courses,
    required this.apports,
    required this.portee,
  });

  final Evenement evenement;
  final List<ProduitEvenement> produits;

  /// Les gymnases que la personne gère (tous, pour le responsable).
  final List<Gymnase> gymnases;
  final Map<String, Map<String, int>> stocksReference;
  final Map<String, Map<String, int>> stocks;
  final TableauDeBord tableau;

  /// Null quand la personne n'a pas accès à tout l'événement (pas de courses).
  final ListeCourses? courses;
  final List<Apport> apports;
  final PorteeGestion portee;
}

/// La portée de la personne sur un tournoi : tout pour le responsable, ses gymnases sinon.
Future<PorteeGestion> porteeDe({
  required DepotEvenements depot,
  required Evenement evenement,
  required String uid,
  required bool responsable,
}) async {
  final mesGymnases = responsable
      ? const <String>{}
      : await depot.suivreMesGymnases(evenement.id, uid).first;
  return PorteeGestion(
    responsable: responsable,
    gymnases: mesGymnases,
    nbGymnases: evenement.nbGymnases,
  );
}

/// Lit un tournoi comme l'écran Après (EcranBilan) : mêmes données, même portée. Un
/// gestionnaire limité n'a que ses gymnases (et pas les courses, qui concernent tout
/// l'événement).
Future<DonneesTournoi> lireTournoi({
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
  return DonneesTournoi(
    evenement: evenement,
    produits: produits,
    gymnases: gymnases,
    stocksReference: reference,
    stocks: stocks,
    tableau: tableau,
    courses: courses,
    apports: [
      for (final a in tousApports)
        if (visibles.contains(a.gymnaseId)) a
    ],
    portee: portee,
  );
}

/// Le classeur d'un tournoi clôturé, comme le bouton d'export de l'onglet Après.
Future<Uint8List> construireExportTournoi({
  required DepotEvenements depot,
  required Evenement evenement,
  required PorteeGestion portee,
}) async {
  final d = await lireTournoi(depot: depot, evenement: evenement, portee: portee);
  return construireExport(
    evenement: d.evenement,
    produits: d.produits,
    gymnases: d.gymnases,
    stocksReference: d.stocksReference,
    stocksActuels: d.stocks,
    tableau: d.tableau,
    courses: d.courses,
    coursesVisibles: d.portee.toutVoir,
    limite: !d.portee.toutVoir,
    apports: d.apports,
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
        final octets = await construireModeleVierge();
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
        final portee = await porteeDe(
          depot: dev,
          evenement: ev,
          uid: widget.uid,
          responsable: widget.responsable,
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
          StreamBuilder<List<Evenement>>(
            stream: widget.depot
                .evenements(widget.assoId)
                .suivreEvenements(enCoursSeulement: false),
            builder: (context, s) {
              final clotures = [
                for (final e in s.data ?? const <Evenement>[])
                  if (e.cloture) e
              ];
              final assez = clotures.length >= 2;
              return _Carte(
                cle: const Key('carte_comparateur'),
                titre: 'Comparer deux tournois',
                texte: 'Deux tournois clôturés côte à côte : personnes, ventes, '
                    'résultat, puis chaque produit. Export en Excel possible.',
                enfant: OutlinedButton.icon(
                  key: const Key('comparateur'),
                  style: TypeAction.gerer.contour,
                  onPressed: _occupe || !assez
                      ? null
                      : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => EcranComparateur(
                                depot: widget.depot.evenements(widget.assoId),
                                uid: widget.uid,
                                responsable: widget.responsable,
                                tournois: clotures,
                                partager: widget.partager,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(assez
                      ? 'Comparer deux tournois'
                      : 'Il faut deux tournois clôturés'),
                ),
                titreStyle: titre,
              );
            },
          ),
          _Carte(
            cle: const Key('carte_import'),
            titre: 'Importer',
            texte: 'Un assistant pour importer un classeur : le menu, les anciens '
                'tournois (références de prévision) et, si vous le voulez, le stock de '
                'départ d\'un tournoi en préparation. Un résumé s\'affiche avant toute '
                'écriture.',
            enfant: OutlinedButton.icon(
              key: const Key('importer'),
              style: TypeAction.gerer.contour,
              onPressed: _occupe
                  ? null
                  : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => EcranImport(
                            sources: SourcesImport.depuis(
                              menus: widget.depot.menus(widget.assoId),
                              evenements: widget.depot.evenements(widget.assoId),
                              uid: widget.uid,
                              responsable: widget.responsable,
                            ),
                          ),
                        ),
                      ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Importer'),
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
