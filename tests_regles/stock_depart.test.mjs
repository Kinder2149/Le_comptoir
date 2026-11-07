// Mission « Préparer l'événement », étape P2 : la marque « repris » du stock de départ.
// Posée à la création par la reprise des restes (true seulement), effacée par la
// correction du chiffre ; les écritures de caisse ne la touchent pas.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RACINE, assoAvecGestionnaire, ecrire, entier, lire, lot } from './outils.mjs';
import {
  GYM, caisse, chemins, evenement, gymnase, ouvrir, produitEvenement, rattachement,
} from './outilsCaisse.mjs';

const vrai = { booleanValue: true };
const faux = { booleanValue: false };

/** Écriture complète d'un document de stock (création ou remplacement). */
const stock = (chemin, quantite, repris) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      quantite: entier(quantite),
      reference: entier(quantite),
      ...(repris === undefined ? {} : { repris }),
    },
  },
});

/** Mise à jour partielle d'un stock. */
const mise = (chemin, fields) => ({
  update: { name: `${RACINE}/${chemin}`, fields },
  updateMask: { fieldPaths: Object.keys(fields) },
  currentDocument: { exists: true },
});

/** Événement en préparation, gymnase g1 (Gus y est rattaché), produit p1 sans stock. */
async function enPreparation() {
  const ctx = await assoAvecGestionnaire();
  const c = chemins(ctx.id);
  assert.equal(await lot(ctx.chef, [
    ecrire(c.evt, evenement()),
    gymnase(ctx.id),
    produitEvenement(ctx.id, 'e1', 'p1'),
  ]), 200);
  assert.equal(await lot(ctx.chef, [rattachement(ctx.id, 'e1', ctx.gestionnaire.uid, [GYM])]), 200);
  return { ...ctx, c };
}

test('repris : posé à true seulement, à la création du stock', async () => {
  const { chef, gestionnaire: gus, c } = await enPreparation();
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, faux)]), 403);
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, { stringValue: 'oui' })]), 403);
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, { integerValue: '1' })]), 403);
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, vrai)]), 200);
  assert.equal(await lire(gus, c.stock('p1')), 200);
});

test('repris : création sans marque toujours possible (saisie à la main)', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24)]), 200);
});

test('repris : la correction du chiffre (document remplacé) efface la marque', async () => {
  const { chef, gestionnaire: gus, c } = await enPreparation();
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, vrai)]), 200);
  // Remplacement sans la marque, par le responsable puis par le gestionnaire rattaché.
  assert.equal(await lot(chef, [stock(c.stock('p1'), 20)]), 200);
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, vrai)]), 200);
  assert.equal(await lot(gus, [stock(c.stock('p1'), 18)]), 200);
});

test('repris : une mise à jour ne peut le passer qu’à true', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24)]), 200);
  assert.equal(await lot(chef, [mise(c.stock('p1'), { repris: faux })]), 403);
  assert.equal(await lot(chef, [mise(c.stock('p1'), { repris: { stringValue: 'x' } })]), 403);
  assert.equal(await lot(chef, [mise(c.stock('p1'), { repris: vrai })]), 200);
});

test('repris : un gestionnaire non rattaché au gymnase ne pose pas de stock', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  assert.equal(await lot(chef, [{
    update: { name: `${RACINE}/${c.gymnase('g2')}`, fields: { nom: { stringValue: 'Annexe' } } },
  }]), 403); // un gymnase ne s'ajoute pas seul : il passe par ajoutGymnase
  void id;
  assert.equal(await lot(gus, [stock(c.stock('p1', 'g2'), 5, vrai)]), 403);
});

test('repris : les écritures de caisse (vente, annulation) ne le modifient pas, et ne peuvent pas le poser', async () => {
  const { chef, lea, id, c } = await enPreparation();
  assert.equal(await lot(chef, [stock(c.stock('p1'), 24, vrai)]), 200);
  assert.equal(await ouvrir(id), 200);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
  // Vente : la quantité seule baisse, la marque reste.
  assert.equal(await lot(lea, [mise(c.stock('p1'), { quantite: entier(23) })]), 200);
  // Une caisse n'efface pas la marque (ni par mise à jour, ni en remplaçant le document).
  assert.equal(await lot(lea, [mise(c.stock('p1'), { quantite: entier(22), repris: faux })]), 403);
  assert.equal(await lot(lea, [stock(c.stock('p1'), 22)]), 403);
});

test('repris : à la création de l’événement, le stock repris et le gymnase partent dans le même lot', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const c = chemins(id, 'e9', 'g9');
  assert.equal(await lot(chef, [
    ecrire(c.evt, evenement({ nbGymnases: 1 })),
    gymnase(id, 'e9', 'g9'),
    produitEvenement(id, 'e9', 'p1'),
    stock(c.stock('p1'), 24, vrai),
  ]), 200);
});

// P6 : l'import d'un classeur écrit les stocks de départ par groupes de 20, en création puis
// en remplacement (rejouer l'import), par le responsable comme par un gestionnaire rattaché.
test('import : 20 stocks dans le même lot, créés puis remplacés (rejouer est sans risque)', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  const ids = Array.from({ length: 20 }, (_, i) => `q${i}`);
  assert.equal(await lot(chef, ids.slice(0, 10).map((p) => produitEvenement(id, 'e1', p))), 200);
  assert.equal(await lot(chef, ids.slice(10).map((p) => produitEvenement(id, 'e1', p))), 200);
  assert.equal(await lot(chef, ids.map((p) => stock(c.stock(p), 5))), 200);
  assert.equal(await lot(chef, ids.map((p) => stock(c.stock(p), 7))), 200);
  assert.equal(await lot(gus, ids.map((p) => stock(c.stock(p), 9))), 200);
  assert.equal(await lire(gus, c.stock('q19')), 200);
});
