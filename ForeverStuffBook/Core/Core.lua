local ADDON, FSB = ...

FSB.name = ADDON
local defaults = { enabled = true, unknownStats = {}, thresholds = nil }

local function InitDB()
    ForeverStuffBookDB = ForeverStuffBookDB or {}
    for k, v in pairs(defaults) do
        if ForeverStuffBookDB[k] == nil then ForeverStuffBookDB[k] = v end
    end
    FSB.db = ForeverStuffBookDB
    FSB.Profiles.Init(FSB.db)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        frame:UnregisterEvent("ADDON_LOADED")
        FSB.Utils.Print(FSB.L.ADDON_LOADED)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        FSB.Analyzer.InvalidateSlot(arg1)
    end
end)

-- Commandes : l'interface graphique (/fsb sans argument) arrivera en phase 7.
local Commands = {}

function Commands.on()  FSB.db.enabled = true;  FSB.Utils.Print(FSB.L.ENABLED) end
function Commands.off() FSB.db.enabled = false; FSB.Utils.Print(FSB.L.DISABLED) end

function Commands.profils()
    for _, p in ipairs(FSB.Profiles.List()) do
        local mark = p.name == FSB.db.activeProfile and " *" or ""
        FSB.Utils.Print(p.name .. mark)
    end
end

function Commands.profil(rest)
    if rest == "" then return FSB.Utils.Print(FSB.L.PROFILE_ACTIVE:format(FSB.db.activeProfile)) end
    if FSB.Profiles.SetActive(rest) then
        FSB.Utils.Print(FSB.L.PROFILE_ACTIVE:format(rest))
    else
        FSB.Utils.Print(FSB.L.PROFILE_UNKNOWN:format(rest))
    end
end

function Commands.nouveau(rest)
    if FSB.Profiles.Create(rest) then
        FSB.Utils.Print(FSB.L.PROFILE_CREATED:format(rest))
    else
        FSB.Utils.Print(FSB.L.PROFILE_EXISTS:format(rest))
    end
end

function Commands.supprimer(rest)
    if not FSB.Profiles.Find(rest) then return FSB.Utils.Print(FSB.L.PROFILE_UNKNOWN:format(rest)) end
    if FSB.Profiles.Delete(rest) then
        FSB.Utils.Print(FSB.L.PROFILE_DELETED:format(rest))
    else
        FSB.Utils.Print(FSB.L.PROFILE_KEEP_ONE)
    end
end

function Commands.poids(rest)
    local profile = FSB.Profiles.GetActive()
    local alias, value = rest:match("^(%S+)%s+(%-?[%d%.]+)$")
    if not alias then
        for _, s in ipairs(FSB.Stats.KEYS) do
            local w = profile.weights[s.key]
            if w then FSB.Utils.Print(("%s (%s) = %s"):format(s.label, s.alias, w)) end
        end
        return
    end
    local key = FSB.Stats.FromAlias(alias)
    if not key then return FSB.Utils.Print(FSB.L.STAT_UNKNOWN:format(alias)) end
    FSB.Profiles.SetWeight(profile, key, tonumber(value))
    FSB.Utils.Print(FSB.L.WEIGHT_SET:format(FSB.Stats.Label(key), value, profile.name))
end

function Commands.inconnus()
    local any = false
    for key in pairs(FSB.db.unknownStats) do any = true; FSB.Utils.Print(key) end
    if not any then FSB.Utils.Print(FSB.L.NO_UNKNOWN) end
end

SLASH_FSB1 = "/fsb"
SlashCmdList["FSB"] = function(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local handler = Commands[cmd:lower()]
    if handler then return handler(rest) end
    for _, line in ipairs(FSB.L.HELP) do FSB.Utils.Print(line) end
end
