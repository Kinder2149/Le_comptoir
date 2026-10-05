import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/ecran_evenement.dart';
import 'package:le_comptoir/evenement.dart';

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

  group("état d'un événement", () {
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
