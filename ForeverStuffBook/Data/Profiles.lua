local _, FSB = ...

-- Profils : { name, role, weights = { [clé de stat] = poids } }.
-- Les poids par défaut sont des valeurs de départ génériques, modifiables : ils ne
-- prétendent pas être des valeurs optimales pour une classe donnée.
local Profiles = {}
FSB.Profiles = Profiles

local DEFAULTS = {
    { name = "Soigneur", role = "HEALER", weights = {
        ITEM_MOD_SPELL_HEALING_DONE_SHORT = 100, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 80, ITEM_MOD_INTELLECT_SHORT = 75,
        ITEM_MOD_MANA_REGENERATION_SHORT = 90, ITEM_MOD_SPIRIT_SHORT = 65, ITEM_MOD_CRIT_RATING_SHORT = 50,
        ITEM_MOD_HASTE_RATING_SHORT = 55, ITEM_MOD_STAMINA_SHORT = 20 } },
    { name = "Dégâts magiques", role = "DAMAGER", damage = "MAGIC", weights = {
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 100, ITEM_MOD_INTELLECT_SHORT = 70, ITEM_MOD_HIT_RATING_SHORT = 85,
        ITEM_MOD_CRIT_RATING_SHORT = 60, ITEM_MOD_HASTE_RATING_SHORT = 60, ITEM_MOD_STAMINA_SHORT = 15 } },
    { name = "Dégâts physiques", role = "DAMAGER", damage = "PHYSICAL", weights = {
        ITEM_MOD_ATTACK_POWER_SHORT = 50, ITEM_MOD_STRENGTH_SHORT = 80, ITEM_MOD_AGILITY_SHORT = 80,
        ITEM_MOD_HIT_RATING_SHORT = 85, ITEM_MOD_CRIT_RATING_SHORT = 70, ITEM_MOD_HASTE_RATING_SHORT = 60,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 60, ITEM_MOD_STAMINA_SHORT = 15 } },
    { name = "Tank", role = "TANK", weights = {
        ITEM_MOD_STAMINA_SHORT = 80, RESISTANCE0_NAME = 20, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 70,
        ITEM_MOD_DODGE_RATING_SHORT = 65, ITEM_MOD_PARRY_RATING_SHORT = 65, ITEM_MOD_BLOCK_RATING_SHORT = 40,
        ITEM_MOD_STRENGTH_SHORT = 40, ITEM_MOD_AGILITY_SHORT = 50, ITEM_MOD_EXPERTISE_RATING_SHORT = 40 } },
}

local function Copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and Copy(v) or v end
    return c
end

-- Appelé une fois la SavedVariable chargée.
-- Version 2 : les clés de soins/dégâts de sorts ont été corrigées (valeurs vues en jeu).
local RENAMED = {
    ITEM_MOD_HEALING_POWER_SHORT = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    ITEM_MOD_SPELL_POWER_SHORT = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
}
local function Migrate(db)
    if (db.schema or 1) >= 2 then return end
    for _, p in ipairs(db.profiles) do
        for old, new in pairs(RENAMED) do
            if p.weights[old] ~= nil then
                if p.weights[new] == nil then p.weights[new] = p.weights[old] end
                p.weights[old] = nil
            end
        end
    end
    db.schema = 2
end

function Profiles.Init(db)
    if not db.profiles or #db.profiles == 0 then db.profiles = Copy(DEFAULTS) end
    Migrate(db)
    if not Profiles.Find(db.activeProfile, db) then db.activeProfile = db.profiles[1].name end
end

function Profiles.IsBuiltin(name)
    for _, p in ipairs(DEFAULTS) do if p.name == name then return true end end
    return false
end

function Profiles.List() return FSB.db.profiles end

function Profiles.Find(name, db)
    for _, p in ipairs((db or FSB.db).profiles) do
        if p.name == name then return p end
    end
end

function Profiles.GetActive() return Profiles.Find(FSB.db.activeProfile) end

local function Changed() if FSB.Analyzer then FSB.Analyzer.InvalidateAll() end end

-- auto = true : changement fait par la détection de spé ; sinon (choix de l'utilisateur) on
-- désactive la sélection automatique.
function Profiles.SetActive(name, auto)
    if not Profiles.Find(name) then return false end
    FSB.db.activeProfile = name
    if not auto then FSB.db.autoProfile = false end
    Changed()
    return true
end

function Profiles.Create(name, baseProfile)
    if name == "" or Profiles.Find(name) then return nil end
    local p = Copy(baseProfile or Profiles.GetActive())
    p.name = name
    table.insert(FSB.db.profiles, p)
    Changed()
    return p
end

function Profiles.Delete(name)
    local list = FSB.db.profiles
    if #list <= 1 then return false end
    for i, p in ipairs(list) do
        if p.name == name then
            table.remove(list, i)
            if FSB.db.activeProfile == name then FSB.db.activeProfile = list[1].name end
            Changed()
            return true
        end
    end
    return false
end

function Profiles.SetWeight(profile, statKey, value)
    profile.weights[statKey] = value
    Changed()
end

-- Valeur (en points de score) d'un palier de bonus de set pour ce profil. 0 = non estimé.
function Profiles.SetBonusValue(profile, value)
    profile.setBonusValue = value
    Changed()
end
