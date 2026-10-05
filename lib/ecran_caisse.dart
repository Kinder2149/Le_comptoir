import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';
import 'ticket.dart';

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
};

/// Icône d'une clé ; une icône générique si la clé est absente ou inconnue.
IconData iconeDe(String? cle) => iconesModeles[cle] ?? Icons.restaurant;

/// Image d'un produit : sa photo (vignette) si elle existe, sinon son icône.
class VignetteProduit extends StatelessWidget {
  const VignetteProduit({super.key, this.icone, this.photo, this.taille = 40});

  final String? icone;
  final Uint8List? photo;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    if (p == null) return Icon(iconeDe(icone), size: taille);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        p,
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        // Photo illisible : on retombe sur l'icône plutôt que de casser l'écran.
        errorBuilder: (_, _, _) => Icon(iconeDe(icone), size: taille),
      ),
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
    this.verrouillee = false,
  });

  final String titre;

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

  /// Caisse clôturée : on regarde, on ne vend plus.
  final bool verrouillee;

  /// Information affichée au-dessus des produits (ventes du jour, envoi…).
  final Widget? bandeau;

  @override
  State<EcranCaisse> createState() => _EtatCaisse();
}

class _EtatCaisse extends State<EcranCaisse> {
  final Ticket _ticket = Ticket();

  // Avertissement de stock : affiché au-dessus du total (jamais par-dessus les
  // boutons de paiement) ; il ne bloque rien.
  String? _alerte;

  /// Vente annulée que le ticket en cours remplace (correction).
  String? _corrigeDe;

  void _ajouter(Produit p) {
    final dejaAuTicket = _ticket.lignes[p] ?? 0;
    setState(() {
      if (p.stock != null && p.stock! - dejaAuTicket <= 0) {
        _alerte = 'Stock épuisé : ${p.nom}. Vous pouvez quand même vendre.';
      }
      _ticket.ajouter(p);
    });
  }

  void _vider() => setState(() {
    _ticket.vider();
    _alerte = null;
    _corrigeDe = null;
  });

  void _encaisser(String mode) {
    widget.onEncaisser?.call(_ticket, mode, _corrigeDe);
    _vider();
  }

  /// Liste des ventes ; si on en corrige une, ses articles reviennent au ticket.
  Future<void> _voirVentes() async {
    final c = await widget.onVoirVentes!();
    if (c == null || !mounted) return;
    setState(() {
      _ticket.vider();
      _alerte = null;
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
                          if (p.stock != null)
                            Text(
                              p.stock! <= 0 ? 'Épuisé' : 'Stock : ${p.stock}',
                              key: Key('stock_${p.id}'),
                              style: TextStyle(
                                fontSize: 11,
                                color: p.stock! <= 0
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
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
          if (_alerte != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                _alerte!,
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
        _produits = [
          for (final x in p.data ?? const <ProduitEvenement>[])
            Produit(x.id, x.nom, x.prixCentimes, x.stock, x.icone, x.photo),
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
                verrouillee: cloturee,
                bandeau: _bandeau(v.data ?? const <Vente>[], c.data),
              );
            },
          ),
        );
      },
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
