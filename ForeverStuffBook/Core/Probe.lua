local _, FSB = ...

-- Sonde de vérification en jeu (/fsb sonde) : lecture seule. Vérifie l'existence des API
-- utilisées par FSB et échantillonne leurs retours. Résultat affiché et stocké dans
-- FSB.db.probe pour être renvoyé au développement (docs/SONDE.md).
local Probe = {}
FSB.Probe = Probe

local APIS = {
    "C_Item.GetItemStats", "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemQualityByID",
    "C_TooltipInfo.GetHyperlink", "TooltipUtil.SurfaceArgs", "TooltipDataProcessor.AddTooltipPostCall",
    "C_SpecializationInfo.GetSpecialization", "C_SpecializationInfo.GetSpecializationInfo",
    "C_SpecializationInfo.GetInspectSpecialization", "C_SpecializationInfo.GetNumSpecializationsForClassID",
    "C_SpecializationInfo.GetClassIDFromSpecID", "GetSpecializationInfoForSpecID", "GetSpecializationInfoForClassID",
    "NotifyInspect", "CanInspect", "ClearInspectPlayer", "GetInventoryItemLink", "C_Map.GetBestMapForUnit",
    "UnitIsVisible", "CanDualWield", "C_Timer.NewTicker", "C_Timer.After", "IsInInstance", "IsInGroup",
    "ITEM_SET_BONUS_GRAY", "GetNumTalentTabs", "GetNumTalents", "GetTalentInfo", "GetTalentTabInfo",
    "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "GetSpecializationRole",
    "UnitGroupRolesAssigned", "GetShapeshiftFormID", "GetShapeshiftForm", "UnitClass",
}

local function Resolve(path)
    local v = _G
    for part in path:gmatch("[^.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local function Sample(lines)
    local function add(s) lines[#lines + 1] = s end
    local link
    for slot = 1, 19 do
        link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then add("échantillon : emplacement " .. slot); break end
    end
    if not link then return add("échantillon : aucun objet équipé") end
    local stats = FSB.Compat.GetStats(link)
    local keys = {}
    for k, v in pairs(stats or {}) do keys[#keys + 1] = k .. "=" .. tostring(v) end
    table.sort(keys)
    add("stats : " .. (stats and table.concat(keys, ", ") or "nil"))
    add("equipLoc : " .. tostring(FSB.Compat.GetEquipLoc(link)))
    add("setID : " .. tostring(FSB.Compat.GetSetID(link)))
    add("paliers de set : " .. (FSB.Compat.GetSetThresholds(link) and "lus" or "nil"))
    local okT, data = pcall(C_TooltipInfo and C_TooltipInfo.GetHyperlink or error, link)
    local first = okT and type(data) == "table" and data.lines and data.lines[1]
    add("tooltip ligne 1 : " .. (first and (tostring(first.leftText) .. " | couleur=" .. type(first.leftColor)
        .. (type(first.leftColor) == "table" and (" r=" .. tostring(first.leftColor.r)) or "")) or "illisible"))
    local usable = FSB.Compat.GetUsability(link)
    add("utilisabilité : " .. (usable and ("inutilisable=" .. tostring(usable.unusable) .. " niveau=" .. tostring(usable.reqLevel)) or "nil"))
    add("ITEM_MIN_LEVEL : " .. tostring(_G.ITEM_MIN_LEVEL))
    add("spé joueur : " .. tostring(FSB.Spec.Detect()))
end

function Probe.Run()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local ok, version, build, _, toc = pcall(GetBuildInfo)
    add(ok and ("client : " .. tostring(version) .. " build " .. tostring(build) .. " interface " .. tostring(toc)) or "GetBuildInfo : erreur")
    for _, path in ipairs(APIS) do add(path .. " : " .. type(Resolve(path))) end
    add("slot 18 : " .. tostring(GetInventorySlotInfo and select(2, pcall(GetInventorySlotInfo, "RANGEDSLOT")) or "n/a"))
    pcall(Sample, lines)
    if FSB.db then FSB.db.probe = lines end
    return lines
end

function Probe.Print() FSB.Utils.Report(Probe.Run()) end

-- /fsb debug : raisonnement complet sur le dernier objet survolé (stats, objets portés, scores).
local function StatList(stats)
    local t = {}
    for k, v in pairs(stats or {}) do t[#t + 1] = k .. "=" .. tostring(v) end
    table.sort(t)
    return #t > 0 and table.concat(t, ", ") or "(aucune)"
end

local function TooltipTexts(link, add, label)
    local ok, data = pcall(C_TooltipInfo and C_TooltipInfo.GetHyperlink or error, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return add(label .. " : illisible") end
    for i, line in ipairs(data.lines) do
        if i > 40 then break end
        local okT, text = pcall(function() return tostring(line.leftText) end)
        add(label .. " " .. i .. " : " .. (okT and text or "?"))
    end
end

function Probe.Debug()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local link = FSB.lastLink
    if not link then
        FSB.Utils.Print("Survole d'abord un objet équipable, puis retape /fsb debug.")
        return
    end
    local equipLoc = FSB.Compat.GetEquipLoc(link)
    local stats = FSB.Compat.GetStats(link)
    local profile = FSB.Profiles.GetActive()
    add("objet : " .. tostring(link) .. " | equipLoc=" .. tostring(equipLoc))
    add("stats : " .. StatList(stats))
    add("ITEM_MOD_MANA_REGENERATION : " .. tostring(_G.ITEM_MOD_MANA_REGENERATION) .. " | _SHORT : " .. tostring(_G.ITEM_MOD_MANA_REGENERATION_SHORT))
    local usable = FSB.Compat.GetUsability(link)
    add("utilisabilité : " .. (usable and ("inutilisable=" .. tostring(usable.unusable) .. " niveau=" .. tostring(usable.reqLevel)) or "nil"))
    add("profil actif : " .. tostring(profile and profile.name) .. " | " .. StatList(profile and profile.weights))
    local newScore = stats and profile and FSB.ScoreEngine.Score(stats, profile.weights)
    add("score nouvel objet : " .. tostring(newScore))
    for _, slot in ipairs(FSB.Stats.SLOTS_FOR[equipLoc or ""] or {}) do
        local item = FSB.Compat.GetEquipped(slot)
        if not item then
            add("emplacement " .. slot .. " : vide")
        else
            add("emplacement " .. slot .. " : " .. tostring(item.link) .. (item.unreadable and " ILLISIBLE" or ""))
            add("  stats : " .. StatList(item.stats))
            add("  score : " .. tostring(profile and FSB.ScoreEngine.Score(item.stats, profile.weights)))
            if not Probe.skipTooltips then TooltipTexts(item.link, add, "  tooltip porté") end
        end
    end
    if not Probe.skipTooltips then TooltipTexts(link, add, "tooltip objet") end
    local verdict = equipLoc and FSB.Analyzer.Analyze(link, equipLoc)
    add("verdict : " .. tostring(verdict and verdict.kind) .. " slot=" .. tostring(verdict and verdict.slot))
    if FSB.db then FSB.db.debug = lines end
    FSB.Utils.Report(lines)
end

-- /fsb etat : liste brute des spécialisations de la classe et de la spé détectée.
function Probe.Specs(add)
    -- Verdict de lecture des talents (ce que FSB utilise réellement pour trouver la spé).
    if not GetNumTalentTabs or not GetTalentTabInfo then
        add("LECTURE DES TALENTS : impossible — GetNumTalentTabs/GetTalentTabInfo absents (" ..
            tostring(GetNumTalentTabs ~= nil) .. "/" .. tostring(GetTalentTabInfo ~= nil) .. ")")
    else
        local trees = FSB.Spec.ReadTrees()
        if not trees then
            add("LECTURE DES TALENTS : impossible — format de GetTalentTabInfo non reconnu (voir onglets ci-dessous)")
        else
            local parts = {}
            for i, t in ipairs(trees) do parts[i] = tostring(t.name) .. "=" .. t.points end
            local idx, name = FSB.Spec.ActiveTree()
            add("LECTURE DES TALENTS : " .. table.concat(parts, ", ") .. " -> arbre actif : " .. tostring(name or "aucun/égalité"))
        end
    end
    local function pack(...) return { n = select("#", ...), ... } end
    local function show(t)
        local out = {}
        for i = 1, t.n do out[i] = tostring(t[i]) end
        return table.concat(out, " | ")
    end
    local classID = select(3, UnitClass("player"))
    local okN, num = pcall(function() return C_SpecializationInfo.GetNumSpecializationsForClassID(classID) end)
    add("classe : " .. tostring(classID) .. " | spés de la classe : " .. tostring(okN and num))
    for i = 1, 6 do
        local ok, r = pcall(function() return pack(GetSpecializationInfoForClassID(classID, i)) end)
        if ok and r[1] then add("  spé " .. i .. " : " .. show(r)) end
    end
    local okI, idx = pcall(function() return C_SpecializationInfo.GetSpecialization() end)
    add("index détecté : " .. tostring(okI and idx))
    if okI and idx then
        local ok, r = pcall(function() return pack(C_SpecializationInfo.GetSpecializationInfo(idx)) end)
        add("GetSpecializationInfo(index) : " .. (ok and show(r) or "erreur"))
    end
    local current = FSB.Spec.Current()
    if current then
        local ok, r = pcall(function() return pack(GetSpecializationInfoForSpecID(current)) end)
        add("GetSpecializationInfoForSpecID(" .. current .. ") : " .. (ok and show(r) or "erreur"))
    end
    -- Découverte des API de talents réellement présentes (noms uniquement, lecture seule).
    local found = {}
    for k, v in pairs(_G) do
        if type(v) == "function" and type(k) == "string" and k:find("Talent") then found[#found + 1] = k end
    end
    table.sort(found)
    add("fonctions globales *Talent* : " .. (#found > 0 and table.concat(found, ", ") or "aucune"))
    for _, ns in ipairs({ "C_ClassTalents", "C_Traits", "C_SpecializationInfo" }) do
        local t, names = _G[ns], {}
        if type(t) == "table" then for k, v in pairs(t) do if type(v) == "function" then names[#names + 1] = k end end end
        table.sort(names)
        add(ns .. " : " .. (type(t) == "table" and table.concat(names, ", ") or "absent"))
    end
    local okC, configID = pcall(function() return C_ClassTalents.GetActiveConfigID() end)
    add("config de talents active : " .. tostring(okC and configID))
    if GetNumTalentTabs then
        local okT, tabs = pcall(GetNumTalentTabs)
        add("onglets de talents : " .. tostring(okT and tabs))
        for t = 1, (okT and tabs or 0) do
            local ok, r = pcall(function() return pack(GetTalentTabInfo(t)) end)
            add("  onglet " .. t .. " : " .. (ok and show(r) or "erreur"))
        end
    end
    if GetShapeshiftFormID then add("forme : " .. tostring(select(2, pcall(GetShapeshiftFormID)))) end
    if UnitGroupRolesAssigned then add("rôle de groupe : " .. tostring(select(2, pcall(UnitGroupRolesAssigned, "player")))) end
end

-- /fsb specs : table brute des spécialisations de toutes les classes (id, nom, rôle, stat principale...).
function Probe.AllSpecs()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    for classID = 1, 15 do
        local okN, num = pcall(function() return C_SpecializationInfo.GetNumSpecializationsForClassID(classID) end)
        if okN and num and num > 0 then
            local okC, className = pcall(function() return select(1, GetClassInfo(classID)) end)
            add("classe " .. classID .. " " .. tostring(okC and className or "?") .. " : " .. num .. " spé(s)")
            for i = 1, num do
                local ok, packed = pcall(function() return { GetSpecializationInfoForClassID(classID, i) } end)
                local parts = {}
                if ok then for k = 1, 7 do parts[k] = tostring(packed[k]) end end
                add("  " .. i .. " : " .. (ok and table.concat(parts, " | ") or "erreur"))
            end
        end
    end
    if #lines == 0 then add("aucune spécialisation lisible") end
    if FSB.db then FSB.db.allSpecs = lines end
    FSB.Utils.Report(lines)
end
