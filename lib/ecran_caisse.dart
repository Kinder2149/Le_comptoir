import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'depot_menus.dart' show FicheProduit;
import 'evenement.dart';
import 'unites_affichees.dart';
import 'gymnase.dart';
import 'theme.dart';
import 'ticket.dart';

/// Fond d'un produit selon l'état de son stock (null = fond habituel).
Color? fondEtat(EtatStock e) => switch (e) {
  EtatStock.epuise || EtatStock.vide => Palette.briqueDoux,
  EtatStock.bas => Palette.ocreDoux,
  _ => null,
};

/// Couleur du texte d'état (null = couleur habituelle).
Color? couleurEtat(EtatStock e) => switch (e) {
  EtatStock.epuise || EtatStock.vide => Palette.briqueFonce,
  EtatStock.bas => Palette.ocreFonce,
  _ => null,
};

/// Libellé d'état, avec la quantité quand il y en a une.
String libelleEtat(EtatStock e, int? quantite) => switch (e) {
  EtatStock.epuise => 'Épuisé',
  EtatStock.vide => 'Vide',
  EtatStock.bas => 'Stock bas : $quantite',
  EtatStock.normal => 'Stock : $quantite',
  EtatStock.aucun => '',
};

/// Illustration de chaque icône modèle (mêmes clés que [cleIcones]).
const iconesModeles = <String, IconData>{
  'croque': Icons.lunch_dining,
  'salade': Icons.eco,
  'fruit': Icons.apple,
  'the': Icons.emoji_food_beverage,
  'cafe': Icons.coffee,
  'barre': Icons.cookie,
  'soda': Icons.local_drink,
  'gateau_sucre': Icons.cake,
  'gateau_sale': Icons.bakery_dining,
  'crepe': Icons.breakfast_dining,
  'biere': Icons.sports_bar,
  'eau': Icons.water_drop,
  'frites': Icons.fastfood,
  'glace': Icons.icecream,
  'tarte': Icons.pie_chart,
};

/// Logos fournis par l'association pour certaines clés (assets/logos/) : ils
/// remplacent l'icône du système. Les autres clés gardent leur icône.
const logosModeles = <String, String>{
  'croque': 'assets/logos/croque.png',
  'salade': 'assets/logos/salade.png',
  'fruit': 'assets/logos/fruit.png',
  'the': 'assets/logos/the.png',
  'cafe': 'assets/logos/cafe.png',
  'barre': 'assets/logos/barre.png',
  'soda': 'assets/logos/soda.png',
  'gateau_sucre': 'assets/logos/gateau_sucre.png',
  'crepe': 'assets/logos/crepe.png',
  'tarte': 'assets/logos/tarte.png',
};

/// Icône d'une clé ; une icône générique si la clé est absente ou inconnue.
IconData iconeDe(String? cle) => iconesModeles[cle] ?? Icons.restaurant;

/// Image d'un produit : sa photo (vignette) si elle existe, sinon son logo,
/// sinon son icône.
class VignetteProduit extends StatelessWidget {
  const VignetteProduit({super.key, this.icone, this.photo, this.taille = 40});

  final String? icone;
  final Uint8List? photo;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    if (p == null) return _logoOuIcone();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        p,
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        // Photo illisible : on retombe sur l'icône plutôt que de casser l'écran.
        errorBuilder: (_, _, _) => _logoOuIcone(),
      ),
    );
  }

  /// Le logo (entier, non rogné) s'il existe pour cette clé, sinon l'icône.
  Widget _logoOuIcone() {
    final logo = logosModeles[icone];
    if (logo == null) return Icon(iconeDe(icone), size: taille);
    return Image.asset(
      logo,
      width: taille,
      height: taille,
      fit: BoxFit.contain,
      cacheWidth: (taille * 3).round(),
      errorBuilder: (_, _, _) => Icon(iconeDe(icone), size: taille),
    );
  }
}

/// Écran de caisse : produits, ticket, total, paiement.
/// Sans [modes] ni [onEncaisser], c'est la caisse de démonstration.
class EcranCaisse extends StatefulWidget {
  const EcranCaisse({
    super.key,
    this.titre = 'Le Comptoir',
    this.sousTitre,
    this.produits = menuGenerique,
    this.modes = const [],
    this.onEncaisser,
    this.bandeau,
    this.onVoirVentes,
    this.onCloturer,
    this.onStock,
    this.verrouillee = false,
    this.fiches = const {},
  });

  final String titre;

  /// Fiche de chaque produit (identifiant -> fiche), pour montrer le stock en verres,
  /// litres, parts ou gâteaux. Affichage seulement.
  final Map<String, FicheProduit> fiches;

  /// Sous le titre : le gymnase de la caisse, quand il y en a un.
  final String? sousTitre;
  final List<Produit> produits;

  /// Modes de paiement proposés (clés de [modesPaiement]).
  final List<String> modes;

  /// Appelée quand on valide une vente avec un mode de paiement ;
  /// [corrigeDe] = vente annulée que ce ticket remplace, s'il y en a une.
  final void Function(Ticket ticket, String mode, String? corrigeDe)?
  onEncaisser;

  /// Ouvre la liste des ventes ; renvoie une correction à ressaisir, ou null.
  final Future<Correction?> Function()? onVoirVentes;

  /// Ouvre l'écran de clôture de la caisse.
  final VoidCallback? onCloturer;

  /// Ouvre l'écran « Stock » du bénévole (ajout de parts, produits vides).
  final VoidCallback? onStock;

  /// Caisse clôturée : on regarde, on ne vend plus.
  final bool verrouillee;

  /// Information affichée au-dessus des produits (ventes du jour, envoi…).
  final Widget? bandeau;

  @override
  State<EcranCaisse> createState() => _EtatCaisse();
}

class _EtatCaisse extends State<EcranCaisse> {
  final Ticket _ticket = Ticket();

  // Avertissement de stock : calculé d'après le contenu du ticket (décision 69),
  // affiché au-dessus du total (jamais par-dessus les boutons de paiement) ;
  // il ne bloque rien.
  String? get _alerte {
    final epuises = [
      for (final e in _ticket.lignes.entries)
        if (e.key.stock != null && e.value >= e.key.stock!) e.key.nom,
    ];
    if (epuises.isEmpty) return null;
    return 'Stock épuisé : ${epuises.join(', ')}. Vous pouvez quand même vendre.';
  }

  /// Vente annulée que le ticket en cours remplace (correction).
  String? _corrigeDe;

  void _ajouter(Produit p) {
    setState(() => _ticket.ajouter(p));
  }

  void _vider() => setState(() {
    _ticket.vider();
    _corrigeDe = null;
  });

  void _encaisser(String mode) {
    // Un second appui avant le redessin ne doit pas enregistrer une vente vide.
    if (_ticket.estVide) return;
    widget.onEncaisser?.call(_ticket, mode, _corrigeDe);
    _vider();
  }

  /// Liste des ventes ; si on en corrige une, ses articles reviennent au ticket.
  Future<void> _voirVentes() async {
    final c = await widget.onVoirVentes!();
    if (c == null || !mounted) return;
    setState(() {
      _ticket.vider();
      for (final l in c.lignes) {
        final p = widget.produits.where((x) => x.id == l.produitId).firstOrNull;
        if (p == null) continue;
        for (var i = 0; i < l.quantite; i++) {
          _ticket.ajouter(p);
        }
      }
      _corrigeDe = c.venteId;
    });
  }

  Future<void> _monnaie() => showDialog<void>(
    context: context,
    builder: (_) => _DialogueMonnaie(totalCentimes: _ticket.totalCentimes),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.sousTitre == null
            ? Text(widget.titre)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.titre),
                  Text(
                    widget.sousTitre!,
                    key: const Key('gymnase_caisse'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
        actions: [
          if (widget.onStock != null && !widget.verrouillee)
            IconButton(
              key: const Key('ouvrir_stock'),
              tooltip: 'Parts et produits vides',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: widget.onStock,
            ),
          if (widget.onCloturer != null)
            IconButton(
              key: const Key('ouvrir_cloture'),
              tooltip: 'Clôturer ma caisse',
              icon: const Icon(Icons.lock_outline),
              onPressed: widget.onCloturer,
            ),
          if (widget.onVoirVentes != null)
            IconButton(
              key: const Key('voir_ventes'),
              tooltip: 'Mes ventes',
              icon: const Icon(Icons.receipt_long),
              onPressed: _voirVentes,
            ),
        ],
      ),
      body: Column(
        children: [
          ?widget.bandeau,
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final p in widget.produits)
                  Card(
                    color: fondEtat(p.etatAffiche),
                    child: InkWell(
                      key: Key('produit_${p.id}'),
                      onTap: widget.verrouillee ? null : () => _ajouter(p),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VignetteProduit(
                            key: Key('vignette_${p.id}'),
                            icone: p.icone ?? p.id,
                            photo: p.photo,
                            taille: 40,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.nom,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            formaterEuros(p.prixCentimes),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (p.etatAffiche != EtatStock.aucun)
                            Text(
                              libelleEtat(p.etatAffiche, p.stock),
                              key: Key('stock_${p.id}'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    couleurEtat(p.etatAffiche) == null
                                        ? null
                                        : FontWeight.bold,
                                color: couleurEtat(p.etatAffiche),
                              ),
                            ),
                          if (p.stock != null && widget.fiches[p.id] != null)
                            UnitesStock(
                              key: Key('unites_${p.id}'),
                              fiche: widget.fiches[p.id]!,
                              quantite: p.stock,
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 120,
            child: ListView(
              children: [
                for (final e in _ticket.lignes.entries)
                  ListTile(
                    dense: true,
                    title: Text('${e.value} × ${e.key.nom}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formaterEuros(e.key.prixCentimes * e.value)),
                        IconButton(
                          key: Key('retirer_${e.key.id}'),
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              setState(() => _ticket.retirer(e.key)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_corrigeDe != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                "Correction d'une vente annulée",
                key: Key('correction_en_cours'),
              ),
            ),
          if (_alerte case final alerte?)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                alerte,
                key: const Key('alerte_stock'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total : ${formaterEuros(_ticket.totalCentimes)}',
                    key: const Key('total'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.modes.contains('especes'))
                  IconButton(
                    key: const Key('monnaie'),
                    tooltip: 'Monnaie à rendre',
                    icon: const Icon(Icons.calculate),
                    onPressed: _ticket.estVide ? null : _monnaie,
                  ),
                OutlinedButton(
                  key: const Key('remise_a_zero'),
                  onPressed: _ticket.estVide ? null : _vider,
                  child: const Text('Remise à zéro'),
                ),
              ],
            ),
          ),
          if (widget.modes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  for (final m in widget.modes)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilledButton(
                          key: Key('encaisser_$m'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _ticket.estVide || widget.verrouillee
                              ? null
                              : () => _encaisser(m),
                          child: Text(modesPaiement[m] ?? m),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Somme reçue -> monnaie à rendre. Simple aide au comptage, rien n'est enregistré.
class _DialogueMonnaie extends StatefulWidget {
  const _DialogueMonnaie({required this.totalCentimes});

  final int totalCentimes;

  @override
  State<_DialogueMonnaie> createState() => _EtatDialogueMonnaie();
}

class _EtatDialogueMonnaie extends State<_DialogueMonnaie> {
  final _recu = TextEditingController();

  @override
  void dispose() {
    _recu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recu = parserPrix(_recu.text);
    final rendu = recu == null
        ? null
        : monnaieARendre(widget.totalCentimes, recu);
    final String message;
    if (_recu.text.trim().isEmpty) {
      message = '';
    } else if (recu == null) {
      message = 'Somme invalide (exemple : 20).';
    } else if (rendu == null) {
      message = 'Somme insuffisante.';
    } else {
      message = 'À rendre : ${formaterEuros(rendu)}';
    }
    return AlertDialog(
      title: Text('Total : ${formaterEuros(widget.totalCentimes)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('somme_recue'),
            controller: _recu,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Somme reçue en €'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            key: const Key('a_rendre'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

/// Caisse d'un membre sur un événement : produits de l'événement, ventes
/// enregistrées sur le téléphone puis envoyées dès que le réseau est là.
class EcranCaisseEvenement extends StatefulWidget {
  const EcranCaisseEvenement({
    super.key,
    required this.uid,
    required this.prenom,
    required this.gymnase,
    required this.evenement,
    required this.depotEvenements,
    required this.depotCaisses,
  });

  final String uid;
  final String prenom;

  /// Gymnase où la caisse est ouverte : son stock est celui qui baisse.
  final Gymnase gymnase;
  final Evenement evenement;
  final DepotEvenements depotEvenements;
  final DepotCaisses depotCaisses;

  @override
  State<EcranCaisseEvenement> createState() => _EtatCaisseEvenement();
}

class _EtatCaisseEvenement extends State<EcranCaisseEvenement> {
  String? _erreurEnvoi;
  List<Produit> _produits = const [];
  List<ProduitEvenement> _produitsEvenement = const [];

  // Rupture, stock bas et « vide » du gymnase de cette caisse.
  late final Stream<Map<String, Map<String, EtatStock>>> _etats = widget
      .depotEvenements
      .suivreEtats(widget.evenement.id, gymnases: {widget.gymnase.id});

  void _surErreur(Object _) {
    if (mounted) {
      setState(
        () => _erreurEnvoi =
            "Une écriture n'a pas pu être envoyée. Prévenez un gestionnaire.",
      );
    }
  }

  Map<String, int?> get _stocks => {for (final p in _produits) p.id: p.stock};

  String get _caisseId => idCaisse(widget.uid, widget.gymnase.id);

  void _encaisser(Ticket ticket, String mode, String? corrigeDe) {
    widget.depotCaisses.enregistrerVente(
      _caisseId,
      lignesDuTicket(ticket),
      mode,
      stocks: _stocks,
      corrigeDe: corrigeDe,
      onErreur: _surErreur,
    );
  }

  Future<Correction?> _voirVentes(bool cloturee) =>
      Navigator.of(context).push<Correction>(
        MaterialPageRoute(
          builder: (_) => EcranVentes(
            uid: widget.uid,
            prenom: widget.prenom,
            caisseId: _caisseId,
            depotCaisses: widget.depotCaisses,
            stocks: () => _stocks,
            onErreur: _surErreur,
            verrouillee: cloturee,
          ),
        ),
      );

  void _ouvrirStock() => showDialog<void>(
    context: context,
    builder: (_) => _DialogueStockBenevole(
      depot: widget.depotEvenements,
      evenementId: widget.evenement.id,
      gymnaseId: widget.gymnase.id,
      gymnaseNom: widget.gymnase.nom,
      uid: widget.uid,
      prenom: widget.prenom,
      produits: _produitsEvenement,
      onErreur: _surErreur,
    ),
  );

  void _cloturer() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EcranCloture(
        caisseId: _caisseId,
        modes: widget.evenement.modes,
        depotCaisses: widget.depotCaisses,
      ),
    ),
  );

  Widget _bandeau(List<Vente> ventes, Caisse? caisse) {
    // Les ventes annulées restent listées mais ne comptent plus.
    final valides = ventes.where((v) => !v.annulee);
    final total = valides.fold<int>(0, (s, v) => s + v.totalCentimes);
    final annulees = ventes.length - valides.length;
    final attente = ventes.where((v) => v.enAttente).length;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mes ventes : ${valides.length} · ${formaterEuros(total)}',
                key: const Key('recap_caisse'),
              ),
              if (annulees > 0)
                Text(
                  'Ventes annulées : $annulees',
                  key: const Key('annulees_caisse'),
                ),
              Text(
                attente == 0
                    ? 'Tout est envoyé'
                    : "En attente d'envoi : $attente",
                key: const Key('envoi_caisse'),
              ),
              if (caisse != null && caisse.cloturee) ...[
                const Text('Caisse clôturée', key: Key('caisse_cloturee')),
                TextButton(
                  key: const Key('rouvrir_caisse'),
                  onPressed: () => widget.depotCaisses.rouvrirCaisse(
                    _caisseId,
                    onErreur: _surErreur,
                  ),
                  child: const Text('Rouvrir ma caisse'),
                ),
              ],
              if (_erreurEnvoi != null)
                Text(
                  _erreurEnvoi!,
                  key: const Key('erreur_envoi'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProduitEvenement>>(
      stream: widget.depotEvenements.suivreProduits(
        widget.evenement.id,
        gymnaseId: widget.gymnase.id,
      ),
      builder: (context, p) {
        _produitsEvenement = p.data ?? const <ProduitEvenement>[];
        return StreamBuilder<Map<String, Map<String, EtatStock>>>(
          stream: _etats,
          builder: (context, e) => _avecEtats(
            context,
            e.data?[widget.gymnase.id] ?? const <String, EtatStock>{},
          ),
        );
      },
    );
  }

  Widget _avecEtats(BuildContext context, Map<String, EtatStock> etats) {
    _produits = [
      for (final x in _produitsEvenement)
        Produit(x.id, x.nom, x.prixCentimes, x.stock, x.icone, x.photo,
            etats[x.id]),
    ];
    return StreamBuilder<Caisse?>(
      stream: widget.depotCaisses.suivreCaisse(_caisseId),
      builder: (context, c) => StreamBuilder<List<Vente>>(
        stream: widget.depotCaisses.suivreVentes(_caisseId),
        builder: (context, v) {
          final cloturee = c.data?.cloturee ?? false;
          return EcranCaisse(
            titre: 'Caisse de ${widget.prenom}',
            sousTitre: widget.gymnase.nom,
            produits: _produits,
            modes: widget.evenement.modes,
            onEncaisser: _encaisser,
            onVoirVentes: () => _voirVentes(cloturee),
            onCloturer: cloturee ? null : _cloturer,
            onStock: _ouvrirStock,
            verrouillee: cloturee,
            fiches: {for (final x in _produitsEvenement) x.id: x.fiche},
            bandeau: _bandeau(v.data ?? const <Vente>[], c.data),
          );
        },
      ),
    );
  }
}

/// Ce qu'un bénévole peut faire du stock de son gymnase : ajouter du stock
/// (produits « part » ou apportés par les bénévoles, suivis) et signaler un produit sans quantité
/// comme vide. Rien d'autre.
class _DialogueStockBenevole extends StatelessWidget {
  const _DialogueStockBenevole({
    required this.depot,
    required this.evenementId,
    required this.gymnaseId,
    required this.gymnaseNom,
    required this.uid,
    required this.prenom,
    required this.produits,
    required this.onErreur,
  });

  final DepotEvenements depot;
  final String evenementId;
  final String gymnaseId;
  final String gymnaseNom;
  final String uid;
  final String prenom;
  final List<ProduitEvenement> produits;
  final void Function(Object) onErreur;

  Future<void> _ajouter(BuildContext context, ProduitEvenement p) async {
    final n = await showDialog<int>(
      context: context,
      builder: (_) => _DialogueParts(
          titre: p.fiche.type == 'part'
              ? 'Ajouter des parts : ${p.nom}'
              : 'Ajouter au stock : ${p.nom}'),
    );
    if (n == null) return;
    // Sans réseau, l'écriture attend l'envoi : on n'attend pas sa fin.
    unawaited(depot
        .ajouterParts(evenementId, gymnaseId, p.id, n)
        .catchError(onErreur));
  }

  /// « Ajouter un apport » : un nom (« Quiche ») et un nombre de parts, notés avec le
  /// prénom et le gymnase ; le stock du produit monte du même nombre.
  Future<void> _apporter(BuildContext context, ProduitEvenement p) async {
    final r = await showDialog<({String nom, int parts})>(
      context: context,
      builder: (_) => _DialogueApport(produit: p.nom),
    );
    if (r == null) return;
    unawaited(depot
        .ajouterApport(evenementId,
            gymnaseId: gymnaseId,
            gymnaseNom: gymnaseNom,
            produitId: p.id,
            produitNom: p.nom,
            nom: r.nom,
            parts: r.parts,
            prenom: prenom,
            uid: uid)
        .catchError(onErreur));
  }

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final p in produits)
        if ((p.fiche.type == 'part' || p.fiche.provenance == 'apporte') &&
            p.stock != null)
          p,
    ];
    final sansQuantite = [
      for (final p in produits)
        if (p.stock == null) p,
    ];
    return AlertDialog(
      title: const Text('Stock de mon gymnase'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<Set<String>>(
          stream: depot.suivreVides(evenementId, gymnaseId),
          builder: (context, sv) {
            final vides = sv.data ?? const <String>{};
            return ListView(
              shrinkWrap: true,
              children: [
                if (parts.isEmpty && sansQuantite.isEmpty)
                  const Text(
                    'Rien à régler ici : les quantités sont réglées par la gestion.',
                    key: Key('stock_benevole_vide'),
                  ),
                if (parts.isNotEmpty)
                  Text('Ajouter au stock (parts, pièces)',
                      style: Theme.of(context).textTheme.titleSmall),
                for (final p in parts)
                  ListTile(
                    dense: true,
                    title: Text(p.nom),
                    subtitle: Text('Stock : ${p.stock}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('ajout_apport_${p.id}'),
                          icon: const Icon(Icons.volunteer_activism_outlined),
                          tooltip: 'Ajouter un apport',
                          onPressed: () => _apporter(context, p),
                        ),
                        IconButton(
                          key: Key('ajout_parts_${p.id}'),
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Ajouter au stock',
                          onPressed: () => _ajouter(context, p),
                        ),
                      ],
                    ),
                  ),
                if (sansQuantite.isNotEmpty)
                  Text('Produits sans quantité',
                      style: Theme.of(context).textTheme.titleSmall),
                for (final p in sansQuantite)
                  SwitchListTile(
                    key: Key('vide_${p.id}'),
                    dense: true,
                    title: Text(p.nom),
                    subtitle: const Text('Vide'),
                    value: vides.contains(p.id),
                    onChanged: (v) => unawaited(depot
                        .signalerVide(evenementId, gymnaseId, p.id, v)
                        .catchError(onErreur)),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          key: const Key('fermer_stock'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

/// Un apport nommé : le nom de ce qui est apporté et son nombre de parts (1 à 1000).
class _DialogueApport extends StatefulWidget {
  const _DialogueApport({required this.produit});

  final String produit;

  @override
  State<_DialogueApport> createState() => _EtatDialogueApport();
}

class _EtatDialogueApport extends State<_DialogueApport> {
  final _nom = TextEditingController();
  final _parts = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _parts.dispose();
    super.dispose();
  }

  void _valider() {
    final parts = int.tryParse(_parts.text.trim());
    final erreur = erreurApport(_nom.text, parts);
    if (erreur != null) {
      setState(() => _erreur = erreur);
    } else {
      Navigator.pop(context, (nom: _nom.text.trim(), parts: parts!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajouter un apport : ${widget.produit}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('saisie_apport_nom'),
            controller: _nom,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom (par exemple Quiche)'),
          ),
          TextField(
            key: const Key('saisie_apport_parts'),
            controller: _parts,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nombre de parts'),
            onSubmitted: (_) => _valider(),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_erreur!,
                  key: const Key('erreur_apport'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_apport'),
            onPressed: _valider,
            child: const Text('Ajouter')),
      ],
    );
  }
}

/// Nombre de parts à ajouter : de 1 à 1000.
class _DialogueParts extends StatefulWidget {
  const _DialogueParts({required this.titre});

  final String titre;

  @override
  State<_DialogueParts> createState() => _EtatDialogueParts();
}

class _EtatDialogueParts extends State<_DialogueParts> {
  final _texte = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  void _valider() {
    final n = int.tryParse(_texte.text.trim());
    if (n == null || n < 1 || n > 1000) {
      setState(() => _erreur = 'Entrez un nombre entier de 1 à 1000.');
    } else {
      Navigator.pop(context, n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: TextField(
        key: const Key('saisie_parts'),
        controller: _texte,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration:
            InputDecoration(labelText: 'Quantité ajoutée', errorText: _erreur),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_parts'),
            onPressed: _valider,
            child: const Text('Ajouter')),
      ],
    );
  }
}

/// Liste des ventes de la caisse : annuler ou corriger, avec trace.
class EcranVentes extends StatelessWidget {
  const EcranVentes({
    super.key,
    required this.uid,
    required this.prenom,
    required this.caisseId,
    required this.depotCaisses,
    required this.stocks,
    required this.onErreur,
    this.verrouillee = false,
    this.titre = 'Mes ventes',
    this.peutCorriger = true,
  });

  /// Qui agit (et signe les annulations) : [uid] et [prenom].
  final String uid;
  final String prenom;
  final DepotCaisses depotCaisses;
  final Map<String, int?> Function() stocks;
  final void Function(Object) onErreur;

  /// Caisse affichée : la mienne, ou une autre pour la gestion.
  final String caisseId;
  final String titre;

  /// Corriger = ressaisir dans MON ticket : réservé à l'auteur de la caisse.
  final bool peutCorriger;

  /// Caisse clôturée : la liste se consulte, plus d'annulation ni de correction.
  final bool verrouillee;

  Future<bool> _confirmer(
    BuildContext context,
    String titre,
    String texte,
    String bouton,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titre),
        content: Text(texte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const Key('confirmer_annulation'),
            style: (bouton == 'Corriger' ? TypeAction.attention : TypeAction.danger)
                .plein,
            onPressed: () => Navigator.pop(c, true),
            child: Text(bouton),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _annuler(Vente v) => depotCaisses.annulerVente(
    caisseId,
    v,
    parUid: uid,
    parPrenom: prenom,
    stocks: stocks(),
    onErreur: onErreur,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: StreamBuilder<List<Vente>>(
        stream: depotCaisses.suivreVentes(caisseId),
        builder: (context, s) {
          final ventes = s.data;
          if (ventes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ventes.isEmpty) {
            return const Center(
              child: Text('Aucune vente.', key: Key('aucune_vente')),
            );
          }
          final remplacees = {
            for (final v in ventes)
              if (v.corrigeDe != null) v.corrigeDe!,
          };
          return ListView(
            children: [
              for (final v in ventes)
                Card(
                  key: Key('vente_${v.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${heureAffichee(v.creeLe)} · ${formaterEuros(v.totalCentimes)} · ${modesPaiement[v.mode] ?? v.mode}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: v.annulee
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        Text(
                          [for (final l in v.lignes) '${l.quantite} × ${l.nom}']
                              .join(', '),
                          style: TextStyle(
                            decoration: v.annulee
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (v.corrigeDe != null)
                          const Text('Remplace une vente annulée'),
                        if (v.enAttente) const Text("En attente d'envoi"),
                        if (v.annulee)
                          Text(
                            'Annulée par ${v.annuleeParPrenom ?? '?'}'
                            ' à ${v.annuleeLe == null ? '?' : heureAffichee(v.annuleeLe!)}'
                            '${remplacees.contains(v.id) ? ' · remplacée' : ''}',
                            key: Key('trace_${v.id}'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        else if (!verrouillee)
                          Row(
                            children: [
                              TextButton(
                                key: Key('annuler_${v.id}'),
                                style: TypeAction.danger.texte,
                                onPressed: () async {
                                  if (await _confirmer(
                                    context,
                                    'Annuler cette vente ?',
                                    'Elle restera dans la liste, marquée annulée. Les articles reviennent en stock.',
                                    'Annuler la vente',
                                  )) {
                                    _annuler(v);
                                  }
                                },
                                child: const Text('Annuler'),
                              ),
                              if (peutCorriger)
                                TextButton(
                                  key: Key('corriger_${v.id}'),
                                  style: TypeAction.attention.texte,
                                  onPressed: () async {
                                    if (await _confirmer(
                                      context,
                                      'Corriger cette vente ?',
                                      "L'ancienne vente est annulée et ses articles reviennent dans le ticket pour être ressaisis.",
                                      'Corriger',
                                    )) {
                                      _annuler(v);
                                      if (context.mounted) {
                                        Navigator.pop(
                                          context,
                                          Correction(v.id, v.lignes),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Corriger'),
                                ),
                            ],
                          ),
                      ],
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

/// Clôture de la caisse : récapitulatif à compter, puis envoi final.
class EcranCloture extends StatefulWidget {
  const EcranCloture({
    super.key,
    required this.caisseId,
    required this.modes,
    required this.depotCaisses,
  });

  final String caisseId;
  final List<String> modes;
  final DepotCaisses depotCaisses;

  @override
  State<EcranCloture> createState() => _EtatCloture();
}

class _EtatCloture extends State<EcranCloture> {
  bool _envoi = false;
  bool _annule = false;
  String? _erreur;

  /// Récapitulatif confirmé par le serveur (la caisse est alors clôturée).
  RecapCaisse? _final;

  Future<void> _cloturer() async {
    setState(() {
      _envoi = true;
      _annule = false;
      _erreur = null;
    });
    try {
      final r = await widget.depotCaisses.cloturerCaisse(
        widget.caisseId,
        annule: () => _annule,
      );
      if (mounted) {
        setState(() {
          _envoi = false;
          _final = r;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = 'Clôture impossible. Vérifiez le réseau et réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clôture de ma caisse')),
      body: StreamBuilder<List<Vente>>(
        stream: widget.depotCaisses.suivreVentes(widget.caisseId),
        builder: (context, s) {
          final ventes = s.data ?? const <Vente>[];
          final recap = _final ?? RecapCaisse.depuis(ventes);
          final attente = ventes.where((v) => v.enAttente).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_final != null)
                Text(
                  'Caisse clôturée',
                  key: const Key('cloture_ok'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              Text(
                'Ventes : ${recap.nbVentes} · ${formaterEuros(recap.totalCentimes)}',
                key: const Key('cloture_total'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Ventes annulées : ${recap.nbAnnulees}',
                key: const Key('cloture_annulees'),
              ),
              const SizedBox(height: 12),
              for (final m in widget.modes)
                Text(
                  '${modesPaiement[m] ?? m} : ${formaterEuros(recap.pour(m))}',
                  key: Key('recap_mode_$m'),
                ),
              if (widget.modes.contains('especes')) ...[
                const SizedBox(height: 12),
                Text(
                  'Espèces à remettre : ${formaterEuros(recap.pour('especes'))}',
                  key: const Key('a_remettre'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
              const SizedBox(height: 16),
              if (_final == null && attente > 0)
                Text(
                  "${pluriel(attente, 'vente')} en attente d'envoi : la clôture attend le réseau.",
                  key: const Key('cloture_attente'),
                ),
              if (_erreur != null)
                Text(
                  _erreur!,
                  key: const Key('cloture_erreur'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              if (_final != null)
                FilledButton(
                  key: const Key('fermer_cloture'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                )
              else if (_envoi) ...[
                const Text(
                  'Envoi des ventes au serveur…',
                  key: Key('cloture_envoi'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('annuler_attente'),
                  onPressed: () {
                    _annule = true;
                    setState(() => _envoi = false);
                  },
                  child: const Text("Annuler l'attente"),
                ),
              ] else
                FilledButton(
                  key: const Key('cloturer_caisse'),
                  style: TypeAction.reussir.plein,
                  onPressed: _cloturer,
                  child: const Text('Clôturer ma caisse'),
                ),
            ],
          );
        },
      ),
    );
  }
}
