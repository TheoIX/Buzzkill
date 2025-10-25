--=========================
-- AutoBuffRemover (ABR) for WoW 1.12
--=========================

-- Tooltip for buff names (WoW 1.12 trick)
local ABR_Tooltip = CreateFrame("GameTooltip", "ABR_TempTooltip", nil, "GameTooltipTemplate")
ABR_Tooltip:SetOwner(UIParent, "ANCHOR_NONE")

ABR_BuffsList = ABR_BuffsList or {}
ABR_Profiles = ABR_Profiles or {}
ABR_ActiveProfileName = ABR_ActiveProfileName or "Standard"

local function ABR_ShallowCopy(src)
    local t = {}
    if src then for k,v in pairs(src) do t[k]=v end end
    return t
end

local function ABR_CopyInto(src, dst)
    -- Clear destination and refill
    for k in pairs(dst) do dst[k]=nil end
    if src then for k,v in pairs(src) do dst[k]=v end end
end

-- Replaces the earlier ABR_HookScript version (without "...")
local function ABR_HookScript(frame, script, handler)
    local prev = frame:GetScript(script)
    if prev then
        frame:SetScript(script, function()
            prev()      -- call previous script handler (no args needed)
            handler()   -- then our handler
        end)
    else
        frame:SetScript(script, handler)
    end
end

function ABR_GetBuffName(index)
    ABR_Tooltip:ClearLines()
	local x = UnitBuff("player", index + 1)
		if x then
			ABR_Tooltip:SetPlayerBuff(index)
			local name = getglobal("ABR_TempTooltipTextLeft1"):GetText()
			return name
		end
end

function ABR_RemoveBuffByIndex(index)
    local buffName = ABR_GetBuffName(index)
    if buffName then
        CancelPlayerBuff(index)
        print("ABR: Removed Buff - " .. buffName)
    end
end

--=========================
-- Create frame
--=========================
local ABR_Frame = CreateFrame("Frame", "ABR_BuffOptionsFrame", UIParent)
ABR_Frame:SetWidth(400)
ABR_Frame:SetHeight(500)
ABR_Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ABR_Frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
ABR_Frame:SetBackdropColor(0,0,0,1)
ABR_Frame:Hide() -- initially hidden

-- ScrollFrame
local ABR_Scroll = CreateFrame("ScrollFrame", "ABR_BuffScrollFrame", ABR_Frame, "UIPanelScrollFrameTemplate")
ABR_Scroll:SetPoint("TOPLEFT", ABR_Frame, "TOPLEFT", 10, -20)
ABR_Scroll:SetWidth(380)
ABR_Scroll:SetHeight(470)

local ABR_Content = CreateFrame("Frame", nil, ABR_Scroll)
ABR_Content:SetWidth(380)
ABR_Content:SetHeight(470)
ABR_Scroll:SetScrollChild(ABR_Content)

-- Title
local ABR_Title = ABR_Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ABR_Title:SetPoint("TOP", ABR_Content, "TOP", 0, -4)
ABR_Title:SetText("BuzzKill")

-- =========================
-- Profile UI (Lua 5.0 / 1.12)
-- =========================

-- Label
local ABR_ProfileLabel = ABR_Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ABR_ProfileLabel:SetPoint("TOPLEFT", ABR_Content, "TOPLEFT", 10, -24)
ABR_ProfileLabel:SetText("Profile")

-- EditBox (profile name)
local ABR_ProfileEdit = CreateFrame("EditBox", "ABR_ProfileEditBox", ABR_Content, "InputBoxTemplate")
ABR_ProfileEdit:SetPoint("TOPLEFT", ABR_ProfileLabel, "BOTTOMLEFT", 0, -2)
ABR_ProfileEdit:SetWidth(130)
ABR_ProfileEdit:SetHeight(20)
ABR_ProfileEdit:SetAutoFocus(false)
ABR_ProfileEdit:SetMaxLetters(48)
ABR_ProfileEdit:SetScript("OnEnterPressed", function()
    ABR_SaveProfile(ABR_ProfileEdit:GetText())
    ABR_ProfileEdit:ClearFocus()
end)
ABR_ProfileEdit:SetScript("OnEscapePressed", function()
    ABR_ProfileEdit:ClearFocus()
end)

-- Dropdown button (simple custom)
local ABR_ProfileDDButton = CreateFrame("Button", "ABR_ProfileDDButton", ABR_Content, "UIPanelButtonTemplate")
ABR_ProfileDDButton:SetPoint("LEFT", ABR_ProfileEdit, "RIGHT", 12, 0)
ABR_ProfileDDButton:SetWidth(100)
ABR_ProfileDDButton:SetHeight(22)
ABR_ProfileDDButton:SetText("Standard")

-- Drop-down list panel below the button
local ABR_ProfileDDList = CreateFrame("Frame", "ABR_ProfileDDList", ABR_Content)
ABR_ProfileDDList:SetPoint("TOPLEFT", ABR_ProfileDDButton, "BOTTOMLEFT", 0, -2)
ABR_ProfileDDList:SetWidth(150)
ABR_ProfileDDList:SetHeight(1)
ABR_ProfileDDList:Hide()
ABR_ProfileDDList:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
ABR_ProfileDDList:SetBackdropColor(0, 0, 0, 0.9)

-- Pool of entry buttons
local ABR_DDItems = {}
local ABR_SelectedProfileName

local function ABR_Dropdown_Hide() ABR_ProfileDDList:Hide() end

local function ABR_Dropdown_Show()
    local names, n = {}, 0
    for k in pairs(ABR_Profiles) do n=n+1; names[n]=k end
    table.sort(names)

    for i=1, table.getn(ABR_DDItems) do ABR_DDItems[i]:Hide() end

    local itemHeight, topPad, gap = 18, 6, 2
    local totalH = topPad

    for i=1, n do
        local name = names[i]
        local btn = ABR_DDItems[i]
        if not btn then
            btn = CreateFrame("Button", nil, ABR_ProfileDDList)
            ABR_DDItems[i] = btn
            btn:SetHeight(itemHeight)
            btn:SetWidth(142)
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            btn:GetHighlightTexture():SetAlpha(0.25)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
            btn:SetScript("OnEnter", function() this.text:SetTextColor(1,1,0) end)
			btn:SetScript("OnLeave", function() this.text:SetTextColor(1,1,1) end)
        end
        if not btn.text then
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ABR_ProfileDDList, "TOPLEFT", 4, -(topPad + (i-1)*(itemHeight+gap)))
        btn.text:SetText(name)
        btn.text:SetTextColor(1,1,1)

        btn:SetScript("OnClick", function()
            ABR_SelectedProfileName = name
            ABR_ProfileDDButton:SetText(name)
            ABR_Dropdown_Hide()
        end)

        btn:Show()
        totalH = topPad + i*(itemHeight+gap)
    end

    ABR_ProfileDDList:SetHeight(totalH + 6)
    ABR_ProfileDDList:Show()
end

ABR_ProfileDDButton:SetScript("OnClick", function()
    if ABR_ProfileDDList:IsShown() then ABR_Dropdown_Hide() else ABR_Dropdown_Show() end
end)

-- No :HookScript in 1.12
local function ABR_HookScript(frame, script, handler)
    local prev = frame:GetScript(script)
    if prev then
        frame:SetScript(script, function() prev(); handler(); end)
    else
        frame:SetScript(script, handler)
    end
end
ABR_HookScript(ABR_Content, "OnHide", ABR_Dropdown_Hide)

-- Buttons: Save / Activate / Delete (relative to the dropdown button!)
local ABR_SaveBtn = CreateFrame("Button", nil, ABR_Content, "UIPanelButtonTemplate")
ABR_SaveBtn:SetPoint("LEFT", ABR_ProfileDDButton, "RIGHT", 8, 25)
ABR_SaveBtn:SetWidth(80); ABR_SaveBtn:SetHeight(22)
ABR_SaveBtn:SetText("Speichern")
ABR_SaveBtn:SetScript("OnClick", function()
    ABR_SaveProfile(ABR_ProfileEdit:GetText())
end)

local ABR_ActivateBtn = CreateFrame("Button", nil, ABR_Content, "UIPanelButtonTemplate")
ABR_ActivateBtn:SetPoint("LEFT", ABR_SaveBtn, "BOTTOMLEFT", 0, -13)
ABR_ActivateBtn:SetWidth(80); ABR_ActivateBtn:SetHeight(22)
ABR_ActivateBtn:SetText("Aktivieren")
ABR_ActivateBtn:SetScript("OnClick", function()
    ABR_ActivateProfile(ABR_SelectedProfileName or ABR_ActiveProfileName)
end)

local ABR_DeleteBtn = CreateFrame("Button", nil, ABR_Content, "UIPanelButtonTemplate")
ABR_DeleteBtn:SetPoint("LEFT", ABR_ActivateBtn, "BOTTOMLEFT", 0, -13)
ABR_DeleteBtn:SetWidth(80); ABR_DeleteBtn:SetHeight(22)
ABR_DeleteBtn:SetText("Löschen")
ABR_DeleteBtn:SetScript("OnClick", function()
    local name = ABR_SelectedProfileName or ABR_ProfileEdit:GetText()
    ABR_DeleteProfile(name)
end)

-- Refresh function
function ABR_ProfileUI_Refresh()
    if not ABR_Profiles["Standard"] then ABR_Profiles["Standard"] = {} end
    ABR_SelectedProfileName = ABR_SelectedProfileName or ABR_ActiveProfileName or "Standard"
    ABR_ProfileDDButton:SetText(ABR_SelectedProfileName)
    if ABR_ProfileDDList:IsShown() then ABR_Dropdown_Show() end
end


-- Close Button
local ABR_Close = CreateFrame("Button", nil, ABR_Frame, "UIPanelCloseButton")
ABR_Close:SetPoint("TOPRIGHT", ABR_Frame, "TOPRIGHT", -5, -5)

ABR_Frame:EnableMouse(true)
ABR_Frame:SetMovable(true)
ABR_Frame:RegisterForDrag("LeftButton")
ABR_Frame:SetClampedToScreen(true)          -- do not allow dragging off-screen

ABR_Frame:SetScript("OnDragStart", function()
    if ABR_Frame:IsMovable() then ABR_Frame:StartMoving() end
end)
ABR_Frame:SetScript("OnDragStop", function()
    ABR_Frame:StopMovingOrSizing()
end)



-- Helper function already exists: ABR_ShallowCopy(src)

function ABR_SaveProfile(name)
    -- Trim name (Lua 5.0)
    if name then name = string.gsub(name, "^%s*(.-)%s*$", "%1") end

    if not name or name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8080ABR: Profilname fehlt.|r")
        return
    end

    if name == "Standard" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8080ABR: Das Profil 'Standard' kann nicht überschrieben werden.|r")
        return
    end

    if not ABR_Profiles["Standard"] then ABR_Profiles["Standard"] = {} end

    ABR_Profiles[name] = ABR_ShallowCopy(ABR_BuffsList)
    ABR_SelectedProfileName = name
    if ABR_ProfileUI_Refresh then ABR_ProfileUI_Refresh() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff80ff80ABR: Profil gespeichert:|r "..name)
end

function ABR_ActivateProfile(name)
    if not name or not ABR_Profiles[name] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8080ABR: Profil existiert nicht.|r")
        return
    end
    ABR_ActiveProfileName = name
    ABR_BuffsList = ABR_ShallowCopy(ABR_Profiles[name])
    if ABR_RestoreChecks then ABR_RestoreChecks() end
    ABR_SelectedProfileName = name
    if ABR_ProfileUI_Refresh then ABR_ProfileUI_Refresh() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff80ff80ABR: Profil aktiviert:|r "..name)
end

function ABR_DeleteProfile(name)
    if not name or not ABR_Profiles[name] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8080ABR: Profil nicht gefunden.|r")
        return
    end

    if name == "Standard" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8080ABR: Das Profil 'Standard' kann nicht gelöscht werden.|r")
        return
    end

    if ABR_ActiveProfileName == name then
        ABR_ActiveProfileName = "Standard"
        ABR_BuffsList = ABR_ShallowCopy(ABR_Profiles["Standard"])
        if ABR_RestoreChecks then ABR_RestoreChecks() end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00ABR: Aktives Profil gelöscht → 'Standard' aktiviert.|r")
    end

    ABR_Profiles[name] = nil
    ABR_SelectedProfileName = ABR_ActiveProfileName or "Standard"
    if ABR_ProfileUI_Refresh then ABR_ProfileUI_Refresh() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff80ff80ABR: Profil gelöscht:|r "..name)
end





--=========================
-- Buffs & checkboxes
--=========================
local ABR_Buffs = {
    Scrolls = {"Agility", "Intellect", "Protection", "Spirit", "Stamina", "Strength"},
    Paladin = {"Blessing of Salvation", "Greater Blessing of Salvation", "Blessing of Wisdom", "Greater Blessing of Wisdom", "Blessing of Might", "Greater Blessing of Might", "Blessing of Kings", "Greater Blessing of Kings", "Blessing of Light", "Greater Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Sanctuary", "Daybreak", "Holy Power", "Heathen's Light"},
    Priest = {"Power Word: Fortitude", "Prayer of Fortitude", "Shadow Protection", "Prayer of Shadow Protection", "Divine Spirit", "Prayer of Spirit", "Renew", "Inspiration"},
    Warlock = {"Detect Invisibility", "Detect Greater Invisibility", "Detect Lesser Invisibility", "Unending Breath"},
    Mage = {"Arcane Intellect", "Arcane Brilliance", "Dampen Magic", "Amplify Magic"},
    Druid = {"Mark of the Wild", "Gift of the Wild", "Thorns", "Rejuvenation", "Regrowth", "Blessing of the Claw"},
    Warrior = {"Battle Shout"},
    Shaman = {"Spirit Link", "Healing Way", "Ancestral Fortitude", "Water Walking", "Water Breathing", "Totemic Power"}
}

-- ---- Layout constants ----
local HEADER_TO_FIRST_CHECKBOX_GAP = 8   -- bring header closer to the first checkbox
local CHECKBOX_ROW_GAP             = -10   -- tighter spacing between checkbox rows
local CATEGORY_TOP_MARGIN          = 6   -- less space above the header
local CATEGORY_BOTTOM_MARGIN       = 6   -- less space below the category
local LEFT_INSET_HEADER            = 10
local LEFT_INSET_CHECKBOX          = 20
local COLUMN2_X                    = 200 -- second column x




--=========================
-- Buffs & checkboxes
--=========================
local yOffset = -70  -- start below the title

for category, buffList in pairs(ABR_Buffs) do
    -- Header
    local categoryHeader = ABR_Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    categoryHeader:SetPoint("TOPLEFT", ABR_Content, "TOPLEFT", LEFT_INSET_HEADER, yOffset)
    categoryHeader:SetText(category)

    -- Header -> closer to the first checkbox
    yOffset = yOffset - HEADER_TO_FIRST_CHECKBOX_GAP

    -- Column offsets start at the same height
    local column1YOffset = yOffset
    local column2YOffset = yOffset

    -- Checkboxes (2 columns)
    for i, buffName in ipairs(buffList) do
        local buff = buffName
        local checkButton = CreateFrame("CheckButton", nil, ABR_Content, "UICheckButtonTemplate")

        -- Label
        checkButton.text = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        checkButton.text:SetPoint("LEFT", checkButton, "RIGHT", 5, 0)
        checkButton.text:SetText(buff)

        -- Position within columns
        if mod(i, 2) == 1 then
            checkButton:SetPoint("TOPLEFT", ABR_Content, "TOPLEFT", LEFT_INSET_CHECKBOX, column1YOffset)
            column1YOffset = column1YOffset - (checkButton:GetHeight() + CHECKBOX_ROW_GAP)
        else
            checkButton:SetPoint("TOPLEFT", ABR_Content, "TOPLEFT", COLUMN2_X, column2YOffset)
            column2YOffset = column2YOffset - (checkButton:GetHeight() + CHECKBOX_ROW_GAP)
        end

        -- Click logic
        checkButton:SetScript("OnClick", function()
            ABR_BuffsList[buff] = checkButton:GetChecked() and 1 or nil
            if checkButton:GetChecked() then
                for idx = 1, 40 do
                    local name = ABR_GetBuffName(idx)
                    if name == buff then
                        ABR_RemoveBuffByIndex(idx)
                        break
                    end
                end
            end
        end)
    end

    -- Category closing:
    -- Take the deeper column (more negative y = further down) and add some space below.
    local lowestY = math.min(column1YOffset, column2YOffset)
    yOffset = lowestY - CATEGORY_BOTTOM_MARGIN

    -- Also add a small top margin for the next category
    yOffset = yOffset - CATEGORY_TOP_MARGIN
end

-- Adjust content height (so later categories are not cut off)
-- yOffset is negative; height should be positive:
ABR_Content:SetHeight(math.abs(yOffset) + 20)


--=========================
-- Slash Commands
--=========================
SLASH_BUZZKILL1 = "/buzzkill"
SLASH_BUZZKILL2 = "/bk"
SlashCmdList["BUZZKILL"] = function()
    if ABR_Frame:IsShown() then
        ABR_Frame:Hide()
    else
        ABR_Frame:Show()
    end
end
end

function ABR_RestoreChecks()
    if not ABR_BuffsList then return end

    -- Only handle real CheckButtons; ignore the rest (e.g., profile buttons)
    local children = { ABR_Content:GetChildren() }
    for i = 1, table.getn(children) do
        local child = children[i]
        if child and child.GetObjectType and child:GetObjectType() == "CheckButton" then
            local label = nil
            if child.text and child.text.GetText then
                label = child.text:GetText()
            end

            if label then
                if ABR_BuffsList[label] then
                    child:SetChecked(1)      -- 1/nil instead of true/false (Vanilla)
                else
                    child:SetChecked(nil)
                end
            end
        end
    end
end

-- Throttle against event spam
local ABR_LastScan = 0
local ABR_SCAN_INTERVAL = 0.2  -- seconds

-- Removes all buffs that are marked "active" in ABR_BuffsList
function ABR_ScanAndRemove()
    if not ABR_BuffsList then return end

    -- Important: iterate downwards in case buffs are removed during the loop
    for i = 40, 1, -1 do
        local name = ABR_GetBuffName(i)  -- your tooltip function
        if name and ABR_BuffsList[name] then
            -- Values can be 1/true — any non-nil counts as "on"
            ABR_RemoveBuffByIndex(i)
            -- no break: there may be multiple forbidden buffs active
        end
    end
end



ABR_Frame:RegisterEvent("PLAYER_LOGIN")  -- Alternatively: VARIABLES_LOADED
ABR_Frame:RegisterEvent("PLAYER_AURAS_CHANGED")
ABR_Frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
		if not ABR_BuffsList then ABR_BuffsList = {} end

			-- Profile init + activation
			if not ABR_Profiles["Standard"] then ABR_Profiles["Standard"] = {} end
			if not ABR_Profiles[ABR_ActiveProfileName] then
				ABR_ActiveProfileName = "Standard"
			end
			ABR_BuffsList = ABR_ShallowCopy(ABR_Profiles[ABR_ActiveProfileName])

			ABR_RestoreChecks()
			ABR_ProfileUI_Refresh() 
	elseif event == "PLAYER_AURAS_CHANGED" then
		local now = GetTime()
        if (now - ABR_LastScan) > ABR_SCAN_INTERVAL then
            ABR_LastScan = now
            ABR_ScanAndRemove()
        end
	
	end
end)
