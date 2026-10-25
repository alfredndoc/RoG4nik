local RAW_BASE = "https://raw.githubusercontent.com/alfredndoc/RoG4nik/main/src"
local CORE_PATH = "Core.lua" 
local MODULE_DIRECTORY = "modules/"

-- Refuse to run a mixed or stale remote bundle. The local source package adds
-- these signatures when consolidating shared UI references and guarding the
-- composer TextBox event binding. Settings and message modules also need to match
-- the UIRefs-based Core so history and settings are not silently disconnected.
local REQUIRED_SIGNATURES = {
    ["Core.lua"] = {
        "local UIRefs = {}",
        'UIRefs.InputBar = create("Frame", {',
        'UIRefs.InputBox = create("TextBox", {',
    },
    ["modules/AIRequest.lua"] = {
        "local composerInputBox = UIRefs.InputBox",
        "AIRequest startup could not find the composer TextBox",
    },
    ["modules/SettingsView.lua"] = {
        "--// SETTINGS VIEW",
        "ProviderDropdownMenu",
    },
    ["modules/Messages.lua"] = {
        "UIRefs.CONVOS_FILE",
        "UIRefs.ChatDisplay",
    },
}
local FORBIDDEN_SIGNATURES = {
    -- These old locals were duplicated beside their UIRefs replacements in a
    -- published SettingsView.lua, leaving an unmatched closing brace at compile time.
    ["modules/SettingsView.lua"] = {
        "}, Content)",
        "}, MainFrame)",
        "0, 0, CHAT_TOP)",
    },
}

local MODULES = {
    "Themes.lua",
    "SystemPrompt.lua",
    "ThemeEngine.lua",
    "Sandbox.lua",
    "SettingsView.lua",
    "Markdown.lua",
    "Messages.lua",
    "AIRequest.lua",
}

--============================================================
--// THEMED LOADING SCREEN
-- Read the persisted theme before downloading or assembling the UI modules.
-- Keep these small palettes synchronized with src/modules/Themes.lua.
--============================================================
local Loader = { Completed = 0, Total = 1 + #MODULES }
local TweenService = game:GetService("TweenService")
local LoaderThemes = {
    Dark = { Background = {30,30,36}, Sidebar = {35,35,43}, Panel = {43,43,54}, Border = {67,67,81}, Accent = {78,111,255}, AccentSoft = {43,53,91}, Text = {245,245,250}, Muted = {164,164,179} },
    White = { Background = {248,248,250}, Sidebar = {240,240,244}, Panel = {254,254,255}, Border = {210,210,218}, Accent = {78,111,255}, AccentSoft = {224,232,255}, Text = {25,25,35}, Muted = {90,90,105} },
    Blue = { Background = {24,40,78}, Sidebar = {30,48,92}, Panel = {38,58,108}, Border = {60,88,155}, Accent = {120,168,255}, AccentSoft = {50,82,150}, Text = {235,242,255}, Muted = {160,180,220} },
    MidnightBlue = { Background = {12,16,32}, Sidebar = {16,22,44}, Panel = {20,28,54}, Border = {40,52,88}, Accent = {90,130,255}, AccentSoft = {32,46,92}, Text = {228,235,250}, Muted = {140,155,185} },
    Red = { Background = {28,18,22}, Sidebar = {38,22,28}, Panel = {49,27,34}, Border = {88,49,59}, Accent = {238,75,94}, AccentSoft = {91,38,51}, Text = {250,239,241}, Muted = {190,157,164} },
    CursorBlack = { Background = {8,9,11}, Sidebar = {12,13,16}, Panel = {19,20,24}, Border = {47,48,56}, Accent = {160,145,255}, AccentSoft = {45,40,72}, Text = {245,245,248}, Muted = {165,166,174} },
}
local function loaderColor(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
local function loaderCreate(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        pcall(function() instance[property] = value end)
    end
    instance.Parent = parent
    return instance
end
local function loaderTween(instance, duration, goals, style, direction)
    local animation = TweenService:Create(instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goals)
    animation:Play()
    return animation
end

local selectedTheme = "Dark"
local settingsReadOk, settingsRaw = pcall(function()
    if type(readfile) ~= "function" then return nil end
    return readfile("DeepSeekSettings.json")
end)
if settingsReadOk and type(settingsRaw) == "string" and settingsRaw ~= "" then
    pcall(function()
        local savedSettings = game:GetService("HttpService"):JSONDecode(settingsRaw)
        if type(savedSettings) == "table" and type(savedSettings.Theme) == "string"
            and LoaderThemes[savedSettings.Theme] then
            selectedTheme = savedSettings.Theme
        end
    end)
end
Loader.Theme = LoaderThemes[selectedTheme] or LoaderThemes.Dark
local localPlayer = game:GetService("Players").LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local oldLoader = playerGui:FindFirstChild("Dr4gonikLoader")
if oldLoader then oldLoader:Destroy() end
Loader.Gui = loaderCreate("ScreenGui", {
    Name = "Dr4gonikLoader", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, playerGui)
Loader.Window = loaderCreate("Frame", {
    Name = "LoadingWindow", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.82, 0, 0, 270),
    BackgroundColor3 = loaderColor(Loader.Theme.Background), BackgroundTransparency = 0.06,
    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1,
}, Loader.Gui)
loaderCreate("UISizeConstraint", { MinSize = Vector2.new(300, 250), MaxSize = Vector2.new(520, 270) }, Loader.Window)
loaderCreate("UICorner", { CornerRadius = UDim.new(0, 16) }, Loader.Window)
loaderCreate("UIStroke", { Color = loaderColor(Loader.Theme.Border), Transparency = 0.12, Thickness = 1 }, Loader.Window)
Loader.Scale = loaderCreate("UIScale", { Scale = 0.96 }, Loader.Window)

Loader.Header = loaderCreate("Frame", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = loaderColor(Loader.Theme.Sidebar), BorderSizePixel = 0, ZIndex = 2,
}, Loader.Window)
loaderCreate("Frame", {
    Name = "HeaderDivider", Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = loaderColor(Loader.Theme.Border), BackgroundTransparency = 0.35,
    BorderSizePixel = 0, ZIndex = 3,
}, Loader.Header)
Loader.LogoTile = loaderCreate("Frame", {
    Name = "LogoTile", Position = UDim2.new(0, 16, 0.5, -15), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = loaderColor(Loader.Theme.AccentSoft), BorderSizePixel = 0, ZIndex = 3,
}, Loader.Header)
loaderCreate("UICorner", { CornerRadius = UDim.new(0, 9) }, Loader.LogoTile)
Loader.LogoDiamond = loaderCreate("Frame", {
    Name = "LogoDiamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, BorderSizePixel = 0, Rotation = 45, ZIndex = 4,
}, Loader.LogoTile)
loaderCreate("UICorner", { CornerRadius = UDim.new(0, 2) }, Loader.LogoDiamond)
loaderCreate("UIStroke", { Color = loaderColor(Loader.Theme.Text), Thickness = 1.5, Transparency = 0 }, Loader.LogoDiamond)
loaderCreate("Frame", {
    Name = "LogoSlash", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0, 15, 0, 2), BackgroundColor3 = loaderColor(Loader.Theme.Text),
    BorderSizePixel = 0, Rotation = -45, ZIndex = 5,
}, Loader.LogoTile)
loaderCreate("TextLabel", {
    Name = "AppName", Position = UDim2.new(0, 56, 0, 0), Size = UDim2.new(0, 180, 1, 0),
    BackgroundTransparency = 1, Text = "Dr4gonik Hub", TextColor3 = loaderColor(Loader.Theme.Text),
    Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, Loader.Header)
Loader.Badge = loaderCreate("TextLabel", {
    Name = "LoaderBadge", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
    Size = UDim2.fromOffset(74, 24), BackgroundColor3 = loaderColor(Loader.Theme.Panel),
    Text = "LOADER", TextColor3 = loaderColor(Loader.Theme.Muted), Font = Enum.Font.GothamBold,
    TextSize = 9, BorderSizePixel = 0, ZIndex = 3,
}, Loader.Header)
loaderCreate("UICorner", { CornerRadius = UDim.new(0, 8) }, Loader.Badge)

Loader.Headline = loaderCreate("TextLabel", {
    Name = "Headline", Position = UDim2.new(0, 24, 0, 78), Size = UDim2.new(1, -48, 0, 24),
    BackgroundTransparency = 1, Text = "Loading RoG4nik", TextColor3 = loaderColor(Loader.Theme.Text),
    Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
}, Loader.Window)
Loader.Detail = loaderCreate("TextLabel", {
    Name = "Detail", Position = UDim2.new(0, 24, 0, 108), Size = UDim2.new(1, -48, 0, 22),
    BackgroundTransparency = 1, Text = "Starting loader…", TextColor3 = loaderColor(Loader.Theme.Muted),
    Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
}, Loader.Window)
Loader.Track = loaderCreate("Frame", {
    Name = "ProgressTrack", Position = UDim2.new(0, 24, 0, 164), Size = UDim2.new(1, -48, 0, 7),
    BackgroundColor3 = loaderColor(Loader.Theme.Panel), BorderSizePixel = 0, ZIndex = 2,
}, Loader.Window)
loaderCreate("UICorner", { CornerRadius = UDim.new(1, 0) }, Loader.Track)
Loader.Fill = loaderCreate("Frame", {
    Name = "ProgressFill", Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = loaderColor(Loader.Theme.Accent), BorderSizePixel = 0, ZIndex = 3,
}, Loader.Track)
loaderCreate("UICorner", { CornerRadius = UDim.new(1, 0) }, Loader.Fill)
loaderCreate("UIGradient", {
    Color = ColorSequence.new(loaderColor(Loader.Theme.Accent), loaderColor(Loader.Theme.Text)),
    Rotation = 0,
}, Loader.Fill)
Loader.Status = loaderCreate("TextLabel", {
    Name = "Status", Position = UDim2.new(0, 24, 0, 184), Size = UDim2.new(1, -104, 0, 20),
    BackgroundTransparency = 1, Text = "Fetching modules…", TextColor3 = loaderColor(Loader.Theme.Muted),
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
}, Loader.Window)
Loader.Counter = loaderCreate("TextLabel", {
    Name = "Counter", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 184),
    Size = UDim2.fromOffset(72, 20), BackgroundTransparency = 1, Text = "0 / " .. tostring(Loader.Total),
    TextColor3 = loaderColor(Loader.Theme.Muted), Font = Enum.Font.GothamMedium, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2,
}, Loader.Window)
Loader.ThemeLabel = loaderCreate("TextLabel", {
    Name = "ThemeLabel", Position = UDim2.new(0, 24, 1, -34), Size = UDim2.new(1, -48, 0, 16),
    BackgroundTransparency = 1, Text = selectedTheme == "MidnightBlue" and "Midnight" or selectedTheme,
    TextColor3 = loaderColor(Loader.Theme.Muted), Font = Enum.Font.Gotham, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
}, Loader.Window)

local function setLoaderStatus(message, progress, detail)
    if not Loader.Gui or not Loader.Gui.Parent then return end
    Loader.Status.Text = tostring(message or "Loading…")
    Loader.Counter.Text = tostring(Loader.Completed) .. " / " .. tostring(Loader.Total)
    if detail then Loader.Detail.Text = tostring(detail):sub(1, 140) end
    if progress ~= nil then
        loaderTween(Loader.Fill, 0.22, { Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0) })
    end
end

local function dismissLoader()
    if not Loader.Gui or not Loader.Gui.Parent then return end
    for _, item in ipairs(Loader.Gui:GetDescendants()) do
        local goals = {}
        if item:IsA("GuiObject") then goals.BackgroundTransparency = 1 end
        if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then goals.TextTransparency = 1 end
        if item:IsA("ImageLabel") or item:IsA("ImageButton") then goals.ImageTransparency = 1 end
        if item:IsA("UIStroke") then goals.Transparency = 1 end
        if next(goals) then loaderTween(item, 0.22, goals, Enum.EasingStyle.Sine, Enum.EasingDirection.In) end
    end
    loaderTween(Loader.Window, 0.22, { Position = UDim2.fromScale(0.5, 0.48) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    task.wait(0.24)
    if Loader.Gui and Loader.Gui.Parent then Loader.Gui:Destroy() end
end

loaderTween(Loader.Window, 0.3, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
loaderTween(Loader.Scale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
loaderTween(Loader.Window, 0.24, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local function fetchText(path)
    local displayName = tostring(path):gsub("^modules/", ""):gsub("%.lua$", "")
    setLoaderStatus("Fetching " .. displayName, Loader.Completed / Loader.Total,
        "Loading " .. displayName)
    local url = RAW_BASE .. "/" .. path
    local ok, result = pcall(game.HttpGet, game, url)
    if not ok or type(result) ~= "string" or result == "" or result:find("404: Not Found") then
        setLoaderStatus("Download failed", Loader.Completed / Loader.Total,
            "Could not fetch " .. tostring(path) .. ". Check your connection and try again.")
        error("Failed to fetch: " .. url, 0)
    end
    local required = REQUIRED_SIGNATURES[path]
    if required then
        for _, signature in ipairs(required) do
            if not result:find(signature, 1, true) then
                setLoaderStatus("Source check failed", Loader.Completed / Loader.Total,
                    "The downloaded " .. tostring(path) .. " is outdated or incomplete.")
                error("Outdated or mismatched remote source: " .. url .. " is missing required startup code. Update the GitHub main/src files or run the standalone full build.", 0)
            end
        end
    end
    local forbidden = FORBIDDEN_SIGNATURES[path]
    if forbidden then
        for _, signature in ipairs(forbidden) do
            if result:find(signature, 1, true) then
                setLoaderStatus("Source check failed", Loader.Completed / Loader.Total,
                    "The downloaded " .. tostring(path) .. " is malformed or outdated.")
                error("Outdated or malformed remote source: " .. url .. " contains stale startup code. Update the GitHub main/src files or run the standalone full build.", 0)
            end
        end
    end
    Loader.Completed = Loader.Completed + 1
    setLoaderStatus("Downloaded " .. tostring(path):gsub("^modules/", ""), Loader.Completed / Loader.Total)
    return result
end

print("Fetching modules...")
setLoaderStatus("Fetching Core", 0, "Loading Core")
local assembled = fetchText(CORE_PATH)

for _, moduleName in ipairs(MODULES) do
    setLoaderStatus("Fetching " .. moduleName:gsub("%.lua$", ""), Loader.Completed / Loader.Total)
    local moduleSource = fetchText(MODULE_DIRECTORY .. moduleName)
    local marker = "--[[GITHUB_MODULE:" .. moduleName .. "]]"
    
    local startIdx, endIdx = string.find(assembled, marker, 1, true)
    if not startIdx then
        setLoaderStatus("Assembly failed", Loader.Completed / Loader.Total,
            "The core is missing the insertion point for " .. moduleName .. ".")
        error("Missing marker: " .. marker, 0)
    end
    if string.find(assembled, marker, endIdx + 1, true) then
        setLoaderStatus("Assembly failed", Loader.Completed / Loader.Total,
            "The core contains duplicate insertion points for " .. moduleName .. ".")
        error("Duplicate marker: " .. marker, 0)
    end

    assembled = assembled:sub(1, startIdx - 1) .. moduleSource .. assembled:sub(endIdx + 1)
end

if assembled:find("GITHUB_MODULE:", 1, true) then
    setLoaderStatus("Assembly failed", Loader.Completed / Loader.Total,
        "A source module was missing its expected insertion point.")
    error("Assembly failed: unresolved module marker remains.", 0)
end

print("Executing...")
setLoaderStatus("Starting Dr4gonik Hub", 1, "Thanks For Using!!")
local fn, err = loadstring(assembled, "Dr4gonikHub")
if not fn then
    setLoaderStatus("Compile failed", 1, tostring(err))
    error("Compile error: " .. tostring(err), 0)
end

task.wait(0.5)
dismissLoader()
fn()

