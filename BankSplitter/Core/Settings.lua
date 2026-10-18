-- ============================================================
-- BankSplitter - Settings
-- Saved variables, remembered selection, window position / scale and the Settings panel.
-- ============================================================

local _, ns = ...

local COLOR = ns.COLOR
local DEFAULTS = ns.DEFAULTS
local GetMaxTabs = ns.GetMaxTabs
local L = ns.L
local MODE_NAMES = ns.MODE_NAMES
local OPEN_SETTING = ns.OPEN_SETTING
local Opt = ns.Opt
local RequestPreview = ns.RequestPreview
local S = ns.S
local SOURCE_NAMES = ns.SOURCE_NAMES
local SelectTab = ns.SelectTab
local SetStatus = ns.SetStatus
local UpdateModeUI = ns.UpdateModeUI
local UI = ns.UI

-- ============================================================
-- Remembered selection, window position and scale
-- ============================================================

--- Stores bank / source / tab / stack values (option "remember").
local function SaveLast()
    if not Opt("remember") then return end
    BankSplitterDB = BankSplitterDB or {}
    BankSplitterDB.last = {
        mode = S.mode, sourceMode = S.sourceMode, targetTab = S.targetTab, tab = S.activeTab,
        stackSize = S.stackSize, stackCount = S.stackCount,
    }
end

local function RestoreLast()
    local last = BankSplitterDB and BankSplitterDB.last
    if not (Opt("remember") and type(last) == "table") then return end
    if MODE_NAMES[last.mode]          then S.mode = last.mode end
    if SOURCE_NAMES[last.sourceMode]  then S.sourceMode = last.sourceMode end
    local tab = tonumber(last.targetTab)
    if tab and tab >= 0 and tab <= GetMaxTabs() then S.targetTab = math.floor(tab) end
    S.stackSize  = math.max(1, math.floor(tonumber(last.stackSize)  or 1))
    S.stackCount = math.max(0, math.floor(tonumber(last.stackCount) or 0))
    UI.stackEdit:SetText(tostring(S.stackSize))
    UI.countEdit:SetText(tostring(S.stackCount))
    UpdateModeUI()
    SelectTab(last.tab == "transfer" and "transfer" or "split")
end

local function RestorePosition()
    local p = BankSplitterDB and BankSplitterDB.pos and BankSplitterDB.pos.main
    if type(p) == "table" and p[1] then
        UI.frame:ClearAllPoints()
        UI.frame:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
    end
end

--- Applies the window scale option (the value is passed while the slider moves).
local function ApplyScale(value)
    UI.frame:SetScale(math.min(1.3, math.max(0.7, tonumber(value) or tonumber(Opt("scale")) or 1)))
end

UI.frame:HookScript("OnHide", SaveLast)
UI.frame:HookScript("OnShow", RequestPreview)

--- Called once the saved variables are loaded (ADDON_LOADED, see Init.lua).
local function ApplySavedState()
    RestoreLast()
    RestorePosition()
    ApplyScale()
end

local settingsCategory

--- Fills in missing / invalid saved values.
local function InitDB()
    BankSplitterDB = BankSplitterDB or {}
    local db = BankSplitterDB
    db.settings = type(db.settings) == "table" and db.settings or {}
    db.pos      = type(db.pos) == "table" and db.pos or {}
    -- earlier builds stored which window / tab to open with a bank ("none", "main", ...)
    for _, key in pairs(OPEN_SETTING) do
        if type(db.settings[key]) == "string" then db.settings[key] = (db.settings[key] ~= "none") end
    end
    for key, default in pairs(DEFAULTS) do
        if type(db.settings[key]) ~= type(default) then db.settings[key] = default end
    end
end

--- Registers the options in Blizzard's Settings panel (AddOns > BankSplitter).
local function RegisterSettings()
    local s = BankSplitterDB.settings
    local category = Settings.RegisterVerticalLayoutCategory("BankSplitter")

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(category, "BANKSPLITTER_" .. key:upper(), key, s,
            Settings.VarType.Boolean, label, DEFAULTS[key])
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    Checkbox("openGuild",     L.OPT_OPEN_GUILD,     L.OPT_OPEN_TIP)
    Checkbox("openWarband",   L.OPT_OPEN_WARBAND,   L.OPT_OPEN_TIP)
    Checkbox("openCharacter", L.OPT_OPEN_CHARACTER, L.OPT_OPEN_TIP)
    Checkbox("followBank", L.OPT_FOLLOW_BANK, L.OPT_FOLLOW_BANK_TIP)
    Checkbox("autoClose",  L.OPT_AUTO_CLOSE,  L.OPT_AUTO_CLOSE_TIP)
    Checkbox("remember",   L.OPT_REMEMBER,    L.OPT_REMEMBER_TIP)

    local scaleSetting = Settings.RegisterAddOnSetting(category, "BANKSPLITTER_SCALE", "scale", s,
        Settings.VarType.Number, L.OPT_SCALE, DEFAULTS.scale)
    scaleSetting:SetValueChangedCallback(function(_, value) ApplyScale(value) end)
    local scaleOptions = Settings.CreateSliderOptions(0.7, 1.3, 0.05)
    scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
    Settings.CreateSlider(category, scaleSetting, scaleOptions, L.OPT_SCALE_TIP)

    Checkbox("greeting",  L.OPT_GREETING,  L.OPT_GREETING_TIP)

    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

local function OpenSettings()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    else
        SetStatus(L.STATUS_NO_SETTINGS, COLOR.WARN)
    end
end

-- Exports
ns.ApplySavedState = ApplySavedState
ns.InitDB = InitDB
ns.OpenSettings = OpenSettings
ns.RegisterSettings = RegisterSettings
ns.SaveLast = SaveLast
