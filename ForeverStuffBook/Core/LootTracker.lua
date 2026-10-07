local _, FSB = ...

-- Suivi passif du butin d'équipement reçu pendant l'instance en cours, par joueur du groupe. Lit uniquement le
-- message de butin du chat (CHAT_MSG_LOOT) : aucune action de jeu. Sert à l'équité du verdict « meilleur pour un
-- autre » (un joueur déjà servi doit justifier un plus gros upgrade). Remis à zéro à chaque nouvelle instance ou
-- quand le groupe se dissout. UNVERIFIED sur Forever : format et lisibilité du message, voir /fsb rapport.
local Tracker = {}
FSB.LootTracker = Tracker

local counts = {}      -- [nom normalisé] = nombre d'objets d'équipement reçus
local instanceKey
local recent = {}      -- derniers messages bruts (diagnostic)
local MAX_RECENT = 6

-- Chaînes du jeu (textes localisés du client) : « X reçoit le butin : [objet]. », variantes « multiple »,
-- « bonus » et « vous recevez... ». kind = other (nom + objet) ou self (objet seul).
local DEFS = {
    { "LOOT_ITEM_MULTIPLE", "other" }, { "LOOT_ITEM", "other" },
    { "LOOT_ITEM_PUSHED_MULTIPLE", "other" }, { "LOOT_ITEM_PUSHED", "other" },
    { "LOOT_ITEM_SELF_MULTIPLE", "self" }, { "LOOT_ITEM_SELF", "self" },
    { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "self" }, { "LOOT_ITEM_PUSHED_SELF", "self" },
}

local patterns
local function BuildPatterns()
    patterns = {}
    for _, def in ipairs(DEFS) do
        local fmt = _G[def[1]]
        if type(fmt) == "string" then
            local p = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
            local n = 0
            p = p:gsub("%%%%s", function()
                n = n + 1
                return (def[2] == "other" and n == 1) and "(.-)" or "(.+)"
            end)
            p = p:gsub("%%%%d", "%%d+")
            patterns[#patterns + 1] = { pattern = "^" .. p .. "$", kind = def[2] }
        end
    end
end

-- Nom sans lien de joueur, sans code de couleur ni royaume.
local function Normalize(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("|H.-|h%[(.-)%]|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and name or nil
end
Tracker.Normalize = Normalize

local function IsGear(link)
    if not link or not link:find("|Hitem:", 1, true) then return false end
    local U = FSB.Utils
    if not U.GetEquipLoc(link) then return false end
    local quality = U.GetQuality(link)
    return quality == nil or quality >= U.MIN_QUALITY -- qualité inconnue (objet non chargé) : on compte
end

local function Add(name)
    name = Normalize(name)
    if not name then return end
    counts[name] = (counts[name] or 0) + 1
    if FSB.Analyzer then FSB.Analyzer.InvalidateGroup() end
end

-- Message de butin du chat. Retourne le nom compté ou nil.
function Tracker.OnMessage(text)
    local ok, result = pcall(function()
        if type(text) ~= "string" then return nil end
        recent[#recent + 1] = text
        if #recent > MAX_RECENT then table.remove(recent, 1) end
        if not patterns then BuildPatterns() end
        for _, p in ipairs(patterns) do
            local a, b = text:match(p.pattern)
            if a then
                local name, link = a, b
                if p.kind == "self" then name, link = UnitName and UnitName("player"), a end
                if IsGear(link) then Add(name); return Normalize(name) end
                return nil
            end
        end
    end)
    return ok and result or nil
end

function Tracker.Count(name)
    return counts[Normalize(name) or ""] or 0
end

function Tracker.Remove(name)
    counts[Normalize(name) or ""] = nil
end

function Tracker.Reset()
    if next(counts) then
        counts = {}
        if FSB.Analyzer then FSB.Analyzer.InvalidateGroup() end
    end
    instanceKey = nil
end

-- Nouvelle instance ou sortie du mode groupe : on repart de zéro.
function Tracker.Sync()
    if not FSB.Context.IsGroupMode() then return Tracker.Reset() end
    local ok, _, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
    local key = ok and id or nil
    if key and instanceKey and key ~= instanceKey then
        counts = {}
        if FSB.Analyzer then FSB.Analyzer.InvalidateGroup() end
    end
    instanceKey = key or instanceKey
end

-- Lignes de diagnostic pour /fsb rapport.
function Tracker.Describe()
    local lines, names = {}, {}
    for name in pairs(counts) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do lines[#lines + 1] = ("  butin compté : %s = %d"):format(name, counts[name]) end
    if #names == 0 then lines[1] = "  aucun butin d'équipement compté dans cette instance" end
    lines[#lines + 1] = "  derniers messages de butin reçus (" .. #recent .. ") :"
    for _, text in ipairs(recent) do lines[#lines + 1] = "    " .. tostring(text) end
    return lines
end
