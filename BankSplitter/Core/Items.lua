-- ============================================================
-- BankSplitter - Items
-- Item identity (itemID, plus item level for gear) and the saved transfer list.
-- ============================================================

local _, ns = ...

local transferSet = ns.transferSet

local isGearCache = {}   -- itemID -> true if weapon/armor (never changes, so cached)

local function IsGear(itemID)
    local gear = isGearCache[itemID]
    if gear == nil then
        local classID = select(6, C_Item.GetItemInfoInstant(itemID))
        gear = (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
        isGearCache[itemID] = gear
    end
    return gear
end

--- Identity of an item for matching: "itemID" or, for weapons and armor,
--- "itemID:itemLevel". Different upgrade levels / bonus versions of the same
--- gear piece share an itemID but are different items to the player.
--- Crafting quality ranks already have their own itemIDs.
--- Returns nil if neither link nor itemID is usable.
local function GetItemKey(link, itemID)
    itemID = itemID or (link and (C_Item.GetItemInfoInstant(link)))
    if not itemID then return nil end
    if link and IsGear(itemID) then
        local ilvl = C_Item.GetDetailedItemLevelInfo(link)
        if ilvl and ilvl > 0 then return itemID .. ":" .. ilvl end
    end
    return tostring(itemID)
end

--- Account-wide list of items to move in one go.
--- Entries are { id = itemID, key = item key, link = item link }. Entries
--- saved without a key (older versions) match any version of that itemID.
--- Created lazily: SavedVariables only exist after the addon's files ran.
local function GetTransferList()
    BankSplitterDB = BankSplitterDB or {}
    BankSplitterDB.transferList = BankSplitterDB.transferList or {}
    return BankSplitterDB.transferList
end

local function AddTransferItem(itemID, link)
    local list = GetTransferList()
    local key = GetItemKey(link, itemID)
    for _, entry in ipairs(list) do
        if entry.key == key then return false end
    end
    list[#list + 1] = { id = itemID, key = key, link = link }
    ns.RefreshTransferUI()
    return true
end

local function RemoveTransferItem(entry)
    local list = GetTransferList()
    for i, e in ipairs(list) do
        if e == entry then
            table.remove(list, i)
            break
        end
    end
    ns.RefreshTransferUI()
end

--- Fills transferSet from the list (one lookup per slot while running).
local function BuildTransferSet()
    wipe(transferSet)
    for _, entry in ipairs(GetTransferList()) do
        transferSet[entry.key or ("id:" .. entry.id)] = true
    end
end

--- Whether an item key (see GetItemKey) is on the list being transferred.
local function InTransferSet(key)
    if not key then return false end
    return transferSet[key] or transferSet["id:" .. key:match("^%d+")] or false
end

-- Exports
ns.AddTransferItem = AddTransferItem
ns.BuildTransferSet = BuildTransferSet
ns.GetItemKey = GetItemKey
ns.GetTransferList = GetTransferList
ns.InTransferSet = InTransferSet
ns.RemoveTransferItem = RemoveTransferItem
