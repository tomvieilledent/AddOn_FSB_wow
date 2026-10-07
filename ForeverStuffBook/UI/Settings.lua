local _, FSB = ...

-- Interface de configuration compacte (/fsb). Construite à la première ouverture.
-- Toute erreur de construction est interceptée : l'interface ne doit jamais casser l'analyse.
local UI = {}
FSB.UI = UI

local WIDTH, HEIGHT = 440, 620
local frame, specFrame
local profileButtons, weightBoxes, thresholdBoxes = {}, {}, {}

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

-- Champ numérique : valide à Entrée ou à la perte du focus. Texte vide = valeur par défaut/nil.
local function NumberBox(parent, x, y, w, onValue)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20); e:SetPoint("TOPLEFT", x, y); e:SetAutoFocus(false)
    local function commit(self)
        local text = self:GetText()
        onValue(text ~= "" and tonumber(text) or nil)
        self:ClearFocus()
    end
    e:SetScript("OnEnterPressed", commit)
    e:SetScript("OnEditFocusLost", commit)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); UI.Refresh() end)
    return e
end

local function Threshold(name) return (FSB.db.thresholds and FSB.db.thresholds[name]) or FSB.Verdict.DEFAULT_THRESHOLDS[name] end
local function SetThreshold(name, value)
    FSB.db.thresholds = FSB.db.thresholds or {}
    FSB.db.thresholds[name] = value
    FSB.Analyzer.InvalidateAll()
end

---------------------------------------------------------------------------------------------
-- Rafraîchissement
---------------------------------------------------------------------------------------------

function UI.Refresh()
    if not frame then return end
    frame.enabled:Refresh(); frame.auto:Refresh(); frame.icons:Refresh(); frame.details:Refresh()

    local profiles = FSB.Profiles.List()
    for i = 1, #profileButtons do profileButtons[i]:Hide() end
    for i, p in ipairs(profiles) do
        local b = profileButtons[i]
        if not b then
            b = Button(frame, "", 100, 0, 0, nil)
            profileButtons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 16 + ((i - 1) % 4) * 104, -118 - math.floor((i - 1) / 4) * 24)
        b:SetText((p.name == FSB.db.activeProfile and "* " or "") .. p.name)
        b:SetScript("OnClick", function() FSB.Profiles.SetActive(p.name); UI.Refresh() end)
        b:Show()
    end

    local active = FSB.Profiles.GetActive()
    for _, row in ipairs(weightBoxes) do
        row.box:SetText(active.weights[row.key] and tostring(active.weights[row.key]) or "")
    end
    thresholdBoxes.upgrade:SetText(tostring(math.floor(Threshold("upgradeRel") * 100 + 0.5)))
    thresholdBoxes.margin:SetText(tostring(math.floor(Threshold("otherMargin") * 100 + 0.5)))
    thresholdBoxes.setValue:SetText(tostring(active.setBonusValue or 0))
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
        local box = NumberBox(parent, x + 120, y, 60, function(value)
            FSB.Profiles.SetWeight(FSB.Profiles.GetActive(), s.key, value)
        end)
        weightBoxes[#weightBoxes + 1] = { key = s.key, box = box }
    end
    return top - 22 - math.ceil(#FSB.Stats.KEYS / 2) * 22
end

local function BuildThresholds(parent, top)
    local L = FSB.L
    Label(parent, L.UI_THRESHOLDS, 16, top, "GameFontNormal")
    local y = top - 22
    Label(parent, L.UI_UPGRADE, 16, y - 4)
    thresholdBoxes.upgrade = NumberBox(parent, 120, y, 50, function(v) if v then SetThreshold("upgradeRel", v / 100) end end)
    Label(parent, L.UI_MARGIN, 190, y - 4)
    thresholdBoxes.margin = NumberBox(parent, 290, y, 50, function(v) if v then SetThreshold("otherMargin", v / 100) end end)
    Label(parent, L.UI_SETVALUE, 16, y - 28)
    thresholdBoxes.setValue = NumberBox(parent, 150, y - 24, 60, function(v)
        FSB.Profiles.SetBonusValue(FSB.Profiles.GetActive(), v or 0)
    end)
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
    frame.auto = Check(frame, L.UI_AUTO, 12, -62, function() return FSB.db.autoProfile end,
        function(v) FSB.db.autoProfile = v; if v then FSB.Spec.Apply() end; UI.Refresh() end)
    Button(frame, L.UI_PICK_ROLE, 130, 290, -62, function() UI.ShowRolePicker(true) end)

    Label(frame, L.UI_PROFILES, 16, -98, "GameFontNormal")
    -- les boutons de profil sont créés dans Refresh (zone y = -118 à -190)

    local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameBox:SetSize(150, 20); nameBox:SetPoint("TOPLEFT", 22, -196); nameBox:SetAutoFocus(false)
    Button(frame, L.UI_NEW, 70, 180, -195, function()
        local name = nameBox:GetText()
        if FSB.Profiles.Create(name) then nameBox:SetText("") end
        UI.Refresh()
    end)
    Button(frame, L.UI_DELETE, 90, 254, -195, function() FSB.Profiles.Delete(FSB.db.activeProfile); UI.Refresh() end)

    local y = BuildWeights(frame, -228)
    BuildThresholds(frame, y - 10)
    frame:Hide()
end

---------------------------------------------------------------------------------------------
-- Choix de la spécialisation (quand la détection est impossible, ou à la demande)
---------------------------------------------------------------------------------------------

function UI.ShowSpecPicker()
    if specFrame then specFrame:Hide() end
    local list = FSB.Spec.ListForPlayerClass()
    specFrame = specFrame or CreateFrame("Frame", "FSBSpecFrame", UIParent, "BackdropTemplate")
    specFrame:SetSize(260, 70 + (#list + 1) * 28); specFrame:SetPoint("CENTER", 0, 120)
    specFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    specFrame:SetFrameStrata("DIALOG")
    specFrame.widgets = specFrame.widgets or {}
    for _, w in ipairs(specFrame.widgets) do w:Hide() end
    wipe(specFrame.widgets)

    local title = specFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16); title:SetText(FSB.L.SPEC_PICK_TITLE)
    specFrame.widgets[1] = title

    local function choose(specID)
        FSB.Spec.SetManual(specID)
        specFrame:Hide()
        UI.Refresh()
    end
    local entries = { { id = nil, name = FSB.L.SPEC_AUTO } }
    for _, s in ipairs(list) do entries[#entries + 1] = s end
    for i, s in ipairs(entries) do
        local b = Button(specFrame, s.name, 200, 30, -34 - i * 28, function() choose(s.id) end)
        specFrame.widgets[#specFrame.widgets + 1] = b
    end
    specFrame:Show()
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
