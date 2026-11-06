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
//   Modèle de 27 produits ; événement « Tournoi » : 2 jours, gymnase A = 40 personnes,
//   gymnase B = 30 personnes (80 et 60 « personnes-jours »).
//   Consommations du modèle : croque standard 0,65, végé 0,45, tartiflette 0,6, café 1,3
//   (4 verres/L), Coca 0,32 (4 verres/L), tarte 1 (apportée).
//   Croques (arrondis au-dessus par gymnase) : A 52 + 36 + 48 = 136, B 39 + 27 + 36 = 102 = 238
//            -> pain de mie 2×238 = 476 tranches ; jambon 0,45×(100+75) = 78,75 -> 79 ;
//            gruyère 16 g×91 = 1,456 kg ; beurre 5 g×238 = 1,19 kg ; chèvre 25 g×63 = 1 575 g.
//   Café   : 104 + 78 = 182 verres / 4 = 45,5 L.     Coca : 26 + 20 = 46 verres / 4 = 11,5 L.
//   Tarte  : apportée, hors courses ; stock de 80 posé à la main au gymnase A.
//   Coût des courses : 40,00 €. Le stock gagne exactement les quantités prévues (le pain de mie,
//   acheté pile, limite chaque croque).
//   Ventes (caisse de Léa, gymnase A) : 2 croques + 1 café = 2,50 € (en caisse) ; 76 tartes
//   = 76,00 € ; 5 tartes = 5,00 €  => 83,50 € en 3 ventes ; tarte A : 80 - 76 = 4 (stock bas :
//   4 × 10 = 40 <= 80), puis 4 - 5 = -1 (épuisé). Résultat : 83,50 - 40,00 = 43,50 €.
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
    final evtId = await creerOuvert(depotEv,
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
    final croque = id('Croque-monsieur'), cafe = id('Café'), coca = id('Coca');
    final tarte = id('Tarte'), crepe = id('Crêpes (3 petites)');

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
    // 80 et 60 personnes-jours : croques 52 + 36 + 48 = 136 (A), 39 + 27 + 36 = 102 (B) = 238.
    await attendreTexte(tester, 'achat_pain de mie|tranche', 'Pain de mie : 476 tranches');
    expect(texte(tester, 'achat_jambon blanc|tranche'), 'Jambon blanc : 79 tranches'); // (100 + 75) x 0,45
    expect(texte(tester, 'achat_gruyere rape|g'), 'Gruyère râpé : 1,46 kg'); // 91 x 16 g
    expect(texte(tester, 'achat_beurre|g'), 'Beurre : 1,19 kg'); // 238 x 5 g
    expect(texte(tester, 'achat_buche de chevre|g'), 'Bûche de chèvre : 1,57 kg'); // 63 x 25 g = 1 575 g (1,575 s'affiche 1,57 : arrondi binaire)
    expect(texte(tester, 'achat_produit:$cafe'), 'Café : 45,5 L'); // (104 + 78) verres / 4
    expect(texte(tester, 'achat_produit:$coca'), 'Coca : 11,5 L'); // (26 + 20) verres / 4
    await attendreTexte(tester, 'etat_courses', 'Enregistré');

    // Avec 27 produits la liste est longue : on descend jusqu'au bouton (liste paresseuse).
    await tester.dragUntilVisible(find.byKey(const Key('valider_courses')),
        find.byType(ListView), const Offset(0, -600));
    await toucher(tester, find.byKey(const Key('valider_courses')));
    await attendre(tester, find.byKey(const Key('confirmer_validation')));
    expect(texte(tester, 'rendement_$croque'),
        'Croque-monsieur : +91 (Gymnase A +52 · Gymnase B +39)');
    await saisir(tester, 'cout_courses', '40');
    await toucher(tester, find.byKey(const Key('confirmer_validation')));
    await attendre(tester, find.byKey(const Key('courses_validee')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await stock(gA, croque))!['quantite'], 52);
    expect((await stock(gB, croque))!['quantite'], 39);
    expect((await stock(gA, cafe))!['quantite'], 104);
    expect((await stock(gB, coca))!['quantite'], 20);
    // La tarte est « apportée par les bénévoles » (décision 45) : hors courses,
    // son stock de 80 est posé à la main par la gestion.
    expect(await stock(gA, tarte), isNull);
    await depotEv.definirStock(evtId, gA, tarte, 80);
    final tA = (await stock(gA, tarte))!;
    expect((tA['quantite'], tA['reference']), (80, 80));
    expect(await stock(gA, crepe), isNull); // les crêpes n'ont ni consommation ni suivi

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

    // Vente en caisse : 2 croques + 1 café = 2,50 €.
    await toucher(tester, find.byKey(Key('produit_$croque')));
    await toucher(tester, find.byKey(Key('produit_$croque')));
    await toucher(tester, find.byKey(Key('produit_$cafe')));
    expect(texte(tester, 'total'), 'Total : 2,50 €');
    await toucher(tester, find.byKey(const Key('encaisser_especes')));
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 1 · 2,50 €');
    await attendreTexte(tester, 'stock_$croque', 'Stock : 50');

    // 76 tartes d'un coup (76,00 €) : stock bas à 4.
    final caisses = depotEv.caisses(evtId);
    final caisseId = idCaisse(leaUid, gA);
    caisses.enregistrerVente(
        caisseId, [LigneVente(tarte, 'Tarte', 100, 76)], 'carte',
        stocks: {tarte: 80});
    await attendreTexte(tester, 'stock_$tarte', 'Stock bas : 4');
    // 5 tartes de plus (5,00 €) : épuisé (-1), la vente passe quand même.
    caisses.enregistrerVente(
        caisseId, [LigneVente(tarte, 'Tarte', 100, 5)], 'especes',
        stocks: {tarte: 4});
    await attendreTexte(tester, 'stock_$tarte', 'Épuisé');
    await attendreTexte(tester, 'recap_caisse', 'Mes ventes : 3 · 83,50 €');
    expect((await stock(gA, tarte))!['quantite'], -1);

    // Les crêpes n'ont pas de quantité : Léa les signale vides.
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
        'Total des ventes | 83,50 € | 3 ventes');
    expect(texte(tester, 'bilan_cout'), 'Coût des courses : 40,00 €');
    expect(texte(tester, 'bilan_resultat'), 'Résultat : 43,50 €');
    await toucher(tester, find.byKey(const Key('exporter_csv')));
    expect(nomFichier, 'bilan-tournoi-${dateIso(DateTime.now())}.csv');
    expect(csv, contains('Total des ventes;83,50'));
    expect(csv, contains('Coût des courses;40,00\r\nRésultat;43,50'));
    expect(csv, contains('Vue;Commun'));
    expect(csv, contains('Espèces;7,50')); // 2,50 + 5,00
    expect(csv, contains('Carte;76,00'));
    expect(csv, contains('Tarte;81;81,00;'));
    expect(csv, contains('Croque-monsieur;2;2,00;89'));
    expect(csv, contains('Lea;Gymnase A;Ouverte;3;0;83,50'));
  });
}
