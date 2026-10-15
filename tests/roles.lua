-- Détection automatique de la spé (talents) et du mode (niveau, PvE/PvP) : luajit tests/roles.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Weights", "Data/Profiles", "Data/Classes",
    "Data/Equipment", "Core/Compat", "Core/Context", "Core/Log", "Engine/ScoreEngine", "Engine/EquipmentOptimizer",
    "Engine/SetBonusEngine", "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer", "Core/Spec" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)
local classFile, level, instanceType = "PRIEST", 60, "none"
_G.UnitClass = function() return "X", classFile, 5 end
_G.UnitLevel = function() return level end
_G.IsInInstance = function() return instanceType ~= "none", instanceType end

local function names(l) local t = {}; for _, p in ipairs(l) do t[#t + 1] = p.name end; return table.concat(t, ",") end
local function active() return FSB.db.activeProfile end

-- Données de poids --------------------------------------------------------------------------------
local W = FSB.Weights
local rowsOK = true
for _, s in ipairs(W.SPECS) do for _, m in ipairs(W.MODES) do if #s[5][m] ~= #W.COLUMNS then rowsOK = false end end end
for _, s in ipairs(W.LOW) do for _, m in ipairs(W.LOW_MODES) do if #s[3][m] ~= #W.COLUMNS then rowsOK = false end end end
check("chaque ligne de poids a toutes les colonnes", rowsOK)
check("102 profils : 28 spés/variantes x 3 modes + 9 classes x 2 modes bas niveau", #FSB.db.profiles == 102)
local roleInfoOK = true
for _, s in ipairs(W.SPECS) do
    if not W.ROLE_INFO[s[1] .. ":" .. s[2] .. (s.variant and (":" .. s.variant) or "")] then roleInfoOK = false end
end
check("rôle · type · portée connu pour chaque spé", roleInfoOK)
local frost = FSB.Profiles.For("MAGE", 3, "PVE")
check("mage Givre : école Givre valorisée, pas l'Ombre", frost.weights.ITEM_MOD_FROST_DAMAGE_DONE_SHORT > frost.weights.ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT)
check("toucher générique = max(mêlée, distance)", FSB.Profiles.For("HUNTER", 3, "PVE").weights.ITEM_MOD_HIT_RATING_SHORT == 4.2)

-- Arbres de talents (disposition Classic : nom, icône, points) ---------------------------------------
local points = { 0, 12, 31 }
local treeNames = { "Discipline", "Sacré", "Ombre" }
_G.GetNumTalentTabs = function() return 3 end
_G.GetTalentTabInfo = function(i) return treeNames[i], "icone", points[i], "fond" end
check("arbre actif = le plus de points", select(2, FSB.Spec.ActiveTree()) == "Ombre" and FSB.Spec.Tree() == 3)
FSB.Spec.Apply()
check("prêtre Ombre niveau 60 : profil Ombre PvE, sans question", active() == "Prêtre · Ombre · PvE 60")
check("libellé « Spé »", FSB.Spec.Label():find("Spé : ", 1, true) and FSB.Spec.Label():find("Ombre", 1, true))
check("rôle affiché : DPS · Magique · Distance", FSB.Profiles.RoleLabel(FSB.Profiles.GetActive()) == "DPS · Magique · Distance")
check("OFF-SPÉ : les 3 arbres du prêtre dans le même mode",
    names(FSB.Spec.OffspecProfiles()) == "Prêtre · Discipline · PvE 60,Prêtre · Sacré · PvE 60,Prêtre · Ombre · PvE 60")
points = { 20, 11, 0 }; FSB.Spec.Apply()
check("plus de points en Discipline : Discipline (soigneur)", active() == "Prêtre · Discipline · PvE 60")
points = { 5, 5, 0 }; FSB.Spec.Apply()
check("égalité : l'arbre déjà détecté est gardé", active() == "Prêtre · Discipline · PvE 60")
FSB.db.lastTree = {}; FSB.Spec.Apply()
check("égalité sans historique : premier des ex æquo", active() == "Prêtre · Discipline · PvE 60" and FSB.Spec.Tree() == 1)
points = { 3, 9, 0 }; FSB.Spec.Apply()
points = { 0, 0, 0 }; FSB.Spec.Apply()
check("aucun point : dernier arbre détecté, libellé « Classe »",
    active() == "Prêtre · Sacré · PvE 60" and select(2, FSB.Spec.Tree()) == false and FSB.Spec.Label():find("Classe : ", 1, true))

-- Modes : niveau, PvE / PvP, donjon bas niveau -----------------------------------------------------------
points = { 0, 0, 31 }
level = 35; FSB.Spec.Apply()
check("niveau 35 : Leveling 10–59", active() == "Prêtre · Ombre · Leveling 10–59")
FSB.db.playstyle = "PVP"; FSB.Spec.Apply()
check("style PvP : profil PvP dès le niveau 10", active() == "Prêtre · Ombre · PvP")
level = 5; FSB.Spec.Apply()
check("niveau 5 : pas de spé, profil de classe Leveling 1–9 (PvP sans effet)",
    active() == "Prêtre · Magie / soins · Leveling 1–9" and FSB.Profiles.GetActive().tree == 0)
instanceType = "party"; FSB.Spec.Apply()
check("niveau 5 en donjon : Donjons bas niveau", active() == "Prêtre · Magie / soins · Donjons bas niveau")
check("pas d'OFF-SPÉ sous le niveau 10", #FSB.Spec.OffspecProfiles() == 1)
instanceType = "none"; level = 60; FSB.db.playstyle = nil; FSB.Spec.Apply()
check("retour au PvE 60", active() == "Prêtre · Ombre · PvE 60")
check("lieu : extérieur / donjon / raid / champ de bataille", FSB.Context.Place() == "OUTSIDE"
    and (function() instanceType = "raid"; local r = FSB.Context.Place() == "RAID"; instanceType = "none"; return r end)())

-- Mage Givre : disposition moderne de GetTalentTabInfo -----------------------------------------------
classFile = "MAGE"; points = { 0, 0, 40 }; treeNames = { "Arcanes", "Feu", "Givre" }
_G.GetTalentTabInfo = function(i) return 100 + i, treeNames[i], "desc", "icone", points[i] end
FSB.Spec.Apply()
check("disposition moderne reconnue : mage Givre", active() == "Mage · Givre · PvE 60")

-- Druide farouche : ours ou félin ---------------------------------------------------------------------
classFile = "DRUID"; treeNames = { "Équilibre", "Combat farouche", "Restauration" }; points = { 0, 31, 0 }
local asked = 0
FSB.UI = { ShowFeralPicker = function() asked = asked + 1 end }
FSB.Spec.Apply()
check("druide farouche sans choix : félin + question posée", active() == "Druide · Combat farouche (félin) · PvE 60" and asked == 1)
FSB.db.feralForm = "BEAR"; FSB.Spec.Apply()
check("ours choisi : profil ours, rôle Tank", active() == "Druide · Combat farouche (ours) · PvE 60"
    and FSB.Profiles.RoleLabel(FSB.Profiles.GetActive()) == "Tank · Physique · CAC" and asked == 1)
points = { 31, 0, 0 }; FSB.Spec.Apply()
check("druide Équilibre : ni question ni variante", active() == "Druide · Équilibre · PvE 60" and not FSB.Spec.IsFeral() and asked == 1)
FSB.db.feralForm = nil; classFile = "MAGE"; points = { 0, 0, 40 }; treeNames = { "Arcanes", "Feu", "Givre" }
FSB.Spec.Apply()
check("autre classe : jamais de question ours/félin", asked == 1)
FSB.UI = nil

-- Talents C_Traits : trois arbres côte à côte, lus par position (données réelles d'un prêtre) -------------
_G.GetNumTalentTabs, _G.GetTalentTabInfo = nil, nil
classFile = "PRIEST"
local nodes = {
    { 1620, 3330, 3 }, { 2220, 2730, 2 },                 -- Discipline (x 1020..2820)
    { 5020, 3330, 6 }, { 6220, 2130, 0 }, { 9280, 21300, 0 }, -- Sacré (x 5020..6820) + nœud aberrant (y 21300)
    { 9680, 3930, 0 }, { 10280, 5130, 0 },                 -- Ombre (x 9080..10880)
}
local withPositions = true
_G.C_ClassTalents = { GetActiveConfigID = function() return 99 end }
_G.C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 7 } } end,
    GetTreeNodes = function() local ids = {}; for i = 1, #nodes do ids[i] = i end; return ids end,
    GetNodeInfo = function(_, id)
        local n = nodes[id]
        return { posX = withPositions and n[1] or nil, posY = withPositions and n[2] or nil, currentRank = n[3] }
    end,
}
FSB.db.lastTree = {}
local idx, tname = FSB.Spec.ActiveTree()
check("C_Traits : arbre actif = bande avec le plus de points", idx == 2 and tname == "Sacré")
FSB.Spec.Apply()
check("C_Traits : prêtre Sacré appliqué sans question", active() == "Prêtre · Sacré · PvE 60")
nodes[3][3], nodes[6][3] = 0, 9
check("C_Traits : Ombre", select(2, FSB.Spec.ActiveTree()) == "Ombre")
nodes[5][3] = 50 -- le nœud aberrant (y=21300) ne compte jamais
check("C_Traits : nœud à position aberrante ignoré", select(2, FSB.Spec.ActiveTree()) == "Ombre")
nodes[5][3] = 0
nodes[8] = { 15000, 3930, 0 }
check("C_Traits : nombre de bandes inattendu -> aucune lecture", FSB.Spec.ReadTrees() == nil)
nodes[8] = nil
withPositions = false
check("C_Traits : sans positions, aucune lecture", FSB.Spec.ActiveTree() == nil)
_G.C_ClassTalents, _G.C_Traits = nil, nil

-- Détection lisible (onglet Détection) et classe sans poids -------------------------------------------
local d = FSB.Spec.Describe()
check("onglet Détection : tous les champs", d.class == "Prêtre" and d.spec and d.role and d.level:find("60", 1, true)
    and d.mode:find("PvE", 1, true) and d.place == "Extérieur" and d.profile)
classFile = "DEATHKNIGHT"
check("classe sans poids : aucun profil appliqué", FSB.Spec.Apply() == false)
T.finish("rôles")
