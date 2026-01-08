-- BuzzKill.lua (Turtle WoW / 1.12 style)
-- Always-remove only, with a small UI to add/remove buffs.

local ADDON_NAME = "BuzzKill"

-- SavedVariablesPerCharacter (or SavedVariables if you changed the .toc)
BuzzKillDB = BuzzKillDB or nil

local debugEnabled = false
local AlwaysRemoveMap = {}     -- [buffID] = displayName

-- UI state
local BK_UI = nil
local selectedAlwaysIndex = nil
local selectedActiveIndex = nil
local ActiveBuffs = {}         -- array of { slot, id, name, icon }

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
  if type(BuzzKillDB.list) ~= "table" then BuzzKillDB.list = {} end
  if BuzzKillDB.debug == nil then BuzzKillDB.debug = false end
  debugEnabled = (BuzzKillDB.debug == true)
end

local function BuildMap()
  AlwaysRemoveMap = {}
  if not BuzzKillDB or not BuzzKillDB.list then return end
  for _, entry in ipairs(BuzzKillDB.list) do
    if entry and entry.id then
      AlwaysRemoveMap[entry.id] = entry.name or ("BuffID " .. tostring(entry.id))
    end
  end
end

local initialized = false
local function InitOnce()
  if initialized then return end
  EnsureDB()
  BuildMap()
  initialized = true
end

local function AddBuffID(id, name, icon)
  if not id or id <= 0 then
    BK_Print("Add failed: invalid id.")
    return
  end
  EnsureDB()

  -- de-dupe / update
  for _, entry in ipairs(BuzzKillDB.list) do
    if entry and entry.id == id then
      if name and name ~= "" then entry.name = name end
      if icon and icon ~= "" then entry.icon = icon end
      BuildMap()
      BK_Print("Updated: " .. id .. " -> " .. (AlwaysRemoveMap[id] or tostring(id)))
      return
    end
  end

  table.insert(BuzzKillDB.list, {
    id   = id,
    name = (name and name ~= "" and name) or ("BuffID " .. tostring(id)),
    icon = icon
  })
  BuildMap()
  BK_Print("Added: " .. id .. " -> " .. (AlwaysRemoveMap[id] or tostring(id)))
end

local function DelBuffIndex(index)
  EnsureDB()
  if not index or not BuzzKillDB.list[index] then return end
  local id = BuzzKillDB.list[index].id
  table.remove(BuzzKillDB.list, index)
  BuildMap()
  BK_Print("Deleted: " .. tostring(id))
end

local function ListBuffIDs()
  EnsureDB()
  if table.getn(BuzzKillDB.list) == 0 then
    BK_Print("List is empty.")
    return
  end
  BK_Print("Always-remove list:")
  for _, entry in ipairs(BuzzKillDB.list) do
    if entry and entry.id then
      BK_Print("  " .. entry.id .. " - " .. (entry.name or ("BuffID " .. tostring(entry.id))))
    end
  end
end

-- ------------------------------------------------------------
-- Core logic: remove the first matching buff found (one per aura change)
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- UI: tooltip-based buff name retrieval for active buffs
-- ------------------------------------------------------------

local BK_Tip = nil

local function EnsureTooltip()
  if BK_Tip then return end
  BK_Tip = CreateFrame("GameTooltip", "BuzzKillTooltip", UIParent, "GameTooltipTemplate")
  BK_Tip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function GetBuffNameFromSlot(slot)
  EnsureTooltip()

  -- Turtle/Vanilla generally supports this call; if not, we fall back to "BuffID X"
  if BK_Tip.SetPlayerBuff then
    BK_Tip:ClearLines()
    BK_Tip:SetOwner(UIParent, "ANCHOR_NONE")
    BK_Tip:SetPlayerBuff(slot)
    local left1 = getglobal("BuzzKillTooltipTextLeft1")
    if left1 and left1.GetText then
      local text = left1:GetText()
      if text and text ~= "" then
        return text
      end
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
      local icon = entry.icon
      if icon and icon ~= "" then
        row.icon:SetTexture(icon)
        row.icon:Show()
      else
        row.icon:Hide()
      end

      local nm = entry.name or ("BuffID " .. tostring(entry.id))
      row.text:SetText(string.format("%s  |cffaaaaaa(%d)|r", nm, entry.id))

      if selectedAlwaysIndex == idx then
        row.highlight:Show()
      else
        row.highlight:Hide()
      end

      row:SetScript("OnClick", function()
        selectedAlwaysIndex = idx
        selectedActiveIndex = nil
        UI_RefreshAlwaysList()
        -- clear active selection highlights
        if BK_UI then UI_RefreshActiveList() end
      end)
    else
      row:Hide()
    end
  end

  FauxScrollFrame_Update(BK_UI.alwaysScroll, total, visible, BK_UI.rowH)
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
        row.icon:SetTexture(entry.icon)
        row.icon:Show()
      else
        row.icon:Hide()
      end

      row.text:SetText(string.format("%s  |cffaaaaaa(%d)|r", entry.name or "Unknown", entry.id))

      if selectedActiveIndex == idx then
        row.highlight:Show()
      else
        row.highlight:Hide()
      end

      row:SetScript("OnClick", function()
        selectedActiveIndex = idx
        selectedAlwaysIndex = nil

        -- fill inputs from active buff
        if BK_UI.idBox then BK_UI.idBox:SetText(tostring(entry.id)) end
        if BK_UI.nameBox then BK_UI.nameBox:SetText(entry.name or "") end
        BK_UI._pendingIcon = entry.icon

        UI_RefreshActiveList()
        UI_RefreshAlwaysList()
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
  f:SetWidth(420)
  f:SetHeight(460)
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

  -- Close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  -- Title
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  title:SetText("BuzzKill")

  local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetText("v1.1 TheoIX.")

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

  -- Input area
  local idLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  idLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -86)
  idLabel:SetText("Buff ID:")

  local idBox = CreateFrame("EditBox", "BuzzKillIDBox", f, "InputBoxTemplate")
  idBox:SetAutoFocus(false)
  idBox:SetWidth(80)
  idBox:SetHeight(18)
  idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
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


  local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  addBtn:SetWidth(70)
  addBtn:SetHeight(20)
  addBtn:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -10)
  addBtn:SetText("Add")
  addBtn:SetScript("OnClick", function()
    local id = tonumber(f.idBox:GetText() or "")
    if not id then
      BK_Print("Enter a valid Buff ID.")
      return
    end
    local nm = f.nameBox:GetText() or ""
    local icon = f._pendingIcon
    AddBuffID(id, nm, icon)
    selectedAlwaysIndex = nil
    UI_RefreshAlwaysList()
  end)

  local delBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  delBtn:SetWidth(120)
  delBtn:SetHeight(20)
  delBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
  delBtn:SetText("Remove Selected")
  delBtn:SetScript("OnClick", function()
    if not selectedAlwaysIndex then
      BK_Print("Select an entry in the Always Remove list.")
      return
    end
    DelBuffIndex(selectedAlwaysIndex)
    selectedAlwaysIndex = nil
    UI_RefreshAlwaysList()
  end)

  local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  refreshBtn:SetWidth(120)
  refreshBtn:SetHeight(20)
  refreshBtn:SetPoint("LEFT", delBtn, "RIGHT", 8, 0)
  refreshBtn:SetText("Refresh Active")
  refreshBtn:SetScript("OnClick", function()
    ScanActiveBuffs()
    selectedActiveIndex = nil
    UI_RefreshActiveList()
  end)

  -- Two panels: Always list (left), Active buffs (right)
    -- Footer help (create first so we can reserve space)
  local help = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 18)
  help:SetText("Tip: Click an Active Buff to auto-fill ID/Name, then press Add.")

  local LIST_BOTTOM_PAD = 44 -- space reserved for the tip line

  -- Two panels: Always list (left), Active buffs (right)
  local panelW = 190
  local panelH = 280

  local leftTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  leftTitle:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -16)
  leftTitle:SetText("Always Remove")

  local rightTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  rightTitle:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -16)
  rightTitle:SetText("Active Buffs (click to fill fields)")

  -- Left list container
  local leftBox = CreateFrame("Frame", nil, f)
  leftBox:SetWidth(panelW)
  leftBox:SetPoint("TOPLEFT", leftTitle, "BOTTOMLEFT", 0, -6)
  leftBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, LIST_BOTTOM_PAD)
  leftBox:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  leftBox:SetBackdropColor(0,0,0,0.8)

  -- Right list container
  local rightBox = CreateFrame("Frame", nil, f)
  rightBox:SetWidth(panelW)
  rightBox:SetPoint("TOPLEFT", rightTitle, "BOTTOMLEFT", 0, -6)
  rightBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 220, LIST_BOTTOM_PAD)
  rightBox:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  rightBox:SetBackdropColor(0,0,0,0.8)

  -- Scroll settings
  f.rowH = 22
  f.alwaysVisible = 10
  f.activeVisible = 10

  -- Left scroll + rows
  local alwaysScroll = CreateFrame("ScrollFrame", "BuzzKillAlwaysScroll", leftBox, "FauxScrollFrameTemplate")
  alwaysScroll:SetPoint("TOPLEFT", leftBox, "TOPLEFT", 8, -8)
  alwaysScroll:SetPoint("BOTTOMRIGHT", leftBox, "BOTTOMRIGHT", -28, 8)
  f.alwaysScroll = alwaysScroll

  f.alwaysRows = {}
  for i = 1, f.alwaysVisible do
    local row = CreateRow(leftBox, panelW - 36, f.rowH)
    row:SetPoint("TOPLEFT", leftBox, "TOPLEFT", 8, -8 - (i-1)*f.rowH)
    f.alwaysRows[i] = row
  end

  -- IMPORTANT: Turtle expects (scrollFrame, offset, rowHeight, updateFunc)
  alwaysScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, f.rowH, UI_RefreshAlwaysList)
  end)

  -- Right scroll + rows
  local activeScroll = CreateFrame("ScrollFrame", "BuzzKillActiveScroll", rightBox, "FauxScrollFrameTemplate")
  activeScroll:SetPoint("TOPLEFT", rightBox, "TOPLEFT", 8, -8)
  activeScroll:SetPoint("BOTTOMRIGHT", rightBox, "BOTTOMRIGHT", -28, 8)
  f.activeScroll = activeScroll

  f.activeRows = {}
  for i = 1, f.activeVisible do
    local row = CreateRow(rightBox, panelW - 36, f.rowH)
    row:SetPoint("TOPLEFT", rightBox, "TOPLEFT", 8, -8 - (i-1)*f.rowH)
    f.activeRows[i] = row
  end

  activeScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, f.rowH, UI_RefreshActiveList)
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
  selectedActiveIndex = nil
  BK_UI._pendingIcon = nil

  UI_RefreshAlwaysList()
  UI_RefreshActiveList()
  BK_UI:Show()
end

local function UI_Toggle()
  UI_Build()
  if BK_UI:IsShown() then
    BK_UI:Hide()
  else
    UI_Show()
  end
end

-- ------------------------------------------------------------
-- Slash command: /buzzkill
-- - no args: toggle UI
-- - /buzzkill add <id> [name...]
-- - /buzzkill del <id>
-- - /buzzkill list
-- - /buzzkill debug
-- - /buzzkill ui
-- ------------------------------------------------------------

SLASH_BUZZKILL1 = "/buzzkill"
SlashCmdList["BUZZKILL"] = function(msg)
  msg = msg or ""
  if msg == "" then
    UI_Toggle()
    return
  end

  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd and string.lower(cmd) or ""

  if cmd == "ui" then
    UI_Toggle()
    return

  elseif cmd == "add" then
    local idStr, name = rest:match("^(%d+)%s*(.-)$")
    local id = idStr and tonumber(idStr) or nil
    if not id then
      BK_Print("Usage: /buzzkill add <id> [name]")
      return
    end
    if name == "" then name = nil end
    AddBuffID(id, name, nil)
    return

  elseif cmd == "del" or cmd == "rem" or cmd == "remove" then
    local id = tonumber(rest)
    if not id then
      BK_Print("Usage: /buzzkill del <id>")
      return
    end
    EnsureDB()
    for i, entry in ipairs(BuzzKillDB.list) do
      if entry and entry.id == id then
        DelBuffIndex(i)
        return
      end
    end
    BK_Print("Not found: " .. tostring(id))
    return

  elseif cmd == "list" then
    ListBuffIDs()
    return

  elseif cmd == "debug" then
    EnsureDB()
    BuzzKillDB.debug = not BuzzKillDB.debug
    debugEnabled = BuzzKillDB.debug
    BK_Print("Debug is now " .. (debugEnabled and "ON" or "OFF"))
    return
  end

  BK_Print("Commands:")
  BK_Print("  /buzzkill           (toggle UI)")
  BK_Print("  /buzzkill ui")
  BK_Print("  /buzzkill add <id> [name]")
  BK_Print("  /buzzkill del <id>")
  BK_Print("  /buzzkill list")
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
    -- Don't rely on folder name matching; just init once.
    InitOnce()

    -- Optional: only print the "Loaded" message when it’s actually our addon.
    if arg1 == ADDON_NAME then
      BK_Print("Loaded. Use /buzzkill to open UI.")
    end
    return
  end

  if event == "PLAYER_AURAS_CHANGED" then
    InitOnce()
    RemoveAlways()

    -- keep active list somewhat fresh while UI is open
    if BK_UI and BK_UI:IsShown() then
      ScanActiveBuffs()
      UI_RefreshActiveList()
    end
    return
  end
end)

