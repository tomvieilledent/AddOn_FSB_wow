local _, FSB = ...

-- Contexte de jeu. Mode GROUPE = en donjon ou raid (type d'instance "party"/"raid") ET en groupe.
-- Partout ailleurs (monde ouvert, ville, champ de bataille, instance en solo) : mode SOLO.
local Context = {}
FSB.Context = Context

local groupMode = false

local function Compute()
    if not IsInInstance or not IsInGroup then return false end
    local inInstance, instanceType = IsInInstance()
    return (inInstance and (instanceType == "party" or instanceType == "raid") and IsInGroup()) and true or false
end

function Context.IsGroupMode() return groupMode end

-- Recalcule le mode ; vide les caches si il a changé. Retourne true si changement.
function Context.Refresh()
    local new = Compute()
    if new == groupMode then return false end
    groupMode = new
    if FSB.Analyzer then FSB.Analyzer.InvalidateAll() end
    return true
end

-- Pour les tests.
function Context._Set(value) groupMode = value end
