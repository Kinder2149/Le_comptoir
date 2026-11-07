import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';

void main() {
  test("modes de paiement : liste fixe de 4, libellés dans l'ordre fixe", () {
    expect(modesPaiement.keys, ['especes', 'carte', 'cheque', 'autre']);
    expect(libelleModes(['carte', 'especes']), 'Espèces, Carte');
    expect(libelleModes(['autre']), 'Autre');
    expect(libelleModes([]), '');
    expect(libelleModes(['bitcoin']), '');
  });

  test('date stockée AAAA-MM-JJ', () {
    expect(dateIso(DateTime(2026, 10, 3)), '2026-10-03');
    expect(dateIso(DateTime(2026, 1, 9)), '2026-01-09');
    expect(dateDepuisIso('2026-10-03'), DateTime(2026, 10, 3));
    expect(dateDepuisIso('3/10/2026'), isNull);
    expect(dateDepuisIso(''), isNull);
  });

  test('date affichée JJ/MM/AAAA', () {
    expect(dateAffichee('2026-10-03'), '03/10/2026');
    expect(dateAffichee('texte libre'), 'texte libre');
  });

  test('un événement est en cours ou clôturé', () {
    const e = Evenement(
        id: 'a',
        nom: 'T',
        date: '2026-10-03',
        statut: 'en_cours',
        modes: ['carte'],
        menuNom: 'M');
    expect(e.enCours, isTrue);
    const f = Evenement(
        id: 'a',
        nom: 'T',
        date: '2026-10-03',
        statut: 'cloture',
        modes: ['carte'],
        menuNom: 'M');
    expect(f.enCours, isFalse);
  });

  test('trois états : en préparation, en cours, clôturé (un seul à la fois)', () {
    Evenement avec(String statut) => Evenement(
        id: 'a', nom: 'T', date: '2026-10-03', statut: statut,
        modes: const ['carte'], menuNom: 'M');
    final prep = avec('en_preparation');
    expect([prep.enPreparation, prep.enCours, prep.cloture], [true, false, false]);
    final cours = avec('en_cours');
    expect([cours.enPreparation, cours.enCours, cours.cloture], [false, true, false]);
    final clos = avec('cloture');
    expect([clos.enPreparation, clos.enCours, clos.cloture], [false, false, true]);
  });

  group("ouvrir l'événement (qui peut)", () {
    Evenement avec(String statut) => Evenement(
        id: 'a', nom: 'T', date: '2026-10-03', statut: statut,
        modes: const ['carte'], menuNom: 'M', nbGymnases: 2);
    const responsable =
        PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2);
    const tous = PorteeGestion(responsable: false, gymnases: {'g1', 'g2'}, nbGymnases: 2);
    const partiel = PorteeGestion(responsable: false, gymnases: {'g1'}, nbGymnases: 2);
    const aucun = PorteeGestion(responsable: false, gymnases: {}, nbGymnases: 2);

    test('responsable ou gestionnaire rattaché à tous les gymnases, en préparation seulement', () {
      expect(peutOuvrirEvenement(avec('en_preparation'), responsable), isTrue);
      expect(peutOuvrirEvenement(avec('en_preparation'), tous), isTrue);
      expect(peutOuvrirEvenement(avec('en_preparation'), partiel), isFalse);
      expect(peutOuvrirEvenement(avec('en_preparation'), aucun), isFalse);
    });

    test('déjà en cours ou clôturé : rien à ouvrir', () {
      expect(peutOuvrirEvenement(avec('en_cours'), responsable), isFalse);
      expect(peutOuvrirEvenement(avec('cloture'), responsable), isFalse);
    });
  });

  group("état d'un événement", () {
    Evenement evStatut(String id, String statut) => Evenement(
        id: id,
        nom: id,
        date: '2026-10-03',
        statut: statut,
        modes: const ['carte'],
        menuNom: 'M');

    test('liste : en cours, puis en préparation, puis clôturés', () {
      final tries = trierEvenements([
        evStatut('c', 'cloture'),
        evStatut('p', 'en_preparation'),
        evStatut('e', 'en_cours'),
      ]);
      expect(tries.map((e) => e.id), ['e', 'p', 'c']);
    });

    Evenement ev(String id, String nom, String date, bool enCours) => Evenement(
        id: id,
        nom: nom,
        date: date,
        statut: enCours ? 'en_cours' : 'cloture',
        modes: const ['carte'],
        menuNom: 'M');

    test("en cours d'abord, puis les plus récents", () {
      final tries = trierEvenements([
        ev('a', 'Ancien clôturé', '2026-09-01', false),
        ev('b', 'Récent clôturé', '2026-10-02', false),
        ev('c', 'Vieux en cours', '2026-08-01', true),
        ev('d', 'Récent en cours', '2026-10-03', true),
      ]);
      expect(tries.map((e) => e.id), ['d', 'c', 'b', 'a']);
    });

    test('à égalité de date, par nom', () {
      final tries = trierEvenements([
        ev('b', 'Zèbre', '2026-10-03', true),
        ev('a', 'abeille', '2026-10-03', true),
      ]);
      expect(tries.map((e) => e.id), ['a', 'b']);
    });

    test("ne modifie pas la liste d'origine, accepte une liste vide", () {
      final origine = [ev('a', 'A', '2026-01-01', false), ev('b', 'B', '2026-01-02', true)];
      trierEvenements(origine);
      expect(origine.first.id, 'a');
      expect(trierEvenements(const []), isEmpty);
    });

    testWidgets('la pastille dit « En préparation » (couleur d’attention)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PastilleEtat(key: Key('p'), enCours: false, enPreparation: true),
        ),
      ));
      expect(find.descendant(of: find.byKey(const Key('p')), matching: find.text('En préparation')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('p')), matching: find.text('En cours')),
          findsNothing);
      expect(find.descendant(of: find.byKey(const Key('p')), matching: find.byIcon(Icons.edit_calendar)),
          findsOneWidget);
    });

    testWidgets('la pastille dit « En cours » ou « Clôturé »', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            PastilleEtat(key: Key('a'), enCours: true),
            PastilleEtat(key: Key('b'), enCours: false),
          ]),
        ),
      ));
      expect(find.descendant(of: find.byKey(const Key('a')), matching: find.text('En cours')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('a')), matching: find.byIcon(Icons.play_circle)),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('b')), matching: find.text('Clôturé')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('b')), matching: find.byIcon(Icons.lock)),
          findsOneWidget);
    });
  });
}
