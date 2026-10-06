local _, FSB = ...

local Utils = {}
FSB.Utils = Utils

-- Raretés analysées : vert (2), bleu (3), violet (4), orange (5).
Utils.MIN_QUALITY, Utils.MAX_QUALITY = 2, 5

function Utils.Print(msg)
    print("|cff33ff99FSB|r: " .. tostring(msg))
end

-- Retourne l'emplacement d'équipement (ex. "INVTYPE_FINGER") ou nil si non équipable.
-- Filtre peu coûteux, appliqué avant toute analyse.
function Utils.GetEquipLoc(link)
    if not link or not C_Item or not C_Item.GetItemInfoInstant then return nil end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    if not equipLoc or equipLoc == "" then return nil end
    return equipLoc
end

function Utils.GetQuality(link)
    if not link or not C_Item or not C_Item.GetItemQualityByID then return nil end
    return C_Item.GetItemQualityByID(link)
end

function Utils.IsAnalysedQuality(quality)
    return type(quality) == "number" and quality >= Utils.MIN_QUALITY and quality <= Utils.MAX_QUALITY
end
