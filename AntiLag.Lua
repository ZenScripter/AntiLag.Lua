-- Anti-Lag Safe v2.2 (sanitized)
-- Put this into a LocalScript / executor or StarterPlayerScripts.
-- If run as a Server Script it will exit gracefully.

local success, err = pcall(function()

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")

    -- ensure we are on client
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then
        warn("Anti-Lag: LocalPlayer not found. Make sure this is a LocalScript or run from an executor.")
        return
    end

    -- simple sanity print so you know script loaded
    print("Anti-Lag Safe v2.2 loaded for player:", LocalPlayer.Name)

    local CONFIG = {
        potatoMode = false,
        potatoFast = true,
        disableParticles = true,
        disableTrails = true,
        disableSparkles = true,
        hideDecalsAndTextures = true,
        muteSounds = true,
        disableAttachments = false,
        disableBillboardSurfaceGui = true,
        setRenderingQuality = true,
        qualityLevel = 1,
        scanInterval = 3,
        heartbeatSpikeThreshold = 0.06,
        emergencyDuration = 10,
        emergencyAggressive = true,
        toggleKey = Enum.KeyCode.P,
        guiWhitelist = {"Chat", "Health", "PlayerList", "Topbar"},
    }

    local function safe(fn, ...)
        local ok, res = pcall(fn, ...)
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
        if not inst then return end
        aggressive = aggressive or false

        if CONFIG.disableParticles and inst:IsA("ParticleEmitter") then
            safe(function() inst.Enabled = false end)
            if aggressive then safe(function() if inst.Rate then inst.Rate = 1 end end) end
        end

        if CONFIG.disableTrails and inst:IsA("Trail") then
            safe(function() inst.Enabled = false end)
            if aggressive then safe(function() inst:Destroy() end) end
        end

        if CONFIG.disableSparkles and inst:IsA("Sparkles") then
            safe(function() inst.Enabled = false end)
            if aggressive then safe(function() inst:Destroy() end) end
        end

        if CONFIG.hideDecalsAndTextures and (inst:IsA("Decal") or inst:IsA("Texture")) then
            safe(function() inst.Transparency = 1 end)
        end

        if CONFIG.muteSounds and inst:IsA("Sound") then
            safe(function() inst.Volume = 0 end)
        end

        if CONFIG.disableAttachments and inst:IsA("Attachment") then
            safe(function() inst:Destroy() end)
        end

        if CONFIG.disableBillboardSurfaceGui and (inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")) then
            safe(function() inst.Enabled = false end)
        end

        if inst:IsA("GuiObject") and inst:IsDescendantOf(LocalPlayer.PlayerGui) then
            if not isWhitelistedGui(inst) then
                safe(function() inst.Visible = false end)
            end
        end
    end

    local originals = { lighting = {}, renderingQuality = nil }

    -- capture original lighting/rendering where possible
    safe(function()
        originals.lighting.GlobalShadows = Lighting.GlobalShadows
        originals.lighting.FogEnd = Lighting.FogEnd
        originals.lighting.OutdoorAmbient = Lighting.OutdoorAmbient
        originals.lighting.Ambient = Lighting.Ambient
        originals.lighting.Brightness = Lighting:FindFirstChild("Brightness") and Lighting.Brightness or nil
    end)

    safe(function()
        if settings and settings().Rendering then
            originals.renderingQuality = settings().Rendering.QualityLevel
        end
    end)

    local function reduceLightingAndRendering(potatoFast)
        safe(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e6
            Lighting.OutdoorAmbient = Color3.new(0.6,0.6,0.6)
            if Lighting:FindFirstChild("Brightness") then
                Lighting.Brightness = 1
            else
                Lighting.Ambient = Color3.new(0.6,0.6,0.6)
            end

            if Workspace:FindFirstChild("Terrain") then
                local t = Workspace.Terrain
                pcall(function() if rawget(t, "WaterWaveSize") ~= nil then t.WaterWaveSize = 0 end end)
                pcall(function() if rawget(t, "WaterWaveSpeed") ~= nil then t.WaterWaveSpeed = 0 end end)
                pcall(function() if rawget(t, "WaterReflectance") ~= nil then t.WaterReflectance = 0 end end)
                pcall(function() if rawget(t, "WaterTransparency") ~= nil then t.WaterTransparency = 1 end end)
            end

            if CONFIG.setRenderingQuality and settings and settings().Rendering then
                pcall(function() settings().Rendering.QualityLevel = CONFIG.qualityLevel end)
            end
            -- DO NOT disable 3D rendering here.
        end)
    end

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
        reduceLightingAndRendering(CONFIG.potatoFast)
    end

    local emergencyActive = false
    local function startEmergencyMode()
        if emergencyActive then return end
        emergencyActive = true
        reduceLightingAndRendering(true)
        fullScan(CONFIG.emergencyAggressive)
        if CONFIG.muteSounds then
            pcall(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character then
                        for _, s in ipairs(plr.Character:GetDescendants()) do
                            if s:IsA("Sound") then pcall(function() s.Volume = 0 end) end
                        end
                    end
                end
            end)
        end
        spawn(function()
            task.wait(CONFIG.emergencyDuration)
            emergencyActive = false
            if CONFIG.potatoMode then fullScan(false) end
        end)
    end

    local function setPotatoMode(enabled)
        CONFIG.potatoMode = enabled
        if enabled then
            fullScan(CONFIG.potatoFast)
        else
            pcall(function()
                if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
                    for _, inst in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                        if isWhitelistedGui(inst) and inst:IsA("GuiObject") then
                            pcall(function() inst.Visible = true end)
                        end
                    end
                end
            end)
        end
        print(("Potato mode set to %s"):format(tostring(enabled)))
    end

    local function restoreOriginalVisuals()
        pcall(function()
            if originals.renderingQuality and settings and settings().Rendering then
                settings().Rendering.QualityLevel = originals.renderingQuality
            end
            if originals.lighting.GlobalShadows ~= nil then Lighting.GlobalShadows = originals.lighting.GlobalShadows end
            if originals.lighting.FogEnd ~= nil then Lighting.FogEnd = originals.lighting.FogEnd end
            if originals.lighting.OutdoorAmbient ~= nil then Lighting.OutdoorAmbient = originals.lighting.OutdoorAmbient end
            if originals.lighting.Ambient ~= nil then Lighting.Ambient = originals.lighting.Ambient end
            if originals.lighting.Brightness ~= nil then Lighting.Brightness = originals.lighting.Brightness end
        end)

        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            for _, inst in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                pcall(function() if inst:IsA("GuiObject") and not isWhitelistedGui(inst) then inst.Visible = true end end)
            end
        end

        for _, inst in ipairs(Workspace:GetDescendants()) do
            pcall(function() if inst:IsA("Sound") then inst.Volume = 1 end end)
        end

        print("Original visuals restore attempted.")
    end

    -- initialize
    fullScan(false)

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

    spawn(function()
        while task.wait(CONFIG.scanInterval) do
            pcall(function() fullScan(CONFIG.potatoFast) end)
        end
    end)

    RunService.Heartbeat:Connect(function(dt)
        if dt >= CONFIG.heartbeatSpikeThreshold and not emergencyActive then
            startEmergencyMode()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == CONFIG.toggleKey then setPotatoMode(not CONFIG.potatoMode) end
    end)

    -- exposed controls
    _G.setPotato = setPotatoMode
    _G.forceEmergency = startEmergencyMode
    _G.restoreAntiLag = restoreOriginalVisuals

    print("Anti-Lag Safe v2.2 initialized. Use _G.restoreAntiLag() to attempt a restore.")
end)

if not success then
    -- show a plain error message that doesn't rely on tostring metamethods
    local ok, emsg = pcall(function() return err end)
    if ok and type(emsg) == "string" then
        warn("Anti-Lag failed to start: " .. emsg)
    else
        warn("Anti-Lag failed to start with an unknown error.")
    end
end
