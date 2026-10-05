# PLAN — Plusieurs gymnases par événement (chantier validé le 03/10/2026)

> Document de pilotage du chantier. À lire avec `PROJET_CONTEXTE.md` (décisions figées 25 à 29) et
> `CHANGELOG.md`. Il se met à jour à la fin de CHAQUE mission (section 9). Rédigé pour être exécuté
> dans une nouvelle conversation, mission par mission.

## 1. Pourquoi (en clair)
Kinder organise des événements sur **plusieurs gymnases en même temps**. Chaque gymnase a **son
stock**. Il faut donc pouvoir, sur un même événement :
- associer plusieurs gymnases ;
- gérer le stock de chaque gymnase ;
- rattacher une caisse (donc un bénévole) à un gymnase quand il l'ouvre ;
- lire les ventes et les bilans de deux façons : **distincte** (un gymnase) ou **commune** (tous) ;
- laisser un bénévole changer de gymnase, mais seulement après avoir clôturé sa caisse précédente ;
- partager un code ou un **QR code** qui mène au bon gymnase ;
- rattacher un gestionnaire à un ou plusieurs gymnases.

Déjà livré avant ce chantier (03/10/2026) : une caisse ne s'ouvre que depuis un événement ;
l'état d'un événement est visible (pastille En cours / Clôturé).

## 2. Décisions figées (validées par Kinder le 03/10/2026)
- **G1** Un événement peut avoir plusieurs gymnases. Les gymnases sont propres à l'événement (on
  les nomme à la création ou plus tard) ; il y en a toujours au moins un.
- **G2** Tous les gymnases d'un événement utilisent **le même menu** (mêmes produits, mêmes prix).
  Seul le **stock** diffère, gymnase par gymnase. Le stock du menu sert de valeur de départ pour
  chaque gymnase, modifiable ensuite.
- **G3** Une caisse est rattachée à **un gymnase** à son ouverture. Il existe une caisse par couple
  (membre, gymnase). Un membre n'a **jamais deux caisses ouvertes** sur un même événement : pour
  changer de gymnase il clôture d'abord sa caisse, puis il en ouvre une autre (il peut revenir
  plus tard dans le premier gymnase : sa caisse se rouvre).
- **G4** Suivi en direct et bilan ont **deux vues** : *distincte* (un gymnase au choix) et
  *commune* (tous les gymnases additionnés). La somme des vues distinctes égale la vue commune.
- **G5** Le responsable **rattache** chaque gestionnaire à un ou plusieurs gymnases de l'événement
  (c'est de la gestion des gestionnaires : réservé au responsable). Un gestionnaire ne voit, ne
  corrige et ne réapprovisionne que **ses** gymnases. La vue *commune* n'est offerte qu'au
  responsable et au gestionnaire rattaché à **tous** les gymnases.
- **G6** Partage : le **code d'accès de l'association reste inchangé** (décision 1) ; en plus, un
  **QR code propre à un gymnase** (association + événement + gymnase). Le scanner fait rejoindre
  l'association si besoin (prénom demandé) puis ouvre l'événement avec le gymnase déjà choisi.
  Le responsable et les gestionnaires rattachés peuvent afficher le QR de leurs gymnases.

### À confirmer en une phrase au démarrage (ne pas supposer)
1. **Limite de modules** : le chantier ajoute 3 modules (19 → 22 sur 20 autorisés). Recommandé :
   relever la limite à 24. Sinon fusionner des fichiers existants (voir section 8).
2. **Dépendances** : `qr_flutter` (dessiner un QR code) et `mobile_scanner` (le lire avec la
   caméra). Kinder a dit « je valide le reste » : demander une confirmation explicite avant la
   mission 5.
3. **Données d'essai** : pas de reprise des événements créés avant le chantier (ancien format).
   Kinder supprime ses associations d'essai (l'écran Paramètres le permet) ; l'application ne doit
   pas planter si elle croise un ancien événement (message clair). Recommandé.
4. **Clôture de l'événement** : aujourd'hui tout gestionnaire identifié peut clôturer (décision
   18). Avec plusieurs gymnases, un gestionnaire rattaché à un seul pourrait clôturer pour tous.
   Garder tel quel (recommandé, plus simple) ou réserver la clôture au responsable ?

## 3. Vocabulaire
- **Gymnase** : un lieu de vente d'un événement, avec son stock (interne : `gymnase`).
- **Stock d'un gymnase** : quantité restante d'un produit dans ce gymnase.
- **Caisse** : celle d'un membre dans un gymnase. **Pointeur** (`ouvertes/{uid}`) : petit document
  qui dit quelle caisse est ouverte pour ce membre sur cet événement (sert à interdire deux
  caisses ouvertes).
- **Vue distincte / commune** : voir G4.

## 4. Modèle de données cible
```
associations/{a}/evenements/{e}                 (inchangé : nom, date, statut, modes, menuNom…)
  produits/{p}        nom, prixCentimes, icone?, photo?, creeLe          ⚠ plus de champ « stock »
  gymnases/{g}        nom, gestionnaires: [uid…] (≤ 20, posé par le responsable), creeLe
    stocks/{p}        quantite (entier, peut passer sous zéro : on avertit sans bloquer)
                      absent = pas de suivi de ce produit dans ce gymnase
  caisses/{uid__g}    membreUid, gymnaseId, prenom, statut, ouverteLe, rouverteLe?, récapitulatif…
    ventes/{v}        lignes, totalCentimes, mode, creeLe, gymnaseId (copie), corrigeDe?, annulation…
  ouvertes/{uid}      gymnaseId, caisseId  (existe tant que le membre a une caisse ouverte ici)
associations/{a}/menus/{m}/produits/{p}         stock = stock PAR DÉFAUT copié dans chaque gymnase
```
- Identifiant de caisse : `uid + "__" + gymnaseId` (les identifiants Firestore automatiques ne
  contiennent pas « _ » ; les règles lisent `c.split('__')`).
- Les produits de l'événement restent **immuables** (prix, images) ; seules les quantités de stock
  bougent, dans `stocks`.
- Événement créé avant le chantier = pas de sous-collection `gymnases` : afficher « Événement créé
  avant la mise à jour : recréez-le » (décision à confirmer, point 3 ci-dessus).

## 5. Règles d'accès cibles (à réécrire dans `firestore.rules`)
Fonctions à ajouter : `estResponsable(a)`, `estGestionnaireDe(a, e, g)` (responsable, ou rôle
gestionnaire ET uid présent dans `gymnases/{g}.gestionnaires`), `gymnaseDe(c)` = `c.split('__')[1]`,
`proprietaire(c)` = `c.split('__')[0] == request.auth.uid`.
- **gymnases** : lecture par tout membre (le bénévole choisit son gymnase) ; création et
  renommage par la gestion ; champ `gestionnaires` modifiable par le responsable seul ; jamais
  supprimé (sauf suppression de l'association).
- **stocks** : lecture par tout membre ; création par la gestion à la création de l'événement ;
  modification (a) par le responsable ou le gestionnaire rattaché (réapprovisionnement), (b) par un
  membre dont le pointeur désigne ce gymnase (une vente fait baisser le stock) ; bornes
  −100 000…100 000.
- **caisses** : id imposé `uid__g` avec un gymnase existant ; création/réouverture exigent qu'il
  n'existe pas de pointeur et en créent un dans le même lot (`getAfter` / `existsAfter`) ; clôture
  = caisse clôturée ET pointeur supprimé dans le même lot ; lecture : propriétaire ou
  `estGestionnaireDe(g)`.
- **ventes** : création par le propriétaire d'une caisse ouverte, `gymnaseId` = celui de la caisse ;
  lecture propriétaire ou gestionnaire du gymnase ; annulation propriétaire (caisse ouverte) ou
  gestionnaire du gymnase ; jamais supprimée (sauf suppression de l'association).
- **ouvertes** : lecture par son propriétaire ; création/suppression uniquement dans les lots
  d'ouverture/clôture.
- **Suppression de l'association** (`suppressionEnCours`) : étendre aux gymnases, stocks, ouvertes.
- ⚠ **Requêtes en liste** (suivi en direct d'un gestionnaire) : une règle ne filtre pas, la requête
  doit déjà être limitée. Prévoir une requête par gymnase rattaché
  (`where('gymnaseId', isEqualTo: g)`) et une règle qui s'appuie sur `resource.data.gymnaseId`.
  **À valider par un test de règles avant de construire l'écran** (mission 3, « tir d'essai »).
- ⚠ **Limite d'accès par lot** des règles (20 documents lus par lot, exists/get/getAfter) : garder
  les lots courts, et vérifier sur le VRAI projet (pas seulement l'émulateur) avec une association
  d'essai.

## 6. Parcours cible
- **Responsable** : crée l'événement → choisit le menu → nomme ses gymnases (au moins un) → règle
  les stocks → rattache les gestionnaires → partage code/QR → suit en direct (commun ou par
  gymnase) → clôture → bilan (commun ou distinct).
- **Gestionnaire rattaché** : voit ses gymnases : suivi, annulation de ventes, réapprovisionnement,
  QR à partager, bilan distinct (et commun s'il est rattaché à tous).
- **Bénévole** : scanne le QR (ou entre le code) → ouvre sa caisse dans le gymnase → vend → clôture.
  Pour changer de gymnase : « Clôturer ma caisse à X », puis « Ouvrir ma caisse » dans Y.

## 7. Règles de conduite pour l'exécution (toutes missions)
- Méthode Kinder : **une mission à la fois**, cadrage (phase 5) confirmé AVANT de coder, **UNE
  question à la fois**, français fonctionnel, réponses courtes. Kinder ne lit pas le code : il
  valide par ce que Claude lui rapporte ; **Claude teste tout** (voir ci-dessous).
- Après chaque mission : `flutter analyze`, `flutter test`, tests de règles, parcours Android
  complets, déploiement des règles, application de recette refaite, CHANGELOG + ce plan (section
  9) + mémoire. Ne jamais passer à la mission suivante tant que tout n'est pas vert.
- Commandes et pièges : voir la mémoire `le-comptoir-etat-et-reperes` (émulateur `LC2` en rendu
  logiciel, `--timeout`, scripts écrits via l'outil Write, deux fichiers de test ne partagent pas
  une adresse e-mail, scénario hors réseau dans un fichier à part, attendre la fin des animations).
- **Tests d'abord pour les règles** : écrire/adapter les tests de règles (`tests_regles/`) AVANT le
  code. Les fixtures partagées sont `tests_regles/outils.mjs` et `outilsCaisse.mjs`.
- **Déploiement des règles** : seulement quand les tests passent. Les règles déployées sont
  appliquées au vrai projet : prévenir Kinder qu'avant la mise à jour de l'application, ses
  associations d'essai doivent être supprimées (décision 3 ci-dessus).
- Respecter les limites de Kinder (modules, 5 fichiers .md max — il y en a 4 avec ce plan —,
  aucune dépendance sans accord, 3 couches UI / Logique / Données, rien de vide « pour plus tard »).

## 8. Missions

### Vue d'ensemble
| # | Mission | Visible par Kinder ? | Taille |
|---|---|---|---|
| M1 | Socle : gymnases, stock par gymnase, caisse par (membre, gymnase) | Non (comportement identique, un seul gymnase) | grosse |
| M2 | Gymnases d'un événement + choix à l'ouverture + changement de gymnase | Oui | moyenne |
| M3 | Gestionnaires rattachés aux gymnases (droits limités) | Oui | grosse |
| M4 | Suivi et bilan : vue distincte / commune | Oui | moyenne |
| M5 | QR code et partage (+ scan) | Oui | moyenne |
| M6 | Recette multi-gymnases et finitions | Oui | petite |

Chaque mission laisse l'application **complète et testée** ; on ne livre jamais un état intermédiaire
cassé. Modules : l'état actuel est de 19 ; ajouts prévus : `gymnase.dart` (modèles et logique pure :
identifiant de caisse, charge utile du QR…), `ecran_gymnases.dart` (gymnases, stocks, rattachements),
`ecran_qr.dart` (affichage et scan). Si la limite reste à 20, fusionner par exemple
`firebase_options.dart` dans `main.dart` et `code_association.dart` dans `connexion.dart` avant la M2,
et regrouper les écrans de QR dans `ecran_gymnases.dart`.

---
### M1 — Socle de données (invisible)
**Objectif** : nouveau modèle (section 4) et nouvelles règles (section 5) ; l'application se
comporte comme aujourd'hui avec **un seul gymnase créé automatiquement** (nom « Principal »).

**Périmètre**
- `DepotEvenements.creerEvenement` : crée l'événement, les produits SANS stock, un gymnase
  « Principal » et ses documents `stocks` (copie du stock du menu). Lot court (≤ 400 écritures).
- `DepotCaisses` : identifiant de caisse `uid__g`, champs `membreUid`/`gymnaseId`, ouverture et
  réouverture par lot (caisse + pointeur `ouvertes/{uid}`), clôture par lot (caisse + suppression du
  pointeur) — la clôture exige toujours le réseau (transaction) ; la réouverture et l'ouverture
  restent possibles hors réseau. Ventes : champ `gymnaseId`. Stock : `increment` sur
  `gymnases/{g}/stocks/{p}`.
- `ProduitEvenement` perd `stock` ; l'écran de caisse, le suivi et le bilan lisent le stock du gymnase
  de la caisse (flux `suivreStocks(gymnaseId)`).
- `supprimerAssociation` : effacer aussi gymnases, stocks, ouvertes (nouvelles règles
  `suppressionEnCours`).
- Événement à l'ancien format : message clair, pas de plantage.
- Règles : section 5, SANS le rattachement des gestionnaires (la gestion garde ses droits actuels ;
  `gestionnaires` existe mais n'est pas encore utilisé).

**Tests à écrire / migrer**
- Règles : id de caisse imposé ; gymnase inexistant refusé ; pointeur (ouvrir ; refuser une 2e
  ouverture ; clôture libère ; réouverture exige pointeur libre) ; stock modifiable seulement par un
  membre dont le pointeur désigne le gymnase ; `gymnaseId` de la vente = celui de la caisse ;
  suppression de l'association efface tout ; lots de 15 suppressions OK.
- **Migrer tous les tests existants** (très nombreux : `caisses`, `annulations`, `clotures`, `suivi`,
  `images`, `suppression` côté règles ; `caisse`, `annulations`, `clotures`, `cloture_hors_reseau`,
  `suivi`, `bilan`, `images`, `recette`, `parametres`, `evenements` côté Android ; tests unitaires de
  `Bilan`, `ResumeCaisse`, `Produit`…). Commencer par les fixtures partagées.
- Unitaires : fabrique/lecture de l'identifiant de caisse ; refus d'un identifiant mal formé.

**Critères d'acceptation** : toute la batterie existante est verte (adaptée) ; aucun changement de
comportement visible ; règles déployées ; essai sur le vrai projet (association d'essai créée,
événement, ouverture, vente, clôture, suppression) pour confirmer les limites de lot en production.

**Risques** : budget d'accès des règles par lot ; ordre des écritures hors réseau (caisse avant
pointeur avant vente) ; volume de migration des tests.

---
### M2 — Gymnases d'un événement, choix à l'ouverture
**Objectif** : G1, G2, G3 visibles.

**Périmètre**
- Création/édition d'un événement : liste de gymnases (au moins un, noms distincts, 1 à 40
  caractères). Ajout et renommage ; **pas de suppression** (les règles l'interdisent).
- `ecran_gymnases.dart` : par gymnase, tableau des stocks par produit (modifier une quantité,
  « Réapprovisionner +n », activer/désactiver le suivi d'un produit).
- Ouverture de caisse : un seul gymnase → direct ; plusieurs → liste de choix. L'écran de l'événement
  affiche « Ma caisse : Gymnase A (ouverte) ». Si une caisse est ouverte ailleurs : message
  « Clôturez d'abord votre caisse à A » avec le raccourci vers sa clôture, puis ouverture dans B.
  Retour dans un gymnase déjà utilisé : « Reprendre/Rouvrir ma caisse ».
- La caisse affiche le nom de son gymnase dans le titre et lit le stock de ce gymnase.

**Tests** : règles (création/renommage des gymnases par la gestion seulement ; bénévole refusé ;
suppression refusée) ; unitaires (validation des noms, unicité) ; Android : événement à 2 gymnases
avec stocks différents, deux bénévoles dans deux gymnases, un bénévole qui change de gymnase
(refus tant que la caisse est ouverte, succès après clôture), stock décrémenté dans le bon gymnase
seulement, retour dans le premier gymnase.

**Critères** : un bénévole ne peut jamais avoir deux caisses ouvertes (règle serveur + écran) ; les
stocks des gymnases sont indépendants ; tout est vert.

**Risques** : parcours « changer de gymnase » hors réseau (clôture exige le réseau : message clair).

---
### M3 — Gestionnaires rattachés aux gymnases
**Objectif** : G5.

**Périmètre**
- Écran de rattachement (responsable) : par gymnase, cocher les gestionnaires **actifs** (pas les
  « en attente »). Champ `gestionnaires` (uids).
- Règles de portée : lecture des caisses/ventes/stock modifiable, annulation, QR, réapprovisionnement
  limités aux gymnases du gestionnaire ; un gestionnaire non rattaché voit l'événement et ses
  gymnases (noms) mais aucune vente. Le responsable voit tout.
- Suivi en direct : pour un gestionnaire, un flux par gymnase rattaché
  (`suivreTableauDeBord(gymnaseIds)`), fusionné ; le responsable garde la requête globale.
- **Tir d'essai en premier** : prouver par un test de règles (requêtes REST `runQuery` avec
  `where gymnaseId == g`) que la lecture en liste fonctionne avec `resource.data.gymnaseId` ; sinon
  se rabattre sur une lecture par gymnase via un chemin (ex. un document « gymnase » listant les
  caisses) et adapter le modèle AVANT de construire l'écran.
- Retrait d'un gestionnaire (statut redevient bénévole) : son rattachement ne donne plus aucun droit.

**Tests** : matrice complète de droits (responsable / gestionnaire rattaché / gestionnaire d'un autre
gymnase / gestionnaire en attente / bénévole / intrus) × (lire caisses, lire ventes, annuler, régler le
stock, voir le QR) ; Android : deux gestionnaires, un par gymnase, chacun ne voit que le sien.

**Critères** : aucune fuite de données entre gymnases ; tout est vert.

**Risques** : requêtes en liste et règles (voir tir d'essai) ; complexité des fonctions de règles.

---
### M4 — Suivi et bilan : vue distincte / commune
**Objectif** : G4.

**Périmètre**
- Sélecteur « Commun | Gymnase A | Gymnase B… » (un segment par gymnase visible) dans le **suivi en
  direct** et dans le **bilan**. Commun = somme de tous ; distinct = un gymnase.
- `Bilan.depuis` : paramètre `gymnaseId` (null = commun). Stock affiché : en distinct, celui du gymnase ;
  en commun, le total avec le détail par gymnase. Par caisse : le gymnase est indiqué.
- Gestionnaire : seules ses vues distinctes ; « Commun » seulement s'il est rattaché à tous les gymnases
  (message « vue limitée à vos gymnases » sinon).
- Clôture forcée et annulations : visibles dans les deux vues, comme aujourd'hui.

**Tests** : refaire le **jeu de ventes calculé à la main** (méthode des étapes 12) sur 2 gymnases avec
deux stocks différents : bilan A, bilan B et bilan commun écrits à la main (totaux, par produit, par
mode, par caisse, par jour, heures de pointe, stock). Vérifier : A + B = Commun pour les ventes ;
mêmes chiffres dans le calcul pur, l'écran, et sur Android avec de vraies données datées.

**Critères** : concordance parfaite avec le calcul à la main ; tout est vert.

---
### M5 — QR code et partage
**Objectif** : G6.

**Périmètre** (après confirmation des deux dépendances)
- Charge utile : `lecomptoir://rejoindre?v=1&c=<codeAssociation>&e=<idÉvénement>&g=<idGymnase>`
  (fonctions pures d'encodage/décodage dans `gymnase.dart`, avec refus des charges invalides).
- Affichage : écran gymnase (`ecran_gymnases.dart` ou `ecran_qr.dart`) → bouton « Partager » : QR
  (`qr_flutter`), le code en texte et « Copier le code ». Réservé au responsable et aux
  gestionnaires rattachés. Changer le code de l'association rend les anciens QR invalides (message).
- Scan : bouton « Scanner un QR code » sur l'écran d'accueil (`mobile_scanner`, permission caméra
  dans le manifeste Android). Flux : lecture → si non membre : prénom puis rejoint → ouvre l'événement
  avec le gymnase présélectionné et propose « Ouvrir ma caisse à X » ; si déjà membre : direct. Erreurs
  claires : QR illisible, code périmé, événement clôturé, gymnase inconnu, appartenance à une autre
  association.
- Le lecteur de QR est **injectable** (comme le sélecteur de photo) pour les tests.

**Tests** : unitaires (aller-retour de la charge utile, charges invalides, caractères spéciaux) ;
écran (le QR contient bien la charge attendue ; accès refusé à un bénévole) ; Android avec un faux
lecteur (non membre → membre → bonne caisse ; code périmé ; événement clôturé). Le vrai scan à la
caméra est à la recette de Kinder.

**Critères** : un scan mène au bon gymnase en un geste ; tout est vert.

**Risques** : permission caméra et version minimale d'Android ; lecture en plein jour (à la recette).

---
### M6 — Recette multi-gymnases et finitions
- `recette_test.dart` : scénario avec **2 gymnases**, 2 bénévoles (un change de gymnase), un
  gestionnaire par gymnase, bilan distinct et commun contrôlés chiffre par chiffre.
- Mise à jour de `RECETTE.md` (parcours gymnases et QR), application de recette refaite et signature
  vérifiée, CHANGELOG, `PROJET_CONTEXTE.md`, ce plan, mémoire.
- Revue : modules, fichiers .md, structures vides, dépendances ; rappel à Kinder de supprimer ses
  associations d'essai de l'ancien format.

## 9. Suivi d'avancement (à mettre à jour à la fin de chaque mission)
| Mission | État | Date | Résultat |
|---|---|---|---|
| Plan et cadrage (ce document) | Fait | 03/10/2026 | Décisions G1 à G6 validées |
| Confirmations de démarrage (4 points de la section 2) | Fait | 03/10/2026 | 1: limite 24 modules ; 2: qr_flutter + mobile_scanner accordés (M5) ; 3: pas de reprise des anciens événements ; 4: clôture inchangée |
| M1 Socle de données | Fait (essai sur le vrai projet reporté à la recette de Kinder, accord du 03/10/2026) | 03/10/2026 | Code, règles (déployées), 98 tests logique/écrans, 114 tests de règles, 15 parcours Android, recette refaite. Défaut corrigé : suppression d'association. Essai réel : à faire à la recette (connexion Google) |
| M2 Gymnases et ouverture de caisse | Fait | 03/10/2026 | Formulaire + écran « Gymnases et stocks », bouton de caisse par gymnase, blocage « clôturez d'abord ». 103 tests logique/écrans, 116 tests de règles, 16 parcours Android, règles déployées, recette refaite. 21 modules/24. Choix : un gymnase ajouté plus tard suit les mêmes produits à zéro ; la liste des gymnases se gère depuis l'écran dédié (pas dans le formulaire de modification) |
| M3 Gestionnaires rattachés | Fait | 03/10/2026 | Rattachements, droits limités, suivi/bilan limités, clôture réservée au responsable ou au gestionnaire rattaché à tous. 108 tests logique/écrans, 130 tests de règles, 17 parcours Android, règles déployées, recette refaite. Modèle : `rattachements/{uid}` + compteur `nbGymnases` (8 max) au lieu d'une liste sur le gymnase |
| M4 Vue distincte / commune | Fait | 04/10/2026 | Sélecteur Commun/gymnases dans suivi et bilan, calcul à la main A/B/commun concordant, 128 tests logique/écrans, 130 tests de règles, 18 parcours Android, recette refaite. Point relevé : parcours des gestionnaires intermittent en batterie complète ; cause trouvée en M5 (tests : vente avant caisse), corrigée |
| M5 QR code et partage | Fait | 04/10/2026 | QR par gymnase, scan (accueil + association), 6 messages d'erreur, lecteur injectable, 137 tests logique/écrans, 130 tests de règles, 19 parcours Android, recette refaite (66 Mo). Vrai scan caméra à la recette. Cause de l'échec intermittent des gestionnaires : tests (vente avant caisse) |
| M6 Recette multi-gymnases | Fait | 04/10/2026 | Parcours de recette à 2 gymnases (bilans A, B, commun écrits à la main, A + B = commun), RECETTE.md mise à jour, revue des limites (22 modules, 4 .md, dépendances accordées), 137 tests logique/écrans, 130 tests de règles, 19 parcours Android verts, recette refaite. CHANTIER TERMINÉ : reste la recette de Kinder |

## 10. Chantier terminé (04/10/2026)
Les missions M1 à M6 sont faites et testées. Prochaine étape : le test unique de Kinder avec
`RECETTE.md` (APK : `recette/le-comptoir-recette.apk`), après suppression de ses associations d'essai
de l'ancien format. Rien n'est à reprendre dans ce plan ; les corrections issues de la recette se
noteront dans `CHANGELOG.md`.
