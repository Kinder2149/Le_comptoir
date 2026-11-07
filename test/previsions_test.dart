import 'package:flutter_test/flutter_test.dart';
import 'package:le_comptoir/courses.dart';
import 'package:le_comptoir/depot_caisses.dart';
import 'package:le_comptoir/depot_menus.dart';
import 'package:le_comptoir/evenement.dart';
import 'package:le_comptoir/gymnase.dart';
import 'package:le_comptoir/previsions.dart';

// Mission « Préparer l'événement », étape P4 : la prévision à sources.
//
// Événement passé (calculé À LA MAIN) : 40 personnes (25 + 15) pendant 2 jours.
//   Croque-monsieur : 100 + 60 = 160 vendus, plus 20 vendus puis ANNULÉS (exclus).
//   Soda : proposé mais aucun vendu.
//   Gâteau : vendu 8, absent du nouvel événement.
//   Croque : 160 ÷ 40 ÷ 2 = 2,0 par personne et par jour. Soda : 0.
// Nouvel événement : « croque-monsieur » (casse différente, menu : 1,5), « Soda »
// (menu : 0,5), « Salade » (menu : 0,5, absente de l'événement passé), « Café » (sans
// consommation au menu).
const _croque = ProduitEvenement('n1', 'croque-monsieur', 300, null,
    fiche: FicheProduit(conso: 1.5));
const _soda =
    ProduitEvenement('n2', 'Soda', 100, null, fiche: FicheProduit(conso: 0.5));
const _salade = ProduitEvenement('n3', 'Salade', 400, null,
    fiche: FicheProduit(conso: 0.5));
const _cafe = ProduitEvenement('n4', 'Café', 150, null);
const _produits = [_croque, _soda, _salade, _cafe];

const _passes = {'p1': 'Croque-Monsieur', 'p2': 'SODA', 'p3': 'Gâteau'};

Vente _vente(String id, List<LigneVente> lignes, {bool annulee = false}) => Vente(
      id: id,
      lignes: lignes,
      totalCentimes: lignes.fold<int>(0, (s, l) => s + l.prixCentimes * l.quantite),
      mode: 'especes',
      creeLe: DateTime(2025, 10, 3, 14),
      enAttente: false,
      annulee: annulee,
    );

TableauDeBord _tableauPasse({bool avecAnnulee = true}) {
  const c1 = Caisse(uid: 'a', gymnaseId: 'gA', prenom: 'A', statut: 'cloturee');
  const c2 = Caisse(uid: 'b', gymnaseId: 'gB', prenom: 'B', statut: 'cloturee');
  return TableauDeBord.depuis([
    ResumeCaisse(c1, [
      _vente('v1', [LigneVente('p1', 'Croque-Monsieur', 300, 100)]),
      if (avecAnnulee)
        _vente('v2', [LigneVente('p1', 'Croque-Monsieur', 300, 20)], annulee: true),
      _vente('v3', [LigneVente('p3', 'Gâteau', 250, 8)]),
    ]),
    ResumeCaisse(c2, [
      _vente('v4', [LigneVente('p1', 'Croque-Monsieur', 300, 60)]),
    ]),
  ]);
}

Map<String, double> _calcul(TableauDeBord t, {int personnes = 40, double jours = 2}) =>
    consoDepuisEvenement(
      produits: _produits,
      produitsPasses: _passes,
      tableau: t,
      personnes: personnes,
      jours: jours,
    );

void main() {
  group('critère 1 : par défaut, les chiffres du menu', () {
    test('sans prévision, chaque produit a le chiffre du menu, source « Menu »', () {
      final l = fusionnerPrevisions(_produits, const {});
      expect([for (final x in l) (x.nom, x.conso, x.source)], [
        ('croque-monsieur', 1.5, 'Menu'),
        ('Soda', 0.5, 'Menu'),
        ('Salade', 0.5, 'Menu'),
        ('Café', 0.0, 'Menu'), // pas de consommation au menu : 0
      ]);
    });
  });

  group('critère 2 : d\'après un événement passé', () {
    test('160 croques pour 40 personnes en 2 jours : 2,0 par personne et par jour', () {
      final conso = _calcul(_tableauPasse());
      expect(conso['n1'], 2.0);
      // Le nom est retrouvé sans casse ni accents.
      expect(conso['n2'], 0.0); // « Soda » proposé, aucun vendu
    });

    test('la source est affichée avec le nom de l\'événement', () {
      final l = fusionnerPrevisions(_produits,
          {'n1': Prevision(2.0, sourceEvenement('Tournoi 2025'))});
      expect(l.first.conso, 2.0);
      expect(l.first.source, 'Événement : Tournoi 2025');
    });

    test('une source trop longue est coupée à 80 caractères', () {
      expect(sourceEvenement('x' * 200).length, 80);
    });
  });

  group('critère 3 : un produit absent de la source garde le menu', () {
    test('Salade et Café ne sont pas dans le calcul, le tableau garde le menu', () {
      final conso = _calcul(_tableauPasse());
      expect(conso.containsKey('n3'), isFalse);
      expect(conso.containsKey('n4'), isFalse);
      final l = fusionnerPrevisions(_produits, {
        for (final e in conso.entries) e.key: Prevision(e.value, 'Événement : T'),
      });
      expect(l[2].conso, 0.5);
      expect(l[2].source, 'Menu');
      expect(l[3].conso, 0.0);
      expect(l[3].source, 'Menu');
    });
  });

  group('critère 4 : un chiffre corrigé reste, le menu ne change pas', () {
    test('« modifié à la main » est reconnu et le produit du menu est inchangé', () {
      final l = fusionnerPrevisions(_produits, {'n2': const Prevision(0.8, sourceMain)});
      expect(l[1].conso, 0.8);
      expect(l[1].modifieALaMain, isTrue);
      expect(l[0].modifieALaMain, isFalse);
      // Le produit (et donc le menu dont il est la copie) garde son chiffre.
      expect(_soda.fiche.conso, 0.5);
      final avec = produitsAvecPrevisions(_produits, {'n2': const Prevision(0.8, sourceMain)});
      expect(avec[1].fiche.conso, 0.8);
      expect(_soda.fiche.conso, 0.5);
      // Les autres produits sont les mêmes objets.
      expect(identical(avec[0], _croque), isTrue);
    });

    test('avecConso garde tout le reste du produit', () {
      const p = ProduitEvenement('x', 'Café', 150, 4,
          icone: 'cafe',
          fiche: FicheProduit(
              type: 'litre', provenance: 'apporte', verresParLitre: 8, conso: 1));
      final q = p.avecConso(3);
      expect((q.id, q.nom, q.prixCentimes, q.stock, q.icone), ('x', 'Café', 150, 4, 'cafe'));
      expect((q.fiche.type, q.fiche.provenance, q.fiche.verresParLitre, q.fiche.conso),
          ('litre', 'apporte', 8.0, 3.0));
    });
  });

  group('critère 5 : un événement passé sans personnes réglées n\'est pas proposé', () {
    ReferencePassee r(String id, int personnes, {String date = '2025-10-03', double jours = 2}) =>
        ReferencePassee(id: id, nom: 'T$id', date: date, personnes: personnes, jours: jours);

    test('écarté et compté, avec un message', () {
      final res = selectionnerReferences([
        r('a', 40),
        r('b', 0),
        r('c', 10, date: '2026-03-01'),
        r('d', 25, jours: 0),
      ]);
      expect([for (final x in res.utilisables) x.id], ['c', 'a']); // plus récent d'abord
      expect(res.sansPersonnes, 2);
      expect(messageSansPersonnes,
          'Les événements passés sans nombre de personnes réglé ne peuvent pas servir de référence.');
    });

    test('sans personnes (ou sans durée), aucun calcul', () {
      expect(_calcul(_tableauPasse(), personnes: 0), isEmpty);
      expect(_calcul(_tableauPasse(), jours: 0), isEmpty);
    });
  });

  group('critère 6 : les ventes annulées sont exclues', () {
    test('avec ou sans la vente annulée, le même chiffre', () {
      expect(_calcul(_tableauPasse())['n1'], 2.0);
      expect(_calcul(_tableauPasse(avecAnnulee: false))['n1'], 2.0);
      // Le tableau de bord compte bien la vente annulée à part.
      expect(_tableauPasse().nbAnnulees, 1);
      expect(_tableauPasse().vendus('p1'), 160);
    });
  });

  group('critère 7 : les courses calculent avec ces chiffres', () {
    test('80 personnes × 2 jours × 2,0 = 320, moins le stock', () {
      const gymnases = [Gymnase('gA', 'Gymnase A', 80)];
      final prevus = produitsAvecPrevisions(_produits, {'n1': const Prevision(2.0, 'Événement : T')});
      final sansStock = listeParDefaut(produits: prevus, gymnases: gymnases, jours: 2);
      expect(
          sansStock.lignes.firstWhere((l) => l.produitId == 'n1').quantite, 320);
      final avecStock = listeParDefaut(
        produits: prevus,
        gymnases: gymnases,
        jours: 2,
        stocks: const {'gA': {'n1': 20}},
      );
      expect(
          avecStock.lignes.firstWhere((l) => l.produitId == 'n1').quantite, 300);
      // Avec le menu seul (1,5), le résultat serait autre : 240.
      final menu = listeParDefaut(produits: _produits, gymnases: gymnases, jours: 2);
      expect(menu.lignes.firstWhere((l) => l.produitId == 'n1').quantite, 240);
    });
  });

  group('saisie et affichage', () {
    test('lireConso : 0 à 1000, virgule ou point, le reste refusé', () {
      expect(lireConso('0'), 0);
      expect(lireConso('1000'), 1000);
      expect(lireConso('1,5'), 1.5);
      expect(lireConso('1.25'), 1.25);
      for (final mauvais in ['', ' ', '-0,1', '1000,1', '1001', 'abc', 'NaN', 'Infinity']) {
        expect(lireConso(mauvais), isNull, reason: mauvais);
      }
    });

    test('consoAffichee : 2 décimales au plus, virgule', () {
      expect(consoAffichee(2), '2');
      expect(consoAffichee(1.5), '1,5');
      expect(consoAffichee(1.0 / 3.0), '0,33');
      expect(consoAffichee(0), '0');
    });
  });
}
