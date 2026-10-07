-- Utilisabilité (classe/armure/arme/niveau) : luajit tests/usability.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Core/Compat",
    "Core/Context", "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine",
    "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)

_G.ITEM_MIN_LEVEL = "Requires Level %d"
_G.UnitLevel = function() return 20 end
local RED, WHITE = { r = 1, g = 0.125, b = 0.125 }, { r = 1, g = 1, b = 1 }
local tips = {}
_G.C_TooltipInfo = { GetHyperlink = function(l) return tips[l] end }
_G.C_Item = { GetItemStats = function() return { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 50 } end,
    GetItemInfo = function() end }
_G.GetInventoryItemLink = function() end

tips.usable = { lines = { { leftText = "Robe", leftColor = WHITE }, { leftText = "Cloth", rightColor = WHITE } } }
tips.cuir = { lines = { { leftText = "Chest" }, { leftText = "x", rightText = "Leather", rightColor = RED } } }
tips.epee = { lines = { { leftText = "Sword", leftColor = RED } } }
tips.lvl = { lines = { { leftText = "Requires Level 30", leftColor = RED } } }
tips.both = { lines = { { leftText = "Requires Level 30", leftColor = RED }, { leftText = "Classes: Mage", leftColor = RED } } }

local function u(l) return FSB.Compat.GetUsability(l) end
check("utilisable", u("usable").unusable == false and u("usable").reqLevel == nil)
check("armure inutilisable (rouge)", u("cuir").unusable)
check("arme inutilisable (rouge)", u("epee").unusable)
check("niveau seul : utilisable + niveau requis", not u("lvl").unusable and u("lvl").reqLevel == 30)
check("niveau + classe : inutilisable", u("both").unusable and u("both").reqLevel == 30)
check("tooltip illisible -> nil (aucun filtre)", u("inconnu") == nil)

local ring = "INVTYPE_CHEST"
local v = FSB.Analyzer.Analyze("cuir", ring)
check("inutilisable -> pas À ÉQUIPER", v.kind == "SELL" and v.unusable)
v = FSB.Analyzer.Analyze("lvl", ring)
check("niveau trop bas : verdict conservé + note", v.kind == "EQUIP" and v.reqLevel == 30)
v = FSB.Analyzer.Analyze("usable", ring)
check("utilisable : À ÉQUIPER sans note", v.kind == "EQUIP" and v.reqLevel == nil and not v.unusable)
_G.UnitLevel = function() return 30 end; FSB.Analyzer.InvalidateAll()
check("niveau atteint : plus de note", FSB.Analyzer.Analyze("lvl", ring).reqLevel == nil)
_G.GetInventoryItemLink = function(u, slot) return slot == FSB.Stats.SLOT.CHEST and "porte" or nil end
local realGet = FSB.Compat.GetStats
FSB.Compat.GetStats = function(l) if l == "porte" then return nil end return realGet(l) end
FSB.Analyzer.InvalidateAll()
check("pièce portée illisible : pas de verdict d'équipement", FSB.Analyzer.Analyze("usable", ring).kind == "UNKNOWN")
T.finish("utilisabilité")
