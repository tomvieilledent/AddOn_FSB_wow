-- Localisation français / anglais : luajit tests/locale.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Localization/enUS", "Utils/Utils", "Data/Stats", "Data/Profiles" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)

local fr, en = FSB.Locales.frFR, FSB.Locales.enUS
local missing = {}
for key, value in pairs(fr) do
    if en[key] == nil then missing[#missing + 1] = key
    elseif type(value) == "table" and key ~= "PROFILES" and key ~= "STATS" and #value ~= #en[key] then missing[#missing + 1] = key .. "(taille)" end
end
check("toutes les clés françaises existent en anglais" .. (#missing > 0 and (" : " .. table.concat(missing, ",")) or ""), #missing == 0)

local missingStats = {}
for _, s in ipairs(FSB.Stats.KEYS) do
    if not fr.STATS[s.key] or not en.STATS[s.key] then missingStats[#missingStats + 1] = s.key end
end
check("toutes les stats sont traduites (fr + en)" .. (#missingStats > 0 and (" : " .. table.concat(missingStats, ",")) or ""), #missingStats == 0)

local missingProfiles = {}
for _, p in ipairs(FSB.db.profiles) do if not en.PROFILES[p.name] then missingProfiles[#missingProfiles + 1] = p.name end end
check("tous les profils ont un nom anglais" .. (#missingProfiles > 0 and (" : " .. table.concat(missingProfiles, ",")) or ""), #missingProfiles == 0)

check("français par défaut", FSB.L.VERDICT_EQUIP == "À ÉQUIPER" and FSB.Profiles.DisplayName("Soigneur") == "Soigneur")
check("changement de langue", FSB.SetLanguage("enUS") and FSB.L.VERDICT_EQUIP == "EQUIP" and FSB.db.language == "enUS")
check("nom de profil traduit", FSB.Profiles.DisplayName("Soigneur") == "Healer" and FSB.Stats.Label("ITEM_MOD_STAMINA_SHORT") == "Stamina")
en.TEST_ONLY_FR = nil; fr.TEST_ONLY_FR = "seulement fr"
check("clé manquante : repli sur le français", FSB.L.TEST_ONLY_FR == "seulement fr")
check("langue inconnue refusée", FSB.SetLanguage("deDE") == false and FSB.language == "enUS")
FSB.SetLanguage("frFR")
check("retour au français", FSB.L.VERDICT_SELL == "VENDRE / DÉSENCHANTER")
local lines = FSB.Profiles.WeightLines(true)
check("poids : tous les profils listés", #lines > 40)
T.finish("langues")
