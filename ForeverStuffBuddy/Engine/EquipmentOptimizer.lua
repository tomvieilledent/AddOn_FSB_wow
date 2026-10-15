local _, FSB = ...

-- Compare des configurations finales d'équipement (pas un objet isolé).
-- Entrée "equipped" : { [slot] = { stats=..., twoHand=bool } } (slot vide = nil).
local Optimizer = {}
FSB.Optimizer = Optimizer

local S = FSB.Stats.SLOT
local Score = FSB.ScoreEngine.Score

local function SlotScore(equipped, slot, weights)
    local item = equipped[slot]
    return item and Score(item.stats, weights) or 0
end

-- Gain de score si le nouvel objet prend "slot", en tenant compte des effets de bord
-- sur la main gauche (2M). Retourne nil si la configuration est impossible.
local function DeltaForSlot(equipLoc, slot, newScore, equipped, weights, canDualWield)
    local mainIs2H = equipped[S.MAINHAND] and equipped[S.MAINHAND].twoHand

    if equipLoc == "INVTYPE_2HWEAPON" then
        -- La 2M libère la main gauche : on perd les deux objets actuels.
        return newScore - SlotScore(equipped, S.MAINHAND, weights) - SlotScore(equipped, S.OFFHAND, weights)
    end
    if slot == S.OFFHAND then
        if mainIs2H then return nil end -- nécessiterait de retirer la 2M : hors périmètre
        if equipLoc == "INVTYPE_WEAPON" and not canDualWield then return nil end
    end
    -- Une 1M en main droite remplace une éventuelle 2M (la main gauche est déjà vide dans ce cas).
    return newScore - SlotScore(equipped, slot, weights)
end

-- adjust(slot) -> nombre (optionnel) : bonus/malus supplémentaire si l'objet prend cet emplacement
-- (utilisé pour les bonus de set).
-- Retourne (meilleurGain, meilleurEmplacement, scoreRemplacé). Gain nil = aucune configuration possible.
function Optimizer.Evaluate(equipLoc, newStats, equipped, weights, canDualWield, adjust)
    local slots = FSB.Stats.SLOTS_FOR[equipLoc]
    if not slots then return nil end
    local newScore = Score(newStats, weights)
    local bestDelta, bestSlot
    for _, slot in ipairs(slots) do
        local delta = DeltaForSlot(equipLoc, slot, newScore, equipped, weights, canDualWield)
        if delta and adjust then delta = delta + adjust(slot) end
        if delta and (not bestDelta or delta > bestDelta) then bestDelta, bestSlot = delta, slot end
    end
    if not bestDelta then return nil end
    local replaced = equipLoc == "INVTYPE_2HWEAPON"
        and (SlotScore(equipped, S.MAINHAND, weights) + SlotScore(equipped, S.OFFHAND, weights))
        or SlotScore(equipped, bestSlot, weights)
    return bestDelta, bestSlot, replaced
end

---------------------------------------------------------------------------------------------
-- Armes : combinaisons complètes des deux mains, avec les objets du sac.
---------------------------------------------------------------------------------------------

local MAIN_LOCS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_LOCS = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
-- Armes en main gauche : seulement avec l'ambidextrie.
local DUAL_LOCS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }

local function CanMain(loc) return MAIN_LOCS[loc] == true end
local function CanOff(loc, canDualWield) return OFF_LOCS[loc] == true or (canDualWield and DUAL_LOCS[loc] == true) end

-- Meilleure configuration des mains qui contient le nouvel objet, comparée à la configuration portée :
--  - 2M seule ;
--  - nouvel objet en main droite + meilleure main gauche disponible (sac ou portée) ;
--  - nouvel objet en main gauche + meilleure main droite disponible (sac ou portée).
-- pool : { { link, stats, equipLoc, from = "BAG" | "EQUIPPED", slot } } (sans le nouvel objet lui-même).
-- Retourne (gain, emplacement du nouvel objet, score porté, combo) ou nil.
-- combo = { partner = entrée du pool ou nil, partnerSlot, replaced = { liens portés retirés } }.
function Optimizer.EvaluateWeapons(equipLoc, newStats, equipped, pool, weights, canDualWield, adjust)
    local current = SlotScore(equipped, S.MAINHAND, weights) + SlotScore(equipped, S.OFFHAND, weights)
    local newScore = Score(newStats, weights)

    local function BestPartner(fits)
        local best, bestScore = nil, 0
        for _, item in ipairs(pool or {}) do
            if fits(item.equipLoc) then
                local s = Score(item.stats, weights)
                if s > bestScore then best, bestScore = item, s end
            end
        end
        return best, bestScore
    end

    local options = {}
    if equipLoc == "INVTYPE_2HWEAPON" then
        options[#options + 1] = { slot = S.MAINHAND, score = newScore }
    end
    if CanMain(equipLoc) then
        local off, s = BestPartner(function(loc) return CanOff(loc, canDualWield) end)
        options[#options + 1] = { slot = S.MAINHAND, score = newScore + s, partner = off, partnerSlot = S.OFFHAND }
    end
    if CanOff(equipLoc, canDualWield) then
        local main, s = BestPartner(CanMain)
        options[#options + 1] = { slot = S.OFFHAND, score = newScore + s, partner = main, partnerSlot = S.MAINHAND }
    end

    local chosen, bestDelta
    for _, o in ipairs(options) do
        local delta = o.score - current
        if adjust then delta = delta + adjust(o.slot) end
        if not bestDelta or delta > bestDelta then chosen, bestDelta = o, delta end
    end
    if not chosen then return nil end

    -- Objets portés qui quittent les mains (une arme portée réutilisée, même changée de main, reste équipée).
    local replaced = {}
    for _, slot in ipairs({ S.MAINHAND, S.OFFHAND }) do
        local item = equipped[slot]
        local stays = chosen.partner and chosen.partner.from == "EQUIPPED" and chosen.partner.slot == slot
        if item and not stays then replaced[#replaced + 1] = item.link end
    end
    return bestDelta, chosen.slot, current,
        { partner = chosen.partner, partnerSlot = chosen.partnerSlot, replaced = replaced }
end
