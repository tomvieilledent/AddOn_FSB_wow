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

-- Identifiant de set de l'objet (16e retour de C_Item.GetItemInfo) ou nil.
function Compat.GetSetID(link)
    if not link or not C_Item or not C_Item.GetItemInfo then return nil end
    local ok, setID = pcall(function() return select(16, C_Item.GetItemInfo(link)) end)
    if ok and type(setID) == "number" and setID > 0 then return setID end
end

-- Paliers de bonus ("(2) Set : ...") lus dans le tooltip de l'objet, selon le format localisé
-- du jeu (ITEM_SET_BONUS_GRAY). Retourne une liste triée, ou nil si illisible.
local function BonusPattern()
    local fmt = _G.ITEM_SET_BONUS_GRAY
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%d", "\1"):gsub("%%s", "\2")
    p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("\1", "(%%d+)"):gsub("\2", ".+")
    return "^" .. p .. "$"
end

function Compat.GetSetThresholds(link)
    if not link or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return nil end
    local pattern = BonusPattern()
    if not pattern then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or not data.lines then return nil end
    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
    local thresholds = {}
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" then
            local n = text:match(pattern)
            if n then thresholds[#thresholds + 1] = tonumber(n) end
        end
    end
    table.sort(thresholds)
    return #thresholds > 0 and thresholds or nil
end

local function BuildItem(link)
    local stats = Compat.GetStats(link)
    if not stats then return nil end
    return { link = link, stats = stats, setID = Compat.GetSetID(link),
        twoHand = Compat.GetEquipLoc(link) == "INVTYPE_2HWEAPON" }
end

-- Objet porté à un emplacement : { link, stats, setID, twoHand } ou nil si vide/indisponible.
function Compat.GetEquipped(slot)
    if not GetInventoryItemLink then return nil end
    return BuildItem(GetInventoryItemLink("player", slot))
end

-- Tout l'équipement porté : { [slot] = objet }.
function Compat.GetAllEquipped()
    local equipped = {}
    for _, slot in pairs(FSB.Stats.SLOT) do equipped[slot] = Compat.GetEquipped(slot) end
    return equipped
end

-- Si l'API n'existe pas, on suppose que oui (pas d'invention d'une restriction).
function Compat.CanDualWield()
    if CanDualWield then return CanDualWield() and true or false end
    return true
end
