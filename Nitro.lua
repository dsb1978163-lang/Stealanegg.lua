--[================================================================]--
--     NITRO STEAL AN EGG TESTING & QA SUITE (ROBLOX STUDIO)        --
--     Brand: NITRO | Version: 1.0.0-QA                             --
--[================================================================]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- 1. CONFIGURATION & ASSUMPTION MAPPING
--------------------------------------------------------------------------------
-- Note: Adjust these instance paths to match your exact Roblox Studio hierarchy.
local Config = {
    MasterEnable = false,
    GuiKeybind = Enum.KeyCode.RightControl,
    
    -- Paths (Assumed Folders - Easily Configurable)
    Folders = {
        Eggs = Workspace:WaitForChild("Eggs", 5) or Workspace,
        Treadmills = Workspace:WaitForChild("Treadmills", 5) or Workspace,
        SpawnLocations = Workspace:WaitForChild("SpawnLocations", 5) or Workspace,
    },
    
    -- Remote / Interaction Names (Assumed - Configure to match your remote names)
    Remotes = {
        StealAction = ReplicatedStorage:FindFirstChild("StealEggRemote") 
            or Instance.new("RemoteEvent"), -- Fallback dummy if not found
        TrainAction = ReplicatedStorage:FindFirstChild("TrainRemote") 
            or Instance.new("RemoteEvent"),
    },
    
    -- Timing Delays (Seconds)
    StealDelay = 1.0,
    DetectionInterval = 0.5,
    
    -- Filters (Multi-select / Ranges)
    Filters = {
        Areas = {"Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano", "Abyss"}, -- Default: All
        Rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine"},
        MinKG = 0,
        MaxKG = 999999999,
    },
    
    TrainingBehavior = "AutomaticFallback", -- Options: "AutomaticFallback", "Disabled"
    TargetPriority = "HighestKG",         -- Options: "HighestKG", "ClosestDistance", "Rarest"
}

--------------------------------------------------------------------------------
-- 2. STATE MACHINE & RUNTIME VARIABLES
--------------------------------------------------------------------------------
local States = {
    IDLE = "IDLE",
    SCANNING = "SCANNING",
    TARGET_FOUND = "TARGET_FOUND",
    MOVING = "MOVING",
    INTERACTING = "INTERACTING",
    COMPLETE = "COMPLETE",
    TRAINING = "TRAINING",
    WAITING = "WAITING",
    NO_TARGET = "NO_TARGET"
}

local Runtime = {
    CurrentState = States.IDLE,
    CurrentTarget = nil,
    CurrentAction = "Idle",
    DetectedEggsCache = {},
    LastStealTick = 0,
    IsGuiOpen = true,
}

--------------------------------------------------------------------------------
-- 3. FILTER & EGG EVALUATION LOGIC
--------------------------------------------------------------------------------
local function TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function EvaluateEgg(eggModel)
    -- Expects attributes or values on the Egg model: .Area, .Rarity, .KG (Weight)
    local area = eggModel:GetAttribute("Area") or "Forest"
    local rarity = eggModel:GetAttribute("Rarity") or "Common"
    local kg = eggModel:GetAttribute("KG") or 10
    
    -- Check Area Filter
    if not TableContains(Config.Filters.Areas, area) then
        return false, "Rejected: Wrong Area"
    end
    
    -- Check Rarity Filter
    if not TableContains(Config.Filters.Rarities, rarity) then
        return false, "Rejected: Rarity Filter"
    end
    
    -- Check Min KG Filter
    if kg < Config.Filters.MinKG then
        return false, "Rejected: Below Minimum KG"
    end
    
    -- Check Max KG Filter
    if kg > Config.Filters.MaxKG then
        return false, "Rejected: Above Maximum KG"
    end
    
    return true, "Eligible"
end

local function ScanForEligibleEggs()
    local bestTarget = nil
    local bestScore = -1
    local cache = {}
    
    local eggsFolder = Config.Folders.Eggs
    if not eggsFolder then return nil, cache end
    
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            local pos = egg:IsA("Model") and (egg.PrimaryPart and egg.PrimaryPart.Position or egg:GetPivot().Position) or egg.Position
            local distance = hrp and (hrp.Position - pos).Magnitude or 0
            
            local area = egg:GetAttribute("Area") or "Forest"
            local rarity = egg:GetAttribute("Rarity") or "Common"
            local kg = egg:GetAttribute("KG") or 10
            
            local isEligible, reason = EvaluateEgg(egg)
            
            table.insert(cache, {
                Instance = egg,
                Name = egg.Name,
                Area = area,
                Rarity = rarity,
                KG = kg,
                Distance = math.floor(distance),
                Eligible = isEligible,
                Reason = reason
            })
            
            if isEligible then
                -- Target Selection Algorithm based on priority
                local score = 0
                if Config.TargetPriority == "HighestKG" then
                    score = kg
                elseif Config.TargetPriority == "ClosestDistance" then
                    score = 10000 - distance
                elseif Config.TargetPriority == "Rarest" then
                    score = kg * 2 -- simplified rank scale for testing
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = egg
                end
            end
        end
    end
    
    Runtime.DetectedEggsCache = cache
    return bestTarget, cache
end

--------------------------------------------------------------------------------
-- 4. MOVEMENT & INTERACTION UTILITIES
--------------------------------------------------------------------------------
local function MoveToPosition(targetPosition)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:MoveTo(targetPosition)
    end
end

local function FindNearestTreadmill()
    local treadmillFolder = Config.Folders.Treadmills
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not treadmillFolder or not hrp then return nil end
    
    local nearest = nil
    local shortestDist = math.huge
    
    for _, treadmill in ipairs(treadmillFolder:GetChildren()) do
        local pos = treadmill:IsA("Model") and treadmill:GetPivot().Position or (treadmill:IsA("BasePart") and treadmill.Position)
        if pos then
            local dist = (hrp.Position - pos).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearest = treadmill
            end
        end
    end
    return nearest
end

--------------------------------------------------------------------------------
-- 5. POLISHED CUSTOM NITRO GUI
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NitroStealAnEggQA"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- Main Container Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 620, 0, 420)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "NITRO | STEAL AN EGG TESTING SUITE"
TitleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Close / Minimize Buttons
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 7)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 12
CloseButton.Parent = Header
Instance.new("UICorner", CloseButton).CornerRadius = UDim.new(0, 6)

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Sidebar Navigation Tabs
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 130, 1, -55)
TabContainer.Position = UDim2.new(0, 10, 0, 50)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = TabContainer

local tabs = {"MAIN", "FILTERS", "AUTOMATION", "DEBUG", "SETTINGS", "ABOUT"}
local contentPages = {}

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -155, 1, -55)
ContentFrame.Position = UDim2.new(0, 145, 0, 50)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

for i, tabName in ipairs(tabs) do
    -- Tab Selection Button
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, 0, 0, 35)
    tabBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(40, 40, 55) or Color3.fromRGB(25, 25, 35)
    tabBtn.Text = tabName
    tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 12
    tabBtn.Parent = TabContainer
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)
    
    -- Corresponding Page Frame
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = (i == 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 500)
    page.ScrollBarThickness = 4
    page.Parent = ContentFrame
    contentPages[tabName] = page
    
    tabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(contentPages) do p.Visible = false end
        page.Visible = true
        for _, b in ipairs(TabContainer:GetChildren()) do
            if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(25, 25, 35) end
        end
        tabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    end)
end

--------------------------------------------------------------------------------
-- 6. POPULATE TAB CONTENTS
--------------------------------------------------------------------------------

-- MAIN TAB
local mainPage = contentPages["MAIN"]
local function createLabel(parent, text, pos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 25)
    lbl.Position = pos
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

createLabel(mainPage, "Master Enable Automation:", UDim2.new(0, 0, 0, 10))
local masterToggleBtn = Instance.new("TextButton")
masterToggleBtn.Size = UDim2.new(0, 100, 0, 28)
masterToggleBtn.Position = UDim2.new(0, 200, 0, 10)
masterToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
masterToggleBtn.Text = "OFF"
masterToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggleBtn.Font = Enum.Font.GothamBold
masterToggleBtn.TextSize = 12
masterToggleBtn.Parent = mainPage
Instance.new("UICorner", masterToggleBtn).CornerRadius = UDim.new(0, 6)

masterToggleBtn.MouseButton1Click:Connect(function()
    Config.MasterEnable = not Config.MasterEnable
    masterToggleBtn.BackgroundColor3 = Config.MasterEnable and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
    masterToggleBtn.Text = Config.MasterEnable and "ACTIVE" or "OFF"
end)

local statusTargetLbl = createLabel(mainPage, "Current Target: None", UDim2.new(0, 0, 0, 50))
local statusActionLbl = createLabel(mainPage, "Current Action: Idle", UDim2.new(0, 0, 0, 80))
local statusStateLbl = createLabel(mainPage, "Current State: IDLE", UDim2.new(0, 0, 0, 110))

-- DEBUG TAB
local debugPage = contentPages["DEBUG"]
local debugLogLabel = Instance.new("TextLabel")
debugLogLabel.Size = UDim2.new(1, 0, 0, 450)
debugLogLabel.Position = UDim2.new(0, 0, 0, 0)
debugLogLabel.BackgroundTransparency = 1
debugLogLabel.Font = Enum.Font.Code
debugLogLabel.Text = "Awaiting scan loop..."
debugLogLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
debugLogLabel.TextSize = 11
debugLogLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLogLabel.TextYAlignment = Enum.TextYAlignment.Top
debugLogLabel.TextWrapped = true
debugLogLabel.Parent = debugPage

-- ABOUT TAB
local aboutPage = contentPages["ABOUT"]
local aboutText = Instance.new("TextLabel")
aboutText.Size = UDim2.new(1, 0, 1, 0)
aboutText.BackgroundTransparency = TestTransparency or 1
aboutText.Font = Enum.Font.Gotham
aboutText.Text = "NITRO Steal An Egg QA Testing Suite\nBrand: NITRO\nVersion: 1.0.0-QA\n\nDesigned for internal studio validation, automated egg filtering mechanics, and fallback treadmill training sequence verification."
aboutText.TextColor3 = Color3.fromRGB(220, 220, 220)
aboutText.TextSize = 13
aboutText.TextWrapped = true
aboutText.TextXAlignment = Enum.TextXAlignment.Left
aboutText.TextYAlignment = Enum.TextYAlignment.Top
aboutText.Parent = aboutPage

--------------------------------------------------------------------------------
-- 7. AUTOMATION LOOP (STATE MACHINE)
--------------------------------------------------------------------------------
RunService.Stepped:Connect(function()
    if not Config.MasterEnable then
        Runtime.CurrentState = States.IDLE
        Runtime.CurrentAction = "Master Switch Off"
        statusStateLbl.Text = "Current State: " .. Runtime.CurrentState
        statusActionLbl.Text = "Current Action: " .. Runtime.CurrentAction
        return
    end
    
    -- State: Scanning
    Runtime.CurrentState = States.SCANNING
    Runtime.CurrentAction = "Scanning environment for valid eggs..."
    
    local targetEgg, cache = ScanForEligibleEggs()
    
    -- Update Debug readout
    local debugTextBuilder = "--- NITRO QA DEBUG CONSOLE ---\n"
    for _, info in ipairs(cache) do
        debugTextBuilder = string.format("%s\n[Egg: %s]\n Area: %s | Rarity: %s | KG: %s\n Dist: %s | Eligible: %s\n Reason: %s\n",
            debugTextBuilder, info.Name, info.Area, info.Rarity, tostring(info.KG), tostring(info.Distance), tostring(info.Eligible), info.Reason)
    end
    debugLogLabel.Text = debugTextBuilder
    
    if targetEgg then
        Runtime.CurrentTarget = targetEgg
        Runtime.CurrentState = States.TARGET_FOUND
        Runtime.CurrentAction = "Target Acquired: " .. targetEgg.Name
        
        -- State: Moving
        Runtime.CurrentState = States.MOVING
        local targetPos = targetEgg:IsA("Model") and targetEgg:GetPivot().Position or targetEgg.Position
        MoveToPosition(targetPos)
        
        -- Check distance to interact
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - targetPos).Magnitude < 8 then
            Runtime.CurrentState = States.INTERACTING
            Runtime.CurrentAction = "Executing Steal Interaction..."
            
            if tick() - Runtime.LastStealTick > Config.StealDelay then
                Runtime.LastStealTick = tick()
                -- Trigger simulated legitimate game interaction
                Config.Remotes.StealAction:FireServer(targetEgg)
            end
        end
    else
        -- Fallback: Auto Train on Treadmill when no eggs match filters
        Runtime.CurrentTarget = nil
        if Config.TrainingBehavior == "AutomaticFallback" then
            Runtime.CurrentState = States.GOING_TO_TREADMILL
            Runtime.CurrentAction = "No targets found. Moving to Treadmill."
            
            local treadmill = FindNearestTreadmill()
            if treadmill then
                local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
                MoveToPosition(tPos)
                
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - tPos).Magnitude < 6 then
                    Runtime.CurrentState = States.TRAINING
                    Runtime.CurrentAction = "Training on Treadmill..."
                    Config.Remotes.TrainAction:FireServer(treadmill)
                end
            end
        else
            Runtime.CurrentState = States.NO_TARGET
            Runtime.CurrentAction = "Waiting for eligible eggs..."
        end
    end
    
    -- Refresh UI Readouts
    statusTargetLbl.Text = "Current Target: " .. (Runtime.CurrentTarget and Runtime.CurrentTarget.Name or "None")
    statusActionLbl.Text = "Current Action: " .. Runtime.CurrentAction
    statusStateLbl.Text = "Current State: " .. Runtime.CurrentState
end)

-- Keybind Toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Config.GuiKeybind then
        Runtime.IsGuiOpen = not Runtime.IsGuiOpen
        MainFrame.Visible = Runtime.IsGuiOpen
    end
end)

print("[NITRO QA Suite initialized successfully for Steal an Egg]")
