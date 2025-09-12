-- Super-Fast, No-GUI AntiLag Script for Roblox
-- Place in StarterPlayerScripts or run with your executor.

local plr = game:GetService("Players").LocalPlayer

-- Whitelist: Never remove/touch these object types/names!
local whitelist = {"Hitbox", "Ability", "Music", "Emote", "Player", "Humanoid", "GUI"}
local laggyTypes = {
    "ParticleEmitter", "Trail", "Smoke", "Fire", "Sparkles", "Explosion",
    "SurfaceAppearance", "Decal", "Texture"
}

-- Smart Filtering
local function isWhitelisted(obj)
    for _, w in ipairs(whitelist) do
        if obj.Name:lower():find(w:lower()) then return true end
    end
    if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
    return false
end

local function isLaggy(obj)
    for _, t in ipairs(laggyTypes) do
        if obj:IsA(t) then return true end
    end
    return false
end

-- FPS-Safe cleaning loop (every 3 seconds)
local function cleanLaggyObjects()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isWhitelisted(obj) then continue end
        if isLaggy(obj) then
            pcall(function() obj:Destroy() end)
        end
        -- Remove extra sounds except music/ability/emote
        if obj:IsA("Sound") and not isWhitelisted(obj) then
            pcall(function() obj:Stop() obj.Volume = 0 end)
        end
    end
end

-- Lighting Optimization (optional: comment out if you want default lighting)
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

-- Main loop (FPS-friendly)
local lastClean = 0
game:GetService("RunService").RenderStepped:Connect(function()
    local now = tick()
    if now - lastClean > 3 then
        cleanLaggyObjects()
        potatoLighting()
        lastClean = now
    end
end)

print("AntiLagNoGUI loaded! FPS boost active, no GUI, safe cleaning.")
