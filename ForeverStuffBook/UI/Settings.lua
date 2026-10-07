local _, FSB = ...

-- Interface de configuration compacte (/fsb) : onglets Accueil, Réglages et Stats. Construite à la première ouverture.
-- Toute erreur de construction est interceptée : l'interface ne doit jamais casser l'analyse.
local UI = {}
FSB.UI = UI

-- Onglet « Stats » temporaire : à passer à false (ou supprimer BuildStatsTab) une fois les poids équilibrés.
UI.SHOW_STATS_TAB = true

local WIDTH, HEIGHT = 440, 500
local frame
local weightBoxes = {}
local texts = {} -- { widget, clé de texte } : réaffichés au changement de langue

local function Editing() return FSB.Profiles.GetActive() end

-- text : clé de FSB.L (traduite et mémorisée) ou texte brut.
local function Resolve(text, widget)
    if FSB.L[text] ~= nil then
        texts[#texts + 1] = { widget = widget, key = text }
        return FSB.L[text]
    end
    return text
end

local function Label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(Resolve(text, fs))
    return fs
end

-- Paragraphe multi-lignes à retour automatique.
local function Paragraph(parent, text, x, y, width, template)
    local fs = Label(parent, text, x, y, template or "GameFontHighlight")
    fs:SetWidth(width); fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    return fs
end

local function Button(parent, text, w, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetPoint("TOPLEFT", x, y); b:SetText(Resolve(text, b))
    b:SetScript("OnClick", onClick)
    return b
end

local function Check(parent, text, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y); c:SetSize(24, 24)
    local label = c.Text or c.text
    if label then label:SetText(Resolve(text, label)) end
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
    frame.devCommands:SetText(table.concat(FSB.L.HELP, "\n"))
    frame.credits:SetText(FSB.L.HOME_CREDITS .. "   ·   v" .. FSB.Utils.AddonVersion(FSB.name or "ForeverStuffBook"))
    frame.langFR:SetEnabled(FSB.language ~= "frFR")
    frame.langEN:SetEnabled(FSB.language ~= "enUS")
    if frame.statsTab then
        local active = Editing()
        for _, row in ipairs(weightBoxes) do
            row.name:SetText(FSB.Stats.Label(row.key))
            row.box:SetText(active.weights[row.key] and tostring(active.weights[row.key]) or "-")
        end
    end
end

-- Changement de langue : tous les textes enregistrés sont réécrits.
function UI.Retranslate()
    for _, t in ipairs(texts) do t.widget:SetText(FSB.L[t.key]) end
    UI.Refresh()
end

---------------------------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------------------------

local TOP = -64 -- haut du contenu des onglets

-- Page d'accueil : descriptif, fonctionnement et crédits.
local function BuildHomeTab(tab)
    Paragraph(tab, "HOME_DESC", 16, -4, WIDTH - 40)
    Paragraph(tab, "HOME_HOW", 16, -96, WIDTH - 40, "GameFontNormalSmall")
    frame.credits = tab:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.credits:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18)
end

-- Onglet Commandes : liste des commandes et informations pour modifier l'addon (open source).
local function BuildDevTab(tab)
    Label(tab, "DEV_COMMANDS", 16, -4, "GameFontNormal")
    frame.devCommands = Paragraph(tab, "", 16, -26, WIDTH - 40, "GameFontNormalSmall")
    Paragraph(tab, "DEV_OPEN", 16, -300, WIDTH - 40, "GameFontHighlightSmall")
end

local function BuildGeneralTab(tab)
    frame.enabled = Check(tab, "UI_ENABLED", 12, -4,
        function() return FSB.db.enabled end, function(v) FSB.db.enabled = v end)
    local function display(name)
        return function() return FSB.db.display[name] ~= false end,
            function(v) FSB.db.display[name] = v end
    end
    frame.icons = Check(tab, "UI_ICONS", 190, -4, display("icons"))
    frame.details = Check(tab, "UI_DETAILS", 290, -4, display("details"))
    frame.status = Label(tab, "", 16, -40, "GameFontHighlightSmall")
    Button(tab, "UI_PICK_ROLE", 130, 16, -66, function() UI.ShowRolePicker(true) end)
    Label(tab, "UI_LANGUAGE", 16, -108, "GameFontNormal")
    frame.langFR = Button(tab, "Français", 110, 16, -128, function() FSB.SetLanguage("frFR") end)
    frame.langEN = Button(tab, "English", 110, 132, -128, function() FSB.SetLanguage("enUS") end)
end

-- Onglet temporaire : poids indicatifs (lecture seule) du profil actif + export de tous les profils.
local function BuildStatsTab(tab)
    Label(tab, "UI_STATS_NOTE", 16, -4)
    Label(tab, "UI_WEIGHTS", 16, -26, "GameFontNormal")
    for i, s in ipairs(FSB.Stats.KEYS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = 16 + col * 210, -48 - row * 20
        local name = Label(tab, FSB.Stats.Label(s.key), x, y)
        name:SetWidth(150); name:SetJustifyH("LEFT")
        if name.SetWordWrap then name:SetWordWrap(false) end -- jamais de débordement sur la colonne voisine
        local value = Label(tab, "", x + 156, y, "GameFontHighlightSmall")
        value:SetWidth(40); value:SetJustifyH("LEFT")
        weightBoxes[#weightBoxes + 1] = { key = s.key, name = name, box = value }
    end
    local bottom = -48 - math.ceil(#FSB.Stats.KEYS / 2) * 20 - 8
    Button(tab, "UI_ALL_PROFILES", 190, 16, bottom, function()
        FSB.Utils.Report(FSB.Profiles.WeightLines(true))
    end)
end

local function Build()
    frame = CreateFrame("Frame", "FSBSettingsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT); frame:SetPoint("CENTER")
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "FSBSettingsFrame") -- se ferme avec Échap

    Label(frame, "UI_TITLE", 16, -14, "GameFontNormalLarge")
    CreateFrame("Button", nil, frame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -4, -4)

    local function NewTab()
        local tab = CreateFrame("Frame", nil, frame)
        tab:SetPoint("TOPLEFT", 0, TOP); tab:SetPoint("BOTTOMRIGHT", 0, 0)
        return tab
    end
    -- Ordre des onglets : Accueil, Stats (temporaire), Commandes, Réglages.
    local defs = {
        { "UI_TAB_HOME", BuildHomeTab },
        { "UI_TAB_STATS", function(tab) frame.statsTab = tab; BuildStatsTab(tab) end, temporary = true },
        { "UI_TAB_DEV", BuildDevTab },
        { "UI_TAB_GENERAL", BuildGeneralTab },
    }
    local tabs, buttons = {}, {}
    local function Show(index)
        for i, t in ipairs(tabs) do
            if i == index then t:Show() else t:Hide() end
            buttons[i]:SetEnabled(i ~= index)
        end
        UI.Refresh()
    end
    for _, def in ipairs(defs) do
        if not def.temporary or UI.SHOW_STATS_TAB then
            local index = #tabs + 1
            local tab = NewTab()
            def[2](tab)
            tabs[index] = tab
            buttons[index] = Button(frame, def[1], 98, 16 + (index - 1) * 104, -38, function() Show(index) end)
        end
    end
    Show(1)
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
        local b = Button(roleFrame, FSB.Profiles.DisplayName(p.name), 220, 30, -50 - i * 28, function()
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
