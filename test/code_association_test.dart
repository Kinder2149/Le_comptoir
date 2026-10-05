import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/code_association.dart';

void main() {
  test('un code généré a 6 caractères valides', () {
    for (var i = 0; i < 200; i++) {
      final code = genererCode();
      expect(code.length, 6);
      expect(codeBienForme(code), isTrue, reason: code);
    }
  });

  test('les codes ne contiennent pas de caractères ambigus', () {
    for (final c in ['0', 'O', '1', 'I', 'L']) {
      expect(alphabetCode.contains(c), isFalse, reason: c);
    }
  });

  test('génération reproductible avec un hasard fixé, variée sinon', () {
    expect(genererCode(Random(1)), genererCode(Random(1)));
    final codes = {for (var i = 0; i < 100; i++) genererCode()};
    expect(codes.length, greaterThan(95));
  });

  test('normalisation de la saisie', () {
    expect(normaliserCode(' ab c-d '), 'ABC-D');
    expect(normaliserCode('abc 234'), 'ABC234');
  });

  test('codeBienForme refuse les codes faux', () {
    expect(codeBienForme('ABC23'), isFalse);
    expect(codeBienForme('ABC2345'), isFalse);
    expect(codeBienForme('ABC0DE'), isFalse);
    expect(codeBienForme('abc234'), isFalse);
    expect(codeBienForme('ABC234'), isTrue);
  });

  test('suppression : il faut retaper le nom de l\'association', () {
    expect(confirmationSuppression('Club de foot', 'Club de foot'), isTrue);
    expect(confirmationSuppression('club de foot', 'Club de foot'), isTrue); // majuscules
    expect(confirmationSuppression('  Club de foot  ', 'Club de foot'), isTrue); // espaces autour
    expect(confirmationSuppression('Club', 'Club de foot'), isFalse); // incomplet
    expect(confirmationSuppression('Club de foot 2', 'Club de foot'), isFalse);
    expect(confirmationSuppression('Club  de foot', 'Club de foot'), isFalse); // espace en trop au milieu
    expect(confirmationSuppression('', 'Club de foot'), isFalse);
    expect(confirmationSuppression('', ''), isFalse); // jamais vrai sur un nom vide
    expect(confirmationSuppression('   ', '   '), isFalse);
  });
}
