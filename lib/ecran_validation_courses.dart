import 'package:flutter/material.dart';

import 'courses.dart';
import 'depot_evenements.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'ticket.dart';

/// Validation des courses : quantités réellement achetées, ce que cela ajoute au
/// stock de chaque gymnase (ingrédient limitant), coût total. « Confirmer » ajoute
/// tout au stock et fige la liste, en un seul lot. Se ferme avec `true` si c'est fait.
class EcranValidationCourses extends StatefulWidget {
  const EcranValidationCourses({
    super.key,
    required this.depot,
    required this.evenementId,
    required this.produits,
    required this.gymnases,
    required this.liste,
  });

  final DepotEvenements depot;
  final String evenementId;
  final List<ProduitEvenement> produits;
  final List<Gymnase> gymnases;
  final ListeCourses liste;

  @override
  State<EcranValidationCourses> createState() => _EtatValidation();
}

class _EtatValidation extends State<EcranValidationCourses> {
  late final List<Achat> _achats = calculerAchats(widget.produits, widget.liste);
  late final Map<String, double> _achetes = {
    for (final a in _achats) a.cle: a.aAcheter.toDouble(),
  };
  final Set<String> _invalides = {};
  final _cout = TextEditingController();
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _cout.dispose();
    super.dispose();
  }

  String _nombre(double v) {
    var t = v.toStringAsFixed(3);
    t = t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return t.replaceAll('.', ',');
  }

  void _surAchete(Achat a, String texte) {
    final v = double.tryParse(texte.trim().replaceAll(',', '.'));
    setState(() {
      if (v == null || v < 0 || v > 1000000) {
        _invalides.add(a.cle);
      } else {
        _invalides.remove(a.cle);
        _achetes[a.cle] = v * uniteSaisie(a).facteur;
      }
    });
  }

  Future<void> _confirmer() async {
    final cout = centimesDepuisTexte(_cout.text);
    if (_invalides.isNotEmpty) {
      setState(() => _erreur = 'Une quantité achetée est invalide.');
      return;
    }
    if (cout == null) {
      setState(() => _erreur =
          'Entrez le coût total des courses en euros (0 si vous ne le connaissez pas).');
      return;
    }
    final rendements = [
      for (final r in calculerRendements(widget.produits, widget.liste, _achetes))
        for (final e in r.parGymnase.entries)
          Rendement(e.key, r.produitId, e.value),
    ];
    setState(() {
      _erreur = null;
      _enCours = true;
    });
    try {
      await widget.depot.validerCourses(
        widget.evenementId,
        liste: widget.liste,
        achetes: _achetes,
        rendements: rendements,
        coutCentimes: cout,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur =
              "La validation a échoué : rien n'a été ajouté au stock. Vérifiez la connexion et réessayez.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    final rendements =
        calculerRendements(widget.produits, widget.liste, _achetes);
    final noms = {for (final p in widget.produits) p.id: p.nom};
    return Scaffold(
      appBar: AppBar(title: const Text('Valider les courses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Quantités achetées', style: titre),
          const Text('Corrigez ce qui a vraiment été acheté.'),
          for (final a in _achats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(a.nom, key: Key('achat_valide_${a.cle}')),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      key: Key('achete_${a.cle}'),
                      initialValue:
                          _nombre(a.aAcheter / uniteSaisie(a).facteur),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: uniteSaisie(a).libelle,
                        errorText:
                            _invalides.contains(a.cle) ? 'Invalide' : null,
                      ),
                      onChanged: (t) => _surAchete(a, t),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Text('Ce que cela ajoute au stock', style: titre),
          if (rendements.isEmpty)
            const Text('Rien à ajouter.', key: Key('aucun_rendement')),
          for (final r in rendements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${noms[r.produitId] ?? '?'} : +${r.total}'
                '${r.parGymnase.length > 1 ? ' (${[
                    // Dans l'ordre des gymnases, pas de celui de la saisie.
                    for (final g in widget.gymnases)
                      if (r.parGymnase.containsKey(g.id))
                        '${g.nom} +${r.parGymnase[g.id]}',
                  ].join(' · ')})' : ''}'
                '${r.limitant != null ? ' — limité par ${r.limitant}' : ''}',
                key: Key('rendement_${r.produitId}'),
              ),
            ),
          const Divider(),
          TextField(
            key: const Key('cout_courses'),
            controller: _cout,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Coût total des courses (€)', suffixText: '€'),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _erreur!,
                key: const Key('erreur_validation'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('confirmer_validation'),
            onPressed: _enCours ? null : _confirmer,
            child: Text(_enCours ? 'Validation…' : 'Confirmer et ajouter au stock'),
          ),
          const SizedBox(height: 8),
          const Text(
              'Une fois validée, la liste ne peut plus être modifiée ni rejouée. '
              'Une erreur se corrige à la main dans « Gymnases et stocks ».'),
        ],
      ),
    );
  }
}

/// « 28/10/2026 à 18:42 ».
String dateHeureAffichee(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
    ' à ${heureAffichee(d)}';

/// Montant en euros pour l'affichage d'un coût.
String coutAffiche(int centimes) => formaterEuros(centimes);
