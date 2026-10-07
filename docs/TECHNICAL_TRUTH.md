# TECHNICAL_TRUTH — faits techniques

Statuts : VERIFIED · UNVERIFIED · CONFLICTING · IMPOSSIBLE.
Le code de production ne dépend jamais d'un fait UNVERIFIED sans repli (`pcall`, test de présence, « inconnu »).
Sources VERIFIED admises : sortie d'une commande en jeu (`/fsb sonde`), fichiers d'interface exportés du client Forever.
Sources secondaires (articles, wiki d'autres versions) = UNVERIFIED au mieux.

## Client
| Fait | Statut | Source |
|---|---|---|
| Interface 16001, client 1.60.1, build 70245 | **VERIFIED** | `/fsb sonde` en jeu (2026-10-07) |
| Forever partage l'architecture UI mainline (12.1.5) | UNVERIFIED (Icy Veins, Gamewave) | export interface |
| Restrictions Midnight (« secret values ») actives | UNVERIFIED (mêmes sources) | tests en jeu en instance/combat |
| Retail ≠ Classic ≠ Forever | règle de projet | — |

## API — existence (VERIFIED par `/fsb sonde`, type = function)
C_Item.GetItemStats, GetItemInfo, GetItemInfoInstant, GetItemQualityByID · C_TooltipInfo.GetHyperlink ·
TooltipDataProcessor.AddTooltipPostCall · C_SpecializationInfo.GetSpecialization, GetSpecializationInfo,
GetInspectSpecialization, GetNumSpecializationsForClassID, GetClassIDFromSpecID · GetSpecializationInfoForSpecID,
GetSpecializationInfoForClassID · NotifyInspect, CanInspect, ClearInspectPlayer · GetInventoryItemLink ·
C_Map.GetBestMapForUnit · UnitIsVisible · CanDualWield · C_Timer.NewTicker, After · IsInInstance, IsInGroup.
Global `ITEM_SET_BONUS_GRAY` : string. Emplacement 18 : existe.

## API — absente (VERIFIED)
`TooltipUtil.SurfaceArgs` = nil (FSB la teste avant usage).

L'existence ne prouve ni les retours ni l'absence de valeurs « secrètes » : voir `docs/UNVERIFIED.md`.

## Règles de conformité (VERIFIED : décisions de projet)
Addon passif : aucune action de jeu, aucune simulation d'entrée, aucune API protégée. Voir `docs/COMPLIANCE.md`.

## Limitations connues
- Pas de filtre de classe/armure/arme (écart avec le cahier des charges §3).
- Poids par défaut génériques, non sourcés.

## Données lues en jeu (VERIFIED, 2026-10-07, prêtre)
- Clés de stats : `ITEM_MOD_INTELLECT_SHORT`, `ITEM_MOD_SPIRIT_SHORT`, `ITEM_MOD_SPELL_HEALING_DONE_SHORT`,
  `ITEM_MOD_SPELL_DAMAGE_DONE_SHORT`, `ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT`, `ITEM_MOD_FIRE_DAMAGE_DONE_SHORT`,
  `ITEM_MOD_*_RESISTANCE_SHORT`, `RESISTANCE3/5/6_NAME`, `ITEM_MOD_HEALTH_REGEN_SHORT`.
  `ITEM_MOD_HEALING_POWER_SHORT` et `ITEM_MOD_SPELL_POWER_SHORT` : jamais observées (supprimées du code).
- Stat principale d'une spé : intelligence = 4.
- Spé détectée du prêtre : id 1487, `role=DAMAGER` pour un soigneur : **CONFLICTING** avec la réalité. Spés de la classe : à lire via `/fsb etat`.
