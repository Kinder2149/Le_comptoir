// Chantier Menu, événement et courses, étape B5 (décision 48) : le stock gardé à la clôture
// d'un événement pour le suivant. Écrit dans le MÊME lot que la clôture, par celui qui a le
// droit de clôturer ; lu et effacé par la gestion.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  RACINE, MAJ, ecrire, effacer, lire, lot,
} from './outils.mjs';
import {
  ajoutGymnase, chemins, evenement, evenementEnCours, gymnase, produitEvenement,
} from './outilsCaisse.mjs';

const mise = (chemin, fields, masque) => ({
  update: { name: `${RACINE}/${chemin}`, fields },
  updateMask: { fieldPaths: masque },
  currentDocument: { exists: true },
});

const cloturer = (chemin, uid, prenom) => mise(chemin, {
  statut: { stringValue: 'cloture' },
  clotureLe: { timestampValue: '2026-10-01T10:00:00Z' },
  cloturePar: { stringValue: uid },
  clotureParPrenom: { stringValue: prenom },
  forcee: { booleanValue: false },
  nbCaissesOuvertes: { integerValue: '0' },
}, ['statut', 'clotureLe', 'cloturePar', 'clotureParPrenom', 'forcee', 'nbCaissesOuvertes']);

const reste = (id, r, extra = {}) => ecrire(`associations/${id}/restes/${r}`, {
  nomGymnase: 'Gymnase 1', nomProduit: 'Café', quantite: 24, evenementId: 'e1', majLe: MAJ, ...extra,
});

test('le responsable clôture et garde des restes dans le même lot ; la gestion les lit', async () => {
  const { chef, gestionnaire, lea, intrus, id, c } = await evenementEnCours();
  assert.equal(await lot(chef, [
    cloturer(c.evt, chef.uid, 'Chef'),
    reste(id, 'gymnase-1__cafe'),
    reste(id, 'gymnase-1__soda', { nomProduit: 'Soda', quantite: 24 }),
  ]), 200);
  assert.equal(await lire(chef, `associations/${id}/restes/gymnase-1__cafe`), 200);
  assert.equal(await lire(gestionnaire, `associations/${id}/restes/gymnase-1__soda`), 200);
  assert.equal(await lire(lea, `associations/${id}/restes/gymnase-1__cafe`), 403);
  assert.equal(await lire(intrus, `associations/${id}/restes/gymnase-1__cafe`), 403);
});

test('un gestionnaire rattaché à tous les gymnases garde des restes en clôturant', async () => {
  const { gestionnaire, id, c } = await evenementEnCours();
  assert.equal(await lot(gestionnaire, [
    cloturer(c.evt, gestionnaire.uid, 'Gus'),
    reste(id, 'gymnase-1__cafe'),
  ]), 200);
});

test('un gestionnaire non rattaché à tous les gymnases ne garde rien', async () => {
  const { chef, gestionnaire, id, c } = await evenementEnCours();
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  assert.equal(await lot(gestionnaire, [
    cloturer(c.evt, gestionnaire.uid, 'Gus'),
    reste(id, 'gymnase-1__cafe'),
  ]), 403);
  assert.equal(await lot(gestionnaire, [reste(id, 'gymnase-1__cafe')]), 403);
});

test('sans clôture dans le même lot, ou après la clôture : refusé, même pour le responsable', async () => {
  const { chef, id, c } = await evenementEnCours();
  assert.equal(await lot(chef, [reste(id, 'gymnase-1__cafe')]), 403); // événement encore en cours
  assert.equal(await lot(chef, [cloturer(c.evt, chef.uid, 'Chef')]), 200);
  assert.equal(await lot(chef, [reste(id, 'gymnase-1__cafe')]), 403); // déjà clôturé avant le lot
});

test('un bénévole ou un intrus ne garde rien', async () => {
  const { lea, intrus, id, c } = await evenementEnCours();
  assert.equal(await lot(lea, [cloturer(c.evt, lea.uid, 'Lea'), reste(id, 'gymnase-1__cafe')]), 403);
  assert.equal(await lot(intrus, [cloturer(c.evt, intrus.uid, 'X'), reste(id, 'gymnase-1__cafe')]), 403);
  assert.equal(await lot(lea, [reste(id, 'gymnase-1__cafe')]), 403);
});

test('champs bornés : quantité de 1 à 100000, noms de 1 à 40 caractères, identifiant propre, rien en trop', async () => {
  const { chef, id, c } = await evenementEnCours();
  const essai = async (r, extra = {}, champsEnMoins = []) => {
    const w = reste(id, r, extra);
    // Une valeur déjà typée (ex. { doubleValue: 2.5 }) est posée telle quelle.
    for (const [k, v] of Object.entries(extra)) {
      if (v && typeof v === 'object') w.update.fields[k] = v;
    }
    for (const k of champsEnMoins) delete w.update.fields[k];
    return lot(chef, [cloturer(c.evt, chef.uid, 'Chef'), w]);
  };
  for (const [nom, r, extra, moins] of [
    ['quantité 0', 'a__b', { quantite: 0 }],
    ['quantité négative', 'a__b', { quantite: -3 }],
    ['quantité trop grande', 'a__b', { quantite: 100001 }],
    ['quantité texte', 'a__b', { quantite: '24' }],
    ['quantité décimale', 'a__b', { quantite: { doubleValue: 2.5 } }],
    ['nom de gymnase vide', 'a__b', { nomGymnase: '' }],
    ['nom de produit trop long', 'a__b', { nomProduit: 'x'.repeat(41) }],
    ['champ inconnu', 'a__b', { inconnu: 1 }],
    ['date en texte', 'a__b', { majLe: 'hier' }],
    ['événement inexistant', 'a__b', { evenementId: 'zzz' }],
    ['identifiant avec majuscules', 'Gymnase 1__Café', {}],
    ['sans événement', 'a__b', {}, ['evenementId']],
  ]) {
    assert.equal(await essai(r, extra, moins ?? []), 403, nom);
  }
  assert.equal(await essai('a__b', { quantite: 100000, nomProduit: 'x'.repeat(40) }), 200); // témoin
});

test('la gestion efface un reste ; un bénévole ou un intrus non', async () => {
  const { chef, gestionnaire, lea, intrus, id, c } = await evenementEnCours();
  assert.equal(await lot(chef, [
    cloturer(c.evt, chef.uid, 'Chef'),
    reste(id, 'gymnase-1__cafe'), reste(id, 'gymnase-1__soda', { nomProduit: 'Soda' }),
  ]), 200);
  assert.equal(await lot(lea, [effacer(`associations/${id}/restes/gymnase-1__cafe`)]), 403);
  assert.equal(await lot(intrus, [effacer(`associations/${id}/restes/gymnase-1__cafe`)]), 403);
  assert.equal(await lot(gestionnaire, [effacer(`associations/${id}/restes/gymnase-1__cafe`)]), 200);
  assert.equal(await lot(chef, [effacer(`associations/${id}/restes/gymnase-1__soda`)]), 200);
});

test('216 restes (8 gymnases, 27 produits) partent avec la clôture, en un seul lot', async () => {
  const { chef, id, c } = await evenementEnCours();
  const restes = [];
  for (let g = 0; g < 8; g++) {
    for (let p = 0; p < 27; p++) {
      restes.push(reste(id, `gymnase-${g}__produit-${p}`, { nomGymnase: `Gymnase ${g}`, nomProduit: `Produit ${p}`, quantite: 1 + p }));
    }
  }
  assert.equal(await lot(chef, [cloturer(c.evt, chef.uid, 'Chef'), ...restes]), 200);
});

test('reprise : l’événement suivant se crée avec les stocks repris et efface les restes, en un seul lot', async () => {
  const { chef, gestionnaire, id, c } = await evenementEnCours();
  assert.equal(await lot(chef, [
    cloturer(c.evt, chef.uid, 'Chef'),
    reste(id, 'gymnase-1__cafe'),
    reste(id, 'gymnase-1__soda', { nomProduit: 'Soda' }),
  ]), 200);
  const e2 = chemins(id, 'e2', 'h1');
  assert.equal(await lot(gestionnaire, [
    ecrire(e2.evt, evenement()),
    gymnase(id, 'e2', 'h1', { nom: 'Gymnase 1' }),
    produitEvenement(id, 'e2', 'q1'),
    produitEvenement(id, 'e2', 'q2'),
    ecrire(e2.stock('q1', 'h1'), { quantite: 24, reference: 24 }),
    ecrire(e2.stock('q2', 'h1'), { quantite: 24, reference: 24 }),
    effacer(`associations/${id}/restes/gymnase-1__cafe`),
    effacer(`associations/${id}/restes/gymnase-1__soda`),
  ]), 200);
  assert.equal(await lire(chef, `associations/${id}/restes/gymnase-1__cafe`), 404);
  assert.equal(await lire(chef, e2.stock('q1', 'h1')), 200);
});
