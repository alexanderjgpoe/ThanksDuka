-- ThanksDuka WoW Loot Addon
local frame = CreateFrame("Frame", "ThanksDukaFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(380, 500)
frame:SetPoint("CENTER")
frame:Hide()

table.insert(UISpecialFrames, "ThanksDukaFrame")

local addonEnabled = true
ThanksDukaDB = ThanksDukaDB or {}
ThanksDukaDB.rollHistory = ThanksDukaDB.rollHistory or {}  -- Store roll history
ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}  -- Store attendance history


frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
frame.title:SetText("Thanks Duka - Loot")

local lootItems = {}
local rolls = {}
local lootItemCounts = {}
local rollTimer
local timerBar
local countdownTime = 60  -- Default value



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
frame.scrollFrame:SetSize(320, 380)
frame.scrollFrame:SetPoint("TOP", frame, "TOP", 0, -30)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(320, 1)
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

function EndRoll()
    if rollTimer then
        rollTimer:Cancel()
        rollTimer = nil
    end

    if #lootItems == 0 then return end
    local item = lootItems[1]
    local chatType = IsInRaid() and "RAID" or "SAY"
    local highestRoll, winner = 0, nil
    
    for player, roll in pairs(rolls) do
        if roll > highestRoll then
            highestRoll = roll
            winner = player
        end
    end
    
     local rollTypeText = frame.currentRollType or "Unknown"
     local itemName = GetItemInfo(item.link) or item.link -- Get plain text

     if winner then
        local formattedEntry = string.format("%s, %s, %s, %s, %s", 
            winner, date("%m-%d-%Y"), itemName, GetRaidDifficulty(), rollTypeText)
        
        -- Save it to rollHistory
        table.insert(ThanksDukaDB.rollHistory, formattedEntry)
        --ThanksDukaDB.rollHistory = ThanksDukaDB.rollHistory  -- Save to database

        SendChatMessage(winner .. " won " .. item.link .. " " .. GetRaidDifficulty() .. " for " .. rollTypeText .. " with a roll of " .. highestRoll .. " on " .. date("%m-%d-%Y"), chatType)
        SendChatMessage(winner .. " won " .. item.link, "WHISPER", nil, UnitName("player"))
        RemoveLootItem(1)
    else
        SendChatMessage("No valid rolls received.", chatType)
    end
    
    if rollTimer then
        rollTimer:Cancel()
        rollTimer = nil
    end
    timerBar:SetValue(0)
end

local function UpdateTimerBar(timeRemaining)
    timerBar:SetValue(timeRemaining)
end

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

        SendChatMessage(rollType .. " roll for " .. item.link .. "! You have " .. countdownTime .. " seconds.", chatType)

        rolls = {}


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

--For the clear history button.
local function ClearOldHistory()
    if not ThanksDukaDB.rollHistory or #ThanksDukaDB.rollHistory == 0 then
        print("No roll history to clear.")
        return
    end

    local today = date("%m-%d-%Y")  -- Ensure this matches your entry format
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
    --C_Timer.After(0, function() ThanksDukaDB.rollHistory = newHistory end)

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

local function ClearOldAttendance()
    if not AttendanceDB or next(AttendanceDB) == nil then
        print("No attendance records to clear.")
        return
    end

    local today = date("%m-%d-%Y") -- Match the timestamp format used in RecordAttendance
    local newAttendanceDB = {}
    local removedEntries = 0

    for timestamp, entries in pairs(AttendanceDB) do
        local entryDate = timestamp:match("(%d%d%d%d%-%d%d%-%d%d)")
        if entryDate == today then
            newAttendanceDB[timestamp] = entries -- Keep today's entries
        else
            removedEntries = removedEntries + #entries
        end
    end

    -- Update AttendanceDB and save it
    AttendanceDB = newAttendanceDB
    C_Timer.After(0, function() ThanksDukaDB.AttendanceDB = AttendanceDB end)

    -- Notify user
    if removedEntries > 0 then
        print("Removed " .. removedEntries .. " old attendance records. Only today's records remain.")
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

local function CreateButton(text, point, relativeFrame, relativePoint, btnwidth, btnheight, offsetX, offsetY, onClickFunction)
    local button = CreateFrame("Button", nil, relativeFrame, "GameMenuButtonTemplate")
    button:SetSize(btnwidth, btnheight)
    button:SetPoint(point, relativeFrame, relativePoint, offsetX, offsetY)
    button:SetText(text)
    button:SetScript("OnClick", onClickFunction)
    return button
end



local function AddLootItem(itemLink)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemLink)
    
    if not itemIcon then return end 
    
    lootItemCounts[itemLink] = (lootItemCounts[itemLink] or 0) + 1

    local itemFrame = CreateFrame("Frame", nil, scrollChild)
    itemFrame:SetSize(360, 40)
    
    local texture = itemFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetSize(40, 40)
    texture:SetPoint("LEFT", itemFrame, "LEFT", 0, -30)
    texture:SetTexture(itemIcon)
    
    local itemText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemText:SetPoint("LEFT", texture, "RIGHT", 15, 0)
    itemText:SetText(itemLink)

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
    removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", -40, -30)
    removeButton:SetText("Remove")
    removeButton:SetScript("OnClick", function()
        for i, item in ipairs(lootItems) do
            if item.frame == itemFrame then
                RemoveLootItem(i)
                break
            end
        end
    end)
    
    table.insert(lootItems, { frame = itemFrame, link = itemLink })
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


local twoSetButton = CreateButton("2 set", "BOTTOM", frame, "BOTTOM", 80, 30, -120, 50, AnnounceRoll("2 set"))
local fourSetButton = CreateButton("4 set", "BOTTOM", frame, "BOTTOM", 80, 30, -40, 50, AnnounceRoll("4 set"))
local msButton = CreateButton("MS", "BOTTOM", frame, "BOTTOM", 80, 30, 40, 50, AnnounceRoll("MS"))
local osButton = CreateButton("OS", "BOTTOM", frame, "BOTTOM", 80, 30, 120, 50, AnnounceRoll("OS"))
local xmogButton = CreateButton("XMog", "BOTTOM", frame, "BOTTOM", 80, 30, -40, 10, AnnounceRoll("XMog"))

local endRollButton = CreateButton("End Roll", "BOTTOM", frame, "BOTTOM", 80, 30, 40, 10, EndRoll)

        -- "Clear History" Button
local clearButton = CreateButton("Clear History", "BOTTOM", frame, "BOTTOM", 90, 30, 0, 20, ClearOldHistory)
local attendanceButton = CreateButton("Record Attendance", "BOTTOM", frame, "BOTTOM", 130, 30, -80, 20, RecordAttendance)
local clearAttendanceButton = CreateButton("Clear Attendance", "BOTTOM", frame, "BOTTOM", 130, 30, 80, 20, ClearOldAttendance)


twoSetButton:Hide()
fourSetButton:Hide()
msButton:Hide()
osButton:Hide()
xmogButton:Hide()
endRollButton:Hide()



------------------------------------------------------------------------
-- Create tabs
------------------------------------------------------------------------
local function Tab_OnClick(self) -- What happens when tabs are clicked
    PanelTemplates_SetTab(self:GetParent(), self:GetID()) -- Blizzard API functionality

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
    end
    if self:GetID() == 3 then
        AttendanceWindow()
        attendanceButton:Show()
        clearAttendanceButton:Show()
    end
    if self:GetID() == 4 then
        if not countdownSlider then  -- Ensure it's only created once
            countdownSlider = CreateFrame("Slider", nil, content4, "OptionsSliderTemplate")
            countdownSlider:SetSize(180, 20)
            countdownSlider:SetPoint("TOPLEFT", content4, "TOPLEFT", 20, -40)
            countdownSlider:SetMinMaxValues(10, 60)
            countdownSlider:SetValueStep(10)
            countdownSlider:SetValue(60)
    
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

        tab.content = CreateFrame("Frame", nil, scrollFrame)
        tab.content:SetSize(320, 400)
        tab.content:Hide()

        -- For testing purposes
        --tab.content.bg = tab.content:CreateTexture(nil, "BACKGROUND")
        --tab.content.bg:SetAllPoints(true)
        --tab.content.bg:SetColorTexture(math.random(), math.random(), math.random(), 0.6)

        if i == 1 then
            tab.content = scrollChild  -- Tab 1 content = scrollChild (loot items)
        elseif i == 2 then
            tab.content = CreateFrame("Frame", nil, frame.scrollFrame)
            tab.content:SetSize(320, 400)
            tab.content:Hide()
            content2 = tab.content  -- Store reference to Tab 2's content
        elseif i == 3 then
            tab.content = CreateFrame("Frame", nil, frame.scrollFrame)
            tab.content:SetSize(320, 400)
            tab.content:Hide()
            content3 = tab.content
        elseif i == 4 then
            tab.content = CreateFrame("Frame", nil, frame.scrollFrame)
            tab.content:SetSize(320, 400)
            tab.content:Hide()
            content4 = tab.content  -- Store reference to Tab 3's content (Settings)
        else
            tab.content = CreateFrame("Frame", nil, frame.scrollFrame)
            tab.content:SetSize(320, 400)
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


ShowExportWindow = function()
    if not rollHistory or #rollHistory == 0 then
        print("No saved roll history.")
        return
    end

    -- Create a frame if it doesn't exist
    if not content2.editBox then
        local scrollFrame = CreateFrame("ScrollFrame", nil, content2, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(320, 400)
        scrollFrame:SetPoint("TOP", content2, "TOP", 0, -30)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(320)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
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
-- Raid attendance traker
-------------------------------------------------
function AttendanceWindow()
    -- Ensure attendance history exists
    ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}

    -- Create the frame if it doesn’t exist
    if not content3.editAttendanceBox then
        local scrollFrame = CreateFrame("ScrollFrame", nil, content3, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(320, 380)
        scrollFrame:SetPoint("TOP", content3, "TOP", 0, -30)

        local editAttendanceBox = CreateFrame("EditBox", nil, scrollFrame)
        editAttendanceBox:SetMultiLine(true)
        editAttendanceBox:SetFontObject("ChatFontNormal")
        editAttendanceBox:SetWidth(320)
        editAttendanceBox:SetAutoFocus(false)
        editAttendanceBox:SetScript("OnEscapePressed", function() editAttendanceBox:ClearFocus() end)
        scrollFrame:SetScrollChild(editAttendanceBox)
        content3.editAttendanceBox = editAttendanceBox
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


-------------------------------------------------

-- Create Dropdown Menu
--[[local difficultyDropdown = CreateFrame("Frame", "ThanksDukaDropdown", frame, "UIDropDownMenuTemplate")
difficultyDropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -30)

local function OnDifficultySelected(self, arg1, arg2, checked)
    selectedDifficulty = arg1
    UIDropDownMenu_SetText(difficultyDropdown, arg1)
end

local function InitializeDropdown(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    info.func = OnDifficultySelected
    
    info.text, info.arg1 = "Normal", "Normal"
    UIDropDownMenu_AddButton(info)
    
    info.text, info.arg1 = "Heroic", "Heroic"
    UIDropDownMenu_AddButton(info)
end

UIDropDownMenu_Initialize(difficultyDropdown, InitializeDropdown)
UIDropDownMenu_SetWidth(difficultyDropdown, 100)
UIDropDownMenu_SetText(difficultyDropdown, "Normal")--]]



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






local content1, content2, content3, content4 = SetTabs(frame, 4, "Loot", "History", "Attendance", "Settings")


frame:RegisterForDrag("LeftButton")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)


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
        print("|cff00ff00ThanksDuka is now enabled.|r")
    elseif command == "disable" then
        addonEnabled = false
        frame:Hide()
        print("|cffff0000ThanksDuka is now disabled.|r")
    elseif command == "toggle" then
        ToggleFrame()
    elseif command == "add" and itemLink then
        AddLootItem(itemLink)
    else
        print("|cffff0000Invalid command.|r")
        print("|cffffff00Usage:|r")
        print("|cff00ff00/thanksduka enable|r - enables the addon if it is not already")
        print("|cffff0000/thanksduka disable|r - disables the addon if it is not already")
        print("|cff00ccff/thanksduka toggle|r - toggles the main interface")
        print("|cffffaa00/thanksduka add|r |cffffffff[item]|r - manually add an item to the loot table")
    end
end
