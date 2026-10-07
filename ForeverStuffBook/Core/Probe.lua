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

function Probe.Print()
    for _, l in ipairs(Probe.Run()) do FSB.Utils.Print(l) end
end

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
    for _, l in ipairs(lines) do FSB.Utils.Print(l) end
end
