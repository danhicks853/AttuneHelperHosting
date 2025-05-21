AHIgnoreList = AHIgnoreList or {}
AHSetList = AHSetList or {}
AttuneHelperDB = AttuneHelperDB or {}

local synEXTloaded = false

local SynastriaCoreLib=LibStub("SynastriaCoreLib-1.0")
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

local bagSlotCache = {}
local equipSlotCache = {}
local blacklist_checkboxes={}
local general_option_checkboxes={}
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

if AttuneHelperDB["Background Style"]==nil then AttuneHelperDB["Background Style"]="Tooltip" end
if type(AttuneHelperDB["Background Color"])~="table" or #AttuneHelperDB["Background Color"]<4 then AttuneHelperDB["Background Color"]={0,0,0,0.8} end
if AttuneHelperDB["Button Color"]==nil then AttuneHelperDB["Button Color"]={1,1,1,1} end
if AttuneHelperDB["Button Theme"]==nil then AttuneHelperDB["Button Theme"]="Normal" end
if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == nil then AttuneHelperDB["Disable Auto-Equip Mythic BoE"] = 1 end

local BgStyles={
  Tooltip="Interface\\Tooltips\\UI-Tooltip-Background",
  Guild="Interface\\Addons\\AttuneHelper\\assets\\UI-GuildAchievement-AchievementBackground",
  Atunament="Interface\\Addons\\AttuneHelper\\assets\\atunament-bg"
}

local themePaths = {
  Normal = {
    normal = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton.blp",
    pushed = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_pressed.blp"
  },
  Blue = {
    normal = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_blue.blp",
    pushed = "Interface\\AddOns\\AttuneHelper\\assets\\nicebutton_blue_pressed.blp"
  }
}

local function UpdateBagCache(bagID)
  local old_bag_records = bagSlotCache[bagID]
  if old_bag_records then
    for _, rec_to_remove in pairs(old_bag_records) do
      local raw_inv_type = rec_to_remove.equipSlot
      local unified_keys_for_item = itemTypeToUnifiedSlot[raw_inv_type]
      if unified_keys_for_item then
        if type(unified_keys_for_item) == "string" then
          local list = equipSlotCache[unified_keys_for_item]
          if list then
            for i = #list, 1, -1 do
              if list[i] == rec_to_remove then table.remove(list, i) end
            end
          end
        elseif type(unified_keys_for_item) == "table" then
          for _, key_name in ipairs(unified_keys_for_item) do
            local list = equipSlotCache[key_name]
            if list then
              for i = #list, 1, -1 do
                if list[i] == rec_to_remove then table.remove(list, i) end
              end
            end
          end
        end
      end
    end
  end
  bagSlotCache[bagID] = {}
  for slotID = 1, GetContainerNumSlots(bagID) do
    local link = GetContainerItemLink(bagID, slotID)
    if link then
      local name, _, _, _, _, _, _, _, equipSlot_raw = GetItemInfo(link)
      if equipSlot_raw and equipSlot_raw ~= "" then
        local unifiedSlotTargetNames = itemTypeToUnifiedSlot[equipSlot_raw]
        if unifiedSlotTargetNames then
          local isAttunable = SynastriaCoreLib.IsAttunable(link)
          local inSet  = AHSetList[name] and true or false
          if isAttunable or inSet then
            local rec = {bag=bagID,slot=slotID,link=link,name=name,equipSlot=equipSlot_raw,isAttunable=isAttunable,inSet=inSet}
            bagSlotCache[bagID][slotID] = rec
            if type(unifiedSlotTargetNames) == "string" then
              local key = unifiedSlotTargetNames
              equipSlotCache[key] = equipSlotCache[key] or {}
              table.insert(equipSlotCache[key], rec)
            elseif type(unifiedSlotTargetNames) == "table" then
              for _, key in ipairs(unifiedSlotTargetNames) do
                equipSlotCache[key] = equipSlotCache[key] or {}
                table.insert(equipSlotCache[key], rec)
              end
            end
          end
        end
      end
    end
  end
end

local function ApplyButtonTheme(theme)
  if not themePaths[theme] then return end
  local buttons = {_G.AttuneHelperSortInventoryButton, _G.AttuneHelperEquipAllButton, _G.AttuneHelperVendorAttunedButton}
  for _, btn in ipairs(buttons) do
    if btn then
      btn:SetNormalTexture(themePaths[theme].normal)
      btn:SetPushedTexture(themePaths[theme].pushed)
      btn:SetHighlightTexture(themePaths[theme].pushed, "ADD")
    end
  end
end

local function AH_wait(delay, func, ...)
  if type(delay)~="number" or type(func)~="function" then return false end
  if not waitFrame then
    waitFrame=CreateFrame("Frame",nil,UIParent)
    waitFrame:SetScript("OnUpdate",function(self,elapsed)
      local i=1
      while i<=#waitTable do
        local rec=table.remove(waitTable,i)
        local d=table.remove(rec,1); local f=table.remove(rec,1); local p=table.remove(rec,1)
        if d>elapsed then table.insert(waitTable,i,{d-elapsed,f,p}); i=i+1
        else f(unpack(p)) end
      end
    end)
  end
  table.insert(waitTable,{delay,func,{...}}); return true
end

local function IsItemForgeAllowed(itemLink, currentAllowedForgeTypes)
  local forgeLevel = FORGE_LEVEL_MAP.BASE
  if _G.GetItemLinkTitanforge then
      forgeLevel = GetItemLinkTitanforge(itemLink) or FORGE_LEVEL_MAP.BASE
  end
  local allowedTypes = currentAllowedForgeTypes or {}
  if forgeLevel == FORGE_LEVEL_MAP.BASE and allowedTypes.BASE == true then return true
  elseif forgeLevel == FORGE_LEVEL_MAP.TITANFORGED and allowedTypes.TITANFORGED == true then return true
  elseif forgeLevel == FORGE_LEVEL_MAP.WARFORGED and allowedTypes.WARFORGED == true then return true
  elseif forgeLevel == FORGE_LEVEL_MAP.LIGHTFORGED and allowedTypes.LIGHTFORGED == true then return true
  end
  return false
end

local function HideEquipPopups()
  StaticPopup_Hide("EQUIP_BIND"); StaticPopup_Hide("AUTOEQUIP_BIND")
  for i = 1, STATICPOPUP_NUMDIALOGS do
    local f = _G["StaticPopup"..i]
    if f and f:IsVisible() then
      local w = f.which
      if w == "EQUIP_BIND" or w == "AUTOEQUIP_BIND" then f:Hide() end
    end
  end
end

local AttuneHelper=CreateFrame("Frame","AttuneHelperFrame",UIParent)
AttuneHelper:SetSize(185,125); AttuneHelper:SetPoint("CENTER"); AttuneHelper:EnableMouse(true); AttuneHelper:SetMovable(true)
AttuneHelper:RegisterForDrag("LeftButton"); AttuneHelper:SetScript("OnDragStart",AttuneHelper.StartMoving); AttuneHelper:SetScript("OnDragStop",AttuneHelper.StopMovingOrSizing)
AttuneHelper:SetBackdrop({bgFile=BgStyles[AttuneHelperDB["Background Style"]],edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"])); AttuneHelper:SetBackdropBorderColor(0.4,0.4,0.4)

local function SaveAllSettings()
  if not InterfaceOptionsFrame or not InterfaceOptionsFrame:IsShown() then
    return
  end
  local bgDropdownFrame = _G["AttuneHelperBgDropdown"]
  if bgDropdownFrame and bgDropdownFrame:IsShown() then
    local val = UIDropDownMenu_GetSelectedValue(bgDropdownFrame)
    if val then AttuneHelperDB["Background Style"] = val end
  end
  local buttonThemeDropdownFrame = _G["AttuneHelperButtonThemeDropdown"]
  if buttonThemeDropdownFrame and buttonThemeDropdownFrame:IsShown() then
    local val = UIDropDownMenu_GetSelectedValue(buttonThemeDropdownFrame)
    if val then AttuneHelperDB["Button Theme"] = val end
  end
  for _, cb in ipairs(blacklist_checkboxes) do
    if cb and cb:IsShown() then
      local sn = cb:GetName():gsub("AttuneHelperBlacklist_", ""):gsub("Checkbox", "")
      AttuneHelperDB[sn] = cb:GetChecked() and 1 or 0
    end
  end
  for _, cb in ipairs(general_option_checkboxes) do
    if cb and cb:IsShown() then AttuneHelperDB[cb:GetName()] = cb:GetChecked() and 1 or 0 end
  end
  if type(AttuneHelperDB.AllowedForgeTypes) ~= "table" then AttuneHelperDB.AllowedForgeTypes = {} end
  for _, cb in ipairs(forge_type_checkboxes) do
    if cb and cb:IsShown() and cb.dbKey then
      local isChecked = cb:GetChecked()
      if isChecked then AttuneHelperDB.AllowedForgeTypes[cb.dbKey] = true
      else AttuneHelperDB.AllowedForgeTypes[cb.dbKey] = nil end
    end
  end
end

local function LoadAllSettings()
  if AttuneHelperDB["Background Style"]==nil then AttuneHelperDB["Background Style"]="Tooltip" end
  if type(AttuneHelperDB["Background Color"])~="table" or #AttuneHelperDB["Background Color"]<4 then AttuneHelperDB["Background Color"]={0,0,0,0.8} end
  if AttuneHelperDB["Button Theme"]==nil then AttuneHelperDB["Button Theme"]="Normal" end
  if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == nil then AttuneHelperDB["Disable Auto-Equip Mythic BoE"] = 1 end

  if type(AttuneHelperDB.AllowedForgeTypes) ~= "table" then
     AttuneHelperDB.AllowedForgeTypes = {}
     for keyName, defaultValue in pairs(defaultForgeKeysAndValues) do
         AttuneHelperDB.AllowedForgeTypes[keyName] = defaultValue
     end
  end

  for _, cbWidget in ipairs(forge_type_checkboxes) do
    if cbWidget and cbWidget.dbKey then
      local key = cbWidget.dbKey
      local valueFromDB = AttuneHelperDB.AllowedForgeTypes[key]
      cbWidget:SetChecked(valueFromDB == true)
    end
  end

  local bgDropdownFrame = _G["AttuneHelperBgDropdown"]
  if bgDropdownFrame then
    UIDropDownMenu_SetSelectedValue(bgDropdownFrame, AttuneHelperDB["Background Style"])
    UIDropDownMenu_SetText(bgDropdownFrame, AttuneHelperDB["Background Style"])
  end
  if BgStyles[AttuneHelperDB["Background Style"]] then
    AttuneHelper:SetBackdrop{bgFile=BgStyles[AttuneHelperDB["Background Style"]],edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=(AttuneHelperDB["Background Style"]~="Atunament"),tileSize=(AttuneHelperDB["Background Style"]=="Atunament" and 0 or 16),edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}
    AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"]))
  end
  local theme = AttuneHelperDB["Button Theme"] or "Normal"
  local buttonThemeDropdownFrame = _G["AttuneHelperButtonThemeDropdown"]
  if buttonThemeDropdownFrame then
    UIDropDownMenu_SetSelectedValue(buttonThemeDropdownFrame, theme)
    UIDropDownMenu_SetText(buttonThemeDropdownFrame, theme)
  end
  ApplyButtonTheme(theme)
  local bgColorTable = AttuneHelperDB["Background Color"]
  local colorSwatchFrame = _G["AttuneHelperBgColorSwatch"]
  if colorSwatchFrame then colorSwatchFrame:SetBackdropColor(bgColorTable[1],bgColorTable[2],bgColorTable[3],1) end
  local alphaSliderFrame = _G["AttuneHelperAlphaSlider"]
  if alphaSliderFrame then alphaSliderFrame:SetValue(bgColorTable[4]) end
  for _, cb in ipairs(blacklist_checkboxes) do
    local sn = cb:GetName():gsub("AttuneHelperBlacklist_", ""):gsub("Checkbox", "")
    if AttuneHelperDB[sn]==nil then AttuneHelperDB[sn]=0 end
    cb:SetChecked(AttuneHelperDB[sn]==1)
  end
  for _, cb in ipairs(general_option_checkboxes) do
    local k = cb:GetName()
    if AttuneHelperDB[k]==nil then
      if k == "Disable Auto-Equip Mythic BoE" then AttuneHelperDB[k] = 1 else AttuneHelperDB[k] = 0 end
    end
    cb:SetChecked(AttuneHelperDB[k]==1)
  end
end

local function CreateButton(name,parent,text,anchor,ap,xOff,yOff,width,height,colors,scale)
  scale=scale or 1; local x1,y1,x2,y2=65,176,457,290; local rw, rh = x2-x1, y2-y1; local u1,u2=x1/512,x2/512; local v1,v2=y1/512,y2/512
  if width and not height then height=width*rh/rw elseif height and not width then width=height*rw/rh else height=24;width=height*rw/rh*1.5 end
  local btn=CreateFrame("Button",name,parent,"UIPanelButtonTemplate"); btn:SetSize(width,height);btn:SetScale(scale)
  btn:SetPoint(ap,anchor,ap,xOff,yOff); btn:SetText(text)
  local theme=AttuneHelperDB["Button Theme"] or "Normal"
  btn:SetNormalTexture(themePaths[theme].normal); btn:SetPushedTexture(themePaths[theme].pushed); btn:SetHighlightTexture(themePaths[theme].pushed,"ADD")
  for _,s in ipairs({"Normal","Pushed","Highlight"}) do local tex=btn["Get"..s.."Texture"](btn); tex:SetTexCoord(u1,u2,v1,v2); local c=colors and colors[s:lower()]; if c then tex:SetVertexColor(c[1],c[2],c[3],c[4] or 1) end end
  btn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE"); btn:SetBackdropColor(0,0,0,0.5); btn:SetBackdropBorderColor(1,1,1,1)
  return btn
end

local EquipAllButton,SortInventoryButton,VendorAttunedButton
local mainPanel=CreateFrame("Frame","AttuneHelperOptionsPanel",UIParent); mainPanel.name="AttuneHelper"; InterfaceOptions_AddCategory(mainPanel)
local title_ah=mainPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); title_ah:SetPoint("TOPLEFT",16,-16);title_ah:SetText("AttuneHelper")
local description_ah=mainPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); description_ah:SetPoint("TOPLEFT",title_ah,"BOTTOMLEFT",0,-8); description_ah:SetPoint("RIGHT",-32,0);description_ah:SetJustifyH("LEFT"); description_ah:SetText("AttuneHelper is an addon to assist players with attuning items.")
local blacklistPanel=CreateFrame("Frame","AttuneHelperBlacklistOptionsPanel",mainPanel); blacklistPanel.name="Blacklisting";blacklistPanel.parent=mainPanel.name; InterfaceOptions_AddCategory(blacklistPanel)
local titleB=blacklistPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); titleB:SetPoint("TOPLEFT",16,-16);titleB:SetText("Blacklisting")
local descB=blacklistPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); descB:SetPoint("TOPLEFT",titleB,"BOTTOMLEFT",0,-8); descB:SetPoint("RIGHT",-32,0);descB:SetJustifyH("LEFT"); descB:SetText("Choose which equipment slots to blacklist.")
local generalOptionsPanel=CreateFrame("Frame","AttuneHelperGeneralOptionsPanel",mainPanel); generalOptionsPanel.name="General Options";generalOptionsPanel.parent=mainPanel.name; InterfaceOptions_AddCategory(generalOptionsPanel)
local titleG=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); titleG:SetPoint("TOPLEFT",16,-16);titleG:SetText("General Options")
local descG=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); descG:SetPoint("TOPLEFT",titleG,"BOTTOMLEFT",0,-8); descG:SetPoint("RIGHT",-32,0);descG:SetJustifyH("LEFT"); descG:SetText("Choose general options. (Relog or click Equip Attunables to update)")
local forgeOptionsPanel = CreateFrame("Frame", "AttuneHelperForgeOptionsPanel", mainPanel); forgeOptionsPanel.name = "Forge Equipping"; forgeOptionsPanel.parent = mainPanel.name; InterfaceOptions_AddCategory(forgeOptionsPanel)
local titleF = forgeOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"); titleF:SetPoint("TOPLEFT", 16, -16); titleF:SetText("Forge Equip Settings")
local descF = forgeOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); descF:SetPoint("TOPLEFT", titleF, "BOTTOMLEFT", 0, -8); descF:SetPoint("RIGHT", -32, 0); descF:SetJustifyH("LEFT"); descF:SetText("Configure which types of forged items are allowed for auto-equipping.")

local slots={"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot"}
local general_options_list_for_checkboxes={"Sell Attuned Mythic Gear?","Auto Equip Attunable After Combat","Do Not Sell BoE Items","Limit Selling to 12 Items?", "Disable Auto-Equip Mythic BoE"}

local function CreateCheckbox(name,parent,x,y,isGeneralOption,dbKeyOverride)
  local checkboxName = name; if not isGeneralOption and not dbKeyOverride then checkboxName = "AttuneHelperBlacklist_"..name.."Checkbox" elseif dbKeyOverride then checkboxName = "AttuneHelperForgeType_"..dbKeyOverride.."_Checkbox" end
  local cb=CreateFrame("CheckButton",checkboxName,parent,"UICheckButtonTemplate"); cb:SetPoint("TOPLEFT",x,y)
  local txt=cb:CreateFontString(nil,"ARTWORK","GameFontHighlight"); txt:SetPoint("LEFT",cb,"RIGHT",4,0);txt:SetText(name)
  if dbKeyOverride then cb.dbKey = dbKeyOverride end; return cb
end

local function InitializeOptionCheckboxes()
  wipe(blacklist_checkboxes); wipe(general_option_checkboxes)
  local x0,y0,row,col=16,-60,0,0
  for _,slotName in ipairs(slots) do local cb=CreateCheckbox(slotName,blacklistPanel,x0+120*col,y0-33*row,false); table.insert(blacklist_checkboxes,cb); row=row+1;if row==6 then row=0;col=col+1 end end
  for i,optText in ipairs(general_options_list_for_checkboxes) do local cb=CreateCheckbox(optText,generalOptionsPanel,16,-60-33*(i-1),true); table.insert(general_option_checkboxes,cb) end
end

local function InitializeForgeOptionCheckboxes()
  wipe(forge_type_checkboxes)
  local currentForgeOptionsPanel = _G["AttuneHelperForgeOptionsPanel"]
  if not currentForgeOptionsPanel then return end
  local forgeTypeSectionLabel = currentForgeOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal"); forgeTypeSectionLabel:SetPoint("TOPLEFT", 16, -60); forgeTypeSectionLabel:SetText("Allowed Forge Types for Auto-Equip:")
  local lastAnchor = forgeTypeSectionLabel; local yOffset = -8; local xInitialOffset = 16
  for i, forgeOption in ipairs(forgeTypeOptionsList) do
    local checkboxName = "AttuneHelperForgeType_"..forgeOption.dbKey.."_Checkbox"
    local checkbox = CreateFrame("CheckButton", checkboxName, currentForgeOptionsPanel, "UICheckButtonTemplate")
    if i == 1 then checkbox:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", xInitialOffset, yOffset -5) else checkbox:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, yOffset) end
    lastAnchor = checkbox
    local text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0); text:SetText(forgeOption.label)
    checkbox.dbKey = forgeOption.dbKey
    checkbox:SetScript("OnClick", function(self)
      if type(AttuneHelperDB.AllowedForgeTypes) ~= "table" then AttuneHelperDB.AllowedForgeTypes = {} end
      local key = self.dbKey; local checked = self:GetChecked()
      if checked then AttuneHelperDB.AllowedForgeTypes[key] = true else AttuneHelperDB.AllowedForgeTypes[key] = nil end
    end)
    table.insert(forge_type_checkboxes, checkbox)
  end
end
InitializeOptionCheckboxes(); InitializeForgeOptionCheckboxes()
for _,cb in ipairs(blacklist_checkboxes) do cb:SetScript("OnClick",SaveAllSettings) end
for _,cb in ipairs(general_option_checkboxes) do cb:SetScript("OnClick",SaveAllSettings) end

local bgLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormal"); local lastGeneralCheckbox = general_option_checkboxes[#general_option_checkboxes]; if not lastGeneralCheckbox then lastGeneralCheckbox = descG end; bgLabel:SetPoint("TOPLEFT",lastGeneralCheckbox,"BOTTOMLEFT",0,-16);bgLabel:SetText("Background Style:")
local bgDropdown=CreateFrame("Frame","AttuneHelperBgDropdown",generalOptionsPanel,"UIDropDownMenuTemplate"); bgDropdown:SetPoint("TOPLEFT",bgLabel,"BOTTOMLEFT",-16,0); UIDropDownMenu_SetWidth(bgDropdown,160)
local function OnBgSelect(self) UIDropDownMenu_SetSelectedValue(bgDropdown,self.value); AttuneHelperDB["Background Style"]=self.value; UIDropDownMenu_SetText(bgDropdown,self.value); AttuneHelper:SetBackdrop({bgFile=BgStyles[self.value],edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=(self.value~="Atunament"),tileSize=(self.value=="Atunament" and 0 or 16),edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}); AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"])); SaveAllSettings() end
UIDropDownMenu_Initialize(bgDropdown,function(self) for style in pairs(BgStyles) do local info=UIDropDownMenu_CreateInfo(); info.text=style;info.value=style;info.func=OnBgSelect; info.checked=(style==AttuneHelperDB["Background Style"]); UIDropDownMenu_AddButton(info) end end)
local swatch=CreateFrame("Button","AttuneHelperBgColorSwatch",generalOptionsPanel); swatch:SetSize(16,16);swatch:SetPoint("LEFT",bgDropdown,"RIGHT",20,0); swatch:SetBackdrop{bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=4,edgeSize=4,insets={left=1,right=1,top=1,bottom=1}}; swatch:SetBackdropBorderColor(0,0,0,1)
swatch:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Background Color");GameTooltip:Show() end); swatch:SetScript("OnLeave",GameTooltip_Hide)
swatch:SetScript("OnClick",function(self) local color=AttuneHelperDB["Background Color"]; if type(color)~="table" or #color<4 then color={0,0,0,0.8};AttuneHelperDB["Background Color"]=color end; ColorPickerFrame.func=function() local r,g,b=ColorPickerFrame:GetColorRGB(); color[1],color[2],color[3]=r,g,b; swatch:SetBackdropColor(r,g,b,1); AttuneHelper:SetBackdropColor(r,g,b,color[4]); SaveAllSettings() end; ColorPickerFrame.hasOpacity=false; ColorPickerFrame:SetColorRGB(color[1],color[2],color[3]); if _G.ColorPickerFrameOpacitySlider then _G.ColorPickerFrameOpacitySlider:Hide() end; ColorPickerFrame:Show() end)
local swatchLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlight"); swatchLabel:SetPoint("LEFT",swatch,"RIGHT",4,0);swatchLabel:SetText("BG Color")
local alphaLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormal"); alphaLabel:SetPoint("TOPLEFT",bgDropdown,"BOTTOMLEFT",20,0);alphaLabel:SetText("BG Transparency:")
local alphaSlider=CreateFrame("Slider","AttuneHelperAlphaSlider",generalOptionsPanel,"OptionsSliderTemplate"); alphaSlider:SetOrientation("HORIZONTAL"); alphaSlider:SetMinMaxValues(0,1); alphaSlider:SetValueStep(0.01); alphaSlider:SetWidth(150); alphaSlider:SetPoint("TOPLEFT",alphaLabel,"BOTTOMLEFT",0,-8)
_G.AttuneHelperAlphaSliderLow:SetText("0"); _G.AttuneHelperAlphaSliderHigh:SetText("1"); _G.AttuneHelperAlphaSliderText:SetText("")
alphaSlider:SetScript("OnValueChanged",function(self,val) AttuneHelperDB["Background Color"][4]=val; local c=AttuneHelperDB["Background Color"]; AttuneHelper:SetBackdropColor(c[1],c[2],c[3],c[4]); SaveAllSettings() end)
local btLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormal"); btLabel:SetPoint("TOPLEFT",alphaSlider,"BOTTOMLEFT",0,-20);btLabel:SetText("Button Theme:")
local btDropdown=CreateFrame("Frame","AttuneHelperButtonThemeDropdown",generalOptionsPanel,"UIDropDownMenuTemplate"); btDropdown:SetPoint("TOPLEFT",btLabel,"BOTTOMLEFT",-16,0); UIDropDownMenu_SetWidth(btDropdown,160)
local function OnBtnThemeSelect(self) local v = self.value; UIDropDownMenu_SetSelectedValue(btDropdown, v); UIDropDownMenu_SetText(btDropdown, v); AttuneHelperDB["Button Theme"] = v; ApplyButtonTheme(v); SaveAllSettings() end
UIDropDownMenu_Initialize(btDropdown,function(self) for _,th in ipairs({"Normal","Blue"}) do local info=UIDropDownMenu_CreateInfo(); info.text=th;info.value=th;info.func=OnBtnThemeSelect; info.checked=(th==AttuneHelperDB["Button Theme"]); UIDropDownMenu_AddButton(info) end end)

generalOptionsPanel.okay  = SaveAllSettings; generalOptionsPanel.cancel = LoadAllSettings; generalOptionsPanel.refresh= LoadAllSettings
blacklistPanel.okay    = SaveAllSettings; blacklistPanel.cancel   = LoadAllSettings; blacklistPanel.refresh   = LoadAllSettings
forgeOptionsPanel.okay = SaveAllSettings; forgeOptionsPanel.cancel = LoadAllSettings; forgeOptionsPanel.refresh = LoadAllSettings

local function EquipItemInInventory(slotName)
  if AttuneHelperDB[slotName]==1 then return end
  local localItemTypeToSlotMapping={INVTYPE_HEAD="HeadSlot",INVTYPE_NECK="NeckSlot",INVTYPE_SHOULDER="ShoulderSlot",INVTYPE_CLOAK="BackSlot",INVTYPE_CHEST="ChestSlot",INVTYPE_ROBE="ChestSlot",INVTYPE_WAIST="WaistSlot",INVTYPE_LEGS="LegsSlot",INVTYPE_FEET="FeetSlot",INVTYPE_WRIST="WristSlot",INVTYPE_HAND="HandsSlot",INVTYPE_FINGER={"Finger0Slot","Finger1Slot"},INVTYPE_TRINKET={"Trinket0Slot","Trinket1Slot"},INVTYPE_WEAPON={"MainHandSlot","SecondaryHandSlot"},INVTYPE_2HWEAPON="MainHandSlot",INVTYPE_WEAPONMAINHAND="MainHandSlot",INVTYPE_WEAPONOFFHAND="SecondaryHandSlot",INVTYPE_HOLDABLE="SecondaryHandSlot",INVTYPE_RANGED="RangedSlot",INVTYPE_THROWN="RangedSlot",INVTYPE_RANGEDRIGHT="RangedSlot",INVTYPE_RELIC="RangedSlot",INVTYPE_TABARD="TabardSlot",INVTYPE_BAG="BackSlot",INVTYPE_QUIVER="MainHandSlot",INVTYPE_AMMO="MainHandSlot",INVTYPE_WAND="RangedSlot",INVTYPE_SHIELD="SecondaryHandSlot"}
  local mainHandItemID=GetInventoryItemID("player",16)
  if mainHandItemID then local _,_,_,_,_,_,_,_,equipSlot=GetItemInfoCustom(mainHandItemID) if equipSlot=="INVTYPE_2HWEAPON" and slotName=="SecondaryHandSlot" then return end end
  for _,phase in ipairs{"attunable","set"} do
    for bag=0,4 do
      for slot=1,GetContainerNumSlots(bag) do
        local link=GetContainerItemLink(bag,slot)
        if link then
          local _,_,_,_,_,_,_,_,equipSlot=GetItemInfoCustom(link)
          if AttuneHelperDB["Disable Two-Handers"] == 1 and equipSlot == "INVTYPE_2HWEAPON" then return end
          local expected=localItemTypeToSlotMapping[equipSlot]
          if expected==slotName or (type(expected)=="table" and tContains(expected,slotName)) then
            local ok=(phase=="attunable" and SynastriaCoreLib.IsAttunable(link)) or (phase=="set" and AHSetList[GetItemInfoCustom(link)])
            if ok then local eq=slotNumberMapping[slotName] or GetInventorySlotInfo(slotName); EquipItemByName(link,eq); EquipPendingItem(0); ConfirmBindOnUse(); if phase=="attunable" then HideEquipPopups() end; return end
          end
        end
      end
    end
  end
end

local SWAP_THROTTLE = 0.1
EquipAllButton = CreateButton("AttuneHelperEquipAllButton",AttuneHelper,"Equip Attunables",AttuneHelper,"TOP",0,-5,nil,nil,nil,1.3)
EquipAllButton:SetScript("OnClick", function()
  if MerchantFrame and MerchantFrame:IsShown() then return end
  
  for bag = 0, 4 do UpdateBagCache(bag) end
  local slotsList = {"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot"}
  local twoHanderEquippedInMainHandThisCycle = false

  local willBindScannerTooltip = nil
  local function WillBecomeBoundOnEquip(itemLink, itemBag, itemSlot)
    if not itemLink then return false end
    if not willBindScannerTooltip then
      willBindScannerTooltip = CreateFrame("GameTooltip", "AttuneHelperWillBindScannerTooltip", UIParent, "GameTooltipTemplate")
    end
    willBindScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    willBindScannerTooltip:SetHyperlink(itemLink)
    local isBoEType = false
    for i = 1, willBindScannerTooltip:NumLines() do
      local lineTextWidget = _G[willBindScannerTooltip:GetName().."TextLeft"..i]
      if lineTextWidget then
        local lineText = lineTextWidget:GetText()
        if lineText and string.find(lineText, "Binds when equipped", 1, true) then
          isBoEType = true; break
        end
      end
    end
    if not isBoEType then willBindScannerTooltip:Hide(); return false end
    if itemBag and itemSlot then
      willBindScannerTooltip:SetBagItem(itemBag, itemSlot)
      for i = 1, willBindScannerTooltip:NumLines() do
        local lineTextWidget = _G[willBindScannerTooltip:GetName().."TextLeft"..i]
        if lineTextWidget then
          local lineText = lineTextWidget:GetText()
          if lineText and string.find(lineText, "Soulbound", 1, true) then
            willBindScannerTooltip:Hide(); return false
          end
        end
      end
    end
    willBindScannerTooltip:Hide(); return true
  end

  local function checkAndEquip(slotName)
    if AttuneHelperDB[slotName] == 1 then return end
    if slotName == "SecondaryHandSlot" and twoHanderEquippedInMainHandThisCycle then return end

    local mainHandPlayerSlotId = GetInventorySlotInfo("MainHandSlot")
    local currentMainHandItemLink = GetInventoryItemLink("player", mainHandPlayerSlotId)
    local currentMainHandIsTwoHander = false
    if currentMainHAddonTextItemLink then
        local _, _, _, _, _, _, _, _, currentMainHandEquipSlot_raw = GetItemInfo(currentMainHandItemLink)
        if currentMainHandEquipSlot_raw == "INVTYPE_2HWEAPON" then currentMainHandIsTwoHander = true end
    end
    if currentMainHandIsTwoHander and slotName == "SecondaryHandSlot" then return end

    local invSlotID = GetInventorySlotInfo(slotName)
    local curLink = GetInventoryItemLink("player", invSlotID)

    if not curLink or SynastriaCoreLib.IsAttuned(curLink) or not SynastriaCoreLib.IsAttunableBySomeone(curLink) then
        local candidates = equipSlotCache[slotName] or {}
        local currentAllowedForgeTypes = AttuneHelperDB.AllowedForgeTypes

        for _, rec in ipairs(candidates) do
            local shouldProcessCandidate = true
            if currentMainHandIsTwoHander and slotName == "MainHandSlot" then
                if rec.equipSlot ~= "INVTYPE_2HWEAPON" then shouldProcessCandidate = false end
            end

            if shouldProcessCandidate then
                if rec.inSet or rec.isAttunable then
                    if IsItemForgeAllowed(rec.link, currentAllowedForgeTypes) then
                        local itemName, itemLink_unused, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice, classID, subClassID, originalItemBindType = GetItemInfo(rec.link)
                        
                        local itemID = nil
                        if rec.link then itemID = tonumber(string.match(rec.link, "item:(%d+):")) end
                        
                        local isConsideredMythic = false
                        if itemID and itemID >= MYTHIC_MIN_ITEMID then isConsideredMythic = true end
                        
                        local itemWillBecomeBound = WillBecomeBoundOnEquip(rec.link, rec.bag, rec.slot)
                        local disableAutoEquipMythicBoESetting = AttuneHelperDB["Disable Auto-Equip Mythic BoE"]
                        
                        local passesNonForgeChecks = true
                        if disableAutoEquipMythicBoESetting == 1 and isConsideredMythic and itemWillBecomeBound then
                            passesNonForgeChecks = false
                        end

                        if passesNonForgeChecks then
                            UseContainerItem(rec.bag, rec.slot)
                            EquipPendingItem(0)
                            ConfirmBindOnUse()
                            HideEquipPopups()

                            if slotName == "MainHandSlot" then
                                local _, _, _, _, _, _, _, _, equippedItemEquipSlot = GetItemInfo(rec.link)
                                if equippedItemEquipSlot == "INVTYPE_2HWEAPON" then
                                    twoHanderEquippedInMainHandThisCycle = true
                                end
                            end
                            return
                        end
                    end
                end
            end
        end
    end
  end

  for i, slotName_iter in ipairs(slotsList) do AH_wait(SWAP_THROTTLE * i, checkAndEquip, slotName_iter) end
end)

SortInventoryButton = CreateButton("AttuneHelperSortInventoryButton",AttuneHelper,"Prepare Disenchant",EquipAllButton,"BOTTOM",0,-27,nil,nil,nil,1.3)
SortInventoryButton:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Moves Mythic items to Bag 0."); GameTooltip:Show() end)
SortInventoryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
SortInventoryButton:SetScript("OnClick", function()
  local bagZeroItems, mythicItems, ignoredMythicItems, emptySlots, ignoredLookup = {}, {}, {}, {}, {}
  for name in pairs(AHIgnoreList) do ignoredLookup[name:lower()] = true end
  local function IsMythicItem(itemID) if not itemID then return false end; local tt = CreateFrame("GameTooltip","ItemTooltipScanner",nil,"GameTooltipTemplate"); tt:SetOwner(UIParent, "ANCHOR_NONE"); tt:SetHyperlink("item:" .. itemID); for i = 1, tt:NumLines() do local line = _G["ItemTooltipScannerTextLeft" .. i]:GetText(); if line and line:find("Mythic") then tt:Hide(); return true end end; tt:Hide(); return false end
  local emptyCount = 0; for bag = 0, 4 do for slot = 1, GetContainerNumSlots(bag) do if not GetContainerItemID(bag, slot) then emptyCount = emptyCount + 1 end end end
  if emptyCount < 16 then print("|cffff0000[Attune Helper]|r: You must have 16 empty inventory slots, make space and try again."); return end
  for bag = 0, 4 do for slot = 1, GetContainerNumSlots(bag) do local itemID = GetContainerItemID(bag, slot); local itemName = itemID and GetItemInfoCustom(itemID); if itemID then local isMythic = IsMythicItem(itemID); local isIgnored = itemName and ignoredLookup[itemName:lower()]; if bag == 0 then if not isMythic then table.insert(bagZeroItems, {bag = bag, slot = slot}) elseif isIgnored then table.insert(ignoredMythicItems, {bag = bag, slot = slot}) end elseif isMythic and not isIgnored then table.insert(mythicItems, {bag = bag, slot = slot}) end else table.insert(emptySlots, {bag = bag, slot = slot}) end end end
  for _, item in ipairs(ignoredMythicItems) do if #emptySlots > 0 then local tgt = table.remove(emptySlots); PickupContainerItem(item.bag, item.slot); PickupContainerItem(tgt.bag, tgt.slot) end end
  for _, item in ipairs(bagZeroItems) do if #emptySlots > 0 then local tgt = table.remove(emptySlots); PickupContainerItem(item.bag, item.slot); PickupContainerItem(tgt.bag, tgt.slot) end end
  for _, item in ipairs(mythicItems) do if #emptySlots > 0 then local tgt = table.remove(emptySlots, 1); PickupContainerItem(item.bag, item.slot); PickupContainerItem(tgt.bag, tgt.slot) end end
end)

VendorAttunedButton = CreateButton("AttuneHelperVendorAttunedButton",AttuneHelper,"Vendor Attuned",SortInventoryButton,"BOTTOM",0,-27,nil,nil,nil,1.3)
VendorAttunedButton:SetScript("OnClick",function()
  if not MerchantFrame:IsShown() then return end; local limit=AttuneHelperDB["Limit Selling to 12 Items?"]==1; local maxSell=limit and 12 or math.huge; local sold=0
  local function IsBoE(itemID,bag,slot_idx) if not itemID then return false end; local tt=CreateFrame("GameTooltip","BoETooltipScanner",nil,"GameTooltipTemplate"); tt:SetOwner(UIParent,"ANCHOR_NONE"); tt:SetHyperlink("item:"..itemID); local boe=false; for i=1,tt:NumLines() do local line=_G["BoETooltipScannerTextLeft"..i]:GetText(); if line and line:find("Binds when equipped") then boe=true;break end end; if boe and bag and slot_idx then tt:SetOwner(UIParent, "ANCHOR_NONE"); tt:SetBagItem(bag, slot_idx); for i = 1, tt:NumLines() do local lineText = _G["BoETooltipScannerTextLeft" .. i]; if lineText and lineText:GetText() and lineText:GetText():find("Soulbound") then tt:Hide(); return false end end end; tt:Hide(); return boe end
  for bag=0,4 do for slot_idx=1,GetContainerNumSlots(bag) do if sold>=maxSell then return end; local link=GetContainerItemLink(bag,slot_idx); local itemID=GetContainerItemID(bag,slot_idx); if link and itemID then local name=GetItemInfoCustom(link); if not (AHIgnoreList[name] or AHSetList[name]) then local attuned=SynastriaCoreLib.IsAttuned(link); local boe_status=IsBoE(itemID,bag,slot_idx); local isMythic=itemID>=MYTHIC_MIN_ITEMID; local dont=AttuneHelperDB["Do Not Sell BoE Items"]==1 and attuned and boe_status; local sellMythic=AttuneHelperDB["Sell Attuned Mythic Gear?"]==1; local should=(isMythic and sellMythic) or not isMythic; if attuned and should and not dont then UseContainerItem(bag,slot_idx); sold=sold+1 end end end end end
end)

ApplyButtonTheme(AttuneHelperDB["Button Theme"])
local AttuneHelperItemCountText=AttuneHelper:CreateFontString(nil,"OVERLAY","GameFontNormal"); AttuneHelperItemCountText:SetPoint("BOTTOM",0,6); AttuneHelperItemCountText:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE"); AttuneHelperItemCountText:SetTextColor(1,1,1,1); AttuneHelperItemCountText:SetText("Attunables in Inventory: 0")
local function UpdateItemCountText() local c = 0; for bagID, bagTbl in pairs(bagSlotCache) do for slotID, rec in pairs(bagTbl) do if rec.isAttunable then c = c + 1 end end end; AttuneHelperItemCountText:SetText("Attunables in Inventory: "..c) end
AH_wait(4,UpdateItemCountText)

SLASH_ATTUNEHELPER1="/ath"; SlashCmdList["ATTUNEHELPER"]=function(msg) local cmd=msg:lower():match("^(%S*)"); if cmd=="reset" then AttuneHelper:ClearAllPoints(); AttuneHelper:SetPoint("CENTER"); print("ATH: UI position reset.") elseif cmd=="show" then AttuneHelper:Show() elseif cmd=="hide" then AttuneHelper:Hide() elseif cmd=="sort" then if SortInventoryButton and SortInventoryButton:GetScript("OnClick") then SortInventoryButton:GetScript("OnClick")() end elseif cmd=="equip" then if EquipAllButton and EquipAllButton:GetScript("OnClick") then EquipAllButton:GetScript("OnClick")() end elseif cmd=="vendor" then if VendorAttunedButton and VendorAttunedButton:GetScript("OnClick") then VendorAttunedButton:GetScript("OnClick")() end else print("/ath show | hide | reset | equip | sort | vendor") end end
SLASH_AHIGNORE1="/AHIgnore"; SlashCmdList["AHIGNORE"]=function(msg) local n=GetItemInfo(msg); if not n then print("Invalid item link."); return end; AHIgnoreList[n]=not AHIgnoreList[n]; print(n..(AHIgnoreList[n] and " is now ignored." or " will no longer be ignored.")) end
SLASH_AHSET1="/AHSet"; SlashCmdList["AHSET"]=function(msg) local n=GetItemInfo(msg); if not n then print("Invalid item link."); return end; AHSetList[n]=not AHSetList[n]; print(n..(AHSetList[n] and " is now included in your gear set." or " is no longer included in your gear set.")) end
SLASH_ATH2H1 = "/ah2h"; SlashCmdList["ATH2H"] = function(msg) local f = AttuneHelperDB; f["Disable Two-Handers"] = 1 - (f["Disable Two-Handers"] or 0); print("|cffffd200[AttuneHelper]|r Two-handers equipping " .. (f["Disable Two-Handers"] == 1 and "disabled" or "enabled")) end
local frame=CreateFrame("Frame"); frame:RegisterEvent("MERCHANT_SHOW"); frame:RegisterEvent("MERCHANT_CLOSED"); frame:RegisterEvent("MERCHANT_UPDATE")
frame:SetScript("OnEvent",function(self,event_name_merchant) if event_name_merchant=="MERCHANT_SHOW" or event_name_merchant=="MERCHANT_UPDATE" then for i=1,GetNumBuybackItems() do local link=GetBuybackItemLink(i); if link then local name=GetItemInfoCustom(link); if AHIgnoreList[name] or AHSetList[name] then BuybackItem(i); print("|cffff0000[Attune Helper]|r Bought back your ignored/set item: " .. name); return end end end end end)

AttuneHelper:RegisterEvent("ADDON_LOADED"); AttuneHelper:RegisterEvent("PLAYER_REGEN_DISABLED"); AttuneHelper:RegisterEvent("PLAYER_REGEN_ENABLED"); AttuneHelper:RegisterEvent("PLAYER_LOGIN"); AttuneHelper:RegisterEvent("BAG_UPDATE"); AttuneHelper:RegisterEvent("CHAT_MSG_SYSTEM")
AttuneHelper:SetScript("OnEvent",function(self,event_name_attune, arg1)
  if event_name_attune == "ADDON_LOADED" and arg1 == "AttuneHelper" then
    if AttuneHelperDB["Background Style"] == nil then AttuneHelperDB["Background Style"] = "Tooltip" end
    if type(AttuneHelperDB["Background Color"]) ~= "table" or #AttuneHelperDB["Background Color"] < 4 then AttuneHelperDB["Background Color"] = {0,0,0,0.8} end
    if AttuneHelperDB["Button Theme"] == nil then AttuneHelperDB["Button Theme"] = "Normal" end
    if AttuneHelperDB["Disable Two-Handers"] == nil then AttuneHelperDB["Disable Two-Handers"] = 0 end
    if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == nil then AttuneHelperDB["Disable Auto-Equip Mythic BoE"] = 1 end

    if type(AttuneHelperDB.AllowedForgeTypes) ~= "table" then
        AttuneHelperDB.AllowedForgeTypes = {}
        for keyName, defaultValue in pairs(defaultForgeKeysAndValues) do
            AttuneHelperDB.AllowedForgeTypes[keyName] = defaultValue
        end
    end
    LoadAllSettings()
    self:UnregisterEvent("ADDON_LOADED")
  end

  if event_name_attune=="PLAYER_LOGIN" then
   self:UnregisterEvent("PLAYER_LOGIN")
   AH_wait(3, function() synEXTloaded = true; for bag_id = 0, 4 do UpdateBagCache(bag_id) end; UpdateItemCountText() end)
  elseif event_name_attune=="BAG_UPDATE" then
    if not(synEXTloaded) then return false end
    local bagID = arg1
    UpdateBagCache(bagID)
    UpdateItemCountText()
    
    local now = GetTime()
    if now-(deltaTime or 0) < CHAT_MSG_SYSTEM_THROTTLE then -- CHAT_MSG_SYSTEM_THROTTLE is 0.2
        return 
    end
    deltaTime = now
    
    if AttuneHelperDB["Auto Equip Attunable After Combat"]==1 then
        if EquipAllButton and EquipAllButton:GetScript("OnClick") then
            AH_wait(0.1, function() -- Using AH_wait with a small delay
                if EquipAllButton and EquipAllButton:IsVisible() and EquipAllButton:GetScript("OnClick") then
                     EquipAllButton:GetScript("OnClick")()
                end
            end)
        end
    end

  elseif event_name_attune=="CHAT_MSG_SYSTEM" and AttuneHelperDB["Auto Equip Attunable After Combat"]==1 then
    -- OPTIONAL: Implement a throttle for CHAT_MSG_SYSTEM if it fires too frequently
    -- local now_chat = GetTime()
    -- if now_chat - (chatMsgSystemDelta or 0) < CHAT_MSG_SYSTEM_EVENT_THROTTLE_INTERVAL then 
    --     return 
    -- end
    -- chatMsgSystemDelta = now_chat

    if EquipAllButton and EquipAllButton:GetScript("OnClick") then
        AH_wait(0.1, function() -- Using AH_wait with a small delay
            if EquipAllButton and EquipAllButton:IsVisible() and EquipAllButton:GetScript("OnClick") then
                 EquipAllButton:GetScript("OnClick")()
            end
        end)
    end

  elseif event_name_attune == "PLAYER_REGEN_ENABLED" and AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
    if EquipAllButton and EquipAllButton:GetScript("OnClick") then
        AH_wait(0.1, function() -- Using AH_wait with a small delay
            if EquipAllButton and EquipAllButton:IsVisible() and EquipAllButton:GetScript("OnClick") then
                 EquipAllButton:GetScript("OnClick")()
            end
        end)
    end
  end
end)

SLASH_AHIGNORELIST1 = "/ahignorelist"; SlashCmdList["AHIGNORELIST"] = function(msg) local count = 0; print("|cffffd200[AttuneHelper]|r Ignored Items:"); for name, enabled in pairs(AHIgnoreList) do if enabled then print("- " .. name); count = count + 1 end end; if count == 0 then print("|cffffd200[AttuneHelper]|r No items in ignore list.") end end
local slotAliases = {head="HeadSlot",neck="NeckSlot",shoulder="ShoulderSlot",back="BackSlot",chest="ChestSlot",wrist="WristSlot",hands="HandsSlot",waist="WaistSlot",legs="LegsSlot",pants="LegsSlot",feet="FeetSlot",finger1="Finger0Slot",finger2="Finger1Slot",ring1="Finger0Slot",ring2="Finger1Slot",trinket1="Trinket0Slot",trinket2="Trinket1Slot",mh="MainHandSlot",mainhand="MainHandSlot",oh="SecondaryHandSlot",offhand="SecondaryHandSlot",ranged="RangedSlot"}
SLASH_AHBL1 = "/ahbl"; SlashCmdList["AHBL"] = function(msg) local key = msg:lower():match("^(%S+)"); local slot_val = slotAliases[key]; if not slot_val then print("|cffffd200[AttuneHelper]|r Usage: /ahbl <slot_keyword>"); print(" Valid keywords: head, neck, shoulder, back, chest, wrist, hands,"); print(" waist, legs/pants, feet, finger1/ring1, finger2/ring2, trinket1, trinket2,"); print(" mh/mainhand, oh/offhand, ranged"); return end; AttuneHelperDB[slot_val] = 1 - (AttuneHelperDB[slot_val] or 0); print(string.format("|cffffd200[AttuneHelper]|r %s is now %s.",slot_val,(AttuneHelperDB[slot_val] == 1 and "blacklisted" or "unblacklisted"))); local cb = _G["AttuneHelperBlacklist_" .. slot_val .. "Checkbox"]; if cb and cb.SetChecked then cb:SetChecked(AttuneHelperDB[slot_val] == 1) end end
SLASH_AHBLL1 = "/ahbll"; SlashCmdList["AHBLL"] = function() local seen, found = {}, false; print("|cffffd200[AttuneHelper]|r Blacklisted Slots:"); for _, slotName_val in ipairs(slots) do if AttuneHelperDB[slotName_val] == 1 then print("- " .. slotName_val); found = true end end; if not found then print("|cffffd200[AttuneHelper]|r No blacklisted slots.") end end