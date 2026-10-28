// Chantier Stock et courses, étape 3 : le stock selon le rôle.
// Un bénévole (caisse ouverte dans le gymnase) ajoute des parts, rien d'autre ; la gestion règle la
// quantité et le total de référence ; « vide » se signale par un document `vides/{produit}`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, ecrire, effacer, entier, lire, lot, modifier,
} from './outils.mjs';
import {
  caisse, evenementEnCours, gymnase, produitEvenement,
} from './outilsCaisse.mjs';

const part = { type: { stringValue: 'part' } };

const majStock = (chemin, champs) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: Object.fromEntries(Object.entries(champs).map(([k, v]) => [k, entier(v)])),
  },
  updateMask: { fieldPaths: Object.keys(champs) },
  currentDocument: { exists: true },
});

const vide = (chemin) => ecrire(chemin, { creeLe: MAJ });

/** Événement avec p1 (unité, 20), p4 (part, 5 : stock ancien, sans référence), p5 (part, 8 avec référence), p2 sans suivi. */
async function avecParts() {
  const ctx = await evenementEnCours();
  const { chef, id, c } = ctx;
  assert.equal(await lot(chef, [
    produitEvenement(id, 'e1', 'p4', { stock: 5, champs: part }),
    produitEvenement(id, 'e1', 'p5', { champs: part }),
  ]), 200);
  assert.equal(await lot(chef, [ecrire(c.stock('p5'), { quantite: 8, reference: 8 })]), 200);
  assert.equal(await lot(ctx.lea, [caisse(c.caisse(ctx.lea.uid))]), 200);
  return ctx;
}

test('un bénévole ajoute des parts : la quantité et la référence montent ensemble, produit « part » seulement', async () => {
  const { lea, c } = await avecParts();
  // Stock ancien sans référence : elle se pose d'après la quantité.
  assert.equal(await lot(lea, [majStock(c.stock('p4'), { quantite: 11, reference: 11 })]), 200);
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 14, reference: 14 })]), 200);
  // Les deux montent d'autant : une référence qui ne suit pas est refusée.
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 20, reference: 15 })]), 403);
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 20, reference: 99 })]), 403);
  // Une baisse présentée comme un ajout.
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 10, reference: 10 })]), 403);
  // Trop d'un coup.
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 1015, reference: 1015 })]), 403);
  // Pas l'ajout sur un produit qui n'est pas une part.
  assert.equal(await lot(lea, [majStock(c.stock('p1'), { quantite: 26, reference: 26 })]), 403);
  // La référence seule ne se change pas.
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { reference: 30 })]), 403);
});

test('la vente et l’annulation d’un bénévole ne touchent toujours que la quantité', async () => {
  const { lea, c } = await avecParts();
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 7 })]), 200); // vente
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 8 })]), 200); // annulation
  assert.equal(await lot(lea, [majStock(c.stock('p1'), { quantite: 19 })]), 200);
});

test('ajout de parts : refusé pour un intrus et dans un gymnase où l’on n’a pas de caisse ouverte', async () => {
  const { chef, gestionnaire, intrus, id, c } = await avecParts();
  assert.equal(await lot(intrus, [majStock(c.stock('p5'), { quantite: 14, reference: 14 })]), 403);
  // Un second gymnase : une caisse ouverte dans g1 ne permet rien dans g2.
  assert.equal(await lot(chef, [
    { ...gymnase(id, 'e1', 'g2', { nom: 'Annexe' }),
      __avec: [{ update: { name: `${RACINE}/${c.evt}`, fields: { nbGymnases: entier(2) } },
        updateMask: { fieldPaths: ['nbGymnases'] }, currentDocument: { exists: true } }] },
  ]), 200);
  assert.equal(await lot(chef, [ecrire(c.stock('p5', 'g2'), { quantite: 3, reference: 3 })]), 200);
  assert.equal(await lot(gestionnaire, [majStock(c.stock('p5', 'g2'), { quantite: 4, reference: 4 })]), 403);
});

test('ajout de parts : refusé sur un événement clôturé', async () => {
  const { lea, c } = await avecParts();
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(lea, [majStock(c.stock('p5'), { quantite: 14, reference: 14 })]), 403);
});

test('la gestion règle la quantité et le total de référence de son gymnase', async () => {
  const { chef, gestionnaire, lea, c } = await avecParts();
  assert.equal(await lot(chef, [majStock(c.stock('p1'), { quantite: 30, reference: 30 })]), 200);
  assert.equal(await lot(gestionnaire, [majStock(c.stock('p1'), { quantite: 12, reference: 12 })]), 200);
  assert.equal(await lot(chef, [majStock(c.stock('p1'), { quantite: 12, reference: -1 })]), 403);
  assert.equal(await lot(chef, [majStock(c.stock('p1'), { quantite: 12, reference: 100001 })]), 403);
  assert.equal(await lot(lea, [majStock(c.stock('p1'), { quantite: 30, reference: 30 })]), 403);
});

test('à la création, le stock peut porter son total de référence (entier de 0 à 100000)', async () => {
  const { chef, id, c } = await avecParts();
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p6', { champs: part })]), 200);
  assert.equal(await lot(chef, [ecrire(c.stock('p6'), { quantite: 4, reference: -2 })]), 403);
  assert.equal(await lot(chef, [ecrire(c.stock('p6'), { quantite: 4, reference: 4, inconnu: 1 })]), 403);
  assert.equal(await lot(chef, [ecrire(c.stock('p6'), { quantite: 4, reference: 4 })]), 200);
});

test('« vide » : la gestion ou un bénévole à sa caisse le signale et le retire ; personne d’autre', async () => {
  const { chef, gestionnaire, lea, intrus, c } = await avecParts();
  const v = `${c.gymnase()}/vides/p2`;
  assert.equal(await lot(lea, [vide(v)]), 200);
  assert.equal(await lire(lea, v), 200);
  assert.equal(await lire(chef, v), 200);
  assert.equal(await lot(lea, [effacer(v)]), 200);
  assert.equal(await lot(gestionnaire, [vide(v)]), 200);
  assert.equal(await lot(chef, [effacer(v)]), 200);
  assert.equal(await lot(chef, [vide(v)]), 200);
  assert.equal(await lot(intrus, [effacer(v)]), 403);
  assert.equal(await lot(intrus, [vide(`${c.gymnase()}/vides/p5`)]), 403);
});

test('« vide » : produit inconnu, champ en trop, sans caisse ouverte ou événement clôturé : refusés', async () => {
  const { chef, lea, gestionnaire, c } = await avecParts();
  const v = `${c.gymnase()}/vides/p2`;
  assert.equal(await lot(chef, [vide(`${c.gymnase()}/vides/inexistant`)]), 403);
  assert.equal(await lot(chef, [ecrire(v, { creeLe: MAJ, inconnu: 'x' })]), 403);
  assert.equal(await lot(chef, [ecrire(v, { creeLe: 'pas une date' })]), 403);
  // Une caisse clôturée (pointeur retiré) ne signale plus rien : on part d'un bénévole sans caisse.
  await lot(admin, [effacer(c.ouverte(lea.uid))]);
  assert.equal(await lot(lea, [vide(v)]), 403);
  assert.equal(await lot(chef, [vide(v)]), 200);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [effacer(v)]), 403);
  assert.equal(await lot(gestionnaire, [vide(`${c.gymnase()}/vides/p4`)]), 403);
});

// ---------- étape 4 : la vente et les stocks partent dans UN MÊME lot ----------
import { MAINTENANT } from './outils.mjs';
import { baisserStock, ligne, vente } from './outilsCaisse.mjs';

const annuler = (chemin, uid) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      annulee: { booleanValue: true },
      annuleePar: { stringValue: uid },
      annuleeParPrenom: { stringValue: 'Lea' },
      annuleeLe: { timestampValue: MAINTENANT },
    },
  },
  updateMask: { fieldPaths: ['annulee', 'annuleePar', 'annuleeParPrenom', 'annuleeLe'] },
  currentDocument: { exists: true },
});

test('une vente de 13 produits et ses 13 baisses de stock passent dans un seul lot, puis son annulation', async () => {
  const { chef, lea, id, c } = await evenementEnCours();
  await lot(chef, Array.from({ length: 13 }, (_, i) => produitEvenement(id, 'e1', `q${i}`, { stock: 10 })));
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const v = c.vente(lea.uid, 'v1');
  const lignes = Array.from({ length: 13 }, () => ligne());
  assert.equal(await lot(lea, [
    vente(v, { lignes: { arrayValue: { values: lignes } } }),
    ...Array.from({ length: 13 }, (_, i) => baisserStock(c.stock(`q${i}`), 9)),
  ]), 200);
  assert.equal(await lot(lea, [
    annuler(v, lea.uid),
    ...Array.from({ length: 13 }, (_, i) => baisserStock(c.stock(`q${i}`), 10)),
  ]), 200);
});

test('dans un lot, une baisse refusée annule aussi la vente', async () => {
  const { lea, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const v = c.vente(lea.uid, 'v9');
  assert.equal(await lot(lea, [vente(v), baisserStock(c.stock('p1'), -100001)]), 403);
  assert.equal(await lire(lea, v), 404); // la vente n'a pas été écrite
});
