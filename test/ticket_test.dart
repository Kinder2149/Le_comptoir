import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/ticket.dart';

void main() {
  const a = Produit('a', 'A', 250);
  const b = Produit('b', 'B', 199);

  test('ticket vide : total à zéro', () {
    final t = Ticket();
    expect(t.estVide, isTrue);
    expect(t.totalCentimes, 0);
  });

  test('plusieurs articles et le même plusieurs fois', () {
    final t = Ticket()
      ..ajouter(a)
      ..ajouter(a)
      ..ajouter(b);
    expect(t.lignes[a], 2);
    expect(t.totalCentimes, 699);
  });

  test('retirer décrémente puis supprime la ligne', () {
    final t = Ticket()
      ..ajouter(a)
      ..ajouter(a)
      ..retirer(a);
    expect(t.lignes[a], 1);
    t.retirer(a);
    expect(t.estVide, isTrue);
    t.retirer(a); // retirer un produit absent ne casse rien
    expect(t.totalCentimes, 0);
  });

  test('remise à zéro', () {
    final t = Ticket()
      ..ajouter(a)
      ..ajouter(b)
      ..vider();
    expect(t.estVide, isTrue);
    expect(t.totalCentimes, 0);
  });

  test('formatage en euros', () {
    expect(formaterEuros(0), '0,00 €');
    expect(formaterEuros(5), '0,05 €');
    expect(formaterEuros(350), '3,50 €');
    expect(formaterEuros(1205), '12,05 €');
  });

  test('le menu générique contient les 9 produits attendus', () {
    expect(menuGenerique.length, 9);
    expect(menuGenerique.map((p) => p.id).toSet().length, 9);
  });

  test('saisie du prix : formats acceptés', () {
    expect(parserPrix('2,50'), 250);
    expect(parserPrix('2.50'), 250);
    expect(parserPrix('2,5'), 250);
    expect(parserPrix('2.05'), 205);
    expect(parserPrix('3'), 300);
    expect(parserPrix(' 12 '), 1200);
    expect(parserPrix('0'), 0);
    expect(parserPrix('0,10'), 10);
    expect(parserPrix('999,99'), 99999);
  });

  test('saisie du prix : formats refusés', () {
    for (final faux in ['', 'abc', '-1', '2,555', '2,', ',5', '1000', '2 €', '1,2,3']) {
      expect(parserPrix(faux), isNull, reason: '"$faux"');
    }
  });

  test('prix -> champ de saisie -> prix', () {
    for (final c in [0, 5, 100, 250, 99999]) {
      expect(parserPrix(prixPourSaisie(c)), c);
    }
  });
}
