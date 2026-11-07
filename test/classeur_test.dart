import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/export_bilan.dart';
import 'package:le_comptoir/gymnase.dart';

// Étape P5 : le modèle du classeur Excel (décision 57), logique pure.
//   Menu riche : composé avec recette, litre (café), à la part apportée, à l'unité ;
//   accents, prix 2,50 €, consommation 0,75, recette avec 1/4 de tranche.
final _produits = [
  const ProduitEvenement('croque', 'Croque-monsieur', 300, null,
      fiche: FicheProduit(
        type: 'compose',
        conso: 2,
        ingredients: [
          Ingredient('Pain de mie', 2, 'tranche'),
          Ingredient('Jambon', 0.25, 'tranche'),
          Ingredient('Gruyère râpé', 25, 'g'),
          Ingredient('Œuf', 1, 'unite'),
        ],
      )),
  const ProduitEvenement('cafe', 'Café', 100, null,
      fiche: FicheProduit(type: 'litre', verresParLitre: 8, conso: 2)),
  const ProduitEvenement('gateau', 'Gâteau salé', 250, null,
      fiche: FicheProduit(
          type: 'part', partsParEntier: 8, provenance: 'apporte', conso: 0.75)),
  const ProduitEvenement('fruit', 'Fruit', 50, null),
  const ProduitEvenement('eau', 'Eau', 120, null,
      fiche: FicheProduit(type: 'litre', verresParLitre: 6.5)),
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

List<List<CellValue?>> _menuAvec(List<List<Object?>> lignes) => [
      _l(['aide']),
      _l(entetesMenu),
      for (final l in lignes) _l(l),
    ];

void main() {
  test('critère 1 : un vrai .xlsx (zip « PK »), quatre feuilles dans l\'ordre', () {
    final o = _modele();
    expect(o.sublist(0, 2), [0x50, 0x4B]); // « PK » : début d'un zip
    final x = Excel.decodeBytes(o);
    expect(x.tables.keys.toList(),
        ['Menu', 'Stock de départ', 'Historique', 'Courses']);
    expect(feuillesModele, x.tables.keys.toList());
  });

  test('chaque feuille : ligne 1 = aide en français, ligne 2 = en-têtes exacts', () {
    final x = Excel.decodeBytes(_modele());
    const attendus = {
      'Menu': [
        'Produit',
        'Prix',
        'Type',
        'Provenance',
        'Verres par litre',
        'Parts par gâteau',
        'Recette',
        'Consommation par personne et par jour',
      ],
      'Stock de départ': ['Gymnase', 'Produit', 'Quantité'],
      'Historique': [
        'Événement',
        'Gymnase',
        'Personnes',
        'Jours',
        'Produit',
        'Quantité vendue'
      ],
      'Courses': [
        'Série',
        'Produit ou ligne libre',
        'Quantité achetée',
        'Coût'
      ],
    };
    for (final e in attendus.entries) {
      final lignes = x.tables[e.key]!.rows;
      expect(lignes[0][0]?.value.toString().length, greaterThan(20),
          reason: 'aide de ${e.key}');
      expect([for (final c in lignes[1]) c?.value.toString()], e.value,
          reason: 'en-têtes de ${e.key}');
    }
    // Historique et Courses : seulement l'aide et les en-têtes.
    expect(x.tables['Historique']!.rows.length, 2);
    expect(x.tables['Courses']!.rows.length, 2);
  });

  test('critère 2 : Menu = les produits de l\'événement, Stock = gymnases x produits',
      () {
    final x = Excel.decodeBytes(_modele());
    final menu = x.tables['Menu']!.rows;
    expect([for (final l in menu.skip(2)) l[0]?.value.toString()],
        ['Croque-monsieur', 'Café', 'Gâteau salé', 'Fruit', 'Eau']);
    final stock = x.tables['Stock de départ']!.rows;
    expect(stock.length, 2 + 2 * 5); // 2 gymnases x 5 produits
    expect(stock[2][0]?.value.toString(), 'Gymnase Édith');
    expect(stock[2][1]?.value.toString(), 'Croque-monsieur');
    expect((stock[2][2]?.value as IntCellValue).value, 40);
    // Produit non suivi dans ce gymnase : cellule vide.
    expect(stock[5][1]?.value.toString(), 'Fruit');
    expect(stock[5][2]?.value, isNull);
  });

  test('un gestionnaire partiel n\'obtient que ses gymnases', () {
    final o = construireModele(
        produits: _produits, gymnases: [_gymnases[1]], stocks: _stocks);
    final lu = lireClasseur(o);
    expect({for (final s in lu.stocks) s.gymnase}, {'Gymnase B'});
    expect(lu.stocks.length, 5);
  });

  test('critère 3 : aller-retour exact des produits et des stocks', () {
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

  test('critère 4 : accents conservés, prix et consommations numériques, recette '
      'avec virgule décimale', () {
    final x = Excel.decodeBytes(_modele());
    final menu = x.tables['Menu']!.rows;
    final croque = menu[2];
    expect(croque[0]?.value.toString(), 'Croque-monsieur');
    expect((croque[1]?.value as IntCellValue).value, 3); // 3 € : nombre
    expect(croque[2]?.value.toString(), 'Composé (recette)');
    expect(croque[6]?.value.toString(),
        '2 tranche Pain de mie ; 0,25 tranche Jambon ; 25 g Gruyère râpé ; 1 unité Œuf');
    final gateau = menu[4];
    expect(gateau[0]?.value.toString(), 'Gâteau salé');
    expect((gateau[1]?.value as DoubleCellValue).value, 2.5); // 2,50 € : nombre
    expect(gateau[2]?.value.toString(), 'À la part');
    expect(gateau[3]?.value.toString(), 'Apporté par les bénévoles');
    expect((gateau[5]?.value as IntCellValue).value, 8);
    expect((gateau[7]?.value as DoubleCellValue).value, 0.75);
    expect(menu[5][3]?.value.toString(), 'Acheté par l\'association');
    expect(menu[3][2]?.value.toString(), 'Au litre');
    expect((menu[6][4]?.value as DoubleCellValue).value, 6.5);
  });

  test('lecture tolérante : texte avec virgule, espaces, lignes vides, ordre des '
      'colonnes libre', () {
    final o = _classeur({
      'Menu': _menuAvec([
        ['Pizza', '2,50', 'À l\'unité', 'acheté par l\'association', null, null, null, '1,5'],
        [null, null, null, null, null, null, null, null],
        ['  Thé  ', ' 1 0,5 ', 'au litre', null, '8', null, null, null],
      ]),
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
    expect(lu.produits[1].nom, 'Thé');
    expect(lu.produits[1].prixCentimes, 1050);
    expect(lu.produits[1].fiche.verresParLitre, 8);
    expect(lu.stocks.single.quantite, 1000);
    expect(lu.stocks.single.gymnase, 'Gymnase A');
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
      'Menu': _menuAvec([
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
      'Menu': _menuAvec([]),
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
    expect(nomFichierBilan(ev), 'bilan-tournoi-d-ete-2026-2026-10-03.csv');
    expect(typeMimeClasseur,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  });
}
