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
- Prévision automatique des courses.

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

## 7. Points ouverts
- Menu type prêt à l'emploi : en place avec des produits génériques
  (`assets/menu_type.json`) ; à remplacer par le menu fourni par moi. Exemples cités
  au départ, non figés : croque-monsieur, salade, fruits, thé, café,
  barre chocolatée, soda.

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
