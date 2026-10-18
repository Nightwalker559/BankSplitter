-- ============================================================
-- BankSplitter - Init
-- Slash commands and login.
-- ============================================================

local ADDON, ns = ...

local ApplySavedState = ns.ApplySavedState
local COLOR = ns.COLOR
local InitDB = ns.InitDB
local L = ns.L
local OpenSettings = ns.OpenSettings
local Opt = ns.Opt
local RegisterSettings = ns.RegisterSettings
local S = ns.S
local SelectTab = ns.SelectTab
local SetStatus = ns.SetStatus
local UI = ns.UI

-- /banksplitter [list | config | bank]   (/gbs is the addon's old name, kept as an alias)
SLASH_BANKSPLITTER1 = "/banksplitter"
SLASH_BANKSPLITTER2 = "/gbs"
SlashCmdList["BANKSPLITTER"] = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "list" then
        -- toggles the window on the transfer page
        if UI.frame:IsShown() and S.activeTab == "transfer" then
            UI.frame:Hide()
        else
            UI.frame:Show()
            SelectTab("transfer")
        end
    elseif cmd == "config" or cmd == "options" then
        OpenSettings()
    elseif cmd == "bank" then
        -- diagnostic: which bank / tab does the addon see as open right now?
        local bank = ns.DetectOpenBank()
        local tab = bank and ns.GetVisibleTab(bank)
        print(string.format("|cff00ccff[BankSplitter]|r open bank: %s, visible tab: %s (0 = all), Baganator: %s, selected in addon: %s / tab %s",
            bank or "none", tostring(tab), tostring(ns.IsBaganatorActive()), S.mode, tostring(S.targetTab)))
    elseif UI.frame:IsShown() then
        UI.frame:Hide()
    else
        UI.frame:Show()
        SetStatus(L.STATUS_MANUAL_OPEN, COLOR.INFO)
    end
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        -- Saved variables exist from here on
        InitDB()
        local ok, err = pcall(RegisterSettings)
        if not ok then
            print("|cff00ccff[BankSplitter]|r |cffff8800settings panel error: " .. tostring(err) .. "|r")
        end
        return
    end

    -- PLAYER_ENTERING_WORLD: every addon is loaded now, so a bank replacement addon that
    -- loads after this one is known when the remembered tab ("All") is restored.
    ApplySavedState()
    if Opt("greeting") then
        print("|cff00ccff[BankSplitter]|r " .. L.CHAT_LOADED)
    end
    -- ElvUI is fully initialized by PLAYER_ENTERING_WORLD and the skin only
    -- touches our own frames, so no fixed wait is needed.
    RunNextFrame(ns.ApplyElvUISkin)
    self:UnregisterAllEvents()
end)
