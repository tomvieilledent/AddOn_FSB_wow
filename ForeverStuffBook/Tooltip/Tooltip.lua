local _, FSB = ...

-- Pipeline : tooltip affiché -> équipable ? -> rareté 2..5 ? -> analyse (en cache) -> verdict.
-- Les polices du jeu n'affichent pas les emojis : le verdict est coloré.
local COLORS = {
    EQUIP   = { 0.2, 1.0, 0.2 },
    OFFSPEC = { 0.3, 0.6, 1.0 },
    SELL    = { 1.0, 0.25, 0.25 },
}

local function VerdictText(verdict)
    local L = FSB.L
    if verdict.kind == "EQUIP" then return L.VERDICT_EQUIP end
    if verdict.kind == "OFFSPEC" then return L.VERDICT_OFFSPEC .. " — " .. verdict.profile end
    return L.VERDICT_SELL
end

local function AppendAnalysis(tooltip)
    if not FSB.db or not FSB.db.enabled then return end
    if not tooltip or not tooltip.GetItem then return end

    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or not link then return end

    local U = FSB.Utils
    local equipLoc = U.GetEquipLoc(link)
    if not equipLoc then return end
    if not U.IsAnalysedQuality(U.GetQuality(link)) then return end

    local verdict = FSB.Analyzer.Analyze(link, equipLoc)
    if not verdict then return end

    local c = COLORS[verdict.kind]
    tooltip:AddLine(" ")
    tooltip:AddLine(VerdictText(verdict), c[1], c[2], c[3])
    tooltip:AddLine(FSB.L.PROFILE .. " : " .. FSB.db.activeProfile, 0.7, 0.7, 0.7)
    tooltip:AddLine(FSB.L.ANALYSIS_TITLE, 0.2, 1.0, 0.6)
    tooltip:Show() -- recalcule la taille du tooltip
end

-- API moderne si disponible, sinon repli sur le script classique.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        AppendAnalysis(tooltip)
    end)
elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", AppendAnalysis)
end
