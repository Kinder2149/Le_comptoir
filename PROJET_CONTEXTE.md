# PROJET_CONTEXTE — Le Comptoir

## STATUT — fait foi pour les statuts (lu par DevBoard)

```
STATUT DU PROJET : En développement
MISSION : Ergonomie de la gestion (décisions 61 à 67, figée le 07/11/2026) — Close le 11/11/2026 sur décision de Kinder, SANS vérification par une autre IA (écart à R9 assumé par Kinder) — E1 à E9 implémentées et testées le 08/11/2026 (PLAN_STOCK_COURSES.md section 14 ; version 1.3.0), fusionnée dans `main` le 11/11/2026 sur accord écrit de Kinder — critère : j'ouvre un tournoi et je vois tout de suite où j'en suis (Avant, Pendant ou Après) et ce qu'il me reste à faire ; je saisis mon stock de départ gymnase par gymnase, produits rangés par familles ; je vérifie la prévision en une page ; je fais les courses en magasin avec une liste rangée par rayons que je coche ; je télécharge l'Excel : il est propre, expliqué et aux couleurs de l'application, et je peux le remplir puis le réimporter
MISSION : Retours du terrain (décisions 68 à 74, plan et critères validés par Kinder le 11/11/2026) — Implémentée et testée par Claude le 11/11/2026 sur la branche `claude/retours-terrain` (F1 à F7, PLAN_STOCK_COURSES.md section 15 ; règles d'accès inchangées, rien à déployer ; APK de recette 1.4.0 dans `recette/`), vérification par une autre IA en cours, puis test et capture de Kinder — seule mission active — critère : sur deux téléphones, je vends sans message de stock fantôme, je vois les ventes de l'autre téléphone, je gère mes membres depuis les Paramètres, et depuis l'écran Extraction et modèle je télécharge le modèle, les données de l'association et l'export d'un tournoi, et je compare deux tournois
MISSION : Plan initial (étapes 1 à 14) — En attente (1) — application complète (étapes 1 à 15), mais le test unique de Kinder sur téléphones (RECETTE.md) n'est pas fait et aucun critère de fin n'est écrit : pas close
MISSION : Publication Play Store — En attente (2) — reste : fiche et questionnaires de la Play Console, test fermé (12 testeurs, 14 jours), accès à la production (voir section 12)
MISSION : Stock et courses (étapes 1 à 8) — En attente de ma capture
MISSION : Menu, événement et courses (B1 à B6, plan validé le 29/10/2026) — En attente (3) — vérifiée par une autre IA le 05/11/2026 ; reste le test et la capture de Kinder (B6)
  Étape : B1 Menu = catalogue sans stock — Close — critère : aucun stock dans un menu, provenance acheté / apporté par produit
  Étape : B2 Ratios et consommation par catégorie — Close — critère : 1 gâteau = n parts, ratio à zéro refusé
  Étape : B3 Gymnases et stock côté événement — Close — critère : stock propre à l'événement, vendu et reste exacts après 3 ventes
  Étape : B4 Courses depuis Gymnases et stock — Close — critère : demi-journée, jour complet ou plus, estimation modifiable
  Étape : B5 Clôture et report de stock — Close — critère : 6 L de soda et 2 L de café gardés repris au prochain événement
  Étape : B6 Clôture de mission — Vérification par une autre IA faite le 05/11/2026 (B1 à B5 et C1 réussis, texte en PLAN_STOCK_COURSES.md section 12), en attente du test et de la capture de Kinder — critère : verdict réussi/échoué par critère rendu par une autre IA
MISSION : C1 Courses en plusieurs validations et partage de la liste (décision 52, tri du 30/10/2026) — En attente de ma capture — Implémentée et testée par Claude le 30/10/2026, fusionnée dans `main` (règles déployées le 30/10/2026), vérifiée par une autre IA le 05/11/2026, reste le test et la capture de Kinder — critère : je valide 40 croques le matin puis 40 de plus l'après-midi, le stock affiche 80 et le coût cumulé ; la liste de courses se partage en texte ou CSV
MISSION : Préparer l'événement (décisions 53 à 60, figée le 06/11/2026) — Implémentée et testée par Claude les 06 et 07/11/2026 sur la branche `claude/preparation-evenement` (P1 à P11, PLAN_STOCK_COURSES.md section 13 ; règles déployées ; APK de recette 1.2.0 dans `recette/`), vérifiée par une autre IA le 07/11/2026 (tous critères réussis), testée et validée par Kinder le 07/11/2026, fusionnée dans `main` le 07/11/2026 — Close — critère : je crée un événement, je télécharge le modèle Excel, je le remplis avec les chiffres de l'an passé et je l'importe ; dans Préparation, je retrouve mon stock de départ et une prévision calculée d'après l'an passé, je corrige un chiffre, je lance les courses ; à la fin du tournoi, j'exporte le même classeur rempli
PHASE : 6 Clôture de la mission Retours du terrain (vérification par une autre IA, puis test final de Kinder)
IDÉES PARQUÉES :
  - Bloc « matériel » (après la mission Ergonomie de la gestion, case « Matériel » réservée)
  - Paiement carte avec Monetico (exploration, rien de figé)
  - Front : missions (b) caisse, (c) accueil/association, (e) bilan/paramètres, (f) finitions ((d) et les menus de (e) repris par la décision 61)
```
*(Bloc ajouté le 2026-10-30, validé par Kinder. Étapes B3 et B4 : testées par Claude le 29/10, reste la capture de Kinder.)*

## 1. Vision
Application mobile de caisse pour les buvettes associatives lors
d'événements sportifs (souvent sur un week-end). Encaisser vite (icônes
illustrées, total automatique), fonctionner sans réseau, et obtenir un
bilan détaillé et analysé en fin d'événement.

## 2. Structure
Association → menus et événements → caisses → ventes.
L'association est l'entité mère : c'est le même club qui organise toutes
les buvettes de la saison.

## 3. Rôles
- Responsable : crée l'association. Tous les droits. Seul à nommer ou
  retirer des gestionnaires et à supprimer l'association.
  Connexion Google.
- Gestionnaire : mêmes droits que le responsable, sauf la gestion des
  gestionnaires. Connexion Google obligatoire.
- Bénévole : rejoint avec le code de l'association et son prénom, sans
  compte. Voit uniquement les événements en cours (pas les menus, pas les
  événements passés, pas les bilans du club). Ouvre une caisse à son nom
  et ne corrige que sa caisse.

## 4. Fonctionnalités
- Menus réutilisables et modifiables, prix par produit, suivi du stock
  optionnel par produit ; type de produit (composé avec recette, à l'unité,
  à la part, au litre) et consommation par personne et par jour (décisions 36 et 42).
- Images : modèle fourni intégré à l'application ; photo ajoutée par
  l'association réduite en vignette et stockée avec le produit.
- Événement : menu associé et modes de paiement autorisés ; seuls ces
  modes apparaissent dans la caisse.
- Caisse : icônes illustrées, total automatique, bouton facultatif de
  monnaie à rendre (on saisit la somme reçue, ex. « 20 € », la caisse
  affiche ce qu'il faut rendre), fonctionnement sans réseau, envoi
  automatique des ventes dès que le réseau revient, corrections et
  annulations tracées (qui, quand, montant).
- Clôture : chaque bénévole clôture sa caisse et voit son récapitulatif
  (total par mode de paiement), pour compter son fond de caisse et le
  remettre ; l'événement se clôture quand toutes les caisses sont
  clôturées et envoyées ; clôture forcée possible par un gestionnaire
  identifié, avec signalement des ventes manquantes dans le bilan.
- Suivi en direct (gestionnaires) : ventes et quantités en cours,
  caisses ouvertes et fermées, dernière mise à jour de chaque caisse.
- Bilan : total, détail par produit, par mode de paiement, par caisse et
  par jour, heures de pointe, produits les plus et les moins vendus.
- Membres : liste des membres de l'association dans les Paramètres (responsable : avec les actions ;
  gestionnaire : en lecture seule ; bénévole : pas de liste), avec leur statut (bénévole, gestionnaire en
  attente, gestionnaire) et une note « Qui peut quoi » (décision 71).
- Extraction et modèle (gestion, depuis l'écran de l'association, décisions 72 à 74) : modèle Excel vierge
  générique, données d'un menu de l'association, export d'un tournoi clôturé, comparateur de deux tournois
  (côte à côte, écarts, export Excel). Glisser vers le bas relit les données sur les écrans principaux
  (décision 70) ; l'avertissement de stock suit le ticket (décision 69).

## 5. Hors périmètre
- Notifications push.
- Prévision automatique des courses qui s'impose : seul un pré-remplissage modifiable existe (décision 42).

## 6. Décisions figées (01/10/2026)
1. L'association est l'entité mère ; un seul code d'accès, celui de
   l'association, régénérable par le responsable.
   Pourquoi : un code par événement obligerait les bénévoles à en
   saisir un nouveau à chaque buvette ; régénérer le code permet
   d'écarter un ancien bénévole.
2. Trois rôles : responsable, gestionnaire, bénévole.
   Pourquoi : si tous les co-admins étaient égaux, l'un d'eux pourrait
   retirer les autres, y compris le créateur.
3. Connexion Google obligatoire pour le responsable et les
   gestionnaires ; bénévoles sans compte (code et prénom).
   Pourquoi : les gestionnaires voient et corrigent tout l'argent, il
   faut les identifier et qu'ils gardent leurs droits en changeant de
   téléphone. Google plutôt que le numéro de téléphone : gratuit, un
   seul bouton, alors que les SMS de connexion sont facturés.
4. Passage bénévole → gestionnaire : nomination par le responsable
   depuis la liste des membres, statut « en attente », pastille « +1 »
   sur l'icône Paramètres du membre, activation par connexion Google
   depuis Paramètres.
5. Une caisse indépendante par téléphone, fonctionnant sans réseau.
   Pourquoi : plusieurs caisses servent à aller plus vite ; les
   buvettes de stade ont souvent un réseau faible ou absent.
6. Envoi automatique des ventes dès que le réseau est disponible ; la
   clôture confirme l'envoi final.
   Pourquoi : les bénévoles restent parfois une heure seulement, les
   gestionnaires doivent suivre en direct.
7. Clôture de l'événement conditionnée à la clôture de toutes les
   caisses, sauf clôture forcée par un gestionnaire identifié.
8. Toute correction ou annulation de vente est tracée.
   Pourquoi : argent associatif, chaque écart doit pouvoir s'expliquer.
9. Pas de service de stockage de fichiers ni de service extérieur
   d'images : les photos sont réduites en vignettes et stockées avec le
   produit.
   Pourquoi : le stockage de fichiers Firebase exige désormais le
   forfait payant.
10. Pas de notification push.
    Pourquoi : l'envoi exige le forfait payant Firebase ; la pastille
    « +1 » suffit.
11. Socle : Mobile Flutter (Flutter + Dart, distribution Android) avec
    Firebase.
    Pourquoi : c'est le socle de Nickel (vérifié le 01/10/2026), dont
    Le Comptoir reprend le système de code d'invitation.
12. Modes de paiement : liste fixe (espèces, carte, chèque, autre).
    Pourquoi : simple pour les bénévoles, suffisant pour une buvette
    (validé le 01/10/2026).
13. À la création d'un événement, les produits et prix du menu sont
    copiés dans l'événement ; modifier le menu ensuite ne change pas un
    événement lancé.
    Pourquoi : les prix d'un week-end en cours ne doivent pas bouger, et
    le bénévole n'a pas accès aux menus (validé le 01/10/2026).
    Exception (05/10/2026) : la gestion peut corriger l'IMAGE (icône, photo) d'un
    produit depuis le détail d'un événement en cours ; nom, prix et stock restent
    figés. Une image changée dans le menu n'atteint donc pas un événement déjà créé.
14. Stock épuisé : la caisse avertit (message fixe, produit marqué
    « Épuisé ») mais ne bloque jamais la vente ; le stock peut passer
    sous zéro.
    Pourquoi : une buvette ne doit pas s'arrêter à cause d'un stock mal
    compté (validé le 02/10/2026).
15. Une caisse par membre et par événement ; les ventes sont enregistrées
    sur le téléphone sans attendre le réseau et envoyées dès son retour ;
    le stock baisse par écritures relatives, donc plusieurs caisses hors
    réseau se cumulent correctement.
16. Un bénévole peut annuler n'importe laquelle de ses ventes (pas
    seulement la dernière), tant que sa caisse est ouverte. La vente
    reste dans la liste, marquée annulée avec qui et quand ; les articles
    reviennent en stock ; corriger = annuler puis ressaisir, les deux
    ventes restent liées. La gestion peut annuler une vente d'une autre
    caisse (sous son propre nom) ; l'écran correspondant arrive avec le
    suivi en direct (étape 11).
    Pourquoi : argent associatif, chaque écart doit pouvoir s'expliquer
    (décision 8) ; validé le 02/10/2026.
17. Clôture de caisse : le bénévole voit son récapitulatif (ventes, total
    par mode de paiement, espèces à remettre, ventes annulées) ; la
    clôture attend que TOUTES ses ventes soient envoyées au serveur puis
    enregistre le récapitulatif. Il peut rouvrir sa caisse (vente
    oubliée) : le récapitulatif est effacé, la réouverture est tracée, il
    se recalcule à la clôture suivante. Une caisse clôturée ne vend plus
    et n'annule plus.
    Pourquoi : « la clôture confirme l'envoi final » (décision 6) ;
    validé le 02/10/2026.
18. Clôture d'événement : par un gestionnaire identifié (Google). Normale
    si toutes les caisses sont clôturées ; sinon forcée, avec son auteur,
    l'heure et le nombre de caisses non clôturées, pour signaler dans le
    bilan que des ventes peuvent manquer. L'événement clôturé est figé et
    disparaît pour les bénévoles.
19. Gestionnaires : le responsable nomme un bénévole depuis la liste des
    membres (statut « gestionnaire en attente », pastille « +1 » sur
    Paramètres) ; le membre active LUI-MÊME son statut en se connectant
    avec Google depuis Paramètres ; en attente, il garde les droits d'un
    bénévole. Seul le responsable nomme et retire ; un gestionnaire ne
    gère pas les gestionnaires. Retirer = redevient bénévole.
    Pourquoi : décisions 2 à 4 ; validé le 02/10/2026.
20. Suivi en direct (responsable et gestionnaires, sur l'événement) :
    total et nombre de ventes, quantités vendues et stock restant par
    produit, et pour chaque caisse son état, ses ventes, son total et sa
    dernière vente ; mise à jour automatique. Une caisse ouverte sans
    activité depuis 60 minutes (pas moins) est signalée « silencieuse ».
    La gestion ouvre une caisse et peut annuler une de ses ventes, sous
    son nom (pas de « corriger », réservé à l'auteur de la caisse).
    Pourquoi : suivre les ventes pendant l'événement ; seuil de 60 min
    validé le 02/10/2026.
21. Bilan (gestion, depuis l'événement, pendant ou après) : total et
    nombre de ventes ; détail par produit (quantité, montant, stock),
    produits les plus et les moins vendus ; par mode de paiement, par
    caisse et par jour ; heures de pointe par tranche d'une heure (les 3
    plus chargées) ; ventes annulées listées à part avec leur trace. Les
    chiffres portent sur les ventes non annulées. Provisoire tant que
    l'événement est en cours, définitif une fois clôturé ; une clôture
    forcée est annoncée en toutes lettres (auteur, heure, caisses non
    clôturées, « des ventes peuvent manquer »).
    Pourquoi : spécification (section 4) ; tranches d'une heure validées
    le 02/10/2026.
22. Images des produits : 14 icônes modèles intégrées à l'application
    (liste fixe, la même dans l'application et dans les règles d'accès)
    et, en option, une photo choisie dans la galerie ou prise avec
    l'appareil, réduite à 96 px par le système et stockée avec le produit
    (30 Ko maximum), sans service de fichiers ni d'images extérieur
    (décision 9). L'événement copie l'image avec le produit : la caisse
    l'affiche même sans réseau. Seule la gestion modifie les images.
    Menu type : proposé à la création d'un menu, lu dans
    `assets/menu_type.json` (13 produits avec types, recettes et logos : voir PLAN_STOCK_COURSES.md, étape 2) : pour
    le remplacer par le vôtre, on modifie ce seul fichier.
    Dépendance ajoutée sur accord : image_picker (réduction incluse, pas de
    second module).
23. Paramètres du responsable : nom de l'association, code d'accès avec
    « Changer le code » (déplacé ici depuis l'écran principal), liste des
    membres avec « Retirer de l'association », et « Supprimer l'association ».
    Retirer un membre ne l'empêche pas de revenir avec le code d'accès : il
    faut aussi changer le code (l'écran le rappelle). Ses ventes passées
    restent dans les bilans. Supprimer : le responsable doit retaper le nom ;
    tout est effacé (menus, événements, caisses, ventes, membres, code) et
    chaque téléphone revient à l'écran d'accueil ; en deux temps (l'association
    est d'abord marquée « en cours de suppression », ce qui autorise les règles
    à effacer le reste) ; reprenable si interrompue. Hors de ce cas, une vente
    ne se supprime jamais. Validé le 03/10/2026.
24. Une caisse ne s'ouvre QUE depuis un événement (plus de bouton « Ouvrir la
    caisse » sur l'écran de l'association ni sur l'écran d'erreur). L'état
    d'un événement est visible partout : pastille « En cours » (verte) ou
    « Clôturé » (grise) dans la liste et dans le détail ; les événements en
    cours sont affichés en premier. Demandé par Kinder le 03/10/2026.
25-30. Chantier « plusieurs gymnases par événement » (validé le 03/10/2026,
    détail, missions M1 à M6 et suivi dans PLAN_GYMNASES.md, décisions G1 à
    G6) : 25 = plusieurs gymnases par événement ; 26 = même menu, stock
    distinct par gymnase ; 27 = une caisse par (membre, gymnase), jamais deux
    caisses ouvertes, changement de gymnase après clôture ; 28 = suivi et
    bilan en vue distincte ou commune ; 29 = gestionnaires rattachés à un ou
    plusieurs gymnases ; 30 = QR code par gymnase (code d'accès inchangé).
    M1 (socle), M2 (gymnases, choix à l'ouverture), M3 (gestionnaires rattachés) faites le 03/10/2026, M4 (vue distincte/commune) et M5 (QR code, dépendances qr_flutter et mobile_scanner ajoutées) et M6 (recette multi-gymnases) le 04/10/2026 : chantier terminé, il reste la recette de Kinder (RECETTE.md). Précision de la confirmation 4 (M3) : l'événement ne se clôture que par le responsable ou un gestionnaire rattaché à tous les gymnases ; 8 gymnases au maximum par événement.
    Confirmations de démarrage (Kinder, 03/10/2026) : (1) limite de modules
    relevée de 20 à 24 ; (2) dépendances qr_flutter et mobile_scanner accordées
    (à ajouter à la mission M5 seulement) ; (3) pas de reprise des anciens
    événements : Kinder supprime ses associations d'essai, l'application affiche
    un message clair devant un ancien événement ; (4) clôture de l'événement
    inchangée : tout gestionnaire identifié peut clôturer (décision 18).

31. Identité visuelle (palette validée par Kinder le 04/10/2026, « Anthracite & pigments » ; pétrole remplacé par framboise cassée le même jour) :
    couleur dominante anthracite #2F343C (barres de titre, action principale) sur fond de lin
    #F4EFE6 ; couleurs d'action « cassées », une par sens : prune #6C4F86 (gérer), framboise cassée #A04467
    (analyser), sauge #5A7D4F (réussir), ocre #9A670F (attention), brique #A8433A (danger, toujours
    en contour fin) ; sable parquet #D9B06F en touche chaude. Pas de mode sombre. Familles de
    produits teintées sur les 14 icônes existantes. Police Roboto (aucune dépendance), zones
    d'appui 48 px minimum, boutons d'encaissement 56 px, cartes arrondies à 16, boutons à 14.
    Composants regroupés dans UN module de thème. Le fonctionnement, les données et les règles
    d'accès ne changent pas. Logo : à venir (brief confié à une autre IA, Kinder rapporte ses
    propositions) ; l'icône et l'écran de démarrage attendent le logo. Maquettes et palette
    complète : audit_front/proposition/index.html.

32. Logo et icône (05/10/2026) : Kinder a retenu la piste A, « auvent et tasse » (auvent rayé lin et sable au-dessus d'une tasse posée sur un plan de comptoir sable, sur fond anthracite). Sources dans `audit_front/proposition/logo/` ; `fabriquer_icones.py` régénère les icônes Android (adaptative + anciennes), l'écran de démarrage et `play_store/icone_512.png`. Pas d'icône thématique Android 13 (non vérifiée).

33. Chantier « Stock et courses » (figé le 27/10/2026, cahier des charges d'une IA de l'association comparé à l'existant ; détail des étapes, modèle de données et registre du cahier des charges dans PLAN_STOCK_COURSES.md). Trois modules distincts : Menu, Caisse, Courses.
34. Droits sur le stock : le bénévole garde sa caisse classique et ajoute des parts (gâteau sucré, gâteau salé, salade) au stock de son gymnase ; il ne voit pas le stock complet et ne le modifie pas. Le responsable et les gestionnaires voient et modifient le stock de leurs gymnases.
    Pourquoi : le bénévole apporte les gâteaux ; la gestion tient les chiffres. Précise la décision 3 et reste dans les gymnases rattachés (décision 29).
35. Rupture de stock : la vente n'est jamais bloquée (confirme la décision 14) ; en plus du message « Épuisé », le produit change de couleur en caisse.
36. Types de produit : composé (recette : quantités nécessaires pour UN produit, fractions permises, ex. 1/4 de tranche), à l'unité (fruit, barre), à la part (gâteaux, salade), au litre (café et sodas : litres achetés, ratio litres -> verres vendus ; chaque soda est un produit distinct). Chaque produit du menu a un type et un stock réglable.
37. Modèle générique : remplace le simple menu type (décision 22). L'association l'utilise tel quel, le modifie, le copie ou crée un menu de zéro. Il est construit à partir de la carte de buvette de Kinder (café, thé, tarte, flan, croque-monsieur, barre chocolatée, fruits, salade, soda, crêpes ; logos sans fond fournis). Dans le modèle, les gâteaux et la salade sont « apportés par les bénévoles » donc hors courses ; l'association peut les intégrer aux courses.
38. Module Courses : lancé avant ou pendant l'événement. On choisit les produits du menu de l'événement à acheter et la quantité de produits finaux voulue ; pour un produit composé, l'application calcule les ingrédients (« ce qu'il reste » est une saisie facultative qui réduit les quantités à acheter). À la validation, on saisit les quantités réellement achetées ; calcul inverse : le stock gagne ce que permet l'ingrédient LIMITANT (ex. gruyère pour 80 croques = +80). Les courses ajoutent au stock, n'en retirent rien. Les ingrédients n'ont pas de stock : les restes ne sont suivis que par la saisie « ce qu'il reste ». Le coût TOTAL des courses est saisi (pas de prix par élément) et déduit au bilan. Pas de marge, pas de lots, pas de coût moyen.
39. Stock bas : il ne concerne que les produits finaux, jamais les ingrédients. Il se déclenche à 10 % du DERNIER total de stock enregistré (si le stock est modifié le samedi soir, ce total devient la référence). Les produits sous le seuil s'affichent et sont suggérés aux courses suivantes.
40. Écartés pour l'instant : transferts entre gymnases (à la main : -10 puis +10), prix d'achat par élément, prévision automatique NON modifiable (voir décision 42), cartes prépayées, terminal bancaire (Monetico, en dernier). Export du bilan : fichier CSV qui s'ouvre dans Excel (pas de vrai .xlsx, qui ajouterait une dépendance) ; bilan de clôture conservé. Remise du fichier sur Android : dépendance éventuelle à demander le moment venu.
41. Plafond de modules supprimé (remplace la limite de 24). Documentation : 5 fichiers .md max inchangé.
    Exigences issues de la revue d'équipe Hermès (27/10/2026) : (a) la vente et la baisse de stock sont écrites dans UN MÊME lot (aujourd'hui deux écritures séparées) ; (b) mesurer les lectures du suivi en direct (quota gratuit 50 000/jour) avant de passer à 8 gymnases ; l'estimation d'écritures (environ 11 000/jour pour 3 gymnases et 6 caisses, quota 20 000) tient. L'identifiant unique de vente existe déjà.

42. Pré-remplissage des quantités de courses (27/10/2026, modifie la décision 40) : à la création d'un événement, la gestion règle le nombre de personnes par gymnase et le nombre de jours (2 par défaut). Chaque produit du menu porte une consommation par personne et par jour, modifiable (exemple de départ pour 80 personnes par gymnase : 2 croque-monsieur, 1 boisson, 1 part de gâteau, 1 fruit ou barre, 2 cafés). Le module Courses PRÉ-REMPLIT avec ces réglages les quantités de produits finaux ; la gestion garde la main et modifie chaque chiffre. Estimations de départ du modèle, à corriger par l'association : croque = 2 tranches de pain de mie, 1/4 de tranche de jambon, 25 g de gruyère ; café = 1 litre pour 8 verres. Aucune quantité n'est imposée : rien ne se commande ni ne s'achète sans validation.
43. Liste de courses de l'an dernier et modèle (28/10/2026, Kinder) : (a) le matériel d'organisation (liquide vaisselle, sopalin, papier toilette, torchons, ruban) n'est PAS dans le modèle de menu ; à la création d'une liste de courses on ajoute à la main des lignes libres (nom, quantité) pour garder une trace centralisée de tout ce qui s'achète. (b) Le modèle est complété : buche de chèvre et tartiflette (recettes alternatives au croque-monsieur) ; les bonbons sont offerts (gratuits, un petit plus) ; le Nutella et le sucre servent aux crêpes sans estimation de quantité (trop aléatoire). (c) Dans le stock, on peut signaler qu'un pot ou paquet est vide (signal « vide », sans quantité). Les valeurs d'exemple du croque restent à recaler : la liste de l'an dernier (1000 tranches de pain, 160 de jambon, 3 kg de gruyère) suggère environ 6 g de gruyère par croque, et non 25 g. Estimation retenue pour le modèle (Claude, faute de chiffres de vente, modifiable par l'association) : environ 400 croques l'an dernier, donc 2 tranches de pain de mie, 1/3 de tranche de jambon, 7 g de gruyère par croque.

44. Limite acceptée sur le stock (29/10/2026, Kinder, après la vérification indépendante du chantier « Stock et courses ») : un bénévole dont la caisse est ouverte peut techniquement, en contournant l'application, modifier la quantité de n'importe quel produit de son gymnase, car la règle de la vente et de l'annulation ne distingue pas une vente d'une correction. Accepté : le bénévole est un membre de confiance, l'application ne lui offre pas cette action, et un durcissement compliquerait la vente sans réseau. Seul l'ajout de parts est borné par le serveur (produit « part », 1 à 1000, quantité et total de référence ensemble). Précise les décisions 34 et 43.

45. Menu et événement (29/10/2026, Kinder, après son test ; modifie les décisions 36 et 37) : le menu est le catalogue de ce qu'on propose, SANS stock. Chaque produit y porte son type, sa provenance (acheté par l'association, ou apporté par les bénévoles donc hors courses sauf ajout à la main) et ses ratios de conversion par catégorie (1 gâteau = n parts, 1 litre = n verres, 1 croque = n composants). Le stock appartient à l'ÉVÉNEMENT, par gymnase, et se gère dans l'onglet « Gymnases et stock ».
46. Prévision et consommation réelle (29/10/2026, modifie la décision 42) : deux notions distinctes. La PRÉVISION (personnes, durée, consommation par catégorie, réglable) sert à estimer les besoins. La CONSOMMATION RÉELLE se mesure pendant l'événement à partir des ventes, à un instant donné. Au lancement des courses, l'application connaît le consommé et le reste, demande la durée à couvrir (demi-journée, jour complet ou plus) et propose une estimation modifiable ; rien ne s'achète sans validation.
47. Courses (29/10/2026, précise les décisions 33 et 38) : le module Courses reste distinct ; on y accède depuis « Gymnases et stock », qui lui fournit consommé et reste des produits finaux. Les INGRÉDIENTS restent sans stock (décision 38 inchangée) : signal « vide » et saisie facultative « ce qu'il reste » seulement.
48. Fin d'événement et report de stock (29/10/2026, remplace la limite « pas de reprise » de la décision 40) : à la clôture, la gestion choisit les produits conservables (ex. soda, café), donne la quantité restante de chacun, l'application la fait confirmer ou modifier. Ces restes sont repris dans le stock de l'événement suivant. Chantier traité en dernier.
49. Cohérence visuelle (29/10/2026) : l'onglet « Gymnases et stock » et le module Courses suivent l'identité visuelle de la décision 31, comme le reste de l'application.
50. Recalage du modèle sur l'Excel de l'an passé (30/10/2026, Kinder : « on recale par rapport à ce qu'on a », pas de ventes réelles disponibles, seulement achats 2024-2025 et tarifs 2024) : modèle de 27 produits (3 croques à 1 € dont la tartiflette en variante, boissons à 4 verres de 25 cl par litre, bière, barres, fruit, 7 produits apportés : tarte, flan, gâteau salé (quiche), salade, 3 petites crêpes, sucette, chocolat chaud). Consommations déduites des achats 2025 pour environ 300 personnes-jours (croques 1,7 au total, café 1,3 estimation Excel). Un bénévole ajoute du stock à tout produit de type « part » OU « apporté » (précise la décision 34). Prix à confirmer avec l'affiche de la buvette.
51. Report de stock à la clôture (B5, 30/10/2026, accord de Kinder « figer et coder » ; met en œuvre la décision 48) : à la clôture, une feuille propose les produits qui ont encore du stock, rien de coché d'avance ; la gestion coche, corrige la quantité (litres pour un produit au litre, stockés en verres) et garde. Les restes sont écrits avec la clôture (tout ou rien) dans `associations/{a}/restes`. À la création de l'événement suivant, chaque gymnase de même nom reprend le stock des produits de même nom (sans casse ni accents), le total de référence suit, et le reste est effacé : un report ne sert qu'une fois. Ce qui ne correspond pas attend. Qui : responsable ou gestionnaire rattaché à tous les gymnases (comme la clôture). Hors périmètre : ingrédients (décision 38), choix manuel du gymnase.
52. Tri du cahier des charges du bénévole (30/10/2026, validé par Kinder ; le PDF est le même que celui du 27/10, repris après B5 ; registre détaillé en section 6 de PLAN_STOCK_COURSES.md). RETENU, mission C1 (à cadrer après B6) : (a) courses validables en plusieurs fois, chaque validation ajoutant au stock et au coût, la liste restant protégée contre un double comptage ; les statuts par ligne (à acheter, partiel, reçu, annulé) sont mis de côté ; (b) partage de la liste de courses en texte ou CSV par la feuille de partage existante, sans nouvelle dépendance. ADAPTÉ : vente jamais bloquée, transferts à la main, inventaire = réglage du stock, marge = coût total et résultat, ingrédients calculés à l'achat, sucré/salé = produits distincts. MIS DE CÔTÉ : pertes et consommations internes, état « inconnu » gris, valeur du stock restant et marges par produit, filtres et bilan par catégorie, sauvegardes (l'export CSV en tient lieu), cartes prépayées. PARQUÉ : Monetico. À faire plus tard : rendre compte au bénévole des choix faits par rapport à son PDF.

53. Chantier « Préparer l'événement » (06/11/2026, validé par Kinder ; intègre ses retours du 01/11/2026 R2 à R5, R1 « rupture en rouge » étant déjà fait par l'étape 4 ; détail et plan dans PLAN_STOCK_COURSES.md, section 13). Un onglet « Préparation » dans l'événement mène trois étapes dans l'ordre : stock de départ, prévision, courses. La création de l'événement reste légère (nom, date, menu, gymnases, modes de paiement). « Gymnases et stocks » reste l'écran du « pendant ».
    Pourquoi : un fil unique du « avant » jusqu'aux achats ; les réglages dispersés (personnes dans Courses, stock dans Gymnases) n'étaient pas compris.
54. Stock de départ : produits finis seulement, par gymnase ; saisi à la main, ou pré-rempli par les restes gardés à la clôture précédente (décision 51), toujours corrigeable. Les ingrédients restent sans stock (décision 38 inchangée) et gardent la saisie « ce qu'il reste ».
    Pourquoi : un stock d'ingrédients reprendrait tout le calcul des courses et de la caisse.
55. Personnes attendues (par gymnase) et durée (par événement) se règlent dans la Préparation ; le module Courses les lit sans les régler (précise les décisions 42 et 46).
56. Prévision : un seul calcul, la consommation par personne et par jour de chaque produit, propre à l'événement. Trois sources : le menu (par défaut), un événement passé clôturé choisi par la gestion (ventes non annulées ÷ personnes ÷ jours, produit retrouvé par son nom), l'historique importé par Excel. Un produit absent de la source garde la valeur du menu. Chaque chiffre reste modifiable dans l'événement sans toucher au menu ; la source de chaque chiffre est affichée.
    Pourquoi : la logique des courses ne change pas, seule l'origine du chiffre change (retour R3 et R4).
57. Modèle Excel : un vrai classeur `.xlsx` à quatre feuilles (Menu, Stock de départ, Historique, Courses), téléchargeable vide ou rempli avec les données de l'association, et importable. L'export complet du tournoi produit ce même classeur, bilan compris, et REMPLACE l'export CSV (modifie la décision 40). L'historique importé sert de référence de consommation : il ne crée aucune vente, pour ne pas fausser les bilans. Dépendances accordées par Kinder le 06/11/2026 : lecture et écriture d'un fichier Excel, choix d'un fichier sur le téléphone.
    Pourquoi : un seul format à l'aller et au retour, pour que toute association puisse reprendre ses propres chiffres (retour R5).
58. Excel de l'an passé de Kinder : recopié une fois par Claude Code dans le modèle, puis importé par Kinder dans l'application (premier « événement passé » ; teste l'import en conditions réelles). Fichier à déposer par Kinder dans le dossier du projet.
59. Apports nommés (retour R2) : un bénévole ajoute un apport (ce que c'est, ex. « quiche », et son nombre de parts) dans un produit-catégorie (ex. « Gâteau salé ») ; la caisse vend la catégorie ; le bilan liste les apports (qui, quoi, combien de parts). Précise les décisions 34 et 50.
    Hors du chantier : le bloc matériel (chantier suivant), Monetico, les points ouverts de la section 7.
60. État « En préparation » (06/11/2026, validé par Kinder ; précise les décisions 18 et 24) : un événement naît « En préparation » ; seule la gestion le voit ; aucune caisse ne s'y ouvre. « Ouvrir l'événement » (responsable ou gestionnaire rattaché à tous les gymnases, comme la clôture) le passe « En cours » : les bénévoles le voient alors. Les événements créés avant ce changement restent « En cours ».
    Pourquoi : préparer un tournoi des jours à l'avance sans que les bénévoles le voient ni puissent y encaisser.

61. Chantier « Ergonomie de la gestion » (07/11/2026, validé par Kinder après l'audit des écrans sur émulateur : captures dans `audit_front/ergonomie/avant/`, maquette https://claude.ai/artifact/Nq98zwiUFctzRs43fcaa4S, classeur prototype `audit_front/ergonomie/classeur_propose.xlsx` ; plan dans PLAN_STOCK_COURSES.md section 14). Périmètre : l'écran de l'événement, le stock de départ, les personnes et la durée, la prévision, les courses, le stock pendant le tournoi, le menu et le classeur Excel. Hors périmètre : la caisse des bénévoles, le bilan (inchangé, rangé dans « Après ») et toutes les règles de calcul. Reprend les missions parquées (d) et (e) du front pour ces écrans.
    Pourquoi : la caisse est testée ; changer à la fois l'organisation et les calculs rendrait les défauts impossibles à démêler.
62. L'événement est un tableau de bord en trois temps : Avant (liste de tâches avec avancement : stock de départ, personnes et durée, prévision, courses, et une case « Matériel » réservée au bloc suivant ; bouton « Ouvrir le tournoi aux bénévoles »), Pendant (chiffres du jour, produits à surveiller avec une action, accès au stock, aux courses d'appoint, aux caisses en direct et au bilan provisoire), Après (clôture, report des restes, bilan, export Excel). Le temps affiché d'emblée suit l'état de l'événement. Chaque tâche a son propre écran court ; plus de page unique interminable.
    Pourquoi : l'utilisateur doit voir d'un coup d'œil où il en est du tournoi et ce qu'il reste à faire.
63. Familles de produits : liste fixe de six familles, dans cet ordre partout (application et Excel) : Croques, Boissons chaudes, Boissons fraîches, Snacks et fruits, Fait maison, Autre. Chaque produit en a une (le modèle les remplit) ; un produit sans famille va dans « Autre ». Les listes de produits sont regroupées par famille, repliables, avec un compteur.
    Pourquoi : un ordre unique et stable ; des familles libres viendront si un club le demande.
64. Rayons des courses : liste fixe de six rayons : Boulangerie, Frais et crèmerie, Boissons, Épicerie, Entretien et matériel, Autre. Chaque ingrédient d'une recette, chaque produit acheté tel quel et chaque ligne libre a son rayon (le modèle les remplit). La liste « À acheter » est rangée par rayon.
    Pourquoi : la liste doit servir dans le magasin ; « Entretien et matériel » prépare le bloc suivant.
65. Cases cochées en magasin : enregistrées avec la liste de courses et partagées entre les téléphones de la gestion (deux personnes peuvent faire les courses en même temps). Elles ne changent ni le stock ni le coût : seule la saisie des achats le fait, comme aujourd'hui.
66. Classeur Excel : les recettes passent dans une feuille « Recettes » (un ingrédient par ligne, avec son rayon) ; colonnes Famille (Menu) et Rayon ; feuille « Accueil » qui explique l'usage ; mise en forme aux couleurs de l'application (bandeau, cases blanches à remplir, cases beiges calculées) ; listes déroulantes (type, provenance, famille, unité, rayon) ; en-têtes figés ; l'Historique calcule lui-même la consommation par personne et par jour. Les classeurs à l'ancien format restent importables. Précise la décision 57.
    Pourquoi : le classeur doit être aussi clair que l'application, et un classeur déjà rempli ne doit jamais devenir inutilisable.
67. Icônes : les icônes fausses sont corrigées (barres de céréales, bonbons). Un produit sans icône juste montre une pastille à la couleur de sa famille avec ses initiales.
    Pourquoi : une mauvaise image trompe davantage qu'une absence d'image.
    Ordre : ce chantier démarre après la clôture de la mission « Préparer l'événement » (test, capture et fusion par Kinder) ; le bloc « matériel » vient ensuite, dans la case réservée.

68. Mission « Retours du terrain » (11/11/2026, validée par Kinder après l'usage réel d'une caisse sur deux téléphones ; plan F1 à F7 dans PLAN_STOCK_COURSES.md section 15). Quatre retours : message de stock qui reste affiché, membres absents des Paramètres, pas d'actualisation entre deux téléphones, pas d'endroit unique pour les extractions et le modèle. Elle démarre après la clôture de la mission « Ergonomie de la gestion » (une mission active par projet).
69. Avertissement de stock en caisse : il suit le contenu du ticket. Il reste affiché tant qu'un produit du ticket atteint ou dépasse son stock, et disparaît dès que la ligne est retirée ou ramenée sous le stock. La vente n'est jamais bloquée (décisions 14 et 35 inchangées).
70. Actualisation : les écrans restent en direct. D'abord reproduire sur deux téléphones le défaut vu par Kinder et en corriger la cause ; ensuite « glisser vers le bas pour actualiser » sur les écrans principaux (association, événement, caisses en direct, stock, bilan), qui relit les données sur le serveur.
    Pourquoi : un bouton seul masquerait un vrai défaut de mise à jour en direct.
71. Membres et droits : une seule liste des membres, dans les Paramètres, visible par le responsable et les gestionnaires (elle quitte le bas de l'écran de l'association) ; chaque ligne porte les actions permises (nommer, retirer le statut de gestionnaire, retirer de l'association). Retirer un membre et gérer les gestionnaires restent réservés au responsable (décisions 19 et 23 inchangées, confirmé par Kinder le 11/11/2026). Une note « Qui peut quoi » résume les droits des trois rôles.
72. Écran « Extraction et modèle » (gestion, depuis l'écran de l'association, à côté de « Menus ») : quatre cartes : modèle vierge, données de l'association (menu choisi, composition, prévision), export d'un tournoi clôturé, comparateur d'événements. Chaque export garde les droits d'aujourd'hui (un gestionnaire limité ne voit que ses gymnases). Les accès actuels (bouton Excel de l'onglet Avant, export de l'onglet Après) restent.
73. Modèle générique : construit sur les chiffres réels de l'association de Kinder (décision 50), mais sans aucune marque ni nom de club ; chaque feuille a un exemple rempli et une explication ; il se réimporte sans erreur. Seuls les nouveaux menus créés depuis le modèle sont concernés ; les menus et événements existants ne changent pas.
74. Comparateur d'événements : deux tournois clôturés choisis par la gestion, côte à côte : personnes, jours, ventes, total, coût des courses, résultat, puis par produit (retrouvé par son nom, comme la décision 56) les quantités vendues et la consommation par personne et par jour, avec l'écart. Export en Excel aux couleurs de l'application. Aucune nouvelle dépendance.

## 7. Points ouverts
- Retours de Kinder du 01/11/2026 (R1 à R5, écrits sur la branche en ligne `claude/doc-stock-management-dhutbe`, jamais fusionnée) : R1 fait (étape 4), R2 à R5 repris par les décisions 53 à 59. La branche peut être supprimée sur accord de Kinder.
- Défauts relevés au test de Kinder (29/10/2026) : module Courses introuvable à l'écran ; menu et événement confondus ; onglet « Gymnases et stock » non conforme au thème (décision 49). Plan validé le 29/10/2026 : chantier B1 à B6 dans PLAN_STOCK_COURSES.md, section 5 bis (prochaine : phase 5, cadrage de B1, après initialisation de graphify).
- Menu type prêt à l'emploi : en place avec des produits génériques
  (`assets/menu_type.json`) ; devient le modèle générique (décision 37). Reste à recevoir : les prix de la carte et l'estimation des courses de Kinder (base du modèle). Exemples cités
  au départ, non figés : croque-monsieur, salade, fruits, thé, café,
  barre chocolatée, soda.
- **Paiement carte avec Monetico (piste A, en phase 2 de cadrage, 18/10/2026 — rien de figé)**
  - Besoin : le club (seul club visé pour l'instant) encaisse la carte avec l'appli Monetico Tap to
    Pay (Crédit Mutuel) sur Android ; ses bénévoles saisissent donc chaque montant deux fois
    (Le Comptoir puis Monetico).
  - Orientations prises par Kinder : le mode « Carte » actuel reste inchangé ; à l'ouverture de la
    caisse, proposer d'associer Monetico à cette caisse ; le niveau de liaison sera choisi selon ce
    que Monetico permet. Hypothèse à confirmer : plusieurs téléphones, chacun connecté au compte
    Monetico du club par identifiant et mot de passe.
  - Proposition de Claude (non validée) : Le Comptoir ne fait que vérifier que Monetico est installé
    sur le téléphone ; il ne connaît jamais les identifiants Monetico du club.
  - Trois niveaux possibles : (1) liaison complète, Le Comptoir envoie le montant à Monetico et
    récupère accepté / refusé (exige que Monetico le permette, non documenté publiquement) ;
    (2) bouton qui ouvre Monetico, le montant est retapé (toujours possible) ; (3) contrôle en fin
    d'événement, total « Carte » du bilan à comparer au relevé Monetico (toujours possible).
  - Faits vérifiés (sites Crédit Mutuel / CIC / Monetico, 18/10/2026) : Android 12 ou plus + NFC,
    réseau nécessaire au paiement, code PIN au-delà de 50 €. Tarifs associations : 10 € HT puis
    1,70 % + 0,15 €, ou 5 € HT/mois puis 1,00 % + 0,15 €. Appli Android : `com.ei.softpos`.
    « S'intègre aux solutions d'encaissement » est annoncé sans aucun détail.
  - Piste B écartée pour l'instant (autre prestataire, Stripe par ex.) : changement de banque
    d'encaissement, serveur donc forfait Firebase payant, Android 13 minimum, réseau obligatoire.
  - **Prochaines actions** : (a) Kinder obtient les accès Monetico du club pour tester sur son propre
    téléphone ; (b) téléphone branché au PC, lire ce que l'appli `com.ei.softpos` accepte de recevoir
    des autres applis (lecture seule, demande l'outillage Android et le mode développeur) ;
    (c) en parallèle, question au conseiller Crédit Mutuel : une autre appli peut-elle ouvrir Monetico
    avec un montant et récupérer le résultat ? documentation et coût ? un contrat sur plusieurs
    téléphones ?
  - Points ouverts : redemander l'association à chaque ouverture de caisse ou la retenir sur le
    téléphone ? que fait la caisse si le paiement carte échoue faute de réseau ?

## 8. Plan (validé le 01/10/2026)
Règle : chaque étape est validée par des tests automatiques lancés et
réussis par Claude (logique, écrans simulés, droits sur copie locale de
Firebase, coupure réseau simulée). Kinder ne teste qu'une fois, à la
fin (étape 14). Une pause guidée est faite quand il faut configurer un
service.

1. Caisse minimale : produits en dur, total automatique, remise à zéro.
   Aucun service.
   -- PAUSE SERVICES : création du projet Firebase, base de données,
   connexion invisible et Google, application Android (Kinder guidé pas
   à pas) --
2. Fondation Firebase : démarrage, connexion invisible, accès base.
3. Association et code : création, rejoindre par code et prénom, code
   régénérable (l'ancien cesse de marcher).
4. Connexion Google et rôles : responsable, gestionnaire, bénévole et
   leurs droits.
5. Menus : produits, prix, stock optionnel.
6. Événements : menu associé, modes de paiement autorisés ; le
   bénévole ne voit que les événements en cours.
7. Caisse réelle : caisse au nom du bénévole, ventes, modes autorisés,
   monnaie à rendre facultative, hors réseau avec envoi automatique.
8. Corrections et annulations tracées (qui, quand, montant).
9. Clôtures : récapitulatif, caisse, événement, clôture forcée.
10. Membres et gestionnaires : statuts, « en attente », pastille « +1 ».
11. Suivi en direct.
12. Bilan.
13. Images (modèles, photo en vignette) et menu type.
14. Recette finale : parcours complet automatique, fabrication de
    l'application Android, test unique par Kinder.

Dépendances à demander avant ajout : connexion Google (étape 4),
gestion des photos (étape 13).

### Plan du chantier « Stock et courses » (validé le 27/10/2026, décisions 33 à 41)
Une étape à la fois ; chaque étape a un critère écrit par Kinder avant tout code (phase de cadrage).
1. Types de produit et recettes dans le menu (composé, unité, part, litre avec ratio litres/verres) et consommation par personne et par jour.
2. Modèle générique : partir du modèle, copier un menu ou partir de zéro ; carte de 10 produits avec logos.
3. Stock par rôle : saisie et modification par la gestion, ajout de parts par le bénévole, total de référence enregistré à chaque modification.
4. Caisse : produit coloré en rupture, alerte sous 10 % du dernier total, vente et stock écrits dans un même lot.
5. Courses, préparation : réglages de l'événement (personnes par gymnase, jours), quantités pré-remplies et modifiables, ingrédients calculés, « ce qu'il reste », suggestions de stock bas.
6. Courses, validation : quantités réellement achetées, calcul inverse (ingrédient limitant), mise à jour du stock, coût total.
7. Bilan et export : coût des courses déduit au bilan, export CSV.
8. Recette : parcours complet automatique, test de Kinder, mesure des lectures du suivi en direct.
Détail, points à trancher à chaque cadrage et suivi : PLAN_STOCK_COURSES.md.
Ordre : l'étape 3 précède la 4 (l'alerte a besoin du total de référence). Monetico : chantier à part, en dernier.

## 9. Références techniques (01/10/2026)
- Projet Firebase : `le-comptoir-60ba8` (n° 522645235489), plan Spark
  (gratuit).
- Base Firestore `(default)`, mode natif, région europe-west3
  (Francfort) — irréversible.
- Connexions activées : anonyme et Google.
- Application Android : `fr.lecomptoir.le_comptoir`, empreinte de
  signature de débogage du poste de Kinder enregistrée.
- Fichier `android/app/google-services.json` : configuration publique
  Firebase, intégrée au projet.

## 10. Tests (comment on valide chaque étape)
- Logique et écrans : `flutter test`
- Règles d'accès sur copie locale de Firebase :
  `powershell -File tests_regles/lancer.ps1`
- Parcours sur émulateur Android (copie locale de Firebase) :
  `powershell -File tests_regles/lancer_integration.ps1`
  (émulateur Android dédié `LC2` à démarrer avant)

## 11. Recette finale (02-03/10/2026)
- Étapes 1 à 13 du plan terminées et testées ; étape 14 : recette automatique
  d'un week-end complet (tous les rôles, du menu type au bilan, avec annulation,
  correction, clôture, réouverture, clôture forcée et coupure de réseau), bilan
  vérifié chiffre par chiffre contre un calcul fait à la main.
- Application de recette : `recette/le-comptoir-recette.apk` (signée avec la clé
  d'essai du poste : pas publiable sur le Play Store). Test unique de Kinder :
  voir `RECETTE.md`.
- Revue (04/10/2026, après le chantier gymnases) : 22 modules sur 24, 4 fichiers de
  documentation sur 5, aucune structure vide, uniquement les dépendances accordées
  (dont qr_flutter et mobile_scanner).
- Écran Paramètres avec suppression de l'association et retrait d'un membre :
  ajoutés après la recette (décision 23). Menu type réel à fournir.
- Point ouvert : un gestionnaire peut-il changer le code d'accès ?

## 12. État au 28/10/2026 et reprise sur un autre poste
**Où on en est**
- Application complète (étapes 1 à 15, gymnases M1-M6, images modifiables depuis l'événement, bilan redessiné,
  thème a1, logo et icône). Vérifié le 05/10/2026 : analyse sans erreur, 141 tests de logique et d'écrans,
  132 tests de règles, 19 parcours Android, tous verts. Règles d'accès déployées sur le vrai projet.
- APK de recette à jour (`recette/le-comptoir-recette.apk`, non suivi par git : à reconstruire, voir plus bas).
- Mission Retours du terrain (11/11/2026) : F1 à F7, 466 tests de logique et d'écrans, 255 tests de règles, parcours Android de chaque étape verts (parcours `parcours_retours_terrain_test` vert ; ses captures sont facultatives : sur l'émulateur du poste, la conversion de la surface en image fige les parcours à captures, `parcours_ergonomie_test` y compris). Rouges déjà présents avant la mission : `evenements_test`, `menus_test`, `images_test` (libellés périmés). APK 1.4.0+5.
- Mission Ergonomie de la gestion (08/11/2026) : 439 tests, 254 tests de règles, analyse sans erreur, parcours `parcours_ergonomie_test.dart` réussi ; APK 1.3.0+4. Pour lancer les émulateurs Firebase : Java 21 ou plus (celui d'Android Studio : `C:\Program Files\Android\Android Studio\jbr`), car Java 8 passe en premier sur ce poste.
- **Reste à faire, dans cet ordre** : (1) test unique de Kinder sur téléphones (`RECETTE.md`) puis corrections ;
  (2) publication Play Store (en cours, 06/10/2026) : **fait** : application créée dans la Play Console
  (`fr.lecomptoir.le_comptoir`, gratuite, fr-FR), clé d'envoi dédiée (`V:\DEV\keys\le-comptoir-upload.jks` + `le-comptoir-key.properties` ;
  copie hors poste à faire par Kinder), `build.gradle.kts` signe avec elle via `android/key.properties` (hors git),
  version 1.0.0+1 envoyée en test interne (Play App Signing actif), empreintes Play + clé d'envoi ajoutées dans Firebase,
  politique de confidentialité en ligne (`docs/confidentialite.html`, GitHub Pages sur `main` /docs :
  https://kinder2149.github.io/Le_comptoir/confidentialite.html), image de présentation 1024x500, 6 captures
  (`play_store/captures/`, régénérables par `lancer_captures.ps1`), textes de la fiche (`play_store/textes_fiche.txt`).
  **Reste** : test de la connexion Google sur téléphone depuis l'installation Play (sinon re-télécharger
  `google-services.json` et envoyer 1.0.1) ; remplir la fiche et les questionnaires Play Console (sécurité des données,
  classification, public cible, pubs : non) ; test fermé obligatoire (12 testeurs, 14 jours, liste « Testeur PaperClip » de 22) ;
  puis demande d'accès à la production.
  (3) front : missions (b) caisse, (c) accueil/association, (d) événement/suivi/gymnases, (e) bilan/menus/paramètres, (f) finitions.
  (4) paiement carte avec Monetico : exploration en cours, voir section 7 (18/10/2026).
- **Chantier « Stock et courses » (décisions 33 à 43, PLAN_STOCK_COURSES.md)** : étape 1 (types de produit et recettes) implémentée et testée le 28/10/2026 sur la branche `claude/comptoir-app-refinement-cnuyb4` (analyse sans erreur, 162 tests, 146 tests de règles, 18 parcours Android). Règles déployées sur le vrai projet le 28/10/2026 (accord de Kinder). Reste pour l'étape 1 : vérification par une autre IA et capture de Kinder (le test sur téléphones se fera à la fin des étapes). Étape 2 (modèle générique et logos) implémentée et testée le 28/10/2026 (166 tests, 147 tests de règles, 19 parcours Android) ; clé `tarte` des règles déployée le 28/10/2026 (accord de Kinder) ; reste la vérification par une autre IA et la capture de Kinder. Étape 3 (stock par rôle : ajout de parts par le bénévole, total de référence, signal « vide ») implémentée et testée le 28/10/2026 (166 tests, 155 tests de règles, 21 parcours Android) ; règles (champ `reference`, sous-collection `vides`) déployées le 28/10/2026 (accord de Kinder) ; reste la vérification par une autre IA et la capture de Kinder. Étape 4 (caisse : rupture, stock bas, « vide », vente et stock dans un même lot) implémentée et testée le 28/10/2026 (175 tests, 157 tests de règles, 22 parcours Android) ; règles inchangées ; reste la vérification par une autre IA et la capture de Kinder. Étape 5 (courses : préparation) implémentée et testée le 28/10/2026 (187 tests, 162 tests de règles, 23 parcours Android) ; règles (nbJours, personnes, courses/liste) déployées le 28/10/2026 (accord de Kinder) ; reste la vérification par une autre IA et la capture de Kinder. Étape 6 (courses : validation, calcul inverse, ajout au stock) implémentée et testée le 28/10/2026 (195 tests, 166 tests de règles, 24 parcours Android) ; règles (liste validée) déployées le 28/10/2026 (accord de Kinder) ; reste la vérification par une autre IA et la capture de Kinder. Étape 7 (bilan : coût et résultat des courses ; export CSV par la feuille de partage, dépendance `share_plus` accordée par Kinder) implémentée et testée le 28/10/2026 (210 tests, 166 tests de règles, 24 parcours Android) ; règles inchangées ; reste la vérification par une autre IA et la capture de Kinder. Étape 8 (recette) implémentée et testée le 28/10/2026 : parcours complet automatique, lectures mesurées et optimisées (écoute des stocks partagée ; 3 gymnases ≈ 39 % du quota, 8 gymnases ≈ 79 %), version 1.1.0 et APK de recette reconstruit (signé avec la clé de publication ; désinstaller l'ancienne version), 210 tests, 166 tests de règles, 26 parcours Android. Vérification indépendante faite le 29/10/2026 (11 critères réussis, aucun défaut bloquant ; compteur de gymnases verrouillé dans les règles (déployées le 29/10/2026, accord de Kinder) ; lectures corrigées à la hausse, voir section 10 du plan). Reste : test de Kinder sur téléphones, puis fusion dans `main` sur son accord.
- Piège des règles : une requête évalue 1000 expressions au plus ; ne pas ajouter de contrôles lourds par ingrédient sans mesurer.
- Points ouverts : un gestionnaire peut-il changer le code d'accès ? Prix réels du modèle à fournir.

**Reprendre sur un autre poste** (fichiers volontairement absents de git) :
- `lib/firebase_options.dart` et `android/app/google-services.json` : à copier depuis l'autre poste, ou à régénérer avec
  `flutterfire configure --project le-comptoir-60ba8` (application Android `fr.lecomptoir.le_comptoir`). Sans eux,
  l'application et `test/ecran_caisse_test.dart` ne se compilent pas.
- Empreinte de signature : celle du poste est enregistrée dans Firebase. Un autre poste a une autre clé de débogage : ajouter
  son empreinte SHA-1 dans la console Firebase, sinon la connexion Google échoue sur l'APK construit là-bas.
- Outils : Flutter, Node (pour `firebase-tools`), Java 21 (jbr d'Android Studio) pour les émulateurs Firebase, émulateur Android
  `LC2` (jamais `Medium_Phone`). Lancer les émulateurs avec `-gpu swiftshader_indirect -no-snapshot -no-audio`.
- Commandes : `flutter analyze`, `flutter test`, `powershell -File tests_regles/lancer.ps1`,
  `powershell -File tests_regles/lancer_integration.ps1` (~25 min, en arrière-plan),
  `flutter build apk --release` puis copie de `build/app/outputs/flutter-apk/app-release.apk` vers `recette/`.
- Déployer les règles (seulement après leurs tests) : `firebase deploy --only firestore:rules --project le-comptoir-60ba8`.
- Pièges : après `ouvrirCaisse` dans un test, toujours `await db.waitForPendingWrites()` ; les fichiers `lib/*.dart` sont en CRLF ;
  deux fichiers de test qui partagent l'émulateur ne réutilisent pas la même adresse e-mail.
- Limites de Kinder : plus de plafond de modules (décision 41, 23 utilisés), 5 fichiers .md max (5 : limite atteinte avec PLAN_STOCK_COURSES.md), aucune dépendance sans son accord.
