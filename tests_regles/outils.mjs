// Outils communs aux tests de règles (émulateurs Auth + Firestore, REST).
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

export const PROJET = 'le-comptoir-60ba8';
export const AUTH = 'http://127.0.0.1:9099';
export const RACINE = `projects/${PROJET}/databases/(default)/documents`;
export const API = `http://127.0.0.1:8080/v1/${RACINE}`;
export const MAINTENANT = '2026-10-01T10:00:00Z';

// ---------- outils ----------
export async function utilisateur() {
  const r = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  assert.equal(r.status, 200);
  const { idToken, localId } = await r.json();
  return { jeton: idToken, uid: localId };
}

/** Compte relié à Google (faux jeton accepté par l'émulateur). */
export async function google(identite = randomUUID()) {
  const idToken = JSON.stringify({
    sub: identite,
    email: `${identite}@test.fr`,
    email_verified: true,
  });
  const r = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        postBody: `id_token=${encodeURIComponent(idToken)}&providerId=google.com`,
        requestUri: 'http://localhost',
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(r.status, 200);
  const { idToken: jeton, localId } = await r.json();
  return { jeton, uid: localId };
}

/** Anonyme rattaché à Google ensuite (cas réel : on crée puis on lie). */
export async function anonymeRattacheAGoogle() {
  const anonyme = await utilisateur();
  const idToken = JSON.stringify({
    sub: randomUUID(),
    email: `${randomUUID()}@test.fr`,
    email_verified: true,
  });
  const r = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idToken: anonyme.jeton,
        postBody: `id_token=${encodeURIComponent(idToken)}&providerId=google.com`,
        requestUri: 'http://localhost',
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(r.status, 200);
  const { idToken: jeton, localId } = await r.json();
  assert.equal(localId, anonyme.uid, 'le rattachement garde l’identifiant');
  return { jeton, uid: localId };
}

/** Administrateur de l'émulateur : ignore les règles (pose un état de test). */
export const admin = { jeton: 'owner', uid: 'admin' };

export const valeur = (v) =>
  v instanceof Date
    ? { timestampValue: MAINTENANT }
    : typeof v === 'number'
      ? { integerValue: String(v) }
      : Array.isArray(v)
      ? { arrayValue: { values: v.map((x) => ({ stringValue: x })) } }
      : { stringValue: v };
export const champs = (o) =>
  Object.fromEntries(Object.entries(o).map(([k, v]) => [k, valeur(v)]));

export const ecrire = (chemin, donnees) => ({
  update: { name: `${RACINE}/${chemin}`, fields: champs(donnees) },
});
export const modifier = (chemin, donnees) => ({
  update: { name: `${RACINE}/${chemin}`, fields: champs(donnees) },
  updateMask: { fieldPaths: Object.keys(donnees) },
  currentDocument: { exists: true },
});
export const effacer = (chemin) => ({ delete: `${RACINE}/${chemin}` });

export async function lot(u, ecritures) {
  const headers = { 'Content-Type': 'application/json' };
  if (u) headers.Authorization = `Bearer ${u.jeton}`;
  // Une écriture peut porter `__avec` : écritures qui partent dans le MÊME lot
  // (ex. ouvrir une caisse = la caisse + son pointeur).
  const aplaties = ecritures.flatMap(({ __avec, ...w }) => [w, ...(__avec ?? [])]);
  const r = await fetch(`${API}:commit`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ writes: aplaties }),
  });
  return r.status;
}

export async function lire(u, chemin) {
  const headers = {};
  if (u) headers.Authorization = `Bearer ${u.jeton}`;
  return (await fetch(`${API}/${chemin}`, { headers })).status;
}

export const MAJ = new Date();
export const codeAleatoire = () =>
  randomUUID().replace(/[^A-Z0-9]/gi, '').toUpperCase().slice(0, 6);

/** Crée une association complète ; renvoie ses identifiants. */
export async function creerAsso(responsable, nom = 'Club Test') {
  const id = randomUUID().replace(/-/g, '').slice(0, 20);
  const code = codeAleatoire();
  const statut = await lot(responsable, [
    ecrire(`associations/${id}`, {
      nom, code, responsableUid: responsable.uid, creeLe: MAJ,
    }),
    ecrire(`associations/${id}/membres/${responsable.uid}`, {
      prenom: 'Chef', role: 'responsable', rejointLe: MAJ, codeUtilise: '',
    }),
    ecrire(`codes/${code}`, { assoId: id }),
    ecrire(`users/${responsable.uid}`, { assoId: id }),
  ]);
  assert.equal(statut, 200, 'création de l’association');
  return { id, code };
}

export const rejoindre = (u, id, code, prenom = 'Lea') =>
  lot(u, [
    ecrire(`associations/${id}/membres/${u.uid}`, {
      prenom, role: 'benevole', rejointLe: MAJ, codeUtilise: code,
    }),
    ecrire(`users/${u.uid}`, { assoId: id }),
  ]);

export async function assoAvecGestionnaire() {
  const chef = await google();
  const gestionnaire = await google();
  const lea = await utilisateur();
  const intrus = await google();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  await lot(admin, [
    ecrire(`associations/${id}/membres/${gestionnaire.uid}`, {
      prenom: 'Gus', role: 'gestionnaire', rejointLe: MAJ, codeUtilise: '',
    }),
  ]);
  return { chef, gestionnaire, lea, intrus, id };
}

export const menu = (nom = 'Menu Tournoi') => ({ nom, creeLe: MAJ });
export const entier = (n) => ({ integerValue: String(n) });
export const produit = (extra = {}) => ({
  update: {
    name: `${RACINE}/associations/${extra.id}/menus/${extra.menu}/produits/${extra.p}`,
    fields: {
      nom: { stringValue: extra.nom ?? 'Croque' },
      prixCentimes: entier(extra.prix ?? 300),
      creeLe: { timestampValue: MAJ },
      ...(extra.stock === undefined ? {} : { stock: entier(extra.stock) }),
      ...(extra.champs ?? {}),
    },
  },
});


/** Rattache un compte Google à un compte existant (même identifiant, nouveau jeton). */
export async function lierGoogle(u) {
  const idToken = JSON.stringify({
    sub: randomUUID(),
    email: `${randomUUID()}@test.fr`,
    email_verified: true,
  });
  const r = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idToken: u.jeton,
        postBody: `id_token=${encodeURIComponent(idToken)}&providerId=google.com`,
        requestUri: 'http://localhost',
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(r.status, 200);
  const { idToken: jeton, localId } = await r.json();
  assert.equal(localId, u.uid);
  return { jeton, uid: localId };
}
