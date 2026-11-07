// Mission « Préparer l'événement », étape P6 : les références de consommation importées d'un
// classeur Excel, associations/{a}/references/{id} = { nom (1 à 60), lignes[] {nom (1 à 40),
// conso (0 à 1000)} (0 à 200), creeLe }. Identifiant = clé normalisée du nom (1 à 100 caractères
// de [a-z0-9_-]). Lues, écrites et supprimées par la gestion de l'association.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RACINE, admin, assoAvecGestionnaire, effacer, lire, lot } from './outils.mjs';

const texte = (s) => ({ stringValue: s });
const entier = (n) => ({ integerValue: String(n) });
const decimal = (n) => ({ doubleValue: n });
const instant = { timestampValue: '2026-10-01T10:00:00Z' };

/** Une ligne de référence {nom, conso}. */
const ligne = (nom = 'Croque', conso = decimal(2), extra = {}) => ({
  mapValue: { fields: { nom: typeof nom === 'string' ? texte(nom) : nom, conso, ...extra } },
});
const liste = (lignes) => ({ arrayValue: { values: lignes } });
const lignesOk = (n) => liste(Array.from({ length: n }, (_, i) => ligne(`Produit ${i}`, decimal(1.5))));

const reference = (chemin, champs) => ({
  update: { name: `${RACINE}/${chemin}`, fields: champs },
});
const normale = (chemin, surcharge = {}) => reference(chemin, {
  nom: texte('Tournoi 2025 (Excel)'),
  lignes: liste([ligne('Croque', decimal(2)), ligne('Soda', entier(1))]),
  creeLe: instant,
  ...surcharge,
});

const chemin = (id, r = 'tournoi-2025-excel') => `associations/${id}/references/${r}`;

test('droits : le responsable et le gestionnaire écrivent, lisent et remplacent', async () => {
  const { chef, gestionnaire: gus, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [normale(chemin(id))]), 200);
  assert.equal(await lot(gus, [normale(chemin(id, 'autre'))]), 200);
  assert.equal(await lire(chef, chemin(id)), 200);
  assert.equal(await lire(gus, chemin(id, 'autre')), 200);
  // Remplacement d'une référence de même identifiant.
  assert.equal(await lot(gus, [normale(chemin(id), { lignes: liste([ligne('Café', decimal(0.5))]) })]), 200);
});

test('un bénévole, un inconnu et un visiteur sans compte n\'écrivent ni ne lisent', async () => {
  const { chef, lea, intrus, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [normale(chemin(id))]), 200);
  for (const u of [lea, intrus, null]) {
    assert.equal(await lot(u, [normale(chemin(id, 'x'))]), 403);
    assert.equal(await lot(u, [normale(chemin(id))]), 403);
    assert.equal(await lire(u, chemin(id)), 403);
    assert.equal(await lot(u, [effacer(chemin(id))]), 403);
  }
  assert.equal(await lire(admin, chemin(id)), 200);
});

test('la gestion lit la liste des références, un bénévole non', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [normale(chemin(id))]), 200);
  const liste = (u) => fetch(`http://127.0.0.1:8080/v1/${RACINE}/associations/${id}/references`, {
    headers: { Authorization: `Bearer ${u.jeton}` },
  }).then((r) => r.status);
  assert.equal(await liste(chef), 200);
  assert.equal(await liste(lea), 403);
});

test('nom de la référence : 1 à 60 caractères', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const avec = (nom) => lot(chef, [normale(chemin(id), { nom })]);
  assert.equal(await avec(texte('a')), 200);
  assert.equal(await avec(texte('x'.repeat(60))), 200);
  assert.equal(await avec(texte('x'.repeat(61))), 403);
  assert.equal(await avec(texte('')), 403);
  assert.equal(await avec(entier(3)), 403);
});

test('identifiant : [a-z0-9_-], 1 à 100 caractères', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const avec = (r) => lot(chef, [normale(chemin(id, r))]);
  assert.equal(await avec('tournoi-2025-excel'), 200);
  assert.equal(await avec('a_b-9'), 200);
  assert.equal(await avec('x'.repeat(100)), 200);
  assert.equal(await avec('x'.repeat(101)), 403);
  assert.equal(await avec('Tournoi'), 403);
  assert.equal(await avec('tournoi%202025'), 403);
  assert.equal(await avec('é'), 403);
});

test('champs exactement nom, lignes et creeLe', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const c = chemin(id);
  assert.equal(await lot(chef, [reference(c, { nom: texte('T'), lignes: liste([]) })]), 403);
  assert.equal(await lot(chef, [reference(c, { nom: texte('T'), creeLe: instant })]), 403);
  assert.equal(await lot(chef, [reference(c, { lignes: liste([]), creeLe: instant })]), 403);
  assert.equal(await lot(chef, [normale(c, { autre: entier(1) })]), 403);
  assert.equal(await lot(chef, [normale(c, { creeLe: texte('hier') })]), 403);
  assert.equal(await lot(chef, [reference(c, { nom: texte('T'), lignes: liste([]), creeLe: instant })]), 200);
});

test('consommation d\'une ligne : nombre de 0 à 1000', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const avec = (conso) => lot(chef, [normale(chemin(id), { lignes: liste([ligne('Croque', conso)]) })]);
  assert.equal(await avec(entier(0)), 200);
  assert.equal(await avec(decimal(0)), 200);
  assert.equal(await avec(decimal(2.5)), 200);
  assert.equal(await avec(entier(1000)), 200);
  assert.equal(await avec(decimal(1000)), 200);
  assert.equal(await avec(decimal(1000.5)), 403);
  assert.equal(await avec(entier(1001)), 403);
  assert.equal(await avec(decimal(-0.1)), 403);
  assert.equal(await avec(entier(-1)), 403);
  assert.equal(await avec(texte('2')), 403);
  assert.equal(await avec({ nullValue: null }), 403);
});

test('nom d\'un produit de la ligne : 1 à 40 caractères, texte', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const avec = (nom) => lot(chef, [normale(chemin(id), { lignes: liste([ligne(nom)]) })]);
  assert.equal(await avec('a'), 200);
  assert.equal(await avec('x'.repeat(40)), 200);
  assert.equal(await avec('x'.repeat(41)), 403);
  assert.equal(await avec(''), 403);
  assert.equal(await avec(entier(4)), 403);
});

test('une ligne a un nom et une consommation, et c\'est un objet', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const avec = (l) => lot(chef, [normale(chemin(id), { lignes: liste([l]) })]);
  assert.equal(await avec({ mapValue: { fields: { nom: texte('Croque') } } }), 403);
  assert.equal(await avec({ mapValue: { fields: { conso: decimal(1) } } }), 403);
  assert.equal(await avec(texte('Croque')), 403);
  assert.equal(await avec(entier(2)), 403);
});

test('taille de la liste : 0 à 200 lignes', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const avec = (lignes) => lot(chef, [normale(chemin(id), { lignes })]);
  assert.equal(await avec(liste([])), 200);
  assert.equal(await avec(lignesOk(1)), 200);
  assert.equal(await avec(lignesOk(200)), 200);
  assert.equal(await avec(lignesOk(201)), 403);
  assert.equal(await avec(texte('pas une liste')), 403);
  assert.equal(await avec({ mapValue: { fields: {} } }), 403);
});

// Les règles vérifient les 12 premières lignes une à une (une requête ne peut pas évaluer plus de
// 1000 expressions) ; l'application n'écrit jamais de ligne invalide et ignore à la lecture celles
// qui le seraient.
test('une ligne invalide parmi les 12 premières est refusée', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  const base = Array.from({ length: 12 }, (_, i) => ligne(`P${i}`, decimal(1)));
  const avecLigne = (position, l) => {
    const lignes = [...base];
    lignes[position] = l;
    return lot(chef, [normale(chemin(id), { lignes: liste(lignes) })]);
  };
  assert.equal(await avecLigne(0, ligne('Croque', decimal(-1))), 403);
  assert.equal(await avecLigne(6, ligne('Croque', decimal(1001))), 403);
  assert.equal(await avecLigne(11, ligne('', decimal(1))), 403);
  assert.equal(await avecLigne(11, ligne('x'.repeat(41), decimal(1))), 403);
  assert.equal(await avecLigne(11, ligne('Croque', decimal(1))), 200);
});

test('une référence se remplace (même identifiant) et change de contenu', async () => {
  const { chef, gestionnaire: gus, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [normale(chemin(id))]), 200);
  assert.equal(await lot(gus, [normale(chemin(id), { lignes: liste([ligne('Café', decimal(3))]) })]), 200);
  assert.equal(await lire(admin, chemin(id)), 200);
});

test('suppression : la gestion efface, un bénévole non', async () => {
  const { chef, gestionnaire: gus, lea, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [normale(chemin(id)), normale(chemin(id, 'b'))]), 200);
  assert.equal(await lot(lea, [effacer(chemin(id))]), 403);
  assert.equal(await lot(gus, [effacer(chemin(id))]), 200);
  assert.equal(await lot(chef, [effacer(chemin(id, 'b'))]), 200);
  assert.equal(await lire(admin, chemin(id)), 404);
  assert.equal(await lire(admin, chemin(id, 'b')), 404);
});

test('suppression de l\'association : le responsable efface les références après le drapeau', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  assert.equal(await lot(chef, [normale(chemin(id)), normale(chemin(id, 'b'))]), 200);
  const drapeau = {
    update: { name: `${RACINE}/associations/${id}`, fields: { suppression: { booleanValue: true } } },
    updateMask: { fieldPaths: ['suppression'] },
    currentDocument: { exists: true },
  };
  assert.equal(await lot(chef, [drapeau]), 200);
  assert.equal(await lot(lea, [effacer(chemin(id))]), 403);
  assert.equal(await lot(chef, [effacer(chemin(id)), effacer(chemin(id, 'b'))]), 200);
  assert.equal(await lire(admin, chemin(id)), 404);
});
