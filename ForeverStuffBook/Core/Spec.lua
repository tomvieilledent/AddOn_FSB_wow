local _, FSB = ...

-- Spécialisation du joueur : détection par l'API, sinon choix manuel (db.manualSpecID).
-- En mode auto (db.autoProfile), le profil actif suit la spécialisation.
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
    return FSB.db.manualSpecID or Spec.Detect()
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

function Spec.SetManual(specID)
    FSB.db.manualSpecID = specID -- nil = retour à la détection automatique
    FSB.db.specPromptDone = true
    Spec.Apply()
end

local function ClassFile() return select(2, UnitClass("player")) end

-- Profils possibles pour la spé actuelle (liste d'objets profil).
function Spec.Choices(specID)
    return FSB.SpecEngine.Choices(specID, ClassFile(), FSB.Classes.BY_SPEC, FSB.Classes.ROLES, FSB.Profiles.List())
end

-- Vrai si la spé a plusieurs rôles possibles et que l'utilisateur n'a pas encore choisi.
function Spec.NeedsChoice()
    local specID = Spec.Current()
    if not specID or not FSB.db.autoProfile then return false end
    if FSB.db.specChoice[specID] and FSB.Profiles.Find(FSB.db.specChoice[specID]) then return false end
    local ambiguous = #Spec.Choices(specID) > 1
    if ambiguous then FSB.Log.Add("ROLE_AMBIGU", { detail = "spé " .. tostring(specID), global = true }) end
    return ambiguous
end

-- Mémorise le rôle choisi pour la spé actuelle et applique le profil.
function Spec.Choose(profileName)
    local specID = Spec.Current()
    if not specID or not FSB.Profiles.Find(profileName) then return false end
    FSB.db.specChoice[specID] = profileName
    FSB.Profiles.SetActive(profileName, true)
    return true
end

-- Applique le profil de la spé si le mode auto est actif : choix mémorisé, sinon rôle unique possible,
-- sinon (rôles multiples) le profil reste inchangé en attendant le choix (Spec.NeedsChoice).
-- Retourne false si aucune spé n'est connue (l'appelant peut alors proposer le choix de spé).
function Spec.Apply()
    local specID = Spec.Current()
    if not specID then return false end
    if FSB.db.autoProfile then
        local name = FSB.db.specChoice[specID]
        if not (name and FSB.Profiles.Find(name)) then
            local choices = Spec.Choices(specID)
            if #choices == 1 then
                name = choices[1].name
            elseif #choices == 0 then
                local p = FSB.SpecEngine.ProfileForSpec(specID, SpecInfo(specID), FSB.Profiles.List(), FSB.db.specProfiles)
                name = p and p.name
            else
                name = nil
            end
        end
        if name and name ~= FSB.db.activeProfile then FSB.Profiles.SetActive(name, true) end
    end
    return true
end

-- Ouvre la question de rôle si nécessaire.
function Spec.PromptIfNeeded()
    if Spec.NeedsChoice() and FSB.UI and FSB.UI.ShowRolePicker then FSB.UI.ShowRolePicker() end
end

-- Associe un profil à la spé actuelle (réglage utilisateur).
function Spec.MapCurrentTo(profileName)
    local specID = Spec.Current()
    if not specID or not FSB.Profiles.Find(profileName) then return false end
    FSB.db.specProfiles[specID] = profileName
    Spec.Apply()
    return true
end

-- Profils testés pour OFF-SPÉ : ceux que la classe peut tenir (rôles de la classe), sinon tous.
function Spec.OffspecProfiles()
    local names = FSB.Classes.ROLES[ClassFile() or ""]
    return FSB.SpecEngine.FilterByNames(FSB.Profiles.List(), names, FSB.Profiles.IsBuiltin,
        FSB.db.activeProfile, FSB.db.specChoice)
end
