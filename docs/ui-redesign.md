# Atelier Traffic : refonte de l’interface

## Références consultées le 13 octobre 2026

- [SUMO GUI](https://eclipse.dev/sumo/docs/sumo-gui.html) : commandes de lecture, inspection des objets et coloration des voies suivant une mesure.
- [PTV Vissim, menus](https://cgi.ptvgroup.com/vision-help/VISSIM_2026_EN-DE/en-us/Content/2_Programmbedienung/Menues_Uebersicht.htm) : commandes regroupées par métier, édition de réseau et analyse dans le même atelier.
- [QGIS, interface](https://docs.qgis.org/4.2/en/docs/user_manual/introduction/qgis_gui.html) : carte centrale, navigateur, panneaux et barre d’état.

Ces références servent aux conventions d’interaction, sans reproduire leur identité ou leurs ressources graphiques.

## Direction retenue avant réalisation

Une application de bureau pour construire, observer et comparer un réseau routier. La carte est le document de travail. Les réglages volumineux quittent le panneau permanent pour une fenêtre de configuration ; les objets, la sélection et les mesures restent visibles.

Palette : papier #F7F9FB, chrome #E4E9EF, encre #243746, bleu opérationnel #23649A, véhicule #2585B5, piéton #C67B29. Routes gris ardoise, parcelles vert grisé, bâtiments peu saturés. Le rouge et le vert indiquent des états réels des feux, pas la décoration.

Typographie : Segoe UI, choisie pour l’application Windows et ses contrôles ; 13 px pour les propriétés, 14 px pour les commandes, 17 px pour les titres de panneaux. Nombres accompagnés de leur unité. Alignement à gauche.

```
Projet / commandes                 nom du scénario / connexion
Réseau | Simulation | Expériences        lecture / vitesse / temps
┌ navigateur ┬──────────────────────────────┬ sélection ┐
│ objets     │ carte / outils de vue         │ propriétés│
│ scénario   │ routes, agents, feux          │ mesures   │
│ outils     ├ analyse : attente / comparaison│           │
└────────────┴──────────────────────────────┴───────────┘
Message de l’opération                              performance
```

Révision critique : de grands blocs de chiffres et des formulaires permanents auraient conservé l’aspect de tableau de bord rejeté. On retient des panneaux ajustables, des lignes de propriétés compactes, une arborescence réellement sélectionnable et des outils explicitement nommés. Pas de gradients, d’animations d’entrée ou de données décoratives. Le bâti et les marquages sont procéduraux et servent à lire l’espace ; SUMO reste la source des mesures.
