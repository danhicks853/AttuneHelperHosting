# AttuneHelper Addon Documentation

AttuneHelper is a World of Warcraft addon designed to assist players with managing and equipping "attunable" items (items that can be leveled up via a custom server mechanic) and their main "AHSet" gear.

## Features

* Automated equipping of attunable items for leveling.
* Fallback to equipping main AHSet gear.
* Item blacklisting per slot.
* BoE (Bind on Equip) and Mythic item handling policies for auto-equipping.
* Forge type filtering for auto-equipping.
* Quick vendoring of "attuned" (fully leveled) or unwanted items.
* Inventory sorting helper for disenchanting Mythic items.
* Customizable UI elements.

## Slash Commands

All commands are case-insensitive.

### Main Control: `/ath` or `/attunehelper`

This is the primary command for interacting with the AttuneHelper UI and core functions.
### Item Lists Management

* `/AHIgnore <itemlink>`
    * **Description:** Toggles the specified item's presence in the AHIgnoreList. Ignored items are protected from certain addon actions like automatic vendoring and may be handled differently by sorting.
    * **Usage:** Drag an item from your inventory onto the chat input line after typing the command, then press Enter.
    * **Example:** `/AHIgnore [Item Link]`
    * **Feedback:** Prints a confirmation message indicating whether the item is now ignored or no longer ignored.

* `/AHSet <itemlink>`
    * **Description:** Toggles the specified item's presence in the AHSetList. AHSet items are considered your primary, fully-powered gear. The addon will prioritize equipping items for leveling over AHSet items, and use AHSet items as a fallback.
    * **Restrictions:** Only allows armor, jewelry, and specific non-weapon ranged slot items (wands, relics, thrown) to be added.
    * **Usage:** Drag an item from your inventory onto the chat input line after typing the command, then press Enter.
    * **Example:** `/AHSet [Item Link]`
    * **Feedback:** Prints a confirmation message indicating whether the item has been added to or removed from the set items.

* `/ahignorelist`
    * **Description:** Displays a list of all items currently in your AHIgnoreList in the chat window.

* `/ahsetlist`
    * **Description:** Displays a list of all items currently in your AHSetList in the chat window.

### Equipment Slot Blacklisting

* `/ahbl <slot_keyword>`
    * **Description:** Toggles the blacklist status for a specified equipment slot. If a slot is blacklisted, AttuneHelper will not attempt to auto-equip items into it.
    * **Usage:** `/ahbl keyword`
    * **Valid Keywords:**
        * `head`, `neck`, `shoulder`, `back`, `chest`
        * `wrist`, `hands`, `waist`, `legs` (or `pants`)
        * `feet`, `finger1` (or `ring1`), `finger2` (or `ring2`)
        * `trinket1`, `trinket2`, `mh` (or `mainhand`)
        * `oh` (or `offhand`), `ranged`
    * **Example:** `/ahbl head` (toggles blacklisting for the HeadSlot)
    * **Feedback:** Prints a confirmation message and updates the corresponding checkbox in the addon's options panel.

* `/ahbll`
    * **Description:** Displays a list of all currently blacklisted equipment slots in the chat window.

### Settings Toggles

* `/ahtoggle`
    * **Description:** Toggles the "Auto Equip Attunable After Combat" setting. If enabled, the addon will attempt to run its equipping logic automatically after you leave combat and your health/mana regenerates.
    * **Feedback:** Prints a confirmation message and updates the corresponding checkbox in the addon's options panel.

## Configuration Panel

AttuneHelper also provides a graphical configuration panel within the game's Interface Options (usually accessible via Escape > Interface > AddOns > AttuneHelper). Here you can configure:

* **Blacklisting:** Checkboxes for each equipment slot.
* **General Options:**
    * Sell Attuned Mythic Gear?
    * Auto Equip Attunable After Combat
    * Do Not Sell BoE Items
    * Limit Selling to 12 Items?
    * Disable Auto-Equip Mythic BoE (for items that will bind on equip)
    * Equip BoE Bountied Items (for items that are BoE, have a bounty, and the setting is enabled)
* **Forge Equipping:** Select which item forge levels (Base, Titanforged, Warforged, Lightforged) are permissible for auto-equipping.
* **Appearance:**
    * Background Style for the main window.
    * Background Color and Transparency.
    * Button Theme for the main window buttons.

Changes made in the options panel are saved automatically.

## Dependencies

- [SynastriaCoreLib](https://github.com/imevul/SynastriaCoreLib/releases) (Optional)
