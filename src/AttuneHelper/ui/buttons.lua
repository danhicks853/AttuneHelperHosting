-- ʕ •ᴥ•ʔ✿ UI · Main buttons ✿ ʕ •ᴥ•ʔ
local AH = _G.AttuneHelper

------------------------------------------------------------------------
-- Button creation helper
------------------------------------------------------------------------
function AH.CreateButton(n, p, t, a, ap, x, y, w, h, c, s)
    s = s or 1
    local x1, y1, x2, y2 = 65, 176, 457, 290
    local rw, rh = x2 - x1, y2 - y1
    local u1, u2, v1, v2 = x1 / 512, x2 / 512, y1 / 512, y2 / 512
    
    if w and not h then
        h = w * rh / rw
    elseif h and not w then
        w = h * rw / rh
    else
        h = 24
        w = h * rw / rh * 1.5
    end
    
    local b = CreateFrame("Button", n, p, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetScale(s)
    b:SetPoint(ap, a, ap, x, y)
    b:SetText(AH.t(t))
    
    local thA = AttuneHelperDB["Button Theme"] or "Normal"
    if AH.themePaths[thA] then
        b:SetNormalTexture(AH.themePaths[thA].normal)
        b:SetPushedTexture(AH.themePaths[thA].pushed)
        b:SetHighlightTexture(AH.themePaths[thA].pushed, "ADD")
        
        for _, st in ipairs({"Normal", "Pushed", "Highlight"}) do
            local tx = b["Get" .. st .. "Texture"](b)
            if tx then
                tx:SetTexCoord(u1, u2, v1, v2)
            end
            local cl = c and c[st:lower()]
            if cl and tx then
                tx:SetVertexColor(cl[1], cl[2], cl[3], cl[4] or 1)
            end
        end
    end
    
    local fo = b:GetFontString()
    if fo then
        fo:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end
    
    b:SetBackdropColor(0, 0, 0, 0.5)
    b:SetBackdropBorderColor(1, 1, 1, 1)
    
    return b
end

-- Export for legacy compatibility
_G.CreateButton = AH.CreateButton

------------------------------------------------------------------------
-- Create main frame buttons
------------------------------------------------------------------------
function AH.CreateMainButtons()
    local mainFrame = AH.UI.mainFrame
    if not mainFrame then return end

    -- Equip All Button
    local equipButton = AH.CreateButton(
        "AttuneHelperEquipAllButton",
        mainFrame,
        "Equip Attunables",
        mainFrame,
        "TOP",
        0, -5,
        nil, nil, nil, 1.3
    )

    -- Sort Inventory Button
    local sortButton = AH.CreateButton(
        "AttuneHelperSortInventoryButton",
        mainFrame,
        "Prepare Disenchant",
        equipButton,
        "BOTTOM",
        0, -27,
        nil, nil, nil, 1.3
    )

    -- Vendor Attuned Button
    local vendorButton = AH.CreateButton(
        "AttuneHelperVendorAttunedButton",
        mainFrame,
        "Vendor Attuned",
        sortButton,
        "BOTTOM",
        0, -27,
        nil, nil, nil, 1.3
    )

    -- Store references
    AH.UI.buttons = AH.UI.buttons or {}
    AH.UI.buttons.equipAll = equipButton
    AH.UI.buttons.sort = sortButton
    AH.UI.buttons.vendor = vendorButton

    -- Export for legacy compatibility
    _G.EquipAllButton = equipButton
    _G.SortInventoryButton = sortButton
    _G.VendorAttunedButton = vendorButton

    -- Set up button click handlers
    AH.SetupMainButtonHandlers()

    -- Apply initial theme
    AH.ApplyButtonTheme(AttuneHelperDB["Button Theme"])

    return equipButton, sortButton, vendorButton
end

------------------------------------------------------------------------
-- Setup button click handlers
------------------------------------------------------------------------
function AH.SetupMainButtonHandlers()
    if not AH.UI.buttons.equipAll then
        AH.print_debug_general("SetupMainButtonHandlers: equipAll button not found")
        return
    end

    -- ʕ •ᴥ•ʔ✿ Equip All button - uses comprehensive equip logic ✿ ʕ •ᴥ•ʔ
    AH.UI.buttons.equipAll:SetScript("OnClick", function()
        AH.EquipAllAttunables()
    end)
    
    -- Equip All Button tooltip
    AH.UI.buttons.equipAll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(AH.t("Equip Attunables"))
        
        -- Add detailed list with icons
        local attunableData = AH.GetAttunableItemNamesList()
        local count = #attunableData
        GameTooltip:AddLine(string.format(AH.t("Attunable Items: %d"), count), 1, 1, 0)
        
        if count > 0 then
            GameTooltip:AddLine(" ") -- Empty line for spacing
            for _, itemData in ipairs(attunableData) do
                -- Get item info including quality and texture
                local _, itemLinkFull, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link)
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
                if itemData.id and itemData.id >= (AH.MYTHIC_MIN_ITEMID or 52203) then
                    table.insert(indicators, "|cffFF6600[Mythic]|r")
                end

                -- Check forge level
                local forgeLevel = AH.GetForgeLevelFromLink and AH.GetForgeLevelFromLink(itemData.link) or 0
                if forgeLevel == (AH.FORGE_LEVEL_MAP and AH.FORGE_LEVEL_MAP.WARFORGED or 2) then
                    table.insert(indicators, "|cffFFA680[WF]|r")
                elseif forgeLevel == (AH.FORGE_LEVEL_MAP and AH.FORGE_LEVEL_MAP.LIGHTFORGED or 3) then
                    table.insert(indicators, "|cffFFFFA6[LF]|r")
                elseif forgeLevel == (AH.FORGE_LEVEL_MAP and AH.FORGE_LEVEL_MAP.TITANFORGED or 1) then
                    table.insert(indicators, "|cff8080FF[TF]|r")
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
    AH.UI.buttons.equipAll:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- ʕ •ᴥ•ʔ✿ Sort button - moves mythic items to bag 0 ✿ ʕ •ᴥ•ʔ
    AH.UI.buttons.sort:SetScript("OnClick", function()
        AH.SortInventoryItems()
    end)
    
    -- Sort Inventory Button tooltip
    AH.UI.buttons.sort:SetScript("OnEnter", function(self) 
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT") 
        GameTooltip:SetText(AH.t("Prepare Disenchant"))
        local targetBag = (AttuneHelperDB["Use Bag 1 for Disenchant"] == 1) and 1 or 0
        GameTooltip:AddLine(string.format(AH.t("Moves fully attuned mythic items to bag %d."), targetBag), 1, 1, 1, true)
        GameTooltip:AddLine(AH.t("Clears target bag first, then fills with disenchant-ready items."), 0.7, 0.7, 0.7, true)
        GameTooltip:Show() 
    end)
    AH.UI.buttons.sort:SetScript("OnLeave", function() 
        GameTooltip:Hide() 
    end)

    -- ʕ •ᴥ•ʔ✿ Vendor button - sells attuned items ✿ ʕ •ᴥ•ʔ
    AH.UI.buttons.vendor:SetScript("OnClick", function(self)
        AH.VendorAttunedItems(self)
    end)
    
    -- Vendor Attuned Button tooltip
    AH.UI.buttons.vendor:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(AH.t("Vendor Attuned Items"))
        local itemsToVendor = AH.GetQualifyingVendorItems and AH.GetQualifyingVendorItems() or {}

        if #itemsToVendor > 0 then
            GameTooltip:AddLine(string.format(AH.t("Items to be sold (%d):"), #itemsToVendor), 1, 1, 0) -- Yellow
            for _, itemData in ipairs(itemsToVendor) do
                local _, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemData.link)
                local iconText = ""
                if itemTexture then
                    iconText = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", itemTexture)
                end
                local qualityColor = ITEM_QUALITY_COLORS[itemQuality or 1]
                local r, g, b = 0.8, 0.8, 0.8
                if qualityColor then r, g, b = qualityColor.r, qualityColor.g, qualityColor.b end
                GameTooltip:AddLine(iconText .. itemData.name, r, g, b, true)
            end
        else
            GameTooltip:AddLine(AH.t("No items will be sold based on current settings."), 0.8, 0.8, 0.8, true)
        end

        if not (MerchantFrame and MerchantFrame:IsShown()) then
            GameTooltip:AddLine(AH.t("Open merchant window to sell these items."), 1, 0.8, 0.2, true) -- Orange/Yellowish
        end
        GameTooltip:Show()
    end)
    AH.UI.buttons.vendor:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    AH.print_debug_general("Main button handlers set up successfully")
end

-- ʕ •ᴥ•ʔ✿ Legacy function removed - using new comprehensive handlers ✿ ʕ •ᴥ•ʔ 