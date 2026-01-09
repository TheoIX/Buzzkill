# BuzzKill (Turtle WoW / Vanilla 1.12)

BuzzKill is a lightweight buff manager that:
- **Instantly cancels** buffs you never want (Always Remove)
- **Trims a priority list** only when you exceed a configurable buff threshold (Remove at Buff Cap)
- Lets you pick buffs from your **current active buffs** so you don’t have to guess IDs

> Default cap threshold is **31** (auto-set on fresh installs and auto-repaired if invalid). :contentReference[oaicite:0]{index=0}

---

## Install
1. Create folder: `Interface\AddOns\BuzzKill\`
2. Put these inside:
   - `BuzzKill.toc`
   - `BuzzKill.lua`
3. Restart WoW (or `/reload`).

---

## Open the UI
Type: `/buzzkill`

---

## How it works

### Always Remove (instant)
Anything in **Always Remove** is cancelled as soon as it appears on you.

### Remove at Buff Cap (priority)
When your total buffs **exceed your max** (default 31), BuzzKill removes buffs from the **Cap List** in order (top = highest priority). :contentReference[oaicite:1]{index=1}  
Use the **Up / Down** buttons under the cap list to reorder priority.

BuzzKill removes **one matching buff per aura change** (safe + lightweight).

---

## UI usage
- **Active Buffs (right panel):** click a buff to auto-fill **Buff ID** and **Name**
- **Add Always:** add the typed/selected buff to Always Remove
- **Add Cap List:** add the typed/selected buff to Remove at Buff Cap list
- **Remove Selected:** removes the selected entry (from whichever list you selected)
- **Refresh Active:** re-scan your currently active buffs
- **Debug chat messages:** prints removal messages to chat

> A buff can only be in **one** list at a time. Adding it to one list removes it from the other. :contentReference[oaicite:2]{index=2}

---

## Slash commands
- `/buzzkill` — toggle UI
- `/buzzkill ui` — toggle UI
- `/buzzkill debug` — toggle debug prints
- `/buzzkill max <1-63>` — set cap-trim threshold (default 31)
- `/buzzkill add <id> [name]` — add to Always Remove (manual)
- `/buzzkill addcap <id> [name]` — add to Cap List (manual)
- `/buzzkill list` — print Always Remove list
- `/buzzkill listcap` — print Cap List (priority order)

### Print current max (example)
```lua
/run DEFAULT_CHAT_FRAME:AddMessage("BuzzKillDB.maxBuffs = "..tostring(BuzzKillDB and BuzzKillDB.maxBuffs))
