import 'package:flutter/material.dart';

import 'depot_menus.dart';
import 'theme.dart';

/// Couleur de chaque famille (décision 63, reprise de la maquette Menu.dc.html).
/// Définie ici une seule fois : pastilles et en-têtes de toutes les listes par familles.
const couleursFamilles = <String, Color>{
  'croques': Color(0xFFD9B06F),
  'boissons_chaudes': Color(0xFF9A670F),
  'boissons_fraiches': Color(0xFFA04467),
  'snacks_fruits': Color(0xFF5A7D4F),
  'fait_maison': Color(0xFF6C4F86),
  'autre': Color(0xFF5F6573),
};

/// Mots de liaison ignorés pour les initiales : « Barre de céréales » -> « BC ».
const _motsLiaison = {'de', 'du', 'des', 'la', 'le', 'les', 'et', 'au', 'aux', 'en', 'sur', 'a', 'à'};

/// Initiales d'un nom pour une pastille : « Croque-monsieur » -> « CM », « Coca » -> « Co ».
String initialesDe(String nom) {
  var mots = nom
      .split(RegExp(r'[\s\-]+'))
      .map((m) => m.replaceAll(RegExp(r'[()\[\]"«».,:!?]'), ''))
      .where((m) => m.isNotEmpty)
      .toList();
  final utiles = mots.where((m) => !_motsLiaison.contains(m.toLowerCase())).toList();
  if (utiles.isNotEmpty) mots = utiles;
  if (mots.isEmpty) return '?';
  String majuscule(String m) => m.substring(0, 1).toUpperCase();
  if (mots.length == 1) {
    final m = mots.first;
    return m.length < 2 ? majuscule(m) : majuscule(m) + m.substring(1, 2);
  }
  return majuscule(mots[0]) + majuscule(mots[1]);
}

/// Pastille carrée à la couleur d'une famille, avec les initiales du nom. Sert quand
/// le produit n'a ni photo ni icône juste (décision 67) : jamais une mauvaise image.
class PastilleProduit extends StatelessWidget {
  const PastilleProduit({
    super.key,
    required this.nom,
    required this.couleur,
    this.taille = 40,
  });

  final String nom;
  final Color couleur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    // Texte sombre sur les couleurs claires (sable), blanc sur les autres.
    final texte = couleur.computeLuminance() > 0.4 ? Palette.encre : Colors.white;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initialesDe(nom),
        style: TextStyle(
          color: texte,
          fontWeight: FontWeight.w700,
          fontSize: taille * 0.34,
        ),
      ),
    );
  }
}

/// Liste d'éléments rangée par familles : un bloc repliable par famille, avec pastille,
/// titre, compteur, et une recherche sur le nom. Générique : ne connaît ni le menu ni
/// l'événement. [familleDe] donne la clé de famille de chaque élément ; une clé inconnue
/// va dans la dernière famille (« Autre »). [ligne] construit une ligne (le caller reçoit
/// la couleur de la famille pour sa pastille). Par défaut : les six familles de l'appli.
///
/// Au départ, les familles sont repliées ; pendant une recherche, celles qui ont un
/// résultat sont dépliées. Une famille sans aucun élément n'est pas affichée.
class ListeFamilles<T> extends StatefulWidget {
  const ListeFamilles({
    super.key,
    required this.elements,
    required this.familleDe,
    required this.nomDe,
    required this.ligne,
    this.enTete,
    this.familles = famillesProduit,
    this.libelles = libellesFamilles,
    this.couleurs = couleursFamilles,
    this.avecRecherche = true,
    this.compteurDe,
    this.mentions = const {},
  });

  final List<T> elements;
  final String Function(T element) familleDe;

  /// Texte sur lequel porte la recherche (sans accents ni casse).
  final String Function(T element) nomDe;
  final Widget Function(BuildContext context, T element, Color couleurFamille)
      ligne;

  /// Bandeau affiché au-dessus de la recherche (facultatif).
  final Widget? enTete;

  /// Clés des familles, dans l'ordre d'affichage (la dernière sert de « Autre »).
  final List<String> familles;
  final Map<String, String> libelles;
  final Map<String, Color> couleurs;
  final bool avecRecherche;

  /// Texte du compteur d'une famille (par défaut : son nombre d'éléments affichés).
  final String Function(List<T> items, String famille)? compteurDe;

  /// Mention affichée à la place du compteur pour une famille (ex. « Apporté le jour
  /// même »). Une famille avec mention reste repliée tant qu'on ne la déplie pas.
  final Map<String, String> mentions;

  @override
  State<ListeFamilles<T>> createState() => _EtatListeFamilles<T>();
}

class _EtatListeFamilles<T> extends State<ListeFamilles<T>> {
  final _recherche = TextEditingController();

  /// Choix fait à la main par famille (absent = réglage automatique).
  final Map<String, bool> _ouvert = {};

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requete = cleIngredient(_recherche.text);
    final parFamille = <String, List<T>>{
      for (final f in widget.familles) f: <T>[],
    };
    for (final e in widget.elements) {
      var f = widget.familleDe(e);
      if (!parFamille.containsKey(f)) f = widget.familles.last;
      if (requete.isEmpty || cleIngredient(widget.nomDe(e)).contains(requete)) {
        parFamille[f]!.add(e);
      }
    }
    final sections = [
      for (final f in widget.familles)
        if (parFamille[f]!.isNotEmpty) _section(f, parFamille[f]!, requete.isNotEmpty),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        ?widget.enTete,
        if (widget.avecRecherche)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              key: const Key('recherche_familles'),
              controller: _recherche,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Chercher un produit',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ...sections,
        if (sections.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Aucun produit ne correspond.',
                key: Key('aucun_resultat_familles'),
                textAlign: TextAlign.center),
          ),
      ],
    );
  }

  Widget _section(String f, List<T> items, bool recherche) {
    final couleur = widget.couleurs[f] ?? Palette.gris;
    final ouvert = _ouvert[f] ?? recherche;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Palette.papier,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Palette.filet),
        ),
        child: Column(
          children: [
            InkWell(
              key: Key('entete_famille_$f'),
              onTap: () => setState(() => _ouvert[f] = !ouvert),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: couleur, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.libelles[f] ?? f,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    Text(
                      widget.mentions[f] ??
                          (widget.compteurDe?.call(items, f) ??
                              '${items.length}'),
                      key: widget.mentions.containsKey(f)
                          ? Key('mention_famille_$f')
                          : Key('compteur_famille_$f'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Palette.gris),
                    ),
                    Icon(ouvert ? Icons.expand_less : Icons.expand_more,
                        color: Palette.gris),
                  ],
                ),
              ),
            ),
            if (ouvert)
              ...items.expand((e) => [
                    const Divider(height: 1),
                    widget.ligne(context, e, couleur),
                  ]),
          ],
        ),
      ),
    );
  }
}
