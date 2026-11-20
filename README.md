# BankSplitter

Split item stacks in your banks, move items between bags and banks, and transfer a saved item list in one click. For the Guild Bank, the Warband Bank and the Character Bank.

For World of Warcraft Retail (12.1.5). English and German. Optional: ElvUI skin, Baganator.

**Author:** Nightwalker559 · **License:** MIT with AI restriction

---

## Features

- **Split stacks in place:** pick an item, a stack size and how many stacks (or all). They are built in the bank tab the item is in.
- **Bags <-> Bank:** deposit items from your bags in a chosen stack size, or withdraw split stacks into your bags.
- **Transfer list:** an account-wide item list you move as whole stacks in either direction. Items the target bank refuses are skipped and put back.
- **Live preview** of stacks and slots needed, free slots and why a run cannot start.
- **Safe runs:** every step waits for the server, closing the bank stops the run and nothing stays on your cursor.
- **Follows your bank:** the window picks the bank you opened and the tab you click.

## Quick start

1. Open a bank and type `/banksplitter`.
2. Choose the **bank** and the **source**: Bank -> Bank, Bags -> Bank or Bank -> Bags.
3. **Split tab:** drag an item into the slot, set **Count** (0 = all) and **Size**, check the preview, click **Split!**.
4. **Transfer list tab:** drag items onto the drop target, pick the direction, click **Transfer!**.

**Stop** ends a run at any time.

## Commands and options

| Command | What it does |
| --- | --- |
| `/banksplitter`, `/gbs` | Open or close the window |
| `/banksplitter list` | Open the window on the transfer list |
| `/banksplitter config` | Open the options (AddOns > BankSplitter in the game's Settings) |
| `/banksplitter bank` | Print which bank and tab BankSplitter sees (for bug reports) |

Options: open with the Guild / Warband / Character Bank, selection follows the open bank, close with the bank, remember last selection, window scale, chat message on login.

## Good to know

- Items are matched by item ID, plus item level for weapons and armor. Crafting ranks have their own IDs, so only the exact item in the slot is touched.
- **All tabs** only exists with a bank replacement addon (Baganator, Bagnon, Combuctor, BetterBags, ArkInventory, AdiBags). Baganator is read directly; with the others, pick the tab in BankSplitter yourself.
- The Guild Bank only keeps its visible tab up to date, so with **All** selected BankSplitter asks the server for every tab first.
- **Upgrading from GuildBankSplitter:** delete `Interface\AddOns\GuildBankSplitter`. To keep your list and options, close the game and copy `WTF\Account\<account>\SavedVariables\GuildBankSplitter.lua` to `BankSplitter.lua` in the same folder.

---

See the [changelog](https://github.com/Nightwalker559/BankSplitter/blob/main/CHANGELOG.md) for the version history.

## Feedback

Found a bug or have an idea? [Open an issue on GitHub](https://github.com/Nightwalker559/BankSplitter/issues).

## License

MIT with AI restriction (no use for AI or machine learning), see [LICENSE.md](https://github.com/Nightwalker559/BankSplitter/blob/main/LICENSE.md).
