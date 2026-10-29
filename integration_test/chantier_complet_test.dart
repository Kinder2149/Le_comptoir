import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Chantier Stock et courses, étape 8 : le parcours complet, chiffres calculés à la main.
//
//   Modèle de 13 produits ; événement « Tournoi » : 2 jours, gymnase A = 40 personnes,
//   gymnase B = 30 personnes (80 et 60 « personnes-jours »).
//   Consommations du modèle : croque 2, café 2 (8 verres/L), soda 1 (5 verres/L), thé 1,
//   tarte 1, flan 1, barre 1, fruit 1.
//   Croque : A 160 + B 120 = 280  -> pain de mie 2×280 = 560 tranches, jambon 0,333×280 =
//            93,24 -> 94 tranches, gruyère 7×280 = 1 960 g = 1,96 kg.
//   Café   : 160 + 120 = 280 verres / 8 = 35 L.     Soda : 80 + 60 = 140 verres / 5 = 28 L.
//   Tarte  : A 80, B 60.
//   Coût des courses : 150,00 €. Le stock gagne exactement les quantités prévues.
//   Ventes (caisse de Léa, gymnase A) : 2 croques + 1 café = 7,00 € (en caisse) ; 76 tartes
//   = 152,00 € ; 5 tartes = 10,00 €  => 169,00 € en 3 ventes ; tarte A : 80 - 76 = 4 (stock bas :
//   4 × 10 = 40 <= 80), puis 4 - 5 = -1 (épuisé). Résultat : 169,00 - 150,00 = 19,00 €.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> attendreTexte(WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
    }
    final f = find.byKey(Key(cle));
    final actuel = f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
    throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
  }

  Future<void> saisir(WidgetTester tester, String cle, String valeur) async {
    final f = find.byKey(Key(cle));
    await tester.ensureVisible(f);
    await tester.enterText(f, valeur);
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('chantier complet : menu, courses, validation, ventes, signaux, bilan, CSV',
      (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // ---------- 1. Le responsable prépare : association, menu du modèle, événement.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_complet'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId = (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final json = await rootBundle.loadString('assets/menu_type.json');
    final menuId = await depotAsso.menus(assoId).creerMenuDepuisModele('Menu', lireMenuType(json));
    final depotEv = depotAsso.evenements(assoId);
    final evtId = await depotEv.creerEvenement(
      nom: 'Tournoi',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final gymnases = await depotEv.suivreGymnases(evtId).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evtId).first;
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    final croque = id('Croque-monsieur'), cafe = id('Café'), soda = id('Soda');
    final tarte = id('Tarte'), crepe = id('Crêpe');

    Future<Map<String, dynamic>?> stock(String g, String p) async => (await db
            .collection('associations')
            .doc(assoId)
            .collection('evenements')
            .doc(evtId)
            .collection('gymnases')
            .doc(g)
            .collection('stocks')
            .doc(p)
            .get(serveur))
        .data();

    // ---------- 2. Courses : personnes, quantités, achats, validation.
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('voir_courses')));
    await finTransition(tester);
    await toucher(tester, find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await saisir(tester, 'personnes_$gA', '40');
    await saisir(tester, 'personnes_$gB', '30');
    await toucher(tester, find.byKey(const Key('recalculer')));
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    await attendreTexte(tester, 'achat_pain de mie|tranche', 'Pain de mie : 560 tranches');
    expect(texte(tester, 'achat_jambon blanc|tranche'), 'Jambon blanc : 94 tranches');
    expect(texte(tester, 'achat_gruyere rape|g'), 'Gruyère râpé : 1,96 kg');
    expect(texte(tester, 'achat_produit:$cafe'), 'Café : 35 L');
    expect(texte(tester, 'achat_produit:$soda'), 'Soda : 28 L');
    await attendreTexte(tester, 'etat_courses', 'Enregistré');

    await toucher(tester, find.byKey(const Key('valider_courses')));
    await attendre(tester, find.byKey(const Key('confirmer_validation')));
    expect(texte(tester, 'rendement_$croque'),
        'Croque-monsieur : +280 (Gymnase A +160 · Gymnase B +120)');
    await saisir(tester, 'cout_courses', '150');
    await toucher(tester, find.byKey(const Key('confirmer_validation')));
    await attendre(tester, find.byKey(const Key('courses_validee')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await stock(gA, croque))!['quantite'], 160);
    expect((await stock(gB, croque))!['quantite'], 120);
    expect((await stock(gA, cafe))!['quantite'], 160);
    expect((await stock(gB, soda))!['quantite'], 60);
    // La tarte est « apportée par les bénévoles » (décision 45) : hors courses,
    // son stock de 80 est posé à la main par la gestion.
    expect(await stock(gA, tarte), isNull);
    await depotEv.definirStock(evtId, gA, tarte, 80);
    final tA = (await stock(gA, tarte))!;
    expect((tA['quantite'], tA['reference']), (80, 80));
    expect(await stock(gA, crepe), isNull); // la crêpe n'a ni consommation ni suivi

    // ---------- 3. Léa vend dans le gymnase A.
    await auth.signOut();
    await ouvrir(tester, 'benevole', googleAnnule);
    await attendre(tester, find.byKey(const Key('rejoindre')));
    await tester.enterText(find.byKey(const Key('code_saisi')), code);
    await tester.enterText(find.byKey(const Key('prenom_rejoindre')), 'Lea');
    await toucher(tester, find.byKey(const Key('rejoindre')));
    await attendre(tester, find.text('Tournoi'));
    final leaUid = auth.currentUser!.uid;
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await toucher(tester, find.byKey(Key('ouvrir_caisse_$gA')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    await attendreTexte(tester, 'stock_$tarte', 'Stock : 80');

    // Vente en caisse : 2 croques + 1 café = 7,00 €.
    await toucher(tester, find.byKey(Key('produit_$croque')));
    await toucher(tester, find.byKey(Key('produit_$croque')));
    await toucher(tester, find.byKey(Key('produit_$cafe')));
    expect(texte(tester, 'total'), 'Total : 7,00 €');
    await toucher(tester, find.byKey(const Key('encaisser_especes')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 7,00 €');
    await attendreTexte(tester, 'stock_$croque', 'Stock : 158');

    // 76 tartes d'un coup (152,00 €) : stock bas à 4.
    final caisses = depotEv.caisses(evtId);
    final caisseId = idCaisse(leaUid, gA);
    caisses.enregistrerVente(
        caisseId, [LigneVente(tarte, 'Tarte', 200, 76)], 'carte',
        stocks: {tarte: 80});
    await attendreTexte(tester, 'stock_$tarte', 'Stock bas : 4');
    // 5 tartes de plus (10,00 €) : épuisé (-1), la vente passe quand même.
    caisses.enregistrerVente(
        caisseId, [LigneVente(tarte, 'Tarte', 200, 5)], 'especes',
        stocks: {tarte: 4});
    await attendreTexte(tester, 'stock_$tarte', 'Épuisé');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 169,00 €');
    expect((await stock(gA, tarte))!['quantite'], -1);

    // La crêpe n'a pas de quantité : Léa la signale vide.
    await toucher(tester, find.byKey(const Key('ouvrir_stock')));
    await toucher(tester, find.byKey(Key('vide_$crepe')));
    await toucher(tester, find.byKey(const Key('fermer_stock')));
    await attendreTexte(tester, 'stock_$crepe', 'Vide');

    // ---------- 4. Le responsable revient : suivi en direct et bilan.
    await tester.pumpWidget(const SizedBox());
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_complet')())!);
    expect(auth.currentUser!.uid, chefUid);
    await ouvrir(tester, 'chef2', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await toucher(tester, find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('suivi_en_direct')));
    await attendreTexte(tester, 'direct_signal_$tarte', 'Épuisé : Gymnase A');
    expect(texte(tester, 'direct_signal_$crepe'), 'Vide : Gymnase A');
    expect(find.byKey(Key('direct_signal_$croque')), findsNothing);

    // ---------- 5. Bilan et CSV : les chiffres de l'écran sont ceux du fichier.
    final evenement = (await depotEv.suivreEvenement(evtId).first)!;
    String? nomFichier, csv;
    await tester.pumpWidget(MaterialApp(
      home: EcranBilan(
        evenement: evenement,
        tableau: caisses.suivreTableauDeBord(),
        produits: depotEv.suivreProduits(evtId),
        gymnases: depotEv.suivreGymnases(evtId),
        stocks: depotEv.suivreStocksParGymnase(evtId),
        courses: depotEv.suivreListeCourses(evtId),
        partager: (n, c) async {
          nomFichier = n;
          csv = c;
        },
      ),
    ));
    await attendre(tester, find.byKey(const Key('bilan_cout')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(contenuDe(tester, find.byKey(const Key('bilan_total'))),
        'Total des ventes | 169,00 € | 3 ventes');
    expect(texte(tester, 'bilan_cout'), 'Coût des courses : 150,00 €');
    expect(texte(tester, 'bilan_resultat'), 'Résultat : 19,00 €');
    await toucher(tester, find.byKey(const Key('exporter_csv')));
    expect(nomFichier, 'bilan-tournoi-${dateIso(DateTime.now())}.csv');
    expect(csv, contains('Total des ventes;169,00'));
    expect(csv, contains('Coût des courses;150,00\r\nRésultat;19,00'));
    expect(csv, contains('Vue;Commun'));
    expect(csv, contains('Espèces;17,00')); // 7,00 + 10,00
    expect(csv, contains('Carte;152,00'));
    expect(csv, contains('Tarte;81;162,00;'));
    expect(csv, contains('Croque-monsieur;2;6,00;278'));
    expect(csv, contains('Lea;Gymnase A;Ouverte;3;0;169,00'));
  });
}
