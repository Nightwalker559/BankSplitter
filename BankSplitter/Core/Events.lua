-- ============================================================
-- BankSplitter - Events
-- Bank interactions: opens / closes the window with a bank, keeps the preview current.
-- ============================================================

local _, ns = ...

local BANK_INTERACTIONS = ns.BANK_INTERACTIONS
local COLOR = ns.COLOR
local DetectOpenBank = ns.DetectOpenBank
local L = ns.L
local Opt = ns.Opt
local RequestPreview = ns.RequestPreview
local S = ns.S
local SetMode = ns.SetMode
local StopRunning = ns.StopRunning
local UI = ns.UI

-- One bank visit = from the first bank interaction opening until it closes.
-- It remembers whether the window was opened automatically (it is closed again
-- with the bank) and whether the user closed it by hand (it stays closed).
local visit = nil   -- { applied = { [bank] = true }, autoShown = bool, dismissed = bool }
local autoClosing = false

local OPEN_SETTING = { guild = "openGuild", warband = "openWarband", character = "openCharacter" }

--- Called when a bank is (or becomes) the active one in the current visit:
--- the bank selection follows it, and the window opens (on the tab used last) once per bank and visit.
local function ApplyAutoOpen(bank)
    if not visit then return end
    if Opt("followBank") and bank ~= S.mode then SetMode(bank, true) end
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

--- Bank type of a bank interaction once Blizzard's windows have reacted to it.
local function BankOfInteraction(interaction)
    if interaction == Enum.PlayerInteractionType.GuildBanker then return "guild" end
    return DetectOpenBank()
        or (interaction == Enum.PlayerInteractionType.CharacterBanker and "character")
        or (interaction == Enum.PlayerInteractionType.AccountBanker and "warband")
        or nil
end

-- Switching between the Bank and Warband tab inside Blizzard's BankFrame
local function HookBankPanel()
    local panel = BankFrame and BankFrame.BankPanel
    if not (panel and panel.SetBankType) then return end
    hooksecurefunc(panel, "SetBankType", function(_, bankType)
        local bank = (bankType == Enum.BankType.Account and "warband")
            or (bankType == Enum.BankType.Character and "character") or nil
        if bank then ApplyAutoOpen(bank) end
    end)
end
HookBankPanel()

-- Tracks the guild banker interaction, opens / closes the window together with
-- a bank, and ends a run when a bank closes.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")           -- bag / bank contents changed: refresh the live preview
eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "BAG_UPDATE_DELAYED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
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
        -- The bank panel is set up after this event: look one frame later
        RunNextFrame(function()
            local bank = BankOfInteraction(arg1)
            if bank then ApplyAutoOpen(bank) end
        end)
    else
        -- Closing the bank mid-run would leave items on the cursor
        if S.isRunning then StopRunning(L.STATUS_BANK_CLOSED, COLOR.ERROR) end
        EndVisit()
    end
end)
