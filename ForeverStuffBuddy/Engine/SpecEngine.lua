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

-- Profils retenus par nom (rôles possibles de la classe) : les profils par défaut hors liste sont écartés ;
-- profils utilisateur, profil actif et profils choisis sont conservés. Liste vide : aucun filtre.
function SpecEngine.FilterByNames(profiles, names, isBuiltin, activeName, chosen)
    if not names or #names == 0 then return profiles end
    local allowed = {}
    for _, n in ipairs(names) do allowed[n] = true end
    for _, n in pairs(chosen or {}) do allowed[n] = true end
    local kept = {}
    for _, p in ipairs(profiles) do
        if allowed[p.name] or not isBuiltin(p.name) or p.name == activeName then kept[#kept + 1] = p end
    end
    return kept
end

-- Profils existants parmi une liste de noms.
function SpecEngine.ByNames(names, profiles)
    local list = {}
    for _, n in ipairs(names or {}) do
        for _, p in ipairs(profiles) do if p.name == n then list[#list + 1] = p; break end end
    end
    return list
end

-- Noms de profils possibles pour une spé : table par spé, sinon rôles de la classe. Seuls les profils existants.
function SpecEngine.Choices(specID, classFile, bySpec, byClass, profiles)
    return SpecEngine.ByNames((bySpec and bySpec[specID]) or (byClass and byClass[classFile]), profiles)
end

-- Arbre de talents actif = celui qui a le plus de points investis. trees : { { name, points } }.
-- Retourne (index, nom) ou nil si aucun point ou égalité (aucune devinette).
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
