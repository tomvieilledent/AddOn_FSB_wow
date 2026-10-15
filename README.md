<p align="center"><img src="assets/logo.png" alt="Forever Stuff Buddy" width="220"></p>

# Forever Stuff Buddy (FSB)

Développé par **Koga / Fitaxal**. Projet 100 % open source (licence MIT, voir `LICENSE` et `CONTRIBUTING.md`).

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

Copier le dossier `ForeverStuffBuddy/` dans `Interface\AddOns\` du client Forever. `/fsb` ouvre la configuration.
Tests en jeu à effectuer : voir [`docs/TESTS_INGAME.md`](docs/TESTS_INGAME.md).

## Commandes

`/fsb` (interface : onglets Accueil, Détection, Commandes, Réglages ; langue FR/EN) · `/fsbpve` · `/fsbpvp` ·
`on|off` · `lang fr|en` · `ours|felin` (druide farouche) · `poids` · `inconnus` · `etat` · `rapport` (tout le diagnostic) ·
`log` · `mauvais [texte]` · `debug` · `sonde` · `specs` · `aide`
(les sorties d'information s'ouvrent dans une fenêtre copiable)

## Profils et détection

- **Poids par classe × arbre de talents × mode** (`Data/Weights.lua`, valeurs indicatives à valider) : 9 classes,
  27 spés, modes **Leveling 10–59**, **PvE 60** et **PvP**. Sous le niveau 10 (pas de spé) : un profil par classe,
  **Leveling 1–9** ou **Donjons bas niveau** (en donjon/raid).
- **Spé = arbre de talents le plus investi**, détectée automatiquement, sans aucune question. Égalité : l'arbre déjà
  détecté est gardé ; aucun point : dernier arbre connu de la classe, sinon le premier.
- **Style de jeu PvE / PvP** : choisi par le joueur (page d'accueil, `/fsbpve`, `/fsbpvp`), sans effet sous le niveau 10.
- **Druide farouche** : seul cas où un choix est demandé — **ours** (tank) ou **félin** (DPS), une fois, modifiable dans
  l'onglet Détection ou avec `/fsb ours` / `/fsb felin`. Les poids « ours » sont provisoires (copie des poids félin).
- **Onglet Détection** : classe, spé analysée (points par arbre), rôle (rôle · type · portée), niveau, mode, lieu,
  profil utilisé et poids des stats, pour vérifier ce que FSB a compris.

## Moteur

- **Score** (interne) = Σ valeur de stat × poids du profil. Poids fixes (non modifiables en jeu).
  L'iLvl n'entre pas dans le score. Toucher/critique/hâte génériques = la plus forte valeur mêlée/distance.
- **Configuration finale** : anneaux/bijoux testés dans chaque emplacement.
- **Armes et sacs** : pour une arme ou une main gauche, FSB cherche la meilleure combinaison des deux mains avec les
  armes **du sac** (2M seule, main droite + meilleure main gauche, main gauche + meilleure main droite) et la compare
  aux mains actuelles. Le tooltip indique l'arme à associer (« dans ton sac » / « change de main ») et ce qui est
  remplacé. Arme en main gauche seulement avec l'ambidextrie (`CanDualWield()`).
- **Utilisabilité** : lignes rouges du tooltip + table Classic de l'équipement par classe (`Data/Equipment.lua` :
  armures, armes, plaques/mailles au niveau 40, bouclier, ambidextrie). Une arme dont seule la **compétence** manque
  (type d'arme en rouge) reste analysée, avec « Compétence à apprendre chez un maître d'armes ».
- **Seuils** (fixes, non réglables en jeu) : `upgradeRel` (3 %) et `upgradeAbs` (1 point) = gain minimal pour « à équiper » ;
  `otherMargin` (25 %) : en groupe, un autre membre doit gagner au moins 25 points de pourcentage de la valeur de l'objet
  de plus que moi pour « meilleur pour un autre » (évite le verdict pour une petite différence).
- **Sets** : les paliers gagnés/perdus sont détectés (lecture du tooltip, format localisé) et affichés. Leur valeur n'est
  **jamais estimée** : ils ne changent pas le verdict. Paliers illisibles = « analyse partielle ».
- **Autres joueurs** : leur arbre n'est pas lisible ; ils sont comparés avec la moyenne des arbres de leur classe pour
  leur rôle (rôle unique de la classe, ou HEALER/TANK explicite du groupe), dans le mode de leur niveau. Un membre
  dont la classe ne peut pas porter l'objet (table Classic) est écarté. Rôle ambigu = **pas comparé**.
- **Équité du loot (donjon)** : FSB compte passivement l'équipement reçu par chaque joueur du groupe dans l'instance
  (lecture du message de butin du chat). Pour « meilleur pour un autre », le seuil d'un joueur varie de 8 points de
  pourcentage par objet d'écart avec moi (borné 5 %–60 %) : un joueur déjà servi doit justifier un plus gros upgrade
  sans être exclu. Remis à zéro à chaque instance ; désactivable dans `/fsb` → Réglages. Voir `docs/UNVERIFIED.md`.
- **Cache** : par mode (SOLO/GROUPE) et type d'objet. Équipement changé → seuls les types concernés
  (et les objets de set) sont invalidés ; sacs changés → verdicts d'armes ; profil/poids/seuils → tout ;
  données de groupe → cache GROUPE seulement.
- **Scan de groupe** : un minuteur de 3 s actif seulement en mode groupe tant qu'un membre connecté n'est pas
  scanné ; seuls les membres présents dans l'instance (même carte, visibles, inspectables) sont inspectés.
  Un membre qui quitte est retiré du cache ; groupe dissous = cache vidé. Pas d'inspection en combat.

## Limites connues

- Les clés de stats (`ITEM_MOD_*`) sont celles du format classique, en partie non confirmées sur Forever
  (`/fsb inconnus`), notamment toucher/critique/hâte des sorts.
- Poids indicatifs (estimations à valider) ; poids « ours » provisoires ; pas de colonne Dégâts Sacré.
- La table d'équipement par classe est la référence Classic : si Forever a changé une règle, elle peut écarter un objet
  portable. Les compétences d'armes à apprendre ne sont connues que par le tooltip.
- Pas de gemmes/enchantements. Combinaisons d'armes : seulement celles qui contiennent l'objet survolé ; les sacs des
  autres joueurs ne sont pas lisibles (pour eux, double maniement supposé impossible).
- Vendre vs désenchanter n'est pas distingué.

## Architecture

```
ForeverStuffBuddy/
├── ForeverStuffBuddy(.toc|_Camelot.toc)
├── Core/        Core (événements, commandes) · Compat (seule couche d'API WoW pour l'équipement)
│                Context (solo/groupe, mode, lieu) · Spec (spé par les talents) · Inspector (scan du groupe)
├── Data/        Stats (clés, emplacements) · Weights (poids par classe/arbre/mode) · Profiles (profils)
│                Classes (arbres de talents) · Equipment (équipement utilisable par classe)
├── Engine/      ScoreEngine · EquipmentOptimizer (dont combinaisons d'armes) · SetBonusEngine · SpecEngine
│                VerdictEngine · ItemAnalyzer (cache + orchestration)   <- Lua pur, testable hors jeu
├── Tooltip/     Tooltip
├── UI/          Settings (/fsb : Accueil, Détection, Commandes, Réglages ; question ours/félin)
├── Localization/frFR.lua · enUS.lua
└── Utils/Utils.lua
tests/           sh tests/run_all.sh (luajit, ou LUA=lua5.1)
```

Engine/ ne dépend pas de l'API WoW : réutilisable pour une future extension « LootMaster » (hors périmètre V1).
