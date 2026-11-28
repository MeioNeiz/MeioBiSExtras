-- Character frame slots: each worn item's standing ("BiS", "62%") on its slot, in My gear's
-- tier colours: MeioSim's ranking where it answers for your class, else the main spec's from
-- ForeverLevelingBiS_API.GetVerdicts (patch 64). The slot tooltip carries the detail.
-- Alt+right-click a slot: its upgrades in MeioSim's Best gear view, else on FLBiS's Best in
-- slot tab (bottom of the file).
local _, ns = ...

local function Sim()
  local api = MeioSim and MeioSim.API
  return api and api.Covers and api.Covers() and api or nil
end

local SKIP = { [0] = true, [4] = true, [19] = true } -- ammo, shirt, tabard
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand",
  "Ranged" }
-- MeioTooltipFold's tiers: BiS, epic, rare, poor
local BIS, EPIC, RARE, POOR = { 1, 0.5, 0 }, { 0.64, 0.21, 0.93 }, { 0.2, 0.6, 1 },
  { 0.62, 0.62, 0.62 }

local function Tier(ratio)
  return (ratio >= 0.97 and BIS) or (ratio > 0.85 and EPIC) or (ratio > 0.5 and RARE) or POOR
end

local function Label(button)
  if button.bisStanding then return button.bisStanding end
  local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  text:SetPoint("BOTTOM", button, "BOTTOM", 1, 2)
  button.bisStanding = text
  return text
end

local function Say(best, ratio)
  if best then return "BiS", BIS end
  if ratio then return ("%d%%"):format(math.floor(ratio * 100)), Tier(ratio) end
end

-- text, colour; nil when there is nothing to say (MeioSim still ranking: OnChanged comes)
local function Standing(link, slot)
  if not link then return nil end
  local sim = Sim()
  if sim then
    local s = sim.Standing(slot)
    if not s or s.worn == nil then return nil end
    return Say(s.best, s.ratio)
  end
  local api = ForeverLevelingBiS_API
  if not (link and api and api.GetVerdicts) then return nil end
  -- held: the worn item itself (FLBiS 1.5.0 judges another copy of a ring as a second one)
  local ok, v = pcall(api.GetVerdicts, link, true)
  if not ok or not v or v.cant or v.reason or v.loading then return nil end
  return Say(v.best, v.ratio)
end

local function Mark(button)
  local id = button.GetID and button:GetID()
  if not id or SKIP[id] then return end
  local text, color
  if ns.SlotsOn() then
    text, color = Standing(GetInventoryItemLink("player", id), id)
  end
  if not text then
    if button.bisStanding then button.bisStanding:Hide() end
    return
  end
  local label = Label(button)
  label:SetText(text)
  label:SetTextColor(color[1], color[2], color[3])
  label:Show()
end

local function SafeMark(button)
  local ok, err = pcall(Mark, button)
  if not ok then geterrorhandler()(err) end
end

function ns.RefreshSlots()
  for _, name in ipairs(SLOTS) do
    local button = _G["Character" .. name .. "Slot"]
    if button then SafeMark(button) end
  end
end

if PaperDollItemSlotButton_Update then
  hooksecurefunc("PaperDollItemSlotButton_Update", SafeMark)
end

-- verdicts change with level, spec, weights and items loading, not only with gear
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  local function Refresh()
    if CharacterFrame and CharacterFrame:IsShown() then ns.RefreshSlots() end
  end
  for _, api in ipairs({ ForeverLevelingBiS_API, MeioSim and MeioSim.API }) do
    if api and api.OnChanged then api.OnChanged(Refresh) end
  end
end)

-- Alt+right-click a slot: Forever Leveling BiS's window on that slot's Best in slot list,
-- where each upgrade shows its source. Its UI.ShowSlot is private, but the window's My gear
-- rows do the same on a plain click, so one row's OnClick runs as a stand-in row for the
-- slot (no .entry: a real row would take the held Alt as a modified item click).
local KEYS = { [1] = "head", [2] = "neck", [3] = "shoulder", [15] = "back", [5] = "chest",
  [9] = "wrist", [10] = "hands", [6] = "waist", [7] = "legs", [8] = "feet", [11] = "finger",
  [12] = "finger", [13] = "trinket", [14] = "trinket", [16] = "mainhand", [17] = "offhand",
  [18] = "ranged" }
local HINT = "Alt-right-click: upgrades and where to get them"

local function GearRowClick()
  local window = ForeverLevelingBiSFrame
  if not window then return end
  for _, child in ipairs({ window:GetChildren() }) do
    local row = type(child.rows) == "table" and child.rows[1]
    if type(row) == "table" and row.key and row.GetScript then
      return row:GetScript("OnClick")
    end
  end
end

local function ShowUpgrades(key)
  if not ForeverLevelingBiSFrame then
    local open = SlashCmdList.FOREVERLEVELINGBIS
    if not open then return end
    open("") -- creates the window, shown
  end
  local click = GearRowClick()
  if click then click({ key = key }) end
end

local function OnClick(button, mouse)
  if mouse ~= "RightButton" or not ns.SlotsOn() then return end
  if not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
  local sim = Sim()
  if sim and sim.ShowGear then return sim.ShowGear(button:GetID()) end
  local key = KEYS[button:GetID()]
  if key then ShowUpgrades(key) end
end

local function AddHint(tip)
  tip:AddLine(HINT, 0.5, 0.5, 0.5)
end

local function OurSlot(owner)
  return owner and owner.GetID and owner.bisHint and ns.SlotsOn()
end

for _, name in ipairs(SLOTS) do
  local button = _G["Character" .. name .. "Slot"]
  if button then
    button.bisHint = true
    button:HookScript("OnClick", function(...)
      local ok, err = pcall(OnClick, ...)
      if not ok then geterrorhandler()(err) end
    end)
    -- an empty slot's tooltip is plain text, no item data for the post call below
    button:HookScript("OnEnter", function(self)
      if GameTooltip:GetOwner() ~= self or not OurSlot(self) then return end
      if GetInventoryItemLink("player", self:GetID()) then return end
      AddHint(GameTooltip)
      GameTooltip:Show()
    end)
  end
end

-- item data, so the line survives the tooltip rebuilding itself (item info loading). After
-- login's handlers, so it lands under MeioTooltipFold's BiS line (added at PLAYER_LOGIN)
local hint = CreateFrame("Frame")
hint:RegisterEvent("PLAYER_LOGIN")
hint:SetScript("OnEvent", function()
  if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then return end
  C_Timer.After(0, function()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
      if tip == GameTooltip and not tip:IsForbidden() and OurSlot(tip:GetOwner()) then
        AddHint(tip)
      end
    end)
  end)
end)
