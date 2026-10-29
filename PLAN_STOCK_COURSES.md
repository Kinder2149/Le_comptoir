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

**Suivi B1** : implémentée et testée par Claude le 29/10/2026, sur la branche `claude/menu-evenement-b1` (commit 284fbdb). Analyse sans erreur, 218 tests de logique et d'écrans, 170 tests de règles, 26 parcours Android (24 réussis dans la série complète ; `recette_test` réussi seul après un échec isolé de la série, et `chantier_complet_test` adapté : la tarte, désormais « apportée », n'est plus dans les courses, son stock de 80 est posé à la main, puis réussi). Règles (champ `provenance`) déployées sur le vrai projet le 29/10/2026 (accord de Kinder). Reste : capture de Kinder, et la vérification par une autre IA en clôture du chantier (B6).

## 6. Registre du cahier des charges (rien ne se perd)
| Demande du PDF | Sort |
|---|---|
| Vente bloquée en rupture | **Écarté** (décision 35 : couleur, jamais de blocage) |
| États colorés : disponible vert, bas orange, rupture rouge, inconnu gris | **Retenu en partie** : rupture colorée (étape 4), stock bas signalé (4). « Inconnu gris » (produit sans suivi) à décider à l'étape 4 |
| Tableau de bord des stocks par gymnase/événement, filtres catégorie | **Reporté** : le suivi en direct montre déjà le stock restant ; filtres à rediscuter après l'étape 4 |
| Entrées, pertes/consommations internes, corrections | **Retenu en partie** : entrées et réglages (étape 3, courses 6) ; pertes et consommations internes **reportées** |
| Inventaire de fin de journée (saisie directe, sans écart affiché) | **Couvert** par le réglage du stock par la gestion (étape 3) ; pas d'écran dédié |
| Réapprovisionnements partiels pendant la journée | **À trancher** à l'étape 6 |
| Unités et conversions (tranches, grammes) | **Retenu** : liste d'unités à l'étape 1, conversions g/kg et cl/L aux étapes 5-6 |
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
