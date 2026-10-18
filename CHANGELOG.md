# BankSplitter – Changelog

---

## 1.3.0

### New
- **One window with two tabs**: "Split" and "Transfer list" (Blizzard's tab strip below the window, like the bank). Bank, source and tab are chosen once in a bar at the top and apply to both pages.
  - **Bank and source are dropdowns** (Blizzard's current dropdown style); the tab chips (All, 1-8) show the selection with a gold border. The transfer page only offers "Bags -> Bank" and "Bank -> Bags".
  - **Footer** with the status line and one action button: "Split!" / "Transfer!", which turns into "Stop" while a run is active.
  - **Live preview** on the split page instead of a Preview button. It follows what you type, the bank / source / tab selection and bag or bank changes, and shows why a run can't start (no item, no bank open, wrong tab).
  - **Transfer page**: a drop target at the top and the list below. An empty list shows the hint.
- **Options** in Blizzard's Settings panel (AddOns > BankSplitter). Open them via `/banksplitter config` or the "Options" link in the title bar.
  - **Open with the bank**: one checkbox each for the Guild, Warband and Character Bank. The window opens on the tab you used last. Default: off.
  - **Bank selection follows the open bank** (also when you switch between the Bank and Warband tab). Default: on.
  - **Close with the bank**: a window that opened automatically closes again with the bank; a window you opened yourself stays, and a window you closed by hand is not reopened during the same bank visit. Default: on.
  - **Remember last selection**: bank, source, tab, page, stack count and stack size. Default: on.
  - **Window scale** (70 % - 130 %) and **chat message on login**.
- **The window position** is saved when you move the window.

### Changed
- The addon is called **BankSplitter** everywhere now: the folder is `Interface\AddOns\BankSplitter` (it was `GuildBankSplitter`), and so are the files and frames. **Delete the old `GuildBankSplitter` folder.** To keep your transfer list and options, close the game and copy `WTF\Account\<account>\SavedVariables\GuildBankSplitter.lua` to `BankSplitter.lua` in the same folder.
- `/banksplitter` is the main slash command; `/gbs` still works. `/banksplitter list` opens the window on the transfer page (or closes it when that page is showing).
- The code is split into files by job: `Core/` (constants and shared state, items, bank access, runs, events, settings, init), `UI/` (widgets, window, split page, transfer page, ElvUI skin) and `Locales/`.
- Interface version is 120105 (Patch 12.1.5); 120100 is no longer listed. Checked against Blizzard's UI source (live, 12.1.5): the bank, container, guild bank, item and interaction APIs used here are unchanged since 12.1.0.
- The window uses Blizzard's current panel style (`DefaultPanelTemplate`: nine-slice metal border, title bar and an `InsetFrameTemplate` content area, like the bank window) instead of the old `BasicFrameTemplateWithInset`.
- The transfer list uses Blizzard's current `ScrollFrameTemplate` (modern scroll bar) instead of the deprecated `UIPanelScrollFrameTemplate`.
- The visible Warband / Character Bank tab is read from Blizzard's bank panel (`BankFrame.BankPanel:GetSelectedTabID()`) instead of being guessed from `BAG_UPDATE`. A plain tab click without an item change no longer leaves a stale tab behind.
- The ElvUI skin covers the new controls (dropdowns, tabs) and reads ElvUI's color tables by `.r/.g/.b`.

### Fixed
- Gaps between the new stacks when splitting (seen in the Guild Bank): a step started as soon as a fixed pause was over, even if the server had not processed the previous one yet. The source slot was still locked, the split failed silently, and the reserved target slot stayed empty. Every step now waits until the previous operation is confirmed (cursor empty, slots unlocked, target filled; polled every 0.1 s, up to 2.5 s). An operation that is never confirmed releases its slot and is retried; after 3 in a row the run stops with a message. The fixed pause stays as a minimum. Applies to splits and to the transfer list.
- Crafting quality icons in the transfer list were silently missing: `Professions.GetIconForQuality` no longer exists. The icon is now built from the item's `CraftingQualityInfo`.
- Starting a Warband / Character Bank run with no banker open picked items up and left them on the cursor. It now stops with "No bank is open!".
- A split that the bank refuses (e.g. a soulbound item into the Warband bank) left the item on the cursor and kept going, which could swap items. The item is put back and the run stops with a message.
- Values typed into the Count / Size boxes were not committed when "+" or "-" was clicked (a button click does not take focus from an edit box). They are now committed first, and frozen while a run is active.

---

## 1.2.0

### New
- **Transfer list**: an account-wide list of items that is moved as whole stacks in one go, without splitting. Open it via the "Transfer list" button in the title bar or `/gbs list`. Drag items onto the "+" slot to add them, "x" removes one.
  - Direction, bank and tab come from the main window ("Bags -> Bank" or "Bank -> Bags").
  - Items the target bank doesn't accept are skipped and counted, and put back where they were.
  - Crafting ranks are separate entries and show their quality icon; gear shows its item level.
- **"All" tab button**: operate on every accessible tab of the selected bank instead of a single one (Guild, Warband and Character Bank). Needed for bank replacement addons like Baganator, whose merged "All" view has no per-tab selection.
  - Bank -> Bank keeps a split inside the tab it came from, Bags -> Bank uses the first tab with a free slot, Bank -> Bags withdraws from all tabs.
  - The Guild Bank requests every tab's contents from the server first.
- A run is aborted automatically when the bank is closed, so no item stays on the cursor.
- Locale fallback: missing German strings fall back to English.

### Fixed
- Items are now matched by itemID instead of name. Crafting quality ranks share a name, so splitting one rank also split the others; now only the exact item in the slot is touched.
- Gear is matched by itemID plus item level, so e.g. a 298 and a 53 version of the same weapon are no longer treated as the same item. Transfer list entries saved before this version match any version of that itemID.
- With a bank replacement addon (Baganator, Bagnon, Combuctor, BetterBags, ArkInventory, AdiBags) loaded, the "wrong tab" check no longer blocks single-tab runs.
- The Guild Bank is now also detected as open when Blizzard's `GuildBankFrame` is hidden by a replacement addon.
- Changing bank, source, tab or the item while a run is active is now ignored (clearing the item slot mid-run raised a Lua error).
- `.toc` pointed `IconTexture` at a file that does not exist.

### Changed
- Interface versions updated to 120100 and 120105 (Patch 12.1.0 and 12.1.5); 120007 is no longer listed.
- ElvUI skin is applied on the next frame instead of after a fixed 0.5 s delay, and covers the new controls.
- Pacing delay between operations shortened to 0.4 s (Guild Bank) / 0.3 s (Warband and Character Bank), down from 0.6 s / 1.0 s. It stays as a server latency guard.
- `BAG_UPDATE` is filtered by bag ID, so looting no longer triggers bank detection.
- Guild Bank stack count is read from the documented `itemCount` return value instead of a heuristic.
- Internal cleanup: shared step scheduler, abort handler and button highlighting.

---

## 1.1.1

### Changed
- Added Interface version 120100 (Patch 12.1.0 "Curse of Ula'tek") to the .toc, alongside 120007, for compatibility

### Notes
- Reviewed Patch 12.1.0 API changes: no changes affect Guild Bank, Warband Bank, Character Bank, or Container APIs used by this addon (`GetGuildBankItemInfo`, `C_Container.*`, `Enum.BagIndex`, `Enum.BankType`). No code changes required.

---

## 1.1.0

### New
- Character Bank support as a third bank mode, alongside Guild Bank and Warband Bank (6 tabs, `Enum.BagIndex.CharacterBankTab_1-6`)
- New "Bank -> Bags" source/direction: withdraw split stacks from any bank type directly into player bags
- Exact bank-type detection via `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` and `Enum.PlayerInteractionType` (GuildBanker/AccountBanker/CharacterBanker), replacing the previous frame/bag-slot heuristic

### Changed
- Window widened (290px -> 340px) to fit three mode/source buttons per row instead of two
- Wrong-tab validation now also skips the check for the new "Bank -> Bags" direction's write side where applicable, mirroring the existing "Bags -> Bank" behavior
- Tab tracking for Warband/Character banks generalized into a single per-mode table instead of a single Warband-only variable
- All code comments translated to English

---

## 1.0.4

### Fixed
- `GetGuildBankItemInfo`: stack count is now read directly from return value 2 (`itemCount`) instead of being guessed via a heuristic (eliminates risk of misreading the `locked` flag as a count)
- Empty bank slots previously returned a fallback count of `1` instead of `0`
- ElvUI skin was never loaded (`ElvUI_Skin.lua` was missing from the .toc)
- Warband Bank, "Bags -> Bank" mode: Tab 2+ was incorrectly flagged as "wrong tab". `activeWarbandTab` tracking only reacts to `BAG_UPDATE` and doesn't update on a plain tab click without an item change. Tab check is now skipped in Bags mode.

### Removed
- `## Interface: 120005` removed, only 120007 (Midnight 12.0.7) supported now

---

## 1.0.3

### Changed
- Moved `icon.tga` to `Media/` folder
- Split ElvUI skin code into separate `ElvUI_Skin.lua` file
- Improved ElvUI button border visibility with hover effect
- Item slot now uses ElvUI backdrop and border color when ElvUI is active

### Fixed
- Inactive tab buttons now correctly display in gray instead of olive color
- Preview button now shows an error when no item is placed in the slot
- Stack count and size configuration now shown in preview status message
- Race condition fixed: EditBox values are read directly on Split click

---

## 1.0.2

### New
- Bag-to-Bank source mode: deposit items from player bags into Guild Bank or Warband Bank in defined stack sizes
- Stack count field: set an exact number of stacks to create (0 = unlimited)
- Preview now shows configured count x size before splitting

### Changed
- Split scheduling is now fully timer-based and no longer depends on game events firing
- Increased delays: Guild Bank 0.6s, Warband Bank 1.0s for better server reliability

### Fixed
- Warband Bank: splitting stopped after first stack due to missing BAG_UPDATE event in 12.0
- Stack merging issue: used slots are now tracked immediately to prevent merge conflicts

---

## 1.0.1

### New
- Localization system with English (enUS) and German (deDE) support
- ElvUI skin support with proper button and frame handling
- Visible item drop slot with dark background and border
- Wrong bank / wrong tab detection with status message

### Changed
- Window now opens only via `/gbs` command
- Tab buttons: active tab highlighted in gold, inactive tabs in gray
- Stack size field replaced with EditBox for direct keyboard input
- All +/- buttons enlarged for better visibility

### Fixed
- `IsGuildBankTabViewable` removed (no longer exists in 12.0.5)
- `ACCOUNT_BANK_UI_OPENED` replaced with `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`
- `GUILD_BANK_ITEM_LOCK_CHANGED` removed (no longer exists in 12.0.5)
- `GetNormalTexture()` replaced with `GetFontString():SetTextColor()` for tab highlighting

---

## 1.0.0

### New
- Initial release
- Split item stacks in Guild Bank and Warband Bank
- Configurable stack size per slot
- Tab selection (Guild Bank 1-8, Warband Bank 1-5)
- Drag-and-drop item slot
- Preview mode: shows stacks needed vs free slots
- Stop button to abort running split
- `/gbs` slash command to open/close the window
- ESC closes the window
- ElvUI detection and basic skin support
