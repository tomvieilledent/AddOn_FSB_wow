-- Armes (combinaisons avec le sac), équipement par classe, compétence d'arme : luajit tests/equipment.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Weights", "Data/Profiles", "Data/Classes",
    "Data/Equipment", "Core/Compat", "Core/Context", "Engine/ScoreEngine", "Engine/EquipmentOptimizer",
    "Engine/SetBonusEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)
local S = FSB.Stats.SLOT
local SP, INT = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local MAGE = FSB.Profiles.For("MAGE", 3, "PVE")
local WAR = FSB.Profiles.For("WARRIOR", 2, "PVE")

-- Combinaisons d'armes -------------------------------------------------------------------------------
local staff = { link = "baton", stats = { [SP] = 40 }, twoHand = true }
local equipped = { [S.MAINHAND] = staff }
local orb = { link = "orbe", stats = { [SP] = 25, [INT] = 5 }, equipLoc = "INVTYPE_HOLDABLE", from = "BAG" }
local E = FSB.Optimizer.EvaluateWeapons

-- bâton porté + main gauche dans le sac + dague qui tombe
local d, slot, replaced, combo = E("INVTYPE_WEAPON", { [SP] = 30 }, equipped, { orb }, MAGE.weights, false)
check("dague + orbe du sac > bâton", d > 0 and slot == S.MAINHAND and combo.partner == orb and combo.partnerSlot == S.OFFHAND)
check("le bâton est signalé comme remplacé", combo.replaced[1] == "baton" and #combo.replaced == 1)
check("score remplacé = bâton", replaced == FSB.ScoreEngine.Score(staff.stats, MAGE.weights))
-- sans l'orbe, la dague seule est moins bonne que le bâton
d = E("INVTYPE_WEAPON", { [SP] = 30 }, equipped, {}, MAGE.weights, false)
check("dague seule < bâton", d < 0)
-- main gauche qui tombe + arme de main droite dans le sac
local dagger = { link = "dague", stats = { [SP] = 30 }, equipLoc = "INVTYPE_WEAPON", from = "BAG" }
d, slot, _, combo = E("INVTYPE_HOLDABLE", { [SP] = 25, [INT] = 5 }, equipped, { dagger }, MAGE.weights, false)
check("orbe + dague du sac > bâton", d > 0 and slot == S.OFFHAND and combo.partner == dagger)
-- 2M qui tombe : remplace main droite + main gauche
local pair = { [S.MAINHAND] = { link = "mh", stats = { [SP] = 20 } }, [S.OFFHAND] = { link = "oh", stats = { [SP] = 20 } } }
d, slot, _, combo = E("INVTYPE_2HWEAPON", { [SP] = 50 }, pair, {}, MAGE.weights, false)
check("2M > main droite + main gauche", d > 0 and slot == S.MAINHAND and #combo.replaced == 2 and combo.partner == nil)
-- arme portée réutilisée : reste équipée (change de main)
local warPair = { [S.MAINHAND] = { link = "epee", stats = { ITEM_MOD_STRENGTH_SHORT = 10 } } }
local poolEq = { { link = "epee", stats = { ITEM_MOD_STRENGTH_SHORT = 10 }, equipLoc = "INVTYPE_WEAPON", from = "EQUIPPED", slot = S.MAINHAND } }
d, slot, _, combo = E("INVTYPE_WEAPONMAINHAND", { ITEM_MOD_STRENGTH_SHORT = 15 }, warPair, poolEq, WAR.weights, true)
check("ambidextrie : nouvelle main droite, l'épée passe en main gauche",
    d > 0 and slot == S.MAINHAND and combo.partner == poolEq[1] and combo.partnerSlot == S.OFFHAND and #combo.replaced == 0)
-- sans ambidextrie : une arme de main gauche n'est jamais partenaire
local offWeapon = { link = "mg", stats = { [SP] = 99 }, equipLoc = "INVTYPE_WEAPONOFFHAND", from = "BAG" }
d, _, _, combo = E("INVTYPE_WEAPON", { [SP] = 30 }, equipped, { offWeapon }, MAGE.weights, false)
check("sans ambidextrie : arme de main gauche ignorée", combo.partner == nil and d < 0)
d, _, _, combo = E("INVTYPE_WEAPON", { [SP] = 30 }, equipped, { offWeapon }, MAGE.weights, true)
check("avec ambidextrie : arme de main gauche utilisée", combo.partner == offWeapon)
-- verdict complet : la combinaison est transmise au tooltip
local v = FSB.Verdict.Solo({ equipLoc = "INVTYPE_WEAPON", stats = { [SP] = 30 }, equipped = equipped,
    canDualWield = false, profiles = { MAGE }, active = MAGE, weaponPool = { orb } })
check("verdict : À ÉQUIPER avec l'orbe du sac", v.kind == "EQUIP" and v.combo and v.combo.partner == orb)
v = FSB.Verdict.Solo({ equipLoc = "INVTYPE_WEAPON", stats = { [SP] = 30 }, equipped = equipped,
    canDualWield = false, profiles = { MAGE }, active = MAGE })
check("verdict sans sac : comparaison simple (dague < bâton)", v.kind ~= "EQUIP")

-- Table Classic de l'équipement par classe ------------------------------------------------------------
local U = FSB.Equipment.CanUse
check("mage : plaques interdites", U("MAGE", 60, 4, 4, "INVTYPE_CHEST") == false)
check("guerrier : plaques à partir du niveau 40", U("WARRIOR", 39, 4, 4, "INVTYPE_CHEST") == false and U("WARRIOR", 40, 4, 4, "INVTYPE_CHEST") == true)
check("chasseur : mailles au niveau 40", U("HUNTER", 20, 4, 3, "INVTYPE_CHEST") == false and U("HUNTER", 40, 4, 3, "INVTYPE_CHEST") == true)
check("cape en tissu : tout le monde", U("WARRIOR", 1, 4, 1, "INVTYPE_CLOAK") == nil and U("MAGE", 1, 4, 1, "INVTYPE_CLOAK") == nil)
check("bouclier : chaman oui, druide non", U("SHAMAN", 10, 4, 6, "INVTYPE_SHIELD") == true and U("DRUID", 10, 4, 6, "INVTYPE_SHIELD") == false)
check("prêtre : pas de hache", U("PRIEST", 30, 2, 0, "INVTYPE_WEAPON") == false)
check("prêtre : bâton et baguette", U("PRIEST", 30, 2, 10, "INVTYPE_2HWEAPON") and U("PRIEST", 30, 2, 19, "INVTYPE_RANGEDRIGHT"))
check("paladin : pas d'arme en main gauche", U("PALADIN", 30, 2, 7, "INVTYPE_WEAPONOFFHAND") == false)
check("voleur : arme en main gauche", U("ROGUE", 30, 2, 15, "INVTYPE_WEAPONOFFHAND") == true)
check("canne à pêche : tout le monde", U("MAGE", 5, 2, 20, "INVTYPE_2HWEAPON") == true)
check("classe inconnue : aucune règle", U("DEATHKNIGHT", 60, 4, 4, "INVTYPE_CHEST") == nil)

-- Utilisabilité pour le joueur : table + tooltip, compétence d'arme manquante ------------------------
_G.UnitClass = function() return "Guerrier", "WARRIOR", 1 end
_G.UnitLevel = function() return 30 end
_G.CanDualWield = function() return true end
_G.ITEM_MIN_LEVEL = "Requires Level %d"
local RED, WHITE = { r = 1, g = 0.125, b = 0.125 }, { r = 1, g = 1, b = 1 }
local tips, info = {}, {}
_G.C_TooltipInfo = { GetHyperlink = function(l) return tips[l] end }
_G.C_Item = {
    GetItemInfoInstant = function(l) local i = info[l]; if i then return 1, "Arme", i[3], i[4], 0, i[1], i[2] end end,
    GetItemStats = function() return { ITEM_MOD_STRENGTH_SHORT = 10 } end, GetItemInfo = function() end,
}
info.hache2m = { 2, 1, "Haches à deux mains", "INVTYPE_2HWEAPON" }
tips.hache2m = { lines = { { leftText = "Deux mains", rightText = "Hache", rightColor = RED } } }
local u = FSB.Compat.GetPlayerUsability("hache2m")
check("compétence d'arme manquante : utilisable, compétence signalée", u and u.unusable == false and u.needsSkill == "Hache")
info.plaques = { 4, 4, "Plaques", "INVTYPE_CHEST" }
tips.plaques = { lines = { { leftText = "Torse", rightText = "Plaques", rightColor = RED } } }
u = FSB.Compat.GetPlayerUsability("plaques")
check("plaques avant 40 : inutilisable (pas une compétence d'arme)", u.unusable and not u.needsSkill)
info.robe = { 4, 1, "Tissu", "INVTYPE_ROBE" }
tips.robe = { lines = { { leftText = "Robe", leftColor = WHITE } } }
check("tissu : utilisable", FSB.Compat.GetPlayerUsability("robe").unusable == false)
_G.UnitClass = function() return "Mage", "MAGE", 8 end
info.hache = { 2, 0, "Haches à une main", "INVTYPE_WEAPON" }
tips.hache = { lines = { { leftText = "Une main", rightText = "Hache", rightColor = RED } } }
check("mage : hache jamais utilisable (table)", FSB.Compat.GetPlayerUsability("hache").unusable == true)
tips.hacheBlanche = { lines = { { leftText = "Une main", rightText = "Hache", rightColor = WHITE } } }
info.hacheBlanche = info.hache
check("table de classe l'emporte sur un tooltip sans rouge", FSB.Compat.GetPlayerUsability("hacheBlanche").unusable == true)
check("tooltip illisible, table muette : nil", FSB.Compat.GetPlayerUsability("inconnu") == nil)
info.classes = { 2, 7, "Épées à une main", "INVTYPE_WEAPON" }
tips.classes = { lines = { { leftText = "Classes : Voleur", leftColor = RED }, { leftText = "Une main", rightText = "Épée" } } }
check("restriction de classe (à gauche) : reste inutilisable", FSB.Compat.GetPlayerUsability("classes").unusable == true)

-- Armes du sac --------------------------------------------------------------------------------------
_G.UnitClass = function() return "Guerrier", "WARRIOR", 1 end
local bag = { [0] = { "hache2m", "plaques", "epee" } }
info.epee = { 2, 7, "Épées à une main", "INVTYPE_WEAPON" }
tips.epee = { lines = { { leftText = "Une main", rightText = "Épée", rightColor = WHITE } } }
_G.NUM_BAG_SLOTS = 0
_G.C_Container = { GetContainerNumSlots = function(b) return bag[b] and #bag[b] or 0 end,
    GetContainerItemLink = function(b, s) return bag[b] and bag[b][s] end }
local list = FSB.Compat.GetBagWeapons()
check("sac : seule l'arme équipable tout de suite est retenue", #list == 1 and list[1].link == "epee" and list[1].from == "BAG")
T.finish("équipement")
