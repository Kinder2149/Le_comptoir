import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/mesure.dart' as mesure;
import 'package:flutter/services.dart' show rootBundle;

import 'outils.dart';

// Chantier Stock et courses, étape 8 : mesure des lectures Firestore du suivi en
// direct (quota gratuit : 50 000 lectures par jour). Les ventes de la journée sont
// posées par l'administrateur de la copie locale ; le test compte les documents que
// reçoivent les écoutes d'un téléphone de gestion et d'un téléphone de caisse.
//
// Le test échoue seulement si une mesure est incohérente (une écoute qui ne lit rien) ;
// les chiffres sont affichés (lignes « MESURE ») et reportés dans PLAN_STOCK_COURSES.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  const gymnasesNoms = ['Gymnase A', 'Gymnase B', 'Gymnase C'];
  const ventesInitiales = 600;
  const ventesEnDirect = 60;

  final lectures = <String, int>{};
  void remettreAZero() => lectures.clear();
  int total() => lectures.values.fold<int>(0, (a, b) => a + b);
  void afficher(String titre) {
    final detail = (lectures.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    debugPrint('MESURE $titre : ${total()} lectures ($detail)');
  }

  Future<void> attendreUnPeu(WidgetTester tester, [int secondes = 4]) async {
    for (var i = 0; i < secondes * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('lectures du suivi en direct : une journée simulée', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    mesure.surLecture = (source, n) => lectures[source] = (lectures[source] ?? 0) + n;
    addTearDown(() => mesure.surLecture = null);
    await auth.signOut();

    // --- Préparation : modèle de 27 produits, 3 gymnases, 8 produits suivis par gymnase.
    await ouvrir(tester, 'responsable', fauxGoogle('chef_lectures'));
    await creerAssociationParLInterface(tester);
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
      gymnases: gymnasesNoms,
    );
    final gymnases = await depotEv.suivreGymnases(evtId).first;
    final produits = await depotEv.suivreProduits(evtId).first;
    final suivis = produits.take(8).toList();
    for (final g in gymnases) {
      for (final p in suivis) {
        await depotEv.definirStock(evtId, g.id, p.id, 300);
      }
    }

    // --- 6 caisses (2 par gymnase) et 600 ventes de 3 lignes, posées par l'administrateur.
    final base = 'associations/$assoId/evenements/$evtId';
    final caisses = <(String, String)>[]; // (uid, gymnase)
    for (var i = 0; i < 6; i++) {
      final g = gymnases[i % 3].id;
      final uid = 'membre$i';
      caisses.add((uid, g));
      expect(
          await restEcrire('PATCH', '$base/caisses/${uid}__$g', 'owner', {
            'prenom': restTexte('Membre $i'),
            'statut': restTexte('ouverte'),
            'ouverteLe': restTs(DateTime.now().subtract(const Duration(hours: 3))),
            'membreUid': restTexte(uid),
            'gymnaseId': restTexte(g),
          }),
          200);
    }
    var compteurVentes = 0;
    Future<void> poserVente() async {
      final (uid, g) = caisses[compteurVentes % caisses.length];
      final lignes = [
        for (var k = 0; k < 3; k++)
          restLigne(suivis[(compteurVentes + k) % suivis.length].id,
              suivis[(compteurVentes + k) % suivis.length].nom, 200, 1),
      ];
      expect(
          await restEcrire('POST', '$base/caisses/${uid}__$g/ventes', 'owner',
              restVente(lignes, 600, 'especes', DateTime.now(), g)),
          200);
      // Les trois baisses de stock de la vente.
      for (var k = 0; k < 3; k++) {
        final p = suivis[(compteurVentes + k) % suivis.length];
        expect(
            await restEcrire(
                'PATCH',
                '$base/gymnases/$g/stocks/${p.id}?updateMask.fieldPaths=quantite',
                'owner',
                {'quantite': restEntier(300 - (compteurVentes ~/ 6) - 1)}),
            200);
      }
      compteurVentes++;
    }

    for (var i = 0; i < ventesInitiales; i++) {
      await poserVente();
    }

    // --- 1. Téléphone de GESTION : ouverture de l'écran de l'événement (suivi en direct).
    await auth.signOut();
    await auth.signInWithCredential((await fauxGoogle('chef_lectures')())!);
    expect(auth.currentUser!.uid, chefUid);
    remettreAZero();
    await ouvrir(tester, 'chef', googleAnnule);
    await attendre(tester, find.text('Tournoi'));
    await tester.tap(find.text('Tournoi'));
    await attendre(tester, find.byKey(const Key('suivi_en_direct')));
    await attendreUnPeu(tester, 8);
    afficher('gestion, ouverture du suivi ($ventesInitiales ventes déjà faites)');
    final ouvertureGestion = total();
    expect(ouvertureGestion, greaterThan(ventesInitiales));

    remettreAZero();
    for (var i = 0; i < ventesEnDirect; i++) {
      await poserVente();
    }
    await attendreUnPeu(tester, 6);
    afficher('gestion, $ventesEnDirect ventes en direct');
    final directGestion = total();
    debugPrint('MESURE gestion : ${(directGestion / ventesEnDirect).toStringAsFixed(2)} lectures par vente en direct');

    // --- 2. Téléphone de CAISSE (gymnase A) : ses propres écoutes.
    await tester.pumpWidget(const SizedBox());
    await attendreUnPeu(tester, 2);
    final gA = gymnases.first.id;
    final (uidA, _) = caisses.firstWhere((c) => c.$2 == gA);
    final depotCaisses = depotEv.caisses(evtId);
    remettreAZero();
    final abonnements = [
      depotEv.suivreProduits(evtId, gymnaseId: gA).listen((_) {}),
      depotEv.suivreEtats(evtId, gymnases: {gA}).listen((_) {}),
      depotCaisses.suivreVentes(idCaisse(uidA, gA)).listen((_) {}),
      depotCaisses.suivreCaisse(idCaisse(uidA, gA)).listen((_) {}),
    ];
    await attendreUnPeu(tester, 6);
    afficher('caisse, ouverture (ventes de sa caisse : ${(ventesInitiales + ventesEnDirect) ~/ 6})');
    final ouvertureCaisse = total();
    // Le cache du téléphone est déjà chaud (même application) : l'ouverture n'est pas
    // mesurable ici, elle est égale au nombre de documents des écoutes (produits,
    // stocks, signaux, sa caisse et ses ventes), indiqué dans PLAN_STOCK_COURSES.md.

    remettreAZero();
    for (var i = 0; i < ventesEnDirect; i++) {
      await poserVente();
    }
    await attendreUnPeu(tester, 6);
    afficher('caisse, $ventesEnDirect ventes de toute la salle ($ventesEnDirect/3 dans son gymnase)');
    debugPrint('MESURE caisse : ${(total() / (ventesEnDirect / 3)).toStringAsFixed(2)} lectures par vente de son gymnase');
    for (final a in abonnements) {
      await a.cancel();
    }
    debugPrint('MESURE fin : ouvertureGestion=$ouvertureGestion directGestion=$directGestion '
        'ouvertureCaisse=$ouvertureCaisse ventes=$compteurVentes');
  });
}
