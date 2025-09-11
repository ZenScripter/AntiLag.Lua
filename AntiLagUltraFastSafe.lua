-- ZenScripter's UltraFast SAFE AntiLag.lua
-- LocalScript compatible. Place in StarterPlayerScripts, PlayerGui, or use executor.

local plr = game:GetService("Players").LocalPlayer
local pgui = plr:WaitForChild("PlayerGui")
local runService = game:GetService("RunService")

-- Only create GUI if not already present
if not pgui:FindFirstChild("AntiLagUltraGui") then
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

    -- Drag Support
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

    -- Exclusion filters (case-insensitive)
    local function isExcluded(obj)
        -- Don't affect player character or any part of it
        if plr.Character and obj:IsDescendantOf(plr.Character) then return true end

        -- Don't affect hitboxes or ability parts
        local n = obj.Name:lower()
        if n:find("hitbox") or n:find("ability") or n:find("sound") then return true end

        -- Don't affect sounds named music, ability, or emote
        if obj:IsA("Sound") then
            if n:find("music") or n:find("ability") or n:find("emote") then return true end
        end

        return false
    end

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
            if isExcluded(obj) then continue end
            for _, t in ipairs(laggyTypes) do
                if obj:IsA(t) then
                    pcall(function() obj:Destroy() end)
                end
            end
            if obj:IsA("BasePart") then
                obj.CastShadow = false
                obj.Reflectance = 0
                if obj.Material ~= Enum.Material.Plastic then
                    obj.Material = Enum.Material.Plastic
                end
            end
        end
        for _, s in ipairs(workspace:GetDescendants()) do
            if s:IsA("Sound") then
                if not isExcluded(s) then
                    pcall(function()
                        s.Volume = 0
                        s.Playing = false
                    end)
                end
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
            if lightingLoop then lightingLoop:Disconnect() end
            if laggyLoop then laggyLoop:Disconnect() end
            lightingLoop = runService.RenderStepped:Connect(function()
                potatoLighting()
            end)
            laggyLoop = runService.RenderStepped:Connect(function()
                if tick() % 2 < 0.03 then
                    removeLaggyObjects()
                end
            end)
        else
            btn.Text = "Potato: OFF"
            btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
            if lightingLoop then lightingLoop:Disconnect() end
            if laggyLoop then laggyLoop:Disconnect() end
            -- Restore basic lighting
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
end

-- GUI persistence: If GUI gets removed by the game (e.g., new round), re-parent it:
local function ensureGui()
    local gui = pgui:FindFirstChild("AntiLagUltraGui")
    if not gui then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ZenScripter/AntiLag.Lua/main/AntiLagUltraFastSafe.lua"))()
    end
end

game:GetService("RunService").RenderStepped:Connect(function()
    ensureGui()
end)

print("AntiLagUltraFastSafe Loaded! GUI is persistent, player and abilities remain visible, sounds/music not muted.")
