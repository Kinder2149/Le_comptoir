import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/actualisation.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/firebase_options.dart';
import 'package:le_comptoir/gymnase.dart';

import 'outils.dart';

// Mission « Retours du terrain », étape F2 (décision 70) : deux téléphones sur la copie
// locale de Firebase. Le téléphone B est l'application affichée (le responsable) ; le
// téléphone A est une seconde connexion indépendante (autre instance Firebase, autre
// compte : Léa) qui rejoint, ouvre sa caisse, vend, ajoute du stock et clôture. Pour
// chaque écran de B, on relève s'il se met à jour tout seul. Le relevé est affiché (lignes
// « RELEVE ») et le test échoue si un écran n'a pas suivi.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  Future<void> toucher(WidgetTester tester, Finder cible) async {
    await tester.ensureVisible(cible);
    await tester.tap(cible);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finTransition(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  final releve = <String>[];
  final echecs = <String>[];

  /// Attend jusqu'à 15 s que le texte de [cle] vérifie [ok] ; note le résultat.
  Future<void> verifie(WidgetTester tester, String ecran, String etape, String cle,
      bool Function(String) ok, String attendu) async {
    String actuel = '(absent)';
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final f = find.byKey(Key(cle));
      if (f.evaluate().isNotEmpty) {
        actuel = contenuDe(tester, f);
        if (ok(actuel)) {
          releve.add('RELEVE $ecran | $etape | OK (« $actuel »)');
          return;
        }
      }
    }
    releve.add('RELEVE $ecran | $etape | PAS MIS A JOUR : attendu $attendu, affiché « $actuel »');
    echecs.add('$ecran / $etape');
  }

  Future<void> verifiePresence(WidgetTester tester, String ecran, String etape,
      String cle, bool present) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(Key(cle)).evaluate().isNotEmpty == present) {
        releve.add('RELEVE $ecran | $etape | OK (${present ? 'affiché' : 'disparu'})');
        return;
      }
    }
    releve.add('RELEVE $ecran | $etape | PAS MIS A JOUR : « $cle » '
        '${present ? 'jamais affiché' : 'toujours affiché'}');
    echecs.add('$ecran / $etape');
  }

  Future<void> tirer(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// « Glisser vers le bas » sur l'écran affiché : en ligne, aucun message et l'écran
  /// reste affiché ; hors réseau (réseau de B coupé), le message clair apparaît, rien ne
  /// bloque et le geste se termine.
  Future<void> verifieGlisser(WidgetTester tester, FirebaseFirestore db, String ecran,
      String cleEcran) async {
    await tirer(tester);
    final enLigne = find.byKey(const Key('message_actualisation')).evaluate().isEmpty &&
        find.byKey(Key(cleEcran)).evaluate().isNotEmpty &&
        find.byType(RefreshProgressIndicator).evaluate().isEmpty;
    releve.add('RELEVE $ecran | glisser vers le bas en ligne | '
        '${enLigne ? 'OK (état à jour, aucun message)' : 'ECHEC'}');
    if (!enLigne) echecs.add('$ecran / glisser en ligne');
    await db.disableNetwork();
    await tirer(tester);
    var message = '(aucun)';
    for (var i = 0; i < 100; i++) {
      final f = find.byKey(const Key('message_actualisation'));
      if (f.evaluate().isNotEmpty) {
        message = tester.widget<Text>(f).data!;
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    final horsReseau = message == messageHorsReseau &&
        find.byKey(Key(cleEcran)).evaluate().isNotEmpty &&
        find.byType(RefreshProgressIndicator).evaluate().isEmpty;
    releve.add('RELEVE $ecran | glisser vers le bas hors réseau | '
        '${horsReseau ? 'OK (« $message », rien de bloqué)' : 'ECHEC : « $message »'}');
    if (!horsReseau) echecs.add('$ecran / glisser hors réseau');
    await db.enableNetwork();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool egal(String a, String b) => a == b;
  bool Function(String) vaut(String attendu) => (s) => egal(s, attendu);

  testWidgets('deux téléphones : ce que fait A se voit sur B', (tester) async {
    final db = FirebaseFirestore.instance; // téléphone B
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    // --- Téléphone A : une seconde connexion, tout à fait indépendante de B.
    final appA = await Firebase.initializeApp(
        name: 'telephoneA', options: DefaultFirebaseOptions.android);
    final authA = FirebaseAuth.instanceFor(app: appA);
    await authA.useAuthEmulator('10.0.2.2', 9099);
    final dbA = FirebaseFirestore.instanceFor(app: appA);
    dbA.useFirestoreEmulator('10.0.2.2', 8080);

    // --- B : le responsable crée l'association, le menu et l'événement (ouvert).
    await ouvrir(tester, 'responsable', fauxGoogle('chef_actualisation'));
    await creerAssociationParLInterface(tester);
    final code = texte(tester, 'code');
    final chefUid = auth.currentUser!.uid;
    final assoId =
        (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
    final depotAsso = DepotAssociations(db);
    final menuId = await depotAsso.menus(assoId).creerMenu('Menu Tournoi');
    await depotAsso.menus(assoId)
        .ajouterProduit(menuId,
            nom: 'Croque-monsieur',
            prixCentimes: 300,
            fiche: const FicheProduit(type: 'part'));
    final depotEv = depotAsso.evenements(assoId);
    final evt = await creerOuvert(depotEv,
        nom: 'Tournoi',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes', 'carte']);
    final plusTard = await depotEv.creerEvenement(
        nom: 'Plus tard',
        date: dateIso(DateTime.now()),
        menuId: menuId,
        modes: ['especes'],
        gymnases: [nomGymnaseParDefaut]);
    await donnerStock(depotEv, evt, 'Croque-monsieur', 1);
    final gym = await gymnaseUnique(depotEv, evt);
    final croque = (await depotEv.suivreProduits(evt).first).single.id;
    await db.waitForPendingWrites();

    // --- Écran 1 : l'association (B la regarde pendant que A agit).
    await attendre(tester, find.byKey(Key('evenement_$evt')));
    await verifie(tester, 'association', 'état « Plus tard » avant',
        'etat_$plusTard', (s) => s.contains('prépar'), 'En préparation');

    await authA.createUserWithEmailAndPassword(
        email: 'lea.actualisation@test.fr', password: 'secret12');
    final leaUid = authA.currentUser!.uid;
    await DepotAssociations(dbA)
        .rejoindre(uid: leaUid, codeSaisi: code, prenom: 'Lea');
    await dbA.waitForPendingWrites();
    // La liste des membres est dans Paramètres (responsable).
    await tester.tap(find.byKey(const Key('parametres')));
    await tester.pump(const Duration(milliseconds: 500));
    await verifiePresence(tester, 'association', 'A rejoint : le membre apparaît',
        'param_membre_$leaUid', true);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(milliseconds: 500));
    // Un autre téléphone (administrateur de la copie locale) ouvre l'événement « Plus tard ».
    expect(
        await restEcrire(
            'PATCH',
            'associations/$assoId/evenements/$plusTard?updateMask.fieldPaths=statut',
            'owner',
            {'statut': restTexte('en_cours')}),
        200);
    await verifie(tester, 'association', 'un autre téléphone ouvre « Plus tard »',
        'etat_$plusTard', (s) => s.contains('cours'), 'En cours');

    // --- A : outils.
    final depotEvA = DepotAssociations(dbA).evenements(assoId);
    final caissesA = depotEvA.caisses(evt);
    final caisseId = idCaisse(leaUid, gym);
    Future<void> ouvrirA({required bool rouvrir}) async {
      if (rouvrir) {
        caissesA.rouvrirCaisse(caisseId);
      } else {
        await caissesA.ouvrirCaisse(caisseId, 'Lea');
      }
      await dbA.waitForPendingWrites();
    }

    Future<void> vendreA(int stockAvant) async {
      caissesA.enregistrerVente(
        caisseId,
        [LigneVente(croque, 'Croque-monsieur', 300, 1)],
        'especes',
        stocks: {croque: stockAvant},
      );
      await dbA.waitForPendingWrites();
    }

    Future<void> ajouterA() async {
      await depotEvA.ajouterApport(evt,
          gymnaseId: gym,
          gymnaseNom: nomGymnaseParDefaut,
          produitId: croque,
          produitNom: 'Croque-monsieur',
          nom: 'Gateau maison',
          parts: 2,
          prenom: 'Lea',
          uid: leaUid);
      await dbA.waitForPendingWrites();
    }

    Future<void> cloturerA() async {
      await caissesA.cloturerCaisse(caisseId);
      await dbA.waitForPendingWrites();
    }

    // Modèle du tournoi : stock 1, aucune vente.
    var stock = 1;
    var ventes = 0;
    String euros(int centimes) =>
        '${centimes ~/ 100},${(centimes % 100).toString().padLeft(2, '0')} €';
    String vente(int n) => n <= 1 ? '$n vente' : '$n ventes';

    // --- Écran 2 : l'événement, onglet Pendant.
    await toucher(tester, find.byKey(Key('evenement_$evt')));
    await attendre(tester, find.byKey(const Key('onglets_evenement')));
    await finTransition(tester);
    if (find.byKey(const Key('pendant_total')).evaluate().isEmpty) {
      await toucher(tester, find.byKey(const Key('onglet_pendant')));
    }
    await attendre(tester, find.byKey(const Key('pendant_total')));
    await ouvrirA(rouvrir: false);
    await verifie(tester, 'événement Pendant', 'A ouvre sa caisse', 'pendant_caisses',
        vaut('Caisses ouvertes : 1'), 'Caisses ouvertes : 1');
    await vendreA(stock);
    stock -= 1;
    ventes += 1;
    await verifie(tester, 'événement Pendant', 'A vend', 'pendant_total',
        vaut('Ventes : $ventes · ${euros(300 * ventes)}'), 'Ventes : 1 · 3,00 €');
    await verifiePresence(tester, 'événement Pendant', 'A vend le dernier : « à surveiller »',
        'surveiller_${gym}_$croque', true);
    await ajouterA();
    stock += 2;
    await verifiePresence(tester, 'événement Pendant', 'A ajoute du stock : plus à surveiller',
        'surveiller_${gym}_$croque', false);
    await cloturerA();
    await verifie(tester, 'événement Pendant', 'A clôture sa caisse', 'pendant_caisses',
        vaut('Caisses ouvertes : 0'), 'Caisses ouvertes : 0');

    await verifieGlisser(tester, db, 'événement Pendant', 'pendant_total');

    // --- Écran 3 : caisses en direct.
    await toucher(tester, find.byKey(const Key('voir_caisses')));
    await attendre(tester, find.byKey(const Key('direct_total')));
    await finTransition(tester);
    await verifie(tester, 'caisses en direct', 'ouverture de l’écran (état de A)',
        'statut_caisse_$caisseId', vaut('Clôturée · 1 vente · 3,00 €'),
        'Clôturée · 1 vente · 3,00 €');
    await ouvrirA(rouvrir: true);
    await verifie(tester, 'caisses en direct', 'A rouvre sa caisse',
        'statut_caisse_$caisseId', vaut('Ouverte · 1 vente · 3,00 €'),
        'Ouverte · 1 vente · 3,00 €');
    await vendreA(stock);
    stock -= 1;
    ventes += 1;
    await verifie(tester, 'caisses en direct', 'A vend (total)', 'direct_total',
        vaut('Ventes : $ventes · ${euros(300 * ventes)}'), 'Ventes : 2 · 6,00 €');
    await verifie(tester, 'caisses en direct', 'A vend (produit, stock)',
        'direct_produit_$croque',
        vaut('Croque-monsieur : $ventes vendus · stock $stock'),
        'Croque-monsieur : $ventes vendus · stock $stock');
    await verifie(tester, 'caisses en direct', 'A vend (carte de la caisse)',
        'statut_caisse_$caisseId',
        vaut('Ouverte · ${vente(ventes)} · ${euros(300 * ventes)}'),
        'Ouverte · ${vente(ventes)} · ${euros(300 * ventes)}');
    await ajouterA();
    stock += 2;
    await verifie(tester, 'caisses en direct', 'A ajoute du stock',
        'direct_produit_$croque',
        vaut('Croque-monsieur : $ventes vendus · stock $stock'),
        'Croque-monsieur : $ventes vendus · stock $stock');
    await cloturerA();
    await verifie(tester, 'caisses en direct', 'A clôture sa caisse',
        'statut_caisse_$caisseId',
        vaut('Clôturée · ${vente(ventes)} · ${euros(300 * ventes)}'),
        'Clôturée · ${vente(ventes)} · ${euros(300 * ventes)}');
    await verifieGlisser(tester, db, 'caisses en direct', 'direct_total');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);

    // --- Écran 4 : stock.
    await toucher(tester, find.byKey(const Key('voir_gymnases')));
    await attendre(tester, find.byKey(Key('gymnase_$gym')));
    await finTransition(tester);
    await verifie(tester, 'stock', 'ouverture de l’écran', 'stock_${gym}_$croque',
        vaut('Stock : $stock'), 'Stock : $stock');
    await ouvrirA(rouvrir: true);
    await vendreA(stock);
    stock -= 1;
    ventes += 1;
    await verifie(tester, 'stock', 'A vend (stock)', 'stock_${gym}_$croque',
        vaut('Stock : $stock'), 'Stock : $stock');
    await verifie(tester, 'stock', 'A vend (vendu)', 'vendu_${gym}_$croque',
        vaut('Vendu : $ventes'), 'Vendu : $ventes');
    await ajouterA();
    stock += 2;
    await verifie(tester, 'stock', 'A ajoute du stock', 'stock_${gym}_$croque',
        vaut('Stock : $stock'), 'Stock : $stock');
    await cloturerA();
    await verifieGlisser(tester, db, 'stock', 'titre_stock_evenement');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);

    // --- Écran 5 : bilan (onglet Pendant : « Bilan provisoire »).
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await finTransition(tester);
    String totalBilan() => contenuDe(tester, find.byKey(const Key('bilan_total')));
    bool bilanVaut(String s) =>
        s.contains(euros(300 * ventes)) && s.contains(vente(ventes));
    releve.add('RELEVE bilan | ouverture (information) | « ${totalBilan()} »');
    await ouvrirA(rouvrir: true);
    await verifiePresence(tester, 'bilan', 'A rouvre sa caisse : bandeau « caisses ouvertes »',
        'bilan_caisses_ouvertes', true);
    await vendreA(stock);
    stock -= 1;
    ventes += 1;
    await verifie(tester, 'bilan', 'A vend', 'bilan_total', bilanVaut,
        '${vente(ventes)} · ${euros(300 * ventes)}');
    await ajouterA();
    stock += 2;
    await cloturerA();
    await verifiePresence(tester, 'bilan', 'A clôture : plus de bandeau « caisses ouvertes »',
        'bilan_caisses_ouvertes', false);
    await verifieGlisser(tester, db, 'bilan', 'bilan_total');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);

    // --- Écran 6 : la caisse de B (stock affiché sur la tuile du produit).
    await toucher(tester, find.byKey(const Key('ouvrir_caisse_evenement')));
    await attendre(tester, find.byKey(const Key('recap_caisse')));
    await finTransition(tester);
    bool tuile(String s) => s.endsWith(': $stock');
    await verifie(tester, 'caisse', 'ouverture de l’écran', 'stock_$croque', tuile,
        '… : $stock');
    await ouvrirA(rouvrir: true);
    await vendreA(stock);
    stock -= 1;
    ventes += 1;
    await verifie(tester, 'caisse', 'A vend (stock sur la tuile)', 'stock_$croque',
        (s) => s.endsWith(': $stock'), '… : $stock');
    await ajouterA();
    stock += 2;
    await verifie(tester, 'caisse', 'A ajoute du stock (stock sur la tuile)',
        'stock_$croque', (s) => s.endsWith(': $stock'), '… : $stock');
    await cloturerA();
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);

    // --- Preuve que « actualiser » relit le SERVEUR : un troisième téléphone (le
    // responsable, sans aucun écran ouvert, donc sans écoute) a un cache vide ; après
    // l'actualisation, son cache contient les ventes de A.
    final appC = await Firebase.initializeApp(
        name: 'telephoneC', options: DefaultFirebaseOptions.android);
    final authC = FirebaseAuth.instanceFor(app: appC);
    await authC.useAuthEmulator('10.0.2.2', 9099);
    final dbC = FirebaseFirestore.instanceFor(app: appC);
    dbC.useFirestoreEmulator('10.0.2.2', 8080);
    await authC.signInWithCredential((await fauxGoogle('chef_actualisation')())!);
    final ventesC = dbC
        .collection('associations/$assoId/evenements/$evt/caisses/$caisseId/ventes');
    Future<int> enCache() async {
      try {
        return (await ventesC.get(const GetOptions(source: Source.cache))).docs.length;
      } catch (_) {
        return 0;
      }
    }

    final avant = await enCache();
    await DepotAssociations(dbC).evenements(assoId).actualiser(evt);
    final apres = await enCache();
    final relu = avant == 0 && apres == ventes;
    releve.add('RELEVE actualisation | relecture du serveur (3e téléphone, cache vide) | '
        '${relu ? 'OK ($avant vente en cache avant, $apres après)' : 'ECHEC : $avant avant, $apres après, attendu $ventes'}');
    if (!relu) echecs.add('actualisation / relecture du serveur');

    // --- Un autre téléphone clôture l'événement pendant que B regarde le bilan.
    await toucher(tester, find.byKey(const Key('voir_bilan')));
    await attendre(tester, find.byKey(const Key('bilan_total')));
    await finTransition(tester);
    await verifie(tester, 'bilan', 'avant la clôture de l’événement', 'bilan_etat',
        (s) => s.contains('provisoire'), 'Bilan provisoire');
    expect(
        await restEcrire(
            'PATCH',
            'associations/$assoId/evenements/$evt?updateMask.fieldPaths=statut',
            'owner',
            {'statut': restTexte('cloture')}),
        200);
    await verifie(tester, 'bilan', 'l’événement est clôturé ailleurs : bilan définitif',
        'bilan_etat', (s) => s.contains('définitif'), 'Bilan définitif');

    await verifieGlisser(tester, db, 'bilan', 'bilan_total');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
    await verifieGlisser(tester, db, 'événement', 'titre_evenement');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await finTransition(tester);
    await verifieGlisser(tester, db, 'association', 'code');

    for (final l in releve) {
      debugPrint(l);
    }
    expect(echecs, isEmpty, reason: 'Écrans qui ne suivent pas : $echecs');
  });
}
