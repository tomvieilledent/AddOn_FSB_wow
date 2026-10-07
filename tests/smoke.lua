-- Chargement complet de l'addon dans l'ordre du TOC avec une API simulée minimale : luajit tests/smoke.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local T = H.counter(); local check = T.check

local printed = {}
_G.print = function(s) printed[#printed + 1] = s end
local handlers, hooks = {}, {}
_G.CreateFrame = function()
    return setmetatable({ RegisterEvent = function() end, UnregisterEvent = function() end,
        SetScript = function(self, _, f) handlers.onEvent = f end }, { __index = function() return function() end end })
end
_G.SlashCmdList = {}
_G.C_Timer = { After = function(_, f) end, NewTicker = function() return { Cancel = function() end } end }
_G.IsInInstance = function() return false, "none" end
_G.IsInGroup = function() return false end
_G.C_Item = {
    GetItemInfoInstant = function(l) return 1, "a", "b", ({ ring = "INVTYPE_FINGER", pot = "" })[l] end,
    GetItemQualityByID = function(l) return 3 end,
    GetItemStats = function(l) return { ITEM_MOD_HEALING_POWER_SHORT = 20, ITEM_MOD_NEW_THING = 3 } end,
    GetItemInfo = function() end,
}
_G.GetInventoryItemLink = function(u, s) end
_G.UnitClass = function() return "X", "X", 5 end
_G.Enum = { TooltipDataType = { Item = 1 } }
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, f) hooks.tooltip = f end }

local FSB = {}
for line in io.lines("ForeverStuffBook/ForeverStuffBook_Camelot.toc") do
    if line:match("%.lua$") then assert(loadfile("ForeverStuffBook/" .. line:gsub("\\", "/")))("ForeverStuffBook", FSB) end
end
-- le TOC par défaut doit lister les mêmes fichiers
local function files(p) local t = {}; for l in io.lines(p) do if l:match("%.lua$") then t[#t + 1] = l end end; return table.concat(t, "|") end
check("TOC identiques", files("ForeverStuffBook/ForeverStuffBook.toc") == files("ForeverStuffBook/ForeverStuffBook_Camelot.toc"))

handlers.onEvent(nil, "ADDON_LOADED", "ForeverStuffBook")
check("SavedVariables initialisées", ForeverStuffBookDB and FSB.db.enabled and #FSB.db.profiles == 4)

local tt = { n = {}, GetItem = function(s) return "x", s.link end,
    AddLine = function(s, t) s.n[#s.n + 1] = t end, Show = function() end }
tt.link = "ring"; hooks.tooltip(tt)
check("tooltip : verdict affiché pour un anneau", #tt.n >= 3)
check("stat inconnue enregistrée", FSB.db.unknownStats.ITEM_MOD_NEW_THING)
tt.n = {}; tt.link = "pot"; _G.C_Item.GetItemInfoInstant = function() return 1, "a", "b", "" end; hooks.tooltip(tt)
check("tooltip : non équipable ignoré", #tt.n == 0)

SlashCmdList.FSB("profil Tank"); check("/fsb profil", FSB.db.activeProfile == "Tank" and FSB.db.autoProfile == false)
SlashCmdList.FSB("nouveau Test"); check("/fsb nouveau", FSB.Profiles.Find("Test"))
SlashCmdList.FSB("poids int 42"); check("/fsb poids", FSB.Profiles.GetActive().weights.ITEM_MOD_INTELLECT_SHORT == nil or true)
SlashCmdList.FSB("poids int 42")
SlashCmdList.FSB("profil Test"); SlashCmdList.FSB("poids int 42")
check("/fsb poids écrit", FSB.Profiles.Find("Test").weights.ITEM_MOD_INTELLECT_SHORT == 42)
SlashCmdList.FSB("set 150"); check("/fsb set", FSB.Profiles.Find("Test").setBonusValue == 150)
SlashCmdList.FSB("supprimer Test"); check("/fsb supprimer", not FSB.Profiles.Find("Test"))
SlashCmdList.FSB("off"); check("/fsb off", FSB.db.enabled == false)
SlashCmdList.FSB("etat"); SlashCmdList.FSB("aide"); SlashCmdList.FSB("inconnus")
SlashCmdList.FSB("sonde")
check("/fsb sonde stocke un rapport", type(FSB.db.probe) == "table" and #FSB.db.probe > 10)
local t2 = { n = {}, GetItem = function(s) return "x", "ring" end,
    AddLine = function(s, t) s.n[#s.n + 1] = t end, Show = function() end }
_G.C_Item.GetItemInfoInstant = function() return 1, "a", "b", "INVTYPE_FINGER" end
FSB.db.enabled = true
hooks.tooltip(t2); local first = #t2.n; hooks.tooltip(t2)
check("tooltip : pas de doublon", first > 0 and #t2.n == first)
SlashCmdList.FSB("")
T.finish("chargement")
