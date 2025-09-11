--[[
    Potato Graphics Toggle GUI
    Small, draggable button to enable/disable Potato Mode.
    Author: ZenScripter
--]]

local uis = game:GetService("UserInputService")
local plr = game:GetService("Players").LocalPlayer
local pgui = plr:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PotatoToggleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = pgui

-- Create Drag Frame
local dragFrame = Instance.new("Frame")
dragFrame.Size = UDim2.new(0, 80, 0, 32)
dragFrame.Position = UDim2.new(0, 30, 0, 30)
dragFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
dragFrame.BorderSizePixel = 0
dragFrame.Active = true
dragFrame.Draggable = true -- Old property, works with most executors
dragFrame.Parent = screenGui

-- Small Button
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, 0, 1, 0)
btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
btn.Text = "Potato: OFF"
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 15
btn.Parent = dragFrame

-- Potato Mode Functions
local function setPotato(on)
    if on then
        btn.Text = "Potato: ON"
        btn.BackgroundColor3 = Color3.fromRGB(200,120,40)
        -- Apply potato graphics (partial summary, call your actual function here!)
        pcall(function()
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e5
            Lighting.Brightness = 0.5
            Lighting.OutdoorAmbient = Color3.new(1,1,1)
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            Lighting.ClockTime = 14
            local Terrain = workspace:FindFirstChildOfClass("Terrain")
            if Terrain then
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterColor = Color3.new(0,0,0)
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke")
                    or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Explosion")
                    or obj:IsA("Decal") or obj:IsA("Texture") then
                    obj:Destroy()
                elseif obj:IsA("BasePart") then
                    obj.CastShadow = false
                    obj.Reflectance = 0
                    obj.Material = Enum.Material.Plastic
                end
            end
            for _, s in ipairs(workspace:GetDescendants()) do
                if s:IsA("Sound") then
                    s:Stop()
                    s.Volume = 0
                    s.Playing = false
                end
            end
            if setfpscap then setfpscap(60) elseif setfps then setfps(60) end
        end)
    else
        btn.Text = "Potato: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
        -- Restore (Note: Only reverses basic settings)
        pcall(function()
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 1000
            Lighting.Brightness = 2
            Lighting.OutdoorAmbient = Color3.new(0.5,0.5,0.5)
            Lighting.EnvironmentDiffuseScale = 1
            Lighting.EnvironmentSpecularScale = 1
            Lighting.ClockTime = 12
        end)
    end
end

local potatoOn = false
btn.MouseButton1Click:Connect(function()
    potatoOn = not potatoOn
    setPotato(potatoOn)
end)

-- Additional drag support (for newer executors/users)
local dragging, dragInput, dragStart, startPos
dragFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = dragFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
dragFrame.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        dragFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

print("Potato Graphics GUI loaded! Drag and click to toggle.")
