-- 🛡 Anti-Lag Zen V1 (Auto-Clean Upgrade)
-- Adds auto-detect & delete for heavy lag sources

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local enabled = true
local mode = "Medium" -- default mode

-- ✅ Whitelist
local whitelist = { "PlayerParticles", "SpecialEffect" }
local function isWhitelisted(obj)
    for _, name in ipairs(whitelist) do
        if obj.Name == name then
            return true
        end
    end
    return false
end

-- ✅ Smart cleaner: disable OR delete if heavy
local function cleanObject(obj)
    if not enabled or isWhitelisted(obj) then return end

    -- Detect particle spam
    if obj:IsA("ParticleEmitter") then
        if obj.Rate > 200 then
            obj:Destroy() -- 💥 delete very laggy emitter
        else
            obj.Enabled = false
        end

    elseif obj:IsA("Trail") or obj:IsA("Beam") then
        obj.Enabled = false

    elseif obj:IsA("Smoke") or obj:IsA("Fire") then
        if obj.Opacity > 0.5 then
            obj:Destroy() -- delete strong fire/smoke
        else
            obj.Enabled = false
        end

    elseif obj:IsA("Explosion") then
        obj:Destroy() -- delete instead of hiding
    end
end

-- ✅ Batch scan
task.spawn(function()
    for i, obj in ipairs(workspace:GetDescendants()) do
        cleanObject(obj)
        if i % 100 == 0 then
            task.wait()
        end
    end
end)

-- ✅ New laggy stuff
workspace.DescendantAdded:Connect(cleanObject)

-- ✅ Preset switcher (Light / Medium / Ultra)
local modes = { "Light", "Medium", "Ultra" }
local currentIndex = 2 -- start Medium

local function applyMode(newMode)
    mode = newMode
    print("Anti-Lag Mode:", mode)

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e9
    Lighting.Brightness = 1

    if mode == "Light" then
        -- minimal
        if Lighting:FindFirstChild("Atmosphere") then
            Lighting.Atmosphere:Destroy()
        end
    elseif mode == "Medium" or mode == "Ultra" then
        -- rescan with cleaner
        task.spawn(function()
            for i, obj in ipairs(workspace:GetDescendants()) do
                cleanObject(obj)
                if i % 100 == 0 then
                    task.wait()
                end
            end
        end)
    end
end

-- ✅ Toggle & Cycle hotkeys
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Enum.KeyCode.F3 then
        enabled = not enabled
        print("Anti-Lag:", enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.F4 and enabled then
        currentIndex = currentIndex % #modes + 1
        applyMode(modes[currentIndex])
    end
end)

-- ✅ Init
applyMode(mode)
print("✅ Anti-Lag V1 Loaded with Auto-Clean")
