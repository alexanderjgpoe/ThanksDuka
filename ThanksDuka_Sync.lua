-- ThanksDuka Loot and Attendance Sync Module
local addonPrefix = "THANKSDUKA_SYNC"
local attendancePrefix = "THANKSDUKA_SYNC_ATTENDANCE"

-- Ensure ThanksDukaDB is initialized properly
ThanksDukaDB = ThanksDukaDB or {}
ThanksDukaDB.rollHistory = ThanksDukaDB.rollHistory or {}
ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}

-- Function to send the most recent loot entry to other addon users
local function SendLatestLootEntry()
    if not ThanksDukaDB.rollHistory or #ThanksDukaDB.rollHistory == 0 then return end
    local latestEntry = ThanksDukaDB.rollHistory[#ThanksDukaDB.rollHistory]
    C_ChatInfo.SendAddonMessage(addonPrefix, latestEntry, "RAID")
end

-- Function to receive loot history updates without duplicates
local function OnEvent(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix and sender ~= UnitName("player") then
        -- Check if user wants to receive history
        if ThanksDukaDB.receiveHistory == false then return end
        
        -- Avoid duplicates
        for _, entry in ipairs(ThanksDukaDB.rollHistory) do
            if entry == message then
                return
            end
        end
        
        table.insert(ThanksDukaDB.rollHistory, message)
        print("Received new loot history from " .. sender .. ": " .. message)
    end
end

-- Register addon message event
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", OnEvent)
C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)

-- Hook into the main addon’s EndRoll function to send updates after each item
local originalEndRoll = EndRoll
function EndRoll()
    originalEndRoll()
    SendLatestLootEntry()
end

-- Function to send attendance history when button is clicked
local function SendAttendanceHistory()
    if not ThanksDukaDB.attendanceHistory or next(ThanksDukaDB.attendanceHistory) == nil then return end
    for timestamp, entries in pairs(ThanksDukaDB.attendanceHistory) do
        for _, entry in ipairs(entries) do
            C_ChatInfo.SendAddonMessage(attendancePrefix, timestamp .. " - " .. entry.name, "RAID")
        end
    end
    print("Attendance history sent.")
end

-- Hook up the existing attendanceButton to send attendance history
if attendanceButton then
    attendanceButton:SetScript("OnClick", SendAttendanceHistory)
end

-- Function to receive attendance history updates separately
local function OnAttendanceEvent(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == attendancePrefix and sender ~= UnitName("player") then
        -- Check if user wants to receive attendance history
        if ThanksDukaDB.receiveAttendanceHistory == false then return end
        
        local timestamp, playerName = strmatch(message, "(.-) %- (.+)")
        if timestamp and playerName then
            if not ThanksDukaDB.attendanceHistory[timestamp] then
                ThanksDukaDB.attendanceHistory[timestamp] = {}
            end
            -- Avoid duplicates
            for _, entry in ipairs(ThanksDukaDB.attendanceHistory[timestamp]) do
                if entry.name == playerName then return end
            end
            table.insert(ThanksDukaDB.attendanceHistory[timestamp], { name = playerName })
            print("Received new attendance history from " .. sender .. ": " .. message)
        end
    end
end

-- Register event listener for attendance history
local attendanceFrame = CreateFrame("Frame")
attendanceFrame:RegisterEvent("CHAT_MSG_ADDON")
attendanceFrame:SetScript("OnEvent", OnAttendanceEvent)
C_ChatInfo.RegisterAddonMessagePrefix(attendancePrefix)
