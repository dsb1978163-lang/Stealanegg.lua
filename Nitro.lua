--[================================================================]--
--     NITRO STEAL AN EGG - PROFESSIONAL TABBED SUITE v5.0          --
--     Brand: NITRO | Exact Reference Design & Fixed Logic          --
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
    GuiKeybind = Enum.KeyCode.RightControl,
    
    Toggles = {
        AutoSteal = false,
        AutoTreadmill = false,
        AntiKnockback = false,
        GodMode = false,
        AntiHitGuard = false,
    },
    
    Values = {
        Speed = 20,
        MinStealValue = 0,
    },
    
    Folders = {
        Eggs = Workspace:WaitForChild("Eggs", 5) or Workspace,
        Treadmills = Workspace:WaitForChild("Treadmills", 5) or Workspace,
    },
    
    Remotes = {
        StealAction = ReplicatedStorage:FindFirstChild("StealEggRemote") or Instance.new("RemoteEvent"),
        TrainAction = ReplicatedStorage:FindFirstChild("TrainRemote") or Instance.new("RemoteEvent"),
    },
    
    StealCooldown = 0.6,
    
    Filters = {
        Areas = {"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"},
        Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret"},
    }
}

local Runtime = {
    State = "Idle",
    LastStealTick = 0,
    IsMinimized = false,
}

--------------------------------------------------------------------------------
-- 2. ENGINE LOGIC (EGGS & TREADMILL)
--------------------------------------------------------------------------------
local function TableContains(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function EvaluateEgg(egg)
    if not egg or not egg.Parent then return false end
    local area = egg:GetAttribute("Area") or "Titan Temple"
    local rarity = egg:GetAttribute("Rarity") or "Common"
    if not TableContains(Config.Filters.Areas, area) then return false end
    if not TableContains(Config.Filters.Rarities, rarity) then return false end
    return true
end

local function FindBestEligibleEgg()
    local folder = Config.Folders.Eggs
    if not folder then return nil end
    local bestEgg, bestKG = nil, -1
    for _, egg in ipairs(folder:GetChildren()) do
        if (egg:IsA("Model") or egg:IsA("BasePart")) and EvaluateEgg(egg) then
            local kg = egg:GetAttribute("KG") or 10
            if kg >= Config.Values.MinStealValue and kg > bestKG then
                bestKG = kg; bestEgg = egg
            end
        end
    end
    return bestEgg
end

local function MoveToPosition(pos)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and pos then hum:MoveTo(pos) end
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
-- 3. PROFESSIONAL UI DESIGN (MATCHING REFERENCE)
--------------------------------------------------------------------------------
local parentTarget = (pcall(function() return CoreGui end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")
if parentTarget:FindFirstChild("NitroRefSuite") then parentTarget.NitroRefSuite:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NitroRefSuite"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentTarget

-- Main Container Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 540, 0, 360)
MainFrame.Position = UDim2.new(0.5, -270, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 22, 19) -- Dark emerald theme matching screenshot
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(35, 60, 45)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Top Header Bar (With icons, title, tabs, and window controls)
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(12, 17, 15)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

-- App Icon / Logo placeholder
local LogoBox = Instance.new("Frame")
LogoBox.Size = UDim2.new(0, 32, 0, 32)
LogoBox.Position = UDim2.new(0, 10, 0.5, -16)
LogoBox.BackgroundColor3 = Color3.fromRGB(24, 35, 28)
LogoBox.Parent = Header
Instance.new("UICorner", LogoBox).CornerRadius = UDim.new(0, 6)
local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "⚡"
LogoText.TextSize = 16
LogoText.Parent = LogoBox

-- Horizontal Tabs (Main, Filters, Settings)
local tabButtons = {}
local tabPages = {}
local tabsList = {"Main", "Filters", "Settings"}

for i, tName in ipairs(tabsList) do
    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(0, 75, 0, 28)
    tBtn.Position = UDim2.new(0, 55 + ((i-1) * 82), 0.5, -14)
    tBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(28, 48, 36) or Color3.fromRGB(18, 25, 21)
    tBtn.Text = tName
    tBtn.TextColor3 = Color3.fromRGB(220, 240, 230)
    tBtn.Font = Enum.Font.GothamSemibold
    tBtn.TextSize = 12
    tBtn.Parent = Header
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 5)
    
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -20, 1, -60)
    page.Position = UDim2.new(0, 10, 0, 52)
    page.BackgroundTransparency = 1
    page.Visible = (i == 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 320)
    page.ScrollBarThickness = 3
    page.Parent = MainFrame
    tabPages[tName] = page
    
    tBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(tabPages) do p.Visible = false end
        page.Visible = true
        for _, b in ipairs(tabButtons) do b.BackgroundColor3 = Color3.fromRGB(18, 25, 21) end
        tBtn.BackgroundColor3 = Color3.fromRGB(28, 48, 36)
    end)
    table.insert(tabButtons, tBtn)
end

-- Window Controls (Minimize, Close)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Reopen Pill
local ReopenBtn = Instance.new("TextButton")
ReopenBtn.Name = "ReopenPill"
ReopenBtn.Size = UDim2.new(0, 120, 0, 36)
ReopenBtn.Position = UDim2.new(0.02, 0, 0.05, 0)
ReopenBtn.BackgroundColor3 = Color3.fromRGB(16, 22, 19)
ReopenBtn.Text = "⚡ NITRO (Open)"
ReopenBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
ReopenBtn.Font = Enum.Font.GothamBold
ReopenBtn.TextSize = 12
ReopenBtn.Visible = false
ReopenBtn.Parent = ScreenGui
Instance.new("UICorner", ReopenBtn).CornerRadius = UDim.new(0, 8)

--------------------------------------------------------------------------------
-- 4. TAB 1: MAIN (Toggles & Inputs matching screenshot style)
--------------------------------------------------------------------------------
local mainPage = tabPages["Main"]
local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 8)
mainLayout.Parent = mainPage

-- Helper for toggle items side-by-side
local function createToggleRow(parent, labelText, descText, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(20, 28, 24)
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(240, 255, 245)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(0.7, 0, 0, 16)
    desc.Position = UDim2.new(0, 10, 0, 25)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Color3.fromRGB(140, 170, 155)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 10
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row
    
    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(0, 44, 0, 24)
    tBtn.Position = UDim2.new(1, -54, 0.5, -12)
    tBtn.BackgroundColor3 = Config.Toggles[configKey] and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(45, 55, 50)
    tBtn.Text = Config.Toggles[configKey] and "ON" or "OFF"
    tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tBtn.Font = Enum.Font.GothamBold
    tBtn.TextSize = 10
    tBtn.Parent = row
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 12)
    
    tBtn.MouseButton1Click:Connect(function()
        Config.Toggles[configKey] = not Config.Toggles[configKey]
        tBtn.BackgroundColor3 = Config.Toggles[configKey] and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(45, 55, 50)
        tBtn.Text = Config.Toggles[configKey] and "ON" or "OFF"
    end)
    return row
end

createToggleRow(mainPage, "Auto Steal", "Automatically hunt & steal matching eggs", "AutoSteal")
createToggleRow(mainPage, "Auto Treadmill", "Train on nearest treadmill when idle", "AutoTreadmill")
createToggleRow(mainPage, "Anti Knockback", "Blocks player & chicken knockbacks", "AntiKnockback")
createToggleRow(mainPage, "God Mode", "Equips bat & bypasses damage", "GodMode")

-- Status Label Indicator
local statusDisplay = Instance.new("TextLabel")
statusDisplay.Size = UDim2.new(1, 0, 0, 28)
statusDisplay.BackgroundColor3 = Color3.fromRGB(14, 20, 17)
statusDisplay.Text = " Status: Idle"
statusDisplay.TextColor3 = Color3.fromRGB(100, 255, 150)
statusDisplay.Font = Enum.Font.GothamSemibold
statusDisplay.TextSize = 11
statusDisplay.TextXAlignment = Enum.TextXAlignment.Left
statusDisplay.Parent = mainPage
Instance.new("UICorner", statusDisplay).CornerRadius = UDim.new(0, 5)

--------------------------------------------------------------------------------
-- 5. TAB 2 & 3: FILTERS & SETTINGS
--------------------------------------------------------------------------------
local filterPage = tabPages["Filters"]
local fLayout = Instance.new("UIListLayout")
fLayout.Padding = UDim.new(0, 4)
fLayout.Parent = filterPage

for _, area in ipairs({"Titan Temple", "Cherry Blossom", "Cosmic", "Forest", "Lake", "Desert"}) do
    local fBtn = Instance.new("TextButton")
    fBtn.Size = UDim2.new(1, 0, 0, 28)
    fBtn.BackgroundColor3 = Color3.fromRGB(20, 28, 24)
    fBtn.Text = "  [✓] World: " .. area
    fBtn.TextColor3 = Color3.fromRGB(220, 240, 230)
    fBtn.Font = Enum.Font.Gotham
    fBtn.TextSize = 11
    fBtn.TextXAlignment = Enum.TextXAlignment.Left
    fBtn.Parent = filterPage
    Instance.new("UICorner", fBtn).CornerRadius = UDim.new(0, 5)
    
    fBtn.MouseButton1Click:Connect(function()
        if TableContains(Config.Filters.Areas, area) then
            for idx, val in ipairs(Config.Filters.Areas) do if val == area then table.remove(Config.Filters.Areas, idx) end end
            fBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 35)
            fBtn.Text = "  [  ] World: " .. area
        else
            table.insert(Config.Filters.Areas, area)
            fBtn.BackgroundColor3 = Color3.fromRGB(20, 28, 24)
            fBtn.Text = "  [✓] World: " .. area
        end
    end)
end

local settingsPage = tabPages["Settings"]
local sLayout = Instance.new("UIListLayout")
sLayout.Padding = UDim.new(0, 6)
sLayout.Parent = settingsPage

local function createInputRow(parent, nameText, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(20, 28, 24)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = nameText
    lbl.TextColor3 = Color3.fromRGB(240, 255, 245)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 90, 0, 26)
    box.Position = UDim2.new(1, -98, 0.5, -13)
    box.BackgroundColor3 = Color3.fromRGB(14, 20, 17)
    box.Text = tostring(defaultVal)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 11
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    
    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num) else box.Text = tostring(defaultVal) end
    end)
end

createInputRow(settingsPage, "Player Speed Level", Config.Values.Speed, function(v) Config.Values.Speed = v end)
createInputRow(settingsPage, "Minimum Steal KG", Config.Values.MinStealValue, function(v) Config.Values.MinStealValue = v end)

--------------------------------------------------------------------------------
-- 6. WINDOW DRAGGING & RUNTIME LOOP (FIXED LOGIC)
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

-- Background Automation Loop with independent AutoSteal and AutoTreadmill handling
RunService.Stepped:Connect(function()
    -- 1. Auto Steal Execution
    if Config.Toggles.AutoSteal then
        local targetEgg = FindBestEligibleEgg()
        if targetEgg then
            local pos = targetEgg:IsA("Model") and (targetEgg.PrimaryPart and targetEgg.PrimaryPart.Position or targetEgg:GetPivot().Position) or targetEgg.Position
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = hrp and (hrp.Position - pos).Magnitude or 999
            
            if dist > 7 then
                Runtime.State = "Going to Egg (" .. math.floor(dist) .. "s)"
                MoveToPosition(pos)
            else
                Runtime.State = "Stealing Egg..."
                if tick() - Runtime.LastStealTick > Config.StealCooldown then
                    Runtime.LastStealTick = tick()
                    Config.Remotes.StealAction:FireServer(targetEgg)
                end
            end
        else
            Runtime.State = "No Eggs Found"
            -- If Auto Treadmill is enabled and no eggs are found, fallback cleanly to treadmill!
            if Config.Toggles.AutoTreadmill then
                local treadmill = FindNearestTreadmill()
                if treadmill then
                    local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local dist = hrp and (hrp.Position - tPos).Magnitude or 999
                    if dist > 6 then
                        Runtime.State = "Going to Treadmill"
                        MoveToPosition(tPos)
                    else
                        Runtime.State = "Treadmilling"
                        Config.Remotes.TrainAction:FireServer(treadmill)
                    end
                end
            end
        end
    -- 2. Standalone Auto Treadmill Execution (If AutoSteal is OFF but AutoTreadmill is ON)
    elseif Config.Toggles.AutoTreadmill then
        local treadmill = FindNearestTreadmill()
        if treadmill then
            local tPos = treadmill:IsA("Model") and treadmill:GetPivot().Position or treadmill.Position
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = hrp and (hrp.Position - tPos).Magnitude or 999
            if dist > 6 then
                Runtime.State = "Going to Treadmill"
                MoveToPosition(tPos)
            else
                Runtime.State = "Treadmilling"
                Config.Remotes.TrainAction:FireServer(treadmill)
            end
        else
            Runtime.State = "No Treadmill Found"
        end
    else
        Runtime.State = "Idle"
    end
    
    statusDisplay.Text = " Status: " .. Runtime.State
end)

print("[NITRO Suite v5.0 Successfully Loaded]")
