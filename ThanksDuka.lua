-- ThanksDuka WoW Loot Addon
local frame = CreateFrame("Frame", "ThanksDukaFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(400, 500)
frame:SetPoint("CENTER")
frame:Hide()
frame:RegisterForDrag("LeftButton")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

table.insert(UISpecialFrames, "ThanksDukaFrame")

local addonEnabled = true
ThanksDukaDB = ThanksDukaDB or {}
ThanksDukaDB.rollHistory = ThanksDukaDB.rollHistory or {}  -- Store roll history
ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}  -- Store attendance history
local activeRollGlow = nil

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
frame.title:SetText("Thanks Duka - Loot")

local lootItems = {}
local rolls = {}
local lootItemCounts = {}
local rollTimer
local timerBar
local countdownTime = 60  -- Default value

---------------------------------------------------------------------------------------
-- Debugging
---------------------------------------------------------------------------------------
-- Debug Mode Toggle
local DEBUG_MODE = false  -- Set to false for live use

-- Mock Raid Roster for Testing
local testRaidRoster = {
    "TestPlayer1",
    "TestPlayer2",
    "TestPlayer3",
    "TestPlayer4",
    "TestPlayer5",
}

-- Override IsInRaid() and GetRaidRosterInfo() when debugging
if DEBUG_MODE then
    function IsInRaid()
        return true
    end

    function GetRaidRosterInfo(i)
        return testRaidRoster[i] or nil
    end
end

local function PlayerDropdown_Initialize(self, level)
    local players = {}

    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(players, name)
            end
        end
    end

    table.sort(players)

    for _, player in ipairs(players) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = player
        info.func = function()
            UIDropDownMenu_SetSelectedName(self, player)
            ManualAwardFrame.SelectedPlayer = player
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

-- Debug message to confirm mode
if DEBUG_MODE then
    print("[DEBUG] Simulating Raid Group with Fake Players")
end
---------------------------------------------------------------------------------------

-- Get raid difficulty automatically
local function GetRaidDifficulty()
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID == 14 then
        return "Normal"
    elseif difficultyID == 15 then
        return "Heroic"
    elseif difficultyID == 16 then
        return "Mythic"
    elseif difficultyID == 17 then
        return "LFR"
    else
        return "Unknown"
    end
end

-- Create scrollable loot list
frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
frame.scrollFrame:SetSize(345, 380)
frame.scrollFrame:SetPoint("TOP", frame, "TOP", 0, -30)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(370, 1)
scrollChild:SetPoint("TOP", frame, "TOP")
frame.scrollFrame:SetScrollChild(scrollChild)

local function UpdateLootPositions()
    for i, item in ipairs(lootItems) do
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * 50))
    end
    scrollChild:SetHeight(#lootItems * 50)
end

local function RemoveLootItem(index)
    lootItems[index].frame:Hide()
    table.remove(lootItems, index)
    UpdateLootPositions()
    if #lootItems == 0 then frame:Hide() end
end

-- Once the timer has completed or manually stopped, EndRoll updates ThanksDukaDB.rollHistory with loot history.
-- Data is formatted as: (name), (date mm-dd-yyyy), [item], (raid difficulty), (roll type).
function EndRoll()
    if not rollTimer then
        print("No active roll in progress.")
        return
    end
    
    rollTimer:Cancel()
    rollTimer = nil

    --if rollTimer then
    --    rollTimer:Cancel()
    --    rollTimer = nil
    --end

    if #lootItems == 0 then return end

    local item = lootItems[1]  -- First item in list
    local itemLink = item.link
    local chatType = IsInRaid() and "RAID" or "SAY"

    -- Sort rolls in descending order
    local sortedRolls = {}
    for player, roll in pairs(rolls) do
        table.insert(sortedRolls, {player = player, roll = roll})
    end
    table.sort(sortedRolls, function(a, b) return a.roll > b.roll end)

    -- Distribute items fairly
    local availableItems = lootItemCounts[itemLink] or 1
    local awardedCount = 0

    for i, entry in ipairs(sortedRolls) do
        if awardedCount < availableItems then
            local winner = entry.player
            local highestRoll = entry.roll

            if winner then
                local formattedEntry = string.format("%s, %s, %s, %s, %s", 
                    winner, date("%m-%d-%Y"), itemLink, GetRaidDifficulty(), frame.currentRollType)

                table.insert(ThanksDukaDB.rollHistory, formattedEntry)

                SendChatMessage(winner .. " won " .. itemLink .. " " .. GetRaidDifficulty() .. 
                    " for " .. frame.currentRollType .. " with a roll of " .. highestRoll, chatType)
                    SendChatMessage(winner .. " won " .. itemLink, "WHISPER", nil, UnitName("player"))
                lootItemCounts[itemLink] = lootItemCounts[itemLink] - 1
                awardedCount = awardedCount + 1

                -- If all items are awarded, break out
                if lootItemCounts[itemLink] <= 0 then
                    break
                end
            end
        end
    end

    if awardedCount > 0 then
        -- Subtract awarded count from lootItemCounts
        lootItemCounts[itemLink] = lootItemCounts[itemLink] - awardedCount
    
        -- Remove that many items with matching links from lootItems
        local removed = 0
        for i = #lootItems, 1, -1 do
            if lootItems[i].link == itemLink then
                RemoveLootItem(i)
                removed = removed + 1
                if removed == awardedCount then
                    break
                end
            end
        end
    end


    timerBar:SetValue(0)
    -- Re-enable move buttons
    for _, item in ipairs(lootItems) do
        if item.moveUpButton then item.moveUpButton:Enable() end
        if item.moveDownButton then item.moveDownButton:Enable() end
    end

    -- Hide the glow
    if activeRollGlow then
        activeRollGlow.anim:Stop()
        activeRollGlow:Hide()
        activeRollGlow = nil
    end
end

local function UpdateTimerBar(timeRemaining)
    timerBar:SetValue(timeRemaining)
end

-- Announces a roll is starting for the item in the top position based off of 
-- rollType (2 set tier, 4 set tier, Main Spec, Off Spec, etc.) and starts a timer.
local function AnnounceRoll(rollType)
    return function()
        if not addonEnabled then return end
        if rollTimer then
            print("A roll is already in progress. Please wait for it to finish.")
            return
        end

        if #lootItems == 0 then return end
        local item = lootItems[1]
        local chatType
        if IsInRaid() then
            chatType = "RAID_WARNING"
        elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            chatType = "INSTANCE_CHAT"
        elseif IsInGroup() then
            chatType = "PARTY"
        else
            chatType = "SAY"  -- Fallback if not in a group
        end

        frame.currentRollType = rollType
        rolls = {}

        for _, item in ipairs(lootItems) do
            if item.moveUpButton then item.moveUpButton:Disable() end
            if item.moveDownButton then item.moveDownButton:Disable() end
        end
        
        -- Add glow to the item being rolled
        local rollingItem = lootItems[1]
        if rollingItem then
            if not rollingItem.glow then
                local glow = rollingItem.frame:CreateTexture(nil, "OVERLAY")
                glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                glow:SetBlendMode("ADD")
                glow:SetAlpha(0.8)
                glow:SetSize(80, 80)
                glow:SetPoint("CENTER", rollingItem.icon, "CENTER", 0, 0)
            
                -- Create pulsing animation group
                local ag = glow:CreateAnimationGroup()
                ag:SetLooping("BOUNCE")
            
                local fade = ag:CreateAnimation("Alpha")
                fade:SetFromAlpha(0.4)
                fade:SetToAlpha(0.8)
                fade:SetDuration(0.6)
                fade:SetSmoothing("IN_OUT")
            
                glow.anim = ag
                rollingItem.glow = glow
            end
            
            rollingItem.glow:Show()
            rollingItem.glow.anim:Play()
            activeRollGlow = rollingItem.glow
        end

        SendChatMessage(rollType .. " roll for " .. item.link .. "! You have " .. countdownTime .. " seconds.", chatType)




        rollTimer = C_Timer.NewTicker(1, function()
            local remaining = timerBar:GetValue() - 1
            if remaining <= 0 then
                EndRoll(rollType)
            else
                UpdateTimerBar(remaining)
            end
        end, countdownTime)

        timerBar:SetMinMaxValues(0, countdownTime)
        timerBar:SetValue(countdownTime)
    end
end

-- For the clear history button. Clears ThanksDukaDB.rollHistory. Will only clear history
-- from before the current date.
local function ClearOldHistory()
    if not ThanksDukaDB.rollHistory or #ThanksDukaDB.rollHistory == 0 then
        print("No roll history to clear.")
        return
    end

    local today = date("%m-%d-%Y")
    local newHistory = {}
    local removedEntries = 0

    for _, entry in ipairs(ThanksDukaDB.rollHistory) do
        local entryDate = entry:match("(%d%d%-%d%d%-%d%d%d%d)")
        if entryDate then
            if entryDate == today then
                table.insert(newHistory, entry)  -- Keep today's entries
            else
                removedEntries = removedEntries + 1
            end
        else
            table.insert(newHistory, entry)  -- If date is missing, keep it
        end
    end

    -- Update roll history and save it
    ThanksDukaDB.rollHistory = newHistory

    -- Notify user
    if removedEntries > 0 then
        print("Removed " .. removedEntries .. " old roll entries. Only today's rolls remain.")
    else
        print("No old history found to remove.")
    end

    -- Refresh the export window content
    if content2 and content2.editBox then
        local historyText = table.concat(ThanksDukaDB.rollHistory, "\n")
        content2.editBox:SetText(historyText)
        content2.editBox:HighlightText()
    end
end

-- Similar to ClearOldHistory but for the Attendance tab.
local function ClearOldAttendance()
    -- Ensure attendance history is initialized
    ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}
    AttendanceDB = ThanksDukaDB.attendanceHistory -- Ensure consistency

    if next(AttendanceDB) == nil then
        print("No attendance records to clear.")
        return
    end

    local today = date("%m-%d-%Y") -- Expected format: MM-DD-YYYY
    local newAttendanceDB = {}
    local removedEntries = 0

    -- Iterate through stored attendance records
    for timestamp, entries in pairs(AttendanceDB) do
        if timestamp == today then
            newAttendanceDB[timestamp] = entries -- Keep today's records
        else
            removedEntries = removedEntries + #entries -- Count removed entries
        end
    end

    -- Apply the cleaned attendance history
    ThanksDukaDB.attendanceHistory = newAttendanceDB
    AttendanceDB = newAttendanceDB -- Ensure in-memory reference is updated

    -- Debugging Check: See if it actually removed anything
    if removedEntries > 0 then
        print("Removed " .. removedEntries .. " old attendance records. Only today's remain.")
    else
        print("No old attendance records found to remove.")
    end
     
    -- Refresh the attendance window content
    if content3 and content3.editAttendanceBox then
        local attendanceText = "Raid Attendance - " .. today .. "\n"
        for timestamp, entries in pairs(AttendanceDB) do
            for _, entry in ipairs(entries) do
                attendanceText = attendanceText .. entry.name .. " - " .. timestamp .. "\n"
            end
        end
        content3.editAttendanceBox:SetText(attendanceText)
        content3.editAttendanceBox:HighlightText()
    end
end

-- Function for most basic buttons.
local function CreateButton(text, point, relativeFrame, relativePoint, btnwidth, btnheight, offsetX, offsetY, onClickFunction)
    local button = CreateFrame("Button", nil, relativeFrame, "GameMenuButtonTemplate")
    button:SetSize(btnwidth, btnheight)
    button:SetPoint(point, relativeFrame, relativePoint, offsetX, offsetY)
    button:SetText(text)
    button:SetScript("OnClick", onClickFunction)
    return button
end

-- Fires upon master looter picking up loot. Adds the item icon and tooltip to the loot
-- tab along with a manual remove button beside each item.
local function AddLootItem(itemLink)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemLink)
    
    if not itemIcon then return end 
    
    lootItemCounts[itemLink] = (lootItemCounts[itemLink] or 0) + 1

    local itemFrame = CreateFrame("Frame", nil, scrollChild)
    itemFrame:SetSize(345, 40)
    
    local texture = itemFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetSize(40, 40)
    texture:SetPoint("LEFT", itemFrame, "LEFT", 30, -30)
    texture:SetTexture(itemIcon)
    itemFrame.icon = texture -- Save a reference for glow positioning
    
    local itemButton = CreateFrame("Button", nil, itemFrame)
    itemButton:SetPoint("LEFT", texture, "RIGHT", 15, 0)
    itemButton:SetSize(200, 20) 
    itemButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Common-MouseHilight")
    
    local itemText = itemButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemText:SetPoint("LEFT", itemButton, "LEFT", 0, 0)
    itemText:SetText(itemLink)
    itemButton:SetFontString(itemText)
    
    itemButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(itemButton, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end)
    itemButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    itemFrame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end)
    itemFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Remove button next to each item.
    local removeButton = CreateFrame("Button", nil, itemFrame, "GameMenuButtonTemplate")
    removeButton:SetSize(60, 25)
    removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", -5, -30)
    removeButton:SetText("Remove")
    removeButton:SetScript("OnClick", function()
        for i, item in ipairs(lootItems) do
            if item.frame == itemFrame then
                RemoveLootItem(i)
                break
            end
        end
    end)
    
-- Move Up button
local moveUpButton = CreateFrame("Button", nil, itemFrame, "GameMenuButtonTemplate")
moveUpButton:SetSize(20, 20)
moveUpButton:SetPoint("LEFT", itemFrame, "LEFT", 0, -20)
moveUpButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
moveUpButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
moveUpButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
local upHighlight = moveUpButton:GetHighlightTexture()
upHighlight:ClearAllPoints()
upHighlight:SetAllPoints()
upHighlight:SetBlendMode("ADD")
moveUpButton:SetScript("OnClick", function()
    for i = 1, #lootItems do
        if lootItems[i].frame == itemFrame and i > 1 then
            lootItems[i], lootItems[i - 1] = lootItems[i - 1], lootItems[i]
            UpdateLootPositions()
            break
        end
    end
end)
moveUpButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(moveUpButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Move item up.")
    GameTooltip:Show()
end)
moveUpButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

    -- Move Down button
    local moveDownButton = CreateFrame("Button", nil, itemFrame, "GameMenuButtonTemplate")
    moveDownButton:SetSize(20, 20)
    moveDownButton:SetPoint("BOTTOM", moveUpButton, "CENTER", 0, -30)
    moveDownButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    moveDownButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
    moveDownButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    local downHighlight = moveDownButton:GetHighlightTexture()
    downHighlight:ClearAllPoints()
    downHighlight:SetAllPoints()
    downHighlight:SetBlendMode("ADD")
    moveDownButton:SetScript("OnClick", function()
        for i = 1, #lootItems do
            if lootItems[i].frame == itemFrame and i < #lootItems then
                lootItems[i], lootItems[i + 1] = lootItems[i + 1], lootItems[i]
                UpdateLootPositions()
                break
            end
        end
    end)
    moveDownButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(moveDownButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Move item down.")
        GameTooltip:Show()
    end)
    moveDownButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    --table.insert(lootItems, { frame = itemFrame, link = itemLink })
    table.insert(lootItems, { frame = itemFrame, link = itemLink, moveUpButton = moveUpButton, moveDownButton = moveDownButton, icon = texture })
    itemFrame:SetParent(scrollChild)
    UpdateLootPositions()
    frame:Show()
end



local function ProcessRoll(player, roll)
    if not rolls[player] then
        rolls[player] = roll
    end
end

function RecordAttendance()
    local numGroupMembers = GetNumGroupMembers()
    local dateToday = date("%m-%d-%Y")  -- Format: dd-mm-yyyy

    -- Ensure attendance history is initialized
    ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}

    -- Ensure today's entry exists
    if not ThanksDukaDB.attendanceHistory[dateToday] then
        ThanksDukaDB.attendanceHistory[dateToday] = {}
    end

    local playerName = GetUnitName("player", true)
    if playerName then
        local exists = false
        for _, entry in ipairs(ThanksDukaDB.attendanceHistory[dateToday]) do
            if entry.name == playerName then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(ThanksDukaDB.attendanceHistory[dateToday], { name = playerName })
        end
    end
    
    for i = 1, numGroupMembers do
        local unit = IsInRaid() and "raid" .. i or "party" .. i
        local name = GetUnitName(unit, true)

        if name then
            -- Avoid duplicate names for today
            local exists = false
            for _, entry in ipairs(ThanksDukaDB.attendanceHistory[dateToday]) do
                if entry.name == name then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(ThanksDukaDB.attendanceHistory[dateToday], { name = name })
            end
        end
    end

    -- Force save update
    C_Timer.After(0, function() ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory end)

    -- Update UI
    AttendanceWindow()
end

---------------------------------------------------------------------------------------
-- Handles manually changing winners of loot. Updates ThanksDukaDB.rollHistory with user selected winner.
---------------------------------------------------------------------------------------

local function ManualAwardLoot(entryIndex, newWinner)
    print("ManualAwardLoot called with entry index:", entryIndex, "->", newWinner)

    -- Ensure roll history exists.
    ThanksDukaDB.rollHistory = ThanksDukaDB.rollHistory or {}
    local rollHistory = ThanksDukaDB.rollHistory

    local entry = rollHistory[entryIndex]
    if entry then
        -- Helper function to trim whitespace.
        local function trim(s)
            return s:match("^%s*(.-)%s*$")
        end

        -- Split the entry into parts.
        local parts = { strsplit(",", entry) }
        if #parts >= 5 then
            local oldWinner = trim(parts[1])
            local dateStr   = trim(parts[2])
            local itemName  = trim(parts[3])
            local raidDifficulty = trim(parts[4])
            local rollType  = trim(parts[5])
            
            -- Update the entry while preserving the format.
            rollHistory[entryIndex] = string.format("%s, %s, %s, %s, %s", 
                newWinner, dateStr, itemName, raidDifficulty, rollType)
            
            print(itemName .. " has been manually awarded to " .. newWinner .. ".")
            SendChatMessage("Loot Update: " .. itemName .. " has been awarded to " .. newWinner, "RAID")
            
            if ShowExportWindow then
                ShowExportWindow()
            end
        else
            print("Error: Entry does not split into 5 parts:", entry)
        end
    else
        print("Error: Entry at index " .. entryIndex .. " not found.")
    end
end

local function ItemDropdown_Initialize(self, level)
    local items = {}
    
    local history = ThanksDukaDB and ThanksDukaDB.rollHistory or {}
    if type(history) == "table" then
        for i, entry in ipairs(history) do
            if type(entry) == "string" then
                -- Extract values from the roll history entry.
                local winner, date, itemName, raidDifficulty, rollType = entry:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*(.+)%s*$")
                if itemName then
                    local label = string.format("(%s) %s", winner, itemName)
                    table.insert(items, { index = i, label = label })
                else
                    print("Skipping invalid entry:", entry)
                end
            end
        end

        table.sort(items, function(a, b) return a.label < b.label end)
    end

    if #items == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "No Items"
        info.disabled = true
        UIDropDownMenu_AddButton(info, level)
        return
    end

    for _, itemEntry in ipairs(items) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = itemEntry.label
        info.func = function()
            UIDropDownMenu_SetSelectedName(ThanksDuka_ItemDropdown, itemEntry.label)
            ManualAwardFrame.SelectedEntryIndex = itemEntry.index
        end
        UIDropDownMenu_AddButton(info, level)
    end
end






local function PlayerDropdown_Initialize(self, level)
    local players = {} 

    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            local name = GetRaidRosterInfo(i)
            if name then
                name = name:match("([^%-]+)") -- Remove realm name
                table.insert(players, name)
            end
        end
    end

    table.sort(players)

    for _, player in ipairs(players) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = player
        info.func = function()
            UIDropDownMenu_SetSelectedName(self, player)
            ManualAwardFrame.SelectedPlayer = player
        end
        UIDropDownMenu_AddButton(info, level)
    end
end


local function ShowManualAwardUI()
    if not ManualAwardFrame then
        ManualAwardFrame = CreateFrame("Frame", "ThanksDuka_ManualAwardFrame", UIParent, "BasicFrameTemplateWithInset")
        ManualAwardFrame:SetSize(350, 200)
        ManualAwardFrame:SetPoint("TOP")
        ManualAwardFrame:SetMovable(true)
        ManualAwardFrame:EnableMouse(true)
        ManualAwardFrame:RegisterForDrag("LeftButton")
        ManualAwardFrame:SetScript("OnDragStart", ManualAwardFrame.StartMoving)
        ManualAwardFrame:SetScript("OnDragStop", ManualAwardFrame.StopMovingOrSizing)

        table.insert(UISpecialFrames, "ThanksDuka_ManualAwardFrame")
        
        local title = ManualAwardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", ManualAwardFrame, "TOP", 0, -10)
        title:SetText("Manual Award")
        
        -- Create static labels
        local itemLabel = ManualAwardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemLabel:SetPoint("TOPLEFT", ManualAwardFrame, "TOPLEFT", 10, -45)
        itemLabel:SetText("Item:")
        
        local playerLabel = ManualAwardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        playerLabel:SetPoint("TOPLEFT", ManualAwardFrame, "TOPLEFT", 10, -85)
        playerLabel:SetText("Player:")
        
        -- Item Dropdown
        ThanksDuka_ItemDropdown = CreateFrame("Frame", "ThanksDuka_ItemDropdown", ManualAwardFrame, "UIDropDownMenuTemplate")
        ThanksDuka_ItemDropdown:SetPoint("TOPLEFT", ManualAwardFrame, "TOPLEFT", 70, -40)
        UIDropDownMenu_SetWidth(ThanksDuka_ItemDropdown, 230)
        UIDropDownMenu_Initialize(ThanksDuka_ItemDropdown, ItemDropdown_Initialize)
        
        -- Player Dropdown
        ThanksDuka_PlayerDropdown = CreateFrame("Frame", "ThanksDuka_PlayerDropdown", ManualAwardFrame, "UIDropDownMenuTemplate")
        ThanksDuka_PlayerDropdown:SetPoint("TOPLEFT", ManualAwardFrame, "TOPLEFT", 70, -80)
        UIDropDownMenu_SetWidth(ThanksDuka_PlayerDropdown, 230)
        UIDropDownMenu_Initialize(ThanksDuka_PlayerDropdown, PlayerDropdown_Initialize)
        
        -- Confirm Button
        local confirmButton = CreateFrame("Button", nil, ManualAwardFrame, "GameMenuButtonTemplate")
        confirmButton:SetPoint("BOTTOM", ManualAwardFrame, "BOTTOM", 0, 20)
        confirmButton:SetSize(100, 25)
        confirmButton:SetText("Award")
        confirmButton:SetScript("OnClick", function(self)
            local selectedEntryIndex = ManualAwardFrame.SelectedEntryIndex
            local selectedPlayer = ManualAwardFrame.SelectedPlayer
            if selectedEntryIndex and selectedPlayer then
                ManualAwardLoot(selectedEntryIndex, selectedPlayer)
            else
                print("Please select both an item and a player.")
            end
        end)
    end
    
    ManualAwardFrame:Show()
end
---------------------------------------------------------------------------------------

local twoSetButton = CreateButton("2 Set", "BOTTOM", frame, "BOTTOM", 80, 30, -120, 50, AnnounceRoll("2 Set"))
local fourSetButton = CreateButton("4 Set", "BOTTOM", frame, "BOTTOM", 80, 30, -40, 50, AnnounceRoll("4 Set"))
local msButton = CreateButton("MS", "BOTTOM", frame, "BOTTOM", 80, 30, 40, 50, AnnounceRoll("MS"))
local osButton = CreateButton("OS", "BOTTOM", frame, "BOTTOM", 80, 30, 120, 50, AnnounceRoll("OS"))
local xmogButton = CreateButton("XMog", "BOTTOM", frame, "BOTTOM", 80, 30, -40, 10, AnnounceRoll("XMog"))

--local endRollButton = CreateButton("End Roll", "BOTTOM", frame, "BOTTOM", 80, 30, 40, 10, EndRoll)
local endRollButton = CreateButton("End Roll", "BOTTOM", frame, "BOTTOM", 80, 30, 40, 10, function()
    EndRoll()
end)
        -- "Clear History" Button
local clearButton = CreateButton("Clear History", "BOTTOM", frame, "BOTTOM", 130, 30, -80, 20, ClearOldHistory)
local attendanceButton = CreateButton("Record Attendance", "BOTTOM", frame, "BOTTOM", 130, 30, -80, 20, RecordAttendance)
local clearAttendanceButton = CreateButton("Clear Attendance", "BOTTOM", frame, "BOTTOM", 130, 30, 80, 20, ClearOldAttendance)
local ManualAwardButton = CreateButton("Manually Award", "BOTTOM", frame, "BOTTOM", 130, 30, 80, 20, ShowManualAwardUI)

if not SendAttendanceHistory then
    function SendAttendanceHistory()
    end
end

attendanceButton:HookScript("OnClick", function()
    SendAttendanceHistory()
end)

------------------------------------------------------------------------
-- Create tabs
------------------------------------------------------------------------
local function Tab_OnClick(self) -- What happens when tabs are clicked
    PanelTemplates_SetTab(self:GetParent(), self:GetID()) -- Blizzard API functionality

--[[        -- Hide all tab contents first
    for i = 1, frame.numTabs do
        local tabContent = _G[frame:GetName() .. "Tab" .. i].content
        if tabContent then
            tabContent:Hide()
        end
    end
        -- Hide loot scroll frame when switching to other tabs
    if self:GetID() == 1 then
        frame.scrollFrame:Show()
        frame.scrollFrame:SetScrollChild(scrollChild)
        scrollChild:Show()
    else
        frame.scrollFrame:Hide()
    end

    -- Show this tab's content
    self.content:Show()
--]]

    -- Creates the tab first
    local scrollChild = frame.scrollFrame:GetScrollChild()
    if (scrollChild) then
        scrollChild:Hide()
    end


    -- Gets the content of the tab
    frame.scrollFrame:SetScrollChild(self.content)
    self.content:Show()

    twoSetButton:Hide()
    fourSetButton:Hide()
    msButton:Hide()
    osButton:Hide()
    xmogButton:Hide()
    endRollButton:Hide()
    clearButton:Hide()
    attendanceButton:Hide()
    clearAttendanceButton:Hide()
    ManualAwardButton:Hide()  

    if self:GetID() == 1 then
        twoSetButton:Show()
        fourSetButton:Show()
        msButton:Show()
        osButton:Show()
        xmogButton:Show()
        endRollButton:Show()
    end

    if self:GetID() == 2 then
        ShowExportWindow()
        clearButton:Show()
        ManualAwardButton:Show()
    end
    if self:GetID() == 3 then
        AttendanceWindow()
        attendanceButton:Show()
        clearAttendanceButton:Show()
    end
    if self:GetID() == 4 then
        if not countdownSlider then  -- Ensure it's only created once
            countdownSlider = CreateFrame("Slider", "ThanksDuka_CountdownSlider", content4, "OptionsSliderTemplate")
            countdownSlider:SetSize(180, 20)
            countdownSlider:SetPoint("TOPLEFT", content4, "TOPLEFT", 20, -40)
            countdownSlider:SetMinMaxValues(10, 60)
            countdownSlider:SetValueStep(10)
            countdownSlider:SetValue(60)

            _G["ThanksDuka_CountdownSliderLow"]:SetText("10s")
            _G["ThanksDuka_CountdownSliderHigh"]:SetText("60s")
    
            sliderText = content4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sliderText:SetPoint("BOTTOM", countdownSlider, "TOP", 0, 5)
            sliderText:SetText("Countdown Time: 60s")
    
            countdownSlider:SetScript("OnValueChanged", function(self, value)
                countdownTime = math.floor(value + 0.5)
                sliderText:SetText("Countdown Time: " .. countdownTime .. "s")
            end)
            -- Checkbox to enable/disable receiving loot history
        local receiveHistoryCheckbox = CreateFrame("CheckButton", nil, content4, "UICheckButtonTemplate")
        receiveHistoryCheckbox:SetPoint("TOPLEFT", content4, "TOPLEFT", 20, -80)
        receiveHistoryCheckbox.text = content4:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        receiveHistoryCheckbox.text:SetPoint("LEFT", receiveHistoryCheckbox, "RIGHT", 5, 0)
        receiveHistoryCheckbox.text:SetText("Receive Loot History From Others")

        -- Load saved state
        receiveHistoryCheckbox:SetChecked(ThanksDukaDB.receiveHistory ~= false) -- Default is true

        receiveHistoryCheckbox:SetScript("OnClick", function(self)
            ThanksDukaDB.receiveHistory = self:GetChecked() -- Save setting
        end)

        local receiveAttendanceHistoryCheckbox = CreateFrame("CheckButton", nil, content4, "UICheckButtonTemplate")
        receiveAttendanceHistoryCheckbox:SetPoint("TOPLEFT", content4, "TOPLEFT", 20, -120)
        receiveAttendanceHistoryCheckbox.text = content4:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        receiveAttendanceHistoryCheckbox.text:SetPoint("LEFT", receiveAttendanceHistoryCheckbox, "RIGHT", 5, 0)
        receiveAttendanceHistoryCheckbox.text:SetText("Receive Attendance History From Others")

        -- Load saved state
        receiveAttendanceHistoryCheckbox:SetChecked(AttendanceDB.receiveAttendanceHistory ~= false) -- Default is true

        receiveAttendanceHistoryCheckbox:SetScript("OnClick", function(self)
            AttendanceDB.receiveAttendanceHistory = self:GetChecked() -- Save setting
        end)
        end
    
        countdownSlider:Show()
    else
        if countdownSlider then
            countdownSlider:Hide()
        end
    end
    

end



-- All of the tab content
local function SetTabs(frame, numTabs, ...)
    frame.numTabs = numTabs -- numTabs must be specified for Blizzard API

    local contents = {} -- Stores the contents of each tab
    local frameName = frame:GetName() -- Passes the name of the tab

    for i = 1, numTabs do -- From tab 1 to numTabs do this:

        local tab = CreateFrame("Button", frameName.."Tab"..i, frame, "PanelTabButtonTemplate") -- Creates a frame for the tab
        tab:SetID(i) -- Gives each tab an ID
        tab:SetText(select(i, ...)) -- Text on each tab. i is the tab ID and ... is the text
        tab:SetScript("OnClick", Tab_OnClick)

        tab.content = CreateFrame("Frame", nil, frame)
        tab.content:SetSize(320, 400)
        tab.content:Hide()

        -- For testing purposes
        --tab.content.bg = tab.content:CreateTexture(nil, "BACKGROUND")
        --tab.content.bg:SetAllPoints(true)
        --tab.content.bg:SetColorTexture(math.random(), math.random(), math.random(), 0.6)

        if i == 1 then
            tab.content = scrollChild  -- Tab 1 content = scrollChild (loot items)
        elseif i == 2 then
            tab.content:Hide()
            content2 = tab.content  -- Store reference to Tab 2's content
        elseif i == 3 then
            tab.content:Hide()
            content3 = tab.content
        elseif i == 4 then
            tab.content:Hide()
            content4 = tab.content  -- Store reference to Tab 3's content (Settings)
        else
            tab.content:Hide()
        end

        table.insert(contents, tab.content) -- Table that stores the contents of each tab

        if (i == 1) then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 5, 7)
        else
            tab:SetPoint("TOPLEFT", _G[frameName.."Tab"..(i-1)], "TOPRIGHT", 0, 0)
        end

    end

    Tab_OnClick(_G[frameName.."Tab1"]) -- Global reference for Blizzard API

    return unpack(contents) -- Sends as many contents as needed to contents table above
end
------------------------------------------------------------------------

-------------------------------------------------
-- Window for copying rollHistory.
-------------------------------------------------

function ShowExportWindow()
    if not rollHistory or #rollHistory == 0 then
        print("No saved roll history.")
        return
    end
    
    -- Create a frame if it doesn't exist
    if not content2.editBox then

        local scrollFrame1 = CreateFrame("scrollFrame", nil, content2, "UIPanelScrollFrameTemplate")
        scrollFrame1:SetSize(320, 380)
        scrollFrame1:SetPoint("TOP", content2, "TOP", 0, -30)

        local editBox = CreateFrame("EditBox")
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetSize(320, 1)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
        scrollFrame1:SetScrollChild(editBox)
        content2.editBox = editBox
    end

    -- Populate the edit box with roll history
    local historyText = table.concat(ThanksDukaDB.rollHistory, "\n")
    content2.editBox:SetText(historyText)
    content2.editBox:HighlightText()

    -- Adjust editBox height dynamically based on content
    local numLines = select(2, gsub(historyText, "\n", "\n")) + 1
    local lineHeight = 14  -- Approximate height per line
    local newHeight = math.max(numLines * lineHeight, 380)

    content2.editBox:SetHeight(newHeight)
    content2.editBox:GetParent():SetHeight(newHeight)

end

-------------------------------------------------

-------------------------------------------------
-- Raid attendance tracker
-------------------------------------------------
function AttendanceWindow()
    -- Ensure attendance history exists
    ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}


    -- Create the frame if it doesn’t exist
    if not content3.editAttendanceBox then
        local scrollFrame2 = CreateFrame("ScrollFrame", nil, content3, "UIPanelScrollFrameTemplate")
        scrollFrame2:SetSize(320, 380)
        scrollFrame2:SetPoint("TOP", content3, "TOP", 0, -30)

        local editAttendanceBox = CreateFrame("EditBox", nil, scrollFrame2)
        editAttendanceBox:SetMultiLine(true)
        editAttendanceBox:SetFontObject("ChatFontNormal")
        editAttendanceBox:SetWidth(320)
        editAttendanceBox:SetAutoFocus(false)
        editAttendanceBox:SetScript("OnEscapePressed", function() editAttendanceBox:ClearFocus() end)
        content3.editAttendanceBox = editAttendanceBox
        scrollFrame2:SetScrollChild(editAttendanceBox)
    end
    
    -- Build attendance display text
    local attendanceText = "Raid Attendance\n"
    for entryDate, entries in pairs(ThanksDukaDB.attendanceHistory) do
        for _, entry in ipairs(entries) do
            attendanceText = attendanceText .. entry.name .. ", " .. entryDate .. "\n"
        end
    end

    -- Update UI with saved attendance data
    content3.editAttendanceBox:SetText(attendanceText)
    content3.editAttendanceBox:HighlightText()
end


-- Timer Bar
timerBar = CreateFrame("StatusBar", nil, frame)
timerBar:SetSize(320, 15)
timerBar:SetPoint("TOPLEFT", twoSetButton, "TOPLEFT", 0, 20)
timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
timerBar:SetStatusBarColor(0, 0.7, 1, 0.8)
timerBar:SetMinMaxValues(0, 60)
timerBar:SetValue(0)

local function ToggleAddon()
    addonEnabled = not addonEnabled
    if not addonEnabled then
        frame:Hide()
        print("ThanksDuka is now |cffff0000disabled|r.")
    else
        print("ThanksDuka is now |cff00ff00enabled|r.")
    end
end

local function ToggleFrame()
    if not addonEnabled then
        print("ThanksDuka is currently disabled. Use '/thanksduka enable' to enable it.")
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Passes the contents of each tab.
local content1, content2, content3, content4 = SetTabs(frame, 4, "Loot", "History", "Attendance", "Settings")



frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, msg, sender)
    if event == "PLAYER_LOGIN" then
        ThanksDukaDB = ThanksDukaDB or {}
        rollHistory = ThanksDukaDB.rollHistory or {}
        AttendanceDB = AttendanceDB or {}
    elseif event == "CHAT_MSG_LOOT" then
        if not addonEnabled then return end
        if msg:find("You receive loot:") then  -- Only process if it's YOUR loot
            local itemLink = msg:match("|c.-|Hitem:.-|h|r")
            if itemLink then
                local _, _, itemQuality = GetItemInfo(itemLink)
                if itemQuality and itemQuality >= 3 then  -- Only track Rare+ items
                    AddLootItem(itemLink)
                end
            end
        end
    
    
    
    elseif event == "CHAT_MSG_SYSTEM" then
        if not addonEnabled then return end
        local player, roll = msg:match("(%S+) rolls (%d+) %(1%-100%)")
        if player and roll then ProcessRoll(player, tonumber(roll)) end
    end
end)

SLASH_THANKSDUKA1 = "/thanksduka"
SlashCmdList["THANKSDUKA"] = function(msg)
    if not msg or msg == "" then
        print("|cffffff00Usage:|r")
        print("|cff00ff00/thanksduka enable|r - enables the addon if it is not already")
        print("|cffff0000/thanksduka disable|r - disables the addon if it is not already")
        print("|cff00ccff/thanksduka toggle|r - toggles the main interface") 
        print("|cffffaa00/thanksduka add|r |cffffffff[item]|r - manually add an item to the loot table")
        return
    end

    local command, itemLink = strsplit(" ", msg, 2)

    if command == "enable" then
        addonEnabled = true
        print("ThanksDuka is now |cff00ff00enabled|r.")
    elseif command == "disable" then
        addonEnabled = false
        frame:Hide()
        print("ThanksDuka is now |cffff0000disabled|r.")
    elseif command == "toggle" then
        ToggleFrame()
    elseif command == "add" and itemLink then
        AddLootItem(itemLink)
    else
        print("|cffff0000Invalid command.|r")
        print("|cffffff00Usage:|r")
        print("/thanksduka |cff00ff00enable|r - enables the addon if it is not already")
        print("/thanksduka |cffff0000disable|r - disables the addon if it is not already")
        print("/thanksduka |cff00ccfftoggle|r - toggles the main interface")
        print("/thanksduka |cffffaa00add|r [item] - manually add an item to the loot table")
    end
end
