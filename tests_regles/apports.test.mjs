// Mission « Préparer l'événement », étape P10 : les apports nommés (décision 59).
// evenements/{e}/apports/{id} = { produitId, produitNom, nom, parts, prenom, gymnaseId,
// gymnaseNom, uid, creeLe }, créé par un membre dont la caisse ouverte est dans le gymnase,
// dans le même lot que la hausse du stock du produit (même nombre de parts).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { admin, MAJ, ecrire, entier, lire, lot, modifier, RACINE } from './outils.mjs';
import { caisse, evenementEnCours, produitEvenement } from './outilsCaisse.mjs';

const part = { type: { stringValue: 'part' } };

const majStock = (chemin, champs) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: Object.fromEntries(Object.entries(champs).map(([k, v]) => [k, entier(v)])),
  },
  updateMask: { fieldPaths: Object.keys(champs) },
  currentDocument: { exists: true },
});

/** Un apport « Quiche, 8 parts » de Léa pour p5 dans g1 ; [extra] remplace des champs. */
const apport = (chemin, uid, extra = {}) => {
  const brut = Object.fromEntries(Object.entries(extra).filter(([, v]) => v && v.__brut)
    .map(([k, v]) => [k, v.__brut]));
  const simples = Object.fromEntries(Object.entries(extra).filter(([, v]) => !(v && v.__brut)));
  const e = ecrire(chemin, {
    produitId: 'p5',
    produitNom: 'Gâteau salé',
    nom: 'Quiche',
    parts: 8,
    prenom: 'Léa',
    gymnaseId: 'g1',
    gymnaseNom: 'Principal',
    uid,
    creeLe: MAJ,
    ...simples,
  });
  Object.assign(e.update.fields, brut);
  return e;
};

/** Événement en cours, p5 (part, 8 en stock avec référence), caisse de Léa ouverte dans g1. */
async function avecApports() {
  const ctx = await evenementEnCours();
  const { chef, id, c } = ctx;
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p5', { champs: part })]), 200);
  assert.equal(await lot(chef, [ecrire(c.stock('p5'), { quantite: 8, reference: 8 })]), 200);
  assert.equal(await lot(ctx.lea, [caisse(c.caisse(ctx.lea.uid))]), 200);
  const chemin = (n = 'a1') => `${c.evt}/apports/${n}`;
  return { ...ctx, chemin };
}

test('un bénévole déclare un apport avec la hausse du stock ; la gestion le lit, pas un intrus', async () => {
  const { lea, chef, intrus, c, chemin } = await avecApports();
  assert.equal(await lot(lea, [
    majStock(c.stock('p5'), { quantite: 16, reference: 16 }),
    apport(chemin(), lea.uid),
  ]), 200);
  assert.equal(await lire(chef, chemin()), 200);
  assert.equal(await lire(intrus, chemin()), 403);
  // Le bénévole, lui, ne relit pas la liste (réservée à la gestion).
  assert.equal(await lire(lea, chemin()), 403);
});

test('un apport seul, sans la hausse du stock (ou avec un autre nombre), est refusé', async () => {
  const { lea, c, chemin } = await avecApports();
  assert.equal(await lot(lea, [apport(chemin(), lea.uid)]), 403);
  assert.equal(await lot(lea, [
    majStock(c.stock('p5'), { quantite: 13, reference: 13 }),
    apport(chemin(), lea.uid),
  ]), 403);
});

test('nom vide ou fait d’espaces, parts hors 1 à 1000, champ en trop : refusés', async () => {
  const { lea, c, chemin } = await avecApports();
  const avecHausse = (extra, hausse = 8) => lot(lea, [
    majStock(c.stock('p5'), { quantite: 8 + hausse, reference: 8 + hausse }),
    apport(chemin(), lea.uid, extra),
  ]);
  assert.equal(await avecHausse({ nom: '' }), 403);
  assert.equal(await avecHausse({ nom: '   ' }), 403);
  assert.equal(await avecHausse({ nom: 'x'.repeat(41) }), 403);
  assert.equal(await avecHausse({ parts: 0 }, 0), 403);
  assert.equal(await avecHausse({ parts: 1001 }, 1001), 403);
  assert.equal(await avecHausse({ parts: { __brut: { doubleValue: 8.5 } } }), 403);
  assert.equal(await avecHausse({ extra: 'x' }), 403);
  // Bornes acceptées : 1 part, nom de 40 caractères.
  assert.equal(await avecHausse({ parts: 1, nom: 'x'.repeat(40) }, 1), 200);
});

test('apport : refusé au nom d’un autre, hors caisse ouverte, sur produit inconnu ou événement clôturé', async () => {
  const { lea, chef, gestionnaire, c, chemin } = await avecApports();
  const hausse = [majStock(c.stock('p5'), { quantite: 16, reference: 16 })];
  // uid d'un autre membre.
  assert.equal(await lot(lea, [...hausse, apport(chemin(), chef.uid)]), 403);
  // Un gestionnaire sans caisse ouverte dans le gymnase.
  assert.equal(await lot(gestionnaire, [...hausse, apport(chemin(), gestionnaire.uid)]), 403);
  // Produit absent de l'événement.
  assert.equal(await lot(lea, [...hausse, apport(chemin(), lea.uid, { produitId: 'zz' })]), 403);
  // Jamais modifié.
  assert.equal(await lot(lea, [...hausse, apport(chemin(), lea.uid)]), 200);
  assert.equal(await lot(chef, [modifier(chemin(), { nom: 'Autre' })]), 403);
  // Événement clôturé.
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(lea, [
    majStock(c.stock('p5'), { quantite: 24, reference: 24 }),
    apport(chemin('a2'), lea.uid),
  ]), 403);
});
