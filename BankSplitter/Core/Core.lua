-- ============================================================
-- BankSplitter - Core
-- Namespace, constants, shared state and the default settings.
-- ============================================================

local _, ns = ...

local L = ns.L  -- Locale shorthand

-- Timing (seconds)
local T = {
    GUILD          = 0.4,   -- pause between two Guild Bank operations (guard against server latency)
    WARBAND        = 0.3,   -- same for Warband / Character Bank
    QUERY          = 0.6,   -- wait for guild tab contents before an "All tabs" run
    -- A step only starts once the server confirmed the previous one (slots unlocked,
    -- target filled). Starting early makes the source slot's split fail silently and
    -- leaves gaps, because the claimed target slot stays empty.
    SETTLE_POLL    = 0.1,   -- between two confirmation checks
    SETTLE_TIMEOUT = 2.5,   -- give up on a pending operation after this long
    MAX_LOST       = 3,     -- unconfirmed operations in a row before the run stops
}

-- Status line colors (hex RRGGBB)
local COLOR = {
    OK    = "00ff88",
    ERROR = "ff4444",
    WARN  = "ff8800",
    BUSY  = "ffcc00",
    INFO  = "aaaaaa",
    TEXT  = "ffffff",
}

local TAB_ALL = 0   -- targetTab value meaning "every accessible tab"

-- Bank replacement addons draw their own bank window (often with a merged
-- "All" view), so Blizzard's visible-tab state says nothing about what the
-- user is looking at. The visible-tab check is skipped when one is loaded.
local CUSTOM_BANK_ADDONS = { "Baganator", "Bagnon", "Combuctor", "BetterBags", "ArkInventory", "AdiBags" }

local WARBAND_BAGS = {
    [1] = Enum.BagIndex.AccountBankTab_1,
    [2] = Enum.BagIndex.AccountBankTab_2,
    [3] = Enum.BagIndex.AccountBankTab_3,
    [4] = Enum.BagIndex.AccountBankTab_4,
    [5] = Enum.BagIndex.AccountBankTab_5,
}
local CHARACTER_BANK_BAGS = {
    [1] = Enum.BagIndex.CharacterBankTab_1,
    [2] = Enum.BagIndex.CharacterBankTab_2,
    [3] = Enum.BagIndex.CharacterBankTab_3,
    [4] = Enum.BagIndex.CharacterBankTab_4,
    [5] = Enum.BagIndex.CharacterBankTab_5,
    [6] = Enum.BagIndex.CharacterBankTab_6,
}
local PLAYER_BAGS = { 0, 1, 2, 3, 4, Enum.BagIndex.ReagentBag }  -- backpack, bag slots, reagent bag

-- Bank tab bag ID -> { mode, tab }, to map the bank panel's selected tab ID to our tab number
local BANK_TAB_BY_BAG = {}
for tab, bagID in pairs(WARBAND_BAGS)        do BANK_TAB_BY_BAG[bagID] = { mode = "warband",   tab = tab } end
for tab, bagID in pairs(CHARACTER_BANK_BAGS) do BANK_TAB_BY_BAG[bagID] = { mode = "character", tab = tab } end

-- Interactions that end a bank run when they close
local BANK_INTERACTIONS = {
    [Enum.PlayerInteractionType.Banker]          = true,
    [Enum.PlayerInteractionType.GuildBanker]     = true,
    [Enum.PlayerInteractionType.CharacterBanker] = true,
    [Enum.PlayerInteractionType.AccountBanker]   = true,
}

-- Interactions that open Blizzard's BankFrame (Character + Warband bank)
local BAG_BANK_INTERACTIONS = {
    Enum.PlayerInteractionType.Banker,
    Enum.PlayerInteractionType.CharacterBanker,
    Enum.PlayerInteractionType.AccountBanker,
}

local MODE_NAMES = { guild = L.BTN_GUILD, warband = L.BTN_WARBAND, character = L.BTN_CHARACTER }

local MODE_ORDER   = { "guild", "warband", "character" }
local SOURCE_NAMES = { bank = L.BTN_SOURCE_BANK, bags = L.BTN_SOURCE_BAGS, withdraw = L.BTN_SOURCE_WITHDRAW }
-- Setting that opens the window together with each bank
local OPEN_SETTING = { guild = "openGuild", warband = "openWarband", character = "openCharacter" }

-- Shared mutable state. The other files read and write it as S.<name>.
local S = {
    mode            = "guild",    -- "guild" | "warband" | "character"
    sourceMode      = "bank",     -- "bank" (split in place) | "bags" (Bags -> Bank) | "withdraw" (Bank -> Bags)
    activeTab       = "split",    -- visible tab of the window: "split" | "transfer"
    isRunning       = false,
    runKind         = nil,        -- "split" | "transfer" while isRunning
    targetTab       = 1,          -- 1..N, or TAB_ALL
    targetItem      = nil,        -- { id, key, name, link } (split item)
    pendingTimer    = nil,
    lastOp          = nil,        -- previous bank operation, see RecordOp(); the next step waits until it is confirmed
    settleWaited    = 0,          -- seconds spent waiting for lastOp to be confirmed
    lostInARow      = 0,          -- operations in a row that were never confirmed
    stackSize       = 1,
    stackCount      = 0,          -- 0 = unlimited; >0 = exact N stacks
    stacksCreated   = 0,
    guildBankOpen   = false,      -- guild banker interaction active (independent of Blizzard's GuildBankFrame)
    transferMoved   = 0,
    transferSkipped = 0,
}
local usedSlots    = {}           -- claimed bank target slots, keyed "tab:slot" (merge guard)
local usedBagSlots = {}           -- claimed bag target slots, keyed "bagID:slot" (merge guard)
local transferSet  = {}           -- item keys of the list (see GetItemKey), built per transfer run
local srcDone      = {}           -- source slots already handled this run ("tab:slot" / "bag:slot")

-- ============================================================
-- Saved settings (BankSplitterDB.settings, edited in the Settings panel)
-- ============================================================

local DEFAULTS = {
    openGuild     = false,       -- open the window together with the Guild Bank
    openWarband   = false,       -- ... the Warband Bank
    openCharacter = false,       -- ... the Character Bank
    followBank    = true,        -- bank selection follows the bank that was opened
    autoClose     = true,        -- close an auto-opened window together with the bank
    remember      = true,        -- remember bank / source / tab / stack values
    greeting      = true,        -- chat message on login
    scale         = 1,           -- window scale
}

--- Setting value; falls back to the default while the saved variables aren't loaded yet.
local function Opt(key)
    local s = BankSplitterDB and BankSplitterDB.settings
    local v = s and s[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

-- Exports
ns.BAG_BANK_INTERACTIONS = BAG_BANK_INTERACTIONS
ns.BANK_INTERACTIONS = BANK_INTERACTIONS
ns.BANK_TAB_BY_BAG = BANK_TAB_BY_BAG
ns.CHARACTER_BANK_BAGS = CHARACTER_BANK_BAGS
ns.COLOR = COLOR
ns.CUSTOM_BANK_ADDONS = CUSTOM_BANK_ADDONS
ns.DEFAULTS = DEFAULTS
ns.MODE_NAMES = MODE_NAMES
ns.MODE_ORDER = MODE_ORDER
ns.OPEN_SETTING = OPEN_SETTING
ns.Opt = Opt
ns.PLAYER_BAGS = PLAYER_BAGS
ns.S = S
ns.SOURCE_NAMES = SOURCE_NAMES
ns.T = T
ns.TAB_ALL = TAB_ALL
ns.WARBAND_BAGS = WARBAND_BAGS
ns.srcDone = srcDone
ns.transferSet = transferSet
ns.usedBagSlots = usedBagSlots
ns.usedSlots = usedSlots
ns.UI = {}   -- the window's widgets, filled by the UI files
