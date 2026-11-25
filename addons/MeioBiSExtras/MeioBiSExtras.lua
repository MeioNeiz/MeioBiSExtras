-- MeioBiSExtras: for Forever Leveling BiS's windows (main window, quest and wish list
-- panels, My gear beside the Character frame)
--   Compare: item tooltips always show the equipped-item comparison. The game only adds it
--     on Shift (alwaysCompareItems off), and bag slots re-set their tooltip every 0.2 s so
--     Shift works mid-hover; BiS rows set it once, so it showed only if Shift was already
--     down on entering the row.
--   Wowhead: Alt-click an item for its Wowhead Forever link in a box to copy (addons can't
--     open a browser, CopyToClipboard is Blizzard-only); Ctrl+C there says so in chat and
--     closes it. BiS rows pass every modified click to HandleModifiedItemClick, which does
--     nothing with Alt.
--   Layering: the window and the Auction House come to the front when clicked.
--   Source order: Best in slot lists BoE first; /bisorder reorders the sources.
--   Character slots: each worn item's standing on its slot (Slots.lua).

local _, ns = ...

local WOWHEAD = "https://www.wowhead.com/forever/item=%d"

function ns.SlotsOn() return not MeioBiSExtrasDB or MeioBiSExtrasDB.slots ~= false end

local function OursFrame(frame)
  while frame do
    if frame.addsBlock then return true end
    local name = frame.GetName and frame:GetName()
    if type(name) == "string" and name:find("^ForeverLevelingBiS") then return true end
    frame = frame.GetParent and frame:GetParent()
  end
  return false
end

------------------------------------------------------------------------------ compare
local busy = false
local function Compare(tip)
  if busy or tip:IsForbidden() or not OursFrame(tip:GetOwner()) then return end
  local shopping = tip.shoppingTooltips and tip.shoppingTooltips[1] or ShoppingTooltip1
  if not shopping or shopping:IsShown() then return end
  local _, link = tip:GetItem()
  if not link then return end
  local equipLoc = select(4, C_Item.GetItemInfoInstant(link))
  if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return end
  -- A worn row is shown with SetInventoryItem: nothing to compare it with
  if tip.IsEquippedItem and tip:IsEquippedItem() then return end
  local info = tip.GetPrimaryTooltipInfo and tip:GetPrimaryTooltipInfo()
  if info and info.getterName == "GetInventoryItem" then return end
  busy = true
  local ok, err = pcall(GameTooltip_ShowCompareItem, tip)
  busy = false
  if not ok then geterrorhandler()(err) end
end

-- After the window's own lines: it calls Show once the tooltip is filled, and the game shows
-- it again after a rebuild (Shift, item data arriving), whose OnTooltipSetItem hides the
-- comparison when Shift is up
if GameTooltip_ShowCompareItem then
  hooksecurefunc(GameTooltip, "Show", Compare)
  if GameTooltip.RebuildFromTooltipInfo then
    hooksecurefunc(GameTooltip, "RebuildFromTooltipInfo", Compare)
  end
end

------------------------------------------------------------------------------ wowhead
-- popup edit boxes are shared between dialogs, hence the hook keyed on bisURL
local function CopiedHook(box)
  if box.bisHooked then return end
  box.bisHooked = true
  box:HookScript("OnKeyDown", function(b, key)
    if not (b.bisURL and key == "C" and IsControlKeyDown()) then return end
    print("|cffb090ffMeioBiSExtras:|r copied to clipboard: " .. b.bisURL)
    b.bisURL = nil
    C_Timer.After(0, function() b:GetParent():Hide() end)
  end)
  box:HookScript("OnHide", function(b) b.bisURL = nil end)
end

StaticPopupDialogs.MEIOBISEXTRAS_WOWHEAD = {
  text = "%s\nCtrl+C to copy, then paste in your browser",
  button1 = CLOSE,
  hasEditBox = true,
  editBoxWidth = 320,
  OnShow = function(dialog, url)
    local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
    box:SetText(url)
    box:HighlightText()
    box:SetFocus()
    CopiedHook(box)
    box.bisURL = url
  end,
  EditBoxOnTextChanged = function(box, url)
    if box:GetText() ~= url then
      box:SetText(url)
      box:HighlightText()
    end
  end,
  EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
  EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

local function MouseFocus()
  if GetMouseFoci then return GetMouseFoci()[1] end
  return GetMouseFocus and GetMouseFocus()
end

local function Wowhead(link)
  if not (IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then return end
  if type(link) ~= "string" or not OursFrame(MouseFocus()) then return end
  local id = tonumber(link:match("item:(%d+)"))
  if not id then return end
  local name = C_Item.GetItemInfo(link) or ("item " .. id)
  local url = WOWHEAD:format(id)
  StaticPopup_Show("MEIOBISEXTRAS_WOWHEAD", name, nil, url)
end

if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", Wowhead) end

------------------------------------------------------------------------------ layering
-- The window is HIGH, so it covered the Auction House and every other panel whatever was
-- clicked last. On MEDIUM and toplevel (as AuctionHouseFrame is), a click on either raises
-- it over the other. Side panels and the wish list dock are its children and follow; its
-- popups set their own DIALOG strata. Created on first open, hence the ticker.
local function Layer(frame)
  frame:SetFrameStrata("MEDIUM")
  frame:SetToplevel(true)
  frame:HookScript("OnShow", frame.Raise)
  frame:Raise()
end

local ticker
ticker = C_Timer.NewTicker(0.5, function()
  local frame = _G.ForeverLevelingBiSFrame
  if not frame then return end
  ticker:Cancel()
  Layer(frame)
end)

------------------------------------------------------------------------------ source order
-- Best in slot lists its sources in ForeverLevelingBiS_SourceTypes order (patch 61), read
-- once when the window is built, so a change needs /reload
local NAME = "MeioBiSExtras"
-- the rest (vendor, pvp in FLBiS 1.4) keep the addon's order after these
local DEFAULT_ORDER = { "boe", "quest", "drop", "crafted" }
local LABELS = { boe = "BoE", quest = "Quest", drop = "Dungeon", crafted = "Crafted",
  vendor = "Vendor", pvp = "PvP" }
local ALIASES = { dungeon = "drop", craft = "crafted", crafting = "crafted", quests = "quest",
  vendors = "vendor" }
local TYPED = { drop = "dungeon" }
local CMD = "|cffffd100%s|r"

local function Print(msg) print("|cffb090ff" .. NAME .. ":|r " .. msg) end

local function Labels(order)
  local out = {}
  for i, t in ipairs(order) do out[i] = LABELS[t] or t end
  return table.concat(out, ", ")
end

local function ApplyOrder(types, order)
  local original = { unpack(types) }
  local known, used = {}, {}
  for _, t in ipairs(original) do known[t] = true end
  wipe(types)
  for _, t in ipairs(order) do
    if known[t] and not used[t] then
      types[#types + 1], used[t] = t, true
    end
  end
  for _, t in ipairs(original) do
    if not used[t] then types[#types + 1] = t end
  end
end

local function Ordered(order)
  local types = { unpack(_G.ForeverLevelingBiS_SourceTypes or DEFAULT_ORDER) }
  ApplyOrder(types, order)
  return types
end

-- What Best in slot will show after /reload: the saved order over the addon's own types
local function SavedOrder() return Ordered(MeioBiSExtrasDB.sourceOrder or DEFAULT_ORDER) end
local function DefaultOrder() return Ordered(DEFAULT_ORDER) end

local function TypedList()
  local words = {}
  for i, t in ipairs(DefaultOrder()) do words[i] = TYPED[t] or t end
  return table.concat(words, ", ", 1, #words - 1) .. " or " .. words[#words]
end

local function Save(order)
  MeioBiSExtrasDB.sourceOrder = order
  Print("source order " .. Labels(SavedOrder()) .. " |cff999999- /reload to apply|r")
end

local function Help()
  Print("BiS items compare without Shift, Alt-click for Wowhead, sources in your order")
  print("  " .. CMD:format("/bisorder <sources>") .. " - list " .. TypedList()
    .. " first, e.g. quest boe (now " .. Labels(SavedOrder()) .. ")")
  print("  " .. CMD:format("/bisorder reset") .. " - back to " .. Labels(DefaultOrder()))
  print("  " .. CMD:format("/bisorder settings") .. " - open the Settings panel")
  print("  " .. CMD:format("/bisorder help") .. " - this list")
  print("  Settings: Esc > Options > AddOns > " .. NAME .. " ("
    .. CMD:format("/bisorder settings") .. ")")
end

local category

local function OpenSettings()
  if not category then return Help() end
  Settings.OpenToCategory(category:GetID())
end

local POSITIONS = { "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th" }

-- One dropdown per place; picking a source swaps it with the one there (stays a full order)
local function RegisterSettings()
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory(NAME)
  local header = CreateSettingsListSectionHeaderInitializer
  if header then layout:AddInitializer(header("Character frame")) end
  local slots = Settings.RegisterAddOnSetting(category, "MEIOBISEXTRAS_SLOTS", "slots",
    MeioBiSExtrasDB, Settings.VarType.Boolean, "Slot standing", true)
  slots:SetValueChangedCallback(function() ns.RefreshSlots() end)
  Settings.CreateCheckbox(category, slots, "Each worn item's standing for your main spec on its"
    .. " slot: BiS, or its % of the best you can get now, in My gear's colours.")
  if header then
    layout:AddInitializer(header("Best in slot source order", "The order of the source lists"
      .. " on Forever Leveling BiS's Best in slot tab. A change shows after /reload."))
  end
  local variables, default = {}, DefaultOrder()
  for i = 1, math.min(#default, #POSITIONS) do
    variables[i] = "MEIOBISEXTRAS_SOURCE_" .. i
    local setting = Settings.RegisterProxySetting(category, variables[i],
      Settings.VarType.String, POSITIONS[i] .. " listed", default[i],
      function() return SavedOrder()[i] end,
      function(t)
        local order = SavedOrder()
        for j, u in ipairs(order) do
          if u == t then
            order[i], order[j] = t, order[i]
            break
          end
        end
        Save(order)
        for j, v in ipairs(variables) do
          if j ~= i then Settings.NotifyUpdate(v) end
        end
      end)
    Settings.CreateDropdown(category, setting, function()
      local c = Settings.CreateControlTextContainer()
      for _, t in ipairs(default) do c:Add(t, LABELS[t] or t) end
      return c:GetData()
    end, ("The source listed %s on the Best in slot tab. The one there takes this "
      .. "one's place. /reload to apply (/bisorder boe quest does the same)."):format(
      POSITIONS[i]))
  end
  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer("Source order", "Reset order",
      function()
        SlashCmdList.MEIOBISEXTRASORDER("reset")
        for _, v in ipairs(variables) do Settings.NotifyUpdate(v) end
      end, "Back to " .. Labels(default) .. " (/bisorder reset). /reload to apply.",
      true))
  end
  Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_LOGIN" then
    local ok, err = pcall(RegisterSettings)
    if not ok then geterrorhandler()(err) end
    return
  end
  if name ~= NAME then return end
  self:UnregisterEvent("ADDON_LOADED")
  MeioBiSExtrasDB = MeioBiSExtrasDB or {}
  if MeioBiSExtrasDB.slots == nil then MeioBiSExtrasDB.slots = true end
  local types = _G.ForeverLevelingBiS_SourceTypes
  if types then ApplyOrder(types, MeioBiSExtrasDB.sourceOrder or DEFAULT_ORDER) end
end)

function MeioBiSExtras_OnAddonCompartmentClick() OpenSettings() end

SLASH_MEIOBISEXTRASORDER1 = "/bisorder"
SlashCmdList.MEIOBISEXTRASORDER = function(msg)
  local words = {}
  for w in (msg or ""):lower():gmatch("%S+") do words[#words + 1] = ALIASES[w] or w end
  local first = words[1]
  if not first or first == "help" or first == "?" then return Help() end
  if first == "settings" or first == "options" then return OpenSettings() end
  if first == "reset" then
    MeioBiSExtrasDB.sourceOrder = nil
    Print("source order " .. Labels(DefaultOrder()) .. " |cff999999- /reload to apply|r")
    return
  end
  for _, w in ipairs(words) do
    if not LABELS[w] then
      Print(('unknown command "%s"'):format(w))
      return Help()
    end
  end
  if not _G.ForeverLevelingBiS_SourceTypes then
    Print("|cffff8080Forever Leveling BiS isn't patched|r (run mods.ps1 from the " .. NAME
      .. " download, then /reload)")
    return
  end
  local order = { unpack(_G.ForeverLevelingBiS_SourceTypes) }
  ApplyOrder(order, words)
  Save(order)
end
