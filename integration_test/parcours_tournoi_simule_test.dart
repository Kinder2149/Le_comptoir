import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:le_comptoir/calcul_club.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_associations.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_bilan.dart';
import 'package:le_comptoir/ecran_import.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';
import 'package:le_comptoir/ticket.dart';

import 'attendus_club.dart';
import 'classeur_club_octets.dart';
import 'outils.dart';

// Mission « Calcul du club », V7 (décision 92) : simulation complète d'un tournoi sur les
// chiffres de l'an dernier, avec le vrai moteur de données local (émulateurs Firebase) et ses
// règles d'accès. Tournoi à 2 gymnases et 2 jours (samedi 14/11/2026 = jour 1, dimanche = jour 2),
// menu du club (19 produits), classeur du club importé par l'assistant.
//
//   Preuve 1 : la quantité prévue de chaque produit présent dans le classeur d'origine, par
//              gymnase et par jour, égale celle du classeur (attendus_club.dart), à l'unité
//              supérieure, et le total de chaque gymnase.
//   Preuve 2 : stock de départ (12 croques tartiflette au gymnase 1 ; 2 paquets de jambon),
//              deux séries de courses cochées puis validées, stock mis à jour, rien de ce qui est
//              en stock n'est racheté.
//   Preuve 3 : ventes tirées de la consommation de l'an passé (75 % du prévu du jour, sans hasard),
//              4 caisses (2 par gymnase), 2 jours, espèces / carte / chèque, 8 annulations, une
//              rupture, une caisse clôturée de force.
//   Preuve 4 : les totaux du Bilan (par produit, mode, caisse, jour) = somme des ventes émises,
//              faite à part ; coût = somme des deux séries ; résultat juste au centime.
// Hypothèses du parcours : « 1 paquet de jambon » = 1 unité d'ingrédient (un croque en utilise
// 0,125) ; la clôture de force est la clôture de l'événement avec la caisse d'Emma ouverte.
// Aucune capture : le parcours laisse l'émulateur dans l'état du Bilan (écran Bilan affiché).

class _Produit {
  const _Produit(this.nom, this.prix, [this.fiche = const FicheProduit(conso: 0.5)]);
  final String nom;
  final int prix;
  final FicheProduit fiche;
}

const _pain = Ingredient('Pain de mie', 2, 'tranche');
const _jambon = Ingredient('Jambon blanc', 0.125, 'unite'); // 1 unité = 1 paquet
const _menu = <_Produit>[
  _Produit('Croque-monsieur', 300, FicheProduit(type: 'compose', conso: 0.5, ingredients: [
    _pain,
    _jambon,
    Ingredient('Gruyère râpé', 16, 'g'),
  ])),
  _Produit('Croque végé', 300, FicheProduit(type: 'compose', conso: 0.5, ingredients: [
    _pain,
    Ingredient('Légumes grillés', 40, 'g'),
  ])),
  _Produit('Croque tartiflette', 350, FicheProduit(type: 'compose', conso: 0.5, ingredients: [
    _pain,
    _jambon,
    Ingredient('Reblochon', 30, 'g'),
  ])),
  _Produit('Crêpe sucre', 150, FicheProduit(type: 'compose', conso: 0.5, ingredients: [
    Ingredient('Farine', 30, 'g'),
    Ingredient('Lait', 5, 'cl'),
  ])),
  _Produit('Crêpe Nutella', 200, FicheProduit(type: 'compose', conso: 0.5, ingredients: [
    Ingredient('Farine', 30, 'g'),
    Ingredient('Lait', 5, 'cl'),
    Ingredient('Pâte à tartiner', 20, 'g'),
  ])),
  _Produit('Croque Monsieur Chocolat', 250, FicheProduit(type: 'compose', conso: 0.5, ingredients: [
    _pain,
    Ingredient('Chocolat', 20, 'g'),
  ])),
  _Produit('Mars', 100),
  _Produit('Twix', 100),
  _Produit('Barre de céréales chocolat', 100),
  _Produit('Barre de céréales fruit', 100),
  _Produit('Coca', 150),
  _Produit('Ice Tea', 150),
  _Produit('Orangina', 150),
  _Produit('Oasis', 150),
  _Produit('Bière', 250),
  _Produit('Thé', 100),
  _Produit('Infusion', 100),
  _Produit('Café', 100),
  _Produit('Fruit', 100),
];

/// Série 1 des courses (matin) : la cuisine. Série 2 (après-midi) : le reste.
const _serieMatin = {
  'Croque-monsieur',
  'Croque végé',
  'Croque tartiflette',
  'Crêpe sucre',
  'Crêpe Nutella',
  'Croque Monsieur Chocolat',
};

const _modes = ['especes', 'carte', 'cheque'];
const _coutSerie1 = 31250; // 312,50 €
const _coutSerie2 = 18075; // 180,75 €
const _dates = {1: '2026-11-14', 2: '2026-11-15'};

DateTime _quand(int jour, int rang) =>
    DateTime(2026, 11, 13 + jour, 10 + rang % 8, (rang * 7) % 60);

class _Emise {
  _Emise(this.id, this.vente);
  final String id;
  VenteSimulee vente;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiser);

  testWidgets('simulation complète du tournoi : prévision, courses, ventes, bilan', (tester) async {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    const serveur = GetOptions(source: Source.server);
    final journal = <String>[];
    final rouges = <String>[];
    void note(String ligne) => journal.add(ligne);
    void verdict(String preuve, List<String> problemes, String chiffres) {
      if (problemes.isEmpty) {
        note('PREUVE $preuve : VERT. $chiffres');
      } else {
        rouges.add(preuve);
        note('PREUVE $preuve : ROUGE (${problemes.length}). $chiffres');
        for (final p in problemes.take(30)) {
          note('   - $p');
        }
      }
    }

    await auth.signOut();
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    try {
      // ---------- 0. Association, menu du club, tournoi, import du classeur du club.
      await ouvrir(tester, 'sim_chef', fauxGoogle('chef_tournoi_sim'));
      await creerAssociationParLInterface(tester);
      final code = texte(tester, 'code');
      final chefUid = auth.currentUser!.uid;
      final assoId =
          (await db.collection('users').doc(chefUid).get()).data()!['assoId'] as String;
      await tester.pumpWidget(const SizedBox());
      final depotAsso = DepotAssociations(db);
      final menus = depotAsso.menus(assoId);
      final menuId = await menus.creerMenu('Les Discjonctés');
      for (final p in _menu) {
        await menus.ajouterProduit(menuId, nom: p.nom, prixCentimes: p.prix, fiche: p.fiche);
      }
      final depotEv = depotAsso.evenements(assoId);
      final evt = await depotEv.creerEvenement(
          nom: 'Tournoi simulé',
          date: _dates[1]!,
          menuId: menuId,
          modes: _modes,
          gymnases: gymnasesClub);
      await db.waitForPendingWrites();
      final base = 'associations/$assoId/evenements/$evt';
      final classeur = base64Decode(classeurClubBase64);
      await tester.pumpWidget(MaterialApp(
        home: EcranImport(
          sources: SourcesImport.depuis(
              menus: menus, evenements: depotEv, uid: chefUid, responsable: true),
          evenementId: evt,
          menuPropose: 'Les Discjonctés',
          choisirClasseur: () async => classeur,
        ),
      ));
      await assistantJusquAuResume(tester);
      expect(find.text('Repas : 2 jours, 2 gymnases.'), findsOneWidget);
      expect(find.text('Groupes : 7 groupes, 18 produits.'), findsOneWidget);
      await toucherCle(tester, 'appliquer_import_assistant');
      await attendre(tester, find.byKey(const Key('confirmation_import_assistant')));
      await db.waitForPendingWrites();
      await tester.pumpWidget(const SizedBox());

      await depotEv.definirJours(evt, 2.0);
      final gymnases0 = await depotEv.suivreGymnases(evt).first;
      final idG = {for (final g in gymnases0) g.nom: g.id};
      const personnes = {'Gymnase 1': 65, 'Gymnase 2': 70};
      for (final e in personnes.entries) {
        await depotEv.definirPersonnes(evt, idG[e.key]!, e.value);
      }
      await depotEv.ouvrirEvenement(evt);
      final produitsEvt = await depotEv.suivreProduits(evt).first;
      final idP = {for (final p in produitsEvt) p.nom: p.id};
      final nomDe = {for (final p in produitsEvt) p.id: p.nom};
      final prixDe = {for (final p in produitsEvt) p.nom: p.prixCentimes};
      final previsions = await depotEv.suivrePrevisions(evt).first;
      final calcul = (await depotEv.suivreCalculClub(evt).first)!;
      final caisses = depotEv.caisses(evt);

      Future<int?> stockServeur(String gymnase, String produit) async => (await db
              .doc('$base/gymnases/${idG[gymnase]}/stocks/${idP[produit]}')
              .get(serveur))
          .data()?['quantite'] as int?;

      // ---------- Preuve 1 : prévision = classeur d'origine.
      final ecarts1 = comparerAttendus(calcul: calcul, idProduit: idP, idGymnase: idG);
      // Quantité prévue d'un gymnase (comme les courses) : le calcul du club, sinon l'ancien.
      int prevue(String g, String nom) =>
          quantitePrevueClub(
              calcul: calcul,
              gymnaseId: idG[g]!,
              produitId: idP[nom]!,
              personnes: personnes[g]!,
              jours: 2.0,
              conso: previsions[idP[nom]]?.conso ?? 0.5);
      // Part d'un jour : l'attendu du classeur arrondi ; « Fruit » (hors classeur) : moitié-moitié.
      int duJour(String g, String nom, int j) {
        if (attendusClub.containsKey(nom)) return arrondiClub(attenduClub(nom, g, j));
        final t = prevue(g, nom);
        return j == 1 ? (t + 1) ~/ 2 : t ~/ 2;
      }

      var totalPrevu = 0;
      for (final g in gymnasesClub) {
        for (final p in _menu) {
          totalPrevu += prevue(g, p.nom);
        }
      }
      verdict(
          '1 (prévision = classeur)',
          [for (final e in ecarts1) e.toString()],
          '${attendusClub.length} produits x 2 gymnases x (2 jours + total) = '
          '${attendusClub.length * 2 * 3} comparaisons, croque standard G1 = '
          '${prevue('Gymnase 1', 'Croque-monsieur')} (33,32 + 36,4), total prévu $totalPrevu unités');

      // ---------- Preuve 2 : stock de départ, deux séries de courses.
      final p2 = <String>[];
      final gymnasesPers = await depotEv.suivreGymnases(evt).first;
      final prodsPrev = produitsAvecPrevisions(produitsEvt, previsions);
      final tartiflette = idP['Croque tartiflette']!;
      await depotEv.definirStock(evt, idG['Gymnase 1']!, tartiflette, 12);
      await db.waitForPendingWrites();
      final stocks0 = await depotEv.suivreStocksParGymnase(evt).first;
      final defaut1 = listeParDefaut(
          produits: prodsPrev,
          gymnases: gymnasesPers,
          jours: 2.0,
          stocks: stocks0,
          calcul: calcul);
      final matin = [
        for (final l in defaut1.lignes)
          if (_serieMatin.contains(nomDe[l.produitId])) l,
      ];
      // Stock d'ingrédient : 2 paquets de jambon (bloc « Ingrédients et emballages » = champ restes).
      const cleJambon = 'jambon blanc|unite';
      var liste1 = ListeCourses(lignes: matin, restes: const {cleJambon: 2.0});
      final ligneTart = liste1.quantite(idG['Gymnase 1']!, tartiflette);
      if (ligneTart != prevue('Gymnase 1', 'Croque tartiflette') - 12) {
        p2.add('tartiflette G1 : ligne $ligneTart, attendu ${prevue('Gymnase 1', 'Croque tartiflette') - 12}');
      }
      final achats1 = calculerAchats(prodsPrev, liste1);
      final jambon = achats1.firstWhere((a) => a.cle == cleJambon);
      final lignesJambon = liste1.lignes
          .where((l) => const {'Croque-monsieur', 'Croque tartiflette'}.contains(nomDe[l.produitId]))
          .fold<int>(0, (s, l) => s + l.quantite);
      final besoinJambon = 0.125 * lignesJambon;
      if (jambon.reste != 2.0) p2.add('jambon : reste ${jambon.reste}, attendu 2');
      if ((jambon.besoin - besoinJambon).abs() > 1e-9) {
        p2.add('jambon : besoin ${jambon.besoin}, attendu $besoinJambon');
      }
      if (jambon.aAcheter != arrondiClub(besoinJambon - 2)) {
        p2.add('jambon : à acheter ${jambon.aAcheter}, attendu ${arrondiClub(besoinJambon - 2)}');
      }
      if (arrondiClub(besoinJambon) - jambon.aAcheter != 2) {
        p2.add('jambon : le stock de 2 paquets ne diminue pas l\'achat de 2');
      }

      Future<void> cocherEtValider(ListeCourses l, int cout, String serie) async {
        final achats = calculerAchats(prodsPrev, l);
        final cles = clesArticles(achats, l.libres);
        await depotEv.enregistrerListeCourses(evt, l.avec(articles: cles));
        for (final c in cles) {
          await depotEv.cocherArticle(evt, c, true);
        }
        await db.waitForPendingWrites();
        final relue = (await depotEv.suivreListeCourses(evt).first)!;
        if (relue.coches.length != cles.length || !relue.coches.containsAll(cles)) {
          p2.add('$serie : ${relue.coches.length} cases cochées sur ${cles.length}');
        }
        final achetes = {for (final a in achats) a.cle: a.aAcheter.toDouble()};
        final rendements = [
          for (final r in calculerRendements(prodsPrev, l, achetes))
            for (final e in r.parGymnase.entries) Rendement(e.key, r.produitId, e.value),
        ];
        await depotEv.validerCourses(evt,
            liste: l, achetes: achetes, rendements: rendements, coutCentimes: cout);
        await db.waitForPendingWrites();
        note('   $serie : ${cles.length} articles cochés puis validés, coût ${formaterEuros(cout)}');
      }

      await cocherEtValider(liste1, _coutSerie1, 'série 1 (matin)');
      for (final g in gymnasesClub) {
        for (final nom in _serieMatin) {
          final vu = await stockServeur(g, nom);
          if (vu != prevue(g, nom)) p2.add('stock $nom $g après série 1 : $vu, attendu ${prevue(g, nom)}');
        }
      }
      // Série 2 : la liste repart vide ; ce qui est déjà en stock n'est pas racheté.
      final validee1 = (await depotEv.suivreListeCourses(evt).first)!;
      if (!validee1.validee) p2.add('série 1 non validée');
      await depotEv.nouvelleSerieCourses(evt, validee1);
      await db.waitForPendingWrites();
      final stocks1 = await depotEv.suivreStocksParGymnase(evt).first;
      final defaut2 = listeParDefaut(
          produits: prodsPrev,
          gymnases: gymnasesPers,
          jours: 2.0,
          stocks: stocks1,
          calcul: calcul);
      final racheteMatin = [
        for (final l in defaut2.lignes)
          if (_serieMatin.contains(nomDe[l.produitId])) '${nomDe[l.produitId]} ${l.quantite}',
      ];
      if (racheteMatin.isNotEmpty) p2.add('déjà en stock mais racheté : $racheteMatin');
      final nbReste = _menu.length - _serieMatin.length;
      if (defaut2.lignes.length != nbReste * 2) {
        p2.add('série 2 : ${defaut2.lignes.length} lignes, attendu ${nbReste * 2}');
      }
      final liste2 = validee1.nouvelleSerie().avec(lignes: defaut2.lignes);
      await cocherEtValider(liste2, _coutSerie2, 'série 2 (après-midi)');
      for (final g in gymnasesClub) {
        for (final p in _menu) {
          final vu = await stockServeur(g, p.nom);
          if (vu != prevue(g, p.nom)) p2.add('stock ${p.nom} $g final : $vu, attendu ${prevue(g, p.nom)}');
        }
      }
      final listeFinale = (await depotEv.suivreListeCourses(evt).first)!;
      if (listeFinale.seriesValidees != 2) p2.add('séries validées : ${listeFinale.seriesValidees}');
      if (listeFinale.coutTotalCentimes != _coutSerie1 + _coutSerie2) {
        p2.add('coût cumulé ${listeFinale.coutTotalCentimes}, attendu ${_coutSerie1 + _coutSerie2}');
      }
      verdict(
          '2 (stock et courses)',
          p2,
          'tartiflette G1 : stock 12, achat $ligneTart, stock final ${await stockServeur('Gymnase 1', 'Croque tartiflette')} ; '
          'jambon : besoin ${besoinJambon.toStringAsFixed(3)} paquets, stock 2, à acheter ${jambon.aAcheter} ; '
          'série 2 sans les ${_serieMatin.length} produits déjà en stock ; coût ${formaterEuros(listeFinale.coutTotalCentimes)}');

      // ---------- Preuve 3 : ventes, 4 caisses, 2 jours, annulations, rupture, clôture de force.
      final p3 = <String>[];
      final emises = <_Emise>[];
      const equipe = [
        ('Lea', 'Gymnase 1', 0),
        ('Zoe', 'Gymnase 1', 1),
        ('Tom', 'Gymnase 2', 0),
        ('Emma', 'Gymnase 2', 1),
      ];
      final idCaisses = <String, String>{};
      var nbRupture = 0;
      var stockRupture = 0;
      for (final (prenom, gym, rang) in equipe) {
        final gid = idG[gym]!;
        await auth.signOut();
        await auth.createUserWithEmailAndPassword(
            email: '${prenom.toLowerCase()}.tournoi@test.fr', password: 'secret12');
        final uid = auth.currentUser!.uid;
        await depotAsso.rejoindre(uid: uid, codeSaisi: code, prenom: prenom);
        final caisseId = idCaisse(uid, gid);
        idCaisses[prenom] = caisseId;
        await caisses.ouvrirCaisse(caisseId, prenom);
        await db.waitForPendingWrites();
        final jeton = (await auth.currentUser!.getIdToken())!;

        Future<void> vendre(int jour, int numero, List<(String, int)> lignes, String mode,
            {String? id}) async {
          final venteId = id ?? 'v${jour}_$numero';
          final lignesVente = [
            for (final (nom, q) in lignes) LigneVente(idP[nom]!, nom, prixDe[nom]!, q),
          ];
          final total = lignesVente.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite);
          final baisses = <String, int>{};
          for (final l in lignesVente) {
            baisses[l.produitId] = (baisses[l.produitId] ?? 0) + l.quantite;
          }
          Future<String?> envoyer() => restVenteAvecStock(
                base: base,
                caisseId: caisseId,
                venteId: venteId,
                gymnaseId: gid,
                jeton: jeton,
                champsVente: restVente([
                  for (final l in lignesVente)
                    restLigne(l.produitId, l.nom, l.prixCentimes, l.quantite),
                ], total, mode, _quand(jour, numero), gid),
                baisses: baisses,
              );
          var refus = await envoyer();
          // Les règles lisent le pointeur de caisse qui vient d'être écrit : un refus « valeur
          // nulle » juste après l'ouverture est un délai de l'émulateur, on renvoie (et on le dit).
          for (var essai = 1; refus != null && essai <= 3; essai++) {
            await Future<void>.delayed(const Duration(milliseconds: 800));
            note('   renvoi $essai de la vente $venteId de $prenom après : ${refus.length > 90 ? refus.substring(0, 90) : refus}');
            refus = await envoyer();
          }
          if (refus != null) {
            p3.add('vente $venteId de $prenom refusée : $refus');
            return;
          }
          emises.add(_Emise(
              venteId,
              VenteSimulee(
                  caisseId: caisseId,
                  gymnaseId: gid,
                  date: _dates[jour]!,
                  mode: mode,
                  lignes: lignesVente)));
        }

        // Ventes d'un jour : 75 % du prévu du jour, partagé entre les 2 caisses du gymnase,
        // en morceaux de 4 au plus, 3 lignes par vente, mode de paiement en rotation.
        for (final jour in [1, 2]) {
          final morceaux = <(String, int)>[];
          for (final p in _menu) {
            final vendu = duJour(gym, p.nom, jour) * 3 ~/ 4;
            var part = rang == 0 ? (vendu + 1) ~/ 2 : vendu ~/ 2;
            while (part > 0) {
              final q = part > 4 ? 4 : part;
              morceaux.add((p.nom, q));
              part -= q;
            }
          }
          var numero = 0;
          for (var i = 0; i < morceaux.length; i += 3) {
            await vendre(jour, numero, morceaux.sublist(i, (i + 3).clamp(0, morceaux.length)),
                _modes[(numero + jour) % 3]);
            numero++;
          }
        }

        // Deux annulations tracées par caisse (la vente reste, les quantités reviennent au stock).
        for (final cible in ['v1_1', 'v2_4']) {
          final e = emises.firstWhere((x) => x.id == cible && x.vente.caisseId == caisseId);
          final vente = (await caisses
                  .suivreVentes(caisseId)
                  .firstWhere((l) => l.any((v) => v.id == cible))
                  .timeout(const Duration(seconds: 30)))
              .firstWhere((v) => v.id == cible);
          caisses.annulerVente(caisseId, vente,
              parUid: uid,
              parPrenom: prenom,
              stocks: {for (final id in idP.values) id: 1});
          await db.waitForPendingWrites();
          e.vente = e.vente.annuler();
        }

        // Rupture : Zoe (dernière du gymnase 1) vend tout ce qui reste de croque tartiflette,
        // puis 3 de plus (la vente passe quand même, le stock passe sous zéro).
        if (gym == 'Gymnase 1' && rang == 1) {
          final reste = (await stockServeur(gym, 'Croque tartiflette'))!;
          await vendre(2, 90, [('Croque tartiflette', reste)], 'especes', id: 'rupture_a');
          final apres0 = await stockServeur(gym, 'Croque tartiflette');
          if (etatStock(quantite: apres0, reference: 100) != EtatStock.epuise) {
            p3.add('rupture : stock $apres0 après avoir tout vendu, attendu épuisé');
          }
          await vendre(2, 91, [('Croque tartiflette', 3)], 'carte', id: 'rupture_b');
          stockRupture = (await stockServeur(gym, 'Croque tartiflette'))!;
          nbRupture = reste + 3;
          if (stockRupture != -3) p3.add('rupture : stock final $stockRupture, attendu -3');
        }

        // Clôture normale des trois premières caisses ; celle d'Emma reste ouverte.
        if (prenom != 'Emma') {
          final recap = await caisses.cloturerCaisse(caisseId);
          final siennes =
              SommesVentes([for (final e in emises) if (e.vente.caisseId == caisseId) e.vente]);
          if (recap == null ||
              recap.nbVentes != siennes.nbVentes ||
              recap.totalCentimes != siennes.totalCentimes ||
              recap.nbAnnulees != 2) {
            p3.add('clôture de $prenom : récapitulatif ${recap?.nbVentes} ventes / '
                '${recap?.totalCentimes} c, attendu ${siennes.nbVentes} / ${siennes.totalCentimes}');
          }
        }
      }

      // Contrôle des stocks : prévu - ventes non annulées, produit par produit.
      for (final g in gymnasesClub) {
        for (final p in _menu) {
          final vendus = emises
              .where((e) => !e.vente.annulee && e.vente.gymnaseId == idG[g])
              .expand((e) => e.vente.lignes)
              .where((l) => l.produitId == idP[p.nom])
              .fold<int>(0, (s, l) => s + l.quantite);
          final attendu = prevue(g, p.nom) - vendus;
          final vu = await stockServeur(g, p.nom);
          if (vu != attendu) p3.add('stock ${p.nom} $g : $vu, attendu $attendu');
        }
      }

      // Le responsable revient : clôture de force (la caisse d'Emma est encore ouverte).
      await auth.signOut();
      await auth.signInWithCredential((await fauxGoogle('chef_tournoi_sim')())!);
      if (auth.currentUser!.uid != chefUid) p3.add('le responsable n\'a pas retrouvé son compte');
      await depotEv.cloturerEvenement(evt,
          parUid: chefUid, parPrenom: 'Chef', nbCaissesOuvertes: 1);
      final evtDoc = (await db.doc(base).get(serveur)).data()!;
      if (evtDoc['statut'] != 'cloture' || evtDoc['forcee'] != true) {
        p3.add('clôture forcée : statut ${evtDoc['statut']}, forcée ${evtDoc['forcee']}');
      }
      final sommes = SommesVentes([for (final e in emises) e.vente]);
      if (sommes.nbAnnulees != 8) p3.add('annulations : ${sommes.nbAnnulees}, attendu 8');
      if (sommes.parMode.length != 3) p3.add('modes utilisés : ${sommes.parMode.keys}');
      if (sommes.parJour.length != 2) p3.add('jours : ${sommes.parJour.keys}');
      verdict(
          '3 (ventes)',
          p3,
          '${emises.length} ventes émises (${sommes.nbVentes} comptées, ${sommes.nbAnnulees} annulées), '
          '4 caisses, 2 jours, modes ${sommes.parMode}, rupture tartiflette G1 ($nbRupture vendus pour '
          'le reste + 3, stock final $stockRupture), caisse d\'Emma clôturée de force');

      // ---------- Preuve 4 : le Bilan = la somme des ventes, faite à part.
      final p4 = <String>[];
      final tableau = await caisses.lireTableauDeBord();
      final produitsFin = await depotEv.suivreProduits(evt).first;
      final stocksFin = await depotEv.suivreStocksParGymnase(evt).first;
      final bilan = Bilan.depuis(tableau, produitsFin, _modes, stocks: stocksFin);
      p4.addAll(comparerBilan(sommes, bilan));
      final cout = _coutSerie1 + _coutSerie2;
      final resultat = sommes.totalCentimes - cout;
      final evenement = (await depotEv.suivreEvenement(evt).first)!;
      await tester.pumpWidget(MaterialApp(
        home: EcranBilan(
          evenement: evenement,
          tableau: caisses.suivreTableauDeBord(),
          produits: depotEv.suivreProduits(evt),
          gymnases: depotEv.suivreGymnases(evt),
          stocks: depotEv.suivreStocksParGymnase(evt),
          stocksReference: depotEv.suivreStocksReference(evt),
          courses: depotEv.suivreListeCourses(evt),
          partager: (n, o, m) async {},
        ),
      ));
      await attendre(tester, find.byKey(const Key('bilan_cout')));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final attenduTotal =
          'Total des ventes | ${formaterEuros(sommes.totalCentimes)} | ${pluriel(sommes.nbVentes, 'vente')}';
      if (contenuDe(tester, find.byKey(const Key('bilan_total'))) != attenduTotal) {
        p4.add('écran : « ${contenuDe(tester, find.byKey(const Key('bilan_total')))} », attendu « $attenduTotal »');
      }
      if (texte(tester, 'bilan_cout') != 'Coût des courses : ${formaterEuros(cout)}') {
        p4.add('écran coût : « ${texte(tester, 'bilan_cout')} »');
      }
      if (texte(tester, 'bilan_resultat') != 'Résultat : ${formaterEuros(resultat)}') {
        p4.add('écran résultat : « ${texte(tester, 'bilan_resultat')} », attendu ${formaterEuros(resultat)}');
      }
      for (final m in _modes) {
        final cle = 'bilan_mode_$m';
        if (find.byKey(Key(cle)).evaluate().isEmpty) {
          p4.add('écran : pas de ligne $cle');
        }
      }
      verdict(
          '4 (bilan)',
          p4,
          'total ${formaterEuros(sommes.totalCentimes)} en ${sommes.nbVentes} ventes ; '
          'modes ${sommes.parMode.map((k, v) => MapEntry(k, formaterEuros(v)))} ; '
          'jours ${sommes.parJour.map((k, v) => MapEntry(k, formaterEuros(v[1])))} ; '
          '${sommes.parCaisse.length} caisses, ${sommes.parProduit.length} produits ; '
          'coût ${formaterEuros(cout)} ; résultat ${formaterEuros(resultat)}');
    } finally {
      debugPrint('===== JOURNAL DE LA SIMULATION (V7) =====');
      for (final l in journal) {
        debugPrint(l);
      }
      debugPrint('===== FIN DU JOURNAL : ${rouges.isEmpty ? 'TOUT VERT' : 'ROUGE : ${rouges.join(' | ')}'} =====');
    }
    expect(rouges, isEmpty, reason: 'preuves rouges : ${rouges.join(', ')}');
  });
}
