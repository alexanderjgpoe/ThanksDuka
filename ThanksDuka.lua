ThanksDuka = {}

-- Create a frame to capture events
ThanksDuka.frame = CreateFrame("Frame");

--List of players and loot items.
ThanksDuka.players = {}
ThanksDuka.lootItems = {}

--Table to hold who gets which item
ThanksDuka.lootDistribution = {}

-- Register events to track drops
ThanksDuka.frame:RegisterEvent("CHAT_MSG_LOOT");
ThanksDuka.frame:RegisterEvent("PLAYER_ENTERING_WORLD");

ThanksDuka.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        ThanksDuka:HandleLootEvent(...);
    elseif event == "PLAYER_ENTERING_WORLD" then
        ThanksDuka:ResetLootDistribution();
    end
end)

-- Handle loot events
function ThanksDuka:HandleLootEvent(message)
    local itemLink = message:match("You receive loot: (|c.+|r)") -- Captures the item link
    local playerName = UnitName("player");

    if itemLink then
        -- Store the loot and who won it
        table.insert(ThanksDuka.lootItems, {itemLink = intemLink, player = playerName});
        -- Needs some logic?

        ThanksDuka:ShowRollUI(itemLink); -- Make a popup box for looted item with button to roll on the item
    end
end

-- Function to distribute loot(maybe?)


--Reset loot distribution when entering the world
function ThanksDuka:ResetLootDistribution()
    ThanksDuka.lootDistribution = {}
    ThanksDuka.lootItems = {}
end

-- Main addon frame
local ThanksDukaFrame = CreateFrame("Frame", "ThanksDukaFrame", UIParent, "BasicFrameTemplateWithInset")
ThanksDukaFrame:SetSize(400, 300);
ThanksDukaFrame:SetPoint("CENTER");

-- Child frames and regions
ThanksDukaFrame.title = ThanksDukaFrame:CreateFontString(nil, "OVERLAY");
ThanksDukaFrame.title:SetFontObject("GameFontHighlight");
ThanksDukaFrame.title:SetPoint("LEFT", ThanksDukaFrame.TitleBg, "LEFT", 5, 0);
ThanksDukaFrame.title:SetText("Thanks Duka Options");

ThanksDukaFrame:SetMovable(true);
ThanksDukaFrame:EnableMouse(true);
ThanksDukaFrame:RegisterForDrag("LeftButton");
ThanksDukaFrame:SetScript("OnDragStart", ThanksDukaFrame.StartMoving);
ThanksDukaFrame:SetScript("OnDragStop", ThanksDukaFrame.StopMovingOrSizing);

-- Button
-- Dummy Button for now
ThanksDukaFrame.saveButton = CreateFrame("Button", nil, ThanksDukaFrame, "GameMenuButtonTemplate");
ThanksDukaFrame.saveButton:SetPoint("CENTER", ThanksDukaFrame, "TOP", 0, -70);
ThanksDukaFrame.saveButton:SetSize(140, 40);
ThanksDukaFrame.saveButton:SetText("Save"); -- Dummy button text. Change later.
ThanksDukaFrame.saveButton:SetNormalFontObject("GameFontNormalLarge"); -- Font for button from Blizzard api
ThanksDukaFrame.saveButton:SetHighlightFontObject("GameFontHighlightLarge"); -- Highlight for mouseover of button from Blizzard api

-- Start hidden
ThanksDukaFrame:Hide();

-- Toggle Function
local function ToggleThanksDuka()
    if ThanksDukaFrame:IsShown() then
        ThanksDukaFrame:Hide()
    else
        ThanksDukaFrame:Show()
    end
end

SLASH_THANKSDUKA1 = "/THANKSDUKA" -- Change to something shorter
SlashCmdList["THANKSDUKA"] = ToggleThanksDuka;

--------------------------------------------------------------------
-- Roll UI and roll timer functionality
--------------------------------------------------------------------

--Create and display roll UI for an item.
function ThanksDuka:ShowRollUI(itemLink)
    if not self.rollFrame then
        self.rollFrame = CreateFrame("Frame", "ThanksDukaRollFrame", UIParent, "BasicFrameTemplateWithInset")
        self.rollFrame:SetSize(300, 150)
        self.rollFrame:SetPoint("CENTER")

        self.rollFrame.title = self.rollFrame:CreateFontString(nil, "OVERLAY") 
        self.rollFrame.title:SetFontObject("GameFontHighlight")
        self.rollFrame.title:SetPoint("TOP", self.rollFrame, "TOP", 0, -10)
        self.rollFrame.title:SetText("Roll for Item")

        self.rollFrame.itemText = self.rollFrame:CreateFontString(nil, "OVERLAY")
        self.rollFrame.itemText:SetFontObject("GameFontNormal")
        self.rollFrame.itemText:SetPoint("TOP", self.rollFrame, "TOP", 0, -40)

        -- Button to start a roll. Need five or six buttons.
        self.rollFrame.rollButton = CreateFrame("Button", nil, self.rollFrame, "GameMenuButtonTemplate")
        self.rollFrame.rollButton:SetPoint("BOTTOM", self.rollFrame, "BOTTOM", 0, 20)
        self.rollFrame.rollButton:SetSize(140, 40)
        self.rollFrame.rollButton:SetText("Start Roll")
        self.rollFrame.rollButton:SetNormalFontObject("GameFontNormalLarge")
        self.rollFrame.rollButton:SetHighlightFontObject("GameFontHighlightLarge")
    end

    -- Update the displayed item and show the UI.
    self.rollFrame.itemText:SetText(itemLink)
    self.rollFrame:Show()

    -- Start roll session on button click
    self.rollFrame.rollButton:SetScript("OnClick", function()
        ThanksDuka:StartRollSession(itemLink)
    end)
end

-- Called on button press
function ThanksDuka:StartRollSession(itemLink)
    local warningMessage = "Tou have one minute to roll on " .. itemLink .. "."
    SendChatMessage(warningMessage, "RAID_WARNING") -- Is this how raid warnings are called? Check later.
    print(warningMessage)

    -- Table for current roll session.
    self.currentRollSession = {
        itemLink = itemLink,
        highestRoll = 0,
        winner = nil,
    }

    -- Listening for rolls
    self.frame:RegisterEvent("CHAT_MSG_SYSTEM")

    -- 60 second timer for rolls
    -- Make user defined later
    C_Timer.After(60, function()
        ThanksDuka:EndRollSession()
    end)
end

-- Handle incoming system messages for roll results
function ThanksDuka:HandleRollMessage(message)
    -- Normal /roll command, addon is expecting "PlayerName rolls [x] (1-100)"
    local playerName, roll = message:match("^(%S+) rolls (%d+)")
    if playerName and roll then
        roll = tonumber(roll)
        if roll > self.currentRollSession.highestRoll then
            self.currentRollSession.highestRoll = roll
            self.currentRollSession.winner = playerName
        end
    end
end

function ThanksDuka:EndRollSession()
    self.frame:UnredisterEvent("CHAT_MSG_SYSTEM")
    if self.currentRollSession then
        local winner = self.currentRollSession.winner or "No one"
        local resultMessage = "Roll session ended for " .. self.currentRollSession.itemLink ..
                                ". Winner: " .. winner .. " with roll " ..self.currentRollSession.highestRoll .. "."
        SendChatMessage(resultMessage, "RAIN_WARNING")
        print(resultMessage)
        self.currentRollSession = nil
        if self.rollFrame then
            self.rollFrame:Hide()
        end
    end
end

-- Extending Main Event Handler
local original_OnEvent = ThanksDuka.frame:GetScript("OnEvent")
ThanksDuka.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        ThanksDuka:HandleLootEvent(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ThanksDuka:ResetLootDistribution()
    elseif event == "CHAT_MSG_SYSTEM" and ThanksDuka.currentRollSession then
        local message = ...
        ThanksDuka:HandleRollMessage(message)
    end
    if original_OnEvent then 
        original_OnEvent(self, event, ...)
    end
end)