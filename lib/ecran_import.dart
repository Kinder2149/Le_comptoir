import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LengthLimitingTextInputFormatter, rootBundle;

import 'classeur.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart';
import 'ecran_extraction.dart' show porteeDe;
import 'evenement.dart';
import 'import_assistant.dart';
import 'import_classeur.dart';
import 'import_menu.dart';
import 'partage.dart';
import 'previsions.dart';
import 'resume_import.dart';
import 'selecteur.dart';
import 'theme.dart';

/// Le modèle vierge (menu type, sans gymnase ni stock) : le même classeur pour
/// « Extraction et modèle » et pour l'assistant d'import.
Future<Uint8List> construireModeleVierge() async {
  final json = await rootBundle.loadString('assets/menu_type.json');
  final modele = lireMenuType(json);
  final produits = [
    for (final (i, p) in modele.indexed)
      ProduitEvenement('modele_$i', p.nom, p.prixCentimes, null,
          icone: p.icone, fiche: p.fiche),
  ];
  return construireModele(produits: produits, gymnases: const [], stocks: const {});
}

/// Tout ce que l'assistant lit et écrit, par les méthodes existantes des dépôts
/// (remplaçable dans les tests).
class SourcesImport {
  const SourcesImport({
    required this.menus,
    required this.nomsProduits,
    required this.creerMenu,
    required this.tournois,
    required this.contexte,
    required this.appliquerImport,
    required this.appliquerReference,
  });

  /// Les dépôts réels de l'association.
  factory SourcesImport.depuis({
    required DepotMenus menus,
    required DepotEvenements evenements,
    required String uid,
    required bool responsable,
  }) =>
      SourcesImport(
        menus: () => menus.suivreMenus().first,
        nomsProduits: (id) async =>
            [for (final p in await menus.suivreProduits(id).first) p.nom],
        creerMenu: menus.creerMenuDepuisClasseur,
        tournois: evenements.suivreEvenements(enCoursSeulement: false),
        contexte: (ev) async => ContexteTournoi(
          gymnases: await evenements.suivreGymnases(ev.id).first,
          produits: await evenements.suivreProduits(ev.id).first,
          portee: await porteeDe(
              depot: evenements, evenement: ev, uid: uid, responsable: responsable),
        ),
        appliquerImport: evenements.appliquerImport,
        appliquerReference: evenements.appliquerReference,
      );

  final Future<List<Menu>> Function() menus;
  final Future<List<String>> Function(String menuId) nomsProduits;
  final Future<String> Function(String nom, List<ProduitModele> produits) creerMenu;

  /// Tous les événements ; l'assistant ne propose que ceux en préparation.
  final Stream<List<Evenement>> tournois;
  final Future<ContexteTournoi> Function(Evenement tournoi) contexte;
  final Future<void> Function(String? evenementId, PlanImport plan) appliquerImport;
  final Future<void> Function(String evenementId, ReferenceImportee reference)
      appliquerReference;
}

/// L'assistant d'import unique (décision 77) : départ (modèle ou classeur) -> menu ->
/// tournoi en préparation (facultatif) -> résumé complet AVANT toute écriture ->
/// « Appliquer ». Ouvert par « Extraction et modèle » (gestion seulement), par
/// « Importer un menu depuis Excel » et par « Importer un classeur » (tournoi déjà choisi).
class EcranImport extends StatefulWidget {
  const EcranImport({
    super.key,
    required this.sources,
    this.evenementId,
    this.menuPropose,
    this.partager = partagerFichier,
    this.choisirClasseur = choisirClasseurSysteme,
  });

  final SourcesImport sources;

  /// Tournoi déjà choisi (ouvert depuis l'événement).
  final String? evenementId;

  /// Nom de menu proposé (le menu du tournoi choisi, par exemple).
  final String? menuPropose;
  final PartageurOctets partager;
  final SelecteurClasseur choisirClasseur;

  @override
  State<EcranImport> createState() => _EtatImport();
}

class _EtatImport extends State<EcranImport> {
  final _nomMenu = TextEditingController();
  ClasseurLu? _lu;
  List<Menu> _menus = const [];
  List<Evenement> _enPreparation = const [];
  String? _tournoiId;
  String? _referenceId;
  bool _occupe = false;
  String? _message;
  bool _messageErreur = false;

  @override
  void initState() {
    super.initState();
    _tournoiId = widget.evenementId;
    _nomMenu.text = widget.menuPropose ?? nomMenuImporteParDefaut;
  }

  @override
  void dispose() {
    _nomMenu.dispose();
    super.dispose();
  }

  void _dire(String phrase, {bool erreur = false}) {
    if (!mounted) return;
    setState(() {
      _message = phrase;
      _messageErreur = erreur;
    });
  }

  Future<void> _telechargerModele() async {
    setState(() {
      _occupe = true;
      _message = null;
    });
    try {
      final octets = await construireModeleVierge();
      await widget.partager('modele-vierge.xlsx', octets, typeMimeClasseur);
    } catch (_) {
      _dire('Le modèle n\'a pas pu être préparé. Réessayez.', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _choisirClasseur() async {
    setState(() {
      _occupe = true;
      _message = null;
    });
    try {
      final Uint8List? octets;
      try {
        octets = await widget.choisirClasseur();
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
      if (!lu.contenuUtile && lu.produits.isEmpty) {
        _dire(messageClasseurIllisible, erreur: true);
        return;
      }
      final menus = await widget.sources.menus();
      if (!mounted) return;
      setState(() {
        _lu = lu;
        _menus = menus;
        _referenceId = null;
      });
    } catch (_) {
      _dire('Le fichier n\'a pas pu être lu. Réessayez.', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// Le plan unique d'après les choix faits (lit seulement : le menu existant et les
  /// produits du tournoi).
  Future<PlanAssistant> _plan() async {
    final lu = _lu!;
    final nom = _nomMenu.text.trim();
    // Relu à chaque résumé : un menu créé par un import précédent est alors repris.
    _menus = await widget.sources.menus();
    final existant = menuDeMemeNom(_menus, nom);
    final noms =
        existant == null ? const <String>[] : await widget.sources.nomsProduits(existant.id);
    final tournoi = _enPreparation.where((e) => e.id == _tournoiId).firstOrNull;
    final contexte = tournoi == null ? null : await widget.sources.contexte(tournoi);
    return preparerAssistant(
      lu,
      nomMenu: nom,
      menuExistant: existant,
      produitsExistants: noms,
      tournoi: tournoi,
      contexte: contexte,
      referenceId: _referenceId,
    );
  }

  Future<void> _voirResume() async {
    setState(() {
      _occupe = true;
      _message = null;
    });
    try {
      final PlanAssistant plan;
      try {
        plan = await _plan();
      } catch (_) {
        _dire('Le tournoi ou le menu n\'a pas pu être lu. Vérifiez le réseau puis '
            'réessayez.', erreur: true);
        return;
      }
      if (!mounted) return;
      if (plan.vide) {
        _dire('Rien à importer : ni menu, ni référence de consommation, ni stock de '
            'départ utilisable dans ce classeur.', erreur: true);
        return;
      }
      if (plan.actionMenu == ActionMenu.creer && plan.nomMenu.isEmpty) {
        _dire('Donnez un nom au menu à créer.', erreur: true);
        return;
      }
      final accepte = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _ResumeAssistant(plan: plan)),
      );
      if (accepte != true) return;
      await _appliquer(plan);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// Les écritures, par les méthodes existantes seulement : le menu (créé, jamais
  /// modifié), les références et le stock de départ, puis la prévision. Rejouable : un menu
  /// déjà créé est ensuite repris, une référence de même nom est remplacée.
  Future<void> _appliquer(PlanAssistant plan) async {
    try {
      if (plan.actionMenu == ActionMenu.creer) {
        await widget.sources.creerMenu(plan.nomMenu, plan.menu.aCreer);
      }
      if (!plan.import.vide) {
        await widget.sources.appliquerImport(plan.tournoi?.id, plan.import);
      }
      if (plan.tournoi != null && plan.referencePrevision != null) {
        await widget.sources.appliquerReference(plan.tournoi!.id, plan.referencePrevision!);
      }
      _dire(plan.phraseConfirmation);
    } catch (_) {
      _dire(
          'L\'import n\'a pas pu être terminé. Vérifiez le réseau puis réessayez : '
          'le rejouer est sans risque.',
          erreur: true);
    }
  }

  Widget _carte(String cle, String titre, List<Widget> enfants) => Card(
        key: Key(cle),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titre, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...enfants,
            ],
          ),
        ),
      );

  Widget _carteDepart() => _carte('import_depart', '1. Départ', [
        const Text('Partez du modèle générique à remplir, ou choisissez votre classeur '
            'déjà rempli.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('import_telecharger_modele'),
          style: TypeAction.gerer.contour,
          onPressed: _occupe ? null : _telechargerModele,
          icon: const Icon(Icons.download),
          label: const Text('Télécharger le modèle générique'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('import_choisir_classeur'),
          style: TypeAction.gerer.contour,
          onPressed: _occupe ? null : _choisirClasseur,
          icon: const Icon(Icons.upload_file),
          label: Text(_lu == null ? 'Choisir mon classeur' : 'Choisir un autre classeur'),
        ),
        if (_lu != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Classeur lu : ${_lu!.produits.length} produits de menu, '
              '${_lu!.stocks.length} lignes de stock, '
              '${_lu!.historique.length} lignes d\'historique.',
              key: const Key('import_classeur_lu'),
            ),
          ),
      ]);

  Widget _carteMenu() {
    final nom = _nomMenu.text.trim();
    final existant = menuDeMemeNom(_menus, nom);
    final aProduits = !preparerMenu(_lu!).vide;
    final etat = !aProduits
        ? 'Ce classeur n\'a pas de menu lisible : aucun menu n\'est créé.'
        : existant != null
            ? 'Un menu « ${existant.nom} » existe déjà : il sera repris sans aucune '
                'modification.'
            : 'Un nouveau menu « $nom » sera créé.';
    return _carte('import_menu', '2. Menu', [
      TextField(
        key: const Key('nom_menu_import'),
        controller: _nomMenu,
        inputFormatters: [LengthLimitingTextInputFormatter(40)],
        decoration: const InputDecoration(labelText: 'Nom du menu'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Text(etat, key: const Key('import_menu_etat')),
    ]);
  }

  Widget _carteTournoi() {
    final references = calculerReferences(_lu!.historique).references;
    return _carte('import_tournoi', '3. Tournoi en préparation (facultatif)', [
      const Text('Le stock de départ du classeur est posé dans ce tournoi (gymnases et '
          'produits retrouvés par leur nom) et sa prévision est réglée sur le premier '
          'ancien tournoi du classeur.'),
      const SizedBox(height: 8),
      StreamBuilder<List<Evenement>>(
        stream: widget.sources.tournois,
        builder: (context, s) {
          final liste = s.data;
          if (liste == null) return const Center(child: CircularProgressIndicator());
          _enPreparation = [
            for (final e in liste)
              if (e.enPreparation) e
          ];
          final valeur =
              _enPreparation.any((e) => e.id == _tournoiId) ? _tournoiId : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String?>(
                key: const Key('choix_tournoi'),
                initialValue: valeur,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tournoi'),
                items: [
                  const DropdownMenuItem<String?>(
                      key: Key('tournoi_aucun'), value: null, child: Text('Aucun')),
                  for (final e in _enPreparation)
                    DropdownMenuItem<String?>(
                        key: Key('tournoi_${e.id}'), value: e.id, child: Text(e.nom)),
                ],
                onChanged: (v) => setState(() => _tournoiId = v),
              ),
              if (valeur != null && references.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DropdownButtonFormField<String>(
                    key: const Key('choix_reference_import'),
                    initialValue: references.any((r) => r.id == _referenceId)
                        ? _referenceId
                        : references.first.id,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Prévision réglée sur'),
                    items: [
                      for (final r in references)
                        DropdownMenuItem<String>(
                            key: Key('reference_${r.id}'),
                            value: r.id,
                            child: Text(r.nom)),
                    ],
                    onChanged: (v) => setState(() => _referenceId = v),
                  ),
                ),
            ],
          );
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer')),
      body: ListView(
        key: const Key('import_assistant'),
        padding: const EdgeInsets.all(16),
        children: [
          _carteDepart(),
          if (_lu != null) ...[
            _carteMenu(),
            _carteTournoi(),
            FilledButton(
              key: const Key('import_voir_resume'),
              onPressed: _occupe ? null : _voirResume,
              child: const Text('Voir le résumé'),
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                key: Key(_messageErreur
                    ? 'erreur_import_assistant'
                    : 'confirmation_import_assistant'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _messageErreur ? Palette.ocreFonce : Palette.anthracite,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le résumé de l'assistant (voir [EcranResumeImport]) : tout ce qui sera écrit, puis les
/// lignes ignorées avec leur raison.
class _ResumeAssistant extends StatelessWidget {
  const _ResumeAssistant({required this.plan});

  final PlanAssistant plan;

  @override
  Widget build(BuildContext context) {
    return EcranResumeImport(
      titre: 'Résumé de l\'import',
      cleAppliquer: const Key('appliquer_import_assistant'),
      libelleAppliquer: 'Appliquer',
      ignorees: plan.ignorees,
      erreurs: plan.erreurs,
      corps: [
        for (final (i, phrase) in plan.phrases.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(phrase,
                key: Key('resume_assistant_$i'),
                style: Theme.of(context).textTheme.titleSmall),
          ),
      ],
    );
  }
}
