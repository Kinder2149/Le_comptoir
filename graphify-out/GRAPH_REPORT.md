# Graph Report - .  (2026-10-29)

## Corpus Check
- Large corpus: 343 files · ~1,338,149 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 952 nodes · 1322 edges · 26 communities detected
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

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 52 edges
2. `package:flutter_test/flutter_test.dart` - 42 edges
3. `package:cloud_firestore/cloud_firestore.dart` - 31 edges
4. `package:firebase_auth/firebase_auth.dart` - 31 edges
5. `package:integration_test/integration_test.dart` - 25 edges
6. `outils.dart` - 25 edges
7. `package:le_comptoir/evenement.dart` - 24 edges
8. `package:le_comptoir/depot_associations.dart` - 23 edges
9. `package:le_comptoir/gymnase.dart` - 21 edges
10. `gymnase.dart` - 15 edges

## Surprising Connections (you probably didn't know these)
- `G2 : même menu, stock distinct par gymnase` --references--> `Menu (catalogue de produits)`  [EXTRACTED]
  PLAN_GYMNASES.md → PROJET_CONTEXTE.md
- `Modèle générique de menu (13 produits, logos)` --references--> `Menu (catalogue de produits)`  [EXTRACTED]
  PLAN_STOCK_COURSES.md → PROJET_CONTEXTE.md
- `G1 : plusieurs gymnases par événement` --references--> `Événement`  [EXTRACTED]
  PLAN_GYMNASES.md → PROJET_CONTEXTE.md
- `Test coupure réseau (mode avion)` --references--> `Caisse (hors réseau)`  [EXTRACTED]
  RECETTE.md → PROJET_CONTEXTE.md
- `Coût total des courses déduit au bilan` --shares_data_with--> `Bilan`  [EXTRACTED]
  PLAN_STOCK_COURSES.md → PROJET_CONTEXTE.md

## Hyperedges (group relationships)
- **Missions M1 à M6 du chantier gymnases** — plangym_m1, plangym_m2, plangym_m3, plangym_m4, plangym_m5, plangym_m6 [INFERRED 0.85]
- **Étapes B1 à B6 du chantier Menu, événement et courses** — plansc_b1, plansc_b2, plansc_b3, plansc_b4, plansc_b5, plansc_b6 [INFERRED 0.85]
- **Flux Courses : consommation, préparation, validation, stock, bilan** — plansc_consommation, plansc_courses_prepa, plansc_courses_valid, plansc_stock, plansc_cout_courses [INFERRED 0.80]

## Communities

### Community 0 - "Community 0"
Cohesion: 0.02
Nodes (123): attendre, attendreTexte, creerAssociationParLInterface, main, ouvrir, retour, TestFailure, toucher (+115 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (84): attendre, attendreTexte, creerAssociationParLInterface, finTransition, id, main, ouvrir, saisir (+76 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (86): Correctif compteur de gymnases (dernierGymnase), CHANGELOG, Optimisation : écoute des stocks partagée, Revue d'équipe Hermès (27/10/2026), Chantier plusieurs gymnases par événement (décisions 25-30), G1 : plusieurs gymnases par événement, G2 : même menu, stock distinct par gymnase, G3 : caisse par (membre, gymnase), jamais deux ouvertes (+78 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (77): courses.dart, depot_caisses.dart, evenement.dart, export_bilan.dart, gymnase.dart, caisses, DepotEvenements, _depuis (+69 more)

### Community 4 - "Community 4"
Cohesion: 0.03
Nodes (63): connexion.dart, depot_associations.dart, ecran_accueil.dart, ecran_association.dart, ecran_caisse.dart, ecran_evenement.dart, ecran_nouvel_evenement.dart, ecran_qr.dart (+55 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (50): dart:async, attendre, contenuDe, fauxGoogle, TestFailure, texte, attendre, creerAssociationParLInterface (+42 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (51): code_association.dart, depot_evenements.dart, depot_menus.dart, ecran_bilan.dart, ecran_courses.dart, ecran_gymnases.dart, ecran_menu.dart, Association (+43 more)

### Community 7 - "Community 7"
Cohesion: 0.05
Nodes (37): dart:io, attendre, creerAssociationParLInterface, main, ouvrir, pause, photo, restEcrire (+29 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (39): _ajouter, AlertDialog, _annuler, _avecEtats, _bandeau, build, Center, ClipRRect (+31 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (35): dart:convert, Achat, ajouter, arrondiHaut, avec, avecQuantite, _decimal, formaterQuantite (+27 more)

### Community 10 - "Community 10"
Cohesion: 0.06
Nodes (34): ecran_validation_courses.dart, AlertDialog, _bandeauValidee, build, Card, _charger, _cocher, _contenu (+26 more)

### Community 11 - "Community 11"
Cohesion: 0.06
Nodes (28): attendre, attendreTexte, creerAssociationParLInterface, finTransition, id, main, ouvrir, restEcrire (+20 more)

### Community 12 - "Community 12"
Cohesion: 0.07
Nodes (27): AnnulationBilan, annulerVente, Bilan, Caisse, CaisseBilan, Correction, DepotCaisses, emettre (+19 more)

### Community 13 - "Community 13"
Cohesion: 0.07
Nodes (26): ecran_menus.dart, AlertDialog, build, Center, _champsType, _changer, Column, _DialogueImage (+18 more)

### Community 14 - "Community 14"
Cohesion: 0.09
Nodes (22): action, AlertDialog, build, Card, _CarteGymnase, Column, _DialogueNom, _DialogueNombre (+14 more)

### Community 15 - "Community 15"
Cohesion: 0.1
Nodes (19): dart:typed_data, dateAffichee, dateIso, dureeAffichee, Evenement, heureAffichee, libelleModes, ProduitEvenement (+11 more)

### Community 16 - "Community 16"
Cohesion: 0.1
Nodes (20): attendre, attendreTexte, changerDeSession, connexion, creerAssociationParLInterface, defilerJusqua, demainA, etape (+12 more)

### Community 17 - "Community 17"
Cohesion: 0.14
Nodes (13): attendre, attendreTexte, creerAssociationParLInterface, finTransition, main, montrer, ouvrir, restStatutDocument (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.14
Nodes (13): attendre, attendreTexte, choisirVue, creerAssociationParLInterface, finTransition, id, main, ouvrir (+5 more)

### Community 19 - "Community 19"
Cohesion: 0.17
Nodes (11): afficher, attendre, attendreUnPeu, creerAssociationParLInterface, main, ouvrir, poserVente, remettreAZero (+3 more)

### Community 20 - "Community 20"
Cohesion: 0.17
Nodes (11): detailStockAffiche, ecrireLienGymnase, FormatException, gere, Gymnase, idCaisse, LienGymnase, lireLienGymnase (+3 more)

### Community 21 - "Community 21"
Cohesion: 0.33
Nodes (5): dart:math, codeBienForme, confirmationSuppression, genererCode, normaliserCode

### Community 22 - "Community 22"
Cohesion: 0.67
Nodes (3): Produit final vs ingrédient, Recette et ingrédients (20 max), Types de produit (composé, unité, part, litre)

### Community 23 - "Community 23"
Cohesion: 1.0
Nodes (2): Publication Play Store, Recette finale et vérification par une autre IA

### Community 24 - "Community 24"
Cohesion: 1.0
Nodes (0): 

### Community 25 - "Community 25"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **768 isolated node(s):** `main`, `TestFailure`, `ouvrir`, `creerAssociationParLInterface`, `attendre` (+763 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 23`** (2 nodes): `Publication Play Store`, `Recette finale et vérification par une autre IA`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (1 nodes): `lancer.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (1 nodes): `lancer_integration.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 5` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 6`, `Community 7`, `Community 8`, `Community 10`, `Community 11`, `Community 13`, `Community 14`, `Community 16`, `Community 17`, `Community 18`, `Community 19`?**
  _High betweenness centrality (0.350) - this node is a cross-community bridge._
- **Why does `package:cloud_firestore/cloud_firestore.dart` connect `Community 0` to `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 11`, `Community 12`, `Community 16`, `Community 17`, `Community 18`, `Community 19`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `package:flutter_test/flutter_test.dart` connect `Community 0` to `Community 1`, `Community 5`, `Community 7`, `Community 11`, `Community 16`, `Community 17`, `Community 18`, `Community 19`?**
  _High betweenness centrality (0.073) - this node is a cross-community bridge._
- **What connects `main`, `TestFailure`, `ouvrir` to the rest of the system?**
  _768 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._