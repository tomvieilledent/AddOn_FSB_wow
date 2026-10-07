local _, FSB = ...

-- Seule couche qui appelle l'API WoW pour l'équipement : les moteurs (Engine/)
-- ne manipulent que des tables Lua, ce qui les rend testables hors du jeu.
local Compat = {}
FSB.Compat = Compat

-- MP5 lu dans le texte du tooltip, pour les objets dont la ligne « Rend N points de mana toutes les 5 s » n'est pas
-- dans les stats de l'API. Certaines lignes sont affichées avec un code non résolu par le jeu
-- (ex. « Rend 5 $|point:points: toutes les 5s ») : le nombre reste lisible, on le lit quand même.
-- Source du libellé : ITEM_MOD_MANA_REGENERATION (texte localisé du jeu). UNVERIFIED : voir /fsb debug.
local MP5_KEY = "ITEM_MOD_MANA_REGENERATION_SHORT"

local function ManaRegenPattern()
    local fmt = _G.ITEM_MOD_MANA_REGENERATION
    if type(fmt) ~= "string" then return nil, nil end
    local prefix = fmt:match("^(.-)%%d")
    if not prefix or prefix == "" then return nil, nil end
    local escaped = prefix:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return "^%s*" .. escaped .. "%s*(%d+)", fmt
end

function Compat.ParseManaRegen(text)
    local prefixPattern, fmt = ManaRegenPattern()
    if not prefixPattern or type(text) ~= "string" then return nil end
    local n = text:match(prefixPattern)
    if not n then return nil end
    -- Texte normal complet, ou texte « cassé » (code non résolu) qui mentionne bien « 5 s ».
    local full = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%d", "%%d+")
    if text:match("^%s*" .. full) or ((text:find("$|", 1, true) or text:find("|", 1, true)) and text:match("%f[%d]5%s*s")) then
        return tonumber(n)
    end
end

local function TextStats(link)
    if not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" then
            local mp5 = Compat.ParseManaRegen(text)
            if mp5 then return { [MP5_KEY] = mp5 } end
        end
    end
end

-- Statistiques d'un objet : table { [clé] = valeur numérique } ou nil. Complétées par le MP5 du texte si absent de l'API.
-- Le résultat est mis en cache par lien (les stats d'un lien ne changent pas).
local statsCache, statsCount = {}, 0

function Compat.GetStats(link)
    if not link or not C_Item or not C_Item.GetItemStats then return nil end
    if statsCache[link] then return statsCache[link] end
    local ok, raw = pcall(C_Item.GetItemStats, link)
    if not ok or type(raw) ~= "table" then return nil end
    local stats = {}
    for key, value in pairs(raw) do
        if type(value) == "number" then stats[key] = value end
    end
    if stats[MP5_KEY] == nil then
        local extra = TextStats(link)
        if extra then stats[MP5_KEY] = extra[MP5_KEY] end
    end
    -- Pas de cache si rien n'est lu : l'objet n'est peut-être pas encore chargé côté client.
    if next(stats) then
        if statsCount >= 500 then statsCache, statsCount = {}, 0 end
        statsCache[link], statsCount = stats, statsCount + 1
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
