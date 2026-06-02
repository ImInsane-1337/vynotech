local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera
local Events = ReplicatedStorage:FindFirstChild("Events", true)
local ControlTurnRemote = Events and Events:FindFirstChild("ControlTurn")
local Connections = {}
local unpack = table.unpack or unpack
local GlobalState = {}

if getgenv then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        env.__CBRO_RECODE_STATE = type(env.__CBRO_RECODE_STATE) == "table" and env.__CBRO_RECODE_STATE or {}
        GlobalState = env.__CBRO_RECODE_STATE
    end
end

if type(GlobalState.Cleanup) == "function" then
    pcall(GlobalState.Cleanup)
end

local function GetNamedUpvalue(fn, wantedName)
    local getter = (debug and debug.getupvalue) or getupvalue
    if type(fn) ~= "function" or type(getter) ~= "function" then
        return nil
    end

    for index = 1, 30 do
        local ok, name, value = pcall(getter, fn, index)
        if not ok or name == nil then
            break
        end
        if name == wantedName then
            return value
        end
    end

    return nil
end

local function TrackConnection(connection)
    if connection then
        table.insert(Connections, connection)
    end
    return connection
end

local function RefreshCamera()
    Camera = Workspace.CurrentCamera or Camera
    return Camera
end

TrackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(RefreshCamera))

local PlaceId = game.PlaceId
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local OriginalFOV = Camera and Camera.FieldOfView or 70
local OriginalClockTime = Lighting.ClockTime
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoorAmbient = Lighting.OutdoorAmbient
local OriginalCameraMinZoom = LocalPlayer.CameraMinZoomDistance
local OriginalCameraMaxZoom = LocalPlayer.CameraMaxZoomDistance

getgenv().GameData = {
    Weapons = {},
    OriginalKnives = {},
    GloveData = {},
    GloveTypes = {},
    WeaponData = { Primary = {}, Secondary = {}, Knives = {} },
    SkinData = {},
    SavedSkins = {}
}



getgenv().Config = {
    Legitbot = {
        Aimbot = {
            Enabled = false,
            Keybind = "MB2",
            TeamCheck = true,
            WallCheck = true,
            Smoothness = 5,
            FOV = 100,
            Hitboxes = { "Head" },
            ShowFOV = false,
            FOVColor = Color3.fromRGB(255, 255, 255),
            FOVTransparency = 1,
            FOVFillColor = Color3.fromRGB(255, 255, 255),
            FOVFillTransparency = 0
        },
        SilentAim = {
            Enabled = false,
            Keybind = "MB1",
            TeamCheck = true,
            WallCheck = true,
            AutoFire = false,
            FOV = 100,
            Hitboxes = { "Head" },
            ShowFOV = false,
            FOVColor = Color3.fromRGB(255, 0, 0),
            FOVTransparency = 1
        },
        Triggerbot = {
            Enabled = false,
            Keybind = "MB2",
            TeamCheck = true,
            Delay = 0,
            Hitboxes = { "Head", "Chest", "Stomach", "Arms", "Legs" }
        }
    },
    Rage = {
        AntiAim = {
            Jitter = false,
            PitchJitter = false,
            SpinAngle = 0,
            TickCounter = 0,
            RealYaw = 0,
            CurrentState = "Stand",
            LastState = "Stand",
            States = { "Stand", "Move", "Air", "Crouch" }
        }
    },
    Visuals = {
        ESP = {
            Enemies = {
                Enabled = false,
                Boxes = false,
                BoxColor = Color3.fromRGB(255, 255, 255),
                Names = false,
                NameColor = Color3.fromRGB(255, 255, 255),
                HealthBar = false,
                HealthText = false,
                HealthTextColor = Color3.fromRGB(0, 255, 0),
                Distance = false,
                DistanceColor = Color3.fromRGB(255, 255, 255),
                Weapon = false,
                WeaponColor = Color3.fromRGB(255, 255, 255),
                Chams = false,
                ChamsFillColor = Color3.fromRGB(255, 0, 0),
                ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
                ChamsFillTransparency = 0.5,
                ChamsOutlineTransparency = 0,
                Offscreen = false,
                OffscreenColor = Color3.fromRGB(255, 0, 0),
                OffscreenRadius = 150,
                OffscreenSize = 15
            },
            Teammates = {
                Enabled = false,
                Boxes = false,
                BoxColor = Color3.fromRGB(0, 255, 0),
                Names = false,
                NameColor = Color3.fromRGB(0, 255, 0),
                HealthBar = false,
                HealthText = false,
                HealthTextColor = Color3.fromRGB(0, 255, 0),
                Distance = false,
                DistanceColor = Color3.fromRGB(0, 255, 0),
                Weapon = false,
                WeaponColor = Color3.fromRGB(0, 255, 0),
                Chams = false,
                ChamsFillColor = Color3.fromRGB(0, 255, 0),
                ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
                ChamsFillTransparency = 0.5,
                ChamsOutlineTransparency = 0,
                Offscreen = false,
                OffscreenColor = Color3.fromRGB(0, 255, 0),
                OffscreenRadius = 150,
                OffscreenSize = 15
            },
        },
        LocalChams = {
            Enabled = false,
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 0,
            Material = "Neon"
        },
        World = {
            FOV = { Enabled = false, Value = 90 },
            AspectRatio = { Enabled = false, Value = 1.0 },
            Ambience = { 
                Enabled = false, 
                Outdoor = Color3.fromRGB(100, 100, 100),
                Indoor = Color3.fromRGB(100, 100, 100)
            },
            Time = { Enabled = false, Value = 12 }
        },
        Viewmodel = {
            Weapon = {
                Enabled = false,
                Color = Color3.fromRGB(255, 255, 255),
                Transparency = 0,
                Material = "Neon",
                Reflectance = 0,
                Type = "Static"
            },
            Arms = {
                Enabled = false,
                Color = Color3.fromRGB(255, 0, 0),
                Transparency = 0,
                Material = "Plastic"
            },
            Pos = {
                Enabled = false,
                DisableSway = false,
                X = 0,
                Y = 0,
                Z = 0
            }
        },
        Crosshair = {
            Enabled = false,
            Color = Color3.fromRGB(0, 255, 0),
            Size = 12,
            Thickness = 1,
            Gap = 2
        },
        ThirdPerson = {
            Enabled = false,
            Distance = 10,
            Keybind = "V"
        }
    },
    Skins = {
        Knife = "Default"
    },
    Misc = {
        Spectators = {
            Enabled = false,
            X = 20,
            Y = 300
        },
        Bhop = false,
        InfJump = false,
        CFrameSpeed = {
            Enabled = false,
            Value = 1
        },
        FreezeMove = false
    }
}

local GameData = getgenv().GameData
local Config = getgenv().Config
local UpdateLocalChams = function() end
local UpdateViewmodelChams = function() end
local HopServer
local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
local Options = Library.Options
local Toggles = Library.Toggles

local function GetOptionState(name)
    local option = Options and Options[name]
    if option and type(option.GetState) == "function" then
        return option:GetState()
    end
    return false
end

local function GetToggleValue(name, default)
    local toggle = Toggles and Toggles[name]
    if toggle and toggle.Value ~= nil then
        return toggle.Value
    end
    return default or false
end

local function GetOptionValue(name, default)
    local option = Options and Options[name]
    if option and option.Value ~= nil then
        return option.Value
    end
    return default
end

local function SafeMouseClick()
    if mouse1press and mouse1release then
        mouse1press()
        task.wait(0.05)
        mouse1release()
        return true
    end
    return false
end

local Window = Library:CreateWindow({
    Title = 'vyno.tech | recoded.',
    Center = true,
    AutoShow = true,
    TabPadding = 8
})

local function SyncKeybindVisibility(Toggle, KeyPicker)
    if not Toggle or not KeyPicker then return end

    local function Update()
        if not Toggle.Value or KeyPicker.Value == 'None' then
            KeyPicker.NoUI = true
        else
            KeyPicker.NoUI = false
        end
    end
    Toggle:OnChanged(Update)
    KeyPicker:OnChanged(Update)
    Update()
end

local Tabs = {
    Combat = Window:AddTab('Combat'),
    Rage = Window:AddTab('Rage'),
    Visuals = Window:AddTab('Visuals'),
    Skins = Window:AddTab('Skins'),
    Misc = Window:AddTab('Misc'),
    Settings = Window:AddTab('UI Settings'),
}
local HiddenGroup = Tabs.Settings:AddRightGroupbox('Internal Storage')
HiddenGroup.Visible = false

local function parseskins()
    getgenv().GameData.WeaponData.Primary = {}
    getgenv().GameData.WeaponData.Secondary = {}
    getgenv().GameData.WeaponData.Knives = {}
    getgenv().GameData.SkinData = {}
    
    local weaponsFolder = ReplicatedStorage:WaitForChild("Weapons", 10)
    local skinsFolder = ReplicatedStorage:WaitForChild("Skins", 10)
    if not weaponsFolder or not skinsFolder then
        warn("vyno.tech: Weapons or Skins folder was not found")
        return
    end

    for _, weapon in pairs(weaponsFolder:GetChildren()) do
        local weaponName = weapon.Name
        if weapon:FindFirstChild("Melee") then
            table.insert(getgenv().GameData.WeaponData.Knives, weaponName)
        elseif weapon:FindFirstChild("Secondary") then
            table.insert(getgenv().GameData.WeaponData.Secondary, weaponName)
        elseif weapon:FindFirstChild("Primary") then
            table.insert(getgenv().GameData.WeaponData.Primary, weaponName)
        end
    end

    table.sort(getgenv().GameData.WeaponData.Primary)
    table.sort(getgenv().GameData.WeaponData.Secondary)
    table.sort(getgenv().GameData.WeaponData.Knives)
    
    for _, weaponFolder in pairs(skinsFolder:GetChildren()) do
        local skins = {}
        for _, skin in pairs(weaponFolder:GetChildren()) do
            table.insert(skins, skin.Name)
        end
        table.sort(skins)
        getgenv().GameData.SkinData[weaponFolder.Name] = skins
        
        -- Добавляем скрытые дропдауны
        HiddenGroup:AddDropdown('Conf_' .. weaponFolder.Name, {
            Values = #skins > 0 and skins or { "Default" },
            Default = 1,
            Multi = false,
            Text = weaponFolder.Name,
            Visible = false,
        })
    end

    getgenv().GameData.GloveData = {}
    local glovesFolder = ReplicatedStorage:WaitForChild("Gloves", 10)
    if not glovesFolder then
        warn("vyno.tech: Gloves folder was not found")
        return
    end
    
    for _, folder in pairs(glovesFolder:GetChildren()) do
        if folder.Name ~= "Models" then
            local skins = {}
            for _, skin in pairs(folder:GetChildren()) do
                if skin:FindFirstChild("Textures") then
                    table.insert(skins, skin.Name)
                end
            end
            table.sort(skins)
            getgenv().GameData.GloveData[folder.Name] = skins
            
            -- Добавляем скрытые дропдауны для перчаток
            HiddenGroup:AddDropdown('Conf_Glove_' .. folder.Name, {
                Values = #skins > 0 and skins or { "Default" },
                Default = 1,
                Multi = false,
                Text = folder.Name,
                Visible = false,
            })
        end
    end
    getgenv().GameData.GloveTypes = {}
    for k, _ in pairs(getgenv().GameData.GloveData) do 
        table.insert(getgenv().GameData.GloveTypes, k) 
    end
    table.sort(getgenv().GameData.GloveTypes)
end

parseskins()
local AimbotGroup = Tabs.Combat:AddLeftGroupbox('Legit Aimbot')
local SilentAimGroup = Tabs.Combat:AddRightGroupbox('Silent Aim')
local TriggerGroup = Tabs.Combat:AddLeftGroupbox('Triggerbot')

local AimbotToggle = AimbotGroup:AddToggle('AimbotEnabled', { Text = 'Enabled', Default = Config.Legitbot.Aimbot.Enabled, Callback = function(v) Config.Legitbot.Aimbot.Enabled = v end })
local AimDep = AimbotGroup:AddDependencyBox()
AimDep:AddLabel('Keybind'):AddKeyPicker('AimKey', { Default = Config.Legitbot.Aimbot.Keybind, Mode = 'Hold', Text = 'Aimbot', NoUI = true })
AimDep:AddToggle('AimTeamCheck', { Text = 'Team Check', Default = Config.Legitbot.Aimbot.TeamCheck, Callback = function(v) Config.Legitbot.Aimbot.TeamCheck = v end })
AimDep:AddToggle('AimWallCheck', { Text = 'Wall Check', Default = Config.Legitbot.Aimbot.WallCheck, Callback = function(v) Config.Legitbot.Aimbot.WallCheck = v end })
AimDep:AddSlider('AimSmoothness', { Text = 'Smoothness', Default = Config.Legitbot.Aimbot.Smoothness, Min = 1, Max = 20, Rounding = 1, Callback = function(v) Config.Legitbot.Aimbot.Smoothness = v end })
AimDep:AddSlider('AimFOV', { Text = 'FOV Radius', Default = Config.Legitbot.Aimbot.FOV, Min = 10, Max = 800, Rounding = 0, Callback = function(v) Config.Legitbot.Aimbot.FOV = v end })
AimDep:AddDropdown('AimHitboxes', { Values = { 'Head', 'Chest', 'Stomach', 'Pelvis', 'Arms', 'Legs', 'Feet' }, Default = 1, Multi = true, Text = 'Hitboxes', Callback = function(Value)
    local active = {}
    for name, state in pairs(Value) do if state then table.insert(active, name) end end
    Config.Legitbot.Aimbot.Hitboxes = active
end })
AimDep:AddToggle('ShowFOV', { Text = 'Draw FOV', Default = Config.Legitbot.Aimbot.ShowFOV, Callback = function(v) Config.Legitbot.Aimbot.ShowFOV = v end })
AimDep:AddLabel('FOV Color'):AddColorPicker('FOVColor', { Default = Config.Legitbot.Aimbot.FOVColor, Title = 'FOV Color', Callback = function(v) Config.Legitbot.Aimbot.FOVColor = v end })
AimDep:SetupDependencies({ { AimbotToggle, true } })
SyncKeybindVisibility(AimbotToggle, Library.Options.AimKey)

-- Silent Aim
local SilentToggle = SilentAimGroup:AddToggle('SilentEnabled', { Text = 'Enabled', Default = Config.Legitbot.SilentAim.Enabled, Callback = function(v) Config.Legitbot.SilentAim.Enabled = v end })
local SilentDep = SilentAimGroup:AddDependencyBox()
SilentDep:AddLabel('Keybind'):AddKeyPicker('SilentKey', { Default = Config.Legitbot.SilentAim.Keybind, Mode = 'Hold', Text = 'SilentAim', NoUI = true })
SilentDep:AddToggle('SilentAutoFire', { Text = 'Auto Fire', Default = Config.Legitbot.SilentAim.AutoFire, Callback = function(v) Config.Legitbot.SilentAim.AutoFire = v end })
SilentDep:AddToggle('SilentTeamCheck', { Text = 'Team Check', Default = Config.Legitbot.SilentAim.TeamCheck, Callback = function(v) Config.Legitbot.SilentAim.TeamCheck = v end })
SilentDep:AddToggle('SilentWallCheck', { Text = 'Wall Check', Default = Config.Legitbot.SilentAim.WallCheck, Callback = function(v) Config.Legitbot.SilentAim.WallCheck = v end })
SilentDep:AddSlider('SilentFOV', { Text = 'FOV Radius', Default = Config.Legitbot.SilentAim.FOV, Min = 10, Max = 800, Rounding = 0, Callback = function(v) Config.Legitbot.SilentAim.FOV = v end })
SilentDep:AddDropdown('SilentHitboxes', { Values = { 'Head', 'Chest', 'Stomach', 'Pelvis', 'Arms', 'Legs', 'Feet' }, Default = 1, Multi = true, Text = 'Hitboxes (Priority)', Callback = function(Value)
    local active = {}
    for name, state in pairs(Value) do if state then table.insert(active, name) end end
    Config.Legitbot.SilentAim.Hitboxes = active
end })
SilentDep:AddToggle('ShowSilentFOV', { Text = 'Draw FOV', Default = Config.Legitbot.SilentAim.ShowFOV, Callback = function(v) Config.Legitbot.SilentAim.ShowFOV = v end })
SilentDep:AddLabel('FOV Color'):AddColorPicker('SilentFOVColor', { Default = Config.Legitbot.SilentAim.FOVColor, Title = 'Silent FOV Color', Callback = function(v) Config.Legitbot.SilentAim.FOVColor = v end })
SilentDep:SetupDependencies({ { SilentToggle, true } })
SyncKeybindVisibility(SilentToggle, Library.Options.SilentKey)

-- Triggerbot
local TriggerToggle = TriggerGroup:AddToggle('TriggerEnabled', { Text = 'Enabled', Default = Config.Legitbot.Triggerbot.Enabled, Callback = function(v) Config.Legitbot.Triggerbot.Enabled = v end })
local TrigDep = TriggerGroup:AddDependencyBox()
TrigDep:AddLabel('Keybind'):AddKeyPicker('TriggerKey', { Default = Config.Legitbot.Triggerbot.Keybind, Mode = 'Hold', Text = 'Triggerbot', NoUI = true })
TrigDep:AddToggle('TriggerTeamCheck', { Text = 'Team Check', Default = Config.Legitbot.Triggerbot.TeamCheck, Callback = function(v) Config.Legitbot.Triggerbot.TeamCheck = v end })
TrigDep:AddSlider('TriggerDelay', { Text = 'Delay (ms)', Default = Config.Legitbot.Triggerbot.Delay, Min = 0, Max = 500, Rounding = 0, Callback = function(v) Config.Legitbot.Triggerbot.Delay = v end })
TrigDep:AddDropdown('TriggerHitboxes', { Values = { 'Head', 'Chest', 'Stomach', 'Pelvis', 'Arms', 'Legs', 'Feet' }, Default = 1, Multi = true, Text = 'Hitboxes', Callback = function(Value)
    local active = {}
    for name, state in pairs(Value) do if state then table.insert(active, name) end end
    Config.Legitbot.Triggerbot.Hitboxes = active
end })
TrigDep:SetupDependencies({ { TriggerToggle, true } })
SyncKeybindVisibility(TriggerToggle, Library.Options.TriggerKey)

local IndicatorGroup = Tabs.Combat:AddRightGroupbox('Aim Indicator')
IndicatorGroup:AddToggle('AimIndicator', { Text = 'Target Highlight', Default = false, Tooltip = 'Highlights the player you are currently aiming at' }):AddColorPicker('AimIndicatorColor', { Default = Color3.fromRGB(255, 255, 0), Title = 'Indicator Color' })

-- RAGE TAB
local RAntiAim = Tabs.Rage:AddRightGroupbox('Anti-aim')
RAntiAim:AddToggle('AA_Enabled', { Text = 'Enabled', Default = false, Tooltip = 'Master Switch' })
RAntiAim:AddLabel('Current State: Stand', true, 'StateLabel')
RAntiAim:AddDropdown('StateSelector', {
    Values = Config.Rage.AntiAim.States,
    Default = 1,
    Multi = false,
    Text = 'Edit State Config'
})
RAntiAim:AddDivider()

for _, state in ipairs(Config.Rage.AntiAim.States) do
    local p = state .. "_"
    local StateDep = RAntiAim:AddDependencyBox()
    -- == PITCH ==
    local PitchDrop = StateDep:AddDropdown(p..'Pitch', { Values = {'None', 'Up', 'Down', 'Zero', 'Custom', 'Jitter', 'Spin', 'Random'}, Default = 1, Text = 'Pitch Mode' })
    local P_Custom = StateDep:AddDependencyBox(); P_Custom:AddSlider(p..'PitchCustom', { Text = 'Custom Pitch', Default = 0, Min = -1.5, Max = 1.5, Rounding = 2 }); P_Custom:SetupDependencies({ { PitchDrop, 'Custom' } })
    local P_Jitter = StateDep:AddDependencyBox(); P_Jitter:AddSlider(p..'PitchJitterAmt', { Text = 'Pitch Jitter Amount', Default = 0, Min = 0, Max = 1.5, Rounding = 2 }); P_Jitter:SetupDependencies({ { PitchDrop, 'Jitter' } })
    local P_Spin   = StateDep:AddDependencyBox(); P_Spin:AddSlider(p..'PitchSpinSpeed', { Text = 'Pitch Spin Speed', Default = 1, Min = 0, Max = 10, Rounding = 1 }); P_Spin:SetupDependencies({ { PitchDrop, 'Spin' } })
    local P_Rand   = StateDep:AddDependencyBox(); P_Rand:AddSlider(p..'PitchRandomAmt', { Text = 'Pitch Random Amount', Default = 0, Min = 0, Max = 1.5, Rounding = 2 }); P_Rand:SetupDependencies({ { PitchDrop, 'Random' } })

    StateDep:AddDivider()

    -- == YAW ==
    StateDep:AddDropdown(p..'YawBase', { Values = {'Camera', 'Backwards', '-90', '90'}, Default = 2, Text = 'Yaw Base' })
    local YawModeDrop = StateDep:AddDropdown(p..'YawMode', { Values = {'None', 'Jitter', 'Spin', 'Random'}, Default = 1, Text = 'Yaw Modifier' })
    StateDep:AddSlider(p..'YawCustom', { Text = 'Add Yaw', Default = 0, Min = -180, Max = 180, Rounding = 0 })
    local Y_Jitter = StateDep:AddDependencyBox(); Y_Jitter:AddSlider(p..'JitterAngle', { Text = 'Jitter Angle', Default = 0, Min = 0, Max = 180, Rounding = 0 }); Y_Jitter:SetupDependencies({ { YawModeDrop, 'Jitter' } })
    local Y_Spin = StateDep:AddDependencyBox()
    Y_Spin:AddSlider(p..'SpinSpeed', { Text = 'Speed', Default = 1, Min = 0, Max = 100, Rounding = 0 })
    Y_Spin:AddSlider(p..'SpinRange', { Text = 'Range', Default = 0, Min = 0, Max = 360, Rounding = 0 })
    Y_Spin:SetupDependencies({ { YawModeDrop, 'Spin' } })
    local Y_Rand = StateDep:AddDependencyBox(); Y_Rand:AddSlider(p..'RandomRange', { Text = 'Random Range', Default = 0, Min = 0, Max = 180, Rounding = 0 }); Y_Rand:SetupDependencies({ { YawModeDrop, 'Random' } })
    StateDep:AddSlider(p..'TickDelay', { Text = 'Tick Delay', Default = 1, Min = 1, Max = 10, Rounding = 0 })
    StateDep:SetupDependencies({
        { Library.Options.StateSelector, state }
    })
end

local function getBaseYaw(state)
    local cam = RefreshCamera()
    if not cam or not Options[state .. '_YawBase'] then return 0 end

    local mode = Options[state .. '_YawBase'].Value
    local camYaw = select(2, cam.CFrame:ToEulerAnglesYXZ())
    
    if mode == 'Camera' then return camYaw
    elseif mode == 'Backwards' then return camYaw + math.pi
    elseif mode == '-90' then return camYaw - math.rad(90)
    elseif mode == '90' then return camYaw + math.rad(90)
    end
    return 0
end

local function updateState()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") then return "Stand" end
    
    local hum = char.Humanoid
    local root = char:FindFirstChild("HumanoidRootPart")

    if char:FindFirstChild("Crouched") then
        return "Crouch"
    end

    if hum:GetState() == Enum.HumanoidStateType.Freefall or hum:GetState() == Enum.HumanoidStateType.Jumping then
        return "Air"
    end

    if hum.MoveDirection.Magnitude > 0.1 or (root and root.AssemblyLinearVelocity.Magnitude > 2) then
        return "Move"
    end

    return "Stand"
end

local SteppedConnection = RunService.Stepped:Connect(function(time, deltaTime)
    if Library.Unloaded or not Config then return end

    local currentState = updateState()
    Config.Rage.AntiAim.CurrentState = currentState
    
    if Library.Labels.StateLabel then
        Library.Labels.StateLabel:SetText('Current State: ' .. currentState)
    end

    if not GetToggleValue("AA_Enabled") then 
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.AutoRotate = true
        end
        return 
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.AutoRotate = true
        end
        return
    end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return end

    local hrp = char.HumanoidRootPart
    local hum = char.Humanoid
    hum.AutoRotate = false

    local p = currentState .. "_"
    if Config.Rage.AntiAim.LastState ~= currentState then
        Config.Rage.AntiAim.TickCounter = 999
        Config.Rage.AntiAim.Jitter = false
        Config.Rage.AntiAim.PitchJitter = false
        Config.Rage.AntiAim.LastState = currentState
    end
    local pitchMode = GetOptionValue(p .. 'Pitch', 'None')
    local pitchAngle = nil

    if pitchMode == 'Up' then 
        pitchAngle = 1
    elseif pitchMode == 'Down' then 
        pitchAngle = -1
    elseif pitchMode == 'Zero' then 
        pitchAngle = 0
    elseif pitchMode == 'Custom' then 
        pitchAngle = GetOptionValue(p .. 'PitchCustom', 0)
    elseif pitchMode == 'Jitter' then
        Config.Rage.AntiAim.PitchJitter = not Config.Rage.AntiAim.PitchJitter
        local amt = GetOptionValue(p .. 'PitchJitterAmt', 0)
        pitchAngle = Config.Rage.AntiAim.PitchJitter and amt or -amt
    elseif pitchMode == 'Spin' then
        local speed = GetOptionValue(p .. 'PitchSpinSpeed', 1)
        pitchAngle = math.sin(time * speed)
    elseif pitchMode == 'Random' then
        local amt = GetOptionValue(p .. 'PitchRandomAmt', 0)
        pitchAngle = -amt + math.random() * (amt - (-amt))
    end

    if ControlTurnRemote and pitchAngle ~= nil then
        local isClimbing = hum:GetState() == Enum.HumanoidStateType.Climbing
        task.spawn(function()
            ControlTurnRemote:FireServer(pitchAngle, isClimbing)
        end)
    end


    Config.Rage.AntiAim.TickCounter = Config.Rage.AntiAim.TickCounter + 1
    local delay = GetOptionValue(p .. 'TickDelay', 1)
    
    local shouldUpdateYaw = (Config.Rage.AntiAim.TickCounter >= delay)

    if shouldUpdateYaw then
        Config.Rage.AntiAim.TickCounter = 0
        
        local baseYaw = getBaseYaw(currentState)
        local customYaw = math.rad(GetOptionValue(p .. 'YawCustom', 0))
        local modifier = 0
        local mode = GetOptionValue(p .. 'YawMode', 'None')

        if mode == 'Jitter' then
            Config.Rage.AntiAim.Jitter = not Config.Rage.AntiAim.Jitter
            local angle = math.rad(GetOptionValue(p .. 'JitterAngle', 0))
            modifier = Config.Rage.AntiAim.Jitter and angle or -angle
        elseif mode == 'Spin' then
            local speed = GetOptionValue(p .. 'SpinSpeed', 1)
            local range = GetOptionValue(p .. 'SpinRange', 0)
            Config.Rage.AntiAim.SpinAngle = Config.Rage.AntiAim.SpinAngle + speed
            if range > 0 and Config.Rage.AntiAim.SpinAngle > range then Config.Rage.AntiAim.SpinAngle = 0 end
            modifier = math.rad(Config.Rage.AntiAim.SpinAngle)
        elseif mode == 'Random' then
            local range = GetOptionValue(p .. 'RandomRange', 0)
            modifier = math.rad(math.random(-range, range))
        end

        local finalYaw = baseYaw + customYaw + modifier
        Config.Rage.AntiAim.RealYaw = finalYaw

        local newCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, finalYaw, 0)
        hrp.CFrame = newCFrame
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end


    local fakeHead = char:FindFirstChild("FakeHead")
    local headHB = char:FindFirstChild("HeadHB")
    local realHead = char:FindFirstChild("Head")

    if fakeHead and headHB and realHead and pitchAngle ~= nil then
        if not headHB:FindFirstChild("Weld") and not fakeHead:FindFirstChild("Weld") then
            fakeHead.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            headHB.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

            local yawLook = CFrame.Angles(0, Config.Rage.AntiAim.RealYaw, 0).LookVector
            local safePitch = math.clamp(pitchAngle, -1, 1)
            local xzScale = math.sqrt(math.max(0, 1 - safePitch^2))
            
            local targetLookVector = Vector3.new(
                yawLook.X * xzScale,
                safePitch,
                yawLook.Z * xzScale
            )

            local headPos = realHead.Position
            local finalCFrame = CFrame.lookAt(headPos, headPos + targetLookVector)

            fakeHead.CFrame = finalCFrame
            headHB.CFrame = finalCFrame
        end
    end
end)
table.insert(Connections, SteppedConnection)

-- VISUALS TAB
local ESPTabBox = Tabs.Visuals:AddLeftTabbox()
local EnemyTab = ESPTabBox:AddTab('Enemy')
local TeammateTab = ESPTabBox:AddTab('Teammates')
local LocalChamsTab = ESPTabBox:AddTab('Local')

local function BuildESPMenu(Tab, ConfigTable, Prefix)
    local MainToggle = Tab:AddToggle(Prefix..'Enabled', { Text = 'Enable ESP', Default = ConfigTable.Enabled, Callback = function(v) ConfigTable.Enabled = v end })
    
    local EspDep = Tab:AddDependencyBox()
    EspDep:AddToggle(Prefix..'Boxes', { Text = 'Box ESP', Default = ConfigTable.Boxes, Callback = function(v) ConfigTable.Boxes = v end }):AddColorPicker(Prefix..'BoxColor', { Default = ConfigTable.BoxColor, Title = 'Box Color', Callback = function(v) ConfigTable.BoxColor = v end })
    EspDep:AddToggle(Prefix..'Names', { Text = 'Name ESP', Default = ConfigTable.Names, Callback = function(v) ConfigTable.Names = v end }):AddColorPicker(Prefix..'NameColor', { Default = ConfigTable.NameColor, Title = 'Name Color', Callback = function(v) ConfigTable.NameColor = v end })
    EspDep:AddToggle(Prefix..'HealthBar', { Text = 'Health Bar', Default = ConfigTable.HealthBar, Callback = function(v) ConfigTable.HealthBar = v end })
    EspDep:AddToggle(Prefix..'HealthText', { Text = 'Health Text', Default = ConfigTable.HealthText, Callback = function(v) ConfigTable.HealthText = v end }):AddColorPicker(Prefix..'HealthTextColor', { Default = ConfigTable.HealthTextColor, Title = 'Health Text Color', Callback = function(v) ConfigTable.HealthTextColor = v end })
    EspDep:AddToggle(Prefix..'Weapon', { Text = 'Weapon ESP', Default = ConfigTable.Weapon, Callback = function(v) ConfigTable.Weapon = v end }):AddColorPicker(Prefix..'WeaponColor', { Default = ConfigTable.WeaponColor, Title = 'Weapon Color', Callback = function(v) ConfigTable.WeaponColor = v end })
    EspDep:AddToggle(Prefix..'Distance', { Text = 'Distance ESP', Default = ConfigTable.Distance, Callback = function(v) ConfigTable.Distance = v end }):AddColorPicker(Prefix..'DistanceColor', { Default = ConfigTable.DistanceColor, Title = 'Distance Color', Callback = function(v) ConfigTable.DistanceColor = v end })
    EspDep:AddDivider()
    EspDep:AddToggle(Prefix..'Chams', { Text = 'Chams', Default = ConfigTable.Chams, Callback = function(v) ConfigTable.Chams = v end })
    EspDep:AddLabel('Chams Fill'):AddColorPicker(Prefix..'ChamsFillColor', { Default = ConfigTable.ChamsFillColor, Title = 'Chams Fill', Callback = function(v) ConfigTable.ChamsFillColor = v end })
    EspDep:AddLabel('Chams Outline'):AddColorPicker(Prefix..'ChamsOutlineColor', { Default = ConfigTable.ChamsOutlineColor, Title = 'Chams Outline', Callback = function(v) ConfigTable.ChamsOutlineColor = v end })
    EspDep:AddDivider()
    EspDep:AddToggle(Prefix..'Offscreen', { Text = 'Offscreen Arrows', Default = ConfigTable.Offscreen, Callback = function(v) ConfigTable.Offscreen = v end }):AddColorPicker(Prefix..'OffscreenColor', { Default = ConfigTable.OffscreenColor, Title = 'Arrow Color', Callback = function(v) ConfigTable.OffscreenColor = v end })
    EspDep:AddSlider(Prefix..'OffscreenRadius', { Text = 'Arrow Radius', Default = ConfigTable.OffscreenRadius, Min = 50, Max = 500, Rounding = 0, Callback = function(v) ConfigTable.OffscreenRadius = v end })
    EspDep:AddSlider(Prefix..'OffscreenSize', { Text = 'Arrow Size', Default = ConfigTable.OffscreenSize, Min = 10, Max = 30, Rounding = 0, Callback = function(v) ConfigTable.OffscreenSize = v end })
    EspDep:SetupDependencies({ { MainToggle, true } })
end

local LocalChamsToggle = LocalChamsTab:AddToggle('LocalChamsEnabled', { Text = 'Self Chams', Default = Config.Visuals.LocalChams.Enabled, Callback = function(v) Config.Visuals.LocalChams.Enabled = v; UpdateLocalChams() end })
local LocalChamsDep = LocalChamsTab:AddDependencyBox()

LocalChamsDep:AddLabel('Color'):AddColorPicker('LocalChamsColor', { Default = Config.Visuals.LocalChams.Color, Title = 'Self Color', Callback = function(v) Config.Visuals.LocalChams.Color = v; UpdateLocalChams() end })
LocalChamsDep:AddSlider('LocalChamsTransparency', { Text = 'Transparency', Default = Config.Visuals.LocalChams.Transparency, Min = 0, Max = 1, Rounding = 1, Callback = function(v) Config.Visuals.LocalChams.Transparency = v; UpdateLocalChams() end })
LocalChamsDep:AddDropdown('LocalChamsMaterial', { Values = { 'Plastic', 'Neon', 'ForceField', 'Glass', 'SmoothPlastic' }, Default = 2, Multi = false, Text = 'Material', Callback = function(v) Config.Visuals.LocalChams.Material = v; UpdateLocalChams() end })

LocalChamsDep:SetupDependencies({ { LocalChamsToggle, true } })

BuildESPMenu(EnemyTab, Config.Visuals.ESP.Enemies, 'Enemy')
BuildESPMenu(TeammateTab, Config.Visuals.ESP.Teammates, 'Team')

local WorldGroup = Tabs.Visuals:AddRightGroupbox('World Visuals')
local ViewmodelTabBox = Tabs.Visuals:AddRightTabbox()
local CrosshairGroup = Tabs.Visuals:AddRightGroupbox('Custom Crosshair')

WorldGroup:AddToggle('WorldFOV', { Text = 'FOV Changer', Default = Config.Visuals.World.FOV.Enabled, Callback = function(v)
    Config.Visuals.World.FOV.Enabled = v
    local cam = RefreshCamera()
    if not v and cam then cam.FieldOfView = OriginalFOV end
end })
WorldGroup:AddSlider('WorldFOVVal', { Text = 'Field of View', Default = Config.Visuals.World.FOV.Value, Min = 30, Max = 120, Rounding = 0, Callback = function(v) Config.Visuals.World.FOV.Value = v end })
WorldGroup:AddToggle('AspectRatio', { Text = 'Aspect Ratio', Default = Config.Visuals.World.AspectRatio.Enabled, Callback = function(v) Config.Visuals.World.AspectRatio.Enabled = v end })
WorldGroup:AddSlider('AspectRatioVal', { Text = 'Ratio Factor', Default = Config.Visuals.World.AspectRatio.Value, Min = 0.1, Max = 2, Rounding = 2, Callback = function(v) Config.Visuals.World.AspectRatio.Value = v end })
WorldGroup:AddToggle('WorldAmbience', { Text = 'Ambience Changer', Default = Config.Visuals.World.Ambience.Enabled, Callback = function(v)
    Config.Visuals.World.Ambience.Enabled = v
    if not v then
        Lighting.Ambient = OriginalAmbient
        Lighting.OutdoorAmbient = OriginalOutdoorAmbient
    end
end })
WorldGroup:AddLabel('Outdoor Color'):AddColorPicker('WorldAmbienceOut', { Default = Config.Visuals.World.Ambience.Outdoor, Title = 'Outdoor Color', Callback = function(v) Config.Visuals.World.Ambience.Outdoor = v end })
WorldGroup:AddLabel('Indoor Color'):AddColorPicker('WorldAmbienceIn', { Default = Config.Visuals.World.Ambience.Indoor, Title = 'Indoor Color', Callback = function(v) Config.Visuals.World.Ambience.Indoor = v end })
WorldGroup:AddToggle('WorldTime', { Text = 'Time Changer', Default = Config.Visuals.World.Time.Enabled, Callback = function(v)
    Config.Visuals.World.Time.Enabled = v
    if not v then Lighting.ClockTime = OriginalClockTime end
end })
WorldGroup:AddSlider('WorldTimeVal', { Text = 'Clock Time', Default = Config.Visuals.World.Time.Value, Min = 0, Max = 24, Rounding = 1, Callback = function(v) Config.Visuals.World.Time.Value = v end })

local WeaponTab = ViewmodelTabBox:AddTab('Weapon')
local ArmsTab = ViewmodelTabBox:AddTab('Arms')
local PosTab = ViewmodelTabBox:AddTab('Position')

-- Weapon Chams
local WepToggle = WeaponTab:AddToggle('VMWeaponEnabled', { Text = 'Weapon Chams', Default = Config.Visuals.Viewmodel.Weapon.Enabled, Callback = function(v) Config.Visuals.Viewmodel.Weapon.Enabled = v; UpdateViewmodelChams() end })
local WepDep = WeaponTab:AddDependencyBox()
WepDep:AddLabel('Weapon Color'):AddColorPicker('VMWeaponColor', { Default = Config.Visuals.Viewmodel.Weapon.Color, Title = 'Weapon Color', Callback = function(v) Config.Visuals.Viewmodel.Weapon.Color = v; UpdateViewmodelChams() end })
WepDep:AddSlider('VMWeaponTransparency', { Text = 'Transparency', Default = Config.Visuals.Viewmodel.Weapon.Transparency, Min = 0, Max = 1, Rounding = 1, Callback = function(v) Config.Visuals.Viewmodel.Weapon.Transparency = v; UpdateViewmodelChams() end })
WepDep:AddSlider('VMWeaponReflectance', { Text = 'Reflectance', Default = Config.Visuals.Viewmodel.Weapon.Reflectance, Min = 0, Max = 1, Rounding = 1, Callback = function(v) Config.Visuals.Viewmodel.Weapon.Reflectance = v; UpdateViewmodelChams() end })
WepDep:AddDropdown('VMWeaponMaterial', { Values = { 'Plastic', 'Neon', 'ForceField', 'Glass', 'SmoothPlastic' }, Default = 2, Multi = false, Text = 'Material', Callback = function(v) Config.Visuals.Viewmodel.Weapon.Material = v; UpdateViewmodelChams() end })
WepDep:AddDropdown('VMWeaponType', { Values = { 'Static', 'Pulse', 'Rainbow' }, Default = 1, Multi = false, Text = 'Type', Callback = function(v) Config.Visuals.Viewmodel.Weapon.Type = v; UpdateViewmodelChams() end })
WepDep:SetupDependencies({ { WepToggle, true } })

-- Arms Chams
local ArmsToggle = ArmsTab:AddToggle('VMArmsEnabled', { Text = 'Arms Chams', Default = Config.Visuals.Viewmodel.Arms.Enabled, Callback = function(v) Config.Visuals.Viewmodel.Arms.Enabled = v; UpdateViewmodelChams() end })
local ArmsDep = ArmsTab:AddDependencyBox()
ArmsDep:AddLabel('Arms Color'):AddColorPicker('VMArmsColor', { Default = Config.Visuals.Viewmodel.Arms.Color, Title = 'Arms Color', Callback = function(v) Config.Visuals.Viewmodel.Arms.Color = v; UpdateViewmodelChams() end })
ArmsDep:AddSlider('VMArmsTransparency', { Text = 'Transparency', Default = Config.Visuals.Viewmodel.Arms.Transparency, Min = 0, Max = 1, Rounding = 1, Callback = function(v) Config.Visuals.Viewmodel.Arms.Transparency = v; UpdateViewmodelChams() end })
ArmsDep:AddDropdown('VMArmsMaterial', { Values = { 'Plastic', 'Neon', 'ForceField', 'Glass', 'SmoothPlastic' }, Default = 1, Multi = false, Text = 'Material', Callback = function(v) Config.Visuals.Viewmodel.Arms.Material = v; UpdateViewmodelChams() end })
ArmsDep:SetupDependencies({ { ArmsToggle, true } })

-- Position Tab
local PosToggle = PosTab:AddToggle('VMPosEnabled', { Text = 'Enable Modifiers', Default = Config.Visuals.Viewmodel.Pos.Enabled, Callback = function(v) Config.Visuals.Viewmodel.Pos.Enabled = v end })
local PosDep = PosTab:AddDependencyBox()
PosDep:AddToggle('VMSway', { Text = 'Disable Swaying', Default = Config.Visuals.Viewmodel.Pos.DisableSway, Callback = function(v) Config.Visuals.Viewmodel.Pos.DisableSway = v end })
PosDep:AddSlider('VMX', { Text = 'Offset X', Default = Config.Visuals.Viewmodel.Pos.X, Min = -5, Max = 5, Rounding = 1, Callback = function(v) Config.Visuals.Viewmodel.Pos.X = v end })
PosDep:AddSlider('VMY', { Text = 'Offset Y', Default = Config.Visuals.Viewmodel.Pos.Y, Min = -5, Max = 5, Rounding = 1, Callback = function(v) Config.Visuals.Viewmodel.Pos.Y = v end })
PosDep:AddSlider('VMZ', { Text = 'Offset Z', Default = Config.Visuals.Viewmodel.Pos.Z, Min = -5, Max = 5, Rounding = 1, Callback = function(v) Config.Visuals.Viewmodel.Pos.Z = v end })
PosDep:SetupDependencies({ { PosToggle, true } })

local CrossToggle = CrosshairGroup:AddToggle('CrosshairEnabled', { Text = 'Enable Crosshair', Default = Config.Visuals.Crosshair.Enabled, Callback = function(v) Config.Visuals.Crosshair.Enabled = v end })
local CrossDep = CrosshairGroup:AddDependencyBox()
CrossDep:AddLabel('Color'):AddColorPicker('CrosshairColor', { Default = Config.Visuals.Crosshair.Color, Title = 'Crosshair Color', Callback = function(v) Config.Visuals.Crosshair.Color = v end })
CrossDep:AddSlider('CrosshairSize', { Text = 'Size', Default = Config.Visuals.Crosshair.Size, Min = 4, Max = 40, Rounding = 0, Callback = function(v) Config.Visuals.Crosshair.Size = v end })
CrossDep:AddSlider('CrosshairThickness', { Text = 'Thickness', Default = Config.Visuals.Crosshair.Thickness, Min = 1, Max = 5, Rounding = 0, Callback = function(v) Config.Visuals.Crosshair.Thickness = v end })
CrossDep:AddSlider('CrosshairGap', { Text = 'Gap', Default = Config.Visuals.Crosshair.Gap, Min = 0, Max = 20, Rounding = 0, Callback = function(v) Config.Visuals.Crosshair.Gap = v end })
CrossDep:SetupDependencies({ { CrossToggle, true } })

local TPGroup = Tabs.Visuals:AddLeftGroupbox('Third Person')

local TPToggle = TPGroup:AddToggle('TPEnabled', { Text = 'Enabled', Default = Config.Visuals.ThirdPerson.Enabled, Callback = function(v) 
    Config.Visuals.ThirdPerson.Enabled = v 
    if not v then 
        LocalPlayer.CameraMinZoomDistance = OriginalCameraMinZoom 
        LocalPlayer.CameraMaxZoomDistance = OriginalCameraMaxZoom 
    end
end })

local TPDep = TPGroup:AddDependencyBox()
TPDep:AddSlider('TPDistance', { Text = 'Distance', Default = Config.Visuals.ThirdPerson.Distance, Min = 1, Max = 20, Rounding = 1, Callback = function(v) Config.Visuals.ThirdPerson.Distance = v end })
TPDep:AddLabel('Keybind'):AddKeyPicker('TPKey', { Default = Config.Visuals.ThirdPerson.Keybind, Mode = 'Toggle', Text = 'Third Person', SyncToggleState = false })
SyncKeybindVisibility(TPToggle, Library.Options.TPKey)
TPDep:SetupDependencies({ { TPToggle, true } })

-- Ручная синхронизация
Library.Options.TPKey:OnClick(function()
    local keyState = Library.Options.TPKey:GetState()
    local toggleState = TPToggle.Value
    
    if toggleState ~= keyState then
        TPToggle:SetValue(keyState)
    end
end)

-- [[ SKINS TAB ]]

-- 1. Сначала объявляем вспомогательные функции, чтобы они были видны везде
local function GetSourceMeshId(sourceObj)
    if not sourceObj then return nil end
    if sourceObj:IsA("MeshPart") then return sourceObj.MeshId end
    local sm = sourceObj:FindFirstChildOfClass("SpecialMesh")
    if sm then return sm.MeshId end
    return nil
end

local function ProcessArm(armObj, meshId, textureId)
    local glove = armObj:FindFirstChild("Glove")
    if not glove then return end

    if glove.Transparency > 0 then glove.Transparency = 0 end

    local sa = glove:FindFirstChildOfClass("SurfaceAppearance")
    if sa then sa:Destroy() end
    if not glove:GetAttribute("SizeModified") then
        glove.Size = glove.Size + Vector3.new(0, 0.05, 0.05)
        glove:SetAttribute("SizeModified", true)
    end

    if glove:IsA("MeshPart") then
        if meshId and glove.MeshId ~= meshId then glove.MeshId = meshId end
        if glove.TextureID ~= textureId then glove.TextureID = textureId end
    elseif glove:IsA("BasePart") then
        local sm = glove:FindFirstChildOfClass("SpecialMesh")
        if sm then
            if meshId and sm.MeshId ~= meshId then sm.MeshId = meshId end
            if sm.TextureId ~= textureId then sm.TextureId = textureId end
        end
    end
end

local function IsGun(armsModel)
    if not armsModel then return false end
    if armsModel:FindFirstChild("Slide") or 
       armsModel:FindFirstChild("Magazine") or 	
       armsModel:FindFirstChild("Bolt") or 
       armsModel:FindFirstChild("Chamber") or
       armsModel:FindFirstChild("HUD") then 
        return true 
    end
    return false
end

local function ApplySkinToFolder(weaponName, skinName)
    if not weaponName or not skinName then return end
    local skinFolder = LocalPlayer:WaitForChild("SkinFolder", 5)
    if not skinFolder then return end
    
    local folders = {skinFolder:FindFirstChild("CTFolder"), skinFolder:FindFirstChild("TFolder")}
    for _, folder in pairs(folders) do
        if folder then
            local weaponValue = folder:FindFirstChild(weaponName)
            if weaponValue and weaponValue:IsA("StringValue") then
                weaponValue.Value = skinName
            end
        end
    end
end

local function ApplyKnifeModel(knifeName)
    if not knifeName then return end
    local modelName = "v_" .. knifeName
    local vmFolder = ReplicatedStorage:WaitForChild("Viewmodels", 10)
    if not vmFolder then return end
    local targetModel = vmFolder:FindFirstChild(modelName)
    if not targetModel then return end

    pcall(function()
        if vmFolder:FindFirstChild("v_CT Knife") then vmFolder["v_CT Knife"]:Destroy() end
        if vmFolder:FindFirstChild("v_T Knife") then vmFolder["v_T Knife"]:Destroy() end
        local ctKnife = targetModel:Clone()
        ctKnife.Name = "v_CT Knife"
        ctKnife.Parent = vmFolder
        local tKnife = targetModel:Clone()
        tKnife.Name = "v_T Knife"
        tKnife.Parent = vmFolder
    end)
end

local LastArms = nil
local CachedLeftArm = nil
local CachedRightArm = nil

local function UpdateSkins()
    local cam = RefreshCamera()
    if not cam then return end

    local armsContainer = cam:FindFirstChild("Arms")
    
    if armsContainer ~= LastArms then
        LastArms = armsContainer
        CachedLeftArm = nil
        CachedRightArm = nil
        
        if armsContainer then
            for _, v in pairs(armsContainer:GetDescendants()) do
                if v.Name == "Left Arm" then CachedLeftArm = v end
                if v.Name == "Right Arm" then CachedRightArm = v end
            end
        end
    end

    if not armsContainer then return end
    local kModel = Options.KnifeSelect.Value
    local kSkin = nil
    if kModel and Options['Conf_' .. kModel] then
        kSkin = Options['Conf_' .. kModel].Value
    end

    if kModel and kSkin and not IsGun(armsContainer) then
        local skinsRoot = ReplicatedStorage:FindFirstChild("Skins")
        local skinFolder = skinsRoot and skinsRoot:FindFirstChild(kModel)
        if skinFolder then
            local skinVariant = skinFolder:FindFirstChild(kSkin)
            if skinVariant then
                for _, part in pairs(armsContainer:GetChildren()) do
                    local sourceData = skinVariant:FindFirstChild(part.Name)
                    if sourceData and sourceData:IsA("StringValue") then
                        local textureId = sourceData.Value
                        
                        if part:IsA("MeshPart") then
                            if part.TextureID ~= textureId then
                                part.TextureID = textureId
                            end
                        elseif part:IsA("BasePart") then
                            local pMesh = part:FindFirstChildOfClass("SpecialMesh")
                            if pMesh then
                                if pMesh.TextureId ~= textureId then
                                    pMesh.TextureId = textureId
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if GetToggleValue("EnableGloves") then
        local gType = Options.GloveType.Value
        -- Берем скин из скрытого хранилища для текущего типа перчаток
        local gSkin = nil
        if gType and Options['Conf_Glove_' .. gType] then
            gSkin = Options['Conf_Glove_' .. gType].Value
        end
        
        if gType and gSkin then
            local glovesRoot = ReplicatedStorage:FindFirstChild("Gloves")
            local skinFolder = glovesRoot and glovesRoot:FindFirstChild(gType)
            local modelsFolder = glovesRoot and glovesRoot:FindFirstChild("Models")
            
            if skinFolder and modelsFolder then
                local skinObj = skinFolder:FindFirstChild(gSkin)
                local typeModelFolder = modelsFolder:FindFirstChild(gType)
                
                if skinObj and typeModelFolder then
                    local textureObj = skinObj:FindFirstChild("Textures")
                    if textureObj then
                        local targetTextureId = textureObj.TextureId
                        local lMeshId = GetSourceMeshId(typeModelFolder:FindFirstChild("LGlove"))
                        local rMeshId = GetSourceMeshId(typeModelFolder:FindFirstChild("RGlove"))

                        if CachedLeftArm then ProcessArm(CachedLeftArm, lMeshId, targetTextureId) end
                        if CachedRightArm then ProcessArm(CachedRightArm, rMeshId, targetTextureId) end
                    end
                end
            end
        end
    end
end

-- 3. Интерфейс (UI)
local PrimaryGroup = Tabs.Skins:AddLeftGroupbox('Primary')
local SecondaryGroup = Tabs.Skins:AddRightGroupbox('Secondary')
local KnifeGroup = Tabs.Skins:AddRightGroupbox('KnifeChanger')
local GloveGroup = Tabs.Skins:AddLeftGroupbox('Gloves')
local StatTrakGroup = Tabs.Skins:AddLeftGroupbox('StatTrak')

PrimaryGroup:AddDropdown('PrimaryWeapon', { 
    Values = GameData.WeaponData.Primary, 
    Default = 1, 
    Multi = false, 
    Text = 'Select Primary', 
    Callback = function(Value) 
        if Value and GameData.SkinData[Value] then 
            Options.PrimarySkin:SetValues(GameData.SkinData[Value])
            local savedSkin = Options['Conf_' .. Value].Value
            Options.PrimarySkin:SetValue(savedSkin)
        else 
            Options.PrimarySkin:SetValues({}) 
        end 
    end
})

PrimaryGroup:AddDropdown('PrimarySkin', { 
    Values = {}, 
    Default = 1, 
    Multi = false, 
    Text = 'Select Skin', 
    Callback = function(Value) 
        local currentWeapon = Options.PrimaryWeapon.Value
        if currentWeapon and Value then 
            ApplySkinToFolder(currentWeapon, Value) 
            if Options['Conf_' .. currentWeapon] then
                Options['Conf_' .. currentWeapon]:SetValue(Value)
            end
        end 
    end 
})

-- Secondary
SecondaryGroup:AddDropdown('SecondaryWeapon', { 
    Values = GameData.WeaponData.Secondary, 
    Default = 1, 
    Multi = false, 
    Text = 'Select Secondary', 
    Callback = function(Value) 
        if Value and GameData.SkinData[Value] then 
            Options.SecondarySkin:SetValues(GameData.SkinData[Value])
            local savedSkin = Options['Conf_' .. Value].Value
            Options.SecondarySkin:SetValue(savedSkin)
        else 
            Options.SecondarySkin:SetValues({}) 
        end 
    end 
})

SecondaryGroup:AddDropdown('SecondarySkin', { 
    Values = {}, 
    Default = 1, 
    Multi = false, 
    Text = 'Select Skin', 
    Callback = function(Value) 
        local currentWeapon = Options.SecondaryWeapon.Value
        if currentWeapon and Value then 
            ApplySkinToFolder(currentWeapon, Value) 
            if Options['Conf_' .. currentWeapon] then
                Options['Conf_' .. currentWeapon]:SetValue(Value)
            end
        end 
    end 
})

-- Knife
KnifeGroup:AddDropdown('KnifeSelect', { 
    Values = GameData.WeaponData.Knives, 
    Default = 1, 
    Multi = false, 
    Text = 'Select Knife', 
    Callback = function(Value) 
        ApplyKnifeModel(Value)
        if Value and GameData.SkinData[Value] then
            Options.KnifeSkin:SetValues(GameData.SkinData[Value])
			local savedSkin = Options['Conf_' .. Value].Value
            Options.KnifeSkin:SetValue(savedSkin)
        else
            Options.KnifeSkin:SetValues({})
        end
    end 
})

KnifeGroup:AddDropdown('KnifeSkin', {
    Values = {},
    Default = 1,
    Multi = false,
    Text = 'Knife Skin',
    Callback = function(Value)
        local currentKnife = Options.KnifeSelect.Value
        if currentKnife and Value then
            if Options['Conf_' .. currentKnife] then
                Options['Conf_' .. currentKnife]:SetValue(Value)
            end
        end
    end
})

GloveGroup:AddToggle('EnableGloves', { Text = 'Enable Glove Changer', Default = false })

GloveGroup:AddDropdown('GloveType', { 
    Values = GameData.GloveTypes, 
    Default = 1, 
    Multi = false, 
    Text = 'Glove Type', 
    Callback = function(Value) 
        if Value and GameData.GloveData[Value] then 
            Options.GloveSkin:SetValues(GameData.GloveData[Value])
            local savedSkin = Options['Conf_Glove_' .. Value].Value
            Options.GloveSkin:SetValue(savedSkin)
        else 
            Options.GloveSkin:SetValues({}) 
        end 
    end 
})

GloveGroup:AddDropdown('GloveSkin', { 
    Values = {}, 
    Default = 1, 
    Multi = false, 
    Text = 'Glove Skin',
    Callback = function(Value)
        local currentType = Options.GloveType.Value
        if currentType and Value then
            if Options['Conf_Glove_' .. currentType] then
                Options['Conf_Glove_' .. currentType]:SetValue(Value)
            end
        end
    end
})

StatTrakGroup:AddToggle('GlobalStatTrak', {
    Text = 'StatTrak',
    Default = false,
    Tooltip = 'Enables StatTrak if the weapon supports it'
}):AddColorPicker('GlobalStatColor', {
    Default = Color3.fromRGB(255, 150, 0),
    Title = 'StatTrak Text Color',
})

StatTrakGroup:AddInput('GlobalStatCount', {
    Default = '1337',
    Numeric = true,
    Finished = false,
    Text = 'stattrak',
    Placeholder = '0',
})

local LastSkinUpdate = 0
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Library.Unloaded then return end
    local now = tick()
    if now - LastSkinUpdate < 0.1 then return end
    LastSkinUpdate = now
    UpdateSkins()
end))

-- [[ MISC TAB ]]
local MiscLeft = Tabs.Misc:AddLeftGroupbox('Spectators')
local MiscRight = Tabs.Misc:AddRightGroupbox('Movement')

MiscLeft:AddToggle('SpectatorList', { Text = 'Show Spectators', Default = Config.Misc.Spectators.Enabled, Callback = function(v) Config.Misc.Spectators.Enabled = v end })
MiscRight:AddLabel('Pixel Surf'):AddKeyPicker('PixelSurfKey', { Default = 'V', Text = 'Pixel Surf', Mode = 'Hold' })
MiscRight:AddToggle('BhopEnabled', { Text = 'Bunny Hop', Default = Config.Misc.Bhop, Callback = function(v) Config.Misc.Bhop = v end })
MiscRight:AddToggle('InfJumpEnabled', { Text = 'Infinite Jump', Default = Config.Misc.InfJump, Callback = function(v) Config.Misc.InfJump = v end })
MiscRight:AddDivider()
local SpeedToggle = MiscRight:AddToggle('CFrameSpeed', { Text = 'CFrame Speed (WASD)', Default = Config.Misc.CFrameSpeed.Enabled, Callback = function(v) Config.Misc.CFrameSpeed.Enabled = v end })
local SpeedDep = MiscRight:AddDependencyBox()
SpeedDep:AddSlider('CFrameSpeedVal', { Text = 'Speed Factor', Default = Config.Misc.CFrameSpeed.Value, Min = 0.1, Max = 5, Rounding = 1, Callback = function(v) Config.Misc.CFrameSpeed.Value = v end })
SpeedDep:SetupDependencies({ { SpeedToggle, true } })
MiscRight:AddToggle('FreezeMove', { Text = 'Move Before Timer', Default = Config.Misc.FreezeMove, Callback = function(v) Config.Misc.FreezeMove = v end })
MiscRight:AddDivider()
MiscRight:AddButton({ Text = 'Server Hop', Func = function()
    if HopServer then
        task.spawn(HopServer)
    end
end })

local HitboxMap = { 
    Head = {"HeadHB", "Head"}, 
    Chest = {"UpperTorso", "Torso"},
    Stomach = {"LowerTorso"},
    Pelvis = {"HumanoidRootPart"},
    Arms = {"LeftUpperArm", "RightUpperArm", "LeftArm", "RightArm"}, 
    Legs = {"LeftUpperLeg", "RightUpperLeg", "LeftLeg", "RightLeg"}, 
    Feet = {"LeftFoot", "RightFoot"} 
}

local SharedRaycastParams = RaycastParams.new()
SharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
SharedRaycastParams.IgnoreWater = true
local VisibilityIgnoreList = {}

local function IsVisible(targetPart, ignoreList)
    local cam = RefreshCamera()
    if not cam or not targetPart or not targetPart.Parent then return false end

    local origin = cam.CFrame.Position
    local direction = targetPart.Position - origin
    if not ignoreList then
        local localChar = LocalPlayer.Character
        if localChar then
            VisibilityIgnoreList[1] = localChar
            VisibilityIgnoreList[2] = cam
            VisibilityIgnoreList[3] = nil
        else
            VisibilityIgnoreList[1] = cam
            VisibilityIgnoreList[2] = nil
        end
        ignoreList = VisibilityIgnoreList
    end
    SharedRaycastParams.FilterDescendantsInstances = ignoreList
    local result = Workspace:Raycast(origin, direction, SharedRaycastParams)
    return not result or result.Instance:IsDescendantOf(targetPart.Parent)
end

local PriorityOrder = { "Head", "Chest", "Stomach", "Pelvis", "Arms", "Legs", "Feet" }
local DefaultHitboxes = { "Head" }
local HitboxLookupCache = setmetatable({}, { __mode = "k" })

local function GetHitboxLookup(hitboxes)
    local lookup = HitboxLookupCache[hitboxes]
    if lookup then return lookup end

    lookup = {}
    for _, h in ipairs(hitboxes) do
        lookup[h] = true
    end
    HitboxLookupCache[hitboxes] = lookup
    return lookup
end

local function IsTargetPartValid(targetPart)
    if not targetPart or not targetPart.Parent then return false end

    local character = targetPart.Parent
    local hum = character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function GetTargetPart(character, hitboxes, wallcheck)
    if not character then return nil end
    if type(hitboxes) ~= "table" or #hitboxes == 0 then
        hitboxes = DefaultHitboxes
    end

    local activeHitboxes = GetHitboxLookup(hitboxes)
    for _, category in ipairs(PriorityOrder) do
        if activeHitboxes[category] then
            local partNames = HitboxMap[category]
            if partNames then
                for _, partName in ipairs(partNames) do
                    local part = character:FindFirstChild(partName)
                    if part then
                        if wallcheck then
                            if IsVisible(part) then return part end
                        else
                            return part
                        end
                    end
                end
            end
        end
    end
    return nil
end

local LocalChamsCleanedUp = false

local function CleanLocalChamsOnce()
    if LocalChamsCleanedUp then return end
    if not LocalPlayer.Character then return end
    LocalChamsCleanedUp = true
    for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
        if v:IsA("Decal") and v.Name == "face" then
            v.Transparency = 1
        end
        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
            v:Destroy()
        end
        if v:IsA("MeshPart") then v.TextureID = "" end
        if v:IsA("SpecialMesh") then v.TextureId = "" end
    end
end

function UpdateLocalChams()
    if not LocalPlayer.Character then return end
    if not Config.Visuals.LocalChams.Enabled then return end

    CleanLocalChamsOnce()

    for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            v.Color = Config.Visuals.LocalChams.Color
            v.Transparency = Config.Visuals.LocalChams.Transparency
            v.Material = Enum.Material[Config.Visuals.LocalChams.Material]
        end
    end
end

TrackConnection(LocalPlayer.CharacterAdded:Connect(function(char)
    LocalChamsCleanedUp = false
    task.wait(0.1)
    UpdateLocalChams()
    TrackConnection(char.ChildAdded:Connect(function() task.wait(0.1); UpdateLocalChams() end))
end))

function UpdateViewmodelChams()
    local cam = RefreshCamera()
    if not cam then return end

    local armsModel = cam:FindFirstChild("Arms")
    if not armsModel then return end
    local IgnoreNames = {
        ["HumanoidRootPart"] = true, 
        ["Flash"] = true, 
        ["Joint"] = true, 
        ["Dot"] = true,
        ["Camera"] = true, 
        ["SightMark"] = true, 
        ["notex"] = true, 
    }

    local ConditionalRules = {
        {
            Triggers = {"Silencer"},
            Ignore   = {"FlashS", "Handle", "Silencer", "Slide", "Mag"}
        },
        {
            Triggers = {"Bolt2", "notex", "Joint", "Lever"},
            Ignore   = {"Handle", "Mag", "Lever", "Bolt"}
        }
    }
    local DynamicIgnore = {}
    
    for _, rule in ipairs(ConditionalRules) do
        local foundAll = true
        for _, triggerName in ipairs(rule.Triggers) do
            if not armsModel:FindFirstChild(triggerName, true) then
                foundAll = false
                break
            end
        end

        if foundAll then
            for _, ignoreName in ipairs(rule.Ignore) do
                DynamicIgnore[ignoreName] = true
            end
        end
    end

    -- 4. Основной цикл покраски
    for _, v in pairs(armsModel:GetDescendants()) do
        if v:IsA("BasePart") then
            if IgnoreNames[v.Name] or DynamicIgnore[v.Name] then 
                continue 
            end

            if v.Name == "Right Arm" or v.Name == "Left Arm" then
                if Config.Visuals.Viewmodel.Arms.Enabled then
                    v.Color = Config.Visuals.Viewmodel.Arms.Color
                    v.Transparency = Config.Visuals.Viewmodel.Arms.Transparency
                    v.Material = Enum.Material[Config.Visuals.Viewmodel.Arms.Material]
                end
            else
                if v:FindFirstAncestor("Right Arm") or v:FindFirstAncestor("Left Arm") then continue end
                
                if Config.Visuals.Viewmodel.Weapon.Enabled then
                    for _, child in pairs(v:GetChildren()) do 
                        if child:IsA("SurfaceAppearance") then child:Destroy() end 
                    end
                    
                    
                    local wType = Config.Visuals.Viewmodel.Weapon.Type or "Static"
                    local finalColor = Config.Visuals.Viewmodel.Weapon.Color
                    local finalTrans = Config.Visuals.Viewmodel.Weapon.Transparency

                    if wType == "Rainbow" then
                        local hue = (tick() % 5) / 5
                        finalColor = Color3.fromHSV(hue, 1, 1)
                    elseif wType == "Pulse" then
                        local pulse = (math.sin(tick() * 5) + 1) / 2 -- 0 to 1
                        -- Pulse transparency between Base and (Base + 0.5 clamped to 1)
                        finalTrans = finalTrans + (pulse * 0.5)
                        if finalTrans < 0.1 then finalTrans = 0.1 end
                        if finalTrans > 1 then finalTrans = 1 end
                    end

                    v.Color = finalColor
                    v.Transparency = finalTrans
                    v.Material = Enum.Material[Config.Visuals.Viewmodel.Weapon.Material]
                    v.Reflectance = Config.Visuals.Viewmodel.Weapon.Reflectance
                    
                    if v:IsA("MeshPart") and v.TextureID ~= "" then v.TextureID = "" end
                    
                    local hm = v:FindFirstChildOfClass("SpecialMesh")
                    if hm then
                        if hm.TextureId ~= "" then hm.TextureId = "" end
                        local nc = Vector3.new(Config.Visuals.Viewmodel.Weapon.Color.R, Config.Visuals.Viewmodel.Weapon.Color.G, Config.Visuals.Viewmodel.Weapon.Color.B)
                        if hm.VertexColor ~= nc then hm.VertexColor = nc end
                    end
                end
            end
        end
    end
end

if Camera then
    TrackConnection(Camera.ChildAdded:Connect(function(child)
        if child.Name == "Arms" then
            task.wait(0.01)
            UpdateViewmodelChams()
            TrackConnection(child.DescendantAdded:Connect(function() task.delay(0.01, UpdateViewmodelChams) end))
        end
    end))
end

-- [ HOOKS ]
local CurrentSilentTarget = nil
local CurrentAimTarget = nil
local SilentAimHookActive = false
local LastSilentTargetScan = 0
local SilentTargetScanInterval = 0.05
GlobalState.CurrentSilentTarget = nil
GlobalState.SilentAimHookActive = false
local AimTargetHighlight = Instance.new("Highlight")
AimTargetHighlight.Name = "AimTargetIndicator"
AimTargetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
AimTargetHighlight.FillColor = Color3.fromRGB(255, 255, 0)
AimTargetHighlight.FillTransparency = 0.7
AimTargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 0)
AimTargetHighlight.OutlineTransparency = 0
AimTargetHighlight.Enabled = false
local TriggerDebounce = false

local OldNC, OriginalIndex
local ok_mt, MT = false, nil
if getrawmetatable then
    ok_mt, MT = pcall(getrawmetatable, game)
end

if ok_mt and MT and setreadonly and newcclosure and getnamecallmethod and checkcaller then
    setreadonly(MT, false)
    local currentNamecall = MT.__namecall
    OldNC = GlobalState.OriginalNamecall or GetNamedUpvalue(currentNamecall, "OldNC") or currentNamecall
    if OldNC == GlobalState.NamecallHook and GlobalState.OriginalNamecall then
        OldNC = GlobalState.OriginalNamecall
    end
    OriginalIndex = GlobalState.OriginalIndex or GetNamedUpvalue(MT.__index, "OldIDX") or MT.__index
    GlobalState.OriginalNamecall = OldNC
    GlobalState.OriginalIndex = OriginalIndex
    MT.__index = OriginalIndex
    
    MT.__namecall = newcclosure(function(self, ...)
        if Library.Unloaded then return OldNC(self, ...) end

        local method = getnamecallmethod()

        if method == "PivotTo" and self.Name == "Arms" then
            local args = {...}
            if Config.Visuals.ThirdPerson.Enabled then
                return OldNC(self, CFrame.new(0, -10000, 0))
            end
            if Config.Visuals.Viewmodel.Pos.Enabled then
                local cf = args[1]
                if typeof(cf) ~= "CFrame" then
                    return OldNC(self, ...)
                end
                if Config.Visuals.Viewmodel.Pos.DisableSway then
                    local cam = RefreshCamera()
                    if cam then
                        cf = cam.CFrame
                    end
                end
                cf = cf * CFrame.new(Config.Visuals.Viewmodel.Pos.X, Config.Visuals.Viewmodel.Pos.Y, Config.Visuals.Viewmodel.Pos.Z)
                return OldNC(self, cf)
            end
            return OldNC(self, ...)
        end

        if (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and not checkcaller() then
            local target = GlobalState.CurrentSilentTarget
            if GlobalState.SilentAimHookActive and target and target.Parent then
                local args = {...}
                local ray = args[1]
                if ray and ray.Origin then
                    local delta = target.Position - ray.Origin
                    if delta.Magnitude > 0 then
                        args[1] = Ray.new(ray.Origin, delta.Unit * 10000)
                        return OldNC(self, unpack(args))
                    end
                end
            end
        end

        return OldNC(self, ...)
    end)
    GlobalState.NamecallHook = MT.__namecall
    setreadonly(MT, true)
end

local FOVCircleOutline = Drawing.new("Circle"); FOVCircleOutline.Thickness = 2; FOVCircleOutline.NumSides = 64; FOVCircleOutline.Filled = false; FOVCircleOutline.Transparency = 1
local FOVCircleFill = Drawing.new("Circle"); FOVCircleFill.NumSides = 64; FOVCircleFill.Filled = true; FOVCircleFill.Thickness = 1
local SilentFOVCircle = Drawing.new("Circle"); SilentFOVCircle.Thickness = 2; SilentFOVCircle.NumSides = 64; SilentFOVCircle.Filled = false; SilentFOVCircle.Transparency = 1
local SpectatorText = Drawing.new("Text"); SpectatorText.Size = 18; SpectatorText.Position = Vector2.new(Config.Misc.Spectators.X, Config.Misc.Spectators.Y); SpectatorText.Color = Color3.new(1, 1, 1); SpectatorText.Outline = true; SpectatorText.Visible = false
local CrosshairLeft = Drawing.new("Line"); local CrosshairRight = Drawing.new("Line"); local CrosshairTop = Drawing.new("Line"); local CrosshairBottom = Drawing.new("Line")

local function UpdateCrosshair()
    local cam = RefreshCamera()
    if not cam then return end

    local center = cam.ViewportSize / 2
    local size = Config.Visuals.Crosshair.Size
    local gap = Config.Visuals.Crosshair.Gap
    local thick = Config.Visuals.Crosshair.Thickness
    local color = Config.Visuals.Crosshair.Color
    if Config.Visuals.Crosshair.Enabled then
        CrosshairLeft.Visible = true; CrosshairLeft.Color = color; CrosshairLeft.Thickness = thick; CrosshairLeft.From = Vector2.new(center.X - gap - size, center.Y); CrosshairLeft.To = Vector2.new(center.X - gap, center.Y)
        CrosshairRight.Visible = true; CrosshairRight.Color = color; CrosshairRight.Thickness = thick; CrosshairRight.From = Vector2.new(center.X + gap + size, center.Y); CrosshairRight.To = Vector2.new(center.X + gap, center.Y)
        CrosshairTop.Visible = true; CrosshairTop.Color = color; CrosshairTop.Thickness = thick; CrosshairTop.From = Vector2.new(center.X, center.Y - gap - size); CrosshairTop.To = Vector2.new(center.X, center.Y - gap)
        CrosshairBottom.Visible = true; CrosshairBottom.Color = color; CrosshairBottom.Thickness = thick; CrosshairBottom.From = Vector2.new(center.X, center.Y + gap + size); CrosshairBottom.To = Vector2.new(center.X, center.Y + gap)
    else
        CrosshairLeft.Visible = false; CrosshairRight.Visible = false; CrosshairTop.Visible = false; CrosshairBottom.Visible = false
    end
end

local ESP_Cache = {}
local function CreateDrawing(type, properties) local drawing = Drawing.new(type); for k, v in pairs(properties) do drawing[k] = v end; return drawing end
local function CreateHighlight() local h = Instance.new("Highlight"); h.Name = "ArchitectChams"; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Enabled = false; return h end
local function AddESP(player) 
    if ESP_Cache[player] then return end; 
    ESP_Cache[player] = { 
        BoxOutline = CreateDrawing("Square", {Visible=false, Thickness=3, Filled=false, Color=Color3.new(0,0,0)}), 
        Box = CreateDrawing("Square", {Visible=false, Thickness=1, Filled=false}), 
        Name = CreateDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true, Font=2}), 
        HealthBarOutline = CreateDrawing("Square", {Visible=false, Thickness=1, Filled=true, Color=Color3.new(0,0,0)}), 
        HealthBar = CreateDrawing("Square", {Visible=false, Thickness=1, Filled=true}), 
        HealthText = CreateDrawing("Text", {Visible=false, Size=10, Center=true, Outline=true, Font=2, Color=Color3.new(1,1,1)}), 
        Distance = CreateDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true, Font=2}), 
        Weapon = CreateDrawing("Text", {Visible=false, Size=13, Center=true, Outline=true, Font=2}), 
        Highlight = CreateHighlight(), 
        Arrow = CreateDrawing("Triangle", {Visible=false, Thickness=1, Filled=true})
    } 
end
local function RemoveESP(player) 
    if ESP_Cache[player] then 
        for k, obj in pairs(ESP_Cache[player]) do 
            if k == "Highlight" then 
                if obj then obj:Destroy() end 
            else 
                pcall(function() obj:Remove() end)
            end 
        end; 
        ESP_Cache[player] = nil 
    end 
end
local function GetWeaponName(player, character) local e = player:FindFirstChild("EquippedTool"); if e then return tostring(e.Value) end; if character then e = character:FindFirstChild("EquippedTool"); if e then return tostring(e.Value) end end; return "None" end
for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer then AddESP(player) end end
TrackConnection(Players.PlayerAdded:Connect(function(player) if player ~= LocalPlayer then AddESP(player) end end))
TrackConnection(Players.PlayerRemoving:Connect(RemoveESP))

TrackConnection(UserInputService.JumpRequest:Connect(function() if Config.Misc.InfJump and LocalPlayer.Character then local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end))
table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
    if Config.Misc.CFrameSpeed.Enabled and LocalPlayer.Character then
        local r = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local d = Vector3.new(0,0,0)
            local cam = RefreshCamera()
            if not cam then return end
            local c = cam.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + c.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - c.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + c.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - c.RightVector end
            
            if d.Magnitude > 0 then
                d = Vector3.new(d.X, 0, d.Z).Unit
                local s = Config.Misc.CFrameSpeed.Value * 50
                local startPos = r.Position
                local n = startPos + (d * s * dt)
                r.CFrame = CFrame.new(n) * r.CFrame.Rotation
                r.Velocity = Vector3.new(0, r.Velocity.Y, 0)
            end
        end
    end
end))
table.insert(Connections, RunService.Stepped:Connect(function() if Config.Misc.FreezeMove and LocalPlayer.Character then local r = LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if r and r.Anchored then r.Anchored = false end end end))

task.spawn(function()
    while task.wait(0.01) do
        if Library.Unloaded or not Config then break end
        
        -- Безопасная проверка наличия настроек и бинда
        if Config.Legitbot.Triggerbot.Enabled and GetOptionState("TriggerKey") then
            local mouseTarget = Mouse.Target
            
            if mouseTarget and mouseTarget.Parent then
                local targetCharacter = mouseTarget:FindFirstAncestorOfClass("Model")
                local player = targetCharacter and Players:GetPlayerFromCharacter(targetCharacter)
                
                if player and player ~= LocalPlayer then
                    -- Проверка команды
                    if not Config.Legitbot.Triggerbot.TeamCheck or player.Team ~= LocalPlayer.Team then
                        local hitName = mouseTarget.Name
                        local isValidHitbox = false
                        
                        -- Проверка хитбоксов (развернул цикл для надежности)
                        if Config.Legitbot.Triggerbot.Hitboxes then
                            for _, hb in ipairs(Config.Legitbot.Triggerbot.Hitboxes) do
                                local parts = HitboxMap[hb]
                                if parts then 
                                    for _, p in ipairs(parts) do 
                                        if p == hitName then 
                                            isValidHitbox = true 
                                            break 
                                        end 
                                    end 
                                end
                                if isValidHitbox then break end
                            end
                        end

                        if isValidHitbox and not TriggerDebounce then
                            TriggerDebounce = true
                            if Config.Legitbot.Triggerbot.Delay > 0 then 
                                task.wait(Config.Legitbot.Triggerbot.Delay / 1000) 
                            end
                            
                            -- Безопасный вызов клика
                            SafeMouseClick()
                            
                            TriggerDebounce = false
                        end
                    end
                end
            end
        end
    end
end) 

local OldCFrame = nil

pcall(function()
    table.insert(Connections, RunService.PreSimulation:Connect(function()
        if Library.Unloaded then return end
        if OldCFrame and Config.Visuals.World.AspectRatio.Enabled then
            local cam = RefreshCamera()
            if cam then
                cam.CFrame = OldCFrame
            end
            OldCFrame = nil
        end
    end))
end)

RunService:BindToRenderStep("AspectRatioFix", Enum.RenderPriority.Camera.Value + 100, function()
    if Library.Unloaded then return end
    if Config.Visuals.World.AspectRatio.Enabled then
        local cam = RefreshCamera()
        if not cam then return end
        OldCFrame = cam.CFrame 
        local ratio = Config.Visuals.World.AspectRatio.Value
        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, ratio, 0, 0, 0, 1)
    else
        OldCFrame = nil
    end
end)

local LastLocalChamsUpdate = 0
local RenderConnection = RunService.RenderStepped:Connect(function()
    if Library.Unloaded or not Config then return end
    local cam = RefreshCamera()
    if not cam then return end

    local renderNow = tick()
    if Config.Visuals.LocalChams.Enabled and renderNow - LastLocalChamsUpdate >= 0.15 then
        LastLocalChamsUpdate = renderNow
        UpdateLocalChams()
    end
    if Config.Visuals.Viewmodel.Weapon.Enabled and Config.Visuals.Viewmodel.Weapon.Type ~= "Static" then
        UpdateViewmodelChams()
    end
    local centerScreen = cam.ViewportSize / 2
    local localChar = LocalPlayer.Character
    local localHum = localChar and localChar:FindFirstChild("Humanoid")
    local isLocalAlive = localHum and localHum.Health > 0
    if isLocalAlive and Config.Misc.Bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and localHum.FloorMaterial ~= Enum.Material.Air then 
        localHum:ChangeState(Enum.HumanoidStateType.Jumping) 
    end
    UpdateCrosshair()
    
    if Config.Misc.Spectators.Enabled then
        local s = {}
        for _, p in ipairs(Players:GetPlayers()) do 
            if p ~= LocalPlayer then 
                local c = p:FindFirstChild("CameraCF")
                if c and (c.Value.Position - cam.CFrame.Position).Magnitude < 20 then 
                    -- Проверяем, мертв ли игрок (если жив, это просто тиммейт рядом)
                    if not p.Character or not p.Character:FindFirstChild("Humanoid") or p.Character.Humanoid.Health <= 0 then
                        table.insert(s, p.Name) 
                    end
                end 
            end 
        end
        if #s > 0 then SpectatorText.Text = "Spectators:\n" .. table.concat(s, "\n"); SpectatorText.Visible = true else SpectatorText.Visible = false end
    else SpectatorText.Visible = false end

    if Config.Legitbot.Aimbot.ShowFOV then 
        FOVCircleOutline.Position = centerScreen; FOVCircleOutline.Radius = Config.Legitbot.Aimbot.FOV; FOVCircleOutline.Color = Config.Legitbot.Aimbot.FOVColor; FOVCircleOutline.Transparency = Config.Legitbot.Aimbot.FOVTransparency; FOVCircleOutline.Visible = true
        FOVCircleFill.Position = centerScreen; FOVCircleFill.Radius = Config.Legitbot.Aimbot.FOV; FOVCircleFill.Color = Config.Legitbot.Aimbot.FOVFillColor; FOVCircleFill.Transparency = Config.Legitbot.Aimbot.FOVFillTransparency; FOVCircleFill.Visible = true 
    else FOVCircleOutline.Visible = false; FOVCircleFill.Visible = false end
    
    if Config.Legitbot.SilentAim.ShowFOV then 
        SilentFOVCircle.Position = centerScreen; SilentFOVCircle.Radius = Config.Legitbot.SilentAim.FOV; SilentFOVCircle.Color = Config.Legitbot.SilentAim.FOVColor; SilentFOVCircle.Transparency = Config.Legitbot.SilentAim.FOVTransparency; SilentFOVCircle.Visible = true 
    else SilentFOVCircle.Visible = false end

    CurrentAimTarget = nil
    local AimKeyActive = GetOptionState("AimKey")
    local SilentKeyActive = GetOptionState("SilentKey")
    SilentAimHookActive = Config.Legitbot.SilentAim.Enabled and (SilentKeyActive or Config.Legitbot.SilentAim.AutoFire)
    GlobalState.SilentAimHookActive = SilentAimHookActive

    if not SilentAimHookActive or not isLocalAlive or not IsTargetPartValid(CurrentSilentTarget) then
        CurrentSilentTarget = nil
        GlobalState.CurrentSilentTarget = nil
    end

    local shouldScanAim = isLocalAlive and Config.Legitbot.Aimbot.Enabled and AimKeyActive
    local shouldScanSilent = isLocalAlive and SilentAimHookActive and (renderNow - LastSilentTargetScan >= SilentTargetScanInterval or not CurrentSilentTarget)

    local shouldScanTargets = shouldScanAim or shouldScanSilent

    if shouldScanTargets then
        local BestAimTarget = nil
        local BestSilentTarget = nil
        local BestAimDist = Config.Legitbot.Aimbot.FOV
        local BestSilentDist = Config.Legitbot.SilentAim.FOV

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                local rootPart = p.Character.HumanoidRootPart
                local dist = (rootPart.Position - cam.CFrame.Position).Magnitude
                if dist < 0.1 then continue end
                if dist > 10000 then continue end 
                local cameraDir = cam.CFrame.LookVector
                local toPlayer = (rootPart.Position - cam.CFrame.Position).Unit
                local dot = cameraDir:Dot(toPlayer)
                if dot < 0.2 and not Config.Legitbot.Aimbot.ShowFOV then continue end 

                local isTeammate = (p.Team == LocalPlayer.Team)
                local pos, onScreen = cam:WorldToViewportPoint(rootPart.Position)
                
                if onScreen then
                    local distToCenter = (Vector2.new(pos.X, pos.Y) - centerScreen).Magnitude
                    if shouldScanAim then
                        if not (Config.Legitbot.Aimbot.TeamCheck and isTeammate) then
                            if distToCenter < BestAimDist then
                                local t = GetTargetPart(p.Character, Config.Legitbot.Aimbot.Hitboxes, Config.Legitbot.Aimbot.WallCheck)
                                if t then BestAimTarget = t; BestAimDist = distToCenter end
                            end
                        end
                    end
                    if shouldScanSilent then
                        if not (Config.Legitbot.SilentAim.TeamCheck and isTeammate) then
                            if distToCenter < BestSilentDist then
                                local t = GetTargetPart(p.Character, Config.Legitbot.SilentAim.Hitboxes, Config.Legitbot.SilentAim.WallCheck)
                                if t then BestSilentTarget = t; BestSilentDist = distToCenter end
                            end
                        end
                    end
                end
            end
        end

        if BestAimTarget then
            CurrentAimTarget = BestAimTarget
            cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, BestAimTarget.Position), 1/Config.Legitbot.Aimbot.Smoothness)
        end

        if BestSilentTarget then
            CurrentSilentTarget = BestSilentTarget
            GlobalState.CurrentSilentTarget = BestSilentTarget
            if Config.Legitbot.SilentAim.AutoFire and not TriggerDebounce then
                TriggerDebounce = true
                task.spawn(function()
                    pcall(SafeMouseClick)
                    TriggerDebounce = false
                end)
            end
        elseif shouldScanSilent then
            CurrentSilentTarget = nil
            GlobalState.CurrentSilentTarget = nil
        end

        if shouldScanSilent then
            LastSilentTargetScan = renderNow
        end
    end

    -- Aim Target Indicator
    local indicatorTarget = CurrentAimTarget or CurrentSilentTarget
    if indicatorTarget and indicatorTarget.Parent and GetToggleValue("AimIndicator") then
        if AimTargetHighlight.Parent ~= indicatorTarget.Parent then
            AimTargetHighlight.Parent = indicatorTarget.Parent
        end
        local indicatorColor = GetOptionValue("AimIndicatorColor", Color3.fromRGB(255, 255, 0))
        AimTargetHighlight.FillColor = indicatorColor
        AimTargetHighlight.OutlineColor = indicatorColor
        AimTargetHighlight.Enabled = true
    else
        AimTargetHighlight.Enabled = false
    end

    if Config.Visuals.World.FOV.Enabled then cam.FieldOfView = Config.Visuals.World.FOV.Value end
    if Config.Visuals.World.Time.Enabled then Lighting.ClockTime = Config.Visuals.World.Time.Value end
    if Config.Visuals.World.Ambience.Enabled then
        Lighting.Ambient = Config.Visuals.World.Ambience.Indoor
        Lighting.OutdoorAmbient = Config.Visuals.World.Ambience.Outdoor
    end

    for player, drawings in pairs(ESP_Cache) do
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local isTeam = player.Team == LocalPlayer.Team
        local set = isTeam and Config.Visuals.ESP.Teammates or Config.Visuals.ESP.Enemies

        if char and hum and root and hum.Health > 0 and set.Enabled then
            local pos, onScreen = cam:WorldToViewportPoint(root.Position)
            if set.Offscreen and not onScreen then
                local rel = cam.CFrame:PointToObjectSpace(root.Position)
                local ang = math.atan2(-rel.Y, rel.X)
                local rad, sz = set.OffscreenRadius, set.OffscreenSize
                local arrowPos = centerScreen + Vector2.new(math.cos(ang)*rad, math.sin(ang)*rad)
                local function rot(p, c, a) local s, co = math.sin(a), math.cos(a); local px, py = p.X-c.X, p.Y-c.Y; return Vector2.new(px*co - py*s + c.X, px*s + py*co + c.Y) end
                drawings.Arrow.PointA = rot(arrowPos + Vector2.new(sz, 0), arrowPos, ang)
                drawings.Arrow.PointB = rot(arrowPos + Vector2.new(-sz/2, -sz/2), arrowPos, ang)
                drawings.Arrow.PointC = rot(arrowPos + Vector2.new(-sz/2, sz/2), arrowPos, ang)
                drawings.Arrow.Color = set.OffscreenColor; drawings.Arrow.Visible = true
            else drawings.Arrow.Visible = false end

            if set.Chams then
                if not drawings.Highlight then drawings.Highlight = CreateHighlight() end
                if drawings.Highlight.Parent ~= char then drawings.Highlight.Parent = char end
                drawings.Highlight.FillColor = set.ChamsFillColor; drawings.Highlight.OutlineColor = set.ChamsOutlineColor; drawings.Highlight.FillTransparency = set.ChamsFillTransparency; drawings.Highlight.OutlineTransparency = set.ChamsOutlineTransparency; drawings.Highlight.Enabled = true
            else if drawings.Highlight then drawings.Highlight.Enabled = false end end

            if onScreen then
                local dist = (cam.CFrame.Position - root.Position).Magnitude
                local scale = 1 / (dist * math.tan(math.rad(cam.FieldOfView * 0.5)) * 2) * 1000
                local w, h = 4 * scale, 6 * scale
                local boxPos = Vector2.new(pos.X - w/2, pos.Y - h/2)
                
                if set.Boxes then drawings.BoxOutline.Size = Vector2.new(w, h); drawings.BoxOutline.Position = boxPos; drawings.BoxOutline.Visible = true; drawings.Box.Size = Vector2.new(w, h); drawings.Box.Position = boxPos; drawings.Box.Color = set.BoxColor; drawings.Box.Visible = true else drawings.Box.Visible = false; drawings.BoxOutline.Visible = false end
                if set.Names then drawings.Name.Text = player.Name; drawings.Name.Position = Vector2.new(pos.X, boxPos.Y - 16); drawings.Name.Color = set.NameColor; drawings.Name.Visible = true else drawings.Name.Visible = false end
                if set.HealthBar then
                    local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barH = h * hp
                    drawings.HealthBarOutline.Size = Vector2.new(4, h); drawings.HealthBarOutline.Position = Vector2.new(boxPos.X - 6, boxPos.Y); drawings.HealthBarOutline.Visible = true
                    drawings.HealthBar.Size = Vector2.new(2, barH); drawings.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (h - barH)); drawings.HealthBar.Color = Color3.fromRGB(255 - (255 * hp), 255 * hp, 0); drawings.HealthBar.Visible = true
                    if set.HealthText then drawings.HealthText.Text = tostring(math.floor(hum.Health)); drawings.HealthText.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (h - barH) - 6); drawings.HealthText.Color = set.HealthTextColor; drawings.HealthText.Visible = true else drawings.HealthText.Visible = false end
                else drawings.HealthBar.Visible = false; drawings.HealthBarOutline.Visible = false; drawings.HealthText.Visible = false end
                local botOff = boxPos.Y + h + 2
                if set.Weapon then drawings.Weapon.Text = GetWeaponName(player, char); drawings.Weapon.Position = Vector2.new(pos.X, botOff); drawings.Weapon.Color = set.WeaponColor; drawings.Weapon.Visible = true; botOff = botOff + 14 else drawings.Weapon.Visible = false end
                if set.Distance then drawings.Distance.Text = string.format("[%d m]", math.floor(dist)); drawings.Distance.Position = Vector2.new(pos.X, botOff); drawings.Distance.Color = set.DistanceColor; drawings.Distance.Visible = true else drawings.Distance.Visible = false end
            else
                for k, d in pairs(drawings) do if k ~= "Highlight" and k ~= "Arrow" then d.Visible = false end end
            end
        else
            for k, d in pairs(drawings) do if k == "Highlight" then if d then d.Enabled = false end else d.Visible = false end end
        end
    end
    do
        local statCam = RefreshCamera()
        local armsContainer = statCam and statCam:FindFirstChild("Arms")
        if armsContainer then
            local statClock = armsContainer:FindFirstChild("StatClock")
            if statClock and statClock:IsA("BasePart") then
                local surfaceGui = statClock:FindFirstChild("SurfaceGui")
                local textLabel = surfaceGui and surfaceGui:FindFirstChild("TextLabel")
                if GetToggleValue("GlobalStatTrak") then
                    if surfaceGui and not surfaceGui.Enabled then surfaceGui.Enabled = true end
                    if textLabel then
                        local statCount = tostring(GetOptionValue("GlobalStatCount", "0"))
                        local statColor = GetOptionValue("GlobalStatColor", Color3.fromRGB(255, 150, 0))
                        if textLabel.Text ~= statCount then textLabel.Text = statCount end
                        if textLabel.TextColor3 ~= statColor then textLabel.TextColor3 = statColor end
                    end
                else
                    if statClock.Transparency ~= 1 then statClock.Transparency = 1 end
                    if surfaceGui and surfaceGui.Enabled then surfaceGui.Enabled = false end
                end
            end
        end
    end
    if Config.Visuals.ThirdPerson.Enabled then
        LocalPlayer.CameraMinZoomDistance = Config.Visuals.ThirdPerson.Distance
        LocalPlayer.CameraMaxZoomDistance = Config.Visuals.ThirdPerson.Distance
    end

end)
table.insert(Connections, RenderConnection)

local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddButton({ Text = 'Unload', Func = function() Library:Unload() end })
MenuGroup:AddLabel('Menu Keybind'):AddKeyPicker('MenuKeybind', { Default = 'Insert', NoUI = true, Text = 'Menu keybind' })
MenuGroup:AddToggle("KeybindMenuOpen", { Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(value) Library.KeybindFrame.Visible = value end})
Library.ToggleKeybind = Library.Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('vyno.tech')
SaveManager:SetFolder('vyno.tech/Main')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

task.delay(1, function()
    if Config.Skins.Knife and Config.Skins.Knife ~= "Default" then
        ApplyKnifeModel(Config.Skins.Knife)
        if Library.Options.KnifeSelect then
            Library.Options.KnifeSelect:SetValue(Config.Skins.Knife)
        end
    end
end)

function HopServer()
    local servers = {}
    local cursor = ""

    repeat
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local ok, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not ok or type(response) ~= "table" or type(response.data) ~= "table" then
            warn("vyno.tech: Failed to fetch server list")
            break
        end

        for _, server in ipairs(response.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                table.insert(servers, server.id)
            end
        end

        cursor = response.nextPageCursor
    until not cursor or #servers >= 10

    if #servers > 0 then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        end)
    else
        warn("No available servers found")
    end
end

local LogService = game:GetService("LogService")
table.insert(Connections, LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError and message:match("kicked") then
        local clearConn
        clearConn = RunService.Stepped:Connect(function()
            game:GetService("GuiService"):ClearError()
        end)
        table.insert(Connections, clearConn)
        task.delay(15, function()
            if clearConn then clearConn:Disconnect() end
        end)
        Library:Notify(message, nil, 4590657391)
        task.delay(10, function()
            HopServer()
        end)
    end
end))

table.insert(Connections, RunService.Stepped:Connect(function()
    if Library.Unloaded then return end
    if GetOptionState("PixelSurfKey") then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            local origin = root.Position
            local radius = 2.5
            local directions = {
                root.CFrame.RightVector,
                -root.CFrame.RightVector,
                (root.CFrame.LookVector + root.CFrame.RightVector).Unit,
                (root.CFrame.LookVector - root.CFrame.RightVector).Unit
            }
            
            local foundWall = false
            
            for _, dir in ipairs(directions) do
                local result = Workspace:Raycast(origin, dir * radius, SharedRaycastParams)
                if result then
                    foundWall = true
                    break
                end
            end
            if foundWall then
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
            end
        end
    end
end))

local function CleanupScript()
    if Library.Unloaded then return end
    print("vyno.tech: Unloading...")
    Library.Unloaded = true
    if ok_mt and MT and OldNC then
        setreadonly(MT, false)
        MT.__namecall = OldNC
        if OriginalIndex then
            MT.__index = OriginalIndex
        end
        setreadonly(MT, true)
    end
    for _, conn in ipairs(Connections) do
        if conn then conn:Disconnect() end
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.AutoRotate = true
    end
    local unloadCamera = RefreshCamera()
    if unloadCamera then
        unloadCamera.FieldOfView = OriginalFOV
    end
    Lighting.ClockTime = OriginalClockTime
    Lighting.Ambient = OriginalAmbient
    Lighting.OutdoorAmbient = OriginalOutdoorAmbient
    LocalPlayer.CameraMinZoomDistance = OriginalCameraMinZoom
    LocalPlayer.CameraMaxZoomDistance = OriginalCameraMaxZoom
    FOVCircleOutline:Remove(); FOVCircleFill:Remove(); SilentFOVCircle:Remove(); 
    SpectatorText:Remove(); CrosshairLeft:Remove(); CrosshairRight:Remove(); 
    CrosshairTop:Remove(); CrosshairBottom:Remove()
    if AimTargetHighlight then AimTargetHighlight:Destroy() end
    GlobalState.CurrentSilentTarget = nil
    GlobalState.SilentAimHookActive = false
    for _, player in ipairs(Players:GetPlayers()) do RemoveESP(player) end
    pcall(function() RunService:UnbindFromRenderStep("AspectRatioFix") end)
    if OldCFrame and unloadCamera then unloadCamera.CFrame = OldCFrame end
    getgenv().Config = nil
end

GlobalState.Cleanup = CleanupScript
Library:OnUnload(CleanupScript)

task.spawn(function()
    task.wait(1.5)
    if Options.PrimaryWeapon and Options.PrimarySkin and Options.PrimaryWeapon.Value and Options.PrimarySkin.Value then
        if GameData.SkinData[Options.PrimaryWeapon.Value] then
            Options.PrimarySkin:SetValues(GameData.SkinData[Options.PrimaryWeapon.Value])
        end
        ApplySkinToFolder(Options.PrimaryWeapon.Value, Options.PrimarySkin.Value)
    end
    if Options.SecondaryWeapon and Options.SecondarySkin and Options.SecondaryWeapon.Value and Options.SecondarySkin.Value then
        if GameData.SkinData[Options.SecondaryWeapon.Value] then
            Options.SecondarySkin:SetValues(GameData.SkinData[Options.SecondaryWeapon.Value])
        end
        ApplySkinToFolder(Options.SecondaryWeapon.Value, Options.SecondarySkin.Value)
    end
    if Options.KnifeSelect and Options.KnifeSelect.Value then
        ApplyKnifeModel(Options.KnifeSelect.Value)
        if Options.KnifeSkin and GameData.SkinData[Options.KnifeSelect.Value] then
            Options.KnifeSkin:SetValues(GameData.SkinData[Options.KnifeSelect.Value])
        end
    end
    if Options.GloveType and Options.GloveSkin and Options.GloveType.Value and Options.GloveSkin.Value then
        if GameData.GloveData[Options.GloveType.Value] then
            Options.GloveSkin:SetValues(GameData.GloveData[Options.GloveType.Value])
        end
    end
end)
