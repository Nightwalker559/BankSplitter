# BankSplitter

Split item stacks in the Guild Bank, Warband Bank and Character Bank, move items between your bags and any of these banks, and transfer a saved list of items in one click.

BankSplitter works with Blizzard's default UI and with ElvUI.

## Features

- **Split stacks in place:** pick an item, a stack size and how many stacks you want (or all of them), and BankSplitter creates them in the bank tab the item is in.
- **Bags to bank, bank to bags:** the same, but depositing items from your bags in a chosen stack size, or withdrawing split stacks into your bags.
- **Three banks:** Guild Bank (8 tabs), Warband Bank (5 tabs) and Character Bank (6 tabs). The window shows only the tabs you actually have, and it follows the bank and the tab you open (also in Baganator's bank window). With a bank replacement addon (Baganator, Bagnon, Combuctor, BetterBags, ArkInventory, AdiBags) loaded there is an **All** chip that works on every accessible tab; Blizzard's own bank has no such view.
- **Transfer list:** an account-wide list of items that is moved as whole stacks, deposit or withdraw. Items the target bank doesn't accept are skipped and counted, and put back where they were. Crafting ranks are separate entries and show their quality icon; gear is matched by item level.
- **Live preview:** while you set up a split you see how many stacks and slots it needs and how many are free, and why it can't start (no item, no bank open, wrong tab).
- **Safe runs:** every step waits until the server has confirmed the previous one, so no gaps appear between the new stacks. A run stops by itself if the bank is closed, and an item the bank refuses is put back.
- **One window, two tabs:** "Split" and "Transfer list", with Blizzard's own dropdowns and tab strip.
- **Options** in the game's Settings panel: open the window together with a bank, close it with the bank, remember the last selection, window scale.
- **Languages:** English and German.

## Usage

Open the window with `/banksplitter` (or `/gbs`), or let it open with the bank (see Options).

### Split

1. Open a bank. Pick the bank and the source in the bar at the top: **Bank -> Bank** (split inside the bank), **Bags -> Bank** or **Bank -> Bags**.
2. Pick the tab. It follows the tab you click in the bank window. **All** only exists with a bank replacement addon.
3. Drag the item into the slot, set **Count** (0 = all) and **Size**.
4. Check the preview line, then click **Split!**. **Stop** ends a run.

### Transfer list

1. Open the **Transfer list** tab and drag items onto the drop target. **x** removes an entry.
2. Pick the bank, the direction (**Bags -> Bank** or **Bank -> Bags**) and the tab.
3. Click **Transfer!**.

### Commands

| Command | What it does |
| --- | --- |
| `/banksplitter` | Open or close the window |
| `/banksplitter list` | Open the window on the transfer list (or close it) |
| `/banksplitter config` | Open the options |
| `/banksplitter bank` | Print which bank and tab BankSplitter sees as open (for bug reports) |
| `/gbs` | Same as `/banksplitter` |

## Options

AddOns > BankSplitter in the game's Settings (or `/banksplitter config`).

| Option | Default |
| --- | --- |
| Open with the Guild / Warband / Character Bank (on the tab you used last) | off |
| Bank selection follows the open bank | on |
| Close with the bank (only windows that opened automatically) | on |
| Remember last selection | on |
| Window scale | 100 % |
| Chat message on login | on |

## Good to know

- Items are matched by item ID, plus item level for weapons and armor. Crafting quality ranks have their own IDs, so only the exact item in the slot is touched.
- The Guild Bank only keeps the visible tab up to date. With **All** selected, BankSplitter asks the server for every tab first.
- Baganator is read directly: its bank and guild bank views decide which bank and tab are open, and its all-tabs view selects **All**. Other bank replacement addons are not followed; pick the tab in BankSplitter yourself there (the wrong-tab check is skipped for them).

## Compatibility

- World of Warcraft Retail (Interface 12.1.5)
- Optional: ElvUI

## Upgrading from GuildBankSplitter

The addon folder is now `BankSplitter` (it was `GuildBankSplitter`). Delete the old `Interface\AddOns\GuildBankSplitter` folder. To keep your transfer list and options, close the game and copy `WTF\Account\<account>\SavedVariables\GuildBankSplitter.lua` to `BankSplitter.lua` in the same folder.

## Changelog

See the [changelog](https://github.com/Nightwalker559/BankSplitter/blob/main/CHANGELOG.md).

## Bugs and feedback

Please report problems as a [GitHub issue](https://github.com/Nightwalker559/BankSplitter/issues).

## License

[MIT](https://github.com/Nightwalker559/BankSplitter/blob/main/LICENSE.md), copyright Nightwalker559.
