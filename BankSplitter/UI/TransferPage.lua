-- ============================================================
-- BankSplitter - Transfer page
-- The transfer list (drop target, list) and starting a transfer run.
-- ============================================================

local _, ns = ...

local AddTransferItem = ns.AddTransferItem
local BuildTransferSet = ns.BuildTransferSet
local COLOR = ns.COLOR
local CheckAndValidate = ns.CheckAndValidate
local CreateFlatButton = ns.CreateFlatButton
local GetTransferList = ns.GetTransferList
local L = ns.L
local PL = ns.PL
local RemoveTransferItem = ns.RemoveTransferItem
local S = ns.S
local SetStatus = ns.SetStatus
local W = ns.W
local srcDone = ns.srcDone
local UI = ns.UI

local TL_ROW_H = 24

local function TryAddCursorItem()
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType ~= "item" or not itemID then return false end
    AddTransferItem(itemID, itemLink)
    ClearCursor()
    return true
end

--- Crafting quality icon (ranks share a name, so the list must show them).
--- The atlas comes from the item's CraftingQualityInfo, like in Blizzard's UI.
local function RankMarkup(itemID)
    local ok, markup = pcall(function()
        local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
            or C_TradeSkillUI.GetItemCraftedQualityInfo(itemID)
        if info and info.iconSmall then
            return " " .. CreateAtlasMarkup(info.iconSmall, 14, 14)
        end
    end)
    return ok and markup or ""
end

-- Drop target: drag an item here (or click with an item on the cursor)
local transferAddBtn = CreateFlatButton(UI.transferPage, W - 2 * PL, 28, L.TRANSFER_ADD)
transferAddBtn:SetPoint("TOPLEFT", UI.transferPage, "TOPLEFT", PL, -6)
transferAddBtn:SetScript("OnReceiveDrag", TryAddCursorItem)
transferAddBtn:SetScript("OnClick", function() TryAddCursorItem() end)

local transferScroll = CreateFrame("ScrollFrame", "BankSplitterTransferScroll", UI.transferPage, "ScrollFrameTemplate")
transferScroll:SetPoint("TOPLEFT",     UI.transferPage, "TOPLEFT",      PL,  -42)
transferScroll:SetPoint("BOTTOMRIGHT", UI.transferPage, "BOTTOMRIGHT", -30,   22)

local transferChild = CreateFrame("Frame", nil, transferScroll)
transferChild:SetSize(W - PL - 30 - 4, 1)
transferChild:EnableMouse(true)
transferChild:SetScript("OnReceiveDrag", TryAddCursorItem)
transferScroll:SetScrollChild(transferChild)

-- Shown instead of the list while it is empty
local transferEmptyText = UI.transferPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
transferEmptyText:SetPoint("TOPLEFT",  transferScroll, "TOPLEFT",  8, -8)
transferEmptyText:SetPoint("TOPRIGHT", transferScroll, "TOPRIGHT", -8, -8)
transferEmptyText:SetJustifyH("LEFT")
transferEmptyText:SetJustifyV("TOP")
transferEmptyText:SetWordWrap(true)
transferEmptyText:SetText(L.TRANSFER_HINT)

local transferCountText = UI.transferPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
transferCountText:SetPoint("BOTTOMLEFT", UI.transferPage, "BOTTOMLEFT", PL, 4)

local transferRows = {}
local function GetTransferRow(i)
    local row = transferRows[i]
    if row then return row end
    row = CreateFrame("Button", nil, transferChild)
    row:SetSize(W - PL - 30 - 4, TL_ROW_H)
    row:SetPoint("TOPLEFT", transferChild, "TOPLEFT", 0, -(i - 1) * TL_ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT",  row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row,      "RIGHT", -26, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(20, 20)
    row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.remove:SetText("x")
    row.remove:SetScript("OnClick", function() RemoveTransferItem(row.entry) end)

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local entry = self.entry
        if entry.link then GameTooltip:SetHyperlink(entry.link) else GameTooltip:SetItemByID(entry.id) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnReceiveDrag", TryAddCursorItem)
    if UI.SkinRow then UI.SkinRow(row) end
    transferRows[i] = row
    return row
end

--- Redraws the list (also called by Items.lua when an entry is added or removed).
local function RefreshTransferUI()
    local list = GetTransferList()
    for i, entry in ipairs(list) do
        local row = GetTransferRow(i)
        row.entry = entry
        local name, itemLink, _, _, _, _, _, _, _, texture = C_Item.GetItemInfo(entry.link or entry.id)
        if name then
            -- gear versions differ by item level, which the plain name hides
            local ilvl = entry.key and entry.key:match(":(%d+)$")
            row.text:SetText((entry.link or itemLink or name) .. (ilvl and (" |cff999999(" .. ilvl .. ")|r") or "")
                .. RankMarkup(entry.id))
            row.icon:SetTexture(texture)
        else
            -- not cached yet: show the ID now, redraw once the data arrives
            row.text:SetText("item:" .. entry.id)
            row.icon:SetTexture(134400)
            Item:CreateFromItemID(entry.id):ContinueOnItemLoad(RefreshTransferUI)
        end
        row:Show()
    end
    for i = #list + 1, #transferRows do transferRows[i]:Hide() end
    transferChild:SetHeight(math.max(1, #list * TL_ROW_H))
    transferEmptyText:SetShown(#list == 0)
    transferCountText:SetText(string.format(L.TRANSFER_COUNT, #list))
end
UI.transferPage:SetScript("OnShow", RefreshTransferUI)

local function StartTransfer()
    local list = GetTransferList()
    if #list == 0 then
        SetStatus(L.STATUS_TRANSFER_EMPTY, COLOR.WARN); return
    end
    if not CheckAndValidate() then return end

    BuildTransferSet()
    wipe(srcDone)
    S.lastOp          = nil
    S.transferMoved   = 0
    S.transferSkipped = 0
    ns.StartRun("transfer", ns.DoNextTransfer)
end

-- Exports
ns.RefreshTransferUI = RefreshTransferUI
ns.StartTransfer = StartTransfer
UI.transferAddBtn = transferAddBtn
UI.transferRows = transferRows
UI.transferScroll = transferScroll
