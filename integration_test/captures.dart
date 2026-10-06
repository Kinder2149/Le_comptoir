// Fabrique les captures d'écran de la fiche Play Store : un week-end de buvette réaliste est
// posé sur la copie locale de Firebase, puis chaque écran est photographié. Les images restent
// dans le cache de l'appli : play_store/captures/lancer_captures.ps1 les récupère. Nom sans « _test » : lancer_integration.ps1 ne le lance pas.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
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

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> retour(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await pause(tester);
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    await pause(tester);
    final octets = await binding.takeScreenshot(nom);
    final dossier = Directory('/sdcard/Pictures/lc_captures')..createSync(recursive: true);
    File('${dossier.path}/$nom.png').writeAsBytesSync(octets);
    debugPrint('CAPTURE $nom');
  }

  testWidgets('captures de la fiche', (tester) async {
    debugPrint('ETAPE surface');
    WidgetsApp.debugAllowBannerOverride = false; // pas de bandeau « DEBUG » sur les captures
    await binding.convertFlutterSurfaceToImage();
    debugPrint('ETAPE surface ok');
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await auth.signOut();

    debugPrint('ETAPE ouvrir');
    await ouvrir(tester, 'chef', fauxGoogle('chef_captures'));
    await creerAssociationParLInterface(tester,
        nom: 'Handball Club des Aigles', prenom: 'Marie');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menus = depotAsso.menus(assoId);
    final json = await rootBundle.loadString('assets/menu_type.json');
    final menuId = await menus.creerMenuDepuisModele('Menu Tournoi', lireMenuType(json));
    final depotEv = depotAsso.evenements(assoId);
    final evt = await depotEv.creerEvenement(
      nom: 'Tournoi de printemps',
      date: '2026-10-17',
      menuId: menuId,
      modes: ['especes', 'carte', 'cheque'],
    );
    final gym = await gymnaseUnique(depotEv, evt);
    final produits = await depotEv.suivreProduits(evt).first;
    final base = 'associations/$assoId/evenements/$evt';
    final jeton = (await auth.currentUser!.getIdToken())!;

    debugPrint('ETAPE ventes');
    // Une caisse et une vingtaine de ventes sur deux jours.
    expect(await restOuvrirCaisse(base, chefUid, gym, jeton, 'Marie', DateTime(2026, 10, 17, 9)),
        200);
    final caisseId = idCaisse(chefUid, gym);
    const modes = ['especes', 'carte', 'especes', 'cheque', 'especes', 'carte'];
    for (var n = 0; n < 24; n++) {
      final a = produits[(n * 3) % produits.length];
      final b = produits[(n * 5 + 2) % produits.length];
      final lignes = [
        restLigne(a.id, a.nom, a.prixCentimes, 1 + n % 3),
        if (a.id != b.id) restLigne(b.id, b.nom, b.prixCentimes, 1 + (n + 1) % 2),
      ];
      final total = a.prixCentimes * (1 + n % 3) +
          (a.id != b.id ? b.prixCentimes * (1 + (n + 1) % 2) : 0);
      final quand = n < 15
          ? DateTime(2026, 10, 17, 9 + n ~/ 2, (n * 7) % 60)
          : DateTime(2026, 10, 18, 9 + (n - 15) ~/ 2, (n * 11) % 60);
      expect(
          await restEcrire('POST', '$base/caisses/$caisseId/ventes', jeton,
              restVente(lignes, total, modes[n % modes.length], quand, gym)),
          200);
    }

    debugPrint('ETAPE accueil');
    // 1. Accueil de l'association.
    await attendre(tester, find.text('Tournoi de printemps'));
    await photo(tester, '1_accueil');

    // 2. Le menu et ses produits.
    await toucher(tester, find.byKey(const Key('menus')));
    await attendre(tester, find.byKey(const Key('nouveau_menu')));
    await toucher(tester, find.text('Menu Tournoi'));
    await attendre(tester, find.byKey(const Key('nouveau_produit')));
    await photo(tester, '2_menu');
    await retour(tester);
    await retour(tester);

    // 3. L'événement.
    await toucher(tester, find.text('Tournoi de printemps'));
    await attendre(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await photo(tester, '3_evenement');

    // 4. La caisse, avec une commande en cours.
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await pause(tester);
    for (final nom in ['Croque-monsieur', 'Croque-monsieur', 'Café', 'Crêpe']) {
      await toucher(tester, find.text(nom));
    }
    await tester.drag(find.byType(GridView), const Offset(0, 600)); // remonte la grille
    await photo(tester, '4_caisse');
    await retour(tester);

    // 5. Le bilan.
    final defil = find.byType(Scrollable).first;
    for (var i = 0; i < 40 && find.byKey(const Key('voir_bilan')).evaluate().isEmpty; i++) {
      await tester.drag(defil, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await photo(tester, '5_bilan');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await photo(tester, '6_bilan_detail');
  });
}
