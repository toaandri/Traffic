# Installation locale vérifiée

## Version 1.0 du 12 octobre 2026

La version portable se lance avec `dist/Traffic/Traffic.exe` et contient son runtime
Python, SUMO, netconvert et le moteur Godot. Les export templates Godot ne sont pas
nécessaires à ce paquet : l’interface est exportée en pack de ressources, exécuté
avec le moteur standard livré. Conserver tout le dossier pour le déplacer.

Le code source se lance avec `Lancer Traffic.cmd`. Pour reconstruire : installer
les dépendances de compilation avec `pip install '.[build]'`, puis exécuter
`scripts/build-release.ps1`. PyInstaller 6.22.3 est épinglé. Le profil utilisateur
du paquet et les données sont conservés dans son dossier `data`.

Les paragraphes ci-dessous décrivent l’installation initiale du socle.

Installation effectuée le 08 octobre 2026 dans ce projet, sans installation système
globale ni service cloud. Python 3.14.2 x64 était déjà présent sur la machine.

| Composant | Version | Emplacement |
|---|---|---|
| Godot standard | 4.7.2 stable | `.tools/godot` |
| Python | 3.14.2 | Interpréteur système ; environnement `.venv` |
| SUMO, netconvert | 1.28.0 | Distribution eclipse-sumo dans `.venv` |
| TraCI / sumolib | 1.28.0 | `.venv` |
| Pydantic | 2.14.0 | `.venv` |
| NetworkX | 3.7 | `.venv` |
| websockets | 17.2 | `.venv` |
| pytest | 9.1.1 | `.venv` |
| Ruff | 0.16.10 | `.venv` |

Toutes les dépendances transitives sont recensées dans `requirements.lock.txt`.
Ce lock correspond à Windows x64 et Python 3.14 ; une migration d’interpréteur
ou de plateforme nécessite une nouvelle validation des versions.

## Réinstallation sur une autre machine

1. Installer Python 3.14 x64.
2. Ouvrir PowerShell dans le dossier du projet.
3. Exécuter `.\scripts\setup.ps1` pour les dépendances Python et SUMO.
4. Exécuter `.\scripts\install-godot.ps1` pour Godot portable.
5. Exécuter `.\.venv\Scripts\python.exe -m traffic.cli generate` si aucun scénario n’existe.
6. Utiliser les scripts de lancement décrits dans le README.

Le téléchargement Godot est dirigé vers le site officiel. Le script compare
l’empreinte SHA-256 à celle de l’archive téléchargée lors de cette installation,
puis extrait le moteur. Cette empreinte sert à reproduire le téléchargement ; elle
ne constitue pas une vérification indépendante par signature de l’éditeur.
Le fichier `_sc_` active le mode autonome de Godot afin de conserver ses données
d’éditeur dans `.tools/godot/editor_data`.

Sources : [SUMO](https://eclipse.dev/sumo/docs/Downloads.html),
[Godot Windows](https://godotengine.org/download/windows/).

## Dépendances ultérieures

Blender est facultatif pour créer des modèles. Les boîtes du prototype n’en ont pas
besoin. Les bibliothèques RL sont réservées à l’extension recherche du cahier des
charges. Les export templates Godot seront nécessaires pour livrer un exécutable
autonome, mais pas pour ouvrir l’éditeur ou lancer ce projet depuis le moteur portable.
