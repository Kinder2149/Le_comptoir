import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/gymnase.dart';

void main() {
  group('identifiant de caisse', () {
    test('uid et gymnase se retrouvent après aller-retour', () {
      final id = idCaisse('Abc123', 'G9x');
      expect(id, 'Abc123__G9x');
      final ref = RefCaisse.lire(id);
      expect((ref.uid, ref.gymnaseId, ref.id), ('Abc123', 'G9x', id));
    });

    test('un identifiant mal formé est refusé', () {
      for (final mauvais in [
        '',
        'abc',
        'abc__',
        '__g1',
        'a__b__c',
        'a_b__g1',
        'ab c__g1',
        'a/b__g1',
        'ancienUid', // caisse d'avant les gymnases
      ]) {
        expect(() => RefCaisse.lire(mauvais), throwsFormatException,
            reason: mauvais);
      }
    });

    test('le gymnase par défaut s\'appelle Principal', () {
      expect(nomGymnaseParDefaut, 'Principal');
    });
  });

  group('noms de gymnases', () {
    test('des noms corrects sont acceptés', () {
      expect(erreurNomsGymnases(['Principal']), isNull);
      expect(erreurNomsGymnases(['Gymnase A', 'Gymnase B']), isNull);
      expect(erreurNomsGymnases(['x' * 40]), isNull);
    });

    test('au moins un gymnase', () {
      expect(erreurNomsGymnases([]), 'Il faut au moins un gymnase.');
    });

    test('un nom vide est refusé', () {
      expect(erreurNomsGymnases(['A', '']), 'Donnez un nom à chaque gymnase.');
      expect(erreurNomsGymnases(['  ']), 'Donnez un nom à chaque gymnase.');
    });

    test('41 caractères : trop long', () {
      expect(erreurNomsGymnases(['x' * 41]),
          'Un nom de gymnase fait 40 caractères au maximum.');
    });

    test('deux noms identiques (casse et espaces ignorés) sont refusés', () {
      const msg = 'Deux gymnases ne peuvent pas porter le même nom.';
      expect(erreurNomsGymnases(['Nord', 'Nord']), msg);
      expect(erreurNomsGymnases(['Nord', ' nord ']), msg);
    });
  });

  test('huit gymnases au plus', () {
    expect(erreurNomsGymnases([for (var i = 0; i < 8; i++) 'G$i']), isNull);
    expect(erreurNomsGymnases([for (var i = 0; i < 9; i++) 'G$i']),
        '8 gymnases au maximum par événement.');
  });

  group('portée d’un membre de la gestion', () {
    test('le responsable gère et voit tout', () {
      const p = PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 3);
      expect(p.gere('a'), isTrue);
      expect(p.toutVoir, isTrue);
      expect(p.aucun, isFalse);
      expect(p.filtre, isNull); // une seule requête, sans filtre
    });

    test('un gestionnaire ne gère que ses gymnases', () {
      const p =
          PorteeGestion(responsable: false, gymnases: {'a'}, nbGymnases: 2);
      expect(p.gere('a'), isTrue);
      expect(p.gere('b'), isFalse);
      expect(p.toutVoir, isFalse); // pas de clôture ni de vue commune
      expect(p.filtre, {'a'});
    });

    test('rattaché à tous les gymnases : il voit tout', () {
      const p =
          PorteeGestion(responsable: false, gymnases: {'a', 'b'}, nbGymnases: 2);
      expect(p.toutVoir, isTrue);
    });

    test('un gestionnaire sans gymnase ne voit rien', () {
      const p = PorteeGestion(responsable: false, gymnases: {}, nbGymnases: 2);
      expect(p.aucun, isTrue);
      expect(p.toutVoir, isFalse);
      expect(p.gere('a'), isFalse);
    });
  });

  group('vues distincte et commune', () {
    const a = Gymnase('g1', 'Gymnase A');
    const b = Gymnase('g2', 'Gymnase B');

    test('vue par défaut : la commune si elle est offerte, sinon le premier gymnase', () {
      expect(vueParDefaut(commun: true, gymnases: [a, b]), isNull);
      expect(vueParDefaut(commun: false, gymnases: [b, a]), 'g2');
      expect(vueParDefaut(commun: false, gymnases: []), isNull);
    });

    test('une vue qui n’existe plus (ou pas offerte) n’est pas valide', () {
      expect(vueValide(null, commun: true, gymnases: [a, b]), isTrue);
      expect(vueValide(null, commun: false, gymnases: [a, b]), isFalse);
      expect(vueValide('g1', commun: false, gymnases: [a, b]), isTrue);
      expect(vueValide('g9', commun: true, gymnases: [a, b]), isFalse);
    });

    test('détail du stock par gymnase, dans l’ordre des gymnases', () {
      expect(detailStockAffiche({'g2': 3, 'g1': 4}, [a, b]),
          '(Gymnase A : 4 · Gymnase B : 3)');
      expect(detailStockAffiche({'g2': 3}, [a, b]), '(Gymnase B : 3)');
      expect(detailStockAffiche({}, [a, b]), '');
    });
  });

  group('QR code d’un gymnase', () {
    const lien = LienGymnase('AB12CD', 'evtAbc123', 'gymXyz789');

    test('le texte du QR a le format prévu', () {
      expect(ecrireLienGymnase(lien),
          'lecomptoir://rejoindre?v=1&c=AB12CD&e=evtAbc123&g=gymXyz789');
    });

    test('aller-retour : on relit ce qu’on a écrit', () {
      expect(lireLienGymnase(ecrireLienGymnase(lien)), lien);
    });

    test('le code est relu en majuscules, les espaces autour sont ignorés', () {
      expect(
          lireLienGymnase(
              '  lecomptoir://rejoindre?v=1&c=ab12cd&e=evtAbc123&g=gymXyz789  '),
          lien);
    });

    test('l’ordre des champs ne compte pas', () {
      expect(
          lireLienGymnase(
              'lecomptoir://rejoindre?g=gymXyz789&e=evtAbc123&c=AB12CD&v=1'),
          lien);
    });

    test('des contenus qui ne sont pas des QR du Comptoir sont refusés', () {
      for (final mauvais in [
        '',
        'bonjour',
        'https://exemple.fr/?c=AB12CD&e=a&g=b&v=1',
        'lecomptoir://autre?v=1&c=AB12CD&e=a&g=b',
        'lecomptoir://rejoindre',
        'lecomptoir://rejoindre?c=AB12CD&e=a&g=b', // sans version
        'lecomptoir://rejoindre?v=2&c=AB12CD&e=a&g=b', // autre version
        'lecomptoir://rejoindre?v=1&c=AB12&e=a&g=b', // code trop court
        'lecomptoir://rejoindre?v=1&c=AB12CDE&e=a&g=b', // code trop long
        'lecomptoir://rejoindre?v=1&c=AB-2CD&e=a&g=b', // code mal formé
        'lecomptoir://rejoindre?v=1&c=AB12CD&g=b', // sans événement
        'lecomptoir://rejoindre?v=1&c=AB12CD&e=a', // sans gymnase
        'lecomptoir://rejoindre?v=1&c=AB12CD&e=a/b&g=b', // identifiant piégé
        'lecomptoir://rejoindre?v=1&c=AB12CD&e=a&g=../x',
        'lecomptoir://rejoindre?v=1&c=AB12CD&e=&g=b',
      ]) {
        expect(() => lireLienGymnase(mauvais), throwsFormatException,
            reason: mauvais);
      }
    });

    test('des caractères spéciaux ne sortent pas du champ où ils sont', () {
      // Un identifiant qui tenterait d'injecter un autre champ est refusé à la lecture.
      expect(
          () => lireLienGymnase(
              'lecomptoir://rejoindre?v=1&c=AB12CD&e=a%26g%3Dz&g=b'),
          throwsFormatException);
      expect(
          () => lireLienGymnase(ecrireLienGymnase(
              const LienGymnase('AB12CD', 'a&g=z', 'b'))),
          throwsFormatException);
    });
  });
}
