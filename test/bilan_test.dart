import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';

// Jeu de ventes dont le bilan a été calculé À LA MAIN :
//
//   Léa (caisse clôturée)
//     L1  sam 03/10 14:05  espèces  2 croque-monsieur              = 6,00
//     L2  sam 03/10 14:40  carte    3 cafés                        = 4,50
//     L3  sam 03/10 15:10  espèces  1 croque-monsieur + 1 café     = 4,50
//     L4  dim 04/10 10:15  chèque   1 gâteau                       = 2,50
//     L5  dim 04/10 14:20  carte    2 sodas (ANNULÉE par Léa 14:25)= 3,00
//   Zoé (caisse ouverte)
//     Z1  sam 03/10 14:55  carte    2 cafés                        = 3,00
//     Z2  dim 04/10 10:50  espèces  2 croque-monsieur              = 6,00
//
//   Total (hors annulée) : 26,50 € en 6 ventes, 1 annulée.
//   Modes : espèces 16,50 · carte 7,50 · chèque 2,50.
//   Produits : café 6 (9,00) · croque-monsieur 5 (15,00) · gâteau 1 (2,50)
//              · salade 0 · soda 0 (la vente annulée ne compte pas).
//   Jours : 03/10 → 4 ventes 18,00 · 04/10 → 2 ventes 8,50.
//   Heures : 10 h → 2 ventes · 14 h → 3 ventes · 15 h → 1 vente.
DateTime _t(int jour, int h, int m) => DateTime(2026, 10, jour, h, m);

Vente _v(String id, List<LigneVente> lignes, String mode, DateTime quand,
    {bool annulee = false, DateTime? annuleeLe, String? par}) {
  return Vente(
    id: id,
    lignes: lignes,
    totalCentimes: lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite),
    mode: mode,
    creeLe: quand,
    enAttente: false,
    annulee: annulee,
    annuleeLe: annuleeLe,
    annuleeParPrenom: par,
  );
}

const _produits = [
  ProduitEvenement('croque', 'Croque-monsieur', 300, 4),
  ProduitEvenement('cafe', 'Café', 150, null),
  ProduitEvenement('salade', 'Salade', 400, null),
  ProduitEvenement('gateau', 'Gâteau', 250, 6),
  ProduitEvenement('soda', 'Soda', 150, null),
];

LigneVente _l(String id, String nom, int prix, int q) =>
    LigneVente(id, nom, prix, q);

TableauDeBord _jeu() {
  const lea = Caisse(uid: 'lea', gymnaseId: 'g1', prenom: 'Lea', statut: 'cloturee');
  const zoe = Caisse(uid: 'zoe', gymnaseId: 'g1', prenom: 'Zoe', statut: 'ouverte');
  return TableauDeBord.depuis([
    ResumeCaisse(lea, [
      _v('L1', [_l('croque', 'Croque-monsieur', 300, 2)], 'especes', _t(3, 14, 5)),
      _v('L2', [_l('cafe', 'Café', 150, 3)], 'carte', _t(3, 14, 40)),
      _v('L3', [
        _l('croque', 'Croque-monsieur', 300, 1),
        _l('cafe', 'Café', 150, 1),
      ], 'especes', _t(3, 15, 10)),
      _v('L4', [_l('gateau', 'Gâteau', 250, 1)], 'cheque', _t(4, 10, 15)),
      _v('L5', [_l('soda', 'Soda', 150, 2)], 'carte', _t(4, 14, 20),
          annulee: true, annuleeLe: _t(4, 14, 25), par: 'Lea'),
    ]),
    ResumeCaisse(zoe, [
      _v('Z1', [_l('cafe', 'Café', 150, 2)], 'carte', _t(3, 14, 55)),
      _v('Z2', [_l('croque', 'Croque-monsieur', 300, 2)], 'especes', _t(4, 10, 50)),
    ]),
  ]);
}

void main() {
  final bilan = Bilan.depuis(_jeu(), _produits, ['especes', 'carte', 'cheque']);

  group('bilan du jeu de ventes calculé à la main', () {
    test('total et nombre de ventes (hors annulée)', () {
      expect(bilan.totalCentimes, 2650);
      expect(bilan.nbVentes, 6);
      expect(bilan.nbAnnulees, 1);
    });

    test('par mode de paiement', () {
      expect(bilan.parMode, {'especes': 1650, 'carte': 750, 'cheque': 250});
      expect(bilan.parMode.values.fold<int>(0, (a, b) => a + b),
          bilan.totalCentimes);
    });

    test('par produit : quantités, montants, stock, ordre', () {
      expect([for (final p in bilan.produits) p.nom],
          ['Café', 'Croque-monsieur', 'Gâteau', 'Salade', 'Soda']);
      expect([for (final p in bilan.produits) p.quantite], [6, 5, 1, 0, 0]);
      expect([for (final p in bilan.produits) p.montantCentimes],
          [900, 1500, 250, 0, 0]);
      expect([for (final p in bilan.produits) p.stock], [null, 4, 6, null, null]);
      // Les montants par produit font bien le total.
      expect(bilan.produits.fold<int>(0, (a, p) => a + p.montantCentimes), 2650);
    });

    test('produits les plus et les moins vendus (jamais les mêmes)', () {
      expect([for (final p in bilan.plusVendus) p.nom], ['Café', 'Croque-monsieur']);
      expect([for (final p in bilan.moinsVendus) p.nom], ['Salade', 'Soda']);
    });

    test('par caisse', () {
      final lea = bilan.caisses.firstWhere((c) => c.id == 'lea__g1');
      final zoe = bilan.caisses.firstWhere((c) => c.id == 'zoe__g1');
      expect((lea.nbVentes, lea.totalCentimes, lea.nbAnnulees, lea.cloturee),
          (4, 1750, 1, true));
      expect((zoe.nbVentes, zoe.totalCentimes, zoe.nbAnnulees, zoe.cloturee),
          (2, 900, 0, false));
      expect(lea.totalCentimes + zoe.totalCentimes, bilan.totalCentimes);
      expect(bilan.caissesNonCloturees, ['Zoe']);
    });

    test('par jour', () {
      expect([for (final j in bilan.jours) j.jour], ['2026-10-03', '2026-10-04']);
      expect([for (final j in bilan.jours) j.nbVentes], [4, 2]);
      expect([for (final j in bilan.jours) j.totalCentimes], [1800, 850]);
    });

    test('heures : tranches d\'une heure, et heures de pointe', () {
      expect([for (final h in bilan.heures) (h.heure, h.nbVentes, h.totalCentimes)],
          [(10, 2, 850), (14, 3, 1350), (15, 1, 450)]);
      expect([for (final h in bilan.heuresDePointe) h.heure], [14, 10, 15]);
      expect(trancheAffichee(14), '14 h–15 h');
    });

    test('annulations listées à part avec leur trace', () {
      expect(bilan.annulations.length, 1);
      final a = bilan.annulations.single;
      expect(a.caissePrenom, 'Lea');
      expect(a.totalCentimes, 300);
      expect(a.mode, 'carte');
      expect(a.parPrenom, 'Lea');
      expect(a.venteLe, _t(4, 14, 20));
      expect(a.annuleeLe, _t(4, 14, 25));
    });
  });

  group('cas limites', () {
    test('événement sans vente : tout à zéro, rien ne plante', () {
      final b = Bilan.depuis(TableauDeBord.depuis(const []), _produits,
          ['especes', 'carte']);
      expect(b.totalCentimes, 0);
      expect(b.nbVentes, 0);
      expect(b.parMode, {'especes': 0, 'carte': 0}); // modes affichés à zéro
      expect(b.produits.every((p) => p.quantite == 0), isTrue);
      expect(b.plusVendus, isEmpty); // rien n'est « le plus vendu »
      expect(b.jours, isEmpty);
      expect(b.heures, isEmpty);
      expect(b.heuresDePointe, isEmpty);
      expect(b.annulations, isEmpty);
    });

    test('un seul produit : ni « plus » ni « moins » vendus', () {
      final b = Bilan.depuis(_jeu(), [_produits.first], ['especes']);
      expect(b.produits.length, 1);
      expect(b.plusVendus, isEmpty);
      expect(b.moinsVendus, isEmpty);
    });

    test('deux produits : un plus vendu, un moins vendu', () {
      final b = Bilan.depuis(_jeu(), [_produits[0], _produits[1]], ['especes']);
      expect([for (final p in b.plusVendus) p.nom], ['Café']);
      expect([for (final p in b.moinsVendus) p.nom], ['Croque-monsieur']);
    });

    test('un mode utilisé mais absent des modes de l\'événement est conservé', () {
      final b = Bilan.depuis(_jeu(), _produits, ['especes']);
      expect(b.parMode.keys.first, 'especes');
      expect(b.parMode['carte'], 750);
      expect(b.parMode['cheque'], 250);
      expect(b.parMode.values.fold<int>(0, (a, c) => a + c), 2650);
    });

    test('égalité d\'heures de pointe : la plus tôt d\'abord', () {
      const c = Caisse(uid: 'a', gymnaseId: 'g1', prenom: 'A', statut: 'ouverte');
      final t = TableauDeBord.depuis([
        ResumeCaisse(c, [
          _v('1', [_l('cafe', 'Café', 150, 1)], 'carte', _t(3, 16, 0)),
          _v('2', [_l('cafe', 'Café', 150, 1)], 'carte', _t(3, 9, 59)),
          _v('3', [_l('cafe', 'Café', 150, 1)], 'carte', _t(4, 16, 30)),
          _v('4', [_l('cafe', 'Café', 150, 1)], 'carte', _t(4, 9, 0)),
          _v('5', [_l('cafe', 'Café', 150, 1)], 'carte', _t(4, 12, 0)),
        ]),
      ]);
      final b = Bilan.depuis(t, _produits, ['carte']);
      expect([for (final h in b.heuresDePointe) (h.heure, h.nbVentes)],
          [(9, 2), (16, 2), (12, 1)]);
    });

    test('minuit : la tranche 23 h finit à 0 h', () {
      expect(trancheAffichee(23), '23 h–0 h');
      expect(trancheAffichee(0), '0 h–1 h');
    });

    test('toutes les ventes annulées : total à zéro, annulations listées', () {
      const c = Caisse(uid: 'a', gymnaseId: 'g1', prenom: 'A', statut: 'ouverte');
      final t = TableauDeBord.depuis([
        ResumeCaisse(c, [
          _v('1', [_l('cafe', 'Café', 150, 1)], 'carte', _t(3, 16, 0),
              annulee: true, annuleeLe: _t(3, 16, 5), par: 'A'),
          _v('2', [_l('cafe', 'Café', 150, 2)], 'carte', _t(3, 17, 0),
              annulee: true, annuleeLe: _t(3, 17, 1), par: 'A'),
        ]),
      ]);
      final b = Bilan.depuis(t, _produits, ['carte']);
      expect(b.totalCentimes, 0);
      expect(b.nbVentes, 0);
      expect(b.nbAnnulees, 2);
      expect(b.annulations.length, 2);
      expect(b.annulations.first.annuleeLe, _t(3, 16, 5)); // ordre chronologique
      expect(b.jours, isEmpty);
    });
  });

  group('écran du bilan', () {
    Evenement evt({
      String statut = 'en_cours',
      bool forcee = false,
      int nbOuvertes = 0,
    }) =>
        Evenement(
          id: 'e',
          nom: 'Tournoi',
          date: '2026-10-03',
          statut: statut,
          modes: const ['especes', 'carte', 'cheque'],
          menuNom: 'Menu',
          clotureLe: statut == 'cloture' ? _t(4, 18, 30) : null,
          clotureParPrenom: statut == 'cloture' ? 'Chef' : null,
          forcee: forcee,
          nbCaissesOuvertes: nbOuvertes,
        );

    Future<void> afficher(WidgetTester tester, Evenement e,
        {TableauDeBord? tableau}) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: e,
          tableau: Stream.value(tableau ?? _jeu()),
          produits: Stream.value(_produits),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    String texte(WidgetTester tester, String cle) =>
        tester.widget<Text>(find.byKey(Key(cle))).data!;

    testWidgets('chiffres affichés = chiffres calculés à la main', (tester) async {
      await afficher(tester, evt());
      expect(texte(tester, 'bilan_etat'), 'Bilan provisoire : événement en cours');
      expect(texte(tester, 'bilan_total'), 'Total : 26,50 € · 6 ventes');
      expect(texte(tester, 'bilan_annulees'), 'Ventes annulées : 1');
      // Par produit
      expect(texte(tester, 'bilan_produit_cafe'), 'Café : 6 vendus · 9,00 €');
      expect(texte(tester, 'bilan_produit_croque'),
          'Croque-monsieur : 5 vendus · 15,00 € · stock 4');
      expect(texte(tester, 'bilan_produit_gateau'),
          'Gâteau : 1 vendu · 2,50 € · stock 6');
      expect(texte(tester, 'bilan_produit_salade'), 'Salade : 0 vendu · 0,00 €');
      expect(texte(tester, 'bilan_produit_soda'), 'Soda : 0 vendu · 0,00 €');
      // Plus / moins vendus
      expect(texte(tester, 'plus_1'), '1. Café (6)');
      expect(texte(tester, 'plus_2'), '2. Croque-monsieur (5)');
      expect(texte(tester, 'moins_1'), '1. Salade (0)');
      expect(texte(tester, 'moins_2'), '2. Soda (0)');
      // Par mode
      expect(texte(tester, 'bilan_mode_especes'), 'Espèces : 16,50 €');
      expect(texte(tester, 'bilan_mode_carte'), 'Carte : 7,50 €');
      expect(texte(tester, 'bilan_mode_cheque'), 'Chèque : 2,50 €');
      // Par caisse
      expect(texte(tester, 'bilan_caisse_lea__g1'),
          'Lea : 4 ventes · 17,50 € · Clôturée · 1 annulée');
      expect(texte(tester, 'bilan_caisse_zoe__g1'),
          'Zoe : 2 ventes · 9,00 € · Ouverte');
      // Par jour
      expect(texte(tester, 'bilan_jour_2026-10-03'),
          '03/10/2026 : 4 ventes · 18,00 €');
      expect(texte(tester, 'bilan_jour_2026-10-04'),
          '04/10/2026 : 2 ventes · 8,50 €');
      // Heures de pointe
      expect(texte(tester, 'pointe_1'), '14 h–15 h : 3 ventes');
      expect(texte(tester, 'pointe_2'), '10 h–11 h : 2 ventes');
      expect(texte(tester, 'pointe_3'), '15 h–16 h : 1 vente');
      // Annulation tracée
      expect(texte(tester, 'annulation_0'),
          'Lea · 14:20 · 3,00 € (Carte) — annulée par Lea à 14:25');
      // En cours : la caisse non clôturée est signalée, pas de bandeau « forcée ».
      expect(texte(tester, 'bilan_caisses_ouvertes'),
          '1 caisse pas encore clôturée : Zoe');
      expect(find.byKey(const Key('bilan_forcee')), findsNothing);
    });

    testWidgets('clôture forcée : le bilan le dit clairement', (tester) async {
      await afficher(tester, evt(statut: 'cloture', forcee: true, nbOuvertes: 1));
      expect(texte(tester, 'bilan_etat'), 'Bilan définitif : événement clôturé');
      expect(
          texte(tester, 'bilan_forcee'),
          'Clôture forcée par Chef le 04/10/2026 à 18:30 : 1 caisse non '
          'clôturée (Zoe). Des ventes peuvent manquer.');
      expect(find.byKey(const Key('bilan_caisses_ouvertes')), findsNothing);
      // Les chiffres sont les mêmes.
      expect(texte(tester, 'bilan_total'), 'Total : 26,50 € · 6 ventes');
    });

    testWidgets('clôture normale : ni bandeau de clôture forcée, ni caisse ouverte',
        (tester) async {
      const lea = Caisse(uid: 'lea', gymnaseId: 'g1', prenom: 'Lea', statut: 'cloturee');
      final tab = TableauDeBord.depuis([
        ResumeCaisse(lea, [
          _v('L1', [_l('cafe', 'Café', 150, 2)], 'carte', _t(3, 14, 5)),
        ]),
      ]);
      await afficher(tester, evt(statut: 'cloture'), tableau: tab);
      expect(texte(tester, 'bilan_etat'), 'Bilan définitif : événement clôturé');
      expect(find.byKey(const Key('bilan_forcee')), findsNothing);
      expect(find.byKey(const Key('bilan_caisses_ouvertes')), findsNothing);
      expect(texte(tester, 'bilan_total'), 'Total : 3,00 € · 1 vente');
      expect(find.byKey(const Key('bilan_annulees')), findsNothing);
      expect(find.byKey(const Key('annulation_0')), findsNothing);
    });

    testWidgets('événement sans vente', (tester) async {
      await afficher(tester, evt(), tableau: TableauDeBord.depuis(const []));
      expect(texte(tester, 'bilan_total'), 'Total : 0,00 € · 0 vente');
      expect(find.byKey(const Key('bilan_aucune_caisse')), findsOneWidget);
      expect(find.byKey(const Key('bilan_aucun_jour')), findsOneWidget);
      expect(find.byKey(const Key('bilan_aucune_pointe')), findsOneWidget);
      expect(find.byKey(const Key('plus_1')), findsNothing);
      expect(texte(tester, 'bilan_mode_especes'), 'Espèces : 0,00 €');
    });
  });
}
