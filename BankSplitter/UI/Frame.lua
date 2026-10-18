-- ============================================================
-- BankSplitter - Window
-- Main window: selector bar (bank, source, tab), footer, tabs and the tab pages' shared state.
-- ============================================================

local _, ns = ...

local UI = ns.UI

local COLOR = ns.COLOR
local CreateFlatButton = ns.CreateFlatButton
local CreatePanel = ns.CreatePanel
local DIV = ns.DIV
local FS = ns.FS
local H = ns.H
local INSET_BOTTOM = ns.INSET_BOTTOM
local L = ns.L
local MODE_NAMES = ns.MODE_NAMES
local MODE_ORDER = ns.MODE_ORDER
local MakeMovable = ns.MakeMovable
local PAGE_TOP = ns.PAGE_TOP
local PL = ns.PL
local PR = ns.PR
local S = ns.S
local SOURCE_NAMES = ns.SOURCE_NAMES
local TAB_ALL = ns.TAB_ALL
local W = ns.W
local SetTab, UpdateModeUI, SetMode, SetSource, SelectTab   -- forward declarations: they call each other

local frame = CreatePanel("BankSplitterFrame", UIParent, "BankSplitter")
frame:SetSize(W, H)
frame:SetPoint("CENTER")
MakeMovable(frame, "main")
frame:Hide()
tinsert(UISpecialFrames, "BankSplitterFrame")

-- The two tab pages share the area below the selector bar
local splitPage    = CreateFrame("Frame", nil, frame)
local transferPage = CreateFrame("Frame", nil, frame)
for _, page in ipairs({ splitPage, transferPage }) do
    page:SetPoint("TOPLEFT",     frame, "TOPLEFT",      0, PAGE_TOP)
    page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  0, INSET_BOTTOM)
end
transferPage:Hide()

-- Title-bar link to the Settings panel (plain text: the bar is only ~20 px high)
local configBtn = CreateFrame("Button", nil, frame)
configBtn:SetSize(64, 16)
configBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -5)
configBtn:SetFrameLevel(510)   -- above the panel border (500), like Blizzard's close button (510)
configBtn:SetNormalFontObject("GameFontNormalSmall")
configBtn:SetHighlightFontObject("GameFontHighlightSmall")
configBtn:SetText(L.BTN_CONFIG)
configBtn:SetScript("OnClick", function() ns.OpenSettings() end)

FS(frame, "GameFontNormalSmall", PL + 8, -30, L.LABEL_BANK)
FS(frame, "GameFontNormalSmall", W - PL - 160 + 8, -30, L.LABEL_SOURCE)

local modeDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
modeDropdown:SetWidth(144)
modeDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", PL + 8, -44)
modeDropdown:SetupMenu(function(_, root)
    for _, key in ipairs(MODE_ORDER) do
        root:CreateRadio(MODE_NAMES[key], function() return S.mode == key end, function() SetMode(key) end, key)
    end
end)

local sourceDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
sourceDropdown:SetWidth(144)
sourceDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", W - PL - 160 + 8, -44)
sourceDropdown:SetupMenu(function(_, root)
    -- the transfer list never splits, so "Bank -> Bank" only exists on the split tab
    local keys = (S.activeTab == "transfer") and { "bags", "withdraw" } or { "bank", "bags", "withdraw" }
    for _, key in ipairs(keys) do
        root:CreateRadio(SOURCE_NAMES[key], function() return S.sourceMode == key end, function() SetSource(key) end, key)
    end
end)

-- Tab chips: index 0 = "All", then the numbered tabs
FS(frame, "GameFontNormalSmall", PL, -86, L.LABEL_TAB)
local allTabBtn = CreateFlatButton(frame, 34, 22, L.BTN_ALL_TABS)
allTabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PL + 32, -82)
local tabButtons = { [TAB_ALL] = allTabBtn }   -- ipairs() only walks the numbered tabs
for i = 1, 8 do
    tabButtons[i] = CreateFlatButton(frame, 28, 22, tostring(i))
end

DIV(frame, -106)

local function UpdateTabButtons()
    local tabCount = ns.GetUsableTabCount()   -- only the tabs the player has, not every possible one
    -- Blizzard's own bank has no "all tabs" view; only a bank replacement addon does
    local showAll = ns.IsCustomBankAddonLoaded()
    allTabBtn:SetShown(showAll)
    local x = PL + 32 + (showAll and 38 or 0)
    for i, btn in ipairs(tabButtons) do
        btn:SetShown(i <= tabCount)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x + (i - 1) * 32, -82)
    end
    if S.targetTab > tabCount or (S.targetTab == TAB_ALL and not showAll) then S.targetTab = 1 end
end

local function HighlightTab(index)
    for key, btn in pairs(tabButtons) do btn:SetSelected(key == index) end
end

--- Selects a tab (1..N or TAB_ALL). Ignored mid-run.
SetTab = function(index)
    if S.isRunning then return end
    S.targetTab = index
    HighlightTab(index)
    ns.RequestPreview()
    ns.SaveLast()
end

for index, btn in pairs(tabButtons) do
    btn:SetScript("OnClick", function() SetTab(index) end)
end
HighlightTab(1)

-- Footer: status line on the left, one action button on the right
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PL, 6)
statusText:SetHeight(INSET_BOTTOM - 12)
statusText:SetJustifyH("LEFT")
statusText:SetJustifyV("MIDDLE")
statusText:SetWordWrap(true)
statusText:SetText(L.STATUS_READY)

local actionBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
actionBtn:SetSize(112, 24)
actionBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", PR, 13)
actionBtn:SetText(L.BTN_SPLIT)
statusText:SetWidth(W - 2 * PL - 120)

--- Shows a message in the footer.
local function SetStatus(msg, color)
    statusText:SetText("|cff" .. (color or COLOR.TEXT) .. msg .. "|r")
end

--- The one action button reads "Split!" / "Transfer!" and turns into "Stop" during a run.
local function UpdateActionButton()
    actionBtn:SetText(S.isRunning and L.BTN_STOP or (S.activeTab == "transfer" and L.BTN_TRANSFER or L.BTN_SPLIT))
end

local function SetRunningUI(running)
    UpdateActionButton()
    modeDropdown:SetEnabled(not running)
    sourceDropdown:SetEnabled(not running)
end

--- Re-reads the bank selection into the controls (tab chips, dropdowns).
UpdateModeUI = function()
    UpdateTabButtons()
    HighlightTab(S.targetTab)
    modeDropdown:GenerateMenu()      -- re-reads the selection (text) and, for the source, the page's choices
    sourceDropdown:GenerateMenu()
end

-- Changing the bank or source mid-run would redirect the running operation: ignored while running.
SetMode = function(key)
    if S.isRunning or not MODE_NAMES[key] then return end
    S.mode = key; S.targetTab = 1; UpdateModeUI()
    ns.RequestPreview()
    ns.SaveLast()
end

SetSource = function(key)
    if S.isRunning or not SOURCE_NAMES[key] then return end
    if S.activeTab == "transfer" and key == "bank" then return end   -- the list never splits
    S.sourceMode = key; UpdateModeUI()
    ns.RequestPreview()
    ns.SaveLast()
end

-- Tabs below the window (Blizzard's TabSystem, like the bank window): "Split" and "Transfer list"
local TAB_IDS = {}
frame.TabSystem = CreateFrame("Frame", nil, frame, "TabSystemTemplate")
frame.TabSystem.minTabWidth = 100
frame.TabSystem.maxTabWidth = 150
frame.TabSystem:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 22, 2)
frame:SetTabSystem(frame.TabSystem)
TAB_IDS.split    = frame:AddNamedTab(L.TAB_SPLIT,    splitPage)
TAB_IDS.transfer = frame:AddNamedTab(L.TAB_TRANSFER, transferPage)

--- Switches the window to the "split" or "transfer" page.
SelectTab = function(which)
    if (which ~= "split" and which ~= "transfer") or S.isRunning then return end
    S.activeTab = which
    if which == "transfer" and S.sourceMode == "bank" then S.sourceMode = "bags" end
    splitPage:SetShown(which == "split")
    transferPage:SetShown(which == "transfer")
    frame:SetTab(TAB_IDS[which])     -- tab buttons (and, redundantly, the pages)
    UpdateActionButton()
    UpdateModeUI()
    ns.RequestPreview()
    ns.SaveLast()
end

-- A click on a tab button comes in through the callbacks
for which, id in pairs(TAB_IDS) do
    frame:SetTabCallback(id, function()
        if S.activeTab == which then return end
        if S.isRunning then frame:SetTab(TAB_IDS[S.activeTab]) return end   -- not while a run is active
        SelectTab(which)
    end)
end

UpdateModeUI()
UpdateActionButton()

-- One button: starts the page's run, or stops the running one
actionBtn:SetScript("OnClick", function()
    if S.isRunning then ns.AbortRun()
    elseif S.activeTab == "transfer" then ns.StartTransfer()
    else ns.StartSplit() end
end)

-- Exports
ns.SelectTab = SelectTab
ns.SetMode = SetMode
ns.SetRunningUI = SetRunningUI
ns.SetStatus = SetStatus
ns.SetTab = SetTab
ns.UpdateModeUI = UpdateModeUI
UI.actionBtn = actionBtn
UI.frame = frame
UI.modeDropdown = modeDropdown
UI.sourceDropdown = sourceDropdown
UI.splitPage = splitPage
UI.statusText = statusText
UI.transferPage = transferPage
