# CHANGELOG — Le Comptoir

## 05/10/2026 — Images des produits d'un événement, et bilan lisible
- Constat : une image changée dans un menu n'apparaissait ni en caisse ni dans l'événement. C'est la
  décision 13 (l'événement copie le produit à sa création) : un événement créé avant le changement garde
  l'ancienne image. Ce n'est pas un bogue de copie ; il manquait un moyen de corriger l'image après coup.
- Nouveau : dans le détail d'un événement EN COURS, la gestion touche un produit pour changer son image
  (icône modèle, photo, ou rien). Nom, prix et stock restent figés. La caisse et le bilan reprennent
  l'image aussitôt (flux en direct). Règles d'accès : mise à jour d'un produit d'événement autorisée à la
  gestion, uniquement pour `icone` / `photo`, événement en cours, mêmes limites que pour un menu.
- Code : le choix d'image du formulaire produit devient `SelecteurImage` (ecran_menu.dart), réutilisé par
  `demanderImageProduit` ; `DepotEvenements.modifierImageProduit`. Aucun module ni dépendance ajouté.
- Bilan : mise en page refaite (même contenu, mêmes chiffres, mêmes clés). Total en bandeau sombre ;
  cartes par section avec barres de proportion (modes de paiement, produits, heures de pointe) ;
  produits avec leur image, quantité, stock et montant alignés ; classements numérotés ; caisses avec
  pastille Clôturée / Ouverte ; ventes annulées barrées avec leur trace ; messages d'état (provisoire,
  définitif, clôture forcée, caisses ouvertes) dans des bandeaux de la couleur de leur sens.
- Tests : les lignes du bilan sont maintenant plusieurs textes ; les tests lisent le contenu d'un bloc
  (textes joints par « | »). Tests de logique/écrans : tous verts SAUF ecran_caisse_test.dart, qui
  ne se charge pas sur ce poste car `lib/firebase_options.dart` (ignoré par git) y manque.
  Tests de règles (images.test.mjs, 2 nouveaux) et parcours Android : mis à jour mais NON lancés
  (pas d'outil Firebase ni d'émulateur sur ce poste).

## 04/10/2026 — Front, mission a1 (thème et composants)
- Nouveau module `lib/theme.dart` (23 modules sur 24) : palette de la charte (décision 31), thème de toute
  l'application (anthracite, fond de lin, barres de titre, boutons arrondis à 14, cartes à 16, champs à
  contour, boîtes de dialogue, sélecteur de vue, messages), et `TypeAction` : une couleur par sens
  (gérer = prune, analyser = framboise, réussir = sauge, attention = ocre, danger = brique en contour).
- Appliqué aux écrans existants SANS changer leur disposition : « Menus », « Changer le code »,
  « Gymnases et stocks », « Nouveau menu » / « Produit » en prune ; « Voir le bilan » et le sélecteur
  Commun / Gymnase en framboise ; « Clôturer ma caisse » et l'état « En cours » en sauge ; « Corriger » en
  ocre ; « Annuler », « Retirer », « Supprimer », « Forcer la clôture » en brique (contour, sauf dans les
  boîtes de confirmation). « Clôturer l'événement » (toutes caisses clôturées) en sauge.
- Petits ajustements de mise en page pour que les champs à contour ne se touchent pas (accueil, gymnases du
  formulaire d'événement, produit) et sous-titre de la caisse lisible dans la barre sombre.
- Aucun fonctionnement, donnée ou règle modifié ; aucune dépendance ajoutée ; Key conservées.
- Tests : analyse sans erreur, 137 tests de logique et d'écrans, 130 tests de règles, 19 parcours Android
  verts. Test d'événements : l'aide de parcours attend maintenant que le formulaire se mette en page
  (le bouton « Créer l'événement » descend un peu plus bas), sans affaiblir de vérification.
- Captures : audit_front/a1 (61 écrans) ; planche avant / après : audit_front/proposition/a1_avant_apres.html.
- Reste de l'étape (a2) : icône et écran de démarrage, après réception du logo.


## 04/10/2026 — Front : identité visuelle figée (palette)
- Audit et mission de cohérence faits (voir plus bas). Palette « Anthracite & pigments » validée par
  Kinder après six directions écartées (braise, lagon, marine et jaune, sapin et parquet, denim) et un
  comparatif de six dominantes (choix : anthracite). Décision 31 de PROJET_CONTEXTE.md.
- Livrables de la proposition (hors application) : audit_front/proposition/ (page de maquettes
  avant/après, comparatif des six dominantes, brouillon de logo, brief pour une autre IA).
- Couleur « analyser » : le pétrole (bleu-vert) est remplacé par la framboise cassée #A04467 (choix de Kinder après comparaison avec cacao et taupe).
- Aucun code de l'application modifié par cette étape. Prochaine : mission « fondation » (thème et
  composants) après accord de Kinder ; icône et démarrage après réception du logo.


## 04/10/2026 — Front, mission 0 (cohérence avant l'identité visuelle)
- Audit visuel fait (61 captures « avant » : audit_front/avant) ; cette mission corrige les incohérences
  d'USAGE, sans toucher au fonctionnement, aux données ni aux règles d'accès. Couleurs, typographie,
  icônes et logo restent pour la proposition d'identité visuelle.
- Pluriels corrects partout : « 1 vente », « 4 ventes », « 1 vendu », « 2 caisses non clôturées »
  (fini les « vente(s) »). Aide `pluriel` / `accord` dans ticket.dart. Les textes qui changent :
  bilan, suivi en direct, statut des caisses, clôture de caisse, messages de clôture forcée.
- Caisse : les boutons d'encaissement (Espèces, Carte, Chèque) deviennent l'action principale (pleins,
  plus hauts, texte plus gros) ; « Remise à zéro » devient un bouton secondaire (contour) ; la bande
  « Mes ventes » prend toute la largeur ; « Annuler » / « Corriger » ont une zone d'appui de 48 px.
- Événement : « Gymnases et stocks » et « Voir le bilan » passent AVANT le suivi en direct (long) ;
  « Forcer la clôture » est en rouge (danger) ; « Clôturer l'événement » (toutes caisses clôturées)
  reste normal.
- Accueil : le message d'erreur s'affiche en haut de l'écran (celui du bas passait inaperçu).
- Paramètres : « Retirer de l'association » en rouge, zone d'appui de 48 px.
- Tests : textes adaptés dans 10 fichiers de test (pluriels), une expression du parcours de recette,
  et deux aides de parcours Android (recette, vues) qui attendent maintenant que l'écran se stabilise
  avant d'appuyer (le bouton « Voir le bilan » est plus haut : le contenu au-dessus bougeait pendant
  le chargement). Aucun test affaibli.
- Résultats : analyse sans erreur, 137 tests de logique et d'écrans, 130 tests de règles, 19 parcours
  Android verts. Captures « après » : audit_front/apres (hors réseau et gymnase unique ajoutés).
- Outils d'audit conservés : audit_front/ (parcours de capture, pilote, scripts). Défaut de MES données
  de démonstration, pas de l'application : accent de « Zoé » abîmé dans les ventes envoyées par HTTP.


## 04/10/2026 — Gymnases, mission M6 (recette multi-gymnases et finitions) — CHANTIER TERMINÉ
- Le parcours de recette automatique passe à deux gymnases : événement créé avec « Gymnase A » et
  « Gymnase B » par le formulaire ; Gus gestionnaire de A, Zed gestionnaire de B (nommé et activé
  avec Google) ; Léa vend dans A ; Zoé arrive par le QR code du gymnase B (faux lecteur), ouvre PAR
  ERREUR une caisse dans A, la clôture sans vente, puis ouvre dans B (changement de gymnase) ; Gus
  ne voit que A, Zed que B et annule la vente de Zoé sous son nom ; le responsable force la
  clôture. Bilans écrits à la main : COMMUN 23,50 € en 7 ventes (24 chiffres inchangés), A 16,00 € en
  4 ventes, B 7,50 € en 3 ventes ; A + B = commun vérifié (ventes, modes, produits, jours) ; les
  trois vues passent sur l'écran.
- Fiche de test unique (RECETTE.md) mise à jour : avant de commencer (supprimer les associations
  d'essai de l'ancien format), gymnases, gestionnaires rattachés, vues commune/distincte, QR code et
  vrai scan à la caméra, contrôles sur le vrai serveur (événement à nombreux gymnases et produits en
  un lot, ouverture de caisse sans réseau puis ventes).
- Revue des limites : 22 modules sur 24, 4 fichiers de documentation sur 5, uniquement les
  dépendances accordées (qr_flutter et mobile_scanner en plus), aucune structure vide, aucun
  « à faire plus tard ».
- Tests finaux : analyse sans erreur, 137 tests de logique et d'écrans, 130 tests de règles,
  19 parcours Android (batterie complète verte), règles déployées (dernière mise en ligne en M3,
  inchangées depuis), application de recette refaite (66,5 Mo, signature = celle enregistrée pour
  Google, lancée sur émulateur).
- Reste pour Kinder (jamais testé ici) : vrai scan à la caméra, vraie connexion Google, vrai
  choix de photo, vraie coupure de réseau, installation sur un vrai téléphone, contrôles de la
  section 13 de RECETTE.md sur le vrai serveur. Supprimer d'abord les associations d'essai de
  l'ancien format.

## 04/10/2026 — Gymnases, mission M5 (QR code et partage)
- Chaque gymnase a un QR code (responsable et gestionnaires rattachés, depuis « Gymnases et
  stocks » > « Partager ») : il contient le code d'accès de l'association, l'événement et le
  gymnase (`lecomptoir://rejoindre?v=1&c=…&e=…&g=…`), avec le code en texte et « Copier le
  code ». Si le responsable change le code, l'écran se met à jour et les anciens QR cessent de
  fonctionner (avertissement affiché).
- Bouton « Scanner un QR code » sur l'écran d'accueil et sur l'écran de l'association. Non-membre :
  prénom demandé, il rejoint l'association, l'événement s'ouvre avec le gymnase proposé en premier
  (« QR code lu : … ») ; membre : direct. Messages clairs : QR illisible, code périmé, autre
  association, événement clôturé ou inexistant, gymnase inconnu ; caméra refusée ou absente.
  Une caisse déjà ouverte ailleurs bloque l'ouverture (message de M2).
- Dépendances ajoutées sur accord (M5) : qr_flutter (dessiner) et mobile_scanner (lire). Android :
  autorisation de la caméra ; version minimale d'Android 7 (API 24). L'application de recette passe
  de 50 Mo à 66 Mo. 22 modules sur 24 (ecran_qr.dart).
- Le lecteur de QR est injectable : tests Android avec un faux lecteur. NON TESTÉ ICI : le vrai scan
  à la caméra d'un téléphone (à la recette).
- Tests : analyse sans erreur, 137 tests de logique et d'écrans (dont QR : aller-retour, contenus
  invalides, caractères spéciaux, QR affiché = lien attendu, copie du code, suivi d'un changement de
  code), 130 tests de règles (inchangées), 19 parcours Android dont le nouveau.
- CAUSE TROUVÉE de l'échec intermittent du parcours des gestionnaires (observé en M3 et M4) : un
  défaut de MES TESTS. Ils ouvraient une caisse et enregistraient une vente aussitôt ; l'émulateur
  peut évaluer la vente avant la caisse et la refuser. Reproduit : 5 ventes perdues sur 25 sans
  attente, 0 sur 25 avec attente. 4 parcours corrigés (attente de l'envoi de la caisse). À vérifier
  à la recette sur le vrai serveur : ouvrir la caisse SANS réseau, vendre, remettre le réseau
  (les deux écritures partent ensemble) ; l'ordre y est normalement garanti.

## 04/10/2026 — Gymnases, mission M4 (vue distincte / vue commune)
- Un sélecteur « Commun | Gymnase A | Gymnase B… » dans le suivi en direct et dans le bilan
  (seulement s'il y a un choix à faire). Vue commune = tous les gymnases additionnés, avec le
  stock total et son détail par gymnase ; vue distincte = un seul gymnase (ventes, caisses,
  stock, produits, modes, jours, heures de pointe, annulations). Chaque caisse indique son
  gymnase. Un gestionnaire ne voit que ses gymnases ; « Commun » seulement s'il est rattaché à
  tous (sinon son premier gymnase par défaut). Un seul gymnase : rien ne change.
- Preuve par le calcul à la main : deux gymnases aux stocks différents, bilans A (10,50 €,
  2 ventes), B (11,50 €, 3 ventes) et commun (22,00 €, 5 ventes) écrits à la main ; A + B =
  commun vérifié ; mêmes chiffres dans le calcul, l'écran et sur Android avec de vraies ventes
  datées posées sur le serveur local.
- DÉFAUTS RÉELS TROUVÉS ET CORRIGÉS PAR LES TESTS : (1) le bilan réutilisait les flux du suivi,
  or un flux déjà ouvert n'envoie plus son état à un second écran : le bilan restait vide,
  il a maintenant ses propres flux ; (2) quand une caisse disparaissait d'une vue, les éléments
  voisins de la colonne se réabonnaient (flux relus pour rien) : les cartes de caisses forment
  désormais un seul élément.
- Aucune règle d'accès nouvelle. Tests : analyse sans erreur, 128 tests de logique et d'écrans,
  130 tests de règles, 18 parcours Android (batterie complète verte deux fois de suite).
  Constat honnête : le parcours des gestionnaires (M3) a échoué dans 3 batteries complètes sur 6
  (« 0 vente » affiché pendant 30 s), jamais seul ; non expliqué malgré un diagnostic, les deux
  dernières batteries sont vertes. À surveiller à la recette. Application de recette refaite
  (signature vérifiée). 21 modules sur 24.

## 03/10/2026 — Gymnases, mission M3 (gestionnaires rattachés)
- Le responsable rattache chaque gestionnaire actif à un ou plusieurs gymnases (cases à
  cocher dans « Gymnases et stocks »). Un gestionnaire ne voit, n'annule et ne règle que
  ses gymnases : suivi en direct et bilan limités (mention « Vue limitée à vos gymnases »),
  écran des gymnases réduit aux siens. Sans rattachement : aucune vente visible. Retrait du
  statut de gestionnaire : le rattachement ne donne plus aucun droit.
- Clôture de l'événement : réservée au responsable ou à un gestionnaire rattaché à TOUS les
  gymnases (précision de la confirmation 4 : sinon il clôturerait sans voir les autres caisses).
- Modèle : rattachement stocké par gestionnaire (`evenements/{e}/rattachements/{uid}`), pas dans
  une liste sur chaque gymnase (nécessaire pour vérifier « rattaché à tous » dans les règles) ;
  compteur `nbGymnases` sur l'événement (monte de 1 avec chaque gymnase ajouté, dans le même
  lot) ; 8 gymnases au maximum par événement.
- Tir d'essai validé : la requête « caisses du gymnase g » (where gymnaseId == g) est acceptée
  pour le gestionnaire de g et refusée pour un autre gymnase ou sans filtre. Un gestionnaire
  qui crée un événement à 3 gymnases et 10 produits en un seul lot passe (limite d'accès par
  lot respectée dans l'émulateur).
- La suppression de l'association efface aussi les rattachements.
- Tests : analyse sans erreur, 108 tests de logique et d'écrans, 130 tests de règles (matrice
  de droits complète), 17 parcours Android dont le nouveau (deux gestionnaires, un par
  gymnase, lectures hors périmètre refusées par le serveur, clôture réservée, retrait).
  Constat honnête : deux batteries complètes lancées pendant que la machine était lente ont
  fait échouer chacune un parcours (délai de 30 s dépassé, ventes pas encore arrivées) ; les
  mêmes parcours passent seuls et la batterie complète suivante est entièrement verte.
- Règles déployées, application de recette refaite. 21 modules sur 24.

## 03/10/2026 — Gymnases, mission M2 (gymnases d'un événement, choix à l'ouverture)
- Formulaire de création : liste de gymnases (au moins un, noms de 1 à 40 caractères,
  tous différents), chacun part du stock du menu. Nouvel écran « Gymnases et stocks »
  (gestion, événement en cours) : ajouter et renommer un gymnase (jamais supprimer),
  changer une quantité, réapprovisionner (+n), suivre ou ne plus suivre un produit dans un
  gymnase. Un gymnase ajouté plus tard suit les mêmes produits que les autres, à zéro.
- Ouverture de caisse : un bouton par gymnase (un seul s'il n'y a qu'un gymnase),
  « Ma caisse : A (ouverte) » ; si une caisse est ouverte ailleurs : « Clôturez d'abord votre
  caisse à A » avec raccourci vers la clôture ; retour dans un gymnase déjà utilisé :
  « Rouvrir ma caisse ». Le nom du gymnase s'affiche sous le titre de la caisse.
- Règle ajoutée : la gestion peut arrêter le suivi d'un produit dans un gymnase (suppression
  du stock) tant que l'événement est en cours (test de règles ajouté).
- Tests : analyse sans erreur, 103 tests de logique et d'écrans, 116 tests de règles,
  nouveau parcours Android (2 gymnases aux stocks différents, stock réglé/réapprovisionné,
  gymnase ajouté et renommé, changement de gymnase refusé puis accepté après clôture,
  retour dans le premier gymnase, second bénévole dans un autre gymnase en parallèle).
  Modules : 21 sur 24.

## 03/10/2026 — Gymnases, mission M1 (socle invisible)
- Nouveau modèle de données, sans changement visible : chaque événement a un gymnase
  « Principal » qui porte le stock (le stock du menu en est la valeur de départ) ; la caisse
  est « membre + gymnase » ; un pointeur interdit deux caisses ouvertes sur un même
  événement ; les ventes portent leur gymnase. Règles d'accès réécrites et déployées.
  Un événement de l'ancien format affiche « recréez-le » au lieu de planter.
- DÉFAUT RÉEL TROUVÉ ET CORRIGÉ PAR LES TESTS : la suppression d'une association
  s'arrêtait avant la fin (le responsable ne pouvait pas relire la liste des pointeurs de
  caisse) ; règle corrigée et test de règles ajouté.
- Tests : analyse sans erreur, 98 tests de logique et d'écrans, 114 tests de règles,
  15 parcours Android (batterie complète passée d'un seul tenant). Application de recette
  refaite (signature = celle enregistrée pour Google, lancée sur émulateur).
- Limite de modules : 20 sur 24 (ajout de gymnase.dart). Aucune dépendance ajoutée.
- Reste pour clore M1 : essai sur le vrai projet Firebase (voir PLAN_GYMNASES.md).

## 03/10/2026 — Chantier « plusieurs gymnases »
- Cadrage validé par Kinder : même menu, stock distinct par gymnase, plusieurs
  gymnases par événement, caisse rattachée à un gymnase, bilan distinct/commun,
  gestionnaires rattachés, QR code.
- Plan écrit : PLAN_GYMNASES.md (missions M1 à M6) ; décisions 25 à 30 dans
  PROJET_CONTEXTE. Aucun code écrit : exécution dans une nouvelle conversation.

## 01/10/2026
- Cadrage terminé (phases 1 à 3).
- Décisions figées : voir PROJET_CONTEXTE, section 6.
- Points ouverts : socle à confirmer (vérification de Nickel), menu type
  à fournir.
- Socle vérifié sur Nickel : Flutter + Firebase (connexion anonyme,
  maison rejointe par code d'invitation). Décision n°11 ajoutée ; point
  ouvert « socle » retiré.
- Phase 4 terminée : plan en 14 étapes validé par Kinder (voir
  PROJET_CONTEXTE, section 8). Validation par tests automatiques à
  chaque étape, test manuel unique à la fin.
- Étape 1 (caisse minimale, 9 produits génériques) terminée : analyse du
  code sans erreur, 10 tests automatiques réussis. Aucune dépendance
  ajoutée.
- Pause services terminée : projet Firebase créé, base Firestore
  (europe-west3), connexions anonyme et Google activées, application
  Android déclarée avec son empreinte de signature.
- Étape 2 (fondation Firebase) terminée : connexion anonyme vérifiée sur
  émulateur Android (1 utilisateur créé dans le projet), règles
  déployées (accès réservé aux utilisateurs connectés), 4 tests de
  règles + 10 tests de caisse réussis, analyse du code sans erreur.
  Trois dépendances ajoutées (firebase_core, firebase_auth,
  cloud_firestore). Émulateur Android dédié créé pour les tests.
- Étape 3 (association et code) terminée : création, rejoindre par code
  et prénom, régénération du code (l'ancien est refusé), règles d'accès
  déployées. 15 tests de logique, 14 tests de règles et 1 parcours complet
  sur émulateur Android réussis. Défaut trouvé et corrigé : l'écran de
  l'association s'ouvrait avant la confirmation du serveur.
  Dépendance de test ajoutée : integration_test (fournie par Flutter).
- Étape 4 (connexion Google et rôles) terminée : le responsable crée son
  association avec Google (compte rattaché à l'appareil sans perte), un
  nouveau téléphone retrouve son association par Google, fenêtre Google
  fermée = rien n'est créé. Règles : création, changement de code et
  suppression réservés au responsable ; personne ne peut s'attribuer un
  rôle. 15 tests de logique, 20 tests de règles et 3 parcours sur
  émulateur Android réussis, règles déployées. Dépendance ajoutée :
  google_sign_in. Non testé ici : la vraie fenêtre Google (compte réel),
  prévue à la recette finale.
- Point à trancher : le gestionnaire peut-il aussi changer le code ? La
  décision 1 dit « par le responsable », la section 3 dit « mêmes droits
  sauf gestion des gestionnaires ». Appliqué pour l'instant : responsable
  seul.
- Étape 5 (menus) terminée : menus et produits (nom, prix, stock
  facultatif) réservés au responsable et aux gestionnaires ; le bénévole
  n'y a pas accès. 18 tests de logique (dont la saisie des prix), 25 tests
  de règles (droits par rôle, données invalides refusées) et 4 parcours
  sur émulateur Android réussis (créer, remplir, modifier, retrouver après
  réouverture, supprimer ; prix invalide refusé). Règles déployées.
  Les images des produits restent prévues à l'étape 13.
- Étape 6 (événements) terminée : un événement a un nom, une date, un
  menu dont les produits sont copiés, et des modes de paiement parmi une
  liste fixe. Nom, date et modes modifiables tant qu'il est en cours. Le
  bénévole ne voit que les événements en cours. Décisions 12 et 13 ajoutées.
  22 tests de logique, 33 tests de règles et 5 parcours sur émulateur
  Android réussis, règles déployées. Aucune dépendance ajoutée.
- Attention : 17 modules de code sur 20 autorisés. Les étapes 7 à 12 devront
  regrouper des fichiers existants plutôt que d'en ajouter autant.
- Étape 7 (caisse réelle) terminée : le membre ouvre sa caisse sur un
  événement en cours (une caisse par membre), vend avec les produits de
  l'événement, seuls les modes de paiement autorisés sont proposés,
  monnaie à rendre facultative (calculette, rien d'enregistré), stock
  épuisé = avertissement sans blocage. Ventes enregistrées sans attendre le
  réseau, envoyées au retour du réseau (compteur « en attente d'envoi »).
  Décisions 14 et 15 ajoutées. Défaut trouvé et corrigé : l'avertissement
  de stock recouvrait les boutons de paiement (désormais message fixe).
  30 tests de logique et d'écrans, 45 tests de règles et 6 parcours sur
  émulateur Android réussis, dont une coupure du réseau SIMULÉE dans
  l'application (ventes hors réseau puis envoi, stock cumulé exact) et la
  reprise de caisse après réouverture. Règles déployées. Non testé ici :
  une vraie coupure du réseau du téléphone (recette finale).
- Étape 8 (annulations et corrections tracées) terminée : liste « Mes
  ventes », annulation de n'importe quelle vente de sa caisse avec trace
  (qui, quand), la vente reste affichée barrée et sort des totaux, les
  articles reviennent en stock, correction = annulation + ressaisie avec
  lien entre l'ancienne et la nouvelle vente, annulation possible sans
  réseau. La gestion peut annuler une vente d'une autre caisse (règles et
  couche données testées ; son écran arrive à l'étape 11). Décision 16
  ajoutée. 35 tests de logique et d'écrans, 56 tests de règles, 7 parcours
  sur émulateur Android réussis (2 passes consécutives). Défauts de tests
  corrigés : transitions d'écran trop rapides, changement d'appareil avant
  confirmation du serveur. Règles déployées.
- Étape 9 (clôtures) terminée : le bénévole clôture sa caisse (récapitulatif
  par mode de paiement, espèces à remettre, ventes annulées) ; la clôture
  attend l'envoi final de toutes ses ventes puis enregistre le
  récapitulatif ; il peut rouvrir sa caisse (réouverture tracée, récapitulatif
  effacé) ; une caisse clôturée ne vend plus. Un gestionnaire identifié
  clôture l'événement : normale si toutes les caisses sont clôturées, sinon
  forcée (auteur, heure et nombre de caisses non clôturées conservés pour le
  bilan) ; l'événement clôturé est figé et invisible des bénévoles.
  Décisions 17 et 18 ajoutées. 41 tests de logique et d'écrans, 71 tests
  de règles, 9 parcours sur émulateur Android réussis. Règles déployées.
  Limite : le scénario hors réseau est dans son propre fichier de test, car
  après une coupure simulée l'émulateur local renvoie des erreurs internes
  sur les documents concernés (la même écriture passe sans coupure) ; à
  revérifier sur le vrai serveur à la recette finale.
- Étape 10 (membres et gestionnaires) terminée : la liste des membres
  affiche bénévole / gestionnaire en attente / gestionnaire / responsable ;
  le responsable nomme (en attente) ou retire ; la pastille « +1 » apparaît
  sur Paramètres du membre nommé ; il active lui-même avec Google et obtient
  alors les droits de gestion ; en attente il n'a que ceux d'un bénévole ;
  seul le responsable nomme et retire. Décision 19 ajoutée. 44 tests de
  logique et d'écrans, 81 tests de règles, 10 parcours sur émulateur Android
  réussis. Règles déployées. Limite : si le compte Google choisi à
  l'activation est déjà relié à une autre identité, l'activation est refusée
  avec un message (à ne pas confondre avec une panne).
- Étape 11 (suivi en direct) terminée : sur le détail d'un événement, la
  gestion voit en temps réel le total et le nombre de ventes, les quantités
  vendues et le stock restant par produit, et pour chaque caisse son état,
  ses ventes, son total, sa dernière vente ; une caisse ouverte sans
  activité depuis 60 minutes (pas moins) est signalée « silencieuse ».
  La gestion ouvre une caisse et annule une vente sous son nom (écran
  manquant de l'étape 8) ; pas de « corriger » pour elle. Décision 20
  ajoutée. Aucune règle d'accès nouvelle (les droits de lecture de la
  gestion existaient) mais 3 tests de règles ajoutés sur la lecture des
  listes. 57 tests de logique et d'écrans, 84 tests de règles, 11 parcours
  sur émulateur Android réussis.
- Étape 12 (bilan) terminée : depuis l'événement, la gestion ouvre le bilan
  (provisoire en cours, définitif une fois clôturé) : total et nombre de
  ventes, détail par produit (quantité, montant, stock), produits les plus et
  les moins vendus, par mode de paiement, par caisse, par jour, heures de
  pointe par tranche d'une heure (3 plus chargées), ventes annulées listées
  avec leur trace ; calcul sur les ventes non annulées ; clôture forcée
  annoncée (auteur, heure, caisses non clôturées, « des ventes peuvent
  manquer »). Vérifié sur un jeu de ventes dont le résultat a été calculé à
  la main (mêmes chiffres dans le calcul, l'écran et sur Android avec de
  vraies données datées). Décision 21 ajoutée. Aucune règle nouvelle. 76 tests
  de logique et d'écrans, 84 tests de règles, 12 parcours sur émulateur
  Android réussis. 19 modules sur 20.
- Étape 13 (images et menu type) terminée : 14 icônes modèles intégrées
  (liste fixe, identique dans l'application et dans les règles, vérifié par un
  test) ; photo facultative choisie dans la galerie ou prise avec l'appareil,
  réduite à 96 px par le système et stockée avec le produit (30 Ko max, pas
  de service de fichiers ni d'images extérieur) ; l'événement copie les
  images avec les produits, la caisse les affiche même sans réseau ; seule la
  gestion modifie les images ; photo trop lourde refusée avec un message. Menu
  type proposé à la création d'un menu, lu dans assets/menu_type.json (10
  produits génériques avec icônes, remplaçable sans toucher au code).
  Décision 22 ajoutée. Dépendance ajoutée sur accord : image_picker. 89 tests
  de logique et d'écrans, 91 tests de règles, 13 parcours sur émulateur
  Android réussis. Règles déployées. Non testé ici : le vrai choix de photo
  (galerie, appareil photo) sur un téléphone, remplacé par un faux sélecteur ;
  à la recette finale. 19 modules sur 20.
- Étape 14 (recette finale) terminée côté automatique : parcours de recette
  d'un week-end complet (responsable, gestionnaire activé avec Google, deux
  bénévoles, deux jours, menu type, annulation, correction, clôture,
  réouverture, clôture forcée, bilan, coupure de réseau). Les 24 chiffres du
  bilan correspondent au calcul fait à la main. DÉFAUT RÉEL TROUVÉ ET CORRIGÉ :
  sur l'écran d'un événement, faire défiler la page faisait sortir puis revenir
  le suivi en direct, qui plantait en se rebranchant sur un flux déjà utilisé
  (le flux est maintenant réécoutable ; test de non-régression ajouté).
  Nom de l'application sur le téléphone : « Le Comptoir ». En-tête des règles
  remis au propre. Application de recette : recette/le-comptoir-recette.apk
  (49,8 Mo, signature de débogage vérifiée = celle enregistrée pour Google, lancée
  sur émulateur contre le vrai projet). Fiche de test unique : RECETTE.md.
  90 tests de logique et d'écrans, 91 tests de règles, 14 parcours sur émulateur
  Android réussis ; règles déployées. Revue des limites : 19 modules sur 20,
  3 fichiers .md sur 5, aucune structure vide, dépendances accordées seulement.
  Reste pour Kinder : vraie connexion Google, vrai choix de photo, vraie coupure
  de réseau, installation sur un vrai téléphone (voir RECETTE.md).
- Étape 15 (écran Paramètres : code, retrait de membre, suppression de
  l'association) terminée. Paramètres du responsable : nom, code d'accès avec
  « Changer le code » (déplacé depuis l'écran principal), liste des membres
  avec « Retirer de l'association », « Supprimer l'association » (le nom doit
  être retapé ; tout est effacé : menus, événements, caisses, ventes, membres,
  code ; tous les téléphones reviennent à l'accueil ; reprenable si
  interrompue). Règles : suppression en deux temps (drapeau « en cours de
  suppression » posé par le responsable, qui seul autorise l'effacement) ; une
  vente ne se supprime jamais hors suppression de l'association ; la
  suppression du document de l'association exige désormais le drapeau (trou
  corrigé : avant, le responsable pouvait l'effacer seul et laisser des
  données orphelines) ; le responsable retire un membre (jamais lui-même).
  DÉFAUT RÉEL TROUVÉ ET CORRIGÉ PAR LE TEST : la suppression s'arrêtait avant
  d'effacer le code et l'association (relecture de la liste des membres refusée
  une fois le responsable lui-même retiré). Décision 23 ajoutée. Un membre
  retiré ou une association supprimée ramène le téléphone concerné à l'accueil.
  91 tests de logique et d'écrans, 100 tests de règles, 15 parcours sur émulateur
  Android réussis, règles déployées, application de recette refaite
  (recette/le-comptoir-recette.apk, signature vérifiée, lancée sur émulateur).
  RECETTE.md complétée. 19 modules sur 20.
- Corrections demandées après les premiers essais de Kinder (03/10/2026) : (1) plus
  qu'une seule porte d'entrée vers une caisse : l'événement (boutons « Ouvrir la
  caisse » de l'accueil et de l'écran d'erreur supprimés) ; (2) état d'un
  événement visible : pastille « En cours » / « Clôturé » dans la liste et le
  détail, événements en cours d'abord. Décision 24 ajoutée. DÉFAUT RÉEL TROUVÉ ET
  CORRIGÉ : l'écran d'accueil se reconstruisait à chaque événement de connexion
  (ex. renouvellement automatique du jeton) : ce qu'on venait de taper
  disparaissait et un message d'erreur pouvait se perdre ; le suivi de
  l'association est maintenant créé une seule fois par utilisateur. Tests :
  95 tests de logique et d'écrans, 100 tests de règles, 15 parcours Android.
  Outillage : l'émulateur de test tourne maintenant en rendu logiciel
  (swiftshader_indirect, plus stable : le rendu matériel bloquait parfois les
  longs parcours) et les parcours ont une limite de durée (15 min par test).
  Application de recette refaite. Demande en cadrage, non commencée : plusieurs
  gymnases (stocks) par événement, bilan distinct/commun, QR code, gestionnaires
  rattachés à des gymnases.
