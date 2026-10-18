-- ============================================================
-- BankSplitter - Run
-- Split and transfer runs: next operation, pacing, confirmation by the server.
-- ============================================================

local _, ns = ...

local COLOR = ns.COLOR
local FindEmptyBankSlot = ns.FindEmptyBankSlot
local GetBagSlotInfo = ns.GetBagSlotInfo
local GetBankSlotInfo = ns.GetBankSlotInfo
local GetBankTabSlotCount = ns.GetBankTabSlotCount
local GetItemKey = ns.GetItemKey
local GetTabBagID = ns.GetTabBagID
local InTransferSet = ns.InTransferSet
local IsBankSlotEmpty = ns.IsBankSlotEmpty
local IsTabAccessible = ns.IsTabAccessible
local L = ns.L
local PLAYER_BAGS = ns.PLAYER_BAGS
local RequestGuildTabData = ns.RequestGuildTabData
local RequestPreview = ns.RequestPreview
local S = ns.S
local SetRunningUI = ns.SetRunningUI
local SetStatus = ns.SetStatus
local T = ns.T
local TAB_ALL = ns.TAB_ALL
local TabLabel = ns.TabLabel
local TabRange = ns.TabRange
local srcDone = ns.srcDone
local usedBagSlots = ns.usedBagSlots
local usedSlots = ns.usedSlots

--- Split within the bank (Bank -> Bank).
local function DoSplitBank(tab, sourceSlot, emptySlot, amount)
    if S.mode == "guild" then
        SplitGuildBankItem(tab, sourceSlot, amount)
        PickupGuildBankItem(tab, emptySlot)
    else
        local bagID = GetTabBagID(tab)
        C_Container.SplitContainerItem(bagID, sourceSlot, amount)
        C_Container.PickupContainerItem(bagID, emptySlot)
    end
end

--- Split from player bag into the bank (Bags -> Bank).
local function DoSplitBags(tab, sourceBagID, sourceSlot, emptyBankSlot, amount)
    C_Container.SplitContainerItem(sourceBagID, sourceSlot, amount)
    if S.mode == "guild" then
        PickupGuildBankItem(tab, emptyBankSlot)
    else
        C_Container.PickupContainerItem(GetTabBagID(tab), emptyBankSlot)
    end
end

--- Split from the bank into a player bag (Bank -> Bags).
local function DoSplitWithdraw(tab, sourceSlot, destBagID, destSlot, amount)
    if S.mode == "guild" then
        SplitGuildBankItem(tab, sourceSlot, amount)
    else
        C_Container.SplitContainerItem(GetTabBagID(tab), sourceSlot, amount)
    end
    C_Container.PickupContainerItem(destBagID, destSlot)
end

--- First empty player bag slot that is not already claimed this run.
--- Returns bagID, slot (nil, nil if the bags are full).
local function FindFreeBagSlot()
    for _, bagID in ipairs(PLAYER_BAGS) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local key = bagID .. ":" .. slot
            if not usedBagSlots[key] and C_Container.GetContainerItemLink(bagID, slot) == nil then
                return bagID, slot
            end
        end
    end
    return nil, nil
end

--- Finds the next source + destination slot for the current sourceMode.
--- Returns sourceSlot, destSlot, count, extraBagID, tab.
--- tab is the bank tab the operation touches (source tab for "bank" and
--- "withdraw", destination tab for "bags"); with targetTab == TAB_ALL it is
--- the first accessible tab that fits.
--- extraBagID meaning depends on sourceMode:
---   "bank"     -> nil (source and target slot share the same tab)
---   "bags"     -> source bag ID (player bag the item is taken from)
---   "withdraw" -> destination bag ID (player bag the item is placed into)
local function FindNextOperation()
    local first, last = TabRange()

    if S.sourceMode == "withdraw" then
        -- Destination: first free, unused player bag slot
        local destBagID, destSlot = FindFreeBagSlot()

        -- Source: bank slots with stack > stackSize, in any selected tab
        for tab = first, last do
            if IsTabAccessible(tab) then
                for slot = 1, GetBankTabSlotCount(tab) do
                    local id, count = GetBankSlotInfo(tab, slot)
                    if id and count > S.stackSize and id == S.targetItem.key then
                        return slot, destSlot, count, destBagID, tab
                    end
                end
            end
        end
        return nil, destSlot, 0, destBagID, first
    end

    if S.sourceMode == "bank" then
        -- Source: bank slots with stack > stackSize. The split target must
        -- be in the same tab, so a tab without a free slot is remembered as
        -- fallback (for the "no slots" message) and the search goes on.
        local fallback
        for tab = first, last do
            if IsTabAccessible(tab) then
                local emptySlot = FindEmptyBankSlot(tab)
                for slot = 1, GetBankTabSlotCount(tab) do
                    local id, count = GetBankSlotInfo(tab, slot)
                    if id and count > S.stackSize and id == S.targetItem.key then
                        if emptySlot then return slot, emptySlot, count, nil, tab end
                        fallback = fallback or { slot, count, tab }
                        break
                    end
                end
            end
        end
        if fallback then return fallback[1], nil, fallback[2], nil, fallback[3] end
        return nil, nil, 0, nil, first
    end

    -- "bags": source is the first matching player bag slot
    local srcBag, srcSlot, srcCount
    for _, bagID in ipairs(PLAYER_BAGS) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local id, count = GetBagSlotInfo(bagID, slot)
            if id and count > 0 and id == S.targetItem.key then
                srcBag, srcSlot, srcCount = bagID, slot, count
                break
            end
        end
        if srcBag then break end
    end
    if not srcBag then return nil, nil, 0, nil, first end

    -- Destination: first selected tab with a free slot
    for tab = first, last do
        if IsTabAccessible(tab) then
            local emptySlot = FindEmptyBankSlot(tab)
            if emptySlot then return srcSlot, emptySlot, srcCount, srcBag, tab end
        end
    end
    return srcSlot, nil, srcCount, srcBag, first
end

--- Runs fn after delay seconds; replaces any pending step.
local function ScheduleStep(fn, delay)
    if S.pendingTimer then S.pendingTimer:Cancel() end
    S.pendingTimer = C_Timer.NewTimer(delay, function()
        S.pendingTimer = nil
        fn()
    end)
end

local function StepDelay()
    return (S.mode == "guild") and T.GUILD or T.WARBAND
end

--- A position is { tab = bank tab, slot = n } or { bag = bagID, slot = n }.
--- Locked means an operation on that slot is still pending.
local function IsPosLocked(pos)
    if pos.bag then
        local info = C_Container.GetContainerItemInfo(pos.bag, pos.slot)
        return info and info.isLocked or false
    end
    if S.mode == "guild" then
        -- GetGuildBankItemInfo returns texture, itemCount, locked, ...
        return select(3, GetGuildBankItemInfo(pos.tab, pos.slot)) and true or false
    end
    local bagID = GetTabBagID(pos.tab)
    local info = bagID and C_Container.GetContainerItemInfo(bagID, pos.slot)
    return info and info.isLocked or false
end

local function IsPosEmpty(pos)
    if pos.bag then return C_Container.GetContainerItemLink(pos.bag, pos.slot) == nil end
    return IsBankSlotEmpty(pos.tab, pos.slot)
end

--- Remembers the operation that was just sent. claimTbl[claimKey] is the
--- destination slot reserved for it (released again if the operation is lost).
--- The guild bank only keeps the visible tab up to date, so the target is
--- checked for contents only there; locks and the cursor are checked always.
local function RecordOp(src, dest, claimTbl, claimKey)
    local verifyDest = dest.bag ~= nil or S.mode ~= "guild"
        or (GetCurrentGuildBankTab ~= nil and GetCurrentGuildBankTab() == dest.tab)
    S.lastOp = { src = src, dest = dest, claimTbl = claimTbl, claimKey = claimKey, verifyDest = verifyDest }
end

--- Whether the server has processed lastOp: nothing on the cursor, source and
--- target unlocked, target filled.
local function IsOpConfirmed(op)
    if GetCursorInfo() or IsPosLocked(op.src) or IsPosLocked(op.dest) then return false end
    return not (op.verifyDest and IsPosEmpty(op.dest))
end

--- Called at the start of every step. Returns
---   "ok"   - nothing pending or confirmed: go on
---   "wait" - still pending: this step was rescheduled, return
---   "lost" - not confirmed within T.SETTLE_TIMEOUT: lastOp is kept for the caller
---            to clean up (it must set lastOp = nil)
local function AwaitLastOp(step)
    if not S.lastOp then return "ok" end
    if IsOpConfirmed(S.lastOp) then
        S.lastOp, S.settleWaited, S.lostInARow = nil, 0, 0
        return "ok"
    end
    S.settleWaited = S.settleWaited + T.SETTLE_POLL
    if S.settleWaited < T.SETTLE_TIMEOUT then
        ScheduleStep(step, T.SETTLE_POLL)
        return "wait"
    end
    S.settleWaited = 0
    return "lost"
end

local function StopRunning(msg, color)
    -- A transfer step may have left the item on the cursor; put it back
    if S.runKind == "transfer" and S.lastOp and GetCursorInfo() then ClearCursor() end
    S.isRunning     = false
    S.runKind       = nil
    S.lastOp        = nil
    S.settleWaited  = 0
    S.lostInARow    = 0
    S.stacksCreated = 0
    if S.pendingTimer then S.pendingTimer:Cancel(); S.pendingTimer = nil end
    wipe(usedSlots)
    wipe(usedBagSlots)
    wipe(srcDone)
    SetRunningUI(false)
    if msg then SetStatus(msg, color) end
    RequestPreview()
end

--- Starts a run. Guild Bank "All tabs" first requests every tab's contents
--- and gives the server time to answer before the first operation.
local function StartRun(kind, firstStep)
    S.isRunning = true
    S.runKind   = kind
    SetRunningUI(true)
    SetStatus(L.STATUS_RUNNING, COLOR.BUSY)
    if S.mode == "guild" and S.targetTab == TAB_ALL then
        RequestGuildTabData()
        ScheduleStep(firstStep, T.QUERY)
    else
        firstStep()
    end
end

local function AbortRun()
    StopRunning(L.STATUS_ABORTED, COLOR.WARN)
end

local function DoNextSplit()
    if not S.isRunning then return end

    local state = AwaitLastOp(DoNextSplit)
    if state == "wait" then return end
    if state == "lost" then
        -- Item still on the cursor: the destination refused it (e.g. a
        -- soulbound item in the Warband bank). Another pickup would swap items
        -- around, so put it back and stop.
        if GetCursorInfo() then
            ClearCursor()
            StopRunning(L.STATUS_SPLIT_REFUSED, COLOR.ERROR)
            return
        end
        -- Otherwise the split silently failed: free the reserved slot (no gap)
        -- and do it again.
        S.lastOp.claimTbl[S.lastOp.claimKey] = nil
        S.lastOp = nil
        S.stacksCreated = S.stacksCreated - 1
        S.lostInARow = S.lostInARow + 1
        if S.lostInARow >= T.MAX_LOST then
            StopRunning(L.STATUS_NOT_CONFIRMED, COLOR.ERROR)
            return
        end
    end

    if S.stackCount > 0 and S.stacksCreated >= S.stackCount then
        StopRunning(string.format(L.STATUS_DONE_COUNT, S.stackCount, S.stackSize), COLOR.OK)
        return
    end

    local sourceSlot, destSlot, count, extraBagID, opTab = FindNextOperation()

    if not sourceSlot then
        if S.stacksCreated == 0 then
            StopRunning(string.format(L.STATUS_NO_ITEM_FOUND,
                S.targetItem and S.targetItem.name or "?", TabLabel(S.targetTab)), COLOR.ERROR)
        elseif S.stackCount > 0 then
            StopRunning(string.format(L.STATUS_DONE_COUNT, S.stacksCreated, S.stackSize), COLOR.OK)
        else
            StopRunning(string.format(L.STATUS_DONE, S.stackSize), COLOR.OK)
        end
        return
    end

    if not destSlot then
        local msg = (S.sourceMode == "withdraw")
            and L.STATUS_NO_SLOTS_BAGS
            or string.format(L.STATUS_NO_SLOTS, TabLabel(opTab))
        StopRunning(msg, COLOR.ERROR)
        return
    end

    S.stacksCreated = S.stacksCreated + 1
    SetStatus(string.format(L.STATUS_SPLITTING, sourceSlot, count, S.stackSize), COLOR.BUSY)

    if S.sourceMode == "bank" then
        local key = opTab .. ":" .. destSlot
        usedSlots[key] = true
        DoSplitBank(opTab, sourceSlot, destSlot, S.stackSize)
        RecordOp({ tab = opTab, slot = sourceSlot }, { tab = opTab, slot = destSlot }, usedSlots, key)
    elseif S.sourceMode == "bags" then
        local key = opTab .. ":" .. destSlot
        usedSlots[key] = true
        local amount = math.min(S.stackSize, count)
        DoSplitBags(opTab, extraBagID, sourceSlot, destSlot, amount)
        RecordOp({ bag = extraBagID, slot = sourceSlot }, { tab = opTab, slot = destSlot }, usedSlots, key)
    else -- withdraw
        local key = extraBagID .. ":" .. destSlot
        usedBagSlots[key] = true
        local amount = math.min(S.stackSize, count)
        DoSplitWithdraw(opTab, sourceSlot, extraBagID, destSlot, amount)
        RecordOp({ tab = opTab, slot = sourceSlot }, { bag = extraBagID, slot = destSlot }, usedBagSlots, key)
    end

    ScheduleStep(DoNextSplit, StepDelay())
end

--- Whether the player's bag item may be deposited into the selected bank.
--- Warband / Character bank reject items they don't accept (e.g. soulbound
--- items in the Warband bank); the Guild Bank has no such API.
local function IsBagItemAllowedInBank(bagID, slot)
    local bankType = (S.mode == "warband" and Enum.BankType.Account)
        or (S.mode == "character" and Enum.BankType.Character)
    if not bankType or not (C_Bank and C_Bank.IsItemAllowedInBankType and ItemLocation) then
        return true
    end
    return C_Bank.IsItemAllowedInBankType(bankType, ItemLocation:CreateFromBagAndSlot(bagID, slot))
end

--- Finds the next list item to move.
--- Returns fromA, fromSlot, toA, toSlot:
---   "bags" (deposit):    fromA = bagID, toA = bank tab
---   "withdraw":          fromA = bank tab, toA = bagID
--- or nil, reason with reason "done" (nothing left) / "noslot" (no room).
local function FindNextTransfer()
    local first, last = TabRange()

    if S.sourceMode == "bags" then
        for _, bagID in ipairs(PLAYER_BAGS) do
            for slot = 1, C_Container.GetContainerNumSlots(bagID) do
                local key = bagID .. ":" .. slot
                if not srcDone[key] then
                    local info = C_Container.GetContainerItemInfo(bagID, slot)
                    if info and not info.isLocked and InTransferSet((GetItemKey(info.hyperlink, info.itemID))) then
                        if not IsBagItemAllowedInBank(bagID, slot) then
                            srcDone[key] = true
                            S.transferSkipped = S.transferSkipped + 1
                        else
                            for tab = first, last do
                                if IsTabAccessible(tab) then
                                    local emptySlot = FindEmptyBankSlot(tab)
                                    if emptySlot then return bagID, slot, tab, emptySlot end
                                end
                            end
                            return nil, "noslot"
                        end
                    end
                end
            end
        end
        return nil, "done"
    end

    -- "withdraw"
    for tab = first, last do
        if IsTabAccessible(tab) then
            for slot = 1, GetBankTabSlotCount(tab) do
                local key = tab .. ":" .. slot
                if not srcDone[key] then
                    local id = GetBankSlotInfo(tab, slot)
                    if InTransferSet(id) then
                        local destBag, destSlot = FindFreeBagSlot()
                        if not destBag then return nil, "noslot" end
                        return tab, slot, destBag, destSlot
                    end
                end
            end
        end
    end
    return nil, "done"
end

local function DoNextTransfer()
    if not S.isRunning or S.runKind ~= "transfer" then return end

    local state = AwaitLastOp(DoNextTransfer)
    if state == "wait" then return end
    if state == "lost" then
        -- Not confirmed in time. If the item is still on the cursor the
        -- destination refused it (e.g. soulbound item, restricted tab): put it
        -- back. Either way free the reserved slot and skip that item.
        local refused = GetCursorInfo() ~= nil
        if refused then ClearCursor() end
        S.lastOp.claimTbl[S.lastOp.claimKey] = nil
        S.lastOp = nil
        S.transferMoved   = S.transferMoved - 1
        S.transferSkipped = S.transferSkipped + 1
        S.lostInARow = refused and 0 or S.lostInARow + 1
        if S.lostInARow >= T.MAX_LOST then
            StopRunning(L.STATUS_NOT_CONFIRMED, COLOR.ERROR)
            return
        end
    end

    local fromA, fromSlot, toA, toSlot = FindNextTransfer()

    if not fromA then
        local reason = fromSlot  -- second return value when nothing was found
        if reason == "noslot" then
            local msg = (S.sourceMode == "withdraw") and L.STATUS_NO_SLOTS_BAGS
                or string.format(L.STATUS_NO_SLOTS, TabLabel(S.targetTab))
            StopRunning(string.format(L.STATUS_TRANSFER_PARTIAL, msg, S.transferMoved), COLOR.ERROR)
        elseif S.transferMoved == 0 and S.transferSkipped == 0 then
            StopRunning(L.STATUS_TRANSFER_NOTHING, COLOR.WARN)
        elseif S.transferSkipped > 0 then
            StopRunning(string.format(L.STATUS_TRANSFER_DONE_SKIPPED, S.transferMoved, S.transferSkipped), COLOR.BUSY)
        else
            StopRunning(string.format(L.STATUS_TRANSFER_DONE, S.transferMoved), COLOR.OK)
        end
        return
    end

    S.transferMoved = S.transferMoved + 1
    SetStatus(string.format(L.STATUS_TRANSFERRING, S.transferMoved), COLOR.BUSY)

    if S.sourceMode == "bags" then
        local destKey = toA .. ":" .. toSlot
        srcDone[fromA .. ":" .. fromSlot] = true
        usedSlots[destKey] = true
        C_Container.PickupContainerItem(fromA, fromSlot)
        if S.mode == "guild" then
            PickupGuildBankItem(toA, toSlot)
        else
            C_Container.PickupContainerItem(GetTabBagID(toA), toSlot)
        end
        RecordOp({ bag = fromA, slot = fromSlot }, { tab = toA, slot = toSlot }, usedSlots, destKey)
    else -- withdraw
        local destKey = toA .. ":" .. toSlot
        srcDone[fromA .. ":" .. fromSlot] = true
        usedBagSlots[destKey] = true
        if S.mode == "guild" then
            PickupGuildBankItem(fromA, fromSlot)
        else
            C_Container.PickupContainerItem(GetTabBagID(fromA), fromSlot)
        end
        C_Container.PickupContainerItem(toA, toSlot)
        RecordOp({ tab = fromA, slot = fromSlot }, { bag = toA, slot = toSlot }, usedBagSlots, destKey)
    end

    ScheduleStep(DoNextTransfer, StepDelay())
end

-- Exports
ns.AbortRun = AbortRun
ns.DoNextSplit = DoNextSplit
ns.DoNextTransfer = DoNextTransfer
ns.StartRun = StartRun
ns.StopRunning = StopRunning
