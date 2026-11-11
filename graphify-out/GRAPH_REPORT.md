# Graph Report - .  (2026-11-11)

## Corpus Check
- 141 files · ~1,839,899 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1661 nodes · 2437 edges · 46 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.7)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 89 edges
2. `package:flutter_test/flutter_test.dart` - 76 edges
3. `package:le_comptoir/evenement.dart` - 54 edges
4. `package:cloud_firestore/cloud_firestore.dart` - 50 edges
5. `package:firebase_auth/firebase_auth.dart` - 48 edges
6. `package:le_comptoir/gymnase.dart` - 47 edges
7. `package:integration_test/integration_test.dart` - 42 edges
8. `outils.dart` - 41 edges
9. `package:le_comptoir/depot_associations.dart` - 40 edges
10. `package:le_comptoir/depot_menus.dart` - 37 edges

## Surprising Connections (you probably didn't know these)
- `Menu (catalogue de produits)` --references--> `G2 : même menu, stock distinct par gymnase`  [EXTRACTED]
  PROJET_CONTEXTE.md → PLAN_GYMNASES.md
- `Menu (catalogue de produits)` --references--> `Modèle générique de menu (13 produits, logos)`  [EXTRACTED]
  PROJET_CONTEXTE.md → PLAN_STOCK_COURSES.md
- `Événement` --references--> `G1 : plusieurs gymnases par événement`  [EXTRACTED]
  PROJET_CONTEXTE.md → PLAN_GYMNASES.md
- `Caisse (hors réseau)` --references--> `Test coupure réseau (mode avion)`  [EXTRACTED]
  PROJET_CONTEXTE.md → RECETTE.md
- `Bilan` --shares_data_with--> `Coût total des courses déduit au bilan`  [EXTRACTED]
  PROJET_CONTEXTE.md → PLAN_STOCK_COURSES.md

## Hyperedges (group relationships)
- **Missions M1 à M6 du chantier gymnases** — plangym_m1, plangym_m2, plangym_m3, plangym_m4, plangym_m5, plangym_m6 [INFERRED 0.85]
- **Étapes B1 à B6 du chantier Menu, événement et courses** — plansc_b1, plansc_b2, plansc_b3, plansc_b4, plansc_b5, plansc_b6 [INFERRED 0.85]
- **Flux Courses : consommation, préparation, validation, stock, bilan** — plansc_consommation, plansc_courses_prepa, plansc_courses_valid, plansc_stock, plansc_cout_courses [INFERRED 0.80]

## Communities

### Community 0 - "Community 0"
Cohesion: 0.01
Nodes (216): an_passe_octets.dart, attendre, attendreTexte, creerAssociationParLInterface, donnerStock, main, ouvrir, retour (+208 more)

### Community 1 - "Community 1"
Cohesion: 0.01
Nodes (210): champ_reglage.dart, classeur.dart, courses.dart, dart:async, depot_caisses.dart, depot_evenements.dart, depot_menus.dart, ecran_comparateur.dart (+202 more)

### Community 2 - "Community 2"
Cohesion: 0.02
Nodes (131): classeur_aides.dart, dart:typed_data, attendre, attendreTexte, creerAssociationParLInterface, finTransition, id, main (+123 more)

### Community 3 - "Community 3"
Cohesion: 0.02
Nodes (97): integrationDriver, dart:io, attendre, attendreLong, attendreTexte, creerAssociationParLInterface, id, main (+89 more)

### Community 4 - "Community 4"
Cohesion: 0.03
Nodes (86): Correctif compteur de gymnases (dernierGymnase), CHANGELOG, Optimisation : écoute des stocks partagée, Revue d'équipe Hermès (27/10/2026), Chantier plusieurs gymnases par événement (décisions 25-30), G1 : plusieurs gymnases par événement, G2 : même menu, stock distinct par gymnase, G3 : caisse par (membre, gymnase), jamais deux ouvertes (+78 more)

### Community 5 - "Community 5"
Cohesion: 0.03
Nodes (65): appliquerPasse, appliquerReference, arrondi, _bandeau, build, Center, Container, _corps (+57 more)

### Community 6 - "Community 6"
Cohesion: 0.03
Nodes (64): connexion.dart, depot_associations.dart, ecran_accueil.dart, ecran_association.dart, ecran_caisse.dart, ecran_courses.dart, ecran_qr.dart, ecran_racine.dart (+56 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (54): attendre, attendreTexte, changer, connexion, corps, creerAssociationParLInterface, creerEvenement, defiler (+46 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (53): afficher, attendre, attendreUnPeu, creerAssociationParLInterface, main, ouvrir, poserVente, remettreAZero (+45 more)

### Community 9 - "Community 9"
Cohesion: 0.04
Nodes (56): ecran_bilan.dart, ecran_classeur.dart, ecran_gymnases.dart, ecran_personnes_duree.dart, ecran_prevision.dart, ecran_restes.dart, ecran_stock_depart.dart, _abonner (+48 more)

### Community 10 - "Community 10"
Cohesion: 0.04
Nodes (56): _aideLigne, _aideModele, _avecVolets, _bandeau, ClasseurIllisible, ClasseurLu, construireComparaison, construireDonneesMenu (+48 more)

### Community 11 - "Community 11"
Cohesion: 0.04
Nodes (53): code_association.dart, ecran_evenement.dart, ecran_menu.dart, ecran_nouvel_evenement.dart, import_menu.dart, _asso, Association, _code (+45 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (41): actualisation.dart, afficherJours, build, ChampReglage, Column, didUpdateWidget, dispose, _EtatChampReglage (+33 more)

### Community 13 - "Community 13"
Cohesion: 0.05
Nodes (41): _ajouter, AlertDialog, _annuler, _avecEtats, _bandeau, build, Center, ClipRRect (+33 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (32): ajouterA, attendre, bilanVaut, cloturerA, creerAssociationParLInterface, DepotAssociations, donnerStock, egal (+24 more)

### Community 15 - "Community 15"
Cohesion: 0.07
Nodes (26): ecran_menus.dart, AlertDialog, build, Center, _champsType, _changer, Column, _DialogueImage (+18 more)

### Community 16 - "Community 16"
Cohesion: 0.07
Nodes (24): package:le_comptoir/ecran_evenement.dart, avec, ev, evStatut, main, afficher, _avant, _caisse (+16 more)

### Community 17 - "Community 17"
Cohesion: 0.08
Nodes (25): Achat, ajouter, arrondiHaut, avec, avecQuantite, avecValidation, cleArticleAchat, CumulCourses (+17 more)

### Community 18 - "Community 18"
Cohesion: 0.08
Nodes (22): Apport, avecConso, dateAffichee, dateIso, dureeAffichee, Evenement, heureAffichee, libelleModes (+14 more)

### Community 19 - "Community 19"
Cohesion: 0.1
Nodes (20): attendre, attendreTexte, changerDeSession, connexion, creerAssociationParLInterface, defilerJusqua, demainA, etape (+12 more)

### Community 20 - "Community 20"
Cohesion: 0.11
Nodes (18): comparaison.dart, ecran_extraction.dart, build, Card, _carteProduit, _cellule, Center, _choisir (+10 more)

### Community 21 - "Community 21"
Cohesion: 0.11
Nodes (17): attendre, attendreTexte, champ, champQte, creerAssociationParLInterface, finTransition, main, ouvrir (+9 more)

### Community 22 - "Community 22"
Cohesion: 0.11
Nodes (16): dart:convert, cleIngredient, DepotMenus, _ficheModele, FicheProduit, FormatException, Ingredient, Menu (+8 more)

### Community 23 - "Community 23"
Cohesion: 0.12
Nodes (16): attendre, attendreTexte, candidat, changerDeSession, connexion, creerAssociationParLInterface, donnerStock, finTransition (+8 more)

### Community 24 - "Community 24"
Cohesion: 0.12
Nodes (16): attendre, attendreCase, attendreChamp, attendreTexte, creerAssociationParLInterface, donnerStock, expectLater, main (+8 more)

### Community 25 - "Community 25"
Cohesion: 0.12
Nodes (15): attendre, attendreTexte, champ, champQte, creerAssociationParLInterface, finTransition, main, ouvrir (+7 more)

### Community 26 - "Community 26"
Cohesion: 0.13
Nodes (14): attendre, attendreTexte, creerAssociationParLInterface, donnerStock, finTransition, main, montrer, ouvrir (+6 more)

### Community 27 - "Community 27"
Cohesion: 0.17
Nodes (11): detailStockAffiche, ecrireLienGymnase, FormatException, gere, Gymnase, idCaisse, LienGymnase, lireLienGymnase (+3 more)

### Community 28 - "Community 28"
Cohesion: 0.39
Nodes (8): aide(), bandeau(), cellule(), entetes(), famille(), liste(), main(), Bandeau anthracite en tête de feuille, comme la barre de titre de l'application.

### Community 29 - "Community 29"
Cohesion: 0.22
Nodes (7): dart:math, codeBienForme, confirmationSuppression, genererCode, normaliserCode, package:le_comptoir/code_association.dart, main

### Community 30 - "Community 30"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 31 - "Community 31"
Cohesion: 0.67
Nodes (0): 

### Community 32 - "Community 32"
Cohesion: 0.67
Nodes (3): Produit final vs ingrédient, Recette et ingrédients (20 max), Types de produit (composé, unité, part, litre)

### Community 33 - "Community 33"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (2): Publication Play Store, Recette finale et vérification par une autre IA

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (0): 

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (0): 

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (0): 

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (0): 

### Community 39 - "Community 39"
Cohesion: 1.0
Nodes (0): 

### Community 40 - "Community 40"
Cohesion: 1.0
Nodes (0): 

### Community 41 - "Community 41"
Cohesion: 1.0
Nodes (0): 

### Community 42 - "Community 42"
Cohesion: 1.0
Nodes (0): 

### Community 43 - "Community 43"
Cohesion: 1.0
Nodes (0): 

### Community 44 - "Community 44"
Cohesion: 1.0
Nodes (0): 

### Community 45 - "Community 45"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **1368 isolated node(s):** `MainActivity`, `main`, `TestFailure`, `fin`, `haut` (+1363 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 33`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (2 nodes): `Publication Play Store`, `Recette finale et vérification par une autre IA`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (1 nodes): `lancer.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (1 nodes): `un_parcours.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (1 nodes): `lancer.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (1 nodes): `fabriquer_presentation.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (1 nodes): `an_passe_octets.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (1 nodes): `lancer_captures.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (1 nodes): `lancer.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (1 nodes): `lancer_integration.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 19`, `Community 20`, `Community 21`, `Community 23`, `Community 24`, `Community 25`, `Community 26`?**
  _High betweenness centrality (0.368) - this node is a cross-community bridge._
- **Why does `package:cloud_firestore/cloud_firestore.dart` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 6`, `Community 7`, `Community 8`, `Community 11`, `Community 14`, `Community 17`, `Community 19`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 26`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `package:flutter_test/flutter_test.dart` connect `Community 0` to `Community 2`, `Community 3`, `Community 7`, `Community 8`, `Community 14`, `Community 16`, `Community 19`, `Community 21`, `Community 23`, `Community 24`, `Community 25`, `Community 26`, `Community 29`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **What connects `MainActivity`, `main`, `TestFailure` to the rest of the system?**
  _1368 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._