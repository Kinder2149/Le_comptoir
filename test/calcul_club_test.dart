import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/calcul_club.dart';

// Calcul du club, étape V1 : chiffres du classeur d'origine (sans aucun nom).
// Critère 3 (ancien calcul inchangé) : prouvé par la suite entière, aucun test
// existant n'est modifié.

const g1Samedi = RepasGymnaseJour(
    joueusesMidi: 49,
    joueusesSoir: 49,
    benevolesMidi: 10,
    benevolesSoir: 11,
    spectateursMidi: 0,
    spectateursSoir: 0);
const g1Dimanche = RepasGymnaseJour(
    joueusesMidi: 56,
    joueusesSoir: 56,
    benevolesMidi: 9,
    benevolesSoir: 9);
const g2Samedi = RepasGymnaseJour(
    joueusesMidi: 63,
    joueusesSoir: 63,
    benevolesMidi: 7,
    benevolesSoir: 8);
const g2Dimanche = RepasGymnaseJour(
    joueusesMidi: 56,
    joueusesSoir: 56,
    benevolesMidi: 6,
    benevolesSoir: 3);

CalculClub calculClasseur() => const CalculClub(
      repas: {
        'g1': {1: g1Samedi, 2: g1Dimanche},
        'g2': {1: g2Samedi, 2: g2Dimanche},
      },
      groupes: [
        GroupeConso(
          nom: 'Plat',
          pourcentages: {1: 0.70, 2: 0.80},
          produits: {
            'croque': {1: 0.40, 2: 0.35},
            'vege': {1: 0.25, 2: 0.30},
            'tartiflette': {1: 0.35, 2: 0.35},
          },
        ),
        GroupeConso(
          nom: 'Fruit',
          pourcentages: {1: 0.50, 2: 0.60},
          produits: {
            'fruit': {1: 1.0, 2: 1.0},
          },
        ),
      ],
    );

void main() {
  group('Repas (critère 1)', () {
    test('le total est la somme des six nombres', () {
      expect(
          const RepasGymnaseJour(
                  joueusesMidi: 1,
                  joueusesSoir: 2,
                  benevolesMidi: 3,
                  benevolesSoir: 4,
                  spectateursMidi: 5,
                  spectateursSoir: 6)
              .total,
          21);
      expect(const RepasGymnaseJour().total, 0);
    });

    test('repas du classeur : 119, 130, 141, 121', () {
      final c = calculClasseur();
      expect(repasDuJour(c, 'g1', 1), 119);
      expect(repasDuJour(c, 'g1', 2), 130);
      expect(repasDuJour(c, 'g2', 1), 141);
      expect(repasDuJour(c, 'g2', 2), 121);
    });

    test('gymnase ou jour inconnu : 0', () {
      final c = calculClasseur();
      expect(repasDuJour(c, 'g9', 1), 0);
      expect(repasDuJour(c, 'g1', 3), 0);
    });
  });

  group('Formule et arrondi (critère 2)', () {
    test('repas × % du groupe × part du produit, par jour', () {
      final c = CalculClub(
        repas: const {
          'g': {
            1: RepasGymnaseJour(joueusesMidi: 100),
            2: RepasGymnaseJour(joueusesMidi: 50),
          },
        },
        groupes: const [
          GroupeConso(
            nom: 'X',
            pourcentages: {1: 0.5, 2: 1.0},
            produits: {
              'p': {1: 0.2, 2: 0.1},
            },
          ),
        ],
      );
      expect(quantiteClubJour(c, 'g', 'p', 1), closeTo(10.0, 1e-9));
      expect(quantiteClubJour(c, 'g', 'p', 2), closeTo(5.0, 1e-9));
    });

    test('un seul arrondi sur la somme des jours, pas un par jour', () {
      // 0,3 + 0,3 = 0,6 -> 1 ; arrondir chaque jour donnerait 1 + 1 = 2.
      final c = CalculClub(
        repas: const {
          'g': {
            1: RepasGymnaseJour(joueusesMidi: 3),
            2: RepasGymnaseJour(joueusesMidi: 3),
          },
        },
        groupes: const [
          GroupeConso(
            nom: 'X',
            pourcentages: {1: 1.0, 2: 1.0},
            produits: {
              'p': {1: 0.1, 2: 0.1},
            },
          ),
        ],
      );
      expect(quantiteClub(c, 'g', 'p'), 1);
    });

    test('un nombre exact reste exact (pas de +1 à cause du décimal)', () {
      final c = CalculClub(
        repas: const {
          'g': {1: RepasGymnaseJour(joueusesMidi: 100)},
        },
        groupes: const [
          GroupeConso(
            nom: 'X',
            pourcentages: {1: 0.7},
            produits: {
              'p': {1: 0.4},
            },
          ),
        ],
      );
      // 100 × 0,7 × 0,4 = 28 (28,000000000000004 en flottant).
      expect(quantiteClub(c, 'g', 'p'), 28);
    });

    test('produit absent de tout groupe : null (ancien calcul gardé)', () {
      final c = calculClasseur();
      expect(quantiteClubJour(c, 'g1', 'inconnu', 1), isNull);
      expect(quantiteClub(c, 'g1', 'inconnu'), isNull);
    });

    test('gymnase sans repas détaillés : null', () {
      expect(quantiteClub(calculClasseur(), 'g9', 'croque'), isNull);
    });
  });

  group('Chiffres du classeur d\'origine (critère 4)', () {
    test('croque standard : 4 combinaisons gymnase × jour', () {
      final c = calculClasseur();
      expect(quantiteClubJour(c, 'g1', 'croque', 1), closeTo(33.32, 1e-9));
      expect(quantiteClubJour(c, 'g1', 'croque', 2), closeTo(36.4, 1e-9));
      expect(quantiteClubJour(c, 'g2', 'croque', 1), closeTo(39.48, 1e-9));
      expect(quantiteClubJour(c, 'g2', 'croque', 2), closeTo(33.88, 1e-9));
    });

    test('total G1 sur deux jours : 69,72 arrondi à 70', () {
      final c = calculClasseur();
      final somme = quantiteClubJour(c, 'g1', 'croque', 1)! +
          quantiteClubJour(c, 'g1', 'croque', 2)!;
      expect(somme, closeTo(69.72, 1e-9));
      expect(quantiteClub(c, 'g1', 'croque'), 70);
    });

    test('total G2 : 39,48 + 33,88 = 73,36 arrondi à 74', () {
      expect(quantiteClub(calculClasseur(), 'g2', 'croque'), 74);
    });

    test('un autre produit : végé G1 = 119×0,7×0,25 + 130×0,8×0,3', () {
      final c = calculClasseur();
      expect(quantiteClubJour(c, 'g1', 'vege', 1), closeTo(20.825, 1e-9));
      expect(quantiteClubJour(c, 'g1', 'vege', 2), closeTo(31.2, 1e-9));
      // 52,025 -> 53
      expect(quantiteClub(c, 'g1', 'vege'), 53);
    });

    test('un produit d\'un autre groupe : fruit G2 = 141×0,5 + 121×0,6', () {
      // 70,5 + 72,6 = 143,1 -> 144
      expect(quantiteClub(calculClasseur(), 'g2', 'fruit'), 144);
    });
  });

  group('Parts qui ne font pas 100 % (critère 5)', () {
    test('le classeur d\'origine est juste : aucun écart', () {
      expect(ecartsGroupes(calculClasseur()), isEmpty);
    });

    test('un écart est signalé, avec le groupe, le jour et la somme', () {
      const c = CalculClub(
        repas: {
          'g': {1: RepasGymnaseJour(joueusesMidi: 100)},
        },
        groupes: [
          GroupeConso(
            nom: 'Plat',
            pourcentages: {1: 0.7, 2: 0.8},
            produits: {
              'a': {1: 0.40, 2: 0.35},
              'b': {1: 0.25, 2: 0.30},
              'c': {1: 0.30, 2: 0.35},
            },
          ),
        ],
      );
      final e = ecartsGroupes(c);
      expect(e.length, 1);
      expect(e.first.groupe, 'Plat');
      expect(e.first.jour, 1);
      expect(e.first.somme, closeTo(0.95, 1e-9));
      expect(e.first.ecart, closeTo(-0.05, 1e-9));
    });

    test('les valeurs ne sont jamais corrigées en silence', () {
      const c = CalculClub(
        repas: {
          'g': {1: RepasGymnaseJour(joueusesMidi: 100)},
        },
        groupes: [
          GroupeConso(
            nom: 'Plat',
            pourcentages: {1: 1.0},
            produits: {
              'a': {1: 0.5},
              'b': {1: 0.4},
            },
          ),
        ],
      );
      expect(ecartsGroupes(c).length, 1);
      // La quantité utilise la part saisie telle quelle (0,5 et 0,4), pas 100 %.
      expect(quantiteClubJour(c, 'g', 'a', 1), closeTo(50.0, 1e-9));
      expect(quantiteClubJour(c, 'g', 'b', 1), closeTo(40.0, 1e-9));
      expect(c.groupes.first.produits['a']![1], 0.5);
      expect(c.groupes.first.produits['b']![1], 0.4);
    });

    test('un petit bruit de flottant (0,1 + 0,2 + 0,7) n\'est pas un écart', () {
      const c = CalculClub(groupes: [
        GroupeConso(
          nom: 'X',
          produits: {
            'a': {1: 0.1},
            'b': {1: 0.2},
            'c': {1: 0.7},
          },
        ),
      ]);
      expect(ecartsGroupes(c), isEmpty);
    });
  });

  group('enregistrement : sérialisation (V2)', () {
    void memesRepas(RepasGymnaseJour b, RepasGymnaseJour a) {
      expect(b.joueusesMidi, a.joueusesMidi);
      expect(b.joueusesSoir, a.joueusesSoir);
      expect(b.benevolesMidi, a.benevolesMidi);
      expect(b.benevolesSoir, a.benevolesSoir);
      expect(b.spectateursMidi, a.spectateursMidi);
      expect(b.spectateursSoir, a.spectateursSoir);
      expect(b.total, a.total);
    }

    Map<String, Object> repasValide() => {
          'joueusesMidi': 49,
          'joueusesSoir': 49,
          'benevolesMidi': 10,
          'benevolesSoir': 11,
          'spectateursMidi': 0,
          'spectateursSoir': 0,
        };

    test('les repas font l\'aller-retour : chaque catégorie, midi et soir', () {
      final attendu = calculClasseur().repas;
      final relu = repasDepuisMap(repasVersMap(attendu))!;
      expect(relu.keys.toSet(), attendu.keys.toSet());
      for (final gymnase in attendu.keys) {
        expect(relu[gymnase]!.keys.toSet(), attendu[gymnase]!.keys.toSet());
        for (final jour in attendu[gymnase]!.keys) {
          memesRepas(relu[gymnase]![jour]!, attendu[gymnase]![jour]!);
        }
      }
    });

    test('le document « repas » a la forme attendue par les règles (jour en texte)', () {
      final doc = repasVersMap(calculClasseur().repas);
      final jours = doc['jours'] as Map<String, dynamic>;
      expect(jours.keys.toSet(), {'1', '2'});
      final g1 = jours['1'] as Map<String, dynamic>;
      expect((g1['g1'] as Map)['joueusesMidi'], 49);
      expect((g1['g1'] as Map).length, 6);
    });

    test('les groupes font l\'aller-retour : noms, pourcentages et parts', () {
      final attendu = calculClasseur().groupes;
      final relu = groupesDepuisMap(groupesVersMap(attendu))!;
      expect(relu.length, attendu.length);
      for (var i = 0; i < attendu.length; i++) {
        expect(relu[i].nom, attendu[i].nom);
        expect(relu[i].pourcentages, attendu[i].pourcentages);
        expect(relu[i].produits, attendu[i].produits);
      }
    });

    test('le document « groupes » a la forme attendue par les règles', () {
      final doc = groupesVersMap(calculClasseur().groupes);
      final liste = doc['groupes'] as List;
      expect(liste.length, calculClasseur().groupes.length);
      final premier = liste.first as Map<String, dynamic>;
      expect(premier['nom'], 'Plat');
      expect(premier['pourcentages'], {'1': 0.70, '2': 0.80});
    });

    test('une entrée hors format est ignorée à la lecture des repas', () {
      final relu = repasDepuisMap({
        'jours': {
          '1': {
            'g1': repasValide(),
            'g2': {...repasValide()}..remove('spectateursSoir'),
            'g3': {...repasValide(), 'joueusesMidi': '49'},
            'g4': {...repasValide(), 'benevolesSoir': -1},
            'g5': 'texte',
          },
          'deux': {'g1': repasValide()},
          '3': 'texte',
          '4': {'g1': repasValide()},
        },
      })!;
      expect(relu.keys.toList(), ['g1']);
      expect(relu['g1']!.keys.toSet(), {1, 4});
      expect(relu['g1']![1]!.total, 119);
      memesRepas(relu['g1']![1]!, const RepasGymnaseJour(
          joueusesMidi: 49,
          joueusesSoir: 49,
          benevolesMidi: 10,
          benevolesSoir: 11));
    });

    test('une entrée hors format est ignorée à la lecture des groupes', () {
      final relu = groupesDepuisMap({
        'groupes': [
          {
            'nom': 'Plat',
            'pourcentages': {'1': 0.7, 'deux': 0.5, '2': 'x'},
            'produits': {
              'croque': {'1': 0.4},
              '': {'1': 0.1},
            },
          },
          {'pourcentages': {'1': 1.0}},
          'texte',
        ],
      })!;
      expect(relu.length, 1);
      expect(relu[0].nom, 'Plat');
      expect(relu[0].pourcentages, {1: 0.7});
      expect(relu[0].produits, {
        'croque': {1: 0.4},
      });
    });

    test('un document absent donne null ; un seul document donne l\'autre vide', () {
      expect(repasDepuisMap(null), isNull);
      expect(groupesDepuisMap(null), isNull);
      expect(calculClubDepuis(null, null), isNull);
      final seul = calculClubDepuis(repasVersMap(calculClasseur().repas), null)!;
      expect(seul.groupes, isEmpty);
      expect(seul.repas.keys.toSet(), {'g1', 'g2'});
      final sans = calculClubDepuis(null, groupesVersMap(calculClasseur().groupes))!;
      expect(sans.repas, isEmpty);
      expect(sans.groupes.length, 2);
    });
  });

  group('Groupes dans la Prévision (V4)', () {
    test('quantité d un produit pour un jour, tous gymnases : 33,32 + 39,48 = 72,8', () {
      final c = calculClasseur();
      expect(quantiteClubProduitJour(c, 'croque', 1), closeTo(72.8, 1e-9));
      expect(quantiteClubProduitJour(c, 'croque', 2), closeTo(70.28, 1e-9));
      // Hors groupe : null (l'ancien calcul s'applique) ; jour sans pourcentage : 0.
      expect(quantiteClubProduitJour(c, 'coca', 1), isNull);
      expect(quantiteClubProduitJour(c, 'croque', 3), 0.0);
    });

    test('les écarts d un seul groupe : 100 % ne signale rien, 95 % est signalé', () {
      final juste = calculClasseur().groupes[0];
      expect(ecartsDuGroupe(juste), isEmpty);
      final faux = GroupeConso(nom: 'Plat', produits: {
        'croque': {1: 0.4},
        'vege': {1: 0.25},
        'tartiflette': {1: 0.30},
      });
      final e = ecartsDuGroupe(faux).single;
      expect(e.jour, 1);
      expect(e.ecart, closeTo(-0.05, 1e-9));
    });

    test('ranger un produit : un seul groupe, parts de départ à 0, ancien groupe vidé', () {
      final groupes = calculClasseur().groupes;
      final apres = rangerProduit(groupes, 0, 'fruit', 2);
      expect(apres[0].produits['fruit'], {1: 0.0, 2: 0.0});
      expect(apres[1].produits, isEmpty);
      expect(apres.where((g) => g.produits.containsKey('fruit')), hasLength(1));
      // Les autres produits gardent leurs parts, les pourcentages ne bougent pas.
      expect(apres[0].produits['croque'], {1: 0.40, 2: 0.35});
      expect(apres[0].pourcentages, {1: 0.70, 2: 0.80});
      // Déjà dans le groupe, ou groupe inconnu : inchangé.
      expect(identical(rangerProduit(apres, 0, 'fruit', 2), apres), isTrue);
      expect(identical(rangerProduit(apres, 7, 'croque', 2), apres), isTrue);
    });

    test('retirer, renommer, changer un pourcentage et une part', () {
      final g = calculClasseur().groupes[0];
      expect(retirerProduit([g], 'vege').single.produits.keys, ['croque', 'tartiflette']);
      expect(groupeRenomme(g, 'Plats').nom, 'Plats');
      expect(groupeAvecPourcentage(g, 2, 0.9).pourcentages, {1: 0.70, 2: 0.9});
      expect(groupeAvecPart(g, 'croque', 1, 0.5).produits['croque'], {1: 0.5, 2: 0.35});
      expect(groupeAvecPart(g, 'croque', 1, 0.5).produits['vege'], {1: 0.25, 2: 0.30});
    });

    test('annulation : les groupes rangés puis relus sont identiques (aller-retour)', () {
      final avant = calculClasseur().groupes;
      final champ = groupesPourAnnulation(avant);
      expect(champ, hasLength(2));
      final relus = groupesDepuisAnnulation(champ)!;
      expect(groupesVersMap(relus), groupesVersMap(avant));
      // Un changement de groupes après le rangement, puis l'annulation : l'état d'avant revient.
      final apres = rangerProduit(avant, 0, 'fruit', 2);
      expect(groupesVersMap(apres), isNot(groupesVersMap(avant)));
      expect(groupesVersMap(groupesDepuisAnnulation(champ)!), groupesVersMap(avant));
    });

    test('annulation : sans champ, les groupes ne sont pas touchés ; une entrée hors format est ignorée',
        () {
      expect(groupesDepuisAnnulation(null), isNull);
      expect(groupesDepuisAnnulation('texte'), isNull);
      expect(groupesDepuisAnnulation(const []), isEmpty);
      final relus = groupesDepuisAnnulation([
        {'nom': 'Plat', 'pourcentages': {'1': 0.7}, 'produits': {'croque': {'1': 1}}},
        {'pourcentages': {'1': 0.5}},
        'x',
      ])!;
      expect(relus.single.nom, 'Plat');
      expect(relus.single.produits['croque'], {1: 1.0});
    });

    test('les bornes de l application', () {
      expect(groupesMax, 40);
      expect(nomGroupeMax, 40);
      expect(pourcentageGroupeMax, 5.0);
      expect(partProduitMax, 1.0);
    });
  });
}
