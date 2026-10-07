-- Choix du rôle quand la spé est ambiguë : luajit tests/roles.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Data/Classes", "Core/Compat",
    "Core/Context", "Core/Log", "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine",
    "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer", "Core/Spec" }
local T = H.counter(); local check = T.check
FSB.db = { specChoice = {}, specProfiles = {} }; FSB.Profiles.Init(FSB.db)
local classFile = "PRIEST"
_G.UnitClass = function() return "X", classFile, 5 end

local function names(l) local t = {}; for _, p in ipairs(l) do t[#t + 1] = p.name end; return table.concat(t, ",") end

local detected = 1487
FSB.Spec.Detect = function() return detected end
check("prêtre : question de rôle nécessaire", FSB.Spec.NeedsChoice())
check("prêtre : choix = soigneur ou dégâts magiques", names(FSB.Spec.Choices(1487)) == "Soigneur,Dégâts magiques")
FSB.Spec.Apply()
check("en attente du choix : profil inchangé", FSB.db.activeProfile == "Soigneur")
check("choix mémorisé", FSB.Spec.Choose("Dégâts magiques") and FSB.db.specChoice["1487:0"] == "Dégâts magiques")
check("plus de question", not FSB.Spec.NeedsChoice())
FSB.db.activeProfile = "Soigneur"; FSB.Spec.Apply()
check("le choix mémorisé s'applique", FSB.db.activeProfile == "Dégâts magiques")
check("OFF-SPÉ du prêtre : ni tank ni physique", names(FSB.Spec.OffspecProfiles()) == "Soigneur,Dégâts magiques")

classFile = "MAGE"; detected = 5000
check("mage : un seul rôle, pas de question", not FSB.Spec.NeedsChoice())
FSB.Spec.Apply()
check("mage : profil dégâts magiques appliqué", FSB.db.activeProfile == "Dégâts magiques")

classFile = "DRUID"; detected = 77
FSB.Classes.BY_SPEC[77] = { "Tank", "Dégâts physiques" }
check("druide féral : tank ou dps seulement", names(FSB.Spec.Choices(77)) == "Tank,Dégâts physiques" and FSB.Spec.NeedsChoice())
FSB.Spec.Choose("Tank")
check("druide : tank mémorisé pour cette spé", FSB.db.activeProfile == "Tank" and not FSB.Spec.NeedsChoice())

-- Arbres de talents (disposition Classic : nom, icône, points)
FSB.db.specChoice = {}; classFile = "PRIEST"; detected = 1487
local points = { 0, 12, 31 }
local names = { "Discipline", "Sacré", "Ombre" }
_G.GetNumTalentTabs = function() return 3 end
_G.GetTalentTabInfo = function(i) return names[i], "icone", points[i], "fond" end
check("arbre actif = le plus de points", select(2, FSB.Spec.ActiveTree()) == "Ombre" and FSB.Spec.ActiveTree() == 3)
check("prêtre Ombre : rôle unique, pas de question", not FSB.Spec.NeedsChoice())
FSB.Spec.Apply()
check("prêtre Ombre : profil Dégâts Ombre", FSB.db.activeProfile == "Dégâts Ombre")
check("libellé avec arbre", FSB.Spec.Label():find("Spé : ", 1, true) and FSB.Spec.Label():find("Ombre", 1, true))
points = { 20, 11, 0 }
check("prêtre Discipline : soin ou dégâts Sacré -> question", FSB.Spec.NeedsChoice() and FSB.Spec.Key(1487) == "1487:1")
FSB.Spec.Choose("Soigneur")
check("choix mémorisé pour cet arbre seulement", FSB.db.specChoice["1487:1"] == "Soigneur" and not FSB.Spec.NeedsChoice())
points = { 5, 5, 0 }
check("égalité : aucune devinette (retour aux rôles de la classe)", FSB.Spec.ActiveTree() == nil and FSB.Spec.NeedsChoice())
points = { 0, 0, 0 }
check("aucun point : pas d'arbre", FSB.Spec.ActiveTree() == nil)
classFile = "MAGE"; detected = 1482; points = { 0, 0, 40 }; names = { "Arcanes", "Feu", "Givre" }
FSB.Spec.Apply()
check("mage Givre : profil Dégâts Givre sans question", FSB.db.activeProfile == "Dégâts Givre" and not FSB.Spec.NeedsChoice())
_G.GetTalentTabInfo = function(i) return 100 + i, names[i], "desc", "icone", points[i] end
check("disposition moderne reconnue", select(2, FSB.Spec.ActiveTree()) == "Givre")
_G.GetNumTalentTabs, _G.GetTalentTabInfo = nil, nil
check("API de talents absente : pas d'arbre", FSB.Spec.ActiveTree() == nil)
FSB.db.specChoice = {}; detected = nil
check("spé non détectée : aucune question ni changement", not FSB.Spec.NeedsChoice() and FSB.Spec.Apply() == false)
T.finish("rôles")
