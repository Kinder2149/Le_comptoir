import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LengthLimitingTextInputFormatter, rootBundle;

import 'classeur.dart';
import 'depot_menus.dart';
import 'ecran_menu.dart';
import 'import_menu.dart';
import 'resume_import.dart';
import 'selecteur.dart';
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
    this.choisirClasseur = choisirClasseurSysteme,
  });

  final DepotMenus depot;
  final SelecteurPhoto selecteurPhoto;

  /// Choisit le classeur Excel à importer (remplaçable dans les tests).
  final SelecteurClasseur choisirClasseur;

  void _dire(BuildContext context, String phrase, Key cle) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(phrase, key: cle)));
  }

  /// Importer un menu : fichier, lecture, résumé AVANT écriture, nom, création d'un
  /// NOUVEAU menu. Rien n'est écrit tant que « Créer le menu » n'est pas touché.
  Future<void> _importer(BuildContext context) async {
    final navigateur = Navigator.of(context);
    final Uint8List? octets;
    try {
      octets = await choisirClasseur();
    } catch (_) {
      if (context.mounted) {
        _dire(context, 'Le choix du fichier n\'a pas pu s\'ouvrir. Réessayez.',
            const Key('erreur_import_menu'));
      }
      return;
    }
    if (octets == null || !context.mounted) return; // annulé : rien ne change
    final ClasseurLu lu;
    try {
      lu = lireClasseur(octets);
    } on ClasseurIllisible {
      _dire(context, messageMenuIllisible, const Key('erreur_import_menu'));
      return;
    }
    final plan = preparerMenu(lu);
    if (plan.vide) {
      _dire(context, plan.messageVide, const Key('erreur_import_menu'));
      return;
    }
    final accepte = await navigateur.push<bool>(MaterialPageRoute(
      builder: (_) => EcranResumeImport(
        titre: 'Résumé de l\'import du menu',
        cleAppliquer: const Key('appliquer_import_menu'),
        libelleAppliquer: 'Créer le menu',
        ignorees: plan.ignorees,
        erreurs: plan.erreurs,
        corps: [
          Text(plan.phraseMenu,
              key: const Key('resume_menu'),
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ));
    if (accepte != true || !context.mounted) return;
    final menus = await depot.suivreMenus().first;
    if (!context.mounted) return;
    final n = await demanderNom(context, titre: 'Nom du nouveau menu', menus: menus);
    if (n == null || !context.mounted) return;
    try {
      await depot.creerMenuDepuisClasseur(n.nom, plan.aCreer);
      if (context.mounted) {
        _dire(
            context,
            'Menu « ${n.nom} » créé : ${plan.produits.length} '
            'produit${plan.produits.length > 1 ? 's' : ''}.',
            const Key('confirmation_import_menu'));
      }
    } catch (_) {
      if (context.mounted) {
        _dire(
            context,
            'Le menu n\'a pas pu être créé. Vérifiez le réseau puis réessayez.',
            const Key('erreur_import_menu'));
      }
    }
  }

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('importer_menu'),
                style: TypeAction.gerer.contour,
                onPressed: () => _importer(context),
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
