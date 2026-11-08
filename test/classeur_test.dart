import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/export_bilan.dart';
import 'package:le_comptoir/gymnase.dart';

import 'classeur_aides.dart';

// Étape E8 : le modèle du classeur Excel (décisions 57 et 66), logique pure.
//   Menu riche : composé avec recette et rayons, litre (café), à la part apportée,
//   à l'unité ; accents, prix 2,50 €, consommation 0,75, recette avec 1/4 de tranche.
final _produits = [
  const ProduitEvenement('croque', 'Croque-monsieur', 300, null,
      fiche: FicheProduit(
        type: 'compose',
        conso: 2,
        famille: 'croques',
        ingredients: [
          Ingredient('Pain de mie', 2, 'tranche', 'boulangerie'),
          Ingredient('Jambon', 0.25, 'tranche', 'frais'),
          Ingredient('Gruyère râpé', 25, 'g', 'frais'),
          Ingredient('Œuf', 1, 'unite', 'epicerie'),
        ],
      )),
  const ProduitEvenement('cafe', 'Café', 100, null,
      fiche: FicheProduit(
          type: 'litre',
          verresParLitre: 8,
          conso: 2,
          famille: 'boissons_chaudes',
          rayon: 'boissons')),
  const ProduitEvenement('gateau', 'Gâteau salé', 250, null,
      fiche: FicheProduit(
          type: 'part',
          partsParEntier: 8,
          provenance: 'apporte',
          conso: 0.75,
          famille: 'fait_maison')),
  const ProduitEvenement('fruit', 'Fruit', 50, null,
      fiche: FicheProduit(famille: 'snacks_fruits')),
  const ProduitEvenement('eau', 'Eau', 120, null,
      fiche: FicheProduit(
          type: 'litre',
          verresParLitre: 6.5,
          famille: 'boissons_fraiches',
          rayon: 'boissons')),
];

const _gymnases = [Gymnase('gA', 'Gymnase Édith'), Gymnase('gB', 'Gymnase B')];

const _stocks = {
  'gA': {
    'croque': StockDepart(40),
    'cafe': StockDepart(0),
    'gateau': StockDepart(3, repris: true),
  },
  'gB': {'fruit': StockDepart(25)},
};

List<int> _modele() =>
    construireModele(produits: _produits, gymnases: _gymnases, stocks: _stocks);

/// Un classeur de test : feuilles données (nom -> lignes), chaque ligne = cellules.
List<int> _classeur(Map<String, List<List<CellValue?>>> feuilles) {
  final x = Excel.createExcel();
  final defaut = x.getDefaultSheet()!;
  var premiere = true;
  for (final e in feuilles.entries) {
    if (premiere) {
      x.rename(defaut, e.key);
      premiere = false;
    }
    for (final l in e.value) {
      x[e.key].appendRow(l);
    }
  }
  return x.encode()!;
}

List<CellValue?> _l(List<Object?> v) => [
      for (final c in v)
        c == null
            ? null
            : c is int
                ? IntCellValue(c)
                : c is double
                    ? DoubleCellValue(c)
                    : TextCellValue(c.toString())
    ];

/// Une ligne du Menu (ancien format, sans Famille ni Rayon) : ordre des colonnes de
/// l'ancien modèle.
List<List<CellValue?>> _menuAncien(List<List<Object?>> lignes) => [
      _l(['aide']),
      _l(entetesMenuAncien),
      for (final l in lignes) _l(l),
    ];

/// Les données d'une feuille du modèle (à partir de la ligne 7), cellules sans valeur
/// de fin retirées.
List<List<Data?>> _donnees(Sheet f) => f.rows.skip(6).toList();

/// Les cellules d'une ligne, texte ou nombre, pour comparer.
List<Object?> _valeurs(List<Data?> l) => [
      for (final d in l)
        switch (d?.value) {
          null => null,
          IntCellValue v => v.value,
          DoubleCellValue v => v.value,
          final v => v.toString(),
        }
    ];

void main() {
  group('critère 1 : Accueil d\'abord, puis les feuilles du modèle', () {
    test('six feuilles dans l\'ordre : Accueil, Menu, Recettes, Stock de départ, '
        'Historique, Courses', () {
      final o = _modele();
      expect(o.sublist(0, 2), [0x50, 0x4B]); // « PK » : début d'un zip
      final x = Excel.decodeBytes(o);
      expect(x.tables.keys.toList(), [
        'Accueil',
        'Menu',
        'Recettes',
        'Stock de départ',
        'Historique',
        'Courses',
      ]);
      expect(feuillesModele, x.tables.keys.toList());
      expect(x.getDefaultSheet(), 'Accueil');
    });
  });

  group('critère 2 : bandeau, couleurs, largeurs (les volets figés et les listes '
      'déroulantes ne sont pas écrits par le paquet excel 4.0.6)', () {
    test('bandeau anthracite et titre, en-têtes violets, largeurs de colonnes', () {
      final x = Excel.decodeBytes(_modele());
      final menu = x.tables['Menu']!;
      expect(menu.rows[1][0]?.value.toString(), 'Menu');
      expect(menu.rows[1][0]?.cellStyle?.backgroundColor.colorHex, 'FF2F343C');
      expect(menu.rows[1][0]?.cellStyle?.fontColor.colorHex, 'FFFFFFFF');
      // En-tête : ligne 6, fond violet, texte blanc.
      expect(menu.rows[5][1]?.value.toString(), 'Produit');
      expect(menu.rows[5][1]?.cellStyle?.backgroundColor.colorHex, 'FF6C4F86');
      // Case calculée (Historique, consommation) : beige.
      final histo = x.tables['Historique']!;
      expect(histo.rows[6][6]?.cellStyle?.backgroundColor.colorHex, 'FFE8DFD0');
      // Largeurs : Famille 24, Produit 32.
      expect(menu.getColumnWidth(0), closeTo(24, 1));
      expect(menu.getColumnWidth(1), closeTo(32, 1));
    });

    test('la ligne d\'aide est étirée (fusion) et la feuille est sans quadrillage', () {
      final x = Excel.decodeBytes(_modele());
      final stock = x.tables['Stock de départ']!;
      expect(stock.rows[4][0]?.value.toString(), startsWith('Une ligne par gymnase'));
      expect(stock.spannedItems, contains('A5:C5'));
    });
  });

  test('critère 3 : aller-retour exact des produits, familles, recettes et rayons', () {
    final lu = lireClasseur(_modele());
    expect(lu.erreurs, isEmpty);
    expect(lu.produits.length, _produits.length);
    for (var i = 0; i < _produits.length; i++) {
      final a = _produits[i];
      final b = lu.produits[i];
      expect(b.nom, a.nom);
      expect(b.prixCentimes, a.prixCentimes);
      expect(b.fiche.type, a.fiche.type);
      expect(b.fiche.provenance, a.fiche.provenance);
      expect(b.fiche.verresParLitre, a.fiche.verresParLitre);
      expect(b.fiche.partsParEntier, a.fiche.partsParEntier);
      expect(b.fiche.conso, a.fiche.conso);
      expect(b.fiche.famille, a.fiche.famille, reason: a.nom);
      expect(b.fiche.rayon, a.fiche.rayon, reason: a.nom);
      expect(b.fiche.ingredients, a.fiche.ingredients);
    }
    // Stocks : (gymnase, produit) -> quantité ou vide.
    final attendu = <(String, String), int?>{};
    for (final g in _gymnases) {
      for (final p in _produits) {
        attendu[(g.nom, p.nom)] = _stocks[g.id]?[p.id]?.quantite;
      }
    }
    expect(lu.stocks.length, attendu.length);
    for (final s in lu.stocks) {
      expect(s.quantite, attendu[(s.gymnase, s.produit)],
          reason: '${s.gymnase} / ${s.produit}');
    }
    expect(lu.historique, isEmpty);
  });

  test('Menu : produits dans l\'ordre, accents, prix et consommations numériques, '
      'Famille et Rayon écrits', () {
    final x = Excel.decodeBytes(_modele());
    final menu = _donnees(x.tables['Menu']!);
    expect(menu.length, 5);
    final croque = _valeurs(menu[0]);
    expect(croque[0], 'Croques'); // Famille
    expect(croque[1], 'Croque-monsieur');
    expect(croque[2], 3); // 3 € : nombre
    expect(croque[3], 'Composé (recette)');
    expect(croque[7], isNull); // pas de rayon pour un produit composé
    final gateau = _valeurs(menu[2]);
    expect(gateau[1], 'Gâteau salé');
    expect(gateau[2], 2.5); // 2,50 € : nombre
    expect(gateau[3], 'À la part');
    expect(gateau[4], 'Apporté par les bénévoles');
    expect(gateau[6], 8);
    expect(gateau[8], 0.75);
    expect(_valeurs(menu[1])[7], 'Boissons');
    expect(_valeurs(menu[3])[7], 'Autre'); // achat tel quel sans rayon : « Autre »
  });

  test('Recettes : un ingrédient par ligne, avec quantité, unité et rayon', () {
    final x = Excel.decodeBytes(_modele());
    final recettes = _donnees(x.tables['Recettes']!);
    expect(recettes.length, 4);
    expect(_valeurs(recettes[0]),
        ['Croque-monsieur', 'Pain de mie', 2, 'tranche', 'Boulangerie']);
    expect(_valeurs(recettes[1]),
        ['Croque-monsieur', 'Jambon', 0.25, 'tranche', 'Frais et crèmerie']);
    expect(_valeurs(recettes[3]),
        ['Croque-monsieur', 'Œuf', 1, 'unité', 'Épicerie']);
  });

  test('critère 4 : l\'Historique a une dernière colonne de consommation par personne '
      'et par jour, en formule', () {
    final x = Excel.decodeBytes(_modele());
    final histo = x.tables['Historique']!;
    expect(histo.rows[5][6]?.value.toString(), 'Consommation par personne et par jour');
    final formule = histo.rows[6][6]?.value;
    expect(formule, isA<FormulaCellValue>());
    // Ligne 7 : quantité vendue (F) divisée par personnes (C) × jours (D).
    expect((formule as FormulaCellValue).formula, contains('F7/(C7*D7)'));
    // Le modèle vide prévoit des lignes de calcul (formules, sans saisie).
    expect(_donnees(histo).length, 200);
    expect(lireClasseur(_modele()).historique, isEmpty);
  });

  test('lecture tolérante : texte avec virgule, espaces, lignes vides, ordre des '
      'colonnes libre', () {
    final o = _classeur({
      'Menu': [
        _l(['aide']),
        _l(['Consommation par personne et par jour', 'Produit', 'Prix', 'Type',
          'Provenance', 'Verres par litre', 'Parts par gâteau']),
        _l([1.5, 'Pizza', '2,50', 'À l\'unité', 'acheté par l\'association', null, null]),
        [null, null, null, null, null, null, null],
        _l([null, '  Thé  ', ' 1 0,5 ', 'au litre', null, '8', null]),
      ],
      'Stock de départ': [
        _l(['aide']),
        _l(['Quantité', 'Produit', 'Gymnase']),
        _l(['1 000', 'Pizza', 'Gymnase A']),
      ],
      'Historique': [_l(['aide']), _l(entetesHistorique)],
    });
    final lu = lireClasseur(o);
    expect(lu.erreurs, isEmpty);
    expect(lu.produits.length, 2);
    expect(lu.produits[0].prixCentimes, 250);
    expect(lu.produits[0].fiche.conso, 1.5);
    expect(lu.produits[0].fiche.famille, 'autre');
    expect(lu.produits[1].nom, 'Thé');
    expect(lu.produits[1].prixCentimes, 1050);
    expect(lu.produits[1].fiche.verresParLitre, 8);
    expect(lu.stocks.single.quantite, 1000);
    expect(lu.stocks.single.gymnase, 'Gymnase A');
  });

  test('famille ou rayon inconnu : rangé dans « Autre », signalé sans bloquer', () {
    final lu = lireClasseur(_classeur({
      'Menu': [
        _l(['aide']),
        _l(['Famille', 'Produit', 'Prix', 'Type', 'Provenance', 'Verres par litre',
          'Parts par gâteau', 'Rayon', 'Consommation par personne et par jour']),
        _l(['Divers', 'Pizza', 2, 'À l\'unité', null, null, null, 'Surgelés', 1]),
      ],
      'Stock de départ': [_l(['aide']), _l(entetesStock)],
      'Historique': [_l(['aide']), _l(entetesHistorique)],
    }));
    expect(lu.produits.single.fiche.famille, 'autre');
    expect(lu.produits.single.fiche.rayon, 'autre');
    expect(lu.erreurs.length, 2);
    expect(lu.erreurs[0], contains('famille « Divers » inconnue'));
    expect(lu.erreurs[1], contains('rayon « Surgelés » inconnue'));
    expect(lu.erreurs.any((e) => e.contains(', ligne ')), isFalse);
  });

  test('feuille ou colonne manquante : erreur claire', () {
    final sansMenu = lireClasseur(_classeur({
      'Stock de départ': [_l(['aide']), _l(entetesStock)],
      'Historique': [_l(['aide']), _l(entetesHistorique)],
    }));
    expect(sansMenu.erreurs, contains('Feuille « Menu » introuvable.'));
    expect(sansMenu.produits, isEmpty);

    final sansColonne = lireClasseur(_classeur({
      'Menu': [
        _l(['aide']),
        _l(['Produit', 'Type']),
        _l(['Pizza', 'Au litre']),
      ],
      'Stock de départ': [_l(['aide']), _l(entetesStock)],
      'Historique': [_l(['aide']), _l(entetesHistorique)],
    }));
    expect(sansColonne.erreurs,
        contains('Feuille « Menu » : colonne « Prix » introuvable.'));
    expect(sansColonne.produits, isEmpty);
  });

  test('ligne invalide : listée avec son numéro, ignorée, le reste est lu', () {
    final lu = lireClasseur(_classeur({
      'Menu': _menuAncien([
        ['Bon', 2, null, null, null, null, null, null],
        ['Négatif', -1, null, null, null, null, null, null],
        ['Bizarre', 2, 'Inconnu', null, null, null, null, null],
        ['Litre sans ratio', 2, 'Au litre', null, null, null, null, null],
        ['Recette cassée', 2, 'Composé (recette)', null, null, null, 'beaucoup de sel', null],
        ['Pas un nombre', 'abc', null, null, null, null, null, null],
      ]),
      'Stock de départ': [
        _l(['aide']),
        _l(entetesStock),
        _l(['A', 'Soda', -3]),
        _l(['A', 'Eau', 2.5]),
        _l(['B', 'Soda', 4]),
      ],
      'Historique': [_l(['aide']), _l(entetesHistorique)],
    }));
    expect(lu.produits.map((p) => p.nom), ['Bon']);
    expect(lu.erreurs.length, 7);
    expect(lu.erreurs[0], startsWith('Feuille « Menu », ligne 4 :'));
    expect(lu.erreurs[1], contains('type inconnu'));
    expect(lu.erreurs[2], contains('verres par litre'));
    expect(lu.erreurs[3], contains('ligne 7'));
    expect(lu.erreurs[4], contains('n\'est pas un nombre'));
    expect(lu.stocks.map((s) => (s.gymnase, s.produit, s.quantite)),
        [('B', 'Soda', 4)]);
  });

  test('l\'Historique est lu avec ses contrôles', () {
    final lu = lireClasseur(_classeur({
      'Menu': _menuAncien([]),
      'Stock de départ': [_l(['aide']), _l(entetesStock)],
      'Historique': [
        _l(['aide']),
        _l(entetesHistorique),
        _l(['Tournoi 2025', 'Gymnase A', 40, 2, 'Croque', 160]),
        _l(['Tournoi 2025', 'Gymnase A', 40, 31, 'Croque', 160]),
      ],
    }));
    expect(lu.historique.length, 1);
    expect(lu.historique.single.quantiteVendue, 160);
    expect(lu.historique.single.jours, 2);
    expect(lu.erreurs.single, contains('entre 0,5 et 30 jours'));
  });

  test('un fichier qui n\'est pas un classeur : message clair, aucune lecture', () {
    expect(() => lireClasseur([1, 2, 3, 4]), throwsA(isA<ClasseurIllisible>()));
    expect(() => lireClasseur('a;b\n1;2'.codeUnits),
        throwsA(isA<ClasseurIllisible>()));
  });

  test('critère 5 : les classeurs à l\'ancien format s\'importent comme avant', () {
    // Le classeur du tournoi de l'an passé : feuille Menu vide (en-têtes seuls), ventes
    // dans l'Historique (38 lignes), aucune erreur.
    final an = lireClasseur(File('recette/historique-tournoi-an-passe.xlsx')
        .readAsBytesSync());
    expect(an.erreurs, isEmpty);
    expect(an.produits, isEmpty);
    expect(an.historique.length, 38);
    // Le classeur de l'audit (format précédent, recettes dans la colonne « Recette »).
    final actuel = lireClasseur(
        File('audit_front/ergonomie/classeur_actuel.xlsx').readAsBytesSync());
    expect(actuel.erreurs, isEmpty);
    expect(actuel.produits, isNotEmpty);
  });

  test('recette : unités acceptées en code ou en libellé, « ; » dans un nom '
      'remplacé par une virgule', () {
    expect(recetteDepuisTexte('2 tranches Pain ; 1/4 tranche Jambon ; 25 g Gruyère ; 3 unite Œuf'),
        [
      const Ingredient('Pain', 2, 'tranche'),
      const Ingredient('Jambon', 0.25, 'tranche'),
      const Ingredient('Gruyère', 25, 'g'),
      const Ingredient('Œuf', 3, 'unite'),
    ]);
    expect(recetteEnTexte(const [Ingredient('Sel; poivre', 1, 'g')]),
        '1 g Sel, poivre');
    expect(() => recetteDepuisTexte('2 pincées Sel'), throwsFormatException);
    expect(() => recetteDepuisTexte('beaucoup de sel'), throwsFormatException);
  });

  test('nom du fichier : modele-<événement>-<date>.xlsx', () {
    final ev = Evenement(
        id: 'e',
        nom: 'Tournoi d\'Été 2026 !',
        date: '2026-10-03',
        statut: 'en_preparation',
        modes: const ['carte'],
        menuNom: 'M');
    expect(nomFichierModele(ev), 'modele-tournoi-d-ete-2026-2026-10-03.xlsx');
    expect(nomFichierExport(ev), 'tournoi-tournoi-d-ete-2026-2026-10-03.xlsx');
    expect(typeMimeClasseur,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  });
}
