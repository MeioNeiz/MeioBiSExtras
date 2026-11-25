-- Character frame slots: each worn item's standing for the main spec ("BiS", "62%") on its
-- slot, in My gear's tier colours, from ForeverLevelingBiS_API.GetVerdicts (patch 64).
-- The slot tooltip carries the detail (MeioTooltipFold's BiS line).
local _, ns = ...

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

-- text, colour; nil when there is nothing to say
local function Standing(link)
  local api = ForeverLevelingBiS_API
  if not (link and api and api.GetVerdicts) then return nil end
  local ok, v = pcall(api.GetVerdicts, link)
  if not ok or not v or v.cant or v.reason or v.loading then return nil end
  if v.best then return "BiS", BIS end
  if v.ratio then return ("%d%%"):format(math.floor(v.ratio * 100)), Tier(v.ratio) end
end

local function Mark(button)
  local id = button.GetID and button:GetID()
  if not id or SKIP[id] then return end
  local text, color
  if ns.SlotsOn() then
    text, color = Standing(GetInventoryItemLink("player", id))
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
  local api = ForeverLevelingBiS_API
  if api and api.OnChanged then
    api.OnChanged(function()
      if CharacterFrame and CharacterFrame:IsShown() then ns.RefreshSlots() end
    end)
  end
end)
