-- ============================================================
-- BankSplitter - Bank
-- Guild / Warband / Character bank abstraction: slots, tabs, which bank is open, validation.
-- ============================================================

local _, ns = ...

local BAG_BANK_INTERACTIONS = ns.BAG_BANK_INTERACTIONS
local BANK_TAB_BY_BAG = ns.BANK_TAB_BY_BAG
local CHARACTER_BANK_BAGS = ns.CHARACTER_BANK_BAGS
local COLOR = ns.COLOR
local CUSTOM_BANK_ADDONS = ns.CUSTOM_BANK_ADDONS
local GetItemKey = ns.GetItemKey
local L = ns.L
local MODE_NAMES = ns.MODE_NAMES
local S = ns.S
local TAB_ALL = ns.TAB_ALL
local WARBAND_BAGS = ns.WARBAND_BAGS
local usedSlots = ns.usedSlots

--- Display name of a tab selection ("Tab 3" / "all tabs").
local function TabLabel(tab)
    if tab == TAB_ALL then return L.TAB_ALL_NAME end
    return string.format(L.TAB_NAME, tab)
end

local function GetMaxTabs()
    if S.mode == "warband"   then return 5 end
    if S.mode == "character" then return 6 end
    return 8 -- guild
end

--- Returns the bag ID for a tab of the currently selected bag-based bank
--- (Warband or Character). Returns nil for Guild Bank or invalid tabs.
local function GetTabBagID(tab)
    if S.mode == "warband"   then return WARBAND_BAGS[tab] end
    if S.mode == "character" then return CHARACTER_BANK_BAGS[tab] end
    return nil
end

--- Stack count of a guild bank slot (0 if empty).
--- GetGuildBankItemInfo returns texture, itemCount, locked, isFiltered, quality.
local function GetGuildBankStackCount(tab, slot)
    local _, itemCount = GetGuildBankItemInfo(tab, slot)
    return itemCount or 0
end

--- Returns item key (see GetItemKey), count for a bank slot. nil, 0 = empty.
--- Items are identified by itemID (+ item level for gear), not name:
--- crafting quality ranks share a name but have different itemIDs, and only
--- the dragged version may be touched.
--- For Guild Bank, count is checked first (more reliable right after
--- fresh ops), then link as existence check, to avoid false positives
--- caused by server latency.
local function GetBankSlotInfo(tab, slot)
    if S.mode == "guild" then
        local count = GetGuildBankStackCount(tab, slot)
        if count < 1 then return nil, 0 end
        local link = GetGuildBankItemLink(tab, slot)
        if not link then return nil, 0 end
        return (GetItemKey(link)), count
    else
        local bagID = GetTabBagID(tab)
        if not bagID then return nil, 0 end
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.stackCount and info.stackCount > 0 then
            return (GetItemKey(info.hyperlink, info.itemID)), info.stackCount
        end
        return nil, 0
    end
end

--- Returns item key, count for a player bag slot.
local function GetBagSlotInfo(bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    if info and info.stackCount and info.stackCount > 0 then
        return (GetItemKey(info.hyperlink, info.itemID)), info.stackCount
    end
    return nil, 0
end

local function GetBankTabSlotCount(tab)
    if S.mode == "guild" then return 98 end
    local bagID = GetTabBagID(tab)
    return bagID and C_Container.GetContainerNumSlots(bagID) or 0
end

local function IsBankSlotEmpty(tab, slot)
    if S.mode == "guild" then
        return GetGuildBankItemLink(tab, slot) == nil
    end
    local bagID = GetTabBagID(tab)
    if not bagID then return false end
    return C_Container.GetContainerItemLink(bagID, slot) == nil
end

local function IsGuildBankOpen()
    return S.guildBankOpen or (GuildBankFrame ~= nil and GuildBankFrame:IsShown())
end

local function IsTabAccessible(tab)
    if S.mode == "guild" then
        if not IsGuildBankOpen() then return false end
        local n = GetNumGuildBankTabs()
        return n ~= nil and tab <= n
    end
    local bagID = GetTabBagID(tab)
    return bagID ~= nil and C_Container.GetContainerNumSlots(bagID) > 0
end

--- First and last tab index covered by the current tab selection.
--- Callers loop first..last and skip tabs that are not accessible.
local function TabRange()
    if S.targetTab == TAB_ALL then return 1, GetMaxTabs() end
    return S.targetTab, S.targetTab
end

--- True if any tab of the current selection can be used.
local function AnyTabAccessible()
    local first, last = TabRange()
    for tab = first, last do
        if IsTabAccessible(tab) then return true end
    end
    return false
end

--- First bank slot of a tab that is empty and not already claimed this run.
local function FindEmptyBankSlot(tab)
    for slot = 1, GetBankTabSlotCount(tab) do
        if not usedSlots[tab .. ":" .. slot] and IsBankSlotEmpty(tab, slot) then
            return slot
        end
    end
    return nil
end

local function IsCustomBankAddonLoaded()
    for _, name in ipairs(CUSTOM_BANK_ADDONS) do
        if C_AddOns.IsAddOnLoaded(name) then return true end
    end
    return false
end

--- Asks the server for the contents of every guild bank tab. Blizzard's UI
--- only queries the visible tab, but "All tabs" needs data for the others.
local function RequestGuildTabData()
    if not QueryGuildBankTab then return end
    for tab = 1, (GetNumGuildBankTabs() or 0) do QueryGuildBankTab(tab) end
end

--- Detects which bank is currently open/active.
--- Guild Bank has its own dedicated frame (GuildBankFrame).
--- Character Bank and Warband Bank share a single BankFrame with two
--- internal panels; BankFrame:GetActiveBankType() (the same call Blizzard
--- itself uses in ContainerFrameItemButton_OnClick) tells us which panel
--- is currently shown. This is read live on demand, so panel switches
--- inside an already-open BankFrame are caught correctly - unlike
--- PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE, which only fires once for
--- the whole BankFrame and not per internal panel switch.
local function DetectOpenBank()
    if GuildBankFrame and GuildBankFrame:IsShown() then return "guild" end
    if BankFrame and BankFrame:IsShown() and BankFrame.GetActiveBankType then
        local bankType = BankFrame:GetActiveBankType()
        if bankType == Enum.BankType.Character then return "character" end
        if bankType == Enum.BankType.Account   then return "warband" end
    end
    return nil
end

--- Tab selected in Blizzard's BankFrame for a bag-based bank (1..N), or nil
--- if that can't be told (no panel, other bank type, purchase tab). The
--- panel's selected tab ID is the tab's bag ID.
local function GetVisibleBankTab(bankMode)
    local panel = BankFrame and BankFrame.BankPanel
    if not (panel and panel.GetSelectedTabID) then return nil end
    local tabID = panel:GetSelectedTabID()
    local hit = tabID and BANK_TAB_BY_BAG[tabID]
    return hit and hit.mode == bankMode and hit.tab or nil
end

--- Whether the player is talking to a Character / Warband banker.
local function IsBagBankInteractionActive()
    local IsInteracting = C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
    if not IsInteracting then return true end   -- can't tell: don't block
    for _, interaction in ipairs(BAG_BANK_INTERACTIONS) do
        if IsInteracting(interaction) then return true end
    end
    return false
end

--- Checks that the selected bank / tab can be used right now.
--- Returns nil if everything is fine, otherwise the message to show.
local function ValidateBank()
    local detectedBank = DetectOpenBank()
    -- Bank type check
    if detectedBank and detectedBank ~= S.mode then
        return string.format(L.STATUS_WRONG_BANK, MODE_NAMES[detectedBank])
    end
    -- Without a banker the bank tab bags are not usable; a pickup there
    -- would only leave the item on the cursor.
    if S.mode ~= "guild" and not detectedBank and not IsBagBankInteractionActive() then
        return L.STATUS_NO_BANK_OPEN
    end
    -- Visible-tab check: only meaningful for one specific tab shown in
    -- Blizzard's own bank UI (not for "All" or a bank replacement addon)
    if S.targetTab == TAB_ALL or IsCustomBankAddonLoaded() then
        -- nothing to compare against
    elseif S.mode == "guild" then
        local visibleTab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or nil
        if visibleTab and visibleTab ~= S.targetTab then
            return string.format(L.STATUS_WRONG_TAB, S.targetTab)
        end
    else
        -- In "bags" sourceMode the visible tab is irrelevant, since the
        -- bank is only a write target there. In "bank" and "withdraw"
        -- sourceMode we read from the bank, so the visible tab must
        -- match targetTab.
        if S.sourceMode ~= "bags" then
            local visibleTab = GetVisibleBankTab(S.mode)
            if visibleTab and visibleTab ~= S.targetTab then
                return string.format(L.STATUS_WRONG_TAB, S.targetTab)
            end
        end
    end
    -- Tab accessibility
    if not AnyTabAccessible() then
        return S.targetTab == TAB_ALL and L.STATUS_NO_TAB_ACCESS
            or string.format(L.STATUS_TAB_LOCKED, S.targetTab)
    end
    return nil
end

--- ValidateBank() for a button click: shows the problem in the footer.
local function CheckAndValidate()
    local problem = ValidateBank()
    if problem then ns.SetStatus(problem, COLOR.ERROR) end
    return problem == nil
end

-- Exports
ns.CheckAndValidate = CheckAndValidate
ns.DetectOpenBank = DetectOpenBank
ns.FindEmptyBankSlot = FindEmptyBankSlot
ns.GetBagSlotInfo = GetBagSlotInfo
ns.GetBankSlotInfo = GetBankSlotInfo
ns.GetBankTabSlotCount = GetBankTabSlotCount
ns.GetMaxTabs = GetMaxTabs
ns.GetTabBagID = GetTabBagID
ns.IsBankSlotEmpty = IsBankSlotEmpty
ns.IsTabAccessible = IsTabAccessible
ns.RequestGuildTabData = RequestGuildTabData
ns.TabLabel = TabLabel
ns.TabRange = TabRange
ns.ValidateBank = ValidateBank
