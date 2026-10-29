# Recette et périmètre livré — 12 octobre 2026

Le livrable est le noyau L3 du cahier des charges, complété par plusieurs fonctions
avancées. Les éléments marqués Extension dans le document initial ne font pas partie
de cette version : apprentissage par renforcement, transports publics et données
géographiques réelles. Les limites restantes sont explicites ci-dessous.

| Exigences | Livraison / preuve |
|---|---|
| F-001–005, F-007 | Nouveau, métadonnées, bibliothèque, duplication, JSON versionné, trois exemples |
| F-010–012, F-015–018 | Nœuds/routes, déplacements, suppression, insertion sur segment, trottoirs/traversées, durées protégées et origines/destinations |
| F-030–034, F-036 | Validation graphe/géométrie/références et garde des phases ; réseau invalide refusé |
| F-040–043, F-046–047 | Grille dimensions/espacement/densité, graine locale, connectivité maintenue, édition après génération |
| F-050–056 | SUMO : demandes, itinéraires, positions/vitesses/freinage, distances et files ; modèles simples 3D |
| F-070–077 | Demande piétonne, trottoirs, passages protégés, observations, temps et capsules |
| F-090–096, F-100 | Plans sans mouvements incompatibles, bornes de durée, orange et dégagement, fixe/adaptatif, plugin et inspecteur |
| F-110–114, F-116, F-119–120 | Rendu 3D séparé, trois caméras, pause/reprise/reset, vitesses, feux, statistiques, espaces distincts |
| F-130, F-133, F-137 | Profil pointe, événements pour véhicules/piétons, restauration du scénario |
| F-140–149, F-153 | Attente/trajet des deux types, files/arrêts/débit observé, graphiques, comparaison équitable, CSV/JSON et non arrivés |
| Fonctions avancées livrées | Voies/vitesses, annuler/rétablir, incidents, reroutage, inspection, congestion, captures, raccourcis, historique, campagnes sans rendu et résistance |

## Critères T-01 à T-16

| Critère | Vérification |
|---|---|
| T-01 | Catalogue : sauvegarde/relecture égales, parcours IHM complet |
| T-02 | Nœud isolé rejeté par tests et validation locale |
| T-03 | Génération déterministe, y compris densité/seed |
| T-04 | Simulations SUMO exécutées, compteur de collisions ; règles confiées à SUMO |
| T-05 | Piétons en mouvement, phases séparées et campagnes SUMO avec traversées dans le réseau simple |
| T-06 | Matrice de conflits et vérification à chaque pas, cas incompatibles rejetés |
| T-07 | Test de pause/reprise du pont, rendu synchronisé par états |
| T-08 | Reset à temps zéro et même scénario ; répétition identique des états déterministes |
| T-09 | Six essais fixe/adaptatif, demandes identiques, exports CSV/JSON/HTML |
| T-10 | Cas de résistance 30/100/250 véhicules, densités et populations réglables |
| T-11 | Tests de hausse de véhicules et piétons avec temps journalisé |
| T-12 | Campagne de trois graines et agrégation ; écart-type et intervalle normal exploratoire |
| T-13 | Configuration invalide conserve la session ; erreurs de tâche ne bloquent plus le calcul |
| T-14 | Moyennes de trajet/attente recalculées indépendamment depuis raw.jsonl |
| T-15 | Test GPU : 60 FPS plafonnés sur 10 s, jusqu’à 109 véhicules et 40 piétons, RTX 2060, 1440×900 |
| T-16 | Campagne de résistance réelle ; pire scénario sauvegardé et relançable |

## Limites de recette

Les tests automatisés portent sur des réseaux simples et ne certifient pas tous
les cas de saturation des traversées ou de blocage interne. Le débit par intersection
est observé par changement d’arête interne ; un pas trop grand peut manquer un
franchissement. Les erreurs de quantification des temps dépendent du pas.
Les intervalles normaux sur peu de graines sont exploratoires, sans promesse de couverture.

Restent en évolution : routes courbes/irrégulières, sélection multiple/alignement
avancé, restrictions fines de virage, Max-Pressure véritable, coordination de feux,
personnalités de conduite et dispositifs d’accessibilité avec lecteurs d’écran.
L’IHM a été vérifiée à 1440×900 et 1100×740 ; l’essai GPU est réalisé dans une fenêtre
de test cachée et ne remplace pas un benchmark sur chaque ordinateur.

L’application portable Windows est assemblée avec le moteur Godot standard et un
pack de ressources. Elle n’est pas signée avec un certificat éditeur et n’inclut
pas d’installateur système ; elle se lance dans son dossier sans Python installé.

