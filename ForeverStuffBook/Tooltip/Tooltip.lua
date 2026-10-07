local _, FSB = ...

-- Pipeline : tooltip affiché -> équipable ? -> rareté 2..5 ? -> analyse (en cache) -> verdict.
-- Les polices du jeu n'affichent pas les emojis : le verdict est coloré.
local COLORS = {
    UNKNOWN      = { 0.7, 0.7, 0.7 },
    EQUIP        = { 0.2, 1.0, 0.2 },
    TAKE         = { 0.2, 1.0, 0.2 },
    BETTER_OTHER = { 1.0, 0.85, 0.1 },
    OFFSPEC      = { 0.3, 0.6, 1.0 },
    SELL         = { 1.0, 0.25, 0.25 },
    CUPI         = { 1.0, 0.25, 0.25 },
}
local TEXT_KEY = {
    UNKNOWN = "VERDICT_UNKNOWN", EQUIP = "VERDICT_EQUIP", TAKE = "VERDICT_TAKE", BETTER_OTHER = "VERDICT_BETTER_OTHER",
    OFFSPEC = "VERDICT_OFFSPEC", SELL = "VERDICT_SELL", CUPI = "VERDICT_CUPI",
}
local GREY = { 0.7, 0.7, 0.7 }
local GOLD = { 1.0, 0.82, 0.0 }

-- Icônes standard du jeu (contrôle de disponibilité). Facultatives : option « Icônes ».
local ICON_PATH = "Interface\\RaidFrame\\ReadyCheck-"
local ICON = {
    EQUIP = "Ready", TAKE = "Ready", BETTER_OTHER = "Waiting", SELL = "NotReady", CUPI = "NotReady",
}

-- Option d'affichage : active par défaut tant que l'utilisateur ne l'a pas désactivée.
local function Option(name)
    local d = FSB.db and FSB.db.display
    return d == nil or d[name] ~= false
end

local function VerdictText(verdict)
    local text = FSB.L[TEXT_KEY[verdict.kind]]
    if verdict.kind == "OFFSPEC" then text = text .. " — " .. FSB.Profiles.DisplayName(verdict.profile) end
    local icon = ICON[verdict.kind]
    if Option("icons") then
        text = (icon and ("|T" .. ICON_PATH .. icon .. ":16:16:0:0|t ") or "      ") .. text
    end
    return text
end

local function AddDetails(tooltip, verdict)
    local L = FSB.L
    local details = Option("details")
    if verdict.unusable then tooltip:AddLine(L.UNUSABLE, unpack(GREY)) end
    if verdict.reqLevel then tooltip:AddLine(L.REQ_LEVEL:format(verdict.reqLevel), 1, 0.6, 0.2) end
    if verdict.unknownStats then tooltip:AddLine(L.UNKNOWN_STATS, 1, 0.6, 0.2) end
    if verdict.kind == "BETTER_OTHER" then
        tooltip:AddLine(L.BETTER_FOR:format(table.concat(verdict.others, ", ")), 1, 1, 1)
    end
    if not details then return end
    local set = verdict.setNote
    if set then
        if set.gained > 0 then tooltip:AddLine(L.SET_GAINED:format(set.gained) .. " " .. L.SET_UNVALUED, 0.6, 1, 0.6) end
        if set.lost > 0 then tooltip:AddLine(L.SET_LOST:format(set.lost) .. " " .. L.SET_UNVALUED, 1, 0.6, 0.6) end
        if set.partial then tooltip:AddLine(L.SET_PARTIAL, unpack(GREY)) end
    end
    if verdict.unscanned and verdict.unscanned > 0 then
        tooltip:AddLine(L.UNSCANNED:format(verdict.unscanned), unpack(GREY))
    end
    tooltip:AddLine(FSB.Spec.Label(), unpack(GREY))
end

local function AppendAnalysis(tooltip)
    if not FSB.db or not FSB.db.enabled then return end
    if not tooltip or not tooltip.GetItem then return end
    if tooltip.fsbDone then return end -- une seule fois par affichage

    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or not link then return end

    local U = FSB.Utils
    local equipLoc = U.GetEquipLoc(link)
    if not equipLoc then return end
    if not U.IsAnalysedQuality(U.GetQuality(link)) then return end

    FSB.lastLink = link
    local verdict = FSB.Analyzer.Analyze(link, equipLoc)
    if not verdict then return end
    FSB.lastVerdict = verdict.kind

    -- Un bloc : espace, ligne de verdict (couleur + icône) avec la marque FSB à droite, puis détails.
    local c = COLORS[verdict.kind]
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(VerdictText(verdict), FSB.L.ANALYSIS_TITLE, c[1], c[2], c[3], GOLD[1], GOLD[2], GOLD[3])
    AddDetails(tooltip, verdict)
    tooltip.fsbDone = true
    tooltip:Show() -- recalcule la taille du tooltip
end

-- Le drapeau est remis à zéro quand le tooltip est vidé.
local function HookReset(tooltip)
    if tooltip and tooltip.HookScript and not tooltip.fsbHooked then
        tooltip.fsbHooked = true
        tooltip:HookScript("OnTooltipCleared", function(self) self.fsbDone = nil end)
    end
end
if GameTooltip then HookReset(GameTooltip) end

-- API moderne si disponible, sinon repli sur le script classique.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        HookReset(tooltip)
        AppendAnalysis(tooltip)
    end)
elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", AppendAnalysis)
end
