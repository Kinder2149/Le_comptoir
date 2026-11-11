import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/ecran_menu.dart';
import 'package:le_comptoir/liste_familles.dart';
import 'package:le_comptoir/theme.dart';

// Mission « Ergonomie de la gestion », étape E2 : listes par familles et icônes.

List<ProduitModele> modele() =>
    lireMenuType(File('assets/menu_type.json').readAsStringSync());

/// Produits du menu modèle, avec un identifiant « m0 », « m1 »… selon l'ordre du fichier.
List<ProduitMenu> produitsDuModele() => [
      for (var i = 0; i < modele().length; i++)
        ProduitMenu('m$i', modele()[i].nom, modele()[i].prixCentimes,
            icone: modele()[i].icone, fiche: modele()[i].fiche),
    ];

String idDe(String nom) =>
    produitsDuModele().firstWhere((p) => p.nom == nom).id;

Future<void> pomper(WidgetTester tester, Widget corps) {
  return tester.pumpWidget(MaterialApp(
    theme: themeComptoir(),
    home: Scaffold(body: corps),
  ));
}

Widget menu() => ListeProduitsMenu(produits: produitsDuModele(), onTap: (_) {});

/// Élément de test, sans rapport avec le menu.
class Jouet {
  const Jouet(this.nom, this.famille);
  final String nom;
  final String famille;
}

void main() {
  group('critère 1 : le menu modèle s\'affiche en familles, dans l\'ordre fixe', () {
    testWidgets('titres dans l\'ordre, chacun avec son nombre de produits', (tester) async {
      await pomper(tester, menu());
      final attendu = {
        for (final f in famillesProduit)
          if (produitsDuModele().any((p) => p.fiche.famille == f))
            f: produitsDuModele().where((p) => p.fiche.famille == f).length,
      };
      // Le modèle n'a aucun produit « Autre » : pas de bloc vide.
      expect(attendu.containsKey('autre'), isFalse);
      expect(attendu['croques'], 3);

      final titres = [for (final f in attendu.keys) libellesFamilles[f]!];
      double y(String t) => tester.getCenter(find.text(t)).dy;
      for (var i = 1; i < titres.length; i++) {
        expect(y(titres[i - 1]), lessThan(y(titres[i])), reason: titres[i]);
      }
      for (final f in attendu.keys) {
        expect(tester.widget<Text>(find.byKey(Key('compteur_famille_$f'))).data,
            '${attendu[f]}',
            reason: f);
      }
    });
  });

  group('critère 2 : une famille se replie et se déplie', () {
    testWidgets('produits cachés au départ, puis visibles, puis cachés', (tester) async {
      await pomper(tester, menu());
      expect(find.text('Croque-monsieur'), findsNothing);
      await tester.tap(find.byKey(const Key('entete_famille_croques')));
      await tester.pump();
      expect(find.text('Croque-monsieur'), findsOneWidget);
      await tester.tap(find.byKey(const Key('entete_famille_croques')));
      await tester.pump();
      expect(find.text('Croque-monsieur'), findsNothing);
    });
  });

  group('critère 3 : la recherche', () {
    testWidgets('« chocolat » ne laisse que les produits qui le contiennent', (tester) async {
      await pomper(tester, menu());
      await tester.enterText(find.byKey(const Key('recherche_familles')), 'chocolat');
      await tester.pump();
      expect(find.text('Barre de céréales chocolat'), findsOneWidget);
      expect(find.text('Chocolat chaud'), findsOneWidget);
      expect(find.text('Barre de céréales pomme'), findsNothing);
      expect(find.text('Barre caramel'), findsNothing);
      expect(find.text('Croque-monsieur'), findsNothing);
      expect(find.byKey(const Key('compteur_famille_snacks_fruits')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('compteur_famille_snacks_fruits'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('compteur_famille_boissons_chaudes'))).data, '1');
      expect(find.byKey(const Key('compteur_famille_croques')), findsNothing);
    });

    testWidgets('sans accents ni casse', (tester) async {
      await pomper(tester, menu());
      await tester.enterText(find.byKey(const Key('recherche_familles')), 'CHOCOLAT');
      await tester.pump();
      expect(find.text('Chocolat chaud'), findsOneWidget);
    });

    testWidgets('rien ne correspond : message, pas d\'écran vide', (tester) async {
      await pomper(tester, menu());
      await tester.enterText(find.byKey(const Key('recherche_familles')), 'zzzz');
      await tester.pump();
      expect(find.byKey(const Key('aucun_resultat_familles')), findsOneWidget);
    });
  });

  group('critère 4 : icônes fausses retirées, pastille à la place', () {
    test('barres de céréales et bonbons n\'ont plus d\'icône dans le modèle', () {
      String? icone(String nom) => modele().firstWhere((p) => p.nom == nom).icone;
      expect(icone('Barre de céréales pomme'), isNull);
      expect(icone('Barre de céréales chocolat'), isNull);
      expect(icone('Barre de céréales fraise-framboise'), isNull);
      expect(icone('Bonbons (offerts)'), isNull);
      // Les barres chocolatées gardent leur icône, qui est juste.
      expect(icone('Barre caramel'), 'barre');
    });

    test('initiales : « CM », « Co », « BC », « BO »', () {
      expect(initialesDe('Croque-monsieur'), 'CM');
      expect(initialesDe('Cola'), 'Co');
      expect(initialesDe('Barre de céréales pomme'), 'BC');
      expect(initialesDe('Bonbons (offerts)'), 'BO');
    });

    testWidgets('barre de céréales : pastille de la couleur de Snacks et fruits', (tester) async {
      await pomper(tester, menu());
      await tester.tap(find.byKey(const Key('entete_famille_snacks_fruits')));
      await tester.pump();
      final id = idDe('Barre de céréales pomme');
      expect(find.byKey(Key('vignette_$id')), findsNothing);
      final pastille = tester.widget<PastilleProduit>(find.byKey(Key('pastille_$id')));
      expect(pastille.couleur, couleursFamilles['snacks_fruits']);
      expect(find.descendant(of: find.byKey(Key('pastille_$id')), matching: find.text('BC')),
          findsOneWidget);
      // Les bonbons aussi.
      expect(find.descendant(
              of: find.byKey(Key('pastille_${idDe('Bonbons (offerts)')}')),
              matching: find.text('BO')),
          findsOneWidget);
    });

    testWidgets('Barre caramel garde son icône, sans pastille', (tester) async {
      await pomper(tester, menu());
      await tester.tap(find.byKey(const Key('entete_famille_snacks_fruits')));
      await tester.pump();
      expect(find.byKey(Key('vignette_${idDe('Barre caramel')}')), findsOneWidget);
      expect(find.byKey(Key('pastille_${idDe('Barre caramel')}')), findsNothing);
    });
  });

  group('critère 5 : un seul composant, réutilisable hors du menu', () {
    testWidgets('composant seul : familles et libellés fournis, ordre fixe, « Autre » pour l\'inconnu', (tester) async {
      await pomper(
        tester,
        ListeFamilles<Jouet>(
          elements: const [
            Jouet('Un', 'bleu'),
            Jouet('Deux', 'rouge'),
            Jouet('Trois', 'hors liste'),
          ],
          familleDe: (j) => j.famille,
          nomDe: (j) => j.nom,
          familles: const ['rouge', 'bleu'],
          libelles: const {'rouge': 'Rouges', 'bleu': 'Bleus'},
          couleurs: const {'rouge': Colors.red, 'bleu': Colors.blue},
          ligne: (context, j, couleur) =>
              ListTile(key: Key('ligne_${j.nom}'), title: Text(j.nom)),
        ),
      );
      double y(String t) => tester.getCenter(find.text(t)).dy;
      expect(y('Rouges'), lessThan(y('Bleus')));
      expect(tester.widget<Text>(find.byKey(const Key('compteur_famille_rouge'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('compteur_famille_bleu'))).data, '2');
      // Familles repliées au départ : les lignes ne sont pas affichées.
      expect(find.byKey(const Key('ligne_Deux')), findsNothing);
      await tester.tap(find.byKey(const Key('entete_famille_bleu')));
      await tester.pump();
      expect(find.byKey(const Key('ligne_Un')), findsOneWidget);
      expect(find.byKey(const Key('ligne_Trois')), findsOneWidget);
    });

    testWidgets('ligne et recherche fournies par le caller, sans menu', (tester) async {
      await pomper(
        tester,
        ListeFamilles<Jouet>(
          elements: const [Jouet('Ballon', 'rouge')],
          familleDe: (j) => j.famille,
          nomDe: (j) => j.nom,
          familles: const ['rouge'],
          libelles: const {'rouge': 'Rouges'},
          couleurs: const {'rouge': Colors.red},
          ligne: (context, j, couleur) =>
              ListTile(key: Key('ligne_${j.nom}'), title: Text(j.nom)),
        ),
      );
      await tester.enterText(find.byKey(const Key('recherche_familles')), 'ball');
      await tester.pump();
      expect(find.byKey(const Key('ligne_Ballon')), findsOneWidget);
    });
  });
}
