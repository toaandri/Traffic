# Démonstrations du README

Les fichiers `traffic-simulation.gif` et `traffic-network.gif` sont des captures
réelles de Traffic, sans maquette ajoutée. Ils sont versionnés pour être affichés
directement par GitHub. Les PNG intermédiaires restent dans `.tools/readme-frames/`,
exclu du dépôt.

## Contenu

| Animation | Opérations enregistrées |
|---|---|
| `traffic-simulation.gif` | Simulation de 90 véhicules et 30 piétons, contrôle adaptatif, lecture à 2×, sélection d’un véhicule et évolution des mesures. |
| `traffic-network.gif` | Sélection d’une intersection, déplacement de 25 m, annulation, rétablissement, retour à la géométrie initiale et vue de dessus. |

Résolution : **960 × 600**. Palette commune de 128 couleurs par animation.
Capture demandée à 8 images/s, encodage à 120 ms par image (résolution temporelle
du GIF de 10 ms). La capture sollicite une véritable fenêtre Godot et le rendu GPU ;
ne pas utiliser `--headless` pour enregistrer.

## Régénérer les animations

Installer d’abord Traffic depuis ses sources. Démarrer un moteur de démonstration
isolé dans un premier terminal, à la racine du dépôt :

```powershell
.\.venv\Scripts\python.exe -m traffic.cli serve --scenario data/scenarios/grid.json --port 18767 --output .tools/readme-simulation
```

Dans un second terminal :

```powershell
$env:TRAFFIC_PORT = '18767'
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --path frontend/godot --rendering-driver opengl3 --script res://tests/readme_capture.gd
```

Le script conserve le nombre exact de captures dans un manifeste. Encoder ensuite
les GIFs avec Pillow dans un environnement destiné à la documentation :

```powershell
python -m venv .tools/docs-venv
.\.tools\docs-venv\Scripts\python.exe -m pip install Pillow
.\.tools\docs-venv\Scripts\python.exe scripts/make-readme-gifs.py
```

Pillow sert uniquement à produire les médias ; ce n’est pas une dépendance de
l’application. Arrêter le moteur de démonstration avec `Ctrl+C` après la capture.

Vérifier visuellement le début, le milieu et la fin des séquences, ainsi que leur
poids, avant de remplacer les médias du dépôt. Les captures fixes se trouvent dans
`docs/screenshots/` pour les lecteurs qui préfèrent une image sans animation.
