# Forever Stuff Book (FSB)

Addon **passif** pour WoW Forever (client 1.60.1, Interface `16001`, moteur 12.x) : il analyse un objet
équipable (vert à orange) au survol et affiche un verdict dans le tooltip. **Le joueur décide et agit toujours.**

## Légalité

FSB ne fait que lire des informations et écrire des lignes dans un tooltip. Aucune action de jeu :
pas d'auto-loot/roll/pass/équipement/vente/désenchantement/achat/cast/target/mouvement, pas de simulation
d'entrées, aucun contournement de l'UI protégée. Le scan des membres du groupe utilise l'inspection native
(`NotifyInspect`, lecture seule) uniquement en donjon/raid, jamais sur des joueurs extérieurs au groupe.

## Verdicts

| Contexte | Verdicts |
|---|---|
| **Solo** (hors donjon/raid, ou instance sans groupe) | À ÉQUIPER · OFF-SPÉ — profil · VENDRE / DÉSENCHANTER |
| **Groupe** (donjon ou raid **et** groupe) | À PRENDRE · MEILLEUR POUR UN AUTRE · OFF-SPÉ — profil · CUPI |

« Meilleur pour un autre » = « d'après les données accessibles, cet objet semble un plus gros upgrade pour
un autre membre ». Le joueur reste libre. Aucun score n'est affiché.

## Installation

Copier le dossier `ForeverStuffBook/` dans `Interface\AddOns\` du client Forever. `/fsb` ouvre la configuration.
Tests en jeu à effectuer : voir [`docs/TESTS_INGAME.md`](docs/TESTS_INGAME.md).

## Commandes

`/fsb` (interface) · `on|off` · `profils` · `profil <nom>` · `auto` · `spe` · `specprofil <profil>` · `nouveau <nom>` ·
`supprimer <nom>` · `poids [<stat> <valeur>]` · `set [<valeur>]` · `inconnus` · `etat` · `aide`

## Moteur

- **Score** (interne) = Σ valeur de stat × poids du profil. Les poids par défaut sont génériques et modifiables.
  L'iLvl n'entre pas dans le score.
- **Configuration finale** : anneaux/bijoux testés dans chaque emplacement ; une 2M est comparée à main + off ;
  une arme de main gauche est ignorée si une 2M est portée ; main gauche à une main seulement si
  `CanDualWield()`.
- **Seuils** (`/fsb` → Seuils, ou `FSB.db.thresholds`) :
  - `upgradeRel` (3 %) : gain minimal relatif à l'objet remplacé, et `upgradeAbs` (1 point) ;
  - `otherMargin` (25 %) : en groupe, un autre membre doit gagner au moins 25 points de pourcentage de
    la valeur de l'objet **de plus que moi** pour déclencher « meilleur pour un autre ». Évite le verdict
    pour une petite différence.
- **Sets** : les paliers gagnés/perdus sont détectés (lecture du tooltip, format localisé) et affichés.
  Leur valeur n'est **jamais estimée** : elle ne compte dans le verdict que si l'utilisateur fixe
  `/fsb set <valeur>` (0 par défaut). Paliers illisibles = « analyse partielle ».
- **Spécialisation** : lue via l'API ; si impossible, choix manuel (Auto ou chaque spé de la classe). Un autre
  joueur dont la spé est illisible n'est **pas comparé**.
- **Cache** : par mode (SOLO/GROUPE) et type d'objet. Équipement changé → seuls les types concernés
  (et les objets de set) sont invalidés ; profil/poids/seuils → tout ; données de groupe → cache GROUPE seulement.
- **Scan de groupe** : un minuteur de 3 s actif seulement en mode groupe tant qu'un membre connecté n'est pas
  scanné ; seuls les membres présents dans l'instance (même carte, visibles, inspectables) sont inspectés.
  Un membre qui quitte est retiré du cache ; groupe dissous = cache vidé. Pas d'inspection en combat.

## Limites connues

- Les clés de stats (`ITEM_MOD_*`) sont celles du format classique, non confirmées sur Forever (`/fsb inconnus`).
- Pas de vérification que la classe peut porter l'objet (armure/arme) ni gemmes/enchantements.
- Pour les autres joueurs : double maniement supposé impossible ; poids génériques selon le rôle de leur spé
  (modifiables via `/fsb specprofil`).
- Vendre vs désenchanter n'est pas distingué.

## Architecture

```
ForeverStuffBook/
├── ForeverStuffBook(.toc|_Camelot.toc)
├── Core/        Core (événements, commandes) · Compat (seule couche d'API WoW pour l'équipement)
│                Context (solo/groupe) · Spec (spé du joueur) · Inspector (scan du groupe)
├── Data/        Stats (clés, emplacements) · Profiles (profils, poids)
├── Engine/      ScoreEngine · EquipmentOptimizer · SetBonusEngine · SpecEngine
│                VerdictEngine · ItemAnalyzer (cache + orchestration)   <- Lua pur, testable hors jeu
├── Tooltip/     Tooltip
├── UI/          Settings (/fsb, choix de spé)
├── Localization/frFR.lua
└── Utils/Utils.lua
tests/           luajit tests/run_all.sh
```

Engine/ ne dépend pas de l'API WoW : réutilisable pour une future extension « LootMaster » (hors périmètre V1).
