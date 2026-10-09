local _, FSB = ...

-- Score interne d'un objet pour un profil : somme(valeur * poids). Jamais affiché.
local ScoreEngine = {}
FSB.ScoreEngine = ScoreEngine

function ScoreEngine.Score(stats, weights)
    if not stats then return 0 end
    local total = 0
    for key, value in pairs(stats) do
        local w = weights[key]
        if w then total = total + value * w end
    end
    return total
end
