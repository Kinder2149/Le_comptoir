import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'depot_menus.dart';
import 'ecran_caisse.dart';
import 'ecran_menus.dart';
import 'theme.dart';
import 'ticket.dart';

/// D'où vient la photo d'un produit.
enum SourcePhoto { galerie, camera }

/// Choisit une photo et la renvoie réduite en vignette (octets), ou null si on
/// annule. Remplaçable dans les tests.
typedef SelecteurPhoto = Future<Uint8List?> Function(SourcePhoto source);

/// Vrai sélecteur : galerie ou appareil photo, image réduite à 96 px et
/// compressée par le système avant d'être lue (pas de service d'images
/// extérieur : la vignette est stockée avec le produit).
Future<Uint8List?> selecteurPhotoReel(SourcePhoto source) async {
  final fichier = await ImagePicker().pickImage(
    source: source == SourcePhoto.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 96,
    maxHeight: 96,
    imageQuality: 70,
  );
  return fichier?.readAsBytes();
}

/// Contenu d'un menu : produits, prix, stock facultatif.
class EcranMenu extends StatelessWidget {
  const EcranMenu({
    super.key,
    required this.depot,
    required this.menuId,
    this.selecteurPhoto = selecteurPhotoReel,
  });

  final DepotMenus depot;
  final String menuId;
  final SelecteurPhoto selecteurPhoto;

  Future<void> _renommer(BuildContext context, Menu menu) async {
    final n = await demanderNom(context,
        titre: 'Renommer le menu', initial: menu.nom);
    if (n != null) await depot.renommerMenu(menuId, n.nom);
  }

  Future<void> _supprimer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce menu ?'),
        content: const Text('Le menu et tous ses produits seront supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              style: TypeAction.danger.plein,
              key: const Key('confirmer_suppression'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await depot.supprimerMenu(menuId);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _editerProduit(BuildContext context, [ProduitMenu? p]) async {
    final r = await showDialog<_ResultatProduit>(
      context: context,
      builder: (c) =>
          _DialogueProduit(produit: p, selecteurPhoto: selecteurPhoto),
    );
    if (r == null) return;
    if (r.supprimer) {
      await depot.supprimerProduit(menuId, p!.id);
    } else if (p == null) {
      await depot.ajouterProduit(menuId,
          nom: r.nom,
          prixCentimes: r.prixCentimes,
          stock: r.stock,
          icone: r.icone,
          photo: r.photo);
    } else {
      await depot.modifierProduit(menuId, p.id,
          nom: r.nom,
          prixCentimes: r.prixCentimes,
          stock: r.stock,
          icone: r.icone,
          photo: r.photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Menu?>(
      stream: depot.suivreMenu(menuId),
      builder: (context, m) {
        final menu = m.data;
        if (menu == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(menu.nom, key: const Key('titre_menu')),
            actions: [
              IconButton(
                key: const Key('renommer_menu'),
                icon: const Icon(Icons.edit),
                onPressed: () => _renommer(context, menu),
              ),
              IconButton(
                key: const Key('supprimer_menu'),
                icon: const Icon(Icons.delete),
                onPressed: () => _supprimer(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('nouveau_produit'),
            icon: const Icon(Icons.add),
            label: const Text('Produit'),
            onPressed: () => _editerProduit(context),
          ),
          body: StreamBuilder<List<ProduitMenu>>(
            stream: depot.suivreProduits(menuId),
            builder: (context, s) {
              final produits = s.data;
              if (produits == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (produits.isEmpty) {
                return const Center(
                    child: Text('Aucun produit.', key: Key('aucun_produit')));
              }
              return ListView(
                children: [
                  for (final p in produits)
                    ListTile(
                      key: Key('produit_${p.id}'),
                      leading: VignetteProduit(
                          key: Key('vignette_${p.id}'),
                          icone: p.icone,
                          photo: p.photo),
                      title: Text(p.nom),
                      subtitle: Text(
                        formaterEuros(p.prixCentimes) +
                            (p.stock == null ? '' : ' · Stock : ${p.stock}'),
                      ),
                      onTap: () => _editerProduit(context, p),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ResultatProduit {
  const _ResultatProduit(this.nom, this.prixCentimes, this.stock,
      {this.supprimer = false, this.icone, this.photo});

  final String nom;
  final int prixCentimes;
  final int? stock;
  final bool supprimer;
  final String? icone;
  final Uint8List? photo;
}

class _DialogueProduit extends StatefulWidget {
  const _DialogueProduit({this.produit, required this.selecteurPhoto});

  final ProduitMenu? produit;
  final SelecteurPhoto selecteurPhoto;

  @override
  State<_DialogueProduit> createState() => _EtatDialogueProduit();
}

class _EtatDialogueProduit extends State<_DialogueProduit> {
  late final _nom = TextEditingController(text: widget.produit?.nom ?? '');
  late final _prix = TextEditingController(
      text: widget.produit == null
          ? ''
          : prixPourSaisie(widget.produit!.prixCentimes));
  late final _quantite =
      TextEditingController(text: '${widget.produit?.stock ?? ''}');
  late bool _suivi = widget.produit?.stock != null;
  late String? _icone = widget.produit?.icone;
  late Uint8List? _photo = widget.produit?.photo;
  String? _erreur;

  Future<void> _choisirPhoto() async {
    final source = await showDialog<SourcePhoto>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Photo du produit'),
        children: [
          SimpleDialogOption(
            key: const Key('photo_galerie'),
            onPressed: () => Navigator.pop(c, SourcePhoto.galerie),
            child: const Text('Choisir dans la galerie'),
          ),
          SimpleDialogOption(
            key: const Key('photo_camera'),
            onPressed: () => Navigator.pop(c, SourcePhoto.camera),
            child: const Text('Prendre une photo'),
          ),
        ],
      ),
    );
    if (source == null) return;
    final octets = await widget.selecteurPhoto(source);
    if (octets == null || !mounted) return;
    setState(() {
      if (octets.length > tailleMaxPhoto) {
        _erreur = 'Photo trop lourde. Choisissez-en une autre.';
      } else {
        _photo = octets;
        _erreur = null;
      }
    });
  }

  @override
  void dispose() {
    _nom.dispose();
    _prix.dispose();
    _quantite.dispose();
    super.dispose();
  }

  void _valider() {
    final nom = _nom.text.trim();
    final prix = parserPrix(_prix.text);
    final stock = _suivi ? int.tryParse(_quantite.text.trim()) : null;
    if (nom.isEmpty || nom.length > 40) {
      setState(() => _erreur = 'Le nom est obligatoire (40 caractères max).');
    } else if (prix == null) {
      setState(() => _erreur = 'Prix invalide (exemple : 2,50).');
    } else if (_suivi && (stock == null || stock < 0 || stock > 100000)) {
      setState(() => _erreur = 'Quantité en stock invalide.');
    } else {
      Navigator.pop(context,
          _ResultatProduit(nom, prix, stock, icone: _icone, photo: _photo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.produit == null ? 'Nouveau produit' : 'Produit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('nom_produit'),
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('prix_produit'),
              controller: _prix,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix en €'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Image', style: Theme.of(context).textTheme.labelLarge),
            ),
            Row(
              children: [
                VignetteProduit(
                    key: const Key('apercu_produit'),
                    icone: _icone,
                    photo: _photo,
                    taille: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: [
                      OutlinedButton(
                        key: const Key('ajouter_photo'),
                        onPressed: _choisirPhoto,
                        child: Text(_photo == null ? 'Ajouter une photo' : 'Changer la photo'),
                      ),
                      if (_photo != null)
                        TextButton(
                          key: const Key('retirer_photo'),
                          onPressed: () => setState(() => _photo = null),
                          child: const Text('Retirer la photo'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cle in cleIcones)
                  ChoiceChip(
                    key: Key('icone_$cle'),
                    label: Icon(iconeDe(cle), size: 20),
                    selected: _icone == cle,
                    onSelected: (v) => setState(() => _icone = v ? cle : null),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('suivi_stock'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Suivre le stock'),
              value: _suivi,
              onChanged: (v) => setState(() => _suivi = v),
            ),
            if (_suivi)
              TextField(
                key: const Key('quantite_stock'),
                controller: _quantite,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité en stock'),
              ),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erreur!,
                    key: const Key('erreur_produit'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.produit != null)
          TextButton(
            key: const Key('supprimer_produit'),
            style: TypeAction.danger.texte,
            onPressed: () => Navigator.pop(
                context, const _ResultatProduit('', 0, null, supprimer: true)),
            child: const Text('Supprimer'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          key: const Key('valider_produit'),
          onPressed: _valider,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
