import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_classeur.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Ergonomie de la gestion », étape E9 : le critère de fin de mission, d'un bout à
// l'autre, sur téléphone (432 x 864). « J'ouvre un tournoi et je vois où j'en suis (Avant,
// Pendant, Après). Je saisis mon stock de départ gymnase par gymnase, par familles ; je vérifie
// la prévision ; je fais les courses par rayons et je coche ; je télécharge le classeur, je le
// remplis et je le réimporte ; j'ouvre le tournoi, je surveille le stock, je clôture et je lis
// le bilan. »
//
// Chiffres : 70 personnes au gymnase A, 50 au gymnase B, 2 jours ; croque-monsieur 0,7 par
// personne et par jour corrigé à la main : (70 + 50) x 2 x 0,7 = 168 croques pour le tournoi.
// Stock de départ : gymnase A = 40 croques, 10 cafés (+ sur le bouton), 24 cocas ; le gymnase B
// reçoit la copie puis 0 croque (épuisé, à surveiller). Classeur : A croque passe à 45.
// Captures : sur l'appareil, dans /sdcard/Pictures/lc_captures (récupérées par adb pull vers
// audit_front/ergonomie/apres/).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets('critère de fin Ergonomie : Avant, stock, prévision, courses, classeur, Pendant, Après',
      (tester) async {
    debugPrint('ETAPE surface');
    WidgetsApp.debugAllowBannerOverride = false; // pas de bandeau « DEBUG » sur les captures
    await binding.convertFlutterSurfaceToImage();
    debugPrint('ETAPE surface ok');
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await auth.signOut();
    debugPrint('ETAPE signout ok');

    Future<void> pause([int ms = 500]) => tester.pump(Duration(milliseconds: ms));

    Future<void> photo(String nom) async {
      await pause(700);
      final octets = await binding.takeScreenshot(nom);
      final dossier = Directory('/sdcard/Pictures/lc_captures')..createSync(recursive: true);
      File('${dossier.path}/$nom.png').writeAsBytesSync(octets);
      debugPrint('CAPTURE $nom');
    }

    /// Fait défiler jusqu'à [cible] (dans [defil] si donné), puis la rend visible.
    Future<void> montrer(Finder cible, {Finder? defil}) async {
      final liste = defil ?? find.byType(Scrollable).first;
      if (cible.evaluate().isEmpty) {
        try {
          await tester.scrollUntilVisible(cible, 150, scrollable: liste, maxScrolls: 40);
        } catch (_) {
          await tester.scrollUntilVisible(cible, -150, scrollable: liste, maxScrolls: 80);
        }
      }
      await tester.ensureVisible(cible);
      await pause(300);
    }

    Future<void> toucher(Finder cible, {Finder? defil}) async {
      await montrer(cible, defil: defil);
      await tester.tap(cible);
      await pause(400);
    }

    Future<void> saisir(Finder cible, String valeur, {Finder? defil}) async {
      await montrer(cible, defil: defil);
      await tester.enterText(cible, valeur);
      await pause(300);
    }

    Future<void> retour() async {
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await pause(800);
    }

    Future<void> attendreTexte(String cle, String attendu) async {
      for (var i = 0; i < 150; i++) {
        await pause(100);
        final f = find.byKey(Key(cle));
        if (f.evaluate().isNotEmpty && contenuDe(tester, f) == attendu) return;
      }
      final f = find.byKey(Key(cle));
      final actuel = f.evaluate().isEmpty ? '(absent)' : contenuDe(tester, f);
      throw TestFailure('« $cle » : attendu « $attendu », obtenu « $actuel »');
    }

    /// Déplie une famille de la liste (les familles sont repliées au départ).
    Future<void> ouvrirFamille(String cleListe, String famille) => toucher(
          find.byKey(Key('entete_famille_$famille')),
          defil: find.descendant(
              of: find.byKey(Key(cleListe)), matching: find.byType(Scrollable)),
        );

    // ---------- 1. Le responsable : association, menu du modèle, tournoi à deux gymnases.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_ergonomie'));
    await creerAssociationParLInterface(tester,
        nom: 'Club Ergonomie', prenom: 'Chef');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final json = await rootBundle.loadString('assets/menu_type.json');
    final menuId =
        await depotAsso.menus(assoId).creerMenuDepuisModele('Menu modèle', lireMenuType(json));
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi 2026',
      date: dateIso(DateTime.now()),
      menuId: menuId,
      modes: ['especes', 'carte'],
      gymnases: ['Gymnase A', 'Gymnase B'],
    );
    await db.waitForPendingWrites();
    final gymnases = await depotEv.suivreGymnases(evt).first;
    final gA = gymnases.firstWhere((g) => g.nom == 'Gymnase A').id;
    final gB = gymnases.firstWhere((g) => g.nom == 'Gymnase B').id;
    final produits = await depotEv.suivreProduits(evt).first;
    String id(String nom) => produits.firstWhere((p) => p.nom == nom).id;
    final croque = id('Croque-monsieur'), cafe = id('Café'), coca = id('Cola');

    // ---------- 2. L'accueil de l'association, puis l'onglet Avant du tournoi.
    await attendre(tester, find.text('Tournoi 2026'));
    await photo('01_accueil_association');
    await toucher(find.text('Tournoi 2026'));
    await attendre(tester, find.byKey(const Key('avancement_avant')));
    await attendreTexte('avancement_avant', '0 sur 4 faits');
    await photo('02_evenement_avant');

    // ---------- 3. Stock de départ, gymnase A : familles, clavier, +.
    await toucher(find.byKey(const Key('voir_preparation')));
    await attendre(tester, find.byKey(const Key('aide_stock_depart')));
    await ouvrirFamille('familles_stock_$gA', 'croques');
    await ouvrirFamille('familles_stock_$gA', 'boissons_chaudes');
    await ouvrirFamille('familles_stock_$gA', 'boissons_fraiches');
    await saisir(find.byKey(Key('depart_${gA}_$croque')), '40',
        defil: find.descendant(
            of: find.byKey(Key('familles_stock_$gA')), matching: find.byType(Scrollable)));
    for (var i = 0; i < 3; i++) {
      await toucher(find.byKey(Key('plus_${gA}_$cafe')),
          defil: find.descendant(
              of: find.byKey(Key('familles_stock_$gA')), matching: find.byType(Scrollable)));
    }
    await saisir(find.byKey(Key('depart_${gA}_$coca')), '24',
        defil: find.descendant(
            of: find.byKey(Key('familles_stock_$gA')), matching: find.byType(Scrollable)));
    await pause(1200); // enregistrement après la pause de saisie
    await attendreTexte('onglet_gymnase_$gA', 'Gymnase A · 3');
    await photo('03_stock_depart');

    // Copie vers le gymnase B (confirmation), puis 0 croque au B : épuisé, à surveiller.
    await toucher(find.byKey(const Key('copier_stock_depart')));
    await attendre(tester, find.byKey(const Key('confirmer_copie_stock')));
    await toucher(find.byKey(const Key('confirmer_copie_stock')));
    await attendre(tester, find.byKey(const Key('copie_stock_faite')));
    await toucher(find.byKey(Key('onglet_gymnase_$gB')));
    await ouvrirFamille('familles_stock_$gB', 'croques');
    await saisir(find.byKey(Key('depart_${gB}_$croque')), '0',
        defil: find.descendant(
            of: find.byKey(Key('familles_stock_$gB')), matching: find.byType(Scrollable)));
    await pause(1200);
    for (var i = 0; i < 3 && find.byKey(const Key('avancement_avant')).evaluate().isEmpty; i++) {
      await toucher(find.byKey(const Key('stock_depart_fait')));
      await pause(1500);
    }
    await attendreTexte('avancement_avant', '1 sur 4 faits');

    // ---------- 4. Personnes et durée : 70 et 50 personnes, 2 jours.
    await toucher(find.byKey(const Key('tache_personnes')));
    await attendre(tester, find.byKey(const Key('aide_personnes_duree')));
    await saisir(find.byKey(Key('champ_personnes_$gA')), '70');
    await saisir(find.byKey(Key('champ_personnes_$gB')), '50');
    await saisir(find.byKey(const Key('champ_duree')), '2');
    await pause(1500);
    await photo('04_personnes_duree');
    await retour();
    await attendreTexte('avancement_avant', '2 sur 4 faits');

    // ---------- 5. Prévision : une correction à la main, puis « C'est vérifié ».
    await toucher(find.byKey(const Key('tache_prevision')));
    await attendre(tester, find.byKey(const Key('bandeau_prevision')));
    await saisir(find.byKey(Key('champ_conso_$croque')), '0,7');
    await pause(1500);
    expect(texte(tester, 'total_$croque'), '168');
    await photo('05_prevision');
    await toucher(find.byKey(const Key('prevision_verifiee')));
    if (find.byKey(const Key('confirmer_prevision')).evaluate().isNotEmpty) {
      await toucher(find.byKey(const Key('confirmer_prevision')));
    }
    await attendre(tester, find.byKey(const Key('prevision_verifiee_ok')));
    await retour();
    await attendreTexte('avancement_avant', '3 sur 4 faits');

    // ---------- 6. Courses : rangées par rayons, cases cochées, achats saisis, validation.
    await toucher(find.byKey(const Key('voir_courses')));
    await attendre(tester, find.byKey(const Key('etat_courses')));
    await ouvrirReglagesCourses(tester);
    await toucher(find.byKey(const Key('recalculer')));
    await attendre(tester, find.byKey(Key('qte_${gA}_$croque')));
    await toucher(find.byKey(Key('case_p:$cafe')));
    await toucher(find.byKey(Key('case_p:$coca')));
    await photo('06_courses');
    await toucher(find.byKey(const Key('valider_courses')));
    await pause(2000); // écran de validation : les champs du bas ne sont construits qu'au défilement
    await saisir(find.byKey(const Key('cout_courses')), '40');
    await toucher(find.byKey(const Key('confirmer_validation')));
    await ongletCourses(tester, dejaAchete: true);
    await attendre(tester, find.byKey(const Key('courses_validee')));
    await retour();
    await attendreTexte('avancement_avant', '4 sur 4 faits');

    // ---------- 7. Classeur Excel : l'écran, puis le modèle téléchargé, rempli et réimporté.
    await toucher(find.byKey(const Key('ouvrir_classeur')));
    await attendre(tester, find.byKey(const Key('telecharger_modele')));
    await photo('11_classeur');
    await retour();

    Uint8List? modele;
    Uint8List? aImporter;
    final portee = const PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);
    Navigator.of(tester.element(find.byType(Scaffold).last)).push(MaterialPageRoute<void>(
      builder: (_) => EcranClasseur(
        evenement: depotEv.suivreEvenement(evt),
        portee: portee,
        gymnases: depotEv.suivreGymnases(evt),
        produits: depotEv.suivreProduits(evt),
        stocks: depotEv.suivreStocksDepart(evt),
        assistant: assistantImport(
            depot: depotAsso,
            assoId: assoId,
            uid: chefUid,
            classeur: () => aImporter,
            evenementId: evt,
            menuPropose: 'Menu modèle'),
        partagerModele: (n, o, m) async => modele = Uint8List.fromList(o),
      ),
    ));
    await pause(800);
    await toucher(find.byKey(const Key('telecharger_modele')));
    await pause(500);
    expect(modele, isNotNull);
    final x = Excel.decodeBytes(modele!);
    final stockFeuille = x.tables[feuilleStock]!;
    for (var r = 6; r < stockFeuille.rows.length; r++) {
      final ligne = stockFeuille.rows[r];
      if ('${ligne[0]?.value}|${ligne[1]?.value}' == 'Gymnase A|Croque-monsieur') {
        stockFeuille.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r), IntCellValue(45));
      }
    }
    aImporter = Uint8List.fromList(x.encode()!);
    await toucher(find.byKey(const Key('importer_classeur')));
    await assistantJusquAuResume(tester);
    await pause(800);
    expect(find.textContaining('stock'), findsWidgets);
    await toucher(find.byKey(const Key('appliquer_import_assistant')));
    await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
    await db.waitForPendingWrites();
    await retour();
    await attendre(tester, find.byKey(const Key('ouvrir_evenement')));
    await attendreTexte('avancement_avant', '4 sur 4 faits');
    final stockA = await depotEv.suivreStocksDepart(evt).first;
    expect(stockA[gA]![croque]!.quantite, 45);
    // Les courses validées ont rempli le stock du B : la buvette l'épuise (ventes), à surveiller.
    await depotEv.definirStock(evt, gB, croque, 0);
    await db.waitForPendingWrites();

    // ---------- 8. Ouverture aux bénévoles, puis Pendant : à surveiller, ajout au stock.
    await toucher(find.byKey(const Key('ouvrir_evenement')));
    await attendre(tester, find.byKey(const Key('confirmer_ouverture_evenement')));
    await toucher(find.byKey(const Key('confirmer_ouverture_evenement')));
    await attendre(tester, find.byKey(const Key('onglet_pendant')));
    await toucher(find.byKey(const Key('onglet_pendant')));
    await attendre(tester, find.byKey(const Key('pendant_total')));
    await attendre(tester, find.byKey(Key('ajout_surveiller_${gB}_$croque')));
    await photo('07_pendant');

    await toucher(find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(const Key('titre_stock_evenement')));
    await photo('08_stock_pendant');
    await retour();

    await toucher(find.byKey(Key('ajout_surveiller_${gB}_$croque')));
    await attendre(tester, find.byKey(const Key('saisie_quantite')));
    await saisir(find.byKey(const Key('saisie_quantite')), '10');
    await toucher(find.byKey(const Key('valider_quantite')));
    await pause(1000);

    // ---------- 9. Clôture, puis Après : clôture, bilan.
    await toucher(find.byKey(const Key('cloturer_evenement')));
    await attendre(tester, find.byKey(const Key('confirmer_cloture_evenement')));
    await toucher(find.byKey(const Key('confirmer_cloture_evenement')));
    await neRienGarderSiDemande(tester);
    await pause(1500);
    await toucher(find.byKey(const Key('onglet_apres')));
    await attendre(tester, find.byKey(const Key('voir_bilan')));
    await photo('09_apres');
    await toucher(find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await montrer(find.byKey(const Key('exporter_excel')));
    await photo('12_bilan_export');
    await retour();

    // ---------- 10. Le menu rangé en familles.
    for (var i = 0; i < 4 && find.byKey(const Key('menus')).evaluate().isEmpty; i++) {
      await retour();
    }
    await toucher(find.byKey(const Key('menus')));
    await attendre(tester, find.text('Menu modèle'));
    await toucher(find.text('Menu modèle'));
    await attendre(tester, find.byKey(const Key('nouveau_produit')));
    await photo('10_menu_familles');
  });
}
