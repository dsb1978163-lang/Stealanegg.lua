--[================================================================]--
--     NITRO STEAL AN EGG - PROFESSIONAL ACCORDION SUITE v4.0       --
--     Brand: NITRO | Clean Modular Architecture                    --
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
-- 1. CONFIGURATION & STATE MANAGEMENT
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
    
    StealCooldown = 0.75,
    
    Filters = {
        Areas = {"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"},
        Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"},
        MinKG = 0,
        MaxKG = 999999999,
    },
    
    Automation = {
        Priority = "HighestKG", -- "HighestKG" or "ClosestDistance"
    }
}

local Runtime = {
    State = "Idle",
    TargetEgg = nil,
    TargetTreadmill = nil,
    LastStealTick = 0,
    IsMinimized = false,
}

--------------------------------------------------------------------------------
-- 2. SCANNING & INTELLIGENT ROUTING LOGIC
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
            
            local score = Config.Automation.Priority == "HighestKG" and kg or (-distance)
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
-- 3. COMPACT MODERN UI DESIGN & ACCORDIONS
--------------------------------------------------------------------------------
local parentTarget = (pcall(function() return CoreGui end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")
if parentTarget:FindFirstChild("NitroCompactSuite") then
    parentTarget.NitroCompactSuite:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NitroCompactSuite"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentTarget

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 460)
MainFrame.Position = UDim2.new(0.5, -170, 0.4, -230)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 50, 75)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ NITRO | STEAL AN EGG"
TitleLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Window Controls (Minimize, Close)
local function createHeaderButton(text, color, xOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 26, 0, 26)
    btn.Position = UDim2.new(1, xOffset, 0.5, -13)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = Header
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local CloseBtn = createHeaderButton("✕", Color3.fromRGB(200, 50, 50), -34)
local MinBtn = createHeaderButton("🗕", Color3.fromRGB(200, 160, 40), -66)

-- Reopen Pill
local ReopenBtn = Instance.new("TextButton")
ReopenBtn.Name = "ReopenPill"
ReopenBtn.Size = UDim2.new(0, 120, 0, 36)
ReopenBtn.Position = UDim2.new(0.02, 0, 0.05, 0)
ReopenBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
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

-- Scrollable Body Container
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -56)
Container.Position = UDim2.new(0, 8, 0, 48)
Container.BackgroundTransparency = 1
Container.CanvasSize = UDim2.new(0, 0, 0, 500)
Container.ScrollBarThickness = 3
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 6)
UIList.Parent = Container

--------------------------------------------------------------------------------
-- 4. ACCORDION DROPDOWN BUILDER
--------------------------------------------------------------------------------
local function createAccordion(titleText, expandedHeight)
    local wrapper = Instance.new("Frame")
    wrapper.Size = UDim2.new(1, 0, 0, 32)
    wrapper.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    wrapper.ClipsDescendants = true
    wrapper.Parent = Container
    Instance.new("UICorner", wrapper).CornerRadius = UDim.new(0, 6)
    
    local headerBtn = Instance.new("TextButton")
    headerBtn.Size = UDim2.new(1, 0, 0, 32)
    headerBtn.BackgroundTransparency = 1
    headerBtn.Font = Enum.Font.GothamBold
    headerBtn.Text = "  ▼  " .. titleText
    headerBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    headerBtn.TextSize = 12
    headerBtn.TextXAlignment = Enum.TextXAlignment.Left
    headerBtn.Parent = wrapper
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -16, 0, expandedHeight)
    contentFrame.Position = UDim2.new(0, 8, 0, 36)
    contentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    contentFrame.Parent = wrapper
    Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 6)
    
    local isOpen = false
    headerBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        local targetH = isOpen and (expandedHeight + 42) or 32
        TweenService:Create(wrapper, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
        headerBtn.Text = isOpen ? "  ▲  " .. titleText : "  ▼  " .. titleText
    end)
    
    return contentFrame
end

--------------------------------------------------------------------------------
-- 5. POPULATING SECTIONS & CONTROLS
--------------------------------------------------------------------------------

-- A. Auto Steal Control Panel
local autoAcc = createAccordion("Auto Steal & Status", 85)
local masterToggle = Instance.new("TextButton")
masterToggle.Size = UDim2.new(1, -16, 0, 32)
masterToggle.Position = UDim2.new(0, 8, 0, 8)
masterToggle.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
masterToggle.Text = "Auto Steal: OFF"
masterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggle.Font = Enum.Font.GothamBold
masterToggle.TextSize = 12
masterToggle.Parent = autoAcc
Instance.new("UICorner", masterToggle).CornerRadius = UDim.new(0, 5)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 24)
statusLbl.Position = UDim2.new(0, 8, 0, 48)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.GothamSemibold
statusLbl.Text = "Status: Idle"
statusLbl.TextColor3 = Color3.fromRGB(140, 255, 160)
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = autoAcc

masterToggle.MouseButton1Click:Connect(function()
    Config.MasterEnable = not Config.MasterEnable
    masterToggle.BackgroundColor3 = Config.MasterEnable and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 50, 50)
    masterToggle.Text = Config.MasterEnable and "Auto Steal: ACTIVE" or "Auto Steal: OFF"
end)


-- B. Target World Filters
local worldsAcc = createAccordion("Target Worlds Filter", 155)
local wLayout = Instance.new("UIListLayout")
wLayout.Padding = UDim.new(0, 3)
wLayout.Parent = worldsAcc

for _, areaName in ipairs({"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 22)
    btn.Position = UDim2.new(0, 4, 0, 4)
    btn.BackgroundColor3 = TableContains(Config.Filters.Areas, areaName) and Color3.fromRGB(50, 120, 80) or Color3.fromRGB(35, 35, 48)
    btn.Text = " [✓] " .. areaName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = worldsAcc
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


-- C. Rarity Filters
local rarityAcc = createAccordion("Rarity Filters", 155)
local rLayout = Instance.new("UIListLayout")
rLayout.Padding = UDim.new(0, 3)
rLayout.Parent = rarityAcc

for _, rarityName in ipairs({"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 22)
    btn.BackgroundColor3 = TableContains(Config.Filters.Rarities, rarityName) and Color3.fromRGB(120, 80, 50) or Color3.fromRGB(35, 35, 48)
    btn.Text = " [✓] " .. rarityName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = rarityAcc
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


-- D. Automation Settings & Priority
local settingsAcc = createAccordion("Automation & Priority", 50)
local priorityBtn = Instance.new("TextButton")
priorityBtn.Size = UDim2.new(1, -16, 0, 32)
priorityBtn.Position = UDim2.new(0, 8, 0, 9)
priorityBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
priorityBtn.Text = "Priority Mode: Highest KG"
priorityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
priorityBtn.Font = Enum.Font.GothamSemibold
priorityBtn.TextSize = 11
priorityBtn.Parent = settingsAcc
Instance.new("UICorner", priorityBtn).CornerRadius = UDim.new(0, 5)

priorityBtn.MouseButton1Click:Connect(function()
    if Config.Automation.Priority == "HighestKG" then
        Config.Automation.Priority = "ClosestDistance"
        priorityBtn.Text = "Priority Mode: Closest Distance"
    else
        Config.Automation.Priority = "HighestKG"
        priorityBtn.Text = "Priority Mode: Highest KG"
    end
end)

--------------------------------------------------------------------------------
-- 6. WINDOW DRAGGING & CONTROLS
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
    TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(0.2)
    MainFrame.Visible = false
    ReopenBtn.Visible = true
end)
ReopenBtn.MouseButton1Click:Connect(function()
    Runtime.IsMinimized = false
    ReopenBtn.Visible = false
    MainFrame.Visible = true
    TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 340, 0, 460)}):Play()
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Config.GuiKeybind then
        Runtime.IsMinimized = not Runtime.IsMinimized
        MainFrame.Visible = not Runtime.IsMinimized
        ReopenBtn.Visible = Runtime.IsMinimized
    end
end)


--------------------------------------------------------------------------------
-- 7. STRICT PRIORITY ENGINE (EGGS FIRST, TREADMILL AS TRUE FALLBACK)
--------------------------------------------------------------------------------
RunService.Stepped:Connect(function()
    if not Config.MasterEnable then
        Runtime.State = "Idle"
        statusLbl.Text = "Status: Idle (Paused)"
        return
    end
    
    -- Step 1: Scan selected worlds for eligible eggs
    Runtime.State = "Scanning..."
    statusLbl.Text = "Status: Scanning..."
    
    local targetEgg = FindBestEligibleEgg()
    
    if targetEgg then
        -- Step 2: Eligible egg found! Go and steal it.
        Runtime.TargetEgg = targetEgg
        local pos = targetEgg:IsA("Model") and (targetEgg.PrimaryPart and targetEgg.PrimaryPart.Position or targetEgg:GetPivot().Position) or targetEgg.Position
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist = hrp and (hrp.Position - pos).Magnitude or 999
        
        if dist > 7 then
            Runtime.State = "Going to Egg"
            statusLbl.Text = "Status: Going to Egg (" .. math.floor(dist) .. " studs)"
            MoveToPosition(pos)
        else
            Runtime.State = "Stealing..."
            statusLbl.Text = "Status: Stealing..."
            
            if tick() - Runtime.LastStealTick > Config.StealCooldown then
                Runtime.LastStealTick = tick()
                Config.Remotes.StealAction:FireServer(targetEgg)
            end
        end
    else
        -- Step 3: Zero eligible eggs remaining across selected worlds. ONLY NOW fallback to treadmill!
        Runtime.TargetEgg = nil
        Runtime.State = "No Eggs Found"
        statusLbl.Text = "Status: No Eggs Found"
        
        local treadmill = FindNearestTreadmill()
        if treadmill then
            local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = hrp and (hrp.Position - tPos).Magnitude or 999
            
            if dist > 6 then
                Runtime.State = "Going to Treadmill"
                statusLbl.Text = "Status: Going to Treadmill"
                MoveToPosition(tPos)
            else
                Runtime.State = "Treadmilling"
                statusLbl.Text = "Status: Treadmilling"
                Config.Remotes.TrainAction:FireServer(treadmill)
            end
        end
    end
end)

print("[NITRO Suite v4.0 Successfully Loaded]")
