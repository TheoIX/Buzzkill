-- BuzzKill.lua (Turtle WoW / 1.12)
-- Always-remove + Remove-at-buff-cap + Active buff picker UI.

local ADDON_NAME = "BuzzKill"

BuzzKillDB = BuzzKillDB or {}

local MAX_BUFFS_DEFAULT = 31 -- same idea as Prune's MaxBuffs=31 :contentReference[oaicite:2]{index=2}
-- Hard default for fresh installs (and auto-repair bad values)
if type(BuzzKillDB.maxBuffs) ~= "number" or BuzzKillDB.maxBuffs < 1 or BuzzKillDB.maxBuffs > 63 then
  BuzzKillDB.maxBuffs = MAX_BUFFS_DEFAULT -- 31
end

local debugEnabled = false
local AlwaysRemoveMap = {}   -- [buffID] = name
local NearCapMap     = {}    -- [buffID] = name

-- UI state
local BK_UI = nil
local selectedAlwaysIndex = nil
local selectedCapIndex = nil
local selectedActiveIndex = nil
local ActiveBuffs = {}       -- { slot, id, name, icon }

-- ------------------------------------------------------------
-- Helpers / DB
-- ------------------------------------------------------------

local function BK_Print(msg)
  if debugEnabled and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff<BuzzKill>|r " .. msg)
  end
end

local function EnsureDB()
  if not BuzzKillDB then BuzzKillDB = {} end
  if type(BuzzKillDB.list) ~= "table" then BuzzKillDB.list = {} end                 -- Always Remove
  if type(BuzzKillDB.nearCap) ~= "table" then BuzzKillDB.nearCap = {} end           -- Remove at Buff Cap
  if type(BuzzKillDB.maxBuffs) ~= "number" or BuzzKillDB.maxBuffs < 1 or BuzzKillDB.maxBuffs > 63 then
  BuzzKillDB.maxBuffs = MAX_BUFFS_DEFAULT
end

  if BuzzKillDB.debug == nil then BuzzKillDB.debug = false end
  debugEnabled = (BuzzKillDB.debug == true)
end

local function BuildMaps()
  AlwaysRemoveMap = {}
  NearCapMap = {}

  if not BuzzKillDB then return end

  for _, entry in ipairs(BuzzKillDB.list) do
    if entry and entry.id then
      AlwaysRemoveMap[entry.id] = entry.name or ("BuffID " .. tostring(entry.id))
    end
  end

  for _, entry in ipairs(BuzzKillDB.nearCap) do
    if entry and entry.id then
      NearCapMap[entry.id] = entry.name or ("BuffID " .. tostring(entry.id))
    end
  end
end

local initialized = false
local function InitOnce()
  if initialized then return end
  EnsureDB()
  BuildMaps()
  initialized = true
end

local function RemoveByID(list, id)
  local i = 1
  while i <= table.getn(list) do
    if list[i] and list[i].id == id then
      table.remove(list, i)
      return true
    end
    i = i + 1
  end
  return false
end

local function Upsert(list, id, name, icon)
  for _, entry in ipairs(list) do
    if entry and entry.id == id then
      if name and name ~= "" then entry.name = name end
      if icon and icon ~= "" then entry.icon = icon end
      return true
    end
  end
  table.insert(list, {
    id = id,
    name = (name and name ~= "" and name) or ("BuffID " .. tostring(id)),
    icon = icon
  })
  return true
end

local function AddToAlways(id, name, icon)
  EnsureDB()
  Upsert(BuzzKillDB.list, id, name, icon)
  RemoveByID(BuzzKillDB.nearCap, id) -- keep lists mutually exclusive (like Prune)
  BuildMaps()
end

local function AddToCap(id, name, icon)
  EnsureDB()
  Upsert(BuzzKillDB.nearCap, id, name, icon)
  RemoveByID(BuzzKillDB.list, id) -- keep lists mutually exclusive (like Prune)
  BuildMaps()
end

local function DelAlwaysIndex(index)
  EnsureDB()
  if not index or not BuzzKillDB.list[index] then return end
  table.remove(BuzzKillDB.list, index)
  BuildMaps()
end

local function DelCapIndex(index)
  EnsureDB()
  if not index or not BuzzKillDB.nearCap[index] then return end
  table.remove(BuzzKillDB.nearCap, index)
  BuildMaps()
end

-- ------------------------------------------------------------
-- Buff counting + removers (Prune-style)
-- ------------------------------------------------------------

local function CountBuffs()
  local count, i = 0, 0
  while i <= 63 do
    local id = GetPlayerBuffID(i)
    if id and id > 0 then count = count + 1 end
    i = i + 1
  end
  return count
end

local function RemoveAlways()
  for i = 0, 63 do
    local id = GetPlayerBuffID(i)
    if id and id > 0 and AlwaysRemoveMap[id] then
      CancelPlayerBuff(i)
      BK_Print("Removed: " .. (AlwaysRemoveMap[id] or ("BuffID " .. tostring(id))))
      return true
    end
  end
  return false
end

local function RemoveForCap()
  EnsureDB()
  local maxBuffs = BuzzKillDB.maxBuffs or MAX_BUFFS_DEFAULT

  -- Prune: if CountBuffs() <= MaxBuffs then return :contentReference[oaicite:3]{index=3}
  if CountBuffs() <= maxBuffs then return false end

  -- Prune: iterate RemoveNearCap list in order, find matching buff slot, cancel :contentReference[oaicite:4]{index=4}
  for _, entry in ipairs(BuzzKillDB.nearCap) do
    for i = 0, 63 do
      local id = GetPlayerBuffID(i)
      if id and id == entry.id then
        CancelPlayerBuff(i)
        BK_Print("Removed for buff cap: " .. (entry.name or ("BuffID " .. tostring(id))))
        return true
      end
    end
  end

  return false
end

-- ------------------------------------------------------------
-- Tooltip-based buff name retrieval (Active list)
-- ------------------------------------------------------------

local BK_Tip = nil
local function EnsureTooltip()
  if BK_Tip then return end
  BK_Tip = CreateFrame("GameTooltip", "BuzzKillTooltip", UIParent, "GameTooltipTemplate")
  BK_Tip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function GetBuffNameFromSlot(slot)
  EnsureTooltip()
  if BK_Tip.SetPlayerBuff then
    BK_Tip:ClearLines()
    BK_Tip:SetOwner(UIParent, "ANCHOR_NONE")
    BK_Tip:SetPlayerBuff(slot)
    local left1 = getglobal("BuzzKillTooltipTextLeft1")
    if left1 and left1.GetText then
      local text = left1:GetText()
      if text and text ~= "" then return text end
    end
  end
  return nil
end

local function ScanActiveBuffs()
  ActiveBuffs = {}
  for slot = 0, 63 do
    local id = GetPlayerBuffID(slot)
    if id and id > 0 then
      local icon = GetPlayerBuffTexture(slot)
      local name = GetBuffNameFromSlot(slot) or ("BuffID " .. tostring(id))
      table.insert(ActiveBuffs, { slot = slot, id = id, name = name, icon = icon })
    end
  end
end

local function FindIconIfActive(id)
  ScanActiveBuffs()
  for _, b in ipairs(ActiveBuffs) do
    if b.id == id then return b.icon end
  end
  return nil
end

-- ------------------------------------------------------------
-- Tiny Options UI
-- ------------------------------------------------------------

local function CreateRow(parent, width, height)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(width)
  row:SetHeight(height)

  row.highlight = row:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints(row)
  row.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  row.highlight:SetBlendMode("ADD")
  row.highlight:Hide()

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetWidth(16)
  row.icon:SetHeight(16)
  row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

  row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.text:SetJustifyH("LEFT")
  row.text:SetWidth(width - 30)
  row.text:SetHeight(height)

  return row
end

local function UI_RefreshAlwaysList()
  if not BK_UI then return end
  EnsureDB()

  local list = BuzzKillDB.list
  local total = table.getn(list)
  local visible = BK_UI.alwaysVisible
  local offset = FauxScrollFrame_GetOffset(BK_UI.alwaysScroll)

  for i = 1, visible do
    local row = BK_UI.alwaysRows[i]
    local idx = offset + i
    local entry = list[idx]

    if entry then
      row:Show()
      if entry.icon and entry.icon ~= "" then
        row.icon:SetTexture(entry.icon); row.icon:Show()
      else
        row.icon:Hide()
      end

      row.text:SetText(string.format("%s  |cffaaaaaa(%d)|r", entry.name or ("BuffID " .. entry.id), entry.id))

      if selectedAlwaysIndex == idx then row.highlight:Show() else row.highlight:Hide() end

      row:SetScript("OnClick", function()
        selectedAlwaysIndex = idx
        selectedCapIndex = nil
        selectedActiveIndex = nil
        UI_RefreshAlwaysList()
        UI_RefreshCapList()
        UI_RefreshActiveList()
      end)
    else
      row:Hide()
    end
  end

  FauxScrollFrame_Update(BK_UI.alwaysScroll, total, visible, BK_UI.rowH)
end

function UI_RefreshCapList()
  if not BK_UI then return end
  EnsureDB()

  local list = BuzzKillDB.nearCap
  local total = table.getn(list)
  local visible = BK_UI.capVisible
  local offset = FauxScrollFrame_GetOffset(BK_UI.capScroll)

  for i = 1, visible do
    local row = BK_UI.capRows[i]
    local idx = offset + i
    local entry = list[idx]

    if entry then
      row:Show()
      if entry.icon and entry.icon ~= "" then
        row.icon:SetTexture(entry.icon); row.icon:Show()
      else
        row.icon:Hide()
      end

      row.text:SetText(string.format("%s  |cffaaaaaa(%d)|r", entry.name or ("BuffID " .. entry.id), entry.id))

      if selectedCapIndex == idx then row.highlight:Show() else row.highlight:Hide() end

      row:SetScript("OnClick", function()
        selectedCapIndex = idx
        selectedAlwaysIndex = nil
        selectedActiveIndex = nil
        UI_RefreshAlwaysList()
        UI_RefreshCapList()
        UI_RefreshActiveList()
      end)
    else
      row:Hide()
    end
  end

  FauxScrollFrame_Update(BK_UI.capScroll, total, visible, BK_UI.rowH)
end

function UI_RefreshActiveList()
  if not BK_UI then return end

  local total = table.getn(ActiveBuffs)
  local visible = BK_UI.activeVisible
  local offset = FauxScrollFrame_GetOffset(BK_UI.activeScroll)

  for i = 1, visible do
    local row = BK_UI.activeRows[i]
    local idx = offset + i
    local entry = ActiveBuffs[idx]

    if entry then
      row:Show()
      if entry.icon and entry.icon ~= "" then
        row.icon:SetTexture(entry.icon); row.icon:Show()
      else
        row.icon:Hide()
      end

      row.text:SetText(string.format("%s  |cffaaaaaa(%d)|r", entry.name or "Unknown", entry.id))

      if selectedActiveIndex == idx then row.highlight:Show() else row.highlight:Hide() end

      row:SetScript("OnClick", function()
        selectedActiveIndex = idx
        selectedAlwaysIndex = nil
        selectedCapIndex = nil

        if BK_UI.idBox then BK_UI.idBox:SetText(tostring(entry.id)) end
        if BK_UI.nameBox then BK_UI.nameBox:SetText(entry.name or "") end
        BK_UI._pendingIcon = entry.icon

        UI_RefreshAlwaysList()
        UI_RefreshCapList()
        UI_RefreshActiveList()
      end)
    else
      row:Hide()
    end
  end

  FauxScrollFrame_Update(BK_UI.activeScroll, total, visible, BK_UI.rowH)
end

local function UI_Build()
  if BK_UI then return end

  local f = CreateFrame("Frame", "BuzzKillOptionsFrame", UIParent)
  BK_UI = f
  f:SetWidth(640)
  f:SetHeight(470)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  title:SetText("BuzzKill")

  local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetText("v1.2 TheoIX.")

  -- Debug checkbox
  local dbg = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  dbg:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -56)
  dbg.text = dbg:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  dbg.text:SetPoint("LEFT", dbg, "RIGHT", 2, 0)
  dbg.text:SetText("Debug chat messages")
  dbg:SetScript("OnClick", function()
    EnsureDB()
    BuzzKillDB.debug = (dbg:GetChecked() == 1)
    debugEnabled = (BuzzKillDB.debug == true)
  end)
  f.debugCheck = dbg

  -- Inputs
  local idLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  idLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -86)
  idLabel:SetText("Buff ID:")

  local idBox = CreateFrame("EditBox", "BuzzKillIDBox", f, "InputBoxTemplate")
  idBox:SetAutoFocus(false)
  idBox:SetWidth(90)
  idBox:SetHeight(20)
  idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
  idBox:SetTextInsets(6, 6, 3, 3)
  idBox:SetFontObject(ChatFontNormal)
  idBox:SetScript("OnEscapePressed", function() idBox:ClearFocus() end)
  f.idBox = idBox

  local nameLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  nameLabel:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -12)
  nameLabel:SetText("Name:")

  local nameBox = CreateFrame("EditBox", "BuzzKillNameBox", f, "InputBoxTemplate")
  nameBox:SetAutoFocus(false)
  nameBox:SetWidth(260)
  nameBox:SetHeight(20)
  nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
  nameBox:SetTextInsets(6, 6, 3, 3)
  nameBox:SetFontObject(ChatFontNormal)
  nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
  f.nameBox = nameBox

  -- Buttons row
  local addAlwaysBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  addAlwaysBtn:SetWidth(110)
  addAlwaysBtn:SetHeight(20)
  addAlwaysBtn:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -10)
  addAlwaysBtn:SetText("Add Always")
  addAlwaysBtn:SetScript("OnClick", function()
    local id = tonumber(f.idBox:GetText() or "")
    if not id then BK_Print("Enter a valid Buff ID.") return end
    local nm = f.nameBox:GetText() or ""
    local icon = f._pendingIcon or FindIconIfActive(id)
    AddToAlways(id, nm, icon)
    selectedAlwaysIndex = nil
    selectedCapIndex = nil
    UI_RefreshAlwaysList()
    UI_RefreshCapList()
  end)

  local addCapBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  addCapBtn:SetWidth(140)
  addCapBtn:SetHeight(20)
  addCapBtn:SetPoint("LEFT", addAlwaysBtn, "RIGHT", 8, 0)
  addCapBtn:SetText("Add Cap List")
  addCapBtn:SetScript("OnClick", function()
    local id = tonumber(f.idBox:GetText() or "")
    if not id then BK_Print("Enter a valid Buff ID.") return end
    local nm = f.nameBox:GetText() or ""
    local icon = f._pendingIcon or FindIconIfActive(id)
    AddToCap(id, nm, icon)
    selectedAlwaysIndex = nil
    selectedCapIndex = nil
    UI_RefreshAlwaysList()
    UI_RefreshCapList()
  end)

  local removeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  removeBtn:SetWidth(130)
  removeBtn:SetHeight(20)
  removeBtn:SetPoint("LEFT", addCapBtn, "RIGHT", 8, 0)
  removeBtn:SetText("Remove Selected")
  removeBtn:SetScript("OnClick", function()
    if selectedAlwaysIndex then
      DelAlwaysIndex(selectedAlwaysIndex)
      selectedAlwaysIndex = nil
      UI_RefreshAlwaysList()
      return
    end
    if selectedCapIndex then
      DelCapIndex(selectedCapIndex)
      selectedCapIndex = nil
      UI_RefreshCapList()
      return
    end
    BK_Print("Select an entry in Always Remove or Cap List.")
  end)

  local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  refreshBtn:SetWidth(120)
  refreshBtn:SetHeight(20)
  refreshBtn:SetPoint("LEFT", removeBtn, "RIGHT", 8, 0)
  refreshBtn:SetText("Refresh Active")
  refreshBtn:SetScript("OnClick", function()
    ScanActiveBuffs()
    selectedActiveIndex = nil
    UI_RefreshActiveList()
  end)

  -- Footer help
  local help = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 18)
  help:SetText("Tip: Click an Active Buff to fill ID/Name. Add Always = instant purge. Add Cap List = removed only when buffs exceed max.")

  local LIST_BOTTOM_PAD = 44
  local panelW = 190
  local rowH = 22
  local CAP_BUTTON_PAD = 26  -- reserved space under cap list for Up/Down buttons

  -- Titles
  local leftTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  leftTitle:SetPoint("TOPLEFT", addAlwaysBtn, "BOTTOMLEFT", 0, -16)
  leftTitle:SetText("Always Remove")

  local midTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  midTitle:SetPoint("TOPLEFT", addAlwaysBtn, "BOTTOMLEFT", 204, -16)
  midTitle:SetText("Remove at Buff Cap (priority)")

  local rightTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  rightTitle:SetPoint("TOPLEFT", addAlwaysBtn, "BOTTOMLEFT", 408, -16)
  rightTitle:SetText("Active Buffs (click to fill fields)")

  -- Boxes
  local function MakeBox(x, titleFS, bottomPad)
  local box = CreateFrame("Frame", nil, f)
  box:SetWidth(panelW)
  box:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -6)
  box:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, bottomPad or LIST_BOTTOM_PAD)
  box:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  box:SetBackdropColor(0,0,0,0.8)
  return box
end


  local leftBox  = MakeBox(16,  leftTitle)
  local midBox   = MakeBox(220, midTitle, LIST_BOTTOM_PAD + CAP_BUTTON_PAD)
  local rightBox = MakeBox(424, rightTitle)


  -- Cap priority buttons (below mid box top edge, but inside frame, not overlapping scroll)
  local upBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  upBtn:SetWidth(70)
  upBtn:SetHeight(18)
  upBtn:ClearAllPoints()
  upBtn:SetPoint("TOP", midBox, "BOTTOM", -42, -6)
  upBtn:SetText("Up")
  upBtn:SetScript("OnClick", function()
    EnsureDB()
    if not selectedCapIndex or selectedCapIndex <= 1 then return end
    local i = selectedCapIndex
    BuzzKillDB.nearCap[i], BuzzKillDB.nearCap[i-1] = BuzzKillDB.nearCap[i-1], BuzzKillDB.nearCap[i]
    selectedCapIndex = i - 1
    BuildMaps()
    UI_RefreshCapList()
  end)

  local downBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  downBtn:SetWidth(70)
  downBtn:SetHeight(18)
  downBtn:ClearAllPoints()
  downBtn:SetPoint("LEFT", upBtn, "RIGHT", 8, 0)
  downBtn:SetText("Down")
  downBtn:SetScript("OnClick", function()
    EnsureDB()
    if not selectedCapIndex then return end
    local n = table.getn(BuzzKillDB.nearCap)
    if selectedCapIndex >= n then return end
    local i = selectedCapIndex
    BuzzKillDB.nearCap[i], BuzzKillDB.nearCap[i+1] = BuzzKillDB.nearCap[i+1], BuzzKillDB.nearCap[i]
    selectedCapIndex = i + 1
    BuildMaps()
    UI_RefreshCapList()
  end)

  -- Scroll settings
  f.rowH = rowH
  f.alwaysVisible = 10
  f.capVisible = 9
  f.activeVisible = 10

  -- Always list scroll + rows
  local alwaysScroll = CreateFrame("ScrollFrame", "BuzzKillAlwaysScroll", leftBox, "FauxScrollFrameTemplate")
  alwaysScroll:SetPoint("TOPLEFT", leftBox, "TOPLEFT", 8, -8)
  alwaysScroll:SetPoint("BOTTOMRIGHT", leftBox, "BOTTOMRIGHT", -8, 8)
  f.alwaysScroll = alwaysScroll

  f.alwaysRows = {}
  for i = 1, f.alwaysVisible do
    local row = CreateRow(leftBox, panelW - 36, rowH)
    row:SetPoint("TOPLEFT", leftBox, "TOPLEFT", 8, -8 - (i-1)*rowH)
    f.alwaysRows[i] = row
  end

  alwaysScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, rowH, UI_RefreshAlwaysList)
  end)

  -- Cap list scroll + rows
  local capScroll = CreateFrame("ScrollFrame", "BuzzKillCapScroll", midBox, "FauxScrollFrameTemplate")
  capScroll:SetPoint("TOPLEFT", midBox, "TOPLEFT", 8, -8)
  capScroll:SetPoint("BOTTOMRIGHT", midBox, "BOTTOMRIGHT", -8, 8)
  f.capScroll = capScroll

  f.capRows = {}
  for i = 1, f.capVisible do
    local row = CreateRow(midBox, panelW - 36, rowH)
    row:SetPoint("TOPLEFT", midBox, "TOPLEFT", 8, -8 - (i-1)*rowH)
    f.capRows[i] = row
  end

  capScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, rowH, UI_RefreshCapList)
  end)

  -- Active list scroll + rows
  local activeScroll = CreateFrame("ScrollFrame", "BuzzKillActiveScroll", rightBox, "FauxScrollFrameTemplate")
  activeScroll:SetPoint("TOPLEFT", rightBox, "TOPLEFT", 8, -8)
  activeScroll:SetPoint("BOTTOMRIGHT", rightBox, "BOTTOMRIGHT", -8, 8)
  f.activeScroll = activeScroll

  f.activeRows = {}
  for i = 1, f.activeVisible do
    local row = CreateRow(rightBox, panelW - 36, rowH)
    row:SetPoint("TOPLEFT", rightBox, "TOPLEFT", 8, -8 - (i-1)*rowH)
    f.activeRows[i] = row
  end

  activeScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, rowH, UI_RefreshActiveList)
  end)

  f:Hide()
end

local function UI_Show()
  UI_Build()
  InitOnce()
  EnsureDB()

  BK_UI.debugCheck:SetChecked(debugEnabled and 1 or 0)

  ScanActiveBuffs()
  selectedAlwaysIndex = nil
  selectedCapIndex = nil
  selectedActiveIndex = nil
  BK_UI._pendingIcon = nil

  UI_RefreshAlwaysList()
  UI_RefreshCapList()
  UI_RefreshActiveList()
  BK_UI:Show()
end

local function UI_Toggle()
  UI_Build()
  if BK_UI:IsShown() then BK_UI:Hide() else UI_Show() end
end

-- ------------------------------------------------------------
-- Slash command: /buzzkill
-- ------------------------------------------------------------

SLASH_BUZZKILL1 = "/buzzkill"
SlashCmdList["BUZZKILL"] = function(msg)
  msg = msg or ""
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")

  if msg == "" then
    UI_Toggle()
    return
  end

  local _, _, cmd, rest = string.find(msg, "^(%S+)%s*(.*)$")
  cmd = cmd and string.lower(cmd) or ""
  rest = rest or ""

  InitOnce()

  if cmd == "ui" then
    UI_Toggle()
    return

  elseif cmd == "debug" then
    EnsureDB()
    BuzzKillDB.debug = not BuzzKillDB.debug
    debugEnabled = (BuzzKillDB.debug == true)
    BK_Print("Debug is now " .. (debugEnabled and "ON" or "OFF"))
    return

  elseif cmd == "max" then
    local n = tonumber(rest)
    if not n or n < 1 or n > 63 then
      BK_Print("Usage: /buzzkill max <1-63> (default 31)")
      return
    end
    EnsureDB()
    BuzzKillDB.maxBuffs = n
    BK_Print("Max buffs set to " .. n)
    return

  elseif cmd == "add" then
    local _, _, idStr, name = string.find(rest, "^(%d+)%s*(.*)$")
    local id = idStr and tonumber(idStr) or nil
    if not id then BK_Print("Usage: /buzzkill add <id> [name]") return end
    if not name or name == "" then name = nil end
    AddToAlways(id, name, nil)
    return

  elseif cmd == "addcap" then
    local _, _, idStr, name = string.find(rest, "^(%d+)%s*(.*)$")
    local id = idStr and tonumber(idStr) or nil
    if not id then BK_Print("Usage: /buzzkill addcap <id> [name]") return end
    if not name or name == "" then name = nil end
    AddToCap(id, name, nil)
    return

  elseif cmd == "list" then
    EnsureDB()
    BK_Print("Always Remove list:")
    for _, e in ipairs(BuzzKillDB.list) do
      if e and e.id then BK_Print("  " .. e.id .. " - " .. (e.name or ("BuffID " .. e.id))) end
    end
    return

  elseif cmd == "listcap" then
    EnsureDB()
    BK_Print("Remove at Buff Cap list (priority order):")
    for _, e in ipairs(BuzzKillDB.nearCap) do
      if e and e.id then BK_Print("  " .. e.id .. " - " .. (e.name or ("BuffID " .. e.id))) end
    end
    return
  end

  BK_Print("Commands:")
  BK_Print("  /buzzkill            (toggle UI)")
  BK_Print("  /buzzkill ui")
  BK_Print("  /buzzkill add <id> [name]")
  BK_Print("  /buzzkill addcap <id> [name]")
  BK_Print("  /buzzkill list")
  BK_Print("  /buzzkill listcap")
  BK_Print("  /buzzkill max <n>    (default 31)")
  BK_Print("  /buzzkill debug")
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_AURAS_CHANGED")

f:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    InitOnce()
    if arg1 == ADDON_NAME then
      BK_Print("Loaded. Use /buzzkill")
    end
    return
  end

  if event == "PLAYER_AURAS_CHANGED" then
    InitOnce()

    -- Prune behavior: Always first, then cap-trim :contentReference[oaicite:5]{index=5}
    if RemoveAlways() then return end
    RemoveForCap()

    if BK_UI and BK_UI:IsShown() then
      ScanActiveBuffs()
      UI_RefreshActiveList()
    end
    return
  end
end)
