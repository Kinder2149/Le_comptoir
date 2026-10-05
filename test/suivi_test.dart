import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/evenement.dart';

final _maintenant = DateTime(2026, 10, 3, 18, 0);

Caisse _caisse(String uid, String prenom,
        {bool cloturee = false, DateTime? ouverteLe, DateTime? rouverteLe}) =>
    Caisse(
      uid: uid,
      gymnaseId: 'g1',
      prenom: prenom,
      statut: cloturee ? 'cloturee' : 'ouverte',
      ouverteLe: ouverteLe,
      rouverteLe: rouverteLe,
    );

Vente _vente(String id, List<LigneVente> lignes, String mode, DateTime quand,
    {bool annulee = false, DateTime? annuleeLe}) {
  final total = lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite);
  return Vente(
    id: id,
    lignes: lignes,
    totalCentimes: total,
    mode: mode,
    creeLe: quand,
    enAttente: false,
    annulee: annulee,
    annuleeLe: annuleeLe,
  );
}

const _croque = LigneVente('croque', 'Croque-monsieur', 300, 2);
const _cafe = LigneVente('cafe', 'Café', 150, 1);
const _cafe2 = LigneVente('cafe', 'Café', 150, 2);

DateTime _avant(int minutes) => _maintenant.subtract(Duration(minutes: minutes));

void main() {
  group('tableau de bord', () {
    test('totaux, quantités par produit et par mode ; annulées exclues', () {
      final t = TableauDeBord.depuis([
        ResumeCaisse(_caisse('lea', 'Lea', ouverteLe: _avant(200)), [
          _vente('a', [_croque], 'especes', _avant(30)),
          _vente('b', [_cafe], 'carte', _avant(20), annulee: true),
        ]),
        ResumeCaisse(_caisse('zoe', 'Zoe', cloturee: true, ouverteLe: _avant(300)), [
          _vente('c', [_cafe2], 'carte', _avant(90)),
        ]),
      ]);
      expect(t.nbVentes, 2);
      expect(t.nbAnnulees, 1);
      expect(t.totalCentimes, 900); // 600 + 300, la vente annulée ne compte pas
      expect(t.parMode, {'especes': 600, 'carte': 300});
      expect(t.vendus('croque'), 2);
      expect(t.vendus('cafe'), 2); // 2 cafés de Zoe ; celui annulé de Léa exclu
      expect(t.vendus('inconnu'), 0);
      expect(t.parProduit['croque']!.montantCentimes, 600);
      expect(t.parProduit['croque']!.nom, 'Croque-monsieur');
    });

    test('événement sans caisse', () {
      final t = TableauDeBord.depuis(const []);
      expect(t.nbVentes, 0);
      expect(t.totalCentimes, 0);
      expect(t.parProduit, isEmpty);
      expect(t.caisses, isEmpty);
    });
  });

  group('caisse silencieuse (60 minutes)', () {
    bool silencieuse(ResumeCaisse r) => r.silencieuse(_maintenant);

    test('le seuil est de 60 minutes, pas moins', () {
      expect(seuilSilence, const Duration(minutes: 60));
      final c = _caisse('l', 'Lea', ouverteLe: _avant(500));
      expect(silencieuse(ResumeCaisse(c, [_vente('a', [_cafe], 'carte', _avant(59))])), isFalse);
      expect(silencieuse(ResumeCaisse(c, [_vente('a', [_cafe], 'carte', _avant(60))])), isTrue);
      expect(silencieuse(ResumeCaisse(c, [_vente('a', [_cafe], 'carte', _avant(61))])), isTrue);
      expect(silencieuse(ResumeCaisse(c, [_vente('a', [_cafe], 'carte', _avant(15))])), isFalse);
    });

    test('seule la dernière vente compte', () {
      final c = _caisse('l', 'Lea', ouverteLe: _avant(500));
      expect(
          silencieuse(ResumeCaisse(c, [
            _vente('a', [_cafe], 'carte', _avant(200)),
            _vente('b', [_cafe], 'carte', _avant(10)),
          ])),
          isFalse);
    });

    test('sans vente : on part de l\'ouverture de la caisse', () {
      expect(silencieuse(ResumeCaisse(_caisse('l', 'Lea', ouverteLe: _avant(45)), const [])), isFalse);
      expect(silencieuse(ResumeCaisse(_caisse('l', 'Lea', ouverteLe: _avant(75)), const [])), isTrue);
      // Aucune date connue : on ne signale rien.
      expect(silencieuse(ResumeCaisse(_caisse('l', 'Lea'), const [])), isFalse);
    });

    test('une réouverture ou une annulation récente sont de l\'activité', () {
      final ancienne = [_vente('a', [_cafe], 'carte', _avant(300))];
      expect(
          silencieuse(ResumeCaisse(
              _caisse('l', 'Lea', ouverteLe: _avant(400), rouverteLe: _avant(20)),
              ancienne)),
          isFalse);
      expect(
          silencieuse(ResumeCaisse(_caisse('l', 'Lea', ouverteLe: _avant(400)), [
            _vente('a', [_cafe], 'carte', _avant(300),
                annulee: true, annuleeLe: _avant(5)),
          ])),
          isFalse);
    });

    test('une caisse clôturée n\'est jamais signalée', () {
      final c = _caisse('l', 'Lea', cloturee: true, ouverteLe: _avant(900));
      expect(silencieuse(ResumeCaisse(c, [_vente('a', [_cafe], 'carte', _avant(800))])), isFalse);
    });

    test('dernière vente : null s\'il n\'y en a pas', () {
      expect(ResumeCaisse(_caisse('l', 'Lea'), const []).derniereVente, isNull);
      final r = ResumeCaisse(_caisse('l', 'Lea'), [
        _vente('a', [_cafe], 'carte', _avant(50)),
        _vente('b', [_cafe], 'carte', _avant(10)),
      ]);
      expect(r.derniereVente, _avant(10));
    });
  });

  test('durée affichée', () {
    expect(dureeAffichee(Duration.zero), '0 min');
    expect(dureeAffichee(const Duration(minutes: 59)), '59 min');
    expect(dureeAffichee(const Duration(minutes: 60)), '1 h');
    expect(dureeAffichee(const Duration(minutes: 65)), '1 h 05');
    expect(dureeAffichee(const Duration(minutes: 80)), '1 h 20');
    expect(dureeAffichee(const Duration(hours: 2)), '2 h');
    expect(dureeAffichee(const Duration(hours: 10)), '10 h');
  });

  group('écran de suivi en direct', () {
    Future<void> afficher(
      WidgetTester tester,
      TableauDeBord tableau, {
      List<ProduitEvenement> produits = const [],
      void Function(Caisse)? onOuvrir,
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuiviEnDirect(
              tableau: Stream.value(tableau),
              produits: Stream.value(produits),
              onOuvrirCaisse: onOuvrir ?? (_) {},
              maintenant: () => _maintenant,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    String texte(WidgetTester tester, String cle) =>
        tester.widget<Text>(find.byKey(Key(cle))).data!;

    testWidgets('totaux, produits avec stock, caisses et dernière vente',
        (tester) async {
      final lea = _caisse('lea', 'Lea', ouverteLe: _avant(200));
      final zoe = _caisse('zoe', 'Zoe', cloturee: true, ouverteLe: _avant(300));
      await afficher(
        tester,
        TableauDeBord.depuis([
          ResumeCaisse(lea, [
            _vente('a', [_croque], 'especes', DateTime(2026, 10, 3, 17, 40)),
          ]),
          ResumeCaisse(zoe, [
            _vente('c', [_cafe2], 'carte', DateTime(2026, 10, 3, 16, 5)),
          ]),
        ]),
        produits: const [
          ProduitEvenement('croque', 'Croque-monsieur', 300, 8),
          ProduitEvenement('cafe', 'Café', 150, null),
          ProduitEvenement('rare', 'Rareté', 500, 3),
        ],
      );
      expect(texte(tester, 'direct_total'), 'Ventes : 2 · 9,00 €');
      expect(find.byKey(const Key('direct_annulees')), findsNothing);
      expect(texte(tester, 'direct_produit_croque'),
          'Croque-monsieur : 2 vendus · stock 8');
      expect(texte(tester, 'direct_produit_cafe'), 'Café : 2 vendus');
      expect(texte(tester, 'direct_produit_rare'),
          'Rareté : 0 vendu · stock 3');
      expect(texte(tester, 'statut_caisse_lea__g1'), 'Ouverte · 1 vente · 6,00 €');
      expect(texte(tester, 'statut_caisse_zoe__g1'), 'Clôturée · 1 vente · 3,00 €');
      expect(texte(tester, 'activite_lea__g1'), 'Dernière vente à 17:40');
      expect(texte(tester, 'activite_zoe__g1'), 'Dernière vente à 16:05');
      expect(find.byKey(const Key('silence_lea__g1')), findsNothing); // 20 min
      expect(find.byKey(const Key('silence_zoe__g1')), findsNothing); // clôturée
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('une caisse ouverte sans vente depuis 60 min est signalée',
        (tester) async {
      final lea = _caisse('lea', 'Lea', ouverteLe: _avant(200));
      final zoe = _caisse('zoe', 'Zoe', ouverteLe: _avant(200));
      final max = _caisse('max', 'Max', ouverteLe: _avant(10));
      await afficher(
        tester,
        TableauDeBord.depuis([
          ResumeCaisse(lea, [_vente('a', [_cafe], 'carte', _avant(80))]),
          ResumeCaisse(zoe, [_vente('b', [_cafe], 'carte', _avant(59))]),
          ResumeCaisse(max, const []),
        ]),
      );
      expect(texte(tester, 'silence_lea__g1'), 'Pas de vente depuis 1 h 20');
      expect(find.byKey(const Key('silence_zoe__g1')), findsNothing); // 59 min
      expect(find.byKey(const Key('silence_max__g1')), findsNothing); // ouverte il y a 10 min
      expect(texte(tester, 'activite_max__g1'), 'Aucune vente');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ventes annulées signalées, caisse touchée = callback',
        (tester) async {
      Caisse? ouverte;
      final lea = _caisse('lea', 'Lea', ouverteLe: _avant(20));
      await afficher(
        tester,
        TableauDeBord.depuis([
          ResumeCaisse(lea, [
            _vente('a', [_cafe], 'carte', _avant(10)),
            _vente('b', [_cafe], 'carte', _avant(5), annulee: true),
          ]),
        ]),
        onOuvrir: (c) => ouverte = c,
      );
      expect(texte(tester, 'direct_total'), 'Ventes : 1 · 1,50 €');
      expect(texte(tester, 'direct_annulees'), 'Ventes annulées : 1');
      await tester.tap(find.byKey(const Key('caisse_lea__g1')));
      expect(ouverte?.uid, 'lea');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('aucune caisse ouverte', (tester) async {
      await afficher(tester, TableauDeBord.depuis(const []));
      expect(find.byKey(const Key('aucune_caisse')), findsOneWidget);
      expect(texte(tester, 'direct_total'), 'Ventes : 0 · 0,00 €');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group("défilement de l'écran de l'événement", () {
    testWidgets("le suivi sort de l'écran puis revient : il se rebranche sans planter",
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final tableau = TableauDeBord.depuis([
        ResumeCaisse(_caisse('lea', 'Lea', ouverteLe: _avant(20)), [
          _vente('a', [_cafe], 'carte', _avant(10)),
        ]),
      ]);
      var ecoutes = 0;
      late final StreamController<TableauDeBord> flux;
      // Comme le vrai flux : réécoutable, il réémet l'état courant à chaque écoute.
      flux = StreamController<TableauDeBord>.broadcast(onListen: () {
        ecoutes++;
        scheduleMicrotask(() => flux.add(tableau));
      });
      addTearDown(flux.close);
      late final StreamController<List<ProduitEvenement>> produits;
      produits = StreamController<List<ProduitEvenement>>.broadcast(
          onListen: () => scheduleMicrotask(() => produits.add(const [])));
      addTearDown(produits.close);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SuiviEnDirect(
                tableau: flux.stream,
                produits: produits.stream,
                onOuvrirCaisse: (_) {},
                maintenant: () => _maintenant,
              ),
              for (var i = 0; i < 60; i++) ListTile(title: Text('Ligne $i')),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('direct_total')), findsOneWidget);
      expect(ecoutes, 1);
      // On descend très bas : le suivi est retiré de l'écran (liste paresseuse)...
      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pump();
      expect(find.byKey(const Key('direct_total')), findsNothing);
      // ... puis on remonte : il revient, se rebranche, et affiche de nouveau les chiffres.
      await tester.drag(find.byType(ListView), const Offset(0, 6000));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('direct_total')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('direct_total'))).data,
          'Ventes : 1 · 1,50 €');
      expect(ecoutes, 2);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
