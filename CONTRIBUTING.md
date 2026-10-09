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
├── Data/          stats (clés ITEM_MOD_*), profils et poids, classes/arbres de talents
├── Engine/        score, optimiseur d'équipement, sets, verdicts, analyseur + cache (Lua pur, testable hors jeu)
├── Tooltip/       affichage du verdict
├── UI/            fenêtre /fsb (onglets Accueil, Réglages, Commandes, Stats)
├── Localization/  frFR.lua, enUS.lua
└── Utils/
tests/             tests hors jeu (luajit)
docs/              audit, vérité technique, registre des incertitudes, décisions
```

## Tester
Hors jeu (nécessite `luajit`) : `sh tests/run_all.sh`. Ces tests simulent l'API WoW : ils valident la logique, pas la
compatibilité avec le client. En jeu : `/fsb rapport` produit tout le diagnostic dans une fenêtre à copier.

## Cas courants
- **Ajouter une langue** : crée `Localization/xxXX.lua` (copie `enUS.lua`), ajoute-le au `.toc`, déclare le code dans
  `FSB.SetLanguage`/l'interface. `tests/locale.lua` vérifie que toutes les clés sont traduites.
- **Ajouter une stat** : ajoute-la dans `Data/Stats.lua` (`KEYS`) et ses traductions (`STATS` dans chaque langue), puis ses
  poids dans `Data/Profiles.lua`.
- **Ajuster les poids** : `Data/Profiles.lua`. Les poids sont fixes et indicatifs ; l'onglet Stats sert à les relire.
- **Ajouter une classe ou un arbre de talents** : `Data/Classes.lua`.
