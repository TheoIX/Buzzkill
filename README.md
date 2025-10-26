BuzzKill (WoW 1.12)

Auto‑removes selected buffs from your character as soon as they appear. Built for Turtle/Vanilla 1.12 clients. Includes a simple in‑game UI, per‑user profiles, and a quiet mode.

What it does

Shows a categorized list of common buffs (Paladin, Priest, Mage, Druid, Warrior, Shaman, Warlock, Scrolls).

You check the buffs you do not want. When any checked buff appears on you, BuzzKill cancels it immediately.

Scans on login and whenever your auras change (throttled for performance).

Features

Simple UI: Two‑column checkbox list with class headers.

Two slash commands: /buzzkill and /bk to open/close the UI.

Silent by default: Chat messages are suppressed unless you enable them.

Notify toggle: /bknotify to turn chat messages ON/OFF, or view status.

Profiles: Save/activate/delete named profiles. The built‑in profile “Standard” is protected (can’t overwrite or delete).

Paladin support: Includes Heathen’s Light in the Paladin category.

Safe removals: Cancels buffs by index, iterating downward to avoid skipping; scan interval is throttled to reduce spam.

Installation

Create a folder:

Interface/AddOns/Buzzkill

Put the addon files in that folder:

Buzzkill.toc

Buzzkill.lua

Restart the game client or reload the UI.

Usage
Open the UI

/buzzkill or /bk

Mark unwanted buffs

Check the boxes next to any buffs you want automatically removed.

Close the window; settings are saved immediately.

Toggle notifications

/bknotify — toggles notifications ON/OFF.

/bknotify on or /bknotify enable — enable messages.

/bknotify off or /bknotify disable — disable messages.

/bknotify status — show the current state without changing it.

Default: OFF (silent).

Profiles

Type a profile name in the text box and click Save to store your current checkboxes.

Click Activate to switch to a saved profile.

Click Delete to remove a saved profile.

The profile “Standard” is built‑in; it cannot be overwritten or deleted.

Buff categories included

Scrolls

Agility, Intellect, Protection, Spirit, Stamina, Strength

Paladin

Blessing of Salvation, Greater Blessing of Salvation

Blessing of Wisdom, Greater Blessing of Wisdom

Blessing of Might, Greater Blessing of Might

Blessing of Kings, Greater Blessing of Kings

Blessing of Light, Greater Blessing of Light

Blessing of Sanctuary, Greater Blessing of Sanctuary

Daybreak, Holy Power, Heathen’s Light

Priest

Power Word: Fortitude, Prayer of Fortitude

Shadow Protection, Prayer of Shadow Protection

Divine Spirit, Prayer of Spirit

Renew, Inspiration

Warlock

Detect Invisibility, Detect Greater Invisibility, Detect Lesser Invisibility, Unending Breath

Mage

Arcane Intellect, Arcane Brilliance, Dampen Magic, Amplify Magic

Druid

Mark of the Wild, Gift of the Wild, Thorns, Rejuvenation, Regrowth, Blessing of the Claw

Warrior

Battle Shout

Shaman

Spirit Link, Healing Way, Ancestral Fortitude, Water Walking, Water Breathing, Totemic Power

Performance & behavior

Scans on PLAYER_LOGIN and PLAYER_AURAS_CHANGED with a 0.2s throttle.

Removes only your buffs (not party/raid members).

Uses tooltip reading to match the buff name shown on your character.

Troubleshooting

UI not opening? Ensure the files are in Interface/AddOns/Buzzkill/ and the addon is enabled at the character select screen.

A buff isn’t being removed? Make sure its name is checked and spelled exactly as it appears in your client.

Duplicate buffs with the same name/icon (e.g., Heathen’s Light)? Removal is name‑based; if multiple auras share the same name on you, checking that name removes any that match.

Too much chat spam? Use /bknotify off (default is OFF).

Changelog

1.0.0

Initial release for 1.12 clients.

English UI and messages.

Added Paladin buff Heathen’s Light.

Added /bknotify (silent by default).

Safer scan/removal loop and throttle.
