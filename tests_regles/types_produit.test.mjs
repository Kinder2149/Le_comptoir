// Chantier Stock et courses, étape 1 : type, recette, ratio litres/verres et consommation d'un produit.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assoAvecGestionnaire, ecrire, lire, lot, MAJ, produit, RACINE, entier,
} from './outils.mjs';
import { evenement, produitEvenement } from './outilsCaisse.mjs';

const texte = (s) => ({ stringValue: s });
const nombre = (n) => (Number.isInteger(n) ? entier(n) : { doubleValue: n });
const type = (t) => ({ type: texte(t) });
const ingredient = (nom = 'Gruyère', quantite = 25, unite = 'g') => ({
  mapValue: { fields: { nom: texte(nom), quantite: nombre(quantite), unite: texte(unite) } },
});
const recette = (...ings) => ({ ingredients: { arrayValue: { values: ings } } });
const compose = (...ings) => ({ ...type('compose'), ...recette(...ings) });
const plusieurs = (n) => Array.from({ length: n }, (_, i) => ingredient(`Ingrédient ${i}`, 1, 'g'));

const produitMenu = (id, p, champs = {}) => produit({ id, menu: 'm1', p, champs });

async function avecMenu() {
  const ctx = await assoAvecGestionnaire();
  assert.equal(
    await lot(ctx.chef, [ecrire(`associations/${ctx.id}/menus/m1`, { nom: 'Menu', creeLe: MAJ })]),
    200,
  );
  return ctx;
}

test('croque-monsieur composé : trois ingrédients avec fractions, acceptés', async () => {
  const { chef, gestionnaire, id } = await avecMenu();
  const champs = {
    ...compose(ingredient('Pain de mie', 2, 'tranche'), ingredient('Jambon', 0.25, 'tranche'), ingredient('Gruyère', 25, 'g')),
    conso: nombre(2),
  };
  assert.equal(await lot(chef, [produitMenu(id, 'p1', champs)]), 200);
  assert.equal(await lot(gestionnaire, [produitMenu(id, 'p2', champs)]), 200);
  assert.equal(await lire(chef, `associations/${id}/menus/m1/produits/p1`), 200);
});

test('café au litre : ratio verres par litre et consommation acceptés', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'c', { ...type('litre'), verresParLitre: nombre(8), conso: nombre(2) })]), 200);
  assert.equal(await lot(chef, [produitMenu(id, 'c2', { ...type('litre'), verresParLitre: nombre(7.5) })]), 200);
});

test('produits sans type, ou à l\'unité / à la part : toujours acceptés', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'a')]), 200); // produit existant, sans type
  assert.equal(await lot(chef, [produitMenu(id, 'b', type('unite'))]), 200);
  assert.equal(await lot(chef, [produitMenu(id, 'c', { ...type('part'), conso: nombre(1) })]), 200);
});

test('type inconnu refusé', async () => {
  const { chef, id } = await avecMenu();
  for (const faux of ['Compose', 'liquide', '', 'composé']) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', type(faux))]), 403, faux);
  }
  assert.equal(await lot(chef, [produitMenu(id, 'x', { type: nombre(2) })]), 403);
});

test('composé sans ingrédient, ou recette sur un autre type : refusés', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'x', type('compose'))]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'x', compose())]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'x', { ...type('unite'), ...recette(ingredient()) })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'x', recette(ingredient()))]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'x', { ...compose(ingredient()), ingredients: texte('du pain') })]), 403);
});

test('quantité d\'ingrédient à zéro, négative ou illisible : refusée', async () => {
  const { chef, id } = await avecMenu();
  for (const q of [0, -1, -0.5]) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', compose(ingredient('Pain', q, 'tranche')))]), 403, `${q}`);
  }
  const quantiteTexte = { mapValue: { fields: { nom: texte('Pain'), quantite: texte('2'), unite: texte('g') } } };
  assert.equal(await lot(chef, [produitMenu(id, 'x', compose(quantiteTexte))]), 403);
});

test('unités : seulement la liste fixe', async () => {
  const { chef, id } = await avecMenu();
  for (const u of ['unite', 'tranche', 'g', 'kg', 'cl', 'L']) {
    assert.equal(await lot(chef, [produitMenu(id, `u_${u}`, compose(ingredient('X', 1, u)))]), 200, u);
  }
  for (const faux of ['l', 'litre', 'KG', '', 'cuillère']) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', compose(ingredient('X', 1, faux)))]), 403, faux);
  }
});

test('nom d\'ingrédient : 1 à 40 caractères, autres champs interdits', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'a', compose(ingredient('x'.repeat(40))))]), 200);
  assert.equal(await lot(chef, [produitMenu(id, 'b', compose(ingredient('x'.repeat(41))))]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'c', compose(ingredient('')))]), 403);
  const sansUnite = { mapValue: { fields: { nom: texte('A'), quantite: nombre(1) } } };
  assert.equal(await lot(chef, [produitMenu(id, 'e', compose(sansUnite))]), 403);
});

test('20 ingrédients au plus', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'a', compose(...plusieurs(20)))]), 200);
  assert.equal(await lot(chef, [produitMenu(id, 'b', compose(...plusieurs(21)))]), 403);
  // Un ingrédient invalide en dernière position (20e) est bien vérifié.
  const liste = [...plusieurs(19), ingredient('Pain', 0, 'g')];
  assert.equal(await lot(chef, [produitMenu(id, 'c', compose(...liste))]), 403);
});

test('ratio verres par litre : strictement positif, réservé au type litre', async () => {
  const { chef, id } = await avecMenu();
  for (const v of [0, -3]) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', { ...type('litre'), verresParLitre: nombre(v) })]), 403, `${v}`);
  }
  assert.equal(await lot(chef, [produitMenu(id, 'x', type('litre'))]), 403); // ratio obligatoire
  assert.equal(await lot(chef, [produitMenu(id, 'x', { ...type('litre'), verresParLitre: nombre(101) })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'x', { ...type('unite'), verresParLitre: nombre(8) })]), 403);
  assert.equal(await lot(chef, [produitMenu(id, 'x', { ...type('litre'), verresParLitre: texte('8') })]), 403);
});

test('consommation : de 0 à 1000, un nombre', async () => {
  const { chef, id } = await avecMenu();
  for (const c of [0, 0.5, 2, 1000]) {
    assert.equal(await lot(chef, [produitMenu(id, `c${c}`.replace('.', '_'), { conso: nombre(c) })]), 200, `${c}`);
  }
  for (const c of [-1, 1001]) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', { conso: nombre(c) })]), 403, `${c}`);
  }
  assert.equal(await lot(chef, [produitMenu(id, 'x', { conso: texte('2') })]), 403);
});

test('un produit existant se complète : le prix et le stock restent', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produit({ id, menu: 'm1', p: 'f', prix: 100, stock: 12 })]), 200);
  const chemin = `associations/${id}/menus/m1/produits/f`;
  const maj = (champs, masque) => lot(chef, [{
    update: { name: `${RACINE}/${chemin}`, fields: champs },
    updateMask: { fieldPaths: masque },
    currentDocument: { exists: true },
  }]);
  assert.equal(await maj({ ...type('part'), conso: nombre(1) }, ['type', 'conso']), 200);
  // Le document complet reste valide (la règle juge le résultat).
  assert.equal(await maj({ ...compose(ingredient()) }, ['type', 'ingredients']), 200);
  assert.equal(await maj({ ...type('compose') }, ['type']), 200); // garde la recette
  assert.equal(await maj({ ...type('unite') }, ['type']), 403); // recette restée : incohérent
});

test('l\'événement reçoit la copie ; seule l\'image change ensuite', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement())]), 200);
  const fiche = { ...compose(ingredient('Pain de mie', 2, 'tranche')), conso: nombre(2) };
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p1', { champs: fiche })]), 200);
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p2', { champs: { ...type('litre'), verresParLitre: nombre(8) } })]), 200);
  // Une copie incohérente est refusée.
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p3', { champs: type('compose') })]), 403);
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p3', { champs: { ...type('litre'), verresParLitre: nombre(0) } })]), 403);
  // La recette de l'événement ne se modifie pas (nom, prix, fiche figés).
  const chemin = `associations/${id}/evenements/e1/produits/p1`;
  const maj = (champs, masque) => lot(chef, [{
    update: { name: `${RACINE}/${chemin}`, fields: champs },
    updateMask: { fieldPaths: masque },
    currentDocument: { exists: true },
  }]);
  assert.equal(await maj({ ...recette(ingredient('Pain de mie', 3, 'tranche')) }, ['ingredients']), 403);
  assert.equal(await maj({ conso: nombre(5) }, ['conso']), 403);
  assert.equal(await maj({ icone: texte('croque') }, ['icone']), 200);
});
