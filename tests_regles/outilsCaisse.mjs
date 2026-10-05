// Outils des tests de caisses (étapes 7 et 8, puis gymnases).
// Modèle : un événement a des gymnases (g1 par défaut), chacun avec ses stocks ;
// une caisse est « uid__gymnase » ; un pointeur « ouvertes/uid » dit quelle caisse
// est ouverte pour ce membre (créé à l'ouverture, retiré à la clôture, même lot).
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import {
  RACINE, MAJ, MAINTENANT, assoAvecGestionnaire, ecrire, effacer, entier, lot, produit,
} from './outils.mjs';

export const GYM = 'g1';

export const evenement = (extra = {}) => ({
  nom: 'Tournoi', date: '2026-10-03', statut: 'en_cours',
  modes: ['especes', 'carte'], menuNom: 'Menu Tournoi', creeLe: MAJ, ...extra,
});

/**
 * Produit d'un événement (sans stock). Si `stock` est donné, la quantité de
 * départ est posée dans le gymnase `g` (par défaut g1) dans le même lot.
 */
export const produitEvenement = (id, e, p, extra = {}) => {
  const { stock, g = GYM, ...reste } = extra;
  const u = produit({ id, menu: 'x', p, ...reste }).update;
  u.name = `${RACINE}/associations/${id}/evenements/${e}/produits/${p}`;
  const ecriture = { update: u };
  if (stock !== undefined) {
    ecriture.__avec = [{
      update: {
        name: `${RACINE}/associations/${id}/evenements/${e}/gymnases/${g}/stocks/${p}`,
        fields: { quantite: entier(stock) },
      },
    }];
  }
  return ecriture;
};

/** Le gymnase (à poser dans le même lot que l'événement). */
export const gymnase = (id, e = 'e1', g = GYM, extra = {}) =>
  ecrire(`associations/${id}/evenements/${e}/gymnases/${g}`, { nom: 'Principal', creeLe: MAJ, ...extra });

/**
 * Ajoute un gymnase à un événement existant : le compteur `nbGymnases` de
 * l'événement passe à [n] dans le même lot.
 */
export const ajoutGymnase = (id, e, g, extra = {}, n = 2) => ({
  ...gymnase(id, e, g, extra),
  __avec: [{
    update: { name: `${RACINE}/associations/${id}/evenements/${e}`, fields: { nbGymnases: entier(n) } },
    updateMask: { fieldPaths: ['nbGymnases'] },
    currentDocument: { exists: true },
  }],
});

/** Rattache un membre à des gymnases (écriture du responsable). */
export const rattachement = (id, e, uid, gymnases) =>
  ecrire(`associations/${id}/evenements/${e}/rattachements/${uid}`, { gymnases });

export const chemins = (id, e = 'e1', g = GYM) => ({
  evt: `associations/${id}/evenements/${e}`,
  gymnase: (gym = g) => `associations/${id}/evenements/${e}/gymnases/${gym}`,
  caisse: (uid, gym = g) => `associations/${id}/evenements/${e}/caisses/${uid}__${gym}`,
  vente: (uid, v = randomUUID().slice(0, 8), gym = g) =>
    `associations/${id}/evenements/${e}/caisses/${uid}__${gym}/ventes/${v}`,
  stock: (p, gym = g) => `associations/${id}/evenements/${e}/gymnases/${gym}/stocks/${p}`,
  produit: (p) => `associations/${id}/evenements/${e}/produits/${p}`,
  rattachement: (uid) => `associations/${id}/evenements/${e}/rattachements/${uid}`,
  ouverte: (uid) => `associations/${id}/evenements/${e}/ouvertes/${uid}`,
});

/** Lit « uid__gymnase » dans le chemin d'une caisse. */
export function decoupe(chemin) {
  const m = chemin.match(/^(associations\/[^/]+\/evenements\/[^/]+)\/caisses\/([^_/]+)__([^/]+)/);
  assert.ok(m, `chemin de caisse inattendu : ${chemin}`);
  return { evt: m[1], uid: m[2], gym: m[3], id: `${m[2]}__${m[3]}` };
}

export const ligne = (nom = 'Croque', prix = 300, q = 2) => ({
  mapValue: {
    fields: {
      produitId: { stringValue: 'p1' },
      nom: { stringValue: nom },
      prixCentimes: entier(prix),
      quantite: entier(q),
    },
  },
});

/** Vente dans la caisse du chemin (le gymnase de la vente est celui de la caisse). */
export const vente = (chemin, extra = {}) => ({
  update: {
    name: `${RACINE}/${chemin}`,
    fields: {
      lignes: { arrayValue: { values: [ligne()] } },
      totalCentimes: entier(600),
      mode: { stringValue: 'especes' },
      creeLe: { timestampValue: MAINTENANT },
      gymnaseId: { stringValue: chemin.match(/__([^/]+)\/ventes\//)[1] },
      ...extra,
    },
  },
});

/** Le pointeur d'une caisse (créé avec elle). */
export const pointeur = (chemin) => {
  const { evt, uid, gym, id } = decoupe(chemin);
  return ecrire(`${evt}/ouvertes/${uid}`, { gymnaseId: gym, caisseId: id });
};

/** Ouvre une caisse : la caisse ET son pointeur partent dans le même lot. */
export const caisse = (chemin, extra = {}) => {
  const { uid, gym } = decoupe(chemin);
  return {
    ...ecrire(chemin, {
      prenom: 'Lea', statut: 'ouverte', ouverteLe: MAJ, membreUid: uid, gymnaseId: gym, ...extra,
    }),
    __avec: [pointeur(chemin)],
  };
};

/** Ajoute à une écriture de caisse la suppression du pointeur (clôture). */
export const avecPointeurEfface = (ecriture, chemin) => {
  const { evt, uid } = decoupe(chemin);
  return { ...ecriture, __avec: [effacer(`${evt}/ouvertes/${uid}`)] };
};

/** Ajoute à une écriture de caisse la création du pointeur (réouverture). */
export const avecPointeurCree = (ecriture, chemin) => ({ ...ecriture, __avec: [pointeur(chemin)] });

export const baisserStock = (chemin, valeur) => ({
  update: { name: `${RACINE}/${chemin}`, fields: { quantite: entier(valeur) } },
  updateMask: { fieldPaths: ['quantite'] },
  currentDocument: { exists: true },
});

/**
 * Association + événement en cours, un gymnase g1 (produit p1 avec stock 20,
 * p2 sans suivi de stock). Aucune caisse n'est ouverte.
 */
export async function evenementEnCours() {
  const ctx = await assoAvecGestionnaire();
  const c = chemins(ctx.id);
  assert.equal(await lot(ctx.chef, [
    ecrire(c.evt, evenement()),
    gymnase(ctx.id),
    produitEvenement(ctx.id, 'e1', 'p1', { stock: 20 }),
    produitEvenement(ctx.id, 'e1', 'p2'),
  ]), 200);
  // Le gestionnaire est rattaché au gymnase g1 (sans cela il n'y voit rien).
  assert.equal(await lot(ctx.chef, [rattachement(ctx.id, 'e1', ctx.gestionnaire.uid, [GYM])]), 200);
  return { ...ctx, c };
}
