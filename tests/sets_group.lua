-- Sets, spé, verdict de groupe, mode, cache : luajit tests/sets_group.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Weights", "Data/Profiles", "Data/Equipment",
    "Core/Compat", "Core/Context", "Engine/ScoreEngine", "Engine/EquipmentOptimizer", "Engine/SetBonusEngine",
    "Engine/SpecEngine", "Engine/VerdictEngine", "Engine/ItemAnalyzer" }
local T = H.counter(); local check = T.check
FSB.db = {}; FSB.Profiles.Init(FSB.db)
local S = FSB.Stats.SLOT
local HEAL = FSB.Profiles.For("PRIEST", 2, "PVE")
local SHADOW = FSB.Profiles.For("PRIEST", 3, "PVE")
local PHYS = FSB.Profiles.For("WARRIOR", 1, "PVE")
local HP, AP = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT"
local function item(stats, setID) return { stats = stats, setID = setID, link = "L" .. tostring(setID) } end

-- Profils par classe / arbre / mode ------------------------------------------------------------------
local function names(l) local t = {}; for _, p in ipairs(l) do t[#t + 1] = p.name end; return table.concat(t, ",") end
check("prêtre PvE : trois arbres", names(FSB.Profiles.ForClass("PRIEST", "PVE")) == "Prêtre · Discipline · PvE 60,Prêtre · Sacré · PvE 60,Prêtre · Ombre · PvE 60")
check("rôles du prêtre : soigneur et dégâts", table.concat(FSB.Profiles.Roles("PRIEST", "PVE"), ",") == "HEALER,DAMAGER")
check("rôles du druide : dégâts, tank (ours), soigneur", table.concat(FSB.Profiles.Roles("DRUID", "PVE"), ",") == "DAMAGER,TANK,HEALER")
local avg = FSB.Profiles.ClassRole("PRIEST", "HEALER", "PVE")
check("profil moyen des soigneurs prêtres", avg and avg.weights[HP] == HEAL.weights[HP] and avg.name == "Prêtre · Soigneur · PvE 60")
check("variante par défaut du druide farouche : félin", FSB.Profiles.For("DRUID", 2, "PVE").variant == "CAT"
    and FSB.Profiles.For("DRUID", 2, "PVE", "BEAR").role == "TANK")

-- Profils fixes rechargés depuis le code ; la valeur de palier de set est conservée -------------------
local saved = { profiles = { { name = HEAL.name, weights = { [HP] = 1 }, setBonusValue = 77 } } }
FSB.Profiles.Init(saved)
local savedHeal
for _, p in ipairs(saved.profiles) do if p.name == HEAL.name then savedHeal = p end end
check("poids rechargés depuis le code", savedHeal.weights[HP] == HEAL.weights[HP] and HEAL.weights[HP] > 1)
check("valeur de palier de set conservée", savedHeal.setBonusValue == 77 and saved.schema == 5)
check("stats vues en jeu non signalées inconnues", FSB.Stats.IsKnown("RESISTANCE5_NAME") and FSB.Stats.IsKnown("ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT"))
check("nouvelles stats reconnues", FSB.Stats.IsKnown("ITEM_MOD_RANGED_ATTACK_POWER_SHORT") and FSB.Stats.IsKnown("ITEM_MOD_HEALTH_REGEN_SHORT")
    and FSB.Stats.IsKnown("ITEM_MOD_HIT_SPELL_RATING_SHORT") and FSB.Stats.IsKnown("ITEM_MOD_BLOCK_VALUE_SHORT"))
check("bonus Ombre : compte pour l'Ombre, pas pour un soigneur pur",
    FSB.ScoreEngine.Score({ ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = 40 }, SHADOW.weights) > 0
    and (HEAL.weights.ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT or 0) == 0)

-- Stats vues en jeu : puissance des sorts (soins + dégâts) et DPS d'arme
check("bonus contre un type de créature : connu, hors score", FSB.Stats.IsKnown("ITEM_MOD_ATTACK_POWER_VS_HUMANOID_SHORT") and not FSB.Stats.IsKnown("ITEM_MOD_NOUVEAU_TRUC"))
check("bonus de métier (minage) : connu, hors score", FSB.Stats.IsKnown("ITEM_MOD_MINING_SHORT"))
check("SPELL_POWER et DPS d'arme reconnus", FSB.Stats.IsKnown("ITEM_MOD_SPELL_POWER_SHORT") and FSB.Stats.IsKnown("ITEM_MOD_DAMAGE_PER_SECOND_SHORT"))
check("puissance des sorts compte pour un soigneur", FSB.ScoreEngine.Score({ ITEM_MOD_SPELL_POWER_SHORT = 20 }, HEAL.weights) > 0)
check("DPS d'arme : compte pour le physique, pas pour un soigneur",
    FSB.ScoreEngine.Score({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 }, PHYS.weights) > 0
    and FSB.ScoreEngine.Score({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 }, HEAL.weights) == 0)

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
    profiles = { HEAL, PHYS }, active = HEAL }
check("sans valeur de set : n'améliore pas ? (slot vide => équipe)", FSB.Verdict.Solo(ctx).kind == "EQUIP")
ctx = { equipLoc = "INVTYPE_CHEST", stats = { [HP] = 10 }, equipped = { [S.CHEST] = item({ [HP] = 20 }, 7) },
    profiles = { HEAL, PHYS }, active = HEAL,
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

-- Arbre le plus investi -------------------------------------------------------------------------
local AT = FSB.SpecEngine.ActiveTree
check("arbre le plus investi", AT({ { name = "a", points = 3 }, { name = "b", points = 9 } }) == 2)
check("égalité ou aucun point : nil", AT({ { name = "a", points = 4 }, { name = "b", points = 4 } }) == nil
    and AT({ { name = "a", points = 0 } }) == nil and AT(nil) == nil)
local P = { HEAL, PHYS }

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
check("groupe : off-spé conservé", rr.kind == "OFFSPEC" and rr.profile == PHYS.name)
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
FSB.db.activeProfile = HEAL.name
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
