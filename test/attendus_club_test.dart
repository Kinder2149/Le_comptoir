import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import '../integration_test/attendus_club.dart';

// Simulation V7 : logique de comparaison du parcours (attendus de la preuve 1, sommes et
// comparaison du bilan de la preuve 4). Aucun émulateur : le parcours utilise ces mêmes
// fonctions avec les données relues depuis la base.

const _ids = {'Gymnase 1': 'g1', 'Gymnase 2': 'g2'};

Map<int, double> _p(double a, [double? b]) => {1: a, 2: ?b};

CalculClub _calculDuClub() {
  RepasGymnaseJour r(int j, int b1, int b2) => RepasGymnaseJour(
      joueusesMidi: j, joueusesSoir: j, benevolesMidi: b1, benevolesSoir: b2);
  return CalculClub(
    repas: {
      'g1': {1: r(49, 10, 11), 2: r(56, 9, 9)},
      'g2': {1: r(63, 7, 8), 2: r(56, 6, 3)},
    },
    groupes: [
      GroupeConso(nom: 'Plat', pourcentages: _p(.7, .8), produits: {
        'Croque-monsieur': _p(.4, .35),
        'Croque végé': _p(.25, .3),
        'Croque tartiflette': _p(.35, .35),
      }),
      GroupeConso(nom: 'Dessert', pourcentages: _p(1.1, 1.0), produits: {
        'Crêpe sucre': _p(.25, .25),
        'Crêpe Nutella': _p(.5, .45),
        'Croque Monsieur Chocolat': _p(.25, .3),
      }),
      GroupeConso(nom: 'Barres', pourcentages: _p(.2, .25), produits: {
        'Mars': _p(.15, .15),
        'Twix': _p(.15, .15),
        'Barre de céréales chocolat': _p(.35, .35),
        'Barre de céréales fruit': _p(.35, .35),
      }),
      GroupeConso(nom: 'Boissons froides', pourcentages: _p(1.5, 1.5), produits: {
        'Coca': _p(.45, .45),
        'Ice Tea': _p(.2, .2),
        'Orangina': _p(.1, .1),
        'Oasis': _p(.25, .25),
      }),
      GroupeConso(nom: 'Boissons chaudes', pourcentages: _p(1.1, 1.5), produits: {
        'Thé': _p(.3, .25),
        'Infusion': _p(.1, .05),
        'Café': _p(.6, .7),
      }),
      GroupeConso(nom: 'Boissons alcoolisées', pourcentages: _p(.3), produits: {
        'Bière': {1: 1.0},
      }),
    ],
  );
}

Map<String, String> get _produits => {for (final n in attendusClub.keys) n: n};

void main() {
  test('les attendus : 18 produits, 4 valeurs (2 pour la bière), valeurs du cadrage', () {
    expect(attendusClub.length, 18);
    for (final e in attendusClub.entries) {
      expect(e.value.length, e.key == 'Bière' ? 2 : 4, reason: e.key);
    }
    expect(attendusClub['Croque-monsieur']!['Gymnase 1|1'], 33.32);
    expect(attendusClub['Croque-monsieur']!['Gymnase 1|2'], 36.4);
    expect(attenduClub('Bière', 'Gymnase 1', 2), 0.0); // absent = 0
  });

  test('preuve 1 : le calcul du club retrouve tous les attendus, jour par jour et au total', () {
    final ecarts = comparerAttendus(
        calcul: _calculDuClub(), idProduit: _produits, idGymnase: _ids);
    expect(ecarts, isEmpty, reason: ecarts.join('\n'));
    // Total d'un gymnase : un seul arrondi (33,32 + 36,4 = 69,72 -> 70).
    expect(quantiteClub(_calculDuClub(), 'g1', 'Croque-monsieur'), 70);
  });

  test('preuve 1 : un écart est listé avec produit, gymnase, jour, attendu et vu', () {
    final calcul = _calculDuClub();
    final faux = CalculClub(repas: calcul.repas, groupes: [
      for (final g in calcul.groupes)
        g.nom == 'Plat' ? groupeAvecPart(g, 'Croque végé', 2, 0.35) : g,
    ]);
    final ecarts =
        comparerAttendus(calcul: faux, idProduit: _produits, idGymnase: _ids);
    final jour2 = ecarts.where((e) => e.produit == 'Croque végé' && e.jour == 2).toList();
    expect(jour2.map((e) => e.gymnase), ['Gymnase 1', 'Gymnase 2']);
    expect(jour2.first.attendu, 31.2);
    expect(jour2.first.vu, closeTo(130 * 0.8 * 0.35, 1e-9));
    expect(ecarts.where((e) => e.produit != 'Croque végé'), isEmpty);
    // Un produit absent de l'événement est un écart, jamais ignoré.
    final sans = comparerAttendus(
        calcul: calcul,
        idProduit: {..._produits}..remove('Mars'),
        idGymnase: _ids);
    expect(sans.where((e) => e.produit == 'Mars').length, 6);
  });

  test('arrondi de la preuve : unité supérieure, sans faux +1 sur un entier', () {
    expect(arrondiClub(20.825), 21);
    expect(arrondiClub(39.000000000000004), 39);
    expect(arrondiClub(0), 0);
    expect(arrondiClub(136.5), 137);
  });

  // ----- Preuve 4 : sommes faites à part et comparées au Bilan.
  LigneVente l(String id, int prix, int q) => LigneVente(id, id, prix, q);
  Vente v(String id, List<LigneVente> lignes, String mode, DateTime quand,
          {bool annulee = false}) =>
      Vente(
        id: id,
        lignes: lignes,
        totalCentimes: lignes.fold<int>(0, (s, x) => s + x.prixCentimes * x.quantite),
        mode: mode,
        creeLe: quand,
        enAttente: false,
        annulee: annulee,
      );
  VenteSimulee s(String caisse, String g, String date, String mode,
          List<LigneVente> lignes, {bool annulee = false}) =>
      VenteSimulee(
          caisseId: caisse,
          gymnaseId: g,
          date: date,
          mode: mode,
          lignes: lignes,
          annulee: annulee);

  final caLea = idCaisse('lea', 'g1');
  final caTom = idCaisse('tom', 'g2');
  final d1 = DateTime(2026, 11, 14, 11, 5);
  final d2 = DateTime(2026, 11, 15, 15, 30);

  final simulees = [
    s(caLea, 'g1', '2026-11-14', 'especes', [l('a', 150, 3), l('b', 250, 1)]),
    s(caLea, 'g1', '2026-11-15', 'carte', [l('a', 150, 2)]),
    s(caTom, 'g2', '2026-11-14', 'cheque', [l('b', 250, 4)]),
    s(caTom, 'g2', '2026-11-15', 'especes', [l('a', 150, 1)], annulee: true),
  ];

  TableauDeBord tableau() => TableauDeBord.depuis([
        ResumeCaisse(
            const Caisse(uid: 'lea', gymnaseId: 'g1', prenom: 'Lea', statut: 'cloturee'), [
          v('1', [l('a', 150, 3), l('b', 250, 1)], 'especes', d1),
          v('2', [l('a', 150, 2)], 'carte', d2),
        ]),
        ResumeCaisse(
            const Caisse(uid: 'tom', gymnaseId: 'g2', prenom: 'Tom', statut: 'ouverte'), [
          v('3', [l('b', 250, 4)], 'cheque', d1),
          v('4', [l('a', 150, 1)], 'especes', d2, annulee: true),
        ]),
      ]);
  const produits = [
    ProduitEvenement('a', 'A', 150, null),
    ProduitEvenement('b', 'B', 250, null),
    ProduitEvenement('c', 'C', 100, null),
  ];
  final modes = ['especes', 'carte', 'cheque'];

  test('preuve 4 : les sommes faites à part égalent le Bilan', () {
    final somme = SommesVentes(simulees);
    expect(somme.nbVentes, 3);
    expect(somme.nbAnnulees, 1);
    expect(somme.totalCentimes, 700 + 300 + 1000);
    expect(somme.parMode, {'especes': 700, 'carte': 300, 'cheque': 1000});
    expect(somme.parJour['2026-11-14'], [2, 1700]);
    expect(somme.parProduit['a'], [5, 750]);
    final bilan = Bilan.depuis(tableau(), produits, modes);
    expect(comparerBilan(somme, bilan), isEmpty);
  });

  test('preuve 4 : une vente de trop ou un mode faux est signalé', () {
    final bilan = Bilan.depuis(tableau(), produits, modes);
    final enTrop = SommesVentes([
      ...simulees,
      s(caLea, 'g1', '2026-11-15', 'carte', [l('c', 100, 1)]),
    ]);
    final r = comparerBilan(enTrop, bilan);
    expect(r, contains('total : attendu 2100, vu 2000'));
    expect(r.any((x) => x.startsWith('mode carte')), isTrue);
    expect(r.any((x) => x.startsWith('produit c')), isTrue);
    final mode = SommesVentes([
      s(caLea, 'g1', '2026-11-14', 'carte', [l('a', 150, 3), l('b', 250, 1)]),
      ...simulees.skip(1),
    ]);
    final r2 = comparerBilan(mode, bilan);
    expect(r2.any((x) => x.startsWith('mode especes')), isTrue);
    expect(r2.any((x) => x.startsWith('total')), isFalse);
  });

  test('le résultat est juste au centime : ventes moins coût, en entiers', () {
    final somme = SommesVentes(simulees);
    const cout = 31250 + 18075;
    expect(somme.totalCentimes - cout, 2000 - 49325);
  });
}
