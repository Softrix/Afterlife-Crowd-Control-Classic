# NaturTimers-1.0

Lightweight timer bar library for WoW Classic Era / TBC / Retail.

**Author:** Codermik — [Discord](https://discord.gg/R6EkZ94TKK)

## Dependencies

- [LibStub](https://www.wowace.com/projects/libstub) (included via `lib.xml`)

## Embedding in an addon

1. Copy the `lib/LibStub` and `lib/NaturTimers-1.0` folders into your addon.
2. Add one of the following to your `.toc` **before** any scripts that use the library:

```
lib\embed.xml
```

Or load only NaturTimers:

```
lib\NaturTimers-1.0\embed.xml
```

Or load manually (LibStub must load first):

```
lib\LibStub\LibStub.lua
lib\NaturTimers-1.0\NaturTimers-1.0.lua
```

3. Acquire the library in your addon code:

```lua
local NT = LibStub:GetLibrary("NaturTimers-1.0")
-- or use the global alias:
local NT = NaturTimers
```

## Quick start

```lua
local NT = LibStub:GetLibrary("NaturTimers-1.0")

NT:CreateGroup("MyAddon_Timers", {
  width = 200,
  height = 18,
  growthDirection = "DOWN",
})

NT:StartTimer("MyAddon_Timers", "example", 10, {
  label = "Example",
  reverse = true,
})
```

Prefix group names with your addon name (e.g. `MyAddon_Timers`) to avoid frame name collisions when multiple addons embed this library.

## API

See the header comment in `NaturTimers-1.0.lua` for the full API:

- `CreateGroup`, `StartTimer`, `StopTimer`, `StopAllTimers`
- `BindGroupToUnitAuras` / `UnbindGroupFromUnitAuras`
- `BindGroupToCooldowns` / `UnbindGroupFromCooldowns`
- Group options: sorting, growth direction, fonts, textures, anchors

## Versioning

Registered with LibStub as `NaturTimers-1.0`, minor version `1`.

When releasing updates, bump the minor number in `NaturTimers-1.0.lua`. LibStub keeps the newest loaded copy and skips older embeds automatically.

## Attribution

If you use this library, include credit such as:

> Powered by NaturTimers, created by Codermik. Discord: https://discord.gg/R6EkZ94TKK

## Files

| File | Purpose |
|------|---------|
| `NaturTimers-1.0.lua` | Library implementation |
| `lib.xml` | Loads LibStub and the library |
| `embed.xml` | Include this from your addon `.toc` |
| `README.md` | This file |
