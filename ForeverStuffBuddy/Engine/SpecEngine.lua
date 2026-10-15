local _, FSB = ...

-- Lecture de la spécialisation à partir des points de talents.
local SpecEngine = {}
FSB.SpecEngine = SpecEngine

-- Arbre de talents actif = celui qui a le plus de points investis. trees : { { name, points } }.
-- Retourne (index, nom) ou nil si aucun point ou égalité.
function SpecEngine.ActiveTree(trees)
    if type(trees) ~= "table" then return nil end
    local best, bestPoints, tie = nil, 0, false
    for i, t in ipairs(trees) do
        if t.points > bestPoints then best, bestPoints, tie = i, t.points, false
        elseif t.points == bestPoints and bestPoints > 0 then tie = true end
    end
    if not best or tie then return nil end
    return best, trees[best].name
end
