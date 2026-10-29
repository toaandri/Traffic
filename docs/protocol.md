# Protocole local v1

WebSocket `ws://127.0.0.1:8765`, JSON UTF-8, messages limités à 1 Mio.
Le service partage un scénario entre les clients. Toute commande possède
`protocol_version: 1` et `command`.

| Commande | Données | Effet |
|---|---|---|
| `play`, `pause` | — | Avancer ou suspendre l’horloge |
| `reset` | — | Nouvelle session, scénario identique, pause |
| `speed` | `value`: 0.5, 1, 2 | Cadence d’affichage |
| `configure` | `scenario`: modèle complet | Valider, exporter, remplacer en pause |
| `generate` | `rows`, `columns`: entiers 2–6 | Remplacer le réseau par une grille |
| `save`, `load` | — | Fichier local `data/scenarios/saved.json` |
| `export` | — | Export des mesures dans un nouveau dossier |
| `compare` | `seeds`: liste optionnelle, 1–10 graines | Campagne fixe/adaptatif |

Le serveur envoie `network` et `snapshot` à la connexion et après remplacement.
`network` comprend `network`, `scenario`, `geometry` (formes des passages et feux).
`snapshot` comprend temps, contrôleur, fin d’essai, véhicules, piétons, feux,
mesures instantanées, résumé des trajets et événements appliqués.
Les coordonnées sont en mètres, le temps en secondes simulées, les vitesses en m/s.
Chaque feu fournit son état SUMO, l’index de phase et la décision de durée.

`error` / `notice` : message lisible. Une configuration invalide conserve la session.
`comparison` : agrégats, amélioration relative éventuelle, graines et dossier d’export.
Le reset et les changements de paramètres placent le moteur en pause. Une comparaison
suspend d’abord la session affichée et exécute des essais indépendants sans rendu.
Le client 1.0 se reconnecte toutes les deux secondes et recharge l’état courant.

Commandes ajoutées : `new`, `catalog`, `save_project` (scénario et id optionnel),
`load_project` (id), `import` (scénario), `validate` (scénario), `example` (nom),
`stress` (graines), `cancel_comparison`. `shutdown` requiert le secret du lanceur.
Les réponses `saved`, `catalog`, `validation`, `progress` et `status` explicitent
le résultat et l’état de l’application. Une panne d’une tâche remet l’IHM en état
utilisable au lieu de laisser un indicateur bloqué.
