// Mission « Annuler un changement de source », T5 (décision 79 a) :
// evenements/{e}/previsions_annulation/dernier = { lignes: produit -> {conso, source} (400 au
// plus), creeLe }. Lu, écrit et effacé par le responsable ou un gestionnaire rattaché à TOUS les
// gymnases, tant que l'événement est en préparation ou en cours ; un seul document « dernier ».
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RACINE, admin, assoAvecGestionnaire, ecrire, effacer, lire, lot, modifier } from './outils.mjs';
import {
  GYM, ajoutGymnase, chemins, evenement, gymnase, ouvrir, produitEvenement, rattachement,
} from './outilsCaisse.mjs';

const texte = (s) => ({ stringValue: s });
const decimal = (n) => ({ doubleValue: n });
const temps = { timestampValue: '2026-10-01T10:00:00Z' };

/** Une entrée du champ `lignes` : { conso, source }. */
const ligne = (conso = 2, source = 'Événement : Tournoi 2025') => ({
  mapValue: { fields: { conso: decimal(conso), source: texte(source) } },
});
const lignes = (entrees = { p1: ligne() }) => ({ mapValue: { fields: entrees } });

/** Écriture du document d'annulation (création ou remplacement) ou son effacement. */
const annulation = (c, champs) => ({
  update: { name: `${RACINE}/${c.annul}`, fields: champs },
});
const normale = (c, entrees) => annulation(c, { lignes: lignes(entrees), creeLe: temps });

/** Événement en préparation, gymnase g1 (Gus y est rattaché), produits p1 et p2. */
async function enPreparation() {
  const ctx = await assoAvecGestionnaire();
  const c = { ...chemins(ctx.id) };
  c.annul = `${c.evt}/previsions_annulation/dernier`;
  assert.equal(await lot(ctx.chef, [
    ecrire(c.evt, evenement()),
    gymnase(ctx.id),
    produitEvenement(ctx.id, 'e1', 'p1'),
    produitEvenement(ctx.id, 'e1', 'p2'),
  ]), 200);
  assert.equal(await lot(ctx.chef, [rattachement(ctx.id, 'e1', ctx.gestionnaire.uid, [GYM])]), 200);
  return { ...ctx, c };
}

const passerEn = (c, statut) => lot(admin, [modifier(c.evt, { statut })]);

test('droits : le responsable et le gestionnaire rattaché à tous les gymnases écrivent, lisent et effacent', async () => {
  const { chef, gestionnaire: gus, lea, intrus, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c)]), 200);
  assert.equal(await lire(gus, c.annul), 200);
  assert.equal(await lot(gus, [normale(c)]), 200);
  assert.equal(await lot(gus, [effacer(c.annul)]), 200);
  assert.equal(await lire(admin, c.annul), 404);
  // Un bénévole et un inconnu n'écrivent, ne lisent ni n'effacent.
  assert.equal(await lot(chef, [normale(c)]), 200);
  assert.equal(await lot(lea, [normale(c)]), 403);
  assert.equal(await lot(intrus, [normale(c)]), 403);
  assert.equal(await lire(lea, c.annul), 403);
  assert.equal(await lire(intrus, c.annul), 403);
  assert.equal(await lot(lea, [effacer(c.annul)]), 403);
  assert.equal(await lot(intrus, [effacer(c.annul)]), 403);
});

test('droits : un gestionnaire rattaché à un seul de deux gymnases ne lit, n\'écrit ni n\'efface', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c)]), 200);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  assert.equal(await lire(gus, c.annul), 403);
  assert.equal(await lot(gus, [normale(c)]), 403);
  assert.equal(await lot(gus, [effacer(c.annul)]), 403);
  // Rattaché aux deux : il retrouve ses droits.
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [GYM, 'g2'])]), 200);
  assert.equal(await lire(gus, c.annul), 200);
  assert.equal(await lot(gus, [normale(c)]), 200);
});

test('en cours : accepté ; clôturé : écriture et effacement refusés, lecture gardée', async () => {
  const { chef, gestionnaire: gus, c } = await enPreparation();
  assert.equal(await ouvrir(c.evt.split('/')[1]), 200);
  assert.equal(await lot(gus, [normale(c)]), 200);
  assert.equal(await passerEn(c, 'cloture'), 200);
  assert.equal(await lot(chef, [normale(c, { p2: ligne(1) })]), 403);
  assert.equal(await lot(gus, [effacer(c.annul)]), 403);
  assert.equal(await lire(gus, c.annul), 200);
});

test('forme : exactement lignes et creeLe, lignes en carte, 400 entrées au plus', async () => {
  const { chef, c } = await enPreparation();
  // Le chemin doit être « dernier » : un autre nom est refusé.
  assert.equal(await lot(chef, [annulation({ annul: `${c.evt}/previsions_annulation/autre` }, {
    lignes: lignes(), creeLe: temps,
  })]), 403);
  // Champs manquants ou en trop.
  assert.equal(await lot(chef, [annulation(c, { lignes: lignes() })]), 403);
  assert.equal(await lot(chef, [annulation(c, { creeLe: temps })]), 403);
  assert.equal(await lot(chef, [annulation(c, { lignes: lignes(), creeLe: temps, autre: texte('x') })]), 403);
  // lignes doit être une carte, creeLe une date.
  assert.equal(await lot(chef, [annulation(c, { lignes: texte('x'), creeLe: temps })]), 403);
  assert.equal(await lot(chef, [annulation(c, { lignes: lignes(), creeLe: texte('2026') })]), 403);
  // Bornes : 400 entrées acceptées, 401 refusées.
  const entrees = (n) => Object.fromEntries(Array.from({ length: n }, (_, i) => [`p${i}`, ligne()]));
  assert.equal(await lot(chef, [normale(c, entrees(400))]), 200);
  assert.equal(await lot(chef, [normale(c, entrees(401))]), 403);
  // Une carte vide (« d'avant, aucune prévision ») est acceptée.
  assert.equal(await lot(chef, [normale(c, {})]), 200);
});

test('un changement de source rangé puis effacé : le scénario au niveau des règles', async () => {
  const { chef, gestionnaire: gus, c } = await enPreparation();
  // Avant le changement : Croque corrigé à la main, puis document rangé.
  assert.equal(await lot(gus, [normale(c, { p1: ligne(0.8, 'Modifié à la main') })]), 200);
  assert.equal(await lot(chef, [normale(c, { p1: ligne(0.8, 'Modifié à la main') })]), 200);
  assert.equal(await lire(chef, c.annul), 200);
  // L'annulation efface le document ; ensuite il n'existe plus.
  assert.equal(await lot(chef, [effacer(c.annul)]), 200);
  assert.equal(await lire(chef, c.annul), 404);
});

/** Un groupe du club, dans le format du document « groupes ». */
const groupe = (nom = 'Plat') => ({
  mapValue: { fields: { nom: texte(nom), pourcentages: { mapValue: { fields: { 1: decimal(0.7) } } }, produits: { mapValue: { fields: {} } } } },
});
const listeGroupes = (n = 1) => ({ arrayValue: { values: Array.from({ length: n }, () => groupe()) } });
const avecGroupes = (c, groupes) => annulation(c, { lignes: lignes(), creeLe: temps, groupes });

test('groupes du club (V4) : champ facultatif, liste de 40 éléments au plus', async () => {
  const { chef, gestionnaire: gus, lea, c } = await enPreparation();
  // Avec les groupes d'avant : accepté, par le responsable et par le gestionnaire.
  assert.equal(await lot(chef, [avecGroupes(c, listeGroupes(2))]), 200);
  assert.equal(await lot(gus, [avecGroupes(c, listeGroupes(1))]), 200);
  // Une liste vide (« d'avant, aucun groupe ») est acceptée ; sans le champ, comme avant.
  assert.equal(await lot(chef, [avecGroupes(c, listeGroupes(0))]), 200);
  assert.equal(await lot(chef, [normale(c)]), 200);
  // Bornes : 40 acceptés, 41 refusés.
  assert.equal(await lot(chef, [avecGroupes(c, listeGroupes(40))]), 200);
  assert.equal(await lot(chef, [avecGroupes(c, listeGroupes(41))]), 403);
  // Le champ doit être une liste.
  assert.equal(await lot(chef, [avecGroupes(c, texte('x'))]), 403);
  assert.equal(await lot(chef, [avecGroupes(c, lignes())]), 403);
  // Un champ de plus est toujours refusé ; lignes et creeLe restent obligatoires.
  assert.equal(await lot(chef, [annulation(c, {
    lignes: lignes(), creeLe: temps, groupes: listeGroupes(1), autre: texte('x'),
  })]), 403);
  assert.equal(await lot(chef, [annulation(c, { lignes: lignes(), groupes: listeGroupes(1) })]), 403);
  assert.equal(await lot(chef, [annulation(c, { creeLe: temps, groupes: listeGroupes(1) })]), 403);
  // Un bénévole n'écrit toujours pas, avec ou sans groupes.
  assert.equal(await lot(lea, [avecGroupes(c, listeGroupes(1))]), 403);
});

test('groupes du club (V4) : écriture refusée une fois l événement clôturé', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [avecGroupes(c, listeGroupes(1))]), 200);
  assert.equal(await passerEn(c, 'cloture'), 200);
  assert.equal(await lot(chef, [avecGroupes(c, listeGroupes(1))]), 403);
});
