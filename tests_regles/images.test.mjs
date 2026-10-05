// Étape 13 : icônes modèles et photos de produits (vignettes stockées avec le produit).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, assoAvecGestionnaire, ecrire, lire, lot, MAJ, produit, RACINE, API, entier,
} from './outils.mjs';
import { evenement, produitEvenement } from './outilsCaisse.mjs';

const ICONES = ['croque', 'salade', 'fruit', 'the', 'cafe', 'barre', 'soda',
  'gateau_sucre', 'gateau_sale', 'crepe', 'biere', 'eau', 'frites', 'glace'];

const octets = (n) => ({ bytesValue: Buffer.alloc(n, 7).toString('base64') });
const icone = (c) => ({ icone: { stringValue: c } });

/** Produit de menu avec champs supplémentaires. */
const produitMenu = (id, menu, p, champs = {}) =>
  produit({ id, menu, p, champs });

async function avecMenu() {
  const ctx = await assoAvecGestionnaire();
  assert.equal(
    await lot(ctx.chef, [ecrire(`associations/${ctx.id}/menus/m1`, { nom: 'Menu', creeLe: MAJ })]),
    200,
  );
  return ctx;
}

test('un produit de menu peut porter une icône modèle et une photo', async () => {
  const { chef, gestionnaire, id } = await avecMenu();
  for (const [qui, p] of [[chef, 'p1'], [gestionnaire, 'p2']]) {
    assert.equal(
      await lot(qui, [produitMenu(id, 'm1', p, { ...icone('croque'), photo: octets(3000) })]),
      200,
    );
    assert.equal(await lire(qui, `associations/${id}/menus/m1/produits/${p}`), 200);
  }
  // Sans image : toujours accepté (les images sont facultatives).
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'p3')]), 200);
});

test('toutes les icônes de la liste fixe sont acceptées, rien d\'autre', async () => {
  const { chef, id } = await avecMenu();
  for (const c of ICONES) {
    assert.equal(await lot(chef, [produitMenu(id, 'm1', `i_${c}`, icone(c))]), 200, c);
  }
  for (const faux of ['licorne', '', 'Croque', 'croque ', 'CAFE', '../x']) {
    assert.equal(await lot(chef, [produitMenu(id, 'm1', 'px', icone(faux))]), 403, `« ${faux} »`);
  }
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'px', { icone: { integerValue: '3' } })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'px', { icone: { booleanValue: true } })]), 403);
});

test('photo : 30 000 octets maximum, et des octets seulement', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'a', { photo: octets(30000) })]), 200);
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'b', { photo: octets(30001) })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'c', { photo: octets(200000) })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'd', { photo: { stringValue: 'http://exemple.fr/photo.jpg' } })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'm1', 'e', { photo: { integerValue: '5' } })]), 403);
});

test('on change ou on retire l\'image d\'un produit existant', async () => {
  const { chef, id } = await avecMenu();
  await lot(chef, [produitMenu(id, 'm1', 'p', { ...icone('cafe'), photo: octets(2000) })]);
  const chemin = `associations/${id}/menus/m1/produits/p`;
  const modifier = (fields, masque) => lot(chef, [{
    update: { name: `${RACINE}/${chemin}`, fields },
    updateMask: { fieldPaths: masque },
    currentDocument: { exists: true },
  }]);
  assert.equal(await modifier({ photo: octets(5000) }, ['photo']), 200); // autre photo
  assert.equal(await modifier({ photo: octets(40000) }, ['photo']), 403); // trop lourde
  assert.equal(await modifier({ ...icone('crepe') }, ['icone']), 200); // autre icône
  assert.equal(await modifier({ ...icone('licorne') }, ['icone']), 403);
  assert.equal(await modifier({}, ['photo']), 200); // photo retirée
  assert.equal(await modifier({}, ['icone']), 200); // icône retirée
  const doc = await (await fetch(`${API}/${chemin}`, {
    headers: { Authorization: `Bearer ${chef.jeton}` },
  })).json();
  assert.equal(doc.fields.photo, undefined);
  assert.equal(doc.fields.icone, undefined);
  assert.equal(doc.fields.nom.stringValue, 'Croque');
});

test('un bénévole ne touche pas aux images des menus', async () => {
  const { lea, id } = await avecMenu();
  assert.equal(await lot(lea, [produitMenu(id, 'm1', 'p', icone('croque'))]), 403);
  assert.equal(await lire(lea, `associations/${id}/menus/m1`), 403);
});

test('les images sont copiées dans l\'événement et lisibles par les bénévoles', async () => {
  const { chef, lea, id } = await avecMenu();
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1', { champs: { ...icone('croque'), photo: octets(4000) } }),
    produitEvenement(id, 'e1', 'p2', { champs: icone('cafe') }),
    produitEvenement(id, 'e1', 'p3'),
  ]), 200);
  const lu = await (await fetch(`${API}/associations/${id}/evenements/e1/produits/p1`, {
    headers: { Authorization: `Bearer ${lea.jeton}` },
  })).json();
  assert.equal(lu.fields.icone.stringValue, 'croque');
  assert.equal(Buffer.from(lu.fields.photo.bytesValue, 'base64').length, 4000);
  // Les mêmes limites s'appliquent à la copie.
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/evenements/e2`, evenement()),
    produitEvenement(id, 'e2', 'p1', { champs: { photo: octets(30001) } }),
  ]), 403);
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/evenements/e3`, evenement()),
    produitEvenement(id, 'e3', 'p1', { champs: icone('licorne') }),
  ]), 403);
});

test('sur l\'événement, un bénévole ne modifie jamais le produit (ni image, ni stock)', async () => {
  const { chef, lea, id } = await avecMenu();
  await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1', { champs: icone('croque') }),
  ]);
  const chemin = `associations/${id}/evenements/e1/produits/p1`;
  const maj = (fields, masque) => lot(lea, [{
    update: { name: `${RACINE}/${chemin}`, fields },
    updateMask: { fieldPaths: masque },
    currentDocument: { exists: true },
  }]);
  assert.equal(await maj({ stock: entier(9) }, ['stock']), 403); // le stock est dans le gymnase
  assert.equal(await maj({ ...icone('crepe') }, ['icone']), 403);
  assert.equal(await maj({ photo: octets(100) }, ['photo']), 403);
  assert.equal(await maj({ stock: entier(8), ...icone('crepe') }, ['stock', 'icone']), 403);
});

test('sur l\'événement en cours, la gestion corrige l\'image seulement (jamais nom, prix, stock)', async () => {
  const { chef, gestionnaire, id } = await avecMenu();
  await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1', { champs: { ...icone('croque'), photo: octets(2000) } }),
  ]);
  const chemin = `associations/${id}/evenements/e1/produits/p1`;
  const maj = (qui, fields, masque) => lot(qui, [{
    update: { name: `${RACINE}/${chemin}`, fields },
    updateMask: { fieldPaths: masque },
    currentDocument: { exists: true },
  }]);
  for (const qui of [chef, gestionnaire]) {
    assert.equal(await maj(qui, { ...icone('crepe') }, ['icone']), 200); // autre icône
    assert.equal(await maj(qui, { photo: octets(5000) }, ['photo']), 200); // autre photo
    assert.equal(await maj(qui, { ...icone('cafe'), photo: octets(100) }, ['icone', 'photo']), 200);
  }
  assert.equal(await maj(chef, {}, ['photo']), 200); // photo retirée
  assert.equal(await maj(chef, {}, ['icone']), 200); // icône retirée
  // Mêmes limites que pour un menu.
  assert.equal(await maj(chef, { ...icone('licorne') }, ['icone']), 403);
  assert.equal(await maj(chef, { photo: octets(30001) }, ['photo']), 403);
  // Nom, prix et stock restent figés, même mêlés à une image.
  assert.equal(await maj(chef, { nom: { stringValue: 'Autre' } }, ['nom']), 403);
  assert.equal(await maj(chef, { prixCentimes: entier(1) }, ['prixCentimes']), 403);
  assert.equal(await maj(chef, { stock: entier(9) }, ['stock']), 403);
  assert.equal(await maj(chef, { ...icone('crepe'), prixCentimes: entier(1) }, ['icone', 'prixCentimes']), 403);
});

test('événement clôturé : les images sont figées', async () => {
  const { chef, id } = await avecMenu();
  await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1', { champs: icone('croque') }),
  ]);
  await lot(admin, [{
    update: { name: `${RACINE}/associations/${id}/evenements/e1`, fields: { statut: { stringValue: 'cloture' } } },
    updateMask: { fieldPaths: ['statut'] },
    currentDocument: { exists: true },
  }]);
  assert.equal(await lot(chef, [{
    update: {
      name: `${RACINE}/associations/${id}/evenements/e1/produits/p1`,
      fields: { ...icone('crepe') },
    },
    updateMask: { fieldPaths: ['icone'] },
    currentDocument: { exists: true },
  }]), 403);
});
