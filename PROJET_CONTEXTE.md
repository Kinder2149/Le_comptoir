# PROJET_CONTEXTE — Le Comptoir

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
  optionnel par produit.
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
- Membres : liste des membres de l'association, avec leur statut
  (bénévole, gestionnaire en attente, gestionnaire).

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
    `assets/menu_type.json` (10 produits génériques avec icônes) : pour
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

33. Chantier « Stock et courses » (figé le 27/10/2026, cahier des charges d'une IA de l'association comparé à l'existant ; détail du déroulé ci-dessous). Trois modules distincts : Menu, Caisse, Courses.
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

## 7. Points ouverts
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

## 12. État au 05/10/2026 et reprise sur un autre poste
**Où on en est**
- Application complète (étapes 1 à 15, gymnases M1-M6, images modifiables depuis l'événement, bilan redessiné,
  thème a1, logo et icône). Vérifié le 05/10/2026 : analyse sans erreur, 141 tests de logique et d'écrans,
  132 tests de règles, 19 parcours Android, tous verts. Règles d'accès déployées sur le vrai projet.
- APK de recette à jour (`recette/le-comptoir-recette.apk`, non suivi par git : à reconstruire, voir plus bas).
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
- Points ouverts : un gestionnaire peut-il changer le code d'accès ? Menu type réel à fournir.

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
- Limites de Kinder : plus de plafond de modules (décision 41, 23 utilisés), 5 fichiers .md max (4), aucune dépendance sans son accord.
