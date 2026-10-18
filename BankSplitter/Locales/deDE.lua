-- BankSplitter – Lokalisierung: Deutsch (deDE)
local _, ns = ...

if GetLocale() ~= "deDE" then return end

-- Keys missing here fall back to the English text
ns.L = setmetatable({
    LABEL_BANK          = "Bank:",
    LABEL_SOURCE        = "Quelle:",
    LABEL_TAB           = "Tab:",
    LABEL_STACK_COUNT   = "Anzahl:",
    LABEL_STACK_SIZE    = "Größe:",
    LABEL_PER_SLOT      = "pro Stack",
    LABEL_STACKS_HINT   = "Stacks  (0 = alle)",

    BTN_GUILD               = "Gildenbank",
    BTN_WARBAND             = "Kriegsmeute",
    BTN_CHARACTER           = "Charakterbank",
    BTN_SOURCE_BANK         = "Bank -> Bank",
    BTN_SOURCE_BAGS         = "Tasche -> Bank",
    BTN_SOURCE_WITHDRAW     = "Bank -> Tasche",
    BTN_ALL_TABS            = "Alle",
    BTN_SPLIT               = "Split!",
    BTN_STOP                = "Stop",

    BTN_TRANSFER            = "Transfer!",
    TAB_SPLIT               = "Splitten",
    TAB_TRANSFER            = "Transferliste",
    TRANSFER_ADD            = "+ Items hierher ziehen",
    BTN_CONFIG              = "Optionen",
    TRANSFER_HINT           = "Items hierher ziehen, um sie zur Liste hinzuzufügen. Jeder Handwerksrang zählt als eigenes Item.",
    TRANSFER_COUNT          = "%d Items in der Liste",

    ITEM_EMPTY         = "|cff888888Kein Item - hierher\nziehen oder klicken.|r",
    TOOLTIP_REMOVE      = "|cffaaaaaa[Klicken zum Entfernen]|r",

    STATUS_READY            = "|cff888888Bereit.|r",
    STATUS_RUNNING          = "Läuft...",
    STATUS_ABORTED          = "Abgebrochen.",
    STATUS_BANK_CLOSED      = "Bank geschlossen - Durchlauf abgebrochen.",
    STATUS_MANUAL_OPEN      = "Bereit.",

    STATUS_SPLITTING    = "Slot %d (x%d) -> x%d",
    STATUS_DONE         = "Fertig! Alle Stacks auf %d aufgeteilt.",
    STATUS_DONE_COUNT   = "Fertig! %d Stacks à %d erstellt.",
    TAB_NAME            = "Tab %d",
    TAB_ALL_NAME        = "allen Tabs",
    STATUS_NO_SLOTS     = "Keine leeren Slots in %s!",
    STATUS_NO_SLOTS_BAGS = "Keine leeren Slots in der Tasche!",
    STATUS_NO_STACKS    = "Keine Stacks > %d gefunden.",
    STATUS_NO_ITEMS_IN_BAGS = "Kein passendes Item in der Tasche!",
    STATUS_NO_ITEM      = "Item in den Slot ziehen!",
    STATUS_NO_ITEM_FOUND = "Kein \"%s\" in %s gefunden!",
    STATUS_PREVIEW_OK   = "%d Stacks  ·  %d Slots nötig, %d frei  OK",
    STATUS_PREVIEW_FAIL = "%d Stacks  ·  %d nötig, %d frei  |cffff4444Fehlen: %d|r",
    STATUS_TAB_LOCKED   = "Tab %d nicht zugänglich!",
    STATUS_NO_TAB_ACCESS = "Kein Tab zugänglich!",
    STATUS_WRONG_TAB    = "Falscher Tab! Bitte Tab %d in der Bank anklicken.",
    STATUS_WRONG_BANK   = "Falsche Bank! %s ist offen.\nModus wechseln oder richtige Bank öffnen.",
    STATUS_NO_BANK_OPEN = "Keine Bank geöffnet! Bitte zuerst die Bank öffnen.",
    STATUS_SPLIT_REFUSED = "Die Bank hat das Item abgelehnt - Vorgang gestoppt.",
    STATUS_NOT_CONFIRMED = "Der Server hat die Verschiebungen nicht bestätigt - Vorgang gestoppt.",
    STATUS_NO_SETTINGS   = "Das Einstellungs-Panel ist nicht verfügbar.",

    STATUS_TRANSFER_EMPTY        = "Die Transferliste ist leer.",
    STATUS_TRANSFER_NOTHING      = "Keines der gelisteten Items gefunden.",
    STATUS_TRANSFERRING          = "Übertrage Stack %d...",
    STATUS_TRANSFER_DONE         = "Fertig! %d Stacks übertragen.",
    STATUS_TRANSFER_DONE_SKIPPED = "Fertig! %d Stacks übertragen, %d übersprungen (hier nicht erlaubt).",
    STATUS_TRANSFER_PARTIAL      = "%s\nBisher %d Stacks übertragen.",

    -- Optionen (Einstellungs-Panel)
    OPT_OPEN_GUILD       = "Mit der Gildenbank öffnen",
    OPT_OPEN_WARBAND     = "Mit der Kriegsmeutenbank öffnen",
    OPT_OPEN_CHARACTER   = "Mit der Charakterbank öffnen",
    OPT_OPEN_TIP         = "Öffnet das BankSplitter-Fenster zusammen mit dieser Bank, auf dem zuletzt benutzten Tab.",
    OPT_FOLLOW_BANK      = "Bank-Modus folgt der geöffneten Bank",
    OPT_FOLLOW_BANK_TIP  = "Wählt im Fenster Gilden-, Kriegsmeuten- oder Charakterbank, sobald diese Bank aufgeht oder du zwischen Bank und Kriegsmeutenbank wechselst.",
    OPT_AUTO_CLOSE       = "Mit der Bank schließen",
    OPT_AUTO_CLOSE_TIP   = "Ein automatisch geöffnetes Fenster schließt sich wieder, wenn die Bank zugeht. Ein selbst geöffnetes Fenster bleibt.",
    OPT_REMEMBER         = "Letzte Auswahl merken",
    OPT_REMEMBER_TIP     = "Behält Bank, Quelle, Tab, Stack-Anzahl und Stack-Größe über Sitzungen hinweg.",
    OPT_SCALE            = "Fenstergröße",
    OPT_SCALE_TIP        = "Größe beider Fenster.",
    OPT_GREETING         = "Chat-Meldung beim Login",
    OPT_GREETING_TIP     = "Gibt beim Login eine kurze \"geladen\"-Zeile aus.",

    CHAT_LOADED        = "geladen - /banksplitter zum Öffnen",
}, { __index = ns.L })
