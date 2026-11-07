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
- **Décision 43 (28/10/2026)** : ajouter au modèle buche de chèvre et tartiflette (produits composés), bonbons offerts (prix 0, sans consommation), Nutella et sucre pour les crêpes (sans estimation de quantité) ; pas de matériel d'organisation dans le modèle. Source : liste de courses de l'an dernier fournie par Kinder.
- **À trancher** : correspondance des logos : la tarte confiture (03) est-elle un second gâteau sucré, et quel logo pour le gâteau salé ? (10 images, 9 produits distincts) ; soda (09) au style différent ; où se range le modèle (livré avec l'application,
  jamais modifiable lui-même : on le copie) ; le menu type actuel est-il remplacé ?
- **Cadrage figé le 28/10/2026 (Kinder : « oui, figer et coder »)** :
  - Modèle de 13 lignes (12 produits vendus + bonbons offerts), valeurs de départ modifiables, prix actuels conservés faute de prix reçus : Croque-monsieur (composé : 2 tranches de pain de mie, 1/3 de tranche de jambon, 7 g de gruyère ; conso 2) ; Croque chèvre (composé : 2 tranches de pain de mie, 30 g de bûche de chèvre, estimation) ; Tartiflette (part) ; Café (litre, 8 verres par litre ; conso 2) ; Thé (unité ; conso 1) ; Soda (litre, 5 verres par litre, estimation ; conso 1) ; Tarte (part ; conso 1) ; Flan (part ; conso 1) ; Barre chocolatée (unité ; conso 1) ; Fruit (unité ; conso 1) ; Salade (part) ; Crêpe (unité) ; Bonbons (unité, prix 0).
  - Logos : café, thé, croque-monsieur, barre, fruit, salade, soda, crêpe gardent leur clé ; flan = `gateau_sucre` ; tarte = nouvelle clé `tarte` (à ajouter aux règles d'accès). Chèvre, tartiflette et bonbons gardent une icône du système. Priorité d'affichage : photo, puis logo, puis icône. Logos entiers (non rognés), conservés à 500 px.
  - Création d'un menu : modèle, copie d'un menu existant, ou vide. « Partir du menu type » devient « Partir du modèle ».
  - Gâteau salé retiré du modèle (remplacé par la tartiflette) ; Nutella et sucre hors modèle (décision 43).
- **Critère de validation (proposé par Claude, validé le 28/10/2026)** :
  1. Un menu créé « à partir du modèle » contient les 13 lignes avec logos, types, recettes et consommations.
  2. Je rouvre le croque : mêmes quantités. Je modifie son prix : le modèle d'origine ne change pas.
  3. Je copie un menu existant : tous les produits arrivent avec leurs types, recettes, images et stocks.
  4. Un événement créé avec ce menu affiche les logos en caisse (hors réseau aussi).
  5. Une photo ajoutée remplace le logo ; sans photo, le logo s'affiche.
  6. Caisse, stock et bilan inchangés : les tests existants restent verts.

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
- **Décision 43 (28/10/2026)** : un produit sans quantité (ex. Nutella) peut être signalé « vide » dans le stock ; à cadrer : qui peut le signaler (bénévole ?) et comment cela s'affiche en caisse et en suivi.
- **CADRAGE FIGÉ (28/10/2026, accord de Kinder)** :
  1. Le bénévole saisit la **quantité ajoutée** (+6, de 1 à 1000), pas un nouveau total.
  2. L'ajout de parts **augmente le total de référence** (sinon le « stock bas » de l'étape 4 serait faux).
  3. « Vide » : signalé par la gestion **ou** par un bénévole dont la caisse est ouverte dans le gymnase, pour un produit sans quantité suivie ; stocké dans `gymnases/{g}/vides/{produit}` (document présent = vide). Affichage en caisse et en suivi : étape 4.
  4. Événement clôturé : plus rien ne bouge (ni ajout, ni réglage, ni « vide »).
  5. Règles : l'ajout du bénévole est limité aux produits de type « part », quantité et référence montent du même nombre ; la vente et l'annulation (quantité seule) restent autorisées comme avant.
  6. Écran du bénévole : bouton « Parts et produits vides » dans la barre de sa caisse ; réglage de la gestion dans « Gymnases et stocks » (interrupteur « Vide » sur les produits sans quantité).
- **Critères** : (1) un bénévole ajoute 6 parts de tarte, le stock de son gymnase passe de 5 à 11 et les autres produits ne bougent pas ; (2) il ne peut ni ajouter à un produit qui n'est pas une part, ni changer un prix ou un autre stock ; (3) la gestion règle un total, le total de référence prend cette valeur ; (4) un produit signalé « vide » est marqué dans « Gymnases et stocks », et le signal se retire ; (5) sur un événement clôturé, tout est bloqué.
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
- **CADRAGE FIGÉ (28/10/2026, accord de Kinder)** :
  1. Rupture : tuile rouge clair, « Épuisé », vente toujours possible. Stock bas : tuile orange clair, « Stock bas : n ».
  2. Seuil : total de référence > 0 et quantité de 1 à 10 % du total (quantité × 10 ≤ référence). Total 50 : bas de 1 à 5, normal à partir de 6. Sans total de référence (stock ancien) : jamais « bas ».
  3. Visible par la gestion **et** le bénévole en caisse.
  4. Produit sans quantité signalé « vide » : même rendu que la rupture (« Vide ») ; sans signal : aucune couleur (pas de gris « inconnu »).
  5. Suivi en direct (gestion) : ligne de signal sous le produit ; vue commune : gymnases concernés (« Épuisé : Gymnase B · Stock bas : Gymnase A ») ; vue d'un gymnase : signal seul.
  6. Vente et baisses de stock dans UN MÊME lot, annulation et retour au stock aussi.
  7. Double appui sur l’encaissement : un second appui n’enregistre rien (garde ajoutée, test).
- **Critères** : (1) total 50 : à 6 normal, à 5 orange « Stock bas : 5 », à 0 rouge « Épuisé », la vente passe quand même ; (2) un produit sans quantité signalé « vide » est rouge « Vide » en caisse, normal quand le signal est retiré ; (3) la gestion voit « Stock bas » ou « Épuisé » sur le bon gymnase dans le suivi en direct ; (4) la vente et ses baisses de stock partent ensemble (lot unique de 13 produits accepté par les règles).

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
- **Décision 43 (28/10/2026)** : la liste accepte des lignes libres ajoutées à la main (matériel d'organisation, etc.) pour tout centraliser ; elles n'entrent pas dans le stock ni le calcul inverse.
- **À trancher** : qui lance les courses (gestion de tous les gymnases ?) ;
  arrondis (pain en paquets ?) ; ajouter une ligne à la main après calcul ; plusieurs listes dans un même événement.
- **CADRAGE FIGÉ (28/10/2026, accord de Kinder)** :
  1. Qui lance les courses : le responsable, ou un gestionnaire rattaché à TOUS les gymnases (même règle que la clôture).
  2. Une seule liste par événement (document `courses/liste`), enregistrée automatiquement, modifiable jusqu'à la validation (étape 6, qui traitera aussi les achats partiels).
  3. Réglages (jours 1 à 30, 2 par défaut ; personnes par gymnase 0 à 1000) sur l'écran Courses, pas dans le formulaire de création.
  4. Produits pré-cochés : ceux qui ont une consommation ; la gestion décoche, ou coche d'autres produits. « Suggéré : stock bas » sur un produit en stock bas, épuisé ou vide dans le gymnase.
  5. Arrondis à l'unité supérieure, sans paquets ; g/kg et cl/L convertis (affichage en kg à partir de 1 000 g, en L à partir de 100 cl) ; produits au litre : verres → litres ; « ce qu'il reste » saisi dans l'unité de base de l'achat.
  6. Lignes libres (nom, quantité) à tout moment ; elles n'entrent ni dans le stock ni dans le calcul.
- **Critères** : (1) croque (2 tranches de pain, 1/3 de tranche de jambon, 7 g de gruyère, conso 2), 2 jours, gymnases de 80 et 60 personnes : 320 et 240 croques, à acheter 1 120 tranches de pain, 187 de jambon, 3,92 kg de gruyère ; (2) 320 → 300 recalcule, avec 540 croques le pain passe à 1 080 tranches, et « il reste 100 tranches de pain » le ramène à 980 ; (3) café (8 verres par litre, conso 2) pour 560 verres : 70 L ; (4) ligne libre « Liquide vaisselle × 2 » ; (5) quitter puis rouvrir : tout est retrouvé, et seuls le responsable et le gestionnaire de tous les gymnases y ont accès.

### Étape 6 — Courses : validation (moyenne)
- **Kinder voit** : « Valider » ouvre la saisie des quantités réellement achetées ; l'application affiche ce que cela
  donne en produits finaux (ingrédient limitant) et ajoute au stock ; saisie du coût total des courses.
- **Stratégie** : calcul inverse en logique pure ; mise à jour du stock et du total de référence dans un même lot ;
  une liste validée ne se rejoue pas (pas de double ajout au stock).
- **Fichiers** : module Courses, `lib/depot_evenements.dart`, `firestore.rules`, tests.
- **On ne fait pas** : lots, prix par élément, coût moyen, marge.
- **À trancher** : achat partiel (valider ce qui est acheté, relancer une liste pour le reste ?) ; répartition entre gymnases
  de ce qui est acheté ; peut-on corriger une validation ? ; produits simples (unité, part) : on saisit directement le nombre.
- **CADRAGE FIGÉ (28/10/2026, accord de Kinder)** :
  1. Calcul inverse : un produit gagne sa quantité prévue × le plus petit rapport (acheté + il reste) / (proposé + il reste) de ses ingrédients ; un ingrédient partagé se répartit proportionnellement entre toutes les lignes ; produit à l'unité ou à la part : le nombre acheté ; produit au litre : litres → verres. Arrondi vers le bas pour le total du produit, réparti entre gymnases au plus grand reste (aucune unité perdue).
  2. Répartition entre gymnases : proportionnelle aux quantités prévues.
  3. Un produit sans suivi de stock dans un gymnase commence à y être suivi, avec le rendement comme quantité de départ ; le total de référence monte du même nombre.
  4. Tout ou rien : ajouts de stock et passage en « validée » dans un seul lot (mesuré : 104 écritures acceptées) ; la validation demande le réseau ; en cas de refus rien n'est ajouté.
  5. Achat partiel : on valide ce qui est acheté ; le reste se complète à la main par un réapprovisionnement. Pas de seconde liste ni de correction d'une validation (une erreur se corrige par un réglage du stock).
  6. Qui : responsable, ou gestionnaire rattaché à tous les gymnases. Coût total obligatoire (0 si inconnu), en euros, conservé avec la liste.
- **Critères** : (1) liste de l'étape 5 (300 et 240 croques), tout acheté comme proposé : +300 au gymnase A, +240 au gymnase B ; (2) gruyère ramené de 3,78 kg à 1,89 kg : l'écran annonce 270 croques (150 et 120), « limité par Gruyère râpé » ; (3) café : 70 L donnent 560 verres (320 et 240) ; (4) coût 412,50 € enregistré avec la liste ; (5) un produit sans suivi se met à suivre son stock, le total de référence aussi ; (6) seconde validation impossible, la liste affiche « validée le … » ; (7) pas d'accès pour un bénévole ni pour un gestionnaire non rattaché à tous les gymnases.

### Étape 7 — Bilan et export CSV (petite)
- **Kinder voit** : le coût total des courses déduit au bilan ; un bouton d'export du bilan en CSV (s'ouvre dans Excel).
- **Stratégie** : bilan existant complété (mêmes clés, mêmes tests) ; CSV généré sans paquet (séparateur « ; », encodage
  lisible par Excel) ; remise du fichier sur Android : dépendance éventuelle À DEMANDER à Kinder (décision 40).
- **Fichiers** : `lib/ecran_bilan.dart`, module Courses (coût), tests.
- **À trancher** : vue distincte (un gymnase) : comment afficher un coût d'événement entier ? ; contenu exact du CSV.
- **CADRAGE FIGÉ (28/10/2026, accord de Kinder)** :
  1. Vue commune : « Coût des courses » (celui saisi à la validation) et « Résultat » (ventes moins coût, négatif avec son signe). Vue d'un gymnase : pas de coût, la mention « Le coût des courses concerne tout l'événement : voir la vue commune. »
  2. Seuls le responsable et le gestionnaire rattaché à tous les gymnases voient le coût (même accès que les courses). Courses non validées : « Courses non validées », sans résultat.
  3. CSV : un fichier pour la vue affichée, en sections (totaux avec coût et résultat en vue commune, modes, produits avec stock restant, caisses, jours, heures, ventes annulées). Séparateur « ; », virgule décimale, dates jj/mm/aaaa, UTF-8 avec marque, fins de ligne Windows, champs protégés par des guillemets.
  4. Remise du fichier : dépendance `share_plus` 10.1.4 (accord de Kinder le 28/10/2026, décision 40) ; fichier `bilan-<événement>-<date>.csv` remis à la feuille de partage d'Android. Repli possible : copie dans le presse-papiers.
- **Critères** : (1) coût 10,00 € et ventes 22,00 € : « Coût des courses : 10,00 € » et « Résultat : 12,00 € » en vue commune ; (2) courses non validées : « Courses non validées », ni coût ni résultat ; (3) vue d'un gymnase : la mention, pas de coût ; (4) le CSV reprend les chiffres de l'écran (relu à la main par les tests) : « 6,00 », accents lisibles, « ; » protégé ; (5) le bouton partage un fichier `.csv` nommé comme prévu (partage réel à vérifier sur téléphone, recette point 20).

### Étape 8 — Recette (moyenne)
- **CADRAGE FIGÉ (28/10/2026, accord de Kinder)** : parcours automatique complet (`chantier_complet_test.dart`, chiffres à la
  main) ; mesure des lectures (`lectures_test.dart`, section 10) avec optimisation si plus de 70 % du quota (fait : écoute des
  stocks partagée) ; version 1.1.0 (numéro 2) et APK de recette reconstruit, installé et lancé sur l'émulateur ; `RECETTE.md`
  remis en ordre ; texte de vérification pour une autre IA (section 11). Pas de bundle Play Store, pas de fusion dans `main`,
  pas de poussée sur GitHub.
- Parcours automatique complet (menu avec recettes -> événement -> courses -> validation -> ventes -> stock bas -> bilan
  -> export), vérifié chiffre par chiffre ; mesure des lectures du suivi en direct (quota gratuit 50 000/jour, vérifier
  avant de passer à 8 gymnases) ; mise à jour de `RECETTE.md` ; recette sur téléphones par Kinder ; APK reconstruit.

## 5 bis. Chantier « Menu, événement et courses » (plan validé le 29/10/2026, décisions 45 à 49)
Né du test de Kinder du 29/10/2026. Une étape à la fois, dans l'ordre ; chaque étape passe par un cadrage (phase 5) avant tout code. Avant l'étape 1 : initialiser graphify pour ce projet (aucun rapport au 29/10/2026).

**Critère de fin de mission (Kinder, validé le 29/10/2026)** : « Depuis un événement, j'ouvre Gymnases et stock, je vois ce qui est vendu et ce qui reste, je lance les courses en choisissant demi-journée ou jour complet, je valide, puis à la clôture je garde le soda et le café pour l'événement suivant. »

| # | Étape | Ce que Kinder voit | Critère (test de code) |
|---|---|---|---|
| B1 | Menu = catalogue sans stock | Plus de stock dans le menu ; provenance par produit (acheté / apporté par les bénévoles) | Aucun stock dans un menu ; un produit « apporté » n'apparaît pas aux courses sauf ajout à la main ; les anciens menus s'ouvrent sans erreur |
| B2 | Ratios et consommation par catégorie | 1 gâteau = n parts, 1 L = n verres, 1 croque = n composants ; consommation prévue réglable par catégorie | 1 gâteau = 8 parts : vente à la part, comptage en gâteaux entiers ; changer la consommation d'une catégorie met tous ses produits à jour ; ratio à zéro refusé avec message clair |
| B3 | Gymnases et stock côté événement | Stock propre à l'événement, par gymnase ; onglet au thème de l'application ; vendu et reste à l'instant T | Régler un stock d'événement ne change pas le menu ; après 3 ventes, vendu et reste exacts ; palette et composants du reste de l'application |
| B4 | Courses depuis Gymnases et stock | Bouton Courses visible ; consommé et reste connus ; choix demi-journée / jour complet / plus ; estimation modifiable | Courses atteint en moins de deux appuis ; l'estimation d'une demi-journée est inférieure à celle d'un jour complet pour un même reste ; quantité modifiée conservée ; ingrédients calculés d'après la recette, sans stock d'ingrédients |
| B5 | Clôture et report de stock | Choix des produits conservables, quantités restantes confirmées ou corrigées | Clôture avec 6 L de soda et 2 L de café gardés : repris dans le stock du bon gymnase au prochain événement ; produit non coché non reporté |
| B6 | Clôture de mission | Texte de vérification pour une autre IA, avec captures | Verdict réussi/échoué par critère rendu par une autre IA qui lance l'application |

Ordre : B1 → B2 → B3 → B4 → B5 → B6 (B3 avant B4 : les courses ont besoin du stock de l'événement ; B5 en dernier, voulu par Kinder).
À trancher au cadrage : B3, comment distinguer clairement l'écran du menu et celui de l'événement ?

**B1 — CADRAGE FIGÉ (29/10/2026, accord de Kinder)**
1. Le champ « stock » disparaît du formulaire et de la liste des produits du menu. Un nouvel événement démarre sans stock suivi dans les gymnases (la gestion le règle dans « Gymnases et stock », qui a déjà l'interrupteur et la quantité de départ) ; fin de la copie « chaque gymnase part du stock du menu » dans `depot_evenements.dart`. La copie d'un menu ne reprend plus de stock.
2. Provenance par produit : `acheté` (défaut, produits sans le champ) ou `apporté`, dans la fiche produit, copiée dans l'événement. Modèle fourni : tarte, flan et salade « apportés » (décision 37), tartiflette « achetée ».
3. Courses : un produit « apporté » n'est pas pré-coché ; la gestion peut le cocher à la main.
4. Anciens stocks dans les menus existants : ignorés (ni lus, ni affichés, ni copiés) ; effacés d'un produit quand il est enregistré de nouveau. Pas de migration.
5. Règles d'accès : champ `provenance` ('achete' | 'apporte') accepté et validé sur les produits de menu et d'événement ; la clé `stock` du menu reste tolérée pour les anciens documents.
6. Fichiers : `ecran_menu.dart`, `depot_menus.dart`, `depot_evenements.dart`, `courses.dart`, `ecran_courses.dart`, `assets/menu_type.json`, `firestore.rules`, tests (logique, écrans, règles, parcours Android qui garnissaient le stock par le menu).
7. On ne fait pas : ratios et consommation par catégorie (B2), écran « Gymnases et stock » (B3), courses depuis cet écran (B4), report de stock (B5).
- **Critères** : (1) plus de champ stock dans le formulaire de menu ; « acheté / apporté » choisi puis retrouvé à la réouverture ; (2) événement créé depuis un menu : aucun stock dans les gymnases, provenance copiée ; (3) courses : produit « apporté » non pré-coché mais cochable ; (4) ancien menu avec stock : s'ouvre et se copie sans stock ; (5) caisse, bilan et suivi en direct inchangés (tests existants adaptés, verts).

**B2 — CADRAGE FIGÉ (29/10/2026, accord de Kinder)** — les « catégories » sont les types de produit (à la part, au litre, en quantité ; plus le composé), chacune avec ses réglages propres ; pas de regroupement de produits à consommation commune : chaque boisson (café, coca, oasis) reste un produit distinct, avec son propre stock (décision 36). Le plan « changer la consommation d'une catégorie met tous ses produits à jour » est abandonné ; la consommation reste un réglage par produit.
1. Type « à la part » : réglage facultatif « parts par gâteau » (entier de 1 à 100). Sans valeur : comportement actuel. Avec valeur : la liste de courses affiche des gâteaux entiers (parts prévues ÷ parts par gâteau, arrondi au-dessus, moins « ce qu'il reste ») ; à la validation, le stock gagne gâteaux achetés × parts par gâteau (répartis entre gymnases au prorata des quantités prévues).
2. Boisson (verres par litre) et composé (recette) : inchangés.
3. Règles d'accès : `partsParEntier` seulement pour le type « part », entier de 1 à 100, sur les produits de menu et d'événement.
4. Aucune valeur de parts par gâteau dans le modèle fourni (pas de chiffres de Kinder).
5. Fichiers : `depot_menus.dart`, `ecran_menu.dart`, `courses.dart`, `firestore.rules`, tests. Pas touchés : « Gymnases et stock » (B3), courses depuis cet écran (B4), report de stock (B5).
- **Critères** : (1) gâteau à 8 parts : retrouvé à la réouverture ; (2) 20 parts prévues : la liste affiche 3 gâteaux ; (3) validation de 3 gâteaux achetés : +24 parts au stock ; (4) un gâteau sans ratio se comporte comme avant ; (5) ratio à zéro, ou sur un autre type, refusé (application et règles).

**B3 — CADRAGE FIGÉ (29/10/2026, accord de Kinder)** : (1) écran « Gymnases et stocks » refait dans le langage de l'application : en-tête « Stock de l'événement « nom » », une carte par gymnase, par produit image + état coloré (Stock bas orange, Épuisé / Vide rouge, comme en caisse) + « Stock : n » + « Vendu : v », actions nommées de 48 px (« Ajouter », « Corriger », « Suivre le stock ») ; (2) vendu en direct = ventes non annulées du gymnase (`suivreTableauDeBord`), écoute ouverte seulement sur cet écran de gestion (lectures de quota en plus pendant qu'il est ouvert) ; (3) événement neuf sans stock suivi : message d'aide et bouton « Suivre tous les produits » par gymnase (démarre à 0) ; (4) menu : bandeau « Catalogue : le stock se règle dans l'événement » ; (5) droits inchangés ; aucune règle d'accès modifiée. Ne fait pas : Courses depuis cet écran (B4), report de stock (B5).
- **Critères** : (1) événement neuf : message d'aide, « Suivre tous les produits » démarre à 0 ; (2) stock réglé à 20 : le menu ne change pas, après 3 ventes « Stock : 17 · Vendu : 3 » ; (3) « Stock bas » orange / « Épuisé » rouge comme en caisse ; (4) actions nommées, 48 px, image du produit ; (5) bandeau dans le menu ; (6) gestionnaire limité à ses gymnases.

**B4 — CADRAGE FIGÉ (29/10/2026, accord de Kinder)** : (1) bouton « Préparer les courses » en haut de « Gymnases et stocks » (responsable ou gestionnaire de tous les gymnases ; sinon une phrase explique la réserve) ; le bouton du détail de l'événement reste ; (2) durée : « Demi-journée » (0,5), « Jour complet » (1) ou « Plus » (2 à 30 jours) ; `nbJours` devient un nombre (règle : 0,5 à 30) ; (3) estimation par gymnase et produit acheté : personnes × durée × consommation (arrondi au-dessus) moins le stock actuel si suivi, jamais sous zéro ; un produit couvert par le stock n'est pas coché ; (4) chaque ligne affiche « En stock » et « Vendu » ; « Recalculer » relit le stock ; (5) le consommé est affiché à titre d'information, sans extrapolation automatique ; (6) ingrédients sans stock et produits « apportés » non cochés d'avance : inchangés. Ne fait pas : validation des achats, report de stock (B5).
- **Critères** : (1) « Préparer les courses » depuis « Gymnases et stocks » ouvre les courses ; (2) demi-journée = moitié du jour complet (arrondi au-dessus) ; (3) besoin 160 et stock 40 : 120 ; stock 200 : 0 ; (4) « Plus » avec 3 jours = triple du jour complet ; (5) chaque ligne montre besoin, stock et vendu, quantité modifiée conservée ; (6) ingrédients d'après recette sans stock d'ingrédients ; (7) gestionnaire non rattaché à tous les gymnases : explication au lieu du bouton.

**Suivi B4** : implémentée et testée par Claude le 29/10/2026 (commit 51a0361). Analyse sans erreur, 230 tests de logique et d'écrans, 173 tests de règles, parcours Android `courses_test` (étendu : entrée par Gymnases et stocks, demi-journée, jour complet, stock déduit), `gymnases_test`, `chantier_complet_test`, `recette_test` et `lectures_test` réussis (gestion : 2,78 lectures par vente en direct, avant 2,57 à 2,93) ; série complète des parcours non relancée. Règle `nbJours` (0,5 à 30) déployée le 30/10/2026 (accord de Kinder), avec celle du recalage. Le critère 4 (3 jours = triple) et le critère 7 (gestionnaire non rattaché) ne sont pas couverts par un test d'écran dédié ; le 4 l'est par les tests de calcul (durée 3). Reste : capture de Kinder.

**Suivi recalage du modèle (30/10/2026, décision 50)** : implémenté et testé par Claude, non commité. Analyse sans erreur, 230 tests de logique et d'écrans, 174 tests de règles (modèle de 27 produits créé en un seul lot accepté), parcours Android `chantier_complet` (recalculé à la main : pain 476 tranches, jambon 79, gruyère 1,46 kg, café 45,5 L, ventes 83,50 €, coût 40 €, résultat 43,50 €), `copie_menu`, `images`, `stock_role` (ajout sur produit apporté) et `lectures` réussis ; série complète des parcours non relancée. Commit 70fba1a ; règles (ajout de stock aux produits apportés, et `nbJours` de B4) déployées sur le vrai projet le 30/10/2026 (accord de Kinder). Affichage connu : 1 575 g s'affiche « 1,57 kg » (arrondi binaire).

**B5 — CADRAGE FIGÉ (30/10/2026, accord de Kinder)** : (1) à la clôture, feuille « Garder pour le prochain événement ? » : produits suivis avec du stock, gymnase par gymnase, rien de coché ; quantité préremplie et corrigeable (litres pour un produit au litre, stockée en verres) ; (2) restes rangés dans l'association (`restes/{gymnase}__{produit}`, noms sans accents), écrits avec la clôture, un nouveau report remplace l'ancien, un produit décoché retire l'ancien report ; (3) à la création de l'événement suivant : reprise par NOM de gymnase et de produit, total de référence posé, reste effacé, message « n stocks repris » ; (4) non repris : produit non coché, gymnase ou produit au nom inconnu (le reste attend) ; (5) droits : comme la clôture ; (6) règles : collection `restes`, écrite seulement dans le lot de clôture. Ne fait pas : ingrédients, choix manuel du gymnase.
- **Critères** : (1) clôture avec 6 L de soda (Gymnase 1) et 2 L de café (Gymnase 2) cochés : deux restes de 24 et 8 verres ; (2) événement suivant aux mêmes noms de gymnases : Gymnase 1 démarre avec 24 verres de soda, Gymnase 2 avec 8 de café ; (3) produit non coché non repris ; (4) un troisième événement ne reprend rien ; (5) gestionnaire non rattaché à tous les gymnases : refusé ; (6) sans réseau la clôture échoue comme avant, rien n'est enregistré.

**Suivi C1** (30/10/2026, branche `claude/c1-courses-partielles`, décision 52) : implémentée et testée par Claude. Après une validation, le bouton « Nouvelle série de courses » repart d'une liste vide ; le coût et les ajouts de stock déjà validés sont gardés dans un cumul (`cumulSeries`, `cumulCout`, `cumulAjouts` sur le même document `courses/liste`) ; le bilan compte toutes les séries ; bouton « Partager la liste » (texte `liste-de-courses.txt` par la feuille de partage existante, aucune dépendance). Analyse sans erreur, 247 tests de logique et d'écrans, 186 tests de règles, parcours Android `courses_test` (2 parcours) réussis ; la série complète des 27 parcours n'a pas été relancée. Critère : 40 croques validés puis 40 de plus -> stock +80 au total, coût cumulé ; vérifié par le parcours (150 + 40 = 190 au gymnase A, coût cumulé 492,50 € en 2 séries). Non couvert par un test d'écran : l'ouverture réelle de la feuille de partage et le contenu partagé de bout en bout (le texte lui-même est vérifié par un test de logique). Règles déployées sur le vrai projet le 30/10/2026 (accord de Kinder). Reste : capture de Kinder.

**Suivi B5** : implémentée et testée par Claude le 30/10/2026, branche `claude/b5-report-stock`. Analyse sans erreur, 243 tests de logique et d'écrans, 183 tests de règles (dont 216 restes écrits avec la clôture en un seul lot), série complète des 27 parcours Android réussis (`restes_test` : critères 1 à 4 ; `clotures_test` et `bilan_test` adaptés à la nouvelle feuille). Règles (collection `restes`) déployées sur le vrai projet le 30/10/2026 (accord de Kinder) ; APK de recette reconstruit avec B5 (1.1.0+2, `recette/le-comptoir-recette.apk`). Non couvert par un test d'écran : le message « n stocks repris » à la création par l'écran (la reprise l'est par le dépôt), et le critère 6 (sans réseau) par le seul comportement de la transaction. Défaut déjà présent avant B5 corrigé dans `gestionnaires_test` : un appui sur la case de rattachement pouvait tomber à côté pendant le rechargement de l'écran, le test recommence maintenant l'appui. Reste : capture de Kinder.

**Suivi B3** : implémentée et testée par Claude le 29/10/2026 (commit B3). Analyse sans erreur, 226 tests de logique et d’écrans, parcours Android `gymnases_test` (étendu : titre, « Vendu : 0 », « Suivre tous les produits »), `menus_test` (bandeau), `stock_role_test`, `rupture_test`, `chantier_complet_test` et `lectures_test` réussis ; série complète des parcours non relancée. Le critère « 3 ventes -> Vendu : 3 » n'est pas vérifié par un test d'écran (le calcul `TableauDeBord.vendus` l'est par les tests du suivi). Aucune règle à déployer. Reste : capture de Kinder.

**Suivi B2** : implémentée et testée par Claude le 29/10/2026, sur la branche `claude/menu-evenement-b1` (commit 7b9be1e). Analyse sans erreur, 226 tests de logique et d'écrans, 172 tests de règles, parcours Android `courses_test`, `menus_test` et `chantier_complet_test` réussis (série complète des 26 parcours non relancée). Règles (`partsParEntier`) déployées le 29/10/2026 (accord de Kinder). Reste : capture de Kinder.

**Suivi B1** : implémentée et testée par Claude le 29/10/2026, sur la branche `claude/menu-evenement-b1` (commit 284fbdb). Analyse sans erreur, 218 tests de logique et d'écrans, 170 tests de règles, 26 parcours Android (24 réussis dans la série complète ; `recette_test` réussi seul après un échec isolé de la série, et `chantier_complet_test` adapté : la tarte, désormais « apportée », n'est plus dans les courses, son stock de 80 est posé à la main, puis réussi). Règles (champ `provenance`) déployées sur le vrai projet le 29/10/2026 (accord de Kinder). Reste : capture de Kinder, et la vérification par une autre IA en clôture du chantier (B6).

## 6. Registre du cahier des charges (rien ne se perd)
| Demande du PDF | Sort |
|---|---|
| Vente bloquée en rupture | **Écarté** (décision 35 : couleur, jamais de blocage) |
| États colorés : disponible vert, bas orange, rupture rouge, inconnu gris | **Retenu en partie** : rupture colorée (étape 4), stock bas signalé (4). « Inconnu gris » (produit sans suivi) **mis de côté** (tri du 30/10/2026 : un produit sans suivi n'a simplement pas d'alerte) |
| Tableau de bord des stocks par gymnase/événement, filtres catégorie | **Reporté** : le suivi en direct montre déjà le stock restant ; filtres par catégorie **mis de côté** (tri du 30/10/2026 : pas de catégorie de produit, 27 produits restent lisibles) |
| Entrées, pertes/consommations internes, corrections | **Retenu en partie** : entrées et réglages (étape 3, courses 6) ; pertes et consommations internes **mises de côté** (tri du 30/10/2026 : baisser le stock à la main suffit) |
| Inventaire de fin de journée (saisie directe, sans écart affiché) | **Couvert** par le réglage du stock par la gestion (étape 3) ; pas d'écran dédié |
| Réapprovisionnements partiels pendant la journée | **Retenu, version simple (tri du 30/10/2026, décision 52)** : valider les courses plusieurs fois ; chaque validation ajoute au stock et au coût ; mission C1 |
| Unités et conversions (tranches, grammes) | **Retenu** : liste d'unités à l'étape 1, conversions g/kg et cl/L aux étapes 5-6 |
| Transferts entre gymnases | **Écarté** (à la main : -10 puis +10) |
| Lots à prix différents, coût moyen pondéré | **Écarté** (coût total des courses seulement) |
| Prévisions personnes × jours × coefficients, coefficients visibles et modifiables | **Retenu** en pré-remplissage modifiable (décision 42, étape 5) ; pas de stock cible |
| Déduire stocks et réceptions pour éviter les doubles commandes | **Retenu** : la liste part des quantités saisies et de « ce qu'il reste » ; pas de déduction automatique des courses déjà validées (à trancher étape 5) ; **tri du 30/10/2026** : traité par les validations successives de la mission C1 (décision 52) |
| Liste de courses : cases à cocher, statuts (à acheter, partiel, reçu, annulé), ajout manuel | **Retenu en partie** : préparation puis validation (étapes 5 et 6) ; cases à cocher faites ; **tri du 30/10/2026** : statuts détaillés par ligne (à acheter, partiel, reçu, annulé) **mis de côté**, remplacés par les validations successives (mission C1, décision 52) |
| Impression ou export de la liste de courses | **Retenu (tri du 30/10/2026, décision 52)** : partage de la liste en texte ou CSV par la feuille de partage existante ; mission C1 |
| Recettes, décrémentation des ingrédients à la vente, portions réalisables | **Retenu en partie** : recettes (étape 1) ; les ingrédients n'ont pas de stock (décision 38), donc pas de décrémentation ; « portions réalisables » = calcul inverse à la validation |
| Prix de vente, coût matière, marge et taux de marge | **Écarté** (coût total des courses déduit au bilan) |
| Cartes physiques prépayées | **Écarté** pour l'instant |
| Paiement carte envoyé au terminal | **Reporté en dernier** : Monetico (section 7 du contexte) |
| Gâteaux et préparations bénévoles (sucré/salé, parts, prix) | **Retenu** : types « part » (étapes 1 et 3) |
| Bilan par produit, catégorie, moyen de paiement, gymnase, événement | **Déjà fait** ; bilan par catégorie, valeur du stock restant, coûts et marges par produit **mis de côté** (tri du 30/10/2026 : il faudrait un prix d'achat par élément) |
| Export CSV/Excel du bilan | **Retenu** : CSV (étape 7) |
| Cohérence multi-appareils, droits, coupures réseau, sauvegardes | **Déjà fait** ; lectures en direct à mesurer (étape 8) ; sauvegardes **mises de côté** (tri du 30/10/2026 : l'export CSV du bilan en tient lieu ; à reprendre si le club veut l'historique de plusieurs saisons) |

**Tri du cahier des charges (30/10/2026, validé par Kinder, décision 52)** : le PDF transmis par un bénévole est le même que celui du 27/10 ; il a été repris point par point après B5. *Gardé tel quel* : stock par gymnase, états rupture et stock bas, prévisions, courses générées avec cases et lignes libres, recettes et ingrédient limitant, unités, gâteaux apportés, bilan et export CSV, multi-appareils, droits, coupure réseau. *Adapté* : vente jamais bloquée (couleur seulement), transferts à la main, inventaire = réglage du stock, marge = coût total et résultat, ingrédients calculés à l'achat, sucré/salé = produits distincts. *Retenu, mission C1* : validations successives des courses, partage de la liste de courses. *Mis de côté* : pertes, « inconnu » gris, valeur du stock et marges, catégories, sauvegardes, cartes prépayées. *Parqué* : Monetico. **À faire plus tard : rendre compte au bénévole des choix faits par rapport à son PDF** (reprendre ce tri en langage simple).

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
| 1 Types et recettes | **implémentée, testée par Claude (28/10/2026)** ; reste la capture de Kinder | 27-28/10/2026 | critères 1 à 6 réussis par les tests de code (analyse sans erreur, 162 tests de logique et d'écrans, 146 tests de règles, 18 parcours Android) ; captures dans `audit_front/captures_stock_courses/` ; règles déployées sur le vrai projet le 28/10/2026 (accord de Kinder) |
| 2 Modèle générique et logos | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et la capture de Kinder | 28/10/2026 | critères 1 à 6 réussis par les tests de code (analyse sans erreur, 166 tests de logique et d'écrans, 147 tests de règles, 19 parcours Android) ; captures `reel2_*` dans `audit_front/captures_stock_courses/` ; règles (clé `tarte`) déployées sur le vrai projet le 28/10/2026 (accord de Kinder) |
| 3 Stock par rôle | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et la capture de Kinder ; règles (champ `reference`, sous-collection `vides`) déployées sur le vrai projet le 28/10/2026 (accord de Kinder) | 28/10/2026 | critères 1 à 5 réussis par les tests de code (analyse sans erreur, 166 tests de logique et d'écrans, 155 tests de règles, 21 parcours Android dont `stock_role_test`) |
| 4 Caisse : rupture et stock bas | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et la capture de Kinder ; aucune modification des règles (rien à déployer) | 28/10/2026 | critères 1 à 4 réussis par les tests de code (analyse sans erreur, 175 tests de logique et d'écrans, 157 tests de règles, 22 parcours Android dont `rupture_test`) |
| 5 Courses : préparation | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et la capture de Kinder ; règles (nbJours, personnes, courses/liste) déployées sur le vrai projet le 28/10/2026 (accord de Kinder) | 28/10/2026 | critères 1 à 5 réussis par les tests de code (analyse sans erreur, 187 tests de logique et d'écrans, 162 tests de règles, 23 parcours Android dont `courses_test`) |
| 6 Courses : validation | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et la capture de Kinder ; règles (liste « validee ») déployées sur le vrai projet le 28/10/2026 (accord de Kinder) | 28/10/2026 | critères 1 à 7 réussis par les tests de code (analyse sans erreur, 195 tests de logique et d'écrans, 166 tests de règles, 24 parcours Android dont la validation dans `courses_test`) |
| 7 Bilan et export CSV | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et la capture de Kinder ; aucune modification des règles (rien à déployer) | 28/10/2026 | critères 1 à 4 réussis par les tests de code (analyse sans erreur, 210 tests de logique et d'écrans, 166 tests de règles, 24 parcours Android) ; critère 5 : appel de partage réel sans erreur sur l'émulateur, feuille de partage à vérifier par Kinder |
| 8 Recette | **implémentée, testée par Claude (28/10/2026)** ; reste la vérification par une autre IA et votre test sur téléphones | 28/10/2026 | parcours complet réussi chiffre par chiffre, lectures mesurées et optimisées (section 10), APK 1.1.0 dans `recette/` installé et lancé sur l'émulateur ; analyse sans erreur, 210 tests de logique et d'écrans, 166 tests de règles, 26 parcours Android |

## 9. Reprendre dans une nouvelle conversation
1. Lire `PROJET_CONTEXTE.md` (sections 6, 7, 8, 12), ce plan et `CHANGELOG.md`.
2. Annoncer la phase 5 (cadrage) de l'étape à venir : stratégie, fichiers, ce qu'on ne fait pas, points à trancher ;
   Kinder écrit le critère en français ; puis phase 6 (implémentation), une étape seule.
3. À la fin : tests de logique, d'écrans et de règles ; compte rendu fonctionnel à Kinder (critère réussi ou non) ;
   capture d'écran pour la validation ; mise à jour de la section 8, du `CHANGELOG.md` et de la section 12 du contexte.

## 10. Mesure des lectures du suivi en direct (étape 8)
Mesuré sur l'émulateur par `integration_test/lectures_test.dart` (3 gymnases, 6 caisses, 600 ventes de 3 lignes déjà
faites, 60 ventes en direct). Les documents lus sont comptés par chaque écoute (`lib/mesure.dart`, inactif en production).

| Mesure | Avant optimisation | Après (écoute des stocks partagée) |
|---|---|---|
| Téléphone de gestion, ouverture du suivi (600 ventes déjà faites) | 712 lectures | 638 lectures |
| Gestion, lectures par vente en direct | 7,12 | **2,93** |
| Caisse, lectures par vente de son gymnase | 6,50 | **3,50** |
| Caisse, ouverture | = nombre de documents des écoutes : produits 13 + stocks 8 + gymnases + sa caisse + pointeur + ses ventes | idem |

Cause trouvée : chaque changement de stock était lu 2 à 3 fois (quantités, couleurs, produits). Une seule écoute partagée
par événement et par ensemble de gymnases remplace les trois.

Projection d'une journée (hypothèses : 2 appareils de gestion ouvrent le suivi 5 fois dans la journée, en moyenne à
mi-journée ; chaque caisse est ouverte 2 fois ; ventes réparties à parts égales) :

| Cas | Gestion (ouvertures + direct) | Caisses (ouvertures + direct) | Total / jour | Part du quota (50 000) |
|---|---|---|---|---|
| 3 gymnases, 6 caisses, 1 000 ventes | 5 380 + 5 860 | 1 308 + 7 000 | **≈ 19 500** | 39 % |
| 8 gymnases, 16 caisses, 2 000 ventes | 11 040 + 11 720 | 2 976 + 14 000 | **≈ 39 700** | 79 % |
| idem, avec un seul appareil de gestion | 5 520 + 5 860 | 2 976 + 14 000 | ≈ 28 400 | 57 % |
| idem, avant optimisation (deux appareils) | 11 040 + 28 480 | 2 976 + 26 000 | ≈ 68 500 | 137 % (dépassement) |

**Correction après la vérification indépendante (29/10/2026)** : le test écrit les trois baisses de stock d'une vente en
rafale, et les écoutes en regroupent une partie ; en situation réelle, la gestion lit jusqu'à 4 documents par vente (1 vente +
3 baisses de stock) au lieu de 2,93 mesurés. Les lectures faites par les règles d'accès elles-mêmes (relecture du membre, de
l'événement, de la caisse : environ 5 par vente) sont aussi facturées et ne sont pas comptées par `lib/mesure.dart`.
Projection corrigée (ordre de grandeur) :

| Cas | Total / jour | Part du quota (50 000) |
|---|---|---|
| 3 gymnases, 6 caisses, 1 000 ventes, 2 appareils de gestion | ≈ 26 700 | 53 % |
| 8 gymnases, 16 caisses, 2 000 ventes, 1 appareil de gestion | ≈ 40 500 | 81 % |
| 8 gymnases, 16 caisses, 2 000 ventes, 2 appareils de gestion | ≈ 54 000 | 108 % (dépassement) |

Conclusion : confortable pour le cas visé (3 gymnases). À 8 gymnases, un seul appareil de gestion doit laisser le suivi
ouvert, et fermer l'écran quand on ne le regarde pas (les lectures en direct s'arrêtent) ; sinon le quota gratuit est
dépassé. **À confirmer pendant la recette** : après un vrai événement, lire les lectures réelles dans la console Firebase
(Firestore, onglet Utilisation) et les comparer à ce tableau. Les écritures (environ 11 000 par jour pour 3 gymnases et 6
caisses, quota 20 000) n'ont pas changé.

### Vérification indépendante (29/10/2026)
Une IA qui n'a pas écrit le code a refait toutes les suites (analyse, 210 tests de logique et d'écrans, 166 tests de règles,
26 parcours Android) et vérifié les 11 critères du texte de la section 11 : **tous réussis, aucun défaut bloquant**. Rapport et
captures : `audit_front/captures_stock_courses/verif_ia/`. Points relevés et traités :
- Stock : un bénévole à sa caisse peut techniquement (en contournant l'application) corriger la quantité d'un produit de son
  gymnase, car la règle de la vente et de l'annulation ne distingue pas une vente d'une correction. **Limite acceptée par
  Kinder le 29/10/2026** (décision 44) : le bénévole est un membre de confiance, l'application ne lui offre pas cette action, et
  la durcir compliquerait la vente sans réseau. Seul « ajouter des parts » est borné par le serveur.
- Compteur de gymnases : un gestionnaire pouvait le monter sans créer de gymnase, ce qui retirait à tous les gestionnaires
  l'accès aux courses et à la clôture. **Corrigé** : le compteur ne monte qu'avec la naissance du gymnase (`dernierGymnase`),
  vérifié dans les règles et par des tests (règles déployées sur le vrai projet le 29/10/2026, accord de Kinder).
- Mesure des lectures : projection corrigée ci-dessus.
- Restent connus et sans gravité : contenu des listes de courses non borné en taille (limite de 1 Mo par document, gestion
  seule) ; signal « vide » accepté sur un produit qui a une quantité (effet visuel seulement) ; deux validations de courses au
  même instant sur deux appareils (rare, gestion seule). Non vérifiables sans téléphone : ouverture du CSV dans Excel et
  feuille de partage Android (recette, point 20).

## 11. Texte de vérification pour une autre IA (étapes 1 à 7 et parcours complet)
À donner tel quel à une IA qui n'a pas écrit le code (décision : l'IA qui code rédige, une autre vérifie).

> Tu vérifies l'application Flutter « Le Comptoir » (dossier `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`, branche
> `claude/comptoir-app-refinement-cnuyb4`), chantier « Stock et courses » (étapes 1 à 8 de `PLAN_STOCK_COURSES.md`, décisions
> 33 à 43 de `PROJET_CONTEXTE.md`). Tu ne corriges rien : tu rends un verdict réussi/échoué par critère, avec une capture.
>
> **Lancer** : émulateurs Firebase `firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8` (Java 21 :
> `C:\Program Files\Android\Android Studio\jbr`) ; émulateur Android `LC2` (`-gpu swiftshader_indirect -no-snapshot
> -no-audio`) ; `tests_regles/lancer.ps1` (166 tests de règles), `flutter analyze`, `flutter test` (210 tests),
> `tests_regles/lancer_integration.ps1` (26 parcours). Si un parcours se fige sur l'émulateur Android (écran noir), tuer
> l'émulateur (`adb emu kill`), le relancer et relancer ce parcours : ce n'est pas un défaut du code.
>
> **À vérifier, étape par étape (chaque ligne = un critère)** :
> 1. Types de produit : composé (recette, 20 ingrédients au plus), à l'unité, à la part, au litre ; fiche copiée dans
>    l'événement et figée.
> 2. Modèle de 13 produits avec logos ; copie d'un menu existant ; le modèle d'origine ne change jamais.
> 3. Stock par rôle : un bénévole à sa caisse ajoute des parts (produits « part » seulement, 1 à 1000) ; le total de
>    référence monte du même nombre ; « vide » se signale et se retire ; événement clôturé : tout est bloqué.
> 4. Caisse : orange « Stock bas : n » à 10 % ou moins du total, rouge « Épuisé » à zéro, rouge « Vide » ; la vente n'est
>    jamais bloquée ; vente et baisses de stock dans un seul lot.
> 5. Courses, préparation : personnes par gymnase, jours, quantités pré-remplies modifiables, achats additionnés (g/kg, cl/L),
>    « il reste », lignes libres, enregistrement automatique ; accès réservé au responsable et au gestionnaire de tous les
>    gymnases.
> 6. Courses, validation : calcul par l'ingrédient limitant, ajout au stock (suivi démarré si absent), coût obligatoire,
>    liste figée, tout ou rien.
> 7. Bilan : coût et résultat en vue commune seulement ; export CSV (« ; », virgule décimale, accents).
> 8. Parcours complet (`integration_test/chantier_complet_test.dart`) : 2 gymnases (40 et 30 personnes, 2 jours) → pain de mie
>    560 tranches, jambon 94 tranches, gruyère 1,96 kg, café 35 L, soda 28 L ; coût 150,00 € ; ventes 7,00 + 152,00 + 10,00 =
>    169,00 € ; tarte « Stock bas : 4 » puis « Épuisé » ; résultat 19,00 €.
>
> **Pièges connus** : un lot Firestore est limité à 500 écritures et une requête de règles à 1000 expressions ; les fichiers
> `lib/*.dart` sont en CRLF ; ne pas lancer deux émulateurs Firestore en même temps (port 8080).
>
> **Rendu attendu** : un tableau critère / verdict / capture, la liste des défauts classés par gravité, et UNE question.

## 12. Texte de vérification pour une autre IA : chantier B1 à B5 et mission C1 (étape B6, rédigé le 30/10/2026)
À donner tel quel à une IA qui n'a pas écrit le code. Son verdict ferme l'implémentation ; la capture finale de Kinder ferme la mission.

> Tu vérifies l'application Flutter « Le Comptoir » (dossier `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`, branche
> `claude/c1-courses-partielles`, qui contient aussi tout B1 à B5), chantier « Menu, événement et courses » (étapes B1 à B5,
> section 5 bis de `PLAN_STOCK_COURSES.md`, décisions 45 à 51 de `PROJET_CONTEXTE.md`) et mission C1 (décision 52, suivi C1 de
> la section 5 bis). Tu ne corriges rien : tu rends un verdict réussi/échoué par critère, avec une
> capture. Lancement : voir la section 11 (émulateurs Firebase, émulateur Android `LC2`, `tests_regles/lancer.ps1`,
> `flutter analyze`, `flutter test`, `tests_regles/lancer_integration.ps1`). Attendus au 30/10/2026 : analyse sans erreur,
> 247 tests de logique et d'écrans, 186 tests de règles, 27 parcours Android.
>
> **Critères (chaque ligne = un verdict)** :
> 1. B1 : un menu ne contient aucun stock ; chaque produit porte sa provenance (acheté par l'association / apporté par les
>    bénévoles) ; un produit apporté n'apparaît pas dans les courses sauf ajout à la main.
> 2. B2 : ratios de conversion par catégorie (1 gâteau = n parts, 1 litre = n verres, 1 croque = n composants) ; un ratio à
>    zéro est refusé.
> 3. B3 : le stock appartient à l'événement, par gymnase (onglet « Gymnases et stock ») ; après 3 ventes, « Vendu » et « Reste »
>    sont exacts ; modifier le menu ensuite ne change pas un événement lancé.
> 4. B4 : depuis « Gymnases et stock », les courses connaissent le consommé et le reste ; durée à couvrir au choix (demi-journée,
>    jour complet ou plus) ; estimation modifiable ; rien ne s'achète sans validation.
> 5. B5 : à la clôture, la feuille propose les produits qui ont du stock, rien de coché d'avance ; 6 L de soda et 2 L de café
>    gardés sont repris au stock de l'événement suivant (gymnase et produit de même nom) ; un report ne sert qu'une fois ;
>    la clôture et les restes s'écrivent ensemble (tout ou rien).
> 6. Cohérence visuelle (décision 49) : l'onglet « Gymnases et stock » et les courses suivent le thème (anthracite, lin, pigments).
> 7. C1, plusieurs séries : après une validation, « Nouvelle série de courses » ouvre une liste vide ; un bandeau donne le nombre
>    de séries validées, le coût cumulé et ce que le stock a déjà reçu ; une série validée n'ajoute jamais deux fois au stock
>    (ex. : 40 croques à 50,00 € puis 40 à 30,00 € = +80 au total, coût cumulé 80,00 €) ; le bilan affiche le coût de toutes les
>    séries ; les règles n'acceptent une nouvelle série que depuis une liste validée, vide, avec le cumul exact.
> 8. C1, partage : le bouton « Partager la liste » ouvre la feuille de partage avec « À acheter » (quantités arrondies) puis les
>    lignes libres ; contrôle visuel du bouton seulement (la feuille d'Android ne se capture pas dans le test).
> 9. Non-régression : les critères 1 à 8 de la section 11 passent toujours (le critère 6 est étendu par C1 : la liste validée
>    n'est plus définitivement figée, elle repart par une nouvelle série).
>
> **Captures de départ** (à ne pas croire sur parole, à refaire) : `audit_front/captures_stock_courses/verif_finale/` (16 images prises par Claude le 30/10/2026,
> lancées par `lancer.ps1` du même dossier).
>
> **Rendu attendu** : un tableau critère / verdict / capture, la liste des défauts classés par gravité, et UNE question.

## 13. Mission « Préparer l'événement » (décisions 53 à 60, plan, critères et préalables validés par Kinder le 06/11/2026)

**Critère de fin de mission (Kinder, 06/11/2026)** : « Je crée un événement, je télécharge le modèle Excel, je le remplis avec les chiffres de l'an passé et je l'importe ; dans Préparation, je retrouve mon stock de départ et une prévision calculée d'après l'an passé, je corrige un chiffre, je lance les courses ; à la fin du tournoi, j'exporte le même classeur rempli. »

**Préalables (à valider avec le plan)** : (1) le chantier (phase 6) démarre après le test de Kinder sur téléphone des missions en attente (Stock et courses, B1 à B6, C1), pour respecter « une mission à la fois » ; (2) les règles d'accès de chaque étape sont déployées sur le vrai projet dès que leurs tests passent, avec un accord donné une fois pour toute la mission ; (3) la session mère (Sonnet) mène les étapes une par une, chacune dans une sous-session neuve.

**Le classeur Excel (décision 57)** : un fichier `.xlsx` ; chaque feuille commence par une ligne d'aide puis une ligne d'en-têtes ; les produits et gymnases se retrouvent par leur NOM (sans casse ni accents, comme le report de stock).

| Feuille | Colonnes | À l'import |
|---|---|---|
| Menu | Produit, Prix, Type, Provenance, Verres par litre, Parts par gâteau, Recette, Consommation par personne et par jour | Écran Menus : crée un nouveau menu (étape P7) |
| Stock de départ | Gymnase, Produit, Quantité | Préparation : stock de départ de l'événement (P6) |
| Historique | Événement, Gymnase, Personnes, Jours, Produit, Quantité vendue | Préparation : crée une référence de consommation nommée (P6) |
| Courses | Série, Produit ou ligne libre, Quantité achetée, Coût | Ignorée (sortie seulement) |
| Bilan (export seulement) | Les rubriques de l'ancien CSV | Ignorée |

**Étapes** (une à la fois, dans l'ordre ; chaque critère est vérifié par un test de code ou sur émulateur)

| # | Étape | Ce que Kinder voit | Critères (test de code) |
|---|---|---|---|
| P1 | État « En préparation » (décision 60) | Pastille « En préparation » ; bouton « Ouvrir l'événement » | (1) un événement neuf est « En préparation » ; (2) un bénévole ne le voit pas ; (3) aucune caisse ne s'y ouvre, ni par l'application ni en contournant (règles) ; (4) « Ouvrir l'événement » le passe « En cours » et le bénévole le voit ; (5) seul le responsable ou un gestionnaire rattaché à tous les gymnases l'ouvre (comme la clôture) ; (6) un événement créé avant P1 reste « En cours » ; (7) les restes gardés sont toujours repris à la création |
| P2 | Onglet Préparation et stock de départ (décisions 53, 54) | Onglet « Préparation » en trois étapes ; étape 1 : quantité par gymnase et produit fini | (1) l'onglet existe pour la gestion, pas pour un bénévole ; (2) 24 sodas saisis au gymnase A : « Gymnases et stocks » affiche 24 ; (3) un reste repris est pré-rempli, marqué « repris de l'événement précédent », corrigeable ; (4) aucun ingrédient dans la liste ; (5) un gestionnaire ne voit que ses gymnases ; (6) une fois l'événement ouvert, le stock de départ se lit seulement et renvoie vers « Gymnases et stocks » |
| P3 | Personnes et durée (décision 55) | Étape 2 de la Préparation : personnes par gymnase, durée de l'événement | (1) 80 personnes au gymnase A et 2 jours réglés dans la Préparation : Courses affiche et utilise 80 et 2 ; (2) Courses n'a plus de champ « personnes » ; (3) le choix « demi-journée / jour complet / plus » des courses reste, propose « tout l'événement » par défaut, et ne change pas la durée de l'événement ; (4) durée refusée hors 0,5 à 30 jours, personnes hors 0 à la limite actuelle |
| P4 | Prévision à sources (décision 56) | Tableau produit / consommation / source ; bouton « D'après un événement passé » | (1) par défaut, les chiffres du menu, source « Menu » ; (2) événement passé où 160 croques ont été vendus pour 40 personnes en 2 jours : 2,0 par personne et par jour, source affichée ; (3) un produit absent de la source garde le chiffre du menu ; (4) un chiffre corrigé reste, source « modifié à la main », le menu ne change pas ; (5) un événement passé sans personnes réglées n'est pas proposé (message) ; (6) ventes annulées exclues ; (7) les courses calculent avec ces chiffres (80 personnes × 2 jours × 2,0 = 320, moins le stock) |
| P5 | Télécharger le modèle (décision 57) | Bouton « Télécharger le modèle Excel » dans la Préparation | (1) un `.xlsx` part par la feuille de partage et s'ouvre avec les feuilles Menu, Stock de départ, Historique, Courses ; (2) Menu contient les produits de l'événement, Stock de départ ses gymnases et produits ; (3) relu par l'application, le fichier donne exactement les mêmes données (aller-retour) ; (4) accents et virgules décimales lisibles dans Excel |
| P6 | Importer dans la Préparation (décisions 56, 57) | Bouton « Importer un classeur » : choix du fichier, résumé, « Appliquer » | (1) le résumé annonce n stocks et la référence « nom (Excel) » AVANT d'appliquer ; (2) après « Appliquer », le stock de départ est celui du fichier ; (3) la référence apparaît dans les sources de la prévision, avec le chiffre calculé comme en P4 ; (4) un produit ou gymnase inconnu est listé « ignoré », le reste s'applique ; (5) un fichier illisible ou d'un autre format : message clair, rien n'est appliqué ; (6) aucune vente créée, bilans inchangés |
| P7 | Importer un menu (décision 57) | Écran Menus : « Importer un menu depuis Excel » | (1) la feuille Menu d'un classeur crée un nouveau menu avec types, prix, recettes, ratios et consommations ; (2) une ligne invalide (prix négatif, type inconnu) est listée et ignorée ; (3) le menu importé crée un événement sans erreur |
| P8 | Export complet du tournoi (décision 57) | Bilan : « Exporter (Excel) » remplace « Exporter (CSV) » | (1) le classeur contient Menu, Stock de départ, Historique (personnes, jours, quantités vendues de cet événement), Courses (séries, achats, coût, lignes libres) et Bilan ; (2) les chiffres du Bilan égalent ceux de l'écran (comparés à un calcul fait à la main) ; (3) réimporté dans un nouvel événement, il donne la même consommation que la source « événement passé » ; (4) l'ancien export CSV a disparu |
| P9 | Import de l'an passé (décision 58) | La référence « Tournoi de l'an passé (Excel) » dans la prévision | Préalable : le fichier de Kinder déposé dans le projet. (1) Claude Code produit le classeur rempli d'après ce fichier, avec un relevé de ce qui a été repris et de ce qui ne l'a pas été ; (2) importé sur émulateur sans erreur ; (3) consommations égales au calcul à la main noté dans le relevé |
| P10 | Apports nommés (décision 59) | Bénévole : « Ajouter un apport » (nom, parts) ; bilan : rubrique « Apports » | (1) « Quiche, 8 parts » ajoutée à « Gâteau salé » : stock +8 ; (2) la caisse vend « Gâteau salé » comme avant ; (3) le bilan et l'export listent « Quiche, 8 parts, prénom, gymnase » ; (4) nom vide ou parts hors 1 à 1000 refusés (application et règles) |
| P11 | Clôture de mission | Texte de vérification et parcours complet | (1) parcours automatique du critère de fin sur émulateur (créer, télécharger, importer, préparer, corriger, courses, ouvrir, vendre, clôturer, exporter) ; (2) texte de vérification rédigé pour une autre IA ; (3) APK de recette reconstruit, version 1.2.0 |

**Dépendances entre étapes** : P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10 → P11. P2 a besoin de l'état « En préparation » ; P4 des personnes et de la durée ; P5 à P8 du format du classeur ; P9 de l'import (P6) et du fichier de Kinder ; P10 est indépendante mais placée après pour ne pas mêler deux chantiers ; P11 en dernier.

**Arrêts prévus** : P9 si le fichier de Kinder manque ; toute contradiction avec une décision figée ; deux échecs de suite à la vérification.

**Suivi** (une ligne par étape close)

| Étape | État | Date | Critères |
|---|---|---|---|
| P1 | Close (testée par Claude) | 06/11/2026 | 1 à 7 réussis : règles 197/197 (10 nouveaux, `preparation.test.mjs`), `flutter test` 252/252, `flutter analyze` sans erreur, parcours Android LC2 `evenements_test` + `restes_test` 2/2. Règles déployées le 06/11/2026. Limite : le bouton « Ouvrir l'événement » est testé en logique et dans le parcours `evenements_test`, pas en test d'écran isolé |
| P2 | Close (testée par Claude) | 06/11/2026 | 1 à 6 réussis : règles 204/204 (7 nouveaux, `stock_depart.test.mjs`), `flutter test` 261/261, analyse sans erreur, parcours Android LC2 `preparation_test` + `restes_test` + `gymnases_test` + `evenements_test` 4/4. Règles (champ `repris`) déployées le 06/11/2026 |
| P3 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : `flutter test` 269/269 (8 nouveaux : limites de durée et de personnes, lecture seule), analyse sans erreur, règles inchangées (204/204 à P2), parcours Android LC2 `preparation_test` + `courses_test` + `chantier_complet_test` + `recette_test` 6/6 (80 personnes et 2 jours réglés dans la Préparation, Courses lit 80 et 2 et calcule 320 ; « Jour complet » dans Courses : durée de l'événement toujours 2). Limite : l'absence du champ « personnes » dans Courses est constatée par le parcours Android, pas par un test d'écran isolé (pas de faux Firestore) |
| P4 | Close (testée par Claude) | 07/11/2026 | 1 à 7 réussis : `flutter test` 293/293 (24 nouveaux), règles 215/215 (11 nouveaux, `previsions.test.mjs`), analyse sans erreur, parcours Android LC2 7/7 (`previsions_test` : 160 ÷ 40 ÷ 2 = 2,0 avec une vente annulée exclue, produit absent = menu, correction à la main, événement sans personnes non proposé, Courses 80 × 2 × 2,0 − 20 = 300 ; + preparation, courses, parametres, chantier_complet). Règles déployées le 07/11/2026. Points connus : écriture par groupes de 10 (non atomique au-delà, rejouable) ; un produit présent dans l'événement passé sans vente prend 0 ; lecture réservée à ceux qui lancent les courses |
| P5 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : `flutter test` 310/310 (17 nouveaux, dont l'aller-retour sur un menu riche), analyse sans erreur, règles inchangées (215/215), parcours Android LC2 3/3 (`classeur_test`, `preparation_test`). Dépendance : `excel` 4.0.6 (version exacte). Limite : le fichier n'a pas été ouvert dans l'application Excel, il est relu par la bibliothèque |
| P6 | Close (testée par Claude) | 07/11/2026 | 1 à 6 réussis : `flutter test` 352/352, règles 230/230 (15 nouveaux, collection `references`), analyse sans erreur, parcours Android LC2 `import_test` + `preparation_test` 3/3 (après correction) et `previsions_test`, `classeur_test`, `parametres_test` verts avant correction. Dépendance : `file_picker` 11.0.3 (exacte ; les versions 12 et 13 sont incompatibles avec `share_plus` 10.1.4). Règles déployées le 07/11/2026. Décision de mise en œuvre : une fois l'événement ouvert, l'import n'écrit plus de stock (lignes « ignorées »), seules les références s'importent. Limites : le sélecteur système n'est pas piloté par les tests (octets fournis) ; les règles `references` valident les 12 premières lignes une à une (limite de 1000 expressions), l'application écarte les lignes hors format |
| P7 | Close (testée par Claude) | 07/11/2026 | 1 à 3 réussis : `flutter test` 366/366 (14 nouveaux, `import_menu_test`), analyse sans erreur, règles inchangées (230/230), parcours Android LC2 `import_menu_test` + `menus_test` + `import_test` + `preparation_test` 4/4 (menu de 4 produits valides + 2 lignes invalides listées, événement créé depuis ce menu, relecture des produits). Limite : sélecteur système non piloté (octets fournis) |
| P8 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : `flutter test` 375/375 (calcul à la main du Bilan : 22,00 € en 5 ventes dont 1 annulée exclue, coût 35 = 25 + 10, résultat −13 ; réimport = mêmes consommations que la source « événement passé » ; plus aucune trace du CSV), analyse sans erreur, règles et dépendances inchangées, parcours Android LC2 6/6 (`export_test`, `chantier_complet_test`, `courses_test`, `bilan_test`, `recette_test`). Limites : le détail des séries de courses précédentes n'est pas conservé par l'application (cumul seulement) ; un gestionnaire partiel obtient une feuille Courses réduite à un message ; ouverture dans l'application Excel non testée (relu par la bibliothèque) |

### Cadrage P1 — État « En préparation » (phase 5, 06/11/2026)

**Critères du plan, repris tels quels** : (1) un événement neuf est « En préparation » ; (2) un bénévole ne le voit pas ; (3) aucune caisse ne s'y ouvre, ni par l'application ni en contournant (règles) ; (4) « Ouvrir l'événement » le passe « En cours » et le bénévole le voit ; (5) seul le responsable ou un gestionnaire rattaché à tous les gymnases l'ouvre (comme la clôture) ; (6) un événement créé avant P1 reste « En cours » ; (7) les restes gardés sont toujours repris à la création.

**Stratégie**
- Nouveau statut stocké `en_preparation` (les anciens documents gardent `en_cours`, aucune migration). `Evenement` gagne `enPreparation` et `cloture` ; `enCours` reste « statut == en_cours ». Chaque usage actuel de `!ev.enCours` (= « clôturé ») est relu et remplacé par `ev.cloture`.
- Règles d'accès : une fonction `reglable(a, e)` (statut `en_preparation` OU `en_cours`) remplace `statut == 'en_cours'` pour tout ce que fait la GESTION (modifier nom/date/modes, durée, gymnases et personnes, produits, stocks réglés par la gestion, suppression de stock, courses, rattachements), afin que P2 à P4 puissent écrire avant l'ouverture. Restent en `en_cours` seulement : lecture par les bénévoles, ouverture de caisse, pointeur `ouvertes`, ventes, annulations, signaux « vide », ajouts de parts et ventes sur le stock (branches caisse), clôture de l'événement, création de restes.
- Création : `statut == 'en_preparation'` exigé (plus `en_cours`). Les créations de produits, gymnases et stocks (même lot) testent `reglable` sur `getAfter`.
- Ouverture : nouvelle règle de mise à jour, `gereTout`, `resource.statut == 'en_preparation'`, seuls `statut` (= `en_cours`) et `ouvertLe` (horodatage) changent. Pas de retour en arrière.
- Application : `creerEvenement` écrit `en_preparation` ; nouvelle méthode `ouvrirEvenement(id)` ; pastille à trois états (« En préparation » en couleur d'attention, « En cours », « Clôturé ») ; bouton « Ouvrir l'événement » (clé `ouvrir_evenement`) visible seulement pour la gestion qui peut (responsable ou rattaché à tous les gymnases) quand l'événement est en préparation, avec confirmation en une phrase ; boutons de caisse, clôture et suivi en direct seulement « En cours » ; tri de la liste : en cours, en préparation, clôturés. Un bénévole n'a déjà que `where statut == en_cours` : rien à changer côté requête.
- Tests existants : les assistants de test qui créent un événement pour ouvrir des caisses l'ouvrent ensuite (`ouvrirEvenement` ou écriture directe en en_cours côté règles via contournement des règles), sans changer leur objet.

**Fichiers touchés** : `firestore.rules`, `lib/evenement.dart`, `lib/depot_evenements.dart`, `lib/ecran_evenement.dart`, `lib/ecran_association.dart` (pastille de la liste), `lib/ecran_bilan.dart` et `lib/export_bilan.dart` (usages de `enCours`), `tests_regles/evenements.test.mjs` (+ nouveau `tests_regles/preparation.test.mjs`), `tests_regles/outilsCaisse.mjs`, `tests_regles/gestionnaires.test.mjs`, `test/evenement_test.dart` (+ tests voisins qui construisent un `Evenement`), `integration_test/outils.dart` et les parcours qui créent un événement.

**Ce qu'on ne fait pas** : pas d'onglet Préparation ni de stock de départ (P2) ; pas de retour d'un événement ouvert vers « En préparation » ; pas de clôture depuis « En préparation » ; pas de changement des restes ni des caisses ; aucune dépendance.

**Test de chaque critère** : règles (`tests_regles/lancer.ps1`) pour 1, 2, 3, 4, 5, 6 (document sans état `en_preparation` resté ouvert aux caisses) ; test d'écran/logique (`flutter test`) pour la pastille, le bouton selon le rôle, le tri ; parcours Android sur LC2 pour 1, 4 et 7 (création → reprise des restes → ouverture → un bénévole voit l'événement). Règles déployées dès que leurs tests passent.

### Cadrage P2 — Onglet Préparation et stock de départ (phase 5, 06/11/2026)

**Critères du plan, repris tels quels** : (1) l'onglet existe pour la gestion, pas pour un bénévole ; (2) 24 sodas saisis au gymnase A : « Gymnases et stocks » affiche 24 ; (3) un reste repris est pré-rempli, marqué « repris de l'événement précédent », corrigeable ; (4) aucun ingrédient dans la liste ; (5) un gestionnaire ne voit que ses gymnases ; (6) une fois l'événement ouvert, le stock de départ se lit seulement et renvoie vers « Gymnases et stocks ».

**Stratégie**
- Dans le bloc de gestion de l'événement (déjà réservé à la gestion : un bénévole ne le voit pas), un bouton « Préparation » (clé `voir_preparation`) placé avant « Gymnases et stocks », visible tant que l'événement n'est pas clôturé. Il ouvre un nouvel écran `EcranPreparation` : titre, puis des étapes numérotées. P2 n'ajoute que l'étape 1 « Stock de départ » ; P3 et P4 ajouteront les étapes 2 et 3 (rien n'est affiché pour elles avant).
- Étape 1 : une carte par gymnase de la portée (`PorteeGestion.gere`), avec la liste des produits finis de l'événement (la liste `produits` de l'événement ne contient déjà jamais d'ingrédient : ils vivent dans les recettes), chacun avec un champ de quantité entière 0 à 100 000 ; saisie = `definirStock` (même écriture que « Gymnases et stocks », donc les deux écrans montrent le même chiffre). Produit sans quantité = non suivi ; bouton « Suivre tous » à zéro réutilisé. Pas de nouvelle structure de données pour le stock.
- Marque « repris de l'événement précédent » : le stock posé par `repriseDesRestes` à la création gagne un champ booléen `repris: true` (écrit par `creerEvenement`). Toute correction du chiffre (`definirStock`, qui remplace le document) efface la marque. Règles d'accès sur `stocks` : `repris` accepté (booléen `true` seulement) à la création et dans les champs modifiables par la gestion de ce gymnase (`affectedKeys` autorise `repris`, valeur absente ou `true`) ; les branches caisse (vente, annulation, ajout de parts) ne le touchent pas. L'étiquette « Repris de l'événement précédent » s'affiche sous le produit tant que la marque existe.
- Événement « En cours » ou clôturé : l'étape 1 est en lecture seule (chiffres sans champ de saisie) avec un bouton « Voir Gymnases et stocks » (clé `aller_gymnases_stocks`) ; en préparation : saisie.
- Flux de lecture : mêmes flux partagés que « Gymnases et stocks » (`suivreProduits`, `suivreStocksParGymnase`) pour ne pas augmenter les lectures ; ajouter `repris` à ce que lit `_lireStocks` (objet stock : quantité, référence, repris) sans casser les usages existants.

**Fichiers touchés** : nouveau `lib/ecran_preparation.dart`, `lib/ecran_evenement.dart` (bouton), `lib/depot_evenements.dart` (champ `repris`, `creerEvenement`, lecture), `firestore.rules`, `tests_regles/preparation.test.mjs` (ou nouveau `tests_regles/stock_depart.test.mjs` inscrit dans `lancer.ps1`), `test/preparation_test.dart` (nouveau), `integration_test/preparation_test.dart` (nouveau parcours), éventuels tests voisins touchés par le changement de lecture.

**Ce qu'on ne fait pas** : personnes et durée (P3), prévision (P4), Excel (P5 et suivantes) ; pas de stock d'ingrédients (décision 54) ; pas de changement de « Gymnases et stocks » ni des courses ; pas de nouvelle dépendance.

**Test de chaque critère** : règles pour la marque `repris` (création, correction, refus d'une valeur autre que `true`, branches caisse intactes) ; `flutter test` pour 1 (bouton absent hors gestion), 4 (liste = produits finis, sans ingrédient), 5 (portée), 6 (lecture seule + lien) et l'étiquette ; parcours Android LC2 pour 2 (24 sodas saisis dans la Préparation, relus dans « Gymnases et stocks ») et 3 (reste gardé à la clôture d'un événement, repris à la création, étiquette visible, corrigé, étiquette disparue).

### Cadrage P3 — Personnes et durée (phase 5, 06/11/2026)

**Critères du plan, repris tels quels** : (1) 80 personnes au gymnase A et 2 jours réglés dans la Préparation : Courses affiche et utilise 80 et 2 ; (2) Courses n'a plus de champ « personnes » ; (3) le choix « demi-journée / jour complet / plus » des courses reste, propose « tout l'événement » par défaut, et ne change pas la durée de l'événement ; (4) durée refusée hors 0,5 à 30 jours, personnes hors 0 à la limite actuelle.

**Stratégie**
- `EcranPreparation` (P2) gagne l'étape 2 « Personnes et durée », sous l'étape 1 : un champ « Durée de l'événement (jours) » (nombre, virgule ou point, 0,5 à 30) enregistré par `definirJours`, et un champ « Personnes attendues » par gymnase de la portée, entier 0 à `personnesMax` (1000), enregistré par `definirPersonnes`. Même mécanique d'enregistrement que l'étape 1 (à la validation, à la sortie du champ, ou après 0,9 s), même indication « Enregistré ». Valeur hors limites : message sous le champ, rien n'est écrit.
- Qui règle : les règles actuelles exigent `gereTout` (responsable, ou gestionnaire rattaché à tous les gymnases) pour la durée et les personnes. Les autres gestionnaires voient l'étape 2 en lecture seule avec une phrase d'explication. Événement clôturé : lecture seule. Ouvert (« En cours ») : toujours modifiable par ceux qui y ont droit (les courses peuvent encore se lancer). Aucun changement de règles : pas de déploiement.
- Courses (`lib/ecran_courses.dart`) : le champ « Personnes attendues » disparaît ; à la place, une ligne de lecture « Personnes attendues : n » (par gymnase) avec la mention « réglé dans la Préparation ». Le choix de durée devient local à l'écran : quatre choix « Tout l'événement » (par défaut, = durée de l'événement), « Demi-journée » (0,5), « Jour complet » (1), « Plus » (champ du nombre de jours, 2 à 30). Il ne s'écrit plus jamais dans l'événement (`definirJours` n'est plus appelé depuis Courses). Il n'est pas mémorisé : l'écran rouvre sur « Tout l'événement » ; la liste enregistrée garde ses quantités. « Recalculer » utilise les personnes de la Préparation et la durée choisie.
- Si les personnes sont toutes à 0, le message d'aide de Courses renvoie vers la Préparation (bouton « Aller à la Préparation »).

**Fichiers touchés** : `lib/ecran_preparation.dart`, `lib/ecran_courses.dart`, `lib/courses.dart` si besoin (aucune logique de calcul ne change), tests de courses existants à adapter (`test/courses_test.dart`, `integration_test/courses_test.dart`, `integration_test/chantier_complet_test.dart`, `integration_test/recette_test.dart` et tout parcours qui saisit des personnes dans Courses : ils règlent désormais personnes et durée par la Préparation ou directement par le dépôt), nouveaux tests dans `test/preparation_test.dart` et `integration_test/preparation_test.dart`.

**Ce qu'on ne fait pas** : prévision par source (P4), Excel, aucun changement de règles ni de données ; la durée choisie dans Courses n'est pas enregistrée ; pas de nouvelle dépendance.

**Test de chaque critère** : parcours Android LC2 pour 1 (80 personnes et 2 jours réglés dans la Préparation, Courses affiche 80 et 2 et en calcule la liste) et 3 (choix « Jour complet » dans Courses, puis durée de l'événement relue : toujours 2) ; `flutter test` pour 2 (aucun champ `personnes_…` dans Courses), 4 (0,4 et 31 refusés, 0,5 et 30 acceptés ; 1001 et −1 refusés, 0 et 1000 acceptés) et l'étape 2 en lecture seule hors `gereTout`.

### Cadrage P4 — Prévision à sources (phase 5, 07/11/2026)

**Critères du plan, repris tels quels** : (1) par défaut, les chiffres du menu, source « Menu » ; (2) événement passé où 160 croques ont été vendus pour 40 personnes en 2 jours : 2,0 par personne et par jour, source affichée ; (3) un produit absent de la source garde le chiffre du menu ; (4) un chiffre corrigé reste, source « modifié à la main », le menu ne change pas ; (5) un événement passé sans personnes réglées n'est pas proposé (message) ; (6) ventes annulées exclues ; (7) les courses calculent avec ces chiffres (80 personnes × 2 jours × 2,0 = 320, moins le stock).

**Stratégie**
- Donnée : sous-collection `evenements/{e}/previsions/{produitId}` = `{conso: nombre 0 à 1000, source: texte 1 à 80}`. Document absent = chiffre du menu (`fiche.conso` du produit de l'événement), source affichée « Menu ». Le menu et le produit de l'événement ne changent jamais.
- Logique pure (`lib/previsions.dart`, nouveau, testable sans Firestore) : `PrevisionProduit {produitId, nom, conso, source}` ; `consoDepuisEvenement(...)` = ventes non annulées du produit ÷ personnes totales de l'événement passé (somme des gymnases) ÷ durée (`nbJours`) ; produit retrouvé par son NOM (clé sans casse ni accents, `cleIngredient`, comme le report de stock) ; `fusionnerPrevisions(produits, previsions)`. Le comptage des ventes réutilise le tableau de bord existant (`suivreTableauDeBord`, qui exclut déjà les ventes annulées, vérifier par un test).
- Source « événement passé » : liste des événements clôturés de l'association dont la somme des personnes réglées est > 0 (et durée connue) ; ceux sans personnes réglées ne sont pas proposés, avec le message « Les événements passés sans nombre de personnes réglé ne peuvent pas servir de référence. ». Choisir un événement applique d'un coup : produits trouvés = chiffre calculé, source « Événement : <nom> » ; produits absents = retour au menu (document supprimé). Un bouton « Revenir au menu » remet tout au chiffre du menu. Les deux actions demandent une confirmation en une phrase si des chiffres corrigés à la main existent.
- Étape 3 de `EcranPreparation` (après l'étape 2) : tableau « Produit / Consommation par personne et par jour / Source » ; chaque chiffre est un champ décimal (virgule ou point, 0 à 1000, enregistrement comme les étapes 1 et 2) ; une correction enregistre `{conso, source: 'Modifié à la main'}` ; un champ vidé ou non valide n'écrit rien ; bouton « D'après un événement passé ». Écriture réservée à ceux qui ont `gereTout` ; lecture seule (avec phrase) pour les autres gestionnaires et pour un événement clôturé. Aussi lisible/modifiable quand l'événement est « En cours ».
- Courses (`lib/ecran_courses.dart`) : charge les prévisions et calcule avec `conso` effective (prévision sinon menu) dans `listeParDefaut`/`_recalculer`/`_cocher` ; `lib/courses.dart` ne change que pour prendre la consommation effective (par exemple en passant des `ProduitEvenement` dont la fiche est copiée avec la consommation de la prévision : ajouter un `avecConso` sur `ProduitEvenement`). Aucune autre logique de calcul ne change.
- Règles d'accès : `match /previsions/{p}` dans l'événement : lecture `gereTout` ; création/mise à jour/suppression `gereTout` et `reglable` (événement en préparation ou en cours), champs exactement `conso`, `source` (types et bornes ci-dessus), `p` = identifiant d'un produit de l'événement existant ; suppression aussi permise par `suppressionEnCours`. Suppression d'une association : `lib/depot_associations.dart` efface aussi cette sous-collection. Déployées dès que leurs tests passent.

**Fichiers touchés** : nouveau `lib/previsions.dart`, `lib/depot_evenements.dart` (flux et écritures des prévisions, liste des événements passés utilisables, calcul), `lib/evenement.dart` (`avecConso`), `lib/ecran_preparation.dart`, `lib/ecran_courses.dart`, `lib/courses.dart` si besoin, `lib/depot_associations.dart` (suppression), `firestore.rules`, `tests_regles/` (nouveau fichier inscrit dans `lancer.ps1`), `test/previsions_test.dart`, `test/preparation_test.dart`, `integration_test/previsions_test.dart` (nouveau parcours) et tout test de suppression d'association à compléter.

**Ce qu'on ne fait pas** : source Excel / référence importée (P6), modèle et export Excel (P5, P8), changement du menu ou du produit de l'événement, prévision automatique sans action de la gestion, nouvelle dépendance. Une source ne s'applique qu'au clic.

**Test de chaque critère** : `flutter test` pour 1, 2 (160 ÷ 40 ÷ 2 = 2,0), 3, 5, 6, et le calcul de 7 ; règles pour les bornes, les droits et la suppression ; parcours Android LC2 pour 2 à 7 de bout en bout (un événement passé clôturé avec ventes dont une annulée, un neuf, choix de la source, correction à la main, menu relu inchangé, Courses calcule 80 × 2 × 2,0 = 320 moins le stock).

### Cadrage P5 — Télécharger le modèle Excel (phase 5, 07/11/2026)

**Critères du plan, repris tels quels** : (1) un `.xlsx` part par la feuille de partage et s'ouvre avec les feuilles Menu, Stock de départ, Historique, Courses ; (2) Menu contient les produits de l'événement, Stock de départ ses gymnases et produits ; (3) relu par l'application, le fichier donne exactement les mêmes données (aller-retour) ; (4) accents et virgules décimales lisibles dans Excel.

**Stratégie**
- Dépendance accordée par Kinder : UNE bibliothèque Excel (lecture et écriture de `.xlsx`, Dart pur, sans code natif), la dernière version stable publiée depuis plus de deux semaines, version EXACTE dans `pubspec.yaml` (comme `share_plus: 10.1.4`). La bibliothèque pour choisir un fichier (autre dépendance accordée) n'est ajoutée qu'en P6. Aucune autre.
- Logique pure, sans Firestore, dans `lib/classeur.dart` (nouveau) : (a) `construireModele(...)` → octets du classeur ; (b) `lireClasseur(octets)` → `ClasseurLu` (lignes typées de chaque feuille + liste d'avertissements/erreurs de lecture par ligne) ; elles partagent les mêmes constantes de feuilles et d'en-têtes. Format de la décision 57 : feuilles `Menu`, `Stock de départ`, `Historique`, `Courses` ; sur chaque feuille ligne 1 = phrase d'aide (en français, dit à quoi sert la feuille), ligne 2 = en-têtes exacts ; données dès la ligne 3. En-têtes : Menu = Produit, Prix, Type, Provenance, Verres par litre, Parts par gâteau, Recette, Consommation par personne et par jour ; Stock de départ = Gymnase, Produit, Quantité ; Historique = Événement, Gymnase, Personnes, Jours, Produit, Quantité vendue ; Courses = Série, Produit ou ligne libre, Quantité achetée, Coût. La feuille Bilan n'existe pas au modèle (export seulement, P8).
- Menu : une ligne par produit de l'événement (nom, prix en euros en cellule numérique, type et provenance en clair français — mêmes libellés que l'écran du menu —, verres par litre, parts par gâteau, consommation en cellules numériques ou vides). Recette = texte lisible et relisible : ingrédients séparés par « ; », chacun écrit « quantité unité nom » (unité prise dans la liste fixe des unités du menu ; quantité avec virgule décimale ; un « ; » dans un nom d'ingrédient est refusé à la lecture et remplacé par une virgule à l'écriture). La consommation écrite est celle du MENU (fiche du produit), pas la prévision.
- Stock de départ : une ligne par gymnase de la portée × produit de l'événement, avec la quantité actuelle (cellule vide si le produit n'est pas suivi dans ce gymnase). Historique et Courses : seulement l'aide et les en-têtes (le modèle est à remplir ; les données arrivent en P8 pour l'export).
- Aller-retour : `lireClasseur(construireModele(x))` rend exactement les produits (nom, prix en centimes, type, provenance, ratios, recette, consommation) et les stocks (gymnase, produit, quantité ou vide) de départ ; les noms se comparent par la clé sans casse ni accents (`cleIngredient`) mais sont conservés tels qu'écrits. Lecture tolérante : feuille ou colonne manquante = erreur claire (« Feuille « Menu » introuvable »), ligne vide ignorée, cellule texte avec virgule décimale (« 1,5 ») comprise, nombre avec espaces.
- Partage : `lib/partage.dart` gagne un `PartageurOctets` / `partagerFichier(nom, octets, mime)` (type MIME `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`) ; le partage de texte existant reste. Nom du fichier : `modele-<événement>-<date>.xlsx` (même assainissement que le nom du CSV du bilan).
- Interface : `EcranPreparation` gagne, en tête de page, une carte « Classeur Excel » avec le bouton « Télécharger le modèle Excel » (clé `telecharger_modele`) et une phrase d'explication ; le partageur est injectable dans l'écran (comme pour Courses) pour les tests. Échec d'ouverture de la feuille de partage : message « Le partage n'a pas pu s'ouvrir. Réessayez. ». Visible pour toute la gestion ; un gestionnaire partiel n'obtient que ses gymnases.

**Fichiers touchés** : `pubspec.yaml` (+ `pubspec.lock`), nouveau `lib/classeur.dart`, `lib/partage.dart`, `lib/ecran_preparation.dart`, `lib/ecran_evenement.dart` (passage du partageur si nécessaire), `test/classeur_test.dart` (nouveau), `test/preparation_test.dart`, `integration_test/preparation_test.dart` ou nouveau `integration_test/classeur_test.dart` (parcours avec partageur factice qui relit les octets reçus).

**Ce qu'on ne fait pas** : aucune importation (P6, P7), aucune donnée dans Historique/Courses (P8), pas de feuille Bilan, pas de choix de fichier, pas de changement de règles Firestore ni de modèle de données, pas de CSV supprimé (P8).

**Test de chaque critère** : `flutter test` pour 1 (octets d'un zip valide « PK », quatre feuilles dans l'ordre), 2, 3 (aller-retour sur un menu riche : composé avec recette, litre, part, apporté, accents, prix 2,50 €, consommation 0,75), 4 (accents dans les noms, virgule décimale d'un texte lue, prix numériques) ; parcours Android LC2 : bouton → partageur factice reçoit un `.xlsx` dont la relecture égale les produits et stocks de l'événement affichés. Limite connue à annoncer au bilan : l'ouverture réelle dans l'application Excel n'est pas testable ici (le fichier est relu par la bibliothèque et son format vérifié).

### Cadrage P6 — Importer dans la Préparation (phase 5, 07/11/2026)

**Critères du plan, repris tels quels** : (1) le résumé annonce n stocks et la référence « nom (Excel) » AVANT d'appliquer ; (2) après « Appliquer », le stock de départ est celui du fichier ; (3) la référence apparaît dans les sources de la prévision, avec le chiffre calculé comme en P4 ; (4) un produit ou gymnase inconnu est listé « ignoré », le reste s'applique ; (5) un fichier illisible ou d'un autre format : message clair, rien n'est appliqué ; (6) aucune vente créée, bilans inchangés.

**Stratégie**
- Dépendance accordée par Kinder : UNE bibliothèque pour choisir un fichier (par ex. `file_picker`), version stable publiée depuis plus de deux semaines, version EXACTE dans `pubspec.yaml`, compatible Android et avec la version de Flutter du projet, qui ne demande pas de permission de stockage dangereuse (sélecteur système). Seconde et dernière dépendance de la mission. Le sélecteur est injectable dans l'écran (`choisirClasseur`: rend les octets ou `null` si annulé), comme le partageur ; les tests lui fournissent des octets.
- Référence de consommation nommée : stockée au niveau de l'ASSOCIATION (réutilisable d'un événement à l'autre, donc d'une année sur l'autre) : `associations/{a}/references/{id}` = `{nom: texte 1–60, lignes: liste de {nom: texte 1–40, conso: nombre 0–1000}, creeLe: horodatage}` ; `id` = clé normalisée du nom (minuscules sans accents, `[a-z0-9_-]`, 1–100) : réimporter le même nom remplace la référence (idempotent). Règles : lecture et écriture par la gestion de l'association (responsable ou gestionnaire), `lignes` liste ≤ 200 ; suppression par la gestion, et par `suppressionEnCours` ; la suppression d'une association (`lib/depot_associations.dart`) efface aussi cette collection.
- Calcul d'une référence depuis la feuille Historique : une référence PAR événement distinct (colonne Événement), nommée « <Événement> (Excel) » ; pour chaque produit (clé normalisée, nom conservé tel qu'écrit) : somme des quantités vendues ÷ personnes de l'événement ÷ jours, où personnes = somme des personnes des gymnases distincts (la valeur d'un gymnase est répétée sur ses lignes : on la prend une fois) et jours = valeur commune à l'événement. Valeurs contradictoires, personnes totales = 0 ou jours hors 0,5 à 30 : l'événement n'est pas retenu et l'erreur est dite (même règle que P4 : une référence sans personnes n'est pas proposée). Même formule exacte que P4 (logique commune dans `lib/previsions.dart`, ne pas dupliquer).
- Sources de la prévision (étape 3 de la Préparation) : la liste « D'après un événement passé » devient « D'après une source » : événements clôturés utilisables (comme P4) PUIS références importées ; choisir une référence applique les chiffres par nom de produit (trouvé = chiffre de la référence, absent = retour au menu, comme P4), source affichée = le nom de la référence, par exemple « Tournoi 2025 (Excel) ».
- Stock de départ (feuille « Stock de départ ») : chaque ligne retrouve gymnase et produit par leur nom normalisé dans l'événement ; trouvé et quantité renseignée (entier 0 à 100 000) = écrit comme la saisie à la main (`definirStock`, la marque « repris » disparaît) ; quantité vide = ligne ignorée sans erreur ; gymnase ou produit inconnu, quantité invalide ou gymnase hors de la portée du gestionnaire (partiel) = ligne listée « ignorée » avec la raison ; le reste s'applique. Événement clôturé : l'import est refusé (bouton absent). Feuille Menu : ignorée par cet import (elle sert à l'écran Menus, P7), signalée dans le résumé. Feuilles Courses et Bilan : ignorées.
- Interface : sur la carte « Classeur Excel » de `EcranPreparation`, bouton « Importer un classeur » (clé `importer_classeur`) → sélecteur de fichier → lecture (`lireClasseur`) → écran/feuille de RÉSUMÉ avant toute écriture : « N stocks seront appliqués », « Référence créée : <nom> (Excel) — k produits » (une ligne par référence), liste des lignes ignorées avec raison (repliable au-delà de 10), erreurs de lecture ; boutons « Appliquer » (clé `appliquer_import`) et « Annuler ». Rien n'est écrit tant que « Appliquer » n'est pas touché. Fichier illisible (`ClasseurIllisible`) ou ne contenant aucune des feuilles Stock de départ / Historique avec données : message « Ce fichier n'est pas un classeur Le Comptoir lisible. Téléchargez le modèle, remplissez-le, puis réessayez. », aucun résumé, rien d'écrit. Après « Appliquer » : bandeau de confirmation (« Stocks appliqués : n. Références enregistrées : … »).
- Aucune vente ni autre donnée de bilan n'est créée ; les écritures sont des stocks et des références seulement. Écritures par lots ≤ 400 documents ; une erreur à l'écriture est dite et l'import peut être rejoué sans risque (idempotent).

**Fichiers touchés** : `pubspec.yaml` (+ `pubspec.lock`), `lib/classeur.dart` (aide au résumé si besoin), `lib/previsions.dart` (formule commune, calcul d'une référence), `lib/depot_evenements.dart` ou nouveau dépôt de références, `lib/depot_associations.dart` (suppression), `lib/ecran_preparation.dart`, `lib/ecran_evenement.dart` (câblage), `firestore.rules`, `tests_regles/` (nouveau fichier inscrit dans `lancer.ps1` : droits, bornes, remplacement, suppression d'association), `test/` (résumé, formule, import, erreurs), `integration_test/` (nouveau parcours d'import : classeur construit par `construireModele`/octets de test, sélecteur factice).

**Ce qu'on ne fait pas** : import de la feuille Menu (P7), export (P8), classeur de Kinder (P9), choix de fichier réel du système dans les tests (non pilotable ici), suppression/gestion visuelle des références (hors périmètre, listées seulement comme sources), nouvelle dépendance autre que le sélecteur.

**Test de chaque critère** : `flutter test` pour 1 (résumé exact avant écriture : n stocks et nom de référence), 4, 5, formule (160 ÷ 40 ÷ 2 = 2,0 ; gymnases répétés comptés une fois), 6 ; règles pour la collection `references` ; parcours Android LC2 pour 2 (stocks du fichier visibles dans « Gymnases et stocks »), 3 (référence dans la liste des sources, chiffre 2,0, étape 3 mise à jour, Courses 80 × 2 × 2,0 − stock), 5 (octets quelconques) et 6 (tableau de bord / bilan identiques avant et après). Règles déployées dès qu'elles passent.

### Cadrage P7 — Importer un menu (phase 5, 07/11/2026)

**Critères du plan, repris tels quels** : (1) la feuille Menu d'un classeur crée un nouveau menu avec types, prix, recettes, ratios et consommations ; (2) une ligne invalide (prix négatif, type inconnu) est listée et ignorée ; (3) le menu importé crée un événement sans erreur.

**Stratégie**
- Écran Menus (`lib/ecran_menus.dart`) : bouton « Importer un menu depuis Excel » (clé `importer_menu`, à côté de « Nouveau menu »), sélecteur de fichier injectable (`SelecteurClasseur`, déjà dans `lib/selecteur.dart`, par défaut `choisirClasseurSysteme`) comme pour P6. Aucune nouvelle dépendance.
- Lecture : `lireClasseur` (P5) lit déjà la feuille Menu et valide chaque ligne (prix 0 à 1 000 €, type et provenance connus, ratios, recette, `FicheProduit.erreur()`), les lignes invalides vont dans `erreurs`. P7 n'ajoute pas de nouvelle validation de ligne ; il ajoute le plan et l'écriture. Plan pur et testable (dans `lib/import_classeur.dart` ou un nouveau `lib/import_menu.dart`) : produits à créer, lignes invalides, noms en double dans le fichier (le premier est gardé, les suivants listés « ignorés : doublon »), limite d'au plus 200 produits (au-delà : refus clair, rien d'écrit).
- Résumé AVANT écriture, comme P6 : « Menu à créer : n produits », la liste des lignes ignorées avec leur raison (repliable au-delà de 10), les erreurs de lecture ; saisie du nom du nouveau menu (même boîte `demanderNom` que « Nouveau menu », donc les mêmes contrôles : non vide, longueur, pas de doublon avec un menu existant) ; boutons « Créer le menu » (clé `appliquer_import_menu`) et « Annuler ». Rien n'est écrit avant « Créer le menu ». Fichier illisible, sans feuille Menu, ou feuille Menu sans aucune ligne valide : message clair (« Ce fichier ne contient aucun produit de menu lisible. Téléchargez le modèle… »), aucun menu créé. Un menu n'est jamais créé vide.
- Écriture : `creerMenuDepuisClasseur(nom, produits)` dans `lib/depot_menus.dart`, dans UN lot (comme `creerMenuDepuisModele`), mêmes champs que `ajouterProduit`/`fiche.versMap()`, donc compatibles avec les règles actuelles des menus (aucun changement de règles attendu ; si un champ était refusé, le test de règles le montre, et on signale). Icônes : aucune importée (le produit prend l'illustration par défaut du modèle générique selon son nom si le code le fait déjà pour les menus créés sans icône ; sinon sans icône). Pas d'écrasement : l'import crée toujours un NOUVEAU menu.
- Cohérence avec le report : la consommation écrite dans la feuille Menu devient le `conso` du produit (ce n'est pas la prévision).

**Fichiers touchés** : `lib/ecran_menus.dart`, `lib/depot_menus.dart`, `lib/import_classeur.dart` ou nouveau `lib/import_menu.dart`, `test/` (plan d'import : doublons, lignes invalides, limite, résumé ; écran Menus), `integration_test/` (nouveau parcours `import_menu_test.dart` : classeur construit en octets de test avec une ligne de chaque type + 2 lignes invalides → résumé → création → le menu existe avec ses produits → création d'un événement à partir de ce menu sans erreur, et ses produits portent types, recettes, ratios, consommations), éventuels tests de règles si un champ pose problème.

**Ce qu'on ne fait pas** : export (P8), modification d'un menu existant par import, import d'icônes ou de photos, feuilles Stock/Historique (déjà P6), fichier de Kinder (P9), nouvelle dépendance.

**Test de chaque critère** : `flutter test` pour 1 (plan : types, prix, recette, ratios, consommation conservés), 2 (prix négatif et type inconnu listés, le reste créé), limites/doublons/résumé ; parcours Android LC2 pour 1 à 3 de bout en bout (dont l'événement créé depuis le menu importé, ses produits relus).

### Cadrage P8 — Export complet du tournoi (phase 5, 07/11/2026)

**Critères du plan, repris tels quels** : (1) le classeur contient Menu, Stock de départ, Historique (personnes, jours, quantités vendues de cet événement), Courses (séries, achats, coût, lignes libres) et Bilan ; (2) les chiffres du Bilan égalent ceux de l'écran (comparés à un calcul fait à la main) ; (3) réimporté dans un nouvel événement, il donne la même consommation que la source « événement passé » ; (4) l'ancien export CSV a disparu.

**Stratégie**
- Le bouton « Exporter (CSV) » de l'écran Bilan (`exporter_csv`) devient « Exporter (Excel) » (clé `exporter_excel`) : il partage un `.xlsx` (`partagerFichier`, nom `tournoi-<événement>-<date>.xlsx`, assaini comme `nomFichierModele`). L'ancien CSV est SUPPRIMÉ : `bilanEnCsv`, `champCsv`/`montantCsv` s'ils ne servent plus, `partagerFichierTexte` seulement s'il n'est plus utilisé (le partage de texte de la liste de courses l'utilise encore : garde-le), tests et parcours à migrer (`test/export_bilan_test.dart`, `integration_test/chantier_complet_test.dart`, `integration_test/courses_test.dart`, `lib/ecran_bilan.dart`). Aucune trace « CSV » dans l'interface de l'écran Bilan.
- Logique pure, dans `lib/classeur.dart` (ou nouveau `lib/export_classeur.dart`), à côté de `construireModele` : `construireExport(...)` → octets. Mêmes feuilles et mêmes en-têtes que le modèle (constantes communes), dans cet ordre : Menu, Stock de départ, Historique, Courses, Bilan (la feuille Bilan n'existe qu'à l'export). Même convention : ligne 1 aide, ligne 2 en-têtes, données dès la ligne 3.
- **Menu** : les produits de l'événement (comme le modèle, consommation = celle du menu de l'événement, pas la prévision). **Stock de départ** : une ligne par gymnase × produit suivi, quantité = total de référence du stock (stock de départ plus réapprovisionnements ; à défaut la quantité) ; l'aide le dit. **Historique** : une ligne par gymnase × produit de CET événement : Événement = nom de l'événement, Gymnase, Personnes (celles du gymnase), Jours (durée de l'événement), Produit, Quantité vendue = ventes NON annulées de ce produit dans ce gymnase (même source que le bilan : `Bilan.depuis(tableau, ..., gymnaseId: g)` / `TableauDeBord.vendus`). Produits non vendus : ligne à 0. **Courses** : pour la série validée : une ligne par achat (Série = son numéro, Produit = nom de l'achat avec son unité de base entre parenthèses, Quantité achetée = quantité réellement achetée à la validation, Coût vide), une ligne « Total de la série n » avec le coût en euros ; une ligne « Séries 1 à n−1 (cumul) » avec le nombre de séries et le coût cumulé des séries précédentes quand il y en a ; les lignes libres (Série = série en cours, nom, quantité, Coût vide) ; si les courses ne sont pas validées : ligne « Courses non validées ». Les détails des séries précédentes ne sont pas conservés par l'application (seul leur cumul l'est) : le dire dans l'aide de la feuille. **Bilan** : les rubriques de l'ancien CSV (en-tête événement/date/état/clôture forcée ; totaux, coût des courses et résultat quand connus ; par mode de paiement ; par produit ; par caisse ; par jour ; par heure ; ventes annulées) sous forme de tableaux successifs séparés d'une ligne vide, montants en cellules numériques en euros, comme l'ancien CSV pour le contenu.
- Portée : le classeur contient ce que la personne voit. Vue commune d'un gestionnaire partiel = ses gymnases seulement ; la feuille Bilan l'indique (« Export limité aux gymnases : … ») ; coût et résultat des courses seulement pour qui y a droit (comme avant). L'export part toujours de la vue COMMUNE (les gymnases visibles), quelle que soit la vue affichée à l'écran ; si le bilan est affiché pour un seul gymnase, le bouton exporte quand même toute la portée de la personne (ligne d'aide sous le bouton). Événement « En cours » : export provisoire, indiqué sur la feuille Bilan comme avant.
- Relecture : `lireClasseur` lit déjà Menu, Stock et Historique ; l'export doit être relu sans erreur (les feuilles Courses et Bilan ignorées). Le critère 3 se prouve : exporter l'événement source, réimporter l'Historique via l'import de P6 → référence ; sa consommation par produit égale celle de la source « événement passé » (P4) pour le même événement (mêmes arrondis).
- Données à fournir à l'écran Bilan : personnes et durée (gymnases, événement), stocks de référence par gymnase, liste de courses et, pour les noms d'achats, les produits ; câblage depuis `lib/ecran_evenement.dart`. Pas de nouvelle lecture Firestore hors flux déjà partagés (quota : ne pas multiplier les écoutes).

**Fichiers touchés** : `lib/classeur.dart` ou `lib/export_classeur.dart`, `lib/export_bilan.dart` (suppression du CSV, noms de fichiers), `lib/ecran_bilan.dart`, `lib/ecran_evenement.dart`, `lib/partage.dart` (rien si inchangé), tests de logique (`test/export_bilan_test.dart` réécrit en export Excel, `test/classeur_test.dart`), parcours Android (`chantier_complet_test.dart`, `courses_test.dart`, nouveau `integration_test/export_test.dart`).

**Ce qu'on ne fait pas** : import des feuilles Courses/Bilan (ignorées), export CSV conservé « en secours » (supprimé), historique détaillé des séries de courses précédentes (non conservé), changement de règles Firestore ou de données, nouvelle dépendance, fichier de Kinder (P9).

**Test de chaque critère** : `flutter test` pour 1 (cinq feuilles, ordre, contenus), 2 (un événement construit à la main : 3 ventes dont 1 annulée, 2 gymnases, mode de paiement, coût de courses connu → chaque total du Bilan égal au calcul noté dans le test et à l'écran Bilan), 4 (plus aucune occurrence de « CSV » dans lib/ecran_bilan.dart et plus de `bilanEnCsv`) ; parcours Android LC2 pour 1 à 3 de bout en bout : événement clôturé avec ventes, bouton « Exporter (Excel) » → partageur factice → relecture des octets, import dans un nouvel événement → référence → mêmes consommations que la source événement passé.

### Prompt de lancement de la session mère (à coller dans une conversation neuve de Claude Code, sur Sonnet, dans `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`)

```
Tu es la session mère de la mission « Préparer l'événement » de Le Comptoir (temps de réalisation : phases 5, 6 et clôture de PHASES_CADRAGE.md).

1. Lis, dans cet ordre : PROJET_CONTEXTE.md (bloc de statut, décisions 53 à 60, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 13 (plan P1 à P11, critères, classeur Excel, préalables), CHANGELOG.md (dernière entrée), graphify-out/GRAPH_REPORT.md.
2. Préalable 1 : demande à Kinder, en une question, si son test sur téléphone des missions en attente est fait. Sinon, tu t'arrêtes là.
3. Hygiène git : rien de non enregistré, main à jour avec le dépôt en ligne, puis branche `claude/preparation-evenement`. Jamais de travail sur main.
4. Pour chaque étape, de P1 à P11, dans l'ordre :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 13 (« Cadrage Pn »), critères du plan repris tels quels.
   b. Phase 6 : confie l'étape à une sous-session neuve (Sonnet) avec son seul dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test. Elle rend un BILAN au format unique (10 lignes max).
   c. Vérifie toi-même que le test de code ou sur émulateur de chaque critère est réussi (flutter analyze, flutter test, tests_regles/lancer.ps1, parcours Android utiles sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent (accord de Kinder donné pour toute la mission, préalable 2).
   d. Ligne dans le tableau de suivi de la section 13, ligne dans CHANGELOG.md, commit sur la branche. Puis étape suivante, sans attendre Kinder.
5. Dépendances accordées : une pour lire et écrire un fichier Excel, une pour choisir un fichier. Aucune autre sans accord de Kinder.
6. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite ; P9 si le fichier Excel de l'an passé de Kinder n'est pas dans le dossier du projet.
7. Clôture : après P11, lance la vérification par une autre IA dans une conversation neuve sur Sonnet, avec le texte de vérification de P11 (capture et verdict par critère). En cas d'échec, retour en phase 6 sur les seuls critères échoués.
8. Fin : documentation à jour, résumé final dans CHANGELOG.md, branche poussée sur le dépôt, APK de recette 1.2.0 ; puis Kinder fait son test et sa capture. Fusion dans main seulement après son accord écrit.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```
