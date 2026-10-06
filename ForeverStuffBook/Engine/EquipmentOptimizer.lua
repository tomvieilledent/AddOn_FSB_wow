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
