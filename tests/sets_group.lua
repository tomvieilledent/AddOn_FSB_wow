-- Sets, spé, verdict de groupe, mode, cache : luajit tests/sets_group.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Core/Compat",
    "Core/Context", "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine",
    "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)
local S = FSB.Stats.SLOT
local HEAL, MAGE, PHYS, TANK = unpack(FSB.db.profiles)
local HP, AP = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT"
local function item(stats, setID) return { stats = stats, setID = setID, link = "L" .. tostring(setID) } end

-- Profils OFF-SPÉ selon la classe ---------------------------------------------------------------
local SE, builtin = FSB.SpecEngine, FSB.Profiles.IsBuiltin
local priest = { { role = "HEALER", primaryStat = 4 }, { role = "HEALER", primaryStat = 4 }, { role = "DAMAGER", primaryStat = 4 } }
local function names(l) local t = {}; for _, p in ipairs(l) do t[#t + 1] = p.name end; return table.concat(t, ",") end
check("prêtre : ni Tank ni physique", names(SE.ClassProfiles(FSB.db.profiles, priest, builtin, HEAL.name, {})) == HEAL.name .. "," .. MAGE.name)
check("profil actif toujours gardé", names(SE.ClassProfiles(FSB.db.profiles, priest, builtin, TANK.name, {})):find("Tank"))
check("profil associé à une spé gardé", names(SE.ClassProfiles(FSB.db.profiles, priest, builtin, HEAL.name, { [1] = PHYS.name })):find(PHYS.name))
local custom = { name = "Farm", role = "DAMAGER", damage = "PHYSICAL", weights = {} }
local withCustom = { HEAL, MAGE, PHYS, TANK, custom }
check("profil utilisateur gardé", names(SE.ClassProfiles(withCustom, priest, builtin, HEAL.name, {})):find("Farm"))
check("spé illisible : aucun filtre", #SE.ClassProfiles(FSB.db.profiles, { { role = "DAMAGER" } }, builtin, HEAL.name, {}) == 4)
check("aucune info : aucun filtre", #SE.ClassProfiles(FSB.db.profiles, nil, builtin, HEAL.name, {}) == 4)

-- Profils fixes rechargés depuis le code ; la valeur de palier de set est conservée -------------------
local saved = { profiles = { { name = "Soigneur", weights = { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1 }, setBonusValue = 77 } } }
FSB.Profiles.Init(saved)
check("poids rechargés depuis le code", saved.profiles[1].weights.ITEM_MOD_SPELL_HEALING_DONE_SHORT == 100)
check("valeur de palier de set conservée", saved.profiles[1].setBonusValue == 77 and saved.schema == 4)
check("stats vues en jeu non signalées inconnues", FSB.Stats.IsKnown("RESISTANCE5_NAME") and FSB.Stats.IsKnown("ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT"))
check("bonus Ombre : compte pour un DPS magique, pas pour un soigneur pur",
    FSB.ScoreEngine.Score({ ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = 40 }, saved.profiles[2].weights) > 0
    and (saved.profiles[1].weights.ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT or 0) == 0)

-- Sets -------------------------------------------------------------------------------------
local thresholds = function() return { 2, 4 } end
local eq = { [S.HEAD] = item({}, 7), [S.CHEST] = item({}, 7), [S.LEGS] = item({}, 7), [S.HANDS] = item({}, 9) }
local c = FSB.SetBonus.Compute(eq, { S.FEET }, 7, thresholds)            -- 3 -> 4 pièces
check("set : palier 4 gagné", c.gained == 1 and c.lost == 0)
c = FSB.SetBonus.Compute(eq, { S.HEAD }, nil, thresholds)                -- 3 -> 2 : rien perdu
check("set : 3->2 pas de perte", c.gained == 0 and c.lost == 0)
c = FSB.SetBonus.Compute({ [S.HEAD] = item({}, 7), [S.CHEST] = item({}, 7) }, { S.HEAD }, nil, thresholds)
check("set : palier 2 perdu", c.lost == 1)
c = FSB.SetBonus.Compute(eq, { S.WRIST }, 5, thresholds)                 -- nouveau set, 1 pièce
check("set : 1 pièce d'un autre set, aucun palier", c and c.gained == 0 and c.lost == 0)
c = FSB.SetBonus.Compute(eq, { S.WRIST }, 7, function() return nil end)
check("set : paliers inconnus -> partiel, rien inventé", c.partial and c.gained == 0)
check("set : aucun set impliqué -> nil", FSB.SetBonus.Compute({ [S.HEAD] = item({}) }, { S.HEAD }, nil, thresholds) == nil)

-- Valeur de palier choisie par l'utilisateur : sans elle, le set ne change pas le verdict
local worn = { [S.CHEST] = item({ [HP] = 100 }, 7), [S.HEAD] = item({}, 7), [S.LEGS] = item({}, 7), [S.FEET] = nil }
local ctx = { equipLoc = "INVTYPE_FEET", stats = { [HP] = 1 }, equipped = { [S.FEET] = nil },
    profiles = FSB.db.profiles, active = HEAL }
check("sans valeur de set : n'améliore pas ? (slot vide => équipe)", FSB.Verdict.Solo(ctx).kind == "EQUIP")
ctx = { equipLoc = "INVTYPE_CHEST", stats = { [HP] = 10 }, equipped = { [S.CHEST] = item({ [HP] = 20 }, 7) },
    profiles = FSB.db.profiles, active = HEAL,
    adjustFor = function(profile)
        return function() return (profile.setBonusValue or 0) * -1 end -- perd un palier
    end }
check("perte de palier non chiffrée : verdict inchangé (pire de toute façon)", FSB.Verdict.Solo(ctx).kind ~= "EQUIP")
ctx.equipped = { [S.CHEST] = item({ [HP] = 9 }, 7) }
HEAL.setBonusValue = 0
check("léger upgrade sans valeur de set", FSB.Verdict.Solo(ctx).kind == "EQUIP")
HEAL.setBonusValue = 500
check("léger upgrade annulé par un palier perdu valorisé", FSB.Verdict.Solo(ctx).kind ~= "EQUIP")
HEAL.setBonusValue = nil

-- Spé -------------------------------------------------------------------------------------
local P = FSB.db.profiles
check("spé soigneur", FSB.SpecEngine.DefaultProfile("HEALER", 3, P) == HEAL)
check("spé tank", FSB.SpecEngine.DefaultProfile("TANK", 1, P) == TANK)
check("spé dps int", FSB.SpecEngine.DefaultProfile("DAMAGER", 4, P) == MAGE)
check("spé dps agi", FSB.SpecEngine.DefaultProfile("DAMAGER", 2, P) == PHYS)
check("dps sans stat principale : pas de devinette", FSB.SpecEngine.DefaultProfile("DAMAGER", nil, P) == nil)
check("spé inconnue : nil", FSB.SpecEngine.ProfileForSpec(0, nil, P, {}) == nil)
check("association explicite", FSB.SpecEngine.ProfileForSpec(55, nil, P, { [55] = "Tank" }) == TANK)

-- Groupe ----------------------------------------------------------------------------------
local mine = { [S.CHEST] = { stats = { [HP] = 40 } } }
local weak = { [S.CHEST] = { stats = {} } }
local function group(members, myGear, active)
    return FSB.Verdict.Group({ equipLoc = "INVTYPE_CHEST", stats = { [HP] = 50 }, equipped = myGear or mine,
        profiles = P, active = active or HEAL, members = members })
end
-- grosse amélioration pour moi : TAKE
check("groupe : à prendre (personne d'autre)", group({}).kind == "TAKE")
-- un autre soigneur sans pièce : gain bien plus grand -> meilleur pour un autre
local r = group({ { name = "Anna", weights = HEAL.weights, equipped = weak } })
check("groupe : meilleur pour un autre", r.kind == "BETTER_OTHER" and r.others[1] == "Anna")
-- différence minuscule : pas de 🟡
local close = { [S.CHEST] = { stats = { [HP] = 38 } } }
check("groupe : petite différence -> à prendre", group({ { name = "Bob", weights = HEAL.weights, equipped = close } }).kind == "TAKE")
-- membre sans bénéfice (autre rôle)
check("groupe : autre rôle sans gain", group({ { name = "Cy", weights = PHYS.weights, equipped = weak } }).kind == "TAKE")
-- inutile pour moi -> CUPI ; off-spé pour moi -> OFFSPEC
local rr = FSB.Verdict.Group({ equipLoc = "INVTYPE_CHEST", stats = { ITEM_MOD_NOPE = 1 }, equipped = mine,
    profiles = P, active = HEAL, members = {} })
check("groupe : CUPI", rr.kind == "CUPI")
rr = FSB.Verdict.Group({ equipLoc = "INVTYPE_CHEST", stats = { [AP] = 200 }, equipped = mine,
    profiles = P, active = HEAL, members = { { name = "Z", weights = PHYS.weights, equipped = weak } } })
check("groupe : off-spé conservé", rr.kind == "OFFSPEC" and rr.profile == "Dégâts physiques")
-- seuil de marge configurable
FSB.db.thresholds = { otherMargin = 5 }
check("groupe : marge très haute -> jamais meilleur pour un autre",
    group({ { name = "Anna", weights = HEAL.weights, equipped = weak } }).kind == "TAKE")
FSB.db.thresholds = nil
-- données joueur indisponibles : liste vide -> comportement solo-like
check("groupe : aucune donnée membre", group({}).kind == "TAKE")

-- Contexte + cache ------------------------------------------------------------------------
local calls = 0
_G.IsInInstance = function() return true, "party" end
_G.IsInGroup = function() return true end
check("contexte : donjon + groupe", FSB.Context.Refresh() and FSB.Context.IsGroupMode())
_G.IsInInstance = function() return false, "none" end
check("contexte : monde ouvert -> solo", FSB.Context.Refresh() and not FSB.Context.IsGroupMode())
_G.IsInInstance = function() return true, "pvp" end
check("contexte : champ de bataille -> solo", not FSB.Context.Refresh() and not FSB.Context.IsGroupMode())
_G.IsInInstance = function() return true, "raid" end
FSB.Context.Refresh(); check("contexte : raid -> groupe", FSB.Context.IsGroupMode())
_G.IsInGroup = function() return false end
FSB.Context.Refresh(); check("contexte : instance solo -> solo", not FSB.Context.IsGroupMode())
FSB.Context._Set(false)

-- Cache de l'analyseur avec Compat simulé
local equippedNow = { [S.CHEST] = { link = "c", stats = { [HP] = 20 }, setID = nil } }
FSB.Compat.GetStats = function(link) calls = calls + 1; return { [HP] = 30 } end
FSB.Compat.GetAllEquipped = function() return equippedNow end
FSB.Compat.GetSetID = function() return nil end
FSB.Compat.CanDualWield = function() return true end
FSB.Inspector = { GetComparableMembers = function() return {} end, CountPending = function() return 0 end }
FSB.db.unknownStats = {}
local v1 = FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
local callsAfterFirst = calls
FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
check("cache : deuxième survol sans recalcul", calls == callsAfterFirst and v1.kind == "EQUIP")
FSB.Analyzer.InvalidateSlot(S.FINGER1)
FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
check("cache : autre emplacement ne l'invalide pas", calls == callsAfterFirst)
FSB.Analyzer.InvalidateSlot(S.CHEST)
FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
check("cache : emplacement concerné invalidé", calls > callsAfterFirst)
local c2 = calls
FSB.Analyzer.InvalidateGroup(); FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
check("cache : invalidation de groupe ne touche pas le solo", calls == c2)
FSB.Profiles.GetActive().weights[HP] = 90; FSB.Analyzer.InvalidateAll()
FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
check("cache : changement de poids -> tout invalidé", calls > c2)
-- mode groupe : cache distinct
FSB.Context._Set(true)
local c3 = calls
local g = FSB.Analyzer.Analyze("lienA", "INVTYPE_CHEST")
check("cache : mode groupe calculé séparément", calls > c3 and g.kind == "TAKE")
FSB.Context._Set(false)
FSB.Analyzer.InvalidateAll()

-- Set impliqué : invalidation par changement d'un autre emplacement
equippedNow = { [S.CHEST] = { link = "c", stats = { [HP] = 20 }, setID = 7 } }
FSB.Compat.GetSetID = function(l) return l == "lienSet" and 7 or nil end
FSB.Compat.GetSetThresholds = function() return { 2 } end
FSB.Analyzer.Analyze("lienSet", "INVTYPE_HEAD")
local c4 = calls
FSB.Analyzer.InvalidateSlot(S.LEGS)
FSB.Analyzer.Analyze("lienSet", "INVTYPE_HEAD")
check("cache : entrée sensible aux sets invalidée par un autre emplacement", calls > c4)

T.finish("sets/groupe")
