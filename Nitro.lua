local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Steal An Egg | Rayfield",
   LoadingTitle = "Steal An Egg",
   LoadingSubtitle = "by you",
   Theme = "Default",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "StealAnEgg",
      FileName = "Config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false
})

-- Main Tab
local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateSection("Player")

MainTab:CreateToggle({
   Name = "Speed Boost",
   CurrentValue = false,
   Flag = "SpeedBoost",
   Callback = function(Value)
      -- Add your speed code here
   end,
})

MainTab:CreateSlider({
   Name = "WalkSpeed",
   Range = {16, 200},
   Increment = 1,
   CurrentValue = 16,
   Flag = "WalkSpeed",
   Callback = function(Value)
      -- Add your walkspeed code here
   end,
})

MainTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "InfJump",
   Callback = function(Value)
      -- Add your infinite jump code here
   end,
})

-- Auto Farm Tab
local AutoTab = Window:CreateTab("Auto Farm", 4483362458)

AutoTab:CreateSection("Egg Features")

AutoTab:CreateToggle({
   Name = "Auto Steal",
   CurrentValue = false,
   Flag = "AutoSteal",
   Callback = function(Value)
      -- Add your auto steal code here
   end,
})

AutoTab:CreateToggle({
   Name = "Auto Hatch",
   CurrentValue = false,
   Flag = "AutoHatch",
   Callback = function(Value)
      -- Add your auto hatch code here
   end,
})

AutoTab:CreateToggle({
   Name = "Auto Place Pet",
   CurrentValue = false,
   Flag = "AutoPlace",
   Callback = function(Value)
      -- Add your auto place code here
   end,
})

-- Teleport Tab
local TPTab = Window:CreateTab("Teleport", 4483362458)

TPTab:CreateSection("Locations")

TPTab:CreateButton({
   Name = "Teleport to Base",
   Callback = function()
      -- Add teleport to base code here
   end,
})

TPTab:CreateButton({
   Name = "Teleport to Forest",
   Callback = function()
      -- Add teleport code here
   end,
})

TPTab:CreateButton({
   Name = "Teleport to Lake",
   Callback = function()
      -- Add teleport code here
   end,
})

-- Misc Tab
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Utility")

MiscTab:CreateButton({
   Name = "Destroy UI",
   Callback = function()
      Rayfield:Destroy()
   end,
})

MiscTab:CreateLabel("Steal An Egg Script")
MiscTab:CreateLabel("Customize the callbacks yourself")

Rayfield:LoadConfiguration()
