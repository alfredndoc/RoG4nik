--[[
    Dr4gonik Hub — Premium Desktop UI v3
    LocalScript location: StarterPlayer > StarterPlayerScripts

    v3 features:
      - Robust theme engine with per-element miss diagnostics
      - Sandbox executor with print/warn capture
      - AI tool loop: [EXECUTE] / [INSPECT] blocks auto-run, results fed back
      - Untagged ```lua blocks only DISPLAY (manual Run button)
      - Workspace inspector exposed to the AI
      - Extensive debugging: console + in-UI Debug panel
]]

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--[[GITHUB_MODULE:Themes.lua]]

-- Forward declaration: ThemeEngine.setTheme may call this after boot.
local saveSettings
--[[GITHUB_MODULE:ThemeEngine.lua]]

--============================================================
--// AI STATE / PERSISTENCE
--============================================================
local AI = {
    Provider  = "DeepSeek",
    Model     = "deepseek-flash",
    ApiKey    = "",
    Endpoint  = "https://api.deepseek.com/chat/completions",
    CustomEndpoint = "",
    Effort    = "Medium",
    Temperature = 0.7,
    MaxTokens = 1024,
    ContextMessages = 30,
    RequestTimeout = 45,
    SystemPrompt = "",
    DisableSummarization = false,
    SaveHistory = true,
    EnterToSend = true,
    AutoScroll = true,
    AutoExecute       = true,
    SandboxMode       = true,
    CaptureOutput     = true,
    MaxToolIterations = 4,
    IncludeWorkspace  = false,
    StreamingEnabled = true,
    RequestActive = false,
    CancelRequest = false,
}

local ProviderPresets = {
    DeepSeek = { endpoint = "https://api.deepseek.com/chat/completions", models = { "deepseek-flash", "deepseek-v4-pro" }, summaryModel = "deepseek-flash" },
    Gemini = { endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", models = { "gemini-3.8-flash" }, summaryModel = "gemini-3.8-flash" },
    Groq = { endpoint = "https://api.groq.com/openai/v1/chat/completions", models = { "openai/gpt-oss-20b", "openai/gpt-oss-120b" }, summaryModel = "openai/gpt-oss-20b" },
    OpenRouter = { endpoint = "https://openrouter.ai/api/v1/chat/completions", models = { "openrouter/free" }, summaryModel = "openrouter/free" },
    ["Token Harbor"] = { endpoint = "https://tokenharbor.ai/v1/chat/completions", models = { "deepseek-v4.1-flash:free" }, summaryModel = "deepseek-v4.1-flash:free" },
    OpenAI   = { endpoint = "https://api.openai.com/v1/chat/completions", models = { "gpt-6-luna", "gpt-6.1-sol", "gpt-6-astra" } },
    Custom   = { endpoint = "", models = { "" } },
}

local SETTINGS_FILE = "DeepSeekSettings.json"
local CONVOS_FILE   = "DeepSeekConversations.json"

local function loadSettings()
    pcall(function()
        if readfile then
            local data = readfile(SETTINGS_FILE)
            if data and data ~= "" then
                local d = HttpService:JSONDecode(data)
                if d.Provider and ProviderPresets[d.Provider] then AI.Provider = d.Provider end
                if type(d.Model) == "string" then AI.Model = d.Model end
                if type(d.ApiKey) == "string" then AI.ApiKey = d.ApiKey end
                if type(d.CustomEndpoint) == "string" then AI.CustomEndpoint = d.CustomEndpoint end
                if d.Effort and ({ Minimal = true, Low = true, Medium = true, High = true, Maximum = true })[d.Effort] then AI.Effort = d.Effort end
                if type(d.Temperature) == "number" then AI.Temperature = math.clamp(d.Temperature, 0, 2) end
                if type(d.MaxTokens) == "number" then AI.MaxTokens = math.clamp(math.floor(d.MaxTokens), 128, 16384) end
                if type(d.ContextMessages) == "number" then AI.ContextMessages = math.clamp(math.floor(d.ContextMessages), 2, 100) end
                if type(d.RequestTimeout) == "number" then AI.RequestTimeout = math.clamp(math.floor(d.RequestTimeout), 5, 120) end
                if type(d.SystemPrompt) == "string" then AI.SystemPrompt = d.SystemPrompt end
                if type(d.DisableSummarization) == "boolean" then AI.DisableSummarization = d.DisableSummarization end
                if type(d.SaveHistory) == "boolean" then AI.SaveHistory = d.SaveHistory end
                if type(d.EnterToSend) == "boolean" then AI.EnterToSend = d.EnterToSend end
                if type(d.AutoScroll) == "boolean" then AI.AutoScroll = d.AutoScroll end
                if type(d.AutoExecute) == "boolean" then AI.AutoExecute = d.AutoExecute end
                if type(d.SandboxMode) == "boolean" then AI.SandboxMode = d.SandboxMode end
                if type(d.CaptureOutput) == "boolean" then AI.CaptureOutput = d.CaptureOutput end
                if type(d.MaxToolIterations) == "number" then AI.MaxToolIterations = math.clamp(math.floor(d.MaxToolIterations), 1, 10) end
                if type(d.IncludeWorkspace) == "boolean" then AI.IncludeWorkspace = d.IncludeWorkspace end
                if d.Theme and Themes[d.Theme] then
                    ThemeEngine.CurrentThemeName = d.Theme
                    ThemeEngine.applyThemePreset(d.Theme)
                end
            end
        end
    end)
    AI.Endpoint = AI.Provider == "Custom" and AI.CustomEndpoint or ProviderPresets[AI.Provider].endpoint
end
loadSettings()

saveSettings = function()
    pcall(function()
        if writefile then
            writefile(SETTINGS_FILE, HttpService:JSONEncode({
                Provider = AI.Provider, Model = AI.Model, ApiKey = AI.ApiKey,
                CustomEndpoint = AI.CustomEndpoint, Theme = ThemeEngine.CurrentThemeName, Effort = AI.Effort,
                Temperature = AI.Temperature, MaxTokens = AI.MaxTokens,
                ContextMessages = AI.ContextMessages, RequestTimeout = AI.RequestTimeout,
                SystemPrompt = AI.SystemPrompt, SaveHistory = AI.SaveHistory,
                DisableSummarization = AI.DisableSummarization,
                EnterToSend = AI.EnterToSend, AutoScroll = AI.AutoScroll,
                AutoExecute = AI.AutoExecute, SandboxMode = AI.SandboxMode,
                CaptureOutput = AI.CaptureOutput, MaxToolIterations = AI.MaxToolIterations,
                IncludeWorkspace = AI.IncludeWorkspace,
            }))
        end
    end)
end

--============================================================
--// LAYOUT CONSTANTS
--============================================================
local WINDOW_WIDTH  = 760
local WINDOW_HEIGHT = 500
local WINDOW_SIZE   = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT)
local WINDOW_POSITION = UDim2.new(0.5, -WINDOW_WIDTH / 2, 0.5, -WINDOW_HEIGHT / 2)
local MINIMIZED_HEIGHT = 60
local SIDEBAR_START = 260
local SIDEBAR_MIN   = 200
local SIDEBAR_MAX   = 350
local DIVIDER_WIDTH = 12
local SIDEBAR_HEADER_HEIGHT = 56
local FOOTER_HEIGHT = 68
local RIGHT_CONTENT_INSET_X = 22
local RIGHT_CONTENT_INSET_Y = 18
local RIGHT_HEADER_HEIGHT = 44
local INPUT_HEIGHT = 58
local CHAT_TOP = 54
local CHAT_BOTTOM_GAP = 72

--[[GITHUB_MODULE:SystemPrompt.lua]]

--[[GITHUB_MODULE:Sandbox.lua]]

--============================================================
--// BUTTONS / SCROLLBARS
--============================================================
local Icons = {
    Menu = "rbxassetid://6031094678", Search = "rbxassetid://6031221421",
    Files = "rbxassetid://6031091004", Send = "rbxassetid://6031075931",
    Plus = "rbxassetid://6031091006",
}

--============================================================
--// ROOT GUI
--============================================================
local oldGui = playerGui:FindFirstChild("DeepSeekUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = create("ScreenGui", {
    Name = "DeepSeekUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local MainFrame = create("Frame", {
    Name = "MainWindow", Size = WINDOW_SIZE, Position = WINDOW_POSITION,
    BackgroundColor3 = Theme.Background, BorderSizePixel = 0, ClipsDescendants = true, Active = true, ZIndex = 1,
}, ScreenGui)
corner(MainFrame, 16)
stroke(MainFrame, Theme.Border, 1, 0.15)

local ThemeTransitionOverlay = create("Frame", {
    Name = "ThemeTransitionOverlay", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Theme.Background, BackgroundTransparency = 1, Visible = false,
    BorderSizePixel = 0, Active = false, Selectable = false, ZIndex = 200,
}, MainFrame)
corner(ThemeTransitionOverlay, 16)
create("UIGradient", {
    Rotation = 0,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.5, Theme.AccentHover),
        ColorSequenceKeypoint.new(1, Theme.Accent),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.35),
        NumberSequenceKeypoint.new(1, 0.1),
    }),
}, ThemeTransitionOverlay)
RuntimeDiagnostics.ThemeTransitionOverlay = ThemeTransitionOverlay

--============================================================
--// PANES
--============================================================
local LeftPane = create("Frame", {
    Name = "LeftPane", Size = UDim2.new(0, SIDEBAR_START, 1, 0),
    BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1,
}, MainFrame)
corner(LeftPane, 16)
create("Frame", {
    Name = "LeftPaneEdgeFill", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 16, 1, 0), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ZIndex = 1,
}, LeftPane)

local RightPane = create("Frame", {
    Name = "RightPane", Position = UDim2.new(0, SIDEBAR_START + 1, 0, 0),
    Size = UDim2.new(1, -(SIDEBAR_START + 1), 1, 0), BackgroundColor3 = Theme.RightBg,
    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1,
}, MainFrame)
corner(RightPane, 16)

local DividerHitbox = create("Frame", {
    Name = "DividerHitbox", Position = UDim2.new(0, SIDEBAR_START - DIVIDER_WIDTH / 2, 0, 0),
    Size = UDim2.new(0, DIVIDER_WIDTH, 1, 0), BackgroundTransparency = 1, Active = true, ZIndex = 12,
}, MainFrame)
local DividerLine = create("Frame", {
    Name = "DividerLine", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
    Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 12,
}, DividerHitbox)

local sidebarWidth = SIDEBAR_START
local function setSidebarWidth(width)
    sidebarWidth = math.clamp(width, SIDEBAR_MIN, SIDEBAR_MAX)
    LeftPane.Size = UDim2.new(0, sidebarWidth, 1, 0)
    DividerHitbox.Position = UDim2.new(0, sidebarWidth - DIVIDER_WIDTH / 2, 0, 0)
    RightPane.Position = UDim2.new(0, sidebarWidth + 1, 0, 0)
    RightPane.Size = UDim2.new(1, -(sidebarWidth + 1), 1, 0)
end

--============================================================
--// SIDEBAR HEADER
--============================================================
local SidebarHeader = create("Frame", {
    Name = "SidebarHeader", Position = UDim2.new(0, 16, 0, 15),
    Size = UDim2.new(1, -32, 0, 28), BackgroundTransparency = 1, ZIndex = 5,
}, LeftPane)

local BrandMark = create("Frame", {
    Name = "BrandMark", Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 6,
}, SidebarHeader)
corner(BrandMark, 9)

Theme.createHubGlyph(BrandMark, 18, 7, Theme.White, true)

create("TextLabel", {
    Name = "BrandTitle", Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -125, 1, 0),
    BackgroundTransparency = 1, Text = "Dr4gonik Hub", TextColor3 = Theme.PrimaryText,
    Font = Theme.FontBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
}, SidebarHeader)

local SidebarHeaderButtons = create("Frame", {
    Name = "SidebarHeaderButtons", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 95, 1, 0), BackgroundTransparency = 1, ZIndex = 6,
}, SidebarHeader)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder,
}, SidebarHeaderButtons)

local function createImageIconButton(parent, name, image, order, size)
    local button = create("ImageButton", {
        Name = name, Size = UDim2.fromOffset(size or 24, size or 24),
        BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1, BorderSizePixel = 0,
        Image = image, ImageColor3 = Theme.MutedText, ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false, LayoutOrder = order or 1, ZIndex = 7,
    }, parent)
    corner(button, 7)
    bindSoftButton(button, { BackgroundTransparency = 0.15, ImageColor3 = Theme.PrimaryText }, 1.08)
    return button
end

local MenuButton   = createImageIconButton(SidebarHeaderButtons, "MenuButton", Icons.Menu, 1, 23)
local SearchButton = createImageIconButton(SidebarHeaderButtons, "SearchButton", Icons.Search, 2, 23)
local FilesButton  = createImageIconButton(SidebarHeaderButtons, "FilesButton", Icons.Files, 3, 23)

--============================================================
--// SIDEBAR SCROLL
--============================================================
local SidebarScroll = create("ScrollingFrame", {
    Name = "SidebarScroll", Position = UDim2.new(0, 0, 0, SIDEBAR_HEADER_HEIGHT),
    Size = UDim2.new(1, 0, 1, -(SIDEBAR_HEADER_HEIGHT + FOOTER_HEIGHT)), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 3,
}, LeftPane)
styleScrollBar(SidebarScroll)
create("UIListLayout", { Padding = UDim.new(0, 11), SortOrder = Enum.SortOrder.LayoutOrder }, SidebarScroll)
padding(SidebarScroll, 15, 15, 7, 16)

create("TextLabel", {
    Name = "WorkspaceTitle", Size = UDim2.new(1, 0, 0, 23), BackgroundTransparency = 1,
    Text = "Your workspace", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold,
    TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, ZIndex = 4,
}, SidebarScroll)

local SegmentedControl = create("Frame", {
    Name = "SegmentedControl", Size = UDim2.new(1, 0, 0, 37),
    BackgroundColor3 = Theme.SegmentedBg, BorderSizePixel = 0, LayoutOrder = 2, ZIndex = 4,
}, SidebarScroll)
corner(SegmentedControl, 10)
stroke(SegmentedControl, Theme.Border, 1, 0.18)
local TabIndicator = create("Frame", {
    Name = "TabIndicator", Position = UDim2.new(0, 3, 0, 3),
    Size = UDim2.new(1 / 3, -4, 1, -6), BackgroundColor3 = Theme.Hover, BorderSizePixel = 0, ZIndex = 5,
}, SegmentedControl)
corner(TabIndicator, 8)

local tabButtons = {}
local activeTab = "Scripts"
local function createTab(name, index)
    local button = create("TextButton", {
        Name = name .. "Tab", Position = UDim2.new((index - 1) / 3, 0, 0, 0),
        Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1, Text = name,
        TextColor3 = name == activeTab and Theme.PrimaryText or Theme.MutedText,
        Font = name == activeTab and Theme.FontBold or Theme.Font, TextSize = 12,
        AutoButtonColor = false, ZIndex = 6,
    }, SegmentedControl)
    button.MouseEnter:Connect(function()
        if activeTab ~= name then tween(button, { TextColor3 = Theme.PrimaryText }, 0.12) end
    end)
    button.MouseLeave:Connect(function()
        if activeTab ~= name then tween(button, { TextColor3 = Theme.MutedText }, 0.12) end
    end)
    tabButtons[name] = button
    return button
end
local CoworkTab = createTab("Scripts", 1)
local ChatTab   = createTab("Chat", 2)
local CodeTab   = createTab("Code", 3)

local NewConvoBtn = create("TextButton", {
    Name = "NewConversationButton", Size = UDim2.new(1, 0, 0, 39),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = "+   New conversation",
    TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = 3, ZIndex = 4,
}, SidebarScroll)
corner(NewConvoBtn, 9)
stroke(NewConvoBtn, Theme.Border, 1, 0.1)
padding(NewConvoBtn, 13, 12, 0, 0)
bindSoftButton(NewConvoBtn, { BackgroundColor3 = Theme.Hover }, 1.015)

local function createSidebarNavButton(name, order)
    local button = create("TextButton", {
        Name = name:gsub("%s", "") .. "Button", Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = name, TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = order, ZIndex = 4,
    }, SidebarScroll)
    corner(button, 8)
    padding(button, 12, 8, 0, 0)
    bindSoftButton(button, { BackgroundTransparency = 0.2, TextColor3 = Theme.PrimaryText }, 1.015)
    return button
end
local SettingsButton = createSidebarNavButton("Settings", 4)
local FoldersButton  = createSidebarNavButton("Conversation folders", 5)

create("TextLabel", {
    Name = "RecentLabel", Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
    Text = "RECENT CHATS", TextColor3 = Theme.QuietText, Font = Theme.FontBold,
    TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 6, ZIndex = 4,
}, SidebarScroll)

--============================================================
--// RIGHT CONTENT
--============================================================
local Content = create("Frame", {
    Name = "Content", Position = UDim2.new(0, RIGHT_CONTENT_INSET_X, 0, RIGHT_CONTENT_INSET_Y),
    Size = UDim2.new(1, -RIGHT_CONTENT_INSET_X * 2, 1, -RIGHT_CONTENT_INSET_Y * 2),
    BackgroundTransparency = 1, ZIndex = 2,
}, RightPane)

local RightHeader = create("Frame", {
    Name = "RightHeader", Size = UDim2.new(1, 0, 0, RIGHT_HEADER_HEIGHT),
    BackgroundTransparency = 1, ZIndex = 8,
}, Content)

local NavButtons = create("Frame", {
    Name = "BackForwardButtons", Position = UDim2.new(0, 0, 0, 5), Size = UDim2.new(0, 58, 0, 29),
    BackgroundTransparency = 1, ZIndex = 9,
}, RightHeader)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, NavButtons)

local function createTextIconButton(parent, name, glyph, order)
    local button = create("TextButton", {
        Name = name, Size = UDim2.fromOffset(27, 27), BackgroundColor3 = Theme.Hover,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = glyph, TextColor3 = Theme.MutedText,
        Font = Theme.Font, TextSize = 22, AutoButtonColor = false, LayoutOrder = order, ZIndex = 10,
    }, parent)
    corner(button, 7)
    bindSoftButton(button, { BackgroundTransparency = 0.1, TextColor3 = Theme.PrimaryText }, 1.07)
    return button
end

local BackButton    = createTextIconButton(NavButtons, "BackButton", "‹", 1)
local ForwardButton = createTextIconButton(NavButtons, "ForwardButton", "›", 2)

local TitleGroup = create("Frame", {
    Name = "TitleDragRegion", Position = UDim2.new(0, 65, 0, 0), Size = UDim2.new(1, -165, 1, 0),
    BackgroundTransparency = 1, Active = true, ZIndex = 8,
}, RightHeader)
local ChatTitle = create("TextLabel", {
    Name = "ChatTitle", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
    Text = "Dr4gonik Hub", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold,
    TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
}, TitleGroup)
local ChatSub = create("TextLabel", {
    Name = "ChatSubtitle", Position = UDim2.new(0, 0, 0, 23), Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1, Text = "Dr4gonik Hub", TextColor3 = Theme.MutedText,
    Font = Theme.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
}, TitleGroup)

local WindowControls = create("Frame", {
    Name = "WindowControls", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4),
    Size = UDim2.new(0, 91, 0, 29), BackgroundTransparency = 1, ZIndex = 9,
}, RightHeader)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, WindowControls)

local function createWindowButton(name, glyph, order, isDanger)
    local button = create("TextButton", {
        Name = name, Size = UDim2.fromOffset(27, 27),
        BackgroundColor3 = isDanger and Theme.Danger or Theme.Hover, BackgroundTransparency = 1,
        BorderSizePixel = 0, Text = glyph, TextColor3 = Theme.MutedText, Font = Theme.Font,
        TextSize = isDanger and 13 or 15, AutoButtonColor = false, LayoutOrder = order, ZIndex = 10,
    }, WindowControls)
    corner(button, 7)
    bindSoftButton(button, { BackgroundTransparency = isDanger and 0.05 or 0.12, TextColor3 = Theme.White }, 1.06)
    return button
end
local MinBtn   = createWindowButton("MinimizeButton", "—", 1, false)
local MaxBtn   = createWindowButton("MaximizeButton", "□", 2, false)
local CloseBtn = createWindowButton("CloseButton", "×", 3, true)

--============================================================
--// CHAT STATE
--============================================================
local conversations = {}
local selectedConversationId = nil
local conversationRows = {}
local conversationButtons = {}
local conversationOptions = {}
local messageOrder = 0
local chatHasContent = false
local activeView = "chat"

local ChatDisplay = create("ScrollingFrame", {
    Name = "ChatDisplay", Position = UDim2.new(0, 0, 0, CHAT_TOP),
    Size = UDim2.new(1, 0, 1, -(CHAT_TOP + CHAT_BOTTOM_GAP)), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 2,
}, Content)
styleScrollBar(ChatDisplay)
create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, ChatDisplay)
padding(ChatDisplay, 2, 7, 9, 12)

local EmptyChatLabel = create("TextLabel", {
    Name = "EmptyState", Position = UDim2.new(0, 0, 0, CHAT_TOP),
    Size = UDim2.new(1, 0, 1, -(CHAT_TOP + CHAT_BOTTOM_GAP)), BackgroundTransparency = 1,
    Text = "A calmer space for your next idea.\n\nSelect a conversation or type a message below.",
    TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 15, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3,
}, Content)

--============================================================
--// CODE EDITOR TAB
--============================================================
local setActiveTab
local ScriptUI = {}

local CodeEditorFrame = create("Frame", {
    Name = "CodeEditorFrame", Position = UDim2.new(0, 0, 0, CHAT_TOP),
    Size = UDim2.new(1, 0, 1, -(CHAT_TOP + CHAT_BOTTOM_GAP)), BackgroundTransparency = 1, Visible = false, ZIndex = 4,
}, Content)

local CodePanel = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BorderSizePixel = 0 }, CodeEditorFrame)
corner(CodePanel, 13)
stroke(CodePanel, Theme.Border, 1, 0.1)

local CodeHeader = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ZIndex = 5 }, CodePanel)
corner(CodeHeader, 13)
local CodeHeaderTitle = create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1,
    Text = "script.lua", TextColor3 = Theme.MutedText, Font = Theme.FontCode, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
}, CodeHeader)

-- Manual fixed positioning for Toolbar items to prevent any overlap on small screens
local CodeToolbar = create("Frame", { Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5 }, CodePanel)
corner(CodeToolbar, 13)
local CodeToolbarDivider = create("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Border, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 5 }, CodeToolbar)
padding(CodeToolbar, 12, 12, 0, 0)

-- Added TextTruncate & ClipsDescendants to stop text overflowing
-- Put each TextBox inside a matching clipping viewport. Roblox TextBoxes can
-- horizontally scroll while focused; the independent parent clip prevents long
-- descriptions from painting over adjacent toolbar buttons or fields.
ScriptUI.NameBoxClip = create("Frame", {
    Name = "ScriptNameClip", Position = UDim2.new(0, 0, 0, 7),
    Size = UDim2.new(0.32, -6, 0, 32), BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 6,
}, CodeToolbar)
ScriptUI.NameBox = create("TextBox", {
    Name = "NameBox", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = "",
    PlaceholderText = "Script name", TextColor3 = Theme.PrimaryText,
    PlaceholderColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    TextWrapped = false, ClearTextOnFocus = false, ClipsDescendants = true, ZIndex = 6,
}, ScriptUI.NameBoxClip)
corner(ScriptUI.NameBox, 8)
stroke(ScriptUI.NameBox, Theme.Border, 1, 0.15)
padding(ScriptUI.NameBox, 10, 8, 0, 0)

ScriptUI.DescriptionBoxClip = create("Frame", {
    Name = "DescriptionBoxClip", Position = UDim2.new(0.32, 2, 0, 7),
    Size = UDim2.new(0.32, -8, 0, 32), BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 6,
}, CodeToolbar)
ScriptUI.DescriptionBox = create("TextBox", {
    Name = "DescriptionBox", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = "",
    PlaceholderText = "Description", TextColor3 = Theme.PrimaryText,
    PlaceholderColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    TextWrapped = false, ClearTextOnFocus = false, ClipsDescendants = true, ZIndex = 6,
}, ScriptUI.DescriptionBoxClip)
corner(ScriptUI.DescriptionBox, 8)
stroke(ScriptUI.DescriptionBox, Theme.Border, 1, 0.15)
padding(ScriptUI.DescriptionBox, 10, 8, 0, 0)

-- Save As (Blue)
local SaveAsBtn = create("TextButton", {Position=UDim2.new(0.64,2,0,7), Size=UDim2.new(0.16,-8,0,32), BackgroundColor3=Theme.Accent, BorderSizePixel=0, Text="Save As", TextColor3=Theme.White, Font=Theme.FontBold, TextSize=12, ZIndex=6}, CodeToolbar)
corner(SaveAsBtn,8)
bindSoftButton(SaveAsBtn, {BackgroundColor3=Theme.AccentHover}, 1.02)

-- Save Script (Normal Gray)
local SaveScriptBtn = create("TextButton", {Position=UDim2.new(0.80,2,0,7), Size=UDim2.new(0.20,-8,0,32), BackgroundColor3=Theme.Panel, BorderSizePixel=0, Text="Save Script", TextColor3=Theme.PrimaryText, Font=Theme.FontBold, TextSize=12, ZIndex=6}, CodeToolbar)
corner(SaveScriptBtn,8); stroke(SaveScriptBtn,Theme.Border,1,0.15)
bindSoftButton(SaveScriptBtn, {BackgroundColor3=Theme.Hover}, 1.02)

ScriptUI.NameBox:GetPropertyChangedSignal("Text"):Connect(function() CodeHeaderTitle.Text = (ScriptUI.NameBox.Text ~= "" and ScriptUI.NameBox.Text or "script") .. ".lua" end)

local CodeFooter = create("Frame", { Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ZIndex = 5 }, CodePanel)
corner(CodeFooter, 13)

local CodeScroll = create("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 94), Size = UDim2.new(1, -24, 1, -156),
    BackgroundTransparency = 1, ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0, 0, 0, 200), ZIndex = 5,
}, CodePanel)
styleScrollBar(CodeScroll)

local CodeTextBox = create("TextBox", {
    Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    Text = "-- Write your code here\n\nlocal function hello(name)\n    print(\"Hello, \" .. name .. \"!\")\nend\n\nhello(\"Dr4gonik Hub\")",
    TextColor3 = Theme.PrimaryText, Font = Theme.FontCode, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, ZIndex = 6,
}, CodeScroll)
padding(CodeTextBox, 4, 4, 4, 4)

local function syncCodeCanvas() CodeScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(CodeScroll.AbsoluteSize.Y, CodeTextBox.TextBounds.Y + 32)) end
CodeTextBox:GetPropertyChangedSignal("TextBounds"):Connect(syncCodeCanvas)
CodeTextBox:GetPropertyChangedSignal("Text"):Connect(syncCodeCanvas)
task.defer(syncCodeCanvas)

local RunBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(80, 30),
    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Text = "> Run", TextColor3 = Theme.White,
    Font = Theme.FontBold, TextSize = 13, AutoButtonColor = false, ZIndex = 6,
}, CodeFooter)
corner(RunBtn, 8)
bindSoftButton(RunBtn, { BackgroundColor3 = Theme.AccentHover }, 1.05)

local CodeStatusLabel = create("TextLabel", {
    Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -112, 1, 0),
    BackgroundTransparency = 1, Text = "Ready · uses sandbox executor",
    TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
}, CodeFooter)

RunBtn.MouseButton1Click:Connect(function()
    local entry = runInSandbox(CodeTextBox.Text)
    if entry.ok then
        local out = entry.output ~= "" and entry.output or (entry.result or "(no output)")
        CodeStatusLabel.Text = "OK · " .. tostring(out):sub(1, 120)
        CodeStatusLabel.TextColor3 = Color3.fromRGB(88, 195, 135)
    else
        CodeStatusLabel.Text = "✗ " .. tostring(entry.error):sub(1, 120)
        CodeStatusLabel.TextColor3 = Theme.Danger
    end
end)

--============================================================
--// SCRIPTS LIBRARY VIEW
--============================================================
ScriptUI.View = create("Frame", {Name="ScriptsView", Position=UDim2.new(0,0,0,CHAT_TOP), Size=UDim2.new(1,0,1,-(CHAT_TOP+CHAT_BOTTOM_GAP)), BackgroundTransparency=1, Visible=false, ZIndex=4}, Content)

local NewScriptBtn = create("TextButton", {Position=UDim2.new(0,0,0,0), Size=UDim2.new(1,-8,0,36), BackgroundColor3=Theme.Panel, BorderSizePixel=0, Text="+ New Script", TextColor3=Theme.PrimaryText, Font=Theme.FontBold, TextSize=13, ZIndex=6}, ScriptUI.View)
corner(NewScriptBtn, 8); stroke(NewScriptBtn, Theme.Border, 1, 0.15)
bindSoftButton(NewScriptBtn, {BackgroundColor3=Theme.Hover}, 1.015)
NewScriptBtn.MouseButton1Click:Connect(function()
    CodeTextBox.Text = "-- New script"
    ScriptUI.NameBox.Text = "NewScript"
    ScriptUI.DescriptionBox.Text = "A saved Lua script"
    ScriptUI.LoadedName = nil
    setActiveTab("Code")
end)

ScriptUI.Hint = create("TextLabel", {Position=UDim2.new(0,2,0,44), Size=UDim2.new(1,-4,0,30), BackgroundTransparency=1, Text="Saved scripts · Edit opens the code workspace · Execute runs in the sandbox", TextColor3=Theme.MutedText, Font=Theme.Font, TextSize=11, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5}, ScriptUI.View)
ScriptUI.List = create("ScrollingFrame", {Position=UDim2.new(0,0,0,76), Size=UDim2.new(1,0,1,-76), BackgroundTransparency=1, BorderSizePixel=0, ScrollingDirection=Enum.ScrollingDirection.Y, AutomaticCanvasSize=Enum.AutomaticSize.Y, CanvasSize=UDim2.new(0,0,0,0), ZIndex=4}, ScriptUI.View)
styleScrollBar(ScriptUI.List); create("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder}, ScriptUI.List); padding(ScriptUI.List,2,7,3,10)

function ScriptUI.refreshCards()
    for _, child in ipairs(ScriptUI.List:GetChildren()) do if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end end
    local items = _G.listHubScripts()
    if #items==0 then
        create("TextLabel", {Size=UDim2.new(1,-8,0,82), BackgroundColor3=Theme.Panel, Text="No saved scripts yet\nWrite code in the Code tab, name it above, then press Save Script.", TextColor3=Theme.MutedText, Font=Theme.Font, TextSize=13, TextWrapped=true, ZIndex=5}, ScriptUI.List)
        return
    end
    for i,item in ipairs(items) do
        local card=create("Frame", {Name="ScriptCard_"..item.name, Size=UDim2.new(1,-8,0,106), BackgroundColor3=Theme.Panel, BorderSizePixel=0, LayoutOrder=i, ZIndex=5}, ScriptUI.List)
        corner(card,12); stroke(card,Theme.Border,1,0.12)
        create("TextLabel", {Position=UDim2.new(0,13,0,8), Size=UDim2.new(1,-26,0,22), BackgroundTransparency=1, Text=item.name, TextColor3=Theme.PrimaryText, Font=Theme.FontBold, TextSize=15, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=6}, card)
        local desc=tostring(item.description or "Lua script")
        create("TextLabel", {Position=UDim2.new(0,13,0,32), Size=UDim2.new(1,-26,0,27), BackgroundTransparency=1, Text=desc, TextColor3=Theme.MutedText, Font=Theme.Font, TextSize=12, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=6}, card)
        
        local del=create("TextButton", {Position=UDim2.new(1,-232,1,-36), Size=UDim2.fromOffset(60,26), BackgroundColor3=Theme.Danger, BorderSizePixel=0, Text="Delete", TextColor3=Theme.White, Font=Theme.FontBold, TextSize=11, ZIndex=7}, card); corner(del,7)
        local edit=create("TextButton", {Position=UDim2.new(1,-164,1,-36), Size=UDim2.fromOffset(68,26), BackgroundColor3=Theme.Hover, BorderSizePixel=0, Text="Edit", TextColor3=Theme.PrimaryText, Font=Theme.FontBold, TextSize=12, ZIndex=7}, card); corner(edit,7)
        local exec=create("TextButton", {Position=UDim2.new(1,-88,1,-36), Size=UDim2.fromOffset(70,26), BackgroundColor3=Theme.Accent, BorderSizePixel=0, Text="Execute", TextColor3=Theme.White, Font=Theme.FontBold, TextSize=11, ZIndex=7}, card); corner(exec,7)
        
        del.MouseButton1Click:Connect(function() 
            if _G.deleteHubScript then _G.deleteHubScript(item.name) end
            ScriptUI.refreshCards() 
        end)
        
        edit.MouseButton1Click:Connect(function() 
            CodeTextBox.Text=item.source or (_G.readHubScript(item.name) or ""); 
            ScriptUI.NameBox.Text=item.name; 
            ScriptUI.LoadedName=item.name; 
            ScriptUI.DescriptionBox.Text=item.description or "Edited Lua script"; 
            CodeHeaderTitle.Text=item.name .. ".lua"; 
            setActiveTab("Code") 
        end)
        
        exec.MouseButton1Click:Connect(function()
            local result=_G.runHubScript(item.name)
            ScriptUI.Hint.Text=result.ok and ("Executed "..item.name.." · "..tostring(result.output or result.result or "No output"):sub(1,150)) or ("Execution failed: "..tostring(result.error):sub(1,150))
            ScriptUI.Hint.TextColor3=result.ok and Theme.MutedText or Theme.Danger
        end)
    end
end

--============================================================
--// SAVE AS POPUP
--============================================================
local SaveAsPopup = create("Frame", {
    Name = "SaveAsPopup", Size = UDim2.fromOffset(300, 400), Position = UDim2.new(0.5, -150, 0.5, -200),
    BackgroundColor3 = Theme.PanelRaised, BorderSizePixel = 0, Visible = false, ZIndex = 100
}, CodeEditorFrame)
corner(SaveAsPopup, 12); stroke(SaveAsPopup, Theme.Border, 1, 0.1)

local SaveAsBackdrop = create("TextButton", {
    Name = "SaveAsBackdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.5,
    BackgroundColor3 = Color3.new(0,0,0), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 99
}, CodeEditorFrame)

local SaveAsList = create("ScrollingFrame", {
    Position = UDim2.new(0, 10, 0, 50), Size = UDim2.new(1, -20, 1, -60),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0,0,0,0), ZIndex = 101
}, SaveAsPopup)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, SaveAsList)

create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1,
    Text = "Overwrite Existing Script", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold,
    TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101
}, SaveAsPopup)

SaveAsBackdrop.MouseButton1Click:Connect(function() 
    SaveAsPopup.Visible = false; SaveAsBackdrop.Visible = false 
end)

local function openSaveAsPopup()
    for _, child in ipairs(SaveAsList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local items = _G.listHubScripts()
    if #items == 0 then
        local empty = create("TextLabel", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, Text="No existing scripts found.", TextColor3=Theme.MutedText, Font=Theme.Font, TextSize=12, ZIndex=101}, SaveAsList)
        empty.LayoutOrder = 1
    else
        for i, item in ipairs(items) do
            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
                Text = "  " .. item.name, TextColor3 = Theme.PrimaryText, Font = Theme.FontBold,
                TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, ZIndex = 102
            }, SaveAsList)
            corner(btn, 8); stroke(btn, Theme.Border, 1, 0.15); padding(btn, 10, 10, 0, 0)
            bindSoftButton(btn, {BackgroundColor3=Theme.Hover}, 1.015)
            
            btn.MouseButton1Click:Connect(function()
                local desc = ScriptUI.DescriptionBox.Text
                if desc == "" or desc == "A saved Lua script" then desc = item.description or "Overwritten script" end
                _G.saveHubScript(item.name, CodeTextBox.Text, desc)
                ScriptUI.LoadedName = item.name
                ScriptUI.NameBox.Text = item.name
                ScriptUI.DescriptionBox.Text = desc
                
                SaveAsPopup.Visible = false; SaveAsBackdrop.Visible = false
                ScriptUI.refreshCards()
                CodeStatusLabel.Text = "Overwrote " .. item.name
                CodeStatusLabel.TextColor3 = Theme.MutedText
            end)
        end
    end
    SaveAsPopup.Visible = true; SaveAsBackdrop.Visible = true
end

SaveAsBtn.MouseButton1Click:Connect(openSaveAsPopup)

SaveScriptBtn.MouseButton1Click:Connect(function()
    local requestedName = tostring(ScriptUI.NameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if requestedName == "" then
        CodeStatusLabel.Text = "Enter a script name first."
        CodeStatusLabel.TextColor3 = Theme.Danger
        ScriptUI.NameBox:CaptureFocus()
        return
    end
    
    if ScriptUI.LoadedName and requestedName ~= ScriptUI.LoadedName then
        for _, item in ipairs(_G.listHubScripts()) do
            if item.name:lower() == requestedName:lower() then
                CodeStatusLabel.Text = "Name exists! Use Save As to overwrite."
                CodeStatusLabel.TextColor3 = Theme.Danger
                return
            end
        end
    end
    
    local desc = ScriptUI.DescriptionBox.Text
    if desc == "" then desc = "A saved Lua script" end
    
    local ok, msg = _G.saveHubScript(requestedName, CodeTextBox.Text, desc)
    if ok then 
        ScriptUI.LoadedName = requestedName 
        CodeStatusLabel.Text = "Saved to " .. requestedName
        CodeStatusLabel.TextColor3 = Theme.MutedText
        ScriptUI.refreshCards()
    else
        CodeStatusLabel.Text = "Save failed: " .. tostring(msg)
        CodeStatusLabel.TextColor3 = Theme.Danger
    end
end)

--[[GITHUB_MODULE:SettingsView.lua]]

--============================================================
--// CONVERSATION MANAGEMENT
--============================================================
local function getConversation(id)
    for _, c in ipairs(conversations) do if c.id == id then return c end end
    return nil
end
local function currentConversation() return getConversation(selectedConversationId) end

local function refreshConversationStyles()
    for id, row in pairs(conversationRows) do
        local selected = id == selectedConversationId
        row.BackgroundColor3 = selected and Theme.Selected or Theme.Hover
        row.BackgroundTransparency = selected and 0 or 1
        local titleLabel = row:FindFirstChild("ConversationTitle")
        if not titleLabel then
            local sb = row:FindFirstChild("SelectConversationButton")
            if sb then titleLabel = sb:FindFirstChild("ConversationTitle") end
        end
        if titleLabel then
            titleLabel.TextColor3 = selected and Theme.PrimaryText or Theme.MutedText
            titleLabel.Font = selected and Theme.FontBold or Theme.Font
        end
        local moreBtn = conversationOptions[id]
        if moreBtn then
            moreBtn.Visible = selected or row:GetAttribute("Hovered") == true
            moreBtn.TextColor3 = selected and Theme.PrimaryText or Theme.MutedText
        end
    end
end

local function scrollChatToBottom()
    if not AI.AutoScroll then return end
    task.defer(function()
        task.wait()
        local maxY = math.max(0, ChatDisplay.AbsoluteCanvasSize.Y - ChatDisplay.AbsoluteSize.Y)
        ChatDisplay.CanvasPosition = Vector2.new(0, maxY)
    end)
end

local function clearRenderedMessages()
    for _, child in ipairs(ChatDisplay:GetChildren()) do
        if child:IsA("GuiObject") and (child.Name == "MessageRow" or child.Name == "NoticeRow") then
            child:Destroy()
        end
    end
    messageOrder = 0
end

--[[GITHUB_MODULE:Markdown.lua]]
--[[GITHUB_MODULE:Messages.lua]]

--============================================================
--// FOOTER
--============================================================
local Footer = create("Frame", {
    Name = "ProfileFooter", Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT),
    Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ZIndex = 8,
}, LeftPane)
corner(Footer, 16)
create("Frame", {
    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Border,
    BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 9,
}, Footer)
local Avatar = create("ImageLabel", {
    Position = UDim2.new(0, 15, 0.5, -18), Size = UDim2.fromOffset(36, 36),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
    Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId),
    ScaleType = Enum.ScaleType.Crop, ZIndex = 10,
}, Footer)
corner(Avatar, 18)
stroke(Avatar, Theme.Border, 1, 0.25)
create("TextLabel", {
    Position = UDim2.new(0, 61, 0.5, -17), Size = UDim2.new(1, -110, 0, 17), BackgroundTransparency = 1,
    Text = player.DisplayName ~= "" and player.DisplayName or player.Name, TextColor3 = Theme.PrimaryText,
    Font = Theme.FontBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
}, Footer)
create("TextLabel", {
    Position = UDim2.new(0, 61, 0.5, 2), Size = UDim2.new(1, -110, 0, 15), BackgroundTransparency = 1,
    Text = "Project RoSeek", TextColor3 = Theme.MutedText, Font = Theme.Font,
    TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
}, Footer)
local ProfileOptionsBtn = create("TextButton", {
    Name = "ProfileOptionsButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1,
    BorderSizePixel = 0, Text = "···", TextColor3 = Theme.MutedText, Font = Theme.FontBold,
    TextSize = 18, AutoButtonColor = false, ZIndex = 11,
}, Footer)
corner(ProfileOptionsBtn, 8)
bindSoftButton(ProfileOptionsBtn, { BackgroundTransparency = 0.05, TextColor3 = Theme.PrimaryText }, 1.06)

--============================================================
--// COMPOSER
--============================================================
local InputBar = create("Frame", {
    Name = "InputBar", Position = UDim2.new(0, 0, 1, -INPUT_HEIGHT), Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Active = true, ZIndex = 8,
}, Content)
corner(InputBar, 13)
local InputStroke = stroke(InputBar, Theme.Border, 1, 0.05)

local PlusButton = create("ImageButton", {
    Name = "AddButton", Position = UDim2.new(0, 10, 0.5, -17), Size = UDim2.fromOffset(33, 34),
    BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1, BorderSizePixel = 0,
    Image = Icons.Plus, ImageColor3 = Theme.MutedText, AutoButtonColor = false, ZIndex = 10,
}, InputBar)
corner(PlusButton, 9)
bindSoftButton(PlusButton, { BackgroundTransparency = 0.1, ImageColor3 = Theme.PrimaryText }, 1.07)

local EffortButton = create("TextButton", {
    Name = "EffortButton", Position = UDim2.new(0, 48, 0.5, -14), Size = UDim2.fromOffset(30, 28),
    BackgroundColor3 = Theme.PanelRaised, BackgroundTransparency = 0.1, BorderSizePixel = 0,
    Text = "◈", TextColor3 = Theme.Accent, Font = Theme.FontBold, TextSize = 15, AutoButtonColor = false, ZIndex = 10,
}, InputBar)
corner(EffortButton, 8)
stroke(EffortButton, Theme.Accent, 1, 0.6)
bindSoftButton(EffortButton, { BackgroundTransparency = 0, TextColor3 = Theme.AccentHover }, 1.06)

local InputBox = create("TextBox", {
    Name = "MessageInput", Position = UDim2.new(0, 84, 0, 0), Size = UDim2.new(1, -178, 1, 0),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "Message Dr4gonik Hub...", PlaceholderColor3 = Theme.QuietText,
    TextColor3 = Theme.PrimaryText, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    Font = Theme.Font, TextSize = 13, ClearTextOnFocus = false, MultiLine = false, TextWrapped = false, ZIndex = 10,
}, InputBar)

local ComposerMoreBtn = create("TextButton", {
    Name = "ComposerMoreButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -49, 0.5, 0),
    Size = UDim2.fromOffset(29, 30), BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1,
    BorderSizePixel = 0, Text = "···", TextColor3 = Theme.MutedText, Font = Theme.FontBold,
    TextSize = 17, AutoButtonColor = false, ZIndex = 10,
}, InputBar)
corner(ComposerMoreBtn, 8)
bindSoftButton(ComposerMoreBtn, { BackgroundTransparency = 0.08, TextColor3 = Theme.PrimaryText }, 1.06)

local SendBtn = create("ImageButton", {
    Name = "SendButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
    Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
    Image = Icons.Send, ImageColor3 = Theme.MutedText, AutoButtonColor = false, ZIndex = 11,
}, InputBar)
corner(SendBtn, 11)
local SendStroke = stroke(SendBtn, Theme.Accent, 1, 1)
local SendScale = create("UIScale", { Scale = 1 }, SendBtn)
AI.StopGlyph = create("TextLabel", {
    Name = "StopGlyph", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "■", TextColor3 = Theme.White, Font = Theme.FontBold, TextSize = 15,
    Visible = false, ZIndex = 13,
}, SendBtn)

--============================================================
--// EFFORT SLIDER POPUP
--============================================================
local EffortPopup = create("Frame", {
    Name = "EffortPopup", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 48, 1, -(INPUT_HEIGHT + 8)),
    Size = UDim2.fromOffset(280, 112), BackgroundColor3 = Theme.PanelRaised, BorderSizePixel = 0, Visible = false, ZIndex = 31,
}, Content)
corner(EffortPopup, 12)
stroke(EffortPopup, Theme.Border, 1, 0.05)
local effortPopupScale = create("UIScale", { Scale = 1 }, EffortPopup)

create("TextLabel", {
    Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1,
    Text = "Thinking Effort", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32,
}, EffortPopup)

local effortLevelNames = { "Minimal", "Low", "Medium", "High", "Maximum" }
local effortIndex = 3
for i, name in ipairs(effortLevelNames) do if name == AI.Effort then effortIndex = i end end

local EffortColors = {
    Color3.fromRGB(77, 132, 255), Color3.fromRGB(105, 124, 255),
    Color3.fromRGB(145, 112, 255), Color3.fromRGB(190, 105, 241), Color3.fromRGB(231, 115, 213),
}
local EffortGradients = {
    ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(77, 132, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(103, 154, 255)) }),
    ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(77, 132, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 125, 255)) }),
    ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(77, 132, 255)), ColorSequenceKeypoint.new(0.72, Color3.fromRGB(138, 115, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 112, 255)) }),
    ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(77, 132, 255)), ColorSequenceKeypoint.new(0.48, Color3.fromRGB(132, 115, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 112, 226)) }),
    ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(77, 132, 255)), ColorSequenceKeypoint.new(0.38, Color3.fromRGB(128, 113, 255)), ColorSequenceKeypoint.new(0.72, Color3.fromRGB(196, 105, 239)), ColorSequenceKeypoint.new(1, Color3.fromRGB(242, 125, 204)) }),
}

local sliderTrackBg = create("Frame", {
    Position = UDim2.new(0, 18, 0, 44), Size = UDim2.new(1, -36, 0, 6),
    BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 32,
}, EffortPopup)
corner(sliderTrackBg, 3)
local sliderFill = create("Frame", {
    Size = UDim2.new((effortIndex - 1) / (#effortLevelNames - 1), 0, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 33,
}, sliderTrackBg)
corner(sliderFill, 3)
local sliderEffortGradient = create("UIGradient", { Rotation = 0, Color = EffortGradients[effortIndex] }, sliderFill)
local sliderKnob = create("Frame", {
    Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new((effortIndex - 1) / (#effortLevelNames - 1), 0, 0.5, 0),
    Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 34,
}, sliderTrackBg)
corner(sliderKnob, 8)
local sliderKnobStroke = create("UIStroke", {
    Color = EffortColors[effortIndex], Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, sliderKnob)

local tickLabels = {}
for i, name in ipairs(effortLevelNames) do
    local xPos = (i - 1) / (#effortLevelNames - 1)
    local anchorX = (i == 1 and 0) or (i == #effortLevelNames and 1) or 0.5
    local labelPosition
    if i == 1 then labelPosition = UDim2.new(0, 12, 0, 62)
    elseif i == #effortLevelNames then labelPosition = UDim2.new(1, -12, 0, 62)
    else labelPosition = UDim2.new(xPos, 0, 0, 62) end
    tickLabels[i] = create("TextLabel", {
        AnchorPoint = Vector2.new(anchorX, 0), Position = labelPosition,
        Size = UDim2.fromOffset(62, 14), BackgroundTransparency = 1,
        Text = name, TextColor3 = i == effortIndex and Theme.PrimaryText or Theme.MutedText,
        Font = i == effortIndex and Theme.FontBold or Theme.Font, TextSize = 9,
        TextXAlignment = (i == 1 and Enum.TextXAlignment.Left) or (i == #effortLevelNames and Enum.TextXAlignment.Right) or Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None, ZIndex = 33,
    }, EffortPopup)
end

setEffortIndex = function(i)
    local requestedIndex = math.clamp(math.floor(tonumber(i) or effortIndex), 1, #effortLevelNames)
    local changed = requestedIndex ~= effortIndex
    effortIndex = requestedIndex
    local alpha = (effortIndex - 1) / (#effortLevelNames - 1)
    tween(sliderFill, { Size = UDim2.new(alpha, 0, 1, 0) }, 0.22, Enum.EasingStyle.Quint)
    tween(sliderKnob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, 0.22, Enum.EasingStyle.Quint)
    sliderEffortGradient.Color = EffortGradients[effortIndex]
    tween(sliderKnobStroke, { Color = EffortColors[effortIndex] }, 0.22, Enum.EasingStyle.Quad)
    for idx, lbl in ipairs(tickLabels) do
        local active = idx == effortIndex
        tween(lbl, { TextColor3 = active and Theme.PrimaryText or Theme.MutedText }, 0.18)
        lbl.Font = active and Theme.FontBold or Theme.Font
    end
    AI.Effort = effortLevelNames[effortIndex]
    if changed then debugTrace("INFO", "Effort → " .. AI.Effort) end
    saveSettings()
end
sliderEffortGradient.Color = EffortGradients[effortIndex]
sliderKnobStroke.Color = EffortColors[effortIndex]

local sliderDragging = false
local function updateFromPointer(px)
    local trackX = sliderTrackBg.AbsolutePosition.X
    local trackW = sliderTrackBg.AbsoluteSize.X
    if trackW <= 0 then return end
    local rel = math.clamp((px - trackX) / trackW, 0, 1)
    local idx = math.floor(rel * (#effortLevelNames - 1) + 0.5) + 1
    if idx ~= effortIndex then setEffortIndex(idx) end
end
sliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderDragging = true end
end)
sliderTrackBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        updateFromPointer(UserInputService:GetMouseLocation().X)
        sliderDragging = true
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not sliderDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateFromPointer(input.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderDragging = false end
end)

local function toggleEffortPopup(show)
    if show == nil then show = not EffortPopup.Visible end
    EffortPopup.Visible = show
    if show then
        effortPopupScale.Scale = 0.9
        tween(effortPopupScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back)
    end
end
EffortButton.MouseButton1Click:Connect(function() toggleEffortPopup() end)

--============================================================
--// MENUS
--============================================================
local MenuBackdrop = create("TextButton", {
    Name = "MenuBackdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 30,
}, MainFrame)
local OptionsMenu = create("Frame", {
    Name = "OptionsMenu", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -(FOOTER_HEIGHT + 8)),
    Size = UDim2.fromOffset(198, 106), BackgroundColor3 = Theme.PanelRaised, BorderSizePixel = 0, Visible = false, ZIndex = 31,
}, MainFrame)
corner(OptionsMenu, 11)
stroke(OptionsMenu, Theme.Border, 1, 0.05)
local menuScale = create("UIScale", { Scale = 1 }, OptionsMenu)
create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, OptionsMenu)
padding(OptionsMenu, 6, 6, 6, 6)

local menuMode = nil
local activeConversationMenuId = nil
local menuItems = {}
local createNewConversation, clearCurrentConversation, clearConversationById, deleteConversationById

setMenuOpen = function(mode, conversationId)
    if mode == nil then
        menuMode = nil; activeConversationMenuId = nil
        MenuBackdrop.Visible = false; OptionsMenu.Visible = false
        return
    end
    if menuMode == mode and (mode ~= "conversation" or activeConversationMenuId == conversationId) then
        menuMode = nil; activeConversationMenuId = nil
        MenuBackdrop.Visible = false; OptionsMenu.Visible = false
        return
    end
    menuMode = mode
    activeConversationMenuId = mode == "conversation" and conversationId or nil

    local labels
    if mode == "conversation" then
        local row = conversationRows[conversationId]
        if not row then setMenuOpen(nil) return end
        local menuWidth = math.min(198, sidebarWidth - 24)
        local menuHeight = 111
        OptionsMenu.AnchorPoint = Vector2.new(0, 0)
        OptionsMenu.Size = UDim2.fromOffset(menuWidth, menuHeight)
        local mainTop = MainFrame.AbsolutePosition.Y
        local rowTop = row.AbsolutePosition.Y - mainTop
        local y = rowTop + row.AbsoluteSize.Y + 4
        local maxY = math.max(8, MainFrame.AbsoluteSize.Y - menuHeight - 8)
        if y > maxY then y = rowTop - menuHeight - 4 end
        y = math.clamp(y, 8, maxY)
        OptionsMenu.Position = UDim2.fromOffset(8, y)
        labels = { "Clear conversation", "New conversation", "Delete conversation" }
    elseif mode == "composer" or mode == "plus" then
        OptionsMenu.AnchorPoint = Vector2.new(1, 1)
        OptionsMenu.Position = UDim2.new(1, -16, 1, -(INPUT_HEIGHT + 26))
        OptionsMenu.Size = UDim2.fromOffset(198, mode == "plus" and 84 or 112)
        if mode == "plus" then labels = { "Insert code block", "Clear draft" }
        else labels = { "Clear conversation", "New conversation", "Insert code block" } end
    else
        OptionsMenu.AnchorPoint = Vector2.new(0, 1)
        OptionsMenu.Position = UDim2.new(0, 16, 1, -(FOOTER_HEIGHT + 8))
        OptionsMenu.Size = UDim2.fromOffset(198, 118)
        labels = { "New conversation", "Settings", "Hide window" }
    end
    for index, item in ipairs(menuItems) do
        local itemVisible = labels[index] ~= nil
        item.Visible = itemVisible
        item.Size = UDim2.new(1, 0, 0, itemVisible and 31 or 0)
        item.Text = labels[index] or ""
        item.LayoutOrder = index
    end
    MenuBackdrop.Visible = true
    OptionsMenu.Visible = true
    menuScale.Scale = 0.94
    tween(menuScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back)
end

local function performMenuAction(index)
    local mode = menuMode
    local targetConversationId = activeConversationMenuId
    setMenuOpen(nil)
    if mode == "conversation" then
        if index == 1 and clearConversationById then clearConversationById(targetConversationId)
        elseif index == 2 and createNewConversation then createNewConversation()
        elseif index == 3 and deleteConversationById then deleteConversationById(targetConversationId) end
    elseif mode == "profile" then
        if index == 1 and createNewConversation then createNewConversation()
        elseif index == 2 then
            -- Share the same exclusive-navigation path as the sidebar button.
            if AI.OpenSettingsView then AI.OpenSettingsView() end
        elseif index == 3 then ScreenGui.Enabled = false end
    elseif mode == "plus" then
        if index == 1 then
            local draft = InputBox.Text
            InputBox.Text = draft == "" and "```lua\n\n```" or ("```lua\n" .. draft .. "\n```")
            InputBox:CaptureFocus()
        elseif index == 2 then InputBox.Text = "" end
    else
        if index == 1 and clearCurrentConversation then clearCurrentConversation()
        elseif index == 2 and createNewConversation then createNewConversation()
        elseif index == 3 then
            local draft = InputBox.Text
            InputBox.Text = draft == "" and "```lua\n\n```" or ("```lua\n" .. draft .. "\n```")
            InputBox:CaptureFocus()
        end
    end
end

for i = 1, 3 do
    local item = create("TextButton", {
        Name = "MenuItem" .. i, Size = UDim2.new(1, 0, 0, 31), BackgroundColor3 = Theme.Hover,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", TextColor3 = Theme.PrimaryText,
        Font = Theme.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, LayoutOrder = i, Visible = false, ZIndex = 32,
    }, OptionsMenu)
    corner(item, 7)
    padding(item, 10, 8, 0, 0)
    bindSoftButton(item, { BackgroundTransparency = 0.1 }, 1.01)
    item.MouseButton1Click:Connect(function() performMenuAction(i) end)
    menuItems[i] = item
end

MenuBackdrop.MouseButton1Click:Connect(function() setMenuOpen(nil) end)
ProfileOptionsBtn.MouseButton1Click:Connect(function() setMenuOpen("profile") end)
ComposerMoreBtn.MouseButton1Click:Connect(function() setMenuOpen("composer") end)
PlusButton.MouseButton1Click:Connect(function() setMenuOpen("plus") end)

--[[GITHUB_MODULE:AIRequest.lua]]

--============================================================
--// CONVERSATION ACTIONS
--============================================================
createNewConversation = function()
    local id = "conversation_" .. tostring(os.clock()):gsub("%.", "")
    local conv = { id = id, title = "New conversation", history = {} }
    table.insert(conversations, 1, conv)
    refreshConversationOrder()
    showConversation(id)
    if EmptyChatLabel then EmptyChatLabel.Text = "A fresh start.\n\nType a message below to begin." end
    pcall(function()
        if AI.SaveHistory and writefile then writefile(CONVOS_FILE, HttpService:JSONEncode(conversations)) end
    end)
    if activeView == "settings" then
        -- A new conversation should switch through the same tab state machine,
        -- rather than showing Chat while leaving another workspace tab visible.
        if setActiveTab then
            setActiveTab("Chat")
        else
            activeView = "chat"
            activeTab = "Chat"
            if AI.UpdateUIForTab then AI.UpdateUIForTab("Chat") end
        end
    end
end

clearConversationById = function(id)
    local conv = getConversation(id)
    if not conv then return end
    conv.history = {}
    if id == selectedConversationId then
        clearRenderedMessages()
        chatHasContent = false
        if EmptyChatLabel then
            EmptyChatLabel.Visible = true
            EmptyChatLabel.Text = "Conversation cleared.\n\nType a message below to begin again."
        end
    end
    pcall(function()
        if AI.SaveHistory and writefile then writefile(CONVOS_FILE, HttpService:JSONEncode(conversations)) end
    end)
end

clearCurrentConversation = function() clearConversationById(selectedConversationId) end

deleteConversationById = function(id)
    if not id then return end
    local removedIndex
    for i, conv in ipairs(conversations) do
        if conv.id == id then removedIndex = i; table.remove(conversations, i); break end
    end
    if not removedIndex then return end
    local row = conversationRows[id]
    if row then row:Destroy() end
    conversationRows[id] = nil; conversationButtons[id] = nil; conversationOptions[id] = nil
    local removedSelected = selectedConversationId == id
    if removedSelected then
        selectedConversationId = nil
        clearRenderedMessages()
        chatHasContent = false
        if ChatTitle then ChatTitle.Text = "Dr4gonik Hub" end
        if EmptyChatLabel then
            EmptyChatLabel.Visible = true
            EmptyChatLabel.Text = "Conversation deleted."
        end
    end
    refreshConversationOrder()
    if removedSelected and #conversations > 0 then
        showConversation(conversations[math.clamp(removedIndex, 1, #conversations)].id)
    end
    pcall(function()
        if AI.SaveHistory and writefile then writefile(CONVOS_FILE, HttpService:JSONEncode(conversations)) end
    end)
end

NewConvoBtn.MouseButton1Click:Connect(createNewConversation)

--============================================================
--// TABS
--============================================================
AI.UpdateUIForTab = function(tab)
    -- Hide every sibling content root first. This prevents stale tab surfaces
    -- from remaining visible underneath Settings regardless of which button or
    -- menu action opened it.
    if SettingsView then SettingsView.Visible = false end
    if ScriptUI and ScriptUI.View then ScriptUI.View.Visible = false end
    if CodeEditorFrame then CodeEditorFrame.Visible = false end
    if ChatDisplay then ChatDisplay.Visible = false end
    if EmptyChatLabel then EmptyChatLabel.Visible = false end
    if InputBar then InputBar.Visible = false end

    if activeView == "settings" then
        if SettingsView then SettingsView.Visible = true end
        return
    end

    if tab == "Scripts" then
        if ScriptUI and ScriptUI.View then ScriptUI.View.Visible = true end
        if ScriptUI and ScriptUI.refreshCards then ScriptUI.refreshCards() end
    elseif tab == "Code" then
        if CodeEditorFrame then CodeEditorFrame.Visible = true end
    elseif tab == "Chat" then
        if ChatDisplay then ChatDisplay.Visible = true end
        if EmptyChatLabel then EmptyChatLabel.Visible = not chatHasContent end
        if InputBar then InputBar.Visible = true end
    end
end

AI.OpenSettingsView = function()
    activeView = "settings"
    if setMenuOpen then setMenuOpen(nil) end
    if toggleEffortPopup then toggleEffortPopup(false) end
    if AI.UpdateUIForTab then AI.UpdateUIForTab(activeTab) end
    if ChatTitle then ChatTitle.Text = "Settings" end
    if ChatSub then ChatSub.Text = "Customize your workspace" end
end

setActiveTab = function(name)
    local wasInSettings = activeView == "settings"
    activeTab = name
    if wasInSettings then
        activeView = "chat"
        local conversation = currentConversation()
        if ChatTitle then
            ChatTitle.Text = conversation and conversation.title or (name == "Code" and "Code workspace" or (name == "Scripts" and "Script library" or "Dr4gonik Hub"))
        end
    end
    local index = name == "Scripts" and 1 or (name == "Chat" and 2 or 3)
    tween(TabIndicator, { Position = UDim2.new((index - 1) / 3, 3, 0, 3) }, 0.24, Enum.EasingStyle.Quint)
    for tabName, button in pairs(tabButtons) do
        local isActive = tabName == name
        tween(button, { TextColor3 = isActive and Theme.PrimaryText or Theme.MutedText }, 0.14)
        button.Font = isActive and Theme.FontBold or Theme.Font
    end
    if ChatSub then
        ChatSub.Text = (name == "Scripts" and "Script library") or (name == "Chat" and "A focused conversation") or "Code workspace"
    end
    AI.UpdateUIForTab(name)
end

CoworkTab.MouseButton1Click:Connect(function() setActiveTab("Scripts") end)
ChatTab.MouseButton1Click:Connect(function() setActiveTab("Chat") end)
CodeTab.MouseButton1Click:Connect(function() setActiveTab("Code") end)

--============================================================
--// SIDEBAR AFFORDANCES
--============================================================
AI.SearchOpen = false
SearchButton.MouseButton1Click:Connect(function()
    AI.SearchOpen = not AI.SearchOpen
    if AI.SearchOpen then
        InputBox.PlaceholderText = "Search conversations or type a message..."
        InputBox:CaptureFocus()
    else
        InputBox.PlaceholderText = "Message Dr4gonik Hub..."
        InputBox:ReleaseFocus()
    end
end)
FilesButton.MouseButton1Click:Connect(function()
    if EmptyChatLabel then
        EmptyChatLabel.Text = "Files workspace\n\nConnect a file picker or upload flow to add files here."
        EmptyChatLabel.Visible = not chatHasContent
    end
end)
MenuButton.MouseButton1Click:Connect(function() setMenuOpen("profile") end)
BackButton.MouseButton1Click:Connect(function()
    local currentIndex = 1
    for i, conv in ipairs(conversations) do if conv.id == selectedConversationId then currentIndex = i break end end
    local prev = conversations[math.min(#conversations, currentIndex + 1)]
    if prev then showConversation(prev.id) end
end)
ForwardButton.MouseButton1Click:Connect(function()
    local currentIndex = 1
    for i, conv in ipairs(conversations) do if conv.id == selectedConversationId then currentIndex = i break end end
    local prev = conversations[math.max(1, currentIndex - 1)]
    if prev then showConversation(prev.id) end
end)
SettingsButton.MouseButton1Click:Connect(function()
    AI.OpenSettingsView()
end)
FoldersButton.MouseButton1Click:Connect(function()
    if EmptyChatLabel then
        EmptyChatLabel.Text = "Conversation folders\n\nYour folders can be connected here."
        EmptyChatLabel.Visible = not chatHasContent
    end
end)

--============================================================
--// WINDOW CONTROLS
--============================================================
local WindowState = { state = "normal", normalSize = WINDOW_SIZE, normalPosition = WINDOW_POSITION }

WindowState.setBodyVisible = function(visible)
    if Footer then Footer.Visible = visible end
    if SidebarScroll then SidebarScroll.Visible = visible end
    if visible then AI.UpdateUIForTab(activeTab)
    else
        if ChatDisplay then ChatDisplay.Visible = false end
        if InputBar then InputBar.Visible = false end
        if EmptyChatLabel then EmptyChatLabel.Visible = false end
        if CodeEditorFrame then CodeEditorFrame.Visible = false end
        if SettingsView then SettingsView.Visible = false end
    end
end

WindowState.setState = function(newState)
    local previousState = WindowState.state
    if previousState == "normal" and newState ~= "normal" then
        WindowState.normalSize = MainFrame.Size
        WindowState.normalPosition = MainFrame.Position
    end
    WindowState.state = newState
    setMenuOpen(nil)
    toggleEffortPopup(false)
    WindowState.setBodyVisible(newState ~= "minimized")
    if newState == "normal" then
        local goal = { Size = WindowState.normalSize }
        if previousState == "maximized" then goal.Position = WindowState.normalPosition end
        tween(MainFrame, goal, 0.22)
    elseif newState == "minimized" then
        tween(MainFrame, {
            Size = UDim2.fromOffset(WindowState.normalSize.X.Offset, MINIMIZED_HEIGHT),
            Position = previousState == "maximized" and WindowState.normalPosition or MainFrame.Position,
        }, 0.22)
    else
        local vp = viewportSize()
        tween(MainFrame, {
            Size = UDim2.fromOffset(math.max(420, vp.X - 32), math.max(300, vp.Y - 32)),
            Position = UDim2.fromOffset(16, 16),
        }, 0.22)
    end
end

MinBtn.MouseButton1Click:Connect(function() WindowState.setState(WindowState.state == "minimized" and "normal" or "minimized") end)
MaxBtn.MouseButton1Click:Connect(function() WindowState.setState(WindowState.state == "maximized" and "normal" or "maximized") end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

--============================================================
--// DIVIDER
--============================================================
WindowState.resizing = false
WindowState.resizeStartX = 0
WindowState.resizeStartWidth = sidebarWidth
WindowState.dividerHovered = false

DividerHitbox.MouseEnter:Connect(function() WindowState.dividerHovered = true; tween(DividerLine, { BackgroundColor3 = Theme.Accent }, 0.14) end)
DividerHitbox.MouseLeave:Connect(function()
    WindowState.dividerHovered = false
    if not WindowState.resizing then tween(DividerLine, { BackgroundColor3 = Theme.Border }, 0.14) end
end)
DividerHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        WindowState.resizing = true
        WindowState.resizeStartX = input.UserInputType == Enum.UserInputType.Touch and input.Position.X or UserInputService:GetMouseLocation().X
        WindowState.resizeStartWidth = sidebarWidth
        tween(DividerLine, { BackgroundColor3 = Theme.Accent }, 0.1)
    end
end)

--============================================================
--// DRAG
-- The script already approaches Lua's active-local limit. Keep drag state in
-- RuntimeDiagnostics instead of adding more top-level locals.
--============================================================
RuntimeDiagnostics.Dragging = false
RuntimeDiagnostics.DragPointerType = nil
RuntimeDiagnostics.DragStartPointer = Vector2.new(0, 0)
RuntimeDiagnostics.DragStartAbsolute = Vector2.new(0, 0)
RuntimeDiagnostics.DragStartPosition = MainFrame.Position
RuntimeDiagnostics.DragTargetPos = MainFrame.Position

RuntimeDiagnostics.GetPointerPosition = function(input)
    if input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y) end
    return UserInputService:GetMouseLocation()
end

TitleGroup.InputBegan:Connect(function(input)
    if not ScreenGui.Enabled or WindowState.state == "maximized" or WindowState.resizing then return end
    local it = input.UserInputType
    if it ~= Enum.UserInputType.MouseButton1 and it ~= Enum.UserInputType.Touch then return end
    RuntimeDiagnostics.DragStartPointer = RuntimeDiagnostics.GetPointerPosition(input)
    RuntimeDiagnostics.DragStartAbsolute = MainFrame.AbsolutePosition
    RuntimeDiagnostics.DragStartPosition = MainFrame.Position
    RuntimeDiagnostics.DragTargetPos = MainFrame.Position
    RuntimeDiagnostics.Dragging = true
    RuntimeDiagnostics.DragPointerType = it
end)

UserInputService.InputChanged:Connect(function(input)
    if not ScreenGui.Enabled then return end
    local it = input.UserInputType
    local isMove = it == Enum.UserInputType.MouseMovement
    local isTouchMove = it == Enum.UserInputType.Touch
    if not isMove and not isTouchMove then return end
    local pointer = RuntimeDiagnostics.GetPointerPosition(input)
    if WindowState.resizing then setSidebarWidth(WindowState.resizeStartWidth + (pointer.X - WindowState.resizeStartX)); return end
    if not RuntimeDiagnostics.Dragging then return end
    local matching = (RuntimeDiagnostics.DragPointerType == Enum.UserInputType.MouseButton1 and isMove) or (RuntimeDiagnostics.DragPointerType == Enum.UserInputType.Touch and isTouchMove)
    if not matching then return end
    local delta = pointer - RuntimeDiagnostics.DragStartPointer
    local vp = viewportSize()
    local frameSize = MainFrame.AbsoluteSize
    local startAbsolute = RuntimeDiagnostics.DragStartAbsolute
    local targetX = math.clamp(startAbsolute.X + delta.X, 0, math.max(0, vp.X - frameSize.X))
    local targetY = math.clamp(startAbsolute.Y + delta.Y, 0, math.max(0, vp.Y - frameSize.Y))
    local startPosition = RuntimeDiagnostics.DragStartPosition
    RuntimeDiagnostics.DragTargetPos = UDim2.new(
        startPosition.X.Scale, startPosition.X.Offset + targetX - startAbsolute.X,
        startPosition.Y.Scale, startPosition.Y.Offset + targetY - startAbsolute.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    local it = input.UserInputType
    if it == Enum.UserInputType.MouseButton1 or it == Enum.UserInputType.Touch then
        if RuntimeDiagnostics.Dragging then
            MainFrame.Position = RuntimeDiagnostics.DragTargetPos
            RuntimeDiagnostics.Dragging = false
            RuntimeDiagnostics.DragPointerType = nil
        end
        if WindowState.resizing then
            WindowState.resizing = false
            tween(DividerLine, { BackgroundColor3 = WindowState.dividerHovered and Theme.Accent or Theme.Border }, 0.14)
        end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if RuntimeDiagnostics.Dragging then
        local alpha = math.min(dt * 15, 1)
        MainFrame.Position = MainFrame.Position:Lerp(RuntimeDiagnostics.DragTargetPos, alpha)
    end
end)

--============================================================
--// INITIAL STATE
--============================================================
setSidebarWidth(SIDEBAR_START)
refreshConversationStyles()
AI.RefreshSendButton()

if selectedConversationId then
    showConversation(selectedConversationId)
elseif #conversations > 0 then
    showConversation(conversations[1].id)
else
    if ChatTitle then ChatTitle.Text = "Dr4gonik Hub" end
    if EmptyChatLabel then
        EmptyChatLabel.Text = "Welcome to Dr4gonik Hub.\n\nStart a new conversation or type a message below."
        EmptyChatLabel.Visible = true
    end
    chatHasContent = false
end
setActiveTab("Scripts")
ScriptUI.refreshCards()
debugTrace("INFO", "UI boot complete · theme=" .. ThemeEngine.CurrentThemeName ..
    " · provider=" .. AI.Provider .. " · model=" .. AI.Model ..
    " · autoExec=" .. tostring(AI.AutoExecute))
