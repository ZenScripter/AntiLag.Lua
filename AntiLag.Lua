-- Anti-Lag Lite — Improved v1.1
-- Safe, event-driven client-side anti-lag for Roblox (LocalScript/executor)
-- IMPORTANT: run this as a LocalScript or from an executor. Do NOT run on server.
-- Features:
--  * Very low-cost: small initial pass on immediate children, then event-driven handlers
--  * Records original values for lighting, rendering, GUI visibility and sound volumes and provides restore
--  * Lightweight on-screen status indicator (tiny) with minimal overhead (optional)
--  * Queue + rate limit for bursts of DescendantAdded to avoid CPU spikes
--  * No Set3dRenderingEnabled(false); no Destroy() calls in normal ops
--  * Global controls: _G.LiteAntiLagEnabled, _G.toggleLiteAntiLag(), _G.restoreAntiLag(), _G.stopLiteAntiLag()

local success, err = pcall(function()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then
        warn("Anti-Lag Lite: LocalPlayer not found — run this as a LocalScript or from an executor on client.")
        return
    end

    -- ===== CONFIG =====
    local CONFIG = {
        disableParticles = true,
        disableTrails = true,
        disableSparkles = true,
        hideDecals = true,
        muteSounds = true,
        disableBillboard = true,
        keepGuiNames = { "Chat", "Health", "Topbar", "PlayerList" }, -- exact names to keep visible
        initialChildLimit = 300,         -- max children processed in the small initial pass
        descendantBurstWindow = 0.8,     -- seconds window to gather descendant-added bursts
        descendantBatchSize = 40,        -- process up to this many per tick from the queue
        showIndicator = true,            -- small on-screen indicator
        indicatorSize = UDim2.new(0,120,0,22),
        indicatorPos = UDim2.new(0,6,0,6),
        qualityLevel = 1,                -- attempt to set low rendering quality (where available)
    }

    -- ===== state & originals =====
    local originals = {
        lighting = {},
        renderingQuality = nil,
        guiVisible = {},    -- map [inst] = originalVisible
        soundVolume = {},   -- map [sound] = originalVolume
    }

    local state = {
        enabled = true,
        stopped = false,
        queue = {},
        lastBurst = 0,
        indicator = nil,
    }

    local function safe(fn, ...)
        local ok, res = pcall(fn, ...)
        return ok, res
    end

    local function isWhitelistedGui(inst)
        if not inst or not inst.Name then return false end
        for _, n in ipairs(CONFIG.keepGuiNames) do
            if inst.Name == n then return true end
        end
        return false
    end

    -- record original GUI visibility and Sound volumes when first touched
    local function recordOriginals(inst)
        if not inst then return end
        pcall(function()
            if inst:IsA("GuiObject") and inst:IsDescendantOf(LocalPlayer.PlayerGui) then
                if originals.guiVisible[inst] == nil then
                    originals.guiVisible[inst] = inst.Visible
                end
            end
            if inst:IsA("Sound") then
                if originals.soundVolume[inst] == nil then
                    originals.soundVolume[inst] = inst.Volume
                end
            end
        end)
    end

    -- apply light, cheap changes only
    local function applyToInstance(inst)
        if not state.enabled or state.stopped then return end
        if not inst then return end
        pcall(function()
            -- record before touching
            recordOriginals(inst)

            if CONFIG.disableParticles and inst:IsA("ParticleEmitter") then
                inst.Enabled = false
            end
            if CONFIG.disableTrails and inst:IsA("Trail") then
                inst.Enabled = false
            end
            if CONFIG.disableSparkles and inst:IsA("Sparkles") then
                inst.Enabled = false
            end
            if CONFIG.hideDecals and (inst:IsA("Decal") or inst:IsA("Texture")) then
                inst.Transparency = 1
            end
            if CONFIG.muteSounds and inst:IsA("Sound") then
                inst.Volume = 0
            end
            if CONFIG.disableBillboard and (inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")) then
                pcall(function() inst.Enabled = false end)
            end
            if inst:IsA("GuiObject") and inst:IsDescendantOf(LocalPlayer.PlayerGui) then
                if not isWhitelistedGui(inst) then
                    inst.Visible = false
                end
            end
        end)
    end

    -- initial lightweight pass: immediate children only, limited to initialChildLimit
    safe(function()
        local count = 0
        for _, child in ipairs(Workspace:GetChildren()) do
            if count >= CONFIG.initialChildLimit then break end
            applyToInstance(child)
            count = count + 1
        end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            count = 0
            for _, child in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                if count >= CONFIG.initialChildLimit then break end
                applyToInstance(child)
                count = count + 1
            end
        end
    end)

    -- recording original lighting & rendering
    safe(function()
        originals.lighting.GlobalShadows = Lighting.GlobalShadows
        originals.lighting.FogEnd = Lighting.FogEnd
        originals.lighting.OutdoorAmbient = Lighting.OutdoorAmbient
        originals.lighting.Ambient = Lighting.Ambient
        originals.lighting.Brightness = Lighting:FindFirstChild("Brightness") and Lighting.Brightness or nil
        if settings and settings().Rendering then
            originals.renderingQuality = settings().Rendering.QualityLevel
            pcall(function() settings().Rendering.QualityLevel = CONFIG.qualityLevel end)
        end
        -- cheap lighting concessions
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        Lighting.OutdoorAmbient = Color3.new(0.5,0.5,0.5)
        if Lighting:FindFirstChild("Brightness") then
            Lighting.Brightness = 1
        else
            Lighting.Ambient = Color3.new(0.27,0.27,0.27)
        end
    end)

    -- queue & burst-handling for DescendantAdded events
    local queue = state.queue

    local function enqueue(inst)
        if not inst then return end
        -- simple dedupe: avoid many duplicates of same instance
        if queue[inst] then return end
        queue[inst] = true
    end

    local function processQueueBatch()
        if state.stopped or not state.enabled then return end
        local i = 0
        for inst,_ in pairs(queue) do
            queue[inst] = nil
            pcall(function() applyToInstance(inst) end)
            i = i + 1
            if i >= CONFIG.descendantBatchSize then break end
        end
    end

    -- scheduled processor: runs every frame but only processes a small batch
    RunService.Heartbeat:Connect(function(dt)
        if state.stopped or not state.enabled then return end
        -- process small batches so we never spike CPU
        processQueueBatch()
    end)

    -- DescendantAdded handler: add to queue, but throttle burst collection
    Workspace.DescendantAdded:Connect(function(inst)
        if state.stopped or not state.enabled then return end
        enqueue(inst)
    end)
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        LocalPlayer.PlayerGui.DescendantAdded:Connect(function(inst)
            if state.stopped or not state.enabled then return end
            enqueue(inst)
        end)
    end

    -- tiny on-screen indicator (very low cost)
    local function createIndicator()
        if not CONFIG.showIndicator then return end
        local ok, screenGui = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "LiteAntiLagIndicator"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer
            local lbl = Instance.new("TextLabel")
            lbl.Name = "LiteAntiLagStatus"
            lbl.BackgroundTransparency = 0.45
            lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
            lbl.BorderSizePixel = 0
            lbl.Size = CONFIG.indicatorSize
            lbl.Position = CONFIG.indicatorPos
            lbl.Font = Enum.Font.SourceSans
            lbl.TextSize = 14
            lbl.TextColor3 = Color3.fromRGB(220,220,220)
            lbl.Text = "Anti-Lag: ON"
            lbl.Parent = gui
            return gui, lbl
        end)
        if ok and screenGui then
            state.indicator = screenGui
        end
    end

    local function updateIndicator()
        if not state.indicator then return end
        pcall(function()
            local lbl = state.indicator:FindFirstChild("LiteAntiLagStatus")
            if lbl and lbl:IsA("TextLabel") then
                lbl.Text = "Anti-Lag: " .. (state.enabled and "ON" or "OFF")
            end
        end)
    end

    createIndicator()
    updateIndicator()

    -- restore function: attempts to restore recorded originals
    local function restoreOriginals()
        pcall(function()
            if originals.renderingQuality and settings and settings().Rendering then
                pcall(function() settings().Rendering.QualityLevel = originals.renderingQuality end)
            end
            if originals.lighting.GlobalShadows ~= nil then Lighting.GlobalShadows = originals.lighting.GlobalShadows end
            if originals.lighting.FogEnd ~= nil then Lighting.FogEnd = originals.lighting.FogEnd end
            if originals.lighting.OutdoorAmbient ~= nil then Lighting.OutdoorAmbient = originals.lighting.OutdoorAmbient end
            if originals.lighting.Ambient ~= nil then Lighting.Ambient = originals.lighting.Ambient end
            if originals.lighting.Brightness ~= nil then Lighting.Brightness = originals.lighting.Brightness end
        end)

        -- restore GUI visibility & sound volumes we recorded
        pcall(function()
            for inst, vis in pairs(originals.guiVisible) do
                if inst and inst.Parent then
                    pcall(function() inst.Visible = vis end)
                end
            end
            for s, vol in pairs(originals.soundVolume) do
                if s and s.Parent then
                    pcall(function() s.Volume = vol end)
                end
            end
        end)

        print("Lite Anti-Lag: restore attempt complete.")
    end

    -- stop / cleanup: disables behaviour and removes indicator
    local function stopAndCleanup()
        state.stopped = true
        state.enabled = false
        -- clear queue
        for k in pairs(queue) do queue[k] = nil end
        -- remove indicator safely
        pcall(function()
            if state.indicator and state.indicator.Parent then
                state.indicator:Destroy()
            end
            state.indicator = nil
        end)
        print("Lite Anti-Lag stopped and cleaned up. Call _G.restoreLiteAntiLag() to attempt restore.")
    end

    -- public controls
    _G.LiteAntiLagEnabled = true
    _G.toggleLiteAntiLag = function()
        state.enabled = not state.enabled
        _G.LiteAntiLagEnabled = state.enabled
        updateIndicator()
        print("LiteAntiLagEnabled =", state.enabled)
    end
    _G.restoreLiteAntiLag = restoreOriginals
    _G.stopLiteAntiLag = function() stopAndCleanup() end

    -- friendly print
    print("Lite Anti-Lag v1.1 initialized. Controls: _G.toggleLiteAntiLag(), _G.restoreLiteAntiLag(), _G.stopLiteAntiLag()")
end)

if not success then
    local ok, emsg = pcall(function() return err end)
    if ok and type(emsg) == "string" then
        warn("Lite Anti-Lag failed to start: " .. emsg)
    else
        warn("Lite Anti-Lag failed to start with unknown error.")
    end
end
