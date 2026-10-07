local ADDON, FSB = ...

FSB.name = ADDON
local defaults = {
    enabled = true, autoProfile = true, specPromptDone = false,
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
    PLAYER_SPECIALIZATION_CHANGED = function(unit) if unit == nil or unit == "player" then FSB.Spec.Apply() end end,
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = function() FSB.Spec.Apply() end,
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

function Commands.aide() for _, line in ipairs(FSB.L.HELP) do Print(line) end end

function Commands.profils()
    for _, p in ipairs(FSB.Profiles.List()) do
        Print(p.name .. (p.name == FSB.db.activeProfile and " *" or ""))
    end
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
        for _, s in ipairs(FSB.Stats.KEYS) do
            local w = profile.weights[s.key]
            if w then Print(("%s (%s) = %s"):format(s.label, s.alias, w)) end
        end
        return
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

function Commands.spe() if FSB.UI and FSB.UI.ShowSpecPicker then FSB.UI.ShowSpecPicker() end end

function Commands.specprofil(rest)
    if FSB.Spec.MapCurrentTo(rest) then Print(FSB.L.SPEC_MAPPED:format(rest)) else Print(FSB.L.PROFILE_UNKNOWN:format(rest)) end
end

function Commands.debug() FSB.Probe.Debug() end

function Commands.sonde() FSB.Probe.Print() end

function Commands.inconnus()
    local any = false
    for key in pairs(FSB.db.unknownStats) do any = true; Print(key) end
    if not any then Print(FSB.L.NO_UNKNOWN) end
end

-- Diagnostic : état du contexte et du scan (utile pour les tests en jeu).
function Commands.etat()
    Print(FSB.L.STATE:format(FSB.Context.IsGroupMode() and "GROUPE" or "SOLO",
        FSB.Inspector.CountPending(), #FSB.Inspector.GetComparableMembers()))
    local spec = FSB.Spec.Current()
    Print(FSB.L.STATE_SPEC:format(spec or "?", FSB.db.activeProfile, FSB.db.autoProfile and "auto" or "manuel"))
    local info = spec and FSB.Spec.Info(spec)
    Print(("Spé brute : détectée=%s manuelle=%s rôle=%s stat principale=%s"):format(
        tostring(FSB.Spec.Detect()), tostring(FSB.db.manualSpecID),
        tostring(info and info.role), tostring(info and info.primaryStat)))
    FSB.Probe.Specs(Print)
    local names = {}
    for _, p in ipairs(FSB.Spec.OffspecProfiles()) do names[#names + 1] = p.name end
    Print("Profils testés pour OFF-SPÉ : " .. table.concat(names, ", "))
end

SLASH_FSB1 = "/fsb"
SlashCmdList["FSB"] = function(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local handler = Commands[cmd:lower()]
    if handler then return handler(rest) end
    if cmd == "" and FSB.UI and FSB.UI.Toggle then return FSB.UI.Toggle() end
    Commands.aide()
end
