import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/ecran_caisse.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/ticket.dart';

const _croque = Produit('croque', 'Croque-monsieur', 300, 2);
const _cafe = Produit('cafe', 'Café', 150);

void main() {
  group('logique', () {
    test('monnaie à rendre', () {
      expect(monnaieARendre(850, 2000), 1150);
      expect(monnaieARendre(850, 850), 0);
      expect(monnaieARendre(850, 800), isNull);
      expect(monnaieARendre(0, 500), 500);
    });

    test('un produit est identifié par son id, pas par son stock', () {
      const avant = Produit('x', 'X', 100, 5);
      const apres = Produit('x', 'X', 100, 3);
      expect(avant == apres, isTrue);
      final t = Ticket()
        ..ajouter(avant)
        ..ajouter(apres);
      expect(t.lignes.length, 1);
      expect(t.lignes[apres], 2);
    });


    test('une vente non annulée par défaut ; une annulation garde qui et quand', () {
      final v = Vente(
        id: 'a', lignes: const [], totalCentimes: 100, mode: 'carte',
        creeLe: DateTime(2026, 10, 3, 14, 5), enAttente: false);
      expect(v.annulee, isFalse);
      expect(v.corrigeDe, isNull);
      final a = Vente(
        id: 'b', lignes: const [], totalCentimes: 100, mode: 'carte',
        creeLe: DateTime(2026, 10, 3, 14, 5), enAttente: true,
        annulee: true, annuleeParPrenom: 'Lea',
        annuleeLe: DateTime(2026, 10, 3, 14, 32), corrigeDe: 'a');
      expect(a.annulee, isTrue);
      expect(a.annuleeParPrenom, 'Lea');
      expect(heureAffichee(a.annuleeLe!), '14:32');
      expect(a.corrigeDe, 'a');
    });

    test('heure affichée sur deux chiffres', () {
      expect(heureAffichee(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(heureAffichee(DateTime(2026, 1, 1, 0, 0)), '00:00');
      expect(heureAffichee(DateTime(2026, 1, 1, 23, 59)), '23:59');
    });


    Vente vente(String id, int total, String mode, {bool annulee = false}) => Vente(
          id: id,
          lignes: const [],
          totalCentimes: total,
          mode: mode,
          creeLe: DateTime(2026, 10, 3, 14, 5),
          enAttente: false,
          annulee: annulee,
        );

    test('récapitulatif de caisse : total par mode, ventes annulées exclues', () {
      final r = RecapCaisse.depuis([
        vente('a', 450, 'especes'),
        vente('b', 300, 'carte', annulee: true),
        vente('c', 300, 'carte'),
        vente('d', 100, 'especes'),
      ]);
      expect(r.nbVentes, 3);
      expect(r.nbAnnulees, 1);
      expect(r.totalCentimes, 850);
      expect(r.pour('especes'), 550);
      expect(r.pour('carte'), 300);
      expect(r.pour('cheque'), 0); // mode non utilisé
      expect(r.versDonnees(), {
        'nbVentes': 3,
        'nbAnnulees': 1,
        'totalCentimes': 850,
        'parMode': {'especes': 550, 'carte': 300},
      });
    });

    test('récapitulatif d\'une caisse sans vente, ou avec tout annulé', () {
      final vide = RecapCaisse.depuis(const []);
      expect(vide.nbVentes, 0);
      expect(vide.totalCentimes, 0);
      expect(vide.parMode, isEmpty);
      final tout = RecapCaisse.depuis([vente('a', 300, 'carte', annulee: true)]);
      expect(tout.nbVentes, 0);
      expect(tout.nbAnnulees, 1);
      expect(tout.totalCentimes, 0);
      expect(tout.pour('carte'), 0);
    });

    test('une caisse est ouverte ou clôturée', () {
      const o = Caisse(uid: 'u', gymnaseId: 'g1', prenom: 'Lea', statut: 'ouverte');
      expect(o.cloturee, isFalse);
      expect(o.recap, isNull);
      const c = Caisse(uid: 'u', gymnaseId: 'g1', prenom: 'Lea', statut: 'cloturee');
      expect(c.cloturee, isTrue);
    });

    test('un événement non clôturé n\'est pas forcé', () {
      const e = Evenement(
          id: 'a', nom: 'T', date: '2026-10-03', statut: 'en_cours',
          modes: ['carte'], menuNom: 'M');
      expect(e.forcee, isFalse);
      expect(e.nbCaissesOuvertes, 0);
      expect(e.clotureLe, isNull);
    });

    test('un ticket devient des lignes de vente figées', () {
      final t = Ticket()
        ..ajouter(_croque)
        ..ajouter(_croque)
        ..ajouter(_cafe);
      final lignes = lignesDuTicket(t);
      expect(lignes.length, 2);
      final croque = lignes.firstWhere((l) => l.produitId == 'croque');
      expect(croque.quantite, 2);
      expect(croque.prixCentimes, 300);
      expect(croque.versDonnees(), {
        'produitId': 'croque',
        'nom': 'Croque-monsieur',
        'prixCentimes': 300,
        'quantite': 2,
      });
    });
  });

  group('écran de caisse', () {
    Future<void> ouvrir(
      WidgetTester tester, {
      List<Produit> produits = const [_croque, _cafe],
      List<String> modes = const ['especes', 'carte'],
      void Function(Ticket, String, String?)? onEncaisser,
      Future<Correction?> Function()? onVoirVentes,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: EcranCaisse(
            produits: produits,
            modes: modes,
            onEncaisser: onEncaisser,
            onVoirVentes: onVoirVentes),
      ));
    }

    String total(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('total'))).data!;

    testWidgets('seuls les modes autorisés sont proposés', (tester) async {
      await ouvrir(tester, modes: const ['carte', 'cheque']);
      expect(find.byKey(const Key('encaisser_carte')), findsOneWidget);
      expect(find.byKey(const Key('encaisser_cheque')), findsOneWidget);
      expect(find.byKey(const Key('encaisser_especes')), findsNothing);
      expect(find.byKey(const Key('encaisser_autre')), findsNothing);
      // Pas d'espèces : pas de bouton monnaie.
      expect(find.byKey(const Key('monnaie')), findsNothing);
    });

    testWidgets('encaisser envoie le ticket avec le mode, puis vide le ticket',
        (tester) async {
      Ticket? recu;
      String? modeRecu;
      var total0 = 0;
      await ouvrir(tester, onEncaisser: (t, m, _) {
        recu = Ticket();
        for (final e in t.lignes.entries) {
          for (var i = 0; i < e.value; i++) {
            recu!.ajouter(e.key);
          }
        }
        total0 = t.totalCentimes;
        modeRecu = m;
      });
      // Rien à encaisser : boutons inactifs.
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('encaisser_carte')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const Key('produit_croque')));
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.pump();
      expect(total(tester), 'Total : 4,50 €');
      await tester.tap(find.byKey(const Key('encaisser_carte')));
      await tester.pump();
      expect(modeRecu, 'carte');
      expect(total0, 450);
      expect(recu!.lignes.length, 2);
      expect(total(tester), 'Total : 0,00 €');
    });

    testWidgets('stock épuisé : avertissement, mais la vente reste possible',
        (tester) async {
      await ouvrir(tester, produits: const [Produit('croque', 'Croque-monsieur', 300, 1)]);
      expect(find.text('Stock : 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('produit_croque')));
      await tester.pump();
      expect(find.byKey(const Key('alerte_stock')), findsNothing); // 1 en stock, 1 vendu
      await tester.tap(find.byKey(const Key('produit_croque')));
      await tester.pump();
      expect(find.byKey(const Key('alerte_stock')), findsOneWidget);
      expect(find.textContaining('Stock épuisé : Croque-monsieur'), findsOneWidget);
      // L'article est bien ajouté malgré l'avertissement.
      expect(total(tester), 'Total : 6,00 €');
      // L'avertissement est un message fixe : il ne recouvre pas les boutons
      // de paiement et disparaît avec le ticket.
      await tester.tap(find.byKey(const Key('encaisser_carte')));
      await tester.pump();
      expect(find.byKey(const Key('alerte_stock')), findsNothing);
      expect(total(tester), 'Total : 0,00 €');
    });

    testWidgets('un produit à stock nul est marqué « Épuisé »', (tester) async {
      await ouvrir(tester, produits: const [Produit('croque', 'Croque-monsieur', 300, 0), Produit('x', 'Négatif', 100, -2), _cafe]);
      expect(find.text('Épuisé'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('produit_croque')));
      await tester.pump();
      expect(find.byKey(const Key('alerte_stock')), findsOneWidget);
      expect(total(tester), 'Total : 3,00 €');
      // Produit sans suivi de stock : jamais d'alerte.
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.pump();
    });


    testWidgets('corriger une vente : ses articles reviennent au ticket, le lien est transmis',
        (tester) async {
      String? corrige;
      int? total0;
      await ouvrir(
        tester,
        onVoirVentes: () async => const Correction('v42', [
          LigneVente('croque', 'Croque-monsieur', 300, 2),
          LigneVente('cafe', 'Café', 150, 1),
        ]),
        onEncaisser: (t, m, c) {
          corrige = c;
          total0 = t.totalCentimes;
        },
      );
      expect(find.byKey(const Key('correction_en_cours')), findsNothing);
      await tester.tap(find.byKey(const Key('voir_ventes')));
      await tester.pumpAndSettle();
      expect(total(tester), 'Total : 7,50 €');
      expect(find.byKey(const Key('correction_en_cours')), findsOneWidget);
      // Ressaisie : on retire le café, on ajoute un croque-monsieur.
      await tester.tap(find.byKey(const Key('retirer_cafe')));
      await tester.tap(find.byKey(const Key('produit_croque')));
      await tester.pump();
      expect(total(tester), 'Total : 9,00 €');
      await tester.tap(find.byKey(const Key('encaisser_carte')));
      await tester.pump();
      expect(corrige, 'v42');
      expect(total0, 900);
      // Après encaissement, plus de correction en cours.
      expect(find.byKey(const Key('correction_en_cours')), findsNothing);
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('encaisser_carte')));
      await tester.pump();
      expect(corrige, isNull);
    });

    testWidgets('la liste des ventes annulée sans correction ne change pas le ticket',
        (tester) async {
      await ouvrir(tester, onVoirVentes: () async => null);
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voir_ventes')));
      await tester.pumpAndSettle();
      expect(total(tester), 'Total : 1,50 €');
      expect(find.byKey(const Key('correction_en_cours')), findsNothing);
    });

    testWidgets('sans liste de ventes, pas de bouton « Mes ventes »', (tester) async {
      await ouvrir(tester);
      expect(find.byKey(const Key('voir_ventes')), findsNothing);
    });


    testWidgets('caisse clôturée (verrouillée) : on regarde, on ne vend plus',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      var ventes = 0;
      await tester.pumpWidget(MaterialApp(
        home: EcranCaisse(
          produits: const [_croque, _cafe],
          modes: const ['especes', 'carte'],
          verrouillee: true,
          onEncaisser: (t, m, c) => ventes++,
        ),
      ));
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.pump();
      expect(total(tester), 'Total : 0,00 €'); // aucun article ajouté
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('encaisser_carte')))
              .onPressed,
          isNull);
      expect(ventes, 0);
    });

    testWidgets('le bouton de clôture n\'existe que si la clôture est possible',
        (tester) async {
      var ouvertures = 0;
      await ouvrir(tester);
      expect(find.byKey(const Key('ouvrir_cloture')), findsNothing);
      await tester.pumpWidget(MaterialApp(
        home: EcranCaisse(
          produits: const [_croque],
          modes: const ['carte'],
          onCloturer: () => ouvertures++,
        ),
      ));
      await tester.tap(find.byKey(const Key('ouvrir_cloture')));
      await tester.pump();
      expect(ouvertures, 1);
    });

    testWidgets('monnaie à rendre', (tester) async {
      await ouvrir(tester);
      expect(
          tester.widget<IconButton>(find.byKey(const Key('monnaie'))).onPressed,
          isNull); // ticket vide
      await tester.tap(find.byKey(const Key('produit_croque')));
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.tap(find.byKey(const Key('produit_cafe')));
      await tester.pump();
      expect(total(tester), 'Total : 6,00 €');
      await tester.tap(find.byKey(const Key('monnaie')));
      await tester.pumpAndSettle();
      String message() =>
          tester.widget<Text>(find.byKey(const Key('a_rendre'))).data!;
      expect(message(), '');
      await tester.enterText(find.byKey(const Key('somme_recue')), '20');
      await tester.pump();
      expect(message(), 'À rendre : 14,00 €');
      await tester.enterText(find.byKey(const Key('somme_recue')), '6,5');
      await tester.pump();
      expect(message(), 'À rendre : 0,50 €');
      await tester.enterText(find.byKey(const Key('somme_recue')), '5');
      await tester.pump();
      expect(message(), 'Somme insuffisante.');
      await tester.enterText(find.byKey(const Key('somme_recue')), 'abc');
      await tester.pump();
      expect(message(), 'Somme invalide (exemple : 20).');
      // La calculette n'a rien enregistré ni vidé.
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(total(tester), 'Total : 6,00 €');
    });
  });
}
