import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_stock_depart.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/theme.dart';

// Mission « Ergonomie de la gestion », étape E4 : l'écran « Stock de départ ».
// Critères : (1) 24 cocas par + puis au clavier ; (2) l'onglet compte les produits
// renseignés ; (3) « Copier vers » recopie sans toucher un produit déjà compté ;
// (4) un reste repris est marqué « Repris » ; (5) pas d'ingrédient, fait maison replié
// avec « Apporté le jour même ».

Evenement _ev(String statut) => Evenement(
    id: 'e',
    nom: 'Tournoi',
    date: '2026-10-03',
    statut: statut,
    modes: const ['carte'],
    menuNom: 'M',
    nbJours: 3);

const _gymnases = [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B')];

// Produits finis seulement : les ingrédients d'une recette ne sont jamais dans cette liste.
const _produits = [
  ProduitEvenement('coca', 'Coca', 200, null,
      fiche: FicheProduit(type: 'litre', famille: 'boissons_fraiches')),
  ProduitEvenement('fanta', 'Fanta', 200, null,
      fiche: FicheProduit(type: 'litre', famille: 'boissons_fraiches')),
  ProduitEvenement('croque', 'Croque', 300, null,
      fiche: FicheProduit(type: 'unite', famille: 'croques')),
  ProduitEvenement('gateau', 'Gâteau salé', 500, null,
      fiche: FicheProduit(type: 'part', famille: 'fait_maison', provenance: 'apporte')),
];

/// Stock tenu en mémoire : chaque écriture met à jour le flux, comme Firestore.
class _Faux {
  _Faux([Map<String, Map<String, StockDepart>>? depart]) : stock = depart ?? {};

  Map<String, Map<String, StockDepart>> stock;
  final ecrits = <(String, String, int)>[];
  final _ctrl = StreamController<Map<String, Map<String, StockDepart>>>.broadcast();
  Object? echec;

  Map<String, Map<String, StockDepart>> _copie() => {
        for (final g in stock.entries) g.key: Map.of(g.value),
      };

  Stream<Map<String, Map<String, StockDepart>>> get stocks =>
      Stream.multi((c) {
        c.add(_copie());
        final sub = _ctrl.stream.listen(c.add);
        c.onCancel = () => sub.cancel();
      });

  Future<void> definir(String g, String p, int q) async {
    if (echec != null) throw echec!;
    ecrits.add((g, p, q));
    stock = {
      ...stock,
      g: {...(stock[g] ?? {}), p: StockDepart(q)},
    };
    _ctrl.add(_copie());
  }
}

Widget _ecran(
  _Faux f, {
  String statut = 'en_preparation',
  PorteeGestion? portee,
  VoidCallback? voirGymnases,
}) =>
    EcranStockDepart(
      evenement: Stream.value(_ev(statut)),
      portee: portee ?? const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
      gymnases: Stream.value(_gymnases),
      produits: Stream.value(_produits),
      stocks: f.stocks,
      definirStock: f.definir,
      onVoirGymnases: voirGymnases ?? () {},
    );

Future<void> _afficher(
  WidgetTester tester,
  _Faux f, {
  String statut = 'en_preparation',
  PorteeGestion? portee,
  VoidCallback? voirGymnases,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeComptoir(),
    home: _ecran(f, statut: statut, portee: portee, voirGymnases: voirGymnases),
  ));
  await tester.pump();
  await tester.pump();
}

/// Déplie une famille (repliée au départ).
Future<void> _deplier(WidgetTester tester, String famille) async {
  await tester.tap(find.byKey(Key('entete_famille_$famille')));
  await tester.pump();
}

String _champ(WidgetTester tester, String cle) =>
    tester.widget<TextField>(find.byKey(Key(cle))).controller!.text;

void main() {
  testWidgets('critère 1 : 24 cocas, 12 par + puis 12 au clavier, enregistrés à 24',
      (tester) async {
    final f = _Faux();
    await _afficher(tester, f);
    await _deplier(tester, 'boissons_fraiches');
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(const Key('plus_gA_coca')));
      await tester.pump();
    }
    expect(_champ(tester, 'depart_gA_coca'), '12');
    expect(f.ecrits.last, ('gA', 'coca', 12));
    // Les 12 suivants au clavier : on remplace par 24 et on valide.
    await tester.enterText(find.byKey(const Key('depart_gA_coca')), '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(f.ecrits.last, ('gA', 'coca', 24));
    expect(f.stock['gA']!['coca']!.quantite, 24);
    expect(_champ(tester, 'depart_gA_coca'), '24');
  });

  testWidgets('critère 1 : − descend d\'un cran ; sous zéro, rien n\'est écrit',
      (tester) async {
    final f = _Faux({'gA': {'coca': const StockDepart(1)}});
    await _afficher(tester, f);
    await _deplier(tester, 'boissons_fraiches');
    await tester.tap(find.byKey(const Key('moins_gA_coca')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('moins_gA_coca')));
    await tester.pump();
    expect(f.ecrits, [('gA', 'coca', 0)]);
    expect(_champ(tester, 'depart_gA_coca'), '0');
  });

  testWidgets('critère 2 : chaque onglet compte les produits renseignés', (tester) async {
    final f = _Faux({
      'gA': {'coca': const StockDepart(0), 'croque': const StockDepart(3)},
      'gB': {},
    });
    await _afficher(tester, f);
    expect(find.byKey(const Key('onglet_gymnase_gA')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('onglet_gymnase_gA'))).child,
        isA<Text>().having((t) => t.data, 'texte', 'Gymnase A · 2'));
    await tester.tap(find.byKey(const Key('onglet_gymnase_gB')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('onglet_gymnase_gB'))).child,
        isA<Text>().having((t) => t.data, 'texte', 'Gymnase B · 0'));
    // Un produit non compté ne compte pas.
    expect(find.byKey(const Key('depart_gB_coca')), findsNothing);
  });

  testWidgets('critère 3 : « Copier vers » après confirmation, sans toucher un produit déjà compté',
      (tester) async {
    final f = _Faux({
      'gA': {
        'coca': const StockDepart(24),
        'fanta': const StockDepart(16),
        'croque': const StockDepart(5),
      },
      'gB': {'fanta': const StockDepart(7)},
    });
    await _afficher(tester, f);
    expect(find.text('Copier vers Gymnase B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('copier_stock_depart')));
    await tester.pumpAndSettle();
    // Rien n'est écrit avant la confirmation.
    expect(f.ecrits, isEmpty);
    await tester.tap(find.byKey(const Key('confirmer_copie_stock')));
    await tester.pumpAndSettle();
    expect(f.ecrits, [('gB', 'coca', 24), ('gB', 'croque', 5)]);
    expect(f.stock['gB']!['fanta']!.quantite, 7);
    expect(f.stock['gB']!['coca']!.quantite, 24);
    expect(f.stock['gB']!['croque']!.quantite, 5);
  });

  testWidgets('critère 3 : annuler la copie n\'écrit rien', (tester) async {
    final f = _Faux({'gA': {'coca': const StockDepart(24)}});
    await _afficher(tester, f);
    await tester.tap(find.byKey(const Key('copier_stock_depart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('annuler_copie_stock')));
    await tester.pumpAndSettle();
    expect(f.ecrits, isEmpty);
  });

  testWidgets('critère 3 : à plusieurs autres gymnases, on choisit la cible', (tester) async {
    const trois = [
      Gymnase('gA', 'Gymnase A', 40),
      Gymnase('gB', 'Gymnase B'),
      Gymnase('gC', 'Gymnase C'),
    ];
    final f = _Faux({'gA': {'croque': const StockDepart(4)}});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: themeComptoir(),
      home: EcranStockDepart(
        evenement: Stream.value(_ev('en_preparation')),
        portee: const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 3),
        gymnases: Stream.value(trois),
        produits: Stream.value(_produits),
        stocks: f.stocks,
        definirStock: f.definir,
        onVoirGymnases: () {},
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('copier_stock_depart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choix_copie_gC')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmer_copie_stock')));
    await tester.pumpAndSettle();
    expect(f.ecrits, [('gC', 'croque', 4)]);
  });

  testWidgets('critère 4 : un reste repris est marqué « Repris », pas un stock compté à la main',
      (tester) async {
    final f = _Faux({
      'gA': {
        'coca': const StockDepart(6, repris: true),
        'fanta': const StockDepart(2),
      },
    });
    await _afficher(tester, f);
    await _deplier(tester, 'boissons_fraiches');
    expect(find.text('Repris'), findsOneWidget);
    expect(find.byKey(const Key('repris_gA_coca')), findsOneWidget);
    expect(find.byKey(const Key('repris_gA_fanta')), findsNothing);
    // Corriger le chiffre efface la marque (l'écriture remplace le stock).
    await tester.tap(find.byKey(const Key('plus_gA_coca')));
    await tester.pump();
    expect(find.byKey(const Key('repris_gA_coca')), findsNothing);
  });

  testWidgets('critère 5 : fait maison replié avec « Apporté le jour même » ; seuls les produits sont listés',
      (tester) async {
    final f = _Faux();
    await _afficher(tester, f);
    expect(find.text('Apporté le jour même'), findsOneWidget);
    expect(find.byKey(const Key('mention_famille_fait_maison')), findsOneWidget);
    // Replié : le gâteau n'apparaît qu'une fois la famille dépliée.
    expect(find.byKey(const Key('ligne_depart_gA_gateau')), findsNothing);
    await _deplier(tester, 'fait_maison');
    expect(find.byKey(const Key('ligne_depart_gA_gateau')), findsOneWidget);
    // Les familles sans produit sont masquées ; aucun ingrédient dans la liste.
    expect(find.byKey(const Key('entete_famille_autre')), findsNothing);
    expect(find.text('Farine'), findsNothing);
  });

  testWidgets('compteur de famille : « n sur N comptés »', (tester) async {
    final f = _Faux({'gA': {'coca': const StockDepart(3)}});
    await _afficher(tester, f);
    expect(
        tester
            .widget<Text>(find.byKey(const Key('compteur_famille_boissons_fraiches')))
            .data,
        '1 sur 2 comptés');
  });

  testWidgets('un gestionnaire ne voit que ses gymnases, sans copie', (tester) async {
    final f = _Faux();
    await _afficher(tester, f,
        portee: const PorteeGestion(responsable: false, gymnases: {'gB'}, nbGymnases: 2));
    expect(find.byKey(const Key('onglet_gymnase_gB')), findsOneWidget);
    expect(find.byKey(const Key('onglet_gymnase_gA')), findsNothing);
    expect(find.byKey(const Key('copier_stock_depart')), findsNothing);
  });

  testWidgets('événement ouvert : lecture seule, renvoi vers « Gymnases et stocks »',
      (tester) async {
    var renvoi = 0;
    final f = _Faux({'gA': {'coca': const StockDepart(24)}});
    await _afficher(tester, f, statut: 'en_cours', voirGymnases: () => renvoi++);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('copier_stock_depart')), findsNothing);
    await _deplier(tester, 'boissons_fraiches');
    expect(
        tester.widget<Text>(find.byKey(const Key('lecture_depart_gA_coca'))).data,
        'Stock : 24');
    await tester.tap(find.byKey(const Key('aller_gymnases_stocks')));
    expect(renvoi, 1);
  });

  testWidgets('une saisie invalide est refusée avec un message, sans écriture',
      (tester) async {
    final f = _Faux();
    await _afficher(tester, f);
    await _deplier(tester, 'boissons_fraiches');
    await tester.enterText(find.byKey(const Key('depart_gA_coca')), '100001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Entrez un nombre entier de 0 à 100 000.'), findsOneWidget);
    expect(f.ecrits, isEmpty);
  });

  testWidgets('échec d\'écriture : message clair', (tester) async {
    final f = _Faux()..echec = StateError('réseau');
    await _afficher(tester, f);
    await _deplier(tester, 'boissons_fraiches');
    await tester.tap(find.byKey(const Key('plus_gA_coca')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('erreur_stock_depart')), findsOneWidget);
  });

  testWidgets('« C\'est fait » revient à l\'écran précédent', (tester) async {
    final f = _Faux();
    await tester.pumpWidget(MaterialApp(
      theme: themeComptoir(),
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            key: const Key('ouvrir'),
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute(builder: (_) => _ecran(f)),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('ouvrir')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock_depart_fait')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stock_depart_fait')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock_depart_fait')), findsNothing);
  });
}
