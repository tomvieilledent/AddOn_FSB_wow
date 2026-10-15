-- Localisation français / anglais : luajit tests/locale.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Localization/enUS", "Utils/Utils", "Data/Stats", "Data/Weights", "Data/Profiles" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)

local fr, en = FSB.Locales.frFR, FSB.Locales.enUS
local missing = {}
for key, value in pairs(fr) do
    if en[key] == nil then missing[#missing + 1] = key
    elseif type(value) == "table" and key ~= "STATS" and key ~= "ROLE_PARTS" and #value ~= #en[key] then missing[#missing + 1] = key .. "(taille)" end
end
check("toutes les clés françaises existent en anglais" .. (#missing > 0 and (" : " .. table.concat(missing, ",")) or ""), #missing == 0)

local missingStats = {}
for _, s in ipairs(FSB.Stats.KEYS) do
    if not fr.STATS[s.key] or not en.STATS[s.key] then missingStats[#missingStats + 1] = s.key end
end
check("toutes les stats sont traduites (fr + en)" .. (#missingStats > 0 and (" : " .. table.concat(missingStats, ",")) or ""), #missingStats == 0)

-- Noms affichés des profils : classe, arbre, mode et rôle sans spé traduits dans les deux langues
local missingNames = {}
for _, lang in ipairs({ fr, en }) do
    for _, p in ipairs(FSB.db.profiles) do
        local ok = lang.CLASS_NAMES[p.class] and lang.MODES[p.mode]
            and (p.tree == 0 and lang.LOW_ROLES[p.class] or (p.tree > 0 and lang.TREE_NAMES[p.class][p.tree]))
            and (not p.variant or lang.FERAL_FORMS[p.variant])
        if not ok then missingNames[#missingNames + 1] = p.name end
    end
end
check("tous les profils ont un nom traduit" .. (#missingNames > 0 and (" : " .. table.concat(missingNames, ",")) or ""), #missingNames == 0)
local roleWords = {}
for _, info in pairs(FSB.Weights.ROLE_INFO) do
    for _, w in ipairs(info) do if not en.ROLE_PARTS[w] then roleWords[#roleWords + 1] = w end end
end
check("mots du rôle traduits en anglais" .. (#roleWords > 0 and (" : " .. table.concat(roleWords, ",")) or ""), #roleWords == 0)

local holy = FSB.Profiles.For("PRIEST", 2, "PVE").name
check("français par défaut", FSB.L.VERDICT_EQUIP == "À ÉQUIPER" and FSB.Profiles.DisplayName(holy) == "Prêtre · Sacré · PvE 60")
check("changement de langue", FSB.SetLanguage("enUS") and FSB.L.VERDICT_EQUIP == "EQUIP" and FSB.db.language == "enUS")
check("nom de profil traduit", FSB.Profiles.DisplayName(holy) == "Priest · Holy · PvE 60" and FSB.Stats.Label("ITEM_MOD_STAMINA_SHORT") == "Stamina")
check("rôle traduit", FSB.Profiles.RoleLabel(FSB.Profiles.Find(holy)) == "Heal · Magic · Ranged")
check("druide ours traduit", FSB.Profiles.DisplayName(FSB.Profiles.For("DRUID", 2, "PVP", "BEAR").name) == "Druid · Feral (bear) · PvP")
en.TEST_ONLY_FR = nil; fr.TEST_ONLY_FR = "seulement fr"
check("clé manquante : repli sur le français", FSB.L.TEST_ONLY_FR == "seulement fr")
check("langue inconnue refusée", FSB.SetLanguage("deDE") == false and FSB.language == "enUS")
FSB.SetLanguage("frFR")
check("retour au français", FSB.L.VERDICT_SELL == "VENDRE / DÉSENCHANTER")
local lines = FSB.Profiles.WeightLines(true)
check("poids : tous les profils listés", #lines > 40)
T.finish("langues")
