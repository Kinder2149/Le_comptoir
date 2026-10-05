// Étape 11 : suivi en direct. Le suivi lit des LISTES (toutes les caisses, toutes
// leurs ventes) : seules la gestion y a droit ; un bénévole ne lit que la sienne.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { API, lot } from './outils.mjs';
import { caisse, evenementEnCours, vente } from './outilsCaisse.mjs';

async function lister(u, chemin) {
  const headers = {};
  if (u) headers.Authorization = `Bearer ${u.jeton}`;
  const r = await fetch(`${API}/${chemin}`, { headers });
  const corps = r.status === 200 ? await r.json() : null;
  return { statut: r.status, nb: corps?.documents?.length ?? 0 };
}

/** Léa et le responsable ont chacun une caisse avec une vente. */
async function avecDeuxCaisses() {
  const ctx = await evenementEnCours();
  const { lea, chef, c } = ctx;
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  await lot(chef, [caisse(c.caisse(chef.uid), { prenom: 'Chef' })]);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid))]), 200);
  assert.equal(await lot(chef, [vente(c.vente(chef.uid))]), 200);
  return ctx;
}

test('la gestion liste toutes les caisses et toutes leurs ventes', async () => {
  const { chef, gestionnaire, lea, id } = await avecDeuxCaisses();
  const base = `associations/${id}/evenements/e1/caisses`;
  // Le responsable liste tout. Le gestionnaire (rattaché à g1) ne liste jamais sans
  // filtre sur son gymnase (voir gestionnaires.test.mjs) ; ses ventes se listent par caisse.
  const caisses = await lister(chef, base);
  assert.equal(caisses.statut, 200);
  assert.equal(caisses.nb, 2);
  assert.equal((await lister(gestionnaire, base)).statut, 403);
  for (const g of [chef, gestionnaire]) {
    assert.equal((await lister(g, `${base}/${lea.uid}__g1/ventes`)).nb, 1);
    assert.equal((await lister(g, `${base}/${chef.uid}__g1/ventes`)).nb, 1);
  }
});

test('un bénévole ne liste pas les caisses, ni les ventes des autres', async () => {
  const { lea, chef, id } = await avecDeuxCaisses();
  const base = `associations/${id}/evenements/e1/caisses`;
  assert.equal((await lister(lea, base)).statut, 403); // pas la liste des caisses
  assert.equal((await lister(lea, `${base}/${chef.uid}__g1/ventes`)).statut, 403);
  // Il lit sa propre caisse et ses propres ventes.
  const siennes = await lister(lea, `${base}/${lea.uid}__g1/ventes`);
  assert.equal(siennes.statut, 200);
  assert.equal(siennes.nb, 1);
});

test('un intrus ne liste rien, ni sans connexion', async () => {
  const { intrus, lea, id } = await avecDeuxCaisses();
  const base = `associations/${id}/evenements/e1/caisses`;
  assert.equal((await lister(intrus, base)).statut, 403);
  assert.equal((await lister(intrus, `${base}/${lea.uid}/ventes`)).statut, 403);
  assert.equal((await lister(null, base)).statut, 403);
});
