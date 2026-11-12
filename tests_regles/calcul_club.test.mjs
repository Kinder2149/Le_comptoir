// Mission « Calcul du club », étape V2 (décision 88) : evenements/{e}/calcul_club/{d}, avec d =
// « repas » (champ jours, 30 jours au plus) ou « groupes » (champ groupes, 40 au plus).
// Mêmes droits que la prévision : lu et écrit par le responsable ou un gestionnaire rattaché à
// TOUS les gymnases, tant que l'événement est en préparation ou en cours ; effacé aussi par
// l'association en cours de suppression. Un bénévole et un inconnu n'y touchent pas.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RACINE, admin, assoAvecGestionnaire, ecrire, effacer, lire, lot, modifier } from './outils.mjs';
import {
  GYM, ajoutGymnase, chemins, evenement, gymnase, ouvrir, rattachement,
} from './outilsCaisse.mjs';

const texte = (s) => ({ stringValue: s });
const entier = (n) => ({ integerValue: String(n) });
const decimal = (n) => ({ doubleValue: n });
const carte = (fields) => ({ mapValue: { fields } });
const liste = (values) => ({ arrayValue: { values } });

/** Les six nombres d'un repas (une valeur par catégorie et par moment). */
const repas = (n = 1) => carte({
  joueusesMidi: entier(n), joueusesSoir: entier(n),
  benevolesMidi: entier(0), benevolesSoir: entier(0),
  spectateursMidi: entier(0), spectateursSoir: entier(0),
});

/** Champs du document « repas » : `nbJours` jours, un gymnase g1 par jour. */
const repasDoc = (nbJours = 2) => ({
  jours: carte(Object.fromEntries(
    Array.from({ length: nbJours }, (_, i) => [String(i + 1), carte({ g1: repas() })]),
  )),
});

/** Un groupe : pourcentage du jour 1 et une part du produit p1. */
const groupe = (i) => carte({
  nom: texte(`Groupe ${i}`),
  pourcentages: carte({ 1: decimal(0.7) }),
  produits: carte({ p1: carte({ 1: decimal(0.4) }) }),
});

/** Champs du document « groupes » : `nb` groupes. */
const groupesDoc = (nb = 1) => ({
  groupes: liste(Array.from({ length: nb }, (_, i) => groupe(i))),
});

/** Chemin d'un des deux documents. */
const doc = (c, d) => `${c.evt}/calcul_club/${d}`;
/** Écriture d'un document (création ou remplacement) avec des champs déjà typés. */
const ecrireDoc = (c, d, fields) => ({ update: { name: `${RACINE}/${doc(c, d)}`, fields } });

/** Événement en préparation, gymnase g1 (Gus y est rattaché). */
async function enPreparation() {
  const ctx = await assoAvecGestionnaire();
  const c = { ...chemins(ctx.id) };
  assert.equal(await lot(ctx.chef, [
    ecrire(c.evt, evenement()),
    gymnase(ctx.id),
  ]), 200);
  assert.equal(await lot(ctx.chef, [rattachement(ctx.id, 'e1', ctx.gestionnaire.uid, [GYM])]), 200);
  return { ...ctx, c };
}

const passerEn = (c, statut) => lot(admin, [modifier(c.evt, { statut })]);

test('droits : le responsable et le gestionnaire rattaché à tous les gymnases écrivent et lisent', async () => {
  const { chef, gestionnaire: gus, lea, intrus, c } = await enPreparation();
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc())]), 200);
  assert.equal(await lot(gus, [ecrireDoc(c, 'groupes', groupesDoc())]), 200);
  assert.equal(await lire(chef, doc(c, 'repas')), 200);
  assert.equal(await lire(gus, doc(c, 'groupes')), 200);
  assert.equal(await lire(gus, doc(c, 'repas')), 200);
  // Un bénévole et un inconnu n'écrivent ni ne lisent.
  assert.equal(await lot(lea, [ecrireDoc(c, 'repas', repasDoc())]), 403);
  assert.equal(await lot(intrus, [ecrireDoc(c, 'groupes', groupesDoc())]), 403);
  assert.equal(await lire(lea, doc(c, 'repas')), 403);
  assert.equal(await lire(intrus, doc(c, 'groupes')), 403);
});

test('droits : un gestionnaire rattaché à un seul de deux gymnases ne lit ni n\'écrit', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc())]), 200);
  assert.equal(await lot(gus, [ecrireDoc(c, 'repas', repasDoc(1))]), 403);
  assert.equal(await lire(gus, doc(c, 'repas')), 403);
  assert.equal(await lot(gus, [effacer(doc(c, 'repas'))]), 403);
  // Rattaché aux deux : il retrouve ses droits.
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [GYM, 'g2'])]), 200);
  assert.equal(await lot(gus, [ecrireDoc(c, 'repas', repasDoc(1))]), 200);
  assert.equal(await lire(gus, doc(c, 'repas')), 200);
});

test('seuls les documents « repas » et « groupes » existent : un autre identifiant est refusé', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [ecrireDoc(c, 'autre', repasDoc())]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'dernier', groupesDoc())]), 403);
  assert.equal(await lire(chef, doc(c, 'autre')), 403);
  assert.equal(await lot(chef, [effacer(doc(c, 'autre'))]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc())]), 200);
  assert.equal(await lire(admin, doc(c, 'repas')), 200);
});

test('chaque document porte la forme de son identifiant', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', groupesDoc())]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', repasDoc())]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc())]), 200);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', groupesDoc())]), 200);
});

test('champs exacts : « jours » seul pour les repas, « groupes » seul pour les groupes', async () => {
  const { chef, c } = await enPreparation();
  // Champ en trop.
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', { ...repasDoc(), groupes: liste([]) })]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', { ...groupesDoc(), jours: carte({}) })]), 403);
  // Champ manquant.
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', {})]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', {})]), 403);
  // Mauvais type.
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', { jours: texte('x') })]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', { groupes: texte('x') })]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc())]), 200);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', groupesDoc())]), 200);
});

test('jours : 30 au plus ; groupes : 40 au plus', async () => {
  const { chef, c } = await enPreparation();
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc(30))]), 200);
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc(31))]), 403);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', groupesDoc(40))]), 200);
  assert.equal(await lot(chef, [ecrireDoc(c, 'groupes', groupesDoc(41))]), 403);
});

test('modifiables en préparation et en cours, figés une fois l\'événement clôturé', async () => {
  const { chef, gestionnaire: gus, lea, c } = await enPreparation();
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc())]), 200);
  assert.equal(await ouvrir(c.evt.split('/')[1]), 200);
  assert.equal(await lot(gus, [ecrireDoc(c, 'groupes', groupesDoc(2))]), 200);
  // Un bénévole ne lit pas ces réglages, même d'un événement en cours.
  assert.equal(await lire(lea, doc(c, 'repas')), 403);
  assert.equal(await passerEn(c, 'cloture'), 200);
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc(3))]), 403);
  assert.equal(await lot(gus, [ecrireDoc(c, 'groupes', groupesDoc(1))]), 403);
  assert.equal(await lot(chef, [effacer(doc(c, 'repas'))]), 403);
  // Toujours lisibles pour consulter un événement passé.
  assert.equal(await lire(chef, doc(c, 'repas')), 200);
  assert.equal(await lire(chef, doc(c, 'groupes')), 200);
});

test('suppression : l\'association en cours de suppression efface, même après la clôture ; les autres non', async () => {
  const { chef, gestionnaire: gus, lea, id, c } = await enPreparation();
  assert.equal(await lot(chef, [ecrireDoc(c, 'repas', repasDoc()), ecrireDoc(c, 'groupes', groupesDoc())]), 200);
  assert.equal(await passerEn(c, 'cloture'), 200);
  // Clôturé et sans drapeau : on n'efface pas.
  assert.equal(await lot(chef, [effacer(doc(c, 'repas'))]), 403);
  const drapeau = {
    update: { name: `${RACINE}/associations/${id}`, fields: { suppression: { booleanValue: true } } },
    updateMask: { fieldPaths: ['suppression'] },
    currentDocument: { exists: true },
  };
  assert.equal(await lot(chef, [drapeau]), 200);
  // Les autres n'ont toujours aucun droit d'effacement.
  assert.equal(await lot(gus, [effacer(doc(c, 'repas'))]), 403);
  assert.equal(await lot(lea, [effacer(doc(c, 'groupes'))]), 403);
  // Le responsable efface les deux documents.
  assert.equal(await lot(chef, [effacer(doc(c, 'repas')), effacer(doc(c, 'groupes'))]), 200);
  assert.equal(await lire(admin, doc(c, 'repas')), 404);
  assert.equal(await lire(admin, doc(c, 'groupes')), 404);
});
