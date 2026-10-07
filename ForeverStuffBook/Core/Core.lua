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
    -- Le mode manuel n'existe plus : on nettoie les anciens réglages.
    FSB.db.manualSpecID, FSB.db.autoProfile, FSB.db.specPromptDone, FSB.db.specProfiles = nil, nil, nil, nil
    FSB.build = (select(1, GetBuildInfo and GetBuildInfo() or "?") or "?") .. " v" .. (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "?")
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

-- Poids du profil actif, à titre indicatif (non modifiables).
function Commands.poids()
    local profile = FSB.Profiles.GetActive()
    local lines = { profile.name .. " (poids fixes, indicatifs)" }
    for _, s in ipairs(FSB.Stats.KEYS) do
        local w = profile.weights[s.key]
        if w then lines[#lines + 1] = ("%s = %s"):format(s.label, w) end
    end
    FSB.Utils.Report(lines)
end

function Commands.role() if FSB.UI and FSB.UI.ShowRolePicker then FSB.UI.ShowRolePicker(true) end end

function Commands.specs() FSB.Probe.AllSpecs() end

-- /fsb log [vider|off|on] : affiche le journal des hésitations pour l'envoyer au développement.
function Commands.log(rest)
    if rest == "vider" then FSB.Log.Clear(); return Print(FSB.L.LOG_CLEARED) end
    if rest == "off" then FSB.db.logDisabled = true; return Print(FSB.L.LOG_OFF) end
    if rest == "on" then FSB.db.logDisabled = nil; return Print(FSB.L.LOG_ON) end
    if FSB.UI and FSB.UI.ShowLog then FSB.UI.ShowLog(FSB.Log.Report()) else Print(FSB.Log.Report()) end
end

-- /fsb mauvais [commentaire] : signale que le verdict du dernier objet survolé est faux.
function Commands.mauvais(rest)
    if not FSB.lastLink then return Print(FSB.L.LOG_NOITEM) end
    local verdict = FSB.lastVerdict
    FSB.Log.Add("SIGNALE_MAUVAIS", { link = FSB.lastLink, verdict = verdict, detail = rest })
    Print(FSB.L.LOG_FLAGGED)
end

function Commands.debug() FSB.Probe.Debug() end

function Commands.sonde() FSB.Probe.Print() end

function Commands.inconnus()
    local lines = {}
    for key in pairs(FSB.db.unknownStats) do lines[#lines + 1] = key end
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
