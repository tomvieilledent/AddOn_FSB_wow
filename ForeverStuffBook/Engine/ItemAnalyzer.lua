local _, FSB = ...

-- Analyse à la demande + cache.
-- Cache : cache[equipLoc][link] = verdict. Invalidé par groupe d'emplacements
-- (équipement changé) ou globalement (profil / poids / seuils changés).
local Analyzer = {}
FSB.Analyzer = Analyzer

local cache = {}

local function CollectEquipped(equipLoc)
    local equipped = {}
    for _, slot in ipairs(FSB.Stats.RelatedSlots(equipLoc)) do
        equipped[slot] = FSB.Compat.GetEquipped(slot)
    end
    return equipped
end

local function RecordUnknownStats(stats)
    local seen = FSB.db and FSB.db.unknownStats
    if not seen then return end
    for key in pairs(stats) do
        if not FSB.Stats.IsKnown(key) then seen[key] = true end
    end
end

-- Retourne un verdict ou nil (objet non analysable : emplacement ou stats indisponibles).
function Analyzer.Analyze(link, equipLoc)
    if not FSB.Stats.SLOTS_FOR[equipLoc] then return nil end
    local group = cache[equipLoc]
    if group and group[link] then return group[link] end

    local stats = FSB.Compat.GetStats(link)
    local result
    if stats then
        RecordUnknownStats(stats)
        result = FSB.Verdict.Solo({
            equipLoc = equipLoc, stats = stats, equipped = CollectEquipped(equipLoc),
            canDualWield = FSB.Compat.CanDualWield(),
            profiles = FSB.Profiles.List(), active = FSB.Profiles.GetActive(),
        })
    end
    if result then -- un échec (données pas encore chargées) n'est pas mis en cache
        cache[equipLoc] = cache[equipLoc] or {}
        cache[equipLoc][link] = result
    end
    return result
end

function Analyzer.InvalidateAll()
    cache = {}
end

-- Un emplacement a changé : on ne vide que les types d'objets qui en dépendent.
function Analyzer.InvalidateSlot(slot)
    for equipLoc in pairs(cache) do
        for _, s in ipairs(FSB.Stats.RelatedSlots(equipLoc)) do
            if s == slot then cache[equipLoc] = nil; break end
        end
    end
end
