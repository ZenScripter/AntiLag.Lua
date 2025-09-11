--[[
    ZenScripter's AntiLagFixed.lua
    - LocalScript compatible (StarterPlayerScripts/PlayerGui)
    - Fast GUI toggle
    - RenderStepped loop for instant lag cleanup
    - Hardcore anti-lag defense
--]]

local plr = game:GetService("Players").LocalPlayer
local pgui = plr:WaitForChild("PlayerGui")

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiLagUltraGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = pgui

local dragFrame = Instance.new("Frame")
dragFrame.Size = UDim2.new(0, 90, 0, 36)
dragFrame.Position = UDim2.new(0, 30, 0, 30)
dragFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
dragFrame.BorderSizePixel = 0
dragFrame.Active = true
dragFrame.Selectable = true
dragFrame.Parent = screenGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, 0, 1, 0)
btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
btn.Text = "Potato: OFF"
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 16
btn.Parent = dragFrame

-- Drag Support (modern)
local uis = game:GetService("UserInputService")
local dragging, dragStart, startPos
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
uis.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        dragFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Anti-Lag Logic
local laggyTypes = {
    "ParticleEmitter", "Trail", "Smoke", "Fire", "Sparkles", "Explosion",
    "Decal", "Texture", "MeshPart", "SurfaceAppearance"
}

local function potatoLighting()
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness = 5
    Lighting.FogEnd = 1e6
    Lighting.FogStart = 0
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.new(1,1,1)
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.ClockTime = 14
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect")
        or effect:IsA("SunRaysEffect") or effect:IsA("BloomEffect") then
            effect.Enabled = false
        end
    end
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterColor = Color3.new(0,0,0)
    end
end

local function removeLaggyObjects()
    for _, obj in ipairs(workspace:GetDescendants()) do
        for _, t in ipairs(laggyTypes) do
            if obj:IsA(t) then
                pcall(function() obj:Destroy() end)
            end
        end
        if obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Material = Enum.Material.Plastic
        end
    end
    for _, s in ipairs(workspace:GetDescendants()) do
        if s:IsA("Sound") then
            pcall(function()
                s:Stop()
                s.Volume = 0
                s.Playing = false
            end)
        end
    end
end

local function antiAntiLag()
    local Lighting = game:GetService("Lighting")
    Lighting.Changed:Connect(potatoLighting)
    Lighting.ChildAdded:Connect(potatoLighting)
    workspace.DescendantAdded:Connect(function(desc)
        removeLaggyObjects()
    end)
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if Terrain then Terrain.Changed:Connect(potatoLighting) end
end

-- Toggle Logic
local potatoOn = false
local potatoLoop
local function setPotato(on)
    potatoOn = on
    if on then
        btn.Text = "Potato: ON"
        btn.BackgroundColor3 = Color3.fromRGB(200,120,40)
        if potatoLoop then potatoLoop:Disconnect() end
        potatoLoop = game:GetService("RunService").RenderStepped:Connect(function()
            potatoLighting()
            removeLaggyObjects()
        end)
        antiAntiLag()
    else
        btn.Text = "Potato: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
        if potatoLoop then potatoLoop:Disconnect() end
        -- (Optional) Restore basic lighting
        pcall(function()
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 1000
            Lighting.FogStart = 0
            Lighting.Brightness = 2
            Lighting.OutdoorAmbient = Color3.new(0.5,0.5,0.5)
            Lighting.EnvironmentDiffuseScale = 1
            Lighting.EnvironmentSpecularScale = 1
            Lighting.ClockTime = 12
        end)
    end
end

btn.MouseButton1Click:Connect(function()
    setPotato(not potatoOn)
end)

print("AntiLagFixed LocalScript Loaded! Drag GUI and click to toggle Potato Mode.")
