-- ThanksDuka WoW Loot Council Addon
local frame = CreateFrame("Frame", "ThanksDukaFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(380, 500)
frame:SetPoint("CENTER")
frame:Hide()

local addonEnabled = true

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
frame.title:SetText("Thanks Duka - Loot Council")

local lootItems = {}
local rolls = {}
local rollTimer
local timerBar

-- Create scrollable loot list
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(320, 380)
scrollFrame:SetPoint("TOP", frame, "TOP", 0, -30)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(320, 1) -- Will expand dynamically
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
    texture:SetPoint("LEFT", itemFrame, "LEFT")
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
    removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", -40, 0)
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

local function EndRoll()
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
    
    if winner then
        SendChatMessage("Winner: " .. winner .. " with a roll of " .. highestRoll, chatType)
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

local function AnnounceRoll(rollType)
    return function()
        if #lootItems == 0 then return end
        local item = lootItems[1]
        local chatType = IsInRaid() and "RAID" or "SAY"
        SendChatMessage(rollType .. " roll for " .. item.link .. "! You have 60 seconds.", chatType)
        rolls = {}
        rollTimer = C_Timer.NewTicker(1, function()
            local remaining = timerBar:GetValue() - 1
            if remaining <= 0 then
                EndRoll()
            else
                UpdateTimerBar(remaining)
            end
        end, 60)
        timerBar:SetMinMaxValues(0, 60)
        timerBar:SetValue(60)
    end
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

--[[
local startRollButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
startRollButton:SetSize(120, 30)
startRollButton:SetPoint("BOTTOM", frame, "BOTTOM", -70, 10)
startRollButton:SetText("Start Roll")
startRollButton:SetScript("OnClick", AnnounceRoll)
--]]

--[[
local endRollButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
endRollButton:SetSize(120, 30)
endRollButton:SetPoint("BOTTOM", frame, "BOTTOM", 70, 10)
endRollButton:SetText("End Roll")
endRollButton:SetScript("OnClick", EndRoll)
--]]

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
    else
        print("Usage: /thanksduka [enable  |  disable  |  toggle]")
    end
end

frame:RegisterForDrag("LeftButton")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function(self, event, msg, sender)
    if not addonEnabled then return end

    if event == "CHAT_MSG_LOOT" then
        local itemLink = msg:match("|c.-|Hitem:.-|h|r")
        if itemLink then AddLootItem(itemLink) end
    elseif event == "CHAT_MSG_SYSTEM" then
        local player, roll = msg:match("(%S+) rolls (%d+) %(1%-100%)")
        if player and roll then ProcessRoll(player, tonumber(roll)) end
    end
end)
