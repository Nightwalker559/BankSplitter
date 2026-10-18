-- ============================================================
-- BankSplitter - Split page
-- Item slot, stack count / size, live preview and starting a split run.
-- ============================================================

local _, ns = ...

local BTN = ns.BTN
local BagSlots = ns.BagSlots
local BankSlots = ns.BankSlots
local COLOR = ns.COLOR
local CheckAndValidate = ns.CheckAndValidate
local FS = ns.FS
local GetBagSlotInfo = ns.GetBagSlotInfo
local GetBankSlotInfo = ns.GetBankSlotInfo
local GetBankTabSlotCount = ns.GetBankTabSlotCount
local GetItemKey = ns.GetItemKey
local IsBankSlotEmpty = ns.IsBankSlotEmpty
local IsTabAccessible = ns.IsTabAccessible
local L = ns.L
local PL = ns.PL
local PR = ns.PR
local S = ns.S
local SetStatus = ns.SetStatus
local TabRange = ns.TabRange
local ValidateBank = ns.ValidateBank
local WHITE = ns.WHITE
local UI = ns.UI
local RequestPreview   -- forward declaration: assigned below, used by the handlers above it

local itemSlot = CreateFrame("Button", "BankSplitterItemSlot", UI.splitPage)
itemSlot:SetSize(40, 40)
itemSlot:SetPoint("TOPLEFT", UI.splitPage, "TOPLEFT", PL, -6)

do
    local bg = itemSlot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
end

local itemIcon = itemSlot:CreateTexture(nil, "ARTWORK")
itemIcon:SetPoint("TOPLEFT",     itemSlot, "TOPLEFT",     2, -2)
itemIcon:SetPoint("BOTTOMRIGHT", itemSlot, "BOTTOMRIGHT", -2, 2)
itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
itemIcon:Hide()

do
    local b = itemSlot:CreateTexture(nil, "OVERLAY")
    b:SetAllPoints()
    b:SetTexture("Interface\\Buttons\\UI-Slot-Background")
    b:SetTexCoord(0, 0.640625, 0, 0.640625)
    b:SetAlpha(0.4)
end

local itemSlotBorderFrame = CreateFrame("Frame", nil, UI.splitPage, "BackdropTemplate")
itemSlotBorderFrame:SetPoint("TOPLEFT",     itemSlot, "TOPLEFT",     -2,  2)
itemSlotBorderFrame:SetPoint("BOTTOMRIGHT", itemSlot, "BOTTOMRIGHT",  2, -2)
itemSlotBorderFrame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
itemSlotBorderFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
itemSlotBorderFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

local itemNameText = UI.splitPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
itemNameText:SetPoint("TOPLEFT",  UI.splitPage, "TOPLEFT",  PL + 50, -6)
itemNameText:SetPoint("TOPRIGHT", UI.splitPage, "TOPRIGHT", PR,      -6)
itemNameText:SetHeight(40)
itemNameText:SetJustifyH("LEFT")
itemNameText:SetJustifyV("MIDDLE")
itemNameText:SetWordWrap(true)
itemNameText:SetText(L.ITEM_EMPTY)

-- Stack count / size
FS(UI.splitPage, "GameFontNormal", PL, -64, L.LABEL_STACK_COUNT)
local countMinusBtn = BTN(UI.splitPage, PL + 64, -60, 28, 24, "-")
local countEdit = CreateFrame("EditBox", "BankSplitterCountEdit", UI.splitPage, "InputBoxTemplate")
countEdit:SetSize(36, 20)
countEdit:SetPoint("TOPLEFT", UI.splitPage, "TOPLEFT", PL + 102, -62)
countEdit:SetAutoFocus(false)
countEdit:SetNumeric(true)
countEdit:SetMaxLetters(3)
countEdit:SetText("0")
countEdit:SetJustifyH("CENTER")
local countPlusBtn = BTN(UI.splitPage, PL + 144, -60, 28, 24, "+")
FS(UI.splitPage, "GameFontNormalSmall", PL + 180, -66, L.LABEL_STACKS_HINT)

FS(UI.splitPage, "GameFontNormal", PL, -94, L.LABEL_STACK_SIZE)
local stackMinusBtn = BTN(UI.splitPage, PL + 64, -90, 28, 24, "-")
local stackEdit = CreateFrame("EditBox", "BankSplitterStackEdit", UI.splitPage, "InputBoxTemplate")
stackEdit:SetSize(36, 20)
stackEdit:SetPoint("TOPLEFT", UI.splitPage, "TOPLEFT", PL + 102, -92)
stackEdit:SetAutoFocus(false)
stackEdit:SetNumeric(true)
stackEdit:SetMaxLetters(3)
stackEdit:SetText("1")
stackEdit:SetJustifyH("CENTER")
local stackPlusBtn = BTN(UI.splitPage, PL + 144, -90, 28, 24, "+")
FS(UI.splitPage, "GameFontNormalSmall", PL + 180, -96, L.LABEL_PER_SLOT)

-- Live preview: what a run would do with the current selection
local previewText = UI.splitPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
previewText:SetPoint("TOPLEFT",  UI.splitPage, "TOPLEFT",  PL, -128)
previewText:SetPoint("TOPRIGHT", UI.splitPage, "TOPRIGHT", PR, -128)
previewText:SetHeight(36)
previewText:SetJustifyH("LEFT")
previewText:SetJustifyV("TOP")
previewText:SetWordWrap(true)

local function ClearItemSlot()
    S.targetItem = nil
    itemIcon:Hide()
    itemNameText:SetText(L.ITEM_EMPTY)
    RequestPreview()
end

local function TryReceiveItem()
    local cursorType, itemId, itemLink = GetCursorInfo()
    if cursorType == "item" and itemId then
        local name, _, _, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemId)
        if name then
            S.targetItem = { id = itemId, key = GetItemKey(itemLink, itemId), name = name, link = itemLink }
            itemIcon:SetTexture(texture)
            itemIcon:Show()
            itemNameText:SetText(itemLink or name)
            ClearCursor()
            RequestPreview()
            return true
        end
    end
    return false
end

itemSlot:SetScript("OnReceiveDrag", function() if not S.isRunning then TryReceiveItem() end end)
itemSlot:SetScript("OnClick", function(_, button)
    if button == "LeftButton" and not S.isRunning then
        if GetCursorInfo() == "item" then TryReceiveItem() else ClearItemSlot() end
    end
end)
itemSlot:SetScript("OnEnter", function(self)
    if S.targetItem then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if S.targetItem.link then GameTooltip:SetHyperlink(S.targetItem.link) else GameTooltip:SetItemByID(S.targetItem.id) end
        GameTooltip:AddLine(L.TOOLTIP_REMOVE)
        GameTooltip:Show()
    end
end)
itemSlot:SetScript("OnLeave", function() GameTooltip:Hide() end)


-- A click on a button does not take focus from an edit box, so a typed value
-- is not committed yet when +/- or the action button is clicked. Those handlers
-- therefore commit the boxes first. While a run is active the values are
-- frozen: the boxes are reset to what the run uses.
--- Wires an edit box and its - / + buttons to the number S[key] (at least `min`).
--- Returns the function that commits the typed value.
local function BindNumberBox(edit, minusBtn, plusBtn, key, min)
    local function Commit()
        if S.isRunning then edit:SetText(tostring(S[key])); return end
        S[key] = math.max(min, tonumber(edit:GetText()) or min)
        edit:SetText(tostring(S[key]))
    end
    local function Step(delta)
        if S.isRunning then return end
        Commit()
        S[key] = math.max(min, S[key] + delta)
        edit:SetText(tostring(S[key]))
    end
    edit:SetScript("OnEnterPressed", function() Commit(); edit:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function() edit:SetText(tostring(S[key])); edit:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", Commit)
    edit:SetScript("OnTextChanged", function() RequestPreview() end)   -- the preview follows what is typed
    minusBtn:SetScript("OnClick", function() Step(-1) end)
    plusBtn:SetScript("OnClick", function() Step(1) end)
    return Commit
end
local CommitCount = BindNumberBox(countEdit, countMinusBtn, countPlusBtn, "stackCount", 0)
local CommitSize  = BindNumberBox(stackEdit, stackMinusBtn, stackPlusBtn, "stackSize", 1)

--- Commits both edit boxes (Split).
local function ReadInputs()
    CommitCount(); countEdit:ClearFocus()
    CommitSize();  stackEdit:ClearFocus()
end

--- What a split run would do with the current selection.
--- Returns the text and its color. The edit boxes are read as typed (not committed yet).
local function ComputePreview()
    if not S.targetItem then return L.STATUS_NO_ITEM, COLOR.INFO end
    local problem = ValidateBank()
    if problem then return problem, COLOR.WARN end

    local count = math.max(0, tonumber(countEdit:GetText()) or 0)
    local size  = math.max(1, tonumber(stackEdit:GetText()) or 1)
    local key = S.targetItem.key
    local found, slotsNeeded, emptySlots = 0, 0, 0

    if S.sourceMode == "bank" then
        local first, last = TabRange()
        -- Splits stay inside their tab, so free slots are counted for the
        -- tabs that actually hold stacks to split.
        for tab = first, last do
            if IsTabAccessible(tab) then
                local tabFound, tabEmpty = 0, 0
                for slot = 1, GetBankTabSlotCount(tab) do
                    local id, n = GetBankSlotInfo(tab, slot)
                    if not id or n == 0 then
                        tabEmpty = tabEmpty + 1
                    elseif n > size and id == key then
                        tabFound    = tabFound + 1
                        slotsNeeded = slotsNeeded + (math.ceil(n / size) - 1)
                    end
                end
                found = found + tabFound
                if tabFound > 0 then emptySlots = emptySlots + tabEmpty end
            end
        end
        if found == 0 then return string.format(L.STATUS_NO_STACKS, size), COLOR.INFO end
    elseif S.sourceMode == "withdraw" then
        for tab, slot in BankSlots() do
            local id, n = GetBankSlotInfo(tab, slot)
            if id and n > size and id == key then
                found       = found + 1
                slotsNeeded = slotsNeeded + (math.ceil(n / size) - 1)
            end
        end
        if found == 0 then return string.format(L.STATUS_NO_STACKS, size), COLOR.INFO end
        for bagID, slot in BagSlots() do
            if C_Container.GetContainerItemLink(bagID, slot) == nil then emptySlots = emptySlots + 1 end
        end
    else
        -- Bags -> Bank: count matching items in bags and free bank slots
        local totalItems = 0
        for bagID, slot in BagSlots() do
            local id, n = GetBagSlotInfo(bagID, slot)
            if id and id == key then totalItems = totalItems + n end
        end
        if totalItems == 0 then return L.STATUS_NO_ITEMS_IN_BAGS, COLOR.INFO end
        for tab, slot in BankSlots() do
            if IsBankSlotEmpty(tab, slot) then emptySlots = emptySlots + 1 end
        end
        found       = math.ceil(totalItems / size)
        slotsNeeded = found
    end

    -- a run stops after `count` stacks, so it never needs more slots than that
    if count > 0 then slotsNeeded = math.min(slotsNeeded, count) end

    local countLabel = count > 0
        and string.format("%d x %d  |  ", count, size)
        or  string.format("all x %d  |  ", size)
    if slotsNeeded <= emptySlots then
        return countLabel .. string.format(L.STATUS_PREVIEW_OK, found, slotsNeeded, emptySlots), COLOR.OK
    end
    return countLabel .. string.format(L.STATUS_PREVIEW_FAIL, found, slotsNeeded, emptySlots, slotsNeeded - emptySlots), COLOR.TEXT
end

local previewPending = false

--- Refreshes the preview line a frame later, however many changes came in (typing,
--- bag updates, selection changes). Only shown while it can be read: split page, no run.
RequestPreview = function()
    if previewPending then return end
    previewPending = true
    RunNextFrame(function()
        previewPending = false
        if not UI.frame:IsShown() or S.activeTab ~= "split" or S.isRunning then return end
        local text, color = ComputePreview()
        previewText:SetText("|cff" .. color .. text .. "|r")
    end)
end

local function StartSplit()
    if not S.targetItem then
        SetStatus(L.STATUS_NO_ITEM, COLOR.WARN); return
    end
    if not CheckAndValidate() then return end

    ReadInputs()   -- commit typed values (race-condition guard)
    ns.SaveLast()

    S.stacksCreated = 0
    ns.StartRun("split", ns.DoNextSplit)
end

-- Exports
ns.RequestPreview = RequestPreview
ns.StartSplit = StartSplit
UI.countEdit = countEdit
UI.countMinusBtn = countMinusBtn
UI.countPlusBtn = countPlusBtn
UI.itemSlotBorderFrame = itemSlotBorderFrame
UI.previewText = previewText
UI.stackEdit = stackEdit
UI.stackMinusBtn = stackMinusBtn
UI.stackPlusBtn = stackPlusBtn
