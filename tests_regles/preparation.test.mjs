// Mission « Préparer l'événement », étape P1 (décision 60) : l'état « En préparation ».
// Un événement naît en_preparation ; seule la gestion le voit ; aucune caisse ne s'y ouvre ;
// « Ouvrir » (responsable, ou gestionnaire rattaché à tous les gymnases) le passe en_cours.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, MAINTENANT, assoAvecGestionnaire, ecrire, effacer, entier, lire, lot, modifier,
} from './outils.mjs';
import {
  GYM, ajoutGymnase, caisse, chemins, evenement, gymnase, ouvrir, produitEvenement, rattachement,
} from './outilsCaisse.mjs';

const mise = (chemin, fields, masque) => ({
  update: { name: `${RACINE}/${chemin}`, fields },
  updateMask: { fieldPaths: masque },
  currentDocument: { exists: true },
});

const ouverture = (chemin, extra = {}, masque = ['statut', 'ouvertLe']) => mise(chemin, {
  statut: { stringValue: 'en_cours' },
  ouvertLe: { timestampValue: MAINTENANT },
  ...extra,
}, masque);

const cloturer = (chemin, uid, prenom) => mise(chemin, {
  statut: { stringValue: 'cloture' },
  clotureLe: { timestampValue: MAINTENANT },
  cloturePar: { stringValue: uid },
  clotureParPrenom: { stringValue: prenom },
  forcee: { booleanValue: false },
  nbCaissesOuvertes: entier(0),
}, ['statut', 'clotureLe', 'cloturePar', 'clotureParPrenom', 'forcee', 'nbCaissesOuvertes']);

/** Association + événement e1 NÉ en préparation (créé par les règles), un gymnase g1,
 *  produit p1 avec stock 20 ; le gestionnaire est rattaché à g1 (donc à tous). */
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

// ---------- critère 1 : un événement neuf est « En préparation » ----------
test('création : l’événement doit naître en préparation (jamais en cours ni clôturé)', async () => {
  const { chef, gestionnaire, id } = await assoAvecGestionnaire();
  const essai = (qui, statut, e) => lot(qui, [
    ecrire(`associations/${id}/evenements/${e}`, evenement({ statut })),
  ]);
  assert.equal(await essai(chef, 'en_cours', 'a'), 403);
  assert.equal(await essai(gestionnaire, 'en_cours', 'b'), 403);
  assert.equal(await essai(chef, 'cloture', 'c'), 403);
  assert.equal(await essai(chef, 'en_preparation', 'd'), 200);
  assert.equal(await essai(gestionnaire, 'en_preparation', 'e'), 200);
});

// ---------- critère 2 : un bénévole ne le voit pas ----------
test('en préparation : invisible pour le bénévole (événement, produits, gymnases, stocks), visible pour la gestion', async () => {
  const { chef, gestionnaire, lea, intrus, id, c } = await enPreparation();
  for (const chemin of [c.evt, c.produit('p1'), c.gymnase(), c.stock('p1')]) {
    assert.equal(await lire(lea, chemin), 403, chemin);
    assert.equal(await lire(intrus, chemin), 403, chemin);
    assert.equal(await lire(chef, chemin), 200, chemin);
    assert.equal(await lire(gestionnaire, chemin), 200, chemin);
  }
  void id;
});

// ---------- critère 3 : aucune caisse ne s'y ouvre ----------
test('en préparation : aucune caisse, aucun pointeur, aucun signal « vide », même par la gestion', async () => {
  const { chef, gestionnaire, lea, c } = await enPreparation();
  for (const qui of [lea, chef, gestionnaire]) {
    assert.equal(await lot(qui, [caisse(c.caisse(qui.uid))]), 403, 'caisse + pointeur');
  }
  assert.equal(await lot(chef, [ecrire(c.ouverte(chef.uid), { gymnaseId: GYM, caisseId: `${chef.uid}__${GYM}` })]), 403);
  assert.equal(await lot(chef, [ecrire(`${c.gymnase()}/vides/p1`, { creeLe: MAJ })]), 403);
});

// ---------- critère 4 : « Ouvrir » le passe en cours, le bénévole le voit ----------
test('ouverture : l’événement passe en cours, le bénévole le voit et une caisse peut s’ouvrir', async () => {
  const { chef, lea, c } = await enPreparation();
  assert.equal(await lot(chef, [ouverture(c.evt)]), 200);
  for (const chemin of [c.evt, c.produit('p1'), c.gymnase(), c.stock('p1')]) {
    assert.equal(await lire(lea, chemin), 200, chemin);
  }
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
});

// ---------- critère 5 : seul le responsable ou un rattaché à tous l'ouvre ----------
test('ouverture : responsable, ou gestionnaire rattaché à TOUS les gymnases ; pas les autres', async () => {
  const { chef, gestionnaire: gus, lea, intrus, id, c } = await enPreparation();
  // Un deuxième gymnase : Gus (rattaché à g1 seulement) ne peut plus ouvrir.
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  assert.equal(await lot(gus, [ouverture(c.evt)]), 403);
  assert.equal(await lot(lea, [ouverture(c.evt)]), 403);
  assert.equal(await lot(intrus, [ouverture(c.evt)]), 403);
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [GYM, 'g2'])]), 200);
  assert.equal(await lot(gus, [ouverture(c.evt)]), 200);
});

test('ouverture : un gestionnaire rattaché à l’unique gymnase ouvre', async () => {
  const { gestionnaire: gus, c } = await enPreparation();
  assert.equal(await lot(gus, [ouverture(c.evt)]), 200);
});

test('ouverture : seuls le statut et l’horodatage changent, sans retour en arrière', async () => {
  const { chef, c } = await enPreparation();
  // Autre champ en plus, mauvais statut, horodatage absent ou faux.
  assert.equal(await lot(chef, [ouverture(c.evt, { nom: { stringValue: 'Pirate' } }, ['statut', 'ouvertLe', 'nom'])]), 403);
  assert.equal(await lot(chef, [ouverture(c.evt, { statut: { stringValue: 'cloture' } })]), 403);
  assert.equal(await lot(chef, [ouverture(c.evt, { statut: { stringValue: 'en_preparation' } })]), 403);
  assert.equal(await lot(chef, [ouverture(c.evt, { ouvertLe: { stringValue: 'hier' } })]), 403);
  assert.equal(await lot(chef, [mise(c.evt, { statut: { stringValue: 'en_cours' } }, ['statut'])]), 403);
  // Pas de clôture depuis « en préparation ».
  assert.equal(await lot(chef, [cloturer(c.evt, chef.uid, 'Chef')]), 403);
  // Ouverture valide, puis ni rejeu ni retour en préparation.
  assert.equal(await lot(chef, [ouverture(c.evt)]), 200);
  assert.equal(await lot(chef, [ouverture(c.evt, { ouvertLe: { timestampValue: '2026-10-02T10:00:00Z' } })]), 403);
  assert.equal(await lot(chef, [mise(c.evt, { statut: { stringValue: 'en_preparation' } }, ['statut'])]), 403);
});

// ---------- la gestion règle l'événement AVANT l'ouverture (P2 à P4 en dépendent) ----------
test('en préparation : la gestion modifie, règle les gymnases, les stocks, les courses et les rattachements', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  // Événement : nom, date, modes, durée.
  assert.equal(await lot(gus, [modifier(c.evt, { nom: 'Nouveau', date: '2026-10-04', modes: ['carte'] })]), 200);
  assert.equal(await lot(chef, [modifier(c.evt, { nbJours: 3 })]), 200);
  // Gymnase : renommer, personnes attendues, en ajouter un.
  assert.equal(await lot(gus, [modifier(c.gymnase(), { nom: 'Salle A' })]), 200);
  assert.equal(await lot(chef, [modifier(c.gymnase(), { personnes: 40 })]), 200);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  // Produit : nouvelle copie, nouvelle image.
  assert.equal(await lot(chef, [produitEvenement(id, 'e1', 'p2')]), 200);
  // Stock : réglage, suppression du suivi, nouveau suivi.
  assert.equal(await lot(chef, [mise(c.stock('p1'), { quantite: entier(30), reference: entier(30) }, ['quantite', 'reference'])]), 200);
  assert.equal(await lot(chef, [effacer(c.stock('p1'))]), 200);
  assert.equal(await lot(chef, [ecrire(c.stock('p2'), { quantite: 12 })]), 200);
  // Rattachement par le responsable.
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [GYM, 'g2'])]), 200);
  // Courses : liste en préparation.
  assert.equal(await lot(chef, [ecrire(`${c.evt}/courses/liste`, {
    statut: 'preparation', lignes: [], libres: [], restes: [], majLe: MAJ,
  })]), 200);
});

test('en préparation : les écritures propres aux caisses restent refusées (vente, annulation, stock par un bénévole)', async () => {
  const { chef, lea, c } = await enPreparation();
  // Même une écriture de stock « de caisse » (quantité seule) par un bénévole.
  assert.equal(await lot(lea, [mise(c.stock('p1'), { quantite: entier(19) }, ['quantite'])]), 403);
  // Le responsable règle (branche gestion), lui, passe.
  assert.equal(await lot(chef, [mise(c.stock('p1'), { quantite: entier(19) }, ['quantite'])]), 200);
});

// ---------- critère 6 : un événement antérieur reste « En cours » ----------
test('événement créé avant P1 (posé en_cours, sans ouvertLe) : toujours ouvert aux caisses et réglable', async () => {
  const ctx = await assoAvecGestionnaire();
  const { chef, lea, id } = ctx;
  const c = chemins(id);
  assert.equal(await lot(admin, [
    ecrire(c.evt, evenement({ statut: 'en_cours' })),
    gymnase(id),
    produitEvenement(id, 'e1', 'p1', { stock: 20 }),
  ]), 200);
  assert.equal(await lire(lea, c.evt), 200);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
  assert.equal(await lot(chef, [modifier(c.evt, { nom: 'Toujours modifiable' })]), 200);
  assert.equal(await lot(chef, [ouverture(c.evt)]), 403); // déjà ouvert : pas de rejeu
});

// ---------- clôturé : toujours figé ----------
test('clôturé : plus rien ne se règle', async () => {
  const { chef, gestionnaire: gus, id, c } = await enPreparation();
  assert.equal(await ouvrir(id), 200);
  assert.equal(await lot(chef, [cloturer(c.evt, chef.uid, 'Chef')]), 200);
  assert.equal(await lot(gus, [modifier(c.evt, { nom: 'Trop tard' })]), 403);
  assert.equal(await lot(chef, [modifier(c.gymnase(), { nom: 'Trop tard' })]), 403);
  assert.equal(await lot(chef, [mise(c.stock('p1'), { quantite: entier(1), reference: entier(1) }, ['quantite', 'reference'])]), 403);
  assert.equal(await lot(chef, [effacer(c.stock('p1'))]), 403);
  assert.equal(await lot(chef, [ecrire(`${c.evt}/courses/liste`, {
    statut: 'preparation', lignes: [], libres: [], restes: [], majLe: MAJ,
  })]), 403);
});
