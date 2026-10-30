import 'package:flutter/material.dart';

import 'depot_associations.dart';
import 'depot_caisses.dart';
import 'depot_evenements.dart';
import 'ecran_caisse.dart' show VignetteProduit, couleurEtat, fondEtat;
import 'ecran_courses.dart';
import 'ecran_qr.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';
import 'ticket.dart';

/// Gymnases d'un événement et stock de chacun (gestion). Les gymnases peuvent
/// être ajoutés et renommés, jamais supprimés.
class EcranGymnases extends StatelessWidget {
  const EcranGymnases({
    super.key,
    required this.depot,
    required this.evenementId,
    required this.portee,
    required this.membres,
    required this.codeAssociation,
    this.evenementNom,
  });

  final DepotEvenements depot;
  final String evenementId;

  /// Nom de l'événement, rappelé en tête : ce stock est celui de CET événement
  /// (le menu n'a pas de stock, décision 45).
  final String? evenementNom;

  /// Le code d'accès actuel de l'association (pour les QR codes à partager).
  final Stream<String> codeAssociation;

  /// Ce que le membre peut gérer : tout (responsable) ou ses gymnases.
  final PorteeGestion portee;
  final Stream<List<Membre>> membres;

  void _montrerErreur(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Enregistrement impossible. Vérifiez le réseau.',
          key: Key('erreur_gymnases')),
    ));
  }

  /// Demande un nom puis lance [action] ; une panne réseau est signalée.
  Future<void> _nommer(
    BuildContext context, {
    required String titre,
    required String bouton,
    required String initial,
    required List<String> autres,
    required Future<void> Function(String nom) action,
  }) async {
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => _DialogueNom(
          titre: titre, bouton: bouton, initial: initial, autres: autres),
    );
    if (nom == null) return;
    try {
      await action(nom);
    } catch (_) {
      if (context.mounted) _montrerErreur(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gymnase>>(
      stream: depot.suivreGymnases(evenementId),
      builder: (context, s) {
        final tous = s.data;
        // Un gestionnaire ne voit dans cet écran que ses gymnases.
        final gymnases = tous?.where((g) => portee.gere(g.id)).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Gymnases et stocks')),
          body: gymnases == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        evenementNom == null
                            ? 'Stock de l\'événement'
                            : 'Stock de l\'événement « $evenementNom »',
                        key: const Key('titre_stock_evenement'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    // Les courses se préparent d'ici : le stock et le vendu sont sous les yeux.
                    if (portee.toutVoir)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FilledButton.icon(
                          key: const Key('preparer_courses'),
                          style: TypeAction.gerer.plein,
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Préparer les courses'),
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => EcranCourses(
                                  depot: depot, evenementId: evenementId),
                            ),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Les courses sont réservées au responsable ou au '
                          'gestionnaire rattaché à tous les gymnases.',
                          key: Key('courses_reservees'),
                        ),
                      ),
                    for (final g in gymnases)
                      _CarteGymnase(
                        key: Key('gymnase_${g.id}'),
                        depot: depot,
                        evenementId: evenementId,
                        gymnase: g,
                        codeAssociation: codeAssociation,
                        onRenommer: () => _nommer(
                          context,
                          titre: 'Renommer le gymnase',
                          bouton: 'Enregistrer',
                          initial: g.nom,
                          autres: [
                            for (final x in tous!)
                              if (x.id != g.id) x.nom
                          ],
                          action: (nom) =>
                              depot.renommerGymnase(evenementId, g.id, nom),
                        ),
                        onErreur: () => _montrerErreur(context),
                      ),
                    if (portee.responsable) ...[
                      const SizedBox(height: 8),
                      if (tous!.length >= maxGymnases)
                        const Text("Huit gymnases : c'est le maximum.",
                            key: Key('max_gymnases'))
                      else
                        OutlinedButton.icon(
                          key: const Key('ajouter_gymnase'),
                          style: TypeAction.gerer.contour,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un gymnase'),
                          onPressed: () => _nommer(
                            context,
                            titre: 'Nouveau gymnase',
                            bouton: 'Ajouter',
                            initial: '',
                            autres: [for (final x in tous) x.nom],
                            action: (nom) =>
                                depot.ajouterGymnase(evenementId, nom),
                          ),
                        ),
                      const Divider(height: 32),
                      _Rattachements(
                        depot: depot,
                        evenementId: evenementId,
                        gymnases: tous,
                        membres: membres,
                        onErreur: () => _montrerErreur(context),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

/// Rattachement des gestionnaires aux gymnases (responsable seul) : un gestionnaire
/// ne voit et ne corrige que les ventes et le stock de ses gymnases.
class _Rattachements extends StatelessWidget {
  const _Rattachements({
    required this.depot,
    required this.evenementId,
    required this.gymnases,
    required this.membres,
    required this.onErreur,
  });

  final DepotEvenements depot;
  final String evenementId;
  final List<Gymnase> gymnases;
  final Stream<List<Membre>> membres;
  final VoidCallback onErreur;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Membre>>(
      stream: membres,
      builder: (context, m) => StreamBuilder<Map<String, Set<String>>>(
        stream: depot.suivreRattachements(evenementId),
        builder: (context, r) {
          final membresListe = m.data;
          final rattachements = r.data;
          if (membresListe == null || rattachements == null) {
            return const LinearProgressIndicator();
          }
          final gestionnaires = [
            for (final x in membresListe)
              if (x.role == 'gestionnaire' && !x.enAttente) x,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestionnaires par gymnase',
                  style: Theme.of(context).textTheme.titleMedium),
              const Text(
                  "Un gestionnaire ne voit et ne corrige que les ventes et le stock de ses gymnases."),
              if (gestionnaires.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Aucun gestionnaire actif pour le moment.',
                      key: Key('aucun_gestionnaire')),
                ),
              for (final x in gestionnaires)
                Card(
                  key: Key('rattachement_${x.uid}'),
                  margin: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(x.prenom,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final g in gymnases)
                        CheckboxListTile(
                          key: Key('rattacher_${x.uid}_${g.id}'),
                          dense: true,
                          title: Text(g.nom),
                          value: (rattachements[x.uid] ?? const <String>{})
                              .contains(g.id),
                          onChanged: (v) async {
                            final actuel = {...?rattachements[x.uid]};
                            if (v == true) {
                              actuel.add(g.id);
                            } else {
                              actuel.remove(g.id);
                            }
                            try {
                              await depot.definirRattachement(
                                  evenementId, x.uid, actuel);
                            } catch (_) {
                              onErreur();
                            }
                          },
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CarteGymnase extends StatelessWidget {
  const _CarteGymnase({
    super.key,
    required this.depot,
    required this.evenementId,
    required this.gymnase,
    required this.codeAssociation,
    required this.onRenommer,
    required this.onErreur,
  });

  final DepotEvenements depot;
  final String evenementId;
  final Gymnase gymnase;
  final Stream<String> codeAssociation;
  final VoidCallback onRenommer;
  final VoidCallback onErreur;

  Future<void> _essayer(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      onErreur();
    }
  }

  Future<int?> _demanderNombre(BuildContext context, String titre,
      {int? initial}) {
    return showDialog<int>(
      context: context,
      builder: (_) => _DialogueNombre(titre: titre, initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = gymnase.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(gymnase.nom,
                  key: Key('nom_gymnase_$g'),
                  style: Theme.of(context).textTheme.titleMedium),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('partager_gymnase_$g'),
                    icon: const Icon(Icons.qr_code_2),
                    tooltip: 'Partager (QR code)',
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => EcranQr(
                          codeAssociation: codeAssociation,
                          evenementId: evenementId,
                          gymnase: gymnase,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('renommer_gymnase_$g'),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Renommer',
                    onPressed: onRenommer,
                  ),
                ],
              ),
            ),
            StreamBuilder<TableauDeBord>(
              stream: depot.caisses(evenementId).suivreTableauDeBord(gymnaseIds: {g}),
              builder: (context, sTab) => StreamBuilder<Map<String, Map<String, EtatStock>>>(
              stream: depot.suivreEtats(evenementId, gymnases: {g}),
              builder: (context, sv) => StreamBuilder<List<ProduitEvenement>>(
              stream: depot.suivreProduits(evenementId, gymnaseId: g),
              builder: (context, s) {
                final produits = s.data;
                final etats = sv.data?[g] ?? const <String, EtatStock>{};
                final tableau = sTab.data;
                if (produits == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }
                final aucunSuivi = produits.every((p) => p.stock == null);
                final tousSuivis = produits.every((p) => p.stock != null);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (aucunSuivi)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            "Aucun stock n'est suivi dans ce gymnase. "
                            'Suivez les produits à compter, puis réglez leur quantité.',
                            key: Key('aucun_suivi_$g'),
                          ),
                        ),
                      if (!tousSuivis)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            key: Key('suivre_tous_$g'),
                            style: TypeAction.gerer.contour,
                            onPressed: () => _essayer(() async {
                              for (final p in produits) {
                                if (p.stock == null) {
                                  await depot.definirStock(evenementId, g, p.id, 0);
                                }
                              }
                            }),
                            child: const Text('Suivre tous les produits'),
                          ),
                        ),
                      for (final p in produits)
                        _LigneStock(
                          key: Key('ligne_${g}_${p.id}'),
                          produit: p,
                          gymnaseId: g,
                          etat: etats[p.id] ?? etatStock(quantite: p.stock),
                          vendu: tableau?.vendus(p.id),
                          onAjouter: () async {
                            final n = await _demanderNombre(
                                context, 'Ajouter au stock de ${p.nom}');
                            if (n != null) {
                              await _essayer(() => depot.reapprovisionner(
                                  evenementId, g, p.id, n));
                            }
                          },
                          onCorriger: () async {
                            final n = await _demanderNombre(
                                context, 'Stock de ${p.nom}',
                                initial: p.stock);
                            if (n != null) {
                              await _essayer(() =>
                                  depot.definirStock(evenementId, g, p.id, n));
                            }
                          },
                          onSuivre: (v) => _essayer(() => v
                              ? depot.definirStock(evenementId, g, p.id, 0)
                              : depot.arreterSuivi(evenementId, g, p.id)),
                          onVide: (v) => _essayer(
                              () => depot.signalerVide(evenementId, g, p.id, v)),
                        ),
                    ],
                  ),
                );
              },
            ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un produit dans le stock d'un gymnase : image, état coloré (comme en caisse),
/// quantité, vendu, et des actions nommées (zones d'appui de 48 px).
class _LigneStock extends StatelessWidget {
  const _LigneStock({
    super.key,
    required this.produit,
    required this.gymnaseId,
    required this.etat,
    required this.vendu,
    required this.onAjouter,
    required this.onCorriger,
    required this.onSuivre,
    required this.onVide,
  });

  final ProduitEvenement produit;
  final String gymnaseId;
  final EtatStock etat;

  /// Quantité vendue (ventes non annulées) ; null tant que le suivi se charge.
  final int? vendu;
  final VoidCallback onAjouter;
  final VoidCallback onCorriger;
  final ValueChanged<bool> onSuivre;
  final ValueChanged<bool> onVide;

  static String? _libelleAlerte(EtatStock e) => switch (e) {
        EtatStock.bas => 'Stock bas',
        EtatStock.epuise => 'Épuisé',
        EtatStock.vide => 'Vide',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final g = gymnaseId;
    final suivi = p.stock != null;
    final alerte = _libelleAlerte(etat);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: fondEtat(etat) ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.filet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VignetteProduit(icone: p.icone, photo: p.photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nom, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      suivi ? 'Stock : ${p.stock}' : 'Stock non suivi',
                      key: Key('stock_${g}_${p.id}'),
                      style: TextStyle(color: couleurEtat(etat)),
                    ),
                    if (suivi)
                      Text(
                        vendu == null ? 'Vendu : …' : 'Vendu : $vendu',
                        key: Key('vendu_${g}_${p.id}'),
                      ),
                  ],
                ),
              ),
              if (alerte != null)
                Text(alerte,
                    key: Key('etat_${g}_${p.id}'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: couleurEtat(etat))),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (suivi) ...[
                TextButton.icon(
                  key: Key('reappro_${g}_${p.id}'),
                  style: TypeAction.gerer.texte,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Ajouter'),
                  onPressed: onAjouter,
                ),
                TextButton.icon(
                  key: Key('modifier_stock_${g}_${p.id}'),
                  style: TypeAction.gerer.texte,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Corriger'),
                  onPressed: onCorriger,
                ),
              ],
              if (!suivi) ...[
                const Text('Vide'),
                Switch(
                  key: Key('vide_${g}_${p.id}'),
                  value: etat == EtatStock.vide,
                  onChanged: onVide,
                ),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Suivre le stock'),
                  Switch(
                    key: Key('suivi_${g}_${p.id}'),
                    value: suivi,
                    onChanged: onSuivre,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saisie du nom d'un gymnase, avec les mêmes contrôles qu'à la création.
class _DialogueNom extends StatefulWidget {
  const _DialogueNom({
    required this.titre,
    required this.bouton,
    required this.initial,
    required this.autres,
  });

  final String titre;
  final String bouton;
  final String initial;
  final List<String> autres;

  @override
  State<_DialogueNom> createState() => _EtatDialogueNom();
}

class _EtatDialogueNom extends State<_DialogueNom> {
  late final _nom = TextEditingController(text: widget.initial);
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  void _valider() {
    final erreur = erreurNomsGymnases([...widget.autres, _nom.text]);
    if (erreur != null) {
      setState(() => _erreur = erreur);
    } else {
      Navigator.pop(context, _nom.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: TextField(
        key: const Key('saisie_nom_gymnase'),
        controller: _nom,
        autofocus: true,
        decoration:
            InputDecoration(labelText: 'Nom du gymnase', errorText: _erreur),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_nom_gymnase'),
            onPressed: _valider,
            child: Text(widget.bouton)),
      ],
    );
  }
}

/// Saisie d'une quantité entière de 0 à 100 000.
class _DialogueNombre extends StatefulWidget {
  const _DialogueNombre({required this.titre, this.initial});

  final String titre;
  final int? initial;

  @override
  State<_DialogueNombre> createState() => _EtatDialogueNombre();
}

class _EtatDialogueNombre extends State<_DialogueNombre> {
  late final _texte =
      TextEditingController(text: widget.initial?.toString() ?? '');
  String? _erreur;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  void _valider() {
    final n = int.tryParse(_texte.text.trim());
    if (n == null || n < 0 || n > 100000) {
      setState(() => _erreur = 'Entrez un nombre entier de 0 à 100 000.');
    } else {
      Navigator.pop(context, n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: TextField(
        key: const Key('saisie_quantite'),
        controller: _texte,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Quantité', errorText: _erreur),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour')),
        FilledButton(
            key: const Key('valider_quantite'),
            onPressed: _valider,
            child: const Text('Valider')),
      ],
    );
  }
}
