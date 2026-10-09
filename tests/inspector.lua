-- Scan de groupe avec API WoW simulée : luajit tests/inspector.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local T = H.counter(); local check = T.check

-- API simulée -------------------------------------------------------------------------------
local world = { inInstance = true, instanceType = "party", group = {}, myMap = 100, combat = false, time = 0 }
-- group : { party1 = { guid, name, map, visible, connected, specID, gear } }
local notified, ticker, cleared = {}, nil, 0
_G.GetTime = function() return world.time end
_G.InCombatLockdown = function() return world.combat end
_G.IsInInstance = function() return world.inInstance, world.instanceType end
_G.IsInGroup = function() return next(world.group) ~= nil end
_G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() local n = 1; for _ in pairs(world.group) do n = n + 1 end; return n end
_G.UnitExists = function(u) return u == "player" or world.group[u] ~= nil end
_G.UnitIsConnected = function(u) return world.group[u].connected end
_G.UnitIsVisible = function(u) return world.group[u].visible end
_G.UnitIsUnit = function(u, v) return u == v end
_G.UnitGUID = function(u) return u == "player" and "G-me" or (world.group[u] and world.group[u].guid) end
_G.UnitName = function(u) return world.group[u].name end
_G.UnitGroupRolesAssigned = function(u) return (world.group[u] and world.group[u].role) or "NONE" end
_G.UnitClass = function(u) return "Cls", (world.group[u] and world.group[u].classFile) or "MAGE", 8 end
_G.C_Map = { GetBestMapForUnit = function(u) return u == "player" and world.myMap or world.group[u].map end }
_G.CanInspect = function(u) return true end
_G.NotifyInspect = function(u) notified[#notified + 1] = u; world.lastNotified = u end
_G.ClearInspectPlayer = function() cleared = cleared + 1 end
_G.GetInventoryItemLink = function(u, slot) local g = world.group[u].gear; return g and g[slot] end
_G.C_SpecializationInfo = { GetInspectSpecialization = function(u) return world.group[u].specID or 0 end }
_G.C_Timer = { NewTicker = function(_, fn) ticker = { fn = fn, cancelled = false, Cancel = function(self) self.cancelled = true end }; return ticker end }

local FSB = H.load{ "Localization/frFR", "Utils/Utils", "Data/Stats", "Data/Profiles", "Data/Classes", "Core/Context", "Core/Log",
    "Engine/SpecEngine", "Core/Compat", "Core/Spec" }
FSB.db = { specProfiles = {} }; FSB.Profiles.Init(FSB.db)
local invalidations = 0
FSB.Analyzer = { InvalidateAll = function() end, InvalidateGroup = function() invalidations = invalidations + 1 end }
FSB.Compat.GetStats = function(link) return link ~= "missing" and { ITEM_MOD_STAMINA_SHORT = 1 } or nil end
FSB.Compat.GetSetID = function() return nil end
FSB.Spec.Info = function(id) return { role = "HEALER", primaryStat = 4 } end
assert(loadfile("ForeverStuffBuddy/Core/Inspector.lua"))("FSB", FSB)
local I = FSB.Inspector

local function member(i, props)
    local m = { guid = "G-" .. i, name = "M" .. i, map = 100, visible = true, connected = true, specID = 65, gear = { [1] = "head" } }
    for k, v in pairs(props or {}) do m[k] = v end
    world.group["party" .. i] = m
end
local function tick() world.time = world.time + 3; if ticker and not ticker.cancelled then ticker.fn() end end
local function scanAll(maxTicks)
    for _ = 1, maxTicks do
        tick()
        if world.lastNotified then
            local u = world.lastNotified; world.lastNotified = nil
            I.OnInspectReady(world.group[u].guid)
        end
    end
end
local function refresh() FSB.Context.Refresh(); I.Refresh() end

-- Groupe de 5 : 4 membres, dont un reste hors de l'instance
member(1); member(2); member(3, { map = 999, visible = false }); member(4)
refresh()
check("mode groupe en donjon", FSB.Context.IsGroupMode())
check("minuteur démarré", ticker and not ticker.cancelled)
scanAll(10)
check("3 membres présents scannés", #I.GetComparableMembers() == 3)
check("le membre hors instance n'est jamais inspecté", not (function() for _, u in ipairs(notified) do if u == "party3" then return true end end end)())
check("le scan continue pour le membre absent (minuteur actif)", ticker and not ticker.cancelled and I.CountPending() == 1)
check("ClearInspectPlayer appelé", cleared >= 3)

-- Le membre entre dans l'instance : il est scanné, puis le minuteur s'arrête
world.group.party3.map, world.group.party3.visible = 100, true
scanAll(4)
check("tous scannés", #I.GetComparableMembers() == 4 and I.CountPending() == 0)
check("minuteur arrêté quand tout est scanné", ticker.cancelled)

-- Un membre quitte : retiré du cache et cache de groupe invalidé
local before = invalidations
world.group.party2 = world.group.party3 -- les jetons party1..N sont compactés par le jeu
world.group.party3 = world.group.party4
world.group.party4 = nil
refresh()
check("membre parti retiré", #I.GetComparableMembers() == 3 and invalidations > before)

-- Équipement modifié : rescanné
world.group.party1.gear = { [1] = "head2" }
I.OnUnitInventoryChanged("party1")
check("changement d'équipement -> à rescanner", I.CountPending() == 1 and not ticker.cancelled)
scanAll(3)
check("rescan terminé", I.CountPending() == 0)

-- Combat : aucune inspection
member(5); world.combat = true; refresh()
local n = #notified
scanAll(3)
check("pas d'inspection en combat", #notified == n)
world.combat = false; scanAll(3)
check("reprise hors combat", I.CountPending() == 0)

-- Objet non chargé : après MAX tentatives, données partielles acceptées (pas de boucle infinie)
member(6, { gear = { [1] = "missing" } }); refresh()
scanAll(12)
check("données partielles acceptées après 3 tentatives", I.CountPending() == 0)

-- Sortie d'instance : plus de scan, mode solo
member(7, { map = 999, visible = false }); refresh()
world.inInstance = false; refresh()
check("hors instance : mode solo, minuteur arrêté", not FSB.Context.IsGroupMode() and ticker.cancelled)
local m = #notified; scanAll(3)
check("hors instance : aucun scan", #notified == m)
-- Cache conservé tant que le groupe existe
check("cache conservé hors instance", #I.GetComparableMembers() >= 3)

-- Groupe dissous : tout vidé
world.group = {}; I.Reset()
check("groupe dissous : cache vidé", #I.GetComparableMembers() == 0 and I.CountPending() == 0)

-- Membre sans spé lisible : non comparable
world.inInstance = true; member(1, { classFile = "PRIEST" }); refresh(); scanAll(3)
check("classe à plusieurs rôles : pas de comparaison (rôle illisible)", #I.GetComparableMembers() == 0)
world.group = {}; I.Reset(); member(1, { classFile = "MAGE" }); refresh(); scanAll(3)
check("classe à un seul rôle : comparable", #I.GetComparableMembers() == 1)

-- Rôle de groupe explicite : prêtre HEALER comparable, prêtre DAMAGER (défaut) non comparable
world.group = {}; I.Reset(); member(1, { classFile = "PRIEST", role = "HEALER" }); refresh(); scanAll(3)
check("prêtre explicitement HEALER : comparable en Soigneur", #I.GetComparableMembers() == 1)
world.group = {}; I.Reset(); member(1, { classFile = "PRIEST", role = "DAMAGER" }); refresh(); scanAll(3)
check("prêtre DAMAGER (rôle par défaut) : non comparable", #I.GetComparableMembers() == 0)
world.group = {}; I.Reset(); member(1, { classFile = "MAGE", role = "HEALER" }); refresh(); scanAll(3)
check("mage marqué HEALER : reste sur son seul rôle", #I.GetComparableMembers() == 1)
world.group = {}; I.Reset(); member(1, { classFile = "DRUID", role = "TANK" }); refresh(); scanAll(3)
check("druide explicitement TANK : comparable", #I.GetComparableMembers() == 1)
world.group["party1"].role = "NONE"; refresh()
check("rôle retiré au roster : plus comparable", #I.GetComparableMembers() == 0)
T.finish("inspector")
