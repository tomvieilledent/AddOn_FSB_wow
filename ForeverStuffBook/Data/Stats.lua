local _, FSB = ...

-- Clés de statistiques renvoyées par C_Item.GetItemStats. Les clés de soins/dégâts de sorts
-- (ITEM_MOD_SPELL_*_DONE_SHORT) sont VERIFIED en jeu ; les autres restent à confirmer avec
-- /fsb inconnus : toute clé non listée est ignorée du score et enregistrée.
local Stats = {}
FSB.Stats = Stats

Stats.KEYS = {
    { key = "RESISTANCE0_NAME",                 alias = "armure",   label = "Armure" },
    { key = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", alias = "dps",      label = "DPS de l'arme" },
    { key = "ITEM_MOD_STRENGTH_SHORT",          alias = "force",    label = "Force" },
    { key = "ITEM_MOD_AGILITY_SHORT",           alias = "agi",      label = "Agilité" },
    { key = "ITEM_MOD_STAMINA_SHORT",           alias = "endu",     label = "Endurance" },
    { key = "ITEM_MOD_INTELLECT_SHORT",         alias = "int",      label = "Intelligence" },
    { key = "ITEM_MOD_SPIRIT_SHORT",            alias = "esprit",   label = "Esprit" },
    { key = "ITEM_MOD_ATTACK_POWER_SHORT",      alias = "pa",       label = "Puissance d'attaque" },
    { key = "ITEM_MOD_SPELL_POWER_SHORT",              alias = "ps",       label = "Puissance des sorts" },
    { key = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",       alias = "degats",   label = "Puissance des dégâts" },
    { key = "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT", alias = "ombre",   label = "Dégâts Ombre" },
    { key = "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT",   alias = "feu",     label = "Dégâts Feu" },
    { key = "ITEM_MOD_FROST_DAMAGE_DONE_SHORT",  alias = "givre",   label = "Dégâts Givre" },
    { key = "ITEM_MOD_NATURE_DAMAGE_DONE_SHORT", alias = "nature",  label = "Dégâts Nature" },
    { key = "ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT", alias = "arcanes", label = "Dégâts Arcanes" },
    { key = "ITEM_MOD_HOLY_DAMAGE_DONE_SHORT",   alias = "sacre",   label = "Dégâts Sacré" },
    { key = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",     alias = "soins",    label = "Puissance des soins" },
    { key = "ITEM_MOD_MANA_REGENERATION_SHORT", alias = "mp5",      label = "MP5" },
    { key = "ITEM_MOD_CRIT_RATING_SHORT",       alias = "crit",     label = "Critique" },
    { key = "ITEM_MOD_HIT_RATING_SHORT",        alias = "toucher",  label = "Toucher" },
    { key = "ITEM_MOD_HASTE_RATING_SHORT",      alias = "hate",     label = "Hâte" },
    { key = "ITEM_MOD_EXPERTISE_RATING_SHORT",  alias = "expertise",label = "Expertise" },
    { key = "ITEM_MOD_MASTERY_RATING_SHORT",    alias = "maitrise", label = "Maîtrise" },
    { key = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", alias = "defense", label = "Défense" },
    { key = "ITEM_MOD_DODGE_RATING_SHORT",      alias = "esquive",  label = "Esquive" },
    { key = "ITEM_MOD_PARRY_RATING_SHORT",      alias = "parade",   label = "Parade" },
    { key = "ITEM_MOD_BLOCK_RATING_SHORT",      alias = "blocage",  label = "Blocage" },
    { key = "ITEM_MOD_RESILIENCE_RATING_SHORT", alias = "resil",    label = "Résilience" },
}

-- Clés vues en jeu, volontairement hors score pour l'instant (pas de poids, pas dans l'interface) :
-- résistances, régénération de vie. Elles ne sont pas signalées comme inconnues.
Stats.IGNORED = {
    ITEM_MOD_SHADOW_RESISTANCE_SHORT = true, ITEM_MOD_FIRE_RESISTANCE_SHORT = true,
    ITEM_MOD_NATURE_RESISTANCE_SHORT = true, ITEM_MOD_FROST_RESISTANCE_SHORT = true,
    ITEM_MOD_ARCANE_RESISTANCE_SHORT = true, ITEM_MOD_HOLY_RESISTANCE_SHORT = true,
    RESISTANCE1_NAME = true, RESISTANCE2_NAME = true, RESISTANCE3_NAME = true,
    RESISTANCE4_NAME = true, RESISTANCE5_NAME = true, RESISTANCE6_NAME = true,
    ITEM_MOD_HEALTH_REGEN_SHORT = true,
}

-- Bonus d'école : ne profitent qu'aux sorts de cette école (ITEM_MOD_SPELL_DAMAGE_DONE_SHORT les couvre toutes).
Stats.SCHOOL_KEYS = {
    "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT", "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT", "ITEM_MOD_FROST_DAMAGE_DONE_SHORT",
    "ITEM_MOD_NATURE_DAMAGE_DONE_SHORT", "ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT", "ITEM_MOD_HOLY_DAMAGE_DONE_SHORT",
}

local byKey, byAlias = {}, {}
for _, s in ipairs(Stats.KEYS) do byKey[s.key] = s; byAlias[s.alias] = s end

function Stats.IsKnown(key) return byKey[key] ~= nil or Stats.IGNORED[key] == true end
function Stats.FromAlias(text) local s = byAlias[(text or ""):lower()]; return s and s.key end
-- Libellé localisé de la stat (langue active), repli sur le libellé français puis sur la clé.
function Stats.Label(key)
    local localized = FSB.L and FSB.L.STATS and FSB.L.STATS[key]
    return localized or (byKey[key] and byKey[key].label) or key
end

-- Emplacements d'inventaire (INVSLOT_*).
Stats.SLOT = { HEAD=1, NECK=2, SHOULDER=3, CHEST=5, WAIST=6, LEGS=7, FEET=8, WRIST=9,
    HANDS=10, FINGER1=11, FINGER2=12, TRINKET1=13, TRINKET2=14, BACK=15,
    MAINHAND=16, OFFHAND=17, RANGED=18 }

local S = Stats.SLOT
-- equipLoc -> emplacements candidats. Les types absents (chemise, tabard, sac...) ne sont pas analysés.
Stats.SLOTS_FOR = {
    INVTYPE_HEAD={S.HEAD}, INVTYPE_NECK={S.NECK}, INVTYPE_SHOULDER={S.SHOULDER},
    INVTYPE_CHEST={S.CHEST}, INVTYPE_ROBE={S.CHEST}, INVTYPE_WAIST={S.WAIST},
    INVTYPE_LEGS={S.LEGS}, INVTYPE_FEET={S.FEET}, INVTYPE_WRIST={S.WRIST},
    INVTYPE_HAND={S.HANDS}, INVTYPE_FINGER={S.FINGER1, S.FINGER2},
    INVTYPE_TRINKET={S.TRINKET1, S.TRINKET2}, INVTYPE_CLOAK={S.BACK},
    INVTYPE_WEAPON={S.MAINHAND, S.OFFHAND}, INVTYPE_2HWEAPON={S.MAINHAND},
    INVTYPE_WEAPONMAINHAND={S.MAINHAND}, INVTYPE_WEAPONOFFHAND={S.OFFHAND},
    INVTYPE_SHIELD={S.OFFHAND}, INVTYPE_HOLDABLE={S.OFFHAND},
    INVTYPE_RANGED={S.RANGED}, INVTYPE_RANGEDRIGHT={S.RANGED},
    INVTYPE_THROWN={S.RANGED}, INVTYPE_RELIC={S.RANGED},
}

-- Emplacements dont dépend le résultat d'un type d'objet (pour l'invalidation du cache).
-- Toutes les armes dépendent des deux mains (une 2M change l'évaluation de la main gauche).
local WEAPON_SLOTS = { S.MAINHAND, S.OFFHAND }
function Stats.RelatedSlots(equipLoc)
    local slots = Stats.SLOTS_FOR[equipLoc]
    if not slots then return nil end
    if slots[1] == S.MAINHAND or slots[1] == S.OFFHAND then return WEAPON_SLOTS end
    return slots
end
