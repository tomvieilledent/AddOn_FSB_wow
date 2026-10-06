local _, FSB = ...

-- Seule couche qui appelle l'API WoW pour l'équipement : les moteurs (Engine/)
-- ne manipulent que des tables Lua, ce qui les rend testables hors du jeu.
local Compat = {}
FSB.Compat = Compat

-- Statistiques d'un objet : table { [clé] = valeur numérique } ou nil.
function Compat.GetStats(link)
    if not link or not C_Item or not C_Item.GetItemStats then return nil end
    local ok, raw = pcall(C_Item.GetItemStats, link)
    if not ok or type(raw) ~= "table" then return nil end
    local stats = {}
    for key, value in pairs(raw) do
        if type(value) == "number" then stats[key] = value end
    end
    return stats
end

function Compat.GetEquipLoc(link)
    return FSB.Utils.GetEquipLoc(link)
end

-- Objet porté à un emplacement : { stats = {...}, twoHand = bool } ou nil si vide/indisponible.
function Compat.GetEquipped(slot)
    if not GetInventoryItemLink then return nil end
    local link = GetInventoryItemLink("player", slot)
    if not link then return nil end
    local stats = Compat.GetStats(link)
    if not stats then return nil end
    return { stats = stats, twoHand = Compat.GetEquipLoc(link) == "INVTYPE_2HWEAPON" }
end

-- Si l'API n'existe pas, on suppose que oui (pas d'invention d'une restriction).
function Compat.CanDualWield()
    if CanDualWield then return CanDualWield() and true or false end
    return true
end
