local _, FSB = ...

-- Profils : { name, role, weights = { [clé de stat] = poids } }.
-- Poids fixes et indicatifs (non modifiables) : valeurs de départ génériques qui ne prétendent pas
-- être optimales pour une classe donnée.
local Profiles = {}
FSB.Profiles = Profiles

local DEFAULTS = {
    { name = "Soigneur", role = "HEALER", weights = {
        ITEM_MOD_SPELL_HEALING_DONE_SHORT = 100, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10, ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = 10,
        ITEM_MOD_INTELLECT_SHORT = 75,
        ITEM_MOD_MANA_REGENERATION_SHORT = 90, ITEM_MOD_SPIRIT_SHORT = 65, ITEM_MOD_CRIT_RATING_SHORT = 50,
        ITEM_MOD_HASTE_RATING_SHORT = 55, ITEM_MOD_STAMINA_SHORT = 20 } },
    { name = "Dégâts magiques", role = "DAMAGER", damage = "MAGIC", weights = {
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 100, ITEM_MOD_INTELLECT_SHORT = 70, ITEM_MOD_HIT_RATING_SHORT = 85,
        -- bonus d'école : valeur de départ générique (ne profite qu'aux sorts de cette école)
        ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = 50, ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = 50, ITEM_MOD_FROST_DAMAGE_DONE_SHORT = 50,
        ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = 50, ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = 50, ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = 50,
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
-- Les profils viennent du code (poids fixes, indicatifs) et sont rechargés à chaque connexion : seule la
-- valeur de palier de set (réglage du moteur) est conservée d'une session à l'autre.
function Profiles.Init(db)
    local saved = {}
    for _, p in ipairs(db.profiles or {}) do saved[p.name] = p.setBonusValue end
    db.profiles = Copy(DEFAULTS)
    for _, p in ipairs(db.profiles) do p.setBonusValue = saved[p.name] end
    db.schema = 4
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

-- Le profil actif est toujours choisi par la détection de spé (et le choix de rôle), jamais à la main.
function Profiles.SetActive(name)
    if not Profiles.Find(name) then return false end
    FSB.db.activeProfile = name
    Changed()
    return true
end

-- Valeur (en points de score) d'un palier de bonus de set pour ce profil. 0 = non estimé.
function Profiles.SetBonusValue(profile, value)
    profile.setBonusValue = value
    Changed()
end
