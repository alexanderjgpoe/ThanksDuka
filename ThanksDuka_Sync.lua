-- ThanksDuka Loot and Attendance Sync Module
local addonPrefix = "THANKSDUKA_SYNC"
local attendancePrefix = "THANKSDUKA_SYNC_ATTENDANCE"

ThanksDukaDB = ThanksDukaDB or {}
ThanksDukaDB.rollHistory = ThanksDukaDB.rollHistory or {}
ThanksDukaDB.attendanceHistory = ThanksDukaDB.attendanceHistory or {}

-- Function to send the most recent loot entry to other addon users
local function SendLatestLootEntry()
    if not ThanksDukaDB.rollHistory or #ThanksDukaDB.rollHistory == 0 then 
        return 
    end

    local latestEntry = ThanksDukaDB.rollHistory[#ThanksDukaDB.rollHistory]
    local chatType = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or "WHISPER"
    local target = chatType == "WHISPER" and UnitName("player") or nil

    C_ChatInfo.SendAddonMessage("THANKSDUKA_SYNC", latestEntry, chatType, target)
end

-- Function to receive loot history updates without duplicates
local function OnEvent(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
    end

    if event == "CHAT_MSG_ADDON" and prefix == addonPrefix and sender ~= UnitName("player") then

        if ThanksDukaDB.receiveHistory == false then 
            return 
        end

        -- Avoid duplicates
        for _, entry in ipairs(ThanksDukaDB.rollHistory) do
            if entry == message then
                print("Duplicate loot entry detected, ignoring.")
                return
            end
        end
        
        table.insert(ThanksDukaDB.rollHistory, message)
    end
end


-- Register addon message event
C_Timer.After(1, function() -- Ensure EndRoll is defined before hooking
    if type(EndRoll) == "function" then
        local originalEndRoll = EndRoll
        EndRoll = function()
            originalEndRoll() -- Call the original function
            SendLatestLootEntry() -- Send the loot history
        end
    end
end)


-- Function to send attendance history when button is clicked
local function SendAttendanceHistory()
    if not ThanksDukaDB.attendanceHistory or next(ThanksDukaDB.attendanceHistory) == nil then 
        print("No attendance history to send.")
        return 
    end

    local chatType = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or "WHISPER"
    local target = chatType == "WHISPER" and UnitName("player") or nil

    for timestamp, entries in pairs(ThanksDukaDB.attendanceHistory) do
        for _, entry in ipairs(entries) do
            local message = timestamp .. " - " .. entry.name
            print("Sending attendance history for " .. #entries .. " players.")

            local success = C_ChatInfo.SendAddonMessage("THANKSDUKA_SYNC_ATTENDANCE", message, chatType, target)

            if success then
                print("Successfully sent attendance entry.")
            else
                print("Failed to send attendance entry!")
            end
        end
    end
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
        end
    end
end

-- Register event listener for attendance history
local attendanceFrame = CreateFrame("Frame")
attendanceFrame:RegisterEvent("CHAT_MSG_ADDON")
attendanceFrame:SetScript("OnEvent", OnAttendanceEvent)
C_ChatInfo.RegisterAddonMessagePrefix(attendancePrefix)
