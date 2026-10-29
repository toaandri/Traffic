# Vérification de Traffic 1.0 — 12 octobre 2026

17 tests Python réussis. Analyse Ruff, formatage et dépendances vérifiés.
Godot : édition, annuler/rétablir, configuration appliquée, sauvegarde dans la
bibliothèque, inspection, export et comparaison réellement vérifiés par scripts.
Les tests de parcours complet ont identifié puis fait corriger les erreurs de
tâche non remontées à l’interface. Les sous-processus sont testés hors des
restrictions du bac à sable de l’agent, dans les conditions normales de l’application.

L’exécutable Windows assemblé a exécuté une simulation SUMO réelle de 30 pas,
soit 15 secondes simulées avec le scénario de quatre carrefours. Les diagnostics
et résultats se trouvent dans son dossier `data`.
Le backend et le pack Godot de la distribution ont aussi passé le parcours complet
de l’IHM (`TRAFFIC_PORTABLE_OK`), une comparaison de deux essais et le démarrage/arrêt
privés (`--self-test`). Aucun module du backend source n’est utilisé par ces exécutables.

## Interface et performance

Captures examinées à 1440×900 et 1100×740, dans `docs/screenshots`. Une erreur de
retour à la ligne du titre et un contraste insuffisant des textes de l’inspecteur
ont été corrigés. Les panneaux latéraux défilent sans recouvrir le viewport.

Sur NVIDIA GeForce RTX 2060, OpenGL 3.3, test en fenêtre cachée 1440×900 :
601 images en 10,02 secondes, 60 FPS avec plafond à 60 ; jusqu’à 109 véhicules et
40 piétons. Données : `docs/screenshots/performance.json`. Le test ne mesure pas
toutes les configurations possibles ni les ordinateurs sans GPU dédié.

## Campagne comparative

`crossing_lab.json`, 4 carrefours, 30 véhicules, 12 piétons, 180 s, pas 0,5 s,
graines 42/43/44. Six essais et contrôle d’identité des demandes exécutés.

| Moyenne entre essais | Fixe | Adaptatif |
|---|---:|---:|
| Véhicules arrivés | 29,33 / 30 | 29,67 / 30 |
| Piétons arrivés | 8 / 12 | 9,67 / 12 |
| Attente moyenne des véhicules arrivés | 25,07 s | 32,49 s |
| Attente moyenne des piétons arrivés | 10,15 s | 6,25 s |

Dans ce cas, l’attente véhicules augmente d’environ 29,6 % avec l’adaptatif,
tandis que les piétons sont mieux desservis. Cela illustre le compromis ; ce n’est
pas une preuve de supériorité générale. Les arrivées et non arrivés sont exportés.
Le rapport est dans `data/results/release-comparison/report.html` avec CSV/JSON.

## Résistance et mesures

Campagne `data/results/release-stress` : trois charges 30/100/250 véhicules,
4/9 carrefours, hausse de demande et deux contrôleurs pour la graine 42.
`worst-scenario.json` conserve le cas le plus défavorable. L’absence d’arrivées
sur une charge forte ne donne pas une amélioration fictive : la moyenne reste nulle
au sens JSON `null`, et les non arrivés sont comptabilisés.

Les permissions des trottoirs sont vérifiées après réouverture de route. Les temps
d’attente et de trajet sont recalculés indépendamment depuis les journaux bruts
et comparés aux résumés. Les hausses de piétons et les débits explicites sont testés.

## Reproduire

### Refonte IHM du 13 octobre 2026

Captures vérifiées à 1440 × 900 et 1100 × 740, incluant la fenêtre de configuration.
Le parcours de recette couvre aussi l’explorateur sélectionnable, l’ouverture des
réglages et leur fermeture après application, puis édition, sauvegarde, inspection,
export et comparaison. La recette de l’application portable est exécutée sur le
paquet Godot exporté avec le moteur Python embarqué.

Mesure après ajout de l’anticrénelage : environ 60 FPS, plafond de 60, sur dix
secondes, avec jusqu’à 110 véhicules et 40 piétons visibles à 1440 × 900, NVIDIA
RTX 2060. Le fichier `docs/screenshots/performance.json` contient la mesure exacte.
Ce résultat décrit cette machine et ce scénario ; il ne constitue pas une garantie
sur toutes les configurations.

```powershell
.\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider
.\.venv\Scripts\python.exe -m ruff check backend scripts/desktop_entry.py
.\.venv\Scripts\python.exe -m traffic.cli compare --scenario data/scenarios/crossing_lab.json --seeds 42 43 44 --output data/results/reproduction
.\.venv\Scripts\python.exe -m traffic.cli serve
# Dans un autre terminal :
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path frontend/godot --script res://tests/workflow.gd
```

L’accès au magasin des certificats Windows est refusé dans certains tests
restreints, sans impact sur le pont local non TLS. Les simulations ne constituent
pas une certification de sécurité routière ni une validation terrain.

