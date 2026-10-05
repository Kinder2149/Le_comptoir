import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'depot_menus.dart';
import 'ecran_menu.dart';

/// Nom saisi, et si on part du menu type.
typedef NomMenu = ({String nom, bool modele});

/// Demande un nom (création ou renommage d'un menu). Null si annulé.
/// [proposerModele] : à la création, propose de partir du menu type.
Future<NomMenu?> demanderNom(
  BuildContext context, {
  required String titre,
  String initial = '',
  bool proposerModele = false,
}) {
  final champ = TextEditingController(text: initial);
  var modele = false;
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
              decoration: const InputDecoration(labelText: 'Nom du menu'),
            ),
            if (proposerModele)
              CheckboxListTile(
                key: const Key('menu_type'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Partir du menu type'),
                subtitle: const Text('Produits et images prêts à l\'emploi'),
                value: modele,
                onChanged: (v) => setEtat(() => modele = v ?? false),
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
              if (nom.isNotEmpty) Navigator.pop(c, (nom: nom, modele: modele));
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
  });

  final DepotMenus depot;
  final SelecteurPhoto selecteurPhoto;

  /// Crée le menu, vide ou rempli avec le menu type (assets/menu_type.json).
  Future<void> _creer(BuildContext context, NomMenu n) async {
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
          content: Text('Menu type illisible.', key: Key('erreur_menu_type')),
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
          final n = await demanderNom(context,
              titre: 'Nouveau menu', proposerModele: true);
          if (n != null && context.mounted) await _creer(context, n);
        },
      ),
      body: StreamBuilder<List<Menu>>(
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
    );
  }
}
