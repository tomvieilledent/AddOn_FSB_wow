local _, FSB = ...

-- Scan passif des membres du groupe, uniquement en mode GROUPE (donjon/raid + groupe).
-- Boucle légère (un minuteur) active seulement tant qu'un membre connecté reste à scanner ;
-- seuls les membres présents dans l'instance avec moi sont réellement inspectés.
-- Un membre qui quitte le groupe est retiré du cache ; le cache est vidé si le groupe disparaît.
-- N'effectue que des lectures (inspection native) : aucune action de jeu.
local Inspector = {}
FSB.Inspector = Inspector

local TICK_SECONDS = 3
local INSPECT_TIMEOUT = 5
local MAX_ATTEMPTS = 3 -- tentatives de lecture complète avant d'accepter des données partielles

local members = {}   -- [guid] = { name, classID, specID, equipped, complete, attempts }
local pending = {}   -- [guid] = unit token (membres présents à scanner)
local inFlight       -- { guid, unit, startedAt }
local ticker

---------------------------------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------------------------------

local function GroupUnits()
    local units = {}
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- Membre connecté (candidat au scan : peut encore rejoindre l'instance).
local function IsConnected(unit)
    return UnitExists(unit) and UnitIsConnected(unit)
end

-- Membre dans la même zone (instance) que moi et à portée de vue. Un membre resté dehors
-- n'est jamais inspecté. Si la carte d'un membre est inconnue, seule la visibilité décide.
local function IsInMyInstance(unit)
    if not UnitIsVisible(unit) then return false end
    if C_Map and C_Map.GetBestMapForUnit then
        local mine, theirs = C_Map.GetBestMapForUnit("player"), C_Map.GetBestMapForUnit(unit)
        if mine and theirs and mine ~= theirs then return false end
    end
    return true
end

-- Met à jour cache et liste "à scanner" d'après la composition actuelle du groupe.
local function SyncRoster()
    local inGroup = {}
    pending = {}
    for _, unit in ipairs(GroupUnits()) do
        if not UnitIsUnit(unit, "player") then
            local guid = UnitGUID(unit)
            if guid then
                inGroup[guid] = true
                local m = members[guid]
                if (not m or not m.complete) and IsConnected(unit) then pending[guid] = unit end
            end
        end
    end
    local removed = false
    for guid in pairs(members) do
        if not inGroup[guid] then members[guid] = nil; removed = true end
    end
    if removed then FSB.Analyzer.InvalidateGroup() end
end

---------------------------------------------------------------------------------------------
-- Lecture d'une inspection
---------------------------------------------------------------------------------------------

local function ReadEquipment(unit)
    local equipped, complete = {}, true
    for _, slot in pairs(FSB.Stats.SLOT) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local stats = FSB.Compat.GetStats(link)
            if stats then
                equipped[slot] = { link = link, stats = stats, setID = FSB.Compat.GetSetID(link),
                    twoHand = FSB.Compat.GetEquipLoc(link) == "INVTYPE_2HWEAPON" }
            else
                complete = false -- objet pas encore en cache côté client
            end
        end
    end
    return equipped, complete
end

local function ReadSpec(unit)
    if not C_SpecializationInfo or not C_SpecializationInfo.GetInspectSpecialization then return nil end
    local ok, specID = pcall(C_SpecializationInfo.GetInspectSpecialization, unit)
    if ok and type(specID) == "number" and specID > 0 then return specID end
end

local function StoreMember(guid, unit)
    local previous = members[guid]
    local attempts = (previous and previous.attempts or 0) + 1
    local equipped, complete = ReadEquipment(unit)
    members[guid] = {
        name = UnitName(unit), classID = select(3, UnitClass(unit)),
        specID = ReadSpec(unit), equipped = equipped,
        complete = complete or attempts >= MAX_ATTEMPTS, attempts = attempts,
    }
    if not members[guid].specID then
        FSB.Log.Add("SPE_MEMBRE_ILLISIBLE", { detail = tostring(members[guid].name) .. " classe=" .. tostring(members[guid].classID), global = true })
    end
    FSB.Analyzer.InvalidateGroup()
end

---------------------------------------------------------------------------------------------
-- Minuteur
---------------------------------------------------------------------------------------------

local function Blocked()
    if InCombatLockdown and InCombatLockdown() then return true end
    return InspectFrame and InspectFrame:IsShown() -- ne gêne pas une inspection manuelle
end

local function Tick()
    if not FSB.Context.IsGroupMode() or not next(pending) then return Inspector.Stop() end
    if inFlight then
        if GetTime() - inFlight.startedAt < INSPECT_TIMEOUT then return end
        inFlight = nil
    end
    if Blocked() then return end
    for guid, unit in pairs(pending) do
        if UnitGUID(unit) == guid and IsInMyInstance(unit) and CanInspect(unit) then
            inFlight = { guid = guid, unit = unit, startedAt = GetTime() }
            NotifyInspect(unit)
            return
        end
    end
end

function Inspector.Start()
    if ticker or not C_Timer then return end
    ticker = C_Timer.NewTicker(TICK_SECONDS, Tick)
end

function Inspector.Stop()
    if ticker then ticker:Cancel(); ticker = nil end
end

-- Recalcule l'état selon le contexte (à appeler sur changement de groupe/zone).
function Inspector.Refresh()
    if not FSB.Context.IsGroupMode() then inFlight = nil; return Inspector.Stop() end
    SyncRoster()
    if next(pending) then Inspector.Start() else Inspector.Stop() end
end

-- Le groupe n'existe plus : tout le cache de groupe est supprimé.
function Inspector.Reset()
    members, pending, inFlight = {}, {}, nil
    Inspector.Stop()
    FSB.Analyzer.InvalidateGroup()
end

function Inspector.OnInspectReady(guid)
    if not inFlight or inFlight.guid ~= guid then return end
    local unit = inFlight.unit
    inFlight = nil
    if UnitGUID(unit) == guid then
        StoreMember(guid, unit)
        if members[guid].complete then pending[guid] = nil end
    end
    if ClearInspectPlayer then ClearInspectPlayer() end
    if not next(pending) then Inspector.Stop() end
end

-- L'équipement d'un membre a changé : on le rescannera quand il sera à portée.
function Inspector.OnUnitInventoryChanged(unit)
    if not unit or not FSB.Context.IsGroupMode() or UnitIsUnit(unit, "player") then return end
    local guid = UnitGUID(unit)
    if guid and members[guid] then
        members[guid].complete = false
        members[guid].attempts = 0
        pending[guid] = unit
        Inspector.Start()
    end
end

---------------------------------------------------------------------------------------------
-- Accès pour l'analyse
---------------------------------------------------------------------------------------------

-- Membres comparables : spé connue ET profil déterminé ET équipement lu. Sinon exclus
-- (aucune donnée inventée).
function Inspector.GetComparableMembers()
    local list = {}
    local profiles = FSB.Profiles.List()
    for _, m in pairs(members) do
        if m.specID then
            local profile = FSB.SpecEngine.ProfileForSpec(m.specID, FSB.Spec.Info(m.specID), profiles, FSB.db.specProfiles)
            if profile then list[#list + 1] = { name = m.name, weights = profile.weights, equipped = m.equipped } end
        end
    end
    return list
end

function Inspector.CountPending()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
end
