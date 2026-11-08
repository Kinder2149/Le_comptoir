import 'dart:async';

import 'package:flutter/material.dart';

import 'courses.dart' show demiJournee, joursMax, personnesMax;

/// Message affiché quand une saisie n'a pas pu être enregistrée.
void montrerErreurEnregistrement(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Enregistrement impossible. Vérifiez le réseau.',
        key: Key('erreur_preparation')),
  ));
}

/// Durée valide : 0,5 à [joursMax] jours (virgule ou point). Sinon null.
double? lireJours(String saisie) {
  final n = double.tryParse(saisie.trim().replaceAll(',', '.'));
  return n == null || n < demiJournee || n > joursMax ? null : n;
}

String afficherJours(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');

/// Personnes valides : entier de 0 à [personnesMax]. Sinon null.
int? lirePersonnes(String saisie) {
  final n = int.tryParse(saisie.trim());
  return n == null || n < 0 || n > personnesMax ? null : n;
}

/// Un réglage numérique : saisi (enregistré quand on valide, qu'on quitte le champ
/// ou après une courte pause) ou lu. Une valeur hors limites affiche un message et
/// n'écrit rien. Clés : `champ_<id>`, `lecture_<id>`, `enregistre_<id>`.
class ChampReglage<T extends num> extends StatefulWidget {
  const ChampReglage({
    super.key,
    required this.id,
    required this.etiquette,
    required this.messageErreur,
    required this.valeur,
    required this.reglable,
    required this.lire,
    required this.afficher,
    required this.enregistrer,
  });

  final String id;
  final String etiquette;
  final String messageErreur;
  final T valeur;
  final bool reglable;
  final T? Function(String saisie) lire;
  final String Function(T valeur) afficher;
  final Future<void> Function(T valeur) enregistrer;

  @override
  State<ChampReglage<T>> createState() => _EtatChampReglage<T>();
}

class _EtatChampReglage<T extends num> extends State<ChampReglage<T>> {
  late final TextEditingController _texte =
      TextEditingController(text: widget.afficher(widget.valeur));
  final FocusNode _focus = FocusNode();
  Timer? _pause;
  bool _modifie = false;
  String? _erreur;
  bool _enregistre = false;

  /// Dernière valeur écrite, tant que la valeur lue n'a pas rattrapé (évite de
  /// prendre un retour à l'ancienne valeur pour « rien à écrire »).
  T? _ecrit;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _valider();
    });
  }

  @override
  void didUpdateWidget(ChampReglage<T> ancien) {
    super.didUpdateWidget(ancien);
    if (widget.valeur != ancien.valeur) _ecrit = null;
    // Une valeur venue d'ailleurs remplace le champ, sauf pendant qu'on le modifie.
    if (!_modifie && !_focus.hasFocus) {
      final attendu = widget.afficher(widget.valeur);
      if (_texte.text != attendu) _texte.text = attendu;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    if (_modifie) {
      final n = widget.lire(_texte.text);
      if (n != null && n != (_ecrit ?? widget.valeur)) {
        widget.enregistrer(n).catchError((_) {});
      }
    }
    _texte.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    _pause?.cancel();
    if (!_modifie) return;
    final n = widget.lire(_texte.text);
    if (n == null) {
      setState(() {
        _erreur = widget.messageErreur;
        _enregistre = false;
      });
      return;
    }
    // Marqué « envoyé » avant l'attente : valider puis quitter le champ n'écrit qu'une fois.
    setState(() {
      _erreur = null;
      _modifie = false;
    });
    if (n == (_ecrit ?? widget.valeur)) return;
    try {
      await widget.enregistrer(n);
      _ecrit = n;
      if (mounted) setState(() => _enregistre = true);
    } catch (_) {
      _modifie = true;
      if (mounted) montrerErreurEnregistrement(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.reglable) {
      return Text('${widget.etiquette} : ${widget.afficher(widget.valeur)}',
          key: Key('lecture_${widget.id}'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: Key('champ_${widget.id}'),
          controller: _texte,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.etiquette,
            errorText: _erreur,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            _modifie = true;
            _enregistre = false;
            _pause?.cancel();
            _pause = Timer(const Duration(milliseconds: 900), _valider);
          },
          onSubmitted: (_) => _valider(),
        ),
        if (_enregistre && !_modifie && _erreur == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Enregistré', key: Key('enregistre_${widget.id}')),
          ),
      ],
    );
  }
}
