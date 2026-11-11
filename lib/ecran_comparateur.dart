import 'package:flutter/material.dart';

import 'classeur.dart';
import 'comparaison.dart';
import 'depot_evenements.dart';
import 'ecran_extraction.dart';
import 'evenement.dart';
import 'export_bilan.dart';
import 'partage.dart';
import 'previsions.dart' show consoAffichee;
import 'theme.dart';

/// Comparateur de deux tournois clôturés (décision 74) : choix de deux tournois, puis
/// leurs chiffres côte à côte et, par produit, les ventes et la consommation avec l'écart.
/// Ouvert depuis la carte « Comparer deux tournois » de l'écran « Extraction et modèle ».
class EcranComparateur extends StatefulWidget {
  const EcranComparateur({
    super.key,
    required this.depot,
    required this.uid,
    required this.responsable,
    required this.tournois,
    this.partager = partagerFichier,
  });

  final DepotEvenements depot;
  final String uid;

  /// Responsable (tout voir) ou gestionnaire (ses gymnases, pas les courses).
  final bool responsable;

  /// Les tournois clôturés proposés au choix.
  final List<Evenement> tournois;

  /// Remise du classeur à la feuille de partage (remplaçable dans les tests).
  final PartageurOctets partager;

  @override
  State<EcranComparateur> createState() => _EtatComparateur();
}

/// Les deux tournois lus, prêts à comparer.
class _Duo {
  const _Duo(this.a, this.b);

  final PhotoTournoi a;
  final PhotoTournoi b;
}

class _EtatComparateur extends State<EcranComparateur> {
  Evenement? _a;
  Evenement? _b;
  Future<_Duo>? _duo;
  bool _occupe = false;
  String? _erreur;

  Evenement? _trouver(String? id) {
    if (id == null) return null;
    return widget.tournois.where((e) => e.id == id).firstOrNull;
  }

  void _choisir({Evenement? a, Evenement? b, bool premier = true}) {
    setState(() {
      _erreur = null;
      if (premier) {
        _a = a;
        if (_b?.id == a?.id) _b = null;
      } else {
        _b = b;
      }
      _duo = _a != null && _b != null ? _lire(_a!, _b!) : null;
    });
  }

  Future<_Duo> _lire(Evenement a, Evenement b) async =>
      _Duo(await _photo(a), await _photo(b));

  Future<PhotoTournoi> _photo(Evenement ev) async {
    final portee = await porteeDe(
      depot: widget.depot,
      evenement: ev,
      uid: widget.uid,
      responsable: widget.responsable,
    );
    final d = await lireTournoi(
        depot: widget.depot, evenement: ev, portee: portee);
    var personnes = 0;
    for (final g in d.gymnases) {
      personnes += g.personnes;
    }
    return PhotoTournoi(
      nom: ev.nom,
      personnes: personnes,
      jours: ev.nbJours,
      tableau: d.tableau,
      produits: d.produits,
      cout: portee.toutVoir
          ? CoutBilan.depuis(d.courses, d.tableau.totalCentimes)
          : null,
    );
  }

  Future<void> _exporter(_Duo duo) async {
    if (_occupe) return;
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      final octets = construireComparaison(
        nomA: duo.a.nom,
        nomB: duo.b.nom,
        synthese: synthese(duo.a, duo.b),
        produits: comparerProduits(duo.a, duo.b),
      );
      await widget.partager(
        'comparaison-${nomPourFichier(duo.a.nom)}-${nomPourFichier(duo.b.nom)}.xlsx',
        octets,
        typeMimeClasseur,
      );
    } catch (_) {
      if (mounted) {
        setState(() =>
            _erreur = 'La comparaison n\'a pas pu être exportée. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  List<DropdownMenuItem<String>> _items(bool premier) => [
        for (final e in widget.tournois)
          if (premier || e.id != _a?.id)
            DropdownMenuItem<String>(
              key: Key('${premier ? 'a' : 'b'}_${e.id}'),
              value: e.id,
              child: Text(e.nom),
            ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer deux tournois')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: const Key('choix_tournoi_a'),
            isExpanded: true,
            initialValue: _a?.id,
            decoration: const InputDecoration(labelText: 'Premier tournoi'),
            items: _items(true),
            onChanged: (id) => _choisir(a: _trouver(id)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // Recréé quand le premier change : son choix se remet à jour.
            key: ValueKey('choix_tournoi_b_${_a?.id}'),
            isExpanded: true,
            initialValue: _b?.id,
            decoration: const InputDecoration(labelText: 'Second tournoi'),
            items: _items(false),
            onChanged: _a == null
                ? null
                : (id) => _choisir(b: _trouver(id), premier: false),
          ),
          const SizedBox(height: 16),
          if (_duo == null)
            const Text(
              'Choisissez deux tournois différents pour voir leurs chiffres côte à côte.',
              key: Key('comparateur_vide'),
            )
          else
            FutureBuilder<_Duo>(
              future: _duo,
              builder: (context, s) {
                if (s.hasError) {
                  return const Text(
                    'Les tournois n\'ont pas pu être lus. Vérifiez le réseau.',
                    key: Key('erreur_lecture_comparateur'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _resultat(s.data!);
              },
            ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _erreur!,
                key: const Key('erreur_comparaison'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultat(_Duo duo) {
    final lignes = synthese(duo.a, duo.b);
    final produits = comparerProduits(duo.a, duo.b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('exporter_comparaison'),
          style: TypeAction.gerer.contour,
          onPressed: _occupe ? null : () => _exporter(duo),
          icon: const Icon(Icons.ios_share),
          label: const Text('Exporter en Excel'),
        ),
        const SizedBox(height: 16),
        Text('Synthèse', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Table(
          key: const Key('synthese'),
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          border: const TableBorder(
            horizontalInside: BorderSide(color: Colors.black12),
          ),
          children: [
            TableRow(children: [
              _cellule('Indicateur', gras: true),
              _cellule(duo.a.nom, gras: true, droite: true),
              _cellule(duo.b.nom, gras: true, droite: true),
            ]),
            for (var i = 0; i < lignes.length; i++)
              TableRow(key: ValueKey('ligne_$i'), children: [
                _cellule(lignes[i].libelle),
                _cellule(texteValeur(lignes[i].a, lignes[i].unite),
                    droite: true, cle: Key('valeur_${i}_a')),
                _cellule(texteValeur(lignes[i].b, lignes[i].unite),
                    droite: true, cle: Key('valeur_${i}_b')),
              ]),
          ],
        ),
        const SizedBox(height: 16),
        Text('Par produit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Consommation : par personne et par jour. « — » : produit absent de ce '
          'tournoi, ou chiffre non calculable.',
        ),
        const SizedBox(height: 8),
        if (produits.isEmpty) const Text('Aucun produit.'),
        for (var i = 0; i < produits.length; i++)
          _carteProduit(i, produits[i], duo),
      ],
    );
  }

  Widget _carteProduit(int i, ComparaisonProduit p, _Duo duo) {
    return Card(
      key: Key('produit_$i'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.nom,
                style: const TextStyle(fontWeight: FontWeight.w700),
                key: Key('nom_produit_$i')),
            const SizedBox(height: 6),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.6),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(children: [
                  _cellule('', gras: true),
                  _cellule(duo.a.nom, gras: true, droite: true),
                  _cellule(duo.b.nom, gras: true, droite: true),
                ]),
                TableRow(children: [
                  _cellule('Vendus'),
                  _cellule(p.vendusA?.toString() ?? '—',
                      droite: true, cle: Key('vendus_${i}_a')),
                  _cellule(p.vendusB?.toString() ?? '—',
                      droite: true, cle: Key('vendus_${i}_b')),
                ]),
                TableRow(children: [
                  _cellule('Par personne et par jour'),
                  _cellule(
                      p.consoA == null ? '—' : consoAffichee(p.consoA!),
                      droite: true,
                      cle: Key('conso_${i}_a')),
                  _cellule(
                      p.consoB == null ? '—' : consoAffichee(p.consoB!),
                      droite: true,
                      cle: Key('conso_${i}_b')),
                ]),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Écart : ${texteEcart(p.ecart)}',
              key: Key('ecart_$i'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cellule(String texte,
      {bool gras = false, bool droite = false, Key? cle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(
        texte,
        key: cle,
        textAlign: droite ? TextAlign.right : TextAlign.left,
        style: gras ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
  }
}
