// Étape 7 : caisses, ventes, stock. Outils partagés (outils.mjs, outilsCaisse.mjs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import {
  admin, RACINE, MAJ, assoAvecGestionnaire, creerAsso, ecrire, effacer, entier,
  google, lire, lot, modifier, produit, rejoindre, utilisateur,
} from './outils.mjs';
import {
  baisserStock, caisse, chemins, evenement, evenementEnCours, gymnase, ligne,
  produitEvenement, vente,
} from './outilsCaisse.mjs';

test('un bénévole ouvre SA caisse, et seulement la sienne', async () => {
  const { lea, chef, intrus, id, c } = await evenementEnCours();
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
  assert.equal(await lire(lea, c.caisse(lea.uid)), 200);
  // Pas la caisse de quelqu'un d'autre.
  assert.equal(await lot(lea, [caisse(c.caisse(chef.uid))]), 403);
  // Un intrus (non membre) ne peut pas ouvrir de caisse.
  assert.equal(await lot(intrus, [caisse(c.caisse(intrus.uid))]), 403);
  // Le responsable ouvre la sienne aussi.
  assert.equal(await lot(chef, [caisse(c.caisse(chef.uid))]), 200);
  assert.ok(id);
});

test('données de caisse invalides refusées', async () => {
  const { lea, c } = await evenementEnCours();
  const essai = (extra) => lot(lea, [caisse(c.caisse(lea.uid), extra)]);
  assert.equal(await essai({ statut: 'cloturee' }), 403); // née clôturée
  assert.equal(await essai({ prenom: '' }), 403);
  assert.equal(await essai({ inconnu: 'x' }), 403);
  assert.equal(await essai({}), 200); // témoin
});

test('pas de caisse sur un événement clôturé', async () => {
  const { lea, id } = await evenementEnCours();
  const c = chemins(id, 'ancien');
  await lot(admin, [ecrire(c.evt, evenement({ statut: 'cloture' })), gymnase(id, 'ancien')]);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 403);
});

test('lecture des caisses : bénévole = la sienne, gestion = toutes', async () => {
  const { lea, chef, gestionnaire, intrus, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  await lot(chef, [caisse(c.caisse(chef.uid), { prenom: 'Chef' })]);
  assert.equal(await lire(lea, c.caisse(chef.uid)), 403);
  assert.equal(await lire(chef, c.caisse(lea.uid)), 200);
  assert.equal(await lire(gestionnaire, c.caisse(lea.uid)), 200);
  assert.equal(await lire(intrus, c.caisse(lea.uid)), 403);
});

test('une vente valide est enregistrée, lisible par son auteur et la gestion', async () => {
  const { lea, chef, gestionnaire, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const v = c.vente(lea.uid);
  assert.equal(await lot(lea, [vente(v)]), 200);
  assert.equal(await lire(lea, v), 200);
  assert.equal(await lire(chef, v), 200);
  assert.equal(await lire(gestionnaire, v), 200);
});

test('seuls les modes de paiement de l’événement sont acceptés', async () => {
  const { lea, c } = await evenementEnCours(); // modes : espèces, carte
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const mode = (m) => lot(lea, [vente(c.vente(lea.uid), { mode: { stringValue: m } })]);
  assert.equal(await mode('especes'), 200);
  assert.equal(await mode('carte'), 200);
  assert.equal(await mode('cheque'), 403);
  assert.equal(await mode('autre'), 403);
  assert.equal(await mode('bitcoin'), 403);
});

test('vente invalide refusée', async () => {
  const { lea, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const essai = (extra) => lot(lea, [vente(c.vente(lea.uid), extra)]);
  assert.equal(await essai({ totalCentimes: entier(-1) }), 403);
  assert.equal(await essai({ totalCentimes: entier(1000001) }), 403);
  assert.equal(await essai({ totalCentimes: { stringValue: '600' } }), 403);
  assert.equal(await essai({ lignes: { arrayValue: {} } }), 403); // aucune ligne
  assert.equal(await essai({ lignes: { stringValue: 'x' } }), 403);
  assert.equal(await essai({ inconnu: { stringValue: 'x' } }), 403);
  assert.equal(await essai({ creeLe: { stringValue: 'hier' } }), 403);
  assert.equal(await essai({}), 200); // témoin
});

test('on ne vend que dans sa propre caisse, ouverte, d’un événement en cours', async () => {
  const { lea, chef, intrus, id, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  // Dans la caisse d'un autre.
  assert.equal(await lot(chef, [vente(c.vente(lea.uid))]), 403);
  assert.equal(await lot(intrus, [vente(c.vente(lea.uid))]), 403);
  // Sans avoir ouvert de caisse.
  assert.equal(await lot(chef, [vente(c.vente(chef.uid))]), 403);
  // Caisse clôturée (posée par l'administrateur : la clôture arrive à l'étape 9).
  await lot(admin, [modifier(c.caisse(lea.uid), { statut: 'cloturee' })]);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid))]), 403);
  // Événement clôturé.
  const autre = chemins(id, 'e2');
  await lot(admin, [ecrire(autre.evt, evenement()), gymnase(id, 'e2')]);
  await lot(lea, [caisse(autre.caisse(lea.uid))]);
  await lot(admin, [modifier(autre.evt, { statut: 'cloture' })]);
  assert.equal(await lot(lea, [vente(autre.vente(lea.uid))]), 403);
});

test('une vente enregistrée ne se modifie ni ne se supprime (corrections : étape 8)', async () => {
  const { lea, chef, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const v = c.vente(lea.uid, 'v1');
  await lot(lea, [vente(v)]);
  assert.equal(await lot(lea, [modifier(v, { mode: 'carte' })]), 403);
  assert.equal(await lot(lea, [effacer(v)]), 403);
  assert.equal(await lot(chef, [effacer(v)]), 403);
});

test('une vente fait baisser le stock du gymnase, même sous zéro ; rien d’autre ne change', async () => {
  const { lea, intrus, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), 18)]), 200);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), -3)]), 200); // épuisé : on avertit seulement
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), -100001)]), 403);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), 100001)]), 403);
  // Un intrus ne touche pas au stock.
  assert.equal(await lot(intrus, [baisserStock(c.stock('p1'), 5)]), 403);
  // Produit sans suivi de stock : pas de document de stock, donc pas d'écriture.
  assert.equal(await lot(lea, [baisserStock(c.stock('p2'), 5)]), 403);
  // Pas d'autre champ que la quantité.
  assert.equal(await lot(lea, [modifier(c.stock('p1'), { nom: 'Pirate' })]), 403);
  assert.equal(await lot(lea, [{
    update: { name: `${RACINE}/${c.stock('p1')}`, fields: { prixCentimes: entier(1) } },
    updateMask: { fieldPaths: ['prixCentimes'] },
    currentDocument: { exists: true },
  }]), 403);
});

test('le produit de l’événement ne se modifie plus (ni stock, ni prix) par un bénévole', async () => {
  const { lea, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  assert.equal(await lot(lea, [modifier(c.produit('p1'), { stock: 5 })]), 403);
  assert.equal(await lot(lea, [modifier(c.produit('p1'), { nom: 'Pirate' })]), 403);
});

test('stock : plus d’écriture sur un événement clôturé', async () => {
  const { lea, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1'), 5)]), 403);
});

test('une vente de 9 produits (ticket complet) passe en une écriture + 9 baisses de stock', async () => {
  const { lea, id, chef } = await assoAvecGestionnaire().then(async (x) => x);
  const c = chemins(id);
  await lot(chef, [
    ecrire(c.evt, evenement()),
    gymnase(id),
    ...Array.from({ length: 9 }, (_, i) => produitEvenement(id, 'e1', `q${i}`, { stock: 10 })),
  ]);
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  const lignes = Array.from({ length: 9 }, () => ligne());
  assert.equal(await lot(lea, [vente(c.vente(lea.uid), {
    lignes: { arrayValue: { values: lignes } },
  })]), 200);
  for (let i = 0; i < 9; i++) {
    assert.equal(await lot(lea, [baisserStock(c.stock(`q${i}`), 9)]), 200);
  }
});
