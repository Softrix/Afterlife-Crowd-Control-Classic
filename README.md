# Afterlife Crowd Control

Crowd control tracking and feedback for **World of Warcraft Classic** — supports **TBC Classic** and **Mists of Pandaria Classic**.

Afterlife monitors crowd control (CC) spells in combat, shows timer bars for active controls, and gives you clear audio and visual feedback when your CC is applied, renewed, counting down, or broken.

## Features

### CC timer bars

- Tracks your crowd control and CC cast by party or raid members on enemy targets.
- Displays timer bars with spell icon, caster name, remaining time, and optional raid target markers.
- Supports diminish returns (DR) tracking on player targets.
- Handles hunter freezing trap placement and effect timers.
- Timer bars are movable (unlock anchors in options), with configurable size, texture, font, growth direction, and layout.

### 3D target frame

- Optional 3D model frame for **your own** active CC, showing the controlled target and a live countdown.
- Captures the target model at cast start so polymorph renewals do not swap the model to a sheep.
- Fully configurable: position, model scale, target name font/size, remaining time font/size, and text position.
- Positioning preview is shown while the options window is open.

### Sounds

- **PvP killing blow voicepacks** — Unreal-style announcer lines on player kills (two soundpacks, escalating streak).
- Optional killing blow sounds on NPCs while questing.
- Plays sounds when you apply, renew, or break your own CC.
- Locale-specific countdown audio at 15 seconds and from 10 down to 1 second remaining.
- Plays an additional **target free** sound when your CC breaks.
- Optional welcome sound when opening the options window.

### Chat announcements

Optional party/raid chat messages for:

- CC applied
- CC renewed
- CC broken (including breaker name when available)
- CC immune
- Optional battleground-wide announces (off by default)

### Visual alerts

- **Show animated popup** — Batman-style graphic when your CC breaks.
- **Flash game border** — red pulsing screen border when your CC breaks.

### Group sync

- Shares CC apply, renew, and break events with party and raid members who also run Afterlife.

## Slash command

```
/afterlife
```

Opens the options window (toggle).

## Options overview

| Setting | Description |
|--------|-------------|
| Addon enabled | Enable or disable Afterlife for this character |
| Options welcome sound | Play a welcome sound when opening options |
| Play CC Sounds | Audio feedback for your CC events and countdown |
| Play PvP killing blow sounds | Announcer voicepack on enemy player kills |
| Play killing blow sounds on NPCs | Same voicepack on NPC kills while questing |
| Soundpack | Choose voicepack 1 or 2 |
| Announce my CC's / Renewed / Breaks / Immune / Interrupts | Chat announcements |
| Announce in battlegrounds | Send announces to the BG channel instead of party/raid only |
| Show animated popup | Animated break graphic |
| Flash game border | Red border flash on break |
| Display raid markers | Raid icons on timer bars |
| Enable 3D target frame | Toggle the 3D model frame |
| Timer bar settings | Height, width, growth, texture, font, and layout |
| 3D frame settings | Fonts, sizes, model scale, and text position |
| Reset | Restore all settings to defaults |

Use **Unlock Timers** in the options window to drag timer bar anchors into place, then **Lock Timers** when finished.

## Supported locales

- English (enUS)
- German (deDE)
- Spanish (esES)
- French (frFR)
- Russian (ruRU)
- Chinese Simplified (zhCN)
- Chinese Traditional (zhTW)

Countdown and break sounds use locale-specific audio files where available.

## Installation

1. Copy the `Afterlife` folder into `World of Warcraft\_anniversary_\Interface\AddOns\` (or your client's `Interface\AddOns\` path).
2. Enable **Afterlife Crowd Control** on the character select AddOns screen.
3. `/reload` or log in, then type `/afterlife` to configure.

## Author

**Michael Boyle** (Codermik)

- Twitch: [twitch.tv/codermik](https://www.twitch.tv/codermik)
- Discord: [discord.gg/R6EkZ94TKK](https://discord.gg/R6EkZ94TKK)

© Copyright Michael Boyle. All Rights Reserved.
