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
    "ITEM_SET_BONUS_GRAY",
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
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 1)
    if not link then return add("échantillon : aucun objet équipé en tête") end
    local stats = FSB.Compat.GetStats(link)
    local keys = {}
    for k, v in pairs(stats or {}) do keys[#keys + 1] = k .. "=" .. tostring(v) end
    table.sort(keys)
    add("stats(tête) : " .. (stats and table.concat(keys, ", ") or "nil"))
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
