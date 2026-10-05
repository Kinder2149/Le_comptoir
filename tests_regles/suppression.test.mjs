// Étape 15 : suppression de l'association (en deux temps) et retrait d'un membre.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  admin, RACINE, MAJ, ecrire, effacer, lire, lot, rejoindre, utilisateur,
} from './outils.mjs';
import { caisse, evenementEnCours, vente } from './outilsCaisse.mjs';

const mise = (chemin, fields, masque) => ({
  update: { name: `${RACINE}/${chemin}`, fields },
  updateMask: { fieldPaths: masque },
  currentDocument: { exists: true },
});
const drapeau = (id, valeur = true, extra = {}) =>
  mise(`associations/${id}`, { suppression: { booleanValue: valeur }, ...extra },
    ['suppression', ...Object.keys(extra)]);

async function codeDe(id) {
  const doc = await (await fetch(`http://127.0.0.1:8080/v1/${RACINE}/associations/${id}`, {
    headers: { Authorization: 'Bearer owner' },
  })).json();
  return doc.fields.code.stringValue;
}

/** Association complète : un menu, un événement, deux caisses avec ventes, 3 membres. */
async function associationComplete() {
  const ctx = await evenementEnCours();
  const { chef, lea, id, c } = ctx;
  await lot(chef, [
    ecrire(`associations/${id}/menus/m1`, { nom: 'Menu', creeLe: MAJ }),
  ]);
  assert.equal(await lot(lea, [caisse(c.caisse(lea.uid))]), 200);
  assert.equal(await lot(chef, [caisse(c.caisse(chef.uid), { prenom: 'Chef' })]), 200);
  const v1 = c.vente(lea.uid, 'v1');
  const v2 = c.vente(chef.uid, 'v2');
  assert.equal(await lot(lea, [vente(v1)]), 200);
  assert.equal(await lot(chef, [vente(v2)]), 200);
  const code = await codeDe(id);
  return { ...ctx, v1, v2, code };
}

test('seul le responsable marque l\'association « en cours de suppression »', async () => {
  const { chef, gestionnaire, lea, intrus, id } = await associationComplete();
  assert.equal(await lot(gestionnaire, [drapeau(id)]), 403);
  assert.equal(await lot(lea, [drapeau(id)]), 403);
  assert.equal(await lot(intrus, [drapeau(id)]), 403);
  assert.equal(await lot(chef, [drapeau(id, false)]), 403); // pas de marche arrière par ce biais
  assert.equal(await lot(chef, [drapeau(id, true, { nom: { stringValue: 'Autre' } })]), 403);
  assert.equal(await lot(chef, [drapeau(id)]), 200); // témoin
});

test('sans le drapeau, rien ne s\'efface : ni vente, ni caisse, ni événement, ni copie', async () => {
  const { chef, gestionnaire, id, c, v1 } = await associationComplete();
  assert.equal(await lot(chef, [effacer(v1)]), 403); // une vente ne se supprime jamais seule
  assert.equal(await lot(chef, [effacer(c.caisse(chef.uid))]), 403);
  assert.equal(await lot(chef, [effacer(c.produit('p1'))]), 403);
  assert.equal(await lot(chef, [effacer(c.gymnase())]), 403); // un gymnase ne se supprime pas seul
  assert.equal(await lot(chef, [effacer(c.ouverte(chef.uid))]), 403); // pointeur : seulement via la clôture
  assert.equal(await lot(chef, [effacer(c.rattachement(gestionnaire.uid))]), 403); // rattachement : on le vide, on ne le supprime pas
  assert.equal(await lot(chef, [effacer(c.evt)]), 403);
  assert.equal(await lot(chef, [effacer(`associations/${id}`)]), 403); // pas sans le drapeau
});

test('avec le drapeau, le responsable efface tout, dans le bon ordre, puis l\'association', async () => {
  const { chef, id, c, v1, v2, code, lea, gestionnaire } = await associationComplete();
  assert.equal(await lot(chef, [drapeau(id)]), 200);
  const etapes = [
    [effacer(v1), effacer(v2)],
    [effacer(c.caisse(lea.uid)), effacer(c.caisse(chef.uid))],
    [effacer(c.ouverte(lea.uid)), effacer(c.ouverte(chef.uid))],
    [effacer(c.rattachement(gestionnaire.uid))],
    [effacer(c.stock('p1')), effacer(c.gymnase())],
    [effacer(c.produit('p1')), effacer(c.produit('p2'))],
    [effacer(c.evt)],
    [effacer(`associations/${id}/menus/m1`)],
    [effacer(`associations/${id}/membres/${lea.uid}`), effacer(`associations/${id}/membres/${gestionnaire.uid}`)],
    [effacer(`associations/${id}/membres/${chef.uid}`)], // le responsable en dernier
    [effacer(`codes/${code}`)],
    [effacer(`associations/${id}`)],
  ];
  for (const e of etapes) assert.equal(await lot(chef, e), 200, JSON.stringify(e).slice(0, 120));
  // Tout a disparu.
  assert.equal(await lire(admin, `associations/${id}`), 404);
  assert.equal(await lire(admin, v1), 404);
  assert.equal(await lire(admin, `codes/${code}`), 404);
  // L'ancien code ne permet plus de rejoindre.
  const nouveau = await utilisateur();
  assert.equal(await rejoindre(nouveau, id, code), 403);
});

test('avec le drapeau, personne d\'autre que le responsable n\'efface', async () => {
  const { chef, gestionnaire, lea, intrus, id, c, v1 } = await associationComplete();
  await lot(chef, [drapeau(id)]);
  for (const qui of [gestionnaire, lea, intrus]) {
    assert.equal(await lot(qui, [effacer(v1)]), 403);
    assert.equal(await lot(qui, [effacer(c.caisse(lea.uid))]), 403);
    assert.equal(await lot(qui, [effacer(c.evt)]), 403);
    assert.equal(await lot(qui, [effacer(c.produit('p1'))]), 403);
    assert.equal(await lot(qui, [effacer(c.gymnase())]), 403);
    assert.equal(await lot(qui, [effacer(c.rattachement(gestionnaire.uid))]), 403);
  }
});

test('le drapeau d\'une autre association ne donne aucun droit ici', async () => {
  const a = await associationComplete();
  const b = await associationComplete();
  await lot(b.chef, [drapeau(b.id)]);
  assert.equal(await lot(b.chef, [effacer(a.v1)]), 403); // pas son association
  assert.equal(await lot(a.chef, [effacer(a.v1)]), 403); // la sienne n'est pas marquée
});

test('on efface par lots de 15 (limite des règles respectée)', async () => {
  const { chef, lea, id, c } = await associationComplete();
  const ids = Array.from({ length: 15 }, (_, i) => `lot${i}`);
  for (const v of ids) assert.equal(await lot(lea, [vente(c.vente(lea.uid, v))]), 200);
  await lot(chef, [drapeau(id)]);
  assert.equal(await lot(chef, ids.map((v) => effacer(c.vente(lea.uid, v)))), 200);
  assert.equal(await lire(admin, c.vente(lea.uid, 'lot0')), 404);
});

// ---------- retrait d'un membre ----------
test('le responsable retire un bénévole ou un gestionnaire ; leurs ventes restent', async () => {
  const { chef, lea, gestionnaire, id, c, v1 } = await associationComplete();
  assert.equal(await lot(chef, [effacer(`associations/${id}/membres/${lea.uid}`)]), 200);
  assert.equal(await lot(chef, [effacer(`associations/${id}/membres/${gestionnaire.uid}`)]), 200);
  // L'historique de la caisse de Léa est conservé pour le bilan.
  assert.equal(await lire(chef, v1), 200);
  assert.equal(await lire(chef, c.caisse(lea.uid)), 200);
  // Les membres retirés n'accèdent plus à rien.
  assert.equal(await lire(lea, `associations/${id}`), 403);
  assert.equal(await lire(lea, v1), 403);
  assert.equal(await lire(gestionnaire, `associations/${id}/menus/m1`), 403);
});

test('retirer un membre n\'empêche pas de revenir avec l\'ancien code (d\'où « changer le code »)', async () => {
  const { chef, lea, id, code } = await associationComplete();
  await lot(chef, [effacer(`associations/${id}/membres/${lea.uid}`)]);
  assert.equal(await rejoindre(lea, id, code, 'Lea'), 200); // le code n'a pas changé : elle revient
  // Après changement de code, l'ancien ne marche plus.
  await lot(chef, [effacer(`associations/${id}/membres/${lea.uid}`)]);
  const nouveau = 'NNNNNN';
  assert.equal(await lot(chef, [
    mise(`associations/${id}`, { code: { stringValue: nouveau } }, ['code']),
    effacer(`codes/${code}`),
    ecrire(`codes/${nouveau}`, { assoId: id }),
  ]), 200);
  assert.equal(await rejoindre(lea, id, code, 'Lea'), 403);
  assert.equal(await rejoindre(lea, id, nouveau, 'Lea'), 200);
});

test('seul le responsable retire, et jamais lui-même', async () => {
  const { chef, gestionnaire, lea, intrus, id } = await associationComplete();
  const membre = (u) => `associations/${id}/membres/${u.uid}`;
  assert.equal(await lot(gestionnaire, [effacer(membre(lea))]), 403);
  assert.equal(await lot(gestionnaire, [effacer(membre(chef))]), 403);
  assert.equal(await lot(lea, [effacer(membre(gestionnaire))]), 403);
  assert.equal(await lot(lea, [effacer(membre(lea))]), 403); // pas de départ volontaire ici
  assert.equal(await lot(intrus, [effacer(membre(lea))]), 403);
  assert.equal(await lot(chef, [effacer(membre(chef))]), 403); // le responsable ne se retire pas
});

test('pendant la suppression, le responsable relit en liste les pointeurs, gymnases et stocks', async () => {
  const { chef, lea, id } = await associationComplete();
  const liste = async (u, chemin) => {
    const r = await fetch(`http://127.0.0.1:8080/v1/${RACINE}/associations/${id}/evenements/e1/${chemin}`, {
      headers: { Authorization: `Bearer ${u.jeton}` },
    });
    return r.status;
  };
  // Avant le drapeau : personne ne liste les pointeurs des autres.
  assert.equal(await liste(chef, 'ouvertes'), 403);
  assert.equal(await lot(chef, [drapeau(id)]), 200);
  assert.equal(await liste(chef, 'ouvertes'), 200);
  assert.equal(await liste(chef, 'gymnases'), 200);
  assert.equal(await liste(chef, 'gymnases/g1/stocks'), 200);
  // Un bénévole ne gagne rien avec le drapeau.
  assert.equal(await liste(lea, 'ouvertes'), 403);
});
