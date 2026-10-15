local _, FSB = ...

-- Contexte de jeu. Mode GROUPE = en donjon ou raid (type d'instance "party"/"raid") ET en groupe.
-- Partout ailleurs (monde ouvert, ville, champ de bataille, instance en solo) : mode SOLO.
local Context = {}
FSB.Context = Context

local groupMode = false

local function Compute()
    if not IsInInstance or not IsInGroup then return false end
    local inInstance, instanceType = IsInInstance()
    return (inInstance and (instanceType == "party" or instanceType == "raid") and IsInGroup()) and true or false
end

function Context.IsGroupMode() return groupMode end

-- Recalcule le mode ; vide les caches si il a changé. Retourne true si changement.
function Context.Refresh()
    local new = Compute()
    if new == groupMode then return false end
    groupMode = new
    if FSB.Analyzer then FSB.Analyzer.InvalidateAll() end
    return true
end

local MAX_LEVEL, SPEC_LEVEL = 60, 10
Context.MAX_LEVEL, Context.SPEC_LEVEL = MAX_LEVEL, SPEC_LEVEL

local function InstanceType()
    if not IsInInstance then return nil end
    return select(2, IsInInstance())
end

-- Style de jeu choisi par le joueur (/fsbpvp, /fsbpve ou page d'accueil) : "PVE" (défaut) ou "PVP".
function Context.Playstyle() return (FSB.db and FSB.db.playstyle == "PVP") and "PVP" or "PVE" end

-- Lieu actuel : "RAID", "DUNGEON", "BG", "ARENA" ou "OUTSIDE".
function Context.Place()
    local t = InstanceType()
    if t == "raid" then return "RAID" elseif t == "party" then return "DUNGEON"
    elseif t == "pvp" then return "BG" elseif t == "arena" then return "ARENA" end
    return "OUTSIDE"
end

-- Mode des poids. Sous le niveau 10 (pas de spé) : LOW_DUNGEON en donjon/raid, sinon LOW_LEVELING.
-- Ensuite : PVP si le joueur a choisi le PvP, sinon LEVELING sous le niveau 60 et PVE au niveau 60.
function Context.Mode(level)
    level = level or (UnitLevel and UnitLevel("player")) or MAX_LEVEL
    if level > 0 and level < SPEC_LEVEL then
        local t = InstanceType()
        return (t == "party" or t == "raid") and "LOW_DUNGEON" or "LOW_LEVELING"
    end
    if Context.Playstyle() == "PVP" then return "PVP" end
    if level > 0 and level < MAX_LEVEL then return "LEVELING" end
    return "PVE"
end

-- Pour les tests.
function Context._Set(value) groupMode = value end
