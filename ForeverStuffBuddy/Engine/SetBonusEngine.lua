local _, FSB = ...

-- Bonus de set : détecte quels paliers (2/4/... pièces) sont gagnés ou perdus si le nouvel
-- objet remplace des pièces. Aucun bonus n'est jamais estimé : la valeur chiffrée vient
-- uniquement de profile.setBonusValue (réglage de l'utilisateur, 0 par défaut).
local SetBonus = {}
FSB.SetBonus = SetBonus

local function CountBySet(equipped, removedSlots)
    local removed, counts = {}, {}
    for _, slot in ipairs(removedSlots) do removed[slot] = true end
    for slot, item in pairs(equipped) do
        if item.setID and not removed[slot] then counts[item.setID] = (counts[item.setID] or 0) + 1 end
    end
    return counts
end

-- equipped : { [slot] = { setID = n|nil, ... } } (tous les emplacements)
-- removedSlots : emplacements libérés par le nouvel objet
-- newSetID : set du nouvel objet (nil si aucun)
-- thresholdsFor(setID) -> liste de paliers triée, ou nil si inconnue
-- Retourne { gained = n, lost = n, partial = bool } (n = nombre de paliers) ou nil si aucun set impliqué.
function SetBonus.Compute(equipped, removedSlots, newSetID, thresholdsFor)
    local before = CountBySet(equipped, {})
    local after = CountBySet(equipped, removedSlots)
    if newSetID then after[newSetID] = (after[newSetID] or 0) + 1 end

    local result, involved = { gained = 0, lost = 0, partial = false }, false
    for setID in pairs(before) do involved = involved or before[setID] ~= (after[setID] or 0) end
    if newSetID then involved = true end
    if not involved then return nil end

    local sets = {}
    for setID in pairs(before) do sets[setID] = true end
    for setID in pairs(after) do sets[setID] = true end
    for setID in pairs(sets) do
        local b, a = before[setID] or 0, after[setID] or 0
        if a ~= b then
            local thresholds = thresholdsFor(setID)
            if not thresholds or #thresholds == 0 then
                result.partial = true -- paliers inconnus : on n'invente rien
            else
                for _, t in ipairs(thresholds) do
                    if b < t and a >= t then result.gained = result.gained + 1 end
                    if b >= t and a < t then result.lost = result.lost + 1 end
                end
            end
        end
    end
    return result
end
