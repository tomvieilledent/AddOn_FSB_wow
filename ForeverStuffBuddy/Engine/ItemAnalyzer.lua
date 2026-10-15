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

-- Le journal est facultatif : le moteur reste utilisable sans lui (tests).
local function LogAdd(reason, data) if FSB.Log then FSB.Log.Add(reason, data) end end

local function RecordUnknownStats(stats)
    local seen = FSB.db and FSB.db.unknownStats
    local count, names = 0, {}
    for key in pairs(stats) do
        if not FSB.Stats.IsKnown(key) then
            count = count + 1
            names[#names + 1] = key
            if seen then seen[key] = true end
        end
    end
    table.sort(names)
    return count, table.concat(names, ",")
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

-- Armes disponibles pour compléter une combinaison : armes du sac + armes portées en main droite/gauche,
-- moins un exemplaire de l'objet analysé (s'il est lui-même dans le sac ou porté).
local function WeaponPool(equipped, link)
    -- Arme déjà portée : comparaison simple (pas de « à équiper » sur ce qu'on porte déjà).
    for _, slot in ipairs({ FSB.Stats.SLOT.MAINHAND, FSB.Stats.SLOT.OFFHAND }) do
        if equipped[slot] and equipped[slot].link == link then return nil end
    end
    local pool = FSB.Compat.GetBagWeapons and FSB.Compat.GetBagWeapons() or {}
    for _, slot in ipairs({ FSB.Stats.SLOT.MAINHAND, FSB.Stats.SLOT.OFFHAND }) do
        local item = equipped[slot]
        if item and not item.unreadable then
            pool[#pool + 1] = { link = item.link, stats = item.stats, equipLoc = FSB.Compat.GetEquipLoc(item.link),
                from = "EQUIPPED", slot = slot }
        end
    end
    for i, item in ipairs(pool) do
        if item.link == link then table.remove(pool, i); break end
    end
    return pool
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
    local unknownCount, unknownNames = RecordUnknownStats(stats)
    if unknownCount > 0 then LogAdd("STATS_INCONNUES", { link = link, detail = unknownNames }) end

    local usability = FSB.Compat.GetPlayerUsability(link)
    if not usability then LogAdd("UTILISABILITE_ILLISIBLE", { link = link, global = true }) end
    if usability and usability.unusable then
        -- Inutilisable par le personnage : rien à comparer.
        local result = { kind = mode == "GROUP" and "CUPI" or "SELL", unusable = true }
        cache[mode][equipLoc] = cache[mode][equipLoc] or {}
        cache[mode][equipLoc][link] = result
        return result
    end

    local equipped = FSB.Compat.GetAllEquipped()
    -- Une pièce portée illisible fausserait la comparaison : pas de verdict, pas de cache.
    for _, slot in ipairs(FSB.Stats.RelatedSlots(equipLoc)) do
        if equipped[slot] and equipped[slot].unreadable then
            LogAdd("PIECE_PORTEE_ILLISIBLE", { link = link, detail = tostring(equipped[slot].link), verdict = "UNKNOWN" })
            return { kind = "UNKNOWN" }
        end
    end
    local newSetID = FSB.Compat.GetSetID(link)
    local setState = { link = link }
    local ctx = {
        equipLoc = equipLoc, stats = stats, equipped = equipped,
        canDualWield = FSB.Compat.CanDualWield(),
        profiles = FSB.Spec and FSB.Spec.OffspecProfiles() or FSB.Profiles.List(), active = FSB.Profiles.GetActive(),
        adjustFor = BuildSetAdjust(equipped, equipLoc, newSetID, setState),
        weaponPool = FSB.Compat.WEAPON_LOCS and FSB.Compat.WEAPON_LOCS[equipLoc] and WeaponPool(equipped, link) or nil,
    }

    local result
    if mode == "GROUP" then
        -- Membres qui ne peuvent pas porter l'objet (table Classic des classes) : écartés de la comparaison.
        local classID, subClassID = FSB.Compat.ItemClass(link)
        local members = {}
        for _, m in ipairs(FSB.Inspector.GetComparableMembers()) do
            if FSB.Equipment.CanUse(m.classFile, m.level, classID, subClassID, equipLoc) ~= false then
                members[#members + 1] = m
            end
        end
        ctx.members = members
        ctx.myLoot = FSB.LootTracker and UnitName and FSB.LootTracker.Count(UnitName("player")) or 0
        result = FSB.Verdict.Group(ctx)
        result.unscanned = FSB.Inspector.CountPending()
    else
        result = FSB.Verdict.Solo(ctx)
    end
    if usability and usability.reqLevel and usability.reqLevel > FSB.Compat.PlayerLevel() then
        result.reqLevel = usability.reqLevel
    end
    if unknownCount > 0 then result.unknownStats = unknownCount end
    if usability and usability.needsSkill then result.needsSkill = usability.needsSkill end
    result.setNote = result.slot and setState.changeFor(result.slot) or nil
    if result.setNote and result.setNote.partial then LogAdd("SET_PARTIEL", { link = link, verdict = result.kind }) end
    if result.close then LogAdd("VERDICT_LIMITE", { link = link, verdict = result.kind }) end
    result.setSensitive = SetSensitive(equipped, equipLoc, newSetID)

    cache[mode][equipLoc] = cache[mode][equipLoc] or {}
    cache[mode][equipLoc][link] = result
    return result
end

function Analyzer.InvalidateAll()
    cache = { SOLO = {}, GROUP = {} }
end

-- Contenu des sacs changé : seuls les verdicts d'armes (combinaisons avec le sac) sont à refaire.
function Analyzer.InvalidateWeapons()
    for _, byLoc in pairs(cache) do
        for equipLoc in pairs(FSB.Compat.WEAPON_LOCS) do byLoc[equipLoc] = nil end
    end
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
