-- ʕ •ᴥ•ʔ✿ UI · Mini frame setup ✿ ʕ •ᴥ•ʔ
local AH = _G.AttuneHelper

------------------------------------------------------------------------
-- Mini icon button creation helper
------------------------------------------------------------------------
function AH.CreateMiniIconButton(name, parent, iconPath, size, tooltipText)
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(size, size)
    btn:SetNormalTexture(iconPath)
    btn:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-Quickslot-Depress",
        edgeSize = 2,
        insets = {left = -1, right = -1, top = -1, bottom = -1}
    })
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetTexture(iconPath)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.2, 0.2, 0.2, 0.3)
    
    btn:SetScript("OnMouseDown", function(s)
        s:GetNormalTexture():SetVertexColor(0.75, 0.75, 0.75)
    end)
    btn:SetScript("OnMouseUp", function(s)
        s:GetNormalTexture():SetVertexColor(1, 1, 1)
    end)

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

------------------------------------------------------------------------
-- Mini frame creation and setup
------------------------------------------------------------------------
function AH.CreateMiniFrame()
    local frame = CreateFrame("Frame", "AttuneHelperMiniFrame", UIParent)
    frame:SetSize(88, 32)

    -- Position restoration
    if AttuneHelperDB.MiniFramePosition then
        local pos = AttuneHelperDB.MiniFramePosition
        if pos and #pos >= 5 and pos[1] and pos[3] and pos[4] ~= nil and pos[5] ~= nil then
            local success, err = pcall(function()
                frame:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
            end)
            if not success then
                AH.print_debug_general("Failed to restore mini frame position, using default: " .. tostring(err))
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
            end
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
        end
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        AttuneHelperDB.MiniFramePosition = { "CENTER", UIParent, "CENTER", 0, 0 }
    end

    -- Make it draggable
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(s)
        if s:IsMovable() then
            s:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = s:GetPoint()
        AttuneHelperDB.MiniFramePosition = {point, UIParent, relativePoint, xOfs, yOfs}
    end)

    -- Setup backdrop
    frame:SetBackdrop({
        bgFile = AH.BgStyles.MiniModeBg,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })

    frame:SetBackdropColor(
        AttuneHelperDB["Background Color"][1],
        AttuneHelperDB["Background Color"][2],
        AttuneHelperDB["Background Color"][3],
        AttuneHelperDB["Background Color"][4]
    )

    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    frame:Hide()

    -- Store reference
    AH.UI.miniFrame = frame

    -- Export for legacy compatibility
    _G.AttuneHelperMiniFrame = frame

    return frame
end

------------------------------------------------------------------------
-- Create mini frame buttons
------------------------------------------------------------------------
function AH.CreateMiniButtons()
    local frame = AH.UI.miniFrame
    if not frame then return end

    local mBS = 24 -- button size
    local mS = 4   -- spacing
    local fP = (frame:GetHeight() - mBS) / 2 -- frame padding

    -- Equip button
    local equipButton = AH.CreateMiniIconButton(
        "AttuneHelperMiniEquipButton",
        frame,
        "Interface\\Addons\\AttuneHelper\\assets\\icon1.blp",
        mBS,
        "Equip Attunables"
    )
    equipButton:SetPoint("LEFT", frame, "LEFT", fP, 0)

    -- Sort button
    local sortButton = AH.CreateMiniIconButton(
        "AttuneHelperMiniSortButton",
        frame,
        "Interface\\Addons\\AttuneHelper\\assets\\icon2.blp",
        mBS,
        "Prepare Disenchant"
    )
    sortButton:SetPoint("LEFT", equipButton, "RIGHT", mS, 0)

    -- Vendor button
    local vendorButton = AH.CreateMiniIconButton(
        "AttuneHelperMiniVendorButton",
        frame,
        "Interface\\Addons\\AttuneHelper\\assets\\icon3.blp",
        mBS,
        "Vendor Attuned"
    )
    vendorButton:SetPoint("LEFT", sortButton, "RIGHT", mS, 0)

    -- Store references
    AH.UI.miniButtons = AH.UI.miniButtons or {}
    AH.UI.miniButtons.equip = equipButton
    AH.UI.miniButtons.sort = sortButton
    AH.UI.miniButtons.vendor = vendorButton

    -- Export for legacy compatibility
    _G.AttuneHelperMiniEquipButton = equipButton
    _G.AttuneHelperMiniSortButton = sortButton
    _G.AttuneHelperMiniVendorButton = vendorButton

    return equipButton, sortButton, vendorButton
end

------------------------------------------------------------------------
-- Setup mini button click handlers and detailed tooltips
------------------------------------------------------------------------
function AH.SetupMiniButtonHandlers()
    -- These will be called after the main buttons are created
    AH.Wait(0.1, function()
        if AH.UI.miniButtons and AH.UI.miniButtons.equip and _G.EquipAllButton then
            AH.UI.miniButtons.equip:SetScript("OnClick", function()
                if _G.EquipAllButton:GetScript("OnClick") then
                    _G.EquipAllButton:GetScript("OnClick")()
                end
            end)
            
            -- Setup detailed tooltip for mini equip button
            AH.UI.miniButtons.equip:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText("Equip Attunables")

                local attunableData = AH.GetAttunableItemNamesList()
                local count = #attunableData

                if count > 0 then
                    GameTooltip:AddLine(string.format("Qualifying Attunables (%d):", count), 1, 1, 0) -- Yellow text
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
                            table.insert(indicators, "|cff9900FF[WF]|r")
                        elseif forgeLevel == (AH.FORGE_LEVEL_MAP and AH.FORGE_LEVEL_MAP.LIGHTFORGED or 3) then
                            table.insert(indicators, "|cffFFD700[LF]|r")
                        elseif forgeLevel == (AH.FORGE_LEVEL_MAP and AH.FORGE_LEVEL_MAP.TITANFORGED or 1) then
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
            AH.UI.miniButtons.equip:SetScript("OnLeave", GameTooltip_Hide)
        end

        if AH.UI.miniButtons and AH.UI.miniButtons.sort and _G.SortInventoryButton then
            AH.UI.miniButtons.sort:SetScript("OnClick", function()
                if _G.SortInventoryButton:GetScript("OnClick") then
                    _G.SortInventoryButton:GetScript("OnClick")()
                end
            end)
            
            -- Setup detailed tooltip for mini sort button
            AH.UI.miniButtons.sort:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText("Prepare Disenchant")
                local targetBag = (AttuneHelperDB["Use Bag 1 for Disenchant"] == 1) and 1 or 0
                GameTooltip:AddLine("Moves fully attuned mythic items to bag " .. targetBag .. ".", 1, 1, 1, true)
                GameTooltip:AddLine("Clears target bag first, then fills with disenchant-ready items.", 0.7, 0.7, 0.7, true)
                GameTooltip:AddLine("Items must be: Mythic, 100% attuned, soulbound, not in sets/ignore lists.", 0.6, 0.8, 1, true)
                GameTooltip:Show()
            end)
            AH.UI.miniButtons.sort:SetScript("OnLeave", GameTooltip_Hide)
        end

        if AH.UI.miniButtons and AH.UI.miniButtons.vendor and _G.VendorAttunedButton then
            AH.UI.miniButtons.vendor:SetScript("OnClick", function(self)
                if _G.VendorAttunedButton:GetScript("OnClick") then
                    _G.VendorAttunedButton:GetScript("OnClick")(self)
                end
            end)
            
            -- Setup detailed tooltip for mini vendor button
            AH.UI.miniButtons.vendor:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText("Vendor Attuned Items")
                local itemsToVendor = AH.GetQualifyingVendorItems and AH.GetQualifyingVendorItems() or {}

                if #itemsToVendor > 0 then
                    GameTooltip:AddLine(string.format("Items to be sold (%d):", #itemsToVendor), 1, 1, 0) -- Yellow
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
                    GameTooltip:AddLine("No items will be sold based on current settings.", 0.8, 0.8, 0.8, true)
                end

                if not (MerchantFrame and MerchantFrame:IsShown()) then
                    GameTooltip:AddLine("Open merchant window to sell these items.", 1, 0.8, 0.2, true) -- Orange/Yellowish
                end
                GameTooltip:Show()
            end)
            AH.UI.miniButtons.vendor:SetScript("OnLeave", GameTooltip_Hide)
        end
    end)
end

-- Don't initialize immediately - wait for ADDON_LOADED
-- These will be called from events.lua after saved variables are loaded 