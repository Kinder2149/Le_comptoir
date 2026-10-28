// Chantier Stock et courses, étape 5 : réglages (jours, personnes) et liste de courses.
// Réservés au responsable et au gestionnaire rattaché à TOUS les gymnases.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, ecrire, effacer, entier, lire, lot, modifier,
} from './outils.mjs';
import { ajoutGymnase, evenementEnCours, rattachement } from './outilsCaisse.mjs';

const liste = (extra = {}) => ({
  statut: { stringValue: 'preparation' },
  lignes: { arrayValue: { values: [{ mapValue: { fields: {
    gymnaseId: { stringValue: 'g1' }, produitId: { stringValue: 'p1' }, quantite: entier(320),
  } } }] } },
  libres: { arrayValue: { values: [{ mapValue: { fields: {
    nom: { stringValue: 'Liquide vaisselle' }, quantite: { doubleValue: 2 },
  } } }] } },
  restes: { arrayValue: { values: [] } },
  majLe: { timestampValue: MAJ.toISOString() },
  ...extra,
});
const ecrireListe = (chemin, extra = {}) => ({ update: { name: `${RACINE}/${chemin}`, fields: liste(extra) } });
const mise = (chemin, champs) => ({
  update: { name: `${RACINE}/${chemin}`, fields: Object.fromEntries(Object.entries(champs).map(([k, v]) => [k, entier(v)])) },
  updateMask: { fieldPaths: Object.keys(champs) },
  currentDocument: { exists: true },
});

test('la liste de courses : responsable et gestionnaire de tous les gymnases seulement', async () => {
  const { chef, gestionnaire, lea, intrus, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l)]), 200);
  assert.equal(await lire(chef, l), 200);
  assert.equal(await lot(gestionnaire, [ecrireListe(l)]), 200); // rattaché à g1, le seul gymnase
  assert.equal(await lire(gestionnaire, l), 200);
  assert.equal(await lot(lea, [ecrireListe(l)]), 403);
  assert.equal(await lire(lea, l), 403);
  assert.equal(await lot(intrus, [ecrireListe(l)]), 403);
  assert.equal(await lire(intrus, l), 403);
});

test('un gestionnaire rattaché à un seul de deux gymnases n’a pas les courses', async () => {
  const { chef, gestionnaire, id, c } = await evenementEnCours();
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(gestionnaire, [ecrireListe(l)]), 403);
  assert.equal(await lire(gestionnaire, l), 403);
  assert.equal(await lot(chef, [rattachement(id, 'e1', gestionnaire.uid, ['g1', 'g2'])]), 200);
  assert.equal(await lot(gestionnaire, [ecrireListe(l)]), 200);
});

test('la liste : un seul document, champs et tailles bornés, événement en cours', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(`${c.evt}/courses/autre`)]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { statut: { stringValue: 'validee' } })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { inconnu: entier(1) })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { majLe: { stringValue: 'hier' } })]), 403);
  const trop = (n) => ({ arrayValue: { values: Array.from({ length: n }, () => ({ mapValue: { fields: {} } })) } });
  assert.equal(await lot(chef, [ecrireListe(l, { lignes: trop(401) })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { libres: trop(61) })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { lignes: trop(400) })]), 200);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [ecrireListe(l)]), 403);
});

test('jours de l’événement et personnes d’un gymnase : bornes et droits', async () => {
  const { chef, gestionnaire, lea, c } = await evenementEnCours();
  assert.equal(await lot(chef, [mise(c.evt, { nbJours: 3 })]), 200);
  assert.equal(await lot(gestionnaire, [mise(c.evt, { nbJours: 2 })]), 200);
  assert.equal(await lot(chef, [mise(c.evt, { nbJours: 0 })]), 403);
  assert.equal(await lot(chef, [mise(c.evt, { nbJours: 31 })]), 403);
  assert.equal(await lot(lea, [mise(c.evt, { nbJours: 3 })]), 403);
  assert.equal(await lot(chef, [mise(c.gymnase(), { personnes: 80 })]), 200);
  assert.equal(await lot(gestionnaire, [mise(c.gymnase(), { personnes: 60 })]), 200);
  assert.equal(await lot(chef, [mise(c.gymnase(), { personnes: -1 })]), 403);
  assert.equal(await lot(chef, [mise(c.gymnase(), { personnes: 1001 })]), 403);
  assert.equal(await lot(lea, [mise(c.gymnase(), { personnes: 5 })]), 403);
  assert.equal(await lot(chef, [mise(c.evt, { nbJours: 5, nbGymnases: 1 })]), 403); // un seul champ à la fois
});

test('la liste de courses ne se supprime pas à la main', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  await lot(chef, [ecrireListe(l)]);
  assert.equal(await lot(chef, [effacer(l)]), 403);
});
