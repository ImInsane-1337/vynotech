local name = "nebula.loader"
local version = "0.1.0"
local assetFolder = "nebula_loader/assets"
local scriptFolder = "nebula_loader/scripts"
local title2 = "discord.gg/placeholder!!!!!"

local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local globalEnv = (type(getgenv) == "function" and getgenv()) or _G

local function getExecutorName()
    if type(identifyexecutor) == "function" then
        local ok, name = pcall(identifyexecutor)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if type(getexecutorname) == "function" then
        local ok, name = pcall(getexecutorname)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return "Unknown"
end

local previousState = globalEnv.__NEBULA_SCRIPT_LOADER_STATE
if type(previousState) == "table" and type(previousState.Unload) == "function" then
    pcall(previousState.Unload)
end

local config = {
    Interface = {
        Notifications = true,
    },
    Loader = {
        AllowRemoteUrls = true,
        RequireDoubleClick = false,
        RespectPlaceLocks = true,
        AutoCloseAfterRun = false,
    },
    Debug = false,
}

local state = {
    Name = name,
    Version = version,
    Config = config,
    Connections = {},
    LoadedAt = os.clock(),
    Unloaded = false,
    Library = nil,
    Window = nil,
    Preloader = nil,
    Notifications = nil,
    Catalog = {},
    ExecutorName = getExecutorName(),
    ExecutorPolicy = {
        Supported = {},
        Unsupported = {},
        Access = "unknown",
        Matched = nil,
        Version = "local",
    },
    FilteredGameCount = 0,
    SelectedCategory = nil,
    SelectedScript = nil,
    PendingEntry = nil,
    PendingAt = 0,
    Running = false,
    RunCount = 0,
    FailCount = 0,
    Status = "Ready",
    Gui = {},
}

globalEnv.__NEBULA_SCRIPT_LOADER_STATE = state

local function debugWarn(...)
    if config.Debug then
        warn("[" .. name .. "]", ...)
    end
end

local function notify(title, text, duration, allowWhenUnloaded)
    if not config.Interface.Notifications and not allowWhenUnloaded then
        return
    end

    task.spawn(function()
        local notifications = state.Notifications
        if type(notifications) == "table" and type(notifications.create_notification) == "function" then
            local ok, err = pcall(function()
                notifications:create_notification({
                    name = title or name,
                    info = text or "",
                    lifetime = duration or 4,
                })
            end)

            if ok then
                return
            end

            debugWarn("nebula notification failed:", err)
        end

        local payload = {
            Title = title or name,
            Text = text or "",
            Duration = duration or 4,
        }

        for _ = 1, 8 do
            if state.Unloaded and not allowWhenUnloaded then
                return
            end

            local ok = pcall(function()
                StarterGui:SetCore("SendNotification", payload)
            end)

            if ok then
                return
            end

            task.wait(0.25)
        end

        debugWarn("notification failed:", payload.Text)
    end)
end

local function playWarningSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://4590657391"
    sound.Volume = 0.75
    sound.Parent = SoundService

    local ok = pcall(function()
        sound:Play()
    end)

    task.delay(5, function()
        if sound then
            sound:Destroy()
        end
    end)

    return ok
end

local function disconnectAll()
    for _, connection in ipairs(state.Connections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end

    for index in ipairs(state.Connections) do
        state.Connections[index] = nil
    end
end

local function unload()
    if state.Unloaded then
        return
    end

    state.Unloaded = true
    disconnectAll()

    local library = state.Library
    if type(library) == "table" and type(library.unload_menu) == "function" then
        pcall(function()
            library:unload_menu()
        end)
    end

    if state.Preloader and state.Preloader.Gui then
        pcall(function()
            state.Preloader.Gui:Destroy()
        end)
    end

    if globalEnv.__NEBULA_SCRIPT_LOADER_STATE == state then
        globalEnv.__NEBULA_SCRIPT_LOADER_STATE = nil
    end
end

state.Unload = unload

local function getExecutorReadiness()
    local missing = {}

    local required = {
        getgenv = getgenv,
        loadstring = loadstring,
        makefolder = makefolder,
        isfile = isfile,
        writefile = writefile,
        getcustomasset = getcustomasset,
    }

    for name, fn in pairs(required) do
        if type(fn) ~= "function" then
            table.insert(missing, name)
        end
    end

    return #missing == 0, missing
end

local function loadNebula()
    local ready, missing = getExecutorReadiness()
    if not ready then
        notify(name, "Executor is missing: " .. table.concat(missing, ", "), 6, true)
        return nil
    end

    local ok, source = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Millenium/Library.lua")
    end)

    if not ok or type(source) ~= "string" or source == "" then
        notify(name, "Failed to download Nebula UI.", 5, true)
        debugWarn("library download failed:", source)
        return nil
    end

    local chunkOk, chunk = pcall(loadstring, source)
    if not chunkOk or type(chunk) ~= "function" then
        notify(name, "Failed to compile Nebula UI.", 5, true)
        debugWarn("library compile failed:", chunk)
        return nil
    end

    local libraryOk, library = pcall(chunk)
    if not libraryOk or type(library) ~= "table" then
        notify(name, "Failed to initialize Nebula UI.", 5, true)
        debugWarn("library init failed:", library)
        return nil
    end

    state.Library = library
    return library
end

local function safeSetLabel(label, name, info)
    if type(label) ~= "table" or type(label.items) ~= "table" then
        return
    end

    if name ~= nil and label.items["name"] then
        pcall(function()
            label.items["name"].Text = name
        end)
    end

    if info ~= nil and label.items["info"] then
        pcall(function()
            label.items["info"].Text = info
        end)
    end
end

local function setFooter(text)
    local footer = state.Window and state.Window.items and state.Window.items["other_info"]
    if footer then
        footer.Text = '<font color="rgb(72, 72, 73)">' .. title2 .. "</font>"
    end
end

local function setStatus(text)
    state.Status = text
    safeSetLabel(state.Gui.StatusLabel, "Status", text)
    setFooter(text)
end

local function sanitizeFileName(name)
    return tostring(name or "asset.png"):gsub("[^%w%._%-]", "_")
end

local function ensureAssetFolder()
    if type(makefolder) ~= "function" then
        return false, "makefolder is not available."
    end

    pcall(makefolder, "nebula_loader")
    pcall(makefolder, assetFolder)
    pcall(makefolder, scriptFolder)
    return true
end

local function resolveImageAsset(image)
    if type(image) == "string" and image ~= "" then
        return image
    end

    if type(image) ~= "table" then
        return nil
    end

    if type(image.Asset) == "string" and image.Asset ~= "" then
        return image.Asset
    end

    if image.AssetId ~= nil then
        return "rbxassetid://" .. tostring(image.AssetId)
    end

    if type(image.Path) == "string" and image.Path ~= "" then
        if type(getcustomasset) ~= "function" then
            return nil, "getcustomasset is not available."
        end

        local ok, asset = pcall(getcustomasset, image.Path)
        if ok then
            return asset
        end

        return nil, tostring(asset)
    end

    if type(image.Url) ~= "string" or image.Url == "" then
        return nil
    end

    if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then
        return nil, "writefile/getcustomasset is not available."
    end

    local folderOk, folderErr = ensureAssetFolder()
    if not folderOk then
        return nil, folderErr
    end

    local fileName = sanitizeFileName(image.FileName or image.Name or "asset.png")
    local filePath = assetFolder .. "/" .. fileName
    local shouldDownload = image.Refresh == true

    if type(isfile) ~= "function" or not isfile(filePath) then
        shouldDownload = true
    end

    if shouldDownload then
        local ok, body = pcall(function()
            return game:HttpGet(image.Url)
        end)

        if not ok or type(body) ~= "string" or body == "" then
            return nil, "Failed to download image: " .. tostring(body)
        end

        local writeOk, writeErr = pcall(writefile, filePath, body)
        if not writeOk then
            return nil, "Failed to cache image: " .. tostring(writeErr)
        end
    end

    local ok, asset = pcall(getcustomasset, filePath)
    if not ok then
        return nil, tostring(asset)
    end

    return asset
end

local function startsWith(value, prefix)
    return type(value) == "string" and value:sub(1, #prefix) == prefix
end

local function resolveUrl(baseUrl, path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    if startsWith(path, "http://") or startsWith(path, "https://") or startsWith(path, "rbxassetid://") then
        return path
    end

    if type(baseUrl) ~= "string" or baseUrl == "" then
        return path
    end

    if baseUrl:sub(-1) ~= "/" then
        baseUrl = baseUrl .. "/"
    end

    return baseUrl .. path:gsub("^/+", "")
end

local function getEntryId(entry)
    return sanitizeFileName(entry.Id or entry.id or entry.Name or entry.name or "script")
end

local function readBool(value, default)
    if value == nil then
        return default == true
    end

    if value == true or value == 1 then
        return true
    end

    if type(value) == "string" then
        local lower = value:lower()
        return lower == "true" or lower == "yes" or lower == "1"
    end

    return false
end

local function normalizeStatus(status)
    local value = tostring(status or "Undetected"):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = value:lower():gsub("%s+", " ")

    if lower == "detected" then
        return "Detected"
    elseif lower == "can be detected" or lower == "can_be_detected" or lower == "risk" then
        return "Can be detected"
    elseif lower == "undetected" then
        return "Undetected"
    elseif lower == "on update" or lower == "on_update" or lower == "updating" then
        return "On update"
    elseif lower == "discontinued" then
        return "Discontinued"
    end

    return value
end

local function isOnUpdateStatus(status)
    return normalizeStatus(status) == "On update"
end

local function isDiscontinuedStatus(status)
    return normalizeStatus(status) == "Discontinued"
end

local function getStatusColor(status)
    status = normalizeStatus(status)

    if status == "Detected" then
        return Color3.fromRGB(255, 68, 68)
    elseif status == "Can be detected" then
        return Color3.fromRGB(255, 202, 66)
    elseif status == "Undetected" then
        return Color3.fromRGB(72, 218, 118)
    elseif status == "On update" then
        return Color3.fromRGB(74, 144, 255)
    elseif status == "Discontinued" then
        return Color3.fromRGB(255, 28, 28)
    end

    return Color3.fromRGB(165, 165, 172)
end

local function normalizeCatalogEntry(rawEntry, baseUrl)
    local entry = {}

    entry.Id = rawEntry.Id or rawEntry.id or getEntryId(rawEntry)
    entry.Category = rawEntry.Category or rawEntry.category or rawEntry.Group or rawEntry.group or "Games"
    entry.Name = rawEntry.Name or rawEntry.name or rawEntry.Title or rawEntry.title or rawEntry.Game or rawEntry.game or "Unnamed script"
    entry.Description = rawEntry.Description or rawEntry.description or rawEntry.Info or rawEntry.info or "No description."
    entry.Status = normalizeStatus(rawEntry.Status or rawEntry.status or "Undetected")
    entry.Version = rawEntry.Version or rawEntry.version or "0.0.0"
    entry.Disabled = rawEntry.Disabled == true or rawEntry.disabled == true
    entry.AllowUnsupported = readBool(
        rawEntry.AllowUnsupported
            or rawEntry.allowUnsupported
            or rawEntry["Allow-Unsupported"]
            or rawEntry["allow-unsupported"],
        false
    )

    if isOnUpdateStatus(entry.Status) then
        entry.Disabled = true
    end
    entry.PlaceIds = rawEntry.PlaceIds or rawEntry.placeIds or rawEntry.PlaceIDs or rawEntry.places
    entry.Source = rawEntry.Source or rawEntry.source
    entry.Callback = rawEntry.Callback

    local scriptPath = rawEntry.Url or rawEntry.url or rawEntry.Script or rawEntry.script or rawEntry.Path or rawEntry.path
    entry.Url = resolveUrl(baseUrl, scriptPath)

    local imagePath = rawEntry.Image or rawEntry.image or rawEntry.Banner or rawEntry.banner or rawEntry.Thumbnail or rawEntry.thumbnail
    local imageUrl = resolveUrl(baseUrl, imagePath)

    if imageUrl then
        entry.Image = {
            Url = imageUrl,
            FileName = getEntryId(entry) .. "-" .. sanitizeFileName(imagePath):gsub("^_+", ""),
            Refresh = true,
        }
    end

    return entry
end

local function normalizeManifest(manifest)
    local catalog = {}

    if type(manifest) == "table" then
        local baseUrl = manifest.baseUrl or manifest.BaseUrl or manifest.baseURL or manifest.rawBaseUrl
        if type(baseUrl) ~= "string" or baseUrl == "" then
            baseUrl = ("https://raw.githubusercontent.com/ImInsane-1337/vynotech/loader/supported.json"):match("(.*/)")
        end

        local games = manifest.games or manifest.Games or manifest.supported or manifest.Supported or manifest.scripts or manifest.Scripts or manifest

        if type(games) == "table" then
            for _, rawEntry in ipairs(games) do
                if type(rawEntry) == "table" then
                    table.insert(catalog, normalizeCatalogEntry(rawEntry, baseUrl))
                end
            end
        end

    end

    return catalog
end

local function fetchManifest()
    local manifestUrl = "https://raw.githubusercontent.com/ImInsane-1337/vynotech/loader/supported.json"

    local ok, body = pcall(function()
        return game:HttpGet(manifestUrl)
    end)

    if not ok or type(body) ~= "string" or body == "" then
        return false, "Manifest download failed: " .. tostring(body)
    end

    local decodeOk, manifest = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not decodeOk then
        return false, "Manifest JSON is invalid: " .. tostring(manifest)
    end

    local catalog, err = normalizeManifest(manifest)
    if not catalog then
        return false, err
    end

    state.Catalog = catalog
    return true
end

local function normalizeExecutorName(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function appendExecutorRule(target, item)
    if type(item) == "string" and item ~= "" then
        table.insert(target, item)
        return
    end

    if type(item) ~= "table" then
        return
    end

    local name = item.name or item.Name or item.executor or item.Executor
    if type(name) == "string" and name ~= "" then
        table.insert(target, name)
    end

    local aliases = item.aliases or item.Aliases or item.names or item.Names
    if type(aliases) == "table" then
        for _, alias in ipairs(aliases) do
            if type(alias) == "string" and alias ~= "" then
                table.insert(target, alias)
            end
        end
    end
end

local function readExecutorRules(source)
    local rules = {}

    if type(source) ~= "table" then
        return rules
    end

    for _, item in ipairs(source) do
        appendExecutorRule(rules, item)
    end

    return rules
end

local function findExecutorMatch(rules)
    local executor = normalizeExecutorName(state.ExecutorName)
    if executor == "" then
        return nil
    end

    for _, rule in ipairs(rules or {}) do
        local normalizedRule = normalizeExecutorName(rule)
        if normalizedRule ~= "" and (executor:find(normalizedRule, 1, true) or normalizedRule:find(executor, 1, true)) then
            return rule
        end
    end

    return nil
end

local function refreshExecutorAccess()
    local supportedMatch = findExecutorMatch(state.ExecutorPolicy.Supported)
    if supportedMatch then
        state.ExecutorPolicy.Access = "supported"
        state.ExecutorPolicy.Matched = supportedMatch
        return
    end

    local unsupportedMatch = findExecutorMatch(state.ExecutorPolicy.Unsupported)
    if unsupportedMatch then
        state.ExecutorPolicy.Access = "unsupported"
        state.ExecutorPolicy.Matched = unsupportedMatch
        return
    end

    state.ExecutorPolicy.Access = "unknown"
    state.ExecutorPolicy.Matched = nil
end

local function fetchExecutorManifest()
    local manifestUrl = "https://raw.githubusercontent.com/ImInsane-1337/vynotech/loader/supported-executors.json"

    local ok, body = pcall(function()
        return game:HttpGet(manifestUrl)
    end)

    if not ok or type(body) ~= "string" or body == "" then
        refreshExecutorAccess()
        return false, "Executor manifest download failed: " .. tostring(body)
    end

    local decodeOk, manifest = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not decodeOk or type(manifest) ~= "table" then
        refreshExecutorAccess()
        return false, "Executor manifest JSON is invalid: " .. tostring(manifest)
    end

    state.ExecutorPolicy.Supported = readExecutorRules(manifest.supported or manifest.Supported or manifest.supportedExecutors)
    state.ExecutorPolicy.Unsupported = readExecutorRules(manifest.unsupported or manifest.Unsupported or manifest.blacklist or manifest.Blacklist)
    state.ExecutorPolicy.Version = manifest.version or manifest.Version or "unknown"
    refreshExecutorAccess()

    return true
end

local function canEntryRunOnExecutor(entry)
    if state.ExecutorPolicy.Access == "supported" then
        return true
    end

    if state.ExecutorPolicy.Access == "unsupported" then
        return entry.AllowUnsupported == true
    end

    return true
end

local function filterCatalogForExecutor(catalog)
    if type(catalog) ~= "table" then
        return {}, 0
    end

    local filtered = {}
    local hidden = 0

    for _, entry in ipairs(catalog) do
        if canEntryRunOnExecutor(entry) then
            table.insert(filtered, entry)
        else
            hidden += 1
        end
    end

    return filtered, hidden
end

local function httpGetText(url)
    if type(url) ~= "string" or url == "" then
        return false, "Missing URL."
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return false, tostring(body)
    end

    if type(body) ~= "string" or body == "" then
        return false, "URL returned an empty body."
    end

    return true, body
end

local function cacheScript(entry)
    if entry.Disabled or type(entry.Source) == "string" and entry.Source ~= "" then
        return true
    end

    if type(entry.Url) ~= "string" or entry.Url == "" then
        return true
    end

    if type(writefile) ~= "function" or type(readfile) ~= "function" then
        local ok, source = httpGetText(entry.Url)
        if ok then
            entry.Source = source
        end

        return ok, source
    end

    local folderOk, folderErr = ensureAssetFolder()
    if not folderOk then
        return false, folderErr
    end

    local filePath = scriptFolder .. "/" .. getEntryId(entry) .. ".lua"
    local shouldDownload = true

    if type(isfile) ~= "function" or not isfile(filePath) then
        shouldDownload = true
    end

    if shouldDownload then
        local ok, source = httpGetText(entry.Url)
        if not ok then
            return false, source
        end

        local writeOk, writeErr = pcall(writefile, filePath, source)
        if not writeOk then
            return false, tostring(writeErr)
        end
    end

    local readOk, source = pcall(readfile, filePath)
    if not readOk or type(source) ~= "string" or source == "" then
        return false, "Failed to read cached script."
    end

    entry.Source = source
    return true
end

local function tween(instance, properties, duration, style)
    local ok, tweenObject = pcall(function()
        return TweenService:Create(
            instance,
            TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            properties
        )
    end)

    if ok and tweenObject then
        tweenObject:Play()
    end

    return tweenObject
end

local function createPreloader()
    local gui = Instance.new("ScreenGui")
    gui.Name = "NebulaLoaderPreloader"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, 300, 0, 160)
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(26, 26, 32)
    stroke.Transparency = 0.05
    stroke.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
    })
    gradient.Rotation = 90
    gradient.Parent = frame

    local brand = Instance.new("TextLabel")
    brand.BackgroundTransparency = 1
    brand.Position = UDim2.new(0, 18, 0, 14)
    brand.Size = UDim2.new(0, 118, 0, 20)
    brand.Font = Enum.Font.GothamBold
    brand.RichText = true
    brand.Text = '<font color="rgb(0,85,254)">vyno</font><font color="rgb(245,245,245)">.tech</font>'
    brand.TextColor3 = Color3.fromRGB(245, 245, 245)
    brand.TextSize = 17
    brand.TextXAlignment = Enum.TextXAlignment.Left
    brand.Parent = frame

    local accent = Instance.new("Frame")
    accent.Position = UDim2.new(0, 18, 0, 37)
    accent.Size = UDim2.new(0, 54, 0, 2)
    accent.BorderSizePixel = 0
    accent.BackgroundColor3 = Color3.fromRGB(0, 85, 254)
    accent.Parent = frame

    local executorPill = Instance.new("Frame")
    executorPill.AnchorPoint = Vector2.new(1, 0)
    executorPill.Position = UDim2.new(1, -16, 0, 15)
    executorPill.Size = UDim2.new(0, 108, 0, 24)
    executorPill.BorderSizePixel = 0
    executorPill.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    executorPill.Parent = frame

    local executorCorner = Instance.new("UICorner")
    executorCorner.CornerRadius = UDim.new(0, 6)
    executorCorner.Parent = executorPill

    local executorStroke = Instance.new("UIStroke")
    executorStroke.Color = Color3.fromRGB(35, 35, 42)
    executorStroke.Transparency = 0.15
    executorStroke.Parent = executorPill

    local executorText = Instance.new("TextLabel")
    executorText.BackgroundTransparency = 1
    executorText.Position = UDim2.new(0, 8, 0, 0)
    executorText.Size = UDim2.new(1, -16, 1, 0)
    executorText.Font = Enum.Font.Gotham
    executorText.Text = tostring(state.ExecutorName)
    executorText.TextColor3 = Color3.fromRGB(150, 150, 158)
    executorText.TextSize = 11
    executorText.TextXAlignment = Enum.TextXAlignment.Center
    executorText.TextTruncate = Enum.TextTruncate.AtEnd
    executorText.Parent = executorPill

    local logoHolder = Instance.new("Frame")
    logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    logoHolder.Position = UDim2.new(0.5, 0, 0, 74)
    logoHolder.Size = UDim2.new(0, 56, 0, 56)
    logoHolder.BorderSizePixel = 0
    logoHolder.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    logoHolder.Parent = frame

    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 14)
    logoCorner.Parent = logoHolder

    local logoStroke = Instance.new("UIStroke")
    logoStroke.Color = Color3.fromRGB(0, 85, 254)
    logoStroke.Transparency = 0.25
    logoStroke.Parent = logoHolder

    local logoText = Instance.new("TextLabel")
    logoText.BackgroundTransparency = 1
    logoText.Size = UDim2.new(1, 0, 1, 0)
    logoText.Font = Enum.Font.GothamBold
    logoText.Text = "v"
    logoText.TextColor3 = Color3.fromRGB(245, 245, 245)
    logoText.TextSize = 28
    logoText.Parent = logoHolder

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0, 18, 0, 108)
    status.Size = UDim2.new(1, -36, 0, 18)
    status.Font = Enum.Font.Gotham
    status.Text = "Starting..."
    status.TextColor3 = Color3.fromRGB(135, 135, 142)
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.Parent = frame

    local track = Instance.new("Frame")
    track.Position = UDim2.new(0, 24, 1, -22)
    track.Size = UDim2.new(1, -48, 0, 6)
    track.BorderSizePixel = 0
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    track.Parent = frame

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = Color3.fromRGB(0, 85, 254)
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    state.Preloader = {
        Gui = gui,
        Frame = frame,
        Fill = fill,
        Status = status,
        Progress = 0,
    }

    return state.Preloader
end

local function setPreloader(progress, status)
    local preloader = state.Preloader
    if not preloader then
        return
    end

    preloader.Progress = math.clamp(progress or preloader.Progress or 0, 0, 1)

    if status and preloader.Status then
        preloader.Status.Text = status
    end

    if preloader.Fill then
        tween(preloader.Fill, { Size = UDim2.new(preloader.Progress, 0, 1, 0) }, 0.22)
    end
end

local function finishPreloader()
    local preloader = state.Preloader
    if not preloader then
        return
    end

    setPreloader(1, "Opening interface...")

    if preloader.Frame then
        tween(preloader.Frame, { Size = UDim2.new(0, 720, 0, 565) }, 0.35, Enum.EasingStyle.Quint)
    end

    task.wait(0.22)

    if preloader.Gui then
        for _, descendant in ipairs(preloader.Gui:GetDescendants()) do
            if descendant:IsA("TextLabel") then
                tween(descendant, { TextTransparency = 1 }, 0.18)
            elseif descendant:IsA("ImageLabel") then
                tween(descendant, { ImageTransparency = 1 }, 0.18)
            elseif descendant:IsA("Frame") then
                tween(descendant, { BackgroundTransparency = 1 }, 0.18)
            elseif descendant:IsA("UIStroke") then
                tween(descendant, { Transparency = 1 }, 0.18)
            end
        end

        task.wait(0.2)
        pcall(function()
            preloader.Gui:Destroy()
        end)
    end

    state.Preloader = nil
end

local function fadeInWindow(window)
    local main = window and window.items and window.items["main"]
    if not main then
        return
    end

    local snapshots = {}
    local targets = { main }

    for _, descendant in ipairs(main:GetDescendants()) do
        table.insert(targets, descendant)
    end

    for _, object in ipairs(targets) do
        local snapshot = { Object = object, Props = {} }

        if object:IsA("GuiObject") then
            snapshot.Props.BackgroundTransparency = object.BackgroundTransparency
            object.BackgroundTransparency = 1
        end

        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            snapshot.Props.TextTransparency = object.TextTransparency
            object.TextTransparency = 1
        end

        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            snapshot.Props.ImageTransparency = object.ImageTransparency
            object.ImageTransparency = 1
        end

        if object:IsA("UIStroke") then
            snapshot.Props.Transparency = object.Transparency
            object.Transparency = 1
        end

        if next(snapshot.Props) then
            table.insert(snapshots, snapshot)
        end
    end

    task.spawn(function()
        for index, snapshot in ipairs(snapshots) do
            if snapshot.Object and snapshot.Object.Parent then
                tween(snapshot.Object, snapshot.Props, 0.28)
            end

            if index % 10 == 0 then
                task.wait(0.015)
            end
        end
    end)
end

local runSelected

local function mountGameBanner(library, section, entry)
    if type(library) ~= "table" or type(section) ~= "table" or type(section.items) ~= "table" then
        return
    end

    local parent = section.items["elements"]
    if not parent then
        return
    end

    local card = library:create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, -8, 0, 132),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(6, 7, 10),
        ClipsDescendants = true,
    })

    library:create("UICorner", {
        Parent = card,
        CornerRadius = UDim.new(0, 6),
    })

    library:create("UIStroke", {
        Parent = card,
        Color = Color3.fromRGB(34, 34, 40),
        Transparency = 0.1,
    })

    local imageAsset, imageErr = resolveImageAsset(entry.Image)
    if imageErr then
        debugWarn("game image skipped:", entry.Name, imageErr)
    end

    if imageAsset then
        library:create("ImageLabel", {
            Parent = card,
            BackgroundColor3 = Color3.fromRGB(6, 7, 10),
            Size = UDim2.new(1, 0, 1, 0),
            Image = imageAsset,
            ScaleType = Enum.ScaleType.Fit,
        })
    else
        library:create("TextLabel", {
            Parent = card,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Font = Enum.Font.GothamBold,
            Text = tostring(entry.Name or "?"):sub(1, 1),
            TextColor3 = Color3.fromRGB(245, 245, 245),
            TextSize = 48,
        })
    end

    return card
end

local function mountStatusChip(library, section, entry)
    if type(section) ~= "table" or type(section.items) ~= "table" or not section.items["elements"] then
        return
    end

    local status = normalizeStatus(entry.Status)
    local holder = library:create("Frame", {
        Parent = section.items["elements"],
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        BorderSizePixel = 0,
    })

    library:create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 5, 0, 0),
        Size = UDim2.new(1, -10, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = "Status",
        TextColor3 = Color3.fromRGB(245, 245, 245),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    library:create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 5, 0, 20),
        Size = UDim2.new(1, -10, 0, 18),
        Font = Enum.Font.GothamMedium,
        Text = status,
        TextColor3 = getStatusColor(status),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function createGameTab(library, window, entry)
    local Overview = window:tab({
        name = tostring(entry.Name or "Game"),
        tabs = { "Overview" },
    })

    local previewColumn = Overview:column({})
    local infoColumn = Overview:column({})

    local previewSection = previewColumn:section({
        name = "Preview",
        default = true,
        size = 0.42,
    })

    local descriptionSection = previewColumn:section({
        name = "Description",
        default = true,
        size = 0.58,
    })

    local infoSection = infoColumn:section({
        name = "Information",
        side = "right",
        default = true,
        size = 0.48,
    })

    local actionsSection = infoColumn:section({
        name = "Actions",
        side = "right",
        default = true,
        size = 0.52,
    })

    mountGameBanner(library, previewSection, entry)

    descriptionSection:label({
        name = tostring(entry.Name or "Game"),
        info = tostring(entry.Description or "No description."),
    })

    mountStatusChip(library, infoSection, entry)

    infoSection:label({
        name = "Version",
        info = tostring(entry.Version or "0.0.0"),
    })

    infoSection:label({
        name = "Place",
        info = type(entry.PlaceIds) == "table" and table.concat(entry.PlaceIds, ", ") or "Universal",
    })

    local runButtonName = "Run"
    if isOnUpdateStatus(entry.Status) then
        runButtonName = "On update"
    elseif entry.Disabled then
        runButtonName = "Disabled"
    end

    actionsSection:button({
        name = runButtonName,
        callback = function()
            state.SelectedCategory = tostring(entry.Category or "Games")
            state.SelectedScript = tostring(entry.Name or "Game")
            runSelected()
        end,
    })
end

local function updateStats()
    safeSetLabel(
        state.Gui.StatsLabel,
        "Runs",
        "Executed: " .. tostring(state.RunCount) .. " | Failed: " .. tostring(state.FailCount)
    )
end

local function findEntry(category, name)
    local catalog = state.Catalog or {}

    for _, entry in ipairs(catalog) do
        if tostring(entry.Category or "Other") == category and tostring(entry.Name or "Unnamed script") == name then
            return entry
        end
    end

    return nil
end

local function hasPlaceAccess(entry)
    if not config.Loader.RespectPlaceLocks then
        return true
    end

    if type(entry.PlaceIds) ~= "table" or #entry.PlaceIds == 0 then
        return true
    end

    for _, placeId in ipairs(entry.PlaceIds) do
        if tonumber(placeId) == game.PlaceId then
            return true
        end
    end

    return false
end

local function fetchRemote(url)
    if type(url) ~= "string" or url == "" then
        return false, "Missing URL."
    end

    if not config.Loader.AllowRemoteUrls then
        return false, "Remote URLs are disabled in Settings."
    end

    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return false, tostring(source)
    end

    if type(source) ~= "string" or source == "" then
        return false, "Remote URL returned an empty body."
    end

    return true, source
end

local function runSource(entry, source)
    if type(loadstring) ~= "function" then
        return false, "loadstring is not available."
    end

    local chunkOk, chunk = pcall(loadstring, source)
    if not chunkOk or type(chunk) ~= "function" then
        return false, "Compile failed: " .. tostring(chunk)
    end

    task.spawn(function()
        local ok, err = pcall(chunk)
        state.Running = false

        if ok then
            state.RunCount = state.RunCount + 1
            setStatus("Executed " .. tostring(entry.Name))
            notify(name, "Executed " .. tostring(entry.Name), 4)
        else
            state.FailCount = state.FailCount + 1
            setStatus("Runtime error in " .. tostring(entry.Name))
            notify(name, tostring(err), 6)
            debugWarn("script runtime failed:", err)
        end

        updateStats()

        if ok and config.Loader.AutoCloseAfterRun then
            task.delay(0.15, unload)
        end
    end)

    return true
end

local function executeEntry(entry)
    if not entry then
        setStatus("No script selected")
        notify(name, "Select a script first.", 4)
        return
    end

    if state.Running then
        notify(name, "A script is already starting.", 3)
        return
    end

    if not canEntryRunOnExecutor(entry) then
        setStatus("Unsupported executor")
        notify(
            name,
            tostring(state.ExecutorName) .. " is blacklisted for this script.",
            5
        )
        return
    end

    if isOnUpdateStatus(entry.Status) then
        setStatus("On update: " .. tostring(entry.Name))
        notify(name, "This script is on update and cannot be loaded yet.", 5)
        return
    end

    if entry.Disabled then
        setStatus("Disabled: " .. tostring(entry.Name))
        notify(name, "This script is disabled in supported.json.", 5)
        return
    end

    if not hasPlaceAccess(entry) then
        setStatus("Wrong place for " .. tostring(entry.Name))
        notify(name, "This script is locked to another PlaceId.", 5)
        return
    end

    state.Running = true
    setStatus("Starting " .. tostring(entry.Name))

    if type(entry.Callback) == "function" then
        task.spawn(function()
            local ok, err = pcall(entry.Callback, state)
            state.Running = false

            if ok then
                state.RunCount = state.RunCount + 1
                setStatus("Executed " .. tostring(entry.Name))
                notify(name, "Executed " .. tostring(entry.Name), 4)

                if config.Loader.AutoCloseAfterRun then
                    task.delay(0.15, unload)
                end
            else
                state.FailCount = state.FailCount + 1
                setStatus("Runtime error in " .. tostring(entry.Name))
                notify(name, tostring(err), 6)
                debugWarn("callback failed:", err)
            end

            updateStats()
        end)

        return
    end

    local source = entry.Source
    if type(source) ~= "string" or source == "" then
        setStatus("Fetching " .. tostring(entry.Name))
        local ok, result = fetchRemote(entry.Url)
        if not ok then
            state.Running = false
            state.FailCount = state.FailCount + 1
            setStatus("Fetch failed")
            notify(name, result, 6)
            updateStats()
            return
        end

        source = result
    end

    local ok, err = runSource(entry, source)
    if not ok then
        state.Running = false
        state.FailCount = state.FailCount + 1
        setStatus("Launch failed")
        notify(name, err, 6)
        updateStats()
    end
end

runSelected = function()
    local entry = findEntry(state.SelectedCategory, state.SelectedScript)
    if not entry then
        setStatus("No script selected")
        notify(name, "Select a script first.", 4)
        return
    end

    local discontinuedConfirmed = false
    if isDiscontinuedStatus(entry.Status) then
        local now = os.clock()
        if state.PendingEntry ~= entry or now - state.PendingAt > 8 then
            state.PendingEntry = entry
            state.PendingAt = now
            setStatus("Confirm discontinued: " .. tostring(entry.Name))
            playWarningSound()
            notify(
                "Discontinued script",
                "Run again within 8 seconds. This script is no longer supported and may be detected.",
                8
            )
            return
        end

        discontinuedConfirmed = true
    end

    if not discontinuedConfirmed and config.Loader.RequireDoubleClick then
        local now = os.clock()
        if state.PendingEntry ~= entry or now - state.PendingAt > 5 then
            state.PendingEntry = entry
            state.PendingAt = now
            setStatus("Click Run again: " .. tostring(entry.Name))
            notify(name, "Click Run again within 5 seconds.", 4)
            return
        end
    end

    state.PendingEntry = nil
    state.PendingAt = 0
    executeEntry(entry)
end

local function createUi(library)
    local window = library:window({
        name = "vyno.",
        suffix = "tech",
        gameInfo = "Executor: " .. tostring(state.ExecutorName),
        size = UDim2.new(0, 720, 0, 565),
    })

    state.Window = window
    state.Notifications = library.notifications
    setFooter("ready")

    if type(library.update_theme) == "function" then
        pcall(function()
            library:update_theme("accent", Color3.fromRGB(0, 85, 254))
        end)
    end

    window:seperator({ name = "Scripts" })

    local catalog = state.Catalog or {}
    if #catalog == 0 then
        local Empty = window:tab({
            name = "No games",
            tabs = { "Overview" },
        })

        local column = Empty:column({})
        local section = column:section({
            name = "Supported",
            default = true,
            size = 1,
        })

        section:label({
            name = "No games loaded",
            info = state.FilteredGameCount > 0
                and ("No scripts are available for " .. tostring(state.ExecutorName) .. ".")
                or "supported.json did not return any game entries.",
        })
    else
        for _, entry in ipairs(catalog) do
            createGameTab(library, window, entry)
        end
    end

    window:seperator({ name = "Settings" })

    local Main = window:tab({
        name = "Loader",
        tabs = { "Main" },
    })

    local settingsColumn = Main:column({})

    local loaderSection = settingsColumn:section({
        name = "Loader",
        default = true,
        size = 1,
    })

    loaderSection:toggle({
        name = "Auto Close at Run",
        seperator = true,
        default = config.Loader.AutoCloseAfterRun,
        callback = function(value)
            config.Loader.AutoCloseAfterRun = value == true
        end,
    })

    loaderSection:button({
        name = "Unload",
        callback = function()
            notify(name, "Unloading loader.", 2)
            task.delay(0.15, unload)
        end,
    })

    fadeInWindow(window)

    task.defer(function()
        notify(name, "Loader ready.", 4)
    end)
end

local function prepareCatalog()
    setPreloader(0.14, "Getting game list...")

    local manifestLoaded, manifestErr = fetchManifest()
    if not manifestLoaded then
        return false, manifestErr
    end

    setPreloader(0.28, "Checking executor...")

    local executorLoaded, executorErr = fetchExecutorManifest()
    if not executorLoaded then
        return false, executorErr
    end

    local filteredCatalog, hiddenCount = filterCatalogForExecutor(state.Catalog)
    state.Catalog = filteredCatalog
    state.FilteredGameCount = hiddenCount

    setPreloader(0.42, "Caching game images...")

    local catalog = state.Catalog or {}
    local total = math.max(#catalog, 1)

    for index, entry in ipairs(catalog) do
        if entry.Image then
            local asset, imageErr = resolveImageAsset(entry.Image)
            if asset then
                entry.Image.Asset = asset
            elseif imageErr then
                debugWarn("image cache failed:", entry.Name, imageErr)
            end
        end

        setPreloader(0.42 + (index / total) * 0.18, "Caching image " .. tostring(index) .. "/" .. tostring(total))
        task.wait()
    end

    setPreloader(0.64, "Preparing scripts...")

    for index, entry in ipairs(catalog) do
        local ok, err = cacheScript(entry)
        if not ok then
            debugWarn("script cache failed:", entry.Name, err)
        end

        setPreloader(0.64 + (index / total) * 0.14, "Preparing script " .. tostring(index) .. "/" .. tostring(total))
        task.wait()
    end

    return true
end

local function bootstrap()
    createPreloader()

    local ready, missing = getExecutorReadiness()
    if not ready then
        setPreloader(1, "Executor is missing: " .. table.concat(missing, ", "))
        notify(name, "Executor is missing: " .. table.concat(missing, ", "), 6, true)
        task.wait(2)
        unload()
        return
    end

    local prepared, prepareErr = prepareCatalog()
    if not prepared then
        setPreloader(1, "Game list failed.")
        notify(name, tostring(prepareErr), 6, true)
        task.wait(2)
        unload()
        return
    end

    setPreloader(0.82, "Loading interface library...")
    local library = loadNebula()
    if not library then
        setPreloader(1, "Nebula UI failed.")
        task.wait(2)
        unload()
        return
    end

    setPreloader(0.92, "Building game views...")
    local ok, err = pcall(createUi, library)
    if not ok then
        setPreloader(1, "Interface failed.")
        notify(name, "UI initialization failed.", 5, true)
        debugWarn("ui init failed:", err)
        task.wait(2)
        unload()
        return
    end

    finishPreloader()
end

bootstrap()
