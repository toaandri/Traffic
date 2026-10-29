# Guide utilisateur de Traffic 1.0

## Démarrer

Ouvrir `dist/Traffic/Traffic.exe` : le moteur local et l’interface démarrent ensemble.
Conserver tout le dossier Traffic, pas seulement son exécutable. Aucun compte ni
Internet n’est nécessaire après installation. Dans le code source, double-cliquer
sur `Lancer Traffic.cmd`. Une erreur de démarrage indique le dossier de journaux.

La fenêtre peut être redimensionnée jusqu’à 1100 × 740. Les panneaux latéraux
et l’analyse sont redimensionnables par leurs séparateurs. Le panneau de mesures
défile indépendamment ; la ville conserve son espace. La connexion est locale
et se rétablit automatiquement si elle est interrompue.

L’explorateur à gauche liste intersections et routes ; sa recherche filtre les
objets et un clic affiche leurs propriétés à droite. Réseau active les outils
d’édition. Paramètres ouvre la configuration ; Configurer le scénario ouvre
directement Simulation. Appliquer et réinitialiser se trouve au pied de cette
fenêtre. Fermer conserve les saisies locales. Les menus Projet, Édition et
Résultats regroupent les commandes.

## Construire une ville

Dans Paramètres > Réseau, générer une grille avec dimensions, espacement et densité. La densité
est limitée par la conservation de la connectivité et d’au moins deux connexions
par nœud : elle peut rester supérieure à la valeur demandée.

Pour dessiner : ajouter des nœuds au sol, puis Relier et cliquer sur deux nœuds.
Les routes créées sont bidirectionnelles. Un nœud posé au milieu d’une route
divise automatiquement ses deux directions. Déplacer utilise un clic sur le nœud
puis un clic sur la destination. Annuler et Rétablir parcourent les 50 dernières
modifications. L’alignement est de 25 mètres.

Sélectionner un nœud pour modifier les voies des routes qui en partent, leur vitesse
et ses temps de vert fixe/minimal/maximal. Les phases protégées sont calculées
automatiquement : véhicules et piétons sont séparés, les transitions restent imposées.
Les trottoirs accompagnent les routes. Les traversées peuvent être générées ou
ajoutées au nœud sélectionné ; le bouton manuel traverse sa première branche.

Valider signale les identifiants incohérents, routes isolées, doublons de position
et croisements sans carrefour. Appliquer exporte le réseau et crée une nouvelle
session en pause. Une erreur laisse la session précédente disponible.

## Configurer et observer

Dans Configurer le scénario > Simulation, indiquer nom, description, populations, durée, pas et graine.
Les débits peuvent être explicites en agents/heure ; zéro utilise la répartition
automatique. Les agents programmés après la durée de l’essai restent non partis
dans les résultats. Le profil Heure de pointe concentre les départs.

Les origines/destinations sont des routes ; Répartition automatique varie les
trajets avec la graine. Un choix explicite est utilisé pour les deux types d’agents.
Choisir fixe ou adaptatif, puis Appliquer. Démarrer valide d’abord toute modification
locale. Pause suspend l’horloge ; Réinitialiser recharge les mêmes conditions.
La vitesse 0,5×/1×/2× ne change pas les résultats calculés au même temps simulé.

3D et Plan utilisent une projection orthographique. Perspective utilise
une projection perspective. Molette : zoom ; clic droit : rotation ; clic milieu :
déplacement. Cliquer sur un agent ou un carrefour ouvre son état dans l’inspecteur.
Cadrer retrouve l’ensemble du réseau après un déplacement ou un zoom.
Congestion colore les routes chargées en ambre, les routes fermées en rouge.
V/P résument les groupes servis au carrefour ; un vert V ne libère pas toutes ses voies.

## Événements

Programmer une hausse de véhicules/piétons, une fermeture ou un accident, avec
instant et durée. Ajouter/supprimer des événements modifie le scénario local :
appliquer avant le lancement. Les fermetures bloquent les nouvelles entrées et
demandent un reroutage ; les trajets sans alternative sont journalisés. Un accident
immobilise les véhicules présents sur la route. La réouverture restaure leurs
vitesses et les permissions des voies. Les événements sont rejoués après reset.

## Projets et sauvegardes

Enregistrer stocke le scénario dans la bibliothèque locale. Dupliquer crée un
nouvel identifiant. Les projets se rouvrent par double-clic dans Expériences.
Projet > Ouvrir importe un JSON ; Projet > Exporter le projet JSON exporte le scénario vers le fichier choisi.
Le schéma est versionné et validé. Un fichier corrompu n’est pas exécuté.
Les changements locaux sont conservés en brouillon après une seconde ; Reprendre
le brouillon permet aussi de réparer un réseau qui n’est pas encore valide.

## Expériences et rapports

Appliquer le scénario, choisir un nombre de graines puis Lancer la comparaison.
Chaque graine exécute fixe et adaptatif avec les mêmes entrées. Un indicateur montre
le calcul ; l’annulation conserve les données partielles sans annoncer une campagne
réussie. L’historique permet de consulter les campagnes passées et leur dossier.

La Campagne de résistance teste 4/9 carrefours et 30/100/250 véhicules, avec
une hausse de demande, pour chaque graine choisie. Le pire scénario est conservé.
Pour une grande campagne, préférer un nombre de graines limité et surveiller l’espace
disque : les journaux bruts conservent les états par pas.

Exporter fournit CSV/JSON, résumé, trajets et décisions. Une campagne comprend aussi
un rapport HTML lisible dans un navigateur hors ligne, versions et intervalles
exploratoires. Les journaux `raw.jsonl` et `tripinfo.xml` restent dans les dossiers
d’exécution. Capture enregistre une image de la ville dans le profil local.

Les moyennes concernent les agents arrivés. Comparer aussi non partis, non arrivés,
arrêts, blocages et attente des trajets inachevés. « — » signifie qu’aucune moyenne
n’est disponible. Un pourcentage négatif indique une dégradation.

## Raccourcis et dépannage

Espace : démarrer/pause ; Ctrl+S : enregistrer ; Ctrl+O : importer ;
Ctrl+Z / Ctrl+Y : annuler/rétablir ; F1 : aide. Le focus clavier des boutons est visible.
Les flèches règlent rotation et zoom quand un champ de texte n’a pas le focus.

Les journaux sont dans `data/logs` pour le lanceur et `data/generated` pour les essais.
En cas d’écriture refusée, déplacer tout le dossier portable vers un emplacement
accessible en écriture. En cas de disque plein, exporter les résultats à conserver
avant de nettoyer les anciennes campagnes. Le rendu compatible OpenGL exige un GPU
prenant en charge OpenGL 3.3. Les résultats sont ceux d’un modèle de simulation,
sans validation terrain ni garantie de sécurité routière réelle.
