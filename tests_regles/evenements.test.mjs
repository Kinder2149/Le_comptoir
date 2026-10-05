// Étape 6 : événements. Outils partagés avec regles.test.mjs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, API, RACINE, MAJ, assoAvecGestionnaire, ecrire, modifier, effacer,
  lire, lot, produit,
} from './outils.mjs';

const evenement = (extra = {}) => ({
  nom: 'Tournoi', date: '2026-10-03', statut: 'en_cours',
  modes: ['especes', 'carte'], menuNom: 'Menu Tournoi', creeLe: MAJ, ...extra,
});

/** Produit copié dans un événement. */
const produitEvenement = (id, e, p, extra = {}) => {
  const u = produit({ id, menu: 'x', p, ...extra }).update;
  u.name = `${RACINE}/associations/${id}/evenements/${e}/produits/${p}`;
  return { update: u };
};

async function listerEvenements(u, id, avecFiltre) {
  const structuredQuery = { from: [{ collectionId: 'evenements' }] };
  if (avecFiltre) {
    structuredQuery.where = {
      fieldFilter: {
        field: { fieldPath: 'statut' },
        op: 'EQUAL',
        value: { stringValue: 'en_cours' },
      },
    };
  }
  const r = await fetch(`${API}/associations/${id}:runQuery`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${u.jeton}`,
    },
    body: JSON.stringify({ structuredQuery }),
  });
  return r.status;
}

test('gestion crée un événement avec la copie des produits ; tous les membres le lisent', async () => {
  const { chef, gestionnaire, lea, id } = await assoAvecGestionnaire();
  for (const [qui, e] of [[chef, 'e1'], [gestionnaire, 'e2']]) {
    assert.equal(await lot(qui, [
      ecrire(`associations/${id}/evenements/${e}`, evenement()),
      produitEvenement(id, e, 'p1'),
      produitEvenement(id, e, 'p2'),
    ]), 200);
    assert.equal(await lire(lea, `associations/${id}/evenements/${e}`), 200);
    assert.equal(await lire(lea, `associations/${id}/evenements/${e}/produits/p1`), 200);
    assert.equal(await lire(qui, `associations/${id}/evenements/${e}/produits/p2`), 200);
  }
});

test('le produit d’un événement n’a plus de stock : il vit dans les gymnases', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1', { stock: 20 }),
  ]), 403);
});

test('un bénévole ne crée ni ne modifie d’événement', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  assert.equal(await lot(lea, [ecrire(`associations/${id}/evenements/e9`, evenement())]), 403);
  await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement()), produitEvenement(id, 'e1', 'p1')]);
  assert.equal(await lot(lea, [modifier(`associations/${id}/evenements/e1`, { nom: 'Pirate' })]), 403);
  assert.equal(await lot(lea, [produitEvenement(id, 'e1', 'p9')]), 403);
  assert.equal(await lot(lea, [effacer(`associations/${id}/evenements/e1`)]), 403);
});

test('un intrus ne voit rien des événements', async () => {
  const { chef, intrus, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement()), produitEvenement(id, 'e1', 'p1')]);
  assert.equal(await lire(intrus, `associations/${id}/evenements/e1`), 403);
  assert.equal(await lire(intrus, `associations/${id}/evenements/e1/produits/p1`), 403);
  assert.equal(await listerEvenements(intrus, id, true), 403);
});

test('événement clôturé : invisible pour le bénévole, visible pour la gestion', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  await lot(admin, [
    ecrire(`associations/${id}/evenements/ancien`, evenement({ statut: 'cloture' })),
    produitEvenement(id, 'ancien', 'p1'),
  ]);
  assert.equal(await lire(lea, `associations/${id}/evenements/ancien`), 403);
  assert.equal(await lire(lea, `associations/${id}/evenements/ancien/produits/p1`), 403);
  assert.equal(await lire(chef, `associations/${id}/evenements/ancien`), 200);
  assert.equal(await lire(chef, `associations/${id}/evenements/ancien/produits/p1`), 200);
});

test('la liste des événements : le bénévole doit filtrer sur « en cours »', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement()), produitEvenement(id, 'e1', 'p1')]);
  await lot(admin, [ecrire(`associations/${id}/evenements/ancien`, evenement({ statut: 'cloture' }))]);
  assert.equal(await listerEvenements(lea, id, true), 200);
  assert.equal(await listerEvenements(lea, id, false), 403);
  assert.equal(await listerEvenements(chef, id, false), 200);
});

test('événement : données invalides refusées', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const essai = (extra, e = 'ex') =>
    lot(chef, [ecrire(`associations/${id}/evenements/${e}`, evenement(extra))]);
  assert.equal(await essai({}, 'ok1'), 200); // témoin
  assert.equal(await essai({ modes: [] }), 403);
  assert.equal(await essai({ modes: ['bitcoin'] }), 403);
  assert.equal(await essai({ modes: ['especes', 'bitcoin'] }), 403);
  assert.equal(await essai({ modes: ['especes', 'carte', 'cheque', 'autre', 'autre'] }), 403);
  assert.equal(await essai({ modes: ['especes', 'carte', 'cheque', 'autre'] }, 'ok2'), 200);
  assert.equal(await essai({ nom: '' }), 403);
  assert.equal(await essai({ date: '3/10/2026' }), 403);
  assert.equal(await essai({ statut: 'cloture' }), 403); // né clôturé : interdit
  assert.equal(await essai({ menuNom: '' }), 403);
  assert.equal(await essai({ inconnu: 'x' }), 403);
});

test('un produit copié exige un événement en cours et des données valides', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  await lot(admin, [ecrire(`associations/${id}/evenements/ancien`, evenement({ statut: 'cloture' }))]);
  assert.equal(await lot(chef, [produitEvenement(id, 'ancien', 'p1')]), 403);
  assert.equal(await lot(chef, [
    ecrire(`associations/${id}/evenements/e1`, evenement()),
    produitEvenement(id, 'e1', 'p1', { prix: -5 }),
  ]), 403);
});

test('nom, date et modes modifiables en cours ; menu et statut non ; clôturé figé', async () => {
  const { chef, gestionnaire, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement())]);
  const chemin = `associations/${id}/evenements/e1`;
  assert.equal(await lot(gestionnaire, [modifier(chemin, { nom: 'Nouveau', date: '2026-10-04', modes: ['carte'] })]), 200);
  assert.equal(await lot(chef, [modifier(chemin, { modes: [] })]), 403);
  assert.equal(await lot(chef, [modifier(chemin, { menuNom: 'Autre' })]), 403);
  assert.equal(await lot(chef, [modifier(chemin, { statut: 'cloture' })]), 403);
  await lot(admin, [modifier(chemin, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [modifier(chemin, { nom: 'Trop tard' })]), 403);
});
