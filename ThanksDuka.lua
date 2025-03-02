-- ThanksDuka WoW Loot Addon
local frame = CreateFrame("Frame", "ThanksDukaFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(380, 500)
frame:SetPoint("CENTER")
frame:Hide()

local addonEnabled = true
local selectedDifficulty = "Normal"
ThanksDukaDB = ThanksDukaDB or {}
local rollHistory = ThanksDukaDB.rollHistory or {}  -- Load roll history


frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
frame.title:SetText("Thanks Duka - Loot")

-- Create Dropdown Menu
local difficultyDropdown = CreateFrame("Frame", "ThanksDukaDropdown", frame, "UIDropDownMenuTemplate")
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
UIDropDownMenu_SetText(difficultyDropdown, "Normal")

local lootItems = {}
local rolls = {}
local rollTimer
local timerBar

-- Create scrollable loot list
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(320, 380)
scrollFrame:SetPoint("TOP", frame, "TOP", 0, -30)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(320, 1)
scrollChild:SetPoint("TOP", frame, "TOP")
scrollFrame:SetScrollChild(scrollChild)

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

local function AddLootItem(itemLink)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemLink)
    
    if not itemIcon then return end 
    
    local itemFrame = CreateFrame("Frame", nil, frame)
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
        local chatType = IsInRaid() and "RAID" or "SAY"

        frame.currentRollType = rollType

        SendChatMessage(rollType .. " roll for " .. item.link .. "! You have 60 seconds.", chatType)

        rolls = {}
        rollTimer = C_Timer.NewTicker(1, function()
            local remaining = timerBar:GetValue() - 1
            if remaining <= 0 then
                EndRoll(rollType)
            else
                UpdateTimerBar(remaining)
            end
        end, 60)

        timerBar:SetMinMaxValues(0, 60)
        timerBar:SetValue(60)
    end
end

local function EndRoll()
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
            winner, date("%m-%d-%Y"), itemName, selectedDifficulty, rollTypeText)
        
        -- Save it to rollHistory
        table.insert(rollHistory, formattedEntry)
        ThanksDukaDB.rollHistory = rollHistory  -- Save to database

        SendChatMessage(winner .. " won " .. item.link .. " " .. selectedDifficulty .. " for " .. rollTypeText .. " with a roll of " .. highestRoll .. " on " .. date("%m-%d-%Y"), chatType)
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

local function CreateRollButton(text, offsetX, offsetY, onClickFunction)
    local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    button:SetSize(80, 30)
    button:SetPoint("BOTTOM", frame, "BOTTOM", offsetX, offsetY)
    button:SetText(text)
    button:SetScript("OnClick", onClickFunction)
    return button
end

local twoSetButton = CreateRollButton("2 set", -120, 50, AnnounceRoll("2 set"))
local fourSetButton = CreateRollButton("4 set", -40, 50, AnnounceRoll("4 set"))
local msButton = CreateRollButton("MS", 40, 50, AnnounceRoll("MS"))
local osButton = CreateRollButton("OS", 120, 50, AnnounceRoll("OS"))
local xmogButton = CreateRollButton("XMog", -40, 10, AnnounceRoll("XMog"))

local endRollButton = CreateRollButton("End Roll", 40, 10, EndRoll)


local function ProcessRoll(player, roll)
    if not rolls[player] then
        rolls[player] = roll
    end
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



-------------------------------------------------
-- Window for copying rollHistory.
-------------------------------------------------
--For the clear history button.
local function ClearOldHistory()
    if not rollHistory or #rollHistory == 0 then
        print("No roll history to clear.")
        return
    end

    local today = date("%m-%d-%Y")
    local newHistory = {}
    local removedEntries = 0

    for _, entry in ipairs(rollHistory) do
        local entryDate = entry:match("(%d%d%-%d%d%-%d%d%d%d)")
        if entryDate then
            if entryDate == today then
                table.insert(newHistory, entry)  -- Keep today's entries
            else
                removedEntries = removedEntries + 1  -- Count removed entries
            end
        else
            table.insert(newHistory, entry)  -- If date is missing, keep it
        end
    end

    -- Update roll history and save it
    rollHistory = newHistory
    ThanksDukaDB.rollHistory = newHistory

    -- Notify user
    if removedEntries > 0 then
        print("Removed " .. removedEntries .. " old roll entries. Only today's rolls remain.")
    else
        print("No old history found to remove.")
    end
end


local function ShowExportWindow()
    if not rollHistory or #rollHistory == 0 then
        print("No saved roll history.")
        return
    end

    -- Create a frame if it doesn't exist
    if not ThanksDukaExportFrame then
        ThanksDukaExportFrame = CreateFrame("Frame", "ThanksDukaExportFrame", UIParent, "BasicFrameTemplateWithInset")
        ThanksDukaExportFrame:SetSize(400, 300)
        ThanksDukaExportFrame:SetPoint("CENTER")
        ThanksDukaExportFrame:SetMovable(true)
        ThanksDukaExportFrame:EnableMouse(true)
        ThanksDukaExportFrame:RegisterForDrag("LeftButton")
        ThanksDukaExportFrame:SetScript("OnDragStart", ThanksDukaExportFrame.StartMoving)
        ThanksDukaExportFrame:SetScript("OnDragStop", ThanksDukaExportFrame.StopMovingOrSizing)
        
        -- Create a scrollable edit box
        local scrollFrame = CreateFrame("ScrollFrame", nil, ThanksDukaExportFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(360, 200)
        scrollFrame:SetPoint("TOP", ThanksDukaExportFrame, "TOP", 0, -30)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(360)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        ThanksDukaExportFrame.editBox = editBox

        -- "Clear History" Button
        local clearButton = CreateFrame("Button", nil, ThanksDukaExportFrame, "GameMenuButtonTemplate")
        clearButton:SetSize(100, 25)
        clearButton:SetPoint("BOTTOM", ThanksDukaExportFrame, "BOTTOM", -60, 10)
        clearButton:SetText("Clear History")
        clearButton:SetScript("OnClick", function()
            ClearOldHistory()
            ShowExportWindow() -- Refresh window after clearing
        end)

        -- Close button
        local closeButton = CreateFrame("Button", nil, ThanksDukaExportFrame, "GameMenuButtonTemplate")
        closeButton:SetSize(80, 25)
        closeButton:SetPoint("RIGHT", clearButton, "RIGHT", 100, 0)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function() ThanksDukaExportFrame:Hide() end)
    end

    -- Populate the edit box with roll history
    local historyText = ""
    for _, entry in ipairs(rollHistory) do
        historyText = historyText .. entry .. "\n"
    end
    ThanksDukaExportFrame.editBox:SetText(historyText)
    ThanksDukaExportFrame.editBox:HighlightText()  -- Automatically highlights text for easy copying
    ThanksDukaExportFrame:Show()
end

-------------------------------------------------



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
    if msg == "enable" then
        addonEnabled = true
        print("ThanksDuka is now |cff00ff00enabled|r.")
    elseif msg == "disable" then
        addonEnabled = false
        frame:Hide()
        print("ThanksDuka is now |cffff0000disabled|r.")
    elseif msg == "toggle" then
        ToggleFrame()
    elseif msg == "export" then
        ShowExportWindow()
    end
        print("Usage: /thanksduka [enable  |  disable  |  toggle  |  export]")
end
