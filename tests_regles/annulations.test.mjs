// Étape 8 : annulations tracées et corrections. Outils : outils.mjs, outilsCaisse.mjs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, MAINTENANT, effacer, lire, lot, modifier, rejoindre,
  utilisateur,
} from './outils.mjs';
import {
  baisserStock, caisse, evenementEnCours, vente,
} from './outilsCaisse.mjs';

/** Annulation d'une vente : les 4 champs de trace, posés ensemble. */
const annulation = (chemin, uid, prenom, extra = {}) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      annulee: { booleanValue: true },
      annuleePar: { stringValue: uid },
      annuleeParPrenom: { stringValue: prenom },
      annuleeLe: { timestampValue: MAINTENANT },
      ...extra,
    },
  },
  updateMask: { fieldPaths: Object.keys({
    annulee: 1, annuleePar: 1, annuleeParPrenom: 1, annuleeLe: 1, ...extra,
  }) },
  currentDocument: { exists: true },
});

/** Événement en cours, caisse ouverte de Léa, deux ventes. */
async function avecVentes() {
  const ctx = await evenementEnCours();
  const { lea, c } = ctx;
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const v1 = c.vente(lea.uid, 'v1');
  const v2 = c.vente(lea.uid, 'v2');
  assert.equal(await lot(lea, [vente(v1)]), 200);
  assert.equal(await lot(lea, [vente(v2)]), 200);
  return { ...ctx, v1, v2 };
}

test('un bénévole annule n’importe laquelle de ses ventes, pas seulement la dernière', async () => {
  const { lea, v1, v2 } = await avecVentes();
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 200); // la première
  assert.equal(await lot(lea, [annulation(v2, lea.uid, 'Lea')]), 200);
  assert.equal(await lire(lea, v1), 200); // elle reste lisible
});

test('on ne peut pas annuler la vente d’un autre bénévole', async () => {
  const { lea, v1, id, c } = await avecVentes();
  // Un second bénévole (Zoé) rejoint avec le code de l'association.
  const zoe = await utilisateur();
  const code = (await (await fetch(
    `http://127.0.0.1:8080/v1/${RACINE}/associations/${id}`,
    { headers: { Authorization: 'Bearer owner' } },
  )).json()).fields.code.stringValue;
  assert.equal(await rejoindre(zoe, id, code, 'Zoe'), 200);
  assert.equal(await lot(zoe, [annulation(v1, zoe.uid, 'Zoe')]), 403);
  assert.equal(await lire(zoe, c.caisse(lea.uid)), 403);
});

test('un intrus ne peut pas annuler', async () => {
  const { intrus, v1 } = await avecVentes();
  assert.equal(await lot(intrus, [annulation(v1, intrus.uid, 'Intrus')]), 403);
});

test('la gestion annule la vente d’une autre caisse, avec son nom dans la trace', async () => {
  const { chef, gestionnaire, v1, v2 } = await avecVentes();
  assert.equal(await lot(chef, [annulation(v1, chef.uid, 'Chef')]), 200);
  assert.equal(await lot(gestionnaire, [annulation(v2, gestionnaire.uid, 'Gus')]), 200);
});

test('la trace dit la vérité : pas d’usurpation du « qui »', async () => {
  const { lea, chef, v1, v2 } = await avecVentes();
  // Léa se fait passer pour le responsable.
  assert.equal(await lot(lea, [annulation(v1, chef.uid, 'Chef')]), 403);
  // Bon identifiant, mauvais prénom.
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Chef')]), 403);
  // Le responsable ne peut pas non plus signer au nom de Léa.
  assert.equal(await lot(chef, [annulation(v2, lea.uid, 'Lea')]), 403);
  // Témoin : la vraie trace passe.
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 200);
});

test('une annulation est unique et définitive', async () => {
  const { lea, chef, v1 } = await avecVentes();
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 200);
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 403); // pas deux fois
  assert.equal(await lot(chef, [annulation(v1, chef.uid, 'Chef')]), 403); // ni par un autre
  // Impossible de « désannuler » : annulee=false, ou retirer les champs.
  assert.equal(await lot(lea, [{
    update: { name: `${RACINE}/${v1}`, fields: { annulee: { booleanValue: false } } },
    updateMask: { fieldPaths: ['annulee'] },
    currentDocument: { exists: true },
  }]), 403);
  assert.equal(await lot(chef, [{
    update: { name: `${RACINE}/${v1}`, fields: {} },
    updateMask: { fieldPaths: ['annulee', 'annuleePar', 'annuleeParPrenom', 'annuleeLe'] },
    currentDocument: { exists: true },
  }]), 403);
  assert.equal(await lot(lea, [effacer(v1)]), 403);
});

test('l’annulation ne change ni le montant, ni les lignes, ni le mode, ni la date', async () => {
  const { lea, v1, v2 } = await avecVentes();
  const mauvais = [
    { totalCentimes: { integerValue: '1' } },
    { mode: { stringValue: 'carte' } },
    { creeLe: { timestampValue: '2020-01-01T00:00:00Z' } },
    { lignes: { arrayValue: {} } },
  ];
  for (const extra of mauvais) {
    assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea', extra)]), 403, JSON.stringify(extra));
  }
  // Annulation incomplète (trace partielle) refusée.
  assert.equal(await lot(lea, [{
    update: { name: `${RACINE}/${v2}`, fields: { annulee: { booleanValue: true } } },
    updateMask: { fieldPaths: ['annulee'] },
    currentDocument: { exists: true },
  }]), 403);
  // Témoin.
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 200);
});

test('plus d’annulation sur un événement clôturé ; caisse clôturée : gestion seulement', async () => {
  const { lea, chef, v1, v2, c } = await avecVentes();
  // Caisse clôturée (la clôture arrive à l'étape 9) : le bénévole ne peut plus rien changer.
  await lot(admin, [modifier(c.caisse(lea.uid), { statut: 'cloturee' })]);
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 403);
  // La gestion peut encore corriger (ex. erreur découverte au comptage).
  assert.equal(await lot(chef, [annulation(v1, chef.uid, 'Chef')]), 200);
  // Événement clôturé : tout est figé, même pour la gestion.
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [annulation(v2, chef.uid, 'Chef')]), 403);
});

test('une correction remplace une vente déjà annulée de la même caisse', async () => {
  const { lea, v1, v2, c } = await avecVentes();
  const corrige = (id, valeur) => vente(c.vente(lea.uid), { corrigeDe: valeur });
  // Vente encore valable : pas de correction possible.
  assert.equal(await lot(lea, [corrige('x', { stringValue: 'v1' })]), 403);
  assert.equal(await lot(lea, [annulation(v1, lea.uid, 'Lea')]), 200);
  assert.equal(await lot(lea, [corrige('x', { stringValue: 'v1' })]), 200);
  // Vente inexistante, ou mauvais type.
  assert.equal(await lot(lea, [corrige('x', { stringValue: 'fantome' })]), 403);
  assert.equal(await lot(lea, [corrige('x', { integerValue: '1' })]), 403);
  void v2;
});

test('le stock remonte quand on annule (retour des articles)', async () => {
  const { lea, c } = await avecVentes();
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), 18)]), 200);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), 20)]), 200); // retour en stock
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), 100001)]), 403);
});

test('la gestion lit les ventes annulées avec leur trace', async () => {
  const { lea, chef, v1 } = await avecVentes();
  await lot(lea, [annulation(v1, lea.uid, 'Lea')]);
  const doc = await (await fetch(`http://127.0.0.1:8080/v1/${RACINE}/${v1}`, {
    headers: { Authorization: `Bearer ${chef.jeton}` },
  })).json();
  assert.equal(doc.fields.annulee.booleanValue, true);
  assert.equal(doc.fields.annuleePar.stringValue, lea.uid);
  assert.equal(doc.fields.annuleeParPrenom.stringValue, 'Lea');
  assert.ok(doc.fields.annuleeLe.timestampValue);
  assert.equal(MAJ instanceof Date, true);
});
