--[================================================================]--
--     NITRO STEAL AN EGG TESTING & QA SUITE (ROBLOX STUDIO)        --
--     Brand: NITRO | Version: 2.0.0-Pro                            --
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
        SpawnLocations = Workspace:WaitForChild("SpawnLocations", 5) or Workspace,
    },
    
    Remotes = {
        StealAction = ReplicatedStorage:FindFirstChild("StealEggRemote") or Instance.new("RemoteEvent"),
        TrainAction = ReplicatedStorage:FindFirstChild("TrainRemote") or Instance.new("RemoteEvent"),
    },
    
    StealDelay = 1.0,
    DetectionInterval = 0.5,
    
    Filters = {
        Areas = {"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"},
        Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"},
        MinKG = 0,
        MaxKG = 999999999,
    },
    
    AutomationSettings = {
        TrainingBehavior = "AutomaticFallback",
        TargetPriority = "HighestKG",
    }
}

local Runtime = {
    CurrentState = "IDLE",
    CurrentTarget = nil,
    CurrentAction = "Idle",
    DetectedEggsCache = {},
    LastStealTick = 0,
    IsMinimized = false,
}

--------------------------------------------------------------------------------
-- 2. EVALUATION & SCANNING LOGIC
--------------------------------------------------------------------------------
local function TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function EvaluateEgg(eggModel)
    local area = eggModel:GetAttribute("Area") or "Titan Temple"
    local rarity = eggModel:GetAttribute("Rarity") or "Common"
    local kg = eggModel:GetAttribute("KG") or 10
    
    if not TableContains(Config.Filters.Areas, area) then
        return false, "Rejected: Wrong Area"
    end
    if not TableContains(Config.Filters.Rarities, rarity) then
        return false, "Rejected: Rarity Filter"
    end
    if kg < Config.Filters.MinKG then
        return false, "Rejected: Below Minimum KG"
    end
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
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            local pos = egg:IsA("Model") and (egg.PrimaryPart and egg.PrimaryPart.Position or egg:GetPivot().Position) or egg.Position
            local distance = hrp and (hrp.Position - pos).Magnitude or 0
            
            local area = egg:GetAttribute("Area") or "Titan Temple"
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
                local score = Config.AutomationSettings.TargetPriority == "HighestKG" and kg or (10000 - distance)
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

local function MoveToPosition(pos)
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid"):MoveTo(pos)
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
-- 3. POLISHED NITRO GUI DESIGN & ANIMATIONS
--------------------------------------------------------------------------------
local parentTarget = (pcall(function() return CoreGui end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NitroStealAnEggQA"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentTarget

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 660, 0, 440)
MainFrame.Position = UDim2.new(0.5, -330, 0.5, -220)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
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
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -150, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ NITRO | STEAL AN EGG QA SUITE"
TitleLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Window Controls (Close, Minimize)
local function createHeaderButton(text, color, xOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 28, 0, 28)
    btn.Position = UDim2.new(1, xOffset, 0.5, -14)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = Header
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local CloseBtn = createHeaderButton("✕", Color3.fromRGB(200, 50, 50), -38)
local MinBtn = createHeaderButton("🗕", Color3.fromRGB(200, 160, 40), -72)

-- Minimized Reopen Pill
local ReopenBtn = Instance.new("TextButton")
ReopenBtn.Name = "ReopenPill"
ReopenBtn.Size = UDim2.new(0, 130, 0, 40)
ReopenBtn.Position = UDim2.new(0.02, 0, 0.05, 0)
ReopenBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ReopenBtn.Text = "⚡ NITRO (Open)"
ReopenBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
ReopenBtn.Font = Enum.Font.GothamBold
ReopenBtn.TextSize = 13
ReopenBtn.Visible = false
ReopenBtn.Parent = ScreenGui
Instance.new("UICorner", ReopenBtn).CornerRadius = UDim.new(0, 8)
local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = Color3.fromRGB(255, 90, 90)
ReopenStroke.Thickness = 1.5
ReopenStroke.Parent = ReopenBtn

-- Confirmation Popup Modal
local ConfirmOverlay = Instance.new("Frame")
ConfirmOverlay.Size = UDim2.new(1, 0, 1, 0)
ConfirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ConfirmOverlay.BackgroundTransparency = 0.5
ConfirmOverlay.Visible = false
ConfirmOverlay.ZIndex = 10
ConfirmOverlay.Parent = MainFrame

local ConfirmBox = Instance.new("Frame")
ConfirmBox.Size = UDim2.new(0, 300, 0, 140)
ConfirmBox.Position = UDim2.new(0.5, -150, 0.5, -70)
ConfirmBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
ConfirmBox.ZIndex = 11
ConfirmBox.Parent = ConfirmOverlay
Instance.new("UICorner", ConfirmBox).CornerRadius = UDim.new(0, 10)

local ConfirmText = Instance.new("TextLabel")
ConfirmText.Size = UDim2.new(1, -20, 0, 60)
ConfirmText.Position = UDim2.new(0, 10, 0, 15)
ConfirmText.BackgroundTransparency = 1
ConfirmText.Font = Enum.Font.GothamSemibold
ConfirmText.Text = "Are you sure you want to close Nitro?"
ConfirmText.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmText.TextSize = 13
ConfirmText.TextWrapped = true
ConfirmText.ZIndex = 11
ConfirmText.TextXAlignment = Enum.TextXAlignment.Center
ConfirmText.Parent = ConfirmBox

local YesBtn = Instance.new("TextButton")
YesBtn.Size = UDim2.new(0, 120, 0, 32)
YesBtn.Position = UDim2.new(0.08, 0, 0.65, 0)
YesBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
YesBtn.Text = "Close"
YesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
YesBtn.Font = Enum.Font.GothamBold
YesBtn.TextSize = 12
YesBtn.ZIndex = 11
YesBtn.Parent = ConfirmBox
Instance.new("UICorner", YesBtn).CornerRadius = UDim.new(0, 6)

local NoBtn = Instance.new("TextButton")
NoBtn.Size = UDim2.new(0, 120, 0, 32)
NoBtn.Position = UDim2.new(0.54, 0, 0.65, 0)
NoBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
NoBtn.Text = "Cancel"
NoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NoBtn.Font = Enum.Font.GothamBold
NoBtn.TextSize = 12
NoBtn.ZIndex = 11
NoBtn.Parent = ConfirmBox
Instance.new("UICorner", NoBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function() ConfirmOverlay.Visible = true end)
NoBtn.MouseButton1Click:Connect(function() ConfirmOverlay.Visible = false end)
YesBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

MinBtn.MouseButton1Click:Connect(function()
    Runtime.IsMinimized = true
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(0.3)
    MainFrame.Visible = false
    ReopenBtn.Visible = true
end)

ReopenBtn.MouseButton1Click:Connect(function()
    Runtime.IsMinimized = false
    ReopenBtn.Visible = false
    MainFrame.Visible = true
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 660, 0, 440)}):Play()
end)

--------------------------------------------------------------------------------
-- 4. DRAGGING & CORNER RESIZING
--------------------------------------------------------------------------------
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
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

-- Resize Handle
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 18, 0, 18)
ResizeHandle.Position = UDim2.new(1, -18, 1, -18)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = "◢"
ResizeHandle.TextColor3 = Color3.fromRGB(100, 100, 130)
ResizeHandle.TextSize = 12
ResizeHandle.Parent = MainFrame

local resizing, resizeStart, startSize = false, nil, nil
ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true; resizeStart = input.Position; startSize = MainFrame.AbsoluteSize
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then resizing = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and resizing then
        local delta = input.Position - resizeStart
        local newX = math.clamp(startSize.X + delta.X, 500, 900)
        local newY = math.clamp(startSize.Y + delta.Y, 350, 700)
        MainFrame.Size = UDim2.new(0, newX, 0, newY)
    end
end)

--------------------------------------------------------------------------------
-- 5. NAVIGATION TABS & POPULATED MENUS
--------------------------------------------------------------------------------
local TabContainer = Instance.new("ScrollingFrame")
TabContainer.Size = UDim2.new(0, 140, 1, -56)
TabContainer.Position = UDim2.new(0, 10, 0, 52)
TabContainer.BackgroundTransparency = 1
TabContainer.ScrollBarThickness = 2
TabContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = TabContainer

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -165, 1, -56)
ContentFrame.Position = UDim2.new(0, 155, 0, 52)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local tabs = {"MAIN", "FILTERS", "AUTOMATION", "DEBUG", "SETTINGS", "ABOUT"}
local contentPages = {}

for i, tabName in ipairs(tabs) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, 0, 0, 36)
    tabBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(45, 45, 70) or Color3.fromRGB(22, 22, 32)
    tabBtn.Text = tabName
    tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 12
    tabBtn.Parent = TabContainer
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)
    
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = (i == 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 600)
    page.ScrollBarThickness = 4
    page.Parent = ContentFrame
    contentPages[tabName] = page
    
    tabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(contentPages) do p.Visible = false end
        page.Visible = true
        for _, b in ipairs(TabContainer:GetChildren()) do
            if b:IsA("TextButton") then 
                TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(22, 22, 32)}):Play()
            end
        end
        TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 70)}):Play()
    end)
end

-- Helper for UI text items
local function createLabel(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.Position = UDim2.new(0, 0, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(210, 210, 230)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

--------------------------------------------------------------------------------
-- FILLING OUT MENUS (MAIN, FILTERS, AUTOMATION, DEBUG, ABOUT)
--------------------------------------------------------------------------------

-- 1. MAIN TAB
local mainPage = contentPages["MAIN"]
createLabel(mainPage, "Master Automation Enable:", 10)
local masterToggleBtn = Instance.new("TextButton")
masterToggleBtn.Size = UDim2.new(0, 110, 0, 30)
masterToggleBtn.Position = UDim2.new(0, 220, 0, 7)
masterToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
masterToggleBtn.Text = "OFF"
masterToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggleBtn.Font = Enum.Font.GothamBold
masterToggleBtn.TextSize = 12
masterToggleBtn.Parent = mainPage
Instance.new("UICorner", masterToggleBtn).CornerRadius = UDim.new(0, 6)

masterToggleBtn.MouseButton1Click:Connect(function()
    Config.MasterEnable = not Config.MasterEnable
    masterToggleBtn.BackgroundColor3 = Config.MasterEnable and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(180, 50, 50)
    masterToggleBtn.Text = Config.MasterEnable and "ACTIVE" or "OFF"
end)

local statusTargetLbl = createLabel(mainPage, "Current Target: None", 55)
local statusActionLbl = createLabel(mainPage, "Current Action: Idle", 90)
local statusStateLbl = createLabel(mainPage, "Current State: IDLE", 125)

-- 2. FILTERS TAB (FULLY POPULATED & SELECTABLE)
local filterPage = contentPages["FILTERS"]
createLabel(filterPage, "Select Areas to Target:", 10)

local areaListContainer = Instance.new("Frame")
areaListContainer.Size = UDim2.new(1, 0, 0, 140)
areaListContainer.Position = UDim2.new(0, 0, 0, 38)
areaListContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
areaListContainer.Parent = filterPage
Instance.new("UICorner", areaListContainer).CornerRadius = UDim.new(0, 8)

local areaLayout = Instance.new("UIListLayout")
areaLayout.Padding = UDim.new(0, 4)
areaLayout.Parent = areaListContainer

for _, areaName in ipairs({"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"}) do
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -10, 0, 26)
    toggleBtn.Position = UDim2.new(0, 5, 0, 0)
    toggleBtn.BackgroundColor3 = TableContains(Config.Filters.Areas, areaName) and Color3.fromRGB(50, 120, 80) or Color3.fromRGB(35, 35, 48)
    toggleBtn.Text = "  [✓] Area: " .. areaName
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.Gotham
    toggleBtn.TextSize = 11
    toggleBtn.TextXAlignment = Enum.TextXAlignment.Left
    toggleBtn.Parent = areaListContainer
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)
    
    toggleBtn.MouseButton1Click:Connect(function()
        if TableContains(Config.Filters.Areas, areaName) then
            for idx, val in ipairs(Config.Filters.Areas) do if val == areaName then table.remove(Config.Filters.Areas, idx) end end
            toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
            toggleBtn.Text = "  [  ] Area: " .. areaName
        else
            table.insert(Config.Filters.Areas, areaName)
            toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 80)
            toggleBtn.Text = "  [✓] Area: " .. areaName
        end
    end)
end

createLabel(filterPage, "Select Rarities to Target:", 190)
local rarityContainer = Instance.new("Frame")
rarityContainer.Size = UDim2.new(1, 0, 0, 140)
rarityContainer.Position = UDim2.new(0, 0, 0, 218)
rarityContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
rarityContainer.Parent = filterPage
Instance.new("UICorner", rarityContainer).CornerRadius = UDim.new(0, 8)

local rarityLayout = Instance.new("UIListLayout")
rarityLayout.Padding = UDim.new(0, 4)
rarityLayout.Parent = rarityContainer

for _, rarityName in ipairs({"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"}) do
    local rBtn = Instance.new("TextButton")
    rBtn.Size = UDim2.new(1, -10, 0, 26)
    rBtn.BackgroundColor3 = TableContains(Config.Filters.Rarities, rarityName) and Color3.fromRGB(120, 80, 50) or Color3.fromRGB(35, 35, 48)
    rBtn.Text = "  [✓] Rarity: " .. rarityName
    rBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    rBtn.Font = Enum.Font.Gotham
    rBtn.TextSize = 11
    rBtn.TextXAlignment = Enum.TextXAlignment.Left
    rBtn.Parent = rarityContainer
    Instance.new("UICorner", rBtn).CornerRadius = UDim.new(0, 4)
    
    rBtn.MouseButton1Click:Connect(function()
        if TableContains(Config.Filters.Rarities, rarityName) then
            for idx, val in ipairs(Config.Filters.Rarities) do if val == rarityName then table.remove(Config.Filters.Rarities, idx) end end
            rBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
            rBtn.Text = "  [  ] Rarity: " .. rarityName
        else
            table.insert(Config.Filters.Rarities, rarityName)
            rBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 50)
            rBtn.Text = "  [✓] Rarity: " .. rarityName
        end
    end)
end

-- 3. AUTOMATION TAB (USABLE SETTINGS & TOGGLES)
local autoPage = contentPages["AUTOMATION"]
createLabel(autoPage, "Target Priority Selector:", 10)

local priorityBtn = Instance.new("TextButton")
priorityBtn.Size = UDim2.new(1, 0, 0, 32)
priorityBtn.Position = UDim2.new(0, 0, 0, 35)
priorityBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
priorityBtn.Text = "Priority Mode: Highest KG"
priorityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
priorityBtn.Font = Enum.Font.GothamSemibold
priorityBtn.TextSize = 12
priorityBtn.Parent = autoPage
Instance.new("UICorner", priorityBtn).CornerRadius = UDim.new(0, 6)

priorityBtn.MouseButton1Click:Connect(function()
    if Config.AutomationSettings.TargetPriority == "HighestKG" then
        Config.AutomationSettings.TargetPriority = "ClosestDistance"
        priorityBtn.Text = "Priority Mode: Closest Distance"
    else
        Config.AutomationSettings.TargetPriority = "HighestKG"
        priorityBtn.Text = "Priority Mode: Highest KG"
    end
end)

createLabel(autoPage, "Treadmill Fallback Behavior:", 85)
local fallbackBtn = Instance.new("TextButton")
fallbackBtn.Size = UDim2.new(1, 0, 0, 32)
fallbackBtn.Position = UDim2.new(0, 0, 0, 110)
fallbackBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 80)
fallbackBtn.Text = "Behavior: Automatic Fallback Active"
fallbackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
fallbackBtn.Font = Enum.Font.GothamSemibold
fallbackBtn.TextSize = 12
fallbackBtn.Parent = autoPage
Instance.new("UICorner", fallbackBtn).CornerRadius = UDim.new(0, 6)

fallbackBtn.MouseButton1Click:Connect(function()
    if Config.AutomationSettings.TrainingBehavior == "AutomaticFallback" then
        Config.AutomationSettings.TrainingBehavior = "Disabled"
        fallbackBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        fallbackBtn.Text = "Behavior: Training Fallback Disabled"
    else
        Config.AutomationSettings.TrainingBehavior = "AutomaticFallback"
        fallbackBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 80)
        fallbackBtn.Text = "Behavior: Automatic Fallback Active"
    end
end)

-- 4. DEBUG TAB
local debugPage = contentPages["DEBUG"]
local debugLogLabel = Instance.new("TextLabel")
debugLogLabel.Size = UDim2.new(1, 0, 1, 0)
debugLogLabel.BackgroundTransparency = 1
debugLogLabel.Font = Enum.Font.Code
debugLogLabel.Text = "Scanning state waiting..."
debugLogLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
debugLogLabel.TextSize = 11
debugLogLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLogLabel.TextYAlignment = Enum.TextYAlignment.Top
debugLogLabel.TextWrapped = true
debugLogLabel.Parent = debugPage

-- 5. ABOUT TAB
local aboutPage = contentPages["ABOUT"]
local aboutText = Instance.new("TextLabel")
aboutText.Size = UDim2.new(1, 0, 1, 0)
aboutText.BackgroundTransparency = 1
aboutText.Font = Enum.Font.Gotham
aboutText.Text = "⚡ NITRO | Steal an Egg QA Suite\nVersion: 2.0.0-Pro\nBrand: NITRO\n\nFeatures modern UI animations, interactive filtering toggles, robust automation loops, and full testing controls."
aboutText.TextColor3 = Color3.fromRGB(220, 220, 240)
aboutText.TextSize = 13
aboutText.TextWrapped = true
aboutText.TextXAlignment = Enum.TextXAlignment.Left
aboutText.Parent = aboutPage

--------------------------------------------------------------------------------
-- 6. BACKGROUND RUNTIME LOOP
--------------------------------------------------------------------------------
RunService.Stepped:Connect(function()
    if not Config.MasterEnable then
        Runtime.CurrentState = "IDLE"
        Runtime.CurrentAction = "Master Switch Off"
        statusStateLbl.Text = "Current State: " .. Runtime.CurrentState
        statusActionLbl.Text = "Current Action: " .. Runtime.CurrentAction
        return
    end
    
    Runtime.CurrentState = "SCANNING"
    local targetEgg, cache = ScanForEligibleEggs()
    
    local debugBuilder = "--- NITRO QA DEBUG CONSOLE ---\n"
    for _, info in ipairs(cache) do
        debugBuilder = string.format("%s\n[Egg: %s]\n Area: %s | Rarity: %s | KG: %s\n Dist: %s | Eligible: %s\n Reason: %s\n",
            debugBuilder, info.Name, info.Area, info.Rarity, tostring(info.KG), tostring(info.Distance), tostring(info.Eligible), info.Reason)
    end
    debugLogLabel.Text = debugBuilder
    
    if targetEgg then
        Runtime.CurrentTarget = targetEgg
        Runtime.CurrentState = "MOVING"
        local pos = targetEgg:IsA("Model") and targetEgg:GetPivot().Position or targetEgg.Position
        MoveToPosition(pos)
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - pos).Magnitude < 8 then
            Runtime.CurrentState = "INTERACTING"
            Runtime.CurrentAction = "Stealing Egg: " .. targetEgg.Name
            if tick() - Runtime.LastStealTick > Config.StealDelay then
                Runtime.LastStealTick = tick()
                Config.Remotes.StealAction:FireServer(targetEgg)
            end
        end
    else
        Runtime.CurrentTarget = nil
        if Config.AutomationSettings.TrainingBehavior == "AutomaticFallback" then
            Runtime.CurrentState = "GOING_TO_TREADMILL"
            Runtime.CurrentAction = "Moving to Treadmill Training"
            local treadmill = FindNearestTreadmill()
            if treadmill then
                local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
                MoveToPosition(tPos)
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - tPos).Magnitude < 6 then
                    Runtime.CurrentState = "TRAINING"
                    Runtime.CurrentAction = "Training on Treadmill..."
                    Config.Remotes.TrainAction:FireServer(treadmill)
                end
            end
        else
            Runtime.CurrentState = "NO_TARGET"
            Runtime.CurrentAction = "Waiting for valid targets..."
        end
    end
    
    statusTargetLbl.Text = "Current Target: " .. (Runtime.CurrentTarget and Runtime.CurrentTarget.Name or "None")
    statusActionLbl.Text = "Current Action: " .. Runtime.CurrentAction
    statusStateLbl.Text = "Current State: " .. Runtime.CurrentState
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Config.GuiKeybind then
        Runtime.IsMinimized = not Runtime.IsMinimized
        MainFrame.Visible = not Runtime.IsMinimized
        ReopenBtn.Visible = Runtime.IsMinimized
    end
end)

print("[NITRO QA Suite 2.0 successfully loaded]")
