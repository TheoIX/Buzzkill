==============================
BUZZKILL (WoW 1.12)
===================

Auto-removes selected buffs from YOUR character as soon as they appear.
Built for Vanilla/Turtle 1.12. Includes an in-game UI, profiles, and a quiet mode.

---

## WHAT IT DOES

* Shows a categorized list of common buffs (Paladin, Priest, Mage, Druid,
  Warrior, Shaman, Warlock, Scrolls).
* You check the buffs you do NOT want. If a checked buff appears on you,
  BuzzKill cancels it immediately.
* Scans on login and whenever your auras change (throttled for performance).

---

## FEATURES

* Simple two-column checkbox UI with class headers.
* Slash commands to open/close the UI: `/buzzkill`, `/bk`.
* Silent by default (chat messages OFF until you enable them).
* Notification toggle: `/bknotify` to turn chat messages ON/OFF or view status.
* Profiles: save / activate / delete named profiles.
  The built-in profile "Standard" is protected (cannot overwrite or delete).
* Paladin support includes "Heathen's Light".
* Safe removals: cancels by buff index and iterates downward to avoid skips;
  aura scanning is throttled.

---

## INSTALLATION

1. Create a folder:

```
Interface/AddOns/Buzzkill
```

2. Put these files in that folder:

```
Buzzkill.lua
Buzzkill.toc
```

3. Restart the game client or reload the UI.

---

## USAGE

OPEN THE UI

```
/buzzkill
/bk
```

MARK UNWANTED BUFFS

* Check the boxes next to any buffs you want automatically removed.
* Close the window; settings are saved immediately.

TOGGLE NOTIFICATIONS (silent by default)

```
/bknotify           # toggle ON/OFF
/bknotify on        # enable messages
/bknotify off       # disable messages
/bknotify enable    # same as on
/bknotify disable   # same as off
/bknotify status    # show current state
```

PROFILES

* Type a profile name in the text box and click "Save" to store your current
  checkboxes.
* Click "Activate" to switch to a saved profile.
* Click "Delete" to remove a saved profile.
* The profile "Standard" is built-in; it cannot be overwritten or deleted.

---

## BUFF CATEGORIES INCLUDED

SCROLLS

* Agility, Intellect, Protection, Spirit, Stamina, Strength

PALADIN

* Blessing of Salvation, Greater Blessing of Salvation
* Blessing of Wisdom, Greater Blessing of Wisdom
* Blessing of Might, Greater Blessing of Might
* Blessing of Kings, Greater Blessing of Kings
* Blessing of Light, Greater Blessing of Light
* Blessing of Sanctuary, Greater Blessing of Sanctuary
* Daybreak, Holy Power, Heathen's Light

PRIEST

* Power Word: Fortitude, Prayer of Fortitude
* Shadow Protection, Prayer of Shadow Protection
* Divine Spirit, Prayer of Spirit
* Renew, Inspiration

WARLOCK

* Detect Invisibility, Detect Greater Invisibility, Detect Lesser Invisibility,
  Unending Breath

MAGE

* Arcane Intellect, Arcane Brilliance, Dampen Magic, Amplify Magic

DRUID

* Mark of the Wild, Gift of the Wild, Thorns, Rejuvenation, Regrowth,
  Blessing of the Claw

WARRIOR

* Battle Shout

SHAMAN

* Spirit Link, Healing Way, Ancestral Fortitude, Water Walking, Water Breathing,
  Totemic Power

---

## PERFORMANCE & BEHAVIOR

* Scans on `PLAYER_LOGIN` and `PLAYER_AURAS_CHANGED` with a 0.2s throttle.
* Removes only YOUR buffs (not party/raid members).
* Uses tooltip text to match the buff name shown on your character.

---

## TROUBLESHOOTING

* UI not opening? Ensure files are in `Interface/AddOns/Buzzkill/` and the addon
  is enabled at the character select screen.
* A buff isn’t being removed? Make sure its name is checked and spelled exactly
  as it appears in your client.
* Duplicate buffs with the same name/icon (e.g. Heathen's Light)? Removal is
  name-based; checking that name removes any that match.
* Too much chat spam? Use `/bknotify off` (default is OFF).

---

## CHANGELOG

1.0.0

* Initial release for 1.12 clients.
* English UI and messages.
* Added Paladin buff Heathen's Light.
* Added `/bknotify` (silent by default).
* Safer scan/removal loop and throttle.
