# 🌟 AttuneHelper

Your one-stop World of Warcraft addon for managing attunable gear—items that **level up**, **AHSet** a powerful gear preset to automagicly set your gearset back to main gear as long as you set it with /ahset ItemLink, slot blacklisting, forge-level filtering, quick vendoring, and a fully customizable UI!

---

## 📖 Overview

AttuneHelper streamlines your loot life by automatically:

1. Equipping items you’re **currently leveling** (“attunable” items)  
2. Falling back to your **AHSet** (your favorite, fully-powered gear)  
3. Enforcing slot blacklists, BoE/Mythic policies, and **forge**-level filters  
4. Quick-selling fully attuned or unwanted items at a vendor  
5. Sorting your bags to isolate Mythic items for disenchanting  

Plus—choose from multiple backgrounds, colors, button themes, and even a **Mini Mode** toolbar! 🎨

---

## 📦 Installation

1. Download the `AttuneHelper` addon folder.  
2. Copy it into your WoW AddOns directory:

   ```
   Synastria/Interface/AddOns/
   ```

3. Launch (or `/reload`) WoW.    

---

## 🚀 Key Features

- ⚔️ **Automated Attunement**  
  - Finds bag items with attunement progress < 100% and equips them in priority order.  
  - Honors “Equip New Affixes Only” if you only want **fresh variants**.  

- 🛡️ **AHSet Fallback**  
  - Use `/AHSet <itemlink> [slot]` to designate your main gear.  

- 🚫 **Slot Blacklisting**  
  - Prevent auto-equip in any slot via `/ahbl <slot>` or the UI checkboxes.  

- 🔥 **Forge Level Filtering**  
  - Allow/disallow Base, Titanforged, Warforged, Lightforged items.  

- 🏷️ **BoE & Mythic Policies**  
  - Control auto-equip of Bind-on-Equip or Mythic BoE items.  

- 💰 **Quick Vendoring**  
  - Bulk-sell fully attuned or unwanted items at a merchant with one click.  

- 🗂️ **Inventory Sorting**  
  - Moves Mythic items to Bag 0, prepping them for disenchant or sale.  

- 🎨 **Customizable UI**  
  - Background styles, colors, alpha slider, button themes, and **Mini Mode**.  

---

## 🎮 Slash Commands

### Main Controller: `/ath`
```text
/ath reset      — Reset frames to center
/ath show       — Show the addon window
/ath hide       — Hide the addon window
/ath equip      — Run auto-equip now
/ath sort       — Prepare Mythic items for disenchant
/ath vendor     — Vendor attuned/unwanted items (must have merchant open)
```

### Ignore List
```text
/AHIgnore <itemlink>    — Toggle item in “ignore” list  
/ahignorelist           — List all ignored items in chat
```

### AHSet (Fallback Gear)
```text
/AHSet <itemlink> [slot|remove]   — Toggle item in AHSetList  
/ahsetlist                        — List all AHSet items
```
- **slot** can be `mh`/`oh` or exact slot names (`HeadSlot`, `Finger1Slot`, etc.).  
- Use `remove` to clear it from AHSetList.

### Slot Blacklisting
```text
/ahbl <slot_keyword>   — Toggle auto-equip on specific slot  
/ahbll                 — List all blacklisted slots
```
Valid `slot_keyword` examples:  
`head`, `neck`, `shoulder`, `back`, `chest`,  
`wrist`, `hands`, `waist`, `legs` (or `pants`),  
`feet`, `finger1`/`ring1`, `finger2`/`ring2`,  
`trinket1`, `trinket2`, `mh`/`mainhand`,  
`oh`/`offhand`, `ranged`.

### Misc Toggles
```text
/ahtoggle    — Toggle Auto-Equip After Combat  
/ah2h        — Enable/Disable equipping two-handers  
```

---

## ⚙️ Configuration Panel

Open **Esc → Interface → AddOns → AttuneHelper**.

### 🎛️ General Logic
- Sell Attuned Mythic Gear?  
- Auto-Equip Attunable After Combat  
- Do Not Sell BoE Items  
- Limit Selling to 12 Items  
- Disable Auto-Equip for Mythic BoE  
- Equip BoE Bountied Items  
- Equip New Affixes Only  

### 🔒 Blacklisting
✔️ Checkboxes for each equipment slot to disable auto-equip.

### 🔥 Forge Equipping
Allowed Forge Types:
- [ ] Base Items  
- [ ] Titanforged  
- [ ] Warforged  
- [ ] Lightforged  

### 🎨 Theme Settings
- **Background Style** (Tooltip, Guild, Atunament, Always Bee Attunin’, MiniMode)  
- **Background Color & Alpha** with picker & slider  
- **Button Theme** (Normal, Blue, Grey)  
- **Mini Mode** toggle  

> All changes auto-save when you click a checkbox or dropdown.

---

## 🖼️ Mini Mode

A compact, draggable toolbar:

todo put picture here

- Hover icons for detailed tooltips with item icons, forge/mythic indicators, and attunement progress.  
- Toggle via the **Mini Mode** checkbox in Theme Settings or `/ath show`/`hide`.

---

## 🛠️ Development & Contributing

- **Data Structures**
  ```lua
  AttuneHelperDB              — User settings (positions, colors, toggles…)
  AHIgnoreList[itemName]      — Items to ignore (no vendoring/equip)
  AHSetList[itemName]         — Your primary fallback gear
  AttuneHelperDB.AllowedForgeTypes — Table of allowed forge levels
  ```

- **Contributions**
  - Fork & pull-request on GitHub  
  - Report issues with reproduction steps and any lua errors  

---
