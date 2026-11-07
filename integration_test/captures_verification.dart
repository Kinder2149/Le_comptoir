// Captures de vérification finale (B1 à B5 et C1) : une histoire de week-end sur la copie
// locale de Firebase, chaque critère est photographié. Nom sans « _test » : lancer_integration.ps1
// ne le lance pas. Lancement : audit_front/captures_stock_courses/verif_finale/lancer.ps1
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> pause(WidgetTester tester, [int secondes = 2]) async {
    for (var i = 0; i < secondes * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> montrer(WidgetTester tester, Finder cible) async {
    if (cible.evaluate().isEmpty) {
      await tester.scrollUntilVisible(cible, 300,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(cible);
  }

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await montrer(tester, cible);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saisir(WidgetTester tester, String cle, String valeur) async {
    final f = find.byKey(Key(cle));
    await montrer(tester, f);
    await tester.enterText(f, valeur);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> attendreTexte(WidgetTester tester, String cle, String attendu) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
    }
    final f = find.byKey(Key(cle));
    throw TestFailure('« $cle » : attendu « $attendu », obtenu '
        '« ${f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f)} »');
  }

  // L'émulateur est parfois lent : une validation peut prendre plus de 15 s.
  Future<void> attendreLong(WidgetTester tester, Finder cible) async {
    for (var i = 0; i < 900; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (cible.evaluate().isNotEmpty) return;
      // Liste paresseuse : un bandeau en haut n'existe que s'il est à l'écran.
      if (i % 30 == 29 && find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      }
    }
    throw TestFailure('Jamais apparu (90 s) : $cible');
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await pause(tester);
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    await pause(tester);
    final octets = await binding.takeScreenshot(nom);
    final dossier = Directory('/sdcard/Pictures/lc_verif')..createSync(recursive: true);
    File('${dossier.path}/$nom.png').writeAsBytesSync(octets);
    debugPrint('CAPTURE $nom');
  }

  testWidgets('captures de vérification finale', (tester) async {
    WidgetsApp.debugAllowBannerOverride = false;
    await binding.convertFlutterSurfaceToImage();
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    await ouvrir(tester, 'chef', fauxGoogle('chef_verif'));
    await creerAssociationParLInterface(tester,
        nom: 'Handball Club des Aigles', prenom: 'Marie');
    final chefUid = auth.currentUser!.uid;
    final assoId = (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final menuId = await menus.creerMenu('Menu Tournoi');
    await menus.ajouterProduit(menuId,
        nom: 'Croque-monsieur',
        prixCentimes: 100,
        fiche: const FicheProduit(type: 'compose', conso: 2, ingredients: [
          Ingredient('Pain de mie', 2, 'tranche'),
          Ingredient('Jambon blanc', 1 / 3, 'tranche'),
          Ingredient('Gruyère râpé', 7, 'g'),
        ]));
    await menus.ajouterProduit(menuId,
        nom: 'Soda',
        prixCentimes: 100,
        fiche: const FicheProduit(type: 'litre', conso: 1, verresParLitre: 4));
    await menus.ajouterProduit(menuId,
        nom: 'Gâteau',
        prixCentimes: 150,
        fiche: const FicheProduit(type: 'part', partsParEntier: 8, provenance: 'apporte'));
    final depotEv = depotAsso.evenements(assoId);
    final evt = await creerOuvert(depotEv,
      nom: 'Tournoi de printemps',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evt).first;
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    final croque = id('Croque-monsieur'), soda = id('Soda'), gateau = id('Gâteau');
    await depotEv.definirStock(evt, gA, croque, 40);
    await depotEv.definirStock(evt, gA, soda, 26);
    await depotEv.definirStock(evt, gB, soda, 10);
    await depotEv.definirStock(evt, gA, gateau, 16);

    // 3 ventes de croque au gymnase A : 1 + 2 + 3 = 6 vendus, 34 restants.
    final base = 'associations/$assoId/evenements/$evt';
    final jeton = (await auth.currentUser!.getIdToken())!;
    expect(await restOuvrirCaisse(base, chefUid, gA, jeton, 'Marie', DateTime.now()), 200);
    final caisses = depotEv.caisses(evt);
    final caisseId = idCaisse(chefUid, gA);
    var enStock = 40;
    for (final n in [1, 2, 3]) {
      caisses.enregistrerVente(
          caisseId, [LigneVente(croque, 'Croque-monsieur', 100, n)], 'especes',
          stocks: {croque: enStock});
      enStock -= n;
    }

    // ---------- B1, B2 : le menu n'a pas de stock ; provenance et parts par gâteau.
    await attendre(tester, find.text('Tournoi de printemps'));
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.byKey(const Key('nouveau_menu')));
    await toucher(tester, find.text('Menu Tournoi'));
    await attendre(tester, find.byKey(const Key('nouveau_produit')));
    await photo(tester, '01_B1_menu_sans_stock');
    await toucher(tester, find.text('Gâteau'));
    await attendre(tester, find.byKey(const Key('provenance_produit')));
    await photo(tester, '02_B1_B2_gateau_apporte_8_parts');
    await retour(tester);
    await retour(tester);
    await retour(tester);

    // ---------- B3 : Gymnases et stock (stock de l'événement, vendu et reste).
    await toucher(tester, find.text('Tournoi de printemps'));
    await attendre(tester, find.byKey(const Key('voir_gymnases')));
    await pause(tester);
    await photo(tester, '03_evenement_boutons');
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(Key('gymnase_$gA')));
    await attendreTexte(tester, 'vendu_${gA}_$croque', 'Vendu : 6');
    await attendreTexte(tester, 'stock_${gA}_$croque', 'Stock : 34');
    await photo(tester, '04_B3_gymnases_stock_vendu_6_reste_34');
    await retour(tester);

    // ---------- B4 : courses, durée à couvrir, estimation modifiable.
    // Les personnes se règlent dans la Préparation : ici, par le dépôt, avant les courses.
    await depotEv.definirPersonnes(evt, gA, 40);
    await depotEv.definirPersonnes(evt, gB, 30);
    await toucher(tester, find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await toucher(tester, find.byKey(const Key('duree_jour')));
    await toucher(tester, find.byKey(const Key('recalculer')));
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pump(const Duration(milliseconds: 500));
    await photo(tester, '05_B4_courses_duree_estimation');

    // ---------- C1 : validation de la série 1.
    await tester.dragUntilVisible(find.byKey(const Key('valider_courses')),
        find.byType(ListView), const Offset(0, -600));
    await photo(tester, '06_C1_boutons_partager_valider');
    await toucher(tester, find.byKey(const Key('valider_courses')));
    await attendre(tester, find.byKey(const Key('confirmer_validation')));
    await saisir(tester, 'cout_courses', '50');
    await photo(tester, '07_C1_validation_serie_1');
    await toucher(tester, find.byKey(const Key('confirmer_validation')));
    await attendreLong(tester, find.byKey(const Key('courses_validee')));
    await pause(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pump(const Duration(milliseconds: 500));
    await photo(tester, '08_C1_serie_1_validee_haut');
    await tester.dragUntilVisible(find.byKey(const Key('nouvelle_serie')),
        find.byType(ListView), const Offset(0, -600));
    await photo(tester, '09_C1_nouvelle_serie_et_partager');

    // ---------- C1 : série 2 (40 croques de plus au gymnase A, 30,00 €).
    await toucher(tester, find.byKey(const Key('nouvelle_serie')));
    await attendreLong(tester, find.byKey(const Key('aucun_achat')));
    // La liste est paresseuse : le bandeau du haut n'existe que s'il est à l'écran.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pump(const Duration(milliseconds: 500));
    await attendreLong(tester, find.byKey(const Key('series_validees')));
    await photo(tester, '10_C1_serie_2_liste_vide_bandeau_serie_1');
    await toucher(tester, find.byKey(Key('coche_${gA}_$croque')));
    await saisir(tester, 'qte_${gA}_$croque', '40');
    await toucher(tester, find.byKey(const Key('valider_courses')));
    await attendre(tester, find.byKey(const Key('confirmer_validation')));
    await saisir(tester, 'cout_courses', '30');
    await photo(tester, '10b_validation_serie_2');
    await toucher(tester, find.byKey(const Key('confirmer_validation')));
    await photo(tester, '10c_apres_confirmation_serie_2');
    await attendreLong(tester, find.byKey(const Key('courses_validee')));
    await pause(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pump(const Duration(milliseconds: 500));
    await photo(tester, '11_C1_cumul_2_series_80_euros');
    await retour(tester);

    // ---------- Bilan : le coût de toutes les séries.
    final defil = find.byType(Scrollable).first;
    for (var i = 0; i < 40 && find.byKey(const Key('voir_bilan')).evaluate().isEmpty; i++) {
      await tester.drag(defil, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_cout')));
    await photo(tester, '12_C1_bilan_cout_cumule');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await photo(tester, '12b_bilan_detail_produits');
    await retour(tester);

    // ---------- B5 : clôture, feuille « Garder pour le prochain événement ».
    await toucher(tester, find.byKey(const Key('cloturer_evenement')));
    await toucher(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    await attendre(tester, find.byKey(const Key('garder_restes')));
    await photo(tester, '13_B5_feuille_restes_rien_coche');
    await toucher(tester, find.byKey(Key('reste_coche_${gA}_$soda')));
    await tester.enterText(find.byKey(Key('reste_qte_${gA}_$soda')), '6');
    await pause(tester, 1);
    await photo(tester, '14_B5_6_L_de_soda_gardes');
    await toucher(tester, find.byKey(const Key('garder_restes')));
    await attendre(tester, find.byKey(const Key('cloture_info')));
    await photo(tester, '15_B5_evenement_cloture');
  });
}
