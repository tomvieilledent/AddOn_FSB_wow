local ADDON, FSB = ...

FSB.name = ADDON
local defaults = {
    enabled = true, specChoice = {},
    unknownStats = {}, display = {},
    -- thresholds : nil = valeurs par défaut du VerdictEngine
}

local function InitDB()
    ForeverStuffBookDB = ForeverStuffBookDB or {}
    for k, v in pairs(defaults) do
        if ForeverStuffBookDB[k] == nil then
            ForeverStuffBookDB[k] = type(v) == "table" and {} or v
        end
    end
    FSB.db = ForeverStuffBookDB
    -- Langue : choix mémorisé, sinon celle du client (français si le client est en français, sinon anglais).
    if FSB.db.language and FSB.Locales[FSB.db.language] then
        FSB.language = FSB.db.language
    else
        FSB.language = (GetLocale and GetLocale() == "frFR") and "frFR" or "enUS"
    end
    -- Le mode manuel n'existe plus : on nettoie les anciens réglages.
    for key in pairs(FSB.db.unknownStats or {}) do
        if FSB.Stats.IsKnown(key) then FSB.db.unknownStats[key] = nil end -- reconnues depuis
    end
    for key in pairs(FSB.db.specChoice or {}) do
        if not tostring(key):find(":", 1, true) then FSB.db.specChoice[key] = nil end -- ancien format de clé
    end
    FSB.db.manualSpecID, FSB.db.autoProfile, FSB.db.specPromptDone, FSB.db.specProfiles = nil, nil, nil, nil
    FSB.build = (select(1, GetBuildInfo and GetBuildInfo() or "?") or "?") .. " v" .. FSB.Utils.AddonVersion(ADDON)
    FSB.Profiles.Init(FSB.db)
end

---------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------

-- Groupe ou zone changé : recalcul du mode, du scan et du cache de groupe.
local function RefreshGroupState()
    FSB.Context.Refresh()
    if IsInGroup and not IsInGroup() then
        FSB.Inspector.Reset()
    else
        FSB.Inspector.Refresh()
    end
end

local function OnEnteringWorld()
    RefreshGroupState()
    -- Les données de talents peuvent arriver un peu après la connexion.
    C_Timer.After(3, function()
        FSB.Analyzer.InvalidateAll() -- les données de spé ont pu arriver après les premiers survols
        if FSB.Spec.Apply() then
            FSB.Spec.PromptIfNeeded()
        else
            FSB.Log.Add("SPE_NON_DETECTEE", { global = true })
        end
    end)
end

local handlers = {
    PLAYER_ENTERING_WORLD = OnEnteringWorld,
    ZONE_CHANGED_NEW_AREA = RefreshGroupState,
    GROUP_ROSTER_UPDATE = RefreshGroupState,
    PLAYER_LEVEL_UP = function() FSB.Analyzer.InvalidateAll() end,
    PLAYER_EQUIPMENT_CHANGED = function(slot) FSB.Analyzer.InvalidateSlot(slot) end,
    INSPECT_READY = function(guid) FSB.Inspector.OnInspectReady(guid) end,
    UNIT_INVENTORY_CHANGED = function(unit) FSB.Inspector.OnUnitInventoryChanged(unit) end,
    PLAYER_SPECIALIZATION_CHANGED = function(unit)
        if unit == nil or unit == "player" then FSB.Spec.Apply(); FSB.Spec.PromptIfNeeded() end
    end,
    -- Changement de talents : l'arbre actif (donc le rôle possible) peut changer. Événements Classic/moderne ;
    -- ceux qui n'existent pas sur Forever sont ignorés à l'enregistrement.
    PLAYER_TALENT_UPDATE = function() FSB.Spec.Apply(); FSB.Spec.PromptIfNeeded(); FSB.Analyzer.InvalidateAll() end,
    CHARACTER_POINTS_CHANGED = function() FSB.Spec.Apply(); FSB.Spec.PromptIfNeeded(); FSB.Analyzer.InvalidateAll() end,
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = function() FSB.Spec.Apply(); FSB.Spec.PromptIfNeeded() end,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        InitDB()
        frame:UnregisterEvent("ADDON_LOADED")
        for name in pairs(handlers) do pcall(frame.RegisterEvent, frame, name) end
        FSB.Utils.Print(FSB.L.ADDON_LOADED)
        return
    end
    local handler = handlers[event]
    if handler then handler(arg1) end
end)

---------------------------------------------------------------------------------------------
-- Commandes (l'interface graphique s'ouvre avec /fsb)
---------------------------------------------------------------------------------------------

local Commands = {}
local Print = FSB.Utils.Print

function Commands.on()  FSB.db.enabled = true;  Print(FSB.L.ENABLED) end
function Commands.off() FSB.db.enabled = false; Print(FSB.L.DISABLED) end

function Commands.aide() FSB.Utils.Report(FSB.L.HELP) end

-- Poids de tous les profils, à titre indicatif (non modifiables).
function Commands.poids() FSB.Utils.Report(FSB.Profiles.WeightLines(true)) end

-- /fsb lang fr|en : change la langue de l'interface et des verdicts.
function Commands.lang(rest)
    local codes = { fr = "frFR", en = "enUS", frfr = "frFR", enus = "enUS" }
    local code = codes[rest:lower()]
    if not code then return Print(FSB.L.LANG_UNKNOWN:format(rest)) end
    FSB.SetLanguage(code)
    Print(FSB.L.LANG_CHANGED)
end

function Commands.role() if FSB.UI and FSB.UI.ShowRolePicker then FSB.UI.ShowRolePicker(true) end end

function Commands.specs() FSB.Probe.AllSpecs() end

-- /fsb log [vider|off|on] : affiche le journal des hésitations pour l'envoyer au développement.
function Commands.log(rest)
    if rest == "vider" then FSB.Log.Clear(); return Print(FSB.L.LOG_CLEARED) end
    if rest == "off" then FSB.db.logDisabled = true; return Print(FSB.L.LOG_OFF) end
    if rest == "on" then FSB.db.logDisabled = nil; return Print(FSB.L.LOG_ON) end
    FSB.Utils.Report({ FSB.Log.Report() })
end

-- /fsb mauvais [commentaire] : signale que le verdict du dernier objet survolé est faux.
function Commands.mauvais(rest)
    if not FSB.lastLink then return Print(FSB.L.LOG_NOITEM) end
    local verdict = FSB.lastVerdict
    FSB.Log.Add("SIGNALE_MAUVAIS", { link = FSB.lastLink, verdict = verdict, detail = rest })
    Print(FSB.L.LOG_FLAGGED)
end

-- /fsb rapport : toutes les informations de diagnostic d'un seul coup, dans une fenêtre copiable.
function Commands.rapport()
    local buffer = {}
    local sections = {
        { "ENVIRONNEMENT", function() FSB.Utils.Report(FSB.Probe.Environment()) end },
        { "ÉTAT", Commands.etat },
        { "GROUPE", function() local lines = {}; FSB.Probe.Group(function(t) lines[#lines + 1] = t end); FSB.Utils.Report(lines) end },
        { "SONDE DES API", FSB.Probe.Print },
        { "STATS INCONNUES", Commands.inconnus },
        { "JOURNAL DES HÉSITATIONS", Commands.log },
        { "DERNIER OBJET SURVOLÉ", FSB.Probe.Debug },
        { "SPÉCIALISATIONS DE TOUTES LES CLASSES", FSB.Probe.AllSpecs },
        { "POIDS DE TOUS LES PROFILS", Commands.poids },
    }
    for _, section in ipairs(sections) do
        buffer[#buffer + 1] = "===== " .. section[1] .. " ====="
        FSB.Utils.sink = function(lines) for _, l in ipairs(lines) do buffer[#buffer + 1] = l end end
        local ok, err = pcall(section[2], "")
        FSB.Utils.sink = nil
        if not ok then buffer[#buffer + 1] = "ERREUR : " .. tostring(err) end
        buffer[#buffer + 1] = ""
    end
    FSB.Utils.Report(buffer)
end
Commands.tout, Commands.report = Commands.rapport, Commands.rapport

function Commands.debug() FSB.Probe.Debug() end

function Commands.sonde() FSB.Probe.Print() end

function Commands.inconnus()
    local lines = {}
    for key in pairs(FSB.db.unknownStats) do
        if not FSB.Stats.IsKnown(key) then lines[#lines + 1] = key end
    end
    table.sort(lines)
    if #lines == 0 then lines[1] = FSB.L.NO_UNKNOWN end
    FSB.Utils.Report(lines)
end

-- Diagnostic : état du contexte et du scan (utile pour les tests en jeu).
function Commands.etat()
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    add(FSB.L.STATE:format(FSB.Context.IsGroupMode() and "GROUPE" or "SOLO",
        FSB.Inspector.CountPending(), #FSB.Inspector.GetComparableMembers()))
    local spec = FSB.Spec.Current()
    add(FSB.L.STATE_SPEC:format(spec or "?", FSB.db.activeProfile))
    local info = spec and FSB.Spec.Info(spec)
    add(("Spé brute : détectée=%s rôle=%s stat principale=%s"):format(
        tostring(FSB.Spec.Detect()),
        tostring(info and info.role), tostring(info and info.primaryStat)))
    add(FSB.L.LOG_COUNT:format(FSB.Log.Count()))
    FSB.Probe.Specs(add)
    FSB.Probe.Traits(add)
    local names = {}
    for _, p in ipairs(FSB.Spec.OffspecProfiles()) do names[#names + 1] = p.name end
    add("Profils testés pour OFF-SPÉ : " .. table.concat(names, ", "))
    FSB.Utils.Report(lines)
end

SLASH_FSB1 = "/fsb"
SlashCmdList["FSB"] = function(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local handler = Commands[cmd:lower()]
    if handler then return handler(rest) end
    if cmd == "" and FSB.UI and FSB.UI.Toggle then return FSB.UI.Toggle() end
    Commands.aide()
end
