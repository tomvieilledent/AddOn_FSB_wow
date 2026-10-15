# Contribuer à Forever Stuff Buddy

FSB est 100 % open source (licence MIT, voir `LICENSE`). Fork, modifie, propose une amélioration.

## Règles du projet
- **Addon passif** : aucune action de jeu (loot, roll, vente, équipement, cast...), aucun contournement de l'UI protégée.
  Voir `docs/COMPLIANCE.md`.
- **Zéro hallucination d'API** : n'utilise une API WoW que si elle existe sur WoW Forever. Vérifie-la avec `/fsb sonde`
  ou `/fsb rapport`, puis consigne le résultat dans `docs/TECHNICAL_TRUTH.md`. Ce qui n'est pas vérifié va dans
  `docs/UNVERIFIED.md` et ne doit pas être supposé.
- Commits au format **Conventional Commits** (`feat:`, `fix:`, `docs:`...).

## Structure
```
ForeverStuffBuddy/
├── Core/          événements, commandes, Compat (seule couche d'API WoW), contexte, spé, inspection, journal, sonde
├── Data/          stats (clés ITEM_MOD_*), poids par classe/arbre/mode (Weights), profils, arbres de talents (Classes),
│                  équipement utilisable par classe (Equipment)
├── Engine/        score, optimiseur d'équipement et combinaisons d'armes, sets, verdicts, analyseur + cache (Lua pur)
├── Tooltip/       affichage du verdict
├── UI/            fenêtre /fsb (onglets Accueil, Détection, Commandes, Réglages)
├── Localization/  frFR.lua, enUS.lua
└── Utils/
tests/             tests hors jeu (luajit ou Lua 5.1)
docs/              audit, vérité technique, registre des incertitudes, décisions
```

## Tester
Hors jeu : `sh tests/run_all.sh` (luajit par défaut ; autre interpréteur 5.1 : `LUA=lua5.1 sh tests/run_all.sh`).
Ces tests simulent l'API WoW : ils valident la logique, pas la compatibilité avec le client.
En jeu : `/fsb rapport` produit tout le diagnostic dans une fenêtre à copier ; l'onglet Détection de `/fsb` montre la
classe, la spé, le rôle, le mode et les poids utilisés.

## Cas courants
- **Ajouter une langue** : crée `Localization/xxXX.lua` (copie `enUS.lua`), ajoute-le au `.toc`, déclare le code dans
  `FSB.SetLanguage`/l'interface. `tests/locale.lua` vérifie que toutes les clés sont traduites.
- **Ajouter une stat** : ajoute-la dans `Data/Stats.lua` (`KEYS`) et ses traductions (`STATS` dans chaque langue) ;
  pour lui donner un poids, ajoute une colonne dans `Data/Weights.lua` (`COLUMNS`) et une valeur dans chaque ligne.
- **Ajuster les poids** : `Data/Weights.lua` — une ligne de 36 valeurs par classe, arbre et mode (ordre de `COLUMNS`,
  identique au tableau de référence). `tests/roles.lua` vérifie que chaque ligne est complète.
- **Rôle affiché d'une spé** : `Weights.ROLE_INFO` (rôle · type · portée).
- **Équipement par classe** : `Data/Equipment.lua` (armures, armes, niveau minimal, ambidextrie).
- **Ajouter une classe ou un arbre de talents** : `Data/Classes.lua`, puis ses lignes de poids et ses traductions
  (`CLASS_NAMES`, `TREE_NAMES`, `LOW_ROLES`).
