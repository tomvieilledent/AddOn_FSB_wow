-- Journal des hésitations : luajit tests/log.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Core/Compat",
    "Core/Context", "Core/Log", "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine",
    "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)

FSB.Log.Add("TEST", { link = "L1" }); FSB.Log.Add("TEST", { link = "L1" }); FSB.Log.Add("TEST", { link = "L2" })
check("dédoublonnage par raison + objet", FSB.Log.Count() == 2 and FSB.db.log[1].count == 2)
FSB.Log.Add("GLOBAL", { global = true, link = "A" }); FSB.Log.Add("GLOBAL", { global = true, link = "B" })
check("entrée globale unique", FSB.Log.Count() == 3 and FSB.db.log[3].count == 2 and FSB.db.log[3].link == "B")
check("rapport exportable", FSB.Log.Report():find("TEST", 1, true) and FSB.Log.Report():find("x2", 1, true))
FSB.db.logDisabled = true; FSB.Log.Add("OFF", { link = "X" })
check("journal désactivé : rien enregistré", FSB.Log.Count() == 3)
FSB.db.logDisabled = nil
for i = 1, 400 do FSB.Log.Add("MANY", { link = "L" .. i }) end
check("journal borné", FSB.Log.Count() == 300)
FSB.Log.Clear(); check("vidage", FSB.Log.Count() == 0)

-- Intégration : stats inconnues et verdict limite journalisés par l'analyseur
_G.C_Item = { GetItemStats = function() return { ITEM_MOD_HEALING_NEW = 5, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 10 } end, GetItemInfo = function() end }
_G.GetInventoryItemLink = function() end
_G.C_TooltipInfo = nil
FSB.Analyzer.InvalidateAll()
FSB.Analyzer.Analyze("lien", "INVTYPE_CHEST")
local reasons = {}
for _, e in ipairs(FSB.db.log) do reasons[e.reason] = e end
check("stats inconnues journalisées", reasons.STATS_INCONNUES and reasons.STATS_INCONNUES.detail == "ITEM_MOD_HEALING_NEW")
check("utilisabilité illisible journalisée", reasons.UTILISABILITE_ILLISIBLE)
-- cas limite : objet remplaçant une pièce quasi équivalente
_G.C_Item.GetItemStats = function(l) return { ITEM_MOD_SPELL_HEALING_DONE_SHORT = l == "porte" and 100 or 102 } end
_G.GetInventoryItemLink = function(u, slot) return slot == FSB.Stats.SLOT.CHEST and "porte" or nil end
FSB.Analyzer.InvalidateAll(); FSB.Log.Clear()
FSB.Analyzer.Analyze("neuf", "INVTYPE_CHEST")
local limit
for _, e in ipairs(FSB.db.log) do if e.reason == "VERDICT_LIMITE" then limit = e end end
check("verdict limite journalisé", limit ~= nil)
T.finish("journal")
