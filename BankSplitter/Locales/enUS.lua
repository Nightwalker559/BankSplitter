-- BankSplitter - Localization: English (enUS, also the fallback for other locales)
local _, ns = ...

ns.L = {
    -- UI labels
    LABEL_BANK          = "Bank:",
    LABEL_SOURCE        = "Source:",
    LABEL_TAB           = "Tab:",
    LABEL_STACK_COUNT   = "Count:",
    LABEL_STACK_SIZE    = "Size:",
    LABEL_PER_SLOT      = "per stack",
    LABEL_STACKS_HINT   = "Stacks  (0 = all)",

    -- Buttons
    BTN_GUILD               = "Guild Bank",
    BTN_WARBAND             = "Warband",
    BTN_CHARACTER           = "Character Bank",
    BTN_SOURCE_BANK         = "Bank -> Bank",
    BTN_SOURCE_BAGS         = "Bags -> Bank",
    BTN_SOURCE_WITHDRAW     = "Bank -> Bags",
    BTN_ALL_TABS            = "All",
    BTN_SPLIT               = "Split!",
    BTN_STOP                = "Stop",

    -- Transfer list
    BTN_TRANSFER            = "Transfer!",
    TAB_SPLIT               = "Split",
    TAB_TRANSFER            = "Transfer list",
    TRANSFER_ADD            = "+ Drag items here",
    BTN_CONFIG              = "Options",
    TRANSFER_HINT           = "Drag items here to add them to the list. Each crafting rank counts as its own item.",
    TRANSFER_COUNT          = "%d items in list",

    -- Item slot
    ITEM_EMPTY          = "|cff888888No item – drag here\nor click.|r",
    TOOLTIP_REMOVE      = "|cffaaaaaa[Click to remove]|r",

    -- Status
    STATUS_READY            = "|cff888888Ready.|r",
    STATUS_RUNNING          = "Running...",
    STATUS_ABORTED          = "Aborted.",
    STATUS_BANK_CLOSED      = "Bank closed - run aborted.",
    STATUS_MANUAL_OPEN      = "Ready.",

    STATUS_SPLITTING    = "Slot %d (x%d) -> x%d",
    STATUS_DONE         = "Done! All stacks split to %d.",
    STATUS_DONE_COUNT   = "Done! %d stacks of %d created.",
    TAB_NAME            = "Tab %d",
    TAB_ALL_NAME        = "all tabs",
    STATUS_NO_SLOTS     = "No empty slots in %s!",
    STATUS_NO_SLOTS_BAGS = "No empty slots in bags!",
    STATUS_NO_STACKS    = "No stacks > %d found.",
    STATUS_NO_ITEMS_IN_BAGS = "No matching items found in bags!",
    STATUS_NO_ITEM      = "Drag an item into the slot!",
    STATUS_NO_ITEM_FOUND = "No \"%s\" found in %s!",
    STATUS_PREVIEW_OK   = "%d stacks  ·  %d slots needed, %d free  OK",
    STATUS_PREVIEW_FAIL = "%d stacks  ·  %d needed, %d free  |cffff4444Missing: %d|r",
    STATUS_TAB_LOCKED   = "Tab %d not accessible!",
    STATUS_NO_TAB_ACCESS = "No accessible tab!",
    STATUS_WRONG_TAB    = "Wrong tab! Please click Tab %d in the bank.",
    STATUS_WRONG_BANK   = "Wrong bank! %s is open.\nSwitch mode or open correct bank.",
    STATUS_NO_BANK_OPEN = "No bank is open! Open the bank first.",
    STATUS_SPLIT_REFUSED = "The bank refused the item - run stopped.",
    STATUS_NOT_CONFIRMED = "The server did not confirm the moves - run stopped.",
    STATUS_NO_SETTINGS   = "The settings panel is not available.",

    STATUS_TRANSFER_EMPTY        = "The transfer list is empty.",
    STATUS_TRANSFER_NOTHING      = "None of the listed items were found.",
    STATUS_TRANSFERRING          = "Transferring stack %d...",
    STATUS_TRANSFER_DONE         = "Done! %d stacks transferred.",
    STATUS_TRANSFER_DONE_SKIPPED = "Done! %d stacks transferred, %d skipped (not accepted here).",
    STATUS_TRANSFER_PARTIAL      = "%s\n%d stacks transferred so far.",

    -- Options (Settings panel)
    OPT_OPEN_GUILD       = "Open with the Guild Bank",
    OPT_OPEN_WARBAND     = "Open with the Warband Bank",
    OPT_OPEN_CHARACTER   = "Open with the Character Bank",
    OPT_OPEN_TIP         = "Opens the BankSplitter window together with this bank, on the tab you used last.",
    OPT_FOLLOW_BANK      = "Bank mode follows the open bank",
    OPT_FOLLOW_BANK_TIP  = "Selects Guild / Warband / Character Bank in the window when that bank opens or you switch between the Bank and Warband tab.",
    OPT_AUTO_CLOSE       = "Close with the bank",
    OPT_AUTO_CLOSE_TIP   = "A window that opened automatically closes again when the bank closes. A window you opened yourself stays.",
    OPT_REMEMBER         = "Remember last selection",
    OPT_REMEMBER_TIP     = "Keeps bank, source, tab, stack count and stack size between sessions.",
    OPT_SCALE            = "Window scale",
    OPT_SCALE_TIP        = "Size of the BankSplitter window.",
    OPT_GREETING         = "Chat message on login",
    OPT_GREETING_TIP     = "Prints a short \"loaded\" line when you log in.",

    -- Chat
    CHAT_LOADED         = "loaded · |cffffd700/banksplitter|r to open",
}
