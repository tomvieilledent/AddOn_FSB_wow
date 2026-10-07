local _, FSB = ...

-- Spécialisation du joueur : détection par l'API uniquement (aucun mode manuel).
-- Le profil actif suit toujours la spécialisation ; une question de rôle n'est posée que si la spé en a plusieurs.
local Spec = {}
FSB.Spec = Spec

local function SpecInfo(specID)
    if not specID or not GetSpecializationInfoForSpecID then return nil end
    local ok, id, name, _, _, role = pcall(GetSpecializationInfoForSpecID, specID)
    if not ok or not id then return nil end
    local primary
    if C_SpecializationInfo and C_SpecializationInfo.GetClassIDFromSpecID then
        local classID = C_SpecializationInfo.GetClassIDFromSpecID(specID)
        primary = Spec.PrimaryStat(classID, specID)
    end
    return { name = name, role = role, primaryStat = primary }
end
Spec.Info = SpecInfo

-- Stat principale (1 force, 2 agilité, 3 intelligence) d'une spé d'une classe.
function Spec.PrimaryStat(classID, specID)
    if not classID or not C_SpecializationInfo then return nil end
    local n = C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    for i = 1, n do
        if GetSpecializationInfoForClassID(classID, i) == specID then
            local ok, _, _, _, _, _, primary = pcall(C_SpecializationInfo.GetSpecializationInfo,
                i, false, false, nil, nil, nil, classID)
            return ok and primary or nil
        end
    end
end

-- Spécialisation du joueur détectée par l'API, ou nil.
function Spec.Detect()
    if not C_SpecializationInfo or not C_SpecializationInfo.GetSpecialization then return nil end
    local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
    if not ok or not index or index == 0 then return nil end
    local ok2, specID = pcall(C_SpecializationInfo.GetSpecializationInfo, index)
    if ok2 and type(specID) == "number" and specID > 0 then return specID end
end

function Spec.Current()
    return Spec.Detect()
end

-- Liste { { id, name } } des spécialisations de la classe du joueur (pour le choix manuel).
function Spec.ListForPlayerClass()
    local list = {}
    local classID = select(3, UnitClass("player"))
    if not classID or not C_SpecializationInfo then return list end
    for i = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0 do
        local id, name = GetSpecializationInfoForClassID(classID, i)
        if id then list[#list + 1] = { id = id, name = name } end
    end
    return list
end

local function ClassFile() return select(2, UnitClass("player")) end

-- Points investis par arbre de talents, système moderne (C_Traits) : les nœuds de la configuration active sont
-- regroupés par `groupIDs` ; chaque groupe correspond à un arbre classique, dans l'ordre croissant des identifiants
-- (= ordre des onglets). Les groupes ne sont acceptés que s'ils sont aussi nombreux que les arbres connus de la
-- classe (aucune devinette sinon). UNVERIFIED sur Forever : voir le rapport (/fsb rapport, lignes TRAITS).
local function ReadTraitTrees()
    if not C_ClassTalents or not C_Traits then return nil end
    local ok, configID = pcall(function() return C_ClassTalents.GetActiveConfigID() end)
    if not ok or not configID then return nil end
    local okC, cfg = pcall(function() return C_Traits.GetConfigInfo(configID) end)
    if not okC or type(cfg) ~= "table" or type(cfg.treeIDs) ~= "table" then return nil end
    local points, order = {}, {}
    for _, treeID in ipairs(cfg.treeIDs) do
        local okN, nodes = pcall(function() return C_Traits.GetTreeNodes(treeID) end)
        if not okN or type(nodes) ~= "table" then return nil end
        for _, nodeID in ipairs(nodes) do
            local okI, info = pcall(function() return C_Traits.GetNodeInfo(configID, nodeID) end)
            local group = okI and type(info) == "table" and type(info.groupIDs) == "table" and info.groupIDs[1]
            if group then
                if points[group] == nil then points[group] = 0; order[#order + 1] = group end
                points[group] = points[group] + (tonumber(info.currentRank) or 0)
            end
        end
    end
    table.sort(order)
    local known = FSB.Classes.TREES[select(2, UnitClass("player")) or ""]
    if not known or #order ~= #known then return nil end
    local names = FSB.L.TREE_NAMES and FSB.L.TREE_NAMES[select(2, UnitClass("player"))]
    local trees = {}
    for i, group in ipairs(order) do trees[i] = { name = (names and names[i]) or ("#" .. i), points = points[group] } end
    return trees
end

-- Points investis par arbre : { { name, points } } ou nil si aucune API de talents lisible.
-- Ancien système (GetTalentTabInfo, absent de Forever d'après /fsb rapport) puis système moderne (C_Traits).
function Spec.ReadTrees()
    if GetNumTalentTabs and GetTalentTabInfo then
        local ok, n = pcall(GetNumTalentTabs)
        if ok and type(n) == "number" and n >= 1 then
            local trees = {}
            for i = 1, n do
                local okT, a, b, c, d, e = pcall(GetTalentTabInfo, i)
                local name, points
                if okT and type(a) == "string" then name, points = a, c
                elseif okT and type(a) == "number" and type(b) == "string" then name, points = b, e end
                if type(points) ~= "number" then trees = nil; break end
                trees[i] = { name = name, points = points }
            end
            if trees then return trees end
        end
    end
    return ReadTraitTrees()
end

-- (index, nom) de l'arbre de talents le plus investi, ou nil (API absente, aucun point, égalité).
function Spec.ActiveTree()
    return FSB.SpecEngine.ActiveTree(Spec.ReadTrees())
end

-- Clé de mémorisation du choix : classe détectée + arbre actif.
function Spec.Key(specID)
    local tree = Spec.ActiveTree()
    return tostring(specID) .. ":" .. tostring(tree or 0)
end

-- Profils possibles : table par spé, sinon selon l'arbre actif, sinon rôles de la classe.
function Spec.Choices(specID)
    local tree = Spec.ActiveTree()
    local byTree = tree and FSB.Classes.TREES[ClassFile() or ""]
    local names = FSB.Classes.BY_SPEC[specID] or (byTree and byTree[tree]) or FSB.Classes.ROLES[ClassFile() or ""]
    return FSB.SpecEngine.ByNames(names, FSB.Profiles.List())
end

-- Vrai si la spé a plusieurs rôles possibles et que l'utilisateur n'a pas encore choisi.
function Spec.NeedsChoice()
    local specID = Spec.Current()
    if not specID then return false end
    local chosen = FSB.db.specChoice[Spec.Key(specID)]
    if chosen and FSB.Profiles.Find(chosen) then return false end
    local ambiguous = #Spec.Choices(specID) > 1
    if ambiguous then FSB.Log.Add("ROLE_AMBIGU", { detail = "clé " .. Spec.Key(specID), global = true }) end
    return ambiguous
end

-- Mémorise le rôle choisi pour la spé actuelle et applique le profil.
function Spec.Choose(profileName)
    local specID = Spec.Current()
    if not specID or not FSB.Profiles.Find(profileName) then return false end
    FSB.db.specChoice[Spec.Key(specID)] = profileName
    FSB.Profiles.SetActive(profileName)
    return true
end

-- Applique le profil de la spé : choix mémorisé, sinon rôle unique possible, sinon (rôles multiples) le profil
-- reste inchangé en attendant le choix (Spec.NeedsChoice).
-- Retourne false si aucune spé n'est détectée (journalisé : la détection doit fonctionner).
function Spec.Apply()
    local specID = Spec.Current()
    if not specID then return false end
    local name = FSB.db.specChoice[Spec.Key(specID)]
    if not (name and FSB.Profiles.Find(name)) then
        local choices = Spec.Choices(specID)
        if #choices == 1 then
            name = choices[1].name
        elseif #choices == 0 then
            local p = FSB.SpecEngine.ProfileForSpec(specID, SpecInfo(specID), FSB.Profiles.List(), nil)
            name = p and p.name
        else
            name = nil
        end
    end
    if name and name ~= FSB.db.activeProfile then FSB.Profiles.SetActive(name) end
    return true
end

-- Ouvre la question de rôle si nécessaire.
function Spec.PromptIfNeeded()
    if Spec.NeedsChoice() and FSB.UI and FSB.UI.ShowRolePicker then FSB.UI.ShowRolePicker() end
end

-- Profils testés pour OFF-SPÉ : ceux que la classe peut tenir (rôles de la classe), sinon tous.
function Spec.OffspecProfiles()
    local names = FSB.Classes.ROLES[ClassFile() or ""]
    return FSB.SpecEngine.FilterByNames(FSB.Profiles.List(), names, FSB.Profiles.IsBuiltin,
        FSB.db.activeProfile, FSB.db.specChoice)
end

-- Libellé : « Spé : Prêtre · Sacré · Soigneur » si l'arbre de talents est lisible, sinon « Classe : Prêtre · Soigneur ».
function Spec.Label()
    local specID = Spec.Current()
    local info = specID and SpecInfo(specID)
    local _, treeName = Spec.ActiveTree()
    local class = (info and info.name) or "?"
    local parts = { class }
    if treeName then parts[#parts + 1] = treeName end
    parts[#parts + 1] = FSB.Profiles.DisplayName(FSB.db.activeProfile or "?")
    return (treeName and FSB.L.LABEL_SPEC or FSB.L.LABEL_CLASS) .. " : " .. table.concat(parts, " · ")
end
