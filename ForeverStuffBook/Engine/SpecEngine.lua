local _, FSB = ...

-- Choix d'un profil à partir d'informations de spécialisation (rôle + stat principale).
-- Aucune spécialisation n'est jamais devinée : sans info fiable, retourne nil.
local SpecEngine = {}
FSB.SpecEngine = SpecEngine

local PRIMARY_INTELLECT = 3

-- Profil par défaut pour un rôle ("HEALER" | "TANK" | "DAMAGER") et une stat principale
-- (1 force, 2 agilité, 3 intelligence). Utilise les champs role/damage des profils.
function SpecEngine.DefaultProfile(role, primaryStat, profiles)
    local damage
    if role == "DAMAGER" then
        if not primaryStat then return nil end
        damage = primaryStat == PRIMARY_INTELLECT and "MAGIC" or "PHYSICAL"
    end
    for _, p in ipairs(profiles) do
        if p.role == role and (not damage or p.damage == damage) then return p end
    end
end

-- Profil associé à une spé : association explicite de l'utilisateur d'abord, sinon défaut.
function SpecEngine.ProfileForSpec(specID, info, profiles, specProfiles)
    if not specID or specID == 0 then return nil end
    local mapped = specProfiles and specProfiles[specID]
    if mapped then
        for _, p in ipairs(profiles) do if p.name == mapped then return p end end
    end
    if not info then return nil end
    return SpecEngine.DefaultProfile(info.role, info.primaryStat, profiles)
end
