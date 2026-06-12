# Afterlife — Implementation Status

## Core

- **CC spell database** (`spells.lua`) — TBC and MoP Classic CC spells by class, with duration, instant/breakable flags, DR families, hunter trap handling
- **Combat log tracking** — `SPELL_CAST_START`, `SPELL_CAST_FAILED`, `SPELL_CAST_SUCCESS`, `SPELL_AURA_APPLIED`, `SPELL_AURA_REFRESH`, `SPELL_AURA_REMOVED`, `SPELL_AURA_BROKEN`, `SPELL_AURA_BROKEN_SPELL`, `SPELL_MISSED`, `UNIT_DIED` / `PARTY_KILL`
- **CC registry** — per mob+spell entries with caster, duration, raid icon, breakable flag, display unit for 3D frame
- **Instant CC** (Frost Nova, Psychic Scream, etc.) — tracked via `SPELL_AURA_APPLIED` only (not `SPELL_CAST_SUCCESS`) with nil name/guid guards
- **Natural expiry** — expired CC triggers break handling (sound, popup, border flash, announce) via `PurgeExpiredCC`
- **Per-character enable** — addon can be turned off per character
- **Zone enter cleanup** — clears your CC state on `PLAYER_ENTERING_WORLD`
- **Debug mode** — combat log debug prints when enabled

## Timer bars (NaturTimers + LibSharedMedia)

- Timer bars for your CC and party/raid member CC on enemies
- Spell icon, caster name, remaining time, reverse countdown
- Optional **raid target markers** on timer bars (`showRaidIcons`)
- **DR timers** on player targets (halving duration, DR window bar on break)
- **Hunter freezing trap** — placement pending timer + effect CC timer
- Configurable height, width, growth direction, texture, font, font size, right-justify time
- **Unlock / Lock Timers** — draggable anchors, position saved
- **Test** button — sample timer bars + broken free popup preview

## 3D target frame

- Optional 3D model frame for **your own** active CC only
- Model captured at cast start; renewals update name/timer without swapping model (e.g. polymorph)
- Live remaining time on the frame
- Per-character settings: position, model scale, target/timer fonts and sizes, text gap
- Positioning preview while options window is open; re-enables correctly when toggling 3D back on
- Clears when CC ends, trap pending expires, or cast fails with no active CC

## Sounds

- **PvP killing blow voicepacks** — `voicepack1` and `voicepack2` cycle on `PARTY_KILL` (first blood → godlike; resets after 60s idle)
- Optional NPC killing blow sounds while questing (requires PvP killing blow sounds enabled)
- Apply / renew / break sounds for your own CC (`applied.ogg`, `renewed.ogg`, `ccbreak.ogg`)
- Locale-specific countdown: **15s**, **10–1** (`assets/sounds/{locale}/`)
- **Target free** sound on break (`targetfree`)
- **Options welcome sound** on opening options (configurable)
- `Afterlife:PlayLocaleSound(name)` API

## Chat announcements

- CC applied, renewed, broken (with breaker name + spell when available), immune/resisted
- Solo: messages to default chat frame (no `{rt1}` raid icon tokens)
- Party / raid: `SendChatMessage` with raid icon prefixes when target is marked
- Optional **Announce in battlegrounds** — sends to `BATTLEGROUND` / `INSTANCE_CHAT` instead of party or raid only
- Separate toggles for apply, renew, break, immune, interrupts, and battleground-wide announces

## Visual alerts

- **Show animated popup** — `brokenfree` on your CC break; `immune` on CC immune (`missType == IMMUNE`, when announce immune is on)
- **Flash game border** — red pulsing border on your CC break
- Popup assets: `immune.tga`, `brokenfree.tga`

## Group sync

- Addon message prefix `AfterlifeCC` — `ACCA` (apply), `ACCR` (renew), `ACCF` (break)
- Party and raid channel sync between Afterlife users
- Roster gate — only syncs CC from group members you recognize

## Options UI (`/afterlife`)

- Addon enabled (per character)
- Options welcome sound
- Debug mode
- Play CC sounds
- Play PvP killing blow sounds / NPC questing kills / soundpack selection
- Announce apply / renewed / breaks / immune / interrupts
- Show animated popup
- Flash game border
- Display raid markers
- Enable 3D target frame (per character)
- Timer bar settings (height, width, growth, texture, font, layout)
- 3D frame settings (fonts, sizes, model scale, text gap)
- **Reset** — restores global + per-character defaults (including 3D frame)
- Show anchors (unlock timer positions)

## Locales

- enUS, deDE, esES, frFR, ruRU, zhCN, zhTW
- UI strings, announce messages, options labels, load message
- Locale-specific sound folders for countdown and break audio - need to implement other languages, only english exists atm.

## Libraries & assets

- LibStub, CallbackHandler, LibSharedMedia-3.0, NaturTimers-1.0
- Graphics, sounds, README

---

## Known gaps / not implemented

- **Immune popup** — only fires when **Announce Immune** is enabled (coupled to that option)
- **3D frame with multiple own CCs** — casting CC on a second target while one is active changes the 3D target (`GetCCByCaster` returns one arbitrary entry); behaviour undecided

