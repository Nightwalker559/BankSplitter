-- ============================================================
-- BankSplitter - Baganator
-- Baganator replaces Blizzard's bank and guild bank windows, so which bank / tab
-- is open has to be read from Baganator's own views. Its tab 0 is the
-- merged "all tabs" view, the same meaning as TAB_ALL here.
-- ============================================================

local _, ns = ...

local bankViews, guildViews = {}, {}
local seen, hooked = {}, {}

--- Finds Baganator's bank / guild views. Their global names end in the name of
--- the active skin ("Baganator_SingleViewBankViewFrame<skin>"), so they are looked
--- up by prefix, and again whenever a bank opens (a skin change creates new ones).
local function ScanViews()
    for name, obj in pairs(_G) do
        if type(name) == "string" and not seen[name] and name:sub(1, 10) == "Baganator_" and type(obj) == "table" then
            if name:find("^Baganator_%a+ViewBankViewFrame") then
                seen[name] = true
                bankViews[#bankViews + 1] = obj
            elseif name:find("^Baganator_%a+ViewGuildViewFrame") then
                seen[name] = true
                guildViews[#guildViews + 1] = obj
            end
        end
    end
end

--- True once Baganator's bank views exist: Blizzard's bank frames are not what the player sees then.
local function IsBaganatorActive()
    return #bankViews > 0
end

--- The bank Baganator shows right now and its tab: "guild" / "warband" / "character", tab (0 = all tabs).
--- nil when no live bank is shown (closed, or a cached bank of another character).
local function GetBaganatorBank()
    for _, view in ipairs(bankViews) do
        local sub = view:IsShown() and view.currentTab
        if type(sub) == "table" and sub.isLive then
            local bank = (sub.bankType == Enum.BankType.Account and "warband")
                or (sub.bankType == Enum.BankType.Character and "character") or nil
            if bank and type(sub.currentTab) == "number" then return bank, sub.currentTab end
        end
    end
    for _, view in ipairs(guildViews) do
        if view:IsShown() and view.isLive and type(view.currentTab) == "number" then
            return "guild", view.currentTab
        end
    end
    return nil
end

--- Calls onChange(bank, tab) whenever Baganator shows a bank or switches its tab.
--- Safe to call repeatedly: every view is hooked once.
local function HookBaganator(onChange)
    if not C_AddOns.IsAddOnLoaded("Baganator") then return end
    ScanViews()

    local function Notify()
        local bank, tab = GetBaganatorBank()
        if bank then onChange(bank, tab) end
    end
    local function HookMethod(obj, method)
        local key = tostring(obj) .. method
        if hooked[key] or type(obj[method]) ~= "function" then return end
        hooked[key] = true
        hooksecurefunc(obj, method, Notify)
    end

    for _, view in ipairs(bankViews) do
        if not hooked[view] then
            hooked[view] = true
            -- the view fills in isLive / currentTab while it opens: look one frame later
            view:HookScript("OnShow", function() RunNextFrame(Notify) end)
            HookMethod(view, "SetTab")                 -- Character <-> Warband
            if view.Character then HookMethod(view.Character, "SetCurrentTab") end
            if view.Warband   then HookMethod(view.Warband,   "SetCurrentTab") end
        end
    end
    for _, view in ipairs(guildViews) do
        if not hooked[view] then
            hooked[view] = true
            view:HookScript("OnShow", function() RunNextFrame(Notify) end)
            HookMethod(view, "SetCurrentTab")
        end
    end
end

-- Exports
ns.GetBaganatorBank = GetBaganatorBank
ns.HookBaganator = HookBaganator
ns.IsBaganatorActive = IsBaganatorActive
