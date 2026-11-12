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
| V1 Calcul du club (logique) | Close | 12/11/2026 | 1 à 5 réussis : analyse sans problème, 17 tests dédiés, suite entière 566 verts sans test existant modifié (N1) |
| V2 Enregistrement et règles | Close | 12/11/2026 | 1 à 4 réussis : analyse sans problème, 573 tests, 274 tests de règles verts (dont 8 nouveaux) ; règles déployées le 12/11/2026 (seul ajout par rapport au lot A) (N1) |
| V3 Repas jour par jour (Préparation) | Close | 12/11/2026 | 1 à 5 réussis : analyse sans problème, 593 tests verts (20 nouveaux), aucun test existant modifié (N1). Note de checklist : un gymnase aux repas détaillés mais sans personnes réglées entre dans les courses (choix de la sous-session, option la plus simple) ; l'écran Courses n'a pas de test d'écran propre (logique testée) |
| V4 Groupes dans la Prévision | Close | 12/11/2026 | 1 à 5 réussis : analyse sans problème, 616 tests, 276 tests de règles verts (lancés sur copie identique, ports 8180/9199, car l'émulateur du lot A tenait 8080/9099) ; règles déployées le 12/11/2026 (champ `groupes` de l'annulation) (N1). Choix noté : une modification de groupe à la main n'est pas annulable (comme une correction à la main d'un produit) |
| T1 Enregistrer sur le téléphone | Close (test de code) | 11/11/2026 | 1 à 4 réussis : N1 (analyse, 471 tests) ; N2 sur LC2 : fichier enregistré dans Téléchargements via le sélecteur Android, relu par adb ; le tap sur « Enregistrer » est fait par adb, pas par le test |
| T2 Assistant d'import unique (opus) | Close (test de code) | 11/11/2026 | 1 à 8 réussis : N1 (analyse, 486 tests) ; N2 sur LC2 avec le vrai moteur local : menu de même nom repris sans changement, référence de l'an passé, stock par noms, prévision réglée, bénévole sans l'assistant ; règles inchangées. Six parcours N2 anciens adaptés, compilés mais non relancés (un seul N2 par étape) |
| T3 Classeur du club | Close (test de code) | 11/11/2026 | 1 à 4 réussis : `recette/classeur-notre-club.xlsx` (menu vide, historique 38 lignes, stock de départ à remplir) ; N2 sur LC2 : importé par l'assistant sans erreur, 19 consommations égales au relevé. À confirmer par Kinder : noms des gymnases et des produits identiques à ceux du tournoi |
| T4 Ajouter un produit | Close (test de code) | 11/11/2026 | 1 à 5 réussis : N1 (analyse, 491 tests) ; règles 261 (bénévole refusé) ; N2 sur LC2 : ajout en cours, produit dans l'événement et le menu, stock, prévision, courses, caisse. Règles inchangées : rien à déployer |
| T5 Annuler un changement de source | Close (test de code) | 11/11/2026 | 1 à 3 réussis : N1 (analyse, 500 tests) ; règles 266 ; règles déployées sur le vrai projet le 11/11/2026 (nouveau document `previsions_annulation`) ; suppression de l'association efface aussi ce document |
| T6 Heure de la dernière actualisation | Close (test de code) | 11/11/2026 | 1 à 3 réussis : N1 (analyse, 503 tests) ; la ligne vient du composant partagé des cinq écrans actualisables |
| T7 Paramètres en cartes | Close (test de code) | 11/11/2026 | 1 à 5 réussis : N1 (analyse, 513 tests dont 10 nouveaux par rôle). Une confirmation s'ajoute à la nomination d'un gestionnaire. Parcours Android adaptés, non relancés (N1 seulement au plan) |
| T8 Page Courses en cartes | Close (test de code) | 11/11/2026 | 1 à 5 réussis : N1 (analyse, 520 tests ; tests de calcul des courses intacts) ; captures avant/après dans `audit_front/tournoi/` (adb, émulateur LC2). Libellé « Enregistrer ou partager » sur 2 lignes sur téléphone étroit : jugé acceptable. Parcours Android de la page Courses non relancés |
| P1 | Close (testée par Claude) | 06/11/2026 | 1 à 7 réussis : règles 197/197 (10 nouveaux, `preparation.test.mjs`), `flutter test` 252/252, `flutter analyze` sans erreur, parcours Android LC2 `evenements_test` + `restes_test` 2/2. Règles déployées le 06/11/2026. Limite : le bouton « Ouvrir l'événement » est testé en logique et dans le parcours `evenements_test`, pas en test d'écran isolé |
| P2 | Close (testée par Claude) | 06/11/2026 | 1 à 6 réussis : règles 204/204 (7 nouveaux, `stock_depart.test.mjs`), `flutter test` 261/261, analyse sans erreur, parcours Android LC2 `preparation_test` + `restes_test` + `gymnases_test` + `evenements_test` 4/4. Règles (champ `repris`) déployées le 06/11/2026 |
| P3 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : `flutter test` 269/269 (8 nouveaux : limites de durée et de personnes, lecture seule), analyse sans erreur, règles inchangées (204/204 à P2), parcours Android LC2 `preparation_test` + `courses_test` + `chantier_complet_test` + `recette_test` 6/6 (80 personnes et 2 jours réglés dans la Préparation, Courses lit 80 et 2 et calcule 320 ; « Jour complet » dans Courses : durée de l'événement toujours 2). Limite : l'absence du champ « personnes » dans Courses est constatée par le parcours Android, pas par un test d'écran isolé (pas de faux Firestore) |
| P4 | Close (testée par Claude) | 07/11/2026 | 1 à 7 réussis : `flutter test` 293/293 (24 nouveaux), règles 215/215 (11 nouveaux, `previsions.test.mjs`), analyse sans erreur, parcours Android LC2 7/7 (`previsions_test` : 160 ÷ 40 ÷ 2 = 2,0 avec une vente annulée exclue, produit absent = menu, correction à la main, événement sans personnes non proposé, Courses 80 × 2 × 2,0 − 20 = 300 ; + preparation, courses, parametres, chantier_complet). Règles déployées le 07/11/2026. Points connus : écriture par groupes de 10 (non atomique au-delà, rejouable) ; un produit présent dans l'événement passé sans vente prend 0 ; lecture réservée à ceux qui lancent les courses |
| P5 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : `flutter test` 310/310 (17 nouveaux, dont l'aller-retour sur un menu riche), analyse sans erreur, règles inchangées (215/215), parcours Android LC2 3/3 (`classeur_test`, `preparation_test`). Dépendance : `excel` 4.0.6 (version exacte). Limite : le fichier n'a pas été ouvert dans l'application Excel, il est relu par la bibliothèque |
| P6 | Close (testée par Claude) | 07/11/2026 | 1 à 6 réussis : `flutter test` 352/352, règles 230/230 (15 nouveaux, collection `references`), analyse sans erreur, parcours Android LC2 `import_test` + `preparation_test` 3/3 (après correction) et `previsions_test`, `classeur_test`, `parametres_test` verts avant correction. Dépendance : `file_picker` 11.0.3 (exacte ; les versions 12 et 13 sont incompatibles avec `share_plus` 10.1.4). Règles déployées le 07/11/2026. Décision de mise en œuvre : une fois l'événement ouvert, l'import n'écrit plus de stock (lignes « ignorées »), seules les références s'importent. Limites : le sélecteur système n'est pas piloté par les tests (octets fournis) ; les règles `references` valident les 12 premières lignes une à une (limite de 1000 expressions), l'application écarte les lignes hors format |
| P7 | Close (testée par Claude) | 07/11/2026 | 1 à 3 réussis : `flutter test` 366/366 (14 nouveaux, `import_menu_test`), analyse sans erreur, règles inchangées (230/230), parcours Android LC2 `import_menu_test` + `menus_test` + `import_test` + `preparation_test` 4/4 (menu de 4 produits valides + 2 lignes invalides listées, événement créé depuis ce menu, relecture des produits). Limite : sélecteur système non piloté (octets fournis) |
| P8 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : `flutter test` 375/375 (calcul à la main du Bilan : 22,00 € en 5 ventes dont 1 annulée exclue, coût 35 = 25 + 10, résultat −13 ; réimport = mêmes consommations que la source « événement passé » ; plus aucune trace du CSV), analyse sans erreur, règles et dépendances inchangées, parcours Android LC2 6/6 (`export_test`, `chantier_complet_test`, `courses_test`, `bilan_test`, `recette_test`). Limites : le détail des séries de courses précédentes n'est pas conservé par l'application (cumul seulement) ; un gestionnaire partiel obtient une feuille Courses réduite à un message ; ouverture dans l'application Excel non testée (relu par la bibliothèque) |
| P9 | Close (testée par Claude) | 07/11/2026 | 1 à 3 réussis : classeur `recette/historique-tournoi-an-passe.xlsx` produit d'après les estimations du fichier de Kinder (relevé repris / non repris ci-dessus) ; importé sur émulateur sans erreur (`import_an_passe_test`, 19 produits) ; consommations égales au calcul à la main à 0,0001 près ; `flutter test` 375/375, analyse sans erreur, règles inchangées. Limite : le classeur est écrit avec des liens internes relatifs (comme Excel) ; un fichier écrit avec des liens absolus (certains outils) est refusé comme « illisible » par la bibliothèque. Les chiffres du Coca et des boissons diffèrent beaucoup du menu type (unités à confirmer par Kinder). |
| P10 | Close (testée par Claude) | 07/11/2026 | 1 à 4 réussis : « Ajouter un apport » dans le stock du bénévole (nom, parts) ; « Quiche, 8 parts » sur « Gâteau salé » (stock 4) → 12, réf. 12 ; vente du gâteau → 11 comme avant ; apport listé « Quiche, 8 parts, Lea, Principal » (bilan : rubrique « Apports » filtrée par vue et gymnases visibles ; export : rubrique dans la feuille Bilan) ; nom vide, parts 0 ou 1001 refusés (application et règles, nom d'espaces et 41 caractères aussi). `flutter test` 380/380, analyse sans erreur, règles 234/234 (4 nouveaux, `apports.test.mjs`) et déployées le 07/11/2026, 4 parcours Android (apports, stock_role, bilan, export). Choix : l'apport est écrit dans un lot avec la hausse du stock, les règles exigent la même hausse (`getAfter`) ; lecture réservée à la gestion ; le « + » simple de la caisse reste. |
| P11 | Close (testée par Claude) | 07/11/2026 | 1 à 3 réussis : parcours automatique `parcours_mission_test` sur émulateur (créer, modèle téléchargé puis rempli, import, stock de départ retrouvé, prévision 2,0 / 1,0 d'après l'an passé, Croque corrigé à 2,5, courses 380, ouverture, ventes 11,00 €, clôture, export aux cinq feuilles relu sans erreur) ; texte de vérification pour une autre IA rédigé (section 13, « Texte de vérification… P11 ») ; APK de recette 1.2.0+3 reconstruit (`flutter build apk --release`, 72,8 Mo) et copié dans `recette/le-comptoir-recette.apk`. |

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

### Cadrage et relevé P9 — Import de l'an passé (07/11/2026, décision 58)

**Critères du plan, repris tels quels** : (1) Claude Code produit le classeur rempli d'après ce fichier, avec un relevé de ce qui a été repris et de ce qui ne l'a pas été ; (2) importé sur émulateur sans erreur ; (3) consommations égales au calcul à la main noté dans le relevé.

**Ce que contient le fichier de Kinder** (`orga tournoi de l'an passé.xlsx`, 20 feuilles, lu le 07/11/2026) : un classeur d'ORGANISATION, pas un relevé de ventes : personnes et repas prévus par gymnase et par jour, pourcentages de consommation, quantités estimées servies par produit (feuilles « Gymnase 1/2 Samedi/Dimanche »), achats de 2024 avec remarques, tarifs, tickets et étiquettes à imprimer, feuilles de fin de journée vides. Kinder a validé le 07/11/2026 (« Oui, estimations ») que l'historique reprenne les **quantités estimées servies**, par gymnase et par jour. Le classeur produit est donc une référence ESTIMÉE, pas une mesure.

**Classeur produit** : `recette/historique-tournoi-an-passe.xlsx` (hors dépôt : `recette/*.xlsx` est ignoré). Quatre feuilles du modèle ; seule « Historique » est remplie (l'événement s'appelle « Tournoi de l'an passé » → la référence « Tournoi de l'an passé (Excel) »). Aucun nom d'équipe ni de bénévole n'est recopié.

**Relevé — repris**
- Personnes : joueuses + accompagnateurs de chaque gymnase, moyenne des deux jours arrondie : gymnase 1 = (49 + 56) ÷ 2 = 52,5 → 53 ; gymnase 2 = (63 + 56) ÷ 2 = 59,5 → 60 ; total 113. Durée : 2 jours.
- Quantités : pour chaque gymnase, somme des quantités estimées du samedi et du dimanche (colonne des estimations de chaque feuille), arrondie à l'entier. Les repas des bénévoles et de leur famille sont dans ces quantités, mais pas dans les personnes : les consommations par personne sont donc légèrement surestimées.
- Produits repris sous le nom du menu de l'application : Croque-monsieur (« Croque Monsieur standard »), Croque végé, Croque tartiflette, Coca, Ice Tea, Oasis, Bière, Thé, Café, Mars, Twix, Fruit (total de la catégorie : pomme, banane, clémentine), Barre de céréales chocolat.

**Relevé — gardé sous le nom du fichier (sans équivalent exact dans le menu : ignoré par un événement qui n'a pas ce produit, conservé dans la référence)** : Croque Monsieur Chocolat, Crêpe sucre, Crêpe Nutella (le menu a « Crêpes (3 petites) »), Orangina, Infusion, Barre de céréales fruit (le menu a « pomme » et « fraise-framboise »).

**Relevé — non repris** : « Nombre de sucre » ; les totaux de catégorie (plat de résistance, dessert, boissons froides, boisson chaude, boisson alcoolisée, barres de céréales) ; les achats de 2024 (« acheté », « à prévoir », remarques : ce sont des quantités d'achat, pas de consommation) ; tarifs ; tickets, étiquettes, fiches de cuisine ; noms d'équipes, de bénévoles et de familles ; feuilles de fin de journée (vides) ; la liste de courses (le classeur ignore la feuille Courses à l'import).

**Calcul à la main** (consommation par personne et par jour = (gymnase 1 + gymnase 2) ÷ 113 personnes ÷ 2 jours) : Croque-monsieur 70 + 73 = 143 → 0,6327 ; Croque végé 44 + 46 = 90 → 0,3982 ; Croque tartiflette 61 + 64 = 125 → 0,5531 ; Coca 168 + 177 = 345 → 1,5265 ; Ice Tea 75 + 79 = 154 → 0,6814 ; Oasis 93 + 98 = 191 → 0,8451 ; Bière 75 + 79 = 154 → 0,6814 ; Thé 82 + 86 = 168 → 0,7434 ; Café 164 + 173 = 337 → 1,4912 ; Mars 7 + 8 = 15 → 0,0664 ; Twix 15 → 0,0664 ; Fruit 125 + 131 = 256 → 1,1327 ; Barre de céréales chocolat 17 + 18 = 35 → 0,1549 (et Croque Monsieur Chocolat 140 → 0,6195 ; Crêpe sucre 140 → 0,6195 ; Crêpe Nutella 281 → 1,2434 ; Orangina 76 → 0,3363 ; Infusion 56 → 0,2478 ; Barre de céréales fruit 35 → 0,1549). À titre de comparaison, le menu type donne 0,65 / 0,45 / 0,60 pour les trois croques, très proche ; pour les boissons il donne 0,32 pour le Coca (ici 1,53 : unités différentes, verres contre litres, à vérifier par Kinder avant de s'en servir).

**Test** : parcours Android LC2 `integration_test/import_an_passe_test.dart` : le classeur (octets du fichier produit, embarqués dans `integration_test/an_passe_octets.dart`) est lu par l'import de la Préparation (sélecteur factice) → résumé sans erreur → « Appliquer » → référence « Tournoi de l'an passé (Excel) » dans « D'après une source » → chiffres égaux au tableau ci-dessus (à 0,0001 près) ; un événement dont le menu contient les produits repris les reçoit, ceux sans équivalent sont listés comme absents du menu sans erreur.

### Texte de vérification pour une autre IA : mission « Préparer l'événement » (P11, 07/11/2026)
À donner tel quel à une IA qui n'a pas écrit le code, dans une conversation neuve sur Sonnet, dans Claude Code, sur le PC. Son verdict ferme l'implémentation ; le test et la capture de Kinder ferment la mission.

> Tu vérifies l'application Flutter « Le Comptoir » (dossier `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`, branche
> `claude/preparation-evenement`), mission « Préparer l'événement » (étapes P1 à P11 de la section 13 de
> `PLAN_STOCK_COURSES.md`, décisions 53 à 60). Tu ne corriges rien : tu rends un verdict réussi/échoué par critère, avec une
> capture ou la sortie du test.
>
> **Lancer** : Java 21 (`C:\Program Files\Android\Android Studio\jbr`) ; `flutter analyze` ; `flutter test` (380 tests) ;
> `powershell -File tests_regles/lancer.ps1` (234 tests de règles, 5 min) ; émulateur Android `LC2` (`-gpu swiftshader_indirect
> -no-snapshot -no-audio`) puis `powershell -File tests_regles/lancer_integration.ps1` (tous les parcours de
> `integration_test/` ; les nouveaux de la mission : `preparation`, `previsions`, `classeur`, `import`, `import_menu`,
> `export`, `import_an_passe`, `apports`, `parcours_mission`). Si un parcours se fige (écran noir), `adb emu kill`, relancer
> l'émulateur et ce parcours seul : ce n'est pas un défaut du code. Ne pas lancer deux émulateurs Firestore à la fois (port 8080).
>
> **Critère de fin de Kinder (06/11/2026)** : « Je crée un événement, je télécharge le modèle Excel, je le remplis avec les
> chiffres de l'an passé et je l'importe ; dans Préparation, je retrouve mon stock de départ et une prévision calculée d'après
> l'an passé, je corrige un chiffre, je lance les courses ; à la fin du tournoi, j'exporte le même classeur rempli. »
> Le parcours `integration_test/parcours_mission_test.dart` le déroule : stock de départ A Croque 20 / B Soda 6 ; historique
> 160 croques et 80 sodas pour 40 personnes en 2 jours → prévision 2,0 et 1,0 par personne et par jour ; Croque corrigé à 2,5 ;
> courses du gymnase A 80 × 2 × 2,5 − 20 = 380 ; ventes 3 croques + 2 sodas = 11,00 € ; export aux cinq feuilles.
>
> **À vérifier, critère par critère** (les critères de chaque étape sont dans le tableau de la section 13) :
> 1. P1 : un événement neuf est « En préparation » ; aucune caisse ne s'y ouvre ; « Ouvrir l'événement » le passe « En cours ».
> 2. P2 : le stock de départ se règle en préparation ; les restes de l'événement précédent y sont repris (marqués) ; en cours, il est en lecture seule.
> 3. P3 : personnes par gymnase et durée réglées dans la Préparation et lues par les courses (plus de champ « personnes » aux courses).
> 4. P4 : prévision par produit avec sa source (Menu, événement passé, classeur Excel, « Modifié à la main »).
> 5. P5 : « Télécharger le modèle Excel » partage un `.xlsx` (Menu, Stock de départ, Historique, Courses) relisible.
> 6. P6 : « Importer un classeur » : résumé AVANT toute écriture, lignes invalides listées et ignorées, fichier illisible refusé avec un message clair, aucune vente créée.
> 7. P7 : « Importer un menu depuis Excel » crée un menu qui crée un événement sans erreur.
> 8. P8 : « Exporter (Excel) » remplace le CSV ; chiffres du Bilan égaux à l'écran.
> 9. P9 : `recette/historique-tournoi-an-passe.xlsx` (hors dépôt, régénérable depuis `integration_test/an_passe_octets.dart`) s'importe sans erreur ; consommations égales au calcul à la main du relevé P9 (ESTIMATIONS, pas des ventes réelles).
> 10. P10 : « Ajouter un apport » (nom, parts 1 à 1000) : stock + parts, la caisse vend comme avant, le bilan et l'export listent « Quiche, 8 parts, prénom, gymnase » ; nom vide ou parts hors bornes refusés.
>
> **Limites connues (ne pas les compter comme défauts)** : les fichiers ne sont pas ouverts dans le vrai Excel (relus par la bibliothèque) ;
> le sélecteur de fichiers du système n'est pas piloté par les tests (sélecteur factice) ; la bibliothèque Excel refuse un fichier dont
> les liens internes sont absolus (écrit par certains outils) : message « illisible » ; le détail des séries de courses précédentes n'est pas
> conservé (cumul seul) ; un gestionnaire d'une partie des gymnases a une feuille Courses réduite.
>
> **Rendu attendu** : un tableau critère / verdict / preuve, la liste des défauts classés par gravité, et UNE question.

**Vérification indépendante (07/11/2026)** : une IA neuve sur Sonnet (qui n'a pas écrit le code) a refait toutes les suites : analyse sans erreur, `flutter test` 380/380, règles 234/234, 37 parcours Android (34 fichiers) sur LC2 en un seul passage. Les critères 1 à 10 et le critère de fin de Kinder sont **tous réussis, aucun défaut** (preuves = sorties de tests, pas de capture d'écran). Point laissé à Kinder : confirmer au test que les chiffres de l'an passé (estimations, boissons surtout, Coca 1,53 contre 0,32 au menu) lui conviennent.

**Cadrage F3 (11/11/2026)** : la liste des membres (`ecran_association.dart`, bas de l'écran de l'association : « Membres (n) », clés `membre_`, `statut_`, `nommer_`, `retirer_`) est supprimée de l'écran de l'association. Dans `EcranParametres`, une seule liste « Membres » remplace la liste actuelle `_sectionResponsable` : visible par le responsable et les gestionnaires actifs (pas les bénévoles ni un gestionnaire en attente), avec le statut de chaque membre. Actions par ligne, pour le responsable seulement : « Nommer gestionnaire » (bénévole), « Retirer le statut de gestionnaire » (gestionnaire ou en attente), « Retirer de l'association » (tout membre sauf lui-même) ; aucune action pour un gestionnaire. Une note « Qui peut quoi » (droits du responsable, du gestionnaire, du bénévole, d'après la section 3 du PROJET_CONTEXTE) est ajoutée dans les Paramètres, visible par tous. Fichiers touchés : `lib/ecran_association.dart`, tests de logique et parcours `membres_test`, `parametres_test`, `gymnases_test`, `menus_test`, `recette_test` à adapter si leurs clés changent, tests de règles (`tests_regles`) pour le critère 6. On ne touche pas : les règles d'accès (sauf ajout de tests), les droits, le code d'accès, la suppression de l'association.

**Cadrage F4 (11/11/2026, étape « opus »)** : jugement sur des données réelles à rendre génériques sans perdre leur justesse. Stratégie : (1) inventaire de tout ce qui nomme une marque, un club, une personne ou un lieu dans `assets/menu_type.json`, dans le générateur du classeur (`lib/classeur.dart`, `lib/ecran_classeur.dart`, `lib/import_classeur.dart`) et dans les textes du modèle vierge ; au cadrage on connaît déjà Coca, Coca Zéro, Fanta, Ice Tea, Oasis, Mars, Twix, Snickers ; (2) remplacer chaque marque par un nom générique de même nature (ex. « Cola », « Cola zéro », « Soda à l'orange », « Thé glacé », « Boisson fruitée », barres chocolatées distinctes par leur nature, pas par une marque), en gardant intacts prix, consommations (`conso`), recettes, rayons, familles et ratios (décision 50), sauf correction justifiée ligne par ligne dans le bilan ; (3) modèle vierge : chaque feuille du classeur contient un exemple rempli et une explication courte, l'exemple n'est jamais une donnée réelle de club ; (4) test : le modèle vierge se réimporte sans erreur et redonne les mêmes produits (tests existants du classeur à compléter) ; un test parcourt `menu_type.json` et le modèle et échoue si une marque d'une liste fixe y figure ; (5) les menus et événements existants ne changent pas : seul le modèle (menus créés ensuite) est concerné, aucune migration. Fichiers touchés : `assets/menu_type.json`, `lib/classeur.dart` (et voisins du classeur), `test/` du classeur et du menu type. On ne touche pas : calculs, droits, règles d'accès (la liste des 14 icônes est la même dans l'application et les règles : ne change aucune clé d'icône), écran de l'événement. Critères : ceux du tableau (F4, 1 à 5).

**Cadrage F5 (11/11/2026)** : nouvel écran `lib/ecran_extraction.dart` (« Extraction et modèle »), ouvert par un bouton « Extraction et modèle » placé à côté de « Menus » sur l'écran de l'association (`lib/ecran_association.dart`, même condition : responsable ou gestionnaire, jamais un bénévole). Quatre cartes aux couleurs de l'application. (1) **Modèle vierge** : télécharge le classeur du modèle (`construireModele` avec le menu type `assets/menu_type.json` converti en produits, sans gymnase ni stock : il garde ses exemples et explications, F4) via la feuille de partage existante. (2) **Données de l'association** : choix d'un menu de l'association, puis classeur avec feuilles Menu, Recettes (composition) et la prévision (consommations par personne et par jour du menu) ; nouvelle fonction dans `lib/classeur.dart` qui réutilise les générateurs de feuilles existants, sans calcul nouveau. (3) **Export d'un tournoi** : liste des événements clôturés, un choix produit le même classeur que le bouton d'export de l'onglet Après (`construireExport`, mêmes données et même limite de portée : un gestionnaire limité ne voit que ses gymnases) ; réutiliser la lecture des données qui alimente `EcranBilan` (voir `_ouvrirBilan` de `lib/ecran_evenement.dart` et `_exporter` de `lib/ecran_bilan.dart`) plutôt que d'en écrire une seconde, en la sortant en fonction commune si nécessaire. (4) **Comparateur** : carte présente et ouvrant l'écran de F6 (en F5 : la carte existe, désactivée avec la mention « bientôt » si F6 n'est pas faite ; F6 la branche). Les accès actuels (bouton Excel de l'onglet Avant, export de l'onglet Après) restent. Fichiers touchés : `lib/ecran_extraction.dart` (nouveau), `lib/ecran_association.dart` (bouton), `lib/classeur.dart` (classeur des données de l'association), `test/`, `integration_test/` (un parcours court). On ne touche pas : calculs, bilan, droits, règles d'accès (la lecture des menus et événements existe déjà pour la gestion), aucune dépendance nouvelle. Critères : ceux du tableau (F5, 1 à 6).

**Cadrage F6 (11/11/2026)** : le comparateur se branche sur la carte désactivée de `lib/ecran_extraction.dart` (clé `carte_comparateur`). Logique pure dans un fichier à part, `lib/comparaison.dart` : à partir de deux « photographies » de tournoi clôturé (nom, date, personnes = somme des personnes des gymnases visibles, jours, nombre de ventes non annulées, total, coût des courses, résultat, et par produit : nom, quantité vendue), elle rend le tableau de synthèse (personnes, jours, ventes, total, coût des courses, résultat, avec l'écart) puis une ligne par produit retrouvé par son nom sans casse ni accents (comme la décision 56 : réutiliser la fonction existante de `lib/previsions.dart`, ne pas en écrire une seconde) : quantités vendues des deux côtés, consommation par personne et par jour (ventes ÷ personnes ÷ jours) des deux côtés, écart ; un produit présent d'un seul côté a « — » de l'autre côté ; une consommation indéfinie (personnes ou jours à zéro) s'affiche « — » et n'est jamais une division par zéro. Écran `lib/ecran_comparateur.dart` : choix de deux tournois clôturés parmi ceux de la portée de la personne (pas deux fois le même), affichage côte à côte lisible sur téléphone, bouton « Exporter en Excel » qui produit un classeur aux couleurs de l'application (en-têtes, largeurs, volets figés, comme `lib/classeur.dart`) ; la lecture des données d'un tournoi réutilise celle de l'export de F5 (`construireExportTournoi` / sa lecture du tableau de bord). Droits : un gestionnaire limité ne compare que ses gymnases ; les courses (coût, résultat) ne s'affichent que pour qui y a droit, sinon « — ». Aucun nouveau calcul de bilan : on reprend les chiffres du tableau de bord. Fichiers touchés : `lib/comparaison.dart` et `lib/ecran_comparateur.dart` (nouveaux), `lib/ecran_extraction.dart` (carte branchée), `lib/classeur.dart` (classeur du comparateur), `test/`, `integration_test/` (un parcours). On ne touche pas : calculs, bilan, droits, règles d'accès, dépendances. Critère 4 : deux tournois de test dont tous les chiffres sont recalculés à la main dans le test.

**Cadrage F7 (11/11/2026)** : (1) un parcours automatique du critère de fin sur émulateur, `integration_test/parcours_retours_terrain_test.dart`, sur le modèle de `parcours_ergonomie_test.dart` et `captures.dart`, captures rangées dans `audit_front/retours_terrain/apres/` : deux téléphones simulés (deux connexions) ; le premier vend, retire une ligne du ticket (message de stock qui disparaît puis revient), le second voit les ventes ; glisser vers le bas ; les membres dans les Paramètres du responsable (nommer, retirer un bénévole) puis en gestionnaire (sans bouton) ; l'écran « Extraction et modèle » (modèle vierge, données de l'association, export d'un tournoi clôturé, comparaison de deux tournois). (2) Tous les parcours Android existants rejoués un à un (pas la suite d'un bloc), tableau vert/rouge, en distinguant les rouges déjà présents sur `main` avant la mission (`evenements_test`, `menus_test`, `images_test`) ; `parcours_ergonomie_test`, figé à la connexion à F4, doit être expliqué ou corrigé s'il vient d'un défaut de la mission. (3) Version 1.4.0+5 dans `pubspec.yaml` et APK de recette reconstruit puis copié dans `recette/` (non suivi par git). Les règles d'accès n'ont pas changé dans cette mission : rien à déployer. Ensuite, par la mère : checklist C1 à C8, texte de vérification pour une autre IA, documentation, graphify, envoi de la branche.

**Texte de vérification pour une autre IA (rédigé le 11/11/2026, à coller dans une conversation neuve de Claude Code, sur Sonnet, dans `V:\DEV\PROJETSpplications_mobile\Le_Comptoir`)**

```
PROMPT DE VÉRIFICATION — Retours du terrain — projet Le Comptoir
TYPE : finale

Tu es l'IA de vérification. Tu n'as pas codé cette mission. Tu ne corriges rien.

CRITÈRES DE FIN DE MISSION (validés par Kinder le 11/11/2026) :
1. Sur deux téléphones, je vends sans message de stock fantôme : l'avertissement « Stock épuisé » suit le ticket (il s'affiche quand un produit du ticket atteint le stock, disparaît quand la ligne est retirée, revient si je la remets) et la vente n'est jamais bloquée.
2. Je vois les ventes de l'autre téléphone : ce que fait un téléphone (vente, stock, caisse, clôture) apparaît sur l'autre sans rien faire, et « glisser vers le bas » relit les données (hors réseau : message clair, rien de bloqué), sur association, événement, caisses en direct, stock et bilan.
3. Je gère mes membres depuis les Paramètres : le responsable voit tous les membres avec leur statut et, sur chaque ligne, nomme / retire le statut de gestionnaire / retire de l'association ; un gestionnaire voit la liste sans aucun bouton ; un bénévole ne voit pas de liste ; plus de liste en bas de l'écran de l'association ; la note « Qui peut quoi » est présente.
4. Depuis l'écran « Extraction et modèle » (bouton à côté de « Menus », jamais visible d'un bénévole), je télécharge le modèle (sans aucune marque ni nom de club, un exemple et une explication par feuille), les données de l'association (menu, recettes, prévision), l'export d'un tournoi clôturé (identique à celui de l'onglet Après), et je compare deux tournois clôturés (côte à côte, avec écarts, export Excel).

Si TYPE = nouvelle : ne liste ici que les critères échoués. Dans tous les cas, ajoute :
CONTRÔLE RAPIDE (R31) : 1. le projet se lance et l'écran d'arrivée s'affiche ; 2. la caisse d'un événement en cours encaisse une vente.

CE QUI A ÉTÉ FAIT ET TESTÉ (test de code réussi à chaque étape) :
- F1 avertissement de stock qui suit le ticket ; F2 actualisation entre téléphones (un défaut corrigé : le bilan restait « provisoire ») et glisser vers le bas ; F3 membres et droits dans les Paramètres ; F4 modèle générique sans marque ; F5 écran « Extraction et modèle » ; F6 comparateur de deux tournois.
- Tests de la mission : 466 tests de logique et d'écrans, 255 tests de règles, parcours Android de chaque étape ; parcours complet : `integration_test/parcours_retours_terrain_test.dart` (captures dans `audit_front/retours_terrain/apres/`). Règles d'accès inchangées.
- Parcours déjà rouges sur `main` avant la mission, hors périmètre (libellés périmés) : evenements_test, menus_test, images_test.

NOUVEAUTÉS À VÉRIFIER EN PRIORITÉ (mission de modification : le nouveau comportement et l'absence de l'ancien) :
- Caisse : le message de stock suit le ticket (plus de message resté après retrait de la ligne). Voisins : couleur de rupture du produit, encaissement.
- Paramètres : liste des membres et note ; l'écran de l'association n'a plus la liste des membres. Voisins : code d'accès, suppression de l'association (responsable).
- Extraction et modèle : quatre cartes ; classeurs ouvrables dans un tableur ; comparateur sur deux tournois clôturés. Voisins : bouton Excel de l'onglet Avant, export de l'onglet Après (inchangés).
- Point connu non vérifié par le test de code : la remise réelle d'un fichier à la feuille de partage d'Android (simulée dans les parcours).

COMMENT LANCER LE PROJET :
Mobile Flutter + Firebase, copie locale de Firebase. Émulateur Android `LC2` démarré (`-gpu swiftshader_indirect -no-snapshot -no-audio`), Java 21 d'Android Studio (`C:\Program Files\Android\Android Studio\jbr`) en tête du PATH, puis `flutter pub get` si besoin et, pour les parcours : `firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "flutter test integration_test/<nom>_test.dart -d emulator-5554 --timeout 15m"`. Pas de migration ni de base de données à préparer. Un seul émulateur Firebase à la fois (ports 8080, 9099, 9150).

TON TRAVAIL :
1. Lance le projet selon son socle.
2. Utilise-le en conditions réelles, comme un utilisateur (deux connexions pour les critères 1 et 2).
3. Pour chaque critère de fin de mission : une seule capture d'écran, nommée `critere-N.png`, et un verdict, réussi ou échoué (non vérifié si tu n'as pas pu le voir, avec la raison).
4. Ne rejoue pas les tests des étapes.

RENDU :
- Tableau : critère | capture | verdict (réussi / échoué) | ce que tu as vu, en français
- L'écran exact que Kinder doit utiliser pour son test final.
```

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

## 14. Mission « Ergonomie de la gestion » (décisions 61 à 67, plan, critères et préalables validés par Kinder le 07/11/2026)

**Critère de fin de mission (Kinder, 07/11/2026)** : « J'ouvre un tournoi et je vois tout de suite où j'en suis : Avant, Pendant ou Après, et ce qu'il me reste à faire. Je saisis mon stock de départ gymnase par gymnase, produits rangés par familles ; je vérifie la prévision en une page ; je fais les courses en magasin avec une liste rangée par rayons que je coche. Je télécharge l'Excel : il est propre, expliqué et aux couleurs de l'application, et je peux le remplir puis le réimporter. »

**Références** : captures de l'existant `audit_front/ergonomie/avant/` (07/11/2026, menu modèle de 27 produits, 2 gymnases) ; maquette https://claude.ai/artifact/Nq98zwiUFctzRs43fcaa4S (7 écrans) ; classeur prototype `audit_front/ergonomie/classeur_propose.xlsx` (et son script `audit_front/ergonomie/prototype_classeur.py`) ; classeur actuel `audit_front/ergonomie/classeur_actuel.xlsx`.

**Préalables (à valider avec le plan)** : (1) le chantier démarre après la clôture de la mission « Préparer l'événement » (test, capture et fusion par Kinder) ; (2) les règles d'accès de chaque étape sont déployées sur le vrai projet dès que leurs tests passent, accord donné une fois pour toute la mission ; (3) une session mère (Sonnet) mène les étapes une par une, chacune dans une sous-session neuve ; (4) aucune nouvelle dépendance sans accord de Kinder.

**Ce qu'on ne touche pas** : la caisse des bénévoles, le bilan (déplacé dans « Après », contenu inchangé), les calculs (prévision, courses, calcul inverse, report), les droits des rôles.

**Étapes** (une à la fois, dans l'ordre ; chaque critère est vérifié par un test de code ou sur émulateur ; chaque étape refait ses captures dans `audit_front/ergonomie/apres/`)

| # | Étape | Ce que Kinder voit | Critères (test de code) |
|---|---|---|---|
| E1 | Familles et rayons (décisions 63, 64) | Fiche produit : choix de la famille ; recette : rayon de chaque ingrédient ; ligne libre : rayon | (1) un menu créé depuis le modèle donne à chaque produit sa famille (Croque-monsieur : Croques ; Café : Boissons chaudes ; Coca : Boissons fraîches ; Mars : Snacks et fruits ; Tarte : Fait maison) ; (2) une famille choisie dans la fiche est retrouvée à la réouverture et copiée dans l'événement ; (3) un produit enregistré avant E1 est rangé dans « Autre » sans erreur ; (4) chaque ingrédient du modèle a son rayon (Pain de mie : Boulangerie ; Gruyère : Frais et crèmerie) ; (5) une famille ou un rayon hors liste est refusé (application et règles) |
| E2 | Listes par familles et icônes (décisions 63, 67), appliquées au Menu | Menu rangé en six familles repliables avec compteur ; recherche ; pastilles de couleur | (1) le menu modèle s'affiche en familles dans l'ordre fixe, chaque titre avec son nombre de produits ; (2) une famille se replie et se déplie ; (3) « chocolat » dans la recherche ne laisse que les produits qui le contiennent ; (4) barres de céréales et bonbons n'ont plus d'icône fausse : pastille de la couleur de la famille avec initiales ; (5) la liste par familles est un seul composant, réutilisé aux étapes suivantes |
| E3 | Tableau de bord en trois temps (décision 62) | Onglets Avant / Pendant / Après en tête de l'événement ; liste de tâches avec avancement ; « Ouvrir le tournoi aux bénévoles » | (1) un événement en préparation s'ouvre sur Avant, un en cours sur Pendant, un clôturé sur Après ; (2) Avant montre 4 tâches et la case Matériel « bientôt » ; une tâche est faite quand : stock de départ = au moins un produit compté ; personnes et durée = chaque gymnase a ses personnes ; prévision = bouton « C'est vérifié » appuyé ; courses = au moins une série validée ; l'avancement affiche « n sur 4 » ; (3) Pendant montre les chiffres du jour et, sous « À surveiller », un produit épuisé avec un bouton d'ajout ; (4) Après donne la clôture, le bilan et l'export ; (5) la liste des produits ne remplit plus l'écran ; la correction des images reste accessible (« Produits et images ») ; (6) un bénévole ne voit rien de nouveau ; un gestionnaire ne voit que ses gymnases |
| E4 | Écran Stock de départ (décisions 54, 63) | Un onglet par gymnase avec son compteur ; familles repliables ; boutons − et + ; « Copier vers … » ; « C'est fait » | (1) 24 cocas saisis par + et le clavier au gymnase A : « Gymnases et stocks » affiche 24 ; (2) l'onglet du gymnase compte les produits renseignés ; (3) « Copier vers B » recopie les quantités de A dans B après confirmation, sans toucher un produit de B déjà rempli ; (4) un reste repris est marqué « Repris » ; (5) aucun ingrédient, et le fait maison est replié avec la mention « apporté le jour même » |
| E5 | Écrans Personnes et durée, et Prévision (décisions 55, 56, 63) | Personnes et durée sur un écran court ; prévision en une ligne par produit (chiffre, source colorée, total pour le tournoi) | (1) 120 personnes sur 2 jours : le bandeau de la prévision affiche « 120 personnes × 2 jours » ; (2) Croque-monsieur 0,65 : « 156 » pour le tournoi ; Café 1,3 : « 312 verres » et « 78 L » ; (3) la source se lit sur chaque ligne (Menu, nom de l'événement passé ou du classeur, Corrigé à la main) ; (4) changer de source se fait depuis le bandeau ; (5) le fait maison n'a pas de ligne de prévision et une phrase le dit ; (6) « C'est vérifié » coche la tâche Prévision |
| E6 | Courses par rayons, cases cochées partagées (décisions 64, 65) | Onglets « À acheter » et « Déjà acheté » ; liste par rayons ; cases à cocher ; réglages résumés en une ligne | (1) Pain de mie sous Boulangerie, Café sous Boissons, une ligne libre « Liquide vaisselle » sous Entretien et matériel ; (2) une case cochée sur un téléphone apparaît cochée sur un autre (et les règles refusent une case pour un article absent de la liste) ; (3) cocher ne change ni le stock ni le coût ; (4) quantités identiques à celles d'avant E6 pour le même événement ; (5) le texte partagé est rangé par rayons ; (6) « Saisir ce que j'ai acheté » ouvre la validation actuelle, inchangée |
| E7 | Stock pendant le tournoi (décision 62) | Produits suivis rangés par urgence (épuisé, vide, stock bas, puis le reste) ; produits non suivis repliés ; « + » direct ; « Vide » et « Suivre » dans un menu de la ligne | (1) avec Coca épuisé et Café en stock bas, Coca puis Café apparaissent en tête ; (2) les produits non suivis sont repliés sous une ligne qui les compte ; (3) « + » ajoute au stock comme « Ajouter » aujourd'hui ; (4) « Vide » et « Suivre le stock » restent possibles depuis le menu de la ligne ; (5) un bénévole garde son écran actuel d'ajout de parts et d'apports |
| E8 | Classeur Excel (décision 66) | Classeur avec Accueil, Menu, Recettes, Stock de départ, Historique, Courses (et Bilan à l'export), mis en forme comme le prototype | (1) le modèle téléchargé contient ces feuilles dans cet ordre, la feuille Accueil en premier ; (2) bandeau, en-têtes de couleur, largeurs de colonnes, en-têtes figés et listes déroulantes (type, provenance, famille, unité, rayon) sont présents dans le fichier ; (3) aller-retour : le modèle relu redonne exactement les mêmes produits, familles, recettes et rayons ; (4) l'Historique calcule la consommation par personne et par jour dans sa dernière colonne ; (5) les classeurs à l'ancien format (`recette/historique-tournoi-an-passe.xlsx`, `audit_front/ergonomie/classeur_actuel.xlsx`) s'importent comme avant ; (6) l'export du tournoi suit la même mise en forme |
| E9 | Clôture de mission | Parcours complet et texte de vérification | (1) parcours automatique du critère de fin sur émulateur, avec captures « après » de chaque écran à côté de celles « avant » ; (2) texte de vérification pour une autre IA ; (3) APK de recette reconstruit, version 1.3.0 |

**Dépendances entre étapes** : E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → E9. E2 a besoin des familles (E1) ; E3 range les écrans que E4 à E7 refont ; E6 a besoin des rayons (E1) ; E8 a besoin des familles et des rayons ; E9 en dernier.

**Cadrages d'étape** (phase 5, écrits par la session mère avant chaque étape ; les critères sont ceux du tableau ci-dessus, repris tels quels)

*Cadrage E1 — Familles et rayons (08/11/2026)*
- Stratégie : deux listes fixes en code, reprises à l'identique dans les règles. Familles `croques, boissons_chaudes, boissons_fraiches, snacks_fruits, fait_maison, autre` (libellés : Croques, Boissons chaudes, Boissons fraîches, Snacks et fruits, Fait maison, Autre). Rayons `boulangerie, frais, boissons, epicerie, entretien, autre` (Boulangerie, Frais et crèmerie, Boissons, Épicerie, Entretien et matériel, Autre). Champ facultatif `famille` dans la fiche du produit (absent = « autre ») ; champ facultatif `rayon` sur chaque ingrédient de recette, sur chaque produit acheté tel quel (non composé) et sur chaque ligne libre de courses (absent = « autre »). Rien n'est obligatoire : les données existantes restent valides.
- Fichiers touchés : `lib/depot_menus.dart` (listes, libellés, `FicheProduit.famille`/`rayon`, `Ingredient.rayon`, `erreur()`, lecture du modèle), `lib/courses.dart` (`LigneLibre.rayon`), `lib/depot_evenements.dart` et `lib/evenement.dart` (famille et rayon suivent la fiche copiée dans l'événement), `lib/ecran_menu.dart` (choix de la famille ; rayon par ingrédient ; rayon du produit acheté tel quel), `lib/ecran_courses.dart` (rayon d'une ligne libre, à la saisie seulement), `assets/menu_type.json` (famille et rayon des produits et ingrédients), `firestore.rules` (listes fixes, champs facultatifs dans `produitValide`/`ficheValide`, `ingredientsValides` et lignes libres), tests de logique et `tests_regles/` (nouveau fichier `familles_rayons.test.mjs`, ajouté à `lancer.ps1`).
- Piège : les règles évaluent 1000 expressions au plus par requête. Le contrôle du rayon d'un ingrédient reste une expression courte par position ; mesurer avec un produit à 20 ingrédients et garder de la marge.
- Ce qu'on ne fait pas : aucun affichage par familles (E2), aucune liste par rayons (E6), aucun changement de calcul, pas de colonne Excel (E8), pas de famille ni de rayon libres.
- Test : `flutter analyze`, `flutter test`, `tests_regles/lancer.ps1` (y compris 20 ingrédients avec rayon). Le déploiement des règles est fait par la session mère après les tests.

*Cadrage E2 — Listes par familles et icônes, appliquées au Menu (08/11/2026)*
- Stratégie : un seul composant réutilisable `lib/liste_familles.dart` (widget générique : reçoit des éléments avec leur famille, les range dans l'ordre fixe des six familles, un bloc par famille avec pastille de couleur, titre, compteur, repli/dépli, champ de recherche optionnel, et un constructeur de ligne fourni par l'écran). Couleur de chaque famille définie une fois dans ce fichier (reprendre la maquette `audit_front/ergonomie/maquette/project/Menu.dc.html` : Croques #D9B06F, Boissons chaudes #9A670F, Boissons fraîches #A04467, Snacks et fruits #5A7D4F, Fait maison #6C4F86, Autre gris). Pastille de produit : s'il a une icône juste, l'icône ; sinon une pastille à la couleur de sa famille avec ses initiales (ex. « CM », « Co »). Icônes fausses : on retire l'icône `barre` aux barres de céréales et aux bonbons dans `assets/menu_type.json` (Mars, Twix, Snickers gardent la leur) ; un produit sans icône montre la pastille, jamais une mauvaise image.
- Fichiers touchés : nouveau `lib/liste_familles.dart` ; `lib/ecran_menu.dart` (la liste des produits du menu passe par le composant ; recherche par nom, sans accents ni casse ; familles repliées au départ sauf celles qui ont un résultat de recherche) ; `assets/menu_type.json` ; tests (`test/liste_familles_test.dart` + ajustement des tests d'écran du menu). Aucun changement de règles, aucun changement de données.
- Ce qu'on ne fait pas : pas de liste par familles ailleurs (E4 à E7 réutiliseront le composant), pas de changement de la caisse des bénévoles (elle montre déjà la pastille ou l'icône actuelle), pas de glisser-déposer, pas de famille libre.
- Test : `flutter analyze`, `flutter test`. Pas de test de règles à relancer (règles inchangées).

*Cadrage E3 — Tableau de bord en trois temps (08/11/2026)*
- Stratégie : l'écran `EcranEvenement` (lib/ecran_evenement.dart) garde son en-tête, son QR/ses accès et la caisse du bénévole inchangés. Pour la gestion (`peutModifier`), le corps devient trois onglets **Avant / Pendant / Après** (barre en tête, style de la maquette `audit_front/ergonomie/maquette/project/Main.dc.html` et `Pendant.dc.html`). Onglet ouvert d'emblée : événement en préparation → Avant ; en cours → Pendant ; clôturé → Après. Le bénévole (sans gestion) garde exactement son écran actuel, y compris la liste des produits. Le gestionnaire limité à ses gymnases voit les mêmes onglets, avec ses seules données (les tâches et boutons réservés à la vue complète restent réservés, comme aujourd'hui : Courses, Ouvrir, Clôturer).
- **Avant** : titre « Préparer le tournoi », « n sur 4 faits » + barre d'avancement, 4 tâches cliquables et une 5ᵉ case « Matériel — bientôt » en pointillé, inactive. Tâches et règle « faite » : *Stock de départ* (au moins un produit compté dans au moins un gymnase) ; *Personnes et durée* (chaque gymnase a ses personnes) ; *Prévision* (drapeau « prévision vérifiée ») ; *Courses* (au moins une série validée). Chaque sous-titre dit l'état en clair (« 19 produits comptés », « 120 personnes · 2 jours », « à vérifier »…). Les tâches ouvrent pour l'instant les écrans existants (Préparation, Gymnases et stocks, Courses) : les écrans courts viennent en E4 à E6. Le bouton « Ouvrir le tournoi aux bénévoles » (l'actuel `ouvrir_evenement`, mêmes droits) est en pied, avec la phrase « Les bénévoles ne voient pas encore ce tournoi ».
- **Nouvelle donnée** : champ booléen facultatif `previsionVerifiee` sur le document de l'événement, écrit par la gestion (méthode de `DepotEvenements`, par ex. `definirPrevisionVerifiee`), avec un bouton « C'est vérifié » dans l'étape Prévision de l'écran Préparation actuel (E5 le redessinera). Règles : clé autorisée, booléenne, modifiable seule (comme `nbJours`), événement non clôturé ; test de règles dédié.
- **Pendant** : trois chiffres du jour (ventes, tickets, caisses ouvertes — repris du tableau de bord existant) ; bloc « À surveiller » (produits épuisés, vides ou à stock bas, avec leur gymnase, un état coloré et un bouton « + » qui ajoute au stock comme l'ajout actuel) ; quatre accès : Stock (Gymnases et stocks), Courses d'appoint (Courses, vue complète seulement), Caisses en direct (le suivi actuel `SuiviEnDirect` passe sur son propre écran), Bilan provisoire (écran de bilan existant). Bouton « Clôturer le tournoi » / « Forcer la clôture » en pied (mêmes règles et droits).
- **Après** : clôture (qui, quand, forcée ou non), report des restes, bilan, export Excel : ce qui existe déjà (bilan, export, restes) est rangé ici ; rien de nouveau dans le contenu du bilan.
- **Liste des produits** : ne remplit plus l'écran ; elle passe sur son propre écran « Produits et images » (correction de l'image comme aujourd'hui), ouvert par un bouton dans Avant et dans Pendant, pour la gestion.
- Conserver les `Key` existantes des boutons et textes partout où l'élément subsiste (nombreux tests de logique et d'écrans et de parcours Android les utilisent) ; ajuster les tests qui supposent l'ancienne page unique.
- Fichiers touchés : `lib/ecran_evenement.dart` (et éventuellement un nouveau `lib/ecran_tableau_bord.dart` pour alléger), `lib/evenement.dart`, `lib/depot_evenements.dart`, `lib/ecran_preparation.dart` (bouton « C'est vérifié » seulement), `firestore.rules`, tests de logique/écran, `tests_regles/` (nouveau fichier ajouté à `lancer.ps1`).
- Ce qu'on ne fait pas : pas de nouvel écran de saisie du stock, de personnes, de prévision ou de courses (E4 à E6) ; pas de changement de la caisse des bénévoles, du bilan, des calculs ; pas de matériel réel.
- Test : `flutter analyze`, `flutter test`, `tests_regles/lancer.ps1` ; la session mère déploie les règles et lance les parcours Android utiles.

*Cadrage E4 — Écran Stock de départ (08/11/2026)*
- Stratégie : un nouvel écran court `lib/ecran_stock_depart.dart`, ouvert par la tâche « Stock de départ » de l'onglet Avant (à la place de la Préparation actuelle pour cette tâche) et par « Stock de départ » de la Préparation si elle subsiste. Maquette : `audit_front/ergonomie/maquette/project/StockDepart.dc.html`. Un onglet par gymnase (nom + compteur « produits comptés ») ; sous l'onglet, la liste par familles (composant `ListeFamilles` de E2, repliable, compteur « n sur N comptés ») ; une ligne par produit : pastille, nom, mention « Repris » (en couleur discrète) quand la quantité vient d'un report, boutons − et + et champ numérique au clavier (vide = non compté, « — »). Écriture par les méthodes existantes (`definirStock` ; produit vidé = suppression de la ligne comme aujourd'hui si c'est le comportement actuel, sinon 0). Pied : « Copier vers <autre gymnase> » (confirmation, recopie les quantités du gymnase affiché dans l'autre SANS toucher un produit déjà rempli de l'autre ; un seul autre gymnase proposé, ou un choix s'il y en a plusieurs) et « C'est fait » (retour au tableau de bord).
- Produits listés : seulement ceux qui ont un stock de départ (produits achetés ou en parts, jamais les ingrédients ni les produits composés en recette). La famille « Fait maison » est repliée avec la mention « Apporté le jour même » et reste modifiable si le dépôt actuel le permet. Les familles sans produit sont masquées. Un gestionnaire limité ne voit que ses gymnases (onglets) ; événement non « en préparation » : lecture seule comme aujourd'hui.
- Fichiers touchés : nouveau `lib/ecran_stock_depart.dart` ; `lib/ecran_evenement.dart` (câblage de la tâche) ; `lib/ecran_preparation.dart` (retrait de la carte de saisie du stock de départ si elle devient redondante, sans casser le reste) ; `lib/depot_evenements.dart` seulement si une méthode de copie groupée est utile (pas de règles nouvelles prévues : si les règles doivent changer, le dire) ; tests de logique et d'écran ; ajustement des parcours Android concernés (`integration_test/preparation_test.dart`).
- Ce qu'on ne fait pas : pas de nouvelle donnée, pas de changement du report des restes ni des calculs, pas de saisie des personnes (E5).
- Test : `flutter analyze`, `flutter test`, `tests_regles/lancer.ps1` si les règles bougent ; la session mère lance les parcours Android.

*Cadrage E5 — Écrans Personnes et durée, et Prévision (08/11/2026)*
- Stratégie : deux nouveaux écrans courts, ouverts par les tâches « Personnes et durée » et « Prévision » de l'onglet Avant (E3) ; la page Préparation actuelle (`EcranPreparation`) cesse d'être un passage obligé et est démontée (son contenu est réparti). Maquette : `audit_front/ergonomie/maquette/project/Prevision.dc.html` ; captures de l'existant `audit_front/ergonomie/avant/03_preparation_*.png`.
- **Personnes et durée** (`lib/ecran_personnes_duree.dart`) : le nombre de jours et les personnes de chaque gymnase (champs et saisie existants `definirJours`, `definirPersonnes`, mêmes bornes), total affiché ; un gestionnaire limité ne règle que ses gymnases ; lecture seule hors « en préparation » comme aujourd'hui.
- **Prévision** (`lib/ecran_prevision.dart`) : bandeau sombre « Calculée pour 120 personnes × 2 jours » avec la source en cours et un bouton « Changer » (les sources existantes : menu, événement passé, classeur Excel importé, retour au menu — reprendre la logique de `_EtapePrevision`) ; puis les produits rangés par familles (composant `ListeFamilles`), une ligne par produit : nom, pastille de source colorée (Menu, nom de l'événement passé ou du classeur, Corrigé à la main), champ « par personne et par jour » (correction à la main existante) et à droite le total pour le tournoi (ex. Croque-monsieur 0,65 → « 156 » ; Café 1,3 → « 312 verres » et sous-ligne « 78 L »). Le fait maison n'a pas de ligne : une phrase le dit en bas. Pied : « C'est vérifié » (pose `previsionVerifiee`, tâche cochée) puis accès « Voir la liste de courses ». Les calculs de prévision ne changent pas : seuls l'affichage et le rangement changent.
- **Classeur Excel** : la carte de téléchargement du modèle et d'import d'un classeur (`_CarteClasseur`, résumé avant écriture) quitte la Préparation et se range derrière un bouton « Excel » dans la barre de l'écran de l'événement (gestion, en préparation) ; son fonctionnement ne change pas (E8 la retouchera).
- Fichiers touchés : nouveaux `lib/ecran_personnes_duree.dart` et `lib/ecran_prevision.dart` ; `lib/ecran_preparation.dart` (allégé ou supprimé, sans perdre le classeur) ; `lib/ecran_evenement.dart` et `lib/tableau_bord.dart` (câblage des tâches et du bouton Excel) ; `lib/liste_familles.dart` seulement si un paramètre manque ; tests de logique et d'écran ; parcours Android concernés ajustés (`integration_test/preparation_test.dart`, `previsions_test.dart`, `import_test.dart`, etc.). Pas de nouvelle donnée ni de règles.
- Ce qu'on ne fait pas : pas de changement des formules de prévision, de courses ni de report ; pas d'écran de courses (E6).
- Test : `flutter analyze`, `flutter test` ; la session mère lance les parcours Android.

*Cadrage E6 — Courses par rayons, cases cochées partagées (08/11/2026)*
- Stratégie : l'écran Courses (`lib/ecran_courses.dart`, `lib/courses.dart`) est refait pour le magasin, sans toucher aux quantités calculées (critère 4 : mêmes quantités qu'avant E6 pour un même événement). Maquette : `audit_front/ergonomie/maquette/project/Courses.dc.html` ; captures de l'existant `audit_front/ergonomie/avant/05_courses_*.png`.
- Deux onglets : « À acheter · n/N » (cochés / total) et « Déjà acheté » (séries validées et leurs achats, contenu actuel). Dans « À acheter », les articles sont rangés par rayon (six rayons de la décision 64, ordre fixe, rayons vides masqués, bloc des rayons repliable) : chaque article = case à cocher, nom (+ ligne d'explication : « pour les croques », « 24 verres déjà en stock »), quantité à droite. Sources de rayon : l'ingrédient pour une recette (champ `rayon` de E1), le produit acheté tel quel, la ligne libre ; absent = « Autre ». Un article coché est barré et grisé. Les réglages (durée, personnes, etc.) se résument en une ligne repliable. Partage de la liste (texte et CSV) : rangé par rayons. Pied : « Saisir ce que j'ai acheté » ouvre la validation actuelle, inchangée (`ecran_validation_courses.dart`).
- **Cases partagées (décision 65)** : champ facultatif `coches` (liste de clés d'articles) sur le document de la liste de courses (`courses/liste`), mis à jour en direct sur tous les téléphones de la gestion ; cocher ne change ni le stock ni le coût. Pour que les règles puissent refuser une case pour un article absent de la liste, le document porte aussi `articles` (liste des clés des articles affichés, réécrite par l'application quand la liste change) et les règles exigent que `coches` ne contienne que des clés de `articles` (`coches.hasOnly(articles)`), longueurs bornées (≤ 150 articles, clés de ≤ 80 caractères), un seul champ à la fois autorisé en écriture par un membre de la gestion. Si ce schéma se révèle trop lourd (1000 expressions, gestion d'une liste qui change pendant qu'on coche), proposer UNE alternative simple dans le bilan plutôt que de bricoler. Clés d'article : stables, par exemple `i:<cleIngredient>|<unité>`, `p:<produitId>`, `l:<nom de la ligne libre>`. Une case cochée dont l'article a disparu est ignorée à l'affichage. Les cases se vident à la validation d'une série (nouvelle série = nouvelles courses).
- Fichiers touchés : `lib/ecran_courses.dart` (refonte), `lib/courses.dart` (regroupement par rayon, clés d'article, texte partagé), `lib/depot_evenements.dart` (flux et écriture des cases), `lib/liste_familles.dart` seulement si un paramètre manque (les rayons peuvent réutiliser le composant), `firestore.rules`, tests de logique et d'écran, `tests_regles/` (nouveau fichier ajouté à `lancer.ps1`), parcours Android concernés (`courses_test`, `chantier_complet_test`, `previsions_test`, etc.) ajustés.
- Ce qu'on ne fait pas : aucun changement de formule, de stock, de coût ou de validation ; pas d'écran de courses d'appoint spécifique (c'est le même écran) ; pas de rayon libre.
- Test : `flutter analyze`, `flutter test`, `tests_regles/lancer.ps1` ; la session mère déploie les règles et lance les parcours Android.

*Cadrage E7 — Stock pendant le tournoi (08/11/2026)*
- Stratégie : l'écran « Gymnases et stocks » (`lib/ecran_gymnases.dart`, titre `titre_stock_evenement`) est refait pour l'usage pendant le tournoi, côté gestion seulement. Pour chaque gymnase, les produits SUIVIS sont rangés par urgence : épuisé, puis vide (signalé « vide » par un bénévole), puis stock bas, puis le reste (ordre alphabétique ou ordre des familles à l'intérieur d'un même niveau) ; chaque ligne montre le stock, l'état coloré (même vocabulaire et mêmes seuils qu'aujourd'hui, ne rien changer à la logique d'état), un bouton « + » direct qui ajoute au stock exactement comme l'action « Ajouter » actuelle (même boîte de quantité, mêmes écritures), et un menu de ligne (⋮) qui contient « Vide » (signalement) et « Suivre le stock » / « Ne plus suivre » (selon l'état), sans autre changement de comportement. Les produits NON suivis sont repliés sous une ligne qui les compte (« 5 produits non suivis ») ; les déplier permet de les suivre. Maquette de référence pour l'état coloré et le « + » : `audit_front/ergonomie/maquette/project/Pendant.dc.html` (bloc « À surveiller ») ; captures de l'existant : `audit_front/ergonomie/avant/04_gymnases_et_stocks_*.png`.
- Le bénévole garde son écran actuel (ajout de parts, apports, signal « vide ») : ne pas toucher à `lib/ecran_caisse.dart` ni aux écrans bénévole. Les droits de la gestion (vue limitée aux gymnases gérés) restent ceux d'aujourd'hui. Le composant `ListeFamilles` n'est pas obligatoire ici : le critère est le rangement par urgence.
- Fichiers touchés : `lib/ecran_gymnases.dart` (et un éventuel nouveau fichier pour la logique de tri, par exemple dans `lib/tableau_bord.dart` ou `lib/gymnase.dart`, testable sans écran), tests de logique et d'écran, parcours Android concernés ajustés (`gymnases_test`, `rupture_test`, `stock_role_test`, `suivi_test`, `vues_test`, `restes_test`…). Pas de règles ni de donnée nouvelles.
- Ce qu'on ne fait pas : pas de changement des seuils, des états, du calcul du stock, du report des restes ; pas de nouvelle vue pour le bénévole.
- Test : `flutter analyze`, `flutter test` ; la session mère relance les parcours Android.

*Cadrage E8 — Classeur Excel (08/11/2026)*
- Stratégie : `lib/classeur.dart` (écriture du modèle `modeleClasseur…` et de l'export complet, lecture à l'import) est refait, sans toucher aux calculs. Cible visuelle : le prototype `audit_front/ergonomie/classeur_propose.xlsx` (script `audit_front/ergonomie/prototype_classeur.py` pour les couleurs et la mise en page) et l'écran `audit_front/ergonomie/maquette/project/Classeur.dc.html`.
- Contenu (décision 66) : feuilles dans cet ordre : **Accueil** (explique l'usage, étape par étape, légende des couleurs), **Menu** (colonnes Famille, Produit, Prix, Type, Provenance, Verres par litre, Parts par gâteau, Consommation par personne et par jour), **Recettes** (un ingrédient par ligne : produit, ingrédient, quantité, unité, rayon), **Stock de départ**, **Historique** (avec une dernière colonne calculée « consommation par personne et par jour »), **Courses** (avec le rayon), et **Bilan** à l'export. Les libellés de famille et de rayon sont ceux des listes fixes (décisions 63 et 64) ; à l'import, un libellé inconnu → « Autre » avec une ligne signalée dans le résumé, jamais une erreur bloquante.
- Mise en forme aux couleurs de l'application : bandeau anthracite avec titre et sous-titre, en-têtes colorés, cases blanches à remplir et cases beiges calculées, largeurs de colonnes, en-têtes figés, listes déroulantes (type, provenance, famille, unité, rayon).
- **Étape de faisabilité d'abord** (avant de coder le reste) : vérifier ce que la dépendance `excel` 4.0.6 sait écrire (couleurs, largeurs, volets figés, listes déroulantes / validation de données, formules). Tout ce qui est possible avec `excel` seul est fait. Si les listes déroulantes ou les en-têtes figés NE sont PAS possibles avec `excel` seul, ne pas ajouter de dépendance et ne pas bricoler : faire tout le reste, puis rendre un bilan « partiel » qui dit précisément ce qui manque et UNE option (par exemple retoucher le fichier produit au niveau du zip avec un paquet déjà présent dans `pubspec.lock`) pour décision de Kinder.
- Compatibilité : les classeurs à l'ancien format (`recette/historique-tournoi-an-passe.xlsx`, `audit_front/ergonomie/classeur_actuel.xlsx`) s'importent exactement comme avant ; un classeur sans feuille Recettes (recettes dans l'ancienne colonne) reste lisible ; le nouveau modèle relu redonne exactement les mêmes produits, familles, recettes et rayons. L'export du tournoi suit la même mise en forme.
- Fichiers touchés : `lib/classeur.dart`, `lib/import_classeur.dart` / `lib/import_menu.dart` (lecture des nouvelles colonnes et de la feuille Recettes), `lib/export_bilan.dart` si besoin, `lib/ecran_classeur.dart` (textes d'aide), tests de logique (`test/classeur_test.dart`, `test/import_*`, `test/export_bilan_test.dart`), parcours Android concernés. Pas de règles.
- Ce qu'on ne fait pas : pas de macro, pas de protection par mot de passe, pas de nouvelle dépendance sans accord de Kinder, pas de changement des calculs de prévision.
- Test : `flutter analyze`, `flutter test` ; ouverture du fichier produit par un lecteur xlsx externe (par exemple un petit script Python `openpyxl` avec `python -I`) pour constater en-têtes figés, listes déroulantes et couleurs ; la session mère relance les parcours Android.

*Cadrage E9 — Clôture de mission (08/11/2026)*
- Parcours automatique du critère de fin sur émulateur (`integration_test/parcours_ergonomie_test.dart`, sur le modèle de `parcours_mission_test.dart` et de `integration_test/captures.dart` / `audit_front/lancer.ps1` pour les captures) : créer un tournoi, ouvrir Avant et lire « n sur 4 », saisir le stock de départ de deux gymnases par familles, régler personnes et durée, vérifier la prévision (« C'est vérifié »), faire les courses (cocher des articles rangés par rayons, saisir les achats), télécharger le modèle Excel et le réimporter, ouvrir le tournoi, vérifier Pendant (à surveiller), clôturer et ouvrir Après. Captures « après » de chaque écran dans `audit_front/ergonomie/apres/` avec les mêmes noms que celles de `avant/` quand l'écran existait.
- Texte de vérification pour une autre IA (Sonnet, conversation neuve) : critères de fin de mission, ce qui est fait et testé, nouveautés prioritaires ; rangé dans la section 14 du plan sous « Texte de vérification E9 ».
- Version 1.3.0 (build 4), APK de recette reconstruit et copié dans `recette/le-comptoir-recette.apk` (non suivi par git). Documentation : bloc de statut et section 12 de `PROJET_CONTEXTE.md`, `RECETTE.md` si les étapes de test changent.

**Arrêts prévus** : une contradiction avec une décision figée ; une dépendance nouvelle nécessaire (par exemple si les listes déroulantes ou les en-têtes figés de E8 ne peuvent pas s'écrire avec l'outil Excel actuel) ; deux échecs de suite à la vérification.

**Suivi** (une ligne par étape close)

| Étape | État | Date | Critères |
|---|---|---|---|
| E1 Familles et rayons | Implémentée et testée (397 tests, 241 tests de règles) ; règles déployées le 08/11/2026 | 08/11/2026 | (1) à (5) réussis par test de code |
| E2 Listes par familles et icônes | Implémentée et testée (408 tests) ; règles inchangées | 08/11/2026 | (1) à (5) réussis par test de code |
| E3 Tableau de bord en trois temps | Implémentée et testée (424 tests, 247 tests de règles, 19 parcours Android réussis sur LC2) ; règles déployées le 08/11/2026 | 08/11/2026 | (1) à (6) réussis ; règle `previsionVerifiee` réussie |
| E4 Écran Stock de départ | Implémentée et testée (430 tests, parcours Android concernés réussis) ; règles inchangées | 08/11/2026 | (1) à (5) réussis par test de code |
| E5 Personnes et durée, Prévision | Implémentée et testée (417 tests, 6 parcours Android réussis) ; règles inchangées | 08/11/2026 | (1) à (6) réussis par test de code |
| E6 Courses par rayons, cases partagées | Implémentée et testée (425 tests, 254 tests de règles, 6 parcours Android réussis) ; règles déployées le 08/11/2026 | 08/11/2026 | (1) à (6) réussis ; limite : vérification des articles réduite pour tenir 60 lignes libres sous 1000 expressions |
| E7 Stock pendant le tournoi | Implémentée et testée (434 tests, 7 parcours Android réussis) ; règles inchangées | 08/11/2026 | (1) à (5) réussis par test de code |
| E8 Classeur Excel | Implémentée et testée (439 tests, 6 parcours Android réussis) ; dépendance `archive` 3.6.1 ajoutée avec l'accord de Kinder le 08/11/2026 ; règles inchangées | 08/11/2026 | (1) à (6) réussis |
| E9 Clôture de mission | Parcours complet `parcours_ergonomie_test.dart` réussi sur LC2 (12 captures « après » dans `audit_front/ergonomie/apres/`), APK de recette 1.3.0 reconstruit ; 439 tests, analyse sans erreur | 08/11/2026 | (1) à (3) réussis |


**Texte de vérification E9** (à donner à une IA neuve, sur Sonnet, dans Claude Code, sur le PC ; elle n'a pas écrit le code)

> Tu vérifies la mission « Ergonomie de la gestion » de l'application Le Comptoir (Flutter + Firebase, Android), dossier `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`, branche `claude/ergonomie-gestion`. Tu ne modifies aucun code. Lance l'application selon `PROJET_CONTEXTE.md` section 12 (émulateurs Firebase `auth,firestore` avec Java 21 ou plus ; émulateur Android LC2 ; une suite de parcours à la fois ; `adb shell wm size 1080x2160` pour les captures, `wm size reset` ensuite) et utilise-la en conditions réelles. Rends une capture et un verdict réussi/échoué par critère.
>
> **Critère de fin de Kinder** : « J'ouvre un tournoi et je vois tout de suite où j'en suis : Avant, Pendant ou Après, et ce qu'il me reste à faire. Je saisis mon stock de départ gymnase par gymnase, produits rangés par familles ; je vérifie la prévision en une page ; je fais les courses en magasin avec une liste rangée par rayons que je coche. Je télécharge l'Excel : il est propre, expliqué et aux couleurs de l'application, et je peux le remplir puis le réimporter. »
>
> **Fait et testé** : analyse sans erreur ; `flutter test` 439 ; règles 254 (`tests_regles/lancer.ps1`) ; parcours Android dont `integration_test/parcours_ergonomie_test.dart` (le critère de bout en bout, 12 captures dans `audit_front/ergonomie/apres/`, à comparer à `audit_front/ergonomie/avant/`).
>
> **À vérifier en priorité** : (1) l'écran de l'événement s'ouvre sur l'onglet juste (en préparation : Avant ; en cours : Pendant ; clôturé : Après) et Avant affiche « n sur 4 faits » avec les quatre tâches ; (2) le stock de départ est rangé par familles dépliables, avec la copie d'un gymnase vers l'autre ; (3) personnes et durée, puis la prévision se vérifient en une page (« C'est vérifié ») ; (4) les courses sont rangées par rayons, les cases se cochent et se partagent en direct, la validation ajoute les achats au stock ; (5) Pendant liste en tête ce qui est épuisé (« + » pour ajouter) et « Gymnases et stocks » range les produits par urgence ; (6) le modèle Excel téléchargé a six feuilles (Accueil, Menu, Recettes, Stock de départ, Historique, Courses), couleurs, volets figés, listes déroulantes, et se réimporte avec les mêmes chiffres ; (7) la caisse des bénévoles, le bilan et les calculs sont inchangés.
>
> **Limites connues** : règles limitées pour tenir 1000 expressions (60 articles libres de courses) ; copier une quantité fait perdre « Repris » ; le bouton Excel n'est offert que dans Avant (événement en préparation).

### Prompt de lancement de la session mère (à coller dans une conversation neuve de Claude Code, sur Sonnet, dans `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`)

```
Tu es la session mère de la mission « Ergonomie de la gestion » de Le Comptoir (temps de réalisation : phases 5, 6 et clôture de PHASES_CADRAGE.md).

1. Lis, dans cet ordre : PROJET_CONTEXTE.md (bloc de statut, décisions 61 à 67, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 14 (plan E1 à E9, critères, préalables, références), CHANGELOG.md (dernière entrée), graphify-out/GRAPH_REPORT.md. Regarde les captures de audit_front/ergonomie/avant/ et la maquette donnée en référence.
2. Préalable 1 : vérifie que la mission « Préparer l'événement » est fusionnée dans main. Sinon, tu t'arrêtes là et tu le dis à Kinder.
3. Hygiène git : rien de non enregistré, main à jour avec le dépôt en ligne, puis branche `claude/ergonomie-gestion`. Jamais de travail sur main.
4. Pour chaque étape, de E1 à E9, dans l'ordre :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 14 (« Cadrage En »), critères du plan repris tels quels.
   b. Phase 6 : confie l'étape à une sous-session neuve (Sonnet) avec son seul dossier minimal : le cadrage, les critères, les décisions utiles, les captures et l'écran de maquette concernés, les commandes de test. Elle rend un BILAN au format unique (10 lignes max).
   c. Vérifie toi-même que le test de code ou sur émulateur de chaque critère est réussi (flutter analyze, flutter test, tests_regles/lancer.ps1, parcours Android utiles sur l'émulateur LC2), et refais les captures de l'étape dans audit_front/ergonomie/apres/. Règles d'accès modifiées : déploie-les dès que leurs tests passent (préalable 2).
   d. Ligne dans le tableau de suivi de la section 14, ligne dans CHANGELOG.md, commit sur la branche. Puis étape suivante, sans attendre Kinder.
5. Aucune dépendance nouvelle sans accord de Kinder. La caisse des bénévoles, le bilan et les calculs ne changent pas.
6. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite.
7. Clôture : après E9, lance la vérification par une autre IA dans une conversation neuve sur Sonnet, avec le texte de vérification de E9 (capture et verdict par critère). En cas d'échec, retour en phase 6 sur les seuls critères échoués.
8. Fin : documentation à jour, résumé final dans CHANGELOG.md, branche poussée sur le dépôt, APK de recette 1.3.0 ; puis Kinder fait son test et sa capture. Fusion dans main seulement après son accord écrit.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```

## 15. Mission « Retours du terrain » (décisions 68 à 74, plan et critères validés par Kinder le 11/11/2026)

**Critère de fin de mission (validé par Kinder, 11/11/2026)** : « Sur deux téléphones, je vends sans message de stock fantôme, je vois les ventes de l'autre téléphone, je gère mes membres depuis les Paramètres, et depuis l'écran Extraction et modèle je télécharge le modèle, les données de l'association et l'export d'un tournoi, et je compare deux tournois. »

**Origine** : usage réel d'une caisse sur deux téléphones (captures de Kinder du 11/11/2026 : « Caisse de sebastien », ligne « Barre de céréales pomme » retirée sans encaisser, le message « Stock épuisé … Vous pouvez quand même vendre. » reste affiché avec un total à 0,00 €).

**Constats faits dans le code au cadrage (11/11/2026)** :
- Caisse (`lib/ecran_caisse.dart`, `_EtatCaisse`) : `_alerte` est posée dans `_ajouter` et effacée seulement par `_vider` (encaissement, remise à zéro) et `_voirVentes` ; le bouton de retrait d'une ligne (`retirer_<id>`) ne la recalcule pas.
- Membres : la liste complète avec « Retirer de l'association » n'existe dans les Paramètres (`EcranParametres._sectionResponsable`, `lib/ecran_association.dart`) que pour le responsable ; une autre liste (nommer / retirer le statut de gestionnaire) est en bas de l'écran de l'association, visible par tous, bénévoles compris.
- Actualisation : tous les écrans lisent en direct (flux), aucun écran ne lit une seule fois ; le défaut vu entre deux téléphones n'est donc pas expliqué par le code et doit être reproduit (F2). Kinder n'a pas précisé l'écran concerné : on teste la caisse, l'événement (Pendant), les caisses en direct, le stock et le bilan.
- Modèle : `assets/menu_type.json` (27 produits) ne contient aucun nom de club mais des marques (Coca, Coca Zéro, Fanta, Ice Tea, Oasis, Mars, Twix, Snickers). Le modèle Excel et l'export existent déjà (onglets Avant et Après de l'événement, `lib/ecran_classeur.dart`, `lib/classeur.dart`) ; le comparateur est nouveau.

**Préalables (validés avec le plan)** : (1) la mission démarre après la clôture d'« Ergonomie de la gestion » (vérification par une autre IA, test et capture de Kinder, fusion dans `main`) ; (2) règles d'accès déployées sur le vrai projet dès que leurs tests passent, accord donné une fois pour toute la mission ; (3) une session mère (Sonnet) mène les étapes une par une, chacune dans une sous-session neuve, modèle selon R17 ; (4) aucune nouvelle dépendance sans accord de Kinder.

**Ce qu'on ne touche pas** : les calculs (prévision, courses, calcul inverse, report), le contenu du bilan, les droits des rôles (décisions 19 et 23 : seul le responsable retire un membre et gère les gestionnaires), les menus et événements existants.

**Étapes** (une à la fois, dans l'ordre ; chaque critère est vérifié par un test de code ou sur émulateur)

| # | Étape | Ce que Kinder voit | Critères (test de code) |
|---|---|---|---|
| F1 | Avertissement de stock qui suit le ticket (décision 69) | Caisse | (1) j'ajoute le dernier exemplaire d'un produit : le message s'affiche ; (2) je retire la ligne : il disparaît ; (3) je la remets : il revient ; (4) deux produits en rupture, j'en retire un : le message ne nomme plus que l'autre ; (5) la vente n'est jamais bloquée |
| F2 | Actualisation entre deux téléphones (décision 70) | Écrans principaux | (1) scénario reproduit sur deux téléphones simulés (deux appareils ou deux connexions sur la copie locale de Firebase) : le téléphone A vend, ajoute du stock, ouvre ou clôture une caisse ; on relève pour chaque écran du téléphone B (association, événement Pendant, caisses en direct, stock, bilan, caisse) s'il se met à jour seul ; (2) chaque défaut trouvé est corrigé à sa cause et couvert par un test ; (3) sur ces écrans, glisser vers le bas relit les données sur le serveur et affiche l'état à jour ; (4) hors réseau, glisser vers le bas ne bloque rien et le dit en clair |
| F3 | Membres et droits dans les Paramètres (décision 71) | Paramètres | (1) en responsable : tous les membres avec leur statut, et sur chaque ligne nommer, retirer le statut de gestionnaire, retirer de l'association ; je retire un bénévole ; (2) en gestionnaire : la même liste, sans aucun bouton d'action ; (3) en bénévole : pas de liste ; (4) la liste n'est plus en bas de l'écran de l'association ; (5) la note « Qui peut quoi » liste les droits du responsable, du gestionnaire et du bénévole ; (6) les règles d'accès refusent toujours un retrait par un gestionnaire |
| F4 « opus » | Modèle générique retravaillé (décision 73) | Modèle téléchargé, menu créé depuis le modèle | (1) aucun nom de marque ni de club dans `assets/menu_type.json` ni dans le modèle Excel ; (2) prix, consommations, recettes et rayons restent ceux recalés sur l'association réelle (décision 50), sauf correction justifiée ligne par ligne dans le cadrage ; (3) chaque feuille du modèle vierge a un exemple rempli et une explication ; (4) le modèle se réimporte sans erreur et redonne les mêmes produits ; (5) les menus et événements existants ne changent pas. Marquée « opus » : jugement sur des données réelles à rendre génériques sans perdre leur justesse |
| F5 | Écran « Extraction et modèle » (décision 72) | Bouton depuis l'écran de l'association, à côté de « Menus » | (1) visible par le responsable et les gestionnaires, jamais par un bénévole ; (2) quatre cartes : modèle vierge, données de l'association, export d'un tournoi, comparateur ; (3) le modèle vierge se télécharge ; (4) « données de l'association » : je choisis un menu et je télécharge un classeur avec menu, composition (recettes) et prévision ; (5) « export d'un tournoi » liste les tournois clôturés et produit le même classeur que l'onglet Après ; (6) un gestionnaire limité ne voit que ses gymnases dans l'export |
| F6 | Comparateur d'événements (décision 74) | Carte « Comparer deux tournois » | (1) je choisis deux tournois clôturés ; (2) je vois côte à côte personnes, jours, nombre de ventes, total, coût des courses, résultat ; (3) par produit (retrouvé par son nom) : quantités vendues et consommation par personne et par jour, avec l'écart ; un produit présent d'un seul côté est affiché avec « — » ; (4) les chiffres sont égaux à un calcul fait à la main sur deux tournois de test ; (5) export en Excel aux couleurs de l'application, qui s'ouvre sans erreur |
| F7 | Clôture de mission | Parcours complet et texte de vérification | (1) parcours automatique du critère de fin sur émulateur, avec captures ; (2) texte de vérification pour une autre IA ; (3) APK de recette reconstruit, version 1.4.0 |

**Dépendances entre étapes** : F1, F2 et F3 sont indépendantes ; F4 avant F5 (le modèle vierge téléchargé est celui de F4) ; F5 avant F6 (la carte du comparateur est sur l'écran de F5) ; F7 en dernier. Ordre retenu : F1 → F2 → F3 → F4 → F5 → F6 → F7.

**Arrêts prévus** : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite à la vérification.

**Suivi** (une ligne par étape close)

| Étape | État | Date | Critères |
|---|---|---|---|
| F1 | Close | 11/11/2026 | 5 critères sur 5 par test de code (440 tests de logique et d'écrans, analyse sans erreur) |
| F2 | Close | 11/11/2026 | 1 à 4 réussis : un seul défaut reproduit (bilan resté « provisoire » après clôture par un autre téléphone), corrigé ; glisser vers le bas sur 5 écrans, hors réseau géré ; 447 tests, parcours `actualisation_test` vert (45 relevés). Parcours ergonomie/gymnases/événements à rejouer à la clôture |
| F3 | Close | 11/11/2026 | 1 à 6 réussis : liste des membres dans les Paramètres (actions pour le responsable seul, lecture seule pour un gestionnaire, rien pour un bénévole), note « Qui peut quoi », test de règles du critère 6 (255) ; 447 tests ; parcours membres, paramètres, association, recette, actualisation verts. Deux parcours rouges déjà sur `main` avant la mission : evenements_test (« Paiements : Espèces, Chèque ») et menus_test (libellé de prix) : tests périmés par l'ergonomie, à traiter hors mission |
| F4 | Close | 11/11/2026 | 1 à 5 réussis : marques remplacées (Cola, Cola zéro, Soda à l'orange, Thé glacé, Boisson fruitée, trois barres nommées par leur nature), chiffres inchangés (test), exemple et explication par feuille du modèle vierge, réimport identique ; 452 tests ; `chantier_complet` vert. `parcours_ergonomie` non confirmé (figé à la connexion), à rejouer à la clôture ; `images` (integration_test) périmé depuis E2 (icône des barres retirée), à adapter |
| F5 | Close | 11/11/2026 | 1 à 6 réussis : écran « Extraction et modèle » (bouton à côté de « Menus », gestion seulement), quatre cartes, modèle vierge et classeur « données de l'association » relus en test, export d'un tournoi identique à l'onglet Après (empreinte de toutes les feuilles) et limité aux gymnases d'un gestionnaire limité ; 456 tests ; 2 parcours Android verts. Le téléchargement réel sur téléphone n'est pas vérifié (remise de fichier simulée) : à voir au test de Kinder |
| F6 | Close | 11/11/2026 | 1 à 5 réussis : comparateur de deux tournois clôturés (synthèse et par produit, « — » d'un seul côté), chiffres égaux à un calcul à la main (10 tests), export Excel relu (feuilles Synthèse et Produits) ; 466 tests ; parcours Android vert. Les courses non validées s'affichent « — » (pas de mention), coût et résultat réservés à qui a droit aux courses |
| F7 | Close (vérifiée par une autre IA ; fusionnée sur accord écrit de Kinder, sans test final consigné) | 11/11/2026 | (1) parcours du critère de fin vert sur émulateur (sans captures : la conversion de la surface fige l'émulateur du poste, captures laissées à l'IA de vérification) ; (2) texte de vérification rangé ci-dessus ; (3) APK 1.4.0+5 reconstruit. Suite complète rejouée : 33 parcours verts sur 38 au premier passage ; recette et google verts après relance ; rouges déjà présents sur `main` : evenements, menus, images ; `parcours_ergonomie` figé comme `parcours_retours_terrain` avec les captures ; Vérification par une autre IA (Sonnet, conversation neuve) le 11/11/2026 : critères 1 à 4 réussis à l'écran de l'émulateur, contrôle rapide réussi, aucun défaut visuel ; remise réelle des trois classeurs à la feuille de partage d'Android vue. Réserves : coût des courses et résultat du comparateur non vus avec de vrais achats (« — » sans courses), comparaison lente (7 à 8 s en version de développement), actions « Nommer » et « Retirer » non cliquées (couvertes par le parcours), mode hors réseau et rond d'actualisation non photographiés |

**Cadrage F1 (11/11/2026)** : l'avertissement n'est plus un état mémorisé mais se calcule d'après le ticket (`_EtatCaisse._alerte` devient un accesseur) : il nomme tous les produits suivis dont la quantité au ticket atteint ou dépasse le stock, et disparaît avec la ligne. Fichiers touchés : `lib/ecran_caisse.dart`, `test/caisse_evenement_test.dart`. On ne touche pas : la vente (jamais bloquée), les couleurs de rupture, le stock. Critères : ceux du tableau (F1, 1 à 5). Note : l'ancien comportement n'avertissait qu'au dépassement ; la décision 69 dit « atteint ou dépasse » (critère 1 : le dernier exemplaire déclenche le message), le test existant a été mis à jour en conséquence.

**Cadrage F2 (11/11/2026) : relevé sur deux téléphones simulés**

Méthode : parcours `integration_test/actualisation_test.dart` sur l'émulateur Android et la copie locale de Firebase. Le téléphone B est l'application affichée (le responsable) ; le téléphone A est une seconde connexion indépendante (autre instance Firebase, compte de Léa) qui rejoint, ouvre sa caisse, vend, ajoute du stock (apport) et clôture. Pour chaque écran de B, on relève s'il se met à jour seul.

| Écran de B | Ce que fait A | Se met à jour seul ? |
|---|---|---|
| Association | rejoint ; un autre téléphone ouvre un événement | Oui : le membre apparaît, la pastille passe de « En préparation » à « En cours » |
| Événement, onglet Pendant | ouvre sa caisse, vend, vend le dernier, ajoute du stock, clôture | Oui : « Caisses ouvertes », « Ventes », « À surveiller » (apparaît puis disparaît) |
| Caisses en direct | rouvre, vend, ajoute du stock, clôture | Oui : total, produit vendu et stock, carte de la caisse (Ouverte, Clôturée) |
| Stock | vend, ajoute du stock | Oui : « Stock » et « Vendu » |
| Bilan | rouvre, vend, clôture | Oui : total, nombre de ventes, bandeau « caisses ouvertes ». **Non** : quand un autre téléphone clôture l'événement, le bilan reste « provisoire » |
| Caisse de B | vend, ajoute du stock | Oui : le stock sur la tuile du produit |

Cause du seul défaut (bilan) : l'écran du bilan recevait l'événement tel qu'il était à l'ouverture (copie) au lieu de le suivre. Tous les autres écrans lisent en direct et se mettent à jour (25 relevés sur 26 réussis). Le défaut exact vu par Kinder n'est pas reproductible autrement : rien d'autre ne s'est figé. S'il revient sur un écran précis, sa capture dira lequel. Reste non suivi, sans conséquence aujourd'hui : le nom de l'événement rappelé en tête de l'écran Stock (copie à l'ouverture).

Correction : `EcranBilan` reçoit en plus le flux de l'événement (`evenementEnDirect`) et passe de « provisoire » à « définitif » dès la clôture (tests `test/actualisation_test.dart` et parcours).

« Glisser vers le bas pour actualiser » (`lib/actualisation.dart`) : sur l'association, l'événement, les caisses en direct, le stock et le bilan. Il relit sur le serveur (lectures `Source.server` : `DepotAssociations.actualiser`, `DepotEvenements.actualiser`, `DepotCaisses.actualiser`) ; les écoutes en direct affichent aussitôt ce qui a été relu. Hors réseau (ou sans réponse en 10 s), un message court « Hors réseau : affichage des dernières données reçues » s'affiche, rien n'est bloqué et le geste se termine. Coût : le geste relit aussi les ventes des caisses visibles (même volume qu'une ouverture du bilan) ; un geste par écran, jamais en boucle. Règles d'accès : inchangées.

### Prompt de lancement de la session mère (à coller dans une conversation neuve de Claude Code, sur Sonnet, dans `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`)

```
Tu es la session mère de la mission « Retours du terrain » de Le Comptoir (temps de réalisation : phases 5, 6 et clôture). Tu ne codes pas toi-même : tu cadres, tu confies chaque étape à une sous-session neuve, tu vérifies ses tests et tu tiens le suivi.

1. Lis, dans cet ordre : V:\DEV\METHODO\3_CHANTIER.md, PROJET_CONTEXTE.md (bloc STATUT, décisions 68 à 74, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 15 (plan F1 à F7, critères, constats, préalables), CHANGELOG.md (dernière entrée), graphify-out/GRAPH_REPORT.md.
2. Préalable 1 : vérifie que la mission « Ergonomie de la gestion » est fusionnée dans main et que la branche `claude/cadrage-retours-terrain` (ce plan) l'est aussi. Sinon, tu t'arrêtes là et tu le dis à Kinder.
3. Hygiène git : rien de non enregistré, main à jour avec le dépôt en ligne, puis branche `claude/retours-terrain` depuis main. Jamais de travail sur main.
4. Pour chaque étape, de F1 à F7, dans l'ordre :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 15 (« Cadrage Fn »), critères du plan repris tels quels.
   b. Phase 6 : confie l'étape à une sous-session neuve au format MISSION (R14), modèle selon R17 : Sonnet, sauf F4 marquée « opus ». Dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test. Elle rend un BILAN au format unique (R15, 10 lignes max).
   c. Vérifie que le test de code ou sur émulateur de chaque critère est réussi (flutter analyze, flutter test, tests_regles/lancer.ps1, parcours Android utiles sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent (préalable 2).
   d. Ligne dans le tableau de suivi de la section 15, ligne dans CHANGELOG.md, commit sur la branche. Puis étape suivante, sans attendre Kinder.
5. F2 : commence par reproduire le défaut sur deux téléphones simulés et relève écran par écran ce qui se met à jour seul ; corrige la cause avant d'ajouter « glisser vers le bas ».
6. Aucune dépendance nouvelle sans accord de Kinder. Les calculs, le contenu du bilan et les droits des rôles ne changent pas (seul le responsable retire un membre).
7. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite.
8. Clôture (F7) : checklist C1 à C8, texte de vérification rangé en section 15, puis vérification par une autre IA dans une conversation neuve sur Sonnet (capture et verdict par critère). En cas d'échec, retour en phase 6 sur les seuls critères échoués.
9. Fin : documentation à jour, résumé final dans CHANGELOG.md, graphify à jour, branche poussée sur le dépôt, APK de recette 1.4.0 ; puis Kinder fait son test et sa capture. Fusion dans main seulement après son accord écrit.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```

## 16. Mission « Prêt pour le tournoi » (décisions 75 à 79, plan et critères validés par Kinder le 11/11/2026)

**Critère de fin de mission (validé par Kinder, 11/11/2026)** : « Dans l'association test, depuis Extraction et modèle, j'importe le classeur de notre club : le menu, l'an passé, la prévision et le stock de départ du tournoi sont en place sans autre saisie ; j'enregistre un fichier dans Téléchargements ; j'ajoute un produit depuis Produits et images et je le vois en caisse et dans le menu ; dans la prévision j'annule un changement de source ; je vois l'heure de la dernière actualisation ; je change le statut d'un membre ; Paramètres et Courses sont rangés en cartes comme le reste de l'application. »

**Origine** : retours de Kinder du 11/11/2026, avant la mise en service pour le tournoi du week-end (association « test », qui est celle du tournoi), avec une capture des Paramètres (sections séparées par des traits, sans cartes, un seul membre).

**Constats faits dans le code au cadrage (11/11/2026)** :
- Fichiers : `lib/partage.dart` ne fait que la feuille de partage d'Android (`Share.shareXFiles`) ; aucun enregistrement. `file_picker` 11.0.3 (déjà accordé) offre `FilePicker.saveFile(bytes: …)` sur Android : pas de nouvelle dépendance.
- Import : deux chemins séparés. `lib/ecran_menus.dart` (« Importer un menu depuis Excel », `lib/import_menu.dart`, feuille Menu, crée un menu) et `lib/ecran_classeur.dart` ouvert depuis l'événement (« Importer un classeur », `lib/import_classeur.dart` : stock de départ de l'événement + références de l'Historique ; feuilles Menu, Courses et Bilan ignorées). Les références (`DepotEvenements.appliquerImport`, collection `references`) sont rangées au niveau de l'association : elles ne demandent pas d'événement ; le stock de départ, si.
- Classeur de l'an passé : `recette/historique-tournoi-an-passe.xlsx` (fait en P9 le 07/11/2026, importé alors sur émulateur seulement).
- Paramètres (`EcranParametres`, `lib/ecran_association.dart`) : sections séparées par `Divider`, sans cartes ; actions « Nommer gestionnaire », « Retirer le statut de gestionnaire », « Retirer de l'association » en boutons texte, visibles seulement sur les autres membres (Kinder étant seul membre, il n'en voyait aucune).
- Prévision (`lib/ecran_prevision.dart`) : « D'après une source » et « Revenir au menu » (remet tout aux chiffres du menu) ; rien ne rend l'état d'avant le dernier changement de source.
- Courses (`lib/ecran_courses.dart`, 973 lignes) : non revue à l'écran depuis Ergonomie (fusionnée sans vérification par une autre IA).
- « Produits et images » (`EcranProduitsEvenement`, `lib/ecran_evenement.dart`) : image seulement. Règle `evenements/{e}/produits/{p}` : `create` déjà permis à la gestion quand `reglableApres(a, e)` ; à vérifier au cadrage de T4 (en cours compris ?).
- Actualisation (`lib/actualisation.dart`) : aucun repère d'heure.

**Réponse de Kinder (11/11/2026)** : les produits et les prix du week-end sont ceux du menu déjà saisi dans l'association test. Le classeur du club (T3) ne recrée donc pas de menu : l'assistant reprend le menu existant de même nom, et le classeur apporte l'an passé (et le stock de départ si sa feuille est remplie).

**Préalables (validés avec le plan)** : (1) la mission démarre maintenant : « Retours du terrain » est fusionnée et n'attend que la capture de Kinder (R29) ; (2) règles d'accès déployées sur le vrai projet dès que leurs tests passent, accord donné une fois pour toute la mission ; (3) une session mère (Sonnet) mène les étapes une par une, chacune dans une sous-session neuve, modèle selon R17 ; (4) aucune nouvelle dépendance sans accord de Kinder ; (5) pas de banc d'essai dans cette mission (décision 75, écart assumé par Kinder) : N3 = `tests_regles/lancer_integration.ps1` ; rouges connus au départ : `evenements_test`, `menus_test`, `images_test`, et `parcours_ergonomie_test` / `parcours_retours_terrain_test` figés par les captures.

**Ce qu'on ne touche pas** : les calculs (prévision, courses, calcul inverse, report), le bilan, la caisse (sauf l'affichage du produit ajouté), les droits des rôles (décisions 19, 23, 71), le nom et le prix d'un produit déjà dans un événement, les menus et événements existants (hors ajout de T4).

**Étapes** (une à la fois, dans l'ordre ; niveau de preuve selon R34)

| # | Étape | Ce que Kinder voit | Critères | Preuve |
|---|---|---|---|---|
| T1 | Enregistrer sur le téléphone (décision 76) | Chaque bouton de fichier | (1) les six fichiers (modèle, données de l'association, export d'un tournoi, comparateur, classeur de l'événement, liste de courses) proposent « Enregistrer sur le téléphone » et « Partager » ; (2) « Enregistrer » ouvre le choix du dossier et le fichier y est, lisible ; (3) annuler le choix ne montre aucune erreur ; (4) aucune dépendance ajoutée | N1 + N2 (service du téléphone : enregistrement réel d'un fichier sur l'émulateur) |
| T2 « opus » | Assistant d'import unique (décision 77) | Carte « Importer » dans Extraction et modèle | (1) départ : modèle générique ou classeur choisi ; (2) menu : nouveau menu créé, ou menu existant de même nom repris sans modification ; (3) anciens tournois enregistrés comme références de prévision ; (4) tournoi en préparation choisi (facultatif) : stock de départ rempli (gymnases et produits retrouvés par leur nom) et prévision réglée sur la référence importée ; (5) résumé avant toute écriture, lignes ignorées avec leur raison ; (6) « Importer un menu » et « Importer un classeur » renvoient vers l'assistant ; (7) un bénévole ne voit pas l'assistant ; (8) un classeur à l'ancien format reste importable. Marquée « opus » : fusion de deux imports et enchaînement sur le tournoi, beaucoup de cas | N1 + N2 (vrai moteur de données et ses règles vus depuis l'application) |
| T3 | Classeur du club pour l'association test | Fichier `recette/classeur-notre-club.xlsx` | (1) produit par Claude Code d'après `recette/historique-tournoi-an-passe.xlsx`, avec un relevé de ce qui a été repris ou non ; (2) feuille Menu laissée vide ou au nom du menu de l'association test : aucun menu en double ; (3) feuille Stock de départ prête à remplir (gymnases à nommer comme dans le tournoi) ; (4) importé par l'assistant sur émulateur sans erreur, consommations égales au relevé | N2 (import réel sur émulateur) |
| T4 | Ajouter un produit (décision 78) | Bouton « Ajouter un produit » dans Produits et images | (1) en préparation et en cours : le produit est créé dans l'événement et dans le menu d'origine ; (2) il apparaît dans stock de départ, prévision, courses et caisse ; (3) nom et prix des produits existants inchangés ; (4) événement clôturé : pas de bouton ; (5) un bénévole ne peut pas ajouter (test de règles) | N1 + N2 (règles vues depuis l'application, caisse) |
| T5 | Annuler un changement de source (décision 79 a) | Prévision | (1) après « D'après une source », « Annuler ce changement » rend exactement les chiffres d'avant, corrections à la main comprises ; (2) « Revenir au menu » marche comme avant ; (3) l'annulation se lit aussi sur un autre téléphone | N1 |
| T6 | Heure de la dernière actualisation (décision 79 b) | Écrans actualisables (association, événement, caisses en direct, stock, bilan) | (1) ligne « Actualisé le JJ/MM à HH:MM » sous le titre ; (2) mise à jour après un glisser vers le bas réussi ; (3) hors réseau, elle ne change pas et le message hors réseau s'affiche | N1 |
| T7 | Paramètres en cartes (décision 79 c) | Paramètres | (1) cartes Mon compte, Association et code, Membres, Qui peut quoi (repliable), Zone dangereuse, aux couleurs de la décision 31 ; (2) chaque membre a un badge de statut ; (3) responsable : « Changer le statut » propose bénévole, gestionnaire, retirer de l'association, avec confirmation ; (4) gestionnaire : liste sans action ; bénévole : pas de liste ; (5) règles inchangées (un gestionnaire ne retire toujours personne) | N1 |
| T8 | Page Courses en cartes (décision 79 d) | Courses | (1) bandeau résumé (durée, personnes, coût cumulé) ; (2) rayons en cartes repliables avec compteur ; (3) actions (Ajouter une ligne, Partager / Enregistrer, Valider) fixées en bas ; (4) tous les tests de calcul des courses passent sans modification ; (5) captures avant et après rangées dans `audit_front/tournoi/` | N1 |
| T9 | Clôture de mission | Parcours complet et texte de vérification | (1) N3 avec la suite actuelle : vert ou rouges connus seulement ; (2) texte de vérification pour une autre IA rangé dans cette section ; (3) APK de recette 1.5.0 reconstruit ; (4) rappel à Kinder : installer 1.5.0 sur tous les téléphones du week-end, essai à blanc vendredi sur deux téléphones (vraie coupure de réseau, connexion Google), capture qui sert aussi à « Retours du terrain » | N3 |

**Dépendances entre étapes** : T1 avant T2 et T8 (boutons de fichier) ; T2 avant T3 (le classeur s'importe par l'assistant) ; T4 à T7 indépendantes ; T9 en dernier. Ordre retenu, du plus utile au tournoi au plus visuel : T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9.

**Arrêts prévus** : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite.

**Suivi** (une ligne par étape close)

| Étape | État | Date | Critères |
|---|---|---|---|

### Prompt de lancement de la session mère (à coller dans une conversation neuve de Claude Code, sur Sonnet, dans `V:\DEV\PROJETS\applications_mobile\Le_Comptoir`)

```
Tu es la session mère de la mission « Prêt pour le tournoi » de Le Comptoir (temps de réalisation : phases 5, 6 et clôture). Tu ne codes pas toi-même : tu cadres, tu confies chaque étape à une sous-session neuve, tu vérifies ses tests et tu tiens le suivi. Le tournoi a lieu ce week-end : va droit au but.

1. Lis, dans cet ordre : V:\DEV\METHODO\3_CHANTIER.md, PROJET_CONTEXTE.md (bloc STATUT, décisions 13, 19, 23, 56, 70 à 79, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 16 (plan T1 à T9, critères, constats, préalables), CHANGELOG.md (dernière entrée), graphify-out/GRAPH_REPORT.md.
2. Préalable : vérifie que la branche `claude/cadrage-pret-tournoi` (ce plan) est fusionnée dans main. Sinon, tu t'arrêtes là et tu le dis à Kinder.
3. Hygiène git : rien de non enregistré (le dossier `graphify-out/converted/`, produit par graphify, n'est pas du travail de Kinder : laisse-le), main à jour avec le dépôt en ligne, puis branche `claude/pret-tournoi` depuis main. Jamais de travail sur main.
4. Pour chaque étape, de T1 à T9, dans l'ordre :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 16 (« Cadrage Tn »), critères du plan repris tels quels.
   b. Phase 6 : confie l'étape à une sous-session neuve au format MISSION (R14), modèle selon R17 : Sonnet, sauf T2 marquée « opus ». Dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test. Elle rend un BILAN au format unique (R15, 10 lignes max).
   c. Vérifie la preuve au niveau écrit au plan (N1 : flutter analyze, flutter test, tests_regles/lancer.ps1 ; N2 : le seul parcours Android qui prouve le critère, sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent (préalable 2).
   d. Ligne dans le tableau de suivi de la section 16, ligne dans CHANGELOG.md, commit sur la branche. Puis étape suivante, sans attendre Kinder.
5. Pas de banc d'essai dans cette mission (décision 75) : N3 de la clôture = powershell -File tests_regles/lancer_integration.ps1 ; rouges connus : evenements_test, menus_test, images_test, et les parcours à captures figés (parcours_ergonomie_test, parcours_retours_terrain_test). Une sous-session n'enquête jamais sur un rouge connu.
6. T3 : les produits et prix du week-end sont ceux du menu déjà saisi dans l'association test : le classeur du club ne crée pas de menu ; il part de recette/historique-tournoi-an-passe.xlsx.
7. Aucune dépendance nouvelle sans accord de Kinder. Les calculs, le bilan et les droits des rôles ne changent pas ; le nom et le prix d'un produit déjà dans un événement restent figés.
8. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite.
9. Clôture (T9, R11) : N3, puis vérification par une autre IA dans une conversation neuve sur Sonnet (capture et verdict par critère de fin). En cas d'échec, retour en phase 6 sur les seuls critères échoués. Puis documentation et CHANGELOG, branche poussée, APK de recette 1.5.0 ; fusion dans main seulement sur accord écrit de Kinder ; la mission ne passe « Close » qu'après son test final avec capture.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```

### Cadrage T1 — Enregistrer sur le téléphone (décision 76)

**Critères (repris du plan)** : (1) les six fichiers (modèle, données de l'association, export d'un tournoi, comparateur, classeur de l'événement, liste de courses) proposent « Enregistrer sur le téléphone » et « Partager » ; (2) « Enregistrer » ouvre le choix du dossier et le fichier y est, lisible ; (3) annuler le choix ne montre aucune erreur ; (4) aucune dépendance ajoutée.

**Stratégie** : un seul point d'entrée dans `lib/partage.dart`. Les deux fonctions par défaut (`partagerFichier`, `partagerFichierTexte`) gardent leur signature (les écrans et les tests qui injectent un faux partageur ne changent pas) mais, au lieu d'ouvrir directement la feuille de partage, affichent une petite feuille de choix « Enregistrer sur le téléphone » / « Partager ». Pour avoir un contexte sans changer les signatures : clé de navigation globale `navigatorCle` déclarée dans `partage.dart` et branchée sur le `MaterialApp` de `lib/main.dart`. « Enregistrer » = `FilePicker.saveFile(fileName:, bytes:)` (file_picker 11.0.3, déjà accordé) ; fermeture sans choix (retour nul) = silence, jamais d'erreur ; échec réel = message simple. « Partager » = comportement actuel (`Share.shareXFiles`). Libellés en français, boutons aux couleurs de la décision 31.

**Fichiers touchés** : `lib/partage.dart`, `lib/main.dart` (clé de navigation), `test/` (un test d'écran de la feuille de choix), un parcours N2 court dans `integration_test/`.

**On ne fait pas** : aucune dépendance, aucun changement des contenus des fichiers, des écrans appelants ni des calculs ; pas de refonte des boutons existants (leurs libellés peuvent rester).

**Preuve** : N1 (`flutter analyze`, `flutter test`) ; N2 : sur l'émulateur LC2, un fichier enregistré réellement via le sélecteur Android et retrouvé lisible ; annulation sans erreur.

### Cadrage T2 — Assistant d'import unique (décision 77), étape « opus »

**Critères (repris du plan)** : (1) départ : modèle générique ou classeur choisi ; (2) menu : nouveau menu créé, ou menu existant de même nom repris sans modification ; (3) anciens tournois enregistrés comme références de prévision ; (4) tournoi en préparation choisi (facultatif) : stock de départ rempli (gymnases et produits retrouvés par leur nom) et prévision réglée sur la référence importée ; (5) résumé avant toute écriture, lignes ignorées avec leur raison ; (6) « Importer un menu » et « Importer un classeur » renvoient vers l'assistant ; (7) un bénévole ne voit pas l'assistant ; (8) un classeur à l'ancien format reste importable.

**Stratégie** : on ne réécrit aucune lecture ni aucun calcul, on enchaîne l'existant. (a) Logique pure dans un nouveau `lib/import_assistant.dart` : `PlanAssistant` = plan de menu (`preparerImportMenu`, `lib/import_menu.dart`) + choix « créer » ou « reprendre le menu existant de même nom » (comparaison par `cleIngredient`) + plan d'import de `preparerImport` (`lib/import_classeur.dart`, références et stock de départ) + intention de régler la prévision sur la référence importée (la référence du premier tournoi lu, ou celle choisie) ; un seul résumé liste tout ce qui sera écrit et les lignes ignorées avec leur raison. (b) Nouvel écran `lib/ecran_import.dart` : étape Départ (« Télécharger le modèle » via T1, ou « Choisir mon classeur »), étape Menu (nom proposé, détection d'un menu existant de même nom), étape Tournoi facultatif (liste des tournois en préparation, « Aucun » par défaut), puis résumé et « Appliquer ». (c) Écritures par les méthodes existantes seulement : `creerMenuDepuisClasseur`, `DepotEvenements.appliquerImport` (références + stock), et la méthode qui règle la prévision d'après une référence (`depot_evenements.dart` autour de la ligne 655). Rejouable sans risque. (d) Entrée : cinquième carte « Importer » dans `lib/ecran_extraction.dart` (gestion seulement, comme les quatre autres, ce qui règle le critère 7). (e) « Importer un menu depuis Excel » (`lib/ecran_menus.dart`) et « Importer un classeur » (`lib/ecran_classeur.dart`) ouvrent l'assistant (le second avec le tournoi déjà choisi) ; leur ancien code de lecture/écriture est retiré ou reste appelé par l'assistant, sans doublon. (f) Le lecteur de classeur `lireClasseur` ne change pas : les classeurs à l'ancien format restent importables (critère 8). Un menu existant n'est jamais modifié ; la feuille Courses n'est pas importée.

**Fichiers touchés** : nouveaux `lib/import_assistant.dart`, `lib/ecran_import.dart` ; modifiés `lib/ecran_extraction.dart`, `lib/ecran_menus.dart`, `lib/ecran_classeur.dart`, au besoin `lib/depot_evenements.dart` / `lib/depot_menus.dart` pour un petit enchaînement ; tests dans `test/` et `integration_test/` (adaptation des tests d'import qui visaient les anciens boutons, sans toucher aux rouges connus). `firestore.rules` : seulement si un test de règles montre qu'une écriture de l'assistant est refusée à la gestion (alors déployer après tests, préalable 2).

**On ne fait pas** : aucun changement de calcul, de bilan, de droits des rôles, de menu ou d'événement existant ; pas de nouvelle dépendance ; pas d'import de la feuille Courses.

**Preuve** : N1 (`flutter analyze`, `flutter test`, `tests_regles/lancer.ps1` si les règles bougent) ; N2 : un parcours sur LC2 avec le vrai moteur de données local : l'assistant lit `recette/historique-tournoi-an-passe.xlsx`, crée le menu ou reprend le menu de même nom, écrit références, stock et prévision sur un tournoi en préparation, et un bénévole ne voit pas l'assistant.

### Cadrage T3 — Classeur du club pour l'association test

**Critères (repris du plan)** : (1) produit par Claude Code d'après `recette/historique-tournoi-an-passe.xlsx`, avec un relevé de ce qui a été repris ou non ; (2) feuille Menu laissée vide ou au nom du menu de l'association test : aucun menu en double ; (3) feuille Stock de départ prête à remplir (gymnases à nommer comme dans le tournoi) ; (4) importé par l'assistant sur émulateur sans erreur, consommations égales au relevé.

**Stratégie** : un petit script Python (openpyxl, dans le dossier temporaire, pas dans le dépôt) lit l'historique de l'an passé (feuilles Menu vide, Stock de départ vide, Historique de 38 lignes, Courses vide) et écrit `recette/classeur-notre-club.xlsx` : mêmes feuilles et mêmes en-têtes (format lu par `lib/classeur.dart`), feuille Menu laissée vide (le menu du week-end est déjà dans l'association test, décision de Kinder : aucun menu créé), feuille Historique reprise ligne pour ligne (événement, gymnase, personnes, jours, produit, quantité), feuille Stock de départ avec une ligne par gymnase et par produit de l'historique, quantité vide (produit non suivi tant que Kinder ne remplit pas), feuille Courses vide. Le relevé (repris, non repris, pourquoi, gymnases et produits à vérifier contre le menu de l'association test) est écrit dans la section « Relevé T3 » de ce plan (pas de nouveau .md : limite de 5 fichiers atteinte). N2 : le parcours `assistant_import_test` (ou un court parcours dédié) importe ce classeur sur l'émulateur et compare les consommations par personne et par jour au relevé.

**Fichiers touchés** : `recette/classeur-notre-club.xlsx` (nouveau), section « Relevé T3 » de ce plan, un test d'import dédié si nécessaire. **On ne fait pas** : aucun code de l'application, aucun menu, aucun accès au vrai projet Firebase, aucune dépendance.

### Relevé T3 — Classeur du club (recette/classeur-notre-club.xlsx)

**Repris** : l'Historique de l'an passé, ligne pour ligne : 38 lignes, un seul événement « Tournoi de l'an passé », 2 gymnases (« Gymnase 1 » : 53 personnes, « Gymnase 2 » : 60 personnes), 2 jours, 19 produits. Stock de départ : 38 lignes (2 gymnases x 19 produits), quantité vide (produits non suivis tant que Kinder ne remplit pas). Mêmes feuilles, bandeaux, explications et en-têtes que le modèle de l'application (Accueil, Menu, Recettes, Stock de départ, Historique, Courses).

**Non repris** : le Menu (vide, en-têtes seuls) : le menu du week-end est déjà dans l'association test, aucun menu n'est donc créé ni dupliqué. Recettes et Courses : vides (l'historique de l'an passé n'en contenait pas ; Courses est ignorée à l'import). Aucune quantité de stock : l'an passé n'en avait pas, rien n'est inventé. La colonne Consommation de l'Historique est une formule (calculée par Excel), non lue à l'import.

**À vérifier contre le menu de l'association test** (rapprochement par nom, sans casse ni accents ; un nom différent = ligne ignorée et signalée) :
- Gymnases : « Gymnase 1 », « Gymnase 2 » (à renommer dans la feuille Stock de départ si ceux du tournoi s'appellent autrement).
- Produits (19) : Barre de céréales chocolat, Barre de céréales fruit, Bière, Café, Coca, Croque Monsieur Chocolat, Croque tartiflette, Croque végé, Croque-monsieur, Crêpe Nutella, Crêpe sucre, Fruit, Ice Tea, Infusion, Mars, Oasis, Orangina, Thé, Twix. Attention aux variantes de graphie (« Croque Monsieur Chocolat » / « Croque-monsieur », « Croque végé » ; « Thé », « Café », « Bière » avec accents).

**Consommations attendues par personne et par jour** (total vendu / somme des personnes x jours, soit 226 personnes-jours) : Croque-monsieur 0,6327 (143) ; Coca 1,5265 (345) ; Café 1,4912 (337) ; Crêpe Nutella 1,2434 (281) ; Fruit 1,1327 (256) ; Oasis 0,8451 (191) ; Bière 0,6814 (154) ; Thé 0,7434 (168) ; Mars 0,0664 (15) ; Twix 0,0664 (15). Les 19 produits sont contrôlés par le parcours.

**Preuve N2** : `integration_test/classeur_club_test.dart` (LC2, vrai moteur local) : le classeur est lu sans erreur, l'assistant dit « aucun menu lisible » (aucun menu créé), crée la référence « Tournoi de l'an passé (Excel) » et règle la prévision : les 19 consommations égalent le relevé (tolérance 0,0001). Vert. Piège trouvé : openpyxl écrit les liens internes en absolu et le lecteur Excel de l'application plante dessus ; le classeur est corrigé après écriture (liens relatifs).

### Relevé A3 — Classeur du club avec menu et recettes (recette/classeur-notre-club.xlsx)

**Repris** : feuille Menu : 19 produits, les noms exacts de l'Historique (source : « Derniere liste », bloc « Rappels Tarifs 2024 » pour les prix). Familles, types et rayons choisis au plus simple ; consommation vide. Type « Au litre » (4 verres par litre) : Café, Thé, Infusion, Coca, Ice Tea, Oasis, Orangina. Type « Composé (recette) » : les 4 croques. « À l'unité » : le reste. Feuille Recettes : 15 lignes pour les 4 croques, d'après « CM standard », « CM Veggie », « CM Tartiflette », « CM Nutella ». Historique, Stock de départ (quantités vides), Courses (vide) et Accueil : inchangés depuis T3. Lecture par `lireClasseur` (vrai lecteur, test temporaire supprimé) : 19 produits, 4 recettes, 38 lignes d'historique, aucune erreur. `flutter analyze` sans erreur.

**Parcours** : `integration_test/classeur_club_test.dart` crée le menu « Les Discjonctés » avec les 19 produits ; l'assistant le reprend sans modification (aucun menu créé), le résumé dit « repris sans aucune modification » et que les recettes du classeur ne sont pas reprises. Consommations inchangées (relevé T3). Non joué (la mère le joue).

**À vérifier par Kinder** :
- Prix 2024 : Croque 1 €, Soda/Jus 1 €, Thé/Café 0,50 € (repris aussi pour Infusion), Bière 2 €, barres/Twix/Mars 1 €. Au plus proche : Fruit (pas de tarif 2024) 1 € ; crêpes 1 € chacune, alors que le tarif 2024 est « 3 petites crêpes = 1 € ». Pour les boissons « Au litre », le prix est supposé celui d'un verre de 25 cl.
- Sans recette (produits « À l'unité », sans ingrédients) : crêpes sucre et Nutella, Fruit, barres, Mars, Twix, Bière. Rayons par défaut : Bière Boissons, crêpes Autre, Fruit Frais, barres/Mars/Twix Épicerie.
- Pourcentages des fiches convertis en fraction d'unité, faute d'unité « % » : Bûchette de chèvre 20 % = 0,2 unité ; Tomate 40 % = 0,4 unité ; Fromage tartiflette 10 % = 0,1 unité.
- Fiches « Vendu par 2 » : la recette est prise pour UN croque (2 tranches de pain de mie).
- Dans le parcours, le menu « Les Discjonctés » est créé avec un prix de test (1,50 €) et une consommation de test (0,5), pas avec les tarifs ci-dessus.

### Cadrage T4 — Ajouter un produit à un événement (décision 78)

**Critères (repris du plan)** : (1) en préparation et en cours : le produit est créé dans l'événement et dans le menu d'origine ; (2) il apparaît dans stock de départ, prévision, courses et caisse ; (3) nom et prix des produits existants inchangés ; (4) événement clôturé : pas de bouton ; (5) un bénévole ne peut pas ajouter (test de règles).

**Stratégie** : bouton « Ajouter un produit » dans `EcranProduitsEvenement` (`lib/ecran_evenement.dart` ligne ~1655), visible seulement si `modifiable` (donc ni clôturé, ni pour un bénévole : cet écran est de la gestion). Formulaire simple réutilisant l'existant du menu (nom, prix, type de produit, provenance : même validation que `DepotMenus.ajouterProduit`, `lib/depot_menus.dart` ligne ~517, et mêmes limites, dont le nombre maximal de produits d'un menu). Un nouvelle méthode du dépôt des événements écrit, en un seul lot, le produit dans `evenements/{e}/produits` ET dans `menus/{menuId}/produits` du menu d'origine de l'événement (identifiant commun si le modèle le prévoit, sinon retrouvé par le nom), sans toucher aux produits existants (nom et prix figés). Règles : `evenements/{e}/produits` autorise déjà `create` à la gestion quand `reglableApres(a, e)` (en préparation ou en cours) ; vérifier que le lot (événement + menu) passe, sinon ajuster minimalement, avec test de règles, puis la mère déploie. Le produit doit sortir dans les écrans qui lisent la liste des produits de l'événement (stock de départ, prévision, courses, caisse) sans autre modification : vérifier, et ne corriger que l'affichage si l'un d'eux ne le montre pas. Le menu d'origine peut avoir été supprimé : dans ce cas le produit n'est ajouté qu'à l'événement et un message le dit.

**Fichiers touchés** : `lib/ecran_evenement.dart`, `lib/depot_evenements.dart`, éventuellement `firestore.rules` + `tests_regles/`, tests `test/` et un parcours N2 `integration_test/`. **On ne fait pas** : aucun calcul, aucune modification ou suppression de produit existant, aucun changement des droits des rôles, aucune dépendance.

**Preuve** : N1 (`flutter analyze`, `flutter test`, `powershell -File tests_regles/lancer.ps1` : un bénévole ne peut pas créer de produit d'événement, la gestion le peut en préparation et en cours, pas en clôturé) ; N2 sur LC2 : en cours, ajouter un produit, le retrouver dans le menu, le stock de départ (ou la prévision), les courses et la caisse.

### Cadrage T5 — Annuler un changement de source (décision 79 a)

**Critères (repris du plan)** : (1) après « D'après une source », « Annuler ce changement » rend exactement les chiffres d'avant, corrections à la main comprises ; (2) « Revenir au menu » marche comme avant ; (3) l'annulation se lit aussi sur un autre téléphone.

**Stratégie** : avant tout changement de source (`appliquerEvenementPasse`, `appliquerReference`, import d'assistant qui règle la prévision), le dépôt (`lib/depot_evenements.dart`, autour de `_appliquerPrevisions`) range l'état exact des prévisions dans UN document de l'événement, `evenements/{e}/previsions_annulation/dernier` (champ `lignes` : produit → {conso, source} ; liste vide = « d'avant il n'y avait aucune prévision enregistrée », c'est-à-dire les chiffres du menu), avec `creeLe`. « Annuler ce changement » (nouvelle méthode `annulerChangementPrevision`) relit ce document, remet exactement les prévisions d'avant (écrit celles qui existaient, efface les autres) puis efface le document d'annulation ; un seul niveau d'annulation (le dernier changement). Le document étant côté serveur, l'annulation se lit sur un autre téléphone (critère 3) : l'écran le suit en direct (flux). Bouton « Annuler ce changement » dans `lib/ecran_prevision.dart`, à côté de « D'après une source » et « Revenir au menu », visible seulement si le document existe. « Revenir au menu » garde son comportement ; il ne range pas de document d'annulation (il remet aux chiffres du menu comme avant), et un changement de source ultérieur écrase l'annulation précédente. Corriger un chiffre à la main n'efface pas l'annulation (elle remet l'état d'avant la source, y compris les mains d'avant). Règles : nouveau `match /previsions_annulation/{d}` à la gestion (`gereTout` et `reglable`, document `dernier` seul, champs `lignes` et `creeLe` bornés, taille limitée) avec tests de règles ; la mère déploie après les tests (préalable 2). Les écritures par lots de 10 existantes restent (limite d'évaluation des règles).

**Fichiers touchés** : `lib/depot_evenements.dart`, `lib/ecran_prevision.dart`, éventuellement `lib/ecran_evenement.dart` (câblage du flux), `firestore.rules`, `tests_regles/`, `test/`. **On ne fait pas** : aucun calcul de prévision, aucune dépendance, pas de niveaux multiples d'annulation, pas de changement des droits.

**Preuve** : N1 seulement (`flutter analyze`, `flutter test`, `powershell -File tests_regles/lancer.ps1`) ; le test d'écran joue le scénario source → mains → annuler = exactement l'état d'avant, et une seconde instance sur les mêmes données voit le bouton.

### Cadrage T6 — Heure de la dernière actualisation (décision 79 b)

**Critères (repris du plan)** : (1) ligne « Actualisé le JJ/MM à HH:MM » sous le titre ; (2) mise à jour après un glisser vers le bas réussi ; (3) hors réseau, elle ne change pas et le message hors réseau s'affiche.

**Stratégie** : tout passe par `lib/actualisation.dart`, déjà utilisé par les écrans actualisables (association, événement, caisses en direct, stock, bilan ; vérifier la liste réelle avec `grep actualisable|Actualisable lib`). `actualiserEcran` renvoie un booléen (vrai si la relecture a réussi, faux si hors réseau ou en erreur) ; `Actualisable` devient un widget à état qui garde l'heure de la dernière actualisation réussie (au départ : l'heure d'ouverture de l'écran, puisque les écrans sont en direct) et affiche, en tête, une petite ligne discrète « Actualisé le JJ/MM à HH:MM » (format français, deux chiffres, horloge injectable pour les tests) au-dessus de la liste actualisable ; le glisser vers le bas continue de fonctionner (liste toujours défilante). Après un glisser réussi : heure mise à jour ; échec ou hors réseau : heure inchangée et message « Hors réseau… » comme aujourd'hui. Les écrans qui n'ont pas besoin de changer ne changent pas : la ligne vient du composant partagé.

**Fichiers touchés** : `lib/actualisation.dart`, au besoin le câblage d'un écran dont la liste n'est pas dans `Actualisable`, `test/` (tests d'écrans d'actualisation existants à adapter, jamais en les affaiblissant). **On ne fait pas** : aucune relecture ajoutée ni modifiée, aucun changement de lectures serveur, aucune dépendance, aucune règle.

**Preuve** : N1 seulement (`flutter analyze`, `flutter test`) : le test joue ouverture → ligne présente ; glisser réussi → heure mise à jour ; glisser hors réseau → heure inchangée et message.

### Cadrage T7 — Paramètres en cartes (décision 79 c)

**Critères (repris du plan)** : (1) cartes Mon compte, Association et code, Membres, Qui peut quoi (repliable), Zone dangereuse, aux couleurs de la décision 31 ; (2) chaque membre a un badge de statut ; (3) responsable : « Changer le statut » propose bénévole, gestionnaire, retirer de l'association, avec confirmation ; (4) gestionnaire : liste sans action ; bénévole : pas de liste ; (5) règles inchangées (un gestionnaire ne retire toujours personne).

**Stratégie** : refonte de présentation de `EcranParametres` (`lib/ecran_association.dart`, à partir de la ligne ~346) : les sections séparées par `Divider` deviennent des cartes de l'application (même style que les autres écrans : cartes arrondies à 16, teintes de la décision 31 via le module de thème `lib/theme.dart`, zone dangereuse en brique avec contour fin, « Qui peut quoi » en carte repliable). Chaque membre : nom, badge de statut (bénévole, gestionnaire en attente, gestionnaire, responsable) aux couleurs de la décision 31. Pour le responsable, sur chaque autre membre, un seul bouton « Changer le statut » qui ouvre une feuille de choix (bénévole, gestionnaire, retirer de l'association) puis une confirmation ; il appelle les méthodes existantes (`nommerGestionnaire`, `retirerGestionnaire`, `retirerMembre`) sans en changer le fonctionnement ni les règles. Le responsable ne voit pas d'action sur lui-même (il est seul responsable) : afficher son badge « Responsable » et, s'il est seul, une phrase qui dit comment inviter des membres (code d'accès) afin que l'écran ne paraisse plus vide. Gestionnaire : liste avec badges, sans action. Bénévole : pas de liste. Les clés des widgets utilisées par les tests existants sont conservées quand la fonction reste la même ; les tests qui visaient les anciens boutons texte sont adaptés sans être affaiblis.

**Fichiers touchés** : `lib/ecran_association.dart`, éventuellement `lib/theme.dart` (une petite pièce réutilisable de carte/badge, sans changer l'existant), tests `test/` (membres, paramètres). **On ne fait pas** : aucune règle, aucun droit, aucune dépendance, aucun changement du fonctionnement des actions, pas de nouvel écran.

**Preuve** : N1 seulement (`flutter analyze`, `flutter test`) : tests d'écran par rôle (responsable avec autres membres, responsable seul, gestionnaire, bénévole), badges, feuille « Changer le statut » avec confirmation.

### Cadrage T8 — Page Courses en cartes (décision 79 d)

**Critères (repris du plan)** : (1) bandeau résumé (durée, personnes, coût cumulé) ; (2) rayons en cartes repliables avec compteur ; (3) actions (Ajouter une ligne, Partager / Enregistrer, Valider) fixées en bas ; (4) tous les tests de calcul des courses passent sans modification ; (5) captures avant et après rangées dans `audit_front/tournoi/`.

**Stratégie** : présentation seulement dans `lib/ecran_courses.dart` (973 lignes ; `_contenu`, `_ongletAcheter`, `_reglages`, `_rayons`, `_ligneArticle`, bandeaux de séries et de validation). (a) Bandeau résumé en haut sous les onglets : durée (jours), nombre de personnes, coût cumulé des séries déjà validées (valeurs déjà calculées par l'écran, aucune nouvelle lecture ni calcul). (b) Chaque rayon devient une carte repliable (`ExpansionTile` dans une carte arrondie à 16, teintes de la décision 31) avec compteur « cochés/total » ; les clés `rayon_$r`, `case_…`, `reste_…` sont conservées pour les tests. (c) Actions fixées en bas de l'écran (barre inférieure de l'`Scaffold`, hors de la liste qui défile) : « Ajouter une ligne », « Enregistrer / Partager la liste » (le bouton de partage existant de T1 : libellé aligné sur « Enregistrer ou partager »), « Saisir ce que j'ai acheté » (valider) ; clés conservées (`ajouter_libre`, `partager_liste`, `valider_courses`). Les quantités par produit et les réglages (durée, personnes) restent, rangés en cartes, sans changer leur comportement. Onglet « Déjà acheté » en cartes de même style. Les calculs (`lib/courses.dart`), les écritures et les règles ne changent pas ; les tests de calcul des courses ne sont pas modifiés (les tests d'écran dont seules les positions changent peuvent être adaptés sans être affaiblis). **Captures** : « avant » prises AVANT toute modification et « après » à la fin, sur l'émulateur LC2 avec des données de démonstration, par `adb exec-out screencap -p` (jamais par une capture dans un test : la conversion de la surface en image fige les parcours sur ce poste), rangées dans `audit_front/tournoi/` (`courses-avant.png`, `courses-apres.png`, et une capture du bas de page avec les actions fixées). Un seul passage d'émulateur pour les captures, fermé à la fin.

**Fichiers touchés** : `lib/ecran_courses.dart`, `test/` (tests d'écran de la page Courses, adaptés), `audit_front/tournoi/` (captures). **On ne fait pas** : aucun calcul, aucune règle, aucune dépendance, aucun changement de ce que les boutons font.

**Preuve** : N1 (`flutter analyze`, `flutter test`) ; critère 4 : les tests de calcul des courses (`test/courses_test.dart` et voisins) passent sans modification de leur contenu ; critère 5 : les trois captures existent et montrent les cartes.

### Texte de vérification T9 (pour une autre IA, conversation neuve sur Sonnet, sur le PC)

```
PROMPT DE VÉRIFICATION — Prêt pour le tournoi, lot A (A1 à A10) — projet Le Comptoir (branche claude/lot-a-tournoi, version 1.5.0+6)
TYPE : finale

Tu es l'IA de vérification. Tu n'as pas codé cette mission. Tu ne corriges rien.

CRITÈRES DE FIN DE MISSION (validés par Kinder le 11/11/2026), un écran chacun, une capture chacune (R32) :
1. Départ de l'import : dans l'association test, depuis « Extraction et modèle », la carte « Importer » ouvre l'assistant (choix : modèle générique ou mon classeur).
2. Import du classeur du club (recette/classeur-notre-club.xlsx) : le résumé avant écriture montre l'an passé (référence), le menu existant de même nom repris sans modification (ou « aucun menu à créer »), le tournoi en préparation choisi avec stock de départ et prévision réglée sur la référence ; après « Appliquer », la prévision du tournoi montre les chiffres de l'an passé.
3. Enregistrement d'un fichier : « Enregistrer sur le téléphone » (et « Partager ») propose le choix du dossier ; le fichier est dans Téléchargements (vue par l'application Fichiers ou par adb).
4. Ajout d'un produit : « Produits et images » > « Ajouter un produit » ; le produit se voit en caisse.
5. Ce même produit se voit dans le menu d'origine.
6. Prévision : après « D'après une source », « Annuler ce changement » rend les chiffres d'avant.
7. Une ligne « Actualisé le JJ/MM à HH:MM » est visible sous le titre d'un écran actualisable (ex. écran de l'événement).
8. Paramètres : cartes Mon compte, Association et code, Membres, Qui peut quoi, Zone dangereuse ; chaque membre porte un badge ; « Changer le statut » (bénévole, gestionnaire, retirer) s'ouvre sur un autre membre.
9. Courses : bandeau résumé, rayons en cartes repliables avec compteur, actions fixées en bas.
10. Courses, « En stock » : aucun champ « Il reste » ; chaque article porte « En stock : n [unité] » et un bouton « Modifier » qui ouvre la saisie (décision 82 a).
11. Courses, cocher ≠ valider : cocher un article ne change pas le stock ; le bouton du bas est « Valider les courses (n / m cochés) » (décision 82 b).
12. « Quantités par produit » n'est plus dans Courses ; il est dans la Préparation (écran Prévision), sous « Ce qu'on prévoit de vendre » (décision 82 c).
13. Paramètres, badges : un badge de couleur par rôle (responsable, gestionnaire, gestionnaire en attente, bénévole), identique dans la liste des membres et dans « Qui peut quoi » (décision 81).
14. Paramètres, « Qui peut quoi » (carte repliable) : une carte par rôle, avec une liste à puces de ce qu'il peut et ne peut pas faire.
15. Paramètres, QR de l'association : la carte « Association et code » montre un QR code (responsable) ; un second téléphone (ou un faux lecteur) qui le scanne arrive comme bénévole, sans événement ouvert ; un bénévole ne voit pas le QR (décision 80).
16. Unités : chaque stock affiche son unité d'achat et son unité de vente (ex. « 6 L · 24 verres », « 2 gâteaux · 16 parts ») sur Stock de départ, Gymnases et stock, caisse, Courses et Bilan (décision 83).
17. Classeur du club : `recette/classeur-notre-club.xlsx` contient le menu (19 produits) et les recettes de 4 croques ; importé dans l'association dont le menu s'appelle « Les Discjonctés », l'assistant dit que le menu est repris sans modification et n'en crée aucun (décision 84).

CRITÈRE DE FIN DU LOT A (validé par Kinder le 12/11/2026) : « Dans l'association test, depuis Extraction et modèle, j'importe le classeur de notre club : le menu, l'an passé, la prévision et le stock de départ du tournoi sont en place sans autre saisie ; j'enregistre un fichier dans Téléchargements ; j'ajoute un produit depuis Produits et images et je le vois en caisse et dans le menu ; dans la prévision j'annule un changement de source ; je vois l'heure de la dernière actualisation ; je change le statut d'un membre ; Paramètres et Courses sont rangés en cartes comme le reste de l'application ; je montre le QR code de l'association depuis Paramètres ; chaque membre a un badge de couleur ; en magasin je coche les articles sans toucher au stock, puis je valide les courses et le stock se met à jour ; chaque stock affiche son unité et ses verres ou parts ; le classeur du club contient le menu et ne le duplique pas à l'import. » Les critères 1 à 17 le couvrent un écran chacun.

CONTRÔLE RAPIDE (R31) : 1. l'application se lance et l'écran d'arrivée s'affiche ; 2. l'écran de caisse d'un événement en cours s'affiche et une vente s'encaisse.

CE QUI A ÉTÉ FAIT ET TESTÉ : T1 enregistrer ou partager (N1, N2) ; T2 assistant d'import unique (N1, N2) ; T3 classeur du club (N2) ; T4 ajout d'un produit (N1, règles, N2) ; T5 annulation d'un changement de source (N1, règles) ; T6 heure d'actualisation (N1) ; T7 Paramètres en cartes (N1) ; T8 page Courses en cartes (N1, captures avant/après) ; A2 import : menu de même nom porté par le classeur (N1) ; A3 classeur du club rempli (N2) ; A7 badges de rôle, « Qui peut quoi » en cartes, QR de l'association (N1 ; son parcours Android n'a pas pu être prouvé, le critère 15 est donc à voir à l'écran en priorité) ; A9 unités affichées (N1) ; A8 Courses : « En stock » + « Modifier », cocher ≠ valider, quantités en Préparation (N1) ; N3 de clôture : voir le CHANGELOG.

NOUVEAUTÉS À VÉRIFIER EN PRIORITÉ (à l'intérieur des critères) : le QR de l'association (15, preuve Android manquante) ; le déplacement des quantités de la page Courses vers la Préparation (12) et ce que les Courses affichent ensuite ; l'assistant remplace « Importer un menu » et « Importer un classeur » (ils y renvoient) ; le nom et le prix des produits existants ne changent pas après l'ajout d'un produit ; un bénévole ne voit ni « Extraction et modèle », ni « Importer », ni la liste des membres. Voisins : export et comparateur d'Extraction et modèle ; validation des courses (l'écran de validation s'ouvre depuis « Valider les courses » et met le stock à jour).

COMMENT LANCER : Java 21 (jbr d'Android Studio) devant le PATH ; émulateur Android LC2 (`-gpu swiftshader_indirect -no-snapshot -no-audio`, jamais Medium_Phone) ; `firebase emulators:start --only auth,firestore --project le-comptoir-60ba8` ; application en débogage sur l'émulateur contre ces émulateurs. Le moyen le plus simple de mettre l'application dans l'état voulu : un court parcours d'intégration qui prépare les données avec le vrai moteur local puis attend 60 s (modèles : integration_test/capture_courses.dart, assistant_import_test.dart, classeur_club_test.dart, ajout_produit_test.dart, outils.dart) pendant que tu captures par `adb -s emulator-5554 exec-out screencap -p` (jamais de capture prise dans un test : la conversion de la surface en image fige les parcours sur ce poste). Ne touche jamais au vrai projet Firebase ni à l'appareil réel connecté. Aucune migration de base de données ; règles d'accès modifiées par cette mission (nouveau document previsions_annulation) déjà déployées.

TON TRAVAIL :
1. Lance l'application selon la procédure ci-dessus.
2. Utilise-la comme un utilisateur.
3. Pour chaque critère : une seule capture `critere-N.png`, regardée une fois, verdict noté aussitôt (réussi / échoué / non vérifié avec la raison).
4. Ne rejoue pas les tests des étapes.

RENDU : tableau critère | capture | verdict | ce que tu as vu (en français) ; l'écran exact que Kinder utilise pour son test final.
```

## 17. Mission « Clôture du tournoi » — NOTE DE CADRAGE (phase 1, 11/11/2026 au soir, rien de figé)

> Cette section est une **mémoire**, pas un plan. Elle consigne les retours de Kinder du 11/11/2026 (soir) et les
> constats faits dans le code et dans les deux classeurs fournis, pour cadrer plus tard (phases 2 à 4).
> Aucune décision n'est figée, aucun numéro de décision n'est attribué, aucun critère n'est validé. Rien n'est codé.
> Sources : capture de l'écran « Produit » (Croque tartiflette, 11/11/2026, 22:42), `classeur-notre-club.xlsx`
> (celui produit par l'application / T3) et `Nouvelle_feuille_2.xlsx` (le classeur d'origine du club, 20 feuilles).
> **Validée par Kinder le 12/11/2026** (« je valide ») comme mémoire de cadrage : les douze points et le scénario de simulation sont retenus ; la réponse à la question « ratio » est la recommandation de Claude (les deux, effectifs d'abord : à reconfirmer en phase 2). Les décisions restent à figer en phase 3.
> Pièces : la capture est rangée dans `recette/capture-produit-croque-tartiflette.jpg`. Les deux classeurs ne sont PAS dans le dépôt (`recette/*.xlsx` est ignoré par git, et l'original contient des noms de bénévoles) : Kinder les redonne au cadrage.

### 17.1 Les douze points à modifier (verbatim reformulé, + constat dans le code)

| # | Retour de Kinder | Constat au 11/11/2026 | À trancher en phase 2 |
|---|---|---|---|
| 1 | On propose de rejoindre par QR code, mais **aucun écran n'affiche** le QR code pour rejoindre l'association. | Le scan existe (accueil `ecran_accueil.dart`, association `ecran_association.dart`). Le seul affichage d'un QR est `EcranQr` (`lib/ecran_qr.dart`), ouvert depuis l'icône « Partager (QR code) » d'**un gymnase d'un événement** (`ecran_gymnases.dart`). Rien dans Paramètres, ni sur l'écran de l'association, pour montrer un QR « rejoindre l'association ». | Où l'afficher (Paramètres › Association et code ? écran de l'association ?). Que contient-il (code seul = devenir bénévole). Qui le voit (gestion). |
| 2 | Un membre peut avoir **plusieurs associations**, avec **un rôle différent dans chacune**. | Le modèle est « un téléphone = une association » : `utilisateurs/{uid}.assoId` (un seul champ, `depot_associations.dart` l. 64-72, 139-172) ; le rôle est dans `associations/{a}/membres/{uid}`. Tout l'écran racine suppose une seule association. **Changement de fond** : modèle de données, règles d'accès, racine, accueil, suppression d'association, QR. Touche les décisions 19 et 23. | Écran de choix d'association (liste + « Créer / Rejoindre »), association « active » retenue sur le téléphone, migration des utilisateurs existants, règles d'accès. **À challenger : plus gros chantier de la liste ; à isoler.** |
| 3 | Page **Paramètres** « toujours moche » : l'explication des rôles est du texte brut sans mise en page ; je veux des **badges de couleur par rôle**, bien visibles. | `_quiPeutQuoi` (`ecran_association.dart` l. 616-637) = un `Text` unique de trois lignes séparées par `\n`. La décision 79 (c) / étape **T7** (cartes, badge de statut par membre) était au plan « Prêt pour le tournoi » ; au 11/11/2026 le tableau de suivi T1–T9 est **vide** (rien de livré). Reprendre T7 en y ajoutant : une carte par rôle (titre, badge coloré, liste à puces de ce qu'il peut / ne peut pas faire) et les mêmes badges partout où un rôle s'affiche (liste des membres, sélecteur d'association du point 2). | Une couleur par rôle (responsable, gestionnaire, gestionnaire en attente, bénévole), dans la palette de la décision 31. |
| 4 | Le fichier **« Produits / classeur de notre club »** ne précise pas le **ratio du nombre de personnes** qu'on avait : on perd des données par rapport à l'Excel initial. | Feuille Historique (`classeur.dart` l. 100-115) : une seule colonne **Personnes** et une colonne **Jours** par gymnase. Or le classeur d'origine détaille, **par gymnase ET par jour (samedi / dimanche)** : joueuses + accompagnateurs, bénévoles + famille, spectateurs ; **repas midi et repas soir** séparés ; la part de chaque catégorie de produit (ex. croque-monsieur 70 % des personnes le samedi, 80 % le dimanche ; dessert 110 % / 100 % ; boissons froides 150 % ; boissons chaudes 110 % / 150 %) ; la répartition entre produits (croque standard 40 % / végé 25 % / tartiflette 35 %) ; les équipes (14 équipes, 109 joueuses, 112 avec accompagnateurs) et le total « environ 150 personnes ». Voir 17.2. | **Quel niveau de détail garder** : (a) personnes par catégorie, par jour et par gymnase ; (b) les pourcentages de consommation et de répartition ; (c) les deux. **Question à poser à Kinder (« ratio » = laquelle des deux ?).** Contrôle de cohérence : le fichier annonce 53 et 60 personnes ; l'Excel d'origine donne 49 + 10/11 bénévoles (G1 sam.), 56 + 9 (G1 dim.), 63 + 7/8 (G2 sam.), 56 + 6/3 (G2 dim.) : **les chiffres du fichier ne se retrouvent pas** dans l'original — à retracer. |
| 5 | Le **modèle de notre club** ne garde toujours pas **le menu**, alors qu'il est générique et inspiré du club. | Feuilles Menu et Recettes du classeur du club : **vides** (en-têtes seulement), avec la mention « menu laissé vide : le menu est déjà dans l'association ». C'était la réponse de Kinder du 11/11/2026 (T3) pour éviter un menu en double ; il demande maintenant l'inverse. **Contradiction apparente avec la réponse T3 à lever** : le classeur doit **porter** le menu (18 produits : familles, prix, type, provenance, verres par litre, parts par gâteau, rayon, consommation) et les recettes ; c'est l'assistant d'import (décision 77) qui reprend le menu existant de même nom sans le dupliquer. | Confirmer : le classeur contient le menu **et** les recettes ; l'import ne crée rien si le menu existe. Sinon le « modèle » n'est pas réutilisable seul. |
| 6 | **Préparation de l'événement, produits composés** : je veux noter la **quantité en stock du produit composé**, ou la quantité de **ses composants**, ou **certains composants en stock**, pour ajuster la liste de courses. | Stock de départ (`ecran_stock_depart.dart`) : une quantité par produit fini. Les composants (pain de mie, jambon…) n'existent que dans le calcul des courses (« Ce qu'il reste » par article, `courses.dart` l. 199, 355). | Saisie du stock d'un composé à trois niveaux : produits finis déjà faits (ex. 20 croques) / composants (ex. 3 paquets de pain) / un seul composant (ex. le jambon). Règle de calcul : le stock de composants vient en déduction des courses **avant** celui des ingrédients à acheter ; les produits finis déduisent leurs ingrédients. **Touche les calculs des courses (décision de ne pas toucher à lever).** |
| 7 | Toujours **dans les stocks initiaux** : je n'ai **ni la quantité, ni la mesure de référence**, donc impossible d'être juste. | Le champ du stock de départ n'affiche pas l'unité : je ne sais pas si « 12 » veut dire 12 bouteilles, 12 verres ou 12 litres. `mesure.dart` porte pourtant les unités de base (verres par litre, parts par gâteau). | Afficher, **à côté de chaque quantité saisie**, l'unité de référence du produit (bouteille de 2 L, verre de 25 cl, part, pièce) et la conversion en clair (« 3 bouteilles = 24 verres »). |
| 8 | **Écran de paramétrage d'un article** moche et mal rangé ; il faut s'y pencher et faire **rebondir** mesure, composition, provenance, consommation par jour **sur les autres modules**. | Capture : une seule liste verticale dans une boîte de dialogue (Nom, Prix, Type, Famille, Ingrédients, Quantité + unité + Rayon répétés par ingrédient, puis Provenance, Rayon, Consommation) ; les champs de saisie se chevauchent (étiquette « Quantité » écrasée sur le champ Ingrédient au-dessus), l'unité (« tranche ») est un menu sans cadre, « Supprimer / Annuler / Valider » sans hiérarchie. Code : `ecran_menu.dart` l. 353-574. Les valeurs saisies (verres par litre, parts par gâteau, composition, provenance, consommation) servent déjà aux courses et à la prévision, mais **ne sont lues ni affichées** dans le stock, la caisse ni le bilan. | Remplacer la boîte de dialogue par **un écran en cartes** : Identité (nom, prix, famille), Mesure (type, verre/part/pièce), Composition (recette), Provenance et rayon, Consommation par jour. Cartographier **où chaque donnée doit rebondir** (voir 17.3). |
| 9 | **Liste de courses** : pour chaque produit, un bloc « **Il reste** » alors qu'on a déjà validé le stock dans les actions précédentes : il devrait **s'afficher simplement**. | `ecran_courses.dart` l. 704-720 : un champ `TextFormField` « Il reste » par article, **modifiable**, qui double la saisie du stock de départ. | La valeur vient du stock déjà saisi (Préparation, ou fin de journée) et s'affiche en **lecture seule** (« En stock : 3 bouteilles »), avec un lien « Modifier le stock » ; plus de champ de saisie dans les courses. |
| 10 | Toujours dans les courses : un bloc en dessous « **Quantités par produit** », je ne comprends pas : **qu'est-ce qu'il fait là ? Ancien module pas nettoyé ?** | `ecran_courses.dart` l. 495-515 : sous les rayons, un tableau « Produits : gymnase » avec `_ligneProduit` par gymnase et produit = les **quantités de produits finis à faire** (par gymnase) dont se déduisent les achats (étape 5 / décision 56 : « la quantité, le stock et le report »). Ce n'est pas du reste d'un ancien module, c'est **l'entrée du calcul**, mais **mal nommé et mal placé** (après la liste, sans explication). | **À trancher** : (a) le déplacer dans la Préparation / la Prévision (là où on règle les quantités) et le retirer des Courses ; (b) le garder dans Courses mais en tête, sous le titre « Ce qu'on prévoit de vendre » avec une phrase d'explication, en repliable. **Recommandation de Claude : (a)**, les Courses ne montrent que quoi acheter. |
| 11 | Je **ne peux pas valider les lignes** quand j'ai pris l'article. Je veux pouvoir **cocher** l'article au fur et à mesure, mais **garder la saisie finale des courses** pour la mise à jour des stocks réels. | Deux notions confondues : la **case à cocher** (`_basculerCoche`, `case_<clé>`, « Déjà acheté », partagée entre téléphones) et la **validation de la série** (« Valider les courses » : coût, quantités achetées, ajout au stock, `ecran_validation_courses.dart`). Kinder voit la case comme inactive (la ligne reste/refuse de se valider) ; à reproduire à l'écran avant de conclure (capture demandée). | Cocher = « dans le panier » (réversible, sans effet sur le stock) ; **Valider la série** = saisie finale des quantités et prix réels → seul moment où le stock réel est mis à jour. Rendre la différence lisible (bouton « Valider les courses (n/m cochés) » en bas). |
| 12 | Pour **chaque article et son affichage de stock**, afficher **la mesure** : nombre de **verres**, nombre de **parts**, etc. | Le stock s'affiche en nombre brut. Les conversions existent (`mesure.dart` : verres par litre, parts par gâteau). | Affichage partout où un stock apparaît (Stock de départ, Gymnases et stocks, caisse « stock bas », Courses, Bilan) : « 3 bouteilles · 24 verres », « 2 gâteaux · 16 parts », « 5 paquets · 75 tranches ». Un seul mot d'ordre : l'unité **de vente** (verre, part, tranche) à côté de l'unité **d'achat**. |

(Douze points au total : la demande de Kinder compte douze tirets.)

### 17.2 Ce que le classeur d'origine du club contient (relevé de `Nouvelle_feuille_2.xlsx`, à ne pas perdre)

- **Feuille Paramètre** : 2 gymnases, 2 jours (samedi, dimanche) ; **14 équipes** (nom, nombre de joueuses, gymnase, accompagnateurs) : **109 joueuses, 112 avec accompagnateurs, « environ 150 personnes au total »** ; colonnes Standard / Végan par équipe ; **bénévoles + famille** (nom, prénom, gymnase, repas midi/soir samedi et dimanche, ex. « Caro ou Laurent » = 2 repas) ; totaux joueuses/accompagnateurs **par gymnase et par jour** (G1 : 49 samedi, 56 dimanche ; G2 : 63 samedi, 56 dimanche).
- **Feuille Repas** : pour chaque jour, les **% de consommation sur l'ensemble des participants/bénévoles/spectateurs** et la répartition entre produits : plat de résistance (croque-monsieur) 70 % sam. / 80 % dim. ; dessert + 4 h 110 % / 100 % ; fruit 50 % / 60 % ; barres 20 % / 25 % ; boissons froides 150 % ; boisson alcoolisée 30 % ; boissons chaudes 110 % / 150 % ; nombre de sucres 0,5 / 0,6. Unités de service : croque ×2, crêpe ×4, verre 25 cl (**4 verres = 1 L**), canette, sachet, clémentines vendues par 2, bière par pack de 12.
- **Feuilles Gymnase n Jour** : personnes (joueuses + accompagnateurs / bénévoles + famille / spectateurs, midi et soir) × % = quantités prévues par produit ; **feuilles Achat gymnase n** : conversion en **conditionnements d'achat** (paquets de 15 tranches de pain, de 10 tranches de jambon, 1 kg de gruyère râpé, pot de 2 kg de Nutella, bouteille de 2 L, pack de 12 bières) avec **« Reste de l'an dernier »**, et des erreurs `#REF!` (le « reste » n'était jamais branché).
- **Feuilles Achats 2025** : par article, **acheté en 2024, prévu 2025, commentaire de terrain** (ex. pain de mie 700 → 750 « on a un peu manqué » ; barres de céréales « ça part vraiment pas beaucoup » ; sucre roux « personne n'en prend » ; thé « environ 50 par gymnase pour tout le week-end ») ; articles hors menu (liquide vaisselle, sopalin, café, lait, sacs poubelles…).
- **Autres feuilles** : listes à imprimer (fin de journée, ticket buvette à 0,50 €, étiquettes de plats, fiches de composition croque standard / végé / tartiflette / nutella), et `Tabelle1` : une liste de choses à faire (réappro automatique entre samedi et dimanche, prendre en compte les gâteaux restants, régimes spéciaux, % mineurs/majeurs, plan de travail).
- **Écarts entre l'export de l'application et l'original** (point 4) : Personnes = 53 / 60 et Jours = 2 ; consommations calculées 0,16 (barre chocolat) à 1,58 (Coca) par personne et par jour ; **aucun pourcentage, aucune catégorie de personnes, aucun détail par jour, rien sur les équipes ni les bénévoles, pas de colonne Standard / Végan**.

### 17.3 « Faire rebondir » une donnée d'article sur les autres modules (point 8, cartographie à confirmer)

| Donnée de l'article | Doit se retrouver dans |
|---|---|
| Mesure (verre, part, pièce, litre) et conversions | Stock de départ, Gymnases et stocks, caisse (stock bas), Courses (conditionnement), Bilan (quantités vendues) |
| Composition (recette) | Courses (ingrédients), Préparation (stock du composé, point 6), Stock (ingrédients restants) |
| Provenance (acheté / fait sur place / apporté) | Préparation (qui apporte quoi), Courses (exclus si apporté), fiches à imprimer |
| Consommation par personne et par jour | Prévision, Préparation, Comparateur, Bilan (consommation réelle vs prévue) |
| Rayon | Courses (rangement par rayons), liste partagée |

### 17.4 Test de clôture : simulation complète du tournoi sur émulateur (cadrage du scénario)

**But (demandé par Kinder)** : jouer, sur émulateur, un tournoi entier avec des données fictives, **de la création de l'événement jusqu'à la clôture et au bilan financier**, au plus près du réel. Il **conclut** la mission et sert de critère de fin (à écrire en phase 4). Cible : `integration_test/parcours_tournoi_simule_test.dart` (à créer) avec des captures dans `audit_front/tournoi/` ; Kinder valide **sur capture d'écran**.

**Jeu de données fictives, bâti sur le réel** (les chiffres viennent des classeurs ; les prix sont inventés, sauf **1,00 € pour le croque tartiflette**, vu sur la capture) :

1. **Association** « Club test » : 1 responsable (Kinder), 1 gestionnaire, 4 bénévoles ; **deux associations** pour tester le point 2 (rôle différent dans chacune).
2. **Événement** « Tournoi 2026 (simulation) » : 2 gymnases, 2 jours ; effectifs par gymnase et par jour tirés de l'original : G1 samedi 49 joueuses + 10 bénévoles (midi) / 11 (soir), dimanche 56 + 9 ; G2 samedi 63 + 7 / 8, dimanche 56 + 6 / 3 ; spectateurs 0 ; 14 équipes (109 joueuses), % repas du classeur (70 % / 80 %…).
3. **Menu** (18 produits du classeur) : croque-monsieur, végé, tartiflette, chocolat ; crêpes sucre / Nutella ; fruit ; Mars, Twix, 2 barres de céréales ; Coca, Ice Tea, Orangina, Oasis ; bière ; café, thé, infusion ; **recettes** : ex. croque tartiflette = 2 tranches de pain de mie + 0,45 tranche de jambon blanc + … (capture) ; **mesures** : 4 verres de 25 cl par litre, bouteilles de 2 L, packs de 12 bières, parts de gâteau, paquets de 15 tranches de pain.
4. **Historique de référence** : « Tournoi de l'an passé » (53 / 60 personnes, 2 jours, consommations du classeur : Coca 1,58, café 1,55, crêpe Nutella 1,29, etc.).
5. **Stocks de départ fictifs** (restes de l'an dernier, par gymnase, avec leur unité) : p. ex. G1 : 6 bouteilles de Coca 2 L, 2 paquets de café, 40 sachets de thé, 1 pot de Nutella de 2 kg, 3 paquets de pain de mie ; G2 : 4 bouteilles de Coca, 1 paquet de café, 30 sachets de thé ; **un composé en stock fini** (12 croques tartiflette déjà faits) **et un composant seul** (2 paquets de jambon) pour tester le point 6.
6. **Courses fictives** : 2 séries (vendredi, samedi matin) rayon par rayon, quantités **en conditionnements** (paquets de 15 tranches, bouteilles de 2 L, packs de 12) avec coûts réalistes ; cases cochées au fur et à mesure puis **validation finale** qui met à jour le stock (points 9 à 11) ; une ligne libre (sopalin, filtres à café).
7. **Ventes fictives** : générées par un script déterministe à partir de la consommation de l'an passé × personnes × jours (± 10 %), réparties sur **4 caisses** (une par bénévole, 2 par gymnase), **espèces / carte / chèque**, avec **heures de pointe** (midi, 16 h) ; samedi et dimanche ; quelques **annulations et corrections** ; une rupture de stock (bière) et un stock bas (Coca) ; **une caisse clôturée de force** (signalement dans le bilan).
8. **Clôture** : chaque bénévole clôture sa caisse (récapitulatif par mode de paiement), l'événement se clôture, **bilan financier** (total, par produit, par mode, par caisse, par jour, heures de pointe, coût des courses, **résultat**), export Excel, **comparaison** avec « le tournoi de l'an passé », import du classeur sans perte (point 4).
9. **Contrôles à l'écran** (futurs critères, écrits en phase 4) : badges de rôle visibles ; QR de l'association affiché puis scanné par un faux lecteur ; un membre dans deux associations avec deux rôles ; unités et verres / parts affichés sur chaque stock ; « Il reste » en lecture seule ; cases cochées sans toucher au stock jusqu'à la validation ; totaux du bilan = somme des ventes simulées (vérifiable par script) ; coût des courses = somme des séries.

### 17.5 À faire pour la suite (phases 2 à 4)

1. **Phase 2 — questions à trancher avec Kinder, une à la fois** : (a) point 4 : « ratio » = effectifs par catégorie / pourcentages de consommation / les deux ; (b) point 5 : le classeur contient le menu et les recettes (annule la réponse T3) ; (c) point 10 : Quantités par produit déplacé dans la Préparation (recommandé) ou gardé ; (d) point 2 : association active choisie au lancement ou dernière utilisée.
2. **Ordre proposé (à valider)** : Paramètres et badges (3, avec T7) → article en cartes et mesures (8, 7, 12) → classeur (4, 5) → stock des composés (6) → Courses (9, 10, 11) → QR de l'association (1) → **plusieurs associations (2), en dernier et seul** → simulation du tournoi (17.4).
3. **Limites de Kinder** : ≤ 20 modules (19 aujourd'hui : le point 2 et le test de simulation peuvent en demander un ou deux : **signalé avant tout code**) ; ≤ 5 fichiers de documentation (5 aujourd'hui : cette note vit ici, section 17, pas dans un nouveau fichier) ; zéro dépendance ajoutée.
4. **Statut** : « T1 à T9 » (Prêt pour le tournoi) n'est pas suivi dans le tableau de la section 16 : **vérifier ce qui est réellement livré** avant de ré-ouvrir T7 (Paramètres) et T8 (Courses). Les points 3, 9 et 10 recoupent T7 et T8 : à fusionner, pas à doubler.
5. **Phase 3** : décisions 80 et suivantes à figer, section 6 de `PROJET_CONTEXTE.md` ; revue d'équipe par le Coordinateur (Recherche et Technique) pour le point 2 (modèle de comptes Firebase) avant validation.

## 18. Plan complet fusionné « Prêt pour le tournoi » + « Clôture du tournoi » — PROPOSITION (12/11/2026, à valider par Kinder)

> Fusion des étapes T1 à T9 (section 16, plan validé le 11/11/2026) et des douze points de la note de cadrage (section 17).
> **Rien n'est figé** : les points de la section 17 passent par la phase 2 (questions une à une), puis 3 (décisions 80 et suivantes) et 4 (critères) avant tout code.
> Constat au 12/11/2026 : **aucune des étapes T1 à T9 n'est livrée** (rien dans le code, suivi de la section 16 vide). Branche de travail : `claude/pret-tournoi` (contient cette note).
> **Corrigé le 12/11/2026 (voir 18.7)** : ce constat est faux, T1 à T8 étaient faites sur le PC, sur une branche jamais envoyée en ligne. Le travail restant est en 18.7, le prompt en 18.8.

### 18.1 Recoupements (pour ne rien faire deux fois)

| Étape du plan validé | Points de la note qui s'y ajoutent | Écran |
|---|---|---|
| T2 Assistant d'import + T3 Classeur du club | 5 (le classeur porte le menu et les recettes ; l'import reprend le menu existant sans le doubler) | Extraction et modèle |
| T7 Paramètres en cartes | 3 (une carte et un badge de couleur par rôle) + 1 (QR code pour rejoindre l'association, dans la carte « Association et code ») | Paramètres |
| T8 Courses en cartes | 9 (« Il reste » en lecture seule) + 10 (« Quantités par produit » rangé) + 11 (cocher ≠ valider) | Courses |
| — (nouvelle étape, affichage seul) | 7 + 12 (unité et verres / parts à côté de chaque stock) | Stock de départ, stocks, caisse, courses, bilan |

### 18.2 Découpage proposé : ce qui sert au tournoi du week-end, et ce qui vient après

**Lot A — avant l'essai à blanc de vendredi (mission « Prêt pour le tournoi » élargie)** : uniquement de l'affichage et du rangement, **aucun calcul ne change** (règle de la section 16 conservée).

| # | Étape | Origine | Ce que Kinder voit |
|---|---|---|---|
| A1 | Enregistrer sur le téléphone | T1 | Chaque fichier : « Enregistrer sur le téléphone » ou « Partager » |
| A2 | Assistant d'import unique | T2 + point 5 | Une carte « Importer » ; le menu du classeur est repris sans doublon |
| A3 | Classeur du club | T3 + point 5 | `recette/classeur-notre-club.xlsx` avec menu et recettes remplis |
| A4 | Ajouter un produit | T4 | Bouton dans « Produits et images » |
| A5 | Annuler un changement de source | T5 | Bouton dans la prévision |
| A6 | Heure de la dernière actualisation | T6 | « Actualisé le JJ/MM à HH:MM » |
| A7 | Paramètres en cartes, badges de rôle, QR de l'association | T7 + points 3 et 1 | Cartes, badge coloré par rôle, QR à montrer aux bénévoles |
| A8 | Courses en cartes, « Il reste » affiché, cocher ≠ valider, « Quantités par produit » rangé | T8 + points 9, 10, 11 | Liste qu'on coche en magasin ; une seule validation finale met le stock à jour |
| A9 | Unités et verres / parts partout | points 7 et 12 | « 3 bouteilles · 24 verres » sur chaque stock |
| A10 | Clôture du lot A | T9 | Vérification complète, APK 1.5.0 à installer sur les téléphones du week-end |

**Lot B — après le tournoi (mission « Clôture du tournoi »)** : ce qui touche aux calculs ou au modèle de comptes, trop risqué la veille d'un tournoi.

| # | Étape | Origine | Pourquoi après |
|---|---|---|---|
| B1 | Écran article en cartes, données qui « rebondissent » (17.3) | point 8 | Refonte d'un écran central ; à faire à froid |
| B2 | Effectifs par catégorie / jour / gymnase et pourcentages dans le classeur et la prévision | point 4 | Change le calcul de la prévision |
| B3 | Stock des produits composés et de leurs composants | point 6 | Change le calcul des courses |
| B4 | Plusieurs associations, un rôle par association | point 2 | Change le modèle de comptes et les règles d'accès ; seul, en dernier, avec revue |
| B5 | Simulation complète du tournoi sur émulateur (17.4) | note 17.4 | Critère de fin de la mission ; s'appuie sur les vrais chiffres du week-end |

### 18.3 Questions à trancher avant de coder (phase 2, une à la fois)

1. Le découpage lot A (avant le tournoi) / lot B (après) est-il le bon ? → **Validé par Kinder le 12/11/2026** (« Oui, ce découpage »).
2. Point 5 : le classeur du club porte le menu et les recettes (revient sur la réponse T3 du 11/11/2026) ? → **Oui, validé par Kinder le 12/11/2026** (« Oui, il les garde ») : le classeur porte les 18 produits (prix, type, mesures, rayon) et les recettes ; l'assistant reprend tel quel le menu existant de même nom. Remplace la réponse T3 du 11/11/2026.
3. Point 10 : « Quantités par produit » déplacé dans la Préparation (recommandé) ou gardé en tête des Courses ? → **Déplacé dans la Préparation, validé par Kinder le 12/11/2026** (« Oui, en Préparation ») : à côté de la prévision, sous un titre clair ; la page Courses ne montre plus que ce qu'il faut acheter. Aucun calcul ne change.
4. Point 1 : le QR de l'association est visible par la gestion seulement, dans Paramètres › Association et code ? → **Oui, gestion seule, validé par Kinder le 12/11/2026** (« Oui, gestion seule ») : le QR contient le code de l'association ; le scanner fait entrer comme bénévole, comme le code tapé.
   - **Constat au cadrage (12/11/2026), point 9** : « Il reste » dans les Courses n'est pas une copie du stock de départ. Il porte les restes **d'ingrédients et de conditionnements** (pain de mie, jambon, sucre…), qui ne se saisissent nulle part ailleurs (le stock de départ ne porte que les produits finis ; les composants viennent avec le point 6, lot B). Le passer en lecture seule ferait perdre cette saisie. → **Tranché par Kinder le 12/11/2026** (« Oui, avec Modifier ») : chaque article affiche « En stock : n [unité] » sans champ de saisie, et un bouton « Modifier » ouvre la saisie. La saisie du stock des composants en Préparation reste au lot B (point 6).

### 18.5 Décisions et critères du lot A — VALIDÉS par Kinder le 12/11/2026 (phases 3 et 4 closes)

**Décisions** (figées en section 6 de PROJET_CONTEXTE.md, numéros 80 à 84) :

- **80. QR code de l'association** : affiché dans Paramètres › carte « Association et code », pour la gestion seulement (responsable et gestionnaires). Il contient le code de l'association ; le scanner fait entrer comme bénévole, exactement comme le code tapé. Les droits (décisions 19, 23) ne changent pas.
- **81. Badges de rôle** (complète 79 c) : une couleur par rôle (responsable, gestionnaire, gestionnaire en attente, bénévole), prise dans la palette de la décision 31. « Qui peut quoi » devient une carte par rôle (badge + liste à puces de ce qu'il peut et ne peut pas faire). Les mêmes badges partout où un rôle s'affiche.
- **82. Courses** (complète 79 d) : (a) « Il reste » s'affiche « En stock : n [unité] » avec un bouton « Modifier » ; (b) la case à cocher veut dire « dans le panier » : réversible, partagée entre téléphones, sans effet sur le stock ; seul « Valider les courses (n / m cochés) », en bas, met le stock à jour avec les quantités et prix réels ; (c) le bloc « Quantités par produit » quitte les Courses pour la Préparation, à côté de la prévision, sous le titre « Ce qu'on prévoit de vendre ». Aucun calcul ne change.
- **83. Unités affichées** : à côté de chaque quantité de stock (Stock de départ, Gymnases et stock, caisse, Courses, Bilan), l'unité d'achat et l'unité de vente : « 3 bouteilles · 24 verres », « 2 gâteaux · 16 parts ». Affichage seul, aucun calcul ne change.
- **84. Classeur du club** (précise 77, remplace la réponse T3 du 11/11/2026) : le classeur porte le menu (produits, prix, type, mesures, rayon, consommation) et les recettes ; à l'import, un menu de même nom déjà présent est repris tel quel, sans doublon ni modification.

**Critères par étape** (A1, A4, A5, A6 et A10 = critères de T1, T4, T5, T6 et T9 inchangés, section 16) :

| # | Critères ajoutés ou changés |
|---|---|
| A2 | Critères de T2, plus : (9) un classeur qui porte un menu de même nom que celui de l'association ne crée aucun menu et ne modifie pas l'existant ; le résumé le dit |
| A3 | Critères de T3, sauf (2) remplacé par : les feuilles Menu et Recettes sont remplies d'après le menu de l'association test ; importé par l'assistant sur émulateur : aucun menu en double |
| A7 | Critères de T7, plus : (6) un badge de couleur par rôle, identique partout ; (7) « Qui peut quoi » = une carte par rôle avec liste à puces ; (8) la gestion voit le QR code de l'association et peut le scanner depuis un autre téléphone pour entrer comme bénévole ; un bénévole ne voit pas le QR |
| A8 | Critères de T8, plus : (6) aucun champ « Il reste » : « En stock : n [unité] » et un bouton « Modifier » qui garde la saisie ; (7) cocher un article ne change pas le stock ; seul « Valider les courses (n / m cochés) » le change ; (8) « Quantités par produit » n'est plus dans Courses et se trouve dans la Préparation ; (9) tous les tests de calcul des courses passent sans modification |
| A9 | (1) chaque quantité de stock affiche son unité d'achat et, s'il y en a une, son unité de vente (verres, parts) sur les cinq écrans cités ; (2) les conversions sont justes (4 verres par litre, parts par gâteau du produit) ; (3) aucun test de calcul ne change |

**Critère de fin du lot A** (étend celui de « Prêt pour le tournoi ») : critère de la section 16, plus : « je montre le QR code de l'association depuis Paramètres ; chaque membre a un badge de couleur ; en magasin je coche les articles sans toucher au stock, puis je valide les courses et le stock se met à jour ; chaque stock affiche son unité et ses verres ou parts ; le classeur du club contient le menu et ne le duplique pas à l'import. »
5. (Lot B) Point 4 : « ratio » = effectifs, pourcentages, ou les deux (recommandé : les deux, effectifs d'abord).
6. (Lot B) Point 2 : association active = la dernière utilisée, avec un sélecteur dans l'en-tête ?

### 18.4 Limites

Aucune dépendance nouvelle (A1 utilise `file_picker`, déjà accordé ; A7 : à vérifier qu'un affichage de QR existe déjà, `EcranQr`). Cinq fichiers de documentation : ce plan vit ici. Le point 2 (B4) et la simulation (B5) peuvent demander un module de plus : signalé avant le code.

**Ordre et dépendances du lot A** : A1 avant A2 et A8 (boutons de fichier) ; A2 avant A3 (le classeur s'importe par l'assistant) ; A9 avant A8 (l'affichage « En stock : n [unité] » de A8 reprend les unités de A9) ; A4 à A7 indépendantes ; A10 en dernier. Ordre retenu : A1 → A2 → A3 → A4 → A5 → A6 → A7 → A9 → A8 → A10.

**Préalables, ce qu'on ne touche pas, arrêts** : ceux de la section 16, inchangés. Seule différence : les calculs restent intouchés **aussi** pour A8 et A9 (affichage et rangement seulement).

**Suivi** (une ligne par étape close ; lignes A1, A4, A5, A6 écrites le 12/11/2026 d'après les commits et les cadrages de la section 16, le suivi n'ayant pas été tenu le 11/11/2026)

| Étape | État | Date | Critères |
|---|---|---|---|
| A1 (T1) | Faite, N1 et N2 (commits 8527a81, puis b834b40 : clé de navigation corrigée après une régression vue au N3) | 11/11/2026 | critères de T1 ; N3 à refaire en A10 |
| A4 (T4) | Faite, N1, règles et N2 (commit 549d18e) | 11/11/2026 | critères de T4 ; N3 à refaire en A10 |
| A5 (T5) | Faite, N1 et règles (commit dc70268) ; règles `previsions_annulation` déployées | 11/11/2026 | critères de T5 |
| A6 (T6) | Faite, N1 (commit d8dcb26) | 11/11/2026 | critères de T6 |
| A2 (T2 + critère 9) | Faite, N1 (analyse sans erreur, 523 tests ; menu de même nom porté par un classeur Menu + Recettes : aucun menu créé, aucune recette écrite, résumé qui le dit) | 12/11/2026 | critères de T2 + (9) ; N2 de T2 rejoué en A3 |
| A3 (T3 + décision 84) | Faite, N2 (`classeur_club_test` vert sur LC2 : classeur Menu 19 produits + Recettes 4 croques, menu « Les Discjonctés » repris sans aucune modification, aucun menu créé, consommations égales au relevé). Prix 2024 et produits sans recette à vérifier par Kinder (Relevé A3) | 12/11/2026 | critères de T3 avec (2) remplacé |
| A7 (T7 + 6, 7, 8) | Faite, N1 (analyse sans erreur, 532 tests + test/a7_test.dart : badges de couleur par rôle, une carte par rôle, QR de l'association visible du responsable seul, scan par faux lecteur = bénévole sans événement). N2 non prouvé : le parcours Android du QR a échoué deux fois (test), Kinder a décidé le 12/11/2026 de garder N1 ; le critère 8 est vu à l'écran en A10 | 12/11/2026 | critères de T7 + (6), (7), (8) |
| A9 (décision 83) | Faite, N1 (analyse sans erreur, 542 tests dont 10 nouveaux ; « 6 L · 24 verres », « 2 gâteaux · 16 parts » sous chaque stock de Stock de départ, Gymnases et stock, caisse, Courses, Bilan ; aucun test existant modifié) | 12/11/2026 | critères (1), (2), (3) de 18.5 |
| A8 (T8 + 6 à 9, décision 82) | Faite, N1 (analyse sans erreur, 549 tests ; « En stock : n » + « Modifier », bouton « Valider les courses (n / m cochés) », cocher sans effet sur le stock, « Quantités par produit » en Préparation sous « Ce qu'on prévoit de vendre » ; tests de calcul des courses inchangés). Parcours integration_test qui saisissent les quantités depuis Courses à adapter et à rejouer au N3 de A10 | 12/11/2026 | critères de T8 + (6) à (9) |

### 18.6 Prompt de lancement de la session mère du lot A — REMPLACÉ par 18.8 le 12/11/2026, gardé pour trace (remplaçait celui de la section 16 ; à coller dans une conversation neuve de Claude Code, sur Sonnet, dans le dossier Le_comptoir du poste utilisé)

```
Tu es la session mère du lot A « Prêt pour le tournoi » de Le Comptoir (temps de réalisation : phases 5, 6 et clôture). Tu ne codes pas toi-même : tu cadres, tu confies chaque étape à une sous-session neuve, tu vérifies ses tests et tu tiens le suivi. Le tournoi a lieu ce week-end (essai à blanc vendredi) : va droit au but.

1. Lis, dans cet ordre : METHODO\3_CHANTIER.md (dossier DEV du poste), PROJET_CONTEXTE.md (bloc STATUT, décisions 13, 19, 23, 31, 56, 70 à 84, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md sections 16 (T1 à T9 : critères, constats, préalables, arrêts) et 18 (plan complet : lot A = A1 à A10, recoupements, critères ajoutés en 18.5, ordre), section 17 pour le détail des points 1, 3, 5, 7, 9 à 12, CHANGELOG.md (dernière entrée), graphify-out/GRAPH_REPORT.md.
2. Préalable : vérifie que la branche de cadrage `claude/pret-tournoi` (sections 17 et 18, décisions 80 à 84) est fusionnée dans main. Sinon, tu t'arrêtes là et tu le dis à Kinder.
3. Hygiène git : rien de non enregistré (le dossier `graphify-out/converted/`, produit par graphify, n'est pas du travail de Kinder : laisse-le), main à jour avec le dépôt en ligne, puis branche `claude/lot-a-tournoi` depuis main. Jamais de travail sur main.
4. Pour chaque étape, dans l'ordre A1 → A2 → A3 → A4 → A5 → A6 → A7 → A9 → A8 → A10 :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 18 (« Cadrage An »), critères repris tels quels (section 16 pour l'étape T d'origine + ajouts de 18.5).
   b. Phase 6 : confie l'étape à une sous-session neuve au format MISSION (R14), modèle selon R17 : Sonnet, sauf A2 en « opus ». Dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test. Elle rend un BILAN au format unique (R15, 10 lignes max).
   c. Vérifie la preuve au niveau écrit au plan (N1 : flutter analyze, flutter test, tests_regles/lancer.ps1 ; N2 : le seul parcours Android qui prouve le critère, sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent (préalable 2 de la section 16).
   d. Ligne dans le tableau de suivi de la section 18, ligne dans CHANGELOG.md, commit sur la branche. Puis étape suivante, sans attendre Kinder.
5. Pas de banc d'essai dans cette mission (décision 75) : N3 de la clôture = powershell -File tests_regles/lancer_integration.ps1 ; rouges connus : evenements_test, menus_test, images_test, et les parcours à captures figés (parcours_ergonomie_test, parcours_retours_terrain_test). Une sous-session n'enquête jamais sur un rouge connu.
6. A3 : le classeur du club part de recette/historique-tournoi-an-passe.xlsx et porte le menu et les recettes de l'association test (décision 84) ; l'import ne crée aucun menu en double. Les classeurs du club ne sont pas dans le dépôt : s'ils manquent sur le poste, demande-les à Kinder avant A3.
7. A8 et A9 : affichage et rangement seulement (décisions 82 et 83) ; tous les tests de calcul des courses et de la prévision passent sans modification. « Il reste » garde sa saisie derrière un bouton « Modifier ».
8. Aucune dépendance nouvelle sans accord de Kinder (A7 : réutiliser l'affichage de QR existant, `EcranQr`). Les calculs, le bilan et les droits des rôles ne changent pas ; le nom et le prix d'un produit déjà dans un événement restent figés.
9. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite.
10. Clôture (A10, R11) : N3, puis vérification par une autre IA dans une conversation neuve sur Sonnet (capture et verdict par critère de fin du lot A, 18.5). En cas d'échec, retour en phase 6 sur les seuls critères échoués. Puis documentation et CHANGELOG, branche poussée, APK de recette 1.5.0 ; rappel à Kinder : installer 1.5.0 sur tous les téléphones du week-end, essai à blanc vendredi sur deux téléphones (vraie coupure de réseau, connexion Google). Fusion dans main seulement sur accord écrit de Kinder ; la mission ne passe « Close » qu'après son test final avec capture.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```

### 18.7 Reprise au 12/11/2026 — état réel du lot A et plan corrigé — VALIDÉ par Kinder le 12/11/2026 (« Je valide »)

**Constat.** Les étapes T1 à T8 ont été codées et enregistrées le 11/11/2026 sur le PC, sur une branche `claude/pret-tournoi` qui n'avait jamais été envoyée en ligne ; T9 avait commencé (version 1.5.0+6, texte de vérification, batterie complète des parcours interrompue sur `parcours_mission_test`). Le plan complet (sections 17 et 18) a été écrit le 12/11/2026 sur l'autre poste sans voir ce travail, d'où la phrase « aucune des étapes T1 à T9 n'est livrée », **fausse**. Le 12/11/2026, avec l'accord de Kinder : les parcours adaptés pendant le N3 sont enregistrés (commit d7cd723), le travail est envoyé en ligne, puis joint au plan de main sur la branche **`claude/lot-a-tournoi`** (un seul conflit, le CHANGELOG, résolu en gardant les deux côtés). Les cadrages T1 à T8, le relevé T3 et le texte de vérification T9, rangés par erreur dans la section 13, sont replacés en fin de section 16. Décisions 75 à 84 et critères 18.5 **inchangés** : seul le travail restant change.

| Étape | Déjà fait (section 16) | Reste à faire (critères de 18.5) | Modèle |
|---|---|---|---|
| A1, A4, A5, A6 | T1, T4, T5, T6 : tout | rien (lignes au suivi ci-dessus) ; leurs critères sont rejoués en A10 | — |
| A2 | T2 : assistant complet, menu existant de même nom repris sans modification (critère 2 de T2) | critère (9) : un classeur qui **porte** un menu de même nom ne crée aucun menu et ne modifie pas l'existant, **et le résumé le dit** ; test d'écran ou de logique dédié | Sonnet (complément d'un cas, le gros de l'assistant est fait) |
| A3 | T3 : `recette/classeur-notre-club.xlsx` avec Menu et Recettes **vides** (ancienne réponse) | refaire le classeur avec les feuilles Menu et Recettes **remplies** d'après le menu de l'association test (décision 84) ; parcours `classeur_club_test` adapté : import par l'assistant, aucun menu en double, consommations toujours égales au relevé | Sonnet |
| A7 | T7 : cartes, badge de statut par membre, « Changer le statut » | (6) un badge de **couleur par rôle**, identique partout ; (7) « Qui peut quoi » = une carte par rôle avec liste à puces ; (8) QR de l'association dans la carte « Association et code », gestion seulement, scanné depuis un autre téléphone = entrée comme bénévole (réutiliser `EcranQr` et le lecteur existant ; si le lecteur n'accepte pas un QR sans événement ni gymnase, l'étendre sans dépendance) | Sonnet |
| A9 | rien | entière : unité d'achat et unité de vente à côté de chaque stock sur les cinq écrans (décision 83) | Sonnet |
| A8 | T8 : bandeau résumé, rayons en cartes repliables, actions fixées en bas | (6) « En stock : n [unité] » + bouton « Modifier » à la place du champ « Il reste » ; (7) cocher ne change pas le stock, seul « Valider les courses (n / m cochés) » le change ; (8) « Quantités par produit » passe en Préparation sous « Ce qu'on prévoit de vendre » ; (9) tests de calcul des courses inchangés et verts | Sonnet |
| A10 | T9 commencé : version 1.5.0+6, texte de vérification T9 (critères 1 à 9 de T9), parcours adaptés | compléter le texte de vérification avec les critères ajoutés du lot A (18.5 et critère de fin du lot A) ; N3 complet ; vérification par une autre IA ; APK 1.5.0 | Sonnet |

**Ordre restant** (ordre validé, étapes faites retirées) : **A2 → A3 → A7 → A9 → A8 → A10**.

**Préalable avant A3** : le menu de l'association test est sur le vrai serveur, que le chantier ne touche jamais. Source : le fichier « Données de l'association » que Kinder télécharge depuis l'application (Extraction et modèle), complété par les fiches de composition du classeur d'origine (17.2) pour les recettes. S'il manque sur le poste, la session mère le demande à Kinder avant A3 (et continue A7, A9, A8 en attendant).

**Temps** : l'essai à blanc est le vendredi 13/11/2026. Si A10 ne peut pas commencer à temps, la session mère s'arrête et le dit à Kinder ; c'est Kinder qui décide de clore le lot A avec les étapes faites (le reste passe au lot B) — jamais la session seule. Chaque étape ne change que l'affichage : l'application reste stable après n'importe laquelle.

**Critères, préalables, ce qu'on ne touche pas, arrêts** : ceux de la section 16 et de 18.5, inchangés.

### 18.8 Prompt de lancement de la session mère du lot A (reprise du 12/11/2026 ; remplace 18.6 ; à coller dans une conversation neuve de Claude Code, sur Sonnet, dans le dossier Le_Comptoir du poste utilisé)

```
Tu es la session mère du lot A « Prêt pour le tournoi » de Le Comptoir (temps de réalisation : phases 5, 6 et clôture), en REPRISE : une partie du lot est déjà faite. Tu ne codes pas toi-même : tu cadres, tu confies chaque étape à une sous-session neuve, tu vérifies ses tests et tu tiens le suivi. Le tournoi a lieu ce week-end (essai à blanc vendredi 13/11) : va droit au but.

1. Lis, dans cet ordre : METHODO\3_CHANTIER.md (dossier DEV du poste), PROJET_CONTEXTE.md (bloc STATUT, décisions 13, 19, 23, 31, 56, 70 à 84, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 18.7 (ÉTAT RÉEL ET TRAVAIL RESTANT : c'est elle qui fait foi), puis 18.5 (critères), section 16 (critères de T1 à T9, cadrages T1 à T8, relevé T3, texte de vérification T9, préalables, arrêts), section 17 pour le détail des points 1, 3, 5, 7, 9 à 12, CHANGELOG.md (dernières entrées), graphify-out/GRAPH_REPORT.md.
2. Hygiène git : rien de non enregistré (le dossier `graphify-out/converted/` et les fichiers `audit_front/*_test.txt` sont des sorties d'outils, pas du travail de Kinder : laisse-les) ; récupère le dépôt en ligne ; travaille sur la branche EXISTANTE `claude/lot-a-tournoi` (elle contient T1 à T8, le début de T9 et ce plan), à jour avec sa copie en ligne. Ne crée pas de nouvelle branche depuis main : tu perdrais T1 à T8. Jamais de travail sur main.
3. Ne refais pas A1, A4, A5, A6 (faites, voir le suivi de 18). Pour chaque étape restante, dans l'ordre A2 → A3 → A7 → A9 → A8 → A10 :
   a. Phase 5 : cadre l'étape toi-même en partant de ce qui existe (cadrage Tn de la section 16 et code actuel) : seulement le « reste à faire » de 18.7 ; écris ce cadrage sous la section 18 (« Cadrage An »), critères repris tels quels (section 16 pour l'étape T d'origine + ajouts de 18.5).
   b. Phase 6 : confie l'étape à une sous-session neuve au format MISSION (R14), modèle selon 18.7 (Sonnet partout). Dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test. Elle rend un BILAN au format unique (R15, 10 lignes max).
   c. Vérifie la preuve au niveau écrit au plan (N1 : flutter analyze, flutter test, tests_regles/lancer.ps1 ; N2 : le seul parcours Android qui prouve le critère, sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent (préalable 2 de la section 16).
   d. Ligne dans le tableau de suivi de la section 18, ligne dans CHANGELOG.md, commit sur la branche, branche envoyée en ligne (le travail ne reste jamais sur un seul poste). Puis étape suivante, sans attendre Kinder.
4. A3 : préalable de 18.7 (fichier « Données de l'association » de l'association test). S'il manque, demande-le à Kinder en une question et avance A7, A9, A8 en attendant. Jamais d'accès au vrai projet Firebase.
5. A8 et A9 : affichage et rangement seulement (décisions 82 et 83) ; tous les tests de calcul des courses et de la prévision passent sans modification. « Il reste » garde sa saisie derrière un bouton « Modifier ».
6. Aucune dépendance nouvelle sans accord de Kinder (A7 : réutiliser `EcranQr` et le lecteur existant). Les calculs, le bilan et les droits des rôles ne changent pas ; le nom et le prix d'un produit déjà dans un événement restent figés.
7. Pas de banc d'essai dans cette mission (décision 75) : N3 de la clôture = powershell -File tests_regles/lancer_integration.ps1 (en arrière-plan, long) ; rouges connus : evenements_test, menus_test, images_test, et les parcours à captures figés (parcours_ergonomie_test, parcours_retours_terrain_test). Une sous-session n'enquête jamais sur un rouge connu. Le N3 du 11/11 s'était arrêté sur parcours_mission_test : le rejouer seul avant de conclure à un défaut.
8. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite ; A10 impossible à commencer à temps pour l'essai à blanc (Kinder décide alors de clore avec les étapes faites).
9. Clôture (A10, R11) : complète le texte de vérification T9 (section 16) avec les critères ajoutés de 18.5 et le critère de fin du lot A ; N3 ; puis vérification par une autre IA dans une conversation neuve sur Sonnet (capture et verdict par critère). En cas d'échec, retour en phase 6 sur les seuls critères échoués. Puis documentation et CHANGELOG, branche envoyée, APK de recette 1.5.0 ; rappel à Kinder : installer 1.5.0 sur tous les téléphones du week-end, essai à blanc vendredi sur deux téléphones (vraie coupure de réseau, connexion Google). Fusion dans main seulement sur accord écrit de Kinder ; la mission ne passe « Close » qu'après son test final avec capture.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```

### Cadrage A2 — Assistant d'import : menu de même nom porté par le classeur (phase 5, 12/11/2026)

**Critères (repris tels quels)** : ceux de T2 (section 16, 1 à 8, déjà tenus) + **(9) un classeur qui porte un menu de même nom que celui de l'association ne crée aucun menu et ne modifie pas l'existant ; le résumé le dit.**

**Constat dans le code** : `preparerAssistant` (`lib/import_assistant.dart`) reprend déjà un menu existant de même nom (`ActionMenu.reprendre`, phrase « existe déjà, repris sans aucune modification », produits du classeur absents du menu listés en « ignorées »). `ecran_import_test.dart` joue déjà ce cas avec une feuille Menu à produits, sans recettes. Reste : (a) prouver le cas que le classeur du club (A3) va produire, c'est-à-dire un classeur dont la feuille **Menu ET la feuille Recettes sont remplies** avec un menu de même nom : aucune écriture de menu, de produit ni de recette, et le résumé le dit (y compris pour les recettes du classeur, non reprises) ; (b) si la phrase du résumé ne mentionne pas les recettes non reprises, l'ajouter (texte seul).

**Stratégie** : test de logique (`test/import_assistant_test.dart`) et test d'écran (`test/ecran_import_test.dart`) avec un classeur Menu + Recettes remplis (helper `classeurDeTest` : étendre avec un paramètre `recettes` si besoin, sans changer les usages existants). Vérifier que `faux.menusCrees` reste vide et qu'aucune écriture de recette n'est demandée. Correction de code seulement si le test montre une écriture ou une phrase manquante.

**Fichiers touchés** : `test/import_assistant_test.dart`, `test/ecran_import_test.dart`, `test/classeur_aides.dart`, au besoin `lib/import_assistant.dart` (phrase du résumé). **On ne fait pas** : aucun changement de lecture du classeur, de calcul, de règle, de dépendance ; menu existant jamais modifié.

**Preuve** : N1 seulement (`flutter analyze`, `flutter test test/import_assistant_test.dart test/ecran_import_test.dart`, puis `flutter test` complet) ; le parcours N2 de T2 (`assistant_import_test`) est déjà vert et rejoué en A3.

### Cadrage A7 — Paramètres : badges de couleur par rôle, « Qui peut quoi » en cartes, QR de l'association (phase 5, 12/11/2026, décisions 80 et 81)

**Critères (repris tels quels)** : ceux de T7 (section 16, 1 à 5, déjà tenus) + **(6) un badge de couleur par rôle, identique partout ; (7) « Qui peut quoi » = une carte par rôle avec liste à puces ; (8) la gestion voit le QR code de l'association et peut le scanner depuis un autre téléphone pour entrer comme bénévole ; un bénévole ne voit pas le QR.**

**Constat dans le code** : `_couleursStatut` (`lib/ecran_association.dart`) donne déjà un badge par statut, mais local à l'écran et avec le bénévole et le responsable proches (gris foncé / gris clair) ; « Qui peut quoi » (`_quiPeutQuoi`) est un seul texte de trois paragraphes dans une carte repliable. `EcranQr` (`lib/ecran_qr.dart`) n'affiche que le QR d'un gymnase (`ecrireLienGymnase`, lien `lecomptoir://rejoindre?v=1&c=&e=&g=`) ; `lireLienGymnase` (`lib/gymnase.dart`) refuse un lien sans `e` et `g` ; l'accueil (`lib/ecran_accueil.dart`, `_scanner`) lit ce lien, demande le prénom, appelle `depot.rejoindre` puis `surLien`. Aucune dépendance à ajouter (`mobile_scanner` et `qr_flutter` sont là).

**Stratégie** : (a) une seule fonction de couleurs de rôle dans `lib/theme.dart` (ou à côté de `libelleStatut`), palette de la décision 31 : responsable = anthracite sur blanc, gestionnaire = prune, gestionnaire en attente = ocre, bénévole = sauge ; `ecran_association.dart` l'utilise ; tout autre endroit qui affiche un rôle ou un statut de membre (grep `libelleStatut`, `role`) l'utilise aussi. (b) `_quiPeutQuoi` : toujours la carte repliable, mais son contenu = une carte par rôle (badge du rôle + liste à puces de ce qu'il peut et ne peut pas faire, texte repris des droits actuels : décisions 19, 23, 71, rien d'inventé). (c) QR de l'association : nouveau lien sans événement ni gymnase (`ecrireLienAssociation(code)` : `lecomptoir://rejoindre?v=1&c=<code>`), `lireLienGymnase` / la lecture du lien acceptent un lien sans `e` ni `g` (ids vides = pas de gymnase) et `surLien` de l'accueil n'ouvre alors aucun événement : le scanneur entre comme bénévole, exactement comme le code tapé ; les liens de gymnase existants fonctionnent inchangés. (d) Dans la carte « Association et code » (responsable ; la gestion seule voit cette carte, vérifier si le gestionnaire la voit — sinon la règle actuelle d'affichage fait foi et le QR suit la même visibilité que le code), un QR (`QrImageView`) avec le texte « À faire scanner par les bénévoles : ils rejoignent l'association », se mettant à jour si le code change. Aucun droit, aucune règle ne change.

**Fichiers touchés** : `lib/theme.dart`, `lib/ecran_association.dart`, `lib/gymnase.dart` (lien d'association), `lib/ecran_accueil.dart` (surLien sans gymnase), au besoin `lib/ecran_qr.dart` (libellé du scanner), tests `test/` (parametres_test, membres_test, qr_test, code_association_test, gymnase) et un parcours N2 `integration_test/qr_test.dart` adapté si le scan est déjà couvert. **On ne fait pas** : aucune règle, aucun droit, aucune dépendance, aucun changement du fonctionnement de `rejoindre`.

**Preuve** : N1 (`flutter analyze`, `flutter test`) : tests d'écran par rôle (badges de couleurs distinctes, une carte par rôle, QR visible pour la gestion et absent pour un bénévole, le QR contient le code) et de logique (écriture et lecture du lien d'association, anciens liens de gymnase inchangés, lien illisible refusé) ; le scan complet par un faux lecteur sur l'écran d'accueil entre comme bénévole sans ouvrir d'événement. N2 : le parcours qui prouve le critère 8 (un second compte scanne, par faux lecteur, le lien lu depuis le QR de l'association et devient bénévole) sur LC2, seulement si `integration_test/qr_test.dart` ne le couvre pas déjà.

### Cadrage A9 — Unités affichées à côté de chaque stock (phase 5, 12/11/2026, décision 83)

**Critères (repris tels quels, 18.5)** : (1) chaque quantité de stock affiche son unité d'achat et, s'il y en a une, son unité de vente (verres, parts) sur les cinq écrans cités (Stock de départ, Gymnases et stock, caisse, Courses, Bilan) ; (2) les conversions sont justes (verres par litre du produit, parts par gâteau du produit) ; (3) aucun test de calcul ne change.

**Constat dans le code** : le stock est compté dans l'unité de vente (verres pour un produit « au litre », parts pour un produit « à la part », unités sinon). La fiche (`FicheProduit`, `lib/depot_menus.dart`) porte `verresParLitre` et `partsParEntier` ; les conversions existent (`litresDepuisVerres`, `verresDepuisLitres`, `lib/restes.dart`). Une unité d'achat n'est connue que pour ces deux types : le litre (au litre) et le gâteau (à la part, si `partsParEntier` est renseigné). Les autres produits (à l'unité, composés) n'ont qu'une unité : rien à ajouter.

**Stratégie** : une seule fonction pure d'affichage, `libelleStockUnites(FicheProduit fiche, num quantiteEnUniteDeVente)` (nouveau petit fichier `lib/unites_affichees.dart`, ou dans `lib/restes.dart`), qui renvoie « 6 L · 24 verres » (4 verres par litre), « 2 gâteaux · 16 parts », ou simplement « 24 » pour un produit sans autre unité ; arrondis comme l'existant (`nombrePourSaisie`, au plus 2 décimales, jamais de « 0,0000001 »). Les cinq écrans l'appellent à côté de la quantité qu'ils affichent déjà (suffixe ou ligne secondaire), sans changer ce qui est saisi ni stocké, sans nouvelle lecture. Un produit sans verres par litre ou sans parts par gâteau renseigné : on affiche seulement l'unité de vente. Pour Courses, A8 reprendra la fonction pour « En stock : n [unité] ».

**Fichiers touchés** : nouveau `lib/unites_affichees.dart`, `lib/ecran_stock_depart.dart`, l'écran « Gymnases et stock » (`lib/ecran_stock.dart` ou équivalent : `grep stock lib/ecran_*.dart`), l'écran de caisse (`lib/ecran_caisse.dart`, affichage du stock restant seulement), `lib/ecran_courses.dart` (stock affiché ; si A8 n'est pas encore faite, seulement les endroits qui montrent déjà une quantité de stock), l'écran du bilan (`lib/ecran_bilan.dart`), tests `test/`. **On ne fait pas** : aucun calcul, aucune écriture, aucune règle, aucune dépendance, pas de changement de la saisie (un stock se saisit comme avant).

**Preuve** : N1 seulement (`flutter analyze`, `flutter test`) : tests de logique de la fonction (litre avec 4 verres par litre, gâteau avec 8 parts, produit à l'unité, fiche incomplète, arrondis) et un test d'écran par écran montrant l'unité ; tous les tests existants de calcul passent sans modification.

### Cadrage A8 — Courses : « En stock » avec Modifier, cocher ≠ valider, « Quantités par produit » en Préparation (phase 5, 12/11/2026, décision 82)

**Critères (repris tels quels)** : ceux de T8 (section 16, 1 à 5, déjà tenus) + **(6) aucun champ « Il reste » : « En stock : n [unité] » et un bouton « Modifier » qui garde la saisie ; (7) cocher un article ne change pas le stock ; seul « Valider les courses (n / m cochés) » le change ; (8) « Quantités par produit » n'est plus dans Courses et se trouve dans la Préparation ; (9) tous les tests de calcul des courses passent sans modification.**

**Constat dans le code** (`lib/ecran_courses.dart`, 1111 lignes) : (6) `_ligneArticle` porte un `TextFormField` `reste_<cle>` (« Il reste », unité `libelleUniteReste`) qui écrit `_liste.restes` via `_surReste` ; ces restes (ingrédients, conditionnements) ne se saisissent nulle part ailleurs : la saisie reste, derrière « Modifier ». (7) cocher (`_basculerCoche` → `depot.cocherArticle`) ne touche déjà pas le stock : il n'enregistre que la coche partagée ; le stock change seulement dans l'écran de validation (`EcranValidationCourses`, ouvert par `_valider`, bouton `valider_courses` libellé « Saisir ce que j'ai acheté »). Reste à : renommer ce bouton « Valider les courses (n / m cochés) » (n = articles cochés, m = articles de la liste) et rendre clair que la case veut dire « dans le panier » (réversible). (8) le bloc `quantites_produits` (« Quantités par produit », `_ligneProduit` par gymnase, case `coche_<g>_<p>` + quantité, qui alimente `_liste.lignes` d'où sont calculés les achats ; état `_tableaux`, `_stocks`, `_suggeres`, `_version`) est dans l'onglet « À acheter ».

**Stratégie** : (a) « Il reste » : remplacer le champ par une ligne « En stock : n [unité] » (n = reste saisi, « non renseigné » sinon ; unité `libelleUniteReste` ; la fonction de A9 `libelleStockUnites` seulement quand elle s'applique à un produit fini) et un bouton « Modifier » (clé `modifier_reste_<cle>`) qui ouvre la saisie (champ `reste_<cle>` conservé, dans une petite feuille ou en place) ; `_surReste` et `_liste.restes` inchangés. (b) Bouton fixé en bas : « Valider les courses (n / m cochés) » (clé `valider_courses` conservée) ; aucune action sur le stock avant l'écran de validation. (c) Extraire le bloc « Quantités par produit » en un widget partagé (ou l'écran existant `EcranPrevision` / l'onglet Préparation de l'événement, `lib/ecran_evenement.dart`) affiché dans la Préparation, à côté de la prévision, sous le titre « Ce qu'on prévoit de vendre » ; il lit et écrit le MÊME document de liste de courses par les mêmes méthodes du dépôt (aucun changement de calcul ni de format) ; la page Courses relit la liste au retour (ou en direct) pour que les achats suivent. Si le déplacement exige de changer un calcul, un format ou une règle : s'arrêter et le dire (arrêt de la mission). (d) Courses ne montre plus que ce qu'il faut acheter. Cartes, rayons, bandeau, actions : inchangés.

**Fichiers touchés** : `lib/ecran_courses.dart`, `lib/ecran_evenement.dart` et/ou `lib/ecran_prevision.dart` (affichage de la section), éventuellement `lib/depot_evenements.dart` (lecture/écriture de la liste déjà existantes : ne changer que si nécessaire au partage, sans changer le format), tests `test/courses_ecran_test.dart`, `test/courses_rayons_test.dart` et nouveaux tests ; parcours `integration_test/courses_test.dart` à adapter seulement pour l'endroit où se fait la saisie (hors rouges connus). **On ne fait pas** : aucun calcul (`lib/courses.dart` intouché), aucune règle, aucune dépendance, aucun changement de ce que fait la validation ni de ses droits.

**Preuve** : N1 (`flutter analyze`, `flutter test` : `test/courses_test.dart` et voisins sans modification de leur contenu ; tests d'écran : « En stock » + « Modifier » garde la saisie, cocher ne change pas le stock, bouton « Valider les courses (n / m cochés) », bloc absent de Courses et présent dans la Préparation, saisie d'une quantité en Préparation → l'achat apparaît dans Courses). N2 seulement si un parcours existant (`courses_test`) doit être adapté et rejoué : un seul passage, au premier plan.

### Cadrage A3 — Classeur du club avec menu et recettes remplis (phase 5, 12/11/2026, décision 84)

**Critères (repris tels quels)** : ceux de T3 (section 16) sauf (2) remplacé par : **les feuilles Menu et Recettes sont remplies d'après le menu de l'association test ; importé par l'assistant sur émulateur : aucun menu en double** ; consommations toujours égales au relevé T3.

**Sources (Kinder, 12/11/2026)** : le fichier « Données de l'association » n'étant pas disponible, Kinder a déposé `recette/Nouvelle feuille 2.xlsx` (classeur d'origine du club, hors dépôt : noms de bénévoles) et donné le nom du menu de l'association test : « **Les Discjonctés** ». Produits : les 19 noms de l'historique de l'an passé (relevé T3) ; prix : « Rappels Tarifs 2024 » de la feuille « Derniere liste » (à vérifier par Kinder : ils ne sont repris que si le menu n'existe pas, car un menu de même nom est repris sans modification) ; recettes : fiches « CM standard », « CM Veggie », « CM Tartiflette », « CM Nutella » pour les quatre croques ; boissons : type « Au litre », 4 verres par litre (feuille Repas) ; produits sans fiche (crêpes, fruit, barres, Mars, Twix, bière) : « À l'unité » et signalés au relevé.

**Stratégie** : script Python (openpyxl, dossier temporaire, hors dépôt) qui part du `recette/classeur-notre-club.xlsx` actuel, remplit les feuilles Menu et Recettes aux en-têtes de `lib/classeur.dart` (liens relatifs réécrits après écriture : piège connu), garde Historique et Stock de départ. Parcours `integration_test/classeur_club_test.dart` adapté : l'assistant importe le classeur dans une association dont le menu s'appelle « Les Discjonctés » : aucun menu créé, le résumé le dit, consommations égales au relevé. Relevé A3 écrit sous le relevé T3 (section 16) : ce qui est repris, de quelle feuille, ce qui est à vérifier par Kinder (prix 2024, produits sans recette).

**Fichiers touchés** : `recette/classeur-notre-club.xlsx`, `integration_test/classeur_club_test.dart`, section « Relevé A3 » du plan. **On ne fait pas** : aucun code de l'application, aucun accès au vrai projet Firebase, aucune dépendance ; aucun nom de bénévole ni donnée de l'équipe hors du classeur d'origine n'est repris.

**Preuve** : N2 : `classeur_club_test` seul (LC2, vrai moteur local), joué par la mère.

## 19. Mission « Calcul du club » — version 1.6.0 (décisions 85 à 92) — PLAN PRÊT : plan, critères et préalables validés par Kinder le 12/11/2026 (« Je valide »)

> Origine : le 12/11/2026 au soir, Kinder avance au week-end trois points du lot B (section 18.2) : **4** (effectifs et pourcentages du classeur d'origine), **6** (stock des produits composés et de leurs composants), **8** (écran de l'article en cartes), plus la **simulation complète** sur les chiffres de l'an dernier (17.4). Phase 2 menée le 12/11/2026 dans Claude Code (sept questions, une à une, toutes tranchées par Kinder) ; décisions 85 à 92 en section 6 de `PROJET_CONTEXTE.md`. Le point 2 (plusieurs associations) reste après le tournoi.
> Garde-fou (décision 85) : la 1.5.0 (lot A) reste la version du tournoi ; la 1.6.0 ne sert ce week-end que si Kinder le décide, au vu de la simulation, étape par étape (« je te dirai ce que je valide et ce qu'on prend pour ce week-end », Kinder, 12/11/2026).

**Critère de fin de mission (validé par Kinder, 12/11/2026)** : « Dans un tournoi à 2 gymnases et 2 jours, j'importe le classeur de notre club : les repas jour par jour et les groupes du club sont en place, et les quantités prévues sont celles de notre classeur d'origine ; je saisis mes ingrédients en stock dans la Préparation et les courses en tiennent compte ; la fiche d'un article s'ouvre en cinq cartes ; la simulation complète du tournoi sur les chiffres de l'an dernier va jusqu'au bilan, juste au centime. »

### 19.1 Constats faits au cadrage (12/11/2026)

- **Calcul actuel** (`lib/courses.dart`, `quantitePrevue`) : quantité = personnes du gymnase × nombre de jours de l'événement × consommation par personne et par jour du produit. Un seul nombre de personnes par gymnase (`Gymnase.personnes`, `lib/gymnase.dart`), un nombre de jours par événement (`nbJours`, `lib/evenement.dart`), une consommation par produit (fiche du menu, remplacée par la prévision de l'événement, `lib/previsions.dart`, collection `previsions`). Samedi = dimanche.
- **Méthode du club** (`recette/Nouvelle feuille 2.xlsx`, hors dépôt) : par gymnase et par jour, **total des repas** = (joueuses + accompagnateurs) + (bénévoles + famille) + spectateurs, midi et soir (ex. Gymnase 1 samedi : 119 repas ; dimanche 130 ; Gymnase 2 : 141 et 121). Puis, par jour, un **pourcentage par groupe** (Plat 70 % / 80 % ; Dessert + 4 h 110 % / 100 % ; Fruit 50 % / 60 % ; Barres 20 % / 25 % ; Boissons froides 150 % / 150 % ; Bière 30 % ; Boissons chaudes 110 % / 150 %) et une **part par produit dans son groupe, elle aussi propre au jour** (croque standard 40 % le samedi, 35 % le dimanche ; végé 25 % / 30 % ; tartiflette 35 % / 35 %). Quantité d'un produit = repas du jour × % du groupe ce jour × part du produit ce jour (ex. croque standard, Gymnase 1 samedi : 119 × 0,70 × 0,40 = 33,32).
- **Groupes ≠ familles** : les familles du menu (`lib/liste_familles.dart` : croques, boissons chaudes, boissons fraîches, snacks et fruits, fait maison, autre) servent à l'affichage ; les groupes du club n'y correspondent pas (le croque Nutella est un dessert ; fruit et barres séparés ; bière à part).
- **Écarts de produits** : le club détaille « Fruit » en pomme, banane, clémentine (vendue par 2) et compte des sucres ; le menu de l'application a un seul produit « Fruit » et pas de sucre. Ces écarts sont relevés en V5, jamais inventés.
- **Point 6** : les trois niveaux sont déjà calculés. Produits finis en stock = Stock de départ par gymnase, déduits du produit (donc de ses ingrédients) ; ingrédients et emballages en stock = « En stock » de la page Courses (lot A, A8 ; `_liste.restes`, pour tout l'événement), déduits des achats. Il manque seulement une saisie à la bonne place : la Préparation.
- **Point 8** : l'article s'édite dans une boîte de dialogue (`lib/ecran_menu.dart`, `_editerProduit` et `showDialog<ProduitSaisi>`, 786 lignes), champs qui se chevauchent (capture `recette/capture-produit-croque-tartiflette.jpg`).
- **Classeur** (`lib/classeur.dart`) : feuilles Accueil, Menu, Recettes, Stock de départ, Historique, Courses (+ Bilan à l'export) ; lues par l'assistant d'import du lot A (`lib/import_assistant.dart`).

### 19.2 Préalables (validés avec le plan)

1. **R29** : le chantier démarre quand le lot A est fusionné dans main (en attente de la capture de Kinder). La branche de cadrage `claude/cadrage-calcul-club` est fusionnée avant, sur accord de Kinder. **Remplacé le 12/11/2026 par le départ anticipé de 19.5 (écart à R29 décidé par Kinder).**
2. Règles d'accès déployées sur le vrai projet dès que leurs tests passent (accord donné une fois pour la mission, comme au lot A).
3. Une session mère (Sonnet) mène les étapes une par une, chacune dans une sous-session neuve, modèle selon R17 ; V1 en « opus ».
4. Aucune dépendance nouvelle sans accord de Kinder.
5. Pas de banc d'essai dans cette mission (écart à R35, comme décision 75) : N3 = `tests_regles/lancer_integration.ps1`, rouges connus inchangés.
6. Le classeur d'origine reste hors dépôt (noms de bénévoles) ; aucun nom n'en sort.
7. Après chaque étape : branche envoyée en ligne (leçon du 12/11/2026).

**Ce qu'on ne touche pas** : l'ancien calcul (événements sans repas détaillés : décision 87) ; le calcul des courses à partir des quantités de produits (recettes, rendements, conditionnements) ; la caisse, le bilan, les droits des rôles ; les menus (les groupes vivent dans l'événement : décision 88) ; le nom et le prix d'un produit déjà dans un événement.

### 19.3 Étapes (une à la fois ; niveau de preuve selon R34)

| # | Étape | Ce que Kinder voit | Critères | Preuve |
|---|---|---|---|---|
| V1 « opus » | Calcul du club (décisions 86 à 88) | Rien encore (logique) | (1) repas d'un gymnase pour un jour = somme des trois catégories, midi et soir ; (2) quantité d'un produit = Σ jours (repas du jour × % du groupe ce jour × part du produit ce jour), arrondie à l'unité supérieure par gymnase ; (3) un événement sans repas détaillés garde exactement l'ancien calcul (tous les tests existants de prévision et de courses passent sans modification) ; (4) un test reprend les chiffres du classeur d'origine (repas, %, parts des deux jours, deux gymnases) et retrouve ses quantités (ex. croque standard Gymnase 1 samedi 33,32, dimanche 36,4) ; (5) les parts d'un groupe qui ne font pas 100 % sont signalées, jamais corrigées en silence | N1 |
| V2 | Enregistrement et règles | Rien encore (données) | (1) repas par gymnase, par jour et par catégorie, et groupes de l'événement enregistrés dans l'événement ; (2) écriture réservée à la gestion, événement en préparation ou en cours (mêmes droits que la prévision) ; un bénévole ne peut ni écrire ni lire ces réglages s'il ne lit pas la prévision aujourd'hui ; (3) tests de règles verts, règles déployées ; (4) un événement existant n'est pas modifié | N1 (tests de règles) |
| V3 | Repas jour par jour (Préparation) | Carte « Personnes et durée » | (1) bouton « Détailler par jour (méthode du club) » ; (2) une carte par jour, et dans chacune, par gymnase, les trois catégories (joueuses et accompagnateurs, bénévoles et famille, spectateurs), midi et soir, avec le total des repas du jour ; (3) une fois détaillé, la carte montre le tableau des jours au lieu de « personnes × durée » ; (4) les quantités de la Prévision et des Courses suivent ; (5) cartes, vocabulaire et palette de l'application (décision 86) | N1 |
| V4 | Groupes dans la Prévision | Prévision | (1) une carte par groupe : nom, % de chaque jour, puis ses produits avec leur part de chaque jour ; (2) les parts d'un groupe affichent « 100 % » en vert ou l'écart en ocre (comme la case « Verif » du club) ; (3) on crée, renomme, supprime un groupe et on y range un produit ; un produit est dans un seul groupe ; (4) sources comme aujourd'hui : classeur, événement passé, à la main ; « Annuler ce changement » (lot A) couvre aussi les groupes ; (5) la quantité prévue de chaque produit, par jour, est lisible sous le produit | N1 |
| V5 | Classeur : feuilles Repas et Groupes (décision 91) | Modèle téléchargé, classeur du club | (1) le modèle téléchargeable a deux feuilles de plus, « Repas » et « Groupes », expliquées dans l'Accueil, vides ; (2) l'export d'un tournoi les remplit ; (3) l'assistant d'import les lit et règle les repas et les groupes du tournoi choisi, avec le même résumé avant écriture ; un classeur sans ces feuilles s'importe comme avant ; (4) `recette/classeur-notre-club.xlsx` porte les repas et les groupes de l'an dernier, remplis par Claude Code d'après le classeur d'origine, sans aucun nom ; (5) relevé V5 sous cette section : ce qui est repris, et les écarts (Fruit, sucre…) à voir par Kinder | N1 + N2 (import réel du classeur du club sur émulateur, vrai moteur de données : le parcours `classeur_club_test` étendu) |
| V6 | Ingrédients en stock dans la Préparation (décision 89) | Carte « Stock de départ » | (1) une partie « Ingrédients et emballages », chaque article de recette avec son unité ; (2) même chiffre que « En stock » dans Courses : saisi à un endroit, vu à l'autre ; (3) pour tout l'événement ; (4) aucun test de calcul des courses ne change | N1 |
| V7 | Simulation complète du tournoi (décision 92) | Captures de la vérification | (1) parcours `integration_test/parcours_tournoi_simule_test.dart` sur LC2 : tournoi à 2 gymnases et 2 jours, classeur du club importé ; (2) **preuve 1** : quantité prévue de chaque produit présent sous le même nom dans le classeur d'origine, par gymnase et par jour, égale à celle du classeur, arrondie à l'unité supérieure ; (3) **preuve 2** : stock de départ en produits finis (12 croques tartiflette) et en ingrédients (2 paquets de jambon), deux séries de courses cochées puis validées, stock mis à jour, rien de ce qui est en stock racheté ; (4) **preuve 3** : ventes générées d'après la consommation de l'an passé, 4 caisses (2 par gymnase), 2 jours, espèces / carte / chèque, annulations, une rupture, une caisse clôturée de force ; (5) **preuve 4** : totaux du bilan (par produit, mode, caisse, jour) = somme des ventes simulées, contrôlée par un calcul à part ; coût des courses = somme des deux séries ; résultat juste ; (6) aucune capture dans le test (R34) : le parcours laisse l'émulateur dans l'état du bilan, les captures sont prises par la vérification | N2 (plusieurs caisses et comptes, vrai moteur de données et ses règles) |
| V8 | Page de l'article en cinq cartes (décision 90) | Menu > un produit | (1) page entière à la place de la boîte de dialogue ; (2) cinq cartes : Identité (nom, prix, famille) ; Mesure (type, verres par litre ou parts par gâteau, conversion écrite en clair) ; Composition (« pour 1 [produit] », une ligne par ingrédient, quantité, unité et rayon alignés) ; Provenance et rayon ; Consommation habituelle (« sert quand les repas ne sont pas détaillés ») ; (3) « Enregistrer » principal ; « Supprimer » en brique, à part, avec confirmation ; (4) aucun champ ne se chevauche (test d'écran sur largeur de téléphone) ; (5) mêmes données enregistrées qu'avant : tests de menu inchangés et verts | N1 |
| V9 | Clôture de mission | Parcours complet, vérification, APK | (1) N3 : vert ou rouges connus seulement ; (2) vérification par une autre IA, conversation neuve sur Sonnet : une capture par critère de fin et par preuve de la simulation, rangées dans `audit_front/tournoi/simulation/` ; (3) APK de recette 1.6.0 ; (4) Kinder dit, étape par étape, ce qu'il prend pour le week-end (décision 85) ; sans son choix, la 1.5.0 reste installée | N3 |

**Ordre et dépendances** : V1 → V2 (les données portent le calcul) → V3 et V4 (écrans des repas et des groupes) → V5 (le classeur remplit repas et groupes) → V6 → **V7 (la simulation arrive aussitôt après tout ce qui touche au calcul, pour que Kinder décide au plus tôt)** → V8 (indépendante, sans effet sur le calcul, la moins urgente pour le week-end) → V9. Si le temps manque avant le tournoi, la mère s'arrête après V7 et le dit à Kinder : V8 peut suivre après le tournoi.

**Arrêts prévus** : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite ; preuve 1 de la simulation impossible à tenir (écart de calcul non expliqué) : la mère s'arrête et montre l'écart à Kinder.

**Suivi** (une ligne par étape close)

| Étape | État | Date | Critères |
|---|---|---|---|

### Cadrage V1 — Calcul du club, logique pure (12/11/2026, session mère « Calcul du club »)

**Constat sur le classeur d'origine (à garder pour V5 et V7)** : les feuilles « Gymnase 1/2 Dimanche » du classeur d'origine sont branchées sur les pourcentages du bloc **Samedi** de la feuille « Repas » (plat 70 %, dessert 110 %, parts du samedi), pas sur le bloc Dimanche (plat 80 %, dessert 100 %, fruit 60 %…). Leurs valeurs calculées sont donc celles « samedi % × repas du dimanche » (ex. G1 dimanche : plat 91, croque standard 36,4). Pour le croque standard, 130 × 0,8 × 0,35 et 130 × 0,7 × 0,4 donnent le même 36,4 (coïncidence) ; pour les autres groupes, les deux lectures diffèrent. V1 est neutre (la logique prend un pourcentage par jour) ; la lecture à retenir pour le classeur du club et la preuve 1 est une question à Kinder, posée avant V5.

**Stratégie** : nouveau fichier `lib/calcul_club.dart`, logique pure sans Firebase ni écran (comme `lib/courses.dart`). Modèles de valeur immuables : `RepasGymnaseJour` (trois catégories — joueuses et accompagnateurs, bénévoles et famille, spectateurs —, chacune avec midi et soir ; `total` = somme des six nombres) ; `GroupeConso` (nom, pourcentage par jour, produits avec une part par jour) ; `CalculClub` (repas par gymnase et par jour, groupes). Fonctions : `repasDuJour`, `quantiteClubJour` (repas × % du groupe ce jour × part du produit ce jour, nombre décimal), `quantiteClub` (Σ jours, **un seul arrondi à l'unité supérieure par gymnase** via `arrondiHaut` de `courses.dart`), `ecartsGroupes` (parts d'un groupe ≠ 100 % pour un jour : liste d'écarts, jamais de correction). Un événement sans repas détaillés : `CalculClub` absent (null), les fonctions existantes de `courses.dart` ne sont pas modifiées.

**Fichiers touchés** : `lib/calcul_club.dart` (nouveau) ; `test/calcul_club_test.dart` (nouveau). Rien d'autre.

**Ce qu'on ne fait pas** : aucune modification de `quantitePrevue`, `quantiteAPrevoir`, `Gymnase`, `Evenement`, du dépôt de données, des règles, des écrans ; pas de lecture de classeur Excel dans l'application ; pas d'enregistrement (V2) ; pas de conversion « vendu par 2 » (écart relevé en V5) ; aucune dépendance.

**Critères (repris tels quels du plan)** : (1) repas d'un gymnase pour un jour = somme des trois catégories, midi et soir ; (2) quantité d'un produit = Σ jours (repas du jour × % du groupe ce jour × part du produit ce jour), arrondie à l'unité supérieure par gymnase ; (3) un événement sans repas détaillés garde exactement l'ancien calcul (tous les tests existants de prévision et de courses passent sans modification) ; (4) un test reprend les chiffres du classeur d'origine (repas, %, parts des deux jours, deux gymnases) et retrouve ses quantités (ex. croque standard Gymnase 1 samedi 33,32, dimanche 36,4) ; (5) les parts d'un groupe qui ne font pas 100 % sont signalées, jamais corrigées en silence.

**Chiffres du test** (relevés dans le classeur d'origine, aucun nom) : repas samedi G1 : 49 joueuses et accompagnateurs ×2 (midi, soir), bénévoles et famille 10 midi / 11 soir, spectateurs 0 → 119 ; dimanche G1 : 56 ×2, 9 / 9 → 130 ; samedi G2 : 63 ×2, 7 / 8 → 141 ; dimanche G2 : 56 ×2, 6 / 3 → 121. Groupe Plat : samedi 70 %, dimanche 80 % ; croque standard 40 % / 35 %, végé 25 % / 30 %, tartiflette 35 % / 35 %. Attendus : croque standard G1 samedi 33,32 ; G1 dimanche 130 × 0,8 × 0,35 = 36,4 ; G2 samedi 141 × 0,7 × 0,4 = 39,48 ; G2 dimanche 121 × 0,8 × 0,35 = 33,88. Le total G1 sur deux jours est 69,72, arrondi à 70.

**Preuve** : N1 — `flutter analyze`, `flutter test test/calcul_club_test.dart` puis `flutter test` (suite entière, pour le critère 3 : aucun test existant modifié). Pas de règles, pas d'émulateur.

### Cadrage V2 — Enregistrement et règles (12/11/2026)

**Stratégie** : deux documents dans une sous-collection de l'événement, `evenements/{e}/calcul_club/{d}` avec `d` = `repas` ou `groupes` (aucun autre identifiant accepté). `repas` = `{jours: {"1": {gymnaseId: {joueusesMidi, joueusesSoir, benevolesMidi, benevolesSoir, spectateursMidi, spectateursSoir}}}}` (entiers) ; `groupes` = `{groupes: [{nom, pourcentages: {"1": 0.7}, produits: {produitId: {"1": 0.4}}}]}` (fractions). Les clés de jours sont des textes (Firestore). Règles : mêmes droits que `previsions` (`gereTout` pour lire ; `gereTout` + `reglable` pour écrire ; suppression par l'association en cours de suppression) ; champs exacts (`repas` : `jours` seul ; `groupes` : `groupes` seul) ; `jours` est une map de 30 entrées au plus ; `groupes` est une liste de 40 éléments au plus ; pas de contrôle profond par nombre (limite des 1000 expressions) : les bornes des nombres sont tenues par l'application (V3, V4). Côté application : sérialisation `versMap` / `depuis…` dans `lib/calcul_club.dart` (ronde aller-retour testée, entrée hors format ignorée) ; `lib/depot_evenements.dart` : `suivreCalculClub(evenementId)` (flux, rend `CalculClub?`, null si aucun des deux documents), `definirRepas`, `definirGroupes` ; `lib/depot_associations.dart` : effacer la sous-collection avec l'événement (comme `previsions`).

**Fichiers touchés** : `firestore.rules` ; `tests_regles/calcul_club.test.mjs` (nouveau) et sa ligne dans `tests_regles/lancer.ps1` ; `lib/calcul_club.dart` (sérialisation seulement, sans toucher aux fonctions de V1) ; `test/calcul_club_test.dart` (tests de sérialisation ajoutés) ; `lib/depot_evenements.dart` ; `lib/depot_associations.dart` ; l'en-tête de commentaire de `firestore.rules`. Pas d'écran.

**Ce qu'on ne fait pas** : aucune écriture sur le document de l'événement ni sur `previsions` ; pas d'écran ; aucun événement existant touché (pas de migration) ; pas de lecture par les bénévoles ; pas de dépendance.

**Critères (repris tels quels)** : (1) repas par gymnase, par jour et par catégorie, et groupes de l'événement enregistrés dans l'événement ; (2) écriture réservée à la gestion, événement en préparation ou en cours (mêmes droits que la prévision) ; un bénévole ne peut ni écrire ni lire ces réglages s'il ne lit pas la prévision aujourd'hui ; (3) tests de règles verts, règles déployées ; (4) un événement existant n'est pas modifié.

**Preuve** : N1 — `flutter analyze`, `flutter test`, `powershell -File tests_regles/lancer.ps1`. Déploiement des règles par la mère après vérification que `firestore.rules` contient celles du lot A (comparaison avec `origin/claude/lot-a-tournoi`).

### Cadrage V3 — Repas jour par jour dans la Préparation (12/11/2026)

**Stratégie** : (a) un point d'entrée unique du calcul dans `lib/calcul_club.dart` : `quantitePrevueClub` / une fonction qui, pour (gymnase, produit, jours, conso, personnes, `CalculClub?`), rend la quantité du club quand les repas sont détaillés ET que le produit est dans un groupe, sinon exactement l'ancien `quantitePrevue` (décision 87 ; un produit hors groupe garde l'ancien calcul) ; (b) la brancher aux trois endroits qui calculent aujourd'hui une quantité prévue : la liste de départ des courses (`lib/courses.dart` ~l.290, paramètre optionnel `calcul` : sans lui, comportement inchangé), `_cocher` et le tableau des quantités de `lib/ecran_courses.dart` (~l.1190-1230, flux `suivreCalculClub`), et la ligne « total » de `lib/ecran_prevision.dart` (~l.282) ; (c) l'écran `lib/ecran_personnes_duree.dart` (117 lignes, carte « Personnes et durée », ouvert depuis `lib/ecran_evenement.dart` ~l.603) : bouton « Détailler par jour (méthode du club) » ; une fois détaillé, la carte montre le tableau des jours au lieu de « personnes × durée » ; une carte par jour (nombre de jours de l'événement ; jours entiers), par gymnase les trois catégories (joueuses et accompagnateurs, bénévoles et famille, spectateurs), midi et soir, avec le total des repas du jour en lecture ; enregistrement par `definirRepas` (V2). Bornes des nombres tenues par l'application : entiers de 0 à 1000 par case ; nombre de jours = `nbJours` arrondi (pas de repas pour un demi-jour : si `nbJours` n'est pas entier, signaler en clair et ne pas détailler). Design (décision 86) : cartes, vocabulaire et palette du lot A (reprendre les composants déjà utilisés dans la Préparation), rien qui recopie l'allure d'un tableur ; clés (`Key`) sur les champs pour les tests.

**Fichiers touchés** : `lib/calcul_club.dart` (ajout du point d'entrée, V1 et V2 intactes) ; `lib/courses.dart` ; `lib/ecran_courses.dart` ; `lib/ecran_prevision.dart` ; `lib/ecran_personnes_duree.dart` ; `lib/ecran_evenement.dart` (passer le flux et les écritures) ; tests nouveaux : `test/calcul_club_test.dart` (point d'entrée), `test/ecran_personnes_duree_test.dart` (nouveau), tests d'écrans Prévision et Courses pour le critère 4 (nouveaux fichiers ou ajouts, sans modifier un test existant).

**Ce qu'on ne fait pas** : pas de groupes ni de pourcentages à saisir (V4) ; pas de classeur (V5) ; pas de stock des ingrédients (V6) ; pas de changement du calcul des courses à partir des quantités de produits ; pas de règles ni de données nouvelles ; pas de migration des événements existants (un événement sans repas détaillés n'est pas touché) ; aucune dépendance.

**Critères (repris tels quels)** : (1) bouton « Détailler par jour (méthode du club) » ; (2) une carte par jour, et dans chacune, par gymnase, les trois catégories (joueuses et accompagnateurs, bénévoles et famille, spectateurs), midi et soir, avec le total des repas du jour ; (3) une fois détaillé, la carte montre le tableau des jours au lieu de « personnes × durée » ; (4) les quantités de la Prévision et des Courses suivent ; (5) cartes, vocabulaire et palette de l'application (décision 86).

**Preuve** : N1 — `flutter analyze`, `flutter test` (tous les tests existants verts et inchangés : critère de la décision 87). Pas de règles, pas d'émulateur.

### Cadrage V4 — Groupes dans la Prévision (12/11/2026)

**Stratégie** : dans `lib/ecran_prevision.dart`, une zone « Groupes du club » sous le bandeau, **une carte par groupe** (palette et composants du lot A) : nom ; pourcentage de chaque jour (champ par jour, en %, affichage « 70 % » ; stocké en fraction) ; puis ses produits, chacun avec sa part de chaque jour ; sous chaque produit, la quantité prévue de chaque jour (lisible, d'après les repas détaillés de V3 : somme sur les gymnases, non arrondie à l'affichage ou arrondie à l'unité supérieure, comme les totaux existants) ; en bas de carte, pour chaque jour, l'indicateur de parts (`ecartsGroupes` de V1) : « 100 % » en vert ou l'écart en ocre (« 95 % : il manque 5 % »), jamais corrigé en silence. Actions : créer un groupe, le renommer, le supprimer, ranger un produit dans un groupe (un produit dans un seul groupe : le ranger ailleurs le retire de l'ancien ; le choix de produits ne propose que ceux de l'événement ; fait maison exclu comme dans la prévision actuelle). Les groupes s'enregistrent par `definirGroupes` (V2) ; les jours affichés sont ceux de l'événement (`nbJours` entier ; sinon message et pas de groupes, comme V3). Bornes tenues par l'application : pourcentages 0 à 500 %, parts 0 à 100 %, 40 groupes, nom 1 à 40 caractères. « Annuler ce changement » (lot A) couvre aussi les groupes : le document `previsions_annulation/dernier` garde en plus un champ facultatif `groupes` (liste, même format que le document `groupes`) ; `_rangerAnnulation` y range l'état des groupes d'avant ; `annulerChangementPrevision` les remet ; **règles** : le champ `groupes` (liste de 40 éléments au plus) est accepté en plus de `lignes` et `creeLe` dans `previsions_annulation` (tests de règles ajoutés, règles déployées après leurs tests). Un changement de source qui ne touche pas aux groupes (événement passé, classeur de V5 mis à part) les range tels quels ; « Revenir au menu » ne touche pas aux groupes. La quantité prévue par produit et par jour doit sortir d'une fonction pure de `lib/calcul_club.dart` (ajout, V1 à V3 intactes). Sources comme aujourd'hui : l'import du classeur remplira les groupes en V5, pas ici.

**Fichiers touchés** : `lib/ecran_prevision.dart` (et, si l'écran dépasse la taille raisonnable, un nouveau fichier `lib/carte_groupe_club.dart` pour la carte) ; `lib/calcul_club.dart` (ajouts) ; `lib/depot_evenements.dart` (annulation avec groupes, `suivreCalculClub` existant) ; `lib/ecran_evenement.dart` (passer l'écriture des groupes) ; `firestore.rules` (champ `groupes` de `previsions_annulation`) ; `tests_regles/annulation_previsions.test.mjs` (cas ajoutés) ; tests nouveaux : `test/ecran_groupes_club_test.dart`, ajouts dans `test/calcul_club_test.dart`.

**Ce qu'on ne fait pas** : pas de classeur (V5) ; pas de modification de l'ancienne prévision par produit (chiffre par personne et par jour, sources, totaux : inchangés pour un événement sans groupes) ; pas de modification des courses ; pas de dépendance ; aucun test existant modifié.

**Critères (repris tels quels)** : (1) une carte par groupe : nom, % de chaque jour, puis ses produits avec leur part de chaque jour ; (2) les parts d'un groupe affichent « 100 % » en vert ou l'écart en ocre (comme la case « Verif » du club) ; (3) on crée, renomme, supprime un groupe et on y range un produit ; un produit est dans un seul groupe ; (4) sources comme aujourd'hui : classeur, événement passé, à la main ; « Annuler ce changement » (lot A) couvre aussi les groupes ; (5) la quantité prévue de chaque produit, par jour, est lisible sous le produit.

**Preuve** : N1 — `flutter analyze`, `flutter test`, `powershell -File tests_regles/lancer.ps1`.

### 19.4 Prompt de lancement de la session mère — REMPLACÉ par 19.5 le 12/11/2026, gardé pour trace (à coller dans une conversation neuve de Claude Code, sur Sonnet, dans le dossier Le_Comptoir du poste utilisé, une fois le plan validé et le lot A fusionné)

```
Tu es la session mère de la mission « Calcul du club » (version 1.6.0) de Le Comptoir (temps de réalisation : phases 5, 6 et clôture). Tu ne codes pas toi-même : tu cadres, tu confies chaque étape à une sous-session neuve, tu vérifies ses tests et tu tiens le suivi. Le tournoi a lieu ce week-end : la 1.5.0 reste la version du tournoi, et Kinder décidera au vu de ta simulation ce qu'il prend de la 1.6.0.

1. Lis, dans cet ordre : METHODO\3_CHANTIER.md (dossier DEV du poste), PROJET_CONTEXTE.md (bloc STATUT, décisions 46, 56, 75 à 92, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 19 (ce plan : constats, préalables, étapes V1 à V9, critères, arrêts), section 17 (17.2 et 17.4 pour le classeur d'origine et le scénario), section 18 (lot A, pour l'existant), CHANGELOG.md (dernières entrées), graphify-out/GRAPH_REPORT.md.
2. Préalables : le lot A est fusionné dans main (sinon tu t'arrêtes et tu le dis à Kinder) ; la branche de cadrage `claude/cadrage-calcul-club` aussi.
3. Hygiène git : rien de non enregistré (`graphify-out/converted/` et `audit_front/*_test.txt` sont des sorties d'outils : laisse-les) ; main à jour avec le dépôt en ligne ; branche `claude/calcul-club` depuis main. Jamais de travail sur main. Branche envoyée en ligne après chaque étape.
4. Pour chaque étape, dans l'ordre V1 → V2 → V3 → V4 → V5 → V6 → V7 → V8 → V9 :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 19 (« Cadrage Vn »), critères repris tels quels.
   b. Phase 6 : confie l'étape à une sous-session neuve au format MISSION (R14), modèle selon R17 : Sonnet, sauf V1 en « opus ». Dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test. Elle rend un BILAN au format unique (R15, 10 lignes max).
   c. Vérifie la preuve au niveau écrit au plan (N1 : flutter analyze, flutter test, tests_regles/lancer.ps1 ; N2 : le seul parcours Android qui prouve le critère, sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent.
   d. Ligne dans le tableau de suivi de la section 19, ligne dans CHANGELOG.md, commit, branche envoyée. Puis étape suivante, sans attendre Kinder.
5. Le classeur d'origine (`recette/Nouvelle feuille 2.xlsx`) est sur le poste, hors dépôt : tu le lis pour V1 (chiffres du test), V5 (remplir le classeur du club) et V7 (preuve 1). Aucun nom de bénévole n'en sort. S'il manque, demande-le à Kinder.
6. Esprit et design de l'application (décision 86) : cartes, vocabulaire et palette du lot A ; pourcentages pré-remplis par l'import ; rien ne recopie l'allure des feuilles Excel.
7. Après V7 : montre à Kinder le résultat des quatre preuves de la simulation, en une phrase chacune, sans attendre sa réponse pour continuer V8. Si le temps manque avant le tournoi, arrête-toi après V7 et dis-le.
8. Pas de banc d'essai dans cette mission : N3 de la clôture = powershell -File tests_regles/lancer_integration.ps1 ; rouges connus : evenements_test, menus_test, images_test, et les parcours à captures figés (parcours_ergonomie_test, parcours_retours_terrain_test). Une sous-session n'enquête jamais sur un rouge connu.
9. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite ; écart de calcul non expliqué dans la preuve 1 de la simulation.
10. Clôture (V9, R11) : N3, puis vérification par une autre IA dans une conversation neuve sur Sonnet (capture et verdict par critère de fin et par preuve de la simulation, captures dans audit_front/tournoi/simulation/). En cas d'échec, retour en phase 6 sur les seuls critères échoués. Puis documentation et CHANGELOG, branche envoyée, APK de recette 1.6.0. Kinder dit ce qu'il prend pour le week-end. Fusion dans main seulement sur accord écrit de Kinder ; la mission ne passe « Close » qu'après son test final avec capture.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```

### 19.5 Départ anticipé (12/11/2026, décision de Kinder) et prompt de lancement qui remplace 19.4

**Décision de Kinder (12/11/2026, vers 21 h)** : le chantier « Calcul du club » démarre **sans attendre la fin du lot A**, dont la clôture (N3) tourne encore avec des rouges à examiner (`courses_test`, `chantier_complet_test`, `clotures_test`). **Écart à R29 assumé par Kinder** : deux missions actives en même temps sur ce projet, jusqu'à la fusion du lot A.

**Conditions de l'écart** :
1. **Deux dossiers séparés.** Le lot A continue dans `V:\DEV\PROJETS\applications_mobile\Le_Comptoir` (branche `claude/lot-a-tournoi`) ; la 1.6.0 se fait dans `V:\DEV\PROJETS\applications_mobile\Le_Comptoir_calcul_club` (copie de travail du même dépôt, branche `claude/calcul-club`). Aucune session ne touche au dossier de l'autre. Ce second dossier est temporaire : il est retiré à la fusion de la 1.6.0.
2. **Base** : `claude/calcul-club` part de `claude/cadrage-calcul-club`, qui contient le lot A tel qu'il était le 12/11/2026 à 19 h 22 (A1 à A9 faites). Les corrections de la clôture du lot A sont reprises dans `claude/calcul-club` (fusion de `claude/lot-a-tournoi`) **avant V6**, et de nouveau avant V9.
3. **Émulateur LC2 partagé** : la 1.6.0 ne s'en sert pas tant que la clôture du lot A l'occupe (N3, vérification par une autre IA, captures). V1 à V4 ne demandent que N1 ; avant V5 (premier N2), la mère vérifie que le lot A a rendu l'émulateur, sinon elle attend en poursuivant ce qui ne demande que N1.
4. **Fusion** : la 1.6.0 n'est fusionnée dans main qu'après le lot A.
5. **Courses** : V6 et V7 s'appuient sur la page Courses du lot A ; si les rouges de `courses_test` ou de `chantier_complet_test` révèlent un défaut de l'application, la 1.6.0 attend sa correction par le lot A avant V6.

```
Tu es la session mère de la mission « Calcul du club » (version 1.6.0) de Le Comptoir (temps de réalisation : phases 5, 6 et clôture), en DÉPART ANTICIPÉ : la mission « Prêt pour le tournoi » (lot A) est encore en clôture dans un autre dossier, par une autre session. Tu ne codes pas toi-même : tu cadres, tu confies chaque étape à une sous-session neuve, tu vérifies ses tests et tu tiens le suivi. Le tournoi a lieu ce week-end : la 1.5.0 (lot A) reste la version du tournoi, et Kinder décidera au vu de ta simulation ce qu'il prend de la 1.6.0.

0. TON DOSSIER est V:\DEV\PROJETS\applications_mobile\Le_Comptoir_calcul_club (copie de travail séparée du même dépôt). Tu ne lis, n'écris et ne lances RIEN dans V:\DEV\PROJETS\applications_mobile\Le_Comptoir : une autre session y clôt le lot A. Tu ne changes jamais de branche dans ce dossier-là.
1. Lis, dans cet ordre : METHODO\3_CHANTIER.md (dossier DEV du poste), PROJET_CONTEXTE.md (bloc STATUT, décisions 46, 56, 75 à 92, section 12 « Reprendre » pour les commandes et pièges), PLAN_STOCK_COURSES.md section 19 (constats, préalables, étapes V1 à V9, critères, arrêts) et surtout 19.5 (conditions du départ anticipé), section 17 (17.2 et 17.4 pour le classeur d'origine et le scénario), section 18 (lot A, pour l'existant), CHANGELOG.md (dernières entrées), graphify-out/GRAPH_REPORT.md.
2. Hygiène git, dans ton dossier : tu es sur `claude/cadrage-calcul-club` ; crée la branche `claude/calcul-club` à partir d'elle (PAS depuis main, qui n'a pas encore le lot A). Jamais de travail sur main. Branche envoyée en ligne après chaque étape. Les fichiers locaux non versionnés (firebase_options.dart, google-services.json, key.properties, recette/Nouvelle feuille 2.xlsx) sont déjà copiés dans ton dossier : ne les envoie jamais en ligne.
3. Pour chaque étape, dans l'ordre V1 → V2 → V3 → V4 → V5 → V6 → V7 → V8 → V9 :
   a. Phase 5 : cadre l'étape toi-même (stratégie, fichiers touchés, ce qu'on ne fait pas) et écris ce cadrage sous la section 19 (« Cadrage Vn »), critères repris tels quels.
   b. Phase 6 : confie l'étape à une sous-session neuve au format MISSION (R14), modèle selon R17 : Sonnet, sauf V1 en « opus ». Dossier minimal : le cadrage, les critères, les décisions utiles, les commandes de test, et TON DOSSIER comme seul dossier de travail. Elle rend un BILAN au format unique (R15, 10 lignes max).
   c. Vérifie la preuve au niveau écrit au plan (N1 : flutter analyze, flutter test, tests_regles/lancer.ps1 ; N2 : le seul parcours Android qui prouve le critère, sur l'émulateur LC2). Règles d'accès modifiées : déploie-les dès que leurs tests passent ; si le lot A n'est pas encore fusionné, vérifie avant de déployer que tes règles contiennent bien celles du lot A (tu pars de sa branche), pour ne rien retirer de ce qui est en ligne.
   d. Ligne dans le tableau de suivi de la section 19, ligne dans CHANGELOG.md, commit, branche envoyée. Puis étape suivante, sans attendre Kinder.
4. Émulateur LC2 : il est à la session du lot A tant qu'elle est en clôture. Avant le premier N2 (V5), demande à Kinder, en une question, si le lot A a rendu l'émulateur ; en attendant, avance ce qui ne demande que N1.
5. Avant V6, et de nouveau avant V9 : fusionne `claude/lot-a-tournoi` (dernier état en ligne) dans `claude/calcul-club` pour reprendre les corrections de la clôture du lot A ; N1 vert après la fusion. Si la clôture du lot A a révélé un défaut de la page Courses non encore corrigé, attends sa correction avant V6 et dis-le à Kinder.
6. Le classeur d'origine (`recette/Nouvelle feuille 2.xlsx`, hors dépôt) est dans ton dossier : tu le lis pour V1 (chiffres du test), V5 (remplir le classeur du club) et V7 (preuve 1). Aucun nom de bénévole n'en sort. Attention : les parts des produits varient aussi d'un jour à l'autre.
7. Esprit et design de l'application (décision 86) : cartes, vocabulaire et palette du lot A ; pourcentages pré-remplis par l'import ; rien ne recopie l'allure des feuilles Excel.
8. Après V7 : montre à Kinder le résultat des quatre preuves de la simulation, en une phrase chacune, sans attendre sa réponse pour continuer V8. Si le temps manque avant le tournoi, arrête-toi après V7 et dis-le.
9. Pas de banc d'essai dans cette mission : N3 de la clôture = powershell -File tests_regles/lancer_integration.ps1, lancé depuis TON dossier ; rouges connus : evenements_test, menus_test, images_test, et les parcours à captures figés (parcours_ergonomie_test, parcours_retours_terrain_test), plus ceux que la clôture du lot A aura inscrits comme connus. Une sous-session n'enquête jamais sur un rouge connu.
10. Arrêts (et seulement ceux-là) : contradiction avec une décision figée ; dépendance nouvelle nécessaire ; clé, paiement ou conditions ; action irréversible autre que le déploiement des règles ; deux échecs de suite ; écart de calcul non expliqué dans la preuve 1 de la simulation.
11. Clôture (V9, R11) : N3, puis vérification par une autre IA dans une conversation neuve sur Sonnet (capture et verdict par critère de fin et par preuve de la simulation, captures dans audit_front/tournoi/simulation/). En cas d'échec, retour en phase 6 sur les seuls critères échoués. Puis documentation et CHANGELOG, branche envoyée, APK de recette 1.6.0. Kinder dit ce qu'il prend pour le week-end. Fusion dans main seulement APRÈS celle du lot A et sur accord écrit de Kinder ; la mission ne passe « Close » qu'après son test final avec capture.
Parle à Kinder en français, en termes fonctionnels, une seule question à la fois, UNE option avec sa justification.
```
