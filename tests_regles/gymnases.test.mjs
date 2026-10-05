// Chantier gymnases, mission M1 : gymnases, stock par gymnase, caisse « uid__gymnase »,
// pointeur « ouvertes/uid » (jamais deux caisses ouvertes). Outils : outils.mjs, outilsCaisse.mjs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAINTENANT, MAJ, ecrire, effacer, entier, lire, lot, modifier,
} from './outils.mjs';
import {
  avecPointeurCree, avecPointeurEfface, baisserStock, caisse, evenementEnCours,
  ajoutGymnase, gymnase, pointeur, produitEvenement, rattachement, vente,
} from './outilsCaisse.mjs';

const mise = (chemin, fields, masque) => ({
  update: { name: `${RACINE}/${chemin}`, fields },
  updateMask: { fieldPaths: masque },
  currentDocument: { exists: true },
});
const cloturer = (chemin) => avecPointeurEfface(mise(chemin, {
  statut: { stringValue: 'cloturee' },
  clotureLe: { timestampValue: MAINTENANT },
  nbVentes: entier(0), nbAnnulees: entier(0), totalCentimes: entier(0),
  parMode: { mapValue: { fields: {} } },
}, ['statut', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes', 'parMode']), chemin);
const rouvrir = (chemin) => avecPointeurCree(mise(chemin, {
  statut: { stringValue: 'ouverte' }, rouverteLe: { timestampValue: MAINTENANT },
}, ['statut', 'rouverteLe', 'clotureLe', 'nbVentes', 'nbAnnulees', 'totalCentimes', 'parMode']), chemin);

/** Événement à deux gymnases (g1 : p1 = 20, g2 : p1 = 7). */
async function deuxGymnases() {
  const ctx = await evenementEnCours();
  const { chef, id, c } = ctx;
  assert.equal(await lot(chef, [
    ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' }),
    produitEvenement(id, 'e1', 'p3', { stock: 7, g: 'g2' }),
  ]), 200);
  assert.equal(await lot(chef, [rattachement(id, 'e1', ctx.gestionnaire.uid, ['g1', 'g2'])]), 200);
  assert.equal(await lot(chef, [{
    update: { name: `${RACINE}/${c.stock('p1', 'g2')}`, fields: { quantite: entier(7) } },
  }]), 200);
  return ctx;
}

// ---------- gymnases ----------
test('la gestion crée et renomme un gymnase ; un bénévole non ; jamais de suppression', async () => {
  const { chef, gestionnaire, lea, intrus, id, c } = await evenementEnCours();
  assert.equal(await lot(gestionnaire, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' })]), 200);
  assert.equal(await lot(lea, [ajoutGymnase(id, 'e1', 'g3', {}, 3)]), 403);
  assert.equal(await lot(intrus, [ajoutGymnase(id, 'e1', 'g3', {}, 3)]), 403);
  assert.equal(await lot(chef, [modifier(c.gymnase('g2'), { nom: 'Annexe Nord' })]), 200);
  assert.equal(await lot(lea, [modifier(c.gymnase('g2'), { nom: 'Pirate' })]), 403);
  assert.equal(await lot(chef, [modifier(c.gymnase('g2'), { inconnu: 'x' })]), 403);
  assert.equal(await lot(chef, [effacer(c.gymnase('g2'))]), 403);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g4', { nom: '' }, 3)]), 403);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g4', { nom: 'x'.repeat(41) }, 3)]), 403);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g4', { inconnu: 'x' }, 3)]), 403);
});

test('les gymnases sont lisibles par les membres tant que l’événement est en cours', async () => {
  const { chef, lea, intrus, c } = await evenementEnCours();
  assert.equal(await lire(lea, c.gymnase()), 200);
  assert.equal(await lire(lea, c.stock('p1')), 200);
  assert.equal(await lire(intrus, c.gymnase()), 403);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lire(lea, c.gymnase()), 403);
  assert.equal(await lire(chef, c.gymnase()), 200);
  // Plus de nouveau gymnase ni de renommage sur un événement clôturé.
  assert.equal(await lot(chef, [modifier(c.gymnase(), { nom: 'Tard' })]), 403);
});

// ---------- caisse « uid__gymnase » ----------
test('l’identifiant de la caisse est imposé et le gymnase doit exister', async () => {
  const { lea, c } = await evenementEnCours();
  // Gymnase inexistant.
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid, 'fantome'))]), 403);
  // Identifiant mal formé : sans gymnase, ou sans le uid du membre.
  assert.equal(await lot(lea, [{
    ...ecrire(`${c.evt}/caisses/${lea.uid}`, {
      prenom: 'Lea', statut: 'ouverte', ouverteLe: MAJ, membreUid: lea.uid, gymnaseId: 'g1',
    }),
    __avec: [pointeur(c.caisse(lea.uid))],
  }]), 403);
  // membreUid ou gymnaseId qui mentent.
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid), { membreUid: 'autre' })]), 403);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid), { gymnaseId: 'g2' })]), 403);
  // Témoin.
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
});

test('une caisse ne s’ouvre pas sans son pointeur (même lot)', async () => {
  const { lea, c } = await evenementEnCours();
  const { __avec, ...sansPointeur } = caisse(c.caisse(lea.uid));
  void __avec;
  assert.equal(await lot(lea, [sansPointeur]), 403);
  // Pointeur qui désigne une autre caisse.
  assert.equal(await lot(lea, [{
    ...sansPointeur,
    __avec: [ecrire(c.ouverte(lea.uid), { gymnaseId: 'g1', caisseId: `${lea.uid}__g2` })],
  }]), 403);
  // Le pointeur seul, sans caisse : refusé.
  assert.equal(await lot(lea, [pointeur(c.caisse(lea.uid))]), 403);
});

test('un membre n’a jamais deux caisses ouvertes sur un événement', async () => {
  const { lea, chef, id, c } = await deuxGymnases();
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]), 200);
  // Une deuxième caisse, dans l'autre gymnase, est refusée tant que la première est ouverte.
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid, 'g2'))]), 403);
  // Un autre membre n'est pas gêné.
  assert.equal(await lot(chef, [caisse(c.caisse(chef.uid, 'g2'), { prenom: 'Chef' })]), 200);
  void id;
});

test('clôturer libère le membre : il ouvre dans l’autre gymnase, puis revient dans le premier', async () => {
  const { lea, c } = await deuxGymnases();
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]), 200);
  // La clôture sans retirer le pointeur est refusée (l'écriture seule ne libère pas).
  const { __avec, ...cloSeule } = cloturer(c.caisse(lea.uid, 'g1'));
  void __avec;
  assert.equal(await lot(lea, [cloSeule]), 403);
  assert.equal(await lot(lea, [cloturer(c.caisse(lea.uid, 'g1'))]), 200);
  assert.equal(await lire(lea, c.ouverte(lea.uid)), 404);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid, 'g2'))]), 200);
  // Rouvrir la première caisse alors que la seconde est ouverte : refusé.
  assert.equal(await lot(lea, [rouvrir(c.caisse(lea.uid, 'g1'))]), 403);
  assert.equal(await lot(lea, [cloturer(c.caisse(lea.uid, 'g2'))]), 200);
  // Pointeur libre : la réouverture passe.
  assert.equal(await lot(lea, [rouvrir(c.caisse(lea.uid, 'g1'))]), 200);
  assert.equal(await lire(lea, c.ouverte(lea.uid)), 200);
});

test('le pointeur : lisible par son propriétaire, jamais modifiable ni effaçable à la main', async () => {
  const { lea, chef, c } = await evenementEnCours();
  await lot(lea, [caisse(c.caisse(lea.uid))]);
  assert.equal(await lire(lea, c.ouverte(lea.uid)), 200);
  assert.equal(await lire(chef, c.ouverte(lea.uid)), 403);
  assert.equal(await lot(lea, [effacer(c.ouverte(lea.uid))]), 403); // caisse encore ouverte
  assert.equal(await lot(chef, [effacer(c.ouverte(lea.uid))]), 403);
  assert.equal(await lot(lea, [modifier(c.ouverte(lea.uid), { gymnaseId: 'g2' })]), 403);
  // Pointeur au nom d'un autre membre.
  assert.equal(await lot(lea, [ecrire(c.ouverte(chef.uid), { gymnaseId: 'g1', caisseId: `${chef.uid}__g1` })]), 403);
});

// ---------- stock par gymnase ----------
test('chaque gymnase a son stock : on ne touche qu’à celui où la caisse est ouverte', async () => {
  const { lea, c } = await deuxGymnases();
  await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1', 'g1'), 19)]), 200);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1', 'g2'), 6)]), 403); // l'autre gymnase
  await lot(lea, [cloturer(c.caisse(lea.uid, 'g1'))]);
  // Caisse clôturée : plus de vente, donc plus de baisse de stock.
  assert.equal(await lot(lea, [baisserStock(c.stock('p1', 'g1'), 18)]), 403);
  await lot(lea, [caisse(c.caisse(lea.uid, 'g2'))]);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1', 'g2'), 6)]), 200);
  assert.equal(await lot(lea, [baisserStock(c.stock('p1', 'g1'), 17)]), 403);
});

test('la gestion règle le stock de n’importe quel gymnase ; le stock est créé par la gestion seule', async () => {
  const { chef, gestionnaire, lea, id, c } = await deuxGymnases();
  assert.equal(await lot(chef, [baisserStock(c.stock('p1', 'g1'), 50)]), 200);
  assert.equal(await lot(gestionnaire, [baisserStock(c.stock('p1', 'g2'), 12)]), 200);
  assert.equal(await lot(chef, [baisserStock(c.stock('p1', 'g1'), 100001)]), 403);
  // Création d'un stock (suivre un produit dans un gymnase) : gestion seulement, quantité raisonnable.
  const nouveau = (u, q) => lot(u, [{
    update: { name: `${RACINE}/${c.stock('p2', 'g2')}`, fields: { quantite: entier(q) } },
    currentDocument: { exists: false },
  }]);
  assert.equal(await nouveau(lea, 5), 403);
  assert.equal(await nouveau(chef, -1), 403);
  assert.equal(await nouveau(chef, 5), 200);
  void id;
});

// ---------- ventes ----------
test('la vente porte le gymnase de sa caisse, et lui seul', async () => {
  const { lea, c } = await deuxGymnases();
  await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]);
  assert.equal(await lot(lea, [vente(c.vente(lea.uid, 'v1', 'g1'))]), 200);
  const mensonge = vente(c.vente(lea.uid, 'v2', 'g1'), { gymnaseId: { stringValue: 'g2' } });
  assert.equal(await lot(lea, [mensonge]), 403);
  const sans = vente(c.vente(lea.uid, 'v3', 'g1'));
  delete sans.update.fields.gymnaseId;
  assert.equal(await lot(lea, [sans]), 403);
  // Pas de vente dans une caisse du gymnase où l'on n'a rien ouvert.
  assert.equal(await lot(lea, [vente(c.vente(lea.uid, 'v4', 'g2'))]), 403);
});

test('lecture : un bénévole voit ses caisses (plusieurs gymnases), pas celles des autres', async () => {
  const { lea, chef, c } = await deuxGymnases();
  await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]);
  await lot(lea, [cloturer(c.caisse(lea.uid, 'g1'))]);
  await lot(lea, [caisse(c.caisse(lea.uid, 'g2'))]);
  assert.equal(await lire(lea, c.caisse(lea.uid, 'g1')), 200);
  assert.equal(await lire(lea, c.caisse(lea.uid, 'g2')), 200);
  assert.equal(await lire(lea, c.caisse(chef.uid, 'g1')), 403);
  assert.equal(await lire(chef, c.caisse(lea.uid, 'g2')), 200);
});

// ---------- M2 : suivre ou ne plus suivre un produit dans un gymnase ----------
test('la gestion arrête le suivi d’un produit dans un gymnase (stock supprimé) ; ni bénévole ni événement clôturé', async () => {
  const { chef, gestionnaire, lea, intrus, c } = await deuxGymnases();
  assert.equal(await lot(lea, [effacer(c.stock('p1', 'g1'))]), 403);
  assert.equal(await lot(intrus, [effacer(c.stock('p1', 'g1'))]), 403);
  // Même un bénévole dont la caisse est ouverte dans ce gymnase ne supprime pas le stock.
  await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]);
  assert.equal(await lot(lea, [effacer(c.stock('p1', 'g1'))]), 403);
  assert.equal(await lot(chef, [effacer(c.stock('p1', 'g1'))]), 200);
  assert.equal(await lire(chef, c.stock('p1', 'g1')), 404);
  // Le stock de l'autre gymnase n'est pas touché ; on peut reprendre le suivi.
  assert.equal(await lire(chef, c.stock('p1', 'g2')), 200);
  assert.equal(await lot(gestionnaire, [{
    update: { name: `${RACINE}/${c.stock('p1', 'g1')}`, fields: { quantite: entier(15) } },
    currentDocument: { exists: false },
  }]), 200);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [effacer(c.stock('p1', 'g1'))]), 403);
});

test('la gestion ajoute un gymnase avec ses stocks dans le même lot ; un bénévole non', async () => {
  const { chef, lea, id } = await evenementEnCours();
  const stock = (g, p, q) => ({
    update: {
      name: `${RACINE}/associations/${id}/evenements/e1/gymnases/${g}/stocks/${p}`,
      fields: { quantite: entier(q) },
    },
  });
  assert.equal(await lot(lea, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' }), stock('g2', 'p1', 0)]), 403);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' }), stock('g2', 'p1', 0)]), 200);
});
