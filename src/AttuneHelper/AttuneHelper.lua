AHIgnoreList = AHIgnoreList or {}
AHSetList = AHSetList or {} -- Now stores itemName = "TargetSlotName"
AttuneHelperDB = AttuneHelperDB or {}

-- ****** DEBUGGING TOGGLE ******
local GENERAL_DEBUG_MODE = false -- Set to true for original broad debug messages
local AHSET_DEBUG_MODE = false   -- Set to true for focused AHSet debugging
local VENDOR_PREVIEW_DEBUG_MODE = false -- Set to true for vendor preview/confirmation debugging

local function print_debug_general(msg)
    if GENERAL_DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700[AH_DEBUG_GEN]|r " .. tostring(msg))
    end
end
local function print_debug(msg) -- Keep this for existing general debugs if GENERAL_DEBUG_MODE is on
    if GENERAL_DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700[AH_DEBUG]|r " .. tostring(msg))
    end
end
local function print_debug_ahset(slotName, msg)
    if AHSET_DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF8C00[AHSET_DEBUG]|cffFFD700["..tostring(slotName).."]|r " .. tostring(msg))
    end
end
local function print_debug_vendor_preview(msg)
    if VENDOR_PREVIEW_DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33CCFF[AH_VENDOR_CONFIRM]|r " .. tostring(msg))
    end
end
-- *****************************

local function IsMythic(id)
    if not id then return false end

    -- Primary method: Use bitmask from GetItemTagsCustom (more efficient)
    if _G.GetItemTagsCustom then
        local itemTags1 = GetItemTagsCustom(id)
        if itemTags1 then
            local isMythicByBitmask = bit.band(itemTags1, 0x80) ~= 0 -- Check for 128 bit (Mythic)
            print_debug_general("IsMythic bitmask check for ID " .. id .. ": " .. tostring(isMythicByBitmask))
            return isMythicByBitmask
        else
            print_debug_general("GetItemTagsCustom returned nil for ID " .. id .. ", falling back to ID check")
        end
    else
        print_debug_general("GetItemTagsCustom API not available, falling back to ID check")
    end

    -- Fallback method: ID-based detection
    if id >= MYTHIC_MIN_ITEMID then 
        print_debug_general("IsMythic fallback ID check for " .. id .. ": true (>= " .. MYTHIC_MIN_ITEMID .. ")")
        return true 
    end

    -- Final fallback: Tooltip scanning (slowest, most compatible)
    local tt = CreateFrame("GameTooltip", "AttuneHelperMythicScanTooltip", nil, "GameTooltipTemplate")
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:SetHyperlink("item:" .. id)

    for i = 1, tt:NumLines() do
        local line = _G["AttuneHelperMythicScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and string.find(text, "Mythic", 1, true) then
                tt:Hide()
                print_debug_general("IsMythic tooltip scan for " .. id .. ": true")
                return true
            end
        end
    end

    tt:Hide()
    return false
end

local synEXTloaded = false
local isSCKLoaded = false

local AttuneHelperMiniFrame = nil
local AttuneHelperMiniEquipButton = nil
local AttuneHelperMiniSortButton = nil
local AttuneHelperMiniVendorButton = nil

local currentAttunableItemCount = 0

local slotNumberMapping={Finger0Slot=11,Finger1Slot=12,Trinket0Slot=13,Trinket1Slot=14,MainHandSlot=16,SecondaryHandSlot=17}
local itemTypeToUnifiedSlot = {
  INVTYPE_HEAD="HeadSlot",INVTYPE_NECK="NeckSlot",INVTYPE_SHOULDER="ShoulderSlot",INVTYPE_CLOAK="BackSlot",
  INVTYPE_CHEST="ChestSlot",INVTYPE_ROBE="ChestSlot",INVTYPE_WAIST="WaistSlot",INVTYPE_LEGS="LegsSlot",
  INVTYPE_FEET="FeetSlot",INVTYPE_WRIST="WristSlot",INVTYPE_HAND="HandsSlot",
  INVTYPE_FINGER= {"Finger0Slot", "Finger1Slot"},
  INVTYPE_TRINKET= {"Trinket0Slot", "Trinket1Slot"},
  INVTYPE_WEAPON= {"MainHandSlot", "SecondaryHandSlot"},
  INVTYPE_2HWEAPON="MainHandSlot",
  INVTYPE_WEAPONMAINHAND="MainHandSlot",
  INVTYPE_WEAPONOFFHAND="SecondaryHandSlot",
  INVTYPE_HOLDABLE="SecondaryHandSlot",
  INVTYPE_RANGED="RangedSlot",INVTYPE_THROWN="RangedSlot",
  INVTYPE_RANGEDRIGHT="RangedSlot",INVTYPE_RELIC="RangedSlot",
  INVTYPE_WAND="RangedSlot",
  INVTYPE_SHIELD="SecondaryHandSlot"
}
local allInventorySlots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

local slotAliases={oh="SecondaryHandSlot",offhand="SecondaryHandSlot",head="HeadSlot",neck="NeckSlot",shoulder="ShoulderSlot",back="BackSlot",chest="ChestSlot",wrist="WristSlot",hands="HandsSlot",waist="WaistSlot",legs="LegsSlot",pants="LegsSlot",feet="FeetSlot",finger1="Finger0Slot",finger2="Finger1Slot",ring1="Finger0Slot",ring2="Finger1Slot",trinket1="Trinket0Slot",trinket2="Trinket1Slot",mh="MainHandSlot",mainhand="MainHandSlot",ranged="RangedSlot"}

local bagSlotCache = {}
local equipSlotCache = {}
local blacklist_checkboxes={}
local general_option_checkboxes={}
local theme_option_controls = {}
local forge_type_checkboxes = {}

local deltaTime = 0
local CHAT_MSG_SYSTEM_THROTTLE = 0.2
local waitTable = {}
local waitFrame = nil
local MYTHIC_MIN_ITEMID = 52203

local FORGE_LEVEL_MAP = { BASE = 0, TITANFORGED = 1, WARFORGED = 2, LIGHTFORGED = 3 }
local defaultForgeKeysAndValues = { BASE = true, TITANFORGED = true, WARFORGED = true, LIGHTFORGED = true }

local forgeTypeOptionsList = {
  {label = "Base Items", dbKey = "BASE"},
  {label = "Titanforged", dbKey = "TITANFORGED"},
  {label = "Warforged", dbKey = "WARFORGED"},
  {label = "Lightforged", dbKey = "LIGHTFORGED"}
}

local cannotEquipOffHandWeaponThisSession = false
local lastAttemptedSlotForEquip = nil
local lastAttemptedItemTypeForEquip = nil

-- This function now primarily serves CanEquipItemPolicyCheck for the UI settings.
-- It uses the new GetItemLinkTitanforge API.
local function GetForgeLevelFromLink(itemLink)
    if not itemLink then return FORGE_LEVEL_MAP.BASE end
    if _G.GetItemLinkTitanforge then
        local forgeValue = GetItemLinkTitanforge(itemLink) -- API returns values like FORGE_LEVEL_MAP
        -- Validate the returned value against known FORGE_LEVEL_MAP values
        for _, knownValue in pairs(FORGE_LEVEL_MAP) do
            if forgeValue == knownValue then
                return forgeValue
            end
        end
        print_debug_general("GetForgeLevelFromLink: GetItemLinkTitanforge returned unexpected value: " .. tostring(forgeValue))
    else
        print_debug_general("GetForgeLevelFromLink: GetItemLinkTitanforge API not available.")
    end
    return FORGE_LEVEL_MAP.BASE -- Default if API not present or returns unexpected value
end



-- This converts a FORGE_LEVEL_MAP style value (0,1,2,3) into the 0,1,2,3 param expected by 3-param GetItemAttuneProgress API.
-- This is mainly for fallback or if other systems need this specific format.
local function ConvertForgeMapToApiParam(forgeLevelMapValue)
    if forgeLevelMapValue == FORGE_LEVEL_MAP.TITANFORGED then return 1
    elseif forgeLevelMapValue == FORGE_LEVEL_MAP.WARFORGED then return 2
    elseif forgeLevelMapValue == FORGE_LEVEL_MAP.LIGHTFORGED then return 3
    end
    return 0 -- Default for BASE or nil/unknown
end

local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local itemIdStr = string.match(itemLink, "item:(%d+)")
    if itemIdStr then return tonumber(itemIdStr) end
    return nil
end

-- GetItemAffixIDFromLink is removed as GetItemLinkAttuneProgress should handle variants.

-- Helper: Check if an item (equipped) is actively being leveled (progress < 100%)
local function ItemIsActivelyLeveling(itemId, itemLink)
    if not itemLink then
        print_debug_general("ItemIsActivelyLeveling: itemLink is required. ItemId: " .. tostring(itemId))
        return false
    end
    if not itemId then itemId = GetItemIDFromLink(itemLink) end
    if not itemId then return false end

    if not _G.CanAttuneItemHelper or CanAttuneItemHelper(itemId) ~= 1 then
        return false
    end

    if not _G.GetItemLinkAttuneProgress then
        print_debug_general("ItemIsActivelyLeveling: GetItemLinkAttuneProgress API missing for itemLink " .. itemLink)
        return false
    end

    -- CRITICAL: Use the itemLink to check THIS SPECIFIC VARIANT's progress
    local progress = GetItemLinkAttuneProgress(itemLink)

    if type(progress) ~= "number" then
        print_debug_general("ItemIsActivelyLeveling: GetItemLinkAttuneProgress did not return a number for itemLink "..itemLink..". Got: " .. tostring(progress) .. ". Assuming fully attuned.")
        return false
    end

    print_debug_general("ItemIsActivelyLeveling check for itemLink ".. itemLink .. ": Progress="..progress)
    return progress < 100
end

-- Helper: Check if a bag item qualifies for equipping based on attunement needs and "EquipNewAffixesOnly" setting
local function ItemQualifiesForBagEquip(itemId, itemLink, isEquipNewAffixesOnlyEnabled)
    if not itemLink then
        print_debug_general("ItemQualifiesForBagEquip: itemLink is required. ItemId: " .. tostring(itemId))
        return false
    end
    if not itemId then itemId = GetItemIDFromLink(itemLink) end
    if not itemId then return false end

    local canPlayerAttuneThisItem = false
    if _G.CanAttuneItemHelper then
        canPlayerAttuneThisItem = (_G.CanAttuneItemHelper(itemId) == 1)
    else
        print_debug_general("ItemQualifiesForBagEquip: CanAttuneItemHelper API not found for itemId " .. itemId)
        return false
    end

    if not canPlayerAttuneThisItem then
        return false
    end

    -- CRITICAL: Use the itemLink to check THIS SPECIFIC VARIANT's progress
    local progress
    if _G.GetItemLinkAttuneProgress then
        progress = GetItemLinkAttuneProgress(itemLink)
        if type(progress) ~= "number" then
            print_debug_general("ItemQualifiesForBagEquip: GetItemLinkAttuneProgress did not return a number for itemLink "..itemLink..". Got: " .. tostring(progress))
            progress = 100
        end
    else
        print_debug_general("ItemQualifiesForBagEquip: GetItemLinkAttuneProgress API not found for itemLink " .. itemLink)
        return false
    end

    print_debug_general("ItemQualifiesForBagEquip check for itemLink ".. itemLink .. ": Progress="..progress..", EquipNewAffixesOnly="..tostring(isEquipNewAffixesOnlyEnabled))

    if progress >= 100 then
        print_debug_general("  This specific variant already 100% attuned. Does not qualify.")
        return false
    end

    -- Get forge level of this specific variant
    local currentForgeLevel = GetForgeLevelFromLink(itemLink)

    if isEquipNewAffixesOnlyEnabled then
        local hasAnyVariantBeenAttuned = true
        if _G.HasAttunedAnyVariantOfItem then
            hasAnyVariantBeenAttuned = HasAttunedAnyVariantOfItem(itemId)
        else
            print_debug_general("ItemQualifiesForBagEquip: HasAttunedAnyVariantOfItem API not found for itemId " .. itemId)
        end

        if not hasAnyVariantBeenAttuned then
            print_debug_general("  Strict Mode ('EquipNewAffixesOnly' ON): Qualifies because NO variant of base item ID " .. itemId .. " has been attuned yet (and current variant progress < 100%).")
            return true
        else
            -- FORGE PRIORITY OVERRIDE: Even in strict mode, allow higher forge levels
            if currentForgeLevel > FORGE_LEVEL_MAP.BASE then
                print_debug_general("  Strict Mode ('EquipNewAffixesOnly' ON): FORGE OVERRIDE - Qualifies because this is a higher forge level (" .. currentForgeLevel .. ") even though some variant has been attuned.")
                return true
            else
                print_debug_general("  Strict Mode ('EquipNewAffixesOnly' ON): Does NOT qualify because some variant of base item ID " .. itemId .. " has already been attuned and this is only forge level " .. currentForgeLevel .. ".")
                return false
            end
        end
    else
        print_debug_general("  Lenient Mode ('EquipNewAffixesOnly' OFF): Qualifies because this specific variant progress < 100%.")
        return true
    end
end

-- Helper function to check if all forge types are disabled
local function AreAllForgeTypesDisabled()
    local allowedTypes = AttuneHelperDB.AllowedForgeTypes or {}
    for _, enabled in pairs(allowedTypes) do
        if enabled then
            return false -- At least one forge type is enabled
        end
    end
    return true -- All forge types are disabled
end

-- Helper function to get blacklisted slots with friendly names
local function GetBlacklistedSlotNames()
    local blacklisted = {}
    local slotFriendlyNames = {
        HeadSlot = "Head", NeckSlot = "Neck", ShoulderSlot = "Shoulder", BackSlot = "Back",
        ChestSlot = "Chest", WristSlot = "Wrist", HandsSlot = "Hands", WaistSlot = "Waist",
        LegsSlot = "Legs", FeetSlot = "Feet", Finger0Slot = "Ring1", Finger1Slot = "Ring2",
        Trinket0Slot = "Trinket1", Trinket1Slot = "Trinket2", MainHandSlot = "MH",
        SecondaryHandSlot = "OH", RangedSlot = "Ranged"
    }
    
    for slotName, friendlyName in pairs(slotFriendlyNames) do
        if AttuneHelperDB[slotName] == 1 then
            table.insert(blacklisted, friendlyName)
        end
    end
    
    return blacklisted
end

-- Helper: Compare two items to determine which should be equipped first
-- Returns true if item1 should be prioritized over item2
local function ShouldPrioritizeItem(item1Link, item2Link)
    if not item1Link or not item2Link then return false end

    -- Get forge levels
    local forge1 = GetForgeLevelFromLink(item1Link)
    local forge2 = GetForgeLevelFromLink(item2Link)

    -- Higher forge level wins
    if forge1 ~= forge2 then
        return forge1 > forge2
    end

    -- If same forge level, check progress (lower progress = more room to grow)
    local progress1 = 0
    local progress2 = 0

    if _G.GetItemLinkAttuneProgress then
        progress1 = GetItemLinkAttuneProgress(item1Link) or 0
        progress2 = GetItemLinkAttuneProgress(item2Link) or 0
        if type(progress1) ~= "number" then progress1 = 0 end
        if type(progress2) ~= "number" then progress2 = 0 end
    end

    -- Lower progress wins (more room to attune)
    return progress1 < progress2
end


local function UpdateItemCountText()
  local c = 0
  if synEXTloaded then
      local isStrictEquip = (AttuneHelperDB["EquipNewAffixesOnly"] == 1)
      for _, bagTbl in pairs(bagSlotCache) do
          if bagTbl then
              for _, rec in pairs(bagTbl) do
                  if rec and rec.isAttunable then
                      local itemId = GetItemIDFromLink(rec.link)
                      if itemId then
                          if ItemQualifiesForBagEquip(itemId, rec.link, isStrictEquip) then
                              c = c + 1
                          end
                      end
                  end
              end
          end
      end
  end
  currentAttunableItemCount = c
  if AttuneHelperItemCountText then
      AttuneHelperItemCountText:SetText("Attunables in Inventory: "..c)
  end
end
local function CanEquipItemPolicyCheck(candidateRec)
    local itemLink = candidateRec.link
    local itemBag = candidateRec.bag
    local itemSlotInBag = candidateRec.slot
    local itemId = GetItemIDFromLink(itemLink)

    -- BoE scanning tooltip (create if needed)
    local willBindScannerTooltip = _G.AttuneHelperWillBindScannerTooltip
    if not willBindScannerTooltip then
        willBindScannerTooltip = CreateFrame("GameTooltip", "AttuneHelperWillBindScannerTooltip", UIParent, "GameTooltipTemplate")
    end

    local function IsBoEAndNotBound(itemLink, itemBag, itemSlotInBag)
        if not itemLink then return false end
        willBindScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        willBindScannerTooltip:SetHyperlink(itemLink)
        local isBoEType = false
        for i = 1, willBindScannerTooltip:NumLines() do
            local lt = _G[willBindScannerTooltip:GetName().."TextLeft"..i]
            if lt and string.find(lt:GetText() or "", "Binds when equipped", 1, true) then
                isBoEType = true
                break
            end
        end
        if not isBoEType then
            willBindScannerTooltip:Hide()
            return false
        end
        if itemBag and itemSlotInBag then
            willBindScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            willBindScannerTooltip:SetBagItem(itemBag, itemSlotInBag)
            for i = 1, willBindScannerTooltip:NumLines() do
                local lt = _G[willBindScannerTooltip:GetName().."TextLeft"..i]
                if lt and string.find(lt:GetText() or "", "Soulbound", 1, true) then
                    willBindScannerTooltip:Hide()
                    return false
                end
            end
        end
        willBindScannerTooltip:Hide()
        return true
    end

    local itemIsBoENotBound = IsBoEAndNotBound(itemLink, itemBag, itemSlotInBag)
    if itemId then
        local isBountied = (_G.GetCustomGameData and (_G.GetCustomGameData(31, itemId) or 0) > 0) or false
        if itemIsBoENotBound and isBountied then
            if AttuneHelperDB["Equip BoE Bountied Items"] ~= 1 then
                print_debug_general("PolicyCheck Fail (BoE Bountied not allowed): " .. itemLink)
                return false
            end
        else
            local isMythic = IsMythic(itemId)
            if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == 1 and isMythic and itemIsBoENotBound then
                print_debug_general("PolicyCheck Fail (Mythic BoE disabled): " .. itemLink)
                return false
            end
        end
    elseif itemIsBoENotBound then
        print_debug_general("PolicyCheck: No ItemID for BoE checks on "..itemLink..", proceeding with forge check.")
    end

    local determinedForgeLevel = GetForgeLevelFromLink(itemLink)
    print_debug_general("PolicyCheck for " .. itemLink .. ": DeterminedForgeLevel=" .. tostring(determinedForgeLevel) .. " (BASE=0, TF=1, WF=2, LF=3)")

    local allowedTypes = AttuneHelperDB.AllowedForgeTypes or {}
    -- Check against the determinedForgeLevel
    if determinedForgeLevel == FORGE_LEVEL_MAP.BASE and allowedTypes.BASE then
        print_debug_general("PolicyCheck Pass: BASE allowed for " .. itemLink)
        return true
    end
    if determinedForgeLevel == FORGE_LEVEL_MAP.TITANFORGED and allowedTypes.TITANFORGED then
        print_debug_general("PolicyCheck Pass: TITANFORGED allowed for " .. itemLink)
        return true
    end
    if determinedForgeLevel == FORGE_LEVEL_MAP.WARFORGED and allowedTypes.WARFORGED then
        print_debug_general("PolicyCheck Pass: WARFORGED allowed for " .. itemLink)
        return true
    end
    if determinedForgeLevel == FORGE_LEVEL_MAP.LIGHTFORGED and allowedTypes.LIGHTFORGED then
        print_debug_general("PolicyCheck Pass: LIGHTFORGED allowed for " .. itemLink)
        return true
    end

    print_debug_general("PolicyCheck Fail (Forge type " .. tostring(determinedForgeLevel) .. " not allowed or mapping issue): " .. itemLink .. " Allowed: B:"..tostring(allowedTypes.BASE).." TF:"..tostring(allowedTypes.TITANFORGED).." WF:"..tostring(allowedTypes.WARFORGED).." LF:"..tostring(allowedTypes.LIGHTFORGED) )
    return false
end

local function GetAttunableItemNamesList()
    local itemData = {}
    if synEXTloaded then
        local isStrictEquip = (AttuneHelperDB["EquipNewAffixesOnly"] == 1)
        for _, bagTbl in pairs(bagSlotCache) do
            if bagTbl then
                for _, rec in pairs(bagTbl) do
                    if rec and rec.isAttunable then
                        local itemId = GetItemIDFromLink(rec.link)
                        if itemId then
                            -- First check if it qualifies for bag equip (attunement logic)
                            if ItemQualifiesForBagEquip(itemId, rec.link, isStrictEquip) then
                                -- NOW also check if it passes the policy check (forge types, BoE, etc.)
                                local passesPolicy = true
                                
                                -- Create a temporary record for policy check
                                local tempRec = {
                                    link = rec.link,
                                    bag = rec.bag,
                                    slot = rec.slot
                                }
                                
                                -- Apply the same policy check used in the actual equip logic
                                if not CanEquipItemPolicyCheck(tempRec) then
                                    passesPolicy = false
                                end
                                
                                if passesPolicy then
                                    table.insert(itemData, {
                                        name = rec.name or "Unknown Item",
                                        link = rec.link,
                                        id = itemId
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return itemData
end

local function InitializeDefaultSettings()
    if AttuneHelperDB["Background Style"]==nil then AttuneHelperDB["Background Style"]="Tooltip" end
    if type(AttuneHelperDB["Background Color"])~="table" or #AttuneHelperDB["Background Color"]<4 then AttuneHelperDB["Background Color"]={0,0,0,0.8} end
    if AttuneHelperDB["Button Color"]==nil then AttuneHelperDB["Button Color"]={1,1,1,1} end
    if AttuneHelperDB["Button Theme"]==nil then AttuneHelperDB["Button Theme"]="Normal" end
    if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == nil then AttuneHelperDB["Disable Auto-Equip Mythic BoE"] = 1 end
    if AttuneHelperDB["Auto Equip Attunable After Combat"] == nil then AttuneHelperDB["Auto Equip Attunable After Combat"] = 0 end
    if AttuneHelperDB["Equip BoE Bountied Items"] == nil then AttuneHelperDB["Equip BoE Bountied Items"] = 0 end
    if AttuneHelperDB["Mini Mode"] == nil then AttuneHelperDB["Mini Mode"] = 0 end
    if AttuneHelperDB["FramePosition"] == nil then AttuneHelperDB["FramePosition"] = { "CENTER", UIParent, "CENTER", 0, 0 } end
    if AttuneHelperDB["MiniFramePosition"] == nil then AttuneHelperDB["MiniFramePosition"] = { "CENTER", UIParent, "CENTER", 0, 0 } end
    if AttuneHelperDB["Disable Two-Handers"] == nil then AttuneHelperDB["Disable Two-Handers"] = 0 end

    if AttuneHelperDB["EquipUntouchedVariants"] ~= nil and AttuneHelperDB["EquipNewAffixesOnly"] == nil then
        AttuneHelperDB["EquipNewAffixesOnly"] = AttuneHelperDB["EquipUntouchedVariants"]
        print_debug_general("AttuneHelper: Migrated old setting 'EquipUntouchedVariants' to 'EquipNewAffixesOnly'.")
    end
    AttuneHelperDB["EquipUntouchedVariants"] = nil

    if AttuneHelperDB["EquipNewAffixesOnly"] == nil then AttuneHelperDB["EquipNewAffixesOnly"] = 0 end

    -- Handle renaming of EnableVendorPreview to EnableVendorSellConfirmationDialog
    if AttuneHelperDB["EnableVendorPreview"] ~= nil and AttuneHelperDB["EnableVendorSellConfirmationDialog"] == nil then
        AttuneHelperDB["EnableVendorSellConfirmationDialog"] = AttuneHelperDB["EnableVendorPreview"]
        print_debug_general("AttuneHelper: Migrated old setting 'EnableVendorPreview' to 'EnableVendorSellConfirmationDialog'.")
    end
    AttuneHelperDB["EnableVendorPreview"] = nil -- Remove old key

    if type(AttuneHelperDB.AllowedForgeTypes) ~= "table" then
        AttuneHelperDB.AllowedForgeTypes = {}
        for keyName, defaultValue in pairs(defaultForgeKeysAndValues) do AttuneHelperDB.AllowedForgeTypes[keyName] = defaultValue end
    end
    local generalOptionDefaults = {
        ["Sell Attuned Mythic Gear?"] = 0, ["Auto Equip Attunable After Combat"] = 0, ["Do Not Sell BoE Items"] = 0,
        ["Limit Selling to 12 Items?"] = 0, ["Disable Auto-Equip Mythic BoE"] = 1, ["Equip BoE Bountied Items"] = 0,
        ["Mini Mode"] = 0, ["EquipNewAffixesOnly"] = 0,
        ["EnableVendorSellConfirmationDialog"] = 1 -- New name, default to enabled
    }
    for optName, defValue in pairs(generalOptionDefaults) do
        if AttuneHelperDB[optName] == nil then AttuneHelperDB[optName] = defValue end
    end
end
InitializeDefaultSettings()

local BgStyles={ Tooltip="Interface\\Tooltips\\UI-Tooltip-Background", Guild="Interface\\Addons\\AttuneHelper\\assets\\UI-GuildAchievement-AchievementBackground", Atunament="Interface\\Addons\\AttuneHelper\\assets\\atunament-bg", ["Always Bee Attunin'"] = "Interface\\Addons\\AttuneHelper\\assets\\always-bee-attunin", MiniModeBg = "Interface\\Addons\\AttuneHelper\\assets\\white8x8.blp"}
local themePaths = { Normal = { normal = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton.blp", pushed = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_pressed.blp" }, Blue = { normal = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_blue.blp", pushed = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_blue_pressed.blp" }, Grey = { normal = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_gray.blp", pushed = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_gray_pressed.blp" }}
local function tContains(tbl, val) if type(tbl) ~= "table" then return false end for _, v in ipairs(tbl) do if v == val then return true end end return false end
local function IsWeaponTypeForOffHandCheck(eL) return eL=="INVTYPE_WEAPON" or eL=="INVTYPE_WEAPONMAINHAND" or eL=="INVTYPE_WEAPONOFFHAND" end

local function UpdateBagCache(bagID)
    -- Skip bank bags (bags 5-11 are bank slots in 3.3.5a)
    if bagID >= 5 then
      print_debug_general("UpdateBagCache: Skipping bank bag " .. bagID)
      return
    end
    
    local old_bag_records = bagSlotCache[bagID]
    if old_bag_records then
      for _, rec_to_remove in pairs(old_bag_records) do
        local raw_inv_type = rec_to_remove.equipSlot local unified_keys = itemTypeToUnifiedSlot[raw_inv_type]
        if unified_keys then
          if type(unified_keys) == "string" then local list = equipSlotCache[unified_keys] if list then for i=#list,1,-1 do if list[i]==rec_to_remove then table.remove(list,i) end end end
          elseif type(unified_keys) == "table" then for _, k_name in ipairs(unified_keys) do local list = equipSlotCache[k_name] if list then for i=#list,1,-1 do if list[i]==rec_to_remove then table.remove(list,i) end end end end end
        end
      end
    end
    bagSlotCache[bagID] = {}
    for slotID=1,GetContainerNumSlots(bagID) do local link=GetContainerItemLink(bagID,slotID)
      if link then local name,_,_,_,_,_,_,_,eSlot_raw = GetItemInfo(link)
        if eSlot_raw and eSlot_raw~="" then local unifiedNames=itemTypeToUnifiedSlot[eSlot_raw]
          if unifiedNames then
            local itemID=GetItemIDFromLink(link)
            local canPlayerAttune = false
            if itemID then
                if _G.CanAttuneItemHelper then
                    local attuneHelperResult = CanAttuneItemHelper(itemID)
                    print_debug_general("UpdateBagCache: Item ".. (name or link) .. " ID:"..itemID.." CanAttuneItemHelper result: " .. tostring(attuneHelperResult))
                    canPlayerAttune = (attuneHelperResult == 1)
                end
            end
            local inSet=(AHSetList[name] ~= nil)
            if canPlayerAttune or inSet then local rec={bag=bagID,slot=slotID,link=link,name=name,equipSlot=eSlot_raw,isAttunable=canPlayerAttune,inSet=inSet} bagSlotCache[bagID][slotID]=rec
              if type(unifiedNames)=="string" then local k=unifiedNames equipSlotCache[k]=equipSlotCache[k] or {} table.insert(equipSlotCache[k],rec)
              elseif type(unifiedNames)=="table" then for _,k in ipairs(unifiedNames) do equipSlotCache[k]=equipSlotCache[k] or {} table.insert(equipSlotCache[k],rec) end end
            end
          end
        end
      end
    end
  end
  
  local function RefreshAllBagCaches()
    if not synEXTloaded then return end
    print_debug_general("RefreshAllBagCaches: Forcing refresh of all bag caches")
    for b = 0, 4 do
        UpdateBagCache(b)
    end
    UpdateItemCountText()
end

local function ApplyButtonTheme(theme) if not themePaths[theme] then return end if AttuneHelperFrame and AttuneHelperFrame:IsShown() then local btns={_G.AttuneHelperSortInventoryButton,_G.AttuneHelperEquipAllButton,_G.AttuneHelperVendorAttunedButton} for _,b in ipairs(btns) do if b then b:SetNormalTexture(themePaths[theme].normal) b:SetPushedTexture(themePaths[theme].pushed) b:SetHighlightTexture(themePaths[theme].pushed,"ADD") end end end end
local function AH_wait(delay,func,...)
  if type(delay)~="number" or type(func)~="function" then return false end
  if not waitFrame then
    waitFrame=CreateFrame("Frame",nil,UIParent)
    waitFrame:SetScript("OnUpdate",function(s,e)
      local i=1
      while i<=#waitTable do
        local rec_data = table.remove(waitTable,i)
        if rec_data then
            local d = rec_data[1]
            local f = rec_data[2]
            local p = rec_data[3]
            if d and type(d) == "number" and f and type(f) == "function" and p and type(p) == "table" and d > e then
                table.insert(waitTable,i,{d-e,f,p})
                i=i+1
            elseif f and type(f) == "function" then
                f(unpack(p or {}))
            else
                print_debug_general("AH_wait: Invalid record content (d, f, or p is nil/wrong type) from waitTable.")
            end
        else
            print_debug_general("AH_wait: table.remove returned nil from waitTable. Current table size: " .. #waitTable .. ". Index i: " .. i)
            if #waitTable == 0 and i == 1 then break end
            if i > #waitTable + 1 then print_debug_general("AH_wait: Breaking to prevent potential infinite loop with nil returns.") break end
        end
      end
    end)
  end
  table.insert(waitTable,{delay,func,{...}})
  return true
end
local function HideEquipPopups() StaticPopup_Hide("EQUIP_BIND") StaticPopup_Hide("AUTOEQUIP_BIND") for i=1,STATICPOPUP_NUMDIALOGS do local f=_G["StaticPopup"..i] if f and f:IsVisible() then local w=f.which if w=="EQUIP_BIND" or w=="AUTOEQUIP_BIND" then f:Hide() end end end end

local AttuneHelper = CreateFrame("Frame", "AttuneHelperFrame", UIParent)
AttuneHelper:SetSize(185, 125)

if AttuneHelperDB.FramePosition then
    local pos = AttuneHelperDB.FramePosition
    -- Check if position data is valid
    if pos and #pos >= 5 and pos[1] and pos[3] and pos[4] ~= nil and pos[5] ~= nil then
        local success, err = pcall(function()
            AttuneHelper:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
        end)
        if not success then
            print_debug_general("Failed to restore frame position, using default: " .. tostring(err))
            AttuneHelper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            AttuneHelperDB.FramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
        end
    else
        AttuneHelper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        AttuneHelperDB.FramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
    end
else
    AttuneHelper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    AttuneHelperDB.FramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
end

AttuneHelper:EnableMouse(true)
AttuneHelper:SetMovable(true)
AttuneHelper:RegisterForDrag("LeftButton")

AttuneHelper:SetScript("OnDragStart", function(s)
    if s:IsMovable() then
        s:StartMoving()
    end
end)

AttuneHelper:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = s:GetPoint()
    -- Always save with UIParent as the relative frame for consistency
    AttuneHelperDB.FramePosition = {point, UIParent, relativePoint, xOfs, yOfs}
end)

AttuneHelper:SetBackdrop({
    bgFile = BgStyles[AttuneHelperDB["Background Style"]],
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})

AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"]))
AttuneHelper:SetBackdropBorderColor(0.4, 0.4, 0.4)

local AttuneHelper_UpdateDisplayMode
local function SaveAllSettings() if not InterfaceOptionsFrame or not InterfaceOptionsFrame:IsShown() then return end for _,cb in ipairs(blacklist_checkboxes) do if cb and cb:IsShown() then AttuneHelperDB[cb:GetName():gsub("AttuneHelperBlacklist_",""):gsub("Checkbox","")]=cb:GetChecked() and 1 or 0 end end for _,cb in ipairs(general_option_checkboxes) do if cb and cb:IsShown() then AttuneHelperDB[cb.dbKey or cb:GetName()]=cb:GetChecked() and 1 or 0 end end if type(AttuneHelperDB.AllowedForgeTypes)~="table" then AttuneHelperDB.AllowedForgeTypes={} end for _,cb in ipairs(forge_type_checkboxes) do if cb and cb:IsShown() and cb.dbKey then if cb:GetChecked() then AttuneHelperDB.AllowedForgeTypes[cb.dbKey]=true else AttuneHelperDB.AllowedForgeTypes[cb.dbKey]=nil end end end
end

local function LoadAllSettings()
    InitializeDefaultSettings()

    if AttuneHelperDB.FramePosition then
        local pos = AttuneHelperDB.FramePosition
        if pos and #pos >= 5 and pos[1] and pos[3] and pos[4] ~= nil and pos[5] ~= nil then
            local success, err = pcall(function()
                AttuneHelper:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
            end)
            if not success then
                print_debug_general("Failed to restore frame position, using default: " .. tostring(err))
                AttuneHelper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                AttuneHelperDB.FramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
            end
        else
            AttuneHelper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            AttuneHelperDB.FramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
        end
    end

    if AttuneHelperMiniFrame and AttuneHelperDB.MiniFramePosition then
        local pos = AttuneHelperDB.MiniFramePosition
        if pos and #pos >= 5 and pos[1] and pos[3] and pos[4] ~= nil and pos[5] ~= nil then
            local success, err = pcall(function()
                AttuneHelperMiniFrame:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
            end)
            if not success then
                print_debug_general("Failed to restore mini frame position, using default: " .. tostring(err))
                AttuneHelperMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
            end
        else
            AttuneHelperMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
        end
    end

    if type(AttuneHelperDB.AllowedForgeTypes)~="table" then
        AttuneHelperDB.AllowedForgeTypes={}
        for k,v in pairs(defaultForgeKeysAndValues) do
            AttuneHelperDB.AllowedForgeTypes[k]=v
        end
    end

    for _,cbW in ipairs(forge_type_checkboxes) do
        if cbW and cbW.dbKey then
            cbW:SetChecked(AttuneHelperDB.AllowedForgeTypes[cbW.dbKey]==true)
        end
    end

    local ddBgStyle=_G["AttuneHelperBgDropdown"]
    if ddBgStyle then
        UIDropDownMenu_SetSelectedValue(ddBgStyle, AttuneHelperDB["Background Style"])
        UIDropDownMenu_SetText(ddBgStyle, AttuneHelperDB["Background Style"])
    end

    if BgStyles[AttuneHelperDB["Background Style"]] then
        local cs,nt=AttuneHelperDB["Background Style"],(cs=="Atunament" or cs=="Always Bee Attunin'")
        AttuneHelper:SetBackdrop{
            bgFile=BgStyles[cs],
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=(not nt),
            tileSize=(nt and 0 or 16),
            edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4}
        }
        AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"]))
    end

    if AttuneHelperMiniFrame then
        AttuneHelperMiniFrame:SetBackdropColor(
            AttuneHelperDB["Background Color"][1],
            AttuneHelperDB["Background Color"][2],
            AttuneHelperDB["Background Color"][3],
            AttuneHelperDB["Background Color"][4]
        )
    end

    local th=AttuneHelperDB["Button Theme"] or "Normal"
    local ddBtnTheme=_G["AttuneHelperButtonThemeDropdown"]
    if ddBtnTheme then
        UIDropDownMenu_SetSelectedValue(ddBtnTheme,th)
        UIDropDownMenu_SetText(ddBtnTheme,th)
    end
    ApplyButtonTheme(th)

    local bgcT=AttuneHelperDB["Background Color"]
    local csf=_G["AttuneHelperBgColorSwatch"]
    if csf then
        csf:SetBackdropColor(bgcT[1],bgcT[2],bgcT[3],1)
    end

    local asf=_G["AttuneHelperAlphaSlider"]
    if asf then
        asf:SetValue(bgcT[4])
    end

    for _,cb in ipairs(blacklist_checkboxes) do
        cb:SetChecked(AttuneHelperDB[cb:GetName():gsub("AttuneHelperBlacklist_",""):gsub("Checkbox","")]==1)
    end

    for _,cb in ipairs(general_option_checkboxes) do
        cb:SetChecked(AttuneHelperDB[cb.dbKey or cb:GetName()]==1)
    end

    if AttuneHelper_UpdateDisplayMode then
        AttuneHelper_UpdateDisplayMode()
    end
end
local function CreateButton(n,p,t,a,ap,x,y,w,h,c,s) s=s or 1 local x1,y1,x2,y2=65,176,457,290 local rw,rh=x2-x1,y2-y1 local u1,u2,v1,v2=x1/512,x2/512,y1/512,y2/512 if w and not h then h=w*rh/rw elseif h and not w then w=h*rw/rh else h=24 w=h*rw/rh*1.5 end local b=CreateFrame("Button",n,p,"UIPanelButtonTemplate") b:SetSize(w,h) b:SetScale(s) b:SetPoint(ap,a,ap,x,y) b:SetText(t) local thA=AttuneHelperDB["Button Theme"] or "Normal" if themePaths[thA] then b:SetNormalTexture(themePaths[thA].normal) b:SetPushedTexture(themePaths[thA].pushed) b:SetHighlightTexture(themePaths[thA].pushed,"ADD") for _,st in ipairs({"Normal","Pushed","Highlight"}) do local tx=b["Get"..st.."Texture"](b) if tx then tx:SetTexCoord(u1,u2,v1,v2) end local cl=c and c[st:lower()] if cl and tx then tx:SetVertexColor(cl[1],cl[2],cl[3],cl[4] or 1)end end end local fo=b:GetFontString() if fo then fo:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE") end b:SetBackdropColor(0,0,0,0.5) b:SetBackdropBorderColor(1,1,1,1) return b end

local EquipAllButton,SortInventoryButton,VendorAttunedButton
local mainPanel=CreateFrame("Frame","AttuneHelperOptionsPanel",UIParent) mainPanel.name="AttuneHelper" InterfaceOptions_AddCategory(mainPanel)
local title_ah=mainPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge") title_ah:SetPoint("TOPLEFT",16,-16) title_ah:SetText("AttuneHelper Options")
local description_ah=mainPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall") description_ah:SetPoint("TOPLEFT",title_ah,"BOTTOMLEFT",0,-8) description_ah:SetPoint("RIGHT",-32,0) description_ah:SetJustifyH("LEFT") description_ah:SetText("Main options for AttuneHelper.")

local generalOptionsPanel=CreateFrame("Frame","AttuneHelperGeneralOptionsPanel",mainPanel) generalOptionsPanel.name="General Logic" generalOptionsPanel.parent=mainPanel.name InterfaceOptions_AddCategory(generalOptionsPanel)
local titleG=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge") titleG:SetPoint("TOPLEFT",16,-16) titleG:SetText("General Logic Settings")
local descG=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall") descG:SetPoint("TOPLEFT",titleG,"BOTTOMLEFT",0,-8) descG:SetPoint("RIGHT",-32,0) descG:SetJustifyH("LEFT") descG:SetText("Configure core addon behavior and equip logic.")

local themeOptionsPanel=CreateFrame("Frame","AttuneHelperThemeOptionsPanel",mainPanel) themeOptionsPanel.name="Theme Settings" themeOptionsPanel.parent=mainPanel.name InterfaceOptions_AddCategory(themeOptionsPanel)
local titleT=themeOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge") titleT:SetPoint("TOPLEFT",16,-16) titleT:SetText("Theme Settings")
local descT=themeOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall") descT:SetPoint("TOPLEFT",titleT,"BOTTOMLEFT",0,-8) descT:SetPoint("RIGHT",-32,0) descT:SetJustifyH("LEFT") descT:SetText("Customize the appearance of the AttuneHelper frame.")

local blacklistPanel=CreateFrame("Frame","AttuneHelperBlacklistOptionsPanel",mainPanel) blacklistPanel.name="Blacklisting" blacklistPanel.parent=mainPanel.name InterfaceOptions_AddCategory(blacklistPanel)
local titleB=blacklistPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
titleB:SetPoint("TOPLEFT",16,-16)
titleB:SetText("Blacklisting")
local descB=blacklistPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
descB:SetPoint("TOPLEFT",titleB,"BOTTOMLEFT",0,-8)
descB:SetPoint("RIGHT",-32,0)
descB:SetJustifyH("LEFT")
descB:SetText("Choose which equipment slots to blacklist for auto-equipping.")

local forgeOptionsPanel = CreateFrame("Frame", "AttuneHelperForgeOptionsPanel", mainPanel) forgeOptionsPanel.name = "Forge Equipping" forgeOptionsPanel.parent = mainPanel.name InterfaceOptions_AddCategory(forgeOptionsPanel)
local titleF = forgeOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge") titleF:SetPoint("TOPLEFT", 16, -16) titleF:SetText("Forge Equip Settings")
local descF = forgeOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall") descF:SetPoint("TOPLEFT", titleF, "BOTTOMLEFT", 0, -8) descF:SetPoint("RIGHT", -32, 0) descF:SetJustifyH("LEFT") descF:SetText("Configure which types of forged items are allowed for auto-equipping.")

local slots={"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot"}
local general_options_list_for_checkboxes={
    {text = "Sell Attuned Mythic Gear?", dbKey = "Sell Attuned Mythic Gear?"},
    {text = "Auto Equip Attunable After Combat", dbKey = "Auto Equip Attunable After Combat"},
    {text = "Do Not Sell BoE Items", dbKey = "Do Not Sell BoE Items"},
    {text = "Limit Selling to 12 Items?", dbKey = "Limit Selling to 12 Items?"},
    {text = "Disable Auto-Equip Mythic BoE", dbKey = "Disable Auto-Equip Mythic BoE"},
    {text = "Equip BoE Bountied Items", dbKey = "Equip BoE Bountied Items"},
    {text = "Equip New Affixes Only", dbKey = "EquipNewAffixesOnly"},
    {text = "Enable Vendor Sell Confirmation Dialog", dbKey = "EnableVendorSellConfirmationDialog"} -- UPDATED OPTION
}

local function CreateCheckbox(t,p,x,y,iG,dkO) local cN,idK=t,dkO or t if not iG and not dkO then cN="AttuneHelperBlacklist_"..t.."Checkbox" elseif dkO and iG then if string.match(idK,"BASE")or string.match(idK,"FORGED")then cN="AttuneHelperForgeType_"..dkO.."_Checkbox" else cN="AttuneHelperGeneral_"..idK:gsub("[^%w]","").."Checkbox" end elseif iG then cN="AttuneHelperGeneral_"..idK:gsub("[^%w]","").."Checkbox" end local cb=CreateFrame("CheckButton",cN,p,"UICheckButtonTemplate") cb:SetPoint("TOPLEFT",x,y) local txt=cb:CreateFontString(nil,"ARTWORK","GameFontHighlight") txt:SetPoint("LEFT",cb,"RIGHT",4,0) txt:SetText(t) cb.dbKey=idK return cb end

local function InitializeOptionCheckboxes()
    wipe(blacklist_checkboxes)
    wipe(general_option_checkboxes)

    local x,y,r,c=16,-60,0,0 for _,sN in ipairs(slots)do local cb=CreateCheckbox(sN,blacklistPanel,x+120*c,y-33*r,false,sN) table.insert(blacklist_checkboxes,cb) cb:SetScript("OnClick",SaveAllSettings) r=r+1 if r==6 then r=0 c=c+1 end end

    local gYO=-60
    for _,oD in ipairs(general_options_list_for_checkboxes)do
        local cb=CreateCheckbox(oD.text,generalOptionsPanel,16,gYO,true,oD.dbKey)
        table.insert(general_option_checkboxes,cb)
        if oD.dbKey=="EquipNewAffixesOnly"then
            cb:SetScript("OnClick",function(s)SaveAllSettings() UpdateItemCountText()end)
        else
            cb:SetScript("OnClick",SaveAllSettings)
        end
        gYO=gYO-33
    end
end

local function InitializeForgeOptionCheckboxes()
    wipe(forge_type_checkboxes) local cFOP=_G["AttuneHelperForgeOptionsPanel"] if not cFOP then return end
    local fTSL=cFOP:CreateFontString(nil,"ARTWORK","GameFontNormal") fTSL:SetPoint("TOPLEFT",16,-60) fTSL:SetText("Allowed Forge Types for Auto-Equip:")
    local lA,yO,xIO=fTSL,-8,16 for i,fO in ipairs(forgeTypeOptionsList)do local cb=CreateCheckbox(fO.label,cFOP,0,0,true,fO.dbKey) if i==1 then cb:SetPoint("TOPLEFT",lA,"BOTTOMLEFT",xIO,yO-5)else cb:SetPoint("TOPLEFT",lA,"BOTTOMLEFT",0,yO)end lA=cb cb:SetScript("OnClick",function(s)if type(AttuneHelperDB.AllowedForgeTypes)~="table"then AttuneHelperDB.AllowedForgeTypes={}end if s:GetChecked()then AttuneHelperDB.AllowedForgeTypes[s.dbKey]=true else AttuneHelperDB.AllowedForgeTypes[s.dbKey]=nil end SaveAllSettings()end) table.insert(forge_type_checkboxes,cb)end
end

local function InitializeThemeOptions()
    wipe(theme_option_controls)
    local yOffset = -60
    local themePanel = _G["AttuneHelperThemeOptionsPanel"]
    if not themePanel then print_debug_general("Theme panel not found for init!") return end

    local bgL=themePanel:CreateFontString(nil,"ARTWORK","GameFontNormal")
    bgL:SetPoint("TOPLEFT", 16, yOffset) bgL:SetText("Background Style:")
    theme_option_controls.bgLabel = bgL
    local lastAnchor = bgL
    yOffset = yOffset - 10

    local bgDD=CreateFrame("Frame","AttuneHelperBgDropdown",themePanel,"UIDropDownMenuTemplate")
    bgDD:SetPoint("TOPLEFT",lastAnchor,"BOTTOMLEFT",0,-8) UIDropDownMenu_SetWidth(bgDD,160)
    theme_option_controls.bgDropdown = bgDD
    UIDropDownMenu_Initialize(bgDD,function(s)for sN,_ in pairs(BgStyles)do if sN~="MiniModeBg"then local i=UIDropDownMenu_CreateInfo() i.text=sN i.value=sN i.func=function(self) UIDropDownMenu_SetSelectedValue(bgDD,self.value) AttuneHelperDB["Background Style"]=self.value UIDropDownMenu_SetText(bgDD,self.value) if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end SaveAllSettings() end i.checked=(sN==AttuneHelperDB["Background Style"]) UIDropDownMenu_AddButton(i)end end end)
    lastAnchor = bgDD
    yOffset = yOffset - 30

    local sw=CreateFrame("Button","AttuneHelperBgColorSwatch",themePanel) sw:SetSize(16,16)
    sw:SetPoint("TOPLEFT",lastAnchor,"BOTTOMLEFT",0,-15) sw:SetBackdrop{bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=4,edgeSize=4,insets={left=1,right=1,top=1,bottom=1}} sw:SetBackdropBorderColor(0,0,0,1)
    theme_option_controls.bgColorSwatch = sw
    sw:SetScript("OnEnter",function(s)GameTooltip:SetOwner(s,"ANCHOR_RIGHT") GameTooltip:SetText("Background Color") GameTooltip:Show()end) sw:SetScript("OnLeave",GameTooltip_Hide)
    sw:SetScript("OnClick",function(s)local c=AttuneHelperDB["Background Color"] ColorPickerFrame.func=function()local r,g,b=ColorPickerFrame:GetColorRGB() c[1],c[2],c[3]=r,g,b sw:SetBackdropColor(r,g,b,1) if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end SaveAllSettings()end ColorPickerFrame.opacityFunc=function()local nA if _G.ColorPickerFrameOpacitySlider then nA=_G.ColorPickerFrameOpacitySlider:GetValue()else nA=ColorPickerFrame.opacity end if type(nA)=="number"then if ColorPickerFrame.previousValues then ColorPickerFrame.previousValues.a=nA end AttuneHelperDB["Background Color"][4]=nA if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end SaveAllSettings()end end ColorPickerFrame.cancelFunc=function(pV)if pV then AttuneHelperDB["Background Color"]={pV.r,pV.g,pV.b,pV.a} if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end sw:SetBackdropColor(pV.r,pV.g,pV.b,1) if _G.AttuneHelperAlphaSlider then _G.AttuneHelperAlphaSlider:SetValue(pV.a)end end end ColorPickerFrame.hasOpacity=true ColorPickerFrame.opacity=AttuneHelperDB["Background Color"][4] ColorPickerFrame.previousValues={r=AttuneHelperDB["Background Color"][1],g=AttuneHelperDB["Background Color"][2],b=AttuneHelperDB["Background Color"][3],a=AttuneHelperDB["Background Color"][4]} ColorPickerFrame:SetColorRGB(c[1],c[2],c[3]) ColorPickerFrame:Show()end)

    local swL=themePanel:CreateFontString(nil,"ARTWORK","GameFontHighlight") swL:SetPoint("LEFT",sw,"RIGHT",4,0) swL:SetText("BG Color")
    theme_option_controls.bgColorLabel = swL
    lastAnchor = swL
    yOffset = yOffset - 20

    local alpL=themePanel:CreateFontString(nil,"ARTWORK","GameFontNormal")
    alpL:SetPoint("TOPLEFT",sw,"BOTTOMLEFT",-2, -10)
    alpL:SetText("BG Transparency:")
    theme_option_controls.alphaLabel = alpL
    lastAnchor = alpL
    yOffset = yOffset - 10

    local alpS=CreateFrame("Slider","AttuneHelperAlphaSlider",themePanel,"OptionsSliderTemplate") alpS:SetOrientation("HORIZONTAL") alpS:SetMinMaxValues(0,1) alpS:SetValueStep(0.01) alpS:SetWidth(150)
    alpS:SetPoint("TOPLEFT",lastAnchor,"BOTTOMLEFT",0,-8)
    theme_option_controls.alphaSlider = alpS
    _G.AttuneHelperAlphaSliderLow:SetText("0") _G.AttuneHelperAlphaSliderHigh:SetText("1") _G.AttuneHelperAlphaSliderText:SetText("")
    alpS:SetScript("OnValueChanged",function(s,v)AttuneHelperDB["Background Color"][4]=v if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end SaveAllSettings()end)
    lastAnchor = alpS
    yOffset = yOffset - 35

    local btL=themePanel:CreateFontString(nil,"ARTWORK","GameFontNormal")
    btL:SetPoint("TOPLEFT",lastAnchor,"BOTTOMLEFT",0,-20)
    btL:SetText("Button Theme:")
    theme_option_controls.buttonThemeLabel = btL
    lastAnchor = btL
    yOffset = yOffset - 10

    local btDD=CreateFrame("Frame","AttuneHelperButtonThemeDropdown",themePanel,"UIDropDownMenuTemplate")
    btDD:SetPoint("TOPLEFT",lastAnchor,"BOTTOMLEFT",0,-8) UIDropDownMenu_SetWidth(btDD,160)
    theme_option_controls.buttonThemeDropdown = btDD
    UIDropDownMenu_Initialize(btDD,function(s)for _,th in ipairs({"Normal","Blue","Grey"})do local i=UIDropDownMenu_CreateInfo() i.text=th i.value=th i.func=function(self) local v=self.value UIDropDownMenu_SetSelectedValue(btDD,v) UIDropDownMenu_SetText(btDD,v) AttuneHelperDB["Button Theme"]=v ApplyButtonTheme(v) SaveAllSettings() end i.checked=(th==AttuneHelperDB["Button Theme"]) UIDropDownMenu_AddButton(i)end end)
    lastAnchor = btDD
    yOffset = yOffset - 30

    local miniModeCheckbox = CreateCheckbox("Mini Mode", themePanel, 16, yOffset -5, true, "Mini Mode")
    miniModeCheckbox:SetPoint("TOPLEFT", _G["AttuneHelperButtonThemeDropdown"], "BOTTOMLEFT", 0, -15)

    miniModeCheckbox:SetScript("OnClick", function(self)
        AttuneHelperDB["Mini Mode"] = self:GetChecked() and 1 or 0
        SaveAllSettings()
        if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode() end
    end)
    table.insert(general_option_checkboxes, miniModeCheckbox) -- It's a general option, but placed in theme panel for layout
    theme_option_controls.miniModeCheckbox = miniModeCheckbox
end

InitializeOptionCheckboxes()
InitializeForgeOptionCheckboxes()
InitializeThemeOptions()

generalOptionsPanel.okay=function()SaveAllSettings() if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end UpdateItemCountText()end
generalOptionsPanel.cancel=function()LoadAllSettings() UpdateItemCountText()end
generalOptionsPanel.refresh=function()LoadAllSettings() UpdateItemCountText()end
themeOptionsPanel.okay=function()SaveAllSettings() if AttuneHelper_UpdateDisplayMode then AttuneHelper_UpdateDisplayMode()end end
themeOptionsPanel.cancel=LoadAllSettings
themeOptionsPanel.refresh=LoadAllSettings
blacklistPanel.okay=SaveAllSettings
blacklistPanel.cancel=LoadAllSettings
blacklistPanel.refresh=LoadAllSettings
forgeOptionsPanel.okay=SaveAllSettings
forgeOptionsPanel.cancel=LoadAllSettings
forgeOptionsPanel.refresh=LoadAllSettings

local function performEquipAction(itemRecord, targetSlotID, currentSlotNameForAction)
    print_debug_general("Attempting performEquipAction for: " .. itemRecord.link .. " in slot " .. currentSlotNameForAction)
    local itemLinkToEquip = itemRecord.link
    local itemEquipLocToEquip = itemRecord.equipSlot
    local sckEventsTemporarilyUnregistered = false
    if isSCKLoaded and _G["SCK"] and _G["SCK"].frame then
        if _G["SCK"].confirmActive then _G["SCK"].confirmActive = false end
        _G["SCK"].frame:UnregisterEvent('EQUIP_BIND_CONFIRM') _G["SCK"].frame:UnregisterEvent('AUTOEQUIP_BIND_CONFIRM')
        sckEventsTemporarilyUnregistered = true
    end
    local success, err = pcall(function()
        lastAttemptedSlotForEquip = currentSlotNameForAction lastAttemptedItemTypeForEquip = itemEquipLocToEquip
        EquipItemByName(itemLinkToEquip, targetSlotID) EquipPendingItem(0) ConfirmBindOnUse() HideEquipPopups()
    end)
    if sckEventsTemporarilyUnregistered and _G["SCK"] and _G["SCK"].frame then
        _G["SCK"].frame:RegisterEvent('EQUIP_BIND_CONFIRM') _G["SCK"].frame:RegisterEvent('AUTOEQUIP_BIND_CONFIRM')
    end
    if not success then
        print_debug_general("performEquipAction FAILED for "..itemRecord.link..": " .. tostring(err))
    else
        print_debug_general("performEquipAction SUCCEEDED for "..itemRecord.link)
    end
    return success
end

local SWAP_THROTTLE = 0.1
EquipAllButton = CreateButton("AttuneHelperEquipAllButton",AttuneHelper,"Equip Attunables",AttuneHelper,"TOP",0,-5,nil,nil,nil,1.3)
EquipAllButton:SetScript("OnClick", function()
    print_debug_general("EquipAllButton clicked. EquipNewAffixesOnly=" .. tostring(AttuneHelperDB["EquipNewAffixesOnly"]))
    if MerchantFrame and MerchantFrame:IsShown() then print_debug_general("Merchant frame open, aborting equip.") return end
    
    -- Force refresh all bag caches to catch any missed updates
    RefreshAllBagCaches()
    print_debug_general("Bag cache refreshed. Current Attunable Item Count (for display): " .. currentAttunableItemCount)

    local slotsList = {"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot"}
    local twoHanderEquippedInMainHandThisEquipCycle = false

    -- Determine throttle based on combat status
    local equipThrottle = InCombatLockdown() and 0.05 or SWAP_THROTTLE -- Faster in combat

    -- [Rest of the function remains the same...]
    local willBindScannerTooltip = nil
    local function IsBoEAndNotBound(itemLink, itemBag, itemSlotInBag)
        if not itemLink then return false end
        if not willBindScannerTooltip then willBindScannerTooltip = CreateFrame("GameTooltip", "AttuneHelperWillBindScannerTooltip", UIParent, "GameTooltipTemplate") end
        willBindScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE") willBindScannerTooltip:SetHyperlink(itemLink)
        local isBoEType = false
        for i = 1, willBindScannerTooltip:NumLines() do local lt = _G[willBindScannerTooltip:GetName().."TextLeft"..i] if lt and string.find(lt:GetText() or "", "Binds when equipped", 1, true) then isBoEType=true break end end
        if not isBoEType then willBindScannerTooltip:Hide() return false end
        if itemBag and itemSlotInBag then
            willBindScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE") willBindScannerTooltip:SetBagItem(itemBag, itemSlotInBag)
            for i = 1, willBindScannerTooltip:NumLines() do local lt = _G[willBindScannerTooltip:GetName().."TextLeft"..i] if lt and string.find(lt:GetText() or "", "Soulbound", 1, true) then willBindScannerTooltip:Hide() return false end end
        end
        willBindScannerTooltip:Hide() return true
    end

    local function CanEquipItemPolicyCheck(candidateRec)
        local itemLink = candidateRec.link local itemBag = candidateRec.bag local itemSlotInBag = candidateRec.slot
        local itemId = GetItemIDFromLink(itemLink)

        local itemIsBoENotBound = IsBoEAndNotBound(itemLink, itemBag, itemSlotInBag)
        if itemId then
            local isBountied = (_G.GetCustomGameData and (_G.GetCustomGameData(31, itemId) or 0) > 0) or false
            if itemIsBoENotBound and isBountied then
                if AttuneHelperDB["Equip BoE Bountied Items"] ~= 1 then print_debug_general("PolicyCheck Fail (BoE Bountied not allowed): " .. itemLink) return false end
            else
                local isMythic = IsMythic(itemId)
                if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == 1 and isMythic and itemIsBoENotBound then print_debug_general("PolicyCheck Fail (Mythic BoE disabled): " .. itemLink) return false end
            end
        elseif itemIsBoENotBound then
            print_debug_general("PolicyCheck: No ItemID for BoE checks on "..itemLink..", proceeding with forge check.")
        end

        local determinedForgeLevel = GetForgeLevelFromLink(itemLink) -- Using updated function
        print_debug_general("PolicyCheck for " .. itemLink .. ": DeterminedForgeLevel=" .. tostring(determinedForgeLevel) .. " (BASE=0, TF=1, WF=2, LF=3)")

        local allowedTypes = AttuneHelperDB.AllowedForgeTypes or {}
        -- Check against the determinedForgeLevel (which comes from GetItemLinkTitanforge via GetForgeLevelFromLink)
        if determinedForgeLevel == FORGE_LEVEL_MAP.BASE and allowedTypes.BASE then print_debug_general("PolicyCheck Pass: BASE allowed for " .. itemLink) return true end
        if determinedForgeLevel == FORGE_LEVEL_MAP.TITANFORGED and allowedTypes.TITANFORGED then print_debug_general("PolicyCheck Pass: TITANFORGED allowed for " .. itemLink) return true end
        if determinedForgeLevel == FORGE_LEVEL_MAP.WARFORGED and allowedTypes.WARFORGED then print_debug_general("PolicyCheck Pass: WARFORGED allowed for " .. itemLink) return true end
        if determinedForgeLevel == FORGE_LEVEL_MAP.LIGHTFORGED and allowedTypes.LIGHTFORGED then print_debug_general("PolicyCheck Pass: LIGHTFORGED allowed for " .. itemLink) return true end

        print_debug_general("PolicyCheck Fail (Forge type " .. tostring(determinedForgeLevel) .. " not allowed or mapping issue): " .. itemLink .. " Allowed: B:"..tostring(allowedTypes.BASE).." TF:"..tostring(allowedTypes.TITANFORGED).." WF:"..tostring(allowedTypes.WARFORGED).." LF:"..tostring(allowedTypes.LIGHTFORGED) )
        return false
    end

    local function CanEquip2HInMainHandWithoutInterruptingOHAttunement()
        local ohLink = GetInventoryItemLink("player", GetInventorySlotInfo("SecondaryHandSlot"))
        if ohLink then
            local ohItemId = GetItemIDFromLink(ohLink)
            if ohItemId then
                if ItemIsActivelyLeveling(ohItemId, ohLink) then
                    print_debug_general("Cannot equip 2H: OH item "..ohLink.." (ID: "..ohItemId..") is actively leveling (progress < 100%).")
                    return false
                end
            end
        end
        return true
    end

    local function checkAndEquip(slotName)
        print_debug_general("--- Checking slot: " .. slotName .. " ---")
        if AttuneHelperDB[slotName] == 1 then print_debug_general("Slot "..slotName.." is blacklisted.") return end

        local currentMHLink_OverallCheck = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
        local currentMHIs2H = false
        if currentMHLink_OverallCheck then
            local _,_,_,_,_,_,_,_,currentMHEquipLoc = GetItemInfo(currentMHLink_OverallCheck)
            if currentMHEquipLoc == "INVTYPE_2HWEAPON" then currentMHIs2H = true print_debug_general("Current MH is 2H: " .. currentMHLink_OverallCheck) end
        end

        if slotName == "SecondaryHandSlot" then
            if currentMHIs2H then print_debug_general("Cannot equip OH for "..slotName.." because current MH is 2H.") return end
            if twoHanderEquippedInMainHandThisEquipCycle then print_debug_general("Cannot equip OH for "..slotName.." because a 2H was equipped this cycle.") return end
        end

        local invSlotID = GetInventorySlotInfo(slotName) local eqID = slotNumberMapping[slotName] or invSlotID
        local equippedItemLink = GetInventoryItemLink("player", invSlotID)
        local isEquippedItemActivelyLevelingFlag = false
        local equippedItemName, equippedItemEquipLoc

        if equippedItemLink then
            print_debug_general(slotName .. " has equipped: " .. equippedItemLink)
            local equippedItemId = GetItemIDFromLink(equippedItemLink)
            equippedItemName, _,_,_,_,_,_,_,equippedItemEquipLoc = GetItemInfo(equippedItemLink)
            if equippedItemId then
                isEquippedItemActivelyLevelingFlag = ItemIsActivelyLeveling(equippedItemId, equippedItemLink)
            else
                print_debug_general("  Equipped item has no ID: " .. equippedItemLink)
            end
        else
            print_debug_general(slotName .. " is empty.")
        end

        if isEquippedItemActivelyLevelingFlag then
            print_debug_general(slotName .. " is ALREADY equipped with an actively leveling item (progress < 100%). Priority 1 Met.")
            return
        end

        print_debug_general(slotName .. ": Not blocked by an actively leveling equipped item. Looking for P2 (Attunable from bags) items...")
        local candidates = equipSlotCache[slotName] or {}
        local isEquipNewAffixesOnlyEnabled = (AttuneHelperDB["EquipNewAffixesOnly"] == 1)

        -- P2: Look for attunable items from bags, prioritized by forge level and progress
        local attunableCandidates = {}
        for _, rec in ipairs(candidates) do
            if rec.isAttunable then
                local recItemId = GetItemIDFromLink(rec.link)
                if recItemId then
                    print_debug_general("  P2 Candidate (from bag): " .. rec.link .. " (isAttunable from cache: true)")
                    if ItemQualifiesForBagEquip(recItemId, rec.link, isEquipNewAffixesOnlyEnabled) then
                        print_debug_general("    Candidate QUALIFIES for equipping (ItemQualifiesForBagEquip=true based on EquipNewAffixesOnly=" ..tostring(isEquipNewAffixesOnlyEnabled)..")")
                        if CanEquipItemPolicyCheck(rec) then
                            print_debug_general("    Passed policy check.")
                            table.insert(attunableCandidates, rec)
                        else
                            print_debug_general("    Failed policy check for P2 bag item " .. rec.link)
                        end
                    else
                        print_debug_general("    Candidate '" .. (rec.name or "Unknown") .. "' does NOT qualify for equipping (ItemQualifiesForBagEquip=false based on EquipNewAffixesOnly="..tostring(isEquipNewAffixesOnlyEnabled)..").")
                    end
                end
            end
        end

        -- Sort candidates by priority (higher forge level and lower progress first)
        table.sort(attunableCandidates, function(a, b)
            return ShouldPrioritizeItem(a.link, b.link)
        end)

        -- Try to equip the best candidate
        for _, rec in ipairs(attunableCandidates) do
            local proceed = true
            if slotName == "MainHandSlot" and rec.equipSlot == "INVTYPE_2HWEAPON" then
                if not CanEquip2HInMainHandWithoutInterruptingOHAttunement() then proceed = false print_debug_general("    Proceed=false (2H would interrupt OH leveling)") end
            end
            if slotName == "SecondaryHandSlot" and cannotEquipOffHandWeaponThisSession and IsWeaponTypeForOffHandCheck(rec.equipSlot) then
                proceed = false print_debug_general("    Proceed=false (cannotEquipOffHandWeaponThisSession and is weapon type)")
            end
            if proceed then
                print_debug_general("    Proceeding to equip P2 bag item: " .. rec.link)
                if performEquipAction(rec, eqID, slotName) then
                    if rec.equipSlot == "INVTYPE_2HWEAPON" and (slotName == "MainHandSlot" or slotName == "RangedSlot") then
                        twoHanderEquippedInMainHandThisEquipCycle = true
                        print_debug_general("    Set twoHanderEquippedInMainHandThisEquipCycle = true")
                    end
                    return
                end
            else
                print_debug_general("    Not proceeding with equip for P2 bag item " .. rec.link)
            end
        end
        print_debug_general(slotName .. ": Finished P2 (Attunable from bags) candidates loop. No P2 item equipped.")

        print_debug_ahset(slotName, "Starting P3 (AHSet) evaluation.")
        if equippedItemLink and equippedItemName and AHSetList[equippedItemName] == slotName then
            print_debug_ahset(slotName, "Equipped item '" .. equippedItemName .. "' IS the designated AHSet item for this slot. Skipping P3 bag candidates.")
            return
        elseif equippedItemLink and equippedItemName then
            print_debug_ahset(slotName, "Equipped item '" .. equippedItemName .. "' is NOT the designated AHSet item OR item not in AHSetList for this slot. Current AHSet designation for equipped item: " .. tostring(AHSetList[equippedItemName]))
        else
            print_debug_ahset(slotName, "Slot is empty or equipped item has no name. Proceeding to check bag candidates for AHSet.")
        end

        local currentMHLink_forAHSetOHCheck = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))

        for _, rec_set in ipairs(candidates) do
            local designatedSlotForCandidate = AHSetList[rec_set.name]
            print_debug_ahset(slotName, "Checking AHSet bag candidate: '" .. rec_set.name .. "' (" .. rec_set.link .. "). AHSetList designation: " .. tostring(designatedSlotForCandidate))

            if designatedSlotForCandidate == slotName then
                print_debug_ahset(slotName, "Candidate '" .. rec_set.name .. "' IS designated in AHSetList for current slot (" .. slotName .. ").")
                local candidateEquipLoc = rec_set.equipSlot
                local equipThisSetItem = false

                if slotName == "MainHandSlot" then
                    if candidateEquipLoc == "INVTYPE_WEAPON" or candidateEquipLoc == "INVTYPE_2HWEAPON" or candidateEquipLoc == "INVTYPE_WEAPONMAINHAND" then equipThisSetItem = true end
                elseif slotName == "SecondaryHandSlot" then
                    if not currentMHIs2H then
                        if candidateEquipLoc == "INVTYPE_WEAPON" or candidateEquipLoc == "INVTYPE_WEAPONOFFHAND" or candidateEquipLoc == "INVTYPE_SHIELD" or candidateEquipLoc == "INVTYPE_HOLDABLE" then
                            if currentMHLink_forAHSetOHCheck and currentMHLink_forAHSetOHCheck == rec_set.link then
                                local mhItemNameForSetCheck, _,_,_,_,_,_,_,_ = GetItemInfo(currentMHLink_forAHSetOHCheck)
                                if mhItemNameForSetCheck and AHSetList[mhItemNameForSetCheck] == "MainHandSlot" then
                                    print_debug_ahset(slotName, "Cannot equip "..rec_set.link.." in OH for AHSet, it's the *exact same item link* currently in MH AND is the MH AHSet item.")
                                else equipThisSetItem = true end
                            else equipThisSetItem = true end
                        end
                    end
                elseif slotName == "RangedSlot" then
                    if tContains({"INVTYPE_RANGED","INVTYPE_THROWN","INVTYPE_RELIC","INVTYPE_WAND", "INVTYPE_RANGEDRIGHT"}, candidateEquipLoc) then equipThisSetItem = true end
                else
                    local unifiedCandidateSlot = itemTypeToUnifiedSlot[candidateEquipLoc]
                    if (type(unifiedCandidateSlot) == "string" and unifiedCandidateSlot == slotName) or (type(unifiedCandidateSlot) == "table" and tContains(unifiedCandidateSlot, slotName)) then equipThisSetItem = true end
                end

                print_debug_ahset(slotName, "Candidate '" .. rec_set.name .. "' type (" .. candidateEquipLoc .. ") suitable for target slot " .. slotName .. "? Result: " .. tostring(equipThisSetItem))

                if equipThisSetItem then
                    local passesPolicy = CanEquipItemPolicyCheck(rec_set)
                    print_debug_ahset(slotName, "Candidate '" .. rec_set.name .. "' passes CanEquipItemPolicyCheck? Result: " .. tostring(passesPolicy))

                    if passesPolicy then
                        local proceed = true
                        if (slotName == "MainHandSlot" or slotName == "RangedSlot") and rec_set.equipSlot == "INVTYPE_2HWEAPON" then
                            if not CanEquip2HInMainHandWithoutInterruptingOHAttunement() then
                                proceed = false
                                print_debug_ahset(slotName, "Proceed set to false: AHSet 2H ("..rec_set.name..") for MH/Ranged would interrupt OH leveling.")
                            end
                        end
                        if slotName == "SecondaryHandSlot" then
                            if currentMHIs2H then
                                proceed = false
                                print_debug_ahset(slotName, "Proceed set to false: AHSet OH target ("..rec_set.name.."), but current MH is 2H.")
                            elseif cannotEquipOffHandWeaponThisSession and IsWeaponTypeForOffHandCheck(rec_set.equipSlot) then
                                proceed = false
                                print_debug_ahset(slotName, "Proceed set to false: cannotEquipOffHandWeaponThisSession is true and AHSet item ("..rec_set.name..") is weapon type for OH.")
                            end
                        end

                        print_debug_ahset(slotName, "Final 'proceed' decision for AHSet item '"..rec_set.name.."': " .. tostring(proceed))

                        if proceed then
                            print_debug_ahset(slotName, "ATTEMPTING EQUIP of P3 (AHSet) item: " .. rec_set.link .. " into " .. slotName)
                            if performEquipAction(rec_set, eqID, slotName) then
                                if rec_set.equipSlot == "INVTYPE_2HWEAPON" and (slotName=="MainHandSlot" or slotName=="RangedSlot") then
                                    twoHanderEquippedInMainHandThisEquipCycle = true
                                    print_debug_ahset(slotName, "Set twoHanderEquippedInMainHandThisEquipCycle = true for AHSet 2H: " .. rec_set.name)
                                end
                                print_debug_ahset(slotName, "SUCCESSFULLY EQUIPPED P3 (AHSet) item: " .. rec_set.name)
                                return
                            else
                                print_debug_ahset(slotName, "performEquipAction FAILED for P3 (AHSet) item: " .. rec_set.name)
                            end
                        end
                    end
                end
            end
        end
        print_debug_ahset(slotName, "Finished P3 (AHSet from bags) candidates loop. No P3 item was equipped from bags.")

        if slotName=="SecondaryHandSlot"and cannotEquipOffHandWeaponThisSession then
            print_debug_ahset(slotName, "In cannotEquipOffHandWeaponThisSession block, looking for non-weapon offhands (AHSet or Attunable).")
            for _,r_oh_c in ipairs(candidates)do
                if not IsWeaponTypeForOffHandCheck(r_oh_c.equipSlot)then
                    print_debug_ahset(slotName, "Fallback OH Candidate (non-weapon): "..r_oh_c.link)
                    local isGoodForFallback = false
                    local oh_id = GetItemIDFromLink(r_oh_c.link)
                    if oh_id then
                        if r_oh_c.isAttunable and ItemQualifiesForBagEquip(oh_id, r_oh_c.link, isEquipNewAffixesOnlyEnabled) then
                            isGoodForFallback = true
                            print_debug_ahset(slotName, "Fallback OH '"..r_oh_c.name.."' is attunable and qualifies for leveling.")
                        end

                        if not isGoodForFallback and AHSetList[r_oh_c.name] == slotName then
                            isGoodForFallback = true
                            print_debug_ahset(slotName, "Fallback OH '"..r_oh_c.name.."' IS AHSet for this slot.")
                        end

                        if isGoodForFallback then
                            local passesPolicyFallback = CanEquipItemPolicyCheck(r_oh_c)
                            print_debug_ahset(slotName, "Fallback OH '"..r_oh_c.name.."' passes CanEquipItemPolicyCheck? " .. tostring(passesPolicyFallback))
                            if passesPolicyFallback then
                                print_debug_ahset(slotName, "ATTEMPTING EQUIP of Fallback OH: "..r_oh_c.link)
                                if performEquipAction(r_oh_c,eqID,slotName)then
                                    print_debug_ahset(slotName, "SUCCESSFULLY EQUIPPED Fallback OH: "..r_oh_c.name)
                                    return
                                else
                                    print_debug_ahset(slotName, "performEquipAction FAILED for Fallback OH: "..r_oh_c.name)
                                end
                            end
                        end
                    end
                end
            end
        end
        print_debug_ahset(slotName, "--- Finished all checks for slot --- No item equipped for this slot if this is the last message for it.")
    end
    
    -- Use the appropriate throttle based on combat status
    for i, slotName_iter in ipairs(slotsList) do AH_wait(equipThrottle * i, checkAndEquip, slotName_iter) end
end)

SortInventoryButton = CreateButton("AttuneHelperSortInventoryButton",AttuneHelper,"Prepare Disenchant",EquipAllButton,"BOTTOM",0,-27,nil,nil,nil,1.3)
SortInventoryButton:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText("Moves Mythic items to Bag 0.") GameTooltip:Show() end)
SortInventoryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
SortInventoryButton:SetScript("OnClick", function()
    local readyForDisenchant, emptyS, ignoredL = {}, {}, {}

    -- Build ignored list (case-insensitive)
    for n in pairs(AHIgnoreList) do
        ignoredL[string.lower(n)] = true
    end

    -- Determine which bags to scan
    local bagsToScan = {0, 1, 2, 3, 4} -- Always include regular bags
    local includeBankBags = false
    
    -- Check if bank is open (bank bags are 5-11 in 3.3.5a)
    if BankFrame and BankFrame:IsShown() then
        -- Add bank bags to scan list
        for bankBag = 5, 11 do
            table.insert(bagsToScan, bankBag)
        end
        includeBankBags = true
        print("|cffffd200[Attune Helper]|r Bank is open - including bank bags in sort.")
    end

    -- Enhanced function to check if item is ready for disenchanting
    local function IsReadyForDisenchant(itemId, itemLink, itemName, bag, slot)
        if not itemId or not itemLink or not itemName then 
            return false, "Missing item data"
        end

        -- Check 1: Must be Mythic
        if not IsMythic(itemId) then
            return false, "Not mythic"
        end

        -- Check 2: Must not be in ignore list
        if ignoredL[string.lower(itemName)] then
            return false, "In AHIgnore list"
        end

        -- Check 3: Must not be in AHSet list
        if AHSetList[itemName] then
            return false, "In AHSet list"
        end

        -- Check 4: Must be soulbound
        local isSoulbound = false
        local boundScanTT = CreateFrame("GameTooltip", "AttuneHelperBoundScanTooltip", UIParent, "GameTooltipTemplate")
        boundScanTT:SetOwner(UIParent, "ANCHOR_NONE")
        
        if bag and slot then
            boundScanTT:SetBagItem(bag, slot)
        else
            boundScanTT:SetHyperlink(itemLink)
        end
        
        for i = 1, boundScanTT:NumLines() do
            local line = _G["AttuneHelperBoundScanTooltipTextLeft" .. i]
            if line then
                local text = line:GetText()
                if text and string.find(text, "Soulbound", 1, true) then
                    isSoulbound = true
                    break
                end
            end
        end
        boundScanTT:Hide()

        if not isSoulbound then
            return false, "Not soulbound"
        end

        -- Check 5: Must be 100% attuned
        local progress = 0
        if _G.GetItemLinkAttuneProgress then
            local progressResult = GetItemLinkAttuneProgress(itemLink)
            if type(progressResult) == "number" then
                progress = progressResult
            else
                print_debug_general("IsReadyForDisenchant: GetItemLinkAttuneProgress returned non-number for " .. itemLink .. ": " .. tostring(progressResult))
                return false, "Cannot determine attunement progress"
            end
        else
            print_debug_general("IsReadyForDisenchant: GetItemLinkAttuneProgress API not available for " .. itemLink)
            return false, "Attunement API not available"
        end

        if progress < 100 then
            return false, "Not fully attuned (" .. progress .. "%)"
        end

        return true, "Ready for disenchant"
    end

    -- Check for enough empty slots (now including bank if open)
    local emptyCount = 0
    for _, b in ipairs(bagsToScan) do
        for s = 1, GetContainerNumSlots(b) do
            if not GetContainerItemID(b, s) then
                emptyCount = emptyCount + 1
                table.insert(emptyS, {b = b, s = s})
            end
        end
    end

    local requiredEmptySlots = includeBankBags and 16 or 8 -- Reasonable number for disenchant-ready items
    if emptyCount < requiredEmptySlots then
        print("|cffff0000[Attune Helper]|r: Need at least " .. requiredEmptySlots .. " empty slots for sorting" .. (includeBankBags and " (including bank)" or "") .. ".")
        return
    end

    -- Track which slots in bag 0 will become available
    local availableBag0Slots = {}

    -- Scan all bags and categorize items
    for _, b in ipairs(bagsToScan) do
        for s = 1, GetContainerNumSlots(b) do
            local id = GetContainerItemID(b, s)
            if id then
                local link = GetContainerItemLink(b, s)
                local name = GetItemInfo(id)
                
                if link and name then
                    local isReady, reason = IsReadyForDisenchant(id, link, name, b, s)
                    
                    if b == 0 then
                        -- Items currently in bag 0
                        if not isReady then
                            -- Non-disenchant-ready items in bag 0 (need to move out)
                            table.insert(availableBag0Slots, s) -- This slot will become available
                            print_debug_general("Bag 0 item '" .. name .. "' will be moved out: " .. reason)
                        else
                            -- Disenchant-ready items already in bag 0 (leave them)
                            table.insert(readyForDisenchant, {b = b, s = s, id = id, name = name, link = link, alreadyInBag0 = true})
                            print_debug_general("Bag 0 item '" .. name .. "' is ready for disenchant and staying in place")
                        end
                    else
                        -- Items in other bags (regular bags or bank)
                        if isReady then
                            -- Items ready for disenchanting (need to move to bag 0)
                            table.insert(readyForDisenchant, {b = b, s = s, id = id, name = name, link = link, fromBank = (b >= 5)})
                            print_debug_general("Found disenchant-ready item in bag " .. b .. ": " .. name)
                        else
                            print_debug_general("Item '" .. name .. "' not ready for disenchant: " .. reason)
                        end
                    end
                end
            else
                -- Empty slots
                if b == 0 then
                    table.insert(availableBag0Slots, s) -- Already empty slots in bag 0
                end
            end
        end
    end

    -- Sort available bag 0 slots in ascending order
    table.sort(availableBag0Slots)

    local itemsFromBank = 0
    local itemsFromRegularBags = 0
    for _, item in ipairs(readyForDisenchant) do
        if not item.alreadyInBag0 then
            if item.fromBank then 
                itemsFromBank = itemsFromBank + 1 
            else 
                itemsFromRegularBags = itemsFromRegularBags + 1 
            end
        end
    end

    print("|cffffd200[Attune Helper]|r Found " .. #readyForDisenchant .. " items ready for disenchanting" ..
          (itemsFromBank > 0 and " (" .. itemsFromBank .. " from bank, " .. itemsFromRegularBags .. " from regular bags)" or 
           itemsFromRegularBags > 0 and " (" .. itemsFromRegularBags .. " from regular bags)" or "") .. ".")
    
    if #availableBag0Slots > 0 then
        print("|cffffd200[Attune Helper]|r Available bag 0 slots: " .. table.concat(availableBag0Slots, ", "))
    end

    -- Function to safely move items
    local function MoveItem(fromBag, fromSlot, toBag, toSlot)
        if GetContainerItemID(fromBag, fromSlot) then
            PickupContainerItem(fromBag, fromSlot)
            if GetContainerItemID(toBag, toSlot) then
                -- Target slot has item, need to swap
                PickupContainerItem(toBag, toSlot)
                PickupContainerItem(fromBag, fromSlot)
            else
                -- Target slot is empty
                PickupContainerItem(toBag, toSlot)
            end
        end
    end

    -- Step 1: Move non-disenchant-ready items out of bag 0 to make room
    local nonReadyMoved = 0
    for _, b in ipairs(bagsToScan) do
        if b == 0 then
            for s = 1, GetContainerNumSlots(b) do
                local id = GetContainerItemID(b, s)
                if id then
                    local link = GetContainerItemLink(b, s)
                    local name = GetItemInfo(id)
                    
                    if link and name then
                        local isReady, reason = IsReadyForDisenchant(id, link, name, b, s)
                        if not isReady and #emptyS > 0 then
                            local target = table.remove(emptyS)
                            if target then
                                MoveItem(b, s, target.b, target.s)
                                nonReadyMoved = nonReadyMoved + 1
                                print("|cffffd200[Attune Helper]|r Moved non-disenchant item from bag 0: " .. name .. " (" .. reason .. ")")
                            end
                        end
                    end
                end
            end
            break -- Only process bag 0 for this step
        end
    end

    -- Step 2: Move disenchant-ready items to bag 0
    local disenchantItemsMoved = 0
    local slotIndex = 1

    for _, item in ipairs(readyForDisenchant) do
        if not item.alreadyInBag0 and slotIndex <= #availableBag0Slots then
            local targetSlot = availableBag0Slots[slotIndex]
            MoveItem(item.b, item.s, 0, targetSlot)
            disenchantItemsMoved = disenchantItemsMoved + 1
            print("|cffffd200[Attune Helper]|r Moved disenchant-ready item to bag 0 slot " .. targetSlot .. ": " .. 
                  item.name .. (item.fromBank and " (from bank)" or ""))
            slotIndex = slotIndex + 1
        elseif not item.alreadyInBag0 then
            print("|cffff0000[Attune Helper]|r No more available slots in bag 0 for: " .. item.name)
        end
    end

    print("|cffffd200[Attune Helper]|r Prepare Disenchant complete. Moved " .. disenchantItemsMoved .. 
          " disenchant-ready items to bag 0" .. (nonReadyMoved > 0 and ", moved " .. nonReadyMoved .. " other items out of bag 0" or "") .. ".")
    
    if disenchantItemsMoved == 0 and #readyForDisenchant == 0 then
        print("|cffffd200[Attune Helper]|r No items found that are 100% attuned, soulbound, mythic, and not in ignore/set lists.")
    end
end)

-- Helper function to get items that would be vendored
local function GetQualifyingVendorItems()
    local itemsToVendor = {}
    local boeScanTT = nil

    print_debug_vendor_preview("=== GetQualifyingVendorItems: Starting scan ===")

    local function IsBoEUnboundForVendorCheck(itemID, bag, slot_idx)
        if not itemID then return false end
        if not boeScanTT then
            boeScanTT = CreateFrame("GameTooltip", "AHBoEScanVendor", UIParent, "GameTooltipTemplate")
        end
        boeScanTT:SetOwner(UIParent, "ANCHOR_NONE")
        boeScanTT:SetHyperlink("item:" .. itemID)
        local isBoE = false
        for i = 1, boeScanTT:NumLines() do
            local lt = _G[boeScanTT:GetName() .. "TextLeft" .. i]
            if lt and string.find(lt:GetText() or "", "Binds when equipped") then
                isBoE = true
                break
            end
        end
        if isBoE and bag and slot_idx then
            boeScanTT:SetOwner(UIParent, "ANCHOR_NONE")
            boeScanTT:SetBagItem(bag, slot_idx)
            for i = 1, boeScanTT:NumLines() do
                local lt = _G[boeScanTT:GetName() .. "TextLeft" .. i]
                if lt and string.find(lt:GetText() or "", "Soulbound") then
                    boeScanTT:Hide()
                    return false -- It's BoE but already bound
                end
            end
        end
        boeScanTT:Hide()
        return isBoE -- True if BoE and not found to be Soulbound
    end

    -- Determine which bags to scan (include bank if open)
    local bagsToScan = {0, 1, 2, 3, 4}
    if BankFrame and BankFrame:IsShown() then
        for bankBag = 5, 11 do
            table.insert(bagsToScan, bankBag)
        end
        print_debug_vendor_preview("GetQualifying: Including bank bags in vendor scan.")
    end

    print_debug_vendor_preview("GetQualifying: Scanning bags: " .. table.concat(bagsToScan, ", "))

    local totalItemsProcessed = 0
    local itemsSkippedCount = 0

    for bagIndex, b in ipairs(bagsToScan) do
        print_debug_vendor_preview("GetQualifying: === Processing bag " .. b .. " (index " .. bagIndex .. ") ===")
        
        local bagSlots = GetContainerNumSlots(b)
        print_debug_vendor_preview("GetQualifying: Bag " .. b .. " has " .. bagSlots .. " slots")
        
        for s = 1, bagSlots do
            totalItemsProcessed = totalItemsProcessed + 1
            
            local link = GetContainerItemLink(b, s)
            local id = GetContainerItemID(b, s)
            
            print_debug_vendor_preview("GetQualifying: Bag " .. b .. " Slot " .. s .. " - Link: " .. tostring(link and "exists" or "nil") .. ", ID: " .. tostring(id))
            
            if link and id then
                -- Wrap GetItemInfo in pcall to catch any errors
                local success, n, itemLinkFull, q, _, _, _, _, _, itemTexture, _, sellP = pcall(GetItemInfo, link)
                
                if success and n then
                    print_debug_vendor_preview("GetQualifying: Processing item: " .. n .. " (ID: " .. id .. ")")
                    
                    local skip = false
                    local skipReason = ""

                    -- Enhanced sell price check
                    if not sellP or sellP == 0 then
                        skip = true
                        skipReason = "No/Zero sell price (" .. tostring(sellP) .. ")"
                        print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                    end

                    -- Double-check with container item info for sell price
                    if not skip then
                        local containerSuccess, _, itemCount, _, _, _, _, cLink = pcall(GetContainerItemInfo, b, s)
                        if containerSuccess and cLink then
                            local linkSuccess, _, _, _, _, _, _, _, _, _, cSellPrice = pcall(GetItemInfo, cLink)
                            if linkSuccess and (not cSellPrice or cSellPrice == 0) then
                                skip = true
                                skipReason = "Container check - No/Zero sell price"
                                print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                            end
                        end
                    end

                    if not skip and AHIgnoreList[n] then
                        skip = true
                        skipReason = "In AHIgnore list"
                        print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                    end

                    if not skip and AHSetList[n] then
                        skip = true
                        skipReason = "In AHSet list"
                        print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                    end

                    -- Check equipment sets
                    if not skip and GetNumEquipmentSets then
                        local inEquipSet = false
                        for i = 1, GetNumEquipmentSets() do
                            local _, _, sID = GetEquipmentSetInfo(i)
                            if sID then
                                local ids = {GetEquipmentSetItemIDs(sID)}
                                for _, idS in ipairs(ids) do
                                    if idS and idS ~= 0 and idS == id then
                                        inEquipSet = true
                                        break
                                    end
                                end
                            end
                            if inEquipSet then break end
                        end
                        if inEquipSet then
                            skip = true
                            skipReason = "In Equipment Set"
                            print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                        end
                    end

                    -- Check attunement progress
                    if not skip then
                        local thisVariantProgress = 0
                        if _G.GetItemLinkAttuneProgress then
                            local progressSuccess, progress = pcall(GetItemLinkAttuneProgress, link)
                            if progressSuccess and type(progress) == "number" then
                                thisVariantProgress = progress
                            else
                                print_debug_vendor_preview("GetQualifying: GetItemLinkAttuneProgress failed or returned non-number for " .. link .. ": " .. tostring(progress))
                                thisVariantProgress = 0
                            end
                        else
                            print_debug_vendor_preview("GetQualifying: GetItemLinkAttuneProgress API not available for " .. link)
                            thisVariantProgress = 0
                        end

                        local isThisVariantFullyAttuned = (thisVariantProgress >= 100)

                        if not isThisVariantFullyAttuned then
                            skip = true
                            skipReason = "This variant only " .. thisVariantProgress .. "% attuned"
                            print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                        else
                            print_debug_vendor_preview("GetQualifying: " .. n .. " - this variant is " .. thisVariantProgress .. "% attuned, eligible for selling consideration")
                        end
                    end

                    -- Final qualification checks
                    if not skip then
                        local isBoEU, isMSuccess, isM = false, true, false
                        
                        -- BoE check
                        local boeSuccess, boeResult = pcall(IsBoEUnboundForVendorCheck, id, b, s)
                        if boeSuccess then
                            isBoEU = boeResult
                        else
                            print_debug_vendor_preview("GetQualifying: BoE check failed for " .. n .. ": " .. tostring(boeResult))
                        end
                        
                        -- Mythic check
                        isMSuccess, isM = pcall(IsMythic, id)
                        if not isMSuccess then
                            print_debug_vendor_preview("GetQualifying: Mythic check failed for " .. n .. ": " .. tostring(isM))
                            isM = false
                        end
                        
                        local noSellBoE = (AttuneHelperDB["Do Not Sell BoE Items"] == 1 and isBoEU)
                        local sellM = (AttuneHelperDB["Sell Attuned Mythic Gear?"] == 1)
                        local doSell = (isM and sellM) or not isM

                        print_debug_vendor_preview("GetQualifying: " .. n .. " - isBoEU:" .. tostring(isBoEU) .. ", isM:" .. tostring(isM) .. ", noSellBoE:" .. tostring(noSellBoE) .. ", doSell:" .. tostring(doSell))

                        if doSell and not noSellBoE then
                            table.insert(itemsToVendor, {
                                name = n,
                                link = link,
                                id = id,
                                quality = q,
                                bag = b,
                                slot = s
                            })
                            print_debug_vendor_preview("GetQualifying: ✓ ADDING to vendor list: " .. n)
                        else
                            skip = true
                            skipReason = "BoE/Mythic rules (doSell=" .. tostring(doSell) .. ", noSellBoE=" .. tostring(noSellBoE) .. ")"
                            print_debug_vendor_preview("GetQualifying: Skipping " .. n .. " - " .. skipReason)
                        end
                    end

                    if skip then
                        itemsSkippedCount = itemsSkippedCount + 1
                    end
                else
                    -- GetItemInfo failed
                    if not success then
                        print_debug_vendor_preview("GetQualifying: ERROR - GetItemInfo failed for " .. link .. ": " .. tostring(n))
                    else
                        print_debug_vendor_preview("GetQualifying: GetItemInfo returned nil name for " .. link)
                    end
                end
            else
                -- Empty slot
                print_debug_vendor_preview("GetQualifying: Bag " .. b .. " Slot " .. s .. " is empty")
            end
        end
        
        print_debug_vendor_preview("GetQualifying: === Finished processing bag " .. b .. " ===")
    end
    
    print_debug_vendor_preview("GetQualifying: Scan complete. Processed " .. totalItemsProcessed .. " total slots, skipped " .. itemsSkippedCount .. " items, found " .. #itemsToVendor .. " items for vendor.")
    
    for i, item in ipairs(itemsToVendor) do
        print_debug_vendor_preview("GetQualifying: Final list [" .. i .. "]: " .. item.name)
    end
    
    return itemsToVendor
end

local function SellQualifiedItemsFromDialog(itemsToSellFromDialog)
    if not MerchantFrame:IsShown() then
        print_debug_vendor_preview("SellQualifiedItemsFromDialog: Merchant frame not shown.")
        return
    end
    if #itemsToSellFromDialog == 0 then
        print_debug_vendor_preview("SellQualifiedItemsFromDialog: No items to sell.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[Attune Helper]|r No items to vendor based on current settings.")
        return
    end

    local limitSelling = (AttuneHelperDB["Limit Selling to 12 Items?"] == 1)
    local maxSellCount = limitSelling and 12 or #itemsToSellFromDialog
    local soldCount = 0

    print_debug_vendor_preview("SellQualifiedItemsFromDialog: Attempting to sell up to " .. maxSellCount .. " items.")

    for i = 1, math.min(#itemsToSellFromDialog, maxSellCount) do
        local item = itemsToSellFromDialog[i]
        if item and item.bag and item.slot then
            local currentItemLinkInSlot = GetContainerItemLink(item.bag, item.slot)
            if currentItemLinkInSlot and currentItemLinkInSlot == item.link then -- Check if item is still there
                UseContainerItem(item.bag, item.slot)
                soldCount = soldCount + 1
                print("|cffffd200[Attune Helper]|r Sold: " .. item.name)
                print_debug_vendor_preview("SellQualifiedItemsFromDialog: Sold " .. item.name .. " from bag " .. item.bag .. ", slot " .. item.slot)
            else
                print_debug_vendor_preview("SellQualifiedItemsFromDialog: Item " .. item.name .. " no longer at bag " .. item.bag .. ", slot " .. item.slot .. " or changed. Skipping.")
            end
        else
            print_debug_vendor_preview("SellQualifiedItemsFromDialog: Error - item record invalid for selling: " .. tostring(item and item.name or "Unknown"))
        end
    end

    if soldCount > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffd200[Attune Helper]|r Sold %d item(s).", soldCount))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[Attune Helper]|r No items were actually sold (they might have been moved or settings changed).")
    end
end

StaticPopupDialogs["AH_VENDOR_CONFIRM"] = {
  text = "%s", -- Will be formatted with the list of items
  button1 = "Sell",
  button2 = "Cancel",
  OnAccept = function(self, data) -- Added self parameter
    if data and data.itemsToSell then
        SellQualifiedItemsFromDialog(data.itemsToSell)
    end
  end,
  OnCancel = function()
    print_debug_vendor_preview("Vendor confirmation cancelled.")
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
  -- Make the dialog wider to accommodate icons and text
  maxWidth = 450, -- Increased width
  minWidth = 350,
}

VendorAttunedButton = CreateButton("AttuneHelperVendorAttunedButton",AttuneHelper,"Vendor Attuned",SortInventoryButton,"BOTTOM",0,-27,nil,nil,nil,1.3)
VendorAttunedButton:SetScript("OnClick",function(self) -- self is the button clicked
    if not MerchantFrame:IsShown() then
        print_debug_vendor_preview("VendorAttunedButton: Merchant frame not shown.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Attune Helper]|r You must have a merchant window open to vendor items.")
        return
    end

    local itemsToSell = GetQualifyingVendorItems()
    if #itemsToSell == 0 then
        print_debug_vendor_preview("VendorAttunedButton: No items qualify for vendoring.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[Attune Helper]|r No items to vendor based on current settings.")
        return
    end

    if AttuneHelperDB["EnableVendorSellConfirmationDialog"] == 1 then
        local confirmText = "|cffffd200The following items will be sold:|r\n\n"
        local itemCountInPopup = 0
        for i, itemData in ipairs(itemsToSell) do
            if i <= 10 then -- Limit items shown in popup text to avoid excessive length and allow space for icons
                local _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link) -- Fetch icon dynamically
                local iconString = ""
                if itemTexture then
                    iconString = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", itemTexture) -- Added offsets for better spacing
                end
                -- The itemData.link already contains quality coloring and is mouseoverable
                confirmText = confirmText .. iconString .. (itemData.link or itemData.name) .. "\n"
                itemCountInPopup = itemCountInPopup + 1
            else
                confirmText = confirmText .. "\n|cffcccccc...and " .. (#itemsToSell - itemCountInPopup) .. " more items.|r"
                break
            end
        end
        confirmText = confirmText .. "\n\nAre you sure you want to sell these items?"
        StaticPopup_Show("AH_VENDOR_CONFIRM", confirmText, nil, {itemsToSell = itemsToSell})
        print_debug_vendor_preview("VendorAttunedButton: Showing confirmation dialog for " .. #itemsToSell .. " items.")
    else
        -- Sell directly without confirmation
        print_debug_vendor_preview("VendorAttunedButton: Selling directly, confirmation dialog disabled.")
        SellQualifiedItemsFromDialog(itemsToSell)
    end
end)


ApplyButtonTheme(AttuneHelperDB["Button Theme"])
AttuneHelperItemCountText=AttuneHelper:CreateFontString(nil,"OVERLAY","GameFontNormal") AttuneHelperItemCountText:SetPoint("BOTTOM",0,6) AttuneHelperItemCountText:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE") AttuneHelperItemCountText:SetTextColor(1,1,1,1) AttuneHelperItemCountText:SetText("Attunables in Inventory: 0")
AH_wait(4,UpdateItemCountText)
local function CreateMiniIconButton(name,parent,iconPath,size,tooltipText)
    local btn=CreateFrame("Button",name,parent)
    btn:SetSize(size,size)
    btn:SetNormalTexture(iconPath)
    btn:SetBackdrop({edgeFile="Interface\\Buttons\\UI-Quickslot-Depress",edgeSize=2,insets={left=-1,right=-1,top=-1,bottom=-1}})
    btn:SetBackdropBorderColor(0.4,0.4,0.4,0.6)
    local hl=btn:CreateTexture(nil,"HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetTexture(iconPath)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.2,0.2,0.2,0.3)
    btn:SetScript("OnMouseDown",function(s)s:GetNormalTexture():SetVertexColor(0.75,0.75,0.75)end)
    btn:SetScript("OnMouseUp",function(s)s:GetNormalTexture():SetVertexColor(1,1,1)end)

    -- Only add simple tooltip for non-equip/non-vendor buttons initially
    if tooltipText and name ~= "AttuneHelperMiniEquipButton" and name ~= "AttuneHelperMiniVendorButton" then
        btn:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end
    return btn
  end

  AttuneHelperMiniFrame = CreateFrame("Frame", "AttuneHelperMiniFrame", UIParent)
  AttuneHelperMiniFrame:SetSize(88, 32)

  -- Safe positioning with validation for mini frame
  if AttuneHelperDB.MiniFramePosition then
      local pos = AttuneHelperDB.MiniFramePosition
      -- Check if position data is valid
      if pos and #pos >= 5 and pos[1] and pos[3] and pos[4] ~= nil and pos[5] ~= nil then
          -- Use pcall to safely attempt positioning
          local success, err = pcall(function()
              AttuneHelperMiniFrame:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
          end)
          if not success then
              print_debug_general("Failed to restore mini frame position, using default: " .. tostring(err))
              AttuneHelperMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
              AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
          end
      else
          -- Reset to default if position data is invalid
          AttuneHelperMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
          AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
      end
  else
      -- No saved position, use default
      AttuneHelperMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
  end

  AttuneHelperMiniFrame:EnableMouse(true)
  AttuneHelperMiniFrame:SetMovable(true)
  AttuneHelperMiniFrame:RegisterForDrag("LeftButton")

  AttuneHelperMiniFrame:SetScript("OnDragStart", function(s)
      if s:IsMovable() then
          s:StartMoving()
      end
  end)

  -- Fixed drag stop handler for mini frame
  AttuneHelperMiniFrame:SetScript("OnDragStop", function(s)
      s:StopMovingOrSizing()
      local point, relativeTo, relativePoint, xOfs, yOfs = s:GetPoint()
      -- Always save with UIParent as the relative frame for consistency
      AttuneHelperDB.MiniFramePosition = {point, UIParent, relativePoint, xOfs, yOfs}
  end)

  AttuneHelperMiniFrame:SetBackdrop({
      bgFile = BgStyles.MiniModeBg,
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 16,
      insets = {left = 1, right = 1, top = 1, bottom = 1}
  })

  AttuneHelperMiniFrame:SetBackdropColor(
      AttuneHelperDB["Background Color"][1],
      AttuneHelperDB["Background Color"][2],
      AttuneHelperDB["Background Color"][3],
      AttuneHelperDB["Background Color"][4]
  )

  AttuneHelperMiniFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
  AttuneHelperMiniFrame:Hide()

  local mBS = 24 local mS = 4 local fP = (AttuneHelperMiniFrame:GetHeight() - mBS) / 2
AttuneHelperMiniEquipButton = CreateMiniIconButton(
    "AttuneHelperMiniEquipButton",
    AttuneHelperMiniFrame,
    "Interface\\Addons\\AttuneHelper\\assets\\icon1.blp",
    mBS,
    "Equip Attunables" -- Simple text, detailed in OnEnter
)
AttuneHelperMiniEquipButton:SetPoint("LEFT", AttuneHelperMiniFrame, "LEFT", fP, 0)

if EquipAllButton then
    AttuneHelperMiniEquipButton:SetScript("OnClick", function()
        if EquipAllButton:GetScript("OnClick") then
            EquipAllButton:GetScript("OnClick")()
        end
    end)
end

-- Override the tooltip for the mini equip button to include icons
AttuneHelperMiniEquipButton:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:SetText("Equip Attunables")

    local attunableData = GetAttunableItemNamesList()
    local count = #attunableData

    if count > 0 then
        GameTooltip:AddLine(string.format("Qualifying Attunables (%d):", count), 1, 1, 0) -- Yellow text
        for _, itemData in ipairs(attunableData) do
            -- Get item info including quality and texture
            local _, itemLinkFull, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link) -- Use itemData.link
            local iconText = ""

            if itemTexture then
                -- Create icon texture code (16x16 size)
                iconText = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", itemTexture)
            end

            -- Get item quality color
            local qualityColor = ITEM_QUALITY_COLORS[itemQuality or 1]
            local r, g, b = 0.8, 0.8, 0.8 -- default color
            if qualityColor then
                r, g, b = qualityColor.r, qualityColor.g, qualityColor.b
            end

            -- Build item name with forge/mythic indicators
            local itemName = itemData.name
            local indicators = {}

            -- Check if mythic
            if itemData.id >= MYTHIC_MIN_ITEMID then
                table.insert(indicators, "|cffFF6600[Mythic]|r")
            end

            -- Check forge level
            local forgeLevel = GetForgeLevelFromLink(itemData.link) -- Use itemData.link
            if forgeLevel == FORGE_LEVEL_MAP.WARFORGED then
                table.insert(indicators, "|cff9900FF[WF]|r")
            elseif forgeLevel == FORGE_LEVEL_MAP.LIGHTFORGED then
                table.insert(indicators, "|cffFFD700[LF]|r")
            elseif forgeLevel == FORGE_LEVEL_MAP.TITANFORGED then
                table.insert(indicators, "|cff00CCFF[TF]|r")
            end

            -- Combine name with indicators
            local displayName = itemName
            if #indicators > 0 then
                displayName = displayName .. " " .. table.concat(indicators, " ")
            end

            -- Add the line with icon and colored item name
            GameTooltip:AddLine(iconText .. displayName, r, g, b, true)
        end
    else
        GameTooltip:AddLine("No qualifying attunables in bags.", 1, 0.5, 0.5, true) -- Reddish if none
    end

    GameTooltip:Show()
end)
AttuneHelperMiniEquipButton:SetScript("OnLeave", GameTooltip_Hide)

-- Create and setup AttuneHelperMiniSortButton
AttuneHelperMiniSortButton = CreateMiniIconButton(
    "AttuneHelperMiniSortButton",
    AttuneHelperMiniFrame,
    "Interface\\Addons\\AttuneHelper\\assets\\icon2.blp",
    mBS,
    "Prepare Disenchant"
)
AttuneHelperMiniSortButton:SetPoint("LEFT", AttuneHelperMiniEquipButton, "RIGHT", mS, 0)

if SortInventoryButton then
    AttuneHelperMiniSortButton:SetScript("OnClick", function()
        if SortInventoryButton:GetScript("OnClick") then
            SortInventoryButton:GetScript("OnClick")()
        end
    end)
end

-- Create and setup AttuneHelperMiniVendorButton
AttuneHelperMiniVendorButton = CreateMiniIconButton(
    "AttuneHelperMiniVendorButton",
    AttuneHelperMiniFrame,
    "Interface\\Addons\\AttuneHelper\\assets\\icon3.blp",
    mBS,
    "Vendor Attuned" -- Simple text, detailed in OnEnter
)
AttuneHelperMiniVendorButton:SetPoint("LEFT", AttuneHelperMiniSortButton, "RIGHT", mS, 0)

if VendorAttunedButton then
    AttuneHelperMiniVendorButton:SetScript("OnClick", function(self) -- Pass self
        if VendorAttunedButton:GetScript("OnClick") then
            VendorAttunedButton:GetScript("OnClick")(self) -- Call with self
        end
    end)
end

-- Tooltip for VendorAttunedButton (Main Frame)
if VendorAttunedButton then
    VendorAttunedButton:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Vendor Attuned Items")
        local itemsToVendor = GetQualifyingVendorItems()

        if #itemsToVendor > 0 then
            GameTooltip:AddLine(string.format("Items to be sold (%d):", #itemsToVendor), 1, 1, 0) -- Yellow
            for _, itemData in ipairs(itemsToVendor) do
                local _, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link) -- Fetch icon dynamically
                local iconText = ""
                if itemTexture then
                    iconText = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", itemTexture)
                end
                local qualityColor = ITEM_QUALITY_COLORS[itemQuality or 1] -- Use fetched quality
                local r, g, b = 0.8, 0.8, 0.8
                if qualityColor then r, g, b = qualityColor.r, qualityColor.g, qualityColor.b end
                GameTooltip:AddLine(iconText .. itemData.name, r, g, b, true)
            end
        else
            GameTooltip:AddLine("No items will be sold based on current settings.", 0.8, 0.8, 0.8, true)
        end

        if not (MerchantFrame and MerchantFrame:IsShown()) then
            GameTooltip:AddLine("Open merchant window to sell these items.",1,0.8,0.2, true) -- Orange/Yellowish
        end
        GameTooltip:Show()
    end)
    VendorAttunedButton:SetScript("OnLeave", GameTooltip_Hide)
end

-- Tooltip for AttuneHelperMiniVendorButton
if AttuneHelperMiniVendorButton then
    AttuneHelperMiniVendorButton:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Vendor Attuned Items")
        local itemsToVendor = GetQualifyingVendorItems()

        if #itemsToVendor > 0 then
            GameTooltip:AddLine(string.format("Items to be sold (%d):", #itemsToVendor), 1, 1, 0) -- Yellow
            for _, itemData in ipairs(itemsToVendor) do
                local _, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link) -- Fetch icon dynamically
                local iconText = ""
                if itemTexture then
                    iconText = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", itemTexture)
                end
                local qualityColor = ITEM_QUALITY_COLORS[itemQuality or 1] -- Use fetched quality
                local r, g, b = 0.8, 0.8, 0.8
                if qualityColor then r, g, b = qualityColor.r, qualityColor.g, qualityColor.b end
                GameTooltip:AddLine(iconText .. itemData.name, r, g, b, true)
            end
        else
            GameTooltip:AddLine("No items will be sold based on current settings.", 0.8, 0.8, 0.8, true)
        end

        if not (MerchantFrame and MerchantFrame:IsShown()) then
            GameTooltip:AddLine("Open merchant window to sell these items.",1,0.8,0.2, true) -- Orange/Yellowish
        end
        GameTooltip:Show()
    end)
    AttuneHelperMiniVendorButton:SetScript("OnLeave", GameTooltip_Hide)
end


-- Setup the main EquipAllButton tooltip with icons
if EquipAllButton then
    EquipAllButton:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Equip Attunables")
        GameTooltip:AddLine(string.format("Attunable Items: %d", currentAttunableItemCount), 1, 1, 0)

        -- Add detailed list with icons
        local attunableData = GetAttunableItemNamesList()
        if #attunableData > 0 then
            GameTooltip:AddLine(" ") -- Empty line for spacing
            for _, itemData in ipairs(attunableData) do
                -- Get item info including quality and texture
                local _, itemLinkFull, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link) -- Use itemData.link
                local iconText = ""

                if itemTexture then
                    iconText = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", itemTexture)
                end

                -- Get item quality color
                local qualityColor = ITEM_QUALITY_COLORS[itemQuality or 1]
                local r, g, b = 0.8, 0.8, 0.8 -- default color
                if qualityColor then
                    r, g, b = qualityColor.r, qualityColor.g, qualityColor.b
                end

                -- Build item name with forge/mythic indicators
                local itemName = itemData.name
                local indicators = {}

                -- Check if mythic
                if itemData.id >= MYTHIC_MIN_ITEMID then
                    table.insert(indicators, "|cffFF6600[Mythic]|r")
                end

                -- Check forge level
                local forgeLevel = GetForgeLevelFromLink(itemData.link) -- Use itemData.link
                if forgeLevel == FORGE_LEVEL_MAP.WARFORGED then
                    table.insert(indicators, "|cff9900FF[WF]|r")
                elseif forgeLevel == FORGE_LEVEL_MAP.LIGHTFORGED then
                    table.insert(indicators, "|cffFFD700[LF]|r")
                elseif forgeLevel == FORGE_LEVEL_MAP.TITANFORGED then
                    table.insert(indicators, "|cff00CCFF[TF]|r")
                end

                -- Combine name with indicators
                local displayName = itemName
                if #indicators > 0 then
                    displayName = displayName .. " " .. table.concat(indicators, " ")
                end

                GameTooltip:AddLine(iconText .. displayName, r, g, b, true)
            end
        end

        GameTooltip:Show()
    end)
    EquipAllButton:SetScript("OnLeave", GameTooltip_Hide)
end

AttuneHelper_UpdateDisplayMode = function()
    if not AttuneHelperFrame or not AttuneHelperMiniFrame then return end
    local bgC=AttuneHelperDB["Background Color"]
    if AttuneHelperDB["Mini Mode"]==1 then
        AttuneHelperFrame:Hide() AttuneHelperMiniFrame:Show()
        AttuneHelperMiniFrame:SetBackdropColor(bgC[1],bgC[2],bgC[3],bgC[4])
    else
        AttuneHelperMiniFrame:Hide() AttuneHelperFrame:Show()
        local cS=AttuneHelperDB["Background Style"]or"Tooltip"
        local bfU=BgStyles[cS]or BgStyles["Tooltip"]
        local nT=(cS=="Atunament"or cS=="Always Bee Attunin'")
        AttuneHelper:SetBackdrop{bgFile=bfU,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=(not nt),tileSize=(nT and 0 or 16),edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}
        AttuneHelper:SetBackdropColor(unpack(bgC))
    end
    UpdateItemCountText()
    ApplyButtonTheme(AttuneHelperDB["Button Theme"])
end

SLASH_ATTUNEHELPER1="/ath" SlashCmdList["ATTUNEHELPER"]=function(msg)
    local cmd = msg:lower():match("^(%S*)")
    if cmd=="reset"then
        AttuneHelper:ClearAllPoints()
        AttuneHelper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        AttuneHelperDB.FramePosition={"CENTER", UIParent, "CENTER", 0, 0}
        if AttuneHelperMiniFrame then
            AttuneHelperMiniFrame:ClearAllPoints()
            AttuneHelperMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            AttuneHelperDB.MiniFramePosition={"CENTER", UIParent, "CENTER", 0, 0}
        end
    elseif cmd=="show"then if AttuneHelperDB["Mini Mode"]==1 and AttuneHelperMiniFrame then AttuneHelperMiniFrame:Show()else AttuneHelper:Show()end
    elseif cmd=="hide"then if AttuneHelperDB["Mini Mode"]==1 and AttuneHelperMiniFrame then AttuneHelperMiniFrame:Hide()else AttuneHelper:Hide()end
    elseif cmd=="sort"then local fn=SortInventoryButton and SortInventoryButton:GetScript("OnClick") if fn then fn()end
    elseif cmd=="equip"then local fn=EquipAllButton and EquipAllButton:GetScript("OnClick") if fn then fn()end
    elseif cmd=="vendor"then
        local buttonToClick = VendorAttunedButton
        if AttuneHelperDB["Mini Mode"] == 1 and AttuneHelperMiniVendorButton then
            buttonToClick = AttuneHelperMiniVendorButton
        end
        if buttonToClick and buttonToClick:GetScript("OnClick") then
            buttonToClick:GetScript("OnClick")(buttonToClick) -- Pass the button itself as 'self'
        end
    else print("/ath show|hide|reset|equip|sort|vendor")end
end

SLASH_AHIGNORE1="/AHIgnore" SlashCmdList["AHIGNORE"]=function(msg)
    local itemName=GetItemInfo(msg)
    if not itemName then print("Invalid item link.") return end
    AHIgnoreList[itemName]=not AHIgnoreList[itemName]
    print(itemName..(AHIgnoreList[itemName]and" is now ignored."or" will no longer be ignored."))
end

SLASH_AHSET1="/AHSet" SlashCmdList["AHSET"]=function(msg)
  local itemLinkPart = msg:match("^%s*(.-)%s*$") -- Trim leading/trailing whitespace from the whole message first
  local slotArg = ""
  local msgLower = itemLinkPart:lower() -- Use trimmed and lowercased message for keyword matching

  -- Build a list of keywords to check at the end of the string
  -- These keywords will be checked in lowercase
  local knownKeywords = {"remove"}
  if slotAliases then -- Ensure slotAliases is available
      for alias, _ in pairs(slotAliases) do
          table.insert(knownKeywords, alias:lower())
      end
  end
  for _, slotNameValue in ipairs(allInventorySlots) do -- Renamed loop variable for clarity
      table.insert(knownKeywords, slotNameValue:lower())
  end

  -- Sort keywords by length, longest first, to avoid partial matches
  table.sort(knownKeywords, function(a,b) return #a > #b end)

  local foundKeyword = false
  for _, keyword in ipairs(knownKeywords) do
      -- Check if the message ends with " <keyword>"
      -- Ensure there's enough length for the space + keyword
      if msgLower:len() >= (keyword:len() + 1) and msgLower:sub(- (keyword:len() + 1)) == " " .. keyword then
          -- Keyword found at the end, extract original casing for slotArg
          slotArg = itemLinkPart:sub(-keyword:len())
          -- The rest is the itemLinkPart
          itemLinkPart = itemLinkPart:sub(1, itemLinkPart:len() - (keyword:len() + 1))
          itemLinkPart = itemLinkPart:match("^%s*(.-)%s*$") or "" -- Trim again
          foundKeyword = true
          break
      end
  end

  if not itemLinkPart or itemLinkPart == "" then
      print("|cffff0000[AttuneHelper]|r Usage: /ahset <itemlink> [mh|oh|SlotName|remove]")
      print("|cffff0000[AttuneHelper]|r SlotName examples: HeadSlot, Finger0Slot, Trinket1Slot")
      print("|cffff0000[AttuneHelper]|r For armor/jewelry, you can often omit the slot argument.")
      print("|cffff0000[AttuneHelper]|r For weapons/offhands, a slot argument (mh, oh, RangedSlot) is required.")
      print("|cffff0000[AttuneHelper]|r Use 'remove' to clear an item from AHSet.")
      return
  end

  local itemName, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLinkPart)
  if not itemName then
      print("|cffff0000[AttuneHelper]|r Invalid item link provided: '".. itemLinkPart .."'. Please link a valid item.")
      return
  end

  local processedSlotArg = slotArg:lower()

  if processedSlotArg == "remove" then
      if AHSetList[itemName] then
          AHSetList[itemName] = nil
          print("|cffffd200[AttuneHelper]|r '" .. itemName .. "' removed from AHSet.")
          for i=0,4 do UpdateBagCache(i) end
          UpdateItemCountText()
      else
          print("|cffffd200[AttuneHelper]|r '" .. itemName .. "' was not in AHSet.")
      end
      return
  end

  local targetSlotName = nil
  local slotArgIsAliasOrDirect = false

  if processedSlotArg ~= "" then
      if slotAliases and slotAliases[processedSlotArg] then
          targetSlotName = slotAliases[processedSlotArg]
          slotArgIsAliasOrDirect = true
      else
          for _, validSlot in ipairs(allInventorySlots) do
              if string.lower(validSlot) == processedSlotArg then
                  targetSlotName = validSlot
                  slotArgIsAliasOrDirect = true
                  break
              end
          end
      end

      if not slotArgIsAliasOrDirect then
          print("|cffff0000[AttuneHelper]|r Invalid slot argument: '" .. slotArg .. "'. Use mh, oh, remove, or a valid slot name (e.g. HeadSlot, Finger0Slot).")
          return
      end
  else
      local weaponAndOffhandTypes = {
          INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
          INVTYPE_HOLDABLE = true, INVTYPE_SHIELD = true,
          INVTYPE_RANGED = true, INVTYPE_THROWN = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_RELIC = true, INVTYPE_WAND = true
      }

      if weaponAndOffhandTypes[itemEquipLoc] then
          print("|cffff0000[AttuneHelper]|r For items like '" .. itemName .. "' (type: "..itemEquipLoc.."), please specify the target slot: /ahset <itemlink> [mh|oh|RangedSlot|etc]")
          return
      else
          local unifiedSlots = itemTypeToUnifiedSlot[itemEquipLoc]
          if type(unifiedSlots) == "string" then
              targetSlotName = unifiedSlots
          elseif type(unifiedSlots) == "table" then
              print("|cffff0000[AttuneHelper]|r Item '"..itemName.."' (type: "..itemEquipLoc..") can fit multiple slots like "..table.concat(unifiedSlots, " or ")..". Please specify the exact slot (e.g., Finger0Slot, Trinket1Slot).")
              return
          else
              print("|cffff0000[AttuneHelper]|r Could not automatically determine a slot for non-weapon item '" .. itemName .. "' (type: " .. itemEquipLoc .. "). Please specify a slot manually.")
              return
          end
      end
  end

  if not targetSlotName then
      print("|cffff0000[AttuneHelper]|r Could not determine target slot for '" .. itemName .. "'. Logic error or unhandled case.")
      return
  end

  local isSuitable = false
  local unifiedItemSlotsCheck = itemTypeToUnifiedSlot[itemEquipLoc]

  if targetSlotName == "MainHandSlot" then
      isSuitable = (itemEquipLoc == "INVTYPE_WEAPON" or itemEquipLoc == "INVTYPE_2HWEAPON" or itemEquipLoc == "INVTYPE_WEAPONMAINHAND")
  elseif targetSlotName == "SecondaryHandSlot" then
      isSuitable = (itemEquipLoc == "INVTYPE_WEAPON" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND" or itemEquipLoc == "INVTYPE_SHIELD" or itemEquipLoc == "INVTYPE_HOLDABLE")
  elseif targetSlotName == "RangedSlot" then
      isSuitable = (itemEquipLoc == "INVTYPE_RANGED" or itemEquipLoc == "INVTYPE_THROWN" or itemEquipLoc == "INVTYPE_RANGEDRIGHT" or itemEquipLoc == "INVTYPE_RELIC" or itemEquipLoc == "INVTYPE_WAND")
  elseif type(unifiedItemSlotsCheck) == "string" and unifiedItemSlotsCheck == targetSlotName then
      isSuitable = true
  elseif type(unifiedItemSlotsCheck) == "table" and tContains(unifiedItemSlotsCheck, targetSlotName) then
      isSuitable = true
  end

  if not isSuitable then
      print("|cffff0000[AttuneHelper]|r Item '" .. itemName .. "' (type: "..itemEquipLoc..") is not suitable for the target slot: " .. targetSlotName)
      return
  end

  local oldDesignation = AHSetList[itemName]
  if oldDesignation and oldDesignation ~= targetSlotName then
      print_debug_general("AHSet: "..itemName.." was previously set for "..tostring(oldDesignation)..", changing to "..targetSlotName)
  end

  if AHSetList[itemName] == targetSlotName then
      AHSetList[itemName] = nil
      print("|cffffd200[AttuneHelper]|r '" .. itemName .. "' removed from AHSet for slot " .. targetSlotName .. ".")
  else
      AHSetList[itemName] = targetSlotName
      print("|cffffd200[AttuneHelper]|r '" .. itemName .. "' added to AHSet, designated for slot " .. targetSlotName .. ".")
  end

  for i=0,4 do UpdateBagCache(i) end
  UpdateItemCountText()
end

SLASH_ATH2H1="/ah2h" SlashCmdList["ATH2H"]=function()AttuneHelperDB["Disable Two-Handers"]=1-(AttuneHelperDB["Disable Two-Handers"]or 0) print("|cffffd200[AH]|r 2H equipping "..(AttuneHelperDB["Disable Two-Handers"]==1 and"disabled."or"enabled."))end
SLASH_AHTOGGLE1="/ahtoggle" SlashCmdList["AHTOGGLE"]=function()AttuneHelperDB["Auto Equip Attunable After Combat"]=1-(AttuneHelperDB["Auto Equip Attunable After Combat"]or 0) print("|cffffd200[AH]|r Auto-Equip After Combat: "..(AttuneHelperDB["Auto Equip Attunable After Combat"]==1 and"|cff00ff00Enabled|r."or"|cffff0000Disabled|r.")) for _,cb in ipairs(general_option_checkboxes)do if cb.dbKey=="Auto Equip Attunable After Combat"then cb:SetChecked(AttuneHelperDB["Auto Equip Attunable After Combat"]==1) break end end end
SLASH_AHSETLIST1="/ahsetlist" SlashCmdList["AHSETLIST"]=function()local c=0 print("|cffffd200[AH]|r AHSetList Items:") for n,s_val in pairs(AHSetList)do if s_val then print("- "..n .. " (Slot: " .. tostring(s_val) .. ")") c=c+1 end end if c==0 then print("|cffffd200[AH]|r No items in AHSetList.")end end
-- local merchF=CreateFrame("Frame") merchF:RegisterEvent("MERCHANT_SHOW") merchF:RegisterEvent("MERCHANT_UPDATE") merchF:SetScript("OnEvent",function(_,e)if e=="MERCHANT_SHOW"or e=="MERCHANT_UPDATE"then for i=1,GetNumBuybackItems()do local l=GetBuybackItemLink(i) if l then local n=GetItemInfo(l) if AHIgnoreList[n]or AHSetList[n]then BuybackItem(i) print("|cffff0000[AH]|r Bought back: "..n) return end end end end end)

AttuneHelper:RegisterEvent("ADDON_LOADED") AttuneHelper:RegisterEvent("PLAYER_REGEN_DISABLED") AttuneHelper:RegisterEvent("PLAYER_REGEN_ENABLED") AttuneHelper:RegisterEvent("PLAYER_LOGIN") AttuneHelper:RegisterEvent("BAG_UPDATE") AttuneHelper:RegisterEvent("UI_ERROR_MESSAGE") 
AttuneHelper:RegisterEvent("QUEST_COMPLETE")
AttuneHelper:RegisterEvent("QUEST_TURNED_IN") 
AttuneHelper:RegisterEvent("LOOT_CLOSED")
AttuneHelper:RegisterEvent("ITEM_PUSH")

AttuneHelper:SetScript("OnEvent", function(s, e, a1)
    if e == "ADDON_LOADED" and a1 == "AttuneHelper" then
        InitializeDefaultSettings()
        if _G["SCK"] and type(_G["SCK"].loop) == "function" then
            isSCKLoaded = true
            print_debug_general("SCK detected.")
        end
        LoadAllSettings()
        s:UnregisterEvent("ADDON_LOADED")
    end

    if e == "PLAYER_LOGIN" then
        s:UnregisterEvent("PLAYER_LOGIN")
        AH_wait(1, function()
            LoadAllSettings()
        end)
        AH_wait(3, function()
            synEXTloaded = true
            -- Only update regular bags, not bank
            for b = 0, 4 do
                UpdateBagCache(b)
            end
            UpdateItemCountText()
        end)
    elseif e == "BAG_UPDATE" then
        if not synEXTloaded then
            return
        end
        -- Only update regular bags (0-4), skip bank bags (5+)
        if a1 <= 4 then
            UpdateBagCache(a1)
            UpdateItemCountText()
        end
        
        local nT = GetTime()
        if nT - (deltaTime or 0) < CHAT_MSG_SYSTEM_THROTTLE then
            return
        end
        deltaTime = nT
        
        -- Auto-equip logic for both in and out of combat
        if AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
            local fn = EquipAllButton:GetScript("OnClick")
            if fn then
                if InCombatLockdown() then
                    -- In combat - equip immediately with shorter delay
                    AH_wait(0.1, fn)
                else
                    -- Out of combat - use normal delay
                    AH_wait(0.2, fn)
                end
            end
        end
    elseif e == "QUEST_COMPLETE" or e == "QUEST_TURNED_IN" then
        -- Quest rewards might not trigger BAG_UPDATE immediately
        print_debug_general("Quest event detected: " .. e .. ". Scheduling bag cache refresh.")
        AH_wait(0.5, function()
            RefreshAllBagCaches()
            if AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
                local fn = EquipAllButton:GetScript("OnClick")
                if fn then
                    AH_wait(0.2, fn)
                end
            end
        end)
    elseif e == "LOOT_CLOSED" then
        -- Sometimes loot doesn't trigger BAG_UPDATE properly
        print_debug_general("Loot closed. Scheduling bag cache refresh.")
        AH_wait(0.3, function()
            RefreshAllBagCaches()
            if AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
                local fn = EquipAllButton:GetScript("OnClick")
                if fn then
                    AH_wait(0.2, fn)
                end
            end
        end)
    elseif e == "ITEM_PUSH" then
        -- Item push events for items being added to bags
        print_debug_general("Item push event detected. Scheduling bag cache refresh.")
        AH_wait(0.2, function()
            RefreshAllBagCaches()
            if AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
                local fn = EquipAllButton:GetScript("OnClick")
                if fn then
                    AH_wait(0.1, fn)
                end
            end
        end)
    elseif e == "PLAYER_REGEN_ENABLED" and AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
        -- When leaving combat, do a full equip cycle with fresh cache
        print_debug_general("Left combat. Refreshing cache and equipping.")
        AH_wait(0.2, function()
            RefreshAllBagCaches()
            local fn = EquipAllButton:GetScript("OnClick")
            if fn then
                fn()
            end
        end)
    elseif e == "UI_ERROR_MESSAGE" and a1 == ERR_ITEM_CANNOT_BE_EQUIPPED then
        if lastAttemptedSlotForEquip == "SecondaryHandSlot" and IsWeaponTypeForOffHandCheck(lastAttemptedItemTypeForEquip) then
            cannotEquipOffHandWeaponThisSession = true
        end
        lastAttemptedSlotForEquip = nil
        lastAttemptedItemTypeForEquip = nil
    end
end)

SLASH_AHIGNORELIST1="/ahignorelist" SlashCmdList["AHIGNORELIST"]=function()local c=0 print("|cffffd200[AH]|r Ignored:") for n,enable_flag in pairs(AHIgnoreList)do if enable_flag then print("- "..n) c=c+1 end end if c==0 then print("|cffffd200[AH]|r No ignored items.")end end
SLASH_AHBL1="/ahbl" SlashCmdList["AHBL"]=function(m)local k=m:lower():match("^(%S*)") local sV=slotAliases[k] if not sV then print("|cffff0000[AH]|r Usage: /ahbl <slot_keyword> [...]") return end AttuneHelperDB[sV]=1-(AttuneHelperDB[sV]or 0) print(string.format("|cffffd200[AH]|r %s %s.",sV,(AttuneHelperDB[sV]==1 and"blacklisted"or"unblacklisted"))) local cb=_G["AttuneHelperBlacklist_"..sV.."Checkbox"] if cb and cb.SetChecked then cb:SetChecked(AttuneHelperDB[sV]==1)end end
SLASH_AHBLL1="/ahbll" SlashCmdList["AHBLL"]=function()local f=false print("|cffffd200[AH]|r Blacklisted Slots:") for _,sN in ipairs(slots)do if AttuneHelperDB[sN]==1 then print("- "..sN) f=true end end if not f then print("|cffffd200[AH]|r No blacklisted slots.")end end
InitializeDefaultSettings()
if AttuneHelper_UpdateDisplayMode then AH_wait(0.1, AttuneHelper_UpdateDisplayMode) end
