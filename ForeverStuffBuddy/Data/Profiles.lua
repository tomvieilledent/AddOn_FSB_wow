local _, FSB = ...

-- Profils : un par classe × arbre de talents × mode (Data/Weights.lua).
-- { name, class, tree, spec, mode, role, weights = { [clé de stat] = poids } }.
-- Poids fixes et indicatifs (non modifiables).
local Profiles = {}
FSB.Profiles = Profiles

-- Noms français des classes : servent d'identifiant interne des profils.
local CLASS_FR = {
    WARRIOR = "Guerrier", PALADIN = "Paladin", HUNTER = "Chasseur", ROGUE = "Voleur", PRIEST = "Prêtre",
    SHAMAN = "Chaman", MAGE = "Mage", WARLOCK = "Démoniste", DRUID = "Druide",
}
local MODE_FR = { LEVELING = "Leveling 10–59", PVE = "PvE 60", PVP = "PvP",
    LOW_LEVELING = "Leveling 1–9", LOW_DUNGEON = "Donjons bas niveau" }
local ROLE_FR = { DAMAGER = "Dégâts", HEALER = "Soigneur", TANK = "Tank", ANY = "Sans spé" }
local VARIANT_FR = { CAT = "félin", BEAR = "ours" }

-- Colonnes du tableau -> poids par clé de stat (la plus forte valeur l'emporte pour une clé partagée).
local function ToWeights(values)
    local weights = {}
    for i, keys in ipairs(FSB.Weights.COLUMNS) do
        local v = values[i] or 0
        if v > 0 then
            for _, key in ipairs(keys) do
                if not weights[key] or v > weights[key] then weights[key] = v end
            end
        end
    end
    return weights
end

local DEFAULTS = {}
for _, s in ipairs(FSB.Weights.SPECS) do
    local class, tree, spec, role, byMode, variant = s[1], s[2], s[3], s[4], s[5], s.variant
    local key = class .. ":" .. tree .. (variant and (":" .. variant) or "")
    local specName = variant and ("%s (%s)"):format(spec, VARIANT_FR[variant]) or spec
    for _, mode in ipairs(FSB.Weights.MODES) do
        DEFAULTS[#DEFAULTS + 1] = {
            name = ("%s · %s · %s"):format(CLASS_FR[class], specName, MODE_FR[mode]),
            class = class, tree = tree, spec = spec, variant = variant, mode = mode, role = role,
            roleInfo = FSB.Weights.ROLE_INFO[key], -- { rôle, type, portée }
            weights = ToWeights(byMode[mode]),
        }
    end
end
-- Sous le niveau 10 (pas de spé) : un profil par classe, arbre 0, rôle ANY.
for _, s in ipairs(FSB.Weights.LOW) do
    local class, general, byMode = s[1], s[2], s[3]
    for _, mode in ipairs(FSB.Weights.LOW_MODES) do
        DEFAULTS[#DEFAULTS + 1] = {
            name = ("%s · %s · %s"):format(CLASS_FR[class], general, MODE_FR[mode]),
            class = class, tree = 0, spec = general, mode = mode, role = "ANY",
            weights = ToWeights(byMode[mode]),
        }
    end
end

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
    db.schema = 5
    if not Profiles.Find(db.activeProfile, db) then db.activeProfile = db.profiles[1].name end
end

-- Nom affiché dans la langue active : « Mage · Givre · PvE 60 ».
function Profiles.DisplayName(name)
    local p = Profiles.Find(name)
    local L = FSB.L
    if not p or not L then return name end
    local trees = L.TREE_NAMES and L.TREE_NAMES[p.class]
    local class = (L.CLASS_NAMES and L.CLASS_NAMES[p.class]) or CLASS_FR[p.class]
    local spec = (p.tree == 0 and L.LOW_ROLES and L.LOW_ROLES[p.class]) or (trees and trees[p.tree]) or p.spec
    if p.variant then
        spec = ("%s (%s)"):format(spec, (L.FERAL_FORMS and L.FERAL_FORMS[p.variant]) or VARIANT_FR[p.variant])
    end
    local mode = (L.MODES and L.MODES[p.mode]) or MODE_FR[p.mode]
    return ("%s · %s · %s"):format(class, spec, mode)
end

-- Rôle affiché « DPS · Physique · CAC » (rôle, type, portée) ; rôle général sous le niveau 10.
function Profiles.RoleLabel(p)
    local L = FSB.L
    if not p then return "?" end
    if p.role == "ANY" then return (L.LOW_ROLES and L.LOW_ROLES[p.class]) or p.spec end
    if not p.roleInfo then return (ROLE_FR[p.role] or p.role) end
    local parts = {}
    for i, word in ipairs(p.roleInfo) do parts[i] = (L.ROLE_PARTS and L.ROLE_PARTS[word]) or word end
    return table.concat(parts, " · ")
end

-- Lignes de texte des poids : profil actif seul, ou tous les profils (diagnostic d'équilibrage).
function Profiles.WeightLines(all)
    local lines = {}
    local list = all and FSB.db.profiles or { Profiles.GetActive() }
    for _, p in ipairs(list) do
        lines[#lines + 1] = FSB.L.POIDS_TITLE:format(Profiles.DisplayName(p.name))
        for _, stat in ipairs(FSB.Stats.KEYS) do
            local w = p.weights[stat.key]
            if w then lines[#lines + 1] = ("  %s = %s"):format(FSB.Stats.Label(stat.key), w) end
        end
        if all then lines[#lines + 1] = "" end
    end
    return lines
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

-- Profil d'une classe, d'un arbre et d'un mode. variant : "CAT" (défaut) ou "BEAR" pour le druide farouche.
function Profiles.For(class, tree, mode, variant)
    for _, p in ipairs(FSB.db.profiles) do
        if p.class == class and p.tree == tree and p.mode == mode
            and (not p.variant or p.variant == (variant or "CAT")) then return p end
    end
end

-- Tous les profils d'une classe pour un mode (une entrée par arbre).
function Profiles.ForClass(class, mode)
    local list = {}
    for _, p in ipairs(FSB.db.profiles) do
        if p.class == class and p.mode == mode then list[#list + 1] = p end
    end
    return list
end

-- Rôles distincts que les arbres de la classe peuvent tenir dans ce mode.
function Profiles.Roles(class, mode)
    local seen, roles = {}, {}
    for _, p in ipairs(Profiles.ForClass(class, mode)) do
        if not seen[p.role] then seen[p.role] = true; roles[#roles + 1] = p.role end
    end
    return roles
end

-- Profil moyen des arbres d'une classe tenant un rôle (pour un autre joueur dont l'arbre n'est pas lisible).
local roleCache = {}
function Profiles.ClassRole(class, role, mode)
    local key = tostring(class) .. ":" .. tostring(role) .. ":" .. tostring(mode)
    if roleCache[key] then return roleCache[key] end
    local sum, n = {}, 0
    for _, p in ipairs(Profiles.ForClass(class, mode)) do
        if p.role == role then
            n = n + 1
            for k, w in pairs(p.weights) do sum[k] = (sum[k] or 0) + w end
        end
    end
    if n == 0 then return nil end
    for k, w in pairs(sum) do sum[k] = w / n end
    local profile = { name = ("%s · %s · %s"):format(CLASS_FR[class] or class, ROLE_FR[role] or role, MODE_FR[mode] or mode),
        class = class, role = role, mode = mode, weights = sum }
    roleCache[key] = profile
    return profile
end

function Profiles.GetActive() return Profiles.Find(FSB.db.activeProfile) end

local function Changed() if FSB.Analyzer then FSB.Analyzer.InvalidateAll() end end

-- Le profil actif est toujours choisi par la détection de spé (talents) et du mode, jamais à la main.
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
