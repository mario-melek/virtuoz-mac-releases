# Virtuoz pour Mac

Les versions Mac de Virtuoz (Apple Silicon : `Mac-arm64`, Intel : `Mac-x64`), dans l'onglet **Releases**.

Pour installer Virtuoz, le plus simple est la commande du dépôt principal :
https://github.com/mario-melek/virtuoz

## Comment une version Mac est fabriquée

Le workflow **Version Mac** (onglet Actions, « Run workflow ») part de la version Windows publiée dans
`mario-melek/virtuoz-releases` (même code, mêmes modèles) et, sur des Mac de GitHub :

1. construit `Virtuoz.app` pour chaque puce (`build/make-mac.sh`) : Electron 44.10.1 pour Mac, le code et les modèles de
   la version Windows, l'icône Bravo, la signature ad hoc (pas encore de certificat Apple) ;
2. lance l'autotest intégré de Virtuoz sur l'appli construite (`build/selftest.sh`) ;
3. avec « Publier la version » coché : publie le `.dmg`, le `.zip` et `update-manifest.json` ici ;
4. installe Virtuoz comme un membre (`install.sh` du dépôt principal) sur un Mac neuf de chaque puce, puis relance
   l'autotest sur l'appli installée.

« Tester seulement » refait l'étape 4 sur la version déjà publiée.

Les Mac Intel de GitHub sont des machines virtuelles sans carte graphique : l'export 3D de la version Intel y est
seulement signalé ; il est vérifié sous Rosetta 2 sur un Mac Apple Silicon, qui a un vrai GPU.
