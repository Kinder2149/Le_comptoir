import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'depot_menus.dart';
import 'ecran_caisse.dart';
import 'ecran_menus.dart';
import 'liste_familles.dart';
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

/// Contenu d'un menu : produits, prix, provenance (le menu n'a pas de stock).
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
    final r = await demanderProduit(context,
        produit: p, selecteurPhoto: selecteurPhoto);
    if (r == null) return;
    if (r.supprimer) {
      await depot.supprimerProduit(menuId, p!.id);
    } else if (p == null) {
      await depot.ajouterProduit(menuId,
          nom: r.nom,
          prixCentimes: r.prixCentimes,
          icone: r.icone,
          photo: r.photo,
          fiche: r.fiche);
    } else {
      await depot.modifierProduit(menuId, p.id,
          nom: r.nom,
          prixCentimes: r.prixCentimes,
          icone: r.icone,
          photo: r.photo,
          fiche: r.fiche);
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
              return ListeProduitsMenu(
                produits: produits,
                onTap: (p) => _editerProduit(context, p),
              );
            },
          ),
        );
      },
    );
  }
}

/// Produits d'un menu rangés par familles (décision 63). Sans accès à la base :
/// testable seul. Image : photo, sinon icône juste, sinon pastille aux initiales.
class ListeProduitsMenu extends StatelessWidget {
  const ListeProduitsMenu({
    super.key,
    required this.produits,
    required this.onTap,
  });

  final List<ProduitMenu> produits;
  final void Function(ProduitMenu produit) onTap;

  @override
  Widget build(BuildContext context) {
    return ListeFamilles<ProduitMenu>(
      elements: produits,
      familleDe: (p) => p.fiche.famille,
      nomDe: (p) => p.nom,
      enTete: const Padding(
        padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Text(
          "Catalogue : le stock se règle dans l'événement.",
          key: Key('bandeau_menu'),
        ),
      ),
      ligne: (context, p, couleur) => ListTile(
        key: Key('produit_${p.id}'),
        leading: p.photo != null || p.icone != null
            ? VignetteProduit(
                key: Key('vignette_${p.id}'), icone: p.icone, photo: p.photo)
            : PastilleProduit(
                key: Key('pastille_${p.id}'), nom: p.nom, couleur: couleur),
        title: Text(p.nom),
        subtitle: Text(
          formaterEuros(p.prixCentimes) +
              (p.fiche.type == 'unite'
                  ? ''
                  : ' · ${libellesTypes[p.fiche.type]}') +
              (p.fiche.provenance == 'apporte'
                  ? ' · Apporté par les bénévoles'
                  : ''),
        ),
        onTap: () => onTap(p),
      ),
    );
  }
}

/// Formulaire d'un produit de menu (nouveau si [produit] est null), en page
/// entière (décision 90). Renvoie la saisie validée, ou null si on revient sans
/// enregistrer.
Future<ProduitSaisi?> demanderProduit(
  BuildContext context, {
  ProduitMenu? produit,
  SelecteurPhoto selecteurPhoto = selecteurPhotoReel,
}) {
  return Navigator.push<ProduitSaisi>(
    context,
    MaterialPageRoute(
      builder: (c) =>
          PageProduit(produit: produit, selecteurPhoto: selecteurPhoto),
    ),
  );
}

class ProduitSaisi {
  const ProduitSaisi(this.nom, this.prixCentimes,
      {this.supprimer = false,
      this.icone,
      this.photo,
      this.fiche = FicheProduit.unite});

  final FicheProduit fiche;
  final String nom;
  final int prixCentimes;
  final bool supprimer;
  final String? icone;
  final Uint8List? photo;
}

/// Une ligne de la recette en cours de saisie.
class _LigneIngredient {
  _LigneIngredient([Ingredient? i])
      : nom = TextEditingController(text: i?.nom ?? ''),
        quantite = TextEditingController(
            text: i == null ? '' : nombrePourSaisie(i.quantite)),
        unite = i?.unite ?? 'unite',
        rayon = i?.rayon ?? 'autre';

  final TextEditingController nom;
  final TextEditingController quantite;
  String unite;
  String rayon;

  void liberer() {
    nom.dispose();
    quantite.dispose();
  }
}

/// Page d'un produit de menu, en cinq cartes : Identité, Mesure, Composition,
/// Provenance et rayon, Consommation habituelle (décision 90).
class PageProduit extends StatefulWidget {
  const PageProduit({super.key, this.produit, required this.selecteurPhoto});

  final ProduitMenu? produit;
  final SelecteurPhoto selecteurPhoto;

  @override
  State<PageProduit> createState() => _EtatPageProduit();
}

class _EtatPageProduit extends State<PageProduit> {
  late String _type = widget.produit?.fiche.type ?? 'unite';
  late final _conso = TextEditingController(
      text: widget.produit?.fiche.conso == null
          ? ''
          : nombrePourSaisie(widget.produit!.fiche.conso!));
  late final _verres = TextEditingController(
      text: widget.produit?.fiche.verresParLitre == null
          ? ''
          : nombrePourSaisie(widget.produit!.fiche.verresParLitre!));
  late final _parts = TextEditingController(
      text: widget.produit?.fiche.partsParEntier?.toString() ?? '');
  late final List<_LigneIngredient> _lignes = [
    for (final i in widget.produit?.fiche.ingredients ?? const <Ingredient>[])
      _LigneIngredient(i),
  ];

  late final _nom = TextEditingController(text: widget.produit?.nom ?? '');
  late final _prix = TextEditingController(
      text: widget.produit == null
          ? ''
          : prixPourSaisie(widget.produit!.prixCentimes));
  late String _provenance = widget.produit?.fiche.provenance ?? 'achete';
  late String _famille = widget.produit?.fiche.famille ?? 'autre';
  late String _rayon = widget.produit?.fiche.rayon ?? 'autre';
  late String? _icone = widget.produit?.icone;
  late Uint8List? _photo = widget.produit?.photo;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _prix.dispose();
    _conso.dispose();
    _verres.dispose();
    _parts.dispose();
    for (final l in _lignes) {
      l.liberer();
    }
    super.dispose();
  }

  void _valider() {
    final nom = _nom.text.trim();
    final prix = parserPrix(_prix.text);
    final conso = parserNombre(_conso.text);
    final fiche = FicheProduit(
      type: _type,
      provenance: _provenance,
      famille: _famille,
      rayon: _rayon,
      // Une consommation illisible devient -1 : refusée par la vérification.
      conso: _conso.text.trim().isEmpty ? null : (conso ?? -1),
      ingredients: _type == 'compose'
          ? [
              for (final l in _lignes)
                Ingredient(
                    l.nom.text.trim(),
                    parserNombre(l.quantite.text) ?? 0,
                    l.unite,
                    l.rayon),
            ]
          : const [],
      verresParLitre: _type == 'litre' ? parserNombre(_verres.text) : null,
      // Un nombre illisible devient 0 : refusé par la vérification.
      partsParEntier: _type == 'part' && _parts.text.trim().isNotEmpty
          ? (int.tryParse(_parts.text.trim()) ?? 0)
          : null,
    );
    final erreurFiche = fiche.erreur();
    if (nom.isEmpty || nom.length > 40) {
      setState(() => _erreur = 'Le nom est obligatoire (40 caractères max).');
    } else if (prix == null) {
      setState(() => _erreur = 'Prix invalide (exemple : 2,50).');
    } else if (erreurFiche != null) {
      setState(() => _erreur = erreurFiche);
    } else {
      Navigator.pop(
          context,
          ProduitSaisi(nom, prix, icone: _icone, photo: _photo, fiche: fiche));
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Le produit sera retiré du menu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
            key: const Key('confirmer_suppression_produit'),
            style: TypeAction.danger.plein,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.pop(context, const ProduitSaisi('', 0, supprimer: true));
  }

  String _nomAffiche() {
    final n = _nom.text.trim();
    return n.isEmpty ? 'produit' : n;
  }

  Widget _carte(Key cle, String titre, List<Widget> enfants) {
    return Card(
      key: cle,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...enfants,
          ],
        ),
      ),
    );
  }

  Widget _carteIdentite() {
    return _carte(const Key('carte_identite'), 'Identité', [
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
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: const Key('famille_produit'),
        isExpanded: true,
        initialValue: _famille,
        decoration: const InputDecoration(labelText: 'Famille'),
        items: [
          for (final f in famillesProduit)
            DropdownMenuItem(
                key: Key('famille_$f'),
                value: f,
                child: Text(libellesFamilles[f]!)),
        ],
        onChanged: (v) => setState(() => _famille = v ?? 'autre'),
      ),
      const SizedBox(height: 16),
      SelecteurImage(
        icone: _icone,
        photo: _photo,
        selecteurPhoto: widget.selecteurPhoto,
        onChanged: (i, p) => setState(() {
          _icone = i;
          _photo = p;
        }),
        onErreur: (e) => setState(() => _erreur = e),
      ),
    ]);
  }

  Widget _carteMesure() {
    return _carte(const Key('carte_mesure'), 'Mesure', [
      DropdownButtonFormField<String>(
        key: const Key('type_produit'),
        isExpanded: true,
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Type de produit'),
        items: [
          for (final t in typesProduit)
            DropdownMenuItem(
                key: Key('type_$t'), value: t, child: Text(libellesTypes[t]!)),
        ],
        onChanged: (v) => setState(() {
          _type = v ?? 'unite';
          _erreur = null;
        }),
      ),
      if (_type == 'litre') ...[
        const SizedBox(height: 12),
        TextField(
          key: const Key('verres_par_litre'),
          controller: _verres,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Verres par litre'),
        ),
        ListenableBuilder(
          listenable: _verres,
          builder: (context, _) {
            final v = parserNombre(_verres.text);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                v == null || v <= 0
                    ? '1 litre : indiquez le nombre de verres.'
                    : '1 litre = ${nombrePourSaisie(v)} verres',
                key: const Key('conversion_litre'),
              ),
            );
          },
        ),
      ],
      if (_type == 'part') ...[
        const SizedBox(height: 12),
        TextField(
          key: const Key('parts_par_gateau'),
          controller: _parts,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Parts par gâteau', helperText: 'Facultatif'),
        ),
        ListenableBuilder(
          listenable: _parts,
          builder: (context, _) {
            final p = int.tryParse(_parts.text.trim());
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p == null || p <= 0
                    ? '1 gâteau : nombre de parts facultatif.'
                    : '1 gâteau = $p parts',
                key: const Key('conversion_part'),
              ),
            );
          },
        ),
      ],
    ]);
  }

  Widget _carteComposition() {
    return _carte(const Key('carte_composition'), 'Composition', [
      if (_type != 'compose')
        const Text(
            'Un produit composé se choisit dans Type de produit : ses ingrédients s\'affichent ici.'),
      if (_type == 'compose') ...[
        ListenableBuilder(
          listenable: _nom,
          builder: (context, _) => Text(
            'Pour 1 ${_nomAffiche()}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (var i = 0; i < _lignes.length; i++) _ligneIngredient(i),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('ajouter_ingredient'),
            icon: const Icon(Icons.add),
            label: const Text('Ingrédient'),
            onPressed: () => setState(() => _lignes.add(_LigneIngredient())),
          ),
        ),
      ],
    ]);
  }

  Widget _ligneIngredient(int i) {
    final l = _lignes[i];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('ingredient_nom_$i'),
                  controller: l.nom,
                  decoration:
                      InputDecoration(labelText: 'Ingrédient ${i + 1}'),
                ),
              ),
              IconButton(
                key: Key('retirer_ingredient_$i'),
                tooltip: 'Retirer cet ingrédient',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _lignes.removeAt(i)),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  key: Key('ingredient_qte_$i'),
                  controller: l.quantite,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantité'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  key: Key('ingredient_unite_$i'),
                  isExpanded: true,
                  value: l.unite,
                  items: [
                    for (final u in unitesIngredient)
                      DropdownMenuItem(
                          key: Key('unite_${i}_$u'),
                          value: u,
                          child: Text(libellesUnites[u]!)),
                  ],
                  onChanged: (v) => setState(() => l.unite = v ?? 'unite'),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: Key('ingredient_rayon_$i'),
            isExpanded: true,
            initialValue: l.rayon,
            decoration: const InputDecoration(labelText: 'Rayon'),
            items: [
              for (final r in rayonsCourses)
                DropdownMenuItem(
                    key: Key('rayon_${i}_$r'),
                    value: r,
                    child: Text(libellesRayons[r]!)),
            ],
            onChanged: (v) => setState(() => l.rayon = v ?? 'autre'),
          ),
        ],
      ),
    );
  }

  Widget _carteProvenance() {
    return _carte(const Key('carte_provenance'), 'Provenance et rayon', [
      DropdownButtonFormField<String>(
        key: const Key('provenance_produit'),
        isExpanded: true,
        initialValue: _provenance,
        decoration: const InputDecoration(labelText: 'Provenance'),
        items: [
          for (final v in provenancesProduit)
            DropdownMenuItem(
                key: Key('provenance_$v'),
                value: v,
                child: Text(libellesProvenances[v]!)),
        ],
        onChanged: (v) => setState(() => _provenance = v ?? 'achete'),
      ),
      if (_type != 'compose' && _provenance == 'achete') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('rayon_produit'),
          isExpanded: true,
          initialValue: _rayon,
          decoration: const InputDecoration(labelText: 'Rayon des courses'),
          items: [
            for (final r in rayonsCourses)
              DropdownMenuItem(
                  key: Key('rayon_$r'),
                  value: r,
                  child: Text(libellesRayons[r]!)),
          ],
          onChanged: (v) => setState(() => _rayon = v ?? 'autre'),
        ),
      ],
      if (_type == 'compose') ...[
        const SizedBox(height: 12),
        const Text('Un produit composé se range ingrédient par ingrédient.'),
      ],
    ]);
  }

  Widget _carteConsommation() {
    return _carte(const Key('carte_consommation'), 'Consommation habituelle', [
      const Text('Sert quand les repas ne sont pas détaillés.'),
      const SizedBox(height: 12),
      TextField(
        key: const Key('conso_produit'),
        controller: _conso,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
            labelText: 'Consommation par personne et par jour',
            helperText: 'Facultatif'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final erreur = _erreur;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.produit == null ? 'Nouveau produit' : 'Produit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _carteIdentite(),
            _carteMesure(),
            _carteComposition(),
            _carteProvenance(),
            _carteConsommation(),
            if (widget.produit != null) ...[
              const SizedBox(height: 4),
              OutlinedButton(
                key: const Key('supprimer_produit'),
                style: TypeAction.danger.contour,
                onPressed: _supprimer,
                child: const Text('Supprimer ce produit'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (erreur != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(erreur,
                      key: const Key('erreur_produit'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              FilledButton(
                key: const Key('valider_produit'),
                style: TypeAction.gerer.plein,
                onPressed: _valider,
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix de l'image d'un produit : aperçu, photo (galerie ou appareil) et icônes
/// modèles. Sert au formulaire du produit de menu et à l'image d'un produit
/// d'événement. [onErreur] reçoit le message d'une photo refusée (null = effacé).
class SelecteurImage extends StatefulWidget {
  const SelecteurImage({
    super.key,
    required this.icone,
    required this.photo,
    required this.selecteurPhoto,
    required this.onChanged,
    required this.onErreur,
  });

  final String? icone;
  final Uint8List? photo;
  final SelecteurPhoto selecteurPhoto;
  final void Function(String? icone, Uint8List? photo) onChanged;
  final ValueChanged<String?> onErreur;

  @override
  State<SelecteurImage> createState() => _EtatSelecteurImage();
}

class _EtatSelecteurImage extends State<SelecteurImage> {
  late String? _icone = widget.icone;
  late Uint8List? _photo = widget.photo;

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
    if (octets.length > tailleMaxPhoto) {
      widget.onErreur('Photo trop lourde. Choisissez-en une autre.');
      return;
    }
    setState(() => _photo = octets);
    widget.onErreur(null);
    widget.onChanged(_icone, _photo);
  }

  void _changer({String? icone, Uint8List? photo}) {
    setState(() {
      _icone = icone;
      _photo = photo;
    });
    widget.onChanged(_icone, _photo);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image', style: Theme.of(context).textTheme.labelLarge),
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
                      onPressed: () => _changer(icone: _icone),
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
                label: VignetteProduit(icone: cle, taille: 28),
                selected: _icone == cle,
                onSelected: (v) => _changer(icone: v ? cle : null, photo: _photo),
              ),
          ],
        ),
      ],
    );
  }
}

/// Nouvelle image d'un produit d'événement (icône et/ou photo, ou aucune).
class ImageChoisie {
  const ImageChoisie(this.icone, this.photo);

  final String? icone;
  final Uint8List? photo;
}

/// Change l'image d'un produit d'événement : le nom et le prix restent figés.
/// Renvoie le nouveau choix, ou null si on annule.
Future<ImageChoisie?> demanderImageProduit(
  BuildContext context, {
  required String nom,
  String? icone,
  Uint8List? photo,
  SelecteurPhoto selecteurPhoto = selecteurPhotoReel,
}) {
  return showDialog<ImageChoisie>(
    context: context,
    builder: (c) => _DialogueImage(
        nom: nom, icone: icone, photo: photo, selecteurPhoto: selecteurPhoto),
  );
}

class _DialogueImage extends StatefulWidget {
  const _DialogueImage({
    required this.nom,
    required this.icone,
    required this.photo,
    required this.selecteurPhoto,
  });

  final String nom;
  final String? icone;
  final Uint8List? photo;
  final SelecteurPhoto selecteurPhoto;

  @override
  State<_DialogueImage> createState() => _EtatDialogueImage();
}

class _EtatDialogueImage extends State<_DialogueImage> {
  late String? _icone = widget.icone;
  late Uint8List? _photo = widget.photo;
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Image : ${widget.nom}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelecteurImage(
              icone: _icone,
              photo: _photo,
              selecteurPhoto: widget.selecteurPhoto,
              onChanged: (i, p) {
                _icone = i;
                _photo = p;
              },
              onErreur: (e) => setState(() => _erreur = e),
            ),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erreur!,
                    key: const Key('erreur_image'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          key: const Key('valider_image'),
          onPressed: () => Navigator.pop(context, ImageChoisie(_icone, _photo)),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
