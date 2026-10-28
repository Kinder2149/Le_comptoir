# PLAN — Stock et courses (chantier figé le 27/10/2026)

> Document de pilotage du chantier. À lire avec `PROJET_CONTEXTE.md` (décisions figées 33 à 42) et
> `CHANGELOG.md`. Il se met à jour à la fin de CHAQUE étape (section 8). Rédigé pour être exécuté dans
> une nouvelle conversation, étape par étape : une étape à la fois, avec le critère de validation
> écrit par Kinder AVANT tout code.

## 1. Pourquoi (en clair)
Une IA de l'association a rédigé un cahier des charges de gestion (stocks, courses, recettes, marges,
paiements). L'application était une caisse avec un stock simple par gymnase. Kinder garde sa base et
l'affine sur le stock et les courses : la gestion tient le stock et prépare les courses ; le bénévole
garde sa caisse classique. Le modèle de menu devient générique : chaque association part du modèle,
le modifie, le copie ou crée le sien.

## 2. Décisions de référence
Les décisions 33 à 42 de `PROJET_CONTEXTE.md` font foi (droits par rôle, rupture sans blocage, quatre
types de produit, modèle générique, module Courses et calcul inverse, stock bas à 10 % du dernier
total, éléments écartés, export CSV, plafond de modules supprimé, pré-remplissage des quantités).
Ne pas les recopier ici : les relire avant chaque étape.

## 3. Vocabulaire
- **Produit final** : ce qu'on vend (croque-monsieur, café, barre). Seul lui a un stock.
- **Ingrédient** : un élément d'une recette (pain de mie, jambon, gruyère). Pas de stock : un nom, une quantité, une unité.
- **Type** : composé (recette) | unité | part | litre (ratio litres -> verres vendus).
- **Consommation** : quantité d'un produit par personne et par jour (sert au seul pré-remplissage).
- **Total de référence** : dernier total de stock enregistré ; le seuil « stock bas » est 10 % de ce total.
- **Courses** : une liste d'achats d'un événement (en préparation, puis validée).

## 4. Modèle de données cible (ajouts seulement ; le reste est inchangé)
```
associations/{a}/menus/{m}/produits/{p}
  + type            'compose' | 'unite' | 'part' | 'litre'   (absent = 'unite' : les produits existants ne changent pas)
  + conso           nombre >= 0   consommation par personne et par jour (facultatif)
  + ingredients[]   {nom, quantite, unite}  (type composé, 20 au plus ; quantité fractionnaire permise)
  + verresParLitre  nombre > 0              (type litre)
associations/{a}/evenements/{e}
  + nbJours         entier 1 à 30 (2 par défaut)
  produits/{p}      copie des champs ci-dessus (décision 13 : figés ; seule l'image se modifie ensuite)
  gymnases/{g}
    + personnes     entier 0 à 1000 (réglage de l'événement)
    stocks/{p}
      quantite      (inchangé)
      + reference   total de référence (entier) : posé à chaque réglage de la gestion, ajout de parts,
                    validation de courses ; l'alerte est : reference > 0 et quantite <= 10 % de reference
  courses/{c}       statut ('preparation' | 'validee'), creeLe, creePar, lignes[] {gymnaseId, produitId, quantite},
                    restes[] {nom, unite, quantite}, achats[] {nom, unite, quantite}, coutCentimes, valideeLe
```
Les noms et unités des champs sont des propositions : à confirmer au cadrage de chaque étape.

## 5. Les étapes
Pour chaque étape : ce que Kinder voit, stratégie, fichiers, ce qu'on ne fait pas, points à trancher AU
CADRAGE de l'étape (rien n'est supposé), critère de validation (écrit par Kinder en français, avant le code).

### Étape 1 — Types de produit et recettes dans le menu (grosse)
- **Kinder voit** : dans le formulaire « Produit » d'un menu, un choix de type ; selon le type : la liste
  des ingrédients et leurs quantités pour UNE unité (composé), le ratio litres/verres (litre) ; une
  consommation par personne et par jour. Ces informations sont recopiées dans l'événement créé ensuite.
- **Stratégie** : formulaire existant modifié (champs affichés selon le type), pas de nouvel écran ; copie à
  la création de l'événement (comme l'image et le prix) ; produits existants sans type = « unité ».
- **Fichiers** : `lib/ecran_menu.dart`, `lib/depot_menus.dart`, `lib/depot_evenements.dart`, `lib/evenement.dart`,
  `firestore.rules` (champs et limites de taille), tests de logique, d'écrans et de règles.
- **On ne fait pas** : liste de courses, couleurs en caisse, stock, modèle générique, réglages de l'événement.
- **À trancher** : liste des unités (unité, tranche, g, kg, cl, L ?) et conversions g/kg ; un ingrédient
  partagé entre deux recettes se reconnaît-il par son nom (casse, accents) ? ; le stock des produits
  « litre » se compte-t-il en verres ? (proposé : oui) ; formulaire trop chargé : champs selon le type.
- **Tranché le 28/10/2026 (Kinder)** : unités = unité, tranche, g, kg, cl, L, saisies telles quelles, sans conversion à l'étape 1 (g/kg et cl/L se convertiront aux étapes 5-6) ; un ingrédient partagé se reconnaît par son nom sans casse ni accents ni espaces autour (`cleIngredient`), utilisé aux courses ; le stock d'un produit au litre se compte en verres. Fraction acceptée à la saisie (« 1/4 »). Règles d'accès : une requête ne peut évaluer plus de 1000 expressions, donc la recette (20 ingrédients) y est contrôlée de façon compacte (quantité > 0, nom de 1 à 40 caractères, unité de la liste fixe) ; la vérification complète (quantité max, nombre de champs) est faite par l'application.
- **Critère de validation (délégué par Kinder à Claude le 27/10/2026, validé en le déléguant)** :
  1. Dans un menu, je crée « Croque-monsieur » de type composé avec 3 ingrédients (2 tranches de pain de mie,
     1/4 de tranche de jambon, 25 g de gruyère) ; en rouvrant le menu, je retrouve exactement ces valeurs.
  2. Je crée « Café » de type litre avec 8 verres par litre, et je règle sa consommation à 2 par personne et par jour ;
     je retrouve ces valeurs en rouvrant le produit.
  3. Un produit déjà existant (ex. « Fruit ») reste un produit à l'unité : prix, stock et image sont intacts.
  4. Je crée un événement avec ce menu : le croque-monsieur et le café y sont avec leur recette, leur ratio et leur
     consommation. Si je change ensuite la recette dans le menu, l'événement déjà créé ne change pas.
  5. Les saisies incohérentes sont refusées avec un message clair : produit composé sans ingrédient, quantité à zéro
     ou négative, ratio à zéro, plus de 20 ingrédients.
  6. La caisse, le stock et le bilan fonctionnent comme avant (tous les tests existants restent verts).
  Le test de code ferme l'étape ; la capture d'écran de Kinder (formulaire produit, puis événement) ferme la mission.

### Étape 2 — Modèle générique et logos (moyenne)
- **Kinder voit** : à la création d'un menu, « partir du modèle », « copier un menu » ou « de zéro ». Le
  modèle contient la carte de Kinder (10 produits) avec types, recettes et consommations d'exemple, et
  les logos fournis à la place des icônes pour ces produits.
- **Stratégie** : `assets/menu_type.json` étendu (type, ingrédients, consommation) ; action « copier un menu »
  ; logos : les clés d'icônes existantes (croque, salade, fruit, the, cafe, barre, soda, gateau_sucre,
  gateau_sale, crepe) affichent l'image au lieu de l'icône du système, donc aucune règle d'accès à changer
  (même liste de clés) ; les 4 autres icônes (bière, eau, frites, glace) restent.
- **Sources des logos** : `audit_front/logos_menu_modele/` (10 images réduites à 512 px, fond transparent).
  Fournies par Kinder le 27/10/2026. Correspondance proposée : 01 café, 02 thé, 03 tarte confiture =
  À CONFIRMER (second gâteau sucré ? il n'y a alors aucun logo pour le gâteau salé), 04 flan = gâteau sucré (confirmé par Kinder le 27/10/2026), 05 croque, 06 Mars = barre, 07 fruits, 08 salade,
  09 soda (icône plate, style différent des photos), 10 crêpes.
- **Valeurs d'exemple du modèle** (estimations de Claude, à corriger par Kinder, décision 42) : croque = 2 tranches
  de pain de mie + 1/4 de tranche de jambon + 25 g de gruyère ; café = 1 litre pour 8 verres ; consommation
  par personne et par jour : 2 croques, 1 boisson, 1 part de gâteau, 1 fruit ou barre, 2 cafés. Les prix de la
  carte et l'estimation des courses de Kinder sont à recevoir (non reçus au 27/10/2026).
- **Fichiers** : `assets/menu_type.json`, `pubspec.yaml` (déclarer les images, aucune dépendance), `lib/ecran_caisse.dart`
  (affichage des icônes), `lib/ecran_menus.dart`, `lib/depot_menus.dart`, tests.
- **On ne fait pas** : réglages de l'événement, courses.
- **À trancher** : correspondance des logos : la tarte confiture (03) est-elle un second gâteau sucré, et quel logo pour le gâteau salé ? (10 images, 9 produits distincts) ; soda (09) au style différent ; où se range le modèle (livré avec l'application,
  jamais modifiable lui-même : on le copie) ; le menu type actuel est-il remplacé ?
- **Critère (Kinder)** : à écrire.

### Étape 3 — Stock par rôle (moyenne)
- **Kinder voit** : la gestion règle le stock de ses gymnases ; un bénévole ajoute des parts (gâteau sucré,
  gâteau salé, salade) au stock de son gymnase sans voir ni modifier le reste du stock ; chaque réglage
  enregistre le nouveau total de référence.
- **Stratégie** : écran « Gymnases et stocks » existant adapté ; petit écran/bouton d'ajout de parts dans la
  caisse du bénévole ; champ `reference` écrit avec la quantité.
- **Fichiers** : `lib/ecran_gymnases.dart`, `lib/ecran_caisse.dart`, `lib/depot_evenements.dart`, `lib/depot_caisses.dart`,
  `firestore.rules`, tests (règles : tests_regles/).
- **On ne fait pas** : alerte et couleurs (étape 4), courses, transferts entre gymnases.
- **Confirmé par Kinder (27/10/2026)** : un bénévole ajoute des parts, rien d'autre.
- **Point d'attention technique** : les règles autorisent aujourd'hui un membre dont la caisse est ouverte dans le gymnase
  à modifier la quantité (c'est ce qui permet la vente, qui baisse, et l'annulation, qui remonte). L'ajout de parts
  par un bénévole doit être limité aux produits de type « part » et distingué de l'annulation d'une vente.
- **À trancher** : l'ajout de parts du bénévole change-t-il le total de référence ? ; saisie d'une quantité
  ajoutée ou du nouveau total ? ; un événement clôturé ne bouge plus.
- **Critère (Kinder)** : à écrire.

### Étape 4 — Caisse : rupture et stock bas (moyenne)
- **Kinder voit** : en rupture, le produit change de couleur en caisse (la vente reste possible, message « Épuisé »
  conservé) ; un produit sous 10 % du dernier total est signalé (caisse et suivi en direct pour la gestion).
- **Stratégie** : la vente et la baisse de stock sont écrites dans UN MÊME lot (aujourd'hui deux écritures séparées) ;
  couleur et signal pilotés par `quantite` et `reference`.
- **Fichiers** : `lib/ecran_caisse.dart`, `lib/depot_caisses.dart`, `lib/theme.dart`, `lib/ecran_evenement.dart` (signal en suivi), tests.
- **On ne fait pas** : suggestion aux courses (étape 5), état « stock inconnu » gris (voir registre).
- **À trancher** : couleur et libellé du « stock bas » en caisse (la rupture est décidée) ; le bénévole voit-il le « stock bas » ?
  (il voit déjà « Épuisé ») ; double appui sur le bouton d'encaissement.
- **Critère (Kinder)** : à écrire.

### Étape 5 — Courses : préparation (grosse)
- **Kinder voit** : à la création de l'événement ou plus tard, des réglages (personnes par gymnase, jours) ; un écran
  Courses : les produits du menu avec la quantité de produits finaux pré-remplie (personnes × jours × consommation),
  modifiable ; les produits en stock bas suggérés ; pour un produit composé, la liste d'ingrédients calculée
  (somme des ingrédients partagés) ; un champ facultatif « ce qu'il reste ».
- **Stratégie** : module à part (Courses) ; calcul de la liste en logique pure, testée ; la liste se sauvegarde (statut préparation).
- **Fichiers** : nouveau module Courses (écran + dépôt), `lib/ecran_nouvel_evenement.dart`, `lib/ecran_evenement.dart`, `lib/evenement.dart`, `firestore.rules`, tests.
- **On ne fait pas** : validation des achats (étape 6), prix par élément, impression de la liste.
- **Tranché (Kinder, 27/10/2026)** : une liste de courses pour TOUT l'événement ; quantités saisies par gymnase,
  pré-remplies depuis les personnes de ce gymnase ; la validation ajoute à chaque gymnase.
- **À trancher** : qui lance les courses (gestion de tous les gymnases ?) ;
  arrondis (pain en paquets ?) ; ajouter une ligne à la main après calcul ; plusieurs listes dans un même événement.
- **Critère (Kinder)** : à écrire.

### Étape 6 — Courses : validation (moyenne)
- **Kinder voit** : « Valider » ouvre la saisie des quantités réellement achetées ; l'application affiche ce que cela
  donne en produits finaux (ingrédient limitant) et ajoute au stock ; saisie du coût total des courses.
- **Stratégie** : calcul inverse en logique pure ; mise à jour du stock et du total de référence dans un même lot ;
  une liste validée ne se rejoue pas (pas de double ajout au stock).
- **Fichiers** : module Courses, `lib/depot_evenements.dart`, `firestore.rules`, tests.
- **On ne fait pas** : lots, prix par élément, coût moyen, marge.
- **À trancher** : achat partiel (valider ce qui est acheté, relancer une liste pour le reste ?) ; répartition entre gymnases
  de ce qui est acheté ; peut-on corriger une validation ? ; produits simples (unité, part) : on saisit directement le nombre.
- **Critère (Kinder)** : à écrire.

### Étape 7 — Bilan et export CSV (petite)
- **Kinder voit** : le coût total des courses déduit au bilan ; un bouton d'export du bilan en CSV (s'ouvre dans Excel).
- **Stratégie** : bilan existant complété (mêmes clés, mêmes tests) ; CSV généré sans paquet (séparateur « ; », encodage
  lisible par Excel) ; remise du fichier sur Android : dépendance éventuelle À DEMANDER à Kinder (décision 40).
- **Fichiers** : `lib/ecran_bilan.dart`, module Courses (coût), tests.
- **À trancher** : vue distincte (un gymnase) : comment afficher un coût d'événement entier ? ; contenu exact du CSV.
- **Critère (Kinder)** : à écrire.

### Étape 8 — Recette (moyenne)
- Parcours automatique complet (menu avec recettes -> événement -> courses -> validation -> ventes -> stock bas -> bilan
  -> export), vérifié chiffre par chiffre ; mesure des lectures du suivi en direct (quota gratuit 50 000/jour, vérifier
  avant de passer à 8 gymnases) ; mise à jour de `RECETTE.md` ; recette sur téléphones par Kinder ; APK reconstruit.

## 6. Registre du cahier des charges (rien ne se perd)
| Demande du PDF | Sort |
|---|---|
| Vente bloquée en rupture | **Écarté** (décision 35 : couleur, jamais de blocage) |
| États colorés : disponible vert, bas orange, rupture rouge, inconnu gris | **Retenu en partie** : rupture colorée (étape 4), stock bas signalé (4). « Inconnu gris » (produit sans suivi) à décider à l'étape 4 |
| Tableau de bord des stocks par gymnase/événement, filtres catégorie | **Reporté** : le suivi en direct montre déjà le stock restant ; filtres à rediscuter après l'étape 4 |
| Entrées, pertes/consommations internes, corrections | **Retenu en partie** : entrées et réglages (étape 3, courses 6) ; pertes et consommations internes **reportées** |
| Inventaire de fin de journée (saisie directe, sans écart affiché) | **Couvert** par le réglage du stock par la gestion (étape 3) ; pas d'écran dédié |
| Réapprovisionnements partiels pendant la journée | **À trancher** à l'étape 6 |
| Unités et conversions (tranches, grammes) | **Retenu** (étape 1) |
| Transferts entre gymnases | **Écarté** (à la main : -10 puis +10) |
| Lots à prix différents, coût moyen pondéré | **Écarté** (coût total des courses seulement) |
| Prévisions personnes × jours × coefficients, coefficients visibles et modifiables | **Retenu** en pré-remplissage modifiable (décision 42, étape 5) ; pas de stock cible |
| Déduire stocks et réceptions pour éviter les doubles commandes | **Retenu** : la liste part des quantités saisies et de « ce qu'il reste » ; pas de déduction automatique des courses déjà validées (à trancher étape 5) |
| Liste de courses : cases à cocher, statuts (à acheter, partiel, reçu, annulé), ajout manuel | **Retenu en partie** : préparation puis validation (étapes 5 et 6) ; statuts détaillés et cases à cocher **à trancher** |
| Impression ou export de la liste de courses | **Reporté** |
| Recettes, décrémentation des ingrédients à la vente, portions réalisables | **Retenu en partie** : recettes (étape 1) ; les ingrédients n'ont pas de stock (décision 38), donc pas de décrémentation ; « portions réalisables » = calcul inverse à la validation |
| Prix de vente, coût matière, marge et taux de marge | **Écarté** (coût total des courses déduit au bilan) |
| Cartes physiques prépayées | **Écarté** pour l'instant |
| Paiement carte envoyé au terminal | **Reporté en dernier** : Monetico (section 7 du contexte) |
| Gâteaux et préparations bénévoles (sucré/salé, parts, prix) | **Retenu** : types « part » (étapes 1 et 3) |
| Bilan par produit, catégorie, moyen de paiement, gymnase, événement | **Déjà fait** ; catégorie de produit **non décidée** |
| Export CSV/Excel du bilan | **Retenu** : CSV (étape 7) |
| Cohérence multi-appareils, droits, coupures réseau, sauvegardes | **Déjà fait** ; lectures en direct à mesurer (étape 8) ; sauvegardes **non traitées** |

## 7. Risques et points d'attention
- Les règles d'accès Firestore sont la partie la plus délicate : chaque étape qui touche aux règles ajoute ses tests
  (`tests_regles/`) avant tout déploiement (`firebase deploy --only firestore:rules`).
- Stock et ventes : toujours écritures relatives et un seul lot ; l'annulation d'une vente remonte le stock (ne pas
  la confondre avec un ajout de parts, étape 3).
- Limites de taille des champs (nom d'ingrédient, nombre d'ingrédients, quantités) à poser dans les règles comme pour les images.
- Quota gratuit : écritures tenables (environ 11 000/jour pour 3 gymnases et 6 caisses), lectures du suivi en direct à mesurer.
- Formulaire produit à ne pas surcharger ; zéro dépendance sans accord de Kinder (CSV : remise du fichier à voir).
- Les fichiers `lib/*.dart` sont en CRLF ; les pièges de test sont listés dans la section 12 du contexte.

## 8. Suivi (à mettre à jour à la fin de chaque étape)
| Étape | État | Date | Critère validé |
|---|---|---|---|
| 1 Types et recettes | **implémentée, testée par Claude (28/10/2026)** ; reste la capture de Kinder | 27-28/10/2026 | critères 1 à 6 réussis par les tests de code (analyse sans erreur, 161 tests de logique et d'écrans, 145 tests de règles) ; captures dans `audit_front/captures_stock_courses/` ; règles déployées sur le vrai projet le 28/10/2026 (accord de Kinder) |
| 2 Modèle générique et logos | à cadrer | | |
| 3 Stock par rôle | à cadrer | | |
| 4 Caisse : rupture et stock bas | à cadrer | | |
| 5 Courses : préparation | à cadrer | | |
| 6 Courses : validation | à cadrer | | |
| 7 Bilan et export CSV | à cadrer | | |
| 8 Recette | à cadrer | | |

## 9. Reprendre dans une nouvelle conversation
1. Lire `PROJET_CONTEXTE.md` (sections 6, 7, 8, 12), ce plan et `CHANGELOG.md`.
2. Annoncer la phase 5 (cadrage) de l'étape à venir : stratégie, fichiers, ce qu'on ne fait pas, points à trancher ;
   Kinder écrit le critère en français ; puis phase 6 (implémentation), une étape seule.
3. À la fin : tests de logique, d'écrans et de règles ; compte rendu fonctionnel à Kinder (critère réussi ou non) ;
   capture d'écran pour la validation ; mise à jour de la section 8, du `CHANGELOG.md` et de la section 12 du contexte.
