// Chantier Stock et courses, étape 5 : réglages (jours, personnes) et liste de courses.
// Réservés au responsable et au gestionnaire rattaché à TOUS les gymnases.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, ecrire, effacer, entier, lire, lot, modifier,
} from './outils.mjs';
import { ajoutGymnase, evenementEnCours, produitEvenement, rattachement } from './outilsCaisse.mjs';

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

// ---------- étape 6 : validation ----------
const validee = (extra = {}) => liste({
  statut: { stringValue: 'validee' },
  achats: { arrayValue: { values: [{ mapValue: { fields: {
    cle: { stringValue: 'pain de mie|tranche' }, quantite: { doubleValue: 1080 },
  } } }] } },
  rendements: { arrayValue: { values: [{ mapValue: { fields: {
    gymnaseId: { stringValue: 'g1' }, produitId: { stringValue: 'p1' }, quantite: entier(270),
  } } }] } },
  coutCentimes: entier(41250),
  valideeLe: { timestampValue: MAJ.toISOString() },
  ...extra,
});
const ecrireValidee = (chemin, extra = {}) => ({ update: { name: `${RACINE}/${chemin}`, fields: validee(extra) } });
const stockPlus = (chemin, q, ref) => ({
  update: { name: `${RACINE}/${chemin}`, fields: { quantite: entier(q), reference: entier(ref) } },
  updateMask: { fieldPaths: ['quantite', 'reference'] },
  currentDocument: { exists: true },
});

test('valider : la liste devient « validee » avec les stocks, dans un seul lot, puis elle ne bouge plus', async () => {
  const { chef, gestionnaire, lea, id, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l)]), 200);
  // Un bénévole ne valide pas.
  assert.equal(await lot(lea, [ecrireValidee(l)]), 403);
  // Validation par la gestion : stock existant augmenté + stock démarré pour un produit
  // jusque-là sans suivi + liste figée, en un lot.
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'pz', { stock: 5 }), produitEvenement(id, 'e1', 'py')]), 200);
  assert.equal(await lot(gestionnaire, [
    stockPlus(c.stock('pz'), 275, 275),
    ecrire(c.stock('py'), { quantite: 40, reference: 40 }),
    ecrireValidee(l),
  ]), 200);
  assert.equal(await lire(chef, l), 200);
  // Figée : ni retour en préparation, ni nouvelle validation, ni modification.
  assert.equal(await lot(chef, [ecrireListe(l)]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { coutCentimes: entier(1) })]), 403);
  assert.equal(await lot(gestionnaire, [ecrireValidee(l)]), 403);
});

test('valider : champs et bornes du coût, de la liste des achats et des rendements', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  await lot(chef, [ecrireListe(l)]);
  assert.equal(await lot(chef, [ecrireValidee(l, { coutCentimes: entier(-1) })]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { coutCentimes: entier(100000001) })]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { coutCentimes: { stringValue: '12' } })]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { valideeLe: { stringValue: 'hier' } })]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { inconnu: entier(1) })]), 403);
  const trop = (n) => ({ arrayValue: { values: Array.from({ length: n }, () => ({ mapValue: { fields: {} } })) } });
  assert.equal(await lot(chef, [ecrireValidee(l, { rendements: trop(401) })]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { achats: trop(101) })]), 403);
  assert.equal(await lot(chef, [ecrireValidee(l, { rendements: trop(400) })]), 200);
});

test('valider un événement clôturé est refusé', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  await lot(chef, [ecrireListe(l)]);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [ecrireValidee(l)]), 403);
});

test('valider : 13 mises à jour de stock et la liste dans un seul lot', async () => {
  const { chef, id, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  await lot(chef, [ecrireListe(l)]);
  await lot(chef, Array.from({ length: 13 }, (_, k) => produitEvenement(id, 'e1', `v${k}`, { stock: 5 })));
  assert.equal(await lot(chef, [
    ...Array.from({ length: 13 }, (_, k) => stockPlus(c.stock(`v${k}`), 50, 50)),
    ecrireValidee(l),
  ]), 200);
});

// Étape B4 : la durée peut être une demi-journée (0,5), un entier ou un nombre de 0,5 à 30.
const miseNombre = (chemin, champ, n) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: { [champ]: Number.isInteger(n) ? entier(n) : { doubleValue: n } },
  },
  updateMask: { fieldPaths: [champ] },
  currentDocument: { exists: true },
});

test('durée : demi-journée et jours acceptés, hors 0,5 à 30 refusés', async () => {
  const { chef, gestionnaire, lea, c } = await evenementEnCours();
  for (const n of [0.5, 1, 1.5, 30]) {
    assert.equal(await lot(chef, [miseNombre(c.evt, 'nbJours', n)]), 200, `${n}`);
  }
  for (const n of [0, 0.4, -1, 30.5, 31]) {
    assert.equal(await lot(chef, [miseNombre(c.evt, 'nbJours', n)]), 403, `${n}`);
  }
  assert.equal(await lot(gestionnaire, [miseNombre(c.evt, 'nbJours', 0.5)]), 200);
  assert.equal(await lot(lea, [miseNombre(c.evt, 'nbJours', 0.5)]), 403);
});
