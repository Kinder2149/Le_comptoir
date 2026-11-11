// Mission « Prêt pour le tournoi », T4 (décision 78) : ajouter un produit à un événement.
// Le produit part dans le même lot dans l'événement ET dans le menu d'origine, par la gestion,
// en préparation et en cours ; jamais par un bénévole ; jamais une fois l'événement clôturé.
// Nom et prix d'un produit déjà là restent figés.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, assoAvecGestionnaire, ecrire, lire, lot, MAJ, produit, RACINE, entier,
} from './outils.mjs';
import { evenement, ouvrir, produitEvenement } from './outilsCaisse.mjs';

async function avecEvenement() {
  const ctx = await assoAvecGestionnaire();
  const { chef, id } = ctx;
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/menus/m1`, { nom: 'Menu Tournoi', creeLe: MAJ }),
    produit({ id, menu: 'm1', p: 'p1', champs: {} }),
  ]), 200);
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1'),
  ]), 200);
  return ctx;
}

/** Le lot de l'application : le produit dans l'événement ET dans le menu d'origine. */
const ajout = (id, p, champs = {}) => [
  produitEvenement(id, 'e1', p, { champs }),
  produit({ id, menu: 'm1', p, champs }),
];

const cloturer = (id) => lot(admin, [{
  update: { name: `${RACINE}/associations/${id}/evenements/e1`, fields: { statut: { stringValue: 'cloture' } } },
  updateMask: { fieldPaths: ['statut'] },
  currentDocument: { exists: true },
}]);

test('en préparation : la gestion ajoute un produit à l\'événement et au menu', async () => {
  const { chef, gestionnaire, id } = await avecEvenement();
  assert.equal(await lot(chef, ajout(id, 'p2')), 200);
  assert.equal(await lot(gestionnaire, ajout(id, 'p3', { conso: { doubleValue: 0.5 } })), 200);
  for (const p of ['p2', 'p3']) {
    assert.equal(await lire(chef, `associations/${id}/evenements/e1/produits/${p}`), 200);
    assert.equal(await lire(chef, `associations/${id}/menus/m1/produits/${p}`), 200);
  }
});

test('en cours : la gestion ajoute encore un produit', async () => {
  const { chef, gestionnaire, id } = await avecEvenement();
  assert.equal(await ouvrir(id), 200);
  assert.equal(await lot(chef, ajout(id, 'p2')), 200);
  assert.equal(await lot(gestionnaire, ajout(id, 'p3')), 200);
  assert.equal(await lire(chef, `associations/${id}/evenements/e1/produits/p3`), 200);
});

test('un bénévole ne peut pas ajouter de produit (événement, menu, ou les deux)', async () => {
  const { lea, id } = await avecEvenement();
  assert.equal(await lot(lea, ajout(id, 'p2')), 403);
  assert.equal(await ouvrir(id), 200);
  assert.equal(await lot(lea, ajout(id, 'p2')), 403);
  assert.equal(await lot(lea, [produitEvenement(id, 'e1', 'p2')]), 403);
  assert.equal(await lot(lea, [produit({ id, menu: 'm1', p: 'p2' })]), 403);
});

test('événement clôturé : aucun produit ne peut plus être ajouté à l\'événement', async () => {
  const { chef, gestionnaire, id } = await avecEvenement();
  assert.equal(await cloturer(id), 200);
  assert.equal(await lot(chef, ajout(id, 'p2')), 403);
  assert.equal(await lot(gestionnaire, [produitEvenement(id, 'e1', 'p2')]), 403);
});

test('un produit déjà dans l\'événement garde son nom et son prix', async () => {
  const { chef, id } = await avecEvenement();
  assert.equal(await ouvrir(id), 200);
  const maj = (fields, masque) => lot(chef, [{
    update: { name: `${RACINE}/associations/${id}/evenements/e1/produits/p1`, fields },
    updateMask: { fieldPaths: masque },
    currentDocument: { exists: true },
  }]);
  assert.equal(await maj({ nom: { stringValue: 'Autre' } }, ['nom']), 403);
  assert.equal(await maj({ prixCentimes: entier(1) }, ['prixCentimes']), 403);
});

test('le produit ajouté ne peut pas porter de stock (il vit dans les gymnases)', async () => {
  const { chef, id } = await avecEvenement();
  assert.equal(await lot(chef, [
    produitEvenement(id, 'e1', 'p2', { champs: { stock: entier(5) } }),
  ]), 403);
});
