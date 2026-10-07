-- Choix du rôle quand la spé est ambiguë : luajit tests/roles.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Data/Classes", "Core/Compat",
    "Core/Context", "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine",
    "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer", "Core/Spec" }
local T = H.counter(); local check = T.check
FSB.db = { autoProfile = true, specChoice = {}, specProfiles = {} }; FSB.Profiles.Init(FSB.db)
local classFile = "PRIEST"
_G.UnitClass = function() return "X", classFile, 5 end

local function names(l) local t = {}; for _, p in ipairs(l) do t[#t + 1] = p.name end; return table.concat(t, ",") end

FSB.db.manualSpecID = 1487
check("prêtre : question de rôle nécessaire", FSB.Spec.NeedsChoice())
check("prêtre : choix = soigneur ou dégâts magiques", names(FSB.Spec.Choices(1487)) == "Soigneur,Dégâts magiques")
FSB.Spec.Apply()
check("en attente du choix : profil inchangé", FSB.db.activeProfile == "Soigneur")
check("choix mémorisé", FSB.Spec.Choose("Dégâts magiques") and FSB.db.specChoice[1487] == "Dégâts magiques")
check("plus de question", not FSB.Spec.NeedsChoice())
FSB.db.activeProfile = "Soigneur"; FSB.Spec.Apply()
check("le choix mémorisé s'applique", FSB.db.activeProfile == "Dégâts magiques")
check("OFF-SPÉ du prêtre : ni tank ni physique", names(FSB.Spec.OffspecProfiles()) == "Soigneur,Dégâts magiques")

classFile = "MAGE"; FSB.db.manualSpecID = 5000
check("mage : un seul rôle, pas de question", not FSB.Spec.NeedsChoice())
FSB.Spec.Apply()
check("mage : profil dégâts magiques appliqué", FSB.db.activeProfile == "Dégâts magiques")

classFile = "DRUID"; FSB.db.manualSpecID = 77
FSB.Classes.BY_SPEC[77] = { "Tank", "Dégâts physiques" }
check("druide féral : tank ou dps seulement", names(FSB.Spec.Choices(77)) == "Tank,Dégâts physiques" and FSB.Spec.NeedsChoice())
FSB.Spec.Choose("Tank")
check("druide : tank mémorisé pour cette spé", FSB.db.activeProfile == "Tank" and not FSB.Spec.NeedsChoice())

FSB.db.autoProfile = false; FSB.db.specChoice = {}
check("mode manuel : aucune question", not FSB.Spec.NeedsChoice())
T.finish("rôles")
