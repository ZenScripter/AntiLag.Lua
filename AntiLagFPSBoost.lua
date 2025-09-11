-- ZenScripter's FPS-Safe AntiLag.lua
-- LocalScript compatible. Place in StarterPlayerScripts or use executor.

local plr = game:GetService("Players").LocalPlayer
local pgui = plr:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiLagUltraGui"
screenGui.Parent = pgui

local dragFrame = Instance.new("Frame")
dragFrame.Size = UDim2.new(0,90,0,36)
dragFrame.Position = UDim2.new(0,30,0,30)
dragFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
dragFrame.BorderSizePixel = 0
dragFrame.Active = true
dragFrame.Selectable = true
dragFrame.Parent = screenGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1,0,1,0)
btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
btn.Text = "Potato: OFF"
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 16
btn.Parent = dragFrame

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
            -- Only set material if it's not already Plastic for less lag
            if obj.Material ~= Enum.Material.Plastic then
                obj.Material = Enum.Material.Plastic
            end
        end
    end
    for _, s in ipairs(workspace:GetDescendants()) do
        if s:IsA("Sound") then
            pcall(function()
                s.Volume = 0
                s.Playing = false
            end)
        end
    end
end

local potatoOn = false
local lightingLoop, laggyLoop
local function setPotato(on)
    potatoOn = on
    if on then
        btn.Text = "Potato: ON"
        btn.BackgroundColor3 = Color3.fromRGB(200,120,40)
        -- Lighting loop every 1s
        lightingLoop = coroutine.create(function()
            while potatoOn do
                potatoLighting()
                wait(1)
            end
        end)
        coroutine.resume(lightingLoop)
        -- Laggy remover loop every 2s
        laggyLoop = coroutine.create(function()
            while potatoOn do
                removeLaggyObjects()
                wait(2)
            end
        end)
        coroutine.resume(laggyLoop)
    else
        btn.Text = "Potato: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
        potatoOn = false
        -- No need to manually kill coroutines, they will exit on next loop since potatoOn is now false
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

print("AntiLagUltraFastOptimized Loaded! Drag GUI and click to toggle Potato Mode.")

-- Uncomment below to start ON by default
-- setPotato(true)
