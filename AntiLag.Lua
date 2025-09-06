-- Anti-Lag Universal (client-side) v2.0
-- Added: Potato Fast flag, reduced FPS-drop & lag-spike mitigation, emergency mode, toggle key
-- WARNING: client-side only. Use at your own risk. May be detected by strong anti-cheat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ===== CONFIG =====
local CONFIG = {
    potatoMode = false,           -- master potato mode toggle (false = off)
    potatoFast = true,            -- when true: more aggressive reductions for "potato" players
    disableParticles = true,
    disableTrails = true,
    disableSparkles = true,
    hideDecalsAndTextures = true, -- sets Decal/Texture Transparency = 1
    muteSounds = true,
    disableAttachments = false,   -- destructive: destroys Attachments when true
    disableBillboardSurfaceGui = true,
    setRenderingQuality = true,
    qualityLevel = 1,             -- 1 = lowest quality
    scanInterval = 3,             -- seconds between full scans
    heartbeatSpikeThreshold = 0.06, -- seconds (dt) considered a spike; lower = more sensitive
    emergencyDuration = 10,       -- seconds emergency mode stays active before trying to revert
    emergencyAggressive = true,   -- destructive emergency actions (destroy particle emitters/trails)
    toggleKey = Enum.KeyCode.P,   -- key to toggle potato mode on/off
    guiWhitelist = {              -- GUI names to keep visible (case-sensitive)
        "Chat", "Health", "PlayerList", "Topbar"
    },
}

-- ===== helper functions =====
local function safe(p, ...)
    local ok, res = pcall(p, ...)
    return ok, res
end

local function isWhitelistedGui(inst)
    if not inst then return false end
    for _, name in ipairs(CONFIG.guiWhitelist) do
        if inst.Name == name then return true end
    end
    return false
end

local function applyToInstance(inst, aggressive)
    aggressive = aggressive or false
    if not inst then return end

    -- Particles
    if CONFIG.disableParticles and inst:IsA("ParticleEmitter") then
        safe(function() inst.Enabled = false end)
        if aggressive then
            safe(function() if inst:FindFirstChild("Rate") then inst.Rate = 1 end end)
            safe(function() pcall(function() inst.Parent = nil end) end)
        end
    end

    -- Trails
    if CONFIG.disableTrails and inst:IsA("Trail") then
        safe(function() inst.Enabled = false end)
        if aggressive then safe(function() inst:Destroy() end) end
    end

    -- Sparkles
    if CONFIG.disableSparkles and inst:IsA("Sparkles") then
        safe(function() inst.Enabled = false end)
        if aggressive then safe(function() inst:Destroy() end) end
    end

    -- Decals & Textures
    if CONFIG.hideDecalsAndTextures and (inst:IsA("Decal") or inst:IsA("Texture")) then
        safe(function() inst.Transparency = 1 end)
    end

    -- Sounds -> mute
    if CONFIG.muteSounds and inst:IsA("Sound") then
        safe(function() inst.Volume = 0 end)
    end

    -- Attachments
    if CONFIG.disableAttachments and inst:IsA("Attachment") then
        safe(function() inst:Destroy() end)
    end

    -- BillboardGui / SurfaceGui
    if CONFIG.disableBillboardSurfaceGui and (inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")) then
        safe(function() inst.Enabled = false end)
    end

    -- GuiObjects in PlayerGui: respect whitelist
    if inst:IsA("GuiObject") and LocalPlayer and inst:IsDescendantOf(LocalPlayer.PlayerGui) then
        local keep = isWhitelistedGui(inst)
        if not keep then
            safe(function() inst.Visible = false end)
        end
    end
end

-- Apply broad lighting & rendering reductions
local function reduceLightingAndRendering(potatoFast)
    safe(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        Lighting.OutdoorAmbient = Color3.new(0.6, 0.6, 0.6)
        if Lighting:FindFirstChild("Brightness") then
            Lighting.Brightness = 1
        else
            Lighting.Ambient = Color3.new(0.6, 0.6, 0.6)
        end
        -- try reduce water/terrain detail
        if Workspace:FindFirstChild("Terrain") then
            local t = Workspace.Terrain
            pcall(function() if rawget(t, "WaterWaveSize") ~= nil then t.WaterWaveSize = 0 end end)
            pcall(function() if rawget(t, "WaterWaveSpeed") ~= nil then t.WaterWaveSpeed = 0 end end)
            pcall(function() if rawget(t, "WaterReflectance") ~= nil then t.WaterReflectance = 0 end end)
            pcall(function() if rawget(t, "WaterTransparency") ~= nil then t.WaterTransparency = 1 end end)
        end
        -- Rendering quality (safe)
        if CONFIG.setRenderingQuality and settings and settings().Rendering then
            pcall(function() settings().Rendering.QualityLevel = CONFIG.qualityLevel end)
        end
        -- If potatoFast, try to disable 3D rendering (some clients may not allow this)
        if potatoFast then
            pcall(function() RunService:Set3dRenderingEnabled(false) end)
        end
    end)
end

-- Full scan (workspace, Lighting, PlayerGui)
local function fullScan(aggressive)
    for _, inst in ipairs(Workspace:GetDescendants()) do
        pcall(function() applyToInstance(inst, aggressive) end)
    end
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, inst in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            pcall(function() applyToInstance(inst, aggressive) end)
        end
    end
    for _, inst in ipairs(Lighting:GetDescendants()) do
        pcall(function() applyToInstance(inst, aggressive) end)
    end
    -- enforce lighting/render settings each scan
    reduceLightingAndRendering(CONFIG.potatoFast)
end

-- Emergency reduce (called when spike detected)
local emergencyActive = false
local emergencyTimer = 0
local function startEmergencyMode()
    if emergencyActive then return end
    emergencyActive = true
    emergencyTimer = tick()
    -- be more aggressive in emergency
    reduceLightingAndRendering(true)
    -- destroy or aggressively disable heavy instances
    fullScan(CONFIG.emergencyAggressive)
    -- mute more sounds (global)
    pcall(function()
        if CONFIG.muteSounds then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character then
                    for _, s in ipairs(plr.Character:GetDescendants()) do
                        if s:IsA("Sound") then pcall(function() s.Volume = 0 end) end
                    end
                end
            end
        end
    end)
    -- schedule end-of-emergency attempt to revert some things
    spawn(function()
        task.wait(CONFIG.emergencyDuration)
        emergencyActive = false
        -- after emergency, reapply normal potatoMode (if enabled) otherwise try gentle defaults
        if CONFIG.potatoMode then
            fullScan(false)
        end
    end)
end

-- Toggle potato mode function
local function setPotatoMode(enabled)
    CONFIG.potatoMode = enabled
    if enabled then
        -- apply aggressive reductions immediately
        fullScan(CONFIG.potatoFast)
    else
        -- attempt to revert: we can't restore original values reliably; recommend rejoin
        -- but we'll try to enable basic visibility for whitelisted GUIs only
        pcall(function()
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
                for _, inst in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                    if isWhitelistedGui(inst) and inst:IsA("GuiObject") then
                        pcall(function() inst.Visible = true end)
                    end
                end
            end
        end)
        -- try to re-enable 3D rendering (if possible)
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end
    print(("Potato mode set to %s"):format(tostring(enabled)))
end

-- ===== Start initial scan =====
fullScan(false)

-- Watch for new descendants to apply settings (non-aggressive by default)
Workspace.DescendantAdded:Connect(function(inst)
    task.defer(function() pcall(function() applyToInstance(inst, false) end) end)
end)
Lighting.DescendantAdded:Connect(function(inst)
    task.defer(function() pcall(function() applyToInstance(inst, false) end) end)
end)
if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
    LocalPlayer.PlayerGui.DescendantAdded:Connect(function(inst)
        task.defer(function() pcall(function() applyToInstance(inst, false) end) end)
    end)
end

-- Periodic full scan
spawn(function()
    while task.wait(CONFIG.scanInterval) do
        pcall(function() fullScan(CONFIG.potatoFast) end)
    end
end)

-- Heartbeat monitor to detect spikes and trigger emergency reductions
local spikeAccumulator = 0
local spikeCount = 0
local smoothedDt = 0
local alpha = 0.1 -- smoothing factor

RunService.Heartbeat:Connect(function(dt)
    -- EMA smoothing
    smoothedDt = smoothedDt + alpha * (dt - smoothedDt)
    if dt >= CONFIG.heartbeatSpikeThreshold and not emergencyActive then
        spikeCount = spikeCount + 1
        spikeAccumulator = spikeAccumulator + dt
        -- immediate emergency if single big spike
        startEmergencyMode()
    end
end)

-- Toggle keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.toggleKey then
        setPotatoMode(not CONFIG.potatoMode)
    end
end)

-- Expose some simple commands via print for manual control (executor console)
print("Anti-Lag v2.0 initialized.")
print("Commands: setPotato(true/false)  -- toggles potato mode")
print("You can press the toggle key (" .. tostring(CONFIG.toggleKey) .. ") to switch potato mode on/off.")

-- provide global functions for manual control (so user can toggle from console)
_G.setPotato = setPotatoMode
_G.forceEmergency = startEmergencyMode
