# RECETTE — Le Comptoir (votre test unique)

Tout le reste a été testé automatiquement (voir CHANGELOG.md). Cette fiche ne liste que
ce que je **n'ai pas pu tester moi-même**. Comptez 1 h 30 avec **deux téléphones** Android
(un seul suffit pour les points 1 à 4 et 14 à 20).

**Ordre conseillé** : installer → points 1 à 8 (le socle : connexion, caisse, coupure réseau, rôles,
clôtures, bilan) → points 9 à 13 (gymnases, QR, serveur réel) → points 14 à 20 (le chantier Stock et courses,
dans l'ordre : produits et recettes, modèle et logos, stock, rupture, courses, validation, bilan et CSV).

## Avant de commencer (important)
- **Supprimez vos anciennes associations d'essai** (celles créées avant les gymnases) :
  Paramètres → « Supprimer l'association ». Un événement de l'ancien format affiche
  « Événement créé avant la mise à jour : recréez-le » et ne peut plus ouvrir de caisse.
- **Désinstallez d'abord toute version précédente** (APK ou installation Play) : la signature a changé.
- L'application demande **Android 7 ou plus récent** et pèse 70 Mo (lecture des QR codes).

## Installer
1. Copiez `recette/le-comptoir-recette.apk` sur le téléphone (câble, e-mail ou Drive).
2. Ouvrez-le ; Android demande d'autoriser l'installation depuis cette source : acceptez.
3. L'application s'appelle **Le Comptoir** (version 1.1.0, numéro 2). Elle est signée avec la clé de
   publication du projet, comme celle du Play Store.

⚠ Elle travaille sur le **vrai projet Firebase** : ce que vous créez est réel. Utilisez une
association d'essai (par ex. « Essai Club ») ; je la supprimerai ensuite.

## À regarder (cochez ce qui est bon, notez ce qui ne va pas, avec une capture)

**1. Connexion Google (la vraie)**
- [ ] « Créer avec Google » ouvre bien la fenêtre de choix de compte Google, puis l'association est créée.
- [ ] Fermer la fenêtre Google sans choisir ne crée rien et affiche « Connexion Google annulée ».

**2. Photo d'un produit (le vrai choix)**
- [ ] Menus → nouveau menu en cochant « Partir du modèle » : 13 produits avec logos (voir aussi le point 15).
- [ ] Sur un produit : « Ajouter une photo » → galerie **et** appareil photo fonctionnent ; la vignette s'affiche dans la liste puis dans la caisse.

**3. Caisse, au quotidien**
- [ ] Créer un événement (menu + modes de paiement), ouvrir sa caisse : les icônes/photos sont lisibles, un appui ajoute au ticket, le total est juste.
- [ ] « Monnaie à rendre » (calculette) : 20 € reçus pour 6,00 € → 14,00 €.
- [ ] Annuler une vente, en corriger une : la trace « Annulée par … à … » apparaît.
- [ ] Confort : les boutons sont assez gros, lisibles en plein jour, assez rapides à enchaîner.

**4. Vraie coupure du réseau**
- [ ] Mettez le téléphone en **mode avion**, faites 2 ventes : « En attente d'envoi : 2 ».
- [ ] Coupez le mode avion : « Tout est envoyé » apparaît tout seul. Vérifiez sur l'autre téléphone (suivi en direct) que les 2 ventes sont arrivées.
- [ ] **Nouveau** : en mode avion, **ouvrez une caisse** (« Ouvrir ma caisse »), faites 2 ventes, puis remettez le réseau : la caisse ET les 2 ventes arrivent (rien ne se perd).

**5. Deux téléphones, deux rôles**
- [ ] Téléphone B : « Rejoindre » avec le code de l'association + un prénom (sans compte). Il voit les événements en cours, **pas** les menus.
- [ ] Téléphone A (responsable) : Membres → « Nommer gestionnaire » pour B ; la pastille **+1** apparaît sur Paramètres de B ; B active avec Google ; B voit alors les menus (mais, tant qu'il n'est rattaché à aucun gymnase, aucune vente).

**6. Clôtures**
- [ ] B clôture sa caisse : récapitulatif par mode de paiement, « Espèces à remettre ». Elle ne vend plus ; « Rouvrir ma caisse » la rouvre.
- [ ] A clôture l'événement avec une caisse encore ouverte : « Forcer la clôture » ; le bilan l'annonce (« des ventes peuvent manquer »).

**7. Paramètres du responsable** (rouage en haut de l'écran de l'association)
- [ ] Vous voyez le nom, le code d'accès et « Changer le code » ; le nouveau code s'affiche aussi sur l'écran principal.
- [ ] « Retirer de l'association » sur un bénévole : il disparaît de la liste ; sur son téléphone, l'application revient à l'accueil. Il peut revenir avec l'**ancien** code tant que vous n'avez pas changé le code.
- [ ] « Supprimer l'association » (sur l'association d'essai !) : le bouton ne s'active qu'après avoir retapé le nom ; ensuite vous revenez à l'accueil, et sur l'autre téléphone aussi. L'ancien code est refusé.

**8. Bilan**
- [ ] Les chiffres du bilan (total, par produit, par mode, par caisse, par jour, heures de pointe) correspondent à ce que vous avez vendu.

**9. Plusieurs gymnases (nouveau)**
- [ ] Nouvel événement : « Ajouter un gymnase » (par ex. « Gymnase A » et « Gymnase B ») ; deux noms identiques sont refusés.
- [ ] Sur l'événement → « Gymnases et stocks » : changer une quantité, « + » pour réapprovisionner, interrupteur pour suivre ou ne plus suivre un produit, crayon pour renommer, « Ajouter un gymnase » (il suit les mêmes produits que les autres, **à zéro**). Il n'existe pas de suppression de gymnase.
- [ ] Un bénévole voit **un bouton d'ouverture par gymnase**. Il ouvre dans A, vend : le stock baisse **seulement dans A**.
- [ ] Il tente d'ouvrir dans B sans avoir clôturé A : message « Clôturez d'abord votre caisse à A » avec raccourci vers la clôture. Après clôture de A, il ouvre dans B. Retour dans A : « Rouvrir ma caisse ».
- [ ] Le nom du gymnase s'affiche sous « Caisse de … ».

**10. Gestionnaires rattachés à des gymnases (nouveau)**
- [ ] Gymnases et stocks → « Gestionnaires par gymnase » : cochez Gus pour A et Zed pour B (gestionnaires actifs seulement).
- [ ] Gus voit **seulement** les caisses, ventes et stocks de A, avec la mention « Vue limitée à vos gymnases » ; il ne voit pas le gymnase B dans « Gymnases et stocks ».
- [ ] Gus n'a pas le bouton « Clôturer l'événement » (message : seul le responsable, ou un gestionnaire rattaché à tous les gymnases, peut clôturer). Rattaché aux deux gymnases, il peut.
- [ ] Un gestionnaire sans aucun rattachement voit « Aucun gymnase ne vous est rattaché ».
- [ ] **Si un gestionnaire voit « 0 vente » alors qu'il y en a, notez-le avec une capture.**

**11. Vue commune et vue par gymnase (nouveau)**
- [ ] Suivi en direct et bilan : le sélecteur « Commun | Gymnase A | Gymnase B ». Le total commun = total A + total B (ventes, modes, produits). Le stock commun indique le détail « (Gymnase A : … · Gymnase B : …) ».

**12. QR code (nouveau, le vrai scan à la caméra)**
- [ ] Gymnases et stocks → icône QR d'un gymnase : le QR s'affiche, avec le code en texte et « Copier le code ».
- [ ] Sur l'**autre téléphone**, écran d'accueil → « Scanner un QR code » : la caméra s'ouvre, **lit le QR en plein jour** (essayez l'écran du premier téléphone à pleine luminosité), demande le prénom, rejoint l'association et arrive dans l'événement avec « QR code lu : Gymnase B ».
- [ ] Un membre déjà dans l'association : « Scanner un QR code » depuis l'écran de l'association l'amène directement à l'événement.
- [ ] Refusez l'accès à la caméra : le message l'explique (autorisez-la dans les réglages).
- [ ] Changez le code de l'association (Paramètres), puis scannez l'**ancien** QR : « Ce QR code n'est plus valable ». Scannez un QR code quelconque : « QR code illisible ».

**13. Contrôles sur le vrai serveur (nouveau, que je n'ai pu faire qu'en local)**
- [ ] Créer un événement avec le **modèle (13 produits) et 3 ou 4 gymnases en un seul geste** : il se crée sans erreur (limite d'accès par lot des règles).
- [ ] Faire créer un événement par un **gestionnaire** (pas le responsable), avec 2 gymnases : il se crée sans erreur.

**14. Types de produit et recettes (nouveau, chantier Stock et courses, étape 1)**
- [ ] Menus → un menu → « Nouveau produit » : un choix « Type de produit » (composé, à l'unité, à la part, au litre).
- [ ] Type composé : ajouter « Croque-monsieur » avec 3 ingrédients (2 tranches de pain de mie, 1/4 de tranche de jambon, 25 g de gruyère) ; rouvrir le produit : mêmes valeurs.
- [ ] Type au litre : « Café », 8 verres par litre, consommation 2 par personne et par jour ; rouvrir : mêmes valeurs.
- [ ] Un produit déjà existant (ex. « Fruit ») garde son prix, son stock et son image.
- [ ] Saisies refusées avec un message clair : composé sans ingrédient, quantité à zéro, verres par litre à zéro, plus de 20 ingrédients.
- [ ] Créer un événement avec ce menu : dans le détail de l'événement, « Produits » affiche la recette et le ratio. Modifier ensuite la recette dans le menu : l'événement déjà créé ne change pas.

**15. Modèle générique et logos (nouveau, chantier Stock et courses, étape 2)**
- [ ] Menus → « Nouveau menu » : « Partir du modèle » et « Ou copier un menu existant » (liste de vos menus).
- [ ] Partir du modèle : 13 produits avec vos logos (café, thé, croque, barre, fruit, salade, soda, crêpe, flan, tarte) ; bonbons (offerts, 0,00 €), tartiflette et croque chèvre présents.
- [ ] Ouvrir « Croque-monsieur » : recette 2 tranches de pain de mie, 1/3 de tranche de jambon, 7 g de gruyère, consommation 2.
- [ ] Modifier un prix dans le menu copié : le modèle d'origine ne change pas (recréez un menu depuis le modèle : l'ancien prix revient).
- [ ] Copier un menu existant : tous les produits arrivent avec leurs types, recettes, images et stocks.
- [ ] Événement créé avec ce menu : la caisse affiche les logos, aussi en mode avion ; ajouter une photo à un produit remplace son logo.

**16. Stock par rôle (nouveau, chantier Stock et courses, étape 3)**
- [ ] Bénévole, caisse ouverte : le bouton « Parts et produits vides » (icône boîte) de la barre ouvre l'écran « Stock de mon gymnase ».
- [ ] Il propose « Ajouter des parts » seulement pour les produits de type part (tarte, flan, tartiflette, salade) ; ajouter 6 parts : le stock affiché passe de 5 à 11 ; 0 est refusé.
- [ ] Les autres produits (croque, soda…) n'ont pas de bouton d'ajout ; le bénévole ne peut changer ni prix ni autre quantité.
- [ ] Un produit sans quantité (crêpe) : interrupteur « Vide » ; il apparaît « Pas de suivi · Vide » dans « Gymnases et stocks » côté gestion, et le signal se retire des deux côtés.
- [ ] Gestion : « Changer la quantité » et « + » fonctionnent comme avant.
- [ ] Événement clôturé : plus d'ajout de parts ni de signal « vide ».
- [ ] **Hors réseau** : en mode avion, ajouter des parts puis remettre le réseau : le stock est mis à jour sans perte.

**17. Rupture et stock bas (nouveau, chantier Stock et courses, étape 4)**
- [ ] Caisse : un produit dont le stock est à 10 % ou moins du dernier total réglé passe en orange avec « Stock bas : n » ; à zéro il passe en rouge « Épuisé » et la vente reste possible.
- [ ] Un produit sans quantité signalé « vide » passe en rouge « Vide » ; il redevient normal quand on retire le signal.
- [ ] Suivi en direct (gestion) : « Stock bas », « Épuisé » ou « Vide » sous le produit ; en vue commune, avec le nom des gymnases concernés.
- [ ] Les couleurs sont lisibles en plein jour sur le téléphone.
- [ ] Hors réseau : une vente de plusieurs produits puis le retour du réseau — la vente et les baisses de stock arrivent ensemble.

**18. Courses : préparation (nouveau, chantier Stock et courses, étape 5)**
- [ ] Événement → « Courses » (responsable, ou gestionnaire de tous les gymnases ; invisible pour un bénévole).
- [ ] Régler les personnes de chaque gymnase puis « Recalculer » : croque 80 et 60 personnes, 2 jours → 320 et 240.
- [ ] « À acheter » : pain de mie, jambon, gruyère (en kg à partir de 1 000 g), café en litres ; modifier une quantité ou cocher un autre produit recalcule tout.
- [ ] « Il reste » réduit l'achat ; une ligne libre (« Liquide vaisselle × 2 ») se garde et se retire.
- [ ] « Suggéré : stock bas » apparaît sur un produit dont le stock est bas à ce gymnase.
- [ ] Quitter puis rouvrir : tout est retrouvé. Les chiffres sont plausibles par rapport à la liste de courses de l'an dernier (à corriger dans les consommations du menu si besoin).
- [ ] Hors réseau : modifier la liste, remettre le réseau : « Enregistré ».

**19. Courses : validation (nouveau, chantier Stock et courses, étape 6)**
- [ ] Écran Courses → « Valider les courses » : les quantités achetées sont pré-remplies avec « À acheter » ; en baisser une (par exemple le gruyère à moitié) change le résultat annoncé et nomme l'ingrédient limitant.
- [ ] Le coût total est obligatoire ; « Confirmer » ajoute au stock de chaque gymnase (vérifier dans « Gymnases et stocks »).
- [ ] Un produit qui n'avait pas de suivi (le café, le croque du modèle) se met à suivre son stock après la validation.
- [ ] La liste validée affiche « Courses validées le … », le coût et les ajouts, et ne se modifie plus ; le bouton de validation a disparu.
- [ ] Sans réseau, la validation affiche un message et n'ajoute rien.
- [ ] Les quantités annoncées sont plausibles par rapport à ce que vous avez réellement acheté.

**20. Bilan : coût des courses et export CSV (nouveau, chantier Stock et courses, étape 7)**
- [ ] Bilan, vue commune, courses validées : « Coût des courses » (celui saisi) et « Résultat » (ventes moins coût) ; courses non validées : « Courses non validées ».
- [ ] Vue d'un gymnase : pas de coût, la mention « voir la vue commune ».
- [ ] Un gestionnaire rattaché à un seul gymnase ne voit aucun coût.
- [ ] « Exporter (CSV) » ouvre la feuille de partage d'Android ; envoyer le fichier vers Drive ou un e-mail, puis l'ouvrir dans Excel ou Google Sheets : accents lisibles, montants en colonnes (6,00), sections claires.
- [ ] Les chiffres du fichier sont ceux de l'écran (total, produits, modes, jours, caisses).
- [ ] Même export depuis la vue d'un gymnase : seulement ses chiffres.

**21. Après le test, la consommation réelle (nouveau)**
- [ ] Console Firebase → Firestore → onglet Utilisation : noter les lectures et écritures du jour de votre test, pour les comparer à la projection de la section 10 de `PLAN_STOCK_COURSES.md` (quota gratuit : 50 000 lectures et 20 000 écritures par jour).

## Ce que vous devez savoir (limites connues)
- **Code d'accès** : seul le responsable peut le changer (décision 1). Un gestionnaire le pourrait-il aussi ? Question restée ouverte.
- **Retirer un membre** n'empêche pas son retour avec l'ancien code : changez aussi le code. Le QR code contient ce code : il est aussi sensible que lui.
- **Suppression de l'association** : définitive, sans corbeille.
- **Gymnases** : 8 au maximum par événement, jamais supprimés ; un gymnase ajouté plus tard démarre avec un stock à zéro.
- **Clôture de l'événement** : réservée au responsable et au gestionnaire rattaché à **tous** les gymnases.
- **Modèle de menu** : les prix sont des valeurs de départ (vos prix réels ne m'ont pas été donnés) ; les recettes et consommations sont des estimations tirées de la liste de courses de l'an dernier. Donnez-moi vos prix, je remplace `assets/menu_type.json`.
- Un bénévole sans compte qui **désinstalle** l'application perd son accès : il lui suffit de ressaisir le code (ou de rescanner un QR).
- Les photos sont de petites vignettes (96 px) : voulu, pour rester gratuit (pas de stockage de fichiers).
