-- Tests purs du moteur (hors jeu) : luajit tests/run.lua
local FSB = {}
local base = "ForeverStuffBook/"
for _, f in ipairs{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles",
    "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/VerdictEngine" } do
    assert(loadfile(base .. f .. ".lua"))("FSB", FSB)
end
FSB.db = {}
FSB.Profiles.Init(FSB.db)

local S = FSB.Stats.SLOT
local HEAL, MAGE, PHYS = FSB.db.profiles[1], FSB.db.profiles[2], FSB.db.profiles[3]
local function item(stats, twoHand) return { stats = stats, twoHand = twoHand } end
local function solo(loc, stats, equipped, active, dw)
    return FSB.Verdict.Solo({ equipLoc = loc, stats = stats, equipped = equipped,
        canDualWield = dw ~= false, profiles = FSB.db.profiles, active = active or HEAL })
end

local fails, total = 0, 0
local function check(name, cond)
    total = total + 1
    if not cond then fails = fails + 1; print("ECHEC: " .. name) end
end

local HP, INT, AP = "ITEM_MOD_HEALING_POWER_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT"
local SP = "ITEM_MOD_SPELL_POWER_SHORT"

-- objet supérieur / inférieur
local worn = { [S.CHEST] = item{ [HP] = 20, [INT] = 10 } }
check("supérieur", solo("INVTYPE_CHEST", { [HP] = 30, [INT] = 15 }, worn).kind == "EQUIP")
check("inférieur (soigneur) -> pas équiper", solo("INVTYPE_CHEST", { [HP] = 10 }, worn).kind ~= "EQUIP")
-- petite différence sous le seuil
check("différence minuscule", solo("INVTYPE_CHEST", { [HP] = 20, [INT] = 10, ITEM_MOD_STAMINA_SHORT = 1 }, worn).kind ~= "EQUIP")
-- off-spé : bon pour dégâts physiques, inutile pour le soigneur
local r = solo("INVTYPE_CHEST", { [AP] = 80 }, worn, HEAL)
check("off-spé", r.kind == "OFFSPEC" and r.profile == "Dégâts physiques")
-- objet inutile
check("inutile", solo("INVTYPE_CHEST", { ITEM_MOD_UNKNOWN = 50 }, worn).kind == "SELL")
-- emplacement vide
check("emplacement vide", solo("INVTYPE_HEAD", { [HP] = 5 }, {}).kind == "EQUIP")

-- deux anneaux : remplace le moins bon
local rings = { [S.FINGER1] = item{ [HP] = 50 }, [S.FINGER2] = item{ [HP] = 10 } }
local d, slot = FSB.Optimizer.Evaluate("INVTYPE_FINGER", { [HP] = 30 }, rings, HEAL.weights, true)
check("anneaux : meilleur emplacement", slot == S.FINGER2 and d > 0)
check("anneaux : moins bon que les deux", solo("INVTYPE_FINGER", { [HP] = 5 }, rings).kind ~= "EQUIP")
-- deux bijoux
local trk = { [S.TRINKET1] = item{ [HP] = 10 }, [S.TRINKET2] = item{ [HP] = 60 } }
d, slot = FSB.Optimizer.Evaluate("INVTYPE_TRINKET", { [HP] = 40 }, trk, HEAL.weights, true)
check("bijoux : remplace le plus faible", slot == S.TRINKET1)

-- armes : 2M remplace main + off ; comparaison de la configuration finale
local gear = { [S.MAINHAND] = item{ [HP] = 40 }, [S.OFFHAND] = item{ [HP] = 40 } }
check("2M < 1M+off", solo("INVTYPE_2HWEAPON", { [HP] = 60 }, gear).kind ~= "EQUIP")
check("2M > 1M+off", solo("INVTYPE_2HWEAPON", { [HP] = 100 }, gear).kind == "EQUIP")
-- 2M portée : une 1M mieux que la 2M seule
local with2h = { [S.MAINHAND] = item({ [HP] = 40 }, true) }
check("1M > 2M portée", solo("INVTYPE_WEAPON", { [HP] = 60 }, with2h).kind == "EQUIP")
-- bouclier impossible avec une 2M portée
check("bouclier avec 2M portée ignoré", FSB.Optimizer.Evaluate("INVTYPE_SHIELD", { [HP] = 99 }, with2h, HEAL.weights, true) == nil)
-- pas de double maniement
d, slot = FSB.Optimizer.Evaluate("INVTYPE_WEAPON", { [HP] = 99 }, { [S.MAINHAND] = item{ [HP] = 90 } }, HEAL.weights, false)
check("sans DW : main droite uniquement", slot == S.MAINHAND)

-- seuil configurable
FSB.db.thresholds = { upgradeRel = 0.6, upgradeAbs = 1 }
check("seuil relevé", solo("INVTYPE_CHEST", { [HP] = 30, [INT] = 15 }, worn).kind ~= "EQUIP")

print(("%d/%d tests OK"):format(total - fails, total))
os.exit(fails == 0 and 0 or 1)
