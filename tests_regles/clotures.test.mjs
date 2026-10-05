// Étape 9 : clôture de caisse (et réouverture), clôture d'événement (forcée ou non).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, MAINTENANT, ecrire, entier, lire, lot, rejoindre,
  utilisateur,
} from './outils.mjs';
import {
  avecPointeurCree, avecPointeurEfface, caisse, evenementEnCours, vente,
} from './outilsCaisse.mjs';

const mise = (chemin, fields, masque, extra = {}) => ({
  update: { name: `${RACINE}/${chemin}`, fields: { ...fields, ...extra } },
  // Les champs ajoutés par `extra` font partie de la demande (sinon ils seraient ignorés).
  updateMask: { fieldPaths: [...new Set([...masque, ...Object.keys(extra)])] },
  currentDocument: { exists: true },
});

/** Clôture d'une caisse avec son récapitulatif. */
const cloturerCaisse = (chemin, extra = {}) => avecPointeurEfface(mise(
  chemin,
  {
    statut: { stringValue: 'cloturee' },
    clotureLe: { timestampValue: MAINTENANT },
    nbVentes: entier(2),
    nbAnnulees: entier(1),
    totalCentimes: entier(750),
    parMode: { mapValue: { fields: { especes: entier(450), carte: entier(300) } } },
  },
  ['statut', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes', 'parMode'],
  extra,
), chemin);

/** Réouverture : le récapitulatif est effacé (champs absents du masque = supprimés). */
const rouvrirCaisse = (chemin, extra = {}, masque = null) => avecPointeurCree(mise(
  chemin,
  { statut: { stringValue: 'ouverte' }, rouverteLe: { timestampValue: MAINTENANT } },
  masque ?? ['statut', 'rouverteLe', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes', 'parMode'],
  extra,
), chemin);

/** Clôture de l'événement. */
const cloturerEvenement = (chemin, uid, prenom, nb, extra = {}) => mise(
  chemin,
  {
    statut: { stringValue: 'cloture' },
    clotureLe: { timestampValue: MAINTENANT },
    cloturePar: { stringValue: uid },
    clotureParPrenom: { stringValue: prenom },
    forcee: { booleanValue: nb > 0 },
    nbCaissesOuvertes: entier(nb),
  },
  ['statut', 'clotureLe', 'cloturePar', 'clotureParPrenom', 'forcee', 'nbCaissesOuvertes'],
  extra,
);

async function avecCaisse() {
  const ctx = await evenementEnCours();
  const { lea, c } = ctx;
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
  return ctx;
}

// ---------- caisse ----------
test('le bénévole clôture sa caisse avec le récapitulatif', async () => {
  const { lea, c } = await avecCaisse();
  assert.equal(await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]), 200);
  assert.equal(await lire(lea, c.caisse(lea.uid)), 200);
});

test('personne d’autre ne clôture sa caisse (même la gestion)', async () => {
  const { lea, chef, gestionnaire, intrus, c } = await avecCaisse();
  assert.equal(await lot(chef, [cloturerCaisse(c.caisse(lea.uid))]), 403);
  assert.equal(await lot(gestionnaire, [cloturerCaisse(c.caisse(lea.uid))]), 403);
  assert.equal(await lot(intrus, [cloturerCaisse(c.caisse(lea.uid))]), 403);
});

test('clôture invalide refusée', async () => {
  const { lea, c } = await avecCaisse();
  const essai = (extra, masque) => lot(lea, [
    masque
      ? avecPointeurEfface(mise(c.caisse(lea.uid), {}, masque, extra), c.caisse(lea.uid))
      : cloturerCaisse(c.caisse(lea.uid), extra),
  ]);
  assert.equal(await essai({ nbVentes: entier(-1) }), 403);
  assert.equal(await essai({ nbAnnulees: entier(-1) }), 403);
  assert.equal(await essai({ totalCentimes: entier(-5) }), 403);
  assert.equal(await essai({ totalCentimes: { stringValue: '750' } }), 403);
  assert.equal(await essai({ parMode: { stringValue: 'x' } }), 403);
  assert.equal(await essai({ clotureLe: { stringValue: 'hier' } }), 403);
  assert.equal(await essai({ inconnu: { stringValue: 'x' } }), 403); // champ en trop
  // Récapitulatif incomplet (sans parMode).
  assert.equal(await lot(lea, [avecPointeurEfface(mise(c.caisse(lea.uid), {
    statut: { stringValue: 'cloturee' }, clotureLe: { timestampValue: MAINTENANT },
    nbVentes: entier(2), nbAnnulees: entier(0), totalCentimes: entier(750),
  }, ['statut', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes']), c.caisse(lea.uid))]), 403);
  // On ne change pas le prénom ni la date d'ouverture en clôturant.
  assert.equal(await essai({ prenom: { stringValue: 'Autre' } }, ['statut', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes', 'parMode', 'prenom']), 403);
  assert.equal(await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]), 200); // témoin
});

test('caisse clôturée : plus de vente ni d’annulation par le bénévole', async () => {
  const { lea, chef, c } = await avecCaisse();
  const v = c.vente(lea.uid, 'v1');
  assert.equal(await lot(lea, [vente(v)]), 200);
  await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid))]), 403);
  assert.equal(await lot(lea, [mise(v, {
    annulee: { booleanValue: true }, annuleePar: { stringValue: lea.uid },
    annuleeParPrenom: { stringValue: 'Lea' }, annuleeLe: { timestampValue: MAINTENANT },
  }, ['annulee', 'annuleePar', 'annuleeParPrenom', 'annuleeLe'])]), 403);
  // La gestion lit toujours les ventes et la caisse clôturée.
  assert.equal(await lire(chef, v), 200);
  assert.equal(await lire(chef, c.caisse(lea.uid)), 200);
});

test('on ne clôture pas deux fois, ni une caisse d’un événement clôturé', async () => {
  const { lea, c } = await avecCaisse();
  assert.equal(await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]), 200);
  assert.equal(await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]), 403);
  const autre = await evenementEnCours();
  await lot(autre.lea, [caisse(autre.c.caisse(autre.lea.uid))]);
  await lot(admin, [mise(autre.c.evt, { statut: { stringValue: 'cloture' } }, ['statut'])]);
  assert.equal(await lot(autre.lea, [cloturerCaisse(autre.c.caisse(autre.lea.uid))]), 403);
});

test('le bénévole peut rouvrir sa caisse puis vendre à nouveau', async () => {
  const { lea, c } = await avecCaisse();
  await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid))]), 403);
  assert.equal(await lot(lea, [rouvrirCaisse(c.caisse(lea.uid))]), 200);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid))]), 200);
  // Et la reclôturer ensuite (la trace de réouverture est conservée).
  assert.equal(await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]), 200);
});

test('réouverture : par l’auteur seulement, sans reste de récapitulatif', async () => {
  const { lea, chef, c } = await avecCaisse();
  await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]);
  assert.equal(await lot(chef, [rouvrirCaisse(c.caisse(lea.uid))]), 403);
  // Récapitulatif périmé laissé en place (champs retirés du masque) : refusé.
  assert.equal(await lot(lea, [rouvrirCaisse(c.caisse(lea.uid), {}, ['statut', 'rouverteLe'])]), 403);
  // Sans trace de réouverture : refusé.
  assert.equal(await lot(lea, [avecPointeurCree(mise(c.caisse(lea.uid), { statut: { stringValue: 'ouverte' } },
    ['statut', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes', 'parMode']), c.caisse(lea.uid))]), 403);
  assert.equal(await lot(lea, [rouvrirCaisse(c.caisse(lea.uid))]), 200); // témoin
  // Rouvrir une caisse déjà ouverte : refusé.
  assert.equal(await lot(lea, [rouvrirCaisse(c.caisse(lea.uid))]), 403);
});

test('plus de réouverture une fois l’événement clôturé', async () => {
  const { lea, c } = await avecCaisse();
  await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]);
  await lot(admin, [mise(c.evt, { statut: { stringValue: 'cloture' } }, ['statut'])]);
  assert.equal(await lot(lea, [rouvrirCaisse(c.caisse(lea.uid))]), 403);
});

// ---------- événement ----------
test('un gestionnaire identifié clôture l’événement (toutes caisses clôturées)', async () => {
  const { gestionnaire, c } = await avecCaisse();
  assert.equal(await lot(gestionnaire, [cloturerEvenement(c.evt, gestionnaire.uid, 'Gus', 0)]), 200);
});

test('clôture forcée : le nombre de caisses ouvertes et l’auteur sont conservés', async () => {
  const { chef, c } = await avecCaisse();
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 2)]), 200);
  const doc = await (await fetch(`http://127.0.0.1:8080/v1/${RACINE}/${c.evt}`, {
    headers: { Authorization: `Bearer ${chef.jeton}` },
  })).json();
  assert.equal(doc.fields.statut.stringValue, 'cloture');
  assert.equal(doc.fields.forcee.booleanValue, true);
  assert.equal(doc.fields.nbCaissesOuvertes.integerValue, '2');
  assert.equal(doc.fields.cloturePar.stringValue, chef.uid);
  assert.equal(doc.fields.clotureParPrenom.stringValue, 'Chef');
});

test('la clôture ne ment pas : forcée et nombre cohérents, auteur vrai', async () => {
  const { chef, gestionnaire, c } = await evenementEnCours();
  // Dit « forcée » sans caisse ouverte, ou l'inverse.
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 2, { forcee: { booleanValue: false } })]), 403);
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 0, { forcee: { booleanValue: true } })]), 403);
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', -1)]), 403);
  // Signe au nom d'un autre, ou avec un faux prénom.
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, gestionnaire.uid, 'Gus', 0)]), 403);
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Gus', 0)]), 403);
  // Ne touche à rien d'autre en clôturant.
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 0, { nom: { stringValue: 'Pirate' } })]), 403);
  assert.equal(await lot(chef, [mise(c.evt, { statut: { stringValue: 'cloture' } }, ['statut'])]), 403); // sans trace
});

test('un bénévole, un intrus ou un gestionnaire sans Google ne clôturent pas', async () => {
  const { lea, intrus, id, c } = await evenementEnCours();
  assert.equal(await lot(lea, [cloturerEvenement(c.evt, lea.uid, 'Lea', 0)]), 403);
  assert.equal(await lot(intrus, [cloturerEvenement(c.evt, intrus.uid, 'Intrus', 0)]), 403);
  // Gestionnaire nommé mais jamais identifié par Google (compte anonyme).
  const anonyme = await utilisateur();
  await lot(admin, [ecrire(`associations/${id}/membres/${anonyme.uid}`, {
    prenom: 'Anon', role: 'gestionnaire', rejointLe: MAJ, codeUtilise: '',
  })]);
  assert.equal(await lot(anonyme, [cloturerEvenement(c.evt, anonyme.uid, 'Anon', 0)]), 403);
});

test('événement clôturé : figé, invisible du bénévole, une seule clôture', async () => {
  const { lea, chef, gestionnaire, c } = await avecCaisse();
  assert.equal(await lire(lea, c.evt), 200);
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 1)]), 200);
  assert.equal(await lot(gestionnaire, [cloturerEvenement(c.evt, gestionnaire.uid, 'Gus', 0)]), 403); // déjà clôturé
  assert.equal(await lire(lea, c.evt), 403);
  assert.equal(await lire(lea, c.stock('p1')), 403);
  assert.equal(await lire(chef, c.evt), 200);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid))]), 403);
  assert.equal(await lot(chef, [mise(c.evt, { nom: { stringValue: 'Tardif' } }, ['nom'])]), 403);
});

test('un bénévole rejoint avec le code et ne voit que les événements en cours après clôture', async () => {
  const { chef, id, c } = await evenementEnCours();
  await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 0)]);
  const code = (await (await fetch(`http://127.0.0.1:8080/v1/${RACINE}/associations/${id}`, {
    headers: { Authorization: 'Bearer owner' },
  })).json()).fields.code.stringValue;
  const nouveau = await utilisateur();
  assert.equal(await rejoindre(nouveau, id, code, 'Zoe'), 200);
  assert.equal(await lire(nouveau, c.evt), 403);
});

test('clôture forcée avec une caisse clôturée et une caisse restée ouverte (cas réel)', async () => {
  const { lea, chef, c } = await avecCaisse();
  await lot(chef, [caisse(c.caisse(chef.uid), { prenom: 'Chef' })]);
  await lot(lea, [cloturerCaisse(c.caisse(lea.uid))]);
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef', 1)]), 200);
});
