import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/classeur.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/import_assistant.dart';

import 'classeur_aides.dart';

// Mission « Prêt pour le tournoi », T2 (décision 77) : l'assistant d'import unique.
// Logique pure : un seul plan (menu, références, stock de départ, prévision) montré avant
// toute écriture. Les classeurs de test utilisent l'ANCIEN format (critère 8).
const _gymnases = [Gymnase('gA', 'Gymnase A', 40), Gymnase('gB', 'Gymnase B')];
const _produits = [
  ProduitEvenement('soda', 'Soda', 100, null),
  ProduitEvenement('croque', 'Croque', 300, null),
];
const _ctx = ContexteTournoi(
  gymnases: _gymnases,
  produits: _produits,
  portee: PorteeGestion(responsable: true, gymnases: {}, nbGymnases: 2),
);
const _tournoi = Evenement(
    id: 'e',
    nom: 'Tournoi 2026',
    date: '2026-11-14',
    statut: 'en_preparation',
    modes: ['carte'],
    menuNom: 'Menu 2026');

List<Object?> _menu(String nom, double prix) =>
    [nom, prix, null, null, null, null, null, null];

ClasseurLu _lu({
  List<List<Object?>> menu = const [],
  List<List<Object?>> stock = const [],
  List<List<Object?>> historique = const [],
  List<List<Object?>> recettes = const [],
}) =>
    lireClasseur(classeurDeTest(
        menu: menu, stock: stock, historique: historique, recettes: recettes));

void main() {
  group('critère 2 : menu créé ou repris sans modification', () {
    final lu = _lu(menu: [_menu('Soda', 1), _menu('Croque', 3), _menu('Gaufre', 2)]);

    test('aucun menu de ce nom : un nouveau menu est créé', () {
      final p = preparerAssistant(lu, nomMenu: ' Menu 2027 ');
      expect(p.actionMenu, ActionMenu.creer);
      expect(p.nomMenu, 'Menu 2027');
      expect(p.menu.aCreer.map((x) => x.nom), ['Soda', 'Croque', 'Gaufre']);
      expect(p.phrases.first, 'Menu « Menu 2027 » : sera créé (3 produits).');
      expect(p.vide, isFalse);
    });

    test('un menu de même nom (casse et accents ignorés) est repris, jamais modifié', () {
      final menus = [const Menu('m1', 'Menu Été')];
      final existant = menuDeMemeNom(menus, ' menu ete ');
      expect(existant?.id, 'm1');
      final p = preparerAssistant(lu,
          nomMenu: 'menu ete', menuExistant: existant, produitsExistants: ['Soda', 'croque']);
      expect(p.actionMenu, ActionMenu.reprendre);
      expect(p.menuRepris?.id, 'm1');
      // Rien à créer dans ce menu : la liste d'écritures du menu est vide.
      expect(p.phrases.first, contains('repris sans aucune modification'));
      // Ce qui manque dans le menu existant n'est pas ajouté : c'est dit, avec la raison.
      expect(p.produitsNonRepris, ['Gaufre']);
      expect(p.ignorees.single, contains('Gaufre'));
      expect(p.ignorees.single, contains('n\'est pas modifié'));
      expect(p.phraseConfirmation, startsWith('Menu « Menu Été » repris'));
    });

    test('un autre nom que ceux existants : pas de menu de même nom', () {
      expect(menuDeMemeNom([const Menu('m1', 'Menu A')], 'Menu B'), isNull);
      expect(menuDeMemeNom([const Menu('m1', 'Menu A')], '  '), isNull);
    });

    test('pas de produit de menu dans le classeur : aucun menu créé ni repris', () {
      final p = preparerAssistant(
          _lu(historique: [
            ['Tournoi 2025', 'Gymnase A', 20, 2, 'Croque', 80],
          ]),
          nomMenu: 'Menu',
          menuExistant: const Menu('m1', 'Menu'));
      expect(p.actionMenu, ActionMenu.aucune);
      expect(p.vide, isFalse); // la référence reste à écrire
    });

    test('un classeur sans rien d\'utile donne un plan vide', () {
      expect(preparerAssistant(_lu(), nomMenu: 'Menu').vide, isTrue);
    });
  });

  group('critère 9 : menu de même nom porté par le classeur (Menu et Recettes remplis)', () {
    final lu = _lu(menu: [
      ['Croque', 3, 'Composé (recette)', 'Acheté par l\'association', null, null, null, null],
      _menu('Soda', 1),
    ], recettes: [
      ['Croque', 'Pain', 2, 'tranche', null],
      ['Croque', 'Fromage', 30, 'g', null],
    ]);

    test('menu de même nom : repris sans modification, aucun menu créé, recettes non reprises et dites',
        () {
      expect(lu.erreurs, isEmpty);
      expect(lu.produits.firstWhere((x) => x.nom == 'Croque').fiche.ingredients, hasLength(2));
      final p = preparerAssistant(lu,
          nomMenu: 'Menu 2026',
          menuExistant: const Menu('m1', 'Menu 2026'),
          produitsExistants: ['Croque']);
      expect(p.actionMenu, ActionMenu.reprendre);
      expect(p.menuRepris?.id, 'm1');
      expect(p.produitsNonRepris, ['Soda']);
      expect(p.phrases.first, contains('repris sans aucune modification'));
      expect(p.phrases,
          contains('Les recettes du classeur ne sont pas reprises : aucune recette n\'est écrite.'));
      expect(p.phraseConfirmation, startsWith('Menu « Menu 2026 » repris'));
      expect(p.phraseConfirmation, isNot(contains('créé')));
    });

    test('sans menu de même nom : le menu est créé, la phrase des recettes non reprises n\'apparaît pas',
        () {
      final p = preparerAssistant(lu, nomMenu: 'Menu 2026');
      expect(p.actionMenu, ActionMenu.creer);
      expect(p.phrases.any((s) => s.contains('ne sont pas reprises')), isFalse);
    });
  });

  group('critère 3 : anciens tournois = références de prévision', () {
    final lu = _lu(historique: [
      ['Tournoi 2024', 'Gymnase A', 20, 2, 'Croque', 100],
      ['Tournoi 2024', 'Gymnase B', 20, 2, 'Croque', 60],
      ['Tournoi 2025', 'Gymnase A', 40, 2, 'Soda', 80],
    ]);

    test('une référence par ancien tournoi, annoncée dans le résumé', () {
      final p = preparerAssistant(lu, nomMenu: 'Menu');
      expect(p.import.references.map((r) => r.nom),
          ['Tournoi 2024 (Excel)', 'Tournoi 2025 (Excel)']);
      expect(p.phrases, contains('Référence créée : Tournoi 2024 (Excel) — 1 produit'));
      // Sans tournoi, la prévision ne change pas.
      expect(p.referencePrevision, isNull);
    });
  });

  group('critère 4 : stock de départ par noms et prévision sur la référence', () {
    final lu = _lu(stock: [
      ['gymnase a', 'SODA', 24],
      ['Gymnase B', 'Croque', 12],
      ['Gymnase Z', 'Soda', 5],
      ['Gymnase A', 'Pizza', 5],
    ], historique: [
      ['Tournoi 2024', 'Gymnase A', 20, 2, 'Croque', 100],
      ['Tournoi 2025', 'Gymnase A', 40, 2, 'Soda', 80],
    ]);

    test('gymnases et produits retrouvés par leur nom, le reste ignoré avec sa raison',
        () {
      final p = preparerAssistant(lu,
          nomMenu: 'Menu', tournoi: _tournoi, contexte: _ctx);
      expect(p.import.stocks.map((s) => (s.gymnaseId, s.produitId, s.quantite)),
          [('gA', 'soda', 24), ('gB', 'croque', 12)]);
      expect(p.ignorees.where((l) => l.contains('gymnase inconnu')).length, 1);
      expect(p.ignorees.where((l) => l.contains('produit inconnu')).length, 1);
      expect(p.phrases.join('\n'), contains('2 stocks seront appliqués.'));
    });

    test('la prévision est réglée sur la première référence, ou sur celle choisie', () {
      final defaut = preparerAssistant(lu,
          nomMenu: 'Menu', tournoi: _tournoi, contexte: _ctx);
      expect(defaut.referencePrevision?.nom, 'Tournoi 2024 (Excel)');
      final choisie = preparerAssistant(lu,
          nomMenu: 'Menu',
          tournoi: _tournoi,
          contexte: _ctx,
          referenceId: 'tournoi-2025-excel');
      expect(choisie.referencePrevision?.nom, 'Tournoi 2025 (Excel)');
      expect(choisie.phrases.last, 'Prévision : réglée sur « Tournoi 2025 (Excel) ».');
    });

    test('sans tournoi : le stock n\'est pas utilisé, sans bruit dans les lignes ignorées',
        () {
      final p = preparerAssistant(lu, nomMenu: 'Menu');
      expect(p.import.stocks, isEmpty);
      expect(p.ignorees, isEmpty);
      expect(p.stocksIgnoresSansTournoi, 4);
      expect(p.phrases.join('\n'), contains('Aucun tournoi choisi'));
    });

    test('un gestionnaire limité ne pose le stock que dans ses gymnases', () {
      final p = preparerAssistant(lu,
          nomMenu: 'Menu',
          tournoi: _tournoi,
          contexte: const ContexteTournoi(
            gymnases: _gymnases,
            produits: _produits,
            portee: PorteeGestion(responsable: false, gymnases: {'gB'}, nbGymnases: 2),
          ));
      expect(p.import.stocks.single.gymnaseId, 'gB');
      expect(p.ignorees.any((l) => l.contains('ne fait pas partie de vos gymnases')),
          isTrue);
    });
  });

  group('critère 5 : lignes ignorées du classeur, avec leur raison', () {
    test('une ligne de menu invalide est ignorée et dite', () {
      final p = preparerAssistant(
          _lu(menu: [_menu('Soda', 1), _menu('Cassé', -3)]), nomMenu: 'Menu');
      expect(p.menu.produits.map((x) => x.nom), ['Soda']);
      expect(p.ignorees.single, contains('ligne 4'));
      expect(p.ignorees.single, contains('le prix'));
    });
  });
}
