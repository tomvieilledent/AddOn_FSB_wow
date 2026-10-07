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
local function FormatPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%d", "\1"):gsub("%%s", "\2")
    p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("\1", "(%%d+)"):gsub("\2", ".+")
    return "^" .. p .. "$"
end

local function BonusPattern() return FormatPattern(_G.ITEM_SET_BONUS_GRAY) end

-- Ligne de texte rouge (restriction non remplie) : couleur lue dans les données du tooltip.
local function IsRed(color)
    if type(color) ~= "table" then return false end
    local r, g, b = color.r, color.g, color.b
    return type(r) == "number" and type(g) == "number" and type(b) == "number"
        and r > 0.9 and g < 0.3 and b < 0.3
end

-- Utilisabilité par le personnage, lue dans les lignes rouges du tooltip (classe, armure, arme...).
-- Retourne { unusable = bool, reqLevel = n|nil } ou nil si le tooltip est illisible
-- (on ne filtre alors rien : aucune restriction inventée).
function Compat.GetUsability(link)
    if not link or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
    local levelPattern = FormatPattern(_G.ITEM_MIN_LEVEL)
    local result = { unusable = false }
    for _, line in ipairs(data.lines) do
        for _, side in ipairs({ "left", "right" }) do
            local text, color = line[side .. "Text"], line[side .. "Color"]
            if type(text) == "string" and IsRed(color) then
                local n = levelPattern and text:match(levelPattern)
                if n then
                    result.reqLevel = tonumber(n)
                else
                    result.unusable = true
                end
            end
        end
    end
    return result
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

-- Retourne nil si l'emplacement est vide ; { link, unreadable = true } si un objet est porté mais que
-- ses stats sont illisibles (jamais confondu avec un emplacement vide).
local function BuildItem(link)
    if not link then return nil end
    local stats = Compat.GetStats(link)
    if not stats then return { link = link, unreadable = true, stats = {} } end
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

function Compat.PlayerLevel()
    return UnitLevel and UnitLevel("player") or 0
end
