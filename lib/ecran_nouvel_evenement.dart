import 'package:flutter/material.dart';

import 'depot_evenements.dart';
import 'depot_menus.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';

/// Création d'un événement, ou modification (nom, date, modes) d'un existant.
class EcranNouvelEvenement extends StatefulWidget {
  const EcranNouvelEvenement({
    super.key,
    required this.depot,
    required this.depotMenus,
    this.existant,
  });

  final DepotEvenements depot;
  final DepotMenus depotMenus;
  final Evenement? existant;

  @override
  State<EcranNouvelEvenement> createState() => _EtatNouvelEvenement();
}

class _EtatNouvelEvenement extends State<EcranNouvelEvenement> {
  late final _nom = TextEditingController(text: widget.existant?.nom ?? '');
  late DateTime _date = widget.existant == null
      ? DateTime.now()
      : (dateDepuisIso(widget.existant!.date) ?? DateTime.now());
  late final Set<String> _modes = {
    ...?widget.existant?.modes,
    if (widget.existant == null) 'especes',
  };
  // Noms des gymnases (création seulement) : un champ par gymnase.
  final List<TextEditingController> _gymnases = [
    TextEditingController(text: nomGymnaseParDefaut),
  ];
  String? _menuId;
  String? _erreur;
  bool _occupe = false;

  @override
  void dispose() {
    _nom.dispose();
    for (final c in _gymnases) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _valider() async {
    if (_nom.text.trim().isEmpty) {
      setState(() => _erreur = "Donnez un nom à l'événement.");
      return;
    }
    if (widget.existant == null && _menuId == null) {
      setState(() => _erreur = 'Choisissez un menu.');
      return;
    }
    if (_modes.isEmpty) {
      setState(() => _erreur = 'Choisissez au moins un mode de paiement.');
      return;
    }
    if (widget.existant == null) {
      final erreur = erreurNomsGymnases([for (final c in _gymnases) c.text]);
      if (erreur != null) {
        setState(() => _erreur = erreur);
        return;
      }
    }
    setState(() {
      _erreur = null;
      _occupe = true;
    });
    final modes = [
      for (final k in modesPaiement.keys)
        if (_modes.contains(k)) k,
    ];
    try {
      if (widget.existant == null) {
        await widget.depot.creerEvenement(
          nom: _nom.text,
          date: dateIso(_date),
          menuId: _menuId!,
          modes: modes,
          gymnases: [for (final c in _gymnases) c.text.trim()],
        );
      } else {
        await widget.depot.modifierEvenement(
          widget.existant!.id,
          nom: _nom.text,
          date: dateIso(_date),
          modes: modes,
        );
      }
      if (mounted) Navigator.pop(context);
    } on MenuVide {
      if (mounted) {
        setState(() {
          _erreur = 'Ce menu ne contient aucun produit.';
          _occupe = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erreur = 'Enregistrement impossible. Vérifiez le réseau.';
          _occupe = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creation = widget.existant == null;
    return Scaffold(
      appBar: AppBar(
          title: Text(creation ? 'Nouvel événement' : "Modifier l'événement")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('nom_evenement'),
            controller: _nom,
            decoration: const InputDecoration(labelText: "Nom de l'événement"),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('choisir_date'),
            icon: const Icon(Icons.event),
            label: Text('Date : ${dateAffichee(dateIso(_date))}'),
            onPressed: _choisirDate,
          ),
          const Divider(height: 32),
          if (creation) ...[
            Text('Menu', style: Theme.of(context).textTheme.titleMedium),
            StreamBuilder<List<Menu>>(
              stream: widget.depotMenus.suivreMenus(),
              builder: (context, s) {
                final menus = s.data;
                if (menus == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (menus.isEmpty) {
                  return const Text("Créez d'abord un menu.",
                      key: Key('aucun_menu_choix'));
                }
                return RadioGroup<String>(
                  groupValue: _menuId,
                  onChanged: (v) => setState(() => _menuId = v),
                  child: Column(
                    children: [
                      for (final m in menus)
                        RadioListTile<String>(
                          key: Key('choix_menu_${m.id}'),
                          title: Text(m.nom),
                          value: m.id,
                        ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 32),
            Text('Gymnases', style: Theme.of(context).textTheme.titleMedium),
            const Text(
                'Tous les gymnases ont le même menu ; chacun a son propre stock.'),
            for (var i = 0; i < _gymnases.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: Key('nom_gymnase_$i'),
                      controller: _gymnases[i],
                      decoration: InputDecoration(labelText: 'Gymnase ${i + 1}'),
                    ),
                  ),
                  if (_gymnases.length > 1)
                    IconButton(
                      key: Key('retirer_gymnase_$i'),
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Retirer ce gymnase',
                      onPressed: () => setState(() {
                        _gymnases.removeAt(i).dispose();
                      }),
                    ),
                ],
              ),
              ),
            if (_gymnases.length < maxGymnases)
              Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('ajouter_gymnase_formulaire'),
                style: TypeAction.gerer.texte,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un gymnase'),
                onPressed: () =>
                    setState(() => _gymnases.add(TextEditingController())),
              ),
            ),
            const Divider(height: 32),
          ],
          Text('Modes de paiement acceptés',
              style: Theme.of(context).textTheme.titleMedium),
          for (final e in modesPaiement.entries)
            CheckboxListTile(
              key: Key('mode_${e.key}'),
              title: Text(e.value),
              value: _modes.contains(e.key),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _modes.add(e.key);
                } else {
                  _modes.remove(e.key);
                }
              }),
            ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_erreur!,
                  key: const Key('erreur_evenement'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('valider_evenement'),
            onPressed: _occupe ? null : _valider,
            child: Text(creation ? "Créer l'événement" : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
