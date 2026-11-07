import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/restes.dart';

import 'outils.dart';

// Chantier Menu, événement et courses, étape B5 : à la clôture, la gestion garde du stock
// (6 L de soda au Gymnase 1, 2 L de café au Gymnase 2) ; l'événement suivant le reprend dans
// le gymnase du même nom, une seule fois ; un produit non coché n'est pas reporté.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('report de stock : garder à la clôture, reprendre à la création, une seule fois',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // ---------- Préparation : un menu (soda et café au litre, un croque), un événement à deux gymnases.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_restes'));
    await creerAssociationParLInterface(tester);
    final assoId = (await db.collection('users').doc(auth.currentUser!.uid).get())
        .data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Soda',
        prixCentimes: 100,
        fiche: const FicheProduit(type: 'litre', verresParLitre: 4));
    await menus.ajouterProduit(menuId,
        nom: 'Café',
        prixCentimes: 50,
        fiche: const FicheProduit(type: 'litre', verresParLitre: 4));
    await menus.ajouterProduit(menuId, nom: 'Croque', prixCentimes: 100);
    final depotEv = depotAsso.evenements(assoId);
    final evt1 = await creerOuvert(depotEv,
      nom: 'Tournoi 1',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase 1', 'Gymnase 2'],
    );
    final g1 = (await depotEv.suivreGymnases(evt1).first).firstWhere((g) => g.nom == 'Gymnase 1').id;
    final g2 = (await depotEv.suivreGymnases(evt1).first).firstWhere((g) => g.nom == 'Gymnase 2').id;
    final p1 = await depotEv.suivreProduits(evt1).first;
    String id(String nom) => p1.firstWhere((p) => p.nom == nom).id;
    final soda = id('Soda'), cafe = id('Café'), croque = id('Croque');
    await depotEv.definirStock(evt1, g1, soda, 26); // 6,5 L
    await depotEv.definirStock(evt1, g1, cafe, 10);
    await depotEv.definirStock(evt1, g2, cafe, 8); // 2 L
    await depotEv.definirStock(evt1, g2, croque, 7);

    Future<Map<String, dynamic>?> reste(String idReste) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('restes')
            .doc(idReste)
            .get(serveur))
        .data();

    // ---------- 1. Clôture : la feuille propose les produits en stock, rien de coché.
    await attendre(tester, find.text('Tournoi 1'));
    await finTransition(tester);
    await toucher(tester, find.text('Tournoi 1'));
    await attendre(tester, find.byKey(const Key('cloturer_evenement')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('cloturer_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    await attendre(tester, find.byKey(const Key('garder_restes')));
    expect(find.text('Garder pour le prochain événement ?'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byKey(Key('reste_coche_${g1}_$soda'))).value, isFalse);
    expect(tester.widget<TextField>(find.byKey(Key('reste_qte_${g1}_$soda'))).controller!.text,
        '6,5'); // 26 verres / 4

    // 6 L de soda au Gymnase 1, 2 L de café au Gymnase 2 ; le café du Gymnase 1 et le croque restent décochés.
    await toucher(tester, find.byKey(Key('reste_coche_${g1}_$soda')));
    await tester.enterText(find.byKey(Key('reste_qte_${g1}_$soda')), '6');
    await toucher(tester, find.byKey(Key('reste_coche_${g2}_$cafe')));
    await tester.enterText(find.byKey(Key('reste_qte_${g2}_$cafe')), '2');
    await toucher(tester, find.byKey(const Key('garder_restes')));
    await attendre(tester, find.byKey(const Key('cloture_info')));

    // ---------- 2. Côté serveur : deux restes, en verres, rien d'autre.
    final r1 = (await reste('gymnase-1__soda'))!;
    expect((r1['quantite'], r1['nomGymnase'], r1['nomProduit'], r1['evenementId']),
        (24, 'Gymnase 1', 'Soda', evt1));
    expect((await reste('gymnase-2__cafe'))!['quantite'], 8);
    expect(await reste('gymnase-1__cafe'), isNull); // non coché
    expect(await reste('gymnase-2__croque'), isNull); // non coché
    final evenement1 = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt1)
            .get(serveur))
        .data()!;
    expect(evenement1['statut'], 'cloture');

    // ---------- 3. Le prochain événement, mêmes noms de gymnases : reprise dans le bon gymnase.
    List<Reprise> reprises = const [];
    final evt2 = await creerOuvert(depotEv,
      nom: 'Tournoi 2',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['gymnase 2', 'GYMNASE 1'], // ordre, casse : sans importance
      surReprises: (r) => reprises = r,
    );
    expect(reprises.length, 2);
    final gym2 = await depotEv.suivreGymnases(evt2).first;
    final n1 = gym2.firstWhere((g) => g.nom == 'GYMNASE 1').id;
    final n2 = gym2.firstWhere((g) => g.nom == 'gymnase 2').id;
    final p2 = await depotEv.suivreProduits(evt2).first;
    String id2(String nom) => p2.firstWhere((p) => p.nom == nom).id;
    final stocks2 = await depotEv.suivreStocksParGymnase(evt2).first;
    expect(stocks2[n1]![id2('Soda')], 24); // 6 L
    expect(stocks2[n2]![id2('Café')], 8); // 2 L
    expect(stocks2[n1]!.containsKey(id2('Café')), isFalse); // non coché : pas de suivi
    expect(stocks2[n2]!.containsKey(id2('Croque')), isFalse);
    expect(stocks2[n1]!.containsKey(id2('Croque')), isFalse);
    final stockSoda = (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evt2)
            .collection('gymnases')
            .doc(n1)
            .collection('stocks')
            .doc(id2('Soda'))
            .get(serveur))
        .data()!;
    expect((stockSoda['quantite'], stockSoda['reference']), (24, 24));
    // Les restes sont consommés.
    expect(await reste('gymnase-1__soda'), isNull);
    expect(await reste('gymnase-2__cafe'), isNull);

    // ---------- 4. Une seule fois : un troisième événement ne reprend rien.
    var repris3 = -1;
    final evt3 = await creerOuvert(depotEv,
      nom: 'Tournoi 3',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase 1', 'Gymnase 2'],
      surReprises: (r) => repris3 = r.length,
    );
    expect(repris3, 0);
    expect((await depotEv.suivreStocksParGymnase(evt3).first).values.every((m) => m.isEmpty), isTrue);
  });
}
