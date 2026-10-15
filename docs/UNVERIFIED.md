# UNVERIFIED — registre des incertitudes

Existence des API confirmée le 2026-10-07 (voir TECHNICAL_TRUTH). Reste à confirmer : retours, clés, couleurs, valeurs « secrètes ».
Tout est à confirmer via `/fsb sonde` (voir `docs/SONDE.md`) puis déplacé dans `TECHNICAL_TRUTH.md`.
Next action : API SPECIALIST pour chaque ligne, après récupération de la sortie de la sonde.

| Élément | Utilisé par | Question | Impact si faux |
|---|---|---|---|
| `C_Item.GetItemStats` + clés `ITEM_MOD_*` | Compat | Existe ? Quelles clés ? | Tous les verdicts faux |
| `C_Item.GetItemInfo` (16e retour = setID) | Compat | Position du setID ? | Sets inactifs |
| `C_Item.GetItemInfoInstant` (4e retour = equipLoc) | Utils | Idem | Aucun verdict |
| `C_Item.GetItemQualityByID` | Utils | Accepte un lien ? | Aucun verdict |
| `C_TooltipInfo.GetHyperlink` (retour : lignes, couleurs) | Compat (sets, utilisabilité) | Format des lignes et couleurs ? | Sets « partiels », filtre inactif |
| `ITEM_SET_BONUS_GRAY` | Compat | Format de la ligne | Paliers illisibles |
| `TooltipDataProcessor.AddTooltipPostCall`, `tooltip:GetItem` | Tooltip | Fonctionne sur Forever ? | Aucun affichage |
| `C_SpecializationInfo.*`, `GetSpecializationInfoForSpecID/ClassID` | Spec | Existence, signatures (retour 6 = stat principale ?) | Choix manuel seul |
| `C_SpecializationInfo.GetInspectSpecialization` | Inspector | Spé des autres lisible ? | Pas de comparaison de groupe |
| `NotifyInspect`, `CanInspect`, `INSPECT_READY`, `GetInventoryItemLink(unit)` | Inspector | Autorisés, valeurs « secrètes » ? | Pas de comparaison de groupe |
| `C_Map.GetBestMapForUnit`, `UnitIsVisible` | Inspector | Existence | Filtre d'instance dégradé |
| `CanDualWield` | Compat | Existence | Suppose oui |
| `UICheckButtonTemplate` : `.text` ou `.Text` | UI | Nom du champ | `/fsb` en erreur |
| Suffixe `_Camelot.toc` | TOC | Utile à Forever ? | TOC superflu |
| Classe/armure/arme équipables : table Classic `Data/Equipment.lua` | Compat, ItemAnalyzer | Forever a-t-il changé des règles (plaques/mailles niv. 40, armes par classe, ambidextrie) ? | Objet portable écarté, ou membre du groupe écarté à tort |
| `GetItemInfoInstant` : 6e/7e retours = classe/sous-classe d'objet (arme 2, armure 4 ; `Enum.ItemWeaponSubclass`) | Compat (table d'équipement) | Mêmes identifiants que Classic ? | Table d'équipement inactive ou fausse |
| Compétence d'arme non apprise : type d'arme en rouge **à droite** de la ligne « Une main / Deux mains » | Compat | Disposition et couleur réelles ? | Arme marquée inutilisable au lieu de « compétence à apprendre » |
| Clés `ITEM_MOD_HIT/CRIT/HASTE_SPELL_RATING_SHORT`, `_MELEE_`, `_RANGED_`, `ITEM_MOD_RANGED_ATTACK_POWER_SHORT`, `ITEM_MOD_SPELL_PENETRATION_SHORT`, `ITEM_MOD_BLOCK_VALUE_SHORT`, `ITEM_MOD_EXTRA_ARMOR_SHORT` | Weights, Stats | Renvoyées telles quelles par `GetItemStats` ? (`/fsb inconnus`) | Stat ignorée ou comptée sous une autre clé |
| `C_Container.GetContainerNumSlots/GetContainerItemLink` (ou globales), `NUM_BAG_SLOTS`, événement `BAG_UPDATE_DELAYED` | Compat (armes du sac), Core | Présents sur Forever ? | Pas de combinaison avec le sac (comparaison simple) |
| Événement `TRAIT_CONFIG_UPDATED` | Core | Émis au changement de talents ? | Spé mise à jour seulement au changement de zone/niveau |
| Poids (`Data/Weights.lua`) | Profils | Estimations indicatives, à valider (ForeverDB/simulateur) ; poids « ours » = copie des poids félin | Verdicts approximatifs |

| API de talents (arbre, rang) du joueur et des autres | (absent) | Quelle API existe sur Forever ? (`/fsb etat` liste les fonctions *Talent*) | Pas de spé réelle ni de rôle des autres |
| `GetNumTalentTabs`, `GetTalentTabInfo` (disposition du retour), événements `PLAYER_TALENT_UPDATE`/`CHARACTER_POINTS_CHANGED` | Spec (arbre actif) | Présents ? Quel retour ? | Repli sur C_Traits (vérifié) ; sinon arbre par défaut de la classe |
| Ordre des arbres par classe (Classes.TREES) | Spec | Même ordre que Classic ? | Mauvais rôle proposé |
| `UnitGroupRolesAssigned(unit)` pour les autres membres : valeurs réelles (HEALER/TANK explicites ?) | Inspector | Un soigneur marqué HEALER est-il bien lu ? | Pas de comparaison des classes à plusieurs rôles |
| Événement `CHAT_MSG_LOOT` et textes `LOOT_ITEM*` (format, texte lisible en instance, pas de valeur « secrète ») | LootTracker | Le butin des autres joueurs est-il lu ? (`/fsb rapport` → GROUPE → derniers messages de butin) | Pas d'équité du loot (aucun malus), le reste fonctionne |
