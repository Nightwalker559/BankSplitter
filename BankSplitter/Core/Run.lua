-- ============================================================
-- BankSplitter - Run
-- Split and transfer runs: next operation, pacing, confirmation by the server.
-- ============================================================

local _, ns = ...

local BagSlots = ns.BagSlots
local BankSlots = ns.BankSlots
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

--- Picks up a bank slot onto the cursor / drops the cursor into it.
local function PickupBankSlot(tab, slot)
    if S.mode == "guild" then
        PickupGuildBankItem(tab, slot)
    else
        C_Container.PickupContainerItem(GetTabBagID(tab), slot)
    end
end

--- Splits `amount` of a bank slot's stack onto the cursor.
local function SplitBankSlot(tab, slot, amount)
    if S.mode == "guild" then
        SplitGuildBankItem(tab, slot, amount)
    else
        C_Container.SplitContainerItem(GetTabBagID(tab), slot, amount)
    end
end

--- First empty player bag slot that is not already claimed this run.
--- Returns bagID, slot (nil, nil if the bags are full).
local function FindFreeBagSlot()
    for bagID, slot in BagSlots() do
        if not usedBagSlots[bagID .. ":" .. slot] and C_Container.GetContainerItemLink(bagID, slot) == nil then
            return bagID, slot
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
    local key = S.targetItem and S.targetItem.key

    if S.sourceMode == "withdraw" then
        -- Destination: first free, unused player bag slot
        local destBagID, destSlot = FindFreeBagSlot()

        -- Source: bank slots with stack > stackSize, in any selected tab
        for tab, slot in BankSlots() do
            local id, count = GetBankSlotInfo(tab, slot)
            if id and count > S.stackSize and id == key then
                return slot, destSlot, count, destBagID, tab
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
                for slot = 1, GetBankTabSlotCount(tab) do
                    local id, count = GetBankSlotInfo(tab, slot)
                    if id and count > S.stackSize and id == key then
                        local emptySlot = FindEmptyBankSlot(tab)
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
    for bagID, slot in BagSlots() do
        local id, count = GetBagSlotInfo(bagID, slot)
        if id and count > 0 and id == key then
            srcBag, srcSlot, srcCount = bagID, slot, count
            break
        end
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

--- Remembers the operation that was just sent and reserves its destination slot
--- (claimTbl[claimKey]); the reservation is released again if the operation is lost.
--- The guild bank only keeps the visible tab up to date, so the target is
--- checked for contents only there; locks and the cursor are checked always.
local function RecordOp(src, dest, claimTbl, claimKey)
    claimTbl[claimKey] = true
    local verifyDest = dest.bag ~= nil or S.mode ~= "guild"
        or (GetCurrentGuildBankTab ~= nil and GetCurrentGuildBankTab() == dest.tab)
    S.lastOp = { src = src, dest = dest, claimTbl = claimTbl, claimKey = claimKey, verifyDest = verifyDest }
end

--- Forgets lastOp and frees the destination slot it had reserved.
local function ReleaseLastOp()
    local op = S.lastOp
    op.claimTbl[op.claimKey] = nil
    S.lastOp = nil
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
---            to clean up (ReleaseLastOp)
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
        ReleaseLastOp()
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

    local amount = math.min(S.stackSize, count)
    if S.sourceMode == "bank" then
        SplitBankSlot(opTab, sourceSlot, amount)
        PickupBankSlot(opTab, destSlot)
        RecordOp({ tab = opTab, slot = sourceSlot }, { tab = opTab, slot = destSlot }, usedSlots, opTab .. ":" .. destSlot)
    elseif S.sourceMode == "bags" then
        C_Container.SplitContainerItem(extraBagID, sourceSlot, amount)
        PickupBankSlot(opTab, destSlot)
        RecordOp({ bag = extraBagID, slot = sourceSlot }, { tab = opTab, slot = destSlot }, usedSlots, opTab .. ":" .. destSlot)
    else -- withdraw
        SplitBankSlot(opTab, sourceSlot, amount)
        C_Container.PickupContainerItem(extraBagID, destSlot)
        RecordOp({ tab = opTab, slot = sourceSlot }, { bag = extraBagID, slot = destSlot }, usedBagSlots, extraBagID .. ":" .. destSlot)
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
        for bagID, slot in BagSlots() do
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
        return nil, "done"
    end

    -- "withdraw"
    for tab, slot in BankSlots() do
        if not srcDone[tab .. ":" .. slot] and InTransferSet((GetBankSlotInfo(tab, slot))) then
            local destBag, destSlot = FindFreeBagSlot()
            if not destBag then return nil, "noslot" end
            return tab, slot, destBag, destSlot
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
        ReleaseLastOp()
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
    srcDone[fromA .. ":" .. fromSlot] = true

    if S.sourceMode == "bags" then
        C_Container.PickupContainerItem(fromA, fromSlot)
        PickupBankSlot(toA, toSlot)
        RecordOp({ bag = fromA, slot = fromSlot }, { tab = toA, slot = toSlot }, usedSlots, toA .. ":" .. toSlot)
    else -- withdraw
        PickupBankSlot(fromA, fromSlot)
        C_Container.PickupContainerItem(toA, toSlot)
        RecordOp({ tab = fromA, slot = fromSlot }, { bag = toA, slot = toSlot }, usedBagSlots, toA .. ":" .. toSlot)
    end

    ScheduleStep(DoNextTransfer, StepDelay())
end

-- Exports
ns.AbortRun = AbortRun
ns.DoNextSplit = DoNextSplit
ns.DoNextTransfer = DoNextTransfer
ns.StartRun = StartRun
ns.StopRunning = StopRunning
