import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calcul_club.dart';
import 'champ_reglage.dart';
import 'courses.dart' show joursMax, personnesMax;
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';

/// Écran « Personnes et durée » (mission « Ergonomie de la gestion », E5, décision 55).
/// Ouvert par la tâche « Personnes et durée » d'Avant. La durée de l'événement et les
/// personnes attendues de chaque gymnase, avec le total. Les courses les lisent sans les
/// régler. Seuls le responsable et le gestionnaire rattaché à tous les gymnases les règlent
/// (comme les règles d'accès) ; les autres, et tout événement clôturé, les lisent.
///
/// Mission « Calcul du club », V3 (décisions 86 et 87) : les repas peuvent être détaillés
/// jour par jour (méthode du club). Une fois détaillés, le tableau des jours remplace
/// « personnes × durée ». Sans détail, l'écran reste celui d'avant.
class EcranPersonnesDuree extends StatelessWidget {
  const EcranPersonnesDuree({
    super.key,
    required this.evenement,
    required this.portee,
    required this.gymnases,
    required this.definirJours,
    required this.definirPersonnes,
    this.calcul,
    this.definirRepas,
  });

  final Stream<Evenement?> evenement;
  final PorteeGestion portee;

  /// Tous les gymnases de l'événement ; l'écran ne montre que ceux de la portée.
  final Stream<List<Gymnase>> gymnases;
  final Future<void> Function(double jours) definirJours;
  final Future<void> Function(String gymnaseId, int personnes) definirPersonnes;

  /// Le calcul du club (repas détaillés) et son enregistrement (null = pas de détail).
  final Stream<CalculClub?>? calcul;
  final Future<void> Function(Map<String, Map<int, RepasGymnaseJour>> repas)? definirRepas;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Evenement?>(
      stream: evenement,
      builder: (context, sEv) => StreamBuilder<List<Gymnase>>(
        stream: gymnases,
        builder: (context, sG) => _avecCalcul(
          (club) {
            final ev = sEv.data;
            final tous = sG.data;
            return Scaffold(
              appBar: AppBar(title: const Text('Personnes et durée')),
              body: ev == null || tous == null
                  ? const Center(child: CircularProgressIndicator())
                  : _corps(context, ev, tous, club),
            );
          },
        ),
      ),
    );
  }

  /// Le flux du calcul du club, s'il y en a un : [construire] reçoit le calcul (ou null).
  Widget _avecCalcul(Widget Function(CalculClub?) construire) {
    final flux = calcul;
    if (flux == null) return construire(null);
    return StreamBuilder<CalculClub?>(
      stream: flux,
      builder: (context, sC) => construire(sC.data),
    );
  }

  Widget _corps(BuildContext context, Evenement ev, List<Gymnase> tous, CalculClub? club) {
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
        _SectionRepas(
          evenement: ev,
          gymnases: tous,
          reglable: reglable && definirRepas != null,
          calcul: club,
          definirRepas: definirRepas,
          cartesPersonnes: () => [
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
        ),
      ],
    );
  }
}

const _categories = [
  ('joueuses', 'Joueuses et accompagnateurs'),
  ('benevoles', 'Bénévoles et famille'),
  ('spectateurs', 'Spectateurs'),
];

/// Le bloc « repas par jour » (V3). Sans détail : les cartes « personnes » et le bouton
/// « Détailler par jour ». Détaillé : le tableau des jours (et « Modifier le détail »).
/// En cours de saisie : une carte par jour, par gymnase les trois catégories, midi et soir.
class _SectionRepas extends StatefulWidget {
  const _SectionRepas({
    required this.evenement,
    required this.gymnases,
    required this.reglable,
    required this.calcul,
    required this.definirRepas,
    required this.cartesPersonnes,
  });

  final Evenement evenement;
  final List<Gymnase> gymnases;
  final bool reglable;
  final CalculClub? calcul;
  final Future<void> Function(Map<String, Map<int, RepasGymnaseJour>> repas)? definirRepas;
  final List<Widget> Function() cartesPersonnes;

  @override
  State<_SectionRepas> createState() => _EtatSectionRepas();
}

class _EtatSectionRepas extends State<_SectionRepas> {
  bool _editer = false;
  bool _enregistrement = false;
  String? _erreur;

  /// Une saisie par case : « gymnase|jour|catégorie|moment ». Gardées jusqu'à la fermeture
  /// de l'écran, pour ne pas libérer une saisie encore affichée.
  final Map<String, TextEditingController> _saisies = {};

  @override
  void dispose() {
    for (final c in _saisies.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Nombre de jours du détail : un nombre entier de jours, sinon rien (null).
  int? get _jours {
    final n = widget.evenement.nbJours;
    return n >= 1 && n == n.roundToDouble() ? n.round() : null;
  }

  bool get _detaille => widget.calcul != null && widget.calcul!.repas.isNotEmpty;

  static String _cle(String gymnaseId, int jour, String categorie, String moment) =>
      '$gymnaseId|$jour|$categorie|$moment';

  TextEditingController _controleur(String gymnaseId, int jour, String categorie, String moment) =>
      _saisies.putIfAbsent(_cle(gymnaseId, jour, categorie, moment),
          () => TextEditingController()..addListener(_rafraichir));

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  /// Valeur d'une case : un entier de 0 à 1000 ; vide ou non valable compte pour 0 (le
  /// message d'erreur est donné à l'enregistrement).
  int _valeur(String gymnaseId, int jour, String categorie, String moment) {
    final n = int.tryParse(_controleur(gymnaseId, jour, categorie, moment).text.trim());
    return n == null || n < 0 || n > 1000 ? 0 : n;
  }

  bool _saisieValide() {
    for (final g in widget.gymnases) {
      for (var j = 1; j <= _jours!; j++) {
        for (final (cat, _) in _categories) {
          for (final moment in const ['midi', 'soir']) {
            final t = _controleur(g.id, j, cat, moment).text.trim();
            if (t.isEmpty) continue;
            final n = int.tryParse(t);
            if (n == null || n < 0 || n > 1000) return false;
          }
        }
      }
    }
    return true;
  }

  RepasGymnaseJour _repasSaisi(String gymnaseId, int jour) => RepasGymnaseJour(
        joueusesMidi: _valeur(gymnaseId, jour, 'joueuses', 'midi'),
        joueusesSoir: _valeur(gymnaseId, jour, 'joueuses', 'soir'),
        benevolesMidi: _valeur(gymnaseId, jour, 'benevoles', 'midi'),
        benevolesSoir: _valeur(gymnaseId, jour, 'benevoles', 'soir'),
        spectateursMidi: _valeur(gymnaseId, jour, 'spectateurs', 'midi'),
        spectateursSoir: _valeur(gymnaseId, jour, 'spectateurs', 'soir'),
      );

  int _totalGymnaseJour(String gymnaseId, int jour) => _repasSaisi(gymnaseId, jour).total;

  int _totalJour(int jour) =>
      widget.gymnases.fold<int>(0, (s, g) => s + _totalGymnaseJour(g.id, jour));

  void _ouvrirEditeur() {
    final jours = _jours!;
    final actuel = widget.calcul?.repas ?? const <String, Map<int, RepasGymnaseJour>>{};
    for (final g in widget.gymnases) {
      for (var j = 1; j <= jours; j++) {
        final r = actuel[g.id]?[j];
        final valeurs = {
          ('joueuses', 'midi'): r?.joueusesMidi,
          ('joueuses', 'soir'): r?.joueusesSoir,
          ('benevoles', 'midi'): r?.benevolesMidi,
          ('benevoles', 'soir'): r?.benevolesSoir,
          ('spectateurs', 'midi'): r?.spectateursMidi,
          ('spectateurs', 'soir'): r?.spectateursSoir,
        };
        valeurs.forEach((k, v) {
          _controleur(g.id, j, k.$1, k.$2).text = '${v ?? 0}';
        });
      }
    }
    setState(() {
      _editer = true;
      _erreur = null;
    });
  }

  void _annuler() => setState(() {
        _editer = false;
        _erreur = null;
      });

  Future<void> _enregistrer() async {
    if (!_saisieValide()) {
      setState(() => _erreur = 'Entrez un nombre entier de 0 à 1000 dans chaque case.');
      return;
    }
    final jours = _jours!;
    final repas = {
      for (final g in widget.gymnases)
        g.id: {for (var j = 1; j <= jours; j++) j: _repasSaisi(g.id, j)},
    };
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await widget.definirRepas!(repas);
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _editer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = "L'enregistrement a échoué : vérifiez votre connexion.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jours = _jours;
    final enfants = <Widget>[];
    if (_editer && jours != null) {
      enfants.add(_editeur(context, jours));
    } else if (_detaille) {
      enfants.add(_tableau(context));
      if (widget.reglable && jours != null) {
        enfants.add(_bouton(const Key('modifier_repas'), 'Modifier le détail par jour',
            _ouvrirEditeur));
      }
    } else {
      enfants.addAll(widget.cartesPersonnes());
      if (widget.reglable && jours != null) {
        enfants.add(_bouton(const Key('detailler_repas'),
            'Détailler par jour (méthode du club)', _ouvrirEditeur));
      }
    }
    if (widget.reglable && jours == null && !_detaille) {
      enfants.add(const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'La durée n\'est pas un nombre entier de jours : le détail par jour ne se règle pas ici.',
          key: Key('aide_repas_jours'),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: enfants,
    );
  }

  Widget _bouton(Key cle, String texte, VoidCallback surClic) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton(key: cle, onPressed: surClic, child: Text(texte)),
      );

  /// Le tableau des jours, une ligne par jour : le total de chaque gymnase, puis le total.
  Widget _tableau(BuildContext context) {
    final club = widget.calcul!;
    final jours = club.repas.values
        .expand((m) => m.keys)
        .fold<int>(0, (a, j) => j > a ? j : a);
    int totalGymnase(String id, int j) => club.repas[id]?[j]?.total ?? 0;
    Widget cellule(String t, {bool gras = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            t,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: gras ? FontWeight.w700 : FontWeight.w400),
          ),
        );
    return Card(
      key: const Key('tableau_repas'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repas par jour', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Table(
              columnWidths: {
                0: const FixedColumnWidth(64),
                for (var i = 1; i <= widget.gymnases.length + 1; i++)
                  i: const FlexColumnWidth(),
              },
              children: [
                TableRow(children: [
                  cellule('Jour', gras: true),
                  for (final g in widget.gymnases) cellule(g.nom, gras: true),
                  cellule('Total', gras: true),
                ]),
                for (var j = 1; j <= jours; j++)
                  TableRow(children: [
                    cellule('Jour $j'),
                    for (final g in widget.gymnases) cellule('${totalGymnase(g.id, j)}'),
                    cellule(
                      '${widget.gymnases.fold<int>(0, (s, g) => s + totalGymnase(g.id, j))}',
                      gras: true,
                    ),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// La saisie : une carte par jour ; dans chacune, par gymnase, les trois catégories.
  Widget _editeur(BuildContext context, int jours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pour chaque jour et chaque gymnase : les repas de midi et du soir, par '
          'catégorie. Les courses et la prévision s\'en servent.',
          key: Key('aide_repas'),
        ),
        const SizedBox(height: 12),
        for (var j = 1; j <= jours; j++) _carteJour(context, j),
        if (_erreur != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _erreur!,
              key: const Key('erreur_repas'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('enregistrer_repas'),
              style: TypeAction.gerer.plein,
              onPressed: _enregistrement ? null : _enregistrer,
              child: Text(_enregistrement ? 'Enregistrement…' : 'Enregistrer le détail'),
            ),
            TextButton(
              key: const Key('annuler_repas'),
              onPressed: _enregistrement ? null : _annuler,
              child: const Text('Annuler'),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _carteJour(BuildContext context, int jour) {
    return Card(
      key: Key('carte_jour_$jour'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Jour $jour', style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(
                  'Total du jour : ${_totalJour(jour)}',
                  key: Key('total_jour_$jour'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            for (final g in widget.gymnases) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(g.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    '${_totalGymnaseJour(g.id, jour)}',
                    key: Key('total_${g.id}_$jour'),
                  ),
                ],
              ),
              const Row(
                children: [
                  Expanded(child: SizedBox()),
                  SizedBox(width: 72, child: Text('Midi', textAlign: TextAlign.center)),
                  SizedBox(width: 8),
                  SizedBox(width: 72, child: Text('Soir', textAlign: TextAlign.center)),
                ],
              ),
              for (final (cat, libelle) in _categories)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(libelle)),
                      SizedBox(width: 72, child: _champ(g.id, jour, cat, 'midi')),
                      const SizedBox(width: 8),
                      SizedBox(width: 72, child: _champ(g.id, jour, cat, 'soir')),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _champ(String gymnaseId, int jour, String categorie, String moment) => TextField(
        key: Key('repas_${gymnaseId}_${jour}_${categorie}_$moment'),
        controller: _controleur(gymnaseId, jour, categorie, moment),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      );
}
