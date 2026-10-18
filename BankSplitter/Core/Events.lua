-- ============================================================
-- BankSplitter - Events
-- Bank interactions: opens / closes the window with a bank, follows the bank and tab
-- shown by Blizzard's or Baganator's window, keeps the preview current.
-- ============================================================

local _, ns = ...

local BANK_INTERACTIONS = ns.BANK_INTERACTIONS
local BANK_TAB_BY_BAG = ns.BANK_TAB_BY_BAG
local COLOR = ns.COLOR
local DetectOpenBank = ns.DetectOpenBank
local GetVisibleTab = ns.GetVisibleTab
local HookBaganator = ns.HookBaganator
local IsBaganatorActive = ns.IsBaganatorActive
local IsCustomBankAddonLoaded = ns.IsCustomBankAddonLoaded
local L = ns.L
local OPEN_SETTING = ns.OPEN_SETTING
local Opt = ns.Opt
local RequestPreview = ns.RequestPreview
local S = ns.S
local SetMode = ns.SetMode
local SetTab = ns.SetTab
local StopRunning = ns.StopRunning
local TAB_ALL = ns.TAB_ALL
local UI = ns.UI
local UpdateModeUI = ns.UpdateModeUI

-- One bank visit = from the first bank interaction opening until it closes.
-- It remembers whether the window was opened automatically (it is closed again
-- with the bank) and whether the user closed it by hand (it stays closed).
local visit = nil   -- { applied = { [bank] = true }, autoShown = bool, dismissed = bool }
local autoClosing = false

--- Called when a bank is (or becomes) the active one in the current visit:
--- the bank selection follows it, and the window opens (on the tab used last) once per bank and visit.
local function ApplyAutoOpen(bank)
    if not visit then return end
    if Opt("followBank") and bank ~= S.mode then SetMode(bank) end
    if visit.applied[bank] then return end
    visit.applied[bank] = true
    if not Opt(OPEN_SETTING[bank]) or visit.dismissed or UI.frame:IsShown() then return end
    visit.autoShown = true
    UI.frame:Show()
end

local function EndVisit()
    if not visit then return end
    if Opt("autoClose") and visit.autoShown and UI.frame:IsShown() then
        autoClosing = true
        UI.frame:Hide()
        autoClosing = false
    end
    visit = nil
end

-- A window the user closes during a visit is not opened again by that visit
UI.frame:HookScript("OnHide", function()
    if visit and not autoClosing then visit.dismissed = true end
end)

--- Bank type of a bank interaction once the bank windows have reacted to it.
local function BankOfInteraction(interaction)
    if interaction == Enum.PlayerInteractionType.GuildBanker then return "guild" end
    return DetectOpenBank()
        or (interaction == Enum.PlayerInteractionType.CharacterBanker and "character")
        or (interaction == Enum.PlayerInteractionType.AccountBanker and "warband")
        or nil
end

--- The tab chosen in the bank window (Blizzard's or Baganator's) becomes the addon's tab
--- ("tab 7 open" -> chip 7; Baganator's all-tabs view -> "All").
--- Only for the bank the addon has selected, and never mid-run.
local function FollowBankTab(bank, tab)
    if S.isRunning or type(tab) ~= "number" or bank ~= S.mode or tab == S.targetTab then return end
    if tab < 1 and not (tab == TAB_ALL and IsCustomBankAddonLoaded()) then return end
    UpdateModeUI()    -- the chip for this tab must exist (the tab count may have just changed)
    SetTab(tab)
end

--- Baganator showed a bank or switched its tab / bank type.
local function OnBaganatorChanged(bank, tab)
    ApplyAutoOpen(bank)
    FollowBankTab(bank, tab)
end

-- Blizzard's BankFrame: switching between the Bank and Warband panel, selecting a tab
local function HookBankPanel()
    local panel = BankFrame and BankFrame.BankPanel
    if not (panel and panel.SetBankType) then return end
    if panel.SelectTab then
        -- a click, or the panel picking a tab when it opens
        hooksecurefunc(panel, "SelectTab", function(_, tabID)
            if IsBaganatorActive() then return end   -- Blizzard's panel is hidden behind Baganator's window
            local hit = tabID and BANK_TAB_BY_BAG[tabID]
            if hit then FollowBankTab(hit.mode, hit.tab) end
        end)
    end
    hooksecurefunc(panel, "SetBankType", function(_, bankType)
        local bank = (bankType == Enum.BankType.Account and "warband")
            or (bankType == Enum.BankType.Character and "character") or nil
        if bank then ApplyAutoOpen(bank) end
    end)
end
HookBankPanel()

-- A guild bank tab was clicked in Blizzard's guild bank (Blizzard's tab button calls this)
if SetCurrentGuildBankTab then
    hooksecurefunc("SetCurrentGuildBankTab", function(tab)
        if IsBaganatorActive() then return end   -- Baganator reports its own tab (including "all")
        if DetectOpenBank() == "guild" then FollowBankTab("guild", tab) end
    end)
end

-- Tracks the bank interactions: opens / closes the window together with a bank,
-- ends a run when a bank closes, and keeps the preview and the tab chips current.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")           -- bag / bank contents changed: refresh the live preview
eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")            -- a bank tab was bought: the tab chips follow
eventFrame:RegisterEvent("GUILDBANK_UPDATE_TABS")        -- guild bank tab list arrived / changed
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "BAG_UPDATE_DELAYED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
        RequestPreview()
        return
    end
    if event == "BANK_TABS_CHANGED" or event == "GUILDBANK_UPDATE_TABS" then
        UpdateModeUI()
        RequestPreview()
        return
    end

    local isShow = (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    -- Tracked separately from GuildBankFrame so bank replacement addons
    -- that hide Blizzard's frame still count as "guild bank open".
    if arg1 == Enum.PlayerInteractionType.GuildBanker then
        S.guildBankOpen = isShow
    end
    if not BANK_INTERACTIONS[arg1] then return end

    if isShow then
        visit = visit or { applied = {}, autoShown = false, dismissed = false }
        HookBaganator(OnBaganatorChanged)   -- does nothing without Baganator; hooks its views once
        -- The bank windows are set up after this event: look one frame later
        RunNextFrame(function()
            local bank = BankOfInteraction(arg1)
            if bank then ApplyAutoOpen(bank) end
            UpdateModeUI()   -- the bank is open now: show only the tabs it has
            if bank then FollowBankTab(bank, GetVisibleTab(bank)) end   -- and start on the tab it shows
        end)
    else
        -- Closing the bank mid-run would leave items on the cursor
        if S.isRunning then StopRunning(L.STATUS_BANK_CLOSED, COLOR.ERROR) end
        EndVisit()
    end
end)
