-- Robust loader: auto-detects Lua / HTML / Model and tries correct action
local url = "https://raw.githubusercontent.com/ZenScripter/AntiLag.Lua/refs/heads/main/AntiLag.Lua" 
-- <<--- replace only if you want to test another URL

local function safeHttpGet(u)
    local ok, res = pcall(function() return game:HttpGet(u, true) end)
    return ok, res
end

local function looksLikeHtml(s)
    if not s or #s < 4 then return false end
    local first = s:sub(1,10):lower()
    return first:match("^<!doctype") or first:sub(1,1) == "<"
end

local function looksLikeBinaryModel(s)
    if not s then return false end
    -- model/binary responses often include null bytes or start with "RBX" magic
    if s:find("%z") then return true end
    if s:sub(1,3) == "RBX" then return true end
    return false
end

local function tryAutoFixGithub(u)
    -- correct pattern: replace "/refs/heads/" with "/"
    if u:find("raw.githubusercontent.com") and u:find("/refs/heads/") then
        return u:gsub("/refs/heads/", "/")
    end
    -- try to convert a github blob url to raw if user pasted non-raw link
    if u:find("github.com") and not u:find("raw.githubusercontent.com") then
        local user, repo, rest = u:match("github%.com/([^/]+)/([^/]+)/(.*)")
        if user and repo and rest then
            -- rest may start with "blob/main/..."
            rest = rest:gsub("^blob/", "")
            rest = rest:gsub("^raw/", "")
            return ("https://raw.githubusercontent.com/%s/%s/%s"):format(user, repo, rest)
        end
    end
    return nil
end

local function extractAssetIdFromUrl(u)
    if not u then return nil end
    -- find first long numeric sequence (6+ digits)
    local id = u:match("(%d%d%d%d%d%d%d*)")
    return id
end

-- 1) try fetch original URL
local ok, res = safeHttpGet(url)
if not ok then
    warn("HttpGet failed for URL: "..tostring(url) .. "\nError: "..tostring(res))
    return
end

-- show first bytes for debugging
print("HTTP response length:", #res)
print("Preview (first 400 chars):\n" .. res:sub(1,400))

-- 2) detect content type
if looksLikeHtml(res) then
    warn("Response looks like HTML. Possibly wrong (non-raw) GitHub URL or webpage.")
    -- try auto-fix for common Github raw mistakes
    local alt = tryAutoFixGithub(url)
    if alt and alt ~= url then
        print("Attempting auto-fixed raw URL:", alt)
        local ok2, res2 = safeHttpGet(alt)
        if ok2 then
            print("Retry succeeded. Preview (first 400 chars):\n" .. res2:sub(1,400))
            if not looksLikeHtml(res2) and not looksLikeBinaryModel(res2) then
                -- treat as Lua
                local fn, err = loadstring(res2)
                if not fn then error("loadstring error on corrected raw URL: "..tostring(err)) end
                pcall(fn)
                return
            else
                warn("Corrected URL still returned HTML or non-Lua content.")
            end
        else
            warn("Corrected raw URL HttpGet failed: "..tostring(res2))
        end
    end

    -- if original URL contains a Roblox library page, try asset id approach
    local possibleId = extractAssetIdFromUrl(url)
    if possibleId then
        print("Detected numeric id in URL. Trying game:GetObjects with id:", possibleId)
        local success, objs = pcall(function() return game:GetObjects("rbxassetid://"..possibleId) end)
        if success and objs and objs[1] then
            print("Model loaded via game:GetObjects, parenting first object to Workspace")
            objs[1].Parent = workspace
            return
        else
            warn("game:GetObjects failed or returned nil for id: "..possibleId)
        end
    end

    error("URL returned HTML. Use a raw file URL (raw.githubusercontent.com/USER/REPO/BRANCH/PATH) or provide an rbxassetid:// link.")
end

if looksLikeBinaryModel(res) then
    -- Binary data / model returned by HttpGet — user should use game:GetObjects with asset id
    warn("HTTP response appears to be binary / model data. You should load this via game:GetObjects with an rbxassetid://ID.")
    local id = extractAssetIdFromUrl(url)
    if id then
        print("Found numeric id in URL, attempting game:GetObjects with id:", id)
        local success, objs = pcall(function() return game:GetObjects("rbxassetid://"..id) end)
        if success and objs and objs[1] then
            objs[1].Parent = workspace
            print("Model successfully loaded into Workspace.")
            return
        else
            warn("game:GetObjects failed for id: "..tostring(id))
        end
    end
    error("Binary/model response cannot be loadstring-ed. Provide a raw Lua file URL or an rbxassetid://ID.")
end

-- Otherwise treat as Lua text
local fn, err = loadstring(res)
if not fn then
    error("loadstring parse error: " .. tostring(err) .. "\n(Preview was shown above.)")
end

local okRun, runErr = pcall(fn)
if not okRun then
    error("Script runtime error: " .. tostring(runErr))
end

print("Loaded and executed script successfully.")
