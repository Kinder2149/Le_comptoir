// Tests des règles Firestore sur la copie locale (émulateurs).
// Lancement : tests_regles/lancer.ps1
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import {
  admin, anonymeRattacheAGoogle, assoAvecGestionnaire, codeAleatoire, creerAsso,
  ecrire, effacer, google, lire, lot, MAJ, menu, modifier, produit, rejoindre,
  utilisateur, API, RACINE,
} from './outils.mjs';

// ---------- tests ----------
test('sans connexion : tout est refusé', async () => {
  assert.equal(await lire(null, 'associations/x'), 403);
  assert.equal(await lire(null, 'codes/ABC234'), 403);
  assert.equal(
    await lot(null, [ecrire('users/x', { assoId: 'a' })]),
    403,
  );
});

test('un responsable crée son association et la lit', async () => {
  const chef = await google();
  const { id } = await creerAsso(chef);
  assert.equal(await lire(chef, `associations/${id}`), 200);
  assert.equal(await lire(chef, `associations/${id}/membres/${chef.uid}`), 200);
});

test('impossible de créer une association au nom d’un autre', async () => {
  const chef = await google();
  const autre = await utilisateur();
  const id = randomUUID().replace(/-/g, '').slice(0, 20);
  const code = codeAleatoire();
  const statut = await lot(chef, [
    ecrire(`associations/${id}`, {
      nom: 'Pirate', code, responsableUid: autre.uid, creeLe: MAJ,
    }),
    ecrire(`associations/${id}/membres/${chef.uid}`, {
      prenom: 'Chef', role: 'responsable', rejointLe: MAJ, codeUtilise: '',
    }),
  ]);
  assert.equal(statut, 403);
});

test('un non-membre ne voit ni l’association ni ses membres', async () => {
  const chef = await google();
  const intrus = await utilisateur();
  const { id } = await creerAsso(chef);
  assert.equal(await lire(intrus, `associations/${id}`), 403);
  assert.equal(await lire(intrus, `associations/${id}/membres/${chef.uid}`), 403);
});

test('on lit un code précis, jamais la liste des codes', async () => {
  const chef = await google();
  const autre = await utilisateur();
  const { code } = await creerAsso(chef);
  assert.equal(await lire(autre, `codes/${code}`), 200);
  assert.equal(await lire(autre, 'codes'), 403);
});

test('un bénévole rejoint avec le bon code et voit l’association', async () => {
  const chef = await google();
  const lea = await utilisateur();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  assert.equal(await lire(lea, `associations/${id}`), 200);
  assert.equal(await lire(lea, `associations/${id}/membres/${chef.uid}`), 200);
});

test('un faux code ne permet pas de rejoindre', async () => {
  const chef = await google();
  const intrus = await utilisateur();
  const { id } = await creerAsso(chef);
  assert.equal(await rejoindre(intrus, id, 'ZZZZZZ'), 403);
  assert.equal(await lire(intrus, `associations/${id}`), 403);
});

test('on ne peut pas se déclarer responsable d’une association existante', async () => {
  const chef = await google();
  const intrus = await utilisateur();
  const { id, code } = await creerAsso(chef);
  const statut = await lot(intrus, [
    ecrire(`associations/${id}/membres/${intrus.uid}`, {
      prenom: 'Faux', role: 'responsable', rejointLe: MAJ, codeUtilise: code,
    }),
  ]);
  assert.equal(statut, 403);
});

test('on ne peut pas inscrire quelqu’un d’autre', async () => {
  const chef = await google();
  const intrus = await utilisateur();
  const victime = await utilisateur();
  const { id, code } = await creerAsso(chef);
  const statut = await lot(intrus, [
    ecrire(`associations/${id}/membres/${victime.uid}`, {
      prenom: 'Zoe', role: 'benevole', rejointLe: MAJ, codeUtilise: code,
    }),
  ]);
  assert.equal(statut, 403);
});

test('un bénévole ne peut pas changer le code ni supprimer un code', async () => {
  const chef = await google();
  const lea = await utilisateur();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  assert.equal(await lot(lea, [modifier(`associations/${id}`, { code: 'QQQQQQ' })]), 403);
  assert.equal(await lot(lea, [effacer(`codes/${code}`)]), 403);
});

test('le responsable régénère : l’ancien code ne marche plus, le nouveau oui', async () => {
  const chef = await google();
  const { id, code } = await creerAsso(chef);
  const nouveau = codeAleatoire();
  const statut = await lot(chef, [
    modifier(`associations/${id}`, { code: nouveau }),
    effacer(`codes/${code}`),
    ecrire(`codes/${nouveau}`, { assoId: id }),
  ]);
  assert.equal(statut, 200);
  const retard = await utilisateur();
  assert.equal(await lire(retard, `codes/${code}`), 404);
  assert.equal(await rejoindre(retard, id, code), 403);
  const arrive = await utilisateur();
  assert.equal(await lire(arrive, `codes/${nouveau}`), 200);
  assert.equal(await rejoindre(arrive, id, nouveau), 200);
});

test('un membre déjà inscrit reste membre après régénération du code', async () => {
  const chef = await google();
  const lea = await utilisateur();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  const nouveau = codeAleatoire();
  await lot(chef, [
    modifier(`associations/${id}`, { code: nouveau }),
    effacer(`codes/${code}`),
    ecrire(`codes/${nouveau}`, { assoId: id }),
  ]);
  assert.equal(await lire(lea, `associations/${id}`), 200);
});

test('un code ne peut pas être posé s’il n’est pas celui de l’association', async () => {
  const chef = await google();
  const { id } = await creerAsso(chef);
  assert.equal(
    await lot(chef, [ecrire(`codes/${codeAleatoire()}`, { assoId: id })]),
    403,
  );
});

test('un code existant ne peut pas être écrasé par une autre association', async () => {
  const chef1 = await google();
  const chef2 = await google();
  const a1 = await creerAsso(chef1);
  const a2 = await creerAsso(chef2);
  const statut = await lot(chef2, [
    modifier(`associations/${a2.id}`, { code: a1.code }),
    effacer(`codes/${a2.code}`),
    ecrire(`codes/${a1.code}`, { assoId: a2.id }),
  ]);
  assert.equal(statut, 403);
});

// ---------- étape 4 : Google et rôles ----------
test('créer une association exige un compte Google', async () => {
  const anonyme = await utilisateur();
  const id = randomUUID().replace(/-/g, '').slice(0, 20);
  const code = codeAleatoire();
  const statut = await lot(anonyme, [
    ecrire(`associations/${id}`, {
      nom: 'Sans Google', code, responsableUid: anonyme.uid, creeLe: MAJ,
    }),
    ecrire(`associations/${id}/membres/${anonyme.uid}`, {
      prenom: 'Chef', role: 'responsable', rejointLe: MAJ, codeUtilise: '',
    }),
    ecrire(`codes/${code}`, { assoId: id }),
  ]);
  assert.equal(statut, 403);
});

test('un compte anonyme rattaché à Google peut créer (même identifiant)', async () => {
  const chef = await anonymeRattacheAGoogle();
  const { id } = await creerAsso(chef);
  assert.equal(await lire(chef, `associations/${id}`), 200);
});

test('seul le responsable change le code ; un gestionnaire, un bénévole, un intrus non', async () => {
  const chef = await google();
  const gestionnaire = await google();
  const lea = await utilisateur();
  const intrus = await google();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  // Le gestionnaire est posé par l'administrateur (la nomination arrive à l'étape 10).
  assert.equal(
    await lot(admin, [
      ecrire(`associations/${id}/membres/${gestionnaire.uid}`, {
        prenom: 'Gus', role: 'gestionnaire', rejointLe: MAJ, codeUtilise: '',
      }),
    ]),
    200,
  );
  const nouveau = codeAleatoire();
  const changer = (u) =>
    lot(u, [
      modifier(`associations/${id}`, { code: nouveau }),
      effacer(`codes/${code}`),
      ecrire(`codes/${nouveau}`, { assoId: id }),
    ]);
  assert.equal(await changer(lea), 403);
  assert.equal(await changer(gestionnaire), 403);
  assert.equal(await changer(intrus), 403);
  assert.equal(await changer(chef), 200);
});

test('un gestionnaire voit l’association mais ne peut pas la supprimer', async () => {
  const chef = await google();
  const gestionnaire = await google();
  const { id } = await creerAsso(chef);
  await lot(admin, [
    ecrire(`associations/${id}/membres/${gestionnaire.uid}`, {
      prenom: 'Gus', role: 'gestionnaire', rejointLe: MAJ, codeUtilise: '',
    }),
  ]);
  assert.equal(await lire(gestionnaire, `associations/${id}`), 200);
  assert.equal(await lot(gestionnaire, [effacer(`associations/${id}`)]), 403);
});

test('seul le responsable supprime l’association', async () => {
  const chef = await google();
  const lea = await utilisateur();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  assert.equal(await lot(lea, [effacer(`associations/${id}`)]), 403);
  // Sans le drapeau « en cours de suppression », même le responsable ne peut pas.
  assert.equal(await lot(chef, [effacer(`associations/${id}`)]), 403);
  assert.equal(await lot(chef, [{
    update: { name: `${RACINE}/associations/${id}`, fields: { suppression: { booleanValue: true } } },
    updateMask: { fieldPaths: ['suppression'] },
    currentDocument: { exists: true },
  }]), 200);
  assert.equal(await lot(chef, [effacer(`associations/${id}`)]), 200);
  assert.equal(await lire(chef, `associations/${id}`), 404); // supprimée
});

test('personne ne peut s’attribuer ni changer un rôle', async () => {
  const chef = await google();
  const lea = await utilisateur();
  const { id, code } = await creerAsso(chef);
  assert.equal(await rejoindre(lea, id, code), 200);
  // Se déclarer gestionnaire à l'arrivée.
  const malin = await utilisateur();
  assert.equal(
    await lot(malin, [
      ecrire(`associations/${id}/membres/${malin.uid}`, {
        prenom: 'Malin', role: 'gestionnaire', rejointLe: MAJ, codeUtilise: code,
      }),
    ]),
    403,
  );
  // Se promouvoir après coup, ou promouvoir quelqu'un (même le responsable).
  const promouvoir = (u, cible) =>
    lot(u, [modifier(`associations/${id}/membres/${cible.uid}`, { role: 'gestionnaire' })]);
  assert.equal(await promouvoir(lea, lea), 403);
  assert.equal(await promouvoir(chef, lea), 403);
});

// ---------- étape 5 : menus et produits ----------
test('responsable et gestionnaire créent, lisent, modifient, suppriment menus et produits', async () => {
  const { chef, gestionnaire, id } = await assoAvecGestionnaire();
  for (const [qui, m] of [[chef, 'mA'], [gestionnaire, 'mB']]) {
    assert.equal(await lot(qui, [ecrire(`associations/${id}/menus/${m}`, menu())]), 200);
    assert.equal(await lire(qui, `associations/${id}/menus/${m}`), 200);
    assert.equal(await lot(qui, [produit({ id, menu: m, p: 'p1', stock: 20 })]), 200);
    assert.equal(await lot(qui, [produit({ id, menu: m, p: 'p2' })]), 200); // sans stock
    assert.equal(await lire(qui, `associations/${id}/menus/${m}/produits/p1`), 200);
    assert.equal(await lot(qui, [modifier(`associations/${id}/menus/${m}`, { nom: 'Renommé' })]), 200);
    assert.equal(await lot(qui, [effacer(`associations/${id}/menus/${m}/produits/p1`)]), 200);
    assert.equal(await lot(qui, [effacer(`associations/${id}/menus/${m}`)]), 200);
  }
});

test('un bénévole ne voit ni ne touche aux menus', async () => {
  const { chef, lea, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/menus/m1`, menu())]);
  await lot(chef, [produit({ id, menu: 'm1', p: 'p1' })]);
  assert.equal(await lire(lea, `associations/${id}/menus/m1`), 403);
  assert.equal(await lire(lea, `associations/${id}/menus/m1/produits/p1`), 403);
  assert.equal(await lot(lea, [ecrire(`associations/${id}/menus/m2`, menu())]), 403);
  assert.equal(await lot(lea, [produit({ id, menu: 'm1', p: 'p9' })]), 403);
  assert.equal(await lot(lea, [effacer(`associations/${id}/menus/m1`)]), 403);
  assert.equal(await lot(lea, [effacer(`associations/${id}/menus/m1/produits/p1`)]), 403);
});

test('un intrus (même avec Google) ne voit ni ne touche aux menus', async () => {
  const { chef, intrus, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/menus/m1`, menu())]);
  assert.equal(await lire(intrus, `associations/${id}/menus/m1`), 403);
  assert.equal(await lot(intrus, [ecrire(`associations/${id}/menus/m2`, menu())]), 403);
  assert.equal(await lot(intrus, [produit({ id, menu: 'm1', p: 'p1' })]), 403);
});

test('données de produit invalides refusées', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/menus/m1`, menu())]);
  const essai = (extra) => lot(chef, [produit({ id, menu: 'm1', p: 'px', ...extra })]);
  assert.equal(await essai({}), 200); // témoin : valide
  assert.equal(await essai({ prix: -1 }), 403);
  assert.equal(await essai({ prix: 100001 }), 403);
  assert.equal(await essai({ nom: '' }), 403);
  assert.equal(await essai({ nom: 'x'.repeat(41) }), 403);
  assert.equal(await essai({ stock: -5 }), 403);
  assert.equal(await essai({ stock: 100001 }), 403);
  assert.equal(await essai({ champs: { gratuit: { booleanValue: true } } }), 403);
  assert.equal(await essai({ champs: { prixCentimes: { stringValue: '3' } } }), 403);
  assert.equal(await essai({ champs: { stock: { stringValue: 'beaucoup' } } }), 403);
  assert.equal(await essai({ prix: 0 }), 200); // gratuit autorisé
  assert.equal(await essai({ stock: 0 }), 200); // rupture autorisée
  assert.equal(await lot(chef, [ecrire(`associations/${id}/menus/m3`, { nom: '', creeLe: MAJ })]), 403);
  assert.equal(await lot(chef, [ecrire(`associations/${id}/menus/m3`, { nom: 'ok', creeLe: MAJ, extra: 'x' })]), 403);
});

test('on peut retirer le suivi du stock d’un produit', async () => {
  const { chef, id } = await assoAvecGestionnaire();
  await lot(chef, [ecrire(`associations/${id}/menus/m1`, menu())]);
  await lot(chef, [produit({ id, menu: 'm1', p: 'p1', stock: 10 })]);
  const r = await lot(chef, [{
    update: { name: `${RACINE}/associations/${id}/menus/m1/produits/p1`, fields: {} },
    updateMask: { fieldPaths: ['stock'] },
    currentDocument: { exists: true },
  }]);
  assert.equal(r, 200);
  const doc = await (await fetch(`${API}/associations/${id}/menus/m1/produits/p1`, {
    headers: { Authorization: `Bearer ${chef.jeton}` },
  })).json();
  assert.equal(doc.fields.stock, undefined);
});
