local _, FSB = ...

-- Interface de configuration compacte (/fsb). Construite à la première ouverture.
-- Toute erreur de construction est interceptée : l'interface ne doit jamais casser l'analyse.
local UI = {}
FSB.UI = UI

local WIDTH, HEIGHT = 440, 450
local frame
local weightBoxes = {}

local function Editing() return FSB.Profiles.GetActive() end

local function Label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Button(parent, text, w, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetPoint("TOPLEFT", x, y); b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Check(parent, text, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y); c:SetSize(24, 24)
    local label = c.Text or c.text
    if label then label:SetText(text) end
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    c.Refresh = function(self) self:SetChecked(get()) end
    return c
end

---------------------------------------------------------------------------------------------
-- Rafraîchissement
---------------------------------------------------------------------------------------------

function UI.Refresh()
    if not frame then return end
    frame.enabled:Refresh(); frame.icons:Refresh(); frame.details:Refresh()
    frame.status:SetText(FSB.Spec.Label())
    

    local active = Editing()
    for _, row in ipairs(weightBoxes) do
        row.box:SetText(active.weights[row.key] and tostring(active.weights[row.key]) or "-")
    end
end

---------------------------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------------------------

local function BuildWeights(parent, top)
    local L = FSB.L
    Label(parent, L.UI_WEIGHTS, 16, top, "GameFontNormal")
    for i, s in ipairs(FSB.Stats.KEYS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = 16 + col * 210, top - 22 - row * 22
        Label(parent, s.label, x, y - 4)
        local value = Label(parent, "", x + 130, y - 4, "GameFontHighlightSmall")
        weightBoxes[#weightBoxes + 1] = { key = s.key, box = value }
    end
    return top - 22 - math.ceil(#FSB.Stats.KEYS / 2) * 22
end

local function Build()
    local L = FSB.L
    frame = CreateFrame("Frame", "FSBSettingsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT); frame:SetPoint("CENTER")
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "FSBSettingsFrame") -- se ferme avec Échap

    Label(frame, L.UI_TITLE, 16, -14, "GameFontNormalLarge")
    CreateFrame("Button", nil, frame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -4, -4)

    frame.enabled = Check(frame, L.UI_ENABLED, 12, -38,
        function() return FSB.db.enabled end, function(v) FSB.db.enabled = v end)
    local function display(name)
        return function() return FSB.db.display[name] ~= false end,
            function(v) FSB.db.display[name] = v end
    end
    frame.icons = Check(frame, L.UI_ICONS, 190, -38, display("icons"))
    frame.details = Check(frame, L.UI_DETAILS, 290, -38, display("details"))
    frame.status = Label(frame, "", 16, -68, "GameFontHighlightSmall")
    Button(frame, L.UI_PICK_ROLE, 130, 290, -62, function() UI.ShowRolePicker(true) end)

    BuildWeights(frame, -98)
    frame:Hide()
end

-- Question de rôle : proposée seulement quand la spé détectée a plusieurs rôles possibles.
local roleFrame
function UI.ShowRolePicker(force)
    local specID = FSB.Spec.Current()
    if not specID then return end
    local choices = FSB.Spec.Choices(specID)
    if #choices < 2 then return end
    local info = FSB.Spec.Info(specID)
    roleFrame = roleFrame or CreateFrame("Frame", "FSBRoleFrame", UIParent, "BackdropTemplate")
    roleFrame:SetSize(280, 90 + #choices * 28); roleFrame:SetPoint("CENTER", 0, 120)
    roleFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    roleFrame:SetFrameStrata("DIALOG")
    roleFrame.widgets = roleFrame.widgets or {}
    for _, w in ipairs(roleFrame.widgets) do w:Hide() end
    wipe(roleFrame.widgets)
    local title = roleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16); title:SetText(FSB.L.ROLE_PICK_TITLE:format((info and info.name) or "?"))
    local note = roleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOP", 0, -36); note:SetText(FSB.L.ROLE_PICK_NOTE)
    roleFrame.widgets[1], roleFrame.widgets[2] = title, note
    for i, p in ipairs(choices) do
        local b = Button(roleFrame, p.name, 220, 30, -50 - i * 28, function()
            FSB.Spec.Choose(p.name)
            roleFrame:Hide()
            UI.Refresh()
        end)
        roleFrame.widgets[#roleFrame.widgets + 1] = b
    end
    roleFrame:Show()
end

-- Fenêtre de texte à copier (journal, diagnostics, aide).
local logFrame
function UI.ShowText(text)
    local ok, err = pcall(function()
        if not logFrame then
            logFrame = CreateFrame("Frame", "FSBLogFrame", UIParent, "BackdropTemplate")
            logFrame:SetSize(560, 380); logFrame:SetPoint("CENTER")
            logFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
                insets = { left = 6, right = 6, top = 6, bottom = 6 } })
            logFrame:SetFrameStrata("DIALOG")
            logFrame:SetMovable(true); logFrame:EnableMouse(true); logFrame:RegisterForDrag("LeftButton")
            logFrame:SetScript("OnDragStart", logFrame.StartMoving); logFrame:SetScript("OnDragStop", logFrame.StopMovingOrSizing)
            tinsert(UISpecialFrames, "FSBLogFrame")
            Label(logFrame, FSB.L.COPY_TITLE, 16, -14, "GameFontNormal")
            CreateFrame("Button", nil, logFrame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -4, -4)
            local scroll = CreateFrame("ScrollFrame", "FSBLogScroll", logFrame, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 16, -40); scroll:SetPoint("BOTTOMRIGHT", -34, 16)
            local edit = CreateFrame("EditBox", nil, scroll)
            edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject("ChatFontNormal")
            edit:SetWidth(500)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            scroll:SetScrollChild(edit)
            logFrame.edit = edit
        end
        logFrame.edit:SetText(text)
        logFrame:Show()
        logFrame.edit:SetFocus(); logFrame.edit:HighlightText()
    end)
    if not ok then FSB.Utils.Print("UI : " .. tostring(err)) end
end

UI.ShowLog = UI.ShowText

function UI.Toggle()
    local ok, err = pcall(function()
        if not frame then Build() end
        if frame:IsShown() then frame:Hide() else UI.Refresh(); frame:Show() end
    end)
    if not ok then FSB.Utils.Print("UI : " .. tostring(err)) end
end
