local _, FSB = ...

-- Analyse à la demande + cache.
-- cache[mode][equipLoc][link] = verdict, mode = "SOLO" | "GROUP".
-- Invalidation :
--  - équipement porté changé (emplacement) : types d'objets dépendants + entrées sensibles aux sets ;
--  - profil / poids / seuils changés : tout ;
--  - données de groupe changées (membre scanné, parti, spé) : seulement le cache GROUP.
local Analyzer = {}
FSB.Analyzer = Analyzer

local cache = { SOLO = {}, GROUP = {} }

local function RecordUnknownStats(stats)
    local seen = FSB.db and FSB.db.unknownStats
    if not seen then return end
    for key in pairs(stats) do
        if not FSB.Stats.IsKnown(key) then seen[key] = true end
    end
end

-- Libère-t-on les deux mains (2M) ou un seul emplacement ?
local function RemovedSlots(equipLoc, slot)
    if equipLoc == "INVTYPE_2HWEAPON" then return { FSB.Stats.SLOT.MAINHAND, FSB.Stats.SLOT.OFFHAND } end
    return { slot }
end

-- Fournit au moteur l'ajustement de score lié aux sets, par profil.
local function BuildSetAdjust(equipped, equipLoc, newSetID, setState)
    local thresholdCache = {}
    local function thresholdsFor(setID)
        if thresholdCache[setID] == nil then
            local link = (setID == newSetID and setState.link) or nil
            if not link then
                for _, item in pairs(equipped) do
                    if item.setID == setID then link = item.link; break end
                end
            end
            thresholdCache[setID] = FSB.Compat.GetSetThresholds(link) or false
        end
        return thresholdCache[setID] or nil
    end

    local changeBySlot = {}
    local function changeFor(slot)
        if changeBySlot[slot] == nil then
            changeBySlot[slot] = FSB.SetBonus.Compute(equipped, RemovedSlots(equipLoc, slot), newSetID, thresholdsFor) or false
        end
        return changeBySlot[slot] or nil
    end
    setState.changeFor = changeFor

    return function(profile)
        local value = profile.setBonusValue or 0
        if value == 0 then return nil end
        return function(slot)
            local c = changeFor(slot)
            return c and value * (c.gained - c.lost) or 0
        end
    end
end

local function SetSensitive(equipped, equipLoc, newSetID)
    if newSetID then return true end
    for _, slot in ipairs(FSB.Stats.RelatedSlots(equipLoc)) do
        if equipped[slot] and equipped[slot].setID then return true end
    end
    return false
end

-- Retourne un verdict ou nil (objet non analysable : emplacement ou stats indisponibles).
function Analyzer.Analyze(link, equipLoc)
    if not FSB.Stats.SLOTS_FOR[equipLoc] then return nil end
    local mode = FSB.Context.IsGroupMode() and "GROUP" or "SOLO"
    local group = cache[mode][equipLoc]
    if group and group[link] then return group[link] end

    local stats = FSB.Compat.GetStats(link)
    if not stats then return nil end -- données pas encore chargées : pas de mise en cache
    RecordUnknownStats(stats)

    local usability = FSB.Compat.GetUsability(link)
    if usability and usability.unusable then
        -- Inutilisable par le personnage : rien à comparer.
        local result = { kind = mode == "GROUP" and "CUPI" or "SELL", unusable = true }
        cache[mode][equipLoc] = cache[mode][equipLoc] or {}
        cache[mode][equipLoc][link] = result
        return result
    end

    local equipped = FSB.Compat.GetAllEquipped()
    local newSetID = FSB.Compat.GetSetID(link)
    local setState = { link = link }
    local ctx = {
        equipLoc = equipLoc, stats = stats, equipped = equipped,
        canDualWield = FSB.Compat.CanDualWield(),
        profiles = FSB.Profiles.List(), active = FSB.Profiles.GetActive(),
        adjustFor = BuildSetAdjust(equipped, equipLoc, newSetID, setState),
    }

    local result
    if mode == "GROUP" then
        ctx.members = FSB.Inspector.GetComparableMembers()
        result = FSB.Verdict.Group(ctx)
        result.unscanned = FSB.Inspector.CountPending()
    else
        result = FSB.Verdict.Solo(ctx)
    end
    if usability and usability.reqLevel and usability.reqLevel > FSB.Compat.PlayerLevel() then
        result.reqLevel = usability.reqLevel
    end
    result.setNote = result.slot and setState.changeFor(result.slot) or nil
    result.setSensitive = SetSensitive(equipped, equipLoc, newSetID)

    cache[mode][equipLoc] = cache[mode][equipLoc] or {}
    cache[mode][equipLoc][link] = result
    return result
end

function Analyzer.InvalidateAll()
    cache = { SOLO = {}, GROUP = {} }
end

function Analyzer.InvalidateGroup()
    cache.GROUP = {}
end

-- Un emplacement a changé : on ne vide que les types d'objets qui en dépendent
-- (plus les entrées dont le résultat dépend des sets, qui touchent tous les emplacements).
function Analyzer.InvalidateSlot(slot)
    for _, byLoc in pairs(cache) do
        for equipLoc, entries in pairs(byLoc) do
            local related = false
            for _, s in ipairs(FSB.Stats.RelatedSlots(equipLoc)) do
                if s == slot then related = true; break end
            end
            if related then
                byLoc[equipLoc] = nil
            else
                for link, verdict in pairs(entries) do
                    if verdict.setSensitive then entries[link] = nil end
                end
            end
        end
    end
end
