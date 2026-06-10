local SCRIPT_NAME = "nebula.loader"
local SCRIPT_VERSION = "0.1.0"
local STATE_KEY = "__NEBULA_SCRIPT_LOADER_STATE"
local LIBRARY_URL = "https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Millenium/Library.lua"
local ASSET_FOLDER = "nebula_loader/assets"
local SCRIPT_FOLDER = "nebula_loader/scripts"
local MAIN_WINDOW_SIZE = UDim2.new(0, 720, 0, 565)
local PRELOADER_SIZE = UDim2.new(0, 330, 0, 210)

local BRANDING = {
    Title = "Nebula Loader",
    Subtitle = "script hub",
    Logo = {
        -- Asset = "rbxassetid://1234567890",
        -- Url = "https://raw.githubusercontent.com/user/repo/main/assets/logo.png",
        FileName = "logo.png",
        Refresh = false,
    },
}

local REMOTE_MANIFEST = {
    Url = "https://raw.githubusercontent.com/ImInsane/vyno.tech/loader/supported.json",
    Refresh = true,
    Required = false,
}

-- Local fallback. The remote manifest uses the same fields.
local SCRIPT_CATALOG = {
    {
        Category = "Universal",
        Name = "Loader self-test",
        Description = "Runs a tiny print so you can verify the loader works.",
        Source = [[
print("[nebula.loader] Self-test executed.")
        ]],
    },
    {
        Category = "Universal",
        Name = "Player greeting",
        Description = "Example embedded script that reads the local player name.",
        Source = [[
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
print("[nebula.loader] Hello, " .. ((LocalPlayer and LocalPlayer.Name) or "player") .. ".")
        ]],
    },
    {
        Category = "Remote",
        Name = "Replace with raw URL",
        Description = "Template slot. Replace Url with your own raw script link, then set Disabled = false.",
        Url = "https://raw.githubusercontent.com/your-name/your-repo/main/script.lua",
        Disabled = true,
    },
}

local CURRENT_CATALOG = SCRIPT_CATALOG

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local globalEnv = (type(getgenv) == "function" and getgenv()) or _G

local previousState = globalEnv[STATE_KEY]
if type(previousState) == "table" and type(previousState.Unload) == "function" then
    pcall(previousState.Unload)
end

local config = {
    Interface = {
        Notifications = true,
    },
    Loader = {
        AllowRemoteUrls = true,
        RequireDoubleClick = true,
        RespectPlaceLocks = true,
        AutoCloseAfterRun = false,
    },
    Debug = false,
}

local state = {
    Name = SCRIPT_NAME,
    Version = SCRIPT_VERSION,
    Config = config,
    Connections = {},
    LoadedAt = os.clock(),
    Unloaded = false,
    Library = nil,
    Window = nil,
    Preloader = nil,
    Notifications = nil,
    Catalog = CURRENT_CATALOG,
    ManifestMeta = nil,
    AssetCache = {},
    ScriptCache = {},
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

globalEnv[STATE_KEY] = state

local function debugWarn(...)
    if config.Debug then
        warn("[" .. SCRIPT_NAME .. "]", ...)
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
                    name = title or SCRIPT_NAME,
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
            Title = title or SCRIPT_NAME,
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

    if globalEnv[STATE_KEY] == state then
        globalEnv[STATE_KEY] = nil
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
        notify(SCRIPT_NAME, "Executor is missing: " .. table.concat(missing, ", "), 6, true)
        return nil
    end

    local ok, source = pcall(function()
        return game:HttpGet(LIBRARY_URL)
    end)

    if not ok or type(source) ~= "string" or source == "" then
        notify(SCRIPT_NAME, "Failed to download Nebula UI.", 5, true)
        debugWarn("library download failed:", source)
        return nil
    end

    local chunkOk, chunk = pcall(loadstring, source)
    if not chunkOk or type(chunk) ~= "function" then
        notify(SCRIPT_NAME, "Failed to compile Nebula UI.", 5, true)
        debugWarn("library compile failed:", chunk)
        return nil
    end

    local libraryOk, library = pcall(chunk)
    if not libraryOk or type(library) ~= "table" then
        notify(SCRIPT_NAME, "Failed to initialize Nebula UI.", 5, true)
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
        footer.Text = '<font color="rgb(72, 72, 73)">' .. text .. ', </font>' .. SCRIPT_NAME
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
    pcall(makefolder, ASSET_FOLDER)
    pcall(makefolder, SCRIPT_FOLDER)
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
    local filePath = ASSET_FOLDER .. "/" .. fileName
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

local function normalizeCatalogEntry(rawEntry, baseUrl)
    local entry = {}

    entry.Id = rawEntry.Id or rawEntry.id or getEntryId(rawEntry)
    entry.Category = rawEntry.Category or rawEntry.category or rawEntry.Group or rawEntry.group or "Games"
    entry.Name = rawEntry.Name or rawEntry.name or rawEntry.Title or rawEntry.title or rawEntry.Game or rawEntry.game or "Unnamed script"
    entry.Description = rawEntry.Description or rawEntry.description or rawEntry.Info or rawEntry.info or "No description."
    entry.Status = rawEntry.Status or rawEntry.status or "Unknown"
    entry.Version = rawEntry.Version or rawEntry.version or "0.0.0"
    entry.Disabled = rawEntry.Disabled == true or rawEntry.disabled == true
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
            Refresh = REMOTE_MANIFEST.Refresh == true,
        }
    end

    return entry
end

local function normalizeManifest(manifest)
    local catalog = {}

    if type(manifest) == "table" then
        local baseUrl = manifest.baseUrl or manifest.BaseUrl or manifest.baseURL or manifest.rawBaseUrl
        if (type(baseUrl) ~= "string" or baseUrl == "") and type(REMOTE_MANIFEST.Url) == "string" then
            baseUrl = REMOTE_MANIFEST.Url:match("(.*/)")
        end

        local games = manifest.games or manifest.Games or manifest.supported or manifest.Supported or manifest.scripts or manifest.Scripts or manifest

        if type(games) == "table" then
            for _, rawEntry in ipairs(games) do
                if type(rawEntry) == "table" then
                    table.insert(catalog, normalizeCatalogEntry(rawEntry, baseUrl))
                end
            end
        end

        state.ManifestMeta = {
            Name = manifest.name or manifest.Name or "Remote manifest",
            Version = manifest.version or manifest.Version or "unknown",
            BaseUrl = baseUrl,
        }
    end

    if #catalog == 0 then
        return nil, "Manifest has no supported games."
    end

    return catalog
end

local function fetchManifest()
    if type(REMOTE_MANIFEST.Url) ~= "string" or REMOTE_MANIFEST.Url == "" then
        return false, "Remote manifest URL is not configured."
    end

    local ok, body = pcall(function()
        return game:HttpGet(REMOTE_MANIFEST.Url)
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

    CURRENT_CATALOG = catalog
    state.Catalog = catalog
    return true
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

    local filePath = SCRIPT_FOLDER .. "/" .. getEntryId(entry) .. ".lua"
    local shouldDownload = REMOTE_MANIFEST.Refresh == true

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
    state.ScriptCache[entry.Id] = filePath
    return true
end

local function mountBranding(library, window)
    if type(library) ~= "table" or type(library.create) ~= "function" then
        return
    end

    local main = window and window.items and window.items["main"]
    if not main then
        return
    end

    local imageAsset, imageErr = resolveImageAsset(BRANDING.Logo)
    if imageErr then
        debugWarn("branding image skipped:", imageErr)
    end

    local holder = library:create("Frame", {
        Parent = main,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.new(0, 176, 0, 38),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(18, 18, 21),
        BackgroundTransparency = 0.05,
        ZIndex = 3,
    })

    library:create("UICorner", {
        Parent = holder,
        CornerRadius = UDim.new(0, 7),
    })

    library:create("UIStroke", {
        Parent = holder,
        Color = Color3.fromRGB(35, 35, 42),
        Transparency = 0.15,
    })

    local textOffset = imageAsset and 46 or 12

    if imageAsset then
        local image = library:create("ImageLabel", {
            Parent = holder,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0.5, -14),
            Size = UDim2.new(0, 28, 0, 28),
            Image = imageAsset,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 4,
        })

        library:create("UICorner", {
            Parent = image,
            CornerRadius = UDim.new(0, 6),
        })
    end

    library:create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, textOffset, 0, 5),
        Size = UDim2.new(1, -textOffset - 8, 0, 15),
        Font = Enum.Font.GothamMedium,
        Text = BRANDING.Title or SCRIPT_NAME,
        TextColor3 = Color3.fromRGB(245, 245, 245),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })

    library:create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, textOffset, 0, 20),
        Size = UDim2.new(1, -textOffset - 8, 0, 13),
        Font = Enum.Font.Gotham,
        Text = BRANDING.Subtitle or SCRIPT_VERSION,
        TextColor3 = Color3.fromRGB(130, 130, 136),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
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
    frame.Size = PRELOADER_SIZE
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

    local logoHolder = Instance.new("Frame")
    logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    logoHolder.Position = UDim2.new(0.5, 0, 0.39, 0)
    logoHolder.Size = UDim2.new(0, 70, 0, 70)
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
    logoText.TextSize = 34
    logoText.Parent = logoHolder

    local logoAsset = resolveImageAsset(BRANDING.Logo)
    if logoAsset then
        logoText.Visible = false

        local logoImage = Instance.new("ImageLabel")
        logoImage.BackgroundTransparency = 1
        logoImage.Position = UDim2.new(0, 10, 0, 10)
        logoImage.Size = UDim2.new(1, -20, 1, -20)
        logoImage.Image = logoAsset
        logoImage.ScaleType = Enum.ScaleType.Fit
        logoImage.Parent = logoHolder
    end

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 18, 0, 112)
    title.Size = UDim2.new(1, -36, 0, 22)
    title.Font = Enum.Font.GothamMedium
    title.Text = BRANDING.Title or SCRIPT_NAME
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0, 18, 0, 139)
    status.Size = UDim2.new(1, -36, 0, 18)
    status.Font = Enum.Font.Gotham
    status.Text = "Starting..."
    status.TextColor3 = Color3.fromRGB(135, 135, 142)
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.Parent = frame

    local track = Instance.new("Frame")
    track.Position = UDim2.new(0, 24, 1, -34)
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
        tween(preloader.Frame, { Size = MAIN_WINDOW_SIZE }, 0.35, Enum.EasingStyle.Quint)
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
local copySelectedLoadstring

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
        Size = UDim2.new(1, -8, 0, 152),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(18, 18, 21),
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
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Image = imageAsset,
            ScaleType = Enum.ScaleType.Crop,
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

    local shade = library:create("Frame", {
        Parent = card,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.38,
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
    })

    local title = library:create("TextLabel", {
        Parent = shade,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 1, -45),
        Size = UDim2.new(1, -24, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = tostring(entry.Name or "Unnamed game"),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    library:create("TextLabel", {
        Parent = shade,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 1, -24),
        Size = UDim2.new(1, -24, 0, 15),
        Font = Enum.Font.Gotham,
        Text = tostring(entry.Category or "Games"),
        TextColor3 = Color3.fromRGB(170, 170, 178),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    return card
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

    infoSection:label({
        name = "Status",
        info = tostring(entry.Status or "Unknown"),
    })

    infoSection:label({
        name = "Version",
        info = tostring(entry.Version or "0.0.0"),
    })

    infoSection:label({
        name = "Place",
        info = type(entry.PlaceIds) == "table" and table.concat(entry.PlaceIds, ", ") or "Universal",
    })

    actionsSection:button({
        name = entry.Disabled and "Disabled" or "Run",
        callback = function()
            state.SelectedCategory = tostring(entry.Category or "Games")
            state.SelectedScript = tostring(entry.Name or "Game")
            runSelected()
        end,
    })

    actionsSection:button({
        name = "Copy Loadstring",
        callback = function()
            state.SelectedCategory = tostring(entry.Category or "Games")
            state.SelectedScript = tostring(entry.Name or "Game")
            copySelectedLoadstring()
        end,
    })

    actionsSection:button({
        name = "Clear Confirmation",
        callback = function()
            state.PendingEntry = nil
            state.PendingAt = 0
            setStatus("Confirmation cleared")
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

local function uniqueCategories()
    local seen = {}
    local categories = {}
    local catalog = state.Catalog or CURRENT_CATALOG

    for _, entry in ipairs(catalog) do
        local category = tostring(entry.Category or "Other")
        if not seen[category] then
            seen[category] = true
            table.insert(categories, category)
        end
    end

    if #categories == 0 then
        table.insert(categories, "Empty")
    end

    return categories
end

local function scriptsForCategory(category)
    local scripts = {}
    local catalog = state.Catalog or CURRENT_CATALOG

    for _, entry in ipairs(catalog) do
        if tostring(entry.Category or "Other") == category then
            table.insert(scripts, tostring(entry.Name or "Unnamed script"))
        end
    end

    if #scripts == 0 then
        table.insert(scripts, "No scripts")
    end

    return scripts
end

local function findEntry(category, name)
    local catalog = state.Catalog or CURRENT_CATALOG

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

local function describeEntry(entry)
    if not entry then
        return "Select a script from the list."
    end

    local sourceType = "missing source"
    if type(entry.Callback) == "function" then
        sourceType = "callback"
    elseif type(entry.Source) == "string" and entry.Source ~= "" then
        sourceType = "embedded"
    elseif type(entry.Url) == "string" and entry.Url ~= "" then
        sourceType = "remote URL"
    end

    local disabled = entry.Disabled and " | disabled" or ""
    local placeLocked = ""

    if type(entry.PlaceIds) == "table" and #entry.PlaceIds > 0 then
        placeLocked = " | place locked"
    end

    return "Status: "
        .. tostring(entry.Status or "Unknown")
        .. "\nVersion: "
        .. tostring(entry.Version or "0.0.0")
        .. "\n"
        .. tostring(entry.Description or "No description.")
        .. "\nType: "
        .. sourceType
        .. disabled
        .. placeLocked
end

local function selectScript(scriptName)
    state.SelectedScript = scriptName
    state.PendingEntry = nil
    state.PendingAt = 0

    local entry = findEntry(state.SelectedCategory, state.SelectedScript)
    safeSetLabel(state.Gui.SelectedLabel, entry and tostring(entry.Name) or "Selected", describeEntry(entry))
    setStatus(entry and ("Selected " .. tostring(entry.Name)) or "Select a script")
end

local function selectCategory(category)
    state.SelectedCategory = category
    state.PendingEntry = nil
    state.PendingAt = 0

    local scripts = scriptsForCategory(category)
    if state.Gui.ScriptList and type(state.Gui.ScriptList.refresh_options) == "function" then
        state.Gui.ScriptList.refresh_options(scripts)
    end

    local firstScript = scripts[1]
    if firstScript == "No scripts" then
        firstScript = nil
    end

    selectScript(firstScript)
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
            notify(SCRIPT_NAME, "Executed " .. tostring(entry.Name), 4)
        else
            state.FailCount = state.FailCount + 1
            setStatus("Runtime error in " .. tostring(entry.Name))
            notify(SCRIPT_NAME, tostring(err), 6)
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
        notify(SCRIPT_NAME, "Select a script first.", 4)
        return
    end

    if state.Running then
        notify(SCRIPT_NAME, "A script is already starting.", 3)
        return
    end

    if entry.Disabled then
        setStatus("Disabled: " .. tostring(entry.Name))
        notify(SCRIPT_NAME, "Edit SCRIPT_CATALOG and set Disabled = false.", 5)
        return
    end

    if not hasPlaceAccess(entry) then
        setStatus("Wrong place for " .. tostring(entry.Name))
        notify(SCRIPT_NAME, "This script is locked to another PlaceId.", 5)
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
                notify(SCRIPT_NAME, "Executed " .. tostring(entry.Name), 4)

                if config.Loader.AutoCloseAfterRun then
                    task.delay(0.15, unload)
                end
            else
                state.FailCount = state.FailCount + 1
                setStatus("Runtime error in " .. tostring(entry.Name))
                notify(SCRIPT_NAME, tostring(err), 6)
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
            notify(SCRIPT_NAME, result, 6)
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
        notify(SCRIPT_NAME, err, 6)
        updateStats()
    end
end

runSelected = function()
    local entry = findEntry(state.SelectedCategory, state.SelectedScript)
    if not entry then
        setStatus("No script selected")
        notify(SCRIPT_NAME, "Select a script first.", 4)
        return
    end

    if config.Loader.RequireDoubleClick then
        local now = os.clock()
        if state.PendingEntry ~= entry or now - state.PendingAt > 5 then
            state.PendingEntry = entry
            state.PendingAt = now
            setStatus("Click Run again: " .. tostring(entry.Name))
            notify(SCRIPT_NAME, "Click Run again within 5 seconds.", 4)
            return
        end
    end

    state.PendingEntry = nil
    state.PendingAt = 0
    executeEntry(entry)
end

copySelectedLoadstring = function()
    local entry = findEntry(state.SelectedCategory, state.SelectedScript)
    if not entry then
        notify(SCRIPT_NAME, "Select a remote script first.", 4)
        return
    end

    if type(entry.Url) ~= "string" or entry.Url == "" then
        notify(SCRIPT_NAME, "Selected script has no remote URL.", 4)
        return
    end

    if type(setclipboard) ~= "function" then
        notify(SCRIPT_NAME, "setclipboard is not available.", 4)
        return
    end

    local escapedUrl = entry.Url:gsub("\\", "\\\\"):gsub("\"", "\\\"")
    local payload = "loadstring(game:HttpGet(\"" .. escapedUrl .. "\"))()"
    local ok, err = pcall(setclipboard, payload)

    if ok then
        notify(SCRIPT_NAME, "Copied loadstring for " .. tostring(entry.Name), 4)
    else
        notify(SCRIPT_NAME, "Clipboard failed: " .. tostring(err), 5)
    end
end

local function initConfig(library, window)
    if type(library.init_config) ~= "function" then
        return
    end

    if type(listfiles) ~= "function" or type(readfile) ~= "function" or type(delfile) ~= "function" then
        debugWarn("config init skipped: listfiles/readfile/delfile unavailable")
        return
    end

    local ok, err = pcall(function()
        library:init_config(window)
    end)

    if not ok then
        debugWarn("config init failed:", err)
    end
end

local function createUi(library)
    local window = library:window({
        name = "vyno.",
        suffix = "tech",
        gameInfo = "Supported Games",
        size = MAIN_WINDOW_SIZE,
    })

    state.Window = window
    state.Notifications = library.notifications
    setFooter("ready")

    if type(library.update_theme) == "function" then
        pcall(function()
            library:update_theme("accent", Color3.fromRGB(0, 85, 254))
        end)
    end

    mountBranding(library, window)

    window:seperator({ name = "Scripts" })

    local catalog = state.Catalog or CURRENT_CATALOG
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
            info = "supported.json did not return any game entries.",
        })
    else
        for _, entry in ipairs(catalog) do
            createGameTab(library, window, entry)
        end
    end

    window:seperator({ name = "Settings" })

    local Main, Session = window:tab({
        name = "Loader",
        tabs = { "Main", "Session" },
    })

    local settingsColumn = Main:column({})
    local safetyColumn = Main:column({})

    local interfaceSection = settingsColumn:section({
        name = "Interface",
        default = true,
        size = 1,
    })

    local safetySection = safetyColumn:section({
        name = "Safety",
        side = "right",
        default = true,
        size = 1,
    })

    interfaceSection:toggle({
        name = "Notifications",
        seperator = true,
        default = config.Interface.Notifications,
        callback = function(value)
            config.Interface.Notifications = value == true
        end,
    })

    interfaceSection:toggle({
        name = "Debug",
        seperator = true,
        default = config.Debug,
        callback = function(value)
            config.Debug = value == true
        end,
    })

    interfaceSection:colorpicker({
        name = "Accent",
        seperator = true,
        color = Color3.fromRGB(0, 85, 254),
        callback = function(color)
            if type(library.update_theme) == "function" then
                library:update_theme("accent", color)
            end
        end,
    })

    safetySection:toggle({
        name = "Remote URLs",
        seperator = true,
        default = config.Loader.AllowRemoteUrls,
        callback = function(value)
            config.Loader.AllowRemoteUrls = value == true
        end,
    })

    safetySection:toggle({
        name = "Double Click Run",
        seperator = true,
        default = config.Loader.RequireDoubleClick,
        callback = function(value)
            config.Loader.RequireDoubleClick = value == true
        end,
    })

    safetySection:toggle({
        name = "Respect Place Locks",
        seperator = true,
        default = config.Loader.RespectPlaceLocks,
        callback = function(value)
            config.Loader.RespectPlaceLocks = value == true
        end,
    })

    safetySection:toggle({
        name = "Auto Close After Run",
        seperator = true,
        default = config.Loader.AutoCloseAfterRun,
        callback = function(value)
            config.Loader.AutoCloseAfterRun = value == true
        end,
    })

    local sessionColumn = Session:column({})
    local metaColumn = Session:column({})

    local statusSection = sessionColumn:section({
        name = "Status",
        default = true,
        size = 1,
    })

    local metaSection = metaColumn:section({
        name = "Manifest",
        side = "right",
        default = true,
        size = 1,
    })

    state.Gui.StatusLabel = statusSection:label({
        name = "Status",
        info = "Ready",
    })

    state.Gui.StatsLabel = statusSection:label({
        name = "Runs",
        info = "Executed: 0 | Failed: 0",
    })

    statusSection:label({
        name = "User",
        info = LocalPlayer and LocalPlayer.Name or "unknown",
    })

    statusSection:button({
        name = "Unload Loader",
        callback = function()
            notify(SCRIPT_NAME, "Unloading loader.", 2)
            task.delay(0.15, unload)
        end,
    })

    local manifestMeta = state.ManifestMeta or {}
    metaSection:label({
        name = tostring(manifestMeta.Name or "Local fallback"),
        info = "Version: " .. tostring(manifestMeta.Version or SCRIPT_VERSION),
    })

    metaSection:label({
        name = "Games",
        info = tostring(#catalog),
    })

    initConfig(library, window)
    updateStats()
    fadeInWindow(window)

    task.defer(function()
        notify(SCRIPT_NAME, "Loader ready.", 4)
    end)
end

local function prepareCatalog()
    setPreloader(0.16, "Getting game list...")

    local manifestLoaded = false
    local manifestErr = nil

    if type(REMOTE_MANIFEST.Url) == "string" and REMOTE_MANIFEST.Url ~= "" then
        manifestLoaded, manifestErr = fetchManifest()
    else
        manifestErr = "Remote manifest URL is not configured."
    end

    if not manifestLoaded then
        if REMOTE_MANIFEST.Required then
            return false, manifestErr
        end

        state.Catalog = CURRENT_CATALOG
        state.ManifestMeta = {
            Name = "Local fallback",
            Version = SCRIPT_VERSION,
        }

        debugWarn("manifest fallback:", manifestErr)
    end

    setPreloader(0.34, "Caching game images...")

    local catalog = state.Catalog or CURRENT_CATALOG
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

        setPreloader(0.34 + (index / total) * 0.22, "Caching image " .. tostring(index) .. "/" .. tostring(total))
        task.wait()
    end

    setPreloader(0.58, "Preparing scripts...")

    for index, entry in ipairs(catalog) do
        local ok, err = cacheScript(entry)
        if not ok then
            debugWarn("script cache failed:", entry.Name, err)
        end

        setPreloader(0.58 + (index / total) * 0.18, "Preparing script " .. tostring(index) .. "/" .. tostring(total))
        task.wait()
    end

    return true
end

local function bootstrap()
    createPreloader()

    local ready, missing = getExecutorReadiness()
    if not ready then
        setPreloader(1, "Executor is missing: " .. table.concat(missing, ", "))
        notify(SCRIPT_NAME, "Executor is missing: " .. table.concat(missing, ", "), 6, true)
        task.wait(2)
        unload()
        return
    end

    local prepared, prepareErr = prepareCatalog()
    if not prepared then
        setPreloader(1, "Game list failed.")
        notify(SCRIPT_NAME, tostring(prepareErr), 6, true)
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
        notify(SCRIPT_NAME, "UI initialization failed.", 5, true)
        debugWarn("ui init failed:", err)
        task.wait(2)
        unload()
        return
    end

    finishPreloader()
end

bootstrap()
