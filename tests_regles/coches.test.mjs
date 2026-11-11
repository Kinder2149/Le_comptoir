// Chantier Ergonomie de la gestion, E6 : cases cochées en magasin (décision 65).
// Les cases vivent dans le document « courses/liste » (champs « articles » et « coches »).
// Réservées au responsable et au gestionnaire rattaché à TOUS les gymnases.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RACINE, MAJ, entier, lire, lot } from './outils.mjs';
import { evenementEnCours } from './outilsCaisse.mjs';

const texte = (s) => ({ stringValue: s });
const liste = (extra = {}) => ({
  statut: texte('preparation'),
  lignes: { arrayValue: { values: [{ mapValue: { fields: {
    gymnaseId: texte('g1'), produitId: texte('p1'), quantite: entier(320),
  } } }] } },
  libres: { arrayValue: { values: [] } },
  restes: { arrayValue: { values: [] } },
  majLe: { timestampValue: MAJ.toISOString() },
  articles: { arrayValue: { values: [texte('p:p1'), texte('l:Liquide vaisselle')] } },
  ...extra,
});
const ecrireListe = (chemin, extra = {}) => ({ update: { name: `${RACINE}/${chemin}`, fields: liste(extra) } });
const coches = (...cles) => ({ mapValue: { fields: Object.fromEntries(cles.map((k) => [k, { booleanValue: true }])) } });
const tableau = (valeurs) => ({ arrayValue: { values: valeurs.map(texte) } });
// Écriture partielle, comme l'application (merge) : seuls les champs listés changent.
const partielle = (chemin, champs, masque) => ({
  update: { name: `${RACINE}/${chemin}`, fields: champs },
  updateMask: { fieldPaths: masque ?? Object.keys(champs) },
  currentDocument: { exists: true },
});

test('une case cochée pour un article de la liste : acceptée pour la gestion, pas pour un bénévole', async () => {
  const { chef, gestionnaire, lea, intrus, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l, { coches: coches('p:p1') })]), 200);
  assert.equal(await lot(gestionnaire, [partielle(l, { coches: coches('l:Liquide vaisselle') })]), 200);
  assert.equal(await lot(lea, [partielle(l, { coches: coches('p:p1') })]), 403);
  assert.equal(await lot(intrus, [partielle(l, { coches: coches('p:p1') })]), 403);
  assert.equal(await lire(lea, l), 403);
});

test('une case pour un article absent de la liste est refusée', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l, { coches: coches('p:absent') })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l)]), 200);
  assert.equal(await lot(chef, [partielle(l, { coches: coches('p:absent') })]), 403);
  assert.equal(await lot(chef, [partielle(l, { coches: coches('p:p1') })]), 200);
});

test('cocher n’écrit ni le coût ni le reste de la liste', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l)]), 200);
  assert.equal(await lot(chef, [partielle(l, { coches: coches('p:p1'), coutCentimes: entier(500) })]), 403);
  assert.equal(await lot(chef, [partielle(l, { coches: coches('p:p1'), statut: texte('validee') })]), 403);
});

test('retirer un article de la liste exige de retirer sa case dans le même envoi', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l, { coches: coches('l:Liquide vaisselle') })]), 200);
  // L'article disparaît mais sa case reste : refusé.
  assert.equal(await lot(chef, [partielle(l, { articles: tableau(['p:p1']) })]), 403);
  // Même envoi : la case est retirée (suppression du champ de la map) puis l'article : accepté.
  assert.equal(await lot(chef, [{
    update: { name: `${RACINE}/${l}`, fields: { articles: tableau(['p:p1']) } },
    updateMask: { fieldPaths: ['articles', 'coches.`l:Liquide vaisselle`'] },
    currentDocument: { exists: true },
  }]), 200);
});

test('une liste de 60 lignes libres avec ses articles tient sous la limite de règles', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  const libres = Array.from({ length: 60 }, (_, i) => ({ mapValue: { fields: {
    nom: texte(`L${i}`), quantite: { doubleValue: 2 }, rayon: texte('entretien'),
  } } }));
  const articles = Array.from({ length: 60 }, (_, i) => `l:L${i}`);
  assert.equal(await lot(chef, [ecrireListe(l, { libres: { arrayValue: { values: libres } }, articles: tableau(articles) })]), 200);
});

test('les tailles sont bornées : 150 articles, 150 cases', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  const cent = (n) => Array.from({ length: n }, (_, i) => `p:x${i}`);
  const map = (cles) => ({ mapValue: { fields: Object.fromEntries(cles.map((k) => [k, { booleanValue: true }])) } });
  assert.equal(await lot(chef, [ecrireListe(l, { articles: tableau(cent(151)) })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { articles: tableau(cent(150)), coches: map(cent(151)) })]), 403);
  assert.equal(await lot(chef, [ecrireListe(l, { articles: tableau(cent(150)), coches: map(cent(150)) })]), 200);
});

test('une liste validée ne porte ni articles ni cases', async () => {
  const { chef, c } = await evenementEnCours();
  const l = `${c.evt}/courses/liste`;
  assert.equal(await lot(chef, [ecrireListe(l, { statut: texte('validee') , coches: coches('p:p1') })]), 403);
});
