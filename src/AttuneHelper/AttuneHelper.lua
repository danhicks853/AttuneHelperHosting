AHIgnoreList = AHIgnoreList or {}
AHSetList = AHSetList or {}
AttuneHelperDB = AttuneHelperDB or {}

local deltaTime = 0
local CHAT_MSG_SYSTEM_THROTTLE = 0.2
local waitTable = {}
local waitFrame = nil
local MYTHIC_MIN_ITEMID = 52203

if AttuneHelperDB["Background Style"]==nil then AttuneHelperDB["Background Style"]="Tooltip" end
if type(AttuneHelperDB["Background Color"])~="table" or #AttuneHelperDB["Background Color"]<4 then AttuneHelperDB["Background Color"]={0,0,0,0.8} end
if AttuneHelperDB["Button Color"]==nil then AttuneHelperDB["Button Color"]={1,1,1,1} end
if AttuneHelperDB["Button Theme"]==nil then AttuneHelperDB["Button Theme"]="Normal" end

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

local function ApplyButtonTheme(theme)
  if not themePaths[theme] then 
      return 
  end
  
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
        local d=table.remove(rec,1)
        local f=table.remove(rec,1)
        local p=table.remove(rec,1)
        if d>elapsed then
          table.insert(waitTable,i,{d-elapsed,f,p})
          i=i+1
        else
          f(unpack(p))
        end
      end
    end)
  end
  table.insert(waitTable,{delay,func,{...}})
  return true
end

local function HideEquipPopups()
  StaticPopup_Hide("EQUIP_BIND")
  StaticPopup_Hide("AUTOEQUIP_BIND")

  for i = 1, STATICPOPUP_NUMDIALOGS do
    local f = _G["StaticPopup"..i]
    if f and f:IsVisible() then
      local w = f.which
      if w == "EQUIP_BIND" or w == "AUTOEQUIP_BIND" then
        f:Hide()
      end
    end
  end
end

local AttuneHelper=CreateFrame("Frame","AttuneHelperFrame",UIParent)
AttuneHelper:SetSize(185,125)
AttuneHelper:SetPoint("CENTER")
AttuneHelper:EnableMouse(true)
AttuneHelper:SetMovable(true)
AttuneHelper:RegisterForDrag("LeftButton")
AttuneHelper:SetScript("OnDragStart",AttuneHelper.StartMoving)
AttuneHelper:SetScript("OnDragStop",AttuneHelper.StopMovingOrSizing)
AttuneHelper:SetBackdrop{
  bgFile=BgStyles[AttuneHelperDB["Background Style"]],
  edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
  tile=true,tileSize=16,edgeSize=16,
  insets={left=4,right=4,top=4,bottom=4}
}
AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"]))
AttuneHelper:SetBackdropBorderColor(0.4,0.4,0.4)

local function SaveAllSettings()
  if not InterfaceOptionsFrame or not InterfaceOptionsFrame:IsShown() then
    return
  end
  do
    local f=_G["AttuneHelperBgDropdown"]
    if f then
      local v=UIDropDownMenu_GetSelectedValue(f)
      if v then AttuneHelperDB["Background Style"]=v end
    end
  end
  do
    local f=_G["AttuneHelperButtonThemeDropdown"]
    if f then
      local v=UIDropDownMenu_GetSelectedValue(f)
      if v then AttuneHelperDB["Button Theme"]=v end
    end
  end
  for _,cb in ipairs(blacklist_checkboxes) do
    local sn=cb:GetName():gsub("AttuneHelperBlacklist_",""):gsub("Checkbox","")
    AttuneHelperDB[sn]=cb:GetChecked() and 1 or 0
  end
  for _,cb in ipairs(general_option_checkboxes) do
    AttuneHelperDB[cb:GetName()]=cb:GetChecked() and 1 or 0
  end
end

local function LoadAllSettings()
  if AttuneHelperDB["Background Style"]==nil then AttuneHelperDB["Background Style"]="Tooltip" end
  if type(AttuneHelperDB["Background Color"])~="table" or #AttuneHelperDB["Background Color"]<4 then AttuneHelperDB["Background Color"]={0,0,0,0.8} end
  if AttuneHelperDB["Button Theme"]==nil then AttuneHelperDB["Button Theme"]="Normal" end

  local bg=_G["AttuneHelperBgDropdown"]
  if bg then
    UIDropDownMenu_SetSelectedValue(bg,AttuneHelperDB["Background Style"])
    UIDropDownMenu_SetText(bg,AttuneHelperDB["Background Style"])
  end
  if BgStyles[AttuneHelperDB["Background Style"]] then
    AttuneHelper:SetBackdrop{
      bgFile=BgStyles[AttuneHelperDB["Background Style"]],
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=(AttuneHelperDB["Background Style"]~="Atunament"),
      tileSize=(AttuneHelperDB["Background Style"]=="Atunament" and 0 or 16),
      edgeSize=16,insets={left=4,right=4,top=4,bottom=4}
    }
    AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"]))
  end

  local theme = AttuneHelperDB["Button Theme"] or "Normal"
  local bt = _G["AttuneHelperButtonThemeDropdown"]
  if bt then
    UIDropDownMenu_SetSelectedValue(bt, theme)
    UIDropDownMenu_SetText(bt, theme)
  end
  ApplyButtonTheme(theme)

  local bgc=AttuneHelperDB["Background Color"]
  local sw=_G["AttuneHelperBgColorSwatch"]
  if sw then sw:SetBackdropColor(bgc[1],bgc[2],bgc[3],1) end
  local sl=_G["AttuneHelperAlphaSlider"]
  if sl then sl:SetValue(bgc[4]) end

  for _,cb in ipairs(blacklist_checkboxes) do
    local sn=cb:GetName():gsub("AttuneHelperBlacklist_",""):gsub("Checkbox","")
    if AttuneHelperDB[sn]==nil then AttuneHelperDB[sn]=0 end
    cb:SetChecked(AttuneHelperDB[sn]==1)
  end
  for _,cb in ipairs(general_option_checkboxes) do
    local k=cb:GetName()
    if AttuneHelperDB[k]==nil then AttuneHelperDB[k]=0 end
    cb:SetChecked(AttuneHelperDB[k]==1)
  end
end

local function CreateButton(name,parent,text,anchor,ap,xOff,yOff,width,height,colors,scale)
  scale=scale or 1
  local x1,y1,x2,y2=65,176,457,290
  local rw, rh = x2-x1, y2-y1
  local u1,u2=x1/512,x2/512
  local v1,v2=y1/512,y2/512
  if width and not height then height=width*rh/rw
  elseif height and not width then width=height*rw/rh
  else height=24;width=height*rw/rh*1.5 end
  local btn=CreateFrame("Button",name,parent,"UIPanelButtonTemplate")
  btn:SetSize(width,height);btn:SetScale(scale)
  btn:SetPoint(ap,anchor,ap,xOff,yOff)
  btn:SetText(text)
  local theme=AttuneHelperDB["Button Theme"] or "Normal"
  btn:SetNormalTexture(themePaths[theme].normal)
  btn:SetPushedTexture(themePaths[theme].pushed)
  btn:SetHighlightTexture(themePaths[theme].pushed,"ADD")
  for _,s in ipairs({"Normal","Pushed","Highlight"}) do
    local tex=btn["Get"..s.."Texture"](btn)
    tex:SetTexCoord(u1,u2,v1,v2)
    local c=colors and colors[s:lower()]
    if c then tex:SetVertexColor(c[1],c[2],c[3],c[4] or 1) end
  end
  btn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
  btn:SetBackdropColor(0,0,0,0.5)
  btn:SetBackdropBorderColor(1,1,1,1)
  return btn
end

local SynastriaCoreLib=LibStub("SynastriaCoreLib-1.0")
local EquipAllButton,SortInventoryButton,VendorAttunedButton

local mainPanel=CreateFrame("Frame","AttuneHelperOptionsPanel",UIParent)
mainPanel.name="AttuneHelper"
InterfaceOptions_AddCategory(mainPanel)
local title=mainPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
title:SetPoint("TOPLEFT",16,-16);title:SetText("AttuneHelper")
local description=mainPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
description:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-8)
description:SetPoint("RIGHT",-32,0);description:SetJustifyH("LEFT")
description:SetText("AttuneHelper is an addon to assist players with attuning items.")

local blacklistPanel=CreateFrame("Frame","AttuneHelperBlacklistOptionsPanel",mainPanel)
blacklistPanel.name="Blacklisting";blacklistPanel.parent=mainPanel.name
InterfaceOptions_AddCategory(blacklistPanel)
local generalOptionsPanel=CreateFrame("Frame","AttuneHelperGeneralOptionsPanel",mainPanel)
generalOptionsPanel.name="General Options";generalOptionsPanel.parent=mainPanel.name
InterfaceOptions_AddCategory(generalOptionsPanel)

local titleB=blacklistPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
titleB:SetPoint("TOPLEFT",16,-16);titleB:SetText("Blacklisting")
local descB=blacklistPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
descB:SetPoint("TOPLEFT",titleB,"BOTTOMLEFT",0,-8)
descB:SetPoint("RIGHT",-32,0);descB:SetJustifyH("LEFT")
descB:SetText("Choose which equipment slots to blacklist.")

local titleG=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
titleG:SetPoint("TOPLEFT",16,-16);titleG:SetText("General Options")
local descG=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
descG:SetPoint("TOPLEFT",titleG,"BOTTOMLEFT",0,-8)
descG:SetPoint("RIGHT",-32,0);descG:SetJustifyH("LEFT")
descG:SetText("Choose general options. (Relog or click Equip Attunables to update)")

local slots={"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
             "HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot",
             "Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot",
             "SecondaryHandSlot","RangedSlot"}
local general_options={"Sell Attuned Mythic Gear?","Auto Equip Attunable After Combat",
                        "Do Not Sell BoE Items","Limit Selling to 12 Items?"}
blacklist_checkboxes={}
general_option_checkboxes={}

local function CreateCheckbox(type,name,parent,x,y)
  local nm=(type=="BlackList")
    and "AttuneHelperBlacklist_"..name.."Checkbox" or name
  local cb=CreateFrame("CheckButton",nm,parent,"UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT",x,y)
  local txt=cb:CreateFontString(nil,"ARTWORK","GameFontHighlight")
  txt:SetPoint("LEFT",cb,"RIGHT",4,0);txt:SetText(name)
  return cb
end

local function InitializeOptionCheckboxes()
  local x0,y0,row,col=16,-60,0,0
  for _,slot in ipairs(slots) do
    local cb=CreateCheckbox("BlackList",slot,blacklistPanel,
                            x0+120*col,y0-33*row)
    table.insert(blacklist_checkboxes,cb)
    row=row+1;if row==6 then row=0;col=col+1 end
  end
  for i,opt in ipairs(general_options) do
    local cb=CreateCheckbox("General",opt,generalOptionsPanel,
                            16,-60-33*(i-1))
    table.insert(general_option_checkboxes,cb)
  end
end

InitializeOptionCheckboxes()
for _,cb in ipairs(blacklist_checkboxes) do cb:SetScript("OnClick",SaveAllSettings) end
for _,cb in ipairs(general_option_checkboxes) do cb:SetScript("OnClick",SaveAllSettings) end

local bgLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormal")
bgLabel:SetPoint("TOPLEFT",general_option_checkboxes[#general_option_checkboxes],
                 "BOTTOMLEFT",0,-16);bgLabel:SetText("Background Style:")

local bgDropdown=CreateFrame("Frame","AttuneHelperBgDropdown",generalOptionsPanel,
                             "UIDropDownMenuTemplate")
bgDropdown:SetPoint("TOPLEFT",bgLabel,"BOTTOMLEFT",-16,0)
UIDropDownMenu_SetWidth(bgDropdown,160)
local function OnBgSelect(self)
  UIDropDownMenu_SetSelectedValue(bgDropdown,self.value)
  AttuneHelperDB["Background Style"]=self.value
  UIDropDownMenu_SetText(bgDropdown,self.value)
  AttuneHelper:SetBackdrop{
    bgFile=BgStyles[self.value],
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=(self.value~="Atunament"),
    tileSize=(self.value=="Atunament" and 0 or 16),
    edgeSize=16,insets={left=4,right=4,top=4,bottom=4}
  }
  AttuneHelper:SetBackdropColor(unpack(AttuneHelperDB["Background Color"]))
  SaveAllSettings()
end
UIDropDownMenu_Initialize(bgDropdown,function(self)
  for style in pairs(BgStyles) do
    local info=UIDropDownMenu_CreateInfo()
    info.text=style;info.value=style;info.func=OnBgSelect
    info.checked=(style==AttuneHelperDB["Background Style"])
    UIDropDownMenu_AddButton(info)
  end
end)
UIDropDownMenu_SetText(bgDropdown,AttuneHelperDB["Background Style"])

local swatch=CreateFrame("Button","AttuneHelperBgColorSwatch",generalOptionsPanel)
swatch:SetSize(16,16);swatch:SetPoint("LEFT",bgDropdown,"RIGHT",20,0)
swatch:SetBackdrop{bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
  tile=true,tileSize=4,edgeSize=4,insets={left=1,right=1,top=1,bottom=1}}
swatch:SetBackdropBorderColor(0,0,0,1)
swatch:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Background Color");GameTooltip:Show()
end)
swatch:SetScript("OnLeave",GameTooltip_Hide)
swatch:SetScript("OnClick",function(self)
  local color=AttuneHelperDB["Background Color"]
  if type(color)~="table" or #color<4 then color={0,0,0,0.8};AttuneHelperDB["Background Color"]=color end
  ColorPickerFrame.func=function()
    local r,g,b=ColorPickerFrame:GetColorRGB()
    color[1],color[2],color[3]=r,g,b
    swatch:SetBackdropColor(r,g,b,1)
    AttuneHelper:SetBackdropColor(r,g,b,color[4])
    SaveAllSettings()
  end
  ColorPickerFrame.hasOpacity=false
  ColorPickerFrame:SetColorRGB(color[1],color[2],color[3])
  if _G.ColorPickerFrameOpacitySlider then _G.ColorPickerFrameOpacitySlider:Hide() end
  ColorPickerFrame:Show()
end)

local swatchLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontHighlight")
swatchLabel:SetPoint("LEFT",swatch,"RIGHT",4,0);swatchLabel:SetText("BG Color")

local alphaLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormal")
alphaLabel:SetPoint("TOPLEFT",bgDropdown,"BOTTOMLEFT",20,0);alphaLabel:SetText("BG Transparency:")

local alphaSlider=CreateFrame("Slider","AttuneHelperAlphaSlider",generalOptionsPanel,
                              "OptionsSliderTemplate")
alphaSlider:SetOrientation("HORIZONTAL")
alphaSlider:SetMinMaxValues(0,1)
alphaSlider:SetValueStep(0.01)
alphaSlider:SetWidth(150)
alphaSlider:SetPoint("TOPLEFT",alphaLabel,"BOTTOMLEFT",0,-8)
alphaSlider:SetValue(AttuneHelperDB["Background Color"][4])
alphaSlider:SetScript("OnValueChanged",function(self,val)
  AttuneHelperDB["Background Color"][4]=val
  local c=AttuneHelperDB["Background Color"]
  AttuneHelper:SetBackdropColor(c[1],c[2],c[3],c[4])
  SaveAllSettings()
end)

_G.AttuneHelperAlphaSliderLow:SetText("0")
_G.AttuneHelperAlphaSliderHigh:SetText("1")
_G.AttuneHelperAlphaSliderText:SetText("")

local btLabel=generalOptionsPanel:CreateFontString(nil,"ARTWORK","GameFontNormal")
btLabel:SetPoint("TOPLEFT",alphaSlider,"BOTTOMLEFT",0,-20);btLabel:SetText("Button Theme:")

local btDropdown=CreateFrame("Frame","AttuneHelperButtonThemeDropdown",
                             generalOptionsPanel,"UIDropDownMenuTemplate")

btDropdown:SetPoint("TOPLEFT",btLabel,"BOTTOMLEFT",-16,0)
UIDropDownMenu_SetWidth(btDropdown,160)

local function OnBtnThemeSelect(self)
  local v = self.value
  UIDropDownMenu_SetSelectedValue(btDropdown, v)
  UIDropDownMenu_SetText(btDropdown, v)
  AttuneHelperDB["Button Theme"] = v
  ApplyButtonTheme(v)
  SaveAllSettings()
end

UIDropDownMenu_Initialize(btDropdown,function(self)
  for _,th in ipairs({"Normal","Blue"}) do
    local info=UIDropDownMenu_CreateInfo()
    info.text=th;info.value=th;info.func=OnBtnThemeSelect
    info.checked=(th==AttuneHelperDB["Button Theme"])
    UIDropDownMenu_AddButton(info)
  end
end)
UIDropDownMenu_SetText(btDropdown,AttuneHelperDB["Button Theme"])

generalOptionsPanel.okay   = SaveAllSettings
generalOptionsPanel.cancel = LoadAllSettings
generalOptionsPanel.refresh= LoadAllSettings
blacklistPanel.okay        = SaveAllSettings
blacklistPanel.cancel      = LoadAllSettings
blacklistPanel.refresh     = LoadAllSettings

local function EquipItemInInventory(slotName)
  if AttuneHelperDB[slotName]==1 then return end
  local itemTypeToSlot={
    INVTYPE_HEAD="HeadSlot",INVTYPE_NECK="NeckSlot",INVTYPE_SHOULDER="ShoulderSlot",INVTYPE_CLOAK="BackSlot",
    INVTYPE_CHEST="ChestSlot",INVTYPE_ROBE="ChestSlot",INVTYPE_WAIST="WaistSlot",INVTYPE_LEGS="LegsSlot",
    INVTYPE_FEET="FeetSlot",INVTYPE_WRIST="WristSlot",INVTYPE_HAND="HandsSlot",INVTYPE_FINGER={"Finger0Slot","Finger1Slot"},
    INVTYPE_TRINKET={"Trinket0Slot","Trinket1Slot"},INVTYPE_WEAPON={"MainHandSlot","SecondaryHandSlot"},
    INVTYPE_2HWEAPON="MainHandSlot",INVTYPE_WEAPONMAINHAND="MainHandSlot",INVTYPE_WEAPONOFFHAND="SecondaryHandSlot",
    INVTYPE_HOLDABLE="SecondaryHandSlot",INVTYPE_RANGED="RangedSlot",INVTYPE_THROWN="RangedSlot",
    INVTYPE_RANGEDRIGHT="RangedSlot",INVTYPE_RELIC="RangedSlot",INVTYPE_TABARD="TabardSlot",
    INVTYPE_BAG="BackSlot",INVTYPE_QUIVER="MainHandSlot",INVTYPE_AMMO="MainHandSlot",INVTYPE_WAND="RangedSlot",
    INVTYPE_SHIELD="SecondaryHandSlot"
  }
  local slotNumberMapping={Finger0Slot=11,Finger1Slot=12,Trinket0Slot=13,Trinket1Slot=14,MainHandSlot=16,SecondaryHandSlot=17}
  local mainHandItemID=GetInventoryItemID("player",16)
  if mainHandItemID then
    local _,_,_,_,_,_,_,_,equipSlot=GetItemInfo(mainHandItemID)
    if equipSlot=="INVTYPE_2HWEAPON" and slotName=="SecondaryHandSlot" then return end
  end
  for _,phase in ipairs{"attunable","set"} do
    for bag=0,4 do
      for slot=1,GetContainerNumSlots(bag) do
        local link=GetContainerItemLink(bag,slot)
        if link then
          local _,_,_,_,_,_,_,_,equipSlot=GetItemInfo(link)
          if AttuneHelperDB["Disable Two-Handers"] == 1 and equipSlot == "INVTYPE_2HWEAPON" then
            return
          end
          local expected=itemTypeToSlot[equipSlot]
          if expected==slotName or (type(expected)=="table" and tContains(expected,slotName)) then
            local ok=(phase=="attunable" and SynastriaCoreLib.IsAttunable(link)) or (phase=="set" and AHSetList[GetItemInfo(link)])
            if ok then
              local eq=slotNumberMapping[slotName] or GetInventorySlotInfo(slotName)
              EquipItemByName(link,eq)
              EquipPendingItem(0)
              ConfirmBindOnUse()
              if phase=="attunable" then HideEquipPopups() end
              return
            end
          end
        end
      end
    end
  end
end

local SWAP_THROTTLE = 0.2
EquipAllButton = CreateButton("AttuneHelperEquipAllButton",AttuneHelper,"Equip Attunables",AttuneHelper,"TOP",0,-5,nil,nil,nil,1.3)
EquipAllButton:SetScript("OnClick",function()
  -- SaveAllSettings() -- Should be fine without this check now
  local slotsList={"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot"}
  local function checkSlot(slotName)
    local link=GetInventoryItemLink("player",GetInventorySlotInfo(slotName))
    if SynastriaCoreLib.IsAttuned(link) or not SynastriaCoreLib.IsAttunableBySomeone(link) then EquipItemInInventory(slotName) end
  end
  for i,slotName in ipairs(slotsList) do
    AH_wait(SWAP_THROTTLE*i,function() checkSlot(slotName) end)
  end
end)

SortInventoryButton = CreateButton(
  "AttuneHelperSortInventoryButton",
  AttuneHelper,
  "Prepare Disenchant",
  EquipAllButton,
  "BOTTOM",
  0,
  -27,
  nil,
  nil,
  nil,
  1.3
)

SortInventoryButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("Moves Mythic items to Bag 0.")
  GameTooltip:Show()
end)

SortInventoryButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

SortInventoryButton:SetScript("OnClick", function()
  local bagZeroItems, mythicItems, ignoredMythicItems, emptySlots,
        ignoredLookup = {}, {}, {}, {}, {}
  for name in pairs(AHIgnoreList) do
    ignoredLookup[name:lower()] = true
  end

  local function IsMythicItem(itemID)
    if not itemID then
      return false
    end
    local tt = CreateFrame(
      "GameTooltip",
      "ItemTooltipScanner",
      nil,
      "GameTooltipTemplate"
    )
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:SetHyperlink("item:" .. itemID)
    for i = 1, tt:NumLines() do
      local line = _G["ItemTooltipScannerTextLeft" .. i]:GetText()
      if line and line:find("Mythic") then
        return true
      end
    end
    return false
  end

  local emptyCount = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      if not GetContainerItemID(bag, slot) then
        emptyCount = emptyCount + 1
      end
    end
  end

  if emptyCount < 16 then
    print(
      "|cffff0000[Attune Helper]|r: You must have 16 empty inventory "
        .. "slots, make space and try again."
    )
    return
  end

  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local itemID = GetContainerItemID(bag, slot)
      local itemName = itemID and GetItemInfo(itemID)
      if itemID then
        local isMythic = IsMythicItem(itemID)
        local isIgnored = itemName and ignoredLookup[itemName:lower()]
        if bag == 0 then
          if not isMythic then
            tinsert(bagZeroItems, {bag = bag, slot = slot})
          elseif isIgnored then
            tinsert(ignoredMythicItems, {bag = bag, slot = slot})
          end
        elseif isMythic and not isIgnored then
          tinsert(mythicItems, {bag = bag, slot = slot})
        end
      else
        tinsert(emptySlots, {bag = bag, slot = slot})
      end
    end
  end

  for _, item in ipairs(ignoredMythicItems) do
    if #emptySlots > 0 then
      local tgt = tremove(emptySlots)
      PickupContainerItem(item.bag, item.slot)
      PickupContainerItem(tgt.bag, tgt.slot)
    end
  end

  for _, item in ipairs(bagZeroItems) do
    if #emptySlots > 0 then
      local tgt = tremove(emptySlots)
      PickupContainerItem(item.bag, item.slot)
      PickupContainerItem(tgt.bag, tgt.slot)
    end
  end

  for _, item in ipairs(mythicItems) do
    if #emptySlots > 0 then
      local tgt = tremove(emptySlots, 1)
      PickupContainerItem(item.bag, item.slot)
      PickupContainerItem(tgt.bag, tgt.slot)
    end
  end
end)


VendorAttunedButton = CreateButton("AttuneHelperVendorAttunedButton",AttuneHelper,"Vendor Attuned",SortInventoryButton,"BOTTOM",0,-27,nil,nil,nil,1.3)
VendorAttunedButton:SetScript("OnClick",function()
  if not MerchantFrame:IsShown() then return end
  local limit=AttuneHelperDB["Limit Selling to 12 Items?"]==1
  local maxSell=limit and 12 or math.huge
  local sold=0
  local function IsBoE(itemID,bag,slot)
    if not itemID then return false end
    local tt=CreateFrame("GameTooltip","BoETooltipScanner",nil,"GameTooltipTemplate")
    tt:SetOwner(UIParent,"ANCHOR_NONE")
    tt:SetHyperlink("item:"..itemID)
    local boe=false
    for i=1,tt:NumLines() do
      local line=_G["BoETooltipScannerTextLeft"..i]:GetText()
      if line and line:find("Binds when equipped") then boe=true;break end
    end
    if boe and bag and slot then
      tt:SetOwner(UIParent,"ANCHOR_NONE")
      tt:SetBagItem(bag,slot)
      for i=1,tt:NumLines() do
        local line=_G["BoETooltipScannerTextLeft"..i]:GetText()
        if line and line:find("Soulbound") then tt:Hide() return false end
      end
    end
    return boe
  end
  for bag=0,4 do
    for slot=1,GetContainerNumSlots(bag) do
      if sold>=maxSell then return end
      local link=GetContainerItemLink(bag,slot)
      local itemID=GetContainerItemID(bag,slot)
      if link then
        local name=GetItemInfo(link)
        if not (AHIgnoreList[name] or AHSetList[name]) then
          local attuned=SynastriaCoreLib.IsAttuned(link)
          local boe=IsBoE(itemID,bag,slot)
          local isMythic=itemID>=MYTHIC_MIN_ITEMID
          local dont=AttuneHelperDB["Do Not Sell BoE Items"]==1 and attuned and boe
          local sellMythic=AttuneHelperDB["Sell Attuned Mythic Gear?"]==1
          local should=(isMythic and sellMythic) or not isMythic
          if attuned and should and not dont then
            PickupContainerItem(bag,slot)
            if CursorHasItem() then UseContainerItem(bag,slot) end
            sold=sold+1
          end
        end
      end
    end
  end
end)

ApplyButtonTheme(AttuneHelperDB["Button Theme"])

local AttuneHelperItemCountText=AttuneHelper:CreateFontString(nil,"OVERLAY","GameFontNormal")
AttuneHelperItemCountText:SetPoint("BOTTOM",0,6)
AttuneHelperItemCountText:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
AttuneHelperItemCountText:SetTextColor(1,1,1,1)
AttuneHelperItemCountText:SetText("Attunables in Inventory: 0")

local function UpdateItemCountText()
  local c=0
  for bag=0,4 do
    for slot=1,GetContainerNumSlots(bag) do
      local link=GetContainerItemLink(bag,slot)
      if link and SynastriaCoreLib.IsAttunable(link) then c=c+1 end
    end
  end
  AttuneHelperItemCountText:SetText("Attunables in Inventory: "..c)
end

AH_wait(2,UpdateItemCountText)

SLASH_ATTUNEHELPER1="/ath"
SlashCmdList["ATTUNEHELPER"]=function(msg)
  local cmd=msg:lower():match("^(%S*)")
  if cmd=="reset" then AttuneHelper:ClearAllPoints() AttuneHelper:SetPoint("CENTER") print("ATH: UI position reset.")
  elseif cmd=="show" then AttuneHelper:Show()
  elseif cmd=="hide" then AttuneHelper:Hide()
  elseif cmd=="sort" then SortInventoryButton:GetScript("OnClick")()
  elseif cmd=="equip" then EquipAllButton:GetScript("OnClick")()
  elseif cmd=="vendor" then VendorAttunedButton:GetScript("OnClick")()
  else
    print("/ath show hide reset equip sort vendor")
  end
end

SLASH_AHIGNORE1="/AHIgnore"
SlashCmdList["AHIGNORE"]=function(msg)
  local n=GetItemInfo(msg)
  if not n then print("Invalid item link.") return end
  AHIgnoreList[n]=not AHIgnoreList[n]
  print(n..(AHIgnoreList[n] and " is now ignored." or " will no longer be ignored."))
end

SLASH_AHSET1="/AHSet"
SlashCmdList["AHSET"]=function(msg)
  local n=GetItemInfo(msg)
  if not n then print("Invalid item link.") return end
  AHSetList[n]=not AHSetList[n]
  print(n..(AHSetList[n] and " is now included in your gear set." or " is no longer included in your gear set."))
end

SLASH_ATH2H1 = "/ah2h"
SlashCmdList["ATH2H"] = function(msg)
  local f = AttuneHelperDB
  f["Disable Two-Handers"] = 1 - (f["Disable Two-Handers"] or 0)
  print(
    "|cffffd200[AttuneHelper]|r Two-handers equipping " ..
    (f["Disable Two-Handers"] == 1 and "disabled" or "enabled")
  )
end

local frame=CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:SetScript("OnEvent",function(self,event)
  if event=="MERCHANT_SHOW" or event=="MERCHANT_UPDATE" then
    for i=1,GetNumBuybackItems() do
      local link=GetBuybackItemLink(i)
      if link then
        local name=GetItemInfo(link)
        if AHIgnoreList[name] or AHSetList[name] then
          BuybackItem(i)
          print("|cffff0000[Attune Helper]|r Bought back your ignored/set item.")
        end
      end
    end
  end
end)

blacklistPanel:RegisterEvent("PLAYER_LOGOUT")
blacklistPanel:SetScript("OnEvent", function(self, e, ...)
  if e == "PLAYER_LOGOUT" then
    SaveAllSettings()
  end
end)

AttuneHelper:RegisterEvent("ADDON_LOADED")
AttuneHelper:RegisterEvent("PLAYER_REGEN_DISABLED")
AttuneHelper:RegisterEvent("PLAYER_REGEN_ENABLED")
AttuneHelper:RegisterEvent("PLAYER_LOGIN")
AttuneHelper:RegisterEvent("BAG_UPDATE")
AttuneHelper:RegisterEvent("CHAT_MSG_SYSTEM")
AttuneHelper:RegisterEvent("PLAYER_LOGOUT")
AttuneHelper:SetScript("OnEvent",function(self,event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AttuneHelper" then
        if AttuneHelperDB["Background Style"] == nil then
            AttuneHelperDB["Background Style"] = "Tooltip"
        end
        if type(AttuneHelperDB["Background Color"]) ~= "table" or #AttuneHelperDB["Background Color"] < 4 then
            AttuneHelperDB["Background Color"] = {0,0,0,0.8}
        end
        if AttuneHelperDB["Button Theme"] == nil then
            AttuneHelperDB["Button Theme"] = "Normal"
        end

        if AttuneHelperDB["Disable Two-Handers"] == nil then
          AttuneHelperDB["Disable Two-Handers"] = 0
        end

        LoadAllSettings()

        self:UnregisterEvent("ADDON_LOADED")
    end
  if event=="PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    LoadAllSettings()
    UpdateItemCountText()
  elseif event=="BAG_UPDATE" then
    UpdateItemCountText()
    local now=GetTime()
    if now-deltaTime<CHAT_MSG_SYSTEM_THROTTLE then return end
    deltaTime=now
    if AttuneHelperDB["Auto Equip Attunable After Combat"]==1 then EquipAllButton:GetScript("OnClick")() end
  elseif event=="CHAT_MSG_SYSTEM" and AttuneHelperDB["Auto Equip Attunable After Combat"]==1 then
    if arg1:find("attuned") then EquipAllButton:GetScript("OnClick")() end
    elseif event == "PLAYER_REGEN_ENABLED" and AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
      EquipAllButton:GetScript("OnClick")()
    end
end)

SLASH_AHIGNORELIST1 = "/ahignorelist"
SlashCmdList["AHIGNORELIST"] = function(msg)
  local count = 0
  for name, enabled in pairs(AHIgnoreList) do
    if enabled then
      print("|cffffd200[AttuneHelper]|r Ignored: " .. name)
      count = count + 1
    end
  end
  if count == 0 then
    print("|cffffd200[AttuneHelper]|r No items in ignore list.")
  end
end

-- shorthand→slot mapping (aliases for pants/legs, mh/oh, etc.)
local slotAliases = {
  head      = "HeadSlot",
  neck      = "NeckSlot",
  shoulder  = "ShoulderSlot",
  back      = "BackSlot",
  chest     = "ChestSlot",
  wrist     = "WristSlot",
  hands     = "HandsSlot",
  waist     = "WaistSlot",
  legs      = "LegsSlot",
  pants     = "LegsSlot",       -- alias
  feet      = "FeetSlot",
  finger1   = "Finger0Slot",
  finger2   = "Finger1Slot",
  trinket1  = "Trinket0Slot",
  trinket2  = "Trinket1Slot",
  mh        = "MainHandSlot",   -- main hand
  mainhand  = "MainHandSlot",
  oh        = "SecondaryHandSlot", -- off hand
  offhand   = "SecondaryHandSlot",
  ranged    = "RangedSlot",
}

SLASH_AHBL1 = "/ahbl"
SlashCmdList["AHBL"] = function(msg)
  local key = msg:lower():match("^(%S+)")
  local slot = slotAliases[key]
  if not slot then
    print("|cffffd200[AttuneHelper]|r Usage: /ahbl <slot>")
    print(" Valid keys: head, neck, shoulder, back, chest, wrist, hands,")
    print(" waist, legs/pants, feet, finger1/2, trinket1/2, mh/mainhand,")
    print(" oh/offhand, ranged")
    return
  end
  -- toggle 0
  AttuneHelperDB[slot] = 1 - (AttuneHelperDB[slot] or 0)
  print(string.format(
    "|cffffd200[AttuneHelper]|r %s is now %s.",
    slot,
    (AttuneHelperDB[slot] == 1 and "blacklisted" or "unblacklisted")
  ))
  local cb = _G["AttuneHelperBlacklist_" .. slot .. "Checkbox"]
  if cb then
    cb:SetChecked(AttuneHelperDB[slot] == 1)
  end
end

SLASH_AHBLL1 = "/ahbll"
SlashCmdList["AHBLL"] = function()
  local seen, found = {}, false
  for _, slot in pairs(slotAliases) do
    if not seen[slot] then
      seen[slot] = true
      if AttuneHelperDB[slot] == 1 then
        print("|cffffd200[AttuneHelper]|r Blacklisted: " .. slot)
        found = true
      end
    end
  end
  if not found then
    print("|cffffd200[AttuneHelper]|r No blacklisted slots.")
  end
end

--====================================================================
-- Icons above main frame: Blacklist Swapper & AutoEquip toggle
--====================================================================
--[[
-- Blacklist Swapper (sword icon)
local blacklistIcon = CreateFrame(
  "Button",
  "AttuneHelperBlacklistIcon",
  AttuneHelper
)
blacklistIcon:SetSize(24, 24)
blacklistIcon:SetPoint(
  "TOPRIGHT",
  AttuneHelper,
  "TOPRIGHT",
  12,
  12
)
local btex = blacklistIcon:CreateTexture(nil, "BACKGROUND")
btex:SetAllPoints()
btex:SetTexture("Interface\\Icons\\INV_Sword_04")
blacklistIcon:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
  GameTooltip:SetText("Blacklist Swapper")
  GameTooltip:Show()
end)
blacklistIcon:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)
blacklistIcon:SetScript("OnClick", function()
  if AttuneHelper.SlotEditor and AttuneHelper.SlotEditor:IsShown() then
    AttuneHelper.SlotEditor:Hide()
  else
    BuildSlotEditor()
    AttuneHelper.SlotEditor:Show()
  end
end)

local autoEquipIcon = CreateFrame(
  "Button",
  "AttuneHelperAutoEquipIcon",
  AttuneHelper
)
autoEquipIcon:SetSize(24, 24)
autoEquipIcon:SetPoint(
  "TOPLEFT",
  AttuneHelper,
  "TOPLEFT",
  -12,
  12
)
local atex = autoEquipIcon:CreateTexture(nil, "BACKGROUND")
atex:SetAllPoints()
atex:SetTexture("Interface\\Icons\\INV_Gizmo_02")
autoEquipIcon.overlay = autoEquipIcon:CreateTexture(
  nil,
  "OVERLAY"
)
autoEquipIcon.overlay:SetSize(12, 12)
autoEquipIcon.overlay:SetPoint(
  "BOTTOMRIGHT",
  autoEquipIcon,
  "BOTTOMRIGHT",
  0,
  0
)

local function updateAutoEquipOverlay()
  local on = AttuneHelperDB[
    "Auto Equip Attunable After Combat"
  ] == 1
  autoEquipIcon.overlay:SetTexture(on and
    "Interface\\Buttons\\UI-CheckBox-Check" or
    "Interface\\Buttons\\UI-GroupLootFail"
  )
end

autoEquipIcon:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
  local on = AttuneHelperDB[
    "Auto Equip Attunable After Combat"
  ] == 1
  GameTooltip:SetText(
    "Auto Equip After Combat: " .. (on and "On" or "Off")
  )
  GameTooltip:Show()
end)
autoEquipIcon:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)
autoEquipIcon:SetScript("OnClick", function()
  local key = "Auto Equip Attunable After Combat"
  AttuneHelperDB[key] = AttuneHelperDB[key] == 1 and 0 or 1
  updateAutoEquipOverlay()
  local on = AttuneHelperDB[key] == 1
  print(
    "|cffffd200AttuneHelper|r: Auto Equip After Combat " ..
    (on and "Enabled" or "Disabled")
  )
end)

updateAutoEquipOverlay()
--]]--
-- We will finish later