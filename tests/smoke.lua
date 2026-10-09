-- Chargement complet de l'addon dans l'ordre du TOC avec une API simulée minimale : luajit tests/smoke.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local T = H.counter(); local check = T.check

local printed = {}
_G.print = function(s) printed[#printed + 1] = s end
local handlers, hooks = {}, {}
-- Maquette graphique : tout objet renvoyé par Create* est lui-même une maquette, pour que la construction de
-- l'interface s'exécute réellement (une erreur y est signalée par « FSB: UI : ... »).
local function widget()
    local w
    w = setmetatable({}, { __index = function(_, name)
        return function(self, ...)
            if name == "SetScript" then handlers.onEvent = handlers.onEvent or select(2, ...) end
            if name:sub(1, 6) == "Create" or name == "GetChildren" then return widget() end
            if name == "IsShown" then return false end
            if name == "GetText" then return "" end
        end
    end })
    return w
end
_G.CreateFrame = function(_, _, _, _) return widget() end
_G.UIParent = widget(); _G.UISpecialFrames = {}; _G.tinsert = table.insert
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.SlashCmdList = {}
_G.C_Timer = { After = function(_, f) end, NewTicker = function() return { Cancel = function() end } end }
_G.IsInInstance = function() return false, "none" end
_G.IsInGroup = function() return false end
_G.C_Item = {
    GetItemInfoInstant = function(l) return 1, "a", "b", ({ ring = "INVTYPE_FINGER", pot = "" })[l] end,
    GetItemQualityByID = function(l) return 3 end,
    GetItemStats = function(l) return { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20, ITEM_MOD_NEW_THING = 3 } end,
    GetItemInfo = function() end,
}
_G.GetInventoryItemLink = function(u, s) end
_G.UnitClass = function() return "X", "X", 5 end
_G.Enum = { TooltipDataType = { Item = 1 } }
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, f) hooks.tooltip = f end }

local FSB = {}
for line in io.lines("ForeverStuffBuddy/ForeverStuffBuddy_Camelot.toc") do
    if line:match("%.lua$") then assert(loadfile("ForeverStuffBuddy/" .. line:gsub("\\", "/")))("ForeverStuffBuddy", FSB) end
end
-- le TOC par défaut doit lister les mêmes fichiers
local function files(p) local t = {}; for l in io.lines(p) do if l:match("%.lua$") then t[#t + 1] = l end end; return table.concat(t, "|") end
check("TOC identiques", files("ForeverStuffBuddy/ForeverStuffBuddy.toc") == files("ForeverStuffBuddy/ForeverStuffBuddy_Camelot.toc"))

_G.GetLocale = function() return "deDE" end
handlers.onEvent(nil, "ADDON_LOADED", "ForeverStuffBuddy")
check("client non français : interface en anglais par défaut", FSB.language == "enUS")
check("schéma des SavedVariables à jour", FSB.db.schema == 4)
check("SavedVariables initialisées", ForeverStuffBuddyDB and FSB.db.enabled and #FSB.db.profiles == 10)

local tt = { n = {}, GetItem = function(s) return "x", s.link end,
    AddLine = function(s, t) s.n[#s.n + 1] = t end, AddDoubleLine = function(s, t) s.n[#s.n + 1] = t end, Show = function() end }
tt.link = "ring"; hooks.tooltip(tt)
check("tooltip : verdict affiché pour un anneau", #tt.n >= 3)
check("stat inconnue enregistrée", FSB.db.unknownStats.ITEM_MOD_NEW_THING)
tt.n = {}; tt.link = "pot"; _G.C_Item.GetItemInfoInstant = function() return 1, "a", "b", "" end; hooks.tooltip(tt)
check("tooltip : non équipable ignoré", #tt.n == 0)

SlashCmdList.FSB("profil Tank"); check("plus de mode manuel : /fsb profil n'agit pas", FSB.db.activeProfile ~= "Tank" and FSB.db.autoProfile == nil)
SlashCmdList.FSB("poids"); SlashCmdList.FSB("poids int 42")
check("poids non modifiables", FSB.Profiles.GetActive().weights.ITEM_MOD_INTELLECT_SHORT ~= 42)
SlashCmdList.FSB("lang en"); check("/fsb lang en", FSB.language == "enUS" and FSB.db.language == "enUS")
t4 = { n = {}, GetItem = function() return "x", "ring" end, AddLine = function(s, t) s.n[#s.n + 1] = t end,
    AddDoubleLine = function(s, t) s.n[#s.n + 1] = t end, Show = function() end }
FSB.db.enabled = true; _G.C_Item.GetItemInfoInstant = function() return 1, "a", "b", "INVTYPE_FINGER" end
hooks.tooltip(t4)
check("verdict en anglais", t4.n[2] and (t4.n[2]:find("EQUIP", 1, true) or t4.n[2]:find("SELL", 1, true)))
SlashCmdList.FSB("lang fr"); check("/fsb lang fr", FSB.language == "frFR")
SlashCmdList.FSB("lang xx")
SlashCmdList.FSB("off"); check("/fsb off", FSB.db.enabled == false)
SlashCmdList.FSB("etat"); SlashCmdList.FSB("aide"); SlashCmdList.FSB("inconnus")
SlashCmdList.FSB("debug")
check("/fsb debug sans objet : pas d'erreur", true)
FSB.lastLink = "ring"; FSB.Probe.skipTooltips = true; SlashCmdList.FSB("debug")
check("/fsb debug stocke le détail", type(FSB.db.debug) == "table" and #FSB.db.debug > 3)
local shown
local realShow = FSB.UI.ShowText
FSB.UI.ShowText = function(text) shown = text end
SlashCmdList.FSB("etat")
check("/fsb etat : fenêtre de texte, pas de chat", shown and shown:find("Mode", 1, true))
shown = nil; SlashCmdList.FSB("inconnus")
check("/fsb inconnus : fenêtre de texte", shown ~= nil)
shown = nil; SlashCmdList.FSB("aide")
check("/fsb aide : fenêtre de texte", shown and shown:find("/fsb", 1, true))
shown = nil; FSB.lastLink = "ring"; SlashCmdList.FSB("rapport")
check("/fsb rapport : toutes les sections en une fenêtre", shown and shown:find("===== ÉTAT", 1, true)
    and shown:find("===== STATS INCONNUES", 1, true) and shown:find("===== POIDS DE TOUS LES PROFILS", 1, true)
    and shown:find("===== ENVIRONNEMENT", 1, true))
FSB.UI.ShowText = realShow
_G.C_SpecializationInfo = { GetNumSpecializationsForClassID = function() return 1 end,
    GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return 1487, "Prêtre", "", 626004, "DAMAGER", 4 end }
_G.GetSpecializationInfoForClassID = function() return 1487, "Prêtre", "", 626004, "DAMAGER" end
_G.GetSpecializationInfoForSpecID = function() return 1487, "Prêtre", "", 626004, "DAMAGER" end
local keepShow = FSB.UI.ShowText
FSB.UI.ShowText = function(text) shown = text end
shown = nil; SlashCmdList.FSB("etat")
FSB.UI.ShowText = keepShow
check("/fsb etat : spés de la classe lues (pas d'erreur)", shown and shown:find("spé 1 : 1487", 1, true)
    and shown:find("GetSpecializationInfo(index) : 1487", 1, true) and not shown:find(") : erreur", 1, true))
_G.C_SpecializationInfo, _G.GetSpecializationInfoForClassID, _G.GetSpecializationInfoForSpecID = nil, nil, nil
_G.IsInGroup = function() return true end; _G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() return 2 end
_G.UnitExists = function(u) return u == "party1" end
_G.UnitName = function() return "Guerrier" end
_G.UnitGroupRolesAssigned = function() return "TANK" end
_G.UnitIsConnected = function() return true end; _G.UnitIsVisible = function() return true end
_G.CanInspect = function() return true end
_G.UnitClass = function(u) return "X", u == "party1" and "WARRIOR" or "X", 5 end
FSB.UI.ShowText = function(text) shown = text end
shown = nil; SlashCmdList.FSB("rapport")
check("rapport : section GROUPE avec les membres", shown and shown:find("===== GROUPE", 1, true)
    and shown:find("party1 : Guerrier | classe=WARRIOR", 1, true) and shown:find("rôle=TANK", 1, true))
FSB.UI.ShowText = keepShow
SlashCmdList.FSB("specs")
check("/fsb specs sans API : pas d'erreur", FSB.db.allSpecs ~= nil)
SlashCmdList.FSB("sonde")
check("/fsb sonde stocke un rapport", type(FSB.db.probe) == "table" and #FSB.db.probe > 10)
local t2 = { n = {}, GetItem = function(s) return "x", "ring" end,
    AddLine = function(s, t) s.n[#s.n + 1] = t end, AddDoubleLine = function(s, t) s.n[#s.n + 1] = t end, Show = function() end }
_G.C_Item.GetItemInfoInstant = function() return 1, "a", "b", "INVTYPE_FINGER" end
FSB.db.enabled = true
hooks.tooltip(t2); local first = #t2.n; hooks.tooltip(t2)
check("tooltip : pas de doublon", first > 0 and #t2.n == first)
check("verdict avec icône par défaut", t2.n[2] and t2.n[2]:find("|T", 1, true))
FSB.db.display.icons = false; FSB.db.display.details = false
local t3 = { n = {}, GetItem = function() return "x", "ring" end,
    AddLine = function(s, t) s.n[#s.n + 1] = t end, AddDoubleLine = function(s, t) s.n[#s.n + 1] = t end, Show = function() end }
hooks.tooltip(t3)
check("options : sans icône ni détails", #t3.n == 3 and not t3.n[2]:find("|T", 1, true))
SlashCmdList.FSB(""); SlashCmdList.FSB("")  -- ouvre puis ferme la fenêtre : construction réelle de l'interface
FSB.UI.ShowRolePicker(); FSB.UI.ShowText("test")
local uiErrors = {}
for _, line in ipairs(printed) do if tostring(line):find("UI : ", 1, true) then uiErrors[#uiErrors + 1] = line end end
check("interface : aucune erreur de construction" .. (uiErrors[1] and (" -> " .. uiErrors[1]) or ""), #uiErrors == 0)
T.finish("chargement")
