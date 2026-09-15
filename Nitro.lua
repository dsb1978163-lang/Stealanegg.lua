--[================================================================]--
--     NITRO STEAL AN EGG | AUTOMATION SUITE v3.0                   --
--     Fully polished UI · Reliable automation · Mouse-reactive FX  --
--[================================================================]--

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local Workspace       = game:GetService("Workspace")
local CoreGui         = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- GUARD: prevent duplicate loads
--------------------------------------------------------------------------------
if _G.NitroSuiteLoaded then
    warn("[NITRO] Already loaded — aborting duplicate instance.")
    return
end
_G.NitroSuiteLoaded = true

--------------------------------------------------------------------------------
-- 1.  CONFIGURATION  (edit these to match the live game)
--------------------------------------------------------------------------------
local Config = {
    GuiKeybind   = Enum.KeyCode.RightControl,
    StealDelay   = 0.55,   -- seconds between FireServer calls
    ScanInterval = 0.4,    -- seconds between full egg scans
    MoveRange    = 7,      -- studs — how close to trigger interaction

    Folders = {
        Eggs           = nil,   -- resolved at runtime
        Treadmills     = nil,
        SpawnLocations = nil,
    },

    Remotes = {
        StealAction = nil,      -- resolved at runtime
        TrainAction = nil,
    },

    -- Filters (mutated by the UI toggles)
    Filters = {
        Areas    = {"Titan Temple","Cherry Blossom","Cosmic","Forest","Lake","Desert"},
        Rarities = {"Common","Rare","Epic","Legendary","Mythic","Secret"},
        MinKG    = 0,
        MaxKG    = 999999999,
    },

    Automation = {
        Enabled          = false,
        TargetPriority   = "HighestKG",   -- "HighestKG" | "Closest"
        TreadmillFallback = true,
    },
}

--------------------------------------------------------------------------------
-- 2.  RUNTIME STATE
--------------------------------------------------------------------------------
local State = {
    Phase       = "IDLE",   -- IDLE | SCANNING | MOVING | STEALING | TRAINING | NO_TARGET
    Target      = nil,      -- current egg Instance
    Action      = "Waiting…",
    EggCache    = {},
    LastSteal   = 0,
    LastScan    = 0,
    LoopConn    = nil,      -- Stepped connection handle
    Moving      = false,    -- debounce flag
}

--------------------------------------------------------------------------------
-- 3.  UTILITY HELPERS
--------------------------------------------------------------------------------
local function Has(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function Remove(tbl, val)
    for i = #tbl, 1, -1 do
        if tbl[i] == val then table.remove(tbl, i) end
    end
end

local function SafeFolder(name)
    local ok, res = pcall(function() return Workspace:WaitForChild(name, 4) end)
    return (ok and res) or nil
end

local function SafeRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r then return r end
    -- Fallback: search descendants
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == name then return v end
    end
    return nil
end

local function ModelPos(inst)
    if inst:IsA("BasePart")  then return inst.Position end
    if inst.PrimaryPart       then return inst.PrimaryPart.Position end
    local ok, piv = pcall(function() return inst:GetPivot().Position end)
    return ok and piv or Vector3.new(0, 0, 0)
end

local function HRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function Humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function MoveTo(pos)
    local h = Humanoid()
    if h then h:MoveTo(pos) end
end

--------------------------------------------------------------------------------
-- 4.  RUNTIME FOLDER / REMOTE RESOLUTION (deferred so GUI loads first)
--------------------------------------------------------------------------------
task.spawn(function()
    Config.Folders.Eggs           = SafeFolder("Eggs") or Workspace
    Config.Folders.Treadmills     = SafeFolder("Treadmills") or Workspace
    Config.Folders.SpawnLocations = SafeFolder("SpawnLocations") or Workspace
    Config.Remotes.StealAction    = SafeRemote("StealEggRemote")
    Config.Remotes.TrainAction    = SafeRemote("TrainRemote")
end)

--------------------------------------------------------------------------------
-- 5.  SCANNING & EVALUATION
--------------------------------------------------------------------------------
local function EvaluateEgg(egg)
    local area   = egg:GetAttribute("Area")   or "Titan Temple"
    local rarity = egg:GetAttribute("Rarity") or "Common"
    local kg     = egg:GetAttribute("KG")     or 0

    if not Has(Config.Filters.Areas,    area)   then return false, "Area filtered" end
    if not Has(Config.Filters.Rarities, rarity) then return false, "Rarity filtered" end
    if kg < Config.Filters.MinKG                then return false, "Below min KG" end
    if kg > Config.Filters.MaxKG                then return false, "Above max KG" end
    return true, "Eligible"
end

local function ScanEggs()
    local folder = Config.Folders.Eggs
    local hrp    = HRP()
    if not folder then return nil, {} end

    local best, bestScore = nil, -math.huge
    local cache = {}

    for _, egg in ipairs(folder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            local pos      = ModelPos(egg)
            local dist     = hrp and (hrp.Position - pos).Magnitude or 0
            local area     = egg:GetAttribute("Area")   or "Titan Temple"
            local rarity   = egg:GetAttribute("Rarity") or "Common"
            local kg       = egg:GetAttribute("KG")     or 0
            local ok, why  = EvaluateEgg(egg)

            table.insert(cache, {
                Inst    = egg,
                Name    = egg.Name,
                Area    = area,
                Rarity  = rarity,
                KG      = kg,
                Dist    = math.floor(dist),
                OK      = ok,
                Reason  = why,
            })

            if ok then
                local score = Config.Automation.TargetPriority == "HighestKG"
                    and kg
                    or  (100000 - dist)
                if score > bestScore then
                    bestScore = score
                    best      = egg
                end
            end
        end
    end

    State.EggCache = cache
    return best, cache
end

local function NearestTreadmill()
    local folder = Config.Folders.Treadmills
    local hrp    = HRP()
    if not folder or not hrp then return nil end

    local nearest, shortest = nil, math.huge
    for _, t in ipairs(folder:GetChildren()) do
        if t:IsA("Model") or t:IsA("BasePart") then
            local pos  = ModelPos(t)
            local dist = (hrp.Position - pos).Magnitude
            if dist < shortest then shortest = dist; nearest = t end
        end
    end
    return nearest
end

--------------------------------------------------------------------------------
-- 6.  AUTOMATION LOOP  (single Stepped connection, replaced on toggle)
--------------------------------------------------------------------------------
local function StopLoop()
    if State.LoopConn then
        State.LoopConn:Disconnect()
        State.LoopConn = nil
    end
    State.Phase  = "IDLE"
    State.Action = "Automation off"
    State.Target = nil
end

local function StartLoop(onUpdate)
    StopLoop()
    State.LoopConn = RunService.Stepped:Connect(function()
        if not Config.Automation.Enabled then StopLoop(); onUpdate(); return end

        local now = tick()

        -- throttle scanning to avoid frame-rate hammering
        if now - State.LastScan < Config.ScanInterval then
            onUpdate(); return
        end
        State.LastScan = now

        local targetEgg = ScanEggs()

        -- ── STEAL PATH ──────────────────────────────────────────────────────
        if targetEgg then
            State.Target = targetEgg
            local pos    = ModelPos(targetEgg)
            local hrp    = HRP()

            if hrp and (hrp.Position - pos).Magnitude <= Config.MoveRange then
                -- In range: steal
                State.Phase  = "STEALING"
                State.Action = "Stealing: " .. targetEgg.Name
                State.Moving = false

                if now - State.LastSteal >= Config.StealDelay then
                    State.LastSteal = now
                    if Config.Remotes.StealAction then
                        local ok, err = pcall(function()
                            Config.Remotes.StealAction:FireServer(targetEgg)
                        end)
                        if not ok then
                            warn("[NITRO] FireServer error:", err)
                        end
                    end
                end
            else
                -- Out of range: keep walking
                State.Phase  = "MOVING"
                State.Action = "Moving to egg…"
                if not State.Moving then
                    State.Moving = true
                    MoveTo(pos)
                    -- Re-issue MoveTo periodically so humanoid doesn't give up
                    task.delay(1.5, function() State.Moving = false end)
                end
            end

        -- ── TREADMILL FALLBACK ───────────────────────────────────────────
        elseif Config.Automation.TreadmillFallback then
            State.Target = nil
            local tread  = NearestTreadmill()

            if tread then
                local pos = ModelPos(tread)
                local hrp = HRP()

                if hrp and (hrp.Position - pos).Magnitude <= Config.MoveRange then
                    State.Phase  = "TRAINING"
                    State.Action = "Training on treadmill"
                    State.Moving = false
                    if Config.Remotes.TrainAction then
                        pcall(function()
                            Config.Remotes.TrainAction:FireServer(tread)
                        end)
                    end
                else
                    State.Phase  = "MOVING"
                    State.Action = "Moving to treadmill…"
                    if not State.Moving then
                        State.Moving = true
                        MoveTo(pos)
                        task.delay(1.5, function() State.Moving = false end)
                    end
                end
            else
                State.Phase  = "NO_TARGET"
                State.Action = "No treadmill found"
            end

        -- ── WAITING ──────────────────────────────────────────────────────
        else
            State.Target = nil
            State.Phase  = "NO_TARGET"
            State.Action = "No eligible eggs found"
            State.Moving = false
        end

        onUpdate()
    end)
end

--------------------------------------------------------------------------------
-- 7.  GUI CONSTRUCTION
--------------------------------------------------------------------------------

-- Palette
local C = {
    Bg        = Color3.fromRGB(11, 11, 17),
    Surface   = Color3.fromRGB(18, 18, 26),
    Surface2  = Color3.fromRGB(24, 24, 36),
    Border    = Color3.fromRGB(38, 38, 58),
    Accent    = Color3.fromRGB(255, 75, 75),
    AccentDim = Color3.fromRGB(140, 38, 38),
    Green     = Color3.fromRGB(40, 200, 110),
    GreenDim  = Color3.fromRGB(22, 100, 55),
    Yellow    = Color3.fromRGB(255, 195, 50),
    TextHi    = Color3.fromRGB(240, 240, 255),
    TextMid   = Color3.fromRGB(160, 160, 185),
    TextLow   = Color3.fromRGB(90, 90, 115),
    Gold      = Color3.fromRGB(255, 210, 80),
}

local FONT_BOLD   = Enum.Font.GothamBold
local FONT_SEMI   = Enum.Font.GothamSemibold
local FONT_REG    = Enum.Font.Gotham
local FONT_MONO   = Enum.Font.Code

local EASE_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_SPR = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Parent
local parentGui = CoreGui
pcall(function()
    if not game:GetService("RunService"):IsStudio() then
        parentGui = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

-- Destroy any stale instance
local old = parentGui:FindFirstChild("NitroSuiteV3")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "NitroSuiteV3"
ScreenGui.ResetOnSpawn    = false
ScreenGui.DisplayOrder    = 999
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = parentGui

--------------------------------------------------------------------------------
-- WINDOW
--------------------------------------------------------------------------------
local WIN_W, WIN_H = 680, 460

local MainFrame = Instance.new("Frame")
MainFrame.Name                = "Window"
MainFrame.Size                = UDim2.new(0, WIN_W, 0, WIN_H)
MainFrame.Position            = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
MainFrame.BackgroundColor3    = C.Bg
MainFrame.BorderSizePixel     = 0
MainFrame.ClipsDescendants    = true
MainFrame.Parent              = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local winStroke = Instance.new("UIStroke", MainFrame)
winStroke.Color     = C.Border
winStroke.Thickness = 1.2

-- Subtle glow layer behind window (decorative)
local GlowBg = Instance.new("Frame")
GlowBg.Size               = UDim2.new(1, 40, 1, 40)
GlowBg.Position           = UDim2.new(0, -20, 0, -20)
GlowBg.BackgroundColor3   = C.Accent
GlowBg.BackgroundTransparency = 0.92
GlowBg.BorderSizePixel    = 0
GlowBg.ZIndex             = 0
GlowBg.Parent             = MainFrame
Instance.new("UICorner", GlowBg).CornerRadius = UDim.new(0, 20)

--------------------------------------------------------------------------------
-- MOUSE-REACTIVE SPOTLIGHT (follows cursor inside window)
--------------------------------------------------------------------------------
local Spotlight = Instance.new("Frame")
Spotlight.Size                   = UDim2.new(0, 280, 0, 280)
Spotlight.BackgroundColor3       = Color3.fromRGB(120, 60, 255)
Spotlight.BackgroundTransparency = 0.93
Spotlight.BorderSizePixel        = 0
Spotlight.ZIndex                 = 0
Spotlight.Visible                = false
Spotlight.Parent                 = MainFrame
Instance.new("UICorner", Spotlight).CornerRadius = UDim.new(0.5, 0)

local mouseInWindow = false
MainFrame.MouseEnter:Connect(function() mouseInWindow = true;  Spotlight.Visible = true  end)
MainFrame.MouseLeave:Connect(function() mouseInWindow = false; Spotlight.Visible = false end)

RunService.RenderStepped:Connect(function()
    if not mouseInWindow then return end
    local mp = UserInputService:GetMouseLocation()
    local wa = MainFrame.AbsolutePosition
    local mx = mp.X - wa.X - 140
    local my = mp.Y - wa.Y - 140
    TweenService:Create(Spotlight, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0, mx, 0, my)
    }):Play()
end)

--------------------------------------------------------------------------------
-- HEADER
--------------------------------------------------------------------------------
local Header = Instance.new("Frame")
Header.Size               = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3   = C.Surface
Header.BorderSizePixel    = 0
Header.Parent             = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

-- Accent stripe at top of header
local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size             = UDim2.new(1, 0, 0, 2)
HeaderAccent.BackgroundColor3 = C.Accent
HeaderAccent.BorderSizePixel  = 0
HeaderAccent.Parent           = Header

-- Logo / title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size                = UDim2.new(0, 340, 1, 0)
TitleLabel.Position            = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font                = FONT_BOLD
TitleLabel.Text                = "⚡  NITRO · STEAL AN EGG"
TitleLabel.TextColor3          = C.TextHi
TitleLabel.TextSize            = 15
TitleLabel.TextXAlignment      = Enum.TextXAlignment.Left
TitleLabel.Parent              = Header

local SubLabel = Instance.new("TextLabel")
SubLabel.Size                  = UDim2.new(0, 340, 0, 14)
SubLabel.Position              = UDim2.new(0, 16, 1, -15)
SubLabel.BackgroundTransparency = 1
SubLabel.Font                  = FONT_REG
SubLabel.Text                  = "Automation Suite  v3.0"
SubLabel.TextColor3            = C.Accent
SubLabel.TextSize              = 10
SubLabel.TextXAlignment        = Enum.TextXAlignment.Left
SubLabel.Parent                = Header

-- Helper: header icon-button
local function HeaderBtn(icon, bgColor, xOff)
    local b = Instance.new("TextButton")
    b.Size              = UDim2.new(0, 30, 0, 30)
    b.Position          = UDim2.new(1, xOff, 0.5, -15)
    b.BackgroundColor3  = bgColor
    b.Text              = icon
    b.TextColor3        = C.TextHi
    b.Font              = FONT_BOLD
    b.TextSize          = 13
    b.AutoButtonColor   = false
    b.Parent            = Header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, EASE_OUT, {BackgroundTransparency = 0.3}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, EASE_OUT, {BackgroundTransparency = 0}):Play()
    end)
    return b
end

local CloseBtn = HeaderBtn("✕", Color3.fromRGB(200, 50, 50), -10)
local MinBtn   = HeaderBtn("−", Color3.fromRGB(60, 60, 85),  -46)

-- Reopen pill
local ReopenPill = Instance.new("TextButton")
ReopenPill.Name              = "ReopenPill"
ReopenPill.Size              = UDim2.new(0, 140, 0, 38)
ReopenPill.Position          = UDim2.new(0, 14, 0, 14)
ReopenPill.BackgroundColor3  = C.Surface
ReopenPill.Text              = "⚡  NITRO"
ReopenPill.TextColor3        = C.Accent
ReopenPill.Font              = FONT_BOLD
ReopenPill.TextSize          = 14
ReopenPill.Visible           = false
ReopenPill.Parent            = ScreenGui
Instance.new("UICorner", ReopenPill).CornerRadius = UDim.new(0, 10)
local rpStroke = Instance.new("UIStroke", ReopenPill)
rpStroke.Color     = C.Accent
rpStroke.Thickness = 1.2

-- Close confirm modal
local ConfirmOverlay = Instance.new("Frame")
ConfirmOverlay.Size                   = UDim2.new(1, 0, 1, 0)
ConfirmOverlay.BackgroundColor3       = Color3.fromRGB(0,0,0)
ConfirmOverlay.BackgroundTransparency = 0.45
ConfirmOverlay.Visible                = false
ConfirmOverlay.ZIndex                 = 20
ConfirmOverlay.Parent                 = MainFrame

local ConfirmBox = Instance.new("Frame")
ConfirmBox.Size             = UDim2.new(0, 300, 0, 130)
ConfirmBox.Position         = UDim2.new(0.5, -150, 0.5, -65)
ConfirmBox.BackgroundColor3 = C.Surface2
ConfirmBox.BorderSizePixel  = 0
ConfirmBox.ZIndex           = 21
ConfirmBox.Parent           = ConfirmOverlay
Instance.new("UICorner", ConfirmBox).CornerRadius = UDim.new(0, 12)
local cbStroke = Instance.new("UIStroke", ConfirmBox)
cbStroke.Color = C.Border; cbStroke.Thickness = 1

local ConfirmMsg = Instance.new("TextLabel")
ConfirmMsg.Size                   = UDim2.new(1, -24, 0, 50)
ConfirmMsg.Position               = UDim2.new(0, 12, 0, 16)
ConfirmMsg.BackgroundTransparency = 1
ConfirmMsg.Font                   = FONT_SEMI
ConfirmMsg.Text                   = "Close Nitro Suite?"
ConfirmMsg.TextColor3             = C.TextHi
ConfirmMsg.TextSize               = 14
ConfirmMsg.TextWrapped            = true
ConfirmMsg.ZIndex                 = 21
ConfirmMsg.Parent                 = ConfirmBox

local YesBtn = Instance.new("TextButton")
YesBtn.Size             = UDim2.new(0, 120, 0, 32)
YesBtn.Position         = UDim2.new(0.07, 0, 1, -44)
YesBtn.BackgroundColor3 = C.Accent
YesBtn.Text             = "Close"
YesBtn.TextColor3       = C.TextHi
YesBtn.Font             = FONT_BOLD
YesBtn.TextSize         = 12
YesBtn.ZIndex           = 21
YesBtn.Parent           = ConfirmBox
Instance.new("UICorner", YesBtn).CornerRadius = UDim.new(0, 7)

local NoBtn = Instance.new("TextButton")
NoBtn.Size             = UDim2.new(0, 120, 0, 32)
NoBtn.Position         = UDim2.new(0.53, 0, 1, -44)
NoBtn.BackgroundColor3 = C.Surface
NoBtn.Text             = "Cancel"
NoBtn.TextColor3       = C.TextMid
NoBtn.Font             = FONT_SEMI
NoBtn.TextSize         = 12
NoBtn.ZIndex           = 21
NoBtn.Parent           = ConfirmBox
Instance.new("UICorner", NoBtn).CornerRadius = UDim.new(0, 7)

CloseBtn.MouseButton1Click:Connect(function() ConfirmOverlay.Visible = true end)
NoBtn.MouseButton1Click:Connect(function()    ConfirmOverlay.Visible = false end)
YesBtn.MouseButton1Click:Connect(function()
    StopLoop()
    _G.NitroSuiteLoaded = nil
    ScreenGui:Destroy()
end)

-- Minimize / reopen
MinBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, EASE_OUT, {Size = UDim2.new(0,WIN_W,0,0), Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset + WIN_H/2)}):Play()
    task.wait(0.25)
    MainFrame.Visible = false
    ReopenPill.Visible = true
end)

ReopenPill.MouseButton1Click:Connect(function()
    ReopenPill.Visible = false
    MainFrame.Visible  = true
    MainFrame.Size     = UDim2.new(0, WIN_W, 0, 0)
    TweenService:Create(MainFrame, EASE_SPR, {Size = UDim2.new(0, WIN_W, 0, WIN_H), Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)}):Play()
end)

UserInputService.InputBegan:Connect(function(inp, ate)
    if ate then return end
    if inp.KeyCode == Config.GuiKeybind then
        if MainFrame.Visible then
            MinBtn.MouseButton1Click:Fire()
        else
            ReopenPill.MouseButton1Click:Fire()
        end
    end
end)

--------------------------------------------------------------------------------
-- DRAG
--------------------------------------------------------------------------------
do
    local dragging, dragStart, startPos = false, nil, nil
    Header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = inp.Position
            startPos  = MainFrame.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- Resize handle
do
    local ResH = Instance.new("TextButton")
    ResH.Size             = UDim2.new(0, 20, 0, 20)
    ResH.Position         = UDim2.new(1, -20, 1, -20)
    ResH.BackgroundTransparency = 1
    ResH.Text             = "◢"
    ResH.TextColor3       = C.TextLow
    ResH.TextSize         = 12
    ResH.Font             = FONT_REG
    ResH.ZIndex           = 5
    ResH.Parent           = MainFrame

    local resizing, resStart, startSz = false, nil, nil
    ResH.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true; resStart = inp.Position; startSz = MainFrame.AbsoluteSize
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if resizing and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - resStart
            MainFrame.Size = UDim2.new(0,
                math.clamp(startSz.X + d.X, 520, 960), 0,
                math.clamp(startSz.Y + d.Y, 380, 720)
            )
        end
    end)
end

--------------------------------------------------------------------------------
-- SIDEBAR + CONTENT LAYOUT
--------------------------------------------------------------------------------
local SideBar = Instance.new("Frame")
SideBar.Size             = UDim2.new(0, 135, 1, -56)
SideBar.Position         = UDim2.new(0, 8, 0, 54)
SideBar.BackgroundColor3 = C.Surface
SideBar.BorderSizePixel  = 0
SideBar.Parent           = MainFrame
Instance.new("UICorner", SideBar).CornerRadius = UDim.new(0, 10)

local SideList = Instance.new("UIListLayout")
SideList.Padding         = UDim.new(0, 4)
SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideList.Parent          = SideBar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop  = UDim.new(0, 8)
SidePad.PaddingLeft = UDim.new(0, 6)
SidePad.PaddingRight = UDim.new(0, 6)
SidePad.Parent = SideBar

local Content = Instance.new("Frame")
Content.Size             = UDim2.new(1, -152, 1, -62)
Content.Position         = UDim2.new(0, 150, 0, 56)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent           = MainFrame

--------------------------------------------------------------------------------
-- TAB SYSTEM
--------------------------------------------------------------------------------
local TAB_DEFS = {
    {id = "main",     icon = "●", label = "Main"},
    {id = "filters",  icon = "◈", label = "Filters"},
    {id = "auto",     icon = "⚙", label = "Automation"},
    {id = "debug",    icon = "⌗", label = "Debug"},
    {id = "settings", icon = "◇", label = "Settings"},
    {id = "about",    icon = "ℹ", label = "About"},
}

local pages    = {}
local tabBtns  = {}
local activeTab = nil

local function SwitchTab(id)
    if activeTab == id then return end
    activeTab = id
    for tid, page in pairs(pages) do
        page.Visible = (tid == id)
    end
    for tid, btn in pairs(tabBtns) do
        local active = (tid == id)
        TweenService:Create(btn, EASE_OUT, {
            BackgroundColor3 = active and C.Accent or Color3.fromRGB(0,0,0),
            BackgroundTransparency = active and 0 or 1,
        }):Play()
        btn.TextColor3 = active and C.TextHi or C.TextMid
    end
end

for _, def in ipairs(TAB_DEFS) do
    local btn = Instance.new("TextButton")
    btn.Size                    = UDim2.new(1, 0, 0, 34)
    btn.BackgroundTransparency  = 1
    btn.Text                    = def.icon .. "  " .. def.label
    btn.TextColor3              = C.TextMid
    btn.Font                    = FONT_SEMI
    btn.TextSize                = 12
    btn.TextXAlignment          = Enum.TextXAlignment.Left
    btn.AutoButtonColor         = false
    btn.Parent                  = SideBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local bpad = Instance.new("UIPadding", btn)
    bpad.PaddingLeft = UDim.new(0, 10)

    local page = Instance.new("ScrollingFrame")
    page.Size                = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.CanvasSize          = UDim2.new(0, 0, 0, 700)
    page.ScrollBarThickness  = 3
    page.ScrollBarImageColor3 = C.Border
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible             = false
    page.Parent              = Content

    pages[def.id]   = page
    tabBtns[def.id] = btn

    btn.MouseButton1Click:Connect(function() SwitchTab(def.id) end)
    btn.MouseEnter:Connect(function()
        if activeTab ~= def.id then
            TweenService:Create(btn, EASE_OUT, {BackgroundTransparency = 0.85}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= def.id then
            TweenService:Create(btn, EASE_OUT, {BackgroundTransparency = 1}):Play()
        end
    end)
end

SwitchTab("main")

--------------------------------------------------------------------------------
-- COMPONENT HELPERS
--------------------------------------------------------------------------------
local function PageLayout(page, spacing)
    local layout = Instance.new("UIListLayout")
    layout.Padding           = UDim.new(0, spacing or 8)
    layout.FillDirection     = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.SortOrder         = Enum.SortOrder.LayoutOrder
    layout.Parent            = page
    local pad = Instance.new("UIPadding")
    pad.PaddingTop   = UDim.new(0, 10)
    pad.PaddingLeft  = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent       = page
    return layout
end

local function SectionHeader(parent, text, order)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 22)
    f.BackgroundTransparency = 1
    f.LayoutOrder      = order or 0
    f.Parent           = parent

    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Font             = FONT_BOLD
    l.Text             = string.upper(text)
    l.TextColor3       = C.TextLow
    l.TextSize         = 10
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.LetterSpacingModifier = 2
    l.Parent           = f
    return f
end

local function Card(parent, h, order)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, h or 50)
    f.BackgroundColor3 = C.Surface2
    f.BorderSizePixel  = 0
    f.LayoutOrder      = order or 0
    f.Parent           = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", f)
    s.Color = C.Border; s.Thickness = 0.8
    return f
end

local function Label(parent, text, size, color, xAlign)
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1, -12, 1, 0)
    l.Position         = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Font             = FONT_SEMI
    l.Text             = text
    l.TextColor3       = color or C.TextMid
    l.TextSize         = size or 12
    l.TextXAlignment   = xAlign or Enum.TextXAlignment.Left
    l.TextWrapped      = true
    l.Parent           = parent
    return l
end

-- Toggle button factory
local function ToggleButton(parent, labelOn, labelOff, initState, onChange, order)
    local card = Card(parent, 42, order)
    local lbl  = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, -70, 1, 0)
    lbl.Position          = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font              = FONT_SEMI
    lbl.TextColor3        = C.TextMid
    lbl.TextSize          = 12
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.Text              = initState and labelOn or labelOff
    lbl.Parent            = card

    local pill = Instance.new("TextButton")
    pill.Size             = UDim2.new(0, 52, 0, 26)
    pill.Position         = UDim2.new(1, -62, 0.5, -13)
    pill.BackgroundColor3 = initState and C.Green or C.Surface
    pill.Text             = initState and "ON" or "OFF"
    pill.TextColor3       = initState and C.TextHi or C.TextLow
    pill.Font             = FONT_BOLD
    pill.TextSize         = 11
    pill.AutoButtonColor  = false
    pill.Parent           = card
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 13)
    local ps = Instance.new("UIStroke", pill)
    ps.Color = initState and C.GreenDim or C.Border; ps.Thickness = 1

    local state = initState
    pill.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill, EASE_OUT, {BackgroundColor3 = state and C.Green or C.Surface}):Play()
        pill.TextColor3 = state and C.TextHi or C.TextLow
        pill.Text       = state and "ON" or "OFF"
        ps.Color        = state and C.GreenDim or C.Border
        lbl.Text        = state and labelOn or labelOff
        if onChange then onChange(state) end
    end)

    return card, pill, function() return state end
end

-- Cycle button (cycles through options)
local function CycleButton(parent, options, initIdx, onChange, order)
    local card = Card(parent, 42, order)
    local idx  = initIdx or 1

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(0.55, 0, 1, 0)
    lbl.Position          = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font              = FONT_SEMI
    lbl.TextColor3        = C.TextMid
    lbl.TextSize          = 12
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.Text              = options[idx].label
    lbl.Parent            = card

    local valLbl = Instance.new("TextButton")
    valLbl.Size           = UDim2.new(0, 140, 0, 28)
    valLbl.Position       = UDim2.new(1, -148, 0.5, -14)
    valLbl.BackgroundColor3 = C.Surface
    valLbl.Text           = options[idx].value
    valLbl.TextColor3     = C.Gold
    valLbl.Font           = FONT_BOLD
    valLbl.TextSize       = 11
    valLbl.AutoButtonColor = false
    valLbl.Parent         = card
    Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 7)
    local vs = Instance.new("UIStroke", valLbl)
    vs.Color = C.Border; vs.Thickness = 0.8

    valLbl.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        valLbl.Text = options[idx].value
        lbl.Text    = options[idx].label
        TweenService:Create(valLbl, TweenInfo.new(0.1), {TextColor3 = C.Accent}):Play()
        task.delay(0.15, function()
            TweenService:Create(valLbl, TweenInfo.new(0.1), {TextColor3 = C.Gold}):Play()
        end)
        if onChange then onChange(options[idx]) end
    end)
    return card
end

-- Filter checklist item
local function CheckItem(parent, text, initOn, onChange, order)
    local row = Instance.new("TextButton")
    row.Size              = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3  = initOn and Color3.fromRGB(22, 50, 35) or C.Surface2
    row.BorderSizePixel   = 0
    row.AutoButtonColor   = false
    row.LayoutOrder       = order or 0
    row.Parent            = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local rs = Instance.new("UIStroke", row)
    rs.Color = initOn and C.GreenDim or C.Border; rs.Thickness = 0.8

    local check = Instance.new("TextLabel")
    check.Size              = UDim2.new(0, 18, 0, 18)
    check.Position          = UDim2.new(0, 10, 0.5, -9)
    check.BackgroundColor3  = initOn and C.Green or C.Surface
    check.Text              = initOn and "✓" or ""
    check.TextColor3        = C.TextHi
    check.Font              = FONT_BOLD
    check.TextSize          = 11
    check.BorderSizePixel   = 0
    check.Parent            = row
    Instance.new("UICorner", check).CornerRadius = UDim.new(0, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, -40, 1, 0)
    lbl.Position          = UDim2.new(0, 36, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font              = FONT_SEMI
    lbl.Text              = text
    lbl.TextColor3        = initOn and C.TextHi or C.TextMid
    lbl.TextSize          = 12
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.Parent            = row

    local on = initOn
    row.MouseButton1Click:Connect(function()
        on = not on
        TweenService:Create(row, EASE_OUT, {BackgroundColor3 = on and Color3.fromRGB(22,50,35) or C.Surface2}):Play()
        rs.Color    = on and C.GreenDim or C.Border
        check.BackgroundColor3 = on and C.Green or C.Surface
        check.Text  = on and "✓" or ""
        lbl.TextColor3 = on and C.TextHi or C.TextMid
        if onChange then onChange(on) end
    end)
    return row
end

--------------------------------------------------------------------------------
-- STATUS BAR (bottom of window)
--------------------------------------------------------------------------------
local StatusBar = Instance.new("Frame")
StatusBar.Size             = UDim2.new(1, 0, 0, 28)
StatusBar.Position         = UDim2.new(0, 0, 1, -28)
StatusBar.BackgroundColor3 = C.Surface
StatusBar.BorderSizePixel  = 0
StatusBar.Parent           = MainFrame

local StatusText = Instance.new("TextLabel")
StatusText.Size              = UDim2.new(1, -20, 1, 0)
StatusText.Position          = UDim2.new(0, 12, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font              = FONT_MONO
StatusText.Text              = "Idle"
StatusText.TextColor3        = C.TextLow
StatusText.TextSize          = 11
StatusText.TextXAlignment    = Enum.TextXAlignment.Left
StatusText.Parent            = StatusBar

-- Pulsing activity dot
local PulseDot = Instance.new("Frame")
PulseDot.Size             = UDim2.new(0, 8, 0, 8)
PulseDot.Position         = UDim2.new(1, -18, 0.5, -4)
PulseDot.BackgroundColor3 = C.TextLow
PulseDot.BorderSizePixel  = 0
PulseDot.Parent           = StatusBar
Instance.new("UICorner", PulseDot).CornerRadius = UDim.new(0.5, 0)

local dotPulsing = false
local function SetDotActive(active)
    if active == dotPulsing then return end
    dotPulsing = active
    if active then
        local function pulse()
            if not dotPulsing then
                TweenService:Create(PulseDot, EASE_OUT, {BackgroundTransparency = 0, BackgroundColor3 = C.Green}):Play()
                return
            end
            TweenService:Create(PulseDot, TweenInfo.new(0.6), {BackgroundTransparency = 0.1, BackgroundColor3 = C.Green}):Play()
            task.delay(0.6, function()
                if not dotPulsing then return end
                TweenService:Create(PulseDot, TweenInfo.new(0.6), {BackgroundTransparency = 0.7}):Play()
                task.delay(0.6, pulse)
            end)
        end
        pulse()
    else
        TweenService:Create(PulseDot, EASE_OUT, {BackgroundColor3 = C.TextLow, BackgroundTransparency = 0}):Play()
    end
end

--------------------------------------------------------------------------------
-- ── PAGE: MAIN ───────────────────────────────────────────────────────────────
--------------------------------------------------------------------------------
do
    local page = pages["main"]
    PageLayout(page, 8)

    SectionHeader(page, "Control", 1)

    -- Master enable toggle
    local masterCard, masterPill = ToggleButton(
        page,
        "Automation Active",
        "Automation Disabled",
        false,
        function(on)
            Config.Automation.Enabled = on
            if on then
                StartLoop(function()
                    -- UI update happens below via Stepped
                end)
            else
                StopLoop()
            end
            SetDotActive(on)
        end,
        2
    )

    SectionHeader(page, "Live Status", 3)

    -- Status card
    local statCard = Card(page, 110, 4)
    local statLayout = Instance.new("UIListLayout")
    statLayout.Padding        = UDim.new(0, 6)
    statLayout.Parent         = statCard
    local statPad = Instance.new("UIPadding")
    statPad.PaddingTop = UDim.new(0,8); statPad.PaddingLeft = UDim.new(0,12)
    statPad.Parent = statCard

    local function StatRow(key, val)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -12, 0, 20)
        row.BackgroundTransparency = 1
        row.Parent = statCard

        local kl = Instance.new("TextLabel")
        kl.Size = UDim2.new(0, 100, 1, 0)
        kl.BackgroundTransparency = 1
        kl.Font = FONT_SEMI
        kl.Text = key
        kl.TextColor3 = C.TextLow
        kl.TextSize = 11
        kl.TextXAlignment = Enum.TextXAlignment.Left
        kl.Parent = row

        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(1, -104, 1, 0)
        vl.Position = UDim2.new(0, 104, 0, 0)
        vl.BackgroundTransparency = 1
        vl.Font = FONT_MONO
        vl.Text = val
        vl.TextColor3 = C.TextHi
        vl.TextSize = 11
        vl.TextXAlignment = Enum.TextXAlignment.Left
        vl.Parent = row
        return vl
    end

    local statusPhase  = StatRow("Phase",  "IDLE")
    local statusAction = StatRow("Action", "—")
    local statusTarget = StatRow("Target", "None")
    local statusEggs   = StatRow("Eggs found", "0")

    -- Wire status update into the loop
    RunService.Stepped:Connect(function()
        statusPhase.Text  = State.Phase
        statusAction.Text = State.Action
        statusTarget.Text = State.Target and State.Target.Name or "None"
        statusEggs.Text   = tostring(#State.EggCache)

        local c = C.TextHi
        if State.Phase == "STEALING"  then c = C.Accent
        elseif State.Phase == "TRAINING" then c = C.Yellow
        elseif State.Phase == "MOVING"   then c = Color3.fromRGB(80,180,255)
        elseif State.Phase == "IDLE"     then c = C.TextLow
        end
        statusPhase.TextColor3 = c

        StatusText.Text = State.Phase .. " · " .. State.Action
        SetDotActive(Config.Automation.Enabled)
    end)

    SectionHeader(page, "Quick Actions", 5)

    local qCard = Card(page, 42, 6)
    local scanNowBtn = Instance.new("TextButton")
    scanNowBtn.Size             = UDim2.new(0, 130, 0, 28)
    scanNowBtn.Position         = UDim2.new(0, 10, 0.5, -14)
    scanNowBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 140)
    scanNowBtn.Text             = "Scan Now"
    scanNowBtn.TextColor3       = C.TextHi
    scanNowBtn.Font             = FONT_SEMI
    scanNowBtn.TextSize         = 12
    scanNowBtn.AutoButtonColor  = false
    scanNowBtn.Parent           = qCard
    Instance.new("UICorner", scanNowBtn).CornerRadius = UDim.new(0, 7)

    scanNowBtn.MouseButton1Click:Connect(function()
        ScanEggs()
        scanNowBtn.Text = "Scanned ✓"
        task.delay(1.2, function() scanNowBtn.Text = "Scan Now" end)
    end)

    local goTreadBtn = Instance.new("TextButton")
    goTreadBtn.Size             = UDim2.new(0, 160, 0, 28)
    goTreadBtn.Position         = UDim2.new(0, 150, 0.5, -14)
    goTreadBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
    goTreadBtn.Text             = "Go to Treadmill"
    goTreadBtn.TextColor3       = C.TextHi
    goTreadBtn.Font             = FONT_SEMI
    goTreadBtn.TextSize         = 12
    goTreadBtn.AutoButtonColor  = false
    goTreadBtn.Parent           = qCard
    Instance.new("UICorner", goTreadBtn).CornerRadius = UDim.new(0, 7)

    goTreadBtn.MouseButton1Click:Connect(function()
        local t = NearestTreadmill()
        if t then MoveTo(ModelPos(t)) end
    end)
end

--------------------------------------------------------------------------------
-- ── PAGE: FILTERS ────────────────────────────────────────────────────────────
--------------------------------------------------------------------------------
do
    local page = pages["filters"]
    PageLayout(page, 8)

    SectionHeader(page, "Areas", 1)

    local areaCard = Card(page, 10, 2) -- auto-height via list layout
    areaCard.AutomaticSize = Enum.AutomaticSize.Y
    local areaList = Instance.new("UIListLayout")
    areaList.Padding = UDim.new(0, 4)
    areaList.Parent  = areaCard
    local aPad = Instance.new("UIPadding")
    aPad.PaddingTop = UDim.new(0,8); aPad.PaddingBottom = UDim.new(0,8)
    aPad.PaddingLeft = UDim.new(0,8); aPad.PaddingRight = UDim.new(0,8)
    aPad.Parent = areaCard

    for i, area in ipairs({"Titan Temple","Cherry Blossom","Cosmic","Forest","Lake","Desert"}) do
        CheckItem(areaCard, area, Has(Config.Filters.Areas, area), function(on)
            if on then
                if not Has(Config.Filters.Areas, area) then
                    table.insert(Config.Filters.Areas, area)
                end
            else
                Remove(Config.Filters.Areas, area)
            end
        end, i)
    end

    SectionHeader(page, "Rarities", 3)

    local rarCard = Card(page, 10, 4)
    rarCard.AutomaticSize = Enum.AutomaticSize.Y
    local rarList = Instance.new("UIListLayout")
    rarList.Padding = UDim.new(0, 4)
    rarList.Parent  = rarCard
    local rPad = Instance.new("UIPadding")
    rPad.PaddingTop = UDim.new(0,8); rPad.PaddingBottom = UDim.new(0,8)
    rPad.PaddingLeft = UDim.new(0,8); rPad.PaddingRight = UDim.new(0,8)
    rPad.Parent = rarCard

    local rarityColors = {
        Common    = C.TextMid,
        Rare      = Color3.fromRGB(80,160,255),
        Epic      = Color3.fromRGB(160,80,255),
        Legendary = C.Gold,
        Mythic    = Color3.fromRGB(255,80,160),
        Secret    = Color3.fromRGB(255,220,60),
    }

    for i, rar in ipairs({"Common","Rare","Epic","Legendary","Mythic","Secret"}) do
        local row = CheckItem(rarCard, rar, Has(Config.Filters.Rarities, rar), function(on)
            if on then
                if not Has(Config.Filters.Rarities, rar) then
                    table.insert(Config.Filters.Rarities, rar)
                end
            else
                Remove(Config.Filters.Rarities, rar)
            end
        end, i)
        -- Tint rarity label
        local lbl = row:FindFirstChildOfClass("TextLabel")
        if lbl and rarityColors[rar] then
            lbl.TextColor3 = rarityColors[rar]
        end
    end
end

--------------------------------------------------------------------------------
-- ── PAGE: AUTOMATION ─────────────────────────────────────────────────────────
--------------------------------------------------------------------------------
do
    local page = pages["auto"]
    PageLayout(page, 8)

    SectionHeader(page, "Target Priority", 1)

    CycleButton(page, {
        {label = "Priority Mode", value = "Highest KG"},
        {label = "Priority Mode", value = "Closest Distance"},
    }, 1, function(opt)
        Config.Automation.TargetPriority = opt.value == "Highest KG" and "HighestKG" or "Closest"
    end, 2)

    SectionHeader(page, "Timing", 3)

    -- Steal delay cycle
    CycleButton(page, {
        {label = "Steal Delay", value = "0.3s (Fast)"},
        {label = "Steal Delay", value = "0.55s (Normal)"},
        {label = "Steal Delay", value = "1.0s (Safe)"},
        {label = "Steal Delay", value = "1.5s (Slow)"},
    }, 2, function(opt)
        local map = {["0.3s (Fast)"]=0.3, ["0.55s (Normal)"]=0.55, ["1.0s (Safe)"]=1.0, ["1.5s (Slow)"]=1.5}
        Config.StealDelay = map[opt.value] or 0.55
    end, 4)

    SectionHeader(page, "Fallback Behavior", 5)

    ToggleButton(page,
        "Use Treadmill when no eggs",
        "Wait idle when no eggs",
        Config.Automation.TreadmillFallback,
        function(on) Config.Automation.TreadmillFallback = on end,
        6
    )

    SectionHeader(page, "Movement", 7)

    CycleButton(page, {
        {label = "Interact Range", value = "5 studs"},
        {label = "Interact Range", value = "7 studs"},
        {label = "Interact Range", value = "10 studs"},
        {label = "Interact Range", value = "14 studs"},
    }, 2, function(opt)
        local map = {["5 studs"]=5, ["7 studs"]=7, ["10 studs"]=10, ["14 studs"]=14}
        Config.MoveRange = map[opt.value] or 7
    end, 8)
end

--------------------------------------------------------------------------------
-- ── PAGE: DEBUG ──────────────────────────────────────────────────────────────
--------------------------------------------------------------------------------
do
    local page = pages["debug"]
    local pad  = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0,8); pad.PaddingLeft = UDim.new(0,4); pad.PaddingRight = UDim.new(0,10)

    local hdr = SectionHeader(page, "Egg Scanner Output", 1)
    hdr.LayoutOrder = 1

    local logFrame = Card(page, 500, 2)
    logFrame.AutomaticSize = Enum.AutomaticSize.None
    logFrame.Size = UDim2.new(1, 0, 0, 480)

    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size              = UDim2.new(1, -10, 1, -10)
    logScroll.Position          = UDim2.new(0, 5, 0, 5)
    logScroll.BackgroundTransparency = 1
    logScroll.CanvasSize        = UDim2.new(0, 0, 0, 2000)
    logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logScroll.ScrollBarThickness = 3
    logScroll.ScrollBarImageColor3 = C.Border
    logScroll.Parent            = logFrame

    local logText = Instance.new("TextLabel")
    logText.Size              = UDim2.new(1, -8, 0, 2000)
    logText.BackgroundTransparency = 1
    logText.Font              = FONT_MONO
    logText.Text              = "Waiting for scan…"
    logText.TextColor3        = Color3.fromRGB(80, 220, 100)
    logText.TextSize          = 11
    logText.TextXAlignment    = Enum.TextXAlignment.Left
    logText.TextYAlignment    = Enum.TextYAlignment.Top
    logText.TextWrapped       = true
    logText.RichText          = true
    logText.Parent            = logScroll

    -- Update debug log every 0.5s when on debug tab
    local lastDebugUpdate = 0
    RunService.Stepped:Connect(function()
        if not (pages["debug"] and pages["debug"].Visible) then return end
        if tick() - lastDebugUpdate < 0.5 then return end
        lastDebugUpdate = tick()

        local lines = {"<font color='#4ecdc4'>── NITRO DEBUG ──────────────────────────────</font>",
            string.format("<font color='#aaaacc'>Phase: <font color='#ffffff'>%s</font>  |  Action: %s</font>", State.Phase, State.Action),
            string.format("<font color='#aaaacc'>Target: <font color='#ffffff'>%s</font></font>", State.Target and State.Target.Name or "None"),
            "",
            string.format("<font color='#aaaacc'>Eggs scanned: <font color='#ffffff'>%d</font></font>", #State.EggCache),
            "",
        }
        for _, info in ipairs(State.EggCache) do
            local col = info.OK and "#44ff88" or "#ff5555"
            table.insert(lines, string.format(
                "<font color='%s'>[%s] %s — %s · %s · KG:%s · Dist:%s</font>",
                col, info.OK and "✓" or "✗",
                info.Name, info.Area, info.Rarity,
                tostring(info.KG), tostring(info.Dist)
            ))
            if not info.OK then
                table.insert(lines, string.format("<font color='#777799'>    %s</font>", info.Reason))
            end
        end
        logText.Text = table.concat(lines, "\n")
    end)
end

--------------------------------------------------------------------------------
-- ── PAGE: SETTINGS ───────────────────────────────────────────────────────────
--------------------------------------------------------------------------------
do
    local page = pages["settings"]
    PageLayout(page, 8)

    SectionHeader(page, "Keybind", 1)

    local kbCard = Card(page, 42, 2)
    local kbLabel = Instance.new("TextLabel")
    kbLabel.Size              = UDim2.new(1, -12, 1, 0)
    kbLabel.Position          = UDim2.new(0, 12, 0, 0)
    kbLabel.BackgroundTransparency = 1
    kbLabel.Font              = FONT_SEMI
    kbLabel.Text              = "Toggle GUI:  RightControl"
    kbLabel.TextColor3        = C.TextMid
    kbLabel.TextSize          = 12
    kbLabel.TextXAlignment    = Enum.TextXAlignment.Left
    kbLabel.Parent            = kbCard

    SectionHeader(page, "Min KG Filter", 3)

    -- Min KG cycle
    CycleButton(page, {
        {label = "Minimum KG", value = "0 (None)"},
        {label = "Minimum KG", value = "1000"},
        {label = "Minimum KG", value = "5000"},
        {label = "Minimum KG", value = "10000"},
        {label = "Minimum KG", value = "50000"},
    }, 1, function(opt)
        local map = {["0 (None)"]=0, ["1000"]=1000, ["5000"]=5000, ["10000"]=10000, ["50000"]=50000}
        Config.Filters.MinKG = map[opt.value] or 0
    end, 4)
end

--------------------------------------------------------------------------------
-- ── PAGE: ABOUT ──────────────────────────────────────────────────────────────
--------------------------------------------------------------------------------
do
    local page = pages["about"]
    local pad  = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0,10); pad.PaddingLeft = UDim.new(0,6); pad.PaddingRight = UDim.new(0,10)

    local aCard = Card(page, 200, 1)
    aCard.AutomaticSize = Enum.AutomaticSize.Y
    local aPad = Instance.new("UIPadding", aCard)
    aPad.PaddingAll = UDim.new(0,14)

    local lines = {
        {"⚡  NITRO · STEAL AN EGG", 16, C.TextHi, FONT_BOLD},
        {"Automation Suite  v3.0", 12, C.Accent, FONT_SEMI},
        {"", 8, C.TextLow, FONT_REG},
        {"Fully polished UI with mouse-reactive spotlight,", 11, C.TextMid, FONT_REG},
        {"reliable steal + treadmill automation loop,", 11, C.TextMid, FONT_REG},
        {"area/rarity filters, and live debug console.", 11, C.TextMid, FONT_REG},
        {"", 8, C.TextLow, FONT_REG},
        {"Toggle GUI:  RightControl", 11, C.TextLow, FONT_MONO},
        {"Version:  3.0.0", 11, C.TextLow, FONT_MONO},
    }

    local aLayout = Instance.new("UIListLayout")
    aLayout.Padding = UDim.new(0, 4)
    aLayout.Parent  = aCard

    for i, row in ipairs(lines) do
        local l = Instance.new("TextLabel")
        l.Size              = UDim2.new(1, 0, 0, row[2] + 6)
        l.BackgroundTransparency = 1
        l.Font              = row[4]
        l.Text              = row[1]
        l.TextColor3        = row[3]
        l.TextSize          = row[2]
        l.TextXAlignment    = Enum.TextXAlignment.Left
        l.TextWrapped       = true
        l.LayoutOrder       = i
        l.Parent            = aCard
    end
end

--------------------------------------------------------------------------------
-- ENTRY ANIMATION
--------------------------------------------------------------------------------
MainFrame.Size = UDim2.new(0, WIN_W, 0, 0)
MainFrame.BackgroundTransparency = 0.3
TweenService:Create(MainFrame, EASE_SPR, {
    Size = UDim2.new(0, WIN_W, 0, WIN_H),
    BackgroundTransparency = 0,
}):Play()

print("[NITRO Suite v3.0] Loaded — toggle with RightControl")
