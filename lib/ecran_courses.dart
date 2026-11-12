import 'dart:async';

import 'package:flutter/material.dart';

import 'courses.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart' show libellesRayons, rayonDepuis, rayonsCourses;
import 'ecran_caisse.dart' show couleurEtat;
import 'ecran_validation_courses.dart';
import 'evenement.dart';
import 'unites_affichees.dart';
import 'gymnase.dart';
import 'partage.dart';
import 'previsions.dart';
import 'theme.dart';
import 'ticket.dart';

/// Courses d'un événement, en préparation (Ergonomie de la gestion, E6). Deux onglets :
/// « À acheter » (articles rangés par rayons, cases cochées partagées entre les
/// téléphones de la gestion, décision 65) et « Déjà acheté » (séries validées). Les
/// réglages (durée, personnes) se résument en une ligne repliable ; ils se règlent dans
/// la Préparation. Quantités de produits finaux par gymnase, « ce qu'il reste » et
/// lignes libres comme avant. Tout s'enregistre tout seul.
class EcranCourses extends StatefulWidget {
  const EcranCourses({
    super.key,
    required this.depot,
    required this.evenementId,
    this.partager = partagerFichierTexte,
    this.onAllerPreparation,
  });

  final DepotEvenements depot;
  final String evenementId;

  /// Remet la liste à partager à la feuille de partage (remplaçable dans les tests).
  final Partageur partager;

  /// Ouvre la Préparation (où se règlent personnes et durée) ; null = pas de renvoi.
  final Future<void> Function()? onAllerPreparation;

  @override
  State<EcranCourses> createState() => _EtatCourses();
}

class _EtatCourses extends State<EcranCourses> {
  bool _charge = false;
  Object? _erreurChargement;

  /// Onglet affiché : 0 = « À acheter », 1 = « Déjà acheté ».
  int _onglet = 0;

  /// Produits avec la consommation effective : celle de la prévision de l'événement,
  /// sinon celle du menu. [_produitsMenu] = tels que l'événement les a copiés.
  List<ProduitEvenement> _produits = const [];
  List<ProduitEvenement> _produitsMenu = const [];
  List<Gymnase> _gymnases = const [];

  /// Durée de l'événement (réglée dans la Préparation) et choix local de durée à
  /// couvrir : 'tout' (= durée de l'événement, par défaut), 'demi', 'jour' ou 'plus'.
  double _joursEvenement = joursParDefaut;
  String _choixDuree = 'tout';
  int _joursPlus = 2;
  final Map<String, int> _personnes = {};

  double get _jours => switch (_choixDuree) {
        'demi' => demiJournee,
        'jour' => 1.0,
        'plus' => _joursPlus.toDouble(),
        _ => _joursEvenement,
      };

  /// Stock actuel (gymnase -> produit -> quantité), relu à chaque « Recalculer ».
  Map<String, Map<String, int>> _stocks = const {};

  /// Cases cochées en magasin : lues en direct (flux de la liste), partagées entre les
  /// téléphones de la gestion.
  Set<String> _coches = {};
  StreamSubscription<ListeCourses?>? _abonnementCoches;

  ListeCourses _liste = const ListeCourses();

  Timer? _minuteur;
  bool _listeModifiee = false;
  bool _enregistre = true;
  bool _erreurEnregistrement = false;

  /// Change quand la liste est recalculée : les champs sont reconstruits.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    if (_minuteur?.isActive ?? false) {
      _minuteur!.cancel();
      _enregistrer();
    }
    _abonnementCoches?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final id = widget.evenementId;
      final evenement = await widget.depot.suivreEvenement(id).first;
      final produits = await widget.depot.suivreProduits(id).first;
      final gymnases = await widget.depot.suivreGymnases(id).first;
      final stocks = await widget.depot.suivreStocksParGymnase(id).first;
      final enregistree = await widget.depot.suivreListeCourses(id).first;
      final previsions = await _lirePrevisions();
      if (!mounted) return;
      setState(() {
        _produitsMenu = produits;
        _produits = produitsAvecPrevisions(produits, previsions);
        _gymnases = gymnases;
        _stocks = stocks;
        _joursEvenement = evenement?.nbJours ?? joursParDefaut;
        for (final g in gymnases) {
          _personnes[g.id] = g.personnes;
        }
        _liste = enregistree ??
            listeParDefaut(
                produits: produits,
                gymnases: gymnases,
                jours: _jours,
                stocks: stocks);
        _coches = enregistree?.coches ?? {};
        _charge = true;
      });
      _abonnementCoches ??= widget.depot.suivreListeCourses(id).listen(
        (l) {
          if (!mounted || l == null) return;
          // La liste suit en direct (les quantités se règlent dans la Préparation) ;
          // une saisie locale en attente garde la main jusqu'à son enregistrement.
          final enAttente = _listeModifiee || (_minuteur?.isActive ?? false);
          setState(() {
            _coches = l.coches;
            if (!enAttente) _liste = l;
          });
        },
        onError: (_) {},
      );
    } catch (e) {
      if (mounted) setState(() => _erreurChargement = e);
    }
  }

  /// Les prévisions de l'événement ; illisibles (réseau, droits) : aucune, les courses
  /// calculent alors avec les chiffres du menu.
  Future<Map<String, Prevision>> _lirePrevisions() async {
    try {
      return await widget.depot.suivrePrevisions(widget.evenementId).first;
    } catch (_) {
      return const {};
    }
  }

  void _planifier() {
    setState(() => _enregistre = false);
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 700), _enregistrer);
  }

  /// Écrit la liste (avec ses articles et les cases à retirer) si elle a changé, ou si
  /// [force]. Renvoie false si l'écriture a échoué.
  Future<bool> _enregistrer({bool force = false}) async {
    final id = widget.evenementId;
    final ecrire = _listeModifiee || force;
    _listeModifiee = false;
    try {
      if (ecrire) {
        final articles =
            clesArticles(calculerAchats(_produits, _liste), _liste.libres);
        await widget.depot.enregistrerListeCourses(
            id, _liste.avec(articles: articles, coches: _coches));
      }
      if (mounted) {
        setState(() {
          _enregistre = true;
          _erreurEnregistrement = false;
        });
      }
      return true;
    } catch (_) {
      _listeModifiee = _listeModifiee || ecrire;
      if (mounted) setState(() => _erreurEnregistrement = true);
      return false;
    }
  }

  /// Enregistre tout de suite ce qui est en attente, puis ouvre la validation.
  Future<void> _valider() async {
    _minuteur?.cancel();
    final ok = await _enregistrer(force: true); // le document doit exister
    if (!mounted || !ok) return;
    final fait = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranValidationCourses(
          depot: widget.depot,
          evenementId: widget.evenementId,
          produits: _produits,
          gymnases: _gymnases,
          liste: _liste,
        ),
      ),
    );
    if (fait == true && mounted) {
      setState(() => _charge = false);
      await _charger();
    }
  }

  /// Partage la liste « À acheter » et les lignes libres, en texte, rangée par rayons.
  Future<void> _partagerListe() async {
    final texte = texteListeCourses(
        'Liste de courses', calculerAchats(_produits, _liste), _liste.libres);
    try {
      await widget.partager('liste-de-courses.txt', texte);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Le partage n'a pas pu s'ouvrir. Réessayez.")));
    }
  }

  /// Après une validation : la liste repart vide, le cumul garde coût et ajouts.
  Future<void> _nouvelleSerie() async {
    try {
      await widget.depot.nouvelleSerieCourses(widget.evenementId, _liste);
      if (!mounted) return;
      setState(() => _charge = false);
      await _charger();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "La nouvelle série n'a pas pu s'ouvrir. Vérifiez la connexion et réessayez.")));
    }
  }

  void _modifierListe(ListeCourses l) {
    _liste = l;
    _listeModifiee = true;
    _planifier();
  }

  /// Coche ou décoche un article. La liste est d'abord enregistrée (le document doit
  /// porter l'article), puis la case est écrite seule. Rien d'autre ne bouge.
  Future<void> _basculerCoche(String cle, bool coche) async {
    final avant = _coches;
    setState(() => _coches = coche ? {..._coches, cle} : ({..._coches}..remove(cle)));
    if (await _enregistrer(force: true)) {
      try {
        await widget.depot.cocherArticle(widget.evenementId, cle, coche);
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _coches = avant);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("La case n'a pas pu être enregistrée. Vérifiez la connexion.")));
  }

  /// « Plus » : un nombre entier de jours, de 2 à [joursMax]. Choix local : il ne
  /// change jamais la durée de l'événement.
  void _surJours(String texte) {
    final n = int.tryParse(texte.trim());
    if (n == null || n < 2 || n > joursMax) return;
    setState(() => _joursPlus = n);
  }

  /// Tout l'événement (par défaut), demi-journée, jour complet ou plus.
  void _choisirDuree(String choix) => setState(() => _choixDuree = choix);

  /// Va régler personnes et durée dans la Préparation, puis relit ces réglages.
  Future<void> _allerPreparation() async {
    await widget.onAllerPreparation?.call();
    if (!mounted) return;
    try {
      final id = widget.evenementId;
      final evenement = await widget.depot.suivreEvenement(id).first;
      final gymnases = await widget.depot.suivreGymnases(id).first;
      final previsions = await _lirePrevisions();
      if (!mounted) return;
      setState(() {
        _produits = produitsAvecPrevisions(_produitsMenu, previsions);
        _joursEvenement = evenement?.nbJours ?? joursParDefaut;
        _gymnases = gymnases;
        for (final g in gymnases) {
          _personnes[g.id] = g.personnes;
        }
      });
    } catch (_) {}
  }

  Future<void> _recalculer() async {
    // Le stock est relu : l'estimation tient compte de ce qu'il reste maintenant.
    try {
      final stocks = await widget.depot.suivreStocksParGymnase(widget.evenementId).first;
      if (!mounted) return;
      _stocks = stocks;
    } catch (_) {
      if (!mounted) return;
    }
    final base = listeParDefaut(
      produits: _produits,
      gymnases: [for (final g in _gymnases) Gymnase(g.id, g.nom, _personnes[g.id] ?? 0)],
      jours: _jours,
      stocks: _stocks,
    );
    setState(() {
      _version++;
      _modifierListe(_liste.avec(lignes: base.lignes));
    });
  }

  void _surReste(String cle, String texte) {
    final t = texte.trim().replaceAll(',', '.');
    final restes = {..._liste.restes};
    if (t.isEmpty) {
      restes.remove(cle);
    } else {
      final v = double.tryParse(t);
      if (v == null || v < 0 || v > 1000000) return;
      restes[cle] = v;
    }
    setState(() => _modifierListe(_liste.avec(restes: restes)));
  }

  /// « Modifier » : la saisie de ce qu'il y a en stock, dans une petite feuille. Le
  /// champ garde la clé `reste_<cle>` ; l'enregistrement passe par [_surReste].
  Future<void> _modifierReste(Achat achat) async {
    final actuel = _liste.restes[achat.cle];
    final texte = await showDialog<String>(
      context: context,
      builder: (_) => _DialogueReste(
        nom: achat.nom,
        cle: achat.cle,
        unite: libelleUniteReste(achat.uniteBase),
        initial: actuel == null ? '' : _nombre(actuel),
      ),
    );
    if (texte == null || !mounted) return;
    _surReste(achat.cle, texte);
  }

  Future<void> _ajouterLibre() async {
    final ligne = await showDialog<LigneLibre>(
      context: context,
      builder: (_) => const _DialogueLibre(),
    );
    if (ligne == null || !mounted) return;
    setState(() => _modifierListe(_liste.avec(libres: [..._liste.libres, ligne])));
  }

  void _retirerLibre(int i) {
    final libres = [..._liste.libres]..removeAt(i);
    setState(() => _modifierListe(_liste.avec(libres: libres)));
  }

  String _nombre(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: _erreurChargement != null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Impossible de charger les courses.',
                  key: Key('erreur_courses')),
            )
          : !_charge
              ? const Center(child: CircularProgressIndicator())
              : _contenu(context),
      // Les actions restent en bas, hors de la liste qui défile ; le clavier les masque
      // pour laisser la place aux champs « Il reste » et aux quantités.
      bottomNavigationBar: (_erreurChargement == null &&
              _charge &&
              _onglet == 0 &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
          ? _barreActions(context)
          : null,
    );
  }

  /// Barre fixée en bas : ajouter une ligne, enregistrer ou partager la liste, saisir
  /// ce qui a été acheté (valider). Les boutons font ce qu'ils faisaient avant.
  Widget _barreActions(BuildContext context) {
    final validee = _liste.validation != null;
    final cles = clesArticles(calculerAchats(_produits, _liste), _liste.libres);
    final cochesN = cles.where(_coches.contains).length;
    const serre = EdgeInsets.symmetric(horizontal: 8);
    return DecoratedBox(
      key: const Key('barre_actions'),
      decoration: const BoxDecoration(
        color: Palette.papier,
        border: Border(top: BorderSide(color: Palette.filet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('ajouter_libre'),
                      style: OutlinedButton.styleFrom(padding: serre),
                      onPressed: validee ? null : _ajouterLibre,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une ligne',
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('partager_liste'),
                      style: OutlinedButton.styleFrom(padding: serre),
                      onPressed: _partagerListe,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Enregistrer ou partager',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
              if (!validee) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('valider_courses'),
                    onPressed: _liste.lignes.isEmpty ? null : _valider,
                    child: Text('Valider les courses ($cochesN / ${cles.length} cochés)'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bandeau résumé : durée couverte, personnes attendues, coût cumulé des séries
  /// déjà validées (valeurs déjà connues de l'écran, rien de nouveau calculé).
  Widget _bandeauResume(BuildContext context) {
    final personnes = _gymnases.fold<int>(0, (t, g) => t + (_personnes[g.id] ?? 0));
    final cout = _liste.seriesValidees > 0 ? coutAffiche(_liste.coutTotalCentimes) : '—';
    Widget chiffre(String libelle, String valeur, String cle) => Expanded(
          child: Column(
            children: [
              Text(valeur,
                  key: Key(cle),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Palette.pruneFonce)),
              const SizedBox(height: 2),
              Text(libelle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Palette.gris)),
            ],
          ),
        );
    return Card(
      key: const Key('bandeau_resume'),
      color: Palette.pruneDoux,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            chiffre('Durée', '${_nombre(_jours)} j', 'resume_duree'),
            chiffre('Personnes', '$personnes', 'resume_personnes'),
            chiffre('Coût cumulé', cout, 'resume_cout'),
          ],
        ),
      ),
    );
  }

  Widget _contenu(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    final achats = calculerAchats(_produits, _liste);
    final cles = clesArticles(achats, _liste.libres);
    final aucunePersonne = _gymnases.every((g) => (_personnes[g.id] ?? 0) == 0);
    final cochesAffichees = cles.where(_coches.contains).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _onglet == 0
                  ? FilledButton(
                      key: const Key('onglet_acheter'),
                      onPressed: () => setState(() => _onglet = 0),
                      child: Text('À acheter · $cochesAffichees/${cles.length}'))
                  : OutlinedButton(
                      key: const Key('onglet_acheter'),
                      onPressed: () => setState(() => _onglet = 0),
                      child: Text('À acheter · $cochesAffichees/${cles.length}')),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _onglet == 1
                  ? FilledButton(
                      key: const Key('onglet_achete'),
                      onPressed: () => setState(() => _onglet = 1),
                      child: const Text('Déjà acheté'))
                  : OutlinedButton(
                      key: const Key('onglet_achete'),
                      onPressed: () => setState(() => _onglet = 1),
                      child: const Text('Déjà acheté')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bandeauResume(context),
        ...(_onglet == 0
            ? _ongletAcheter(context, titre, achats, cles, aucunePersonne)
            : _ongletAchete(context)),
      ],
    );
  }

  List<Widget> _ongletAcheter(
    BuildContext context,
    TextStyle? titre,
    List<Achat> achats,
    List<String> cles,
    bool aucunePersonne,
  ) {
    final validee = _liste.validation != null;
    return [
      if (validee)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Courses validées : voir « Déjà acheté ».',
              key: Key('renvoi_validee')),
        ),
      Text(
        _erreurEnregistrement
            ? "L'enregistrement a échoué : vérifiez votre connexion."
            : _enregistre
                ? 'Enregistré'
                : 'Enregistrement…',
        key: const Key('etat_courses'),
        style: TextStyle(
            color: _erreurEnregistrement ? Theme.of(context).colorScheme.error : null),
      ),
      // Une liste validée ne bouge plus : on la relit seulement.
      AbsorbPointer(
        absorbing: validee,
        child: Opacity(
          opacity: validee ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reglages(context, titre, aucunePersonne),
              const SizedBox(height: 12),
              Text('Ce qu’il faut acheter', style: titre),
              const Text(
                  'Cochez ce qui est dans le panier : cela ne change pas le stock. Le stock change seulement quand vous validez les courses. Les quantités tiennent compte du stock.'),
              const SizedBox(height: 4),
              _rayons(context, achats, cles),
            ],
          ),
        ),
      ),
    ];
  }

  /// Réglages : une ligne repliable (durée, personnes), puis l'aide si aucune personne.
  Widget _reglages(BuildContext context, TextStyle? titre, bool aucunePersonne) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
          key: const Key('reglages_courses'),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(_resumeReglages(), key: const Key('resume_reglages')),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            Text('Durée à couvrir', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              key: const Key('duree_courses'),
              spacing: 8,
              children: [
                for (final (valeur, cle, texte) in [
                  ('tout', 'duree_tout', 'Tout l’événement (${_nombre(_joursEvenement)} j)'),
                  ('demi', 'duree_demi', 'Demi-journée'),
                  ('jour', 'duree_jour', 'Jour complet'),
                  ('plus', 'duree_plus', 'Plus'),
                ])
                  ChoiceChip(
                    key: Key(cle),
                    label: Text(texte),
                    selected: _choixDuree == valeur,
                    onSelected: (_) => _choisirDuree(valeur),
                  ),
              ],
            ),
            if (_choixDuree == 'plus')
              TextFormField(
                key: const Key('jours_courses'),
                initialValue: '$_joursPlus',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nombre de jours (2 à 30)'),
                onChanged: _surJours,
              ),
            const SizedBox(height: 8),
            for (final g in _gymnases)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _gymnases.length > 1
                      ? 'Personnes attendues (${g.nom}) : ${_personnes[g.id] ?? 0}'
                      : 'Personnes attendues : ${_personnes[g.id] ?? 0}',
                  key: Key('lecture_personnes_${g.id}'),
                ),
              ),
            const Text('Réglé dans « Personnes et durée ».', key: Key('mention_preparation')),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('recalculer'),
                onPressed: _recalculer,
                child: const Text('Recalculer les quantités (remplace vos changements)'),
              ),
            ),
          ],
        ),
        ),
        if (aucunePersonne)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aucune personne attendue : réglez-les dans « Personnes et durée », '
                  'puis « Recalculer » : les quantités se remplissent.',
                  key: Key('aide_personnes'),
                ),
                if (widget.onAllerPreparation != null)
                  OutlinedButton(
                    key: const Key('aller_preparation'),
                    onPressed: _allerPreparation,
                    child: const Text('Aller à Personnes et durée'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// La ligne de résumé des réglages : durée et personnes, sans ouvrir la ligne.
  String _resumeReglages() {
    final duree = switch (_choixDuree) {
      'demi' => 'demi-journée',
      'jour' => 'jour complet',
      'plus' => '$_joursPlus jours',
      _ => 'événement, ${_nombre(_joursEvenement)} j',
    };
    final personnes = [for (final g in _gymnases) '${_personnes[g.id] ?? 0}'].join(' + ');
    return 'Réglages : $duree · ${personnes.isEmpty ? '0' : personnes} personnes';
  }

  /// Les articles (achats puis lignes libres) rangés par rayons, dans l'ordre fixe.
  Widget _rayons(BuildContext context, List<Achat> achats, List<String> cles) {
    final articles = <_Article>[
      for (var i = 0; i < achats.length; i++)
        _Article(cles[i], achats[i].rayon, achat: achats[i]),
      for (var i = 0; i < _liste.libres.length; i++)
        _Article(cles[achats.length + i], rayonDepuis(_liste.libres[i].rayon),
            libre: _liste.libres[i], indexLibre: i),
    ];
    if (articles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Rien à acheter pour l’instant.', key: Key('aucun_achat')),
      );
    }
    final usages = usagesAchats(_produits, _liste);
    return KeyedSubtree(
      key: ValueKey('rayons_$_version'),
      child: Column(
        children: [
          for (final r in rayonsCourses)
            if (articles.any((a) => a.rayon == r))
              Card(
                key: Key('rayon_$r'),
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: _rayon(r, articles.where((a) => a.rayon == r).toList(), usages),
              ),
        ],
      ),
    );
  }

  /// Un rayon : carte repliable, avec le compteur « cochés/total » à côté du nom.
  Widget _rayon(String r, List<_Article> articles, Map<String, List<String>> usages) {
    final cochesIci = articles.where((a) => _coches.contains(a.cle)).length;
    final fini = cochesIci == articles.length;
    return ExpansionTile(
      initiallyExpanded: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        children: [
          Flexible(
            child: Text(libellesRayons[r]!,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          BadgeComptoir(
            texte: '$cochesIci/${articles.length}',
            fond: fini ? Palette.saugeDoux : Palette.anthraciteDoux,
            encre: fini ? Palette.saugeFonce : Palette.anthraciteFonce,
            cleTexte: Key('compteur_rayon_$r'),
          ),
        ],
      ),
      children: [for (final a in articles) _ligneArticle(a, usages[a.cle])],
    );
  }

  /// Un article : case à cocher (partagée), nom et quantité, « ce qu'il reste »,
  /// ou retrait pour une ligne libre.
  Widget _ligneArticle(_Article a, List<String>? pour) {
    final coche = _coches.contains(a.cle);
    final achat = a.achat;
    final libre = a.libre;
    final nom = achat != null
        ? '${achat.nom} : ${formaterQuantite(achat.aAcheter, achat.uniteBase)}'
        : '${libre!.nom} × ${_nombre(libre.quantite)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: Key('case_${a.cle}'),
            value: coche,
            onChanged: (v) => _basculerCoche(a.cle, v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    key: achat != null
                        ? Key('achat_${achat.cle}')
                        : Key('libre_${a.indexLibre}'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: coche ? TextDecoration.lineThrough : null,
                      color: coche ? Colors.grey : null,
                    ),
                  ),
                  if (pour != null && pour.isNotEmpty)
                    Text('pour ${pour.join(', ')}',
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          if (achat != null)
            SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    textAlign: TextAlign.end,
                    _liste.restes[achat.cle] == null
                        ? 'En stock : non renseigné'
                        : 'En stock : ${_nombre(_liste.restes[achat.cle]!)} ${libelleUniteReste(achat.uniteBase)}',
                    key: Key('en_stock_${achat.cle}'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton(
                    key: Key('modifier_reste_${achat.cle}'),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => _modifierReste(achat),
                    child: const Text('Modifier'),
                  ),
                ],
              ),
            ),
          if (libre != null)
            IconButton(
              key: Key('retirer_libre_${a.indexLibre}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Retirer',
              onPressed: () => _retirerLibre(a.indexLibre!),
            ),
        ],
      ),
    );
  }

  /// L'onglet « Déjà acheté » : séries validées, coût et ajouts au stock.
  List<Widget> _ongletAchete(BuildContext context) {
    final validee = _liste.validation;
    return [
      if (validee != null) _bandeauValidee(context, validee)
      else if (_liste.precedent.series > 0) _bandeauSeries(context)
      else const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune course validée pour l’instant.',
              key: Key('aucune_validee')),
        ),
      ),
      if (validee != null) ...[
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('nouvelle_serie'),
          onPressed: _nouvelleSerie,
          child: const Text('Nouvelle série de courses'),
        ),
      ],
    ];
  }

  /// Les séries déjà validées pendant que la suivante se prépare : coût cumulé
  /// et ce que le stock a déjà reçu.
  Widget _bandeauSeries(BuildContext context) {
    final p = _liste.precedent;
    final noms = {for (final x in _produits) x.id: x.nom};
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.series == 1
                  ? '1 série déjà validée'
                  : '${p.series} séries déjà validées',
              key: const Key('series_validees'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Coût cumulé : ${coutAffiche(p.coutCentimes)}',
                key: const Key('cout_cumule')),
            const Text('Déjà ajouté au stock :'),
            for (final e in p.ajouts.entries)
              Text('${noms[e.key] ?? '?'} +${e.value}', key: Key('ajout_${e.key}')),
          ],
        ),
      ),
    );
  }

  Widget _bandeauValidee(BuildContext context, ValidationCourses v) {
    final noms = {for (final p in _produits) p.id: p.nom};
    // Toutes les séries validées : celles d'avant et celle-ci (mission C1).
    final parProduit = _liste.ajoutsTotaux;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v.valideeLe == null
                  ? 'Courses validées'
                  : 'Courses validées le ${dateHeureAffichee(v.valideeLe!)}',
              key: const Key('courses_validee'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
                _liste.seriesValidees > 1
                    ? 'Coût cumulé (${_liste.seriesValidees} séries) : ${coutAffiche(_liste.coutTotalCentimes)}'
                    : 'Coût : ${coutAffiche(v.coutCentimes)}',
                key: const Key('cout_valide')),
            const Text('Ajouté au stock :'),
            for (final e in parProduit.entries)
              Text('${noms[e.key] ?? '?'} +${e.value}', key: Key('ajout_${e.key}')),
          ],
        ),
      ),
    );
  }
}

/// Un article affiché : un achat (ingrédient ou produit) ou une ligne libre.
class _Article {
  const _Article(this.cle, this.rayon,
      {this.achat, this.libre, this.indexLibre});

  final String cle;
  final String rayon;
  final Achat? achat;
  final LigneLibre? libre;
  final int? indexLibre;
}

/// Saisie d'une ligne libre : un nom, une quantité et un rayon.
class _DialogueLibre extends StatefulWidget {
  const _DialogueLibre();

  @override
  State<_DialogueLibre> createState() => _EtatDialogueLibre();
}

class _EtatDialogueLibre extends State<_DialogueLibre> {
  final _nom = TextEditingController();
  final _quantite = TextEditingController(text: '1');
  String _rayon = 'autre';
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _quantite.dispose();
    super.dispose();
  }

  void _valider() {
    final nom = _nom.text.trim();
    final q = double.tryParse(_quantite.text.trim().replaceAll(',', '.'));
    if (nom.isEmpty || nom.length > 60) {
      setState(() => _erreur = 'Entrez un nom (60 caractères au plus).');
    } else if (q == null || q <= 0 || q > 100000) {
      setState(() => _erreur = 'Entrez une quantité supérieure à zéro.');
    } else {
      Navigator.pop(context, LigneLibre(nom, q, _rayon));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une ligne'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('nom_libre'),
            controller: _nom,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          TextField(
            key: const Key('quantite_libre'),
            controller: _quantite,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Quantité', errorText: _erreur),
            onSubmitted: (_) => _valider(),
          ),
          DropdownButtonFormField<String>(
            key: const Key('rayon_libre'),
            isExpanded: true,
            initialValue: _rayon,
            decoration: const InputDecoration(labelText: 'Rayon'),
            items: [
              for (final r in rayonsCourses)
                DropdownMenuItem(
                    key: Key('rayon_libre_$r'),
                    value: r,
                    child: Text(libellesRayons[r]!)),
            ],
            onChanged: (v) => setState(() => _rayon = v ?? 'autre'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_libre'),
            onPressed: _valider,
            child: const Text('Ajouter')),
      ],
    );
  }
}

/// Saisie de « ce qu'il y a en stock » pour un article (bouton « Modifier »).
class _DialogueReste extends StatefulWidget {
  const _DialogueReste({
    required this.nom,
    required this.cle,
    required this.unite,
    required this.initial,
  });

  final String nom;
  final String cle;
  final String unite;
  final String initial;

  @override
  State<_DialogueReste> createState() => _EtatDialogueReste();
}

class _EtatDialogueReste extends State<_DialogueReste> {
  late final TextEditingController _champ =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('En stock : ${widget.nom}'),
      content: TextField(
        key: Key('reste_${widget.cle}'),
        controller: _champ,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: "Ce qu'il y a en stock",
          suffixText: widget.unite,
        ),
        onSubmitted: (t) => Navigator.pop(context, t),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_reste'),
            onPressed: () => Navigator.pop(context, _champ.text),
            child: const Text('Enregistrer')),
      ],
    );
  }
}

/// « Quantités par produit », rangées dans la Préparation (décision 82), sous le titre
/// « Ce qu'on prévoit de vendre ». C'est le même bloc qu'avant dans les courses : il lit
/// et écrit la même liste de courses par les mêmes méthodes du dépôt ; les courses la
/// relisent en direct, les achats suivent. Aucun calcul ne change.
class QuantitesParProduit extends StatefulWidget {
  const QuantitesParProduit({
    super.key,
    required this.depot,
    required this.evenementId,
  });

  final DepotEvenements depot;
  final String evenementId;

  @override
  State<QuantitesParProduit> createState() => _EtatQuantites();
}

class _EtatQuantites extends State<QuantitesParProduit> {
  bool _charge = false;
  Object? _erreur;

  List<ProduitEvenement> _produits = const [];
  List<Gymnase> _gymnases = const [];
  Map<String, List<String>> _suggeres = const {};
  double _jours = joursParDefaut;
  final Map<String, int> _personnes = {};
  Map<String, Map<String, int>> _stocks = const {};

  final Map<String, StreamSubscription<TableauDeBord>> _abonnementsVendus = {};
  final Map<String, TableauDeBord> _tableaux = {};
  StreamSubscription<ListeCourses?>? _abonnementListe;

  ListeCourses _liste = const ListeCourses();
  Timer? _minuteur;
  bool _listeModifiee = false;
  bool _enregistre = true;
  bool _erreurEnregistrement = false;

  /// Change quand une quantité est cochée : les champs sont reconstruits.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    if (_minuteur?.isActive ?? false) {
      _minuteur!.cancel();
      _enregistrer();
    }
    for (final a in _abonnementsVendus.values) {
      a.cancel();
    }
    _abonnementListe?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final id = widget.evenementId;
      final evenement = await widget.depot.suivreEvenement(id).first;
      final produits = await widget.depot.suivreProduits(id).first;
      final gymnases = await widget.depot.suivreGymnases(id).first;
      final etats = await widget.depot.suivreEtats(id).first;
      final stocks = await widget.depot.suivreStocksParGymnase(id).first;
      final enregistree = await widget.depot.suivreListeCourses(id).first;
      var previsions = const <String, Prevision>{};
      try {
        previsions = await widget.depot.suivrePrevisions(id).first;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _produits = produitsAvecPrevisions(produits, previsions);
        _gymnases = gymnases;
        _stocks = stocks;
        for (final g in gymnases) {
          _abonnementsVendus[g.id] ??= widget.depot
              .caisses(id)
              .suivreTableauDeBord(gymnaseIds: {g.id})
              .listen((t) {
            if (mounted) setState(() => _tableaux[g.id] = t);
          });
          _personnes[g.id] = g.personnes;
        }
        _suggeres = produitsSuggeres(etats, gymnases);
        _jours = evenement?.nbJours ?? joursParDefaut;
        _liste = enregistree ??
            listeParDefaut(
                produits: produits,
                gymnases: gymnases,
                jours: _jours,
                stocks: stocks);
        _charge = true;
      });
      _abonnementListe ??= widget.depot.suivreListeCourses(id).listen(
        (l) {
          if (!mounted || l == null) return;
          if (_listeModifiee || (_minuteur?.isActive ?? false)) return;
          setState(() => _liste = l);
        },
        onError: (_) {},
      );
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  void _modifierListe(ListeCourses l) {
    _liste = l;
    _listeModifiee = true;
    _enregistre = false;
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 700), _enregistrer);
  }

  Future<void> _enregistrer() async {
    final ecrire = _listeModifiee;
    _listeModifiee = false;
    try {
      if (ecrire) {
        final articles =
            clesArticles(calculerAchats(_produits, _liste), _liste.libres);
        await widget.depot.enregistrerListeCourses(
            widget.evenementId, _liste.avec(articles: articles));
      }
      if (mounted) {
        setState(() {
          _enregistre = true;
          _erreurEnregistrement = false;
        });
      }
    } catch (_) {
      _listeModifiee = _listeModifiee || ecrire;
      if (mounted) setState(() => _erreurEnregistrement = true);
    }
  }

  void _cocher(Gymnase g, ProduitEvenement p, bool oui) {
    int? quantite;
    if (oui) {
      quantite = quantiteAPrevoir(
          personnes: _personnes[g.id] ?? 0,
          jours: _jours,
          conso: p.fiche.conso ?? 0,
          stock: _stocks[g.id]?[p.id]);
    }
    setState(() {
      _version++;
      _modifierListe(_liste.avecQuantite(g.id, p.id, quantite));
    });
  }

  void _surQuantite(Gymnase g, ProduitEvenement p, String texte) {
    final n = int.tryParse(texte.trim());
    if (n == null || n < 0 || n > 100000) return;
    setState(() => _modifierListe(_liste.avecQuantite(g.id, p.id, n)));
  }

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    if (_erreur != null) {
      return const Text('Impossible de charger les quantités.',
          key: Key('erreur_quantites'));
    }
    if (!_charge) {
      return const Center(child: CircularProgressIndicator());
    }
    final validee = _liste.validation != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Ce qu'on prévoit de vendre",
            key: const Key('titre_prevoit_vendre'), style: titre),
        const SizedBox(height: 4),
        const Text("Combien de chaque produit on prépare ; les courses s'en servent."),
        Text(
          _erreurEnregistrement
              ? "L'enregistrement a échoué : vérifiez votre connexion."
              : _enregistre
                  ? 'Enregistré'
                  : 'Enregistrement…',
          key: const Key('etat_quantites'),
          style: TextStyle(
              color: _erreurEnregistrement ? Theme.of(context).colorScheme.error : null),
        ),
        const SizedBox(height: 4),
        AbsorbPointer(
          absorbing: validee,
          child: Opacity(
            opacity: validee ? 0.6 : 1,
            child: Card(
              key: const Key('quantites_produits'),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantités par produit', style: titre),
                    KeyedSubtree(
                      key: ValueKey(_version),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final g in _gymnases) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(
                                  _gymnases.length > 1
                                      ? 'Produits : ${g.nom}'
                                      : 'Produits',
                                  style: titre),
                            ),
                            for (final p in _produits)
                              _ligneProduit(g, p, _tableaux[g.id]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ligneProduit(Gymnase g, ProduitEvenement p, TableauDeBord? tableau) {
    final quantite = _liste.quantite(g.id, p.id);
    final stock = _stocks[g.id]?[p.id];
    final info = [
      stock == null ? 'Stock non suivi' : 'En stock : $stock',
      'Vendu : ${tableau == null ? '…' : tableau.vendus(p.id)}',
    ].join(' · ');
    final suggere = _suggeres[p.id]?.contains(g.nom) ?? false;
    return Row(
      children: [
        Checkbox(
          key: Key('coche_${g.id}_${p.id}'),
          value: quantite != null,
          onChanged: (v) => _cocher(g, p, v ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nom),
              Text(info,
                  key: Key('info_${g.id}_${p.id}'),
                  style: const TextStyle(fontSize: 12)),
              UnitesStock(
                key: Key('unites_${g.id}_${p.id}'),
                fiche: p.fiche,
                quantite: stock,
              ),
              if (suggere)
                Text(
                  'Suggéré : stock bas',
                  key: Key('suggere_${g.id}_${p.id}'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: couleurEtat(EtatStock.bas)),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 128,
          child: quantite == null
              ? const SizedBox.shrink()
              : TextFormField(
                  key: Key('qte_${g.id}_${p.id}'),
                  initialValue: '$quantite',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: p.fiche.type == 'litre' ? ' verres' : null,
                  ),
                  onChanged: (t) => _surQuantite(g, p, t),
                ),
        ),
      ],
    );
  }
}
