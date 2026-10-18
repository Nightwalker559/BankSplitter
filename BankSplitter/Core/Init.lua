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

SLASH_BANKSPLITTER1 = "/banksplitter"
SLASH_BANKSPLITTER2 = "/gbs"   -- the old name of the addon
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
        ApplySavedState()
        local ok, err = pcall(RegisterSettings)
        if not ok then
            print("|cff00ccff[BankSplitter]|r |cffff8800settings panel error: " .. tostring(err) .. "|r")
        end
        return
    end

    -- PLAYER_ENTERING_WORLD
    if Opt("greeting") then
        print("|cff00ccff[BankSplitter]|r " .. L.CHAT_LOADED)
    end
    -- ElvUI skin is applied from ElvUI_Skin.lua if present
    if ns.ApplyElvUISkin then
        -- ElvUI is fully initialized by PLAYER_ENTERING_WORLD and the skin
        -- only touches our own frames, so no fixed wait is needed.
        RunNextFrame(ns.ApplyElvUISkin)
    end
    self:UnregisterAllEvents()
end)
