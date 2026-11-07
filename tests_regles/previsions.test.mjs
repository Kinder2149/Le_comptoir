// Mission « Préparer l'événement », étape P4 : la prévision de consommation,
// evenements/{e}/previsions/{produitId} = { conso: nombre 0 à 1000, source: texte 1 à 80 }.
// Lue et écrite par le responsable ou un gestionnaire rattaché à TOUS les gymnases, tant que
// l'événement est en préparation ou en cours ; le produit doit exister dans l'événement.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RACINE, admin, assoAvecGestionnaire, ecrire, effacer, lire, lot, modifier } from './outils.mjs';
import {
  GYM, ajoutGymnase, chemins, evenement, gymnase, ouvrir, produitEvenement, rattachement,
} from './outilsCaisse.mjs';

const texte = (s) => ({ stringValue: s });
const entier = (n) => ({ integerValue: String(n) });
const decimal = (n) => ({ doubleValue: n });

/** Écriture d'une prévision (création ou remplacement). */
const prevision = (chemin, champs) => ({
  update: { name: `${RACINE}/${chemin}`, fields: champs },
});
const normale = (chemin, conso = decimal(2), source = texte('Événement : Tournoi 2025')) =>
  prevision(chemin, { conso, source });

/** Événement en préparation, gymnase g1 (Gus y est rattaché), produits p1 et p2. */
async function enPreparation() {
  const ctx = await assoAvecGestionnaire();
  const c = { ...chemins(ctx.id) };
  c.prevision = (p) => `${c.evt}/previsions/${p}`;
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

test('droits : le responsable et le gestionnaire rattaché à tous les gymnases écrivent et lisent', async () => {
  const { chef, gestionnaire: gus, lea, intrus, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('p1'))]), 200);
  assert.equal(await lot(gus, [normale(c.prevision('p2'))]), 200);
  assert.equal(await lire(chef, c.prevision('p1')), 200);
  assert.equal(await lire(gus, c.prevision('p2')), 200);
  // Un bénévole et un inconnu n'écrivent ni ne lisent.
  assert.equal(await lot(lea, [normale(c.prevision('p1'))]), 403);
  assert.equal(await lot(intrus, [normale(c.prevision('p1'))]), 403);
  assert.equal(await lire(lea, c.prevision('p1')), 403);
  assert.equal(await lire(intrus, c.prevision('p1')), 403);
});

test('droits : un gestionnaire rattaché à un seul de deux gymnases ne lit ni n\'écrit', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('p1'))]), 200);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  assert.equal(await lot(gus, [normale(c.prevision('p1'), decimal(1))]), 403);
  assert.equal(await lire(gus, c.prevision('p1')), 403);
  assert.equal(await lot(gus, [effacer(c.prevision('p1'))]), 403);
  // Rattaché aux deux : il retrouve ses droits.
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [GYM, 'g2'])]), 200);
  assert.equal(await lot(gus, [normale(c.prevision('p1'), decimal(1))]), 200);
  assert.equal(await lire(gus, c.prevision('p1')), 200);
});

test('bornes du chiffre : 0 à 1000, nombre seulement (entier ou décimal)', async () => {
  const { chef, c } = await enPreparation();
  const ecrireConso = (conso) => lot(chef, [normale(c.prevision('p1'), conso)]);
  assert.equal(await ecrireConso(entier(0)), 200);
  assert.equal(await ecrireConso(decimal(0)), 200);
  assert.equal(await ecrireConso(entier(3)), 200);
  assert.equal(await ecrireConso(decimal(2.5)), 200);
  assert.equal(await ecrireConso(decimal(1000)), 200);
  assert.equal(await ecrireConso(entier(1000)), 200);
  assert.equal(await ecrireConso(decimal(1000.5)), 403);
  assert.equal(await ecrireConso(entier(1001)), 403);
  assert.equal(await ecrireConso(decimal(-0.1)), 403);
  assert.equal(await ecrireConso(entier(-1)), 403);
  assert.equal(await ecrireConso(texte('2')), 403);
  assert.equal(await ecrireConso({ booleanValue: true }), 403);
  assert.equal(await ecrireConso({ nullValue: null }), 403);
});

test('la source : texte de 1 à 80 caractères', async () => {
  const { chef, c } = await enPreparation();
  const ecrireSource = (source) => lot(chef, [normale(c.prevision('p1'), decimal(2), source)]);
  assert.equal(await ecrireSource(texte('Modifié à la main')), 200);
  assert.equal(await ecrireSource(texte('Menu')), 200);
  assert.equal(await ecrireSource(texte('x'.repeat(80))), 200);
  assert.equal(await ecrireSource(texte('x'.repeat(81))), 403);
  assert.equal(await ecrireSource(texte('')), 403);
  assert.equal(await ecrireSource(entier(3)), 403);
});

test('champs exactement conso et source', async () => {
  const { chef, c } = await enPreparation();
  const chemin = c.prevision('p1');
  assert.equal(await lot(chef, [prevision(chemin, { conso: decimal(2) })]), 403);
  assert.equal(await lot(chef, [prevision(chemin, { source: texte('Menu') })]), 403);
  assert.equal(await lot(chef, [prevision(chemin, {
    conso: decimal(2), source: texte('Menu'), autre: entier(1),
  })]), 403);
  assert.equal(await lot(chef, [normale(chemin)]), 200);
});

test('un produit qui n\'existe pas dans l\'événement est refusé', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('inconnu'))]), 403);
  assert.equal(await lire(admin, c.prevision('inconnu')), 404);
});

test('une prévision se remplace et s\'efface (retour au menu)', async () => {
  const { chef, gestionnaire: gus, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('p1'), decimal(2))]), 200);
  assert.equal(await lot(gus, [normale(c.prevision('p1'), decimal(1.5), texte('Modifié à la main'))]), 200);
  assert.equal(await lot(gus, [effacer(c.prevision('p1'))]), 200);
  assert.equal(await lire(admin, c.prevision('p1')), 404);
});

test('modifiable en préparation et en cours, figée une fois l\'événement clôturé', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('p1'))]), 200);
  assert.equal(await ouvrir(c.evt.split('/')[1]), 200);
  assert.equal(await lot(chef, [normale(c.prevision('p1'), decimal(3))]), 200);
  assert.equal(await lot(chef, [normale(c.prevision('p2'))]), 200);
  assert.equal(await passerEn(c, 'cloture'), 200);
  assert.equal(await lot(chef, [normale(c.prevision('p1'), decimal(4))]), 403);
  assert.equal(await lot(chef, [normale(c.prevision('p3'))]), 403);
  assert.equal(await lot(chef, [effacer(c.prevision('p1'))]), 403);
  // Toujours lisible pour consulter la source d'un événement passé.
  assert.equal(await lire(chef, c.prevision('p1')), 200);
});

test('un bénévole ne lit pas la prévision d\'un événement en cours', async () => {
  const { chef, lea, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('p1'))]), 200);
  assert.equal(await ouvrir(c.evt.split('/')[1]), 200);
  assert.equal(await lire(lea, c.prevision('p1')), 403);
});

test('suppression de l\'association : seule le drapeau du responsable permet d\'effacer après la clôture', async () => {
  const { chef, gestionnaire: gus, lea, id, c } = await enPreparation();
  assert.equal(await lot(chef, [normale(c.prevision('p1')), normale(c.prevision('p2'))]), 200);
  assert.equal(await passerEn(c, 'cloture'), 200);
  // Clôturé et sans drapeau : on n'efface pas.
  assert.equal(await lot(chef, [effacer(c.prevision('p1'))]), 403);
  const drapeau = {
    update: { name: `${RACINE}/associations/${id}`, fields: { suppression: { booleanValue: true } } },
    updateMask: { fieldPaths: ['suppression'] },
    currentDocument: { exists: true },
  };
  assert.equal(await lot(chef, [drapeau]), 200);
  // Les autres n'ont toujours aucun droit d'effacement.
  assert.equal(await lot(gus, [effacer(c.prevision('p1'))]), 403);
  assert.equal(await lot(lea, [effacer(c.prevision('p1'))]), 403);
  // Le responsable relit la collection en liste, puis efface tout.
  const liste = await fetch(`http://127.0.0.1:8080/v1/${RACINE}/${c.evt}/previsions`, {
    headers: { Authorization: `Bearer ${chef.jeton}` },
  });
  assert.equal(liste.status, 200);
  assert.equal(await lot(chef, [effacer(c.prevision('p1')), effacer(c.prevision('p2'))]), 200);
  assert.equal(await lire(admin, c.prevision('p1')), 404);
  assert.equal(await lire(admin, c.prevision('p2')), 404);
});

test('plusieurs prévisions dans le même lot : 10 passent (l\'application écrit par groupes de 10)', async () => {
  const { chef, id, c } = await enPreparation();
  const ids = Array.from({ length: 10 }, (_, i) => `q${i}`);
  assert.equal(await lot(chef, ids.map((p) => produitEvenement(id, 'e1', p))), 200);
  assert.equal(await lot(chef, ids.map((p) => normale(c.prevision(p)))), 200);
  assert.equal(await lot(chef, ids.map((p) => effacer(c.prevision(p)))), 200);
});
