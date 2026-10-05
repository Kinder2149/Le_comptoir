// Chantier gymnases, mission M3 : gestionnaires rattachés à des gymnases.
// Rattachement : `evenements/{e}/rattachements/{uid}` = { gymnases: [ids] }, écrit par le
// responsable seul. Compteur `nbGymnases` sur l'événement (clôture : responsable ou
// gestionnaire rattaché à TOUS les gymnases).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, API, RACINE, MAJ, MAINTENANT, ecrire, effacer, entier, google, lire, lot, modifier,
} from './outils.mjs';
import {
  ajoutGymnase, baisserStock, caisse, evenementEnCours, produitEvenement, rattachement, vente,
} from './outilsCaisse.mjs';

const membre = (id, u, prenom, role, extra = {}) => ({
  update: {
    name: `${RACINE}/associations/${id}/membres/${u.uid}`,
    fields: {
      prenom: { stringValue: prenom },
      role: { stringValue: role },
      rejointLe: { timestampValue: MAINTENANT },
      codeUtilise: { stringValue: '' },
      ...extra,
    },
  },
});

const annulation = (chemin, uid, prenom) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      annulee: { booleanValue: true },
      annuleePar: { stringValue: uid },
      annuleeParPrenom: { stringValue: prenom },
      annuleeLe: { timestampValue: MAINTENANT },
    },
  },
  updateMask: { fieldPaths: ['annulee', 'annuleePar', 'annuleeParPrenom', 'annuleeLe'] },
  currentDocument: { exists: true },
});

const cloturerEvenement = (chemin, uid, prenom) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      statut: { stringValue: 'cloture' },
      clotureLe: { timestampValue: MAINTENANT },
      cloturePar: { stringValue: uid },
      clotureParPrenom: { stringValue: prenom },
      forcee: { booleanValue: false },
      nbCaissesOuvertes: entier(0),
    },
  },
  updateMask: {
    fieldPaths: ['statut', 'clotureLe', 'cloturePar', 'clotureParPrenom', 'forcee', 'nbCaissesOuvertes'],
  },
  currentDocument: { exists: true },
});

/** Liste les caisses d'un événement, avec ou sans filtre sur le gymnase. */
async function listerCaisses(u, id, gymnaseId) {
  const structuredQuery = { from: [{ collectionId: 'caisses' }] };
  if (gymnaseId) {
    structuredQuery.where = {
      fieldFilter: {
        field: { fieldPath: 'gymnaseId' },
        op: 'EQUAL',
        value: { stringValue: gymnaseId },
      },
    };
  }
  const r = await fetch(`${API}/associations/${id}/evenements/e1:runQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${u.jeton}` },
    body: JSON.stringify({ structuredQuery }),
  });
  const corps = r.status === 200 ? await r.json() : [];
  return { statut: r.status, nb: corps.filter((x) => x.document).length };
}

/**
 * Événement à deux gymnases (g1 : p1 = 20, g2 : p1 = 7).
 * Gus (gestionnaire) rattaché à g1 ; Zed (gestionnaire) à g2 ; Attente (nommé, pas
 * encore activé = bénévole) « rattaché » à g1 par un reste d'ancien rattachement.
 * Léa a une caisse dans g1, Max dans g2, avec une vente chacune.
 */
async function monde() {
  const ctx = await evenementEnCours();
  const { chef, lea, id, c } = ctx;
  const zed = await google();
  const attente = await google();
  const max = await google();
  assert.equal(await lot(admin, [
    membre(id, zed, 'Zed', 'gestionnaire'),
    membre(id, attente, 'Attente', 'benevole', { nomme: { booleanValue: true } }),
    membre(id, max, 'Max', 'benevole'),
  ]), 200);
  assert.equal(await lot(chef, [
    ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' }),
    produitEvenement(id, 'e1', 'p3', { stock: 7, g: 'g2' }),
  ]), 200);
  assert.equal(await lot(chef, [
    rattachement(id, 'e1', zed.uid, ['g2']),
    rattachement(id, 'e1', attente.uid, ['g1']),
  ]), 200);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid, 'g1'))]), 200);
  assert.equal(await lot(max, [caisse(c.caisse(max.uid, 'g2'), { prenom: 'Max' })]), 200);
  const v1 = c.vente(lea.uid, 'v1', 'g1');
  const v2 = c.vente(max.uid, 'v2', 'g2');
  assert.equal(await lot(lea, [vente(v1)]), 200);
  assert.equal(await lot(max, [vente(v2)]), 200);
  return { ...ctx, zed, attente, max, v1, v2 };
}

// ---------- tir d'essai : lecture en liste limitée à un gymnase ----------
test('tir d’essai : la requête « caisses du gymnase g » passe pour son gestionnaire, pas pour un autre', async () => {
  const { chef, gestionnaire: gus, zed, attente, lea, intrus, id } = await monde();
  // Le responsable liste tout, avec ou sans filtre.
  assert.deepEqual(await listerCaisses(chef, id), { statut: 200, nb: 2 });
  assert.deepEqual(await listerCaisses(chef, id, 'g1'), { statut: 200, nb: 1 });
  // Gus (g1) : sa requête filtrée passe, et ne ramène que son gymnase.
  assert.deepEqual(await listerCaisses(gus, id, 'g1'), { statut: 200, nb: 1 });
  assert.equal((await listerCaisses(gus, id, 'g2')).statut, 403);
  assert.equal((await listerCaisses(gus, id)).statut, 403); // sans filtre : refusé
  // Zed (g2) : l'inverse.
  assert.deepEqual(await listerCaisses(zed, id, 'g2'), { statut: 200, nb: 1 });
  assert.equal((await listerCaisses(zed, id, 'g1')).statut, 403);
  // Un nommé pas encore activé (bénévole), un bénévole, un intrus : rien.
  for (const qui of [attente, lea, intrus]) {
    assert.equal((await listerCaisses(qui, id, 'g1')).statut, 403);
    assert.equal((await listerCaisses(qui, id)).statut, 403);
  }
});

test('les ventes d’une caisse se listent par son chemin : gestionnaire du gymnase seulement', async () => {
  const { chef, gestionnaire: gus, zed, lea, id, c, v1 } = await monde();
  const ventes = (u, caisseChemin) =>
    fetch(`${API}/${caisseChemin}/ventes`, { headers: { Authorization: `Bearer ${u.jeton}` } })
      .then((r) => r.status);
  const caisseLea = c.caisse(lea.uid, 'g1');
  assert.equal(await ventes(chef, caisseLea), 200);
  assert.equal(await ventes(gus, caisseLea), 200);
  assert.equal(await ventes(zed, caisseLea), 403);
  assert.equal(await ventes(lea, caisseLea), 200);
  void id; void v1;
});

// ---------- matrice de droits ----------
test('matrice : lire une caisse, lire une vente (gymnase g1 = celui de Léa)', async () => {
  const { chef, gestionnaire: gus, zed, attente, lea, max, intrus, c, v1 } = await monde();
  const caisseLea = c.caisse(lea.uid, 'g1');
  const attendus = [
    [chef, 200], [gus, 200], [zed, 403], [attente, 403], [lea, 200], [max, 403], [intrus, 403],
  ];
  for (const [qui, statut] of attendus) {
    assert.equal(await lire(qui, caisseLea), statut, `caisse : ${qui.uid}`);
    assert.equal(await lire(qui, v1), statut, `vente : ${qui.uid}`);
  }
});

test('matrice : annuler une vente du gymnase g1', async () => {
  const { chef, gestionnaire: gus, zed, attente, max, intrus, c, v1 } = await monde();
  for (const [qui, prenom] of [[zed, 'Zed'], [attente, 'Attente'], [max, 'Max'], [intrus, 'X']]) {
    assert.equal(await lot(qui, [annulation(v1, qui.uid, prenom)]), 403, prenom);
  }
  assert.equal(await lot(gus, [annulation(v1, gus.uid, 'Gus')]), 200);
  // Le responsable annule dans n'importe quel gymnase.
  assert.equal(await lot(chef, [annulation(c.vente(max.uid, 'v2', 'g2'), chef.uid, 'Chef')]), 200);
});

test('matrice : régler, supprimer ou créer un stock', async () => {
  const { chef, gestionnaire: gus, zed, attente, intrus, id, c } = await monde();
  const stock = (g, p, q) => ({
    update: {
      name: `${RACINE}/${c.stock(p, g)}`,
      fields: { quantite: entier(q) },
    },
  });
  // Régler la quantité de p1 dans g1.
  for (const qui of [zed, attente, intrus]) {
    assert.equal(await lot(qui, [baisserStock(c.stock('p1', 'g1'), 30)]), 403);
  }
  assert.equal(await lot(gus, [baisserStock(c.stock('p1', 'g1'), 30)]), 200);
  assert.equal(await lot(chef, [baisserStock(c.stock('p3', 'g2'), 30)]), 200);
  // Gus n'a aucun droit sur g2.
  assert.equal(await lot(gus, [baisserStock(c.stock('p3', 'g2'), 31)]), 403);
  // Arrêter le suivi.
  assert.equal(await lot(zed, [effacer(c.stock('p1', 'g1'))]), 403);
  assert.equal(await lot(gus, [effacer(c.stock('p3', 'g2'))]), 403);
  assert.equal(await lot(gus, [effacer(c.stock('p1', 'g1'))]), 200);
  // Reprendre le suivi : seulement dans son gymnase.
  const neuf = (u, g) => lot(u, [{ ...stock(g, 'p1', 5), currentDocument: { exists: false } }]);
  assert.equal(await neuf(gus, 'g2'), 403);
  assert.equal(await neuf(zed, 'g1'), 403);
  assert.equal(await neuf(gus, 'g1'), 200);
  void id;
});

test('un gestionnaire sans rattachement voit l’événement et les noms des gymnases, rien d’autre', async () => {
  const { chef, id, c } = await monde();
  const libre = await google();
  await lot(admin, [membre(id, libre, 'Libre', 'gestionnaire')]);
  assert.equal(await lire(libre, c.evt), 200);
  assert.equal(await lire(libre, c.gymnase('g1')), 200);
  assert.equal(await lire(libre, c.gymnase('g2')), 200);
  assert.equal((await listerCaisses(libre, id, 'g1')).statut, 403);
  assert.equal(await lot(libre, [baisserStock(c.stock('p1', 'g1'), 3)]), 403);
  assert.equal(await lire(libre, c.rattachement(libre.uid)), 404); // pas de document : lisible, vide
  void chef;
});

test('retrait d’un gestionnaire : son rattachement ne donne plus aucun droit', async () => {
  const { chef, gestionnaire: gus, lea, id, c } = await monde();
  assert.equal((await listerCaisses(gus, id, 'g1')).statut, 200);
  // Le responsable le retire (redevient bénévole, sans « nomme »).
  assert.equal(await lot(admin, [membre(id, gus, 'Gus', 'benevole')]), 200);
  assert.equal((await listerCaisses(gus, id, 'g1')).statut, 403);
  assert.equal(await lire(gus, c.caisse(lea.uid, 'g1')), 403);
  assert.equal(await lot(gus, [baisserStock(c.stock('p1', 'g1'), 3)]), 403);
  void chef;
});

// ---------- rattachements ----------
test('seul le responsable rattache ; chacun ne lit que le sien', async () => {
  const { chef, gestionnaire: gus, zed, lea, intrus, id, c } = await monde();
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, ['g1', 'g2'])]), 200);
  for (const qui of [gus, zed, lea, intrus]) {
    assert.equal(await lot(qui, [rattachement(id, 'e1', qui.uid, ['g1', 'g2'])]), 403);
  }
  assert.equal(await lire(chef, c.rattachement(gus.uid)), 200);
  assert.equal(await lire(gus, c.rattachement(gus.uid)), 200);
  assert.equal(await lire(zed, c.rattachement(gus.uid)), 403);
  assert.equal(await lire(lea, c.rattachement(gus.uid)), 403);
  // Contenu invalide : autre champ, pas une liste, trop long.
  assert.equal(await lot(chef, [ecrire(c.rattachement(gus.uid), { gymnases: 'g1' })]), 403);
  assert.equal(await lot(chef, [ecrire(c.rattachement(gus.uid), { gymnases: ['g1'], autre: 'x' })]), 403);
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])]), 403);
  // Rattachement vidé : plus de droits.
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, [])]), 200);
  assert.equal((await listerCaisses(gus, id, 'g1')).statut, 403);
  // Jamais supprimé hors suppression de l'association ; figé quand l'événement est clôturé.
  assert.equal(await lot(chef, [effacer(c.rattachement(gus.uid))]), 403);
  await lot(admin, [modifier(c.evt, { statut: 'cloture' })]);
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, ['g1'])]), 403);
});

// ---------- compteur de gymnases ----------
test('ajouter un gymnase exige de monter le compteur de l’événement de 1, dans le même lot', async () => {
  const { chef, gestionnaire: gus, lea, id, c } = await evenementEnCours();
  const sansCompteur = ecrire(c.gymnase('g2'), { nom: 'Annexe', creeLe: MAJ });
  assert.equal(await lot(chef, [sansCompteur]), 403);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', {}, 3)]), 403); // saute de 2
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g2', {}, 1)]), 403); // ne monte pas
  assert.equal(await lot(gus, [ajoutGymnase(id, 'e1', 'g2', { nom: 'Annexe' }, 2)]), 200);
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'g3', { nom: 'Nord' }, 3)]), 200);
  // Le compteur seul ne se monte pas à la main, ni par un bénévole.
  const monter = (u, n) => lot(u, [{
    update: { name: `${RACINE}/${c.evt}`, fields: { nbGymnases: entier(n) } },
    updateMask: { fieldPaths: ['nbGymnases'] },
    currentDocument: { exists: true },
  }]);
  assert.equal(await monter(lea, 4), 403);
  assert.equal(await monter(chef, 4), 200);
  assert.equal(await monter(chef, 6), 403); // pas de +2
});

test('au plus 8 gymnases par événement', async () => {
  const { chef, id, c } = await evenementEnCours();
  for (let n = 2; n <= 8; n++) {
    assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', `x${n}`, { nom: `G${n}` }, n)]), 200);
  }
  assert.equal(await lot(chef, [ajoutGymnase(id, 'e1', 'x9', { nom: 'G9' }, 9)]), 403);
  void c;
});

test('un événement peut naître avec plusieurs gymnases (compteur dans le même lot)', async () => {
  const { chef, id } = await evenementEnCours();
  const evt = (e, n) => ecrire(`associations/${id}/evenements/${e}`, {
    nom: 'Deux', date: '2026-10-03', statut: 'en_cours', modes: ['especes'],
    menuNom: 'M', creeLe: MAJ, nbGymnases: n,
  });
  const gym = (e, g) => ecrire(`associations/${id}/evenements/${e}/gymnases/${g}`, { nom: g, creeLe: MAJ });
  assert.equal(await lot(chef, [evt('e2', 2), gym('e2', 'a'), gym('e2', 'b')]), 200);
  assert.equal(await lot(chef, [evt('e3', 9), gym('e3', 'a')]), 403); // trop de gymnases annoncés
});

// ---------- clôture de l'événement ----------
test('clôture de l’événement : responsable, ou gestionnaire rattaché à TOUS les gymnases', async () => {
  const { chef, gestionnaire: gus, zed, id, c } = await monde();
  // Gus n'a que g1 sur deux : refusé ; Zed aussi.
  assert.equal(await lot(gus, [cloturerEvenement(c.evt, gus.uid, 'Gus')]), 403);
  assert.equal(await lot(zed, [cloturerEvenement(c.evt, zed.uid, 'Zed')]), 403);
  // Rattaché aux deux : accepté.
  assert.equal(await lot(chef, [rattachement(id, 'e1', gus.uid, ['g1', 'g2'])]), 200);
  assert.equal(await lot(gus, [cloturerEvenement(c.evt, gus.uid, 'Gus')]), 200);
});

test('clôture de l’événement par le responsable, quel que soit le rattachement', async () => {
  const { chef, c } = await monde();
  assert.equal(await lot(chef, [cloturerEvenement(c.evt, chef.uid, 'Chef')]), 200);
});

test('un gestionnaire (non responsable) crée un événement à 3 gymnases et 10 produits en un seul lot', async () => {
  const { gestionnaire: gus, id } = await evenementEnCours();
  const base = `associations/${id}/evenements/neuf`;
  const ecritures = [
    ecrire(base, {
      nom: 'Gros', date: '2026-10-03', statut: 'en_cours', modes: ['especes'],
      menuNom: 'M', creeLe: MAJ, nbGymnases: 3,
    }),
  ];
  for (const g of ['a', 'b', 'c']) {
    ecritures.push(ecrire(`${base}/gymnases/${g}`, { nom: `Gym ${g}`, creeLe: MAJ }));
  }
  for (let i = 0; i < 10; i++) {
    ecritures.push(produitEvenement(id, 'neuf', `p${i}`));
    for (const g of ['a', 'b', 'c']) {
      ecritures.push({
        update: { name: `${RACINE}/${base}/gymnases/${g}/stocks/p${i}`, fields: { quantite: entier(10) } },
      });
    }
  }
  assert.equal(await lot(gus, ecritures), 200);
});
