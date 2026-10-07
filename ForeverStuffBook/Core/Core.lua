local ADDON, FSB = ...

FSB.name = ADDON
local defaults = {
    enabled = true, autoProfile = true, specPromptDone = false, specChoice = {},
    unknownStats = {}, specProfiles = {}, display = {},
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
        if not FSB.Spec.Apply() and not FSB.db.specPromptDone and FSB.UI and FSB.UI.ShowSpecPicker then
            FSB.db.specPromptDone = true
            FSB.UI.ShowSpecPicker()
        else
            FSB.Spec.PromptIfNeeded()
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
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = function() FSB.Spec.Apply(); FSB.Spec.PromptIfNeeded() end,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        InitDB()
        frame:UnregisterEvent("ADDON_LOADED")
        for name in pairs(handlers) do frame:RegisterEvent(name) end
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

function Commands.profils()
    local lines = {}
    for _, p in ipairs(FSB.Profiles.List()) do
        lines[#lines + 1] = p.name .. (p.name == FSB.db.activeProfile and " *" or "")
    end
    FSB.Utils.Report(lines)
end

function Commands.profil(rest)
    if rest == "" then return Print(FSB.L.PROFILE_ACTIVE:format(FSB.db.activeProfile)) end
    if FSB.Profiles.SetActive(rest) then
        Print(FSB.L.PROFILE_ACTIVE:format(rest))
    else
        Print(FSB.L.PROFILE_UNKNOWN:format(rest))
    end
end

function Commands.auto()
    FSB.db.autoProfile = true
    FSB.Spec.Apply()
    Print(FSB.L.AUTO_ON)
end

function Commands.nouveau(rest)
    if FSB.Profiles.Create(rest) then Print(FSB.L.PROFILE_CREATED:format(rest)) else Print(FSB.L.PROFILE_EXISTS:format(rest)) end
end

function Commands.supprimer(rest)
    if not FSB.Profiles.Find(rest) then return Print(FSB.L.PROFILE_UNKNOWN:format(rest)) end
    if FSB.Profiles.Delete(rest) then Print(FSB.L.PROFILE_DELETED:format(rest)) else Print(FSB.L.PROFILE_KEEP_ONE) end
end

function Commands.poids(rest)
    local profile = FSB.Profiles.GetActive()
    local alias, value = rest:match("^(%S+)%s+(%-?[%d%.]+)$")
    if not alias then
        local lines = {}
        for _, s in ipairs(FSB.Stats.KEYS) do
            local w = profile.weights[s.key]
            if w then lines[#lines + 1] = ("%s (%s) = %s"):format(s.label, s.alias, w) end
        end
        return FSB.Utils.Report(lines)
    end
    local key = FSB.Stats.FromAlias(alias)
    if not key then return Print(FSB.L.STAT_UNKNOWN:format(alias)) end
    FSB.Profiles.SetWeight(profile, key, tonumber(value))
    Print(FSB.L.WEIGHT_SET:format(FSB.Stats.Label(key), value, profile.name))
end

function Commands.set(rest)
    local profile = FSB.Profiles.GetActive()
    local value = tonumber(rest)
    if not value then return Print(FSB.L.SET_VALUE:format(profile.setBonusValue or 0, profile.name)) end
    FSB.Profiles.SetBonusValue(profile, value)
    Print(FSB.L.SET_VALUE:format(value, profile.name))
end

function Commands.role() if FSB.UI and FSB.UI.ShowRolePicker then FSB.UI.ShowRolePicker(true) end end

function Commands.spe() if FSB.UI and FSB.UI.ShowSpecPicker then FSB.UI.ShowSpecPicker() end end

function Commands.specprofil(rest)
    if FSB.Spec.MapCurrentTo(rest) then Print(FSB.L.SPEC_MAPPED:format(rest)) else Print(FSB.L.PROFILE_UNKNOWN:format(rest)) end
end

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
    add(FSB.L.STATE_SPEC:format(spec or "?", FSB.db.activeProfile, FSB.db.autoProfile and "auto" or "manuel"))
    local info = spec and FSB.Spec.Info(spec)
    add(("Spé brute : détectée=%s manuelle=%s rôle=%s stat principale=%s"):format(
        tostring(FSB.Spec.Detect()), tostring(FSB.db.manualSpecID),
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
