import 'package:flutter/material.dart';

import 'depot_caisses.dart';
import 'ecran_caisse.dart' show VignetteProduit;
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
            final maxProduit =
                b.produits.fold<int>(0, (m, l) => l.quantite > m ? l.quantite : m);
            final maxPointe =
                b.heuresDePointe.fold<int>(0, (m, h) => h.nbVentes > m ? h.nbVentes : m);
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
                _Bandeau(
                  type: evenement.enCours ? TypeAction.attention : TypeAction.reussir,
                  icone: evenement.enCours ? Icons.hourglass_top : Icons.verified,
                  texte: evenement.enCours
                      ? 'Bilan provisoire : événement en cours'
                      : 'Bilan définitif : événement clôturé',
                  cle: 'bilan_etat',
                ),
                if (limite)
                  const _Bandeau(
                    type: TypeAction.analyser,
                    icone: Icons.filter_alt,
                    texte:
                        "Bilan limité à vos gymnases : les chiffres des autres gymnases ne sont pas inclus.",
                    cle: 'bilan_limite',
                  ),
                // Clôture forcée : le bilan le dit clairement.
                if (!evenement.enCours && evenement.forcee)
                  _Bandeau(
                    type: TypeAction.danger,
                    icone: Icons.warning_amber,
                    gras: true,
                    texte:
                        'Clôture forcée par ${evenement.clotureParPrenom ?? '?'}'
                        '${evenement.clotureLe == null ? '' : ' le ${dateAffichee(dateIso(evenement.clotureLe!))} à ${heureAffichee(evenement.clotureLe!)}'}'
                        ' : ${pluriel(evenement.nbCaissesOuvertes, 'caisse')} non clôturée${accord(evenement.nbCaissesOuvertes)}'
                        '${b.caissesNonCloturees.isEmpty ? '' : ' (${b.caissesNonCloturees.join(', ')})'}.'
                        ' Des ventes peuvent manquer.',
                    cle: 'bilan_forcee',
                  ),
                if (evenement.enCours && b.caissesNonCloturees.isNotEmpty)
                  _Bandeau(
                    type: TypeAction.attention,
                    icone: Icons.point_of_sale,
                    texte:
                        '${pluriel(b.caissesNonCloturees.length, 'caisse')} pas encore clôturée${accord(b.caissesNonCloturees.length)} : '
                        '${b.caissesNonCloturees.join(', ')}',
                    cle: 'bilan_caisses_ouvertes',
                  ),
                const SizedBox(height: 12),
                _Total(
                  total: formaterEuros(b.totalCentimes),
                  ventes: pluriel(b.nbVentes, 'vente'),
                  annulees: b.nbAnnulees,
                ),
                _Section(
                  titre: 'Par mode de paiement',
                  icone: Icons.payments_outlined,
                  enfants: [
                    for (final e in b.parMode.entries)
                      _Ligne(
                        cle: 'bilan_mode_${e.key}',
                        titre: modesPaiement[e.key] ?? e.key,
                        valeur: formaterEuros(e.value),
                        part: b.totalCentimes <= 0 ? 0 : e.value / b.totalCentimes,
                        couleur: Palette.sauge,
                      ),
                  ],
                ),
                _Section(
                  titre: 'Par produit',
                  icone: Icons.fastfood_outlined,
                  enfants: [
                    for (final l in b.produits)
                      _LigneProduit(
                        cle: 'bilan_produit_${l.id}',
                        ligne: l,
                        produit: prods.where((x) => x.id == l.id).firstOrNull,
                        part: maxProduit == 0 ? 0 : l.quantite / maxProduit,
                        detail: l.detailStock.length > 1
                            ? detailStockAffiche(l.detailStock, gymnases)
                            : '',
                      ),
                  ],
                ),
                if (b.plusVendus.isNotEmpty)
                  _Section(
                    titre: 'Produits les plus vendus',
                    icone: Icons.trending_up,
                    enfants: [
                      for (var i = 0; i < b.plusVendus.length; i++)
                        _LigneRang(
                          cle: 'plus_${i + 1}',
                          rang: i + 1,
                          nom: b.plusVendus[i].nom,
                          quantite: b.plusVendus[i].quantite,
                          couleur: Palette.sauge,
                        ),
                    ],
                  ),
                if (b.moinsVendus.isNotEmpty)
                  _Section(
                    titre: 'Produits les moins vendus',
                    icone: Icons.trending_down,
                    enfants: [
                      for (var i = 0; i < b.moinsVendus.length; i++)
                        _LigneRang(
                          cle: 'moins_${i + 1}',
                          rang: i + 1,
                          nom: b.moinsVendus[i].nom,
                          quantite: b.moinsVendus[i].quantite,
                          couleur: Palette.ocre,
                        ),
                    ],
                  ),
                _Section(
                  titre: 'Par caisse',
                  icone: Icons.point_of_sale,
                  enfants: [
                    if (b.caisses.isEmpty)
                      const _Vide('Aucune caisse.', 'bilan_aucune_caisse'),
                    for (final c in b.caisses)
                      _LigneCaisse(
                        cle: 'bilan_caisse_${c.id}',
                        caisse: c,
                        gymnase: multiple ? nomGymnase(c.gymnaseId) : null,
                      ),
                  ],
                ),
                _Section(
                  titre: 'Par jour',
                  icone: Icons.calendar_month_outlined,
                  enfants: [
                    if (b.jours.isEmpty)
                      const _Vide('Aucune vente.', 'bilan_aucun_jour'),
                    for (final j in b.jours)
                      _Ligne(
                        cle: 'bilan_jour_${j.jour}',
                        titre: dateAffichee(j.jour),
                        sous: pluriel(j.nbVentes, 'vente'),
                        valeur: formaterEuros(j.totalCentimes),
                      ),
                  ],
                ),
                _Section(
                  titre: 'Heures de pointe',
                  icone: Icons.schedule,
                  enfants: [
                    if (b.heuresDePointe.isEmpty)
                      const _Vide('Aucune vente.', 'bilan_aucune_pointe'),
                    for (var i = 0; i < b.heuresDePointe.length; i++)
                      _Ligne(
                        cle: 'pointe_${i + 1}',
                        titre: trancheAffichee(b.heuresDePointe[i].heure),
                        valeur: pluriel(b.heuresDePointe[i].nbVentes, 'vente'),
                        part: maxPointe == 0
                            ? 0
                            : b.heuresDePointe[i].nbVentes / maxPointe,
                        couleur: Palette.framboise,
                      ),
                  ],
                ),
                if (b.annulations.isNotEmpty)
                  _Section(
                    titre: 'Ventes annulées',
                    icone: Icons.undo,
                    enfants: [
                      for (var i = 0; i < b.annulations.length; i++)
                        _LigneAnnulation(cle: 'annulation_$i', a: b.annulations[i]),
                    ],
                  ),
              ],
            );
          },
        ),
      );
  }
}

/// Message en tête du bilan (état, clôture forcée, caisses ouvertes) : un seul
/// texte, sur un fond de la couleur de son sens.
class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.type,
    required this.icone,
    required this.texte,
    required this.cle,
    this.gras = false,
  });

  final TypeAction type;
  final IconData icone;
  final String texte;
  final String cle;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: type.doux,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: type.fort.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: type.fonce, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              key: Key(cle),
              style: TextStyle(
                color: type.fonce,
                fontWeight: gras ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le chiffre qui compte : total encaissé et nombre de ventes, puis les ventes
/// annulées (qui ne comptent pas dans le total).
class _Total extends StatelessWidget {
  const _Total({required this.total, required this.ventes, required this.annulees});

  final String total;
  final String ventes;
  final int annulees;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const Key('bilan_total'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Palette.anthracite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total des ventes',
                  style: TextStyle(color: Palette.sableDoux, fontSize: 14)),
              const SizedBox(height: 4),
              Text(total,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(ventes, style: const TextStyle(color: Palette.sable, fontSize: 16)),
            ],
          ),
        ),
        if (annulees > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TypeAction.danger.doux,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Ventes annulées : $annulees',
                  key: const Key('bilan_annulees'),
                  style: TextStyle(
                      color: TypeAction.danger.fonce,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

/// Un bloc du bilan : titre à icône puis une carte de lignes séparées par un filet.
class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.icone, required this.enfants});

  final String titre;
  final IconData icone;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(icone, size: 20, color: Palette.anthracite),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(titre,
                        style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < enfants.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Palette.filet),
                    enfants[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide(this.texte, this.cle);

  final String texte;
  final String cle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(texte, key: Key(cle), style: const TextStyle(color: Palette.gris)),
      );
}

/// Barre de proportion fine sous une ligne.
class _Barre extends StatelessWidget {
  const _Barre(this.part, this.couleur);

  final double part;
  final Color couleur;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: part.clamp(0.0, 1.0),
          minHeight: 6,
          color: couleur,
          backgroundColor: couleur.withValues(alpha: 0.15),
        ),
      );
}

const _styleMontant = TextStyle(fontWeight: FontWeight.w700, fontSize: 16);
const _styleDiscret = TextStyle(color: Palette.gris, fontSize: 13);

/// Titre à gauche (sous-titre facultatif), valeur à droite, barre facultative.
class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.cle,
    required this.titre,
    required this.valeur,
    this.sous,
    this.part,
    this.couleur = Palette.sauge,
  });

  final String cle;
  final String titre;
  final String? sous;
  final String valeur;
  final double? part;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key(cle),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (sous != null) Text(sous!, style: _styleDiscret),
                  ],
                ),
              ),
              Text(valeur, style: _styleMontant),
            ],
          ),
          if (part != null) ...[
            const SizedBox(height: 8),
            _Barre(part!, couleur),
          ],
        ],
      ),
    );
  }
}

/// Un produit : vignette, nom, quantité vendue, stock restant, montant.
class _LigneProduit extends StatelessWidget {
  const _LigneProduit({
    required this.cle,
    required this.ligne,
    required this.produit,
    required this.part,
    required this.detail,
  });

  final String cle;
  final LigneProduitBilan ligne;
  final ProduitEvenement? produit;
  final double part;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key(cle),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                child: VignetteProduit(
                    icone: produit?.icone, photo: produit?.photo, taille: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ligne.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(pluriel(ligne.quantite, 'vendu'), style: _styleDiscret),
                        if (ligne.stock != null)
                          Text('Stock ${ligne.stock}',
                              style: TextStyle(
                                  color: ligne.stock! <= 0
                                      ? Palette.brique
                                      : Palette.saugeFonce,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        if (detail.isNotEmpty)
                          Text(detail,
                              style: const TextStyle(color: Palette.gris, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(formaterEuros(ligne.montantCentimes), style: _styleMontant),
            ],
          ),
          const SizedBox(height: 8),
          _Barre(part, Palette.prune),
        ],
      ),
    );
  }
}

/// Un rang du classement : pastille du rang, nom, quantité vendue.
class _LigneRang extends StatelessWidget {
  const _LigneRang({
    required this.cle,
    required this.rang,
    required this.nom,
    required this.quantite,
    required this.couleur,
  });

  final String cle;
  final int rang;
  final String nom;
  final int quantite;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key(cle),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: couleur.withValues(alpha: 0.15),
            child: Text('$rang',
                style: TextStyle(
                    color: couleur, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(pluriel(quantite, 'vendu'), style: const TextStyle(color: Palette.gris)),
        ],
      ),
    );
  }
}

/// Une caisse : prénom (et gymnase), état, nombre de ventes, total.
class _LigneCaisse extends StatelessWidget {
  const _LigneCaisse({required this.cle, required this.caisse, required this.gymnase});

  final String cle;
  final CaisseBilan caisse;
  final String? gymnase;

  @override
  Widget build(BuildContext context) {
    final c = caisse;
    final type = c.cloturee ? TypeAction.reussir : TypeAction.attention;
    return Padding(
      key: Key(cle),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.prenom, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (gymnase != null) Text(gymnase!, style: _styleDiscret),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: type.doux,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(c.cloturee ? 'Clôturée' : 'Ouverte',
                          style: TextStyle(
                              color: type.fonce,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(pluriel(c.nbVentes, 'vente'), style: _styleDiscret),
                    if (c.nbAnnulees > 0)
                      Text(pluriel(c.nbAnnulees, 'annulée'),
                          style: const TextStyle(color: Palette.brique, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Text(formaterEuros(c.totalCentimes), style: _styleMontant),
        ],
      ),
    );
  }
}

/// Une vente annulée avec sa trace : qui, quand, combien.
class _LigneAnnulation extends StatelessWidget {
  const _LigneAnnulation({required this.cle, required this.a});

  final String cle;
  final AnnulationBilan a;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key(cle),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${a.caissePrenom} · ${heureAffichee(a.venteLe)} · ${modesPaiement[a.mode] ?? a.mode}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    'Annulée par ${a.parPrenom ?? '?'}'
                    '${a.annuleeLe == null ? '' : ' à ${heureAffichee(a.annuleeLe!)}'}',
                    style: const TextStyle(color: Palette.brique, fontSize: 13)),
              ],
            ),
          ),
          Text(formaterEuros(a.totalCentimes),
              style: _styleMontant.copyWith(decoration: TextDecoration.lineThrough)),
        ],
      ),
    );
  }
}
