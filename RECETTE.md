# RECETTE — Le Comptoir (votre test unique)

Tout le reste a été testé automatiquement (voir CHANGELOG.md). Cette fiche ne liste que
ce que je **n'ai pas pu tester moi-même**. Comptez 45 à 60 minutes avec **deux téléphones**
Android (un seul suffit pour les points 1 à 4).

## Avant de commencer (important)
- **Supprimez vos anciennes associations d'essai** (celles créées avant les gymnases) :
  Paramètres → « Supprimer l'association ». Un événement de l'ancien format affiche
  « Événement créé avant la mise à jour : recréez-le » et ne peut plus ouvrir de caisse.
- L'application demande **Android 7 ou plus récent** et pèse 66 Mo (lecture des QR codes).

## Installer
1. Copiez `recette/le-comptoir-recette.apk` sur le téléphone (câble, e-mail ou Drive).
2. Ouvrez-le ; Android demande d'autoriser l'installation depuis cette source : acceptez.
3. L'application s'appelle **Le Comptoir**. Elle est signée avec la clé d'essai de ce
   poste : bonne pour tester, **pas publiable sur le Play Store**.

⚠ Elle travaille sur le **vrai projet Firebase** : ce que vous créez est réel. Utilisez une
association d'essai (par ex. « Essai Club ») ; je la supprimerai ensuite.

## À regarder (cochez ce qui est bon, notez ce qui ne va pas, avec une capture)

**1. Connexion Google (la vraie)**
- [ ] « Créer avec Google » ouvre bien la fenêtre de choix de compte Google, puis l'association est créée.
- [ ] Fermer la fenêtre Google sans choisir ne crée rien et affiche « Connexion Google annulée ».

**2. Photo d'un produit (le vrai choix)**
- [ ] Menus → nouveau menu en cochant « Partir du menu type » : 10 produits avec icônes.
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
- [ ] Créer un événement avec le **menu type (10 produits) et 3 ou 4 gymnases en un seul geste** : il se crée sans erreur (limite d'accès par lot des règles).
- [ ] Faire créer un événement par un **gestionnaire** (pas le responsable), avec 2 gymnases : il se crée sans erreur.

## Ce que vous devez savoir (limites connues)
- **Code d'accès** : seul le responsable peut le changer (décision 1). Un gestionnaire le pourrait-il aussi ? Question restée ouverte.
- **Retirer un membre** n'empêche pas son retour avec l'ancien code : changez aussi le code. Le QR code contient ce code : il est aussi sensible que lui.
- **Suppression de l'association** : définitive, sans corbeille.
- **Gymnases** : 8 au maximum par événement, jamais supprimés ; un gymnase ajouté plus tard démarre avec un stock à zéro.
- **Clôture de l'événement** : réservée au responsable et au gestionnaire rattaché à **tous** les gymnases.
- **Menu type** : les produits et prix sont génériques ; donnez-moi votre menu, je remplace `assets/menu_type.json`.
- Un bénévole sans compte qui **désinstalle** l'application perd son accès : il lui suffit de ressaisir le code (ou de rescanner un QR).
- Les photos sont de petites vignettes (96 px) : voulu, pour rester gratuit (pas de stockage de fichiers).
