local _, FSB = ...

-- Pipeline : tooltip affiché -> équipable ? -> rareté 2..5 ? -> analyse (en cache) -> verdict.
-- Les polices du jeu n'affichent pas les emojis : le verdict est coloré.
local COLORS = {
    EQUIP        = { 0.2, 1.0, 0.2 },
    TAKE         = { 0.2, 1.0, 0.2 },
    BETTER_OTHER = { 1.0, 0.85, 0.1 },
    OFFSPEC      = { 0.3, 0.6, 1.0 },
    SELL         = { 1.0, 0.25, 0.25 },
    CUPI         = { 1.0, 0.25, 0.25 },
}
local TEXT_KEY = {
    EQUIP = "VERDICT_EQUIP", TAKE = "VERDICT_TAKE", BETTER_OTHER = "VERDICT_BETTER_OTHER",
    OFFSPEC = "VERDICT_OFFSPEC", SELL = "VERDICT_SELL", CUPI = "VERDICT_CUPI",
}
local GREY = { 0.7, 0.7, 0.7 }

local function VerdictText(verdict)
    local text = FSB.L[TEXT_KEY[verdict.kind]]
    if verdict.kind == "OFFSPEC" then text = text .. " — " .. verdict.profile end
    return text
end

local function AddDetails(tooltip, verdict)
    local L = FSB.L
    if verdict.kind == "BETTER_OTHER" then
        tooltip:AddLine(L.BETTER_FOR:format(table.concat(verdict.others, ", ")), 1, 1, 1)
    end
    local set = verdict.setNote
    if set then
        if set.gained > 0 then tooltip:AddLine(L.SET_GAINED:format(set.gained) .. " " .. L.SET_UNVALUED, 0.6, 1, 0.6) end
        if set.lost > 0 then tooltip:AddLine(L.SET_LOST:format(set.lost) .. " " .. L.SET_UNVALUED, 1, 0.6, 0.6) end
        if set.partial then tooltip:AddLine(L.SET_PARTIAL, unpack(GREY)) end
    end
    if verdict.unscanned and verdict.unscanned > 0 then
        tooltip:AddLine(L.UNSCANNED:format(verdict.unscanned), unpack(GREY))
    end
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
    AddDetails(tooltip, verdict)
    tooltip:AddLine(FSB.L.PROFILE .. " : " .. FSB.db.activeProfile, unpack(GREY))
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
