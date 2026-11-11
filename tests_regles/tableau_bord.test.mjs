// Mission « Ergonomie de la gestion », étape E3 (décision 62) : la prévision vérifiée
// (« C'est vérifié ») est un booléen facultatif de l'événement. Seule la gestion qui règle la
// durée (responsable, ou gestionnaire rattaché à tous les gymnases) l'écrit, seul, tant
// que l'événement n'est pas clôturé. Un bénévole, un gestionnaire partiel, une valeur qui
// n'est pas un booléen ou un autre champ écrit avec elle sont refusés.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAINTENANT, assoAvecGestionnaire, ecrire, entier, lot,
} from './outils.mjs';
import {
  GYM, ajoutGymnase, chemins, evenement, gymnase, ouvrir, produitEvenement, rattachement,
} from './outilsCaisse.mjs';

const mise = (chemin, fields, masque) => ({
  update: { name: `${RACINE}/${chemin}`, fields },
  updateMask: { fieldPaths: masque },
  currentDocument: { exists: true },
});

const verifier = (chemin, valeur = { booleanValue: true }) =>
  mise(chemin, { previsionVerifiee: valeur }, ['previsionVerifiee']);

/** Association + événement e1 NÉ en préparation, un gymnase g1 et un produit p1 ; le
 *  gestionnaire est rattaché à g1 (donc à tous les gymnases, pour l'instant). */
async function enPreparation() {
  const ctx = await assoAvecGestionnaire();
  const c = chemins(ctx.id);
  assert.equal(await lot(ctx.chef, [
    ecrire(c.evt, evenement()),
    gymnase(ctx.id),
    produitEvenement(ctx.id, 'e1', 'p1', { stock: 20 }),
  ]), 200);
  assert.equal(await lot(ctx.chef, [rattachement(ctx.id, 'e1', ctx.gestionnaire.uid, [GYM])]), 200);
  return { ...ctx, c };
}

test('prévision vérifiée : la gestion l’écrit seule, en préparation comme en cours', async () => {
  const { chef, gestionnaire, c, id } = await enPreparation();
  assert.equal(await lot(chef, [verifier(c.evt)]), 200, 'responsable, en préparation');
  assert.equal(await lot(gestionnaire, [verifier(c.evt, { booleanValue: false })]), 200,
    'gestionnaire rattaché à tous les gymnases : on la remet à « à vérifier »');
  await ouvrir(id, 'e1');
  assert.equal(await lot(chef, [verifier(c.evt)]), 200, 'responsable, en cours');
});

test('prévision vérifiée : un bénévole et un intrus ne l’écrivent pas', async () => {
  const { chef, lea, intrus, c, id } = await enPreparation();
  assert.equal(await lot(lea, [verifier(c.evt)]), 403, 'bénévole, en préparation');
  assert.equal(await lot(intrus, [verifier(c.evt)]), 403, 'hors association');
  await ouvrir(id, 'e1');
  assert.equal(await lot(lea, [verifier(c.evt)]), 403, 'bénévole, en cours');
  assert.equal(await lot(chef, [verifier(c.evt)]), 200);
});

test('prévision vérifiée : un gestionnaire rattaché à seulement un gymnase ne l’écrit pas', async () => {
  const { chef, gestionnaire: gus, c, id } = await enPreparation();
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  // Gus n'est rattaché qu'à g1 : il ne gère pas tous les gymnases.
  assert.equal(await lot(gus, [verifier(c.evt)]), 403);
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [GYM, 'g2'])]), 200);
  assert.equal(await lot(gus, [verifier(c.evt)]), 200);
});

test('prévision vérifiée : seulement un booléen (ni texte, ni nombre, ni null)', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [verifier(c.evt, { stringValue: 'oui' })]), 403, 'texte');
  assert.equal(await lot(chef, [verifier(c.evt, entier(1))]), 403, 'nombre');
  assert.equal(await lot(chef, [verifier(c.evt, { nullValue: null })]), 403, 'vide');
  assert.equal(await lot(chef, [verifier(c.evt, { booleanValue: true })]), 200, 'booléen');
});

test('prévision vérifiée : écrite seule, jamais avec un autre champ', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(
    await lot(chef, [mise(c.evt, {
      previsionVerifiee: { booleanValue: true },
      nom: { stringValue: 'Pirate' },
    }, ['previsionVerifiee', 'nom'])]),
    403,
  );
  assert.equal(
    await lot(chef, [mise(c.evt, {
      previsionVerifiee: { booleanValue: true },
      nbJours: { doubleValue: 3 },
    }, ['previsionVerifiee', 'nbJours'])]),
    403,
  );
});

test('prévision vérifiée : refusée une fois l’événement clôturé', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [verifier(c.evt)]), 200);
  // Clôture posée par l'administrateur de l'émulateur (les règles de clôture ne sont pas testées ici).
  assert.equal(await lot(admin, [mise(c.evt, {
    statut: { stringValue: 'cloture' },
    clotureLe: { timestampValue: MAINTENANT },
    cloturePar: { stringValue: chef.uid },
    clotureParPrenom: { stringValue: 'Chef' },
    forcee: { booleanValue: false },
    nbCaissesOuvertes: entier(0),
  }, ['statut', 'clotureLe', 'cloturePar', 'clotureParPrenom', 'forcee', 'nbCaissesOuvertes'])]), 200);
  assert.equal(await lot(chef, [verifier(c.evt, { booleanValue: false })]), 403);
});
