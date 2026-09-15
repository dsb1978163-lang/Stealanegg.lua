--[================================================================]--
--     NITRO STEAL AN EGG - COMPACT MODULAR QA SUITE                --
--     Brand: NITRO | Version: 3.0.0-Compact                        --
--[================================================================]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- 1. CONFIGURATION & STATE
--------------------------------------------------------------------------------
local Config = {
    MasterEnable = false,
    GuiKeybind = Enum.KeyCode.RightControl,
    
    Folders = {
        Eggs = Workspace:WaitForChild("Eggs", 5) or Workspace,
        Treadmills = Workspace:WaitForChild("Treadmills", 5) or Workspace,
    },
    
    Remotes = {
        StealAction = ReplicatedStorage:FindFirstChild("StealEggRemote") or Instance.new("RemoteEvent"),
        TrainAction = ReplicatedStorage:FindFirstChild("TrainRemote") or Instance.new("RemoteEvent"),
    },
    
    StealDelay = 0.8,
    
    Filters = {
        Areas = {"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"},
        Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"},
        MinKG = 0,
        MaxKG = 999999999,
    },
    
    Automation = {
        TargetPriority = "HighestKG", -- "HighestKG" or "ClosestDistance"
    }
}

local Runtime = {
    CurrentState = "IDLE",
    CurrentAction = "Waiting for activation...",
    CurrentTarget = nil,
    LastStealTick = 0,
    IsMinimized = false,
}

--------------------------------------------------------------------------------
-- 2. ROBUST SCANNING & FILTERING LOGIC
--------------------------------------------------------------------------------
local function TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function EvaluateEgg(egg)
    if not egg or not egg.Parent then return false end
    local area = egg:GetAttribute("Area") or "Titan Temple"
    local rarity = egg:GetAttribute("Rarity") or "Common"
    local kg = egg:GetAttribute("KG") or 10
    
    if not TableContains(Config.Filters.Areas, area) then return false end
    if not TableContains(Config.Filters.Rarities, rarity) then return false end
    if kg < Config.Filters.MinKG or kg > Config.Filters.MaxKG then return false end
    return true
end

local function FindBestEligibleEgg()
    local eggsFolder = Config.Folders.Eggs
    if not eggsFolder then return nil end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local bestEgg = nil
    local bestScore = -math.huge
    
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        if (egg:IsA("Model") or egg:IsA("BasePart")) and EvaluateEgg(egg) then
            local pos = egg:IsA("Model") and (egg.PrimaryPart and egg.PrimaryPart.Position or egg:GetPivot().Position) or egg.Position
            local distance = hrp and (hrp.Position - pos).Magnitude or 0
            local kg = egg:GetAttribute("KG") or 10
            
            local score = Config.Automation.TargetPriority == "HighestKG" and kg or (-distance)
            if score > bestScore then
                bestScore = score
                bestEgg = egg
            end
        end
    end
    return bestEgg
end

local function MoveToPosition(pos)
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid and pos then
        humanoid:MoveTo(pos)
    end
end

local function FindNearestTreadmill()
    local folder = Config.Folders.Treadmills
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not folder or not hrp then return nil end
    local nearest, shortest = nil, math.huge
    for _, t in ipairs(folder:GetChildren()) do
        local pos = t:IsA("Model") and t:GetPivot().Position or (t:IsA("BasePart") and t.Position)
        if pos then
            local dist = (hrp.Position - pos).Magnitude
            if dist < shortest then shortest = dist; nearest = t end
        end
    end
    return nearest
end

--------------------------------------------------------------------------------
-- 3. POLISHED COMPACT MODERN UI DESIGN
--------------------------------------------------------------------------------
local parentTarget = (pcall(function() return CoreGui end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")

if parentTarget:FindFirstChild("NitroCompactUI") then
    parentTarget.NitroCompactUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NitroCompactUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentTarget

-- Compact Main Window (Small, Clean)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 420)
MainFrame.Position = UDim2.new(0.5, -170, 0.4, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(45, 45, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ NITRO | AUTO STEAL"
TitleLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Window Controls (Minimize & Close)
local function createHeaderBtn(text, color, xOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Position = UDim2.new(1, xOffset, 0.5, -12)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = Header
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local CloseBtn = createHeaderBtn("✕", Color3.fromRGB(200, 50, 50), -32)
local MinBtn = createHeaderBtn("🗕", Color3.fromRGB(200, 160, 40), -60)

-- Minimized Reopen Pill
local ReopenBtn = Instance.new("TextButton")
ReopenBtn.Name = "ReopenPill"
ReopenBtn.Size = UDim2.new(0, 120, 0, 36)
ReopenBtn.Position = UDim2.new(0.02, 0, 0.05, 0)
ReopenBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ReopenBtn.Text = "⚡ NITRO (Open)"
ReopenBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
ReopenBtn.Font = Enum.Font.GothamBold
ReopenBtn.TextSize = 12
ReopenBtn.Visible = false
ReopenBtn.Parent = ScreenGui
Instance.new("UICorner", ReopenBtn).CornerRadius = UDim.new(0, 8)
local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = Color3.fromRGB(255, 90, 90)
ReopenStroke.Thickness = 1.5
ReopenStroke.Parent = ReopenBtn

-- Scrollable Content Container (Accordion / Dropdown layout)
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -56)
Container.Position = UDim2.new(0, 8, 0, 48)
Container.BackgroundTransparency = 1
Container.CanvasSize = UDim2.new(0, 0, 0, 680)
Container.ScrollBarThickness = 3
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 8)
UIList.Parent = Container

-- Helper to create styled section headers/dropdowns
local function createSection(titleText)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 32)
    section.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    section.Parent = Container
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = "▼ " .. titleText
    lbl.TextColor3 = Color3.fromRGB(220, 220, 240)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = section
    return section
end

--------------------------------------------------------------------------------
-- 4. BUILDING UI SECTIONS & CONTROLS
--------------------------------------------------------------------------------

-- SECTION: MAIN AUTOMATION CONTROL
createSection("Master Automation")
local mainControlFrame = Instance.new("Frame")
mainControlFrame.Size = UDim2.new(1, 0, 0, 80)
mainControlFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
mainControlFrame.Parent = Container
Instance.new("UICorner", mainControlFrame).CornerRadius = UDim.new(0, 6)

local masterToggle = Instance.new("TextButton")
masterToggle.Size = UDim2.new(1, -16, 0, 32)
masterToggle.Position = UDim2.new(0, 8, 0, 8)
masterToggle.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
masterToggle.Text = "Auto Steal: OFF"
masterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggle.Font = Enum.Font.GothamBold
masterToggle.TextSize = 12
masterToggle.Parent = mainControlFrame
Instance.new("UICorner", masterToggle).CornerRadius = UDim.new(0, 5)

masterToggle.MouseButton1Click:Connect(function()
    Config.MasterEnable = not Config.MasterEnable
    masterToggle.BackgroundColor3 = Config.MasterEnable and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 50, 50)
    masterToggle.Text = Config.MasterEnable and "Auto Steal: ACTIVE" or "Auto Steal: OFF"
end)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 24)
statusLbl.Position = UDim2.new(0, 8, 0, 46)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.GothamSemibold
statusLbl.Text = "Status: IDLE"
statusLbl.TextColor3 = Color3.fromRGB(140, 255, 160)
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = mainControlFrame


-- SECTION: WORLD / AREA FILTERS
createSection("Target World Filters")
local areasFrame = Instance.new("Frame")
areasFrame.Size = UDim2.new(1, 0, 0, 140)
areasFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
areasFrame.Parent = Container
Instance.new("UICorner", areasFrame).CornerRadius = UDim.new(0, 6)

local areaList = Instance.new("UIListLayout")
areaList.Padding = UDim.new(0, 3)
areaList.Parent = areasFrame

for _, areaName in ipairs({"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 20)
    btn.Position = UDim2.new(0, 5, 0, 0)
    btn.BackgroundColor3 = TableContains(Config.Filters.Areas, areaName) and Color3.fromRGB(50, 120, 80) or Color3.fromRGB(35, 35, 48)
    btn.Text = " [✓] " .. areaName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = areasFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        if TableContains(Config.Filters.Areas, areaName) then
            for i, v in ipairs(Config.Filters.Areas) do if v == areaName then table.remove(Config.Filters.Areas, i) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
            btn.Text = " [  ] " .. areaName
        else
            table.insert(Config.Filters.Areas, areaName)
            btn.BackgroundColor3 = Color3.fromRGB(50, 120, 80)
            btn.Text = " [✓] " .. areaName
        end
    end)
end


-- SECTION: RARITY FILTERS
createSection("Rarity Filters")
local rarityFrame = Instance.new("Frame")
rarityFrame.Size = UDim2.new(1, 0, 0, 140)
rarityFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
rarityFrame.Parent = Container
Instance.new("UICorner", rarityFrame).CornerRadius = UDim.new(0, 6)

local rarityList = Instance.new("UIListLayout")
rarityList.Padding = UDim.new(0, 3)
rarityList.Parent = rarityFrame

for _, rarityName in ipairs({"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 20)
    btn.BackgroundColor3 = TableContains(Config.Filters.Rarities, rarityName) and Color3.fromRGB(120, 80, 50) or Color3.fromRGB(35, 35, 48)
    btn.Text = " [✓] " .. rarityName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = rarityFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        if TableContains(Config.Filters.Rarities, rarityName) then
            for i, v in ipairs(Config.Filters.Rarities) do if v == rarityName then table.remove(Config.Filters.Rarities, i) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
            btn.Text = " [  ] " .. rarityName
        else
            table.insert(Config.Filters.Rarities, rarityName)
            btn.BackgroundColor3 = Color3.fromRGB(120, 80, 50)
            btn.Text = " [✓] " .. rarityName
        end
    end)
end


-- SECTION: AUTOMATION SETTINGS
createSection("Automation Behavior")
local settingsFrame = Instance.new("Frame")
settingsFrame.Size = UDim2.new(1, 0, 0, 50)
settingsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
settingsFrame.Parent = Container
Instance.new("UICorner", settingsFrame).CornerRadius = UDim.new(0, 6)

local priorityBtn = Instance.new("TextButton")
priorityBtn.Size = UDim2.new(1, -16, 0, 32)
priorityBtn.Position = UDim2.new(0, 8, 0, 9)
priorityBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
priorityBtn.Text = "Priority Mode: Highest KG"
priorityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
priorityBtn.Font = Enum.Font.GothamSemibold
priorityBtn.TextSize = 11
priorityBtn.Parent = settingsFrame
Instance.new("UICorner", priorityBtn).CornerRadius = UDim.new(0, 5)

priorityBtn.MouseButton1Click:Connect(function()
    if Config.Automation.TargetPriority == "HighestKG" then
        Config.Automation.TargetPriority = "ClosestDistance"
        priorityBtn.Text = "Priority Mode: Closest Distance"
    else
        Config.Automation.TargetPriority = "HighestKG"
        priorityBtn.Text = "Priority Mode: Highest KG"
    end
end)


--------------------------------------------------------------------------------
-- 5. DRAGGING & WINDOW CONTROLS LOGIC
--------------------------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
MinBtn.MouseButton1Click:Connect(function()
    Runtime.IsMinimized = true
    TweenService:Create(MainFrame, TweenInfo.new(0.25), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(0.25)
    MainFrame.Visible = false
    ReopenBtn.Visible = true
end)
ReopenBtn.MouseButton1Click:Connect(function()
    Runtime.IsMinimized = false
    ReopenBtn.Visible = false
    MainFrame.Visible = true
    TweenService:Create(MainFrame, TweenInfo.new(0.25), {Size = UDim2.new(0, 340, 0, 420)}):Play()
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Config.GuiKeybind then
        Runtime.IsMinimized = not Runtime.IsMinimized
        MainFrame.Visible = not Runtime.IsMinimized
        ReopenBtn.Visible = Runtime.IsMinimized
    end
end)


--------------------------------------------------------------------------------
-- 6. STRICT PRIORITY AUTOMATION LOOP (FIXED LOGIC)
--------------------------------------------------------------------------------
RunService.Stepped:Connect(function()
    if not Config.MasterEnable then
        Runtime.CurrentState = "IDLE"
        Runtime.CurrentAction = "Master Switch Off"
        statusLbl.Text = "Status: IDLE (Paused)"
        return
    end
    
    -- STEP 1: Scan for eligible eggs based on user filters
    Runtime.CurrentState = "SCANNING"
    Runtime.CurrentAction = "Searching selected worlds for eligible eggs..."
    statusLbl.Text = "Status: Scanning Worlds..."
    
    local targetEgg = FindBestEligibleEgg()
    
    if targetEgg then
        -- STEP 2: An eligible egg exists! Prioritize stealing it.
        Runtime.CurrentTarget = targetEgg
        local pos = targetEgg:IsA("Model") and (targetEgg.PrimaryPart and targetEgg.PrimaryPart.Position or targetEgg:GetPivot().Position) or targetEgg.Position
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist = hrp and (hrp.Position - pos).Magnitude or 999
        
        if dist > 7 then
            Runtime.CurrentState = "GOING_TO_EGG"
            Runtime.CurrentAction = "Going to Egg: " .. targetEgg.Name
            statusLbl.Text = "Status: Going to Egg (" .. math.floor(dist) .. " studs)"
            MoveToPosition(pos)
        else
            Runtime.CurrentState = "STEALING"
            Runtime.CurrentAction = "Stealing Egg: " .. targetEgg.Name
            statusLbl.Text = "Status: Actively Stealing Egg!"
            
            if tick() - Runtime.LastStealTick > Config.StealDelay then
                Runtime.LastStealTick = tick()
                Config.Remotes.StealAction:FireServer(targetEgg)
            end
        end
    else
        -- STEP 3: NO eligible eggs remain. ONLY NOW fallback to treadmill training!
        Runtime.CurrentTarget = nil
        Runtime.CurrentState = "TREADMILLING"
        Runtime.CurrentAction = "No eggs found - Training on Treadmill (Fallback)"
        statusLbl.Text = "Status: Treadmilling (Fallback)"
        
        local treadmill = FindNearestTreadmill()
        if treadmill then
            local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
            MoveToPosition(tPos)
            Config.Remotes.TrainAction:FireServer(treadmill)
        end
    end
end)

print("[NITRO Compact QA Suite 3.0 successfully loaded]")
