// Mission « Ergonomie de la gestion », étape E1 : familles de produits et rayons des courses.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assoAvecGestionnaire, ecrire, lot, MAJ, produit, RACINE, entier,
} from './outils.mjs';
import { evenement, evenementEnCours, produitEvenement } from './outilsCaisse.mjs';

const texte = (s) => ({ stringValue: s });
const nombre = (n) => (Number.isInteger(n) ? entier(n) : { doubleValue: n });
const FAMILLES = ['croques', 'boissons_chaudes', 'boissons_fraiches', 'snacks_fruits', 'fait_maison', 'autre'];
const RAYONS = ['boulangerie', 'frais', 'boissons', 'epicerie', 'entretien', 'autre'];

const ingredient = (nom = 'Gruyère', rayon) => ({
  mapValue: {
    fields: {
      nom: texte(nom), quantite: nombre(25), unite: texte('g'),
      ...(rayon === undefined ? {} : { rayon: texte(rayon) }),
    },
  },
});
const compose = (...ings) => ({ type: texte('compose'), ingredients: { arrayValue: { values: ings } } });
const produitMenu = (id, p, champs = {}) => produit({ id, menu: 'm1', p, champs });

async function avecMenu() {
  const ctx = await assoAvecGestionnaire();
  assert.equal(
    await lot(ctx.chef, [ecrire(`associations/${ctx.id}/menus/m1`, { nom: 'Menu', creeLe: MAJ })]),
    200,
  );
  return ctx;
}

test('famille : les six valeurs de la liste sont acceptées, absente aussi', async () => {
  const { chef, gestionnaire, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'sans')]), 200); // produit d'avant E1
  for (const f of FAMILLES) {
    assert.equal(await lot(chef, [produitMenu(id, `f_${f}`, { famille: texte(f) })]), 200, f);
  }
  assert.equal(await lot(gestionnaire, [produitMenu(id, 'g', { famille: texte('croques') })]), 200);
});

test('famille hors liste refusée', async () => {
  const { chef, id } = await avecMenu();
  for (const faux of ['desserts', 'Croques', '', 'croques ']) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', { famille: texte(faux) })]), 403, faux);
  }
  assert.equal(await lot(chef, [produitMenu(id, 'x', { famille: nombre(2) })]), 403);
});

test('rayon d\'un produit acheté tel quel : liste fixe, hors liste refusé', async () => {
  const { chef, id } = await avecMenu();
  for (const r of RAYONS) {
    assert.equal(await lot(chef, [produitMenu(id, `r_${r}`, { rayon: texte(r) })]), 200, r);
  }
  for (const faux of ['surgeles', 'Boissons', '']) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', { rayon: texte(faux) })]), 403, faux);
  }
});

test('rayon d\'un ingrédient : liste fixe, absent accepté, hors liste refusé', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [produitMenu(id, 'a', compose(ingredient('Pain de mie', 'boulangerie'), ingredient('Gruyère', 'frais'), ingredient('Beurre')))]), 200);
  for (const r of RAYONS) {
    assert.equal(await lot(chef, [produitMenu(id, `i_${r}`, compose(ingredient('Pain', r)))]), 200, r);
  }
  for (const faux of ['surgeles', 'Frais', '']) {
    assert.equal(await lot(chef, [produitMenu(id, 'x', compose(ingredient('Pain', 'boulangerie'), ingredient('Lait', faux)))]), 403, faux);
  }
  assert.equal(await lot(chef, [produitMenu(id, 'x', compose({ mapValue: { fields: { ...ingredient('Lait').mapValue.fields, rayon: nombre(3) } } }))]), 403);
});

test('20 ingrédients portant tous un rayon : acceptés (menu et événement), le 21e refusé', async () => {
  const { chef, id } = await avecMenu();
  const vingt = (n) => Array.from({ length: n }, (_, i) => ingredient(`Ingrédient ${i}`, RAYONS[i % RAYONS.length]));
  assert.equal(await lot(chef, [produitMenu(id, 'p20', { ...compose(...vingt(20)), famille: texte('croques') })]), 200);
  assert.equal(await lot(chef, [produitMenu(id, 'p21', compose(...vingt(21)))]), 403);
  assert.equal(await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement())]), 200);
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p20', { champs: { ...compose(...vingt(20)), famille: texte('croques') } })]), 200);
  // Dernier ingrédient hors liste : refusé même en position 20.
  const avecFaux = [...vingt(19), ingredient('Dernier', 'surgeles')];
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'pf', { champs: compose(...avecFaux) })]), 403);
});

test('copie dans l\'événement : famille et rayon acceptés, hors liste refusés', async () => {
  const { chef, id } = await avecMenu();
  assert.equal(await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement())]), 200);
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'a', { champs: { famille: texte('boissons_fraiches'), rayon: texte('boissons') } })]), 200);
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'b', { champs: { famille: texte('desserts') } })]), 403);
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'c', { champs: { rayon: texte('surgeles') } })]), 403);
});

const listeAvec = (chemin, libres) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      statut: texte('preparation'),
      lignes: { arrayValue: { values: [] } },
      libres: { arrayValue: { values: libres } },
      restes: { arrayValue: { values: [] } },
      majLe: { timestampValue: MAJ.toISOString() },
    },
  },
});
const libre = (nom, rayon) => ({
  mapValue: { fields: { nom: texte(nom), quantite: { doubleValue: 2 }, ...(rayon === undefined ? {} : { rayon: texte(rayon) }) } },
});

test('ligne libre de courses : rayon de la liste fixe, absent accepté, hors liste refusé', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [listeAvec(l, [libre('Sacs poubelle', 'entretien'), libre('Gobelets')])]), 200);
  for (const r of RAYONS) {
    assert.equal(await lot(chef, [listeAvec(l, [libre('X', r)])]), 200, r);
  }
  assert.equal(await lot(chef, [listeAvec(l, [libre('X', 'surgeles')])]), 403);
  assert.equal(await lot(chef, [listeAvec(l, [libre('A', 'frais'), libre('B', 'Frais')])]), 403);
  const soixante = Array.from({ length: 60 }, (_, i) => libre(`L${i}`, RAYONS[i % RAYONS.length]));
  assert.equal(await lot(chef, [listeAvec(l, soixante)]), 200);
  assert.equal(await lot(chef, [listeAvec(l, [...soixante.slice(0, 59), libre('Dernier', 'surgeles')])]), 403);
});
