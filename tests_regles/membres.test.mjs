// Étape 10 : nomination, activation et retrait des gestionnaires.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import {
  admin, RACINE, MAJ, assoAvecGestionnaire, ecrire, lierGoogle, lire, lot,
  rejoindre, utilisateur,
} from './outils.mjs';
import { evenement, gymnase, produitEvenement, caisse } from './outilsCaisse.mjs';

const mise = (chemin, fields, masque, extra = {}) => ({
  update: { name: `${RACINE}/${chemin}`, fields: { ...fields, ...extra } },
  updateMask: { fieldPaths: [...new Set([...masque, ...Object.keys(extra)])] },
  currentDocument: { exists: true },
});

const membre = (id, uid) => `associations/${id}/membres/${uid}`;
const nommer = (id, uid, extra = {}) =>
  mise(membre(id, uid), { nomme: { booleanValue: true } }, ['nomme'], extra);
/** Retrait : « nomme » est dans le masque mais sans valeur = supprimé. */
const retirer = (id, uid, extra = {}) =>
  mise(membre(id, uid), { role: { stringValue: 'benevole' } }, ['role', 'nomme'], extra);
const activer = (id, uid, extra = {}) =>
  mise(membre(id, uid), { role: { stringValue: 'gestionnaire' } }, ['role', 'nomme'], extra);

async function codeDe(id) {
  const doc = await (await fetch(`http://127.0.0.1:8080/v1/${RACINE}/associations/${id}`, {
    headers: { Authorization: 'Bearer owner' },
  })).json();
  return doc.fields.code.stringValue;
}

/** Un bénévole déjà relié à Google (cas du membre qui active son statut). */
async function beneviloGoogle(id, prenom = 'Zoe') {
  const anonyme = await utilisateur();
  assert.equal(await rejoindre(anonyme, id, await codeDe(id), prenom), 200);
  return lierGoogle(anonyme);
}

async function champ(id, uid, nom) {
  const doc = await (await fetch(`http://127.0.0.1:8080/v1/${RACINE}/${membre(id, uid)}`, {
    headers: { Authorization: 'Bearer owner' },
  })).json();
  return doc.fields[nom];
}

test('le responsable nomme un bénévole : « en attente », il reste bénévole', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  assert.equal(await lot(chef, [nommer(id, zoe.uid)]), 200);
  assert.equal((await champ(id, zoe.uid, 'nomme')).booleanValue, true);
  assert.equal((await champ(id, zoe.uid, 'role')).stringValue, 'benevole');
  // Une seule nomination à la fois.
  assert.equal(await lot(chef, [nommer(id, zoe.uid)]), 403);
});

test('seul le responsable nomme, et pas n’importe qui', async () => {
  const { chef, gestionnaire, lea, intrus, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  assert.equal(await lot(gestionnaire, [nommer(id, zoe.uid)]), 403);
  assert.equal(await lot(zoe, [nommer(id, zoe.uid)]), 403); // pas d'auto-nomination
  assert.equal(await lot(lea, [nommer(id, lea.uid)]), 403);
  assert.equal(await lot(intrus, [nommer(id, zoe.uid)]), 403);
  // Ni le responsable, ni un gestionnaire ne sont nommables.
  assert.equal(await lot(chef, [nommer(id, chef.uid)]), 403);
  assert.equal(await lot(chef, [nommer(id, gestionnaire.uid)]), 403);
  assert.equal(await lot(chef, [nommer(id, zoe.uid)]), 200); // témoin
});

test('une nomination ne change rien d’autre', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  assert.equal(await lot(chef, [nommer(id, zoe.uid, { role: { stringValue: 'gestionnaire' } })]), 403);
  assert.equal(await lot(chef, [nommer(id, zoe.uid, { prenom: { stringValue: 'Autre' } })]), 403);
  assert.equal(await lot(chef, [nommer(id, zoe.uid, { inconnu: { stringValue: 'x' } })]), 403);
  assert.equal(await lot(chef, [mise(membre(id, zoe.uid), { nomme: { booleanValue: false } }, ['nomme'])]), 403);
});

test('en attente = droits de bénévole : ni menus, ni événements, ni clôture', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  await lot(chef, [ecrire(`associations/${id}/menus/m1`, { nom: 'Menu', creeLe: MAJ })]);
  await lot(chef, [ecrire(`associations/${id}/evenements/e1`, evenement()), gymnase(id), produitEvenement(id, 'e1', 'p1')]);
  await lot(chef, [nommer(id, zoe.uid)]);
  assert.equal(await lire(zoe, `associations/${id}/menus/m1`), 403);
  assert.equal(await lot(zoe, [ecrire(`associations/${id}/menus/m2`, { nom: 'X', creeLe: MAJ })]), 403);
  assert.equal(await lot(zoe, [ecrire(`associations/${id}/evenements/e2`, evenement())]), 403);
  // Comme un bénévole : il lit les événements en cours et peut ouvrir sa caisse.
  assert.equal(await lire(zoe, `associations/${id}/evenements/e1`), 200);
  assert.equal(await lot(zoe, [caisse(`associations/${id}/evenements/e1/caisses/${zoe.uid}__g1`, { prenom: 'Zoe' })]), 200);
});

test('activation : le membre nommé, connecté avec Google, devient gestionnaire avec ses droits', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  await lot(chef, [nommer(id, zoe.uid)]);
  assert.equal(await lot(zoe, [activer(id, zoe.uid)]), 200);
  assert.equal((await champ(id, zoe.uid, 'role')).stringValue, 'gestionnaire');
  assert.equal(await champ(id, zoe.uid, 'nomme'), undefined);
  // Ses droits de gestion sont actifs.
  assert.equal(await lot(zoe, [ecrire(`associations/${id}/menus/m1`, { nom: 'Menu', creeLe: MAJ })]), 200);
  assert.equal(await lire(zoe, `associations/${id}/menus/m1`), 200);
  assert.equal(await lot(zoe, [ecrire(`associations/${id}/evenements/e1`, evenement()), produitEvenement(id, 'e1', 'p1')]), 200);
});

test('activation refusée : sans nomination, sans Google, pour un autre, avec autre chose', async () => {
  const { chef, lea, intrus, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id, 'Zoe');
  const max = await beneviloGoogle(id, 'Max');
  // Pas de nomination : pas d'auto-promotion.
  assert.equal(await lot(zoe, [activer(id, zoe.uid)]), 403);
  await lot(chef, [nommer(id, zoe.uid), nommer(id, lea.uid)]);
  // Nommée mais sans Google (compte anonyme) : refusé.
  assert.equal(await lot(lea, [activer(id, lea.uid)]), 403);
  // Pas pour un autre : ni un autre membre, ni un intrus, ni le responsable.
  assert.equal(await lot(max, [activer(id, zoe.uid)]), 403);
  assert.equal(await lot(intrus, [activer(id, zoe.uid)]), 403);
  assert.equal(await lot(chef, [activer(id, zoe.uid)]), 403);
  // Seulement le rôle de gestionnaire, rien d'autre.
  assert.equal(await lot(zoe, [activer(id, zoe.uid, { prenom: { stringValue: 'Autre' } })]), 403);
  assert.equal(await lot(zoe, [mise(membre(id, zoe.uid), { role: { stringValue: 'responsable' } }, ['role', 'nomme'])]), 403);
  assert.equal(await lot(zoe, [activer(id, zoe.uid)]), 200); // témoin
});

test('le responsable retire un gestionnaire : il perd ses droits', async () => {
  const { chef, gestionnaire, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/menus/m1`, { nom: 'Menu', creeLe: MAJ })]);
  assert.equal(await lire(gestionnaire, `associations/${id}/menus/m1`), 200);
  assert.equal(await lot(chef, [retirer(id, gestionnaire.uid)]), 200);
  assert.equal((await champ(id, gestionnaire.uid, 'role')).stringValue, 'benevole');
  assert.equal(await lire(gestionnaire, `associations/${id}/menus/m1`), 403);
  assert.equal(await lot(gestionnaire, [ecrire(`associations/${id}/menus/m2`, { nom: 'X', creeLe: MAJ })]), 403);
});

test('le responsable retire une nomination en attente, puis peut renommer', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  await lot(chef, [nommer(id, zoe.uid)]);
  assert.equal(await lot(chef, [retirer(id, zoe.uid)]), 200);
  assert.equal(await champ(id, zoe.uid, 'nomme'), undefined);
  assert.equal(await lot(zoe, [activer(id, zoe.uid)]), 403); // plus de nomination
  assert.equal(await lot(chef, [nommer(id, zoe.uid)]), 200); // renommable
});

test('retrait : réservé au responsable, et seulement pour un gestionnaire ou un nommé', async () => {
  const { chef, gestionnaire, lea, intrus, id } = await assoAvecGestionnaire();
  const zoe = await beneviloGoogle(id);
  await lot(chef, [nommer(id, zoe.uid)]);
  assert.equal(await lot(gestionnaire, [retirer(id, zoe.uid)]), 403);
  assert.equal(await lot(gestionnaire, [retirer(id, gestionnaire.uid)]), 403); // même pas soi-même
  assert.equal(await lot(lea, [retirer(id, zoe.uid)]), 403);
  assert.equal(await lot(intrus, [retirer(id, gestionnaire.uid)]), 403);
  // Un simple bénévole non nommé n'est pas concerné ; le responsable n'est pas retirable.
  assert.equal(await lot(chef, [retirer(id, lea.uid)]), 403);
  assert.equal(await lot(chef, [retirer(id, chef.uid)]), 403);
  // Le retrait ne change que le rôle.
  assert.equal(await lot(chef, [retirer(id, gestionnaire.uid, { prenom: { stringValue: 'Autre' } })]), 403);
  assert.equal(await lot(chef, [retirer(id, gestionnaire.uid)]), 200); // témoin
});

test('personne ne modifie le prénom d’un membre ; un bénévole ne se supprime pas lui-même', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [mise(membre(id, lea.uid), { prenom: { stringValue: 'Autre' } }, ['prenom'])]), 403);
  assert.equal(await lot(lea, [mise(membre(id, lea.uid), { prenom: { stringValue: 'Autre' } }, ['prenom'])]), 403);
  assert.equal(await lot(lea, [{ delete: `${RACINE}/${membre(id, lea.uid)}` }]), 403);
  assert.equal(await lot(admin, [mise(membre(id, lea.uid), { prenom: { stringValue: 'Lea' } }, ['prenom'])]), 200);
  assert.ok(randomUUID());
});
