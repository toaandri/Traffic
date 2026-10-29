# Algorithmes implémentés

## Réseau

La grille crée deux arcs par segment, identifiés de manière stable. La validation
vérifie les références, identifiants, positions, longueurs non nulles, connectivité
forte et croisements de segments sans nœud commun. Les chemins véhicules suivent
les connexions effectives exportées par SUMO, pour respecter les virages autorisés.
Les piétons sont routés par SUMO sur les trottoirs et les traversées générées.
La demande est déterministe et indépendante du contrôleur.
Une route peut aussi fournir une polyligne `shape` avec des points intermédiaires ;
SUMO conserve cette géométrie à l'export, tandis que la validation vérifie que ses
extrémités correspondent aux nœuds déclarés.

## Plans de feux protégés

Le réseau SUMO contient une matrice `foes` par carrefour. Ses bits se lisent de
droite à gauche, tandis que les états de feux se lisent de gauche à droite.
Le convertisseur associe chaque mouvement à son index de voie interne et regroupe
les mouvements véhicules sans conflit par une construction gloutonne déterministe.
Une association inconnue est considérée conflictuelle. Les passages piétons ont
une phase dédiée, avec tous les signaux véhicules au rouge.

Le cycle suit : vert véhicules → orange 3 s → tout-rouge 8 s ; puis les autres
groupes ; vert piétons 12 s → tout-rouge de dégagement. Le dégagement piéton est
calculé avec la longueur maximale des passages, une vitesse prudente de 1 m/s
et 2 s supplémentaires, puis arrondi à la seconde supérieure. Un carrefour
encore occupé prolonge le tout-rouge. Le garde contrôle les états à chaque pas.

Ces choix sont conservateurs pour les réseaux synthétiques du projet. Ils ne
constituent pas une validation de sécurité pour des carrefours réels ou toute
géométrie importée. La validation dynamique des traversées exige encore des essais
plus larges et des tests de cas limites, notamment les blocages de sortie.

## Contrôleurs

**Fixe** : chaque vert véhicules dure 30 s par défaut ; la durée et les bornes
peuvent être configurées par nœud. Le cycle protégé reste inchangé.

**Adaptatif** : à l’entrée d’une phase véhicules, compter les véhicules arrêtés
sur les voies entrantes servies et les piétons en attente d’une traversée du
carrefour. Recommandation : `10 + 2 × file - demandes_piétonnes`, bornée par la
politique à [10,60], puis par le garde aux bornes du nœud ([10,40] par défaut).
Les bornes configurables vont de 5 à 120 s et le vert fixe doit s’y trouver. L’adaptateur appelle
uniquement `setPhaseDuration` ; aucun saut de phase ni état de feu arbitraire.
Le minimum est 10 s, y compris sans file. Les cycles desservent tous les groupes.

Ce contrôleur simple est une baseline expérimentale à améliorer ; il ne garantit
pas un gain sur tous les scénarios. Sur le scénario de quatre carrefours vérifié,
il augmente les arrivées piétonnes mais augmente l’attente moyenne des véhicules.

**Max-Pressure** : estimer la pression d’une phase par la différence entre les
files entrantes et les files sortantes, puis ajouter la demande piétonne. La
durée recommandée reste bornée par le même garde de sécurité ; le contrôleur ne
peut donc pas modifier les états, les conflits ou les transitions protégées.
Les trois contrôleurs utilisent la même demande lors d’une comparaison.

## Profils d'agents

Les véhicules peuvent utiliser les profils `standard`, `cautious` ou `aggressive`.
Ils modifient les paramètres SUMO d'acceleration, de freinage et de variabilite
sans changer les itineraires ni les regles des feux. La vitesse de marche est
configurable entre 0,5 et 3 m/s et est appliquee aux trajets pietons.

## Événements

Une hausse de demande est programmée à un instant de simulation, appliquée au
premier pas atteignant cet instant et journalisée avec les deux temps.
Les véhicules supplémentaires utilisent une sélection déterministe des mêmes
itinéraires de référence pour chaque contrôleur. Un reset rejoue le même scénario.

Lors d'une fermeture ou d'un accident, le coût de l'arête est rendu prohibitif
avant l'appel de reroutage SUMO. Le journal de l'événement distingue les véhicules
dont l'itinéraire a réellement changé (`rerouted`) des erreurs de reroutage
(`unroutable`). Les véhicules sans chemin alternatif restent comptabilisés et ne
sont pas présentés comme une amélioration. Une fermeture doit être planifiée après
le départ des véhicules concernés ; SUMO refuse sinon les véhicules futurs dont
l'arête source devient interdite avant leur départ.

## Mesures

L’attente cumulée est l’intégrale discrète des pas où la vitesse est inférieure
à 0,1 m/s. Un arrêt correspond au passage d’un état en mouvement à un état arrêté.
Le temps de trajet utilise le pas de départ observé et l’instant d’arrivée.
L’erreur de quantification est de l’ordre du pas de simulation. Cette convention
peut différer de `waitingTime` de SUMO ; les deux ne doivent pas être assimilées.

Les moyennes d’attente et de trajet portent sur les agents arrivés. Les agents
non partis et non arrivés sont séparés et l’attente cumulée des non arrivés est
exportée. Sans arrivée, une moyenne est `null`, jamais un zéro trompeur.
Le compteur de collisions cumule les véhicules impliqués signalés par SUMO aux
pas ; ce n’est pas un décompte d’accidents uniques. Les téléportations automatiques
pour débloquer la congestion sont désactivées.

La comparaison exécute fixe, adaptatif et Max-Pressure pour chaque graine, vérifie l’identité
du fichier de demande par SHA-256, exporte un tableau par type d’agent et calcule
la moyenne entre essais ainsi que l’écart-type de l’échantillon. Le pourcentage
d’amélioration est `(fixe - adaptatif) / fixe × 100`, uniquement si les deux
moyennes existent et la référence est positive. Un résultat négatif est une
dégradation. Ce pourcentage reste soumis au biais des trajets terminés.

Sources officielles :
- [Structure et conflits SUMO](https://eclipse.dev/sumo/docs/Networks/SUMO_Road_Networks.html)
- [Piétons](https://eclipse.dev/sumo/docs/Simulation/Pedestrians.html)
- [Modification des feux via TraCI](https://eclipse.dev/sumo/docs/TraCI/Change_Traffic_Lights_State.html)
