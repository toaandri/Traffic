# Contribuer à Traffic

Merci de partir d’un cas concret : une anomalie reproductible, une mesure incorrecte,
une interaction confuse ou une fonctionnalité dont le comportement est décrit.

## Préparer l’environnement

Suivre [l’installation du README](README.md#installation). La configuration validée
est Windows x64 avec Python 3.14, Godot 4.7.2 et SUMO 1.28.0. Les dépendances et leurs
versions sont recensées dans `requirements.lock.txt`.

## Signaler un problème

Dans une issue, indiquer :

- La version de Traffic, Windows et les composants concernés.
- Les étapes de reproduction, le résultat attendu et le résultat obtenu.
- Le scénario JSON exporté et la graine utilisée.
- Les journaux utiles de `data/logs/` ou du dossier de campagne.
- Une capture pour un problème visuel ou d’interaction.

Réduire le scénario autant que possible. Retirer les informations personnelles des
fichiers joints et ne pas joindre l’environnement `.venv` ou les exécutables.

## Proposer une modification

1. Décrire le problème et le comportement final attendu.
2. Modifier le module responsable ; consulter [l’architecture](docs/architecture.md).
3. Ajouter ou adapter des tests lorsque la logique de simulation ou de validation
   change. Pour l’IHM, vérifier le parcours concerné et le rendu aux deux résolutions.
4. Mettre à jour le guide ou les conventions de mesure si le comportement change.
5. Expliquer dans la pull request ce qui change, pourquoi et comment cela a été vérifié.

Vérifications usuelles :

```powershell
.\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider
.\.venv\Scripts\python.exe -m ruff check backend scripts/desktop_entry.py
.\.venv\Scripts\python.exe -m ruff format --check backend scripts/desktop_entry.py
```

Pour les échanges avec Godot ou les opérations de bureau, exécuter aussi la recette
`frontend/godot/tests/workflow.gd` avec le pont local démarré. Une modification de la
distribution doit être vérifiée avec `scripts/verify-portable.py` après construction.

## Conventions importantes

- SUMO calcule les déplacements ; Godot les affiche et ne modifie pas les mesures.
- Conserver une demande identique entre contrôleurs pour chaque graine.
- Séparer agents arrivés, non partis et trajets inachevés dans les résultats.
- Ne pas remplacer une moyenne indéfinie par un zéro.
- Respecter la garde commune des phases et les transitions protégées.
- Documenter les nouveaux champs de scénario et messages du protocole.
- Ne pas versionner `.venv`, `.tools`, `dist` ou les données d’exécution.

Le dépôt ne définit pas encore de licence propre au projet. Les licences des
composants tiers restent applicables ; toute décision de licence de Traffic relève
de son auteur.
