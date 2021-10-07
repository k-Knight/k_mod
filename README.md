# AimAssist Script

### About

This script works on all games (unless character is not humanoid)
Feel free to edit any of the settings inside the script.

Control options (default):
- `ToggleSpeedKey` - The key that turns speed boost on/off (default: `CTRL + SHIFT + F8`)
- `IncreseBoostKey` - The key increases the boost (default: `CTRL + SHIFT + ]`)
- `DecreseBoostKey` - The key decreases the boost (default: `CTRL + SHIFT + [`)

By editing this script values one is able to customize: input keys that trigger the script functions, the amount of boost that is gained/lost upon change the its amount

### Settings of the script

```lua
local ToggleSpeedKey = Enum.KeyCode.F8 -- The key that turns speed boost on/off (CTRL + SHIFT + <key>)
local IncreseBoostKey = Enum.KeyCode.RightBracket -- The key increases the boost (CTRL + SHIFT + <key>)
local DecreseBoostKey = Enum.KeyCode.LeftBracket -- The key decreases the boost (CTRL + SHIFT + <key>)
local BoostStep = 0.25 -- How much the speed boost changes
```

## Script (With FOV Circle)

Load the script by using the code below or by copying it from [here](https://raw.githubusercontent.com/k-Knight/SpeedBoost-Script/main/SpeedBoost%20Script.lua).
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/k-Knight/SpeedBoost-Script/main/SpeedBoost%20Script.lua"))()
```