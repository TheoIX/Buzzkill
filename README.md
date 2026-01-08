# BuzzKill

BuzzKill is a tiny Turtle WoW (1.12) addon that **automatically cancels specific buffs** the moment they appear.

## Install
1. Copy the folder into:
   `Interface\AddOns\BuzzKill\`
2. Make sure these files exist:
   - `BuzzKill.toc`
   - `BuzzKill.lua`
3. Restart WoW (or `/reload`).

## How to Use
- Type **`/buzzkill`** to open the options UI.

### Add a buff to Always Remove (UI)
1. In the **Active Buffs** list (right side), click the buff you want to kill.
2. Press **Add**.
3. From now on, BuzzKill will cancel it automatically.

### Remove a buff from Always Remove (UI)
1. Click the buff in the **Always Remove** list (left side).
2. Press **Remove Selected**.

### Helpful Buttons
- **Refresh Active** — re-scan your current buffs.

## Commands
- `/buzzkill` — toggle the UI
- `/buzzkill ui` — toggle the UI
- `/buzzkill list` — print your always-remove list to chat
- `/buzzkill add <id> [name]` — add a buff by ID
- `/buzzkill del <id>` — remove a buff by ID
- `/buzzkill debug` — toggle debug chat messages

## Notes
- BuzzKill removes **one matching buff per aura change** (safe + lightweight).
- Buff IDs come from your current buffs (use the UI’s Active Buffs list), or add manually by ID.

## Saved Variables
- `BuzzKillDB` (SavedVariablesPerCharacter by default)
  - `BuzzKillDB.list` — buffs to cancel
  - `BuzzKillDB.debug` — debug toggle
