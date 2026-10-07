local _, FSB = ...

-- Choix d'un profil à partir d'informations de spécialisation (rôle + stat principale).
-- Aucune spécialisation n'est jamais devinée : sans info fiable, retourne nil.
local SpecEngine = {}
FSB.SpecEngine = SpecEngine

-- Valeur VERIFIED en jeu : une spé de prêtre renvoie 4 comme stat principale (intelligence).
local PRIMARY_INTELLECT = 4

-- Profil par défaut pour un rôle ("HEALER" | "TANK" | "DAMAGER") et une stat principale
-- (1 force, 2 agilité, 4 intelligence). Utilise les champs role/damage des profils.
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

-- Profils candidats pour OFF-SPÉ : les profils par défaut que la classe ne peut jamais jouer sont
-- écartés. Les profils créés par l'utilisateur, le profil actif et les profils associés à une spé
-- sont toujours conservés. Si une spé de la classe est illisible : aucun filtre (rien d'inventé).
-- infos : { { role, primaryStat } } pour chaque spé de la classe ; isBuiltin(nom) -> bool.
function SpecEngine.ClassProfiles(profiles, infos, isBuiltin, activeName, specProfiles)
    if not infos or #infos == 0 then return profiles end
    local relevant = {}
    for _, info in ipairs(infos) do
        local p = SpecEngine.DefaultProfile(info.role, info.primaryStat, profiles)
        if not p then return profiles end
        relevant[p] = true
    end
    local kept = {}
    for _, p in ipairs(profiles) do
        local mapped = false
        for _, name in pairs(specProfiles or {}) do if name == p.name then mapped = true end end
        if relevant[p] or not isBuiltin(p.name) or p.name == activeName or mapped then kept[#kept + 1] = p end
    end
    return kept
end
