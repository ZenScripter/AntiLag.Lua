- Anti-Lag Universal (client-side) v2.0
-- Added: Potato Fast flag, reduced FPS-drop & lag-spike mitigation, emergency mode, toggle key
-- WARNING: client-side only. Use at your own risk. May be detected by strong anti-cheat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetServic,
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
