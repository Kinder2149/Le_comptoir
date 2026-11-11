import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LengthLimitingTextInputFormatter, rootBundle;

import 'depot_menus.dart';
import 'ecran_menu.dart';
import 'theme.dart';

/// Nom saisi, et d'où l'on part : le modèle, la copie d'un menu (son id), ou rien.
typedef NomMenu = ({String nom, bool modele, String? copieDe});

/// Demande un nom (création ou renommage d'un menu). Null si annulé.
/// [proposerModele] : à la création, propose de partir du modèle ou de copier un des [menus].
Future<NomMenu?> demanderNom(
  BuildContext context, {
  required String titre,
  String initial = '',
  bool proposerModele = false,
  List<Menu> menus = const [],
}) {
  final champ = TextEditingController(text: initial);
  var modele = false;
  String? copieDe;
  return showDialog<NomMenu>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setEtat) => AlertDialog(
        title: Text(titre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('nom_menu'),
              controller: champ,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              decoration: const InputDecoration(labelText: 'Nom du menu'),
            ),
            if (proposerModele)
              CheckboxListTile(
                key: const Key('menu_type'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Partir du modèle'),
                subtitle: const Text('Produits, recettes et logos prêts à l\'emploi'),
                value: modele,
                onChanged: (v) => setEtat(() {
                  modele = v ?? false;
                  if (modele) copieDe = null;
                }),
              ),
            if (proposerModele && menus.isNotEmpty)
              DropdownButtonFormField<String?>(
                key: const Key('copie_menu'),
                initialValue: copieDe,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Ou copier un menu existant'),
                items: [
                  const DropdownMenuItem<String?>(
                      key: Key('copie_aucune'), value: null, child: Text('Aucun')),
                  for (final m in menus)
                    DropdownMenuItem<String?>(
                        key: Key('copie_${m.id}'), value: m.id, child: Text(m.nom)),
                ],
                onChanged: (v) => setEtat(() {
                  copieDe = v;
                  if (v != null) modele = false;
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            key: const Key('valider_nom'),
            onPressed: () {
              final nom = champ.text.trim();
              if (nom.isNotEmpty) {
                Navigator.pop(c, (nom: nom, modele: modele, copieDe: copieDe));
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
}

/// Liste des menus de l'association (responsable et gestionnaires).
class EcranMenus extends StatelessWidget {
  const EcranMenus({
    super.key,
    required this.depot,
    this.selecteurPhoto = selecteurPhotoReel,
    this.assistant,
  });

  final DepotMenus depot;
  final SelecteurPhoto selecteurPhoto;

  /// L'assistant d'import (T2, décision 77), fourni par l'écran de l'association : « Importer
  /// un menu depuis Excel » y renvoie. Absent : pas de bouton d'import.
  final WidgetBuilder? assistant;

  /// Crée le menu : copie d'un menu, modèle (assets/menu_type.json) ou vide.
  Future<void> _creer(BuildContext context, NomMenu n) async {
    if (n.copieDe != null) {
      await depot.copierMenu(n.copieDe!, n.nom);
      return;
    }
    if (!n.modele) {
      await depot.creerMenu(n.nom);
      return;
    }
    try {
      final json = await rootBundle.loadString('assets/menu_type.json');
      await depot.creerMenuDepuisModele(n.nom, lireMenuType(json));
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Modèle illisible.', key: Key('erreur_menu_type')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menus')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nouveau_menu'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau menu'),
        onPressed: () async {
          final menus = await depot.suivreMenus().first;
          if (!context.mounted) return;
          final n = await demanderNom(context,
              titre: 'Nouveau menu', proposerModele: true, menus: menus);
          if (n != null && context.mounted) await _creer(context, n);
        },
      ),
      body: Column(
        children: [
          if (assistant != null)
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('importer_menu'),
                style: TypeAction.gerer.contour,
                onPressed: () => Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: assistant!)),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer un menu depuis Excel'),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Menu>>(
              stream: depot.suivreMenus(),
              builder: (context, s) {
                final menus = s.data;
                if (menus == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (menus.isEmpty) {
                  return const Center(
                    child: Text('Aucun menu. Créez le premier.',
                        key: Key('aucun_menu')),
                  );
                }
                return ListView(
                  children: [
                    for (final m in menus)
                      ListTile(
                        key: Key('menu_${m.id}'),
                        title: Text(m.nom),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EcranMenu(
                              depot: depot,
                              menuId: m.id,
                              selecteurPhoto: selecteurPhoto,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
