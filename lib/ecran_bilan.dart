import 'package:flutter/material.dart';

import 'depot_caisses.dart';
import 'evenement.dart';
import 'gymnase.dart';
import 'theme.dart';
import 'ticket.dart';

/// Sélecteur « Commun | Gymnase A | Gymnase B… » : la vue commune additionne tous
/// les gymnases, une vue distincte montre un seul gymnase. [vue] null = commune.
class SelecteurVue extends StatelessWidget {
  const SelecteurVue({
    super.key,
    required this.gymnases,
    required this.commun,
    required this.vue,
    required this.onChanged,
  });

  final List<Gymnase> gymnases;

  /// La vue commune est-elle offerte à ce membre ?
  final bool commun;
  final String? vue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: TypeAction.analyser.fort,
          selectedForegroundColor: Colors.white,
          foregroundColor: TypeAction.analyser.fonce,
          side: BorderSide(color: TypeAction.analyser.fort, width: 1.5),
        ),
        showSelectedIcon: false,
        segments: [
          if (commun)
            const ButtonSegment(
                value: vueCommune, label: Text('Commun', key: Key('vue_commune'))),
          for (final g in gymnases)
            ButtonSegment(value: g.id, label: Text(g.nom, key: Key('vue_${g.id}'))),
        ],
        selected: {vue ?? vueCommune},
        onSelectionChanged: (s) =>
            onChanged(s.first == vueCommune ? null : s.first),
      ),
    );
  }
}

/// Bilan de l'événement (gestion) : provisoire tant qu'il est en cours,
/// définitif une fois clôturé. Calculé sur les ventes non annulées. Avec
/// plusieurs gymnases : vue commune (tous additionnés) ou vue d'un gymnase.
class EcranBilan extends StatefulWidget {
  const EcranBilan({
    super.key,
    required this.evenement,
    required this.tableau,
    required this.produits,
    this.gymnases,
    this.stocks,
    this.commun = true,
    this.limite = false,
  });

  final Evenement evenement;
  final Stream<TableauDeBord> tableau;
  final Stream<List<ProduitEvenement>> produits;

  /// Gymnases visibles par ce membre et leur stock : sans eux, un seul bilan.
  final Stream<List<Gymnase>>? gymnases;
  final Stream<Map<String, Map<String, int>>>? stocks;

  /// La vue commune est-elle offerte (responsable, ou gestionnaire de tous) ?
  final bool commun;

  /// Vue limitée aux gymnases du gestionnaire (pas celle de tout l'événement).
  final bool limite;

  @override
  State<EcranBilan> createState() => _EtatBilan();
}

class _EtatBilan extends State<EcranBilan> {
  Evenement get evenement => widget.evenement;
  bool get limite => widget.limite;
  String? _vue;
  bool _choisie = false;

  Widget _titre(BuildContext context, String texte) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Bilan — ${evenement.nom}', key: const Key('titre_bilan'))),
      body: widget.gymnases == null
          ? _corps(context, const [], null)
          : StreamBuilder<List<Gymnase>>(
              stream: widget.gymnases,
              builder: (context, g) => g.data == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<Map<String, Map<String, int>>>(
                      stream: widget.stocks,
                      builder: (context, s) => s.data == null
                          ? const Center(child: CircularProgressIndicator())
                          : _corps(context, g.data!, s.data),
                    ),
            ),
    );
  }

  Widget _corps(BuildContext context, List<Gymnase> gymnases,
      Map<String, Map<String, int>>? stocks) {
    // Le sélecteur n'apparaît que s'il y a un choix à faire.
    final choix = gymnases.length + (widget.commun ? 1 : 0);
    final multiple = gymnases.length > 1;
    if (!_choisie || !vueValide(_vue, commun: widget.commun, gymnases: gymnases)) {
      _vue = vueParDefaut(commun: widget.commun, gymnases: gymnases);
    }
    final vue = _vue;
    return StreamBuilder<TableauDeBord>(
        stream: widget.tableau,
        builder: (context, t) => StreamBuilder<List<ProduitEvenement>>(
          stream: widget.produits,
          builder: (context, p) {
            final tab = t.data;
            final prods = p.data;
            if (tab == null || prods == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final b = Bilan.depuis(tab, prods, evenement.modes,
                gymnaseId: vue, stocks: stocks);
            String nomGymnase(String id) =>
                gymnases.where((g) => g.id == id).firstOrNull?.nom ?? '?';
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                multiple && choix >= 2
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelecteurVue(
                          gymnases: gymnases,
                          commun: widget.commun,
                          vue: vue,
                          onChanged: (v) => setState(() {
                            _vue = v;
                            _choisie = true;
                          }),
                        ),
                      )
                    : const SizedBox.shrink(),
                Text(
                  evenement.enCours
                      ? 'Bilan provisoire : événement en cours'
                      : 'Bilan définitif : événement clôturé',
                  key: const Key('bilan_etat'),
                ),
                if (limite)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                        "Bilan limité à vos gymnases : les chiffres des autres gymnases ne sont pas inclus.",
                        key: Key('bilan_limite')),
                  ),
                // Clôture forcée : le bilan le dit clairement.
                if (!evenement.enCours && evenement.forcee)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Clôture forcée par ${evenement.clotureParPrenom ?? '?'}'
                      '${evenement.clotureLe == null ? '' : ' le ${dateAffichee(dateIso(evenement.clotureLe!))} à ${heureAffichee(evenement.clotureLe!)}'}'
                      ' : ${pluriel(evenement.nbCaissesOuvertes, 'caisse')} non clôturée${accord(evenement.nbCaissesOuvertes)}'
                      '${b.caissesNonCloturees.isEmpty ? '' : ' (${b.caissesNonCloturees.join(', ')})'}.'
                      ' Des ventes peuvent manquer.',
                      key: const Key('bilan_forcee'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                if (evenement.enCours && b.caissesNonCloturees.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${pluriel(b.caissesNonCloturees.length, 'caisse')} pas encore clôturée${accord(b.caissesNonCloturees.length)} : '
                      '${b.caissesNonCloturees.join(', ')}',
                      key: const Key('bilan_caisses_ouvertes'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total : ${formaterEuros(b.totalCentimes)} · ${pluriel(b.nbVentes, 'vente')}',
                  key: const Key('bilan_total'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (b.nbAnnulees > 0)
                  Text('Ventes annulées : ${b.nbAnnulees}',
                      key: const Key('bilan_annulees')),

                _titre(context, 'Par produit'),
                for (final l in b.produits)
                  Text(
                    '${l.nom} : ${pluriel(l.quantite, 'vendu')} · ${formaterEuros(l.montantCentimes)}'
                    '${l.stock == null ? '' : ' · stock ${l.stock}'}'
                    '${l.detailStock.length > 1 ? ' ${detailStockAffiche(l.detailStock, gymnases)}' : ''}',
                    key: Key('bilan_produit_${l.id}'),
                  ),

                if (b.plusVendus.isNotEmpty) ...[
                  _titre(context, 'Produits les plus vendus'),
                  for (var i = 0; i < b.plusVendus.length; i++)
                    Text('${i + 1}. ${b.plusVendus[i].nom} (${b.plusVendus[i].quantite})',
                        key: Key('plus_${i + 1}')),
                ],
                if (b.moinsVendus.isNotEmpty) ...[
                  _titre(context, 'Produits les moins vendus'),
                  for (var i = 0; i < b.moinsVendus.length; i++)
                    Text('${i + 1}. ${b.moinsVendus[i].nom} (${b.moinsVendus[i].quantite})',
                        key: Key('moins_${i + 1}')),
                ],

                _titre(context, 'Par mode de paiement'),
                for (final e in b.parMode.entries)
                  Text('${modesPaiement[e.key] ?? e.key} : ${formaterEuros(e.value)}',
                      key: Key('bilan_mode_${e.key}')),

                _titre(context, 'Par caisse'),
                if (b.caisses.isEmpty)
                  const Text('Aucune caisse.', key: Key('bilan_aucune_caisse')),
                for (final c in b.caisses)
                  Text(
                    '${c.prenom} : ${pluriel(c.nbVentes, 'vente')} · ${formaterEuros(c.totalCentimes)}'
                    ' · ${c.cloturee ? 'Clôturée' : 'Ouverte'}'
                    '${c.nbAnnulees == 0 ? '' : ' · ${pluriel(c.nbAnnulees, 'annulée')}'}'
                    '${multiple ? ' · ${nomGymnase(c.gymnaseId)}' : ''}',
                    key: Key('bilan_caisse_${c.id}'),
                  ),

                _titre(context, 'Par jour'),
                if (b.jours.isEmpty)
                  const Text('Aucune vente.', key: Key('bilan_aucun_jour')),
                for (final j in b.jours)
                  Text(
                    '${dateAffichee(j.jour)} : ${pluriel(j.nbVentes, 'vente')} · ${formaterEuros(j.totalCentimes)}',
                    key: Key('bilan_jour_${j.jour}'),
                  ),

                _titre(context, 'Heures de pointe'),
                if (b.heuresDePointe.isEmpty)
                  const Text('Aucune vente.', key: Key('bilan_aucune_pointe')),
                for (var i = 0; i < b.heuresDePointe.length; i++)
                  Text(
                    '${trancheAffichee(b.heuresDePointe[i].heure)} : ${pluriel(b.heuresDePointe[i].nbVentes, 'vente')}',
                    key: Key('pointe_${i + 1}'),
                  ),

                if (b.annulations.isNotEmpty) ...[
                  _titre(context, 'Ventes annulées'),
                  for (var i = 0; i < b.annulations.length; i++)
                    Text(
                      '${b.annulations[i].caissePrenom} · ${heureAffichee(b.annulations[i].venteLe)}'
                      ' · ${formaterEuros(b.annulations[i].totalCentimes)}'
                      ' (${modesPaiement[b.annulations[i].mode] ?? b.annulations[i].mode})'
                      ' — annulée par ${b.annulations[i].parPrenom ?? '?'}'
                      '${b.annulations[i].annuleeLe == null ? '' : ' à ${heureAffichee(b.annulations[i].annuleeLe!)}'}',
                      key: Key('annulation_$i'),
                    ),
                ],
              ],
            );
          },
        ),
      );
  }
}
