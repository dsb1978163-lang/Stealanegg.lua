--[================================================================]--
--     NITRO STEAL AN EGG - COMPACT DROPDOWN SUITE v6.0             --
--     Brand: NITRO | Dynamic Treadmill, Smooth Physics, Accordions --
--[================================================================]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- 1. CONFIGURATION & RUNTIME STATE
--------------------------------------------------------------------------------
local Config = {
    MasterEnable = false,
    GuiKeybind = Enum.KeyCode.RightControl,
    
    Settings = {
        StealSpeed = 24,       -- Studs per second or tween rate
        TravelHeight = 4.5,    -- Vertical offset above ground
        MinStealValue = 0,     -- Minimum KG filter
    },
    
    Folders = {
        Eggs = Workspace:WaitForChild("Eggs", 5) or Workspace,
        Treadmills = Workspace:WaitForChild("Treadmills", 5) or Workspace,
    },
    
    Remotes = {
        StealAction = ReplicatedStorage:FindFirstChild("StealEggRemote") or Instance.new("RemoteEvent"),
        TrainAction = ReplicatedStorage:FindFirstChild("TrainRemote") or Instance.new("RemoteEvent"),
    },
    
    StealCooldown = 0.65,
    
    Filters = {
        Areas = {"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"},
        Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"},
    }
}

local Runtime = {
    State = "Idle",
    TargetEgg = nil,
    TargetTreadmill = nil,
    LastStealTick = 0,
    IsMinimized = false,
    CurrentTween = nil,
}

--------------------------------------------------------------------------------
-- 2. DYNAMIC DETECTION & ROUTING ENGINE
--------------------------------------------------------------------------------
local function TableContains(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function EvaluateEgg(egg)
    if not egg or not egg.Parent then return false end
    local area = egg:GetAttribute("Area") or "Titan Temple"
    local rarity = egg:GetAttribute("Rarity") or "Common"
    local kg = egg:GetAttribute("KG") or 10
    
    if not TableContains(Config.Filters.Areas, area) then return false end
    if not TableContains(Config.Filters.Rarities, rarity) then return false end
    if kg < Config.Settings.MinStealValue then return false end
    return true
end

local function FindBestEligibleEgg()
    local folder = Config.Folders.Eggs
    if not folder then return nil end
    local bestEgg, bestKG = nil, -1
    for _, egg in ipairs(folder:GetChildren()) do
        if (egg:IsA("Model") or egg:IsA("BasePart")) and EvaluateEgg(egg) then
            local kg = egg:GetAttribute("KG") or 10
            if kg > bestKG then
                bestKG = kg; bestEgg = egg
            end
        end
    end
    return bestEgg
end

local function FindDynamicTreadmill()
    local folder = Config.Folders.Treadmills
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not folder or not hrp then return nil end
    
    local nearest, shortestDist = nil, math.huge
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local pos = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
            local dist = (hrp.Position - pos).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearest = obj
            end
        end
    end
    return nearest
end

local function SmoothMoveTo(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    
    -- Apply custom height offset and smooth pathfinding/tweening approach
    local adjustedTarget = Vector3.new(targetPos.X, targetPos.Y + Config.Settings.TravelHeight, targetPos.Z)
    local distance = (hrp.Position - adjustedTarget).Magnitude
    
    if distance > 6 then
        local travelTime = math.max(0.1, distance / Config.Settings.StealSpeed)
        if not Runtime.CurrentTween or Runtime.CurrentTween.PlaybackState ~= Enum.PlaybackState.Playing then
            local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
            Runtime.CurrentTween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(adjustedTarget)})
            Runtime.CurrentTween:Play()
        end
    else
        if Runtime.CurrentTween then
            Runtime.CurrentTween:Cancel()
            Runtime.CurrentTween = nil
        end
        humanoid:MoveTo(targetPos)
    end
end

local function StopSmoothMovement()
    if Runtime.CurrentTween then
        Runtime.CurrentTween:Cancel()
        Runtime.CurrentTween = nil
    end
end

--------------------------------------------------------------------------------
-- 3. COMPACT ACCORDION UI SUITE
--------------------------------------------------------------------------------
local parentTarget = (pcall(function() return CoreGui end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")
if parentTarget:FindFirstChild("NitroCompactV6") then parentTarget.NitroCompactV6:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NitroCompactV6"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentTarget

-- Main Container Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 440)
MainFrame.Position = UDim2.new(0.5, -170, 0.4, -220)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 18)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(40, 70, 55)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(10, 15, 13)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ NITRO | V6.0 SUITE"
TitleLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
TitleLabel.TextSize = 12
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Window Controls (Minimize, Close)
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
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local CloseBtn = createHeaderBtn("✕", Color3.fromRGB(180, 50, 50), -30)
local MinBtn = createHeaderBtn("🗕", Color3.fromRGB(180, 140, 40), -58)

-- Reopen Pill Button
local ReopenBtn = Instance.new("TextButton")
ReopenBtn.Name = "ReopenPill"
ReopenBtn.Size = UDim2.new(0, 110, 0, 34)
ReopenBtn.Position = UDim2.new(0.02, 0, 0.05, 0)
ReopenBtn.BackgroundColor3 = Color3.fromRGB(15, 20, 18)
ReopenBtn.Text = "⚡ NITRO (Open)"
ReopenBtn.TextColor3 = Color3.fromRGB(80, 255, 140)
ReopenBtn.Font = Enum.Font.GothamBold
ReopenBtn.TextSize = 11
ReopenBtn.Visible = false
ReopenBtn.Parent = ScreenGui
Instance.new("UICorner", ReopenBtn).CornerRadius = UDim.new(0, 8)
local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = Color3.fromRGB(80, 255, 140)
ReopenStroke.Thickness = 1.5
ReopenStroke.Parent = ReopenBtn

-- Scrollable Body
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -50)
Container.Position = UDim2.new(0, 8, 0, 44)
Container.BackgroundTransparency = 1
Container.CanvasSize = UDim2.new(0, 0, 0, 450)
Container.ScrollBarThickness = 3
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 6)
UIList.Parent = Container

--------------------------------------------------------------------------------
-- 4. ACCORDION BUILDER HELPER
--------------------------------------------------------------------------------
local function createAccordion(titleText, expandedHeight)
    local wrapper = Instance.new("Frame")
    wrapper.Size = UDim2.new(1, 0, 0, 30)
    wrapper.BackgroundColor3 = Color3.fromRGB(20, 28, 25)
    wrapper.ClipsDescendants = true
    wrapper.Parent = Container
    Instance.new("UICorner", wrapper).CornerRadius = UDim.new(0, 6)
    
    local headerBtn = Instance.new("TextButton")
    headerBtn.Size = UDim2.new(1, 0, 0, 30)
    headerBtn.BackgroundTransparency = 1
    headerBtn.Font = Enum.Font.GothamBold
    headerBtn.Text = "  ▼  " .. titleText
    headerBtn.TextColor3 = Color3.fromRGB(220, 240, 230)
    headerBtn.TextSize = 11
    headerBtn.TextXAlignment = Enum.TextXAlignment.Left
    headerBtn.Parent = wrapper
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -12, 0, expandedHeight)
    contentFrame.Position = UDim2.new(0, 6, 0, 34)
    contentFrame.BackgroundColor3 = Color3.fromRGB(13, 18, 16)
    contentFrame.Parent = wrapper
    Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 5)
    
    local isOpen = false
    headerBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        local targetH = isOpen and (expandedHeight + 40) or 30
        TweenService:Create(wrapper, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
        headerBtn.Text = isOpen and ("  ▲  " .. titleText) or ("  ▼  " .. titleText)
    end)
    return contentFrame
end

--------------------------------------------------------------------------------
-- 5. POPULATING ACCORDIONS
--------------------------------------------------------------------------------

-- A. Auto Steal & Status
local autoAcc = createAccordion("Auto Steal & Status", 75)
local masterToggle = Instance.new("TextButton")
masterToggle.Size = UDim2.new(1, -12, 0, 30)
masterToggle.Position = UDim2.new(0, 6, 0, 6)
masterToggle.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
masterToggle.Text = "Auto Steal: OFF"
masterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggle.Font = Enum.Font.GothamBold
masterToggle.TextSize = 11
masterToggle.Parent = autoAcc
Instance.new("UICorner", masterToggle).CornerRadius = UDim.new(0, 5)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -12, 0, 24)
statusLbl.Position = UDim2.new(0, 6, 0, 42)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.GothamSemibold
statusLbl.Text = "Status: Idle"
statusLbl.TextColor3 = Color3.fromRGB(100, 255, 160)
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = autoAcc

masterToggle.MouseButton1Click:Connect(function()
    Config.MasterEnable = not Config.MasterEnable
    masterToggle.BackgroundColor3 = Config.MasterEnable and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 50, 50)
    masterToggle.Text = Config.MasterEnable and "Auto Steal: ACTIVE" or "Auto Steal: OFF"
end)


-- B. Target World Filters
local worldsAcc = createAccordion("Target World Filters", 155)
local wLayout = Instance.new("UIListLayout")
wLayout.Padding = UDim.new(0, 3)
wLayout.Parent = worldsAcc

for _, areaName in ipairs({"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -6, 0, 22)
    btn.BackgroundColor3 = TableContains(Config.Filters.Areas, areaName) and Color3.fromRGB(45, 110, 75) or Color3.fromRGB(25, 35, 30)
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
            btn.BackgroundColor3 = Color3.fromRGB(25, 35, 30)
            btn.Text = " [  ] " .. areaName
        else
            table.insert(Config.Filters.Areas, areaName)
            btn.BackgroundColor3 = Color3.fromRGB(45, 110, 75)
            btn.Text = " [✓] " .. areaName
        end
    end)
end


-- C. Movement & Speed Settings
local settingsAcc = createAccordion("Movement & Speed Settings", 95)
local sLayout = Instance.new("UIListLayout")
sLayout.Padding = UDim.new(0, 4)
sLayout.Parent = settingsAcc

local function createInputRow(parent, labelTxt, defaultVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt
    lbl.TextColor3 = Color3.fromRGB(220, 240, 230)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 75, 0, 24)
    box.Position = UDim2.new(1, -75, 0, 1)
    box.BackgroundColor3 = Color3.fromRGB(20, 28, 25)
    box.Text = tostring(defaultVal)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 11
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    
    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num) else box.Text = tostring(defaultVal) end
    end)
end

createInputRow(settingsAcc, "Steal Speed (Studs/s)", Config.Settings.StealSpeed, function(v) Config.Settings.StealSpeed = v end)
createInputRow(settingsAcc, "Travel Height Offset", Config.Settings.TravelHeight, function(v) Config.Settings.TravelHeight = v end)
createInputRow(settingsAcc, "Min Steal KG Value", Config.Settings.MinStealValue, function(v) Config.Settings.MinStealValue = v end)

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
    TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 340, 0, 440)}):Play()
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Config.GuiKeybind then
        Runtime.IsMinimized = not Runtime.IsMinimized
        MainFrame.Visible = not Runtime.IsMinimized
        ReopenBtn.Visible = Runtime.IsMinimized
    end
end)


--------------------------------------------------------------------------------
-- 7. STRICT PRIORITY ENGINE & AUTOMATION LOOP
--------------------------------------------------------------------------------
RunService.Stepped:Connect(function()
    if not Config.MasterEnable then
        Runtime.State = "Idle"
        statusLbl.Text = "Status: Idle (Paused)"
        StopSmoothMovement()
        return
    end
    
    -- Step 1: Scan selected worlds for eligible eggs
    Runtime.State = "Scanning..."
    statusLbl.Text = "Status: Scanning..."
    
    local targetEgg = FindBestEligibleEgg()
    
    if targetEgg then
        -- Step 2: Eligible egg found! Move smoothly & steal.
        Runtime.TargetEgg = targetEgg
        local pos = targetEgg:IsA("Model") and (targetEgg.PrimaryPart and targetEgg.PrimaryPart.Position or targetEgg:GetPivot().Position) or targetEgg.Position
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist = hrp and (hrp.Position - pos).Magnitude or 999
        
        if dist > 7 then
            Runtime.State = "Going to Egg"
            statusLbl.Text = "Status: Going to Egg (" .. math.floor(dist) .. " studs)"
            SmoothMoveTo(pos)
        else
            StopSmoothMovement()
            Runtime.State = "Stealing..."
            statusLbl.Text = "Status: Stealing..."
            
            if tick() - Runtime.LastStealTick > Config.StealCooldown then
                Runtime.LastStealTick = tick()
                Config.Remotes.StealAction:FireServer(targetEgg)
            end
        end
    else
        -- Step 3: Zero eligible eggs remaining. Only now fallback to dynamic treadmill!
        StopSmoothMovement()
        Runtime.TargetEgg = nil
        Runtime.State = "No Eggs Found"
        statusLbl.Text = "Status: No Eggs Found"
        
        local treadmill = FindDynamicTreadmill()
        if treadmill then
            local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = hrp and (hrp.Position - tPos).Magnitude or 999
            
            if dist > 6 then
                Runtime.State = "Going to Treadmill"
                statusLbl.Text = "Status: Going to Treadmill"
                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:MoveTo(tPos) end
            else
                Runtime.State = "Treadmilling"
                statusLbl.Text = "Status: Treadmilling"
                Config.Remotes.TrainAction:FireServer(treadmill)
            end
        end
    end
end)

print("[NITRO Suite v6.0 Successfully Loaded]")
