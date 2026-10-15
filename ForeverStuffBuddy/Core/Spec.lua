local _, FSB = ...

-- Spécialisation du joueur : détection par l'API uniquement (aucun mode manuel).
-- Le profil actif suit toujours l'arbre de talents le plus investi et le mode de jeu ; aucune question n'est posée.
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

-- Points investis par arbre de talents, système moderne (C_Traits). Les trois arbres classiques sont rangés côte à
-- côte dans une même arborescence (VERIFIED sur un prêtre : Discipline x=1020..2820, Sacré x=5020..6820,
-- Ombre x=9080..10880) : l'arbre d'un nœud se lit donc à sa position horizontale (bandes de 4000). Les nœuds à
-- position verticale aberrante (> 8000, ex. « Spécialisation (Sacré) » à y=21300) sont ignorés. Les `groupIDs`
-- ne servent pas : ce sont des groupes de lignes imbriqués, pas un groupe par arbre (vu en jeu). Le nombre
-- d'arbres trouvés doit égaler celui des arbres connus de la classe (aucune devinette sinon).
local BAND_WIDTH, MAX_Y = 4000, 8000

local function ReadTraitTrees()
    if not C_ClassTalents or not C_Traits then return nil end
    local ok, configID = pcall(function() return C_ClassTalents.GetActiveConfigID() end)
    if not ok or not configID then return nil end
    local okC, cfg = pcall(function() return C_Traits.GetConfigInfo(configID) end)
    if not okC or type(cfg) ~= "table" or type(cfg.treeIDs) ~= "table" then return nil end

    local byBand = {}
    for _, treeID in ipairs(cfg.treeIDs) do
        local okN, nodes = pcall(function() return C_Traits.GetTreeNodes(treeID) end)
        if not okN or type(nodes) ~= "table" then return nil end
        for _, nodeID in ipairs(nodes) do
            local okI, info = pcall(function() return C_Traits.GetNodeInfo(configID, nodeID) end)
            if okI and type(info) == "table" then
                local rank = tonumber(info.currentRank) or 0
                local x, y = tonumber(info.posX), tonumber(info.posY)
                if x and y and y <= MAX_Y then
                    local band = math.floor(x / BAND_WIDTH)
                    byBand[band] = (byBand[band] or 0) + rank
                end
            end
        end
    end

    local classFile = select(2, UnitClass("player"))
    local known = FSB.Classes.TREES[classFile or ""]
    if not known then return nil end
    local names = FSB.L.TREE_NAMES and FSB.L.TREE_NAMES[classFile]
    do
        local source = byBand
        local keys = {}
        for key in pairs(source) do keys[#keys + 1] = key end
        table.sort(keys)
        if #keys == #known then
            local trees = {}
            for i, key in ipairs(keys) do trees[i] = { name = (names and names[i]) or ("#" .. i), points = source[key] } end
            return trees
        end
    end
    return nil
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

-- Arbre de la spé, entièrement automatique (aucune question) : l'arbre le plus investi en points de talents.
-- Égalité : le dernier arbre détecté s'il fait partie des ex æquo, sinon le premier d'entre eux.
-- Aucun point (bas niveau) ou talents illisibles : le dernier arbre détecté pour cette classe, sinon le premier.
-- Retourne (index, détecté) : détecté = false quand l'arbre vient du repli.
function Spec.Tree()
    local class = ClassFile() or ""
    FSB.db.lastTree = FSB.db.lastTree or {}
    local last = FSB.db.lastTree[class]
    local trees = Spec.ReadTrees()
    local best, tied = 0, {}
    for i, t in ipairs(trees or {}) do
        if t.points > best then best, tied = t.points, { i }
        elseif t.points == best and best > 0 then tied[#tied + 1] = i end
    end
    if best > 0 then
        local tree = tied[1]
        for _, i in ipairs(tied) do if i == last then tree = i end end
        FSB.db.lastTree[class] = tree
        return tree, true
    end
    return last or 1, false
end

-- Profil de la spé (arbre de talents) dans le mode de jeu actuel, ou nil si la classe n'a pas de poids.
-- Sous le niveau 10 il n'y a pas de spé : profil de classe (arbre 0).
function Spec.Profile()
    local mode = FSB.Context.Mode()
    local tree = mode:find("^LOW_") and 0 or Spec.Tree()
    local variant = (ClassFile() == "DRUID" and tree == 2) and FSB.db.feralForm or nil
    return FSB.Profiles.For(ClassFile() or "", tree, mode, variant)
end

-- Vrai si le personnage est un druide farouche (arbre 2, niveau 10+) : seul cas où ours/félin se choisit.
function Spec.IsFeral()
    if ClassFile() ~= "DRUID" or FSB.Context.Mode():find("^LOW_") then return false end
    return Spec.Tree() == 2
end

-- Applique le profil de la spé et du mode. Retourne false si la classe n'a aucun profil.
-- Druide farouche sans forme choisie : demande ours ou félin (félin en attendant la réponse).
function Spec.Apply()
    local p = Spec.Profile()
    if not p then return false end
    if p.name ~= FSB.db.activeProfile then FSB.Profiles.SetActive(p.name) end
    if FSB.UI and FSB.UI.Refresh then FSB.UI.Refresh() end
    if not FSB.db.feralForm and Spec.IsFeral() and FSB.UI and FSB.UI.ShowFeralPicker then FSB.UI.ShowFeralPicker() end
    return true
end

-- Profils testés pour OFF-SPÉ : les autres arbres de la classe, dans le même mode.
function Spec.OffspecProfiles()
    return FSB.Profiles.ForClass(ClassFile() or "", FSB.Context.Mode())
end

-- Tout ce que FSB a détecté, en texte (onglet Détection) :
-- { class, spec, role, level, mode, place, profile }.
function Spec.Describe()
    local L, Context = FSB.L, FSB.Context
    local class = ClassFile() or ""
    local d = {}
    d.class = (L.CLASS_NAMES and L.CLASS_NAMES[class]) or (UnitClass("player")) or "?"

    local mode = Context.Mode()
    if mode:find("^LOW_") then
        d.spec = L.DET_NOSPEC
    else
        local tree, detected = Spec.Tree()
        local names = L.TREE_NAMES and L.TREE_NAMES[class]
        local points = {}
        for i, t in ipairs(Spec.ReadTrees() or {}) do
            points[i] = ((names and names[i]) or ("#" .. i)) .. " " .. t.points
        end
        d.spec = ((names and names[tree]) or ("#" .. tree))
            .. (#points > 0 and ("  (" .. table.concat(points, " · ") .. ")") or "")
            .. (detected and "" or ("  " .. L.DET_FALLBACK))
    end

    local p = FSB.Profiles.GetActive()
    d.role = FSB.Profiles.RoleLabel(p)
    local level = (UnitLevel and UnitLevel("player")) or 0
    local bracket = (level < Context.SPEC_LEVEL and "1–9") or (level < Context.MAX_LEVEL and "10–59") or "60"
    d.level = ("%d  (%s)"):format(level, bracket)
    local style = Context.Playstyle()
    d.mode = L.PLAYSTYLES[style] .. "  →  " .. ((L.MODES and L.MODES[mode]) or mode)
        .. (mode:find("^LOW_") and ("  " .. L.DET_LOW_NOTE) or "")
    d.place = L.PLACES[Context.Place()] or Context.Place()
    d.profile = p and FSB.Profiles.DisplayName(p.name) or "?"
    return d
end

-- Libellé : « Spé : Mage · Givre · PvE 60 » (arbre lu dans les talents) ou « Classe : ... » (arbre par défaut).
function Spec.Label()
    local _, detected = Spec.Tree()
    return (detected and FSB.L.LABEL_SPEC or FSB.L.LABEL_CLASS) .. " : "
        .. FSB.Profiles.DisplayName(FSB.db.activeProfile or "?")
end
