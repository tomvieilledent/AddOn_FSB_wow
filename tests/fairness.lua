-- Équité du loot en donjon : luajit tests/fairness.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Core/Context", "Core/LootTracker",
    "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine", "Engine/SpecEngine", "Engine/VerdictEngine",
    "Engine/ItemAnalyzer" }
local T = H.counter(); local check = T.check
FSB.db = { lootFairness = true }; FSB.Profiles.Init(FSB.db)
local S, HP = FSB.Stats.SLOT, "ITEM_MOD_SPELL_HEALING_DONE_SHORT"

-- Verdict : seuil relevé pour un joueur déjà servi ---------------------------------------------------
local me = { name = "Moi", weights = { [HP] = 100 } }
local function ctx(memberEquipHP, memberLoot, myLoot)
    return { equipLoc = "INVTYPE_CHEST", stats = { [HP] = 30 }, equipped = { [S.CHEST] = { stats = { [HP] = 20 } } },
        profiles = { me }, active = me, myLoot = myLoot or 0,
        members = { { name = "Autre", weights = { [HP] = 100 },
            equipped = memberEquipHP and { [S.CHEST] = { stats = { [HP] = memberEquipHP } } } or {}, loot = memberLoot } } }
end
check("sans malus : gros upgrade pour un autre -> meilleur pour un autre", FSB.Verdict.Group(ctx(11, 0)).kind == "BETTER_OTHER")
check("déjà 3 objets : même upgrade -> je le prends", FSB.Verdict.Group(ctx(11, 3)).kind == "TAKE")
local big = FSB.Verdict.Group(ctx(nil, 3))
check("déjà 3 objets mais énorme upgrade (emplacement vide) -> il peut l'avoir", big.kind == "BETTER_OTHER")
check("la note « déjà servi » est fournie", big.served and big.served[1] == "Autre (3)")
check("c'est moi le plus servi : seuil abaissé pour l'autre", FSB.Verdict.Group(ctx(18, 0, 3)).kind == "BETTER_OTHER"
    and FSB.Verdict.Group(ctx(18, 0, 0)).kind == "TAKE")
FSB.db.lootFairness = false
check("équité désactivée : le butin n'influence plus", FSB.Verdict.Group(ctx(11, 3)).kind == "BETTER_OTHER"
    and FSB.Verdict.Group(ctx(18, 0, 3)).kind == "TAKE")
FSB.db.lootFairness = true
FSB.db.thresholds = { otherMargin = 9 }
check("marge très haute : le malus ne la baisse pas, jamais meilleur pour un autre", FSB.Verdict.Group(ctx(nil, 0)).kind == "TAKE")
FSB.db.thresholds = nil

-- Suivi du butin (messages du chat) --------------------------------------------------------------
_G.LOOT_ITEM = "%s reçoit le butin : %s."
_G.LOOT_ITEM_MULTIPLE = "%s reçoit le butin : %sx%d."
_G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
_G.UnitName = function() return "Moi" end
_G.C_Item = { GetItemInfoInstant = function(l) return 1, "a", "b", l:find("Epee") and "INVTYPE_WEAPON" or "" end,
    GetItemQualityByID = function(l) return l:find("Gris") and 0 or 3 end }
local L = FSB.LootTracker
local function link(name) return "|cff0070dd|Hitem:123::::::::|h[" .. name .. "]|h|r" end
check("butin d'un autre joueur compté", L.OnMessage("Jacque reçoit le butin : " .. link("Epee noire") .. ".") == "Jacque" and L.Count("Jacque") == 1)
check("nom avec royaume et lien de joueur", L.OnMessage("|Hplayer:Jacque-Royaume:1|h[Jacque-Royaume]|h reçoit le butin : " .. link("Epee") .. ".") == "Jacque" and L.Count("Jacque") == 2)
check("mon propre butin compté", L.OnMessage("Vous recevez le butin : " .. link("Epee") .. ".") == "Moi" and L.Count("Moi") == 1)
check("objet non équipable ignoré", L.OnMessage("Jacque reçoit le butin : " .. link("Potion") .. ".") == nil and L.Count("Jacque") == 2)
check("objet gris ignoré", L.OnMessage("Jacque reçoit le butin : " .. link("Epee Gris") .. ".") == nil and L.Count("Jacque") == 2)
check("message sans rapport ignoré", L.OnMessage("Bonjour tout le monde") == nil)
check("message illisible : aucune erreur", L.OnMessage(nil) == nil)
check("rapport : derniers messages conservés", #L.Describe() >= 4)
L.Remove("Jacque"); check("membre parti : butin retiré", L.Count("Jacque") == 0)
L.Reset(); check("remise à zéro", L.Count("Moi") == 0)
T.finish("équité")
