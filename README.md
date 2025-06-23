# AttuneHelper

A simple addon to add some QOL for attunements

## Features

- Automatic gear swapping for attunement quests
- Mini and full UI modes
- Customizable weapon type controls
- Bag cache optimization for better performance
- Theme customization options
- Slot blacklisting system

## Slash Commands

### Main Commands
- `/ath` - Main command with various subcommands
- `/ath help` - Show all available commands
- `/ath show` - Show AttuneHelper frame
- `/ath hide` - Hide AttuneHelper frame
- `/ath reset` - Reset frame positions to center

### Auto-Equip Controls
- `/ath toggle` - Toggle auto-equip after combat
- `/ahtoggle` - Alias for toggle auto-equip
- `/ath equip <slot>` - Manually equip items for specific slot

### Display Mode
- `/ath togglemini` - Toggle between mini and full UI modes

### Weapon Type Controls
- `/ath weapons` - Show current weapon type settings
- `/ath mh1h` - Toggle MainHand 1H weapons
- `/ath mh2h` - Toggle MainHand 2H weapons  
- `/ath oh1h` - Toggle OffHand 1H weapons
- `/ath oh2h` - Toggle OffHand 2H weapons
- `/ath ohshield` - Toggle OffHand shields
- `/ath ohhold` - Toggle OffHand holdables

### Item Management
- `/ahset <itemlink> [slot]` - Add item to equipment set
- `/ahset remove <itemlink>` - Remove item from equipment set
- `/ahsetlist` - List all items in equipment set
- `/ahsetall` - Add all currently equipped items to set
- `/ahignore <itemlink>` - Toggle item ignore status
- `/ahignorelist` - List all ignored items

### Slot Blacklisting
- `/ath blacklist <slot>` - Toggle slot blacklist
- `/ahbl <slot>` - Short version of slot blacklist
- `/ahbll` - List all blacklisted slots

### Performance & Debug
- `/ath memory` - Show memory usage statistics
- `/ath cleanup` - Force memory cleanup

### UI Controls
- `/ath hidede` - Toggle disenchant button visibility

### Legacy Commands
- `/ah2h` - Toggle 2H weapon equipping (legacy)
- `/AHIgnore` - Legacy ignore command
- `/AHSet` - Legacy set command

## Slot Keywords

When using slot-specific commands, you can use these keywords:
- `mh`, `mainhand` - MainHandSlot
- `oh`, `offhand` - SecondaryHandSlot  
- `head` - HeadSlot
- `neck` - NeckSlot
- `shoulder` - ShoulderSlot
- `back` - BackSlot
- `chest` - ChestSlot
- `wrist` - WristSlot
- `hands` - HandsSlot
- `waist` - WaistSlot
- `legs`, `pants` - LegsSlot
- `feet` - FeetSlot
- `finger1`, `ring1` - Finger0Slot
- `finger2`, `ring2` - Finger1Slot
- `trinket1` - Trinket0Slot
- `trinket2` - Trinket1Slot
- `ranged` - RangedSlot
