--============================================================
--// SETTINGS VIEW
--============================================================
local SettingsView
local setEffortIndex
local ProviderDropdownMenu, closeProviderDropdown, closeThemeDropdown
local AISettingsScroll, ThemeSettingsScroll
local setSettingsTab
local themeAdvancedControls
local themeSimpleButton, themeAdvancedButton, themeGlassButton, themeTransparencyInput, themeGlossInput
local themeGradientButton, themeGradientRotationInput, themeGradientStrengthInput
local themeGradientStartButton, themeGradientEndButton
local GradientColorPicker, GradientColorPickerBackdrop
local function refreshThemeControls() end
do
SettingsView = create("Frame", {
    Name = "SettingsView", Position = UDim2.new(0, 0, 0, UIRefs.CHAT_TOP),
    Size = UDim2.new(1, 0, 1, -(UIRefs.CHAT_TOP + UIRefs.CHAT_BOTTOM_GAP)), BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 5,
}, UIRefs.Content)

local SettingsTabs = create("Frame", {
    Name = "SettingsTabs", Position = UDim2.new(0, 12, 0, 2), Size = UDim2.new(1, -24, 0, 38),
    BackgroundColor3 = Theme.SegmentedBg, BorderSizePixel = 0, ZIndex = 6,
}, SettingsView)
corner(SettingsTabs, 10)
local function makeTabButton(title, x, width)
    local button = create("TextButton", {
        Size = UDim2.new(width, -4, 1, -4), Position = UDim2.new(x, 2, 0, 2),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = title, TextColor3 = Theme.MutedText, Font = Theme.FontBold, TextSize = 12,
        AutoButtonColor = false, ZIndex = 7,
    }, SettingsTabs)
    corner(button, 8)
    return button
end
local AITabButton = makeTabButton("AI Settings", 0, 0.5)
local ThemeTabButton = makeTabButton("Theme Settings", 0.5, 0.5)

local function makeSettingsScroller(name)
    local scroll = create("ScrollingFrame", {
        Name = name, Position = UDim2.new(0, 0, 0, 48), Size = UDim2.new(1, 0, 1, -48),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false, ZIndex = 5,
    }, SettingsView)
    styleScrollBar(scroll)
    create("UIListLayout", { Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    padding(scroll, 12, 12, 4, 12)
    return scroll
end
AISettingsScroll = makeSettingsScroller("AISettingsScroll")
ThemeSettingsScroll = makeSettingsScroller("ThemeSettingsScroll")

setSettingsTab = function(tabName)
    local showTheme = tabName == "Theme"
    AISettingsScroll.Visible = not showTheme
    ThemeSettingsScroll.Visible = showTheme
    AITabButton.BackgroundTransparency = showTheme and 1 or 0
    AITabButton.TextColor3 = showTheme and Theme.MutedText or Theme.PrimaryText
    ThemeTabButton.BackgroundTransparency = showTheme and 0 or 1
    ThemeTabButton.TextColor3 = showTheme and Theme.PrimaryText or Theme.MutedText
    if closeProviderDropdown then closeProviderDropdown(false) end
    if closeThemeDropdown then closeThemeDropdown(false) end
end
AITabButton.MouseButton1Click:Connect(function() setSettingsTab("AI") end)
ThemeTabButton.MouseButton1Click:Connect(function() setSettingsTab("Theme") end)
setSettingsTab("AI")

local function makeSection(title, order, tab)
    local section = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 6,
    }, tab == "Theme" and ThemeSettingsScroll or AISettingsScroll)
    create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, section)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = title:upper(),
        TextColor3 = Theme.QuietText, Font = Theme.FontBold, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 7,
    }, section)
    return section
end

-- Appearance
local AppearanceSection = makeSection("Appearance", 1, "Theme")
local themeSelectWrapper = create("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 7 }, AppearanceSection)

local ThemeDropdownBtn = create("TextButton", {
    Name = "ThemeDropdownBtn", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0, Text = "  " .. themeDisplayNames[ThemeEngine.CurrentThemeName],
    TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, ZIndex = 8,
}, themeSelectWrapper)
corner(ThemeDropdownBtn, 10)
padding(ThemeDropdownBtn, 12, 36, 0, 0)
stroke(ThemeDropdownBtn, Theme.Border, 1, 0.4)
local ThemeChevron = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, ThemeEngine.DropdownChevronOffset, 0.5, 0),
    Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Theme.SegmentedBg,
    Text = "▼", TextColor3 = Theme.MutedText, Font = Theme.FontBold, TextSize = 9, ZIndex = 9,
}, ThemeDropdownBtn)
corner(ThemeChevron, 8)

local ThemeDropdownBackdrop = create("TextButton", {
    Name = "ThemeDropdownBackdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 90,
}, UIRefs.MainFrame)

local ThemeDropdownMenu = create("Frame", {
    Name = "ThemeDropdownMenu", Size = UDim2.fromOffset(200, 0), BackgroundColor3 = Theme.PanelRaised,
    BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 100,
}, UIRefs.MainFrame)
corner(ThemeDropdownMenu, 10)
stroke(ThemeDropdownMenu, Theme.Border, 1, 0.05)
create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, ThemeDropdownMenu)
padding(ThemeDropdownMenu, 6, 6, 6, 6)

local function updateThemeMenuButtons()
    for _, btn in pairs(ThemeDropdownMenu:GetChildren()) do
        if btn:IsA("TextButton") then
            local tName = btn:GetAttribute("ThemeName")
            if tName then
                btn.TextColor3 = tName == ThemeEngine.CurrentThemeName and Theme.Accent or Theme.PrimaryText
                btn.Font = tName == ThemeEngine.CurrentThemeName and Theme.FontBold or Theme.Font
            end
        end
    end
end

for i, name in ipairs(themeOrder) do
    local opt = create("TextButton", {
        Name = "Theme_" .. name, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Theme.Hover,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "  " .. themeDisplayNames[name],
        TextColor3 = name == ThemeEngine.CurrentThemeName and Theme.Accent or Theme.PrimaryText,
        Font = name == ThemeEngine.CurrentThemeName and Theme.FontBold or Theme.Font, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i, ZIndex = 101,
    }, ThemeDropdownMenu)
    opt:SetAttribute("ThemeName", name)
    corner(opt, 7)
    padding(opt, 10, 8, 0, 0)
    bindSoftButton(opt, { BackgroundTransparency = 0.1 }, 1.01)
    opt.MouseButton1Click:Connect(function()
        setTheme(name)
        ThemeDropdownBtn.Text = "  " .. themeDisplayNames[name]
        updateThemeMenuButtons()
        if closeThemeDropdown then closeThemeDropdown(true) end
    end)
end

local menuOpen = false
closeThemeDropdown = function(animate)
    if not menuOpen and not ThemeDropdownMenu.Visible then return end
    menuOpen = false
    if animate then
        tween(ThemeChevron, { Rotation = 0 }, 0.14, Enum.EasingStyle.Quint)
    else
        ThemeChevron.Rotation = 0
    end
    ThemeDropdownBackdrop.Visible = false
    if animate and ThemeDropdownMenu.Visible then
        local closing = tween(ThemeDropdownMenu, {
            Size = UDim2.new(0, ThemeDropdownMenu.AbsoluteSize.X, 0, 0),
            BackgroundTransparency = 1,
        }, 0.14, Enum.EasingStyle.Quint)
        if closing then
            closing.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and not menuOpen then ThemeDropdownMenu.Visible = false end
            end)
        else
            ThemeDropdownMenu.Visible = false
        end
    else
        ThemeDropdownMenu.Visible = false
        ThemeDropdownMenu.BackgroundTransparency = 1
    end
end

local function openThemeDropdown()
    if closeProviderDropdown then closeProviderDropdown(false) end
    menuOpen = true
    tween(ThemeChevron, { Rotation = 180 }, 0.2, Enum.EasingStyle.Quint)
    local absPos = ThemeDropdownBtn.AbsolutePosition
    local absSize = ThemeDropdownBtn.AbsoluteSize
    local mainAbsPos = UIRefs.MainFrame.AbsolutePosition
    ThemeDropdownMenu.Position = UDim2.fromOffset(absPos.X - mainAbsPos.X, absPos.Y - mainAbsPos.Y + absSize.Y + 4)
    ThemeDropdownMenu.Size = UDim2.fromOffset(absSize.X, 0)
    ThemeDropdownMenu.BackgroundTransparency = 1
    ThemeDropdownMenu.Visible = true
    ThemeDropdownBackdrop.Visible = true
    updateThemeMenuButtons()
    tween(ThemeDropdownMenu, {
        Size = UDim2.fromOffset(absSize.X, #themeOrder * 34 + 12), BackgroundTransparency = 0,
    }, 0.2, Enum.EasingStyle.Quint)
end

ThemeDropdownBtn.MouseButton1Click:Connect(function()
    if menuOpen then closeThemeDropdown(true) else openThemeDropdown() end
end)
ThemeDropdownBackdrop.MouseButton1Click:Connect(function()
    closeThemeDropdown(true)
end)
ThemeSettingsScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if menuOpen then closeThemeDropdown(true) end
end)
AISettingsScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if ProviderDropdownMenu and ProviderDropdownMenu.Visible and closeProviderDropdown then
        closeProviderDropdown(true)
    end
end)

SettingsView:GetPropertyChangedSignal("Visible"):Connect(function()
    if not SettingsView.Visible and closeProviderDropdown then closeProviderDropdown(false) end
    if not SettingsView.Visible and menuOpen then closeThemeDropdown(false) end
end)

local function makeAppearanceLabel(text, order, parent)
    return create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text,
        TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 7,
    }, parent)
end

local function applySavedAppearance()
    ThemeEngine.setAppearanceSettings({
        Simple = AI.ThemeSimple,
        Advanced = AI.ThemeAdvanced,
        Glass = AI.ThemeGlass,
        Transparency = AI.ThemeTransparency,
        Gloss = AI.ThemeGloss,
        Gradient = AI.ThemeGradient,
        GradientRotation = AI.ThemeGradientRotation,
        GradientStrength = AI.ThemeGradientStrength,
        GradientStartRGB = AI.ThemeGradientStartRGB,
        GradientEndRGB = AI.ThemeGradientEndRGB,
    })
    saveSettings()
end

local function makeAppearanceModeRow(title, subtitle, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
        LayoutOrder = order, ZIndex = 7,
    }, AppearanceSection)
    corner(row, 10)
    stroke(row, Theme.Border, 1, 0.35)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -110, 0, 18), BackgroundTransparency = 1,
        Text = title, TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, row)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 29), Size = UDim2.new(1, -110, 0, 16), BackgroundTransparency = 1,
        Text = subtitle, TextColor3 = Theme.QuietText, Font = Theme.Font, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, row)
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(66, 28),
        BackgroundColor3 = Theme.SegmentedBg, BorderSizePixel = 0, Text = "OFF",
        TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 11,
        AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(button, 8)
    return button
end

themeSimpleButton = makeAppearanceModeRow("Simple appearance", "Apply the glass look with one setting.", 3)
themeAdvancedButton = makeAppearanceModeRow("Advanced appearance", "Customize glass, gloss, gradients, and colors.", 4)
themeSimpleButton.MouseButton1Click:Connect(function()
    AI.ThemeSimple = not AI.ThemeSimple
    if AI.ThemeSimple then AI.ThemeAdvanced = false end
    refreshThemeControls()
    applySavedAppearance()
end)
themeAdvancedButton.MouseButton1Click:Connect(function()
    AI.ThemeAdvanced = not AI.ThemeAdvanced
    if AI.ThemeAdvanced then AI.ThemeSimple = false end
    refreshThemeControls()
    applySavedAppearance()
end)

themeAdvancedControls = create("Frame", {
    Size = UDim2.new(1, 0, 0, AI.ThemeAdvanced and 320 or 0), BackgroundTransparency = 1, LayoutOrder = 5,
    Visible = AI.ThemeAdvanced, ZIndex = 7,
}, AppearanceSection)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, themeAdvancedControls)
local function makeAppearanceInput(title, value, order, placeholder)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 7 }, themeAdvancedControls)
    makeAppearanceLabel(title, 1, row).Size = UDim2.new(1, -105, 1, 0)
    local input = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(92, 28),
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = tostring(value),
        TextColor3 = Theme.PrimaryText, PlaceholderText = placeholder or "Enter value",
        Font = Theme.FontCode, TextSize = 11, ClearTextOnFocus = false, ZIndex = 8,
    }, row)
    corner(input, 7)
    stroke(input, Theme.Border, 1, 0.45)
    return input
end
local function makeAppearanceToggle(title, order)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 7 }, themeAdvancedControls)
    makeAppearanceLabel(title, 1, row).Size = UDim2.new(1, -105, 1, 0)
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(92, 26),
        BackgroundColor3 = Theme.SegmentedBg, BorderSizePixel = 0, Text = "OFF", TextColor3 = Theme.PrimaryText,
        Font = Theme.FontBold, TextSize = 11, AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(button, 7)
    return button
end
local function makeColorSelector(title, value, order)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 7 }, themeAdvancedControls)
    makeAppearanceLabel(title, 1, row).Size = UDim2.new(1, -105, 1, 0)
    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(92, 30),
        BackgroundColor3 = value, BorderSizePixel = 0, Text = "Choose", TextColor3 = Theme.PrimaryText,
        Font = Theme.FontBold, TextSize = 10, AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(chip, 8)
    stroke(chip, Theme.Border, 1, 0.2)
    return chip
end

themeGlassButton = makeAppearanceToggle("Glass effect", 1)
themeTransparencyInput = makeAppearanceInput("Transparency (%)", math.floor(AI.ThemeTransparency * 100 + 0.5), 2, "0–100")
themeGlossInput = makeAppearanceInput("Gloss (%)", math.floor(AI.ThemeGloss * 100 + 0.5), 3, "0–100")
themeGradientButton = makeAppearanceToggle("Gradient overlay", 4)
themeGradientRotationInput = makeAppearanceInput("Gradient direction (°)", AI.ThemeGradientRotation, 5, "0–360")
themeGradientStrengthInput = makeAppearanceInput("Gradient strength (%)", math.floor(AI.ThemeGradientStrength * 100 + 0.5), 6, "0–100")
themeGradientStartButton = makeColorSelector("Gradient start color", Color3.new(1, 1, 1), 7)
themeGradientEndButton = makeColorSelector("Gradient end color", Color3.fromRGB(224, 228, 240), 8)

themeGlassButton.MouseButton1Click:Connect(function()
    AI.ThemeGlass = not AI.ThemeGlass
    refreshThemeControls()
    applySavedAppearance()
end)
themeGradientButton.MouseButton1Click:Connect(function()
    AI.ThemeGradient = not AI.ThemeGradient
    refreshThemeControls()
    applySavedAppearance()
end)

local function bindPercentInput(input, key)
    input.FocusLost:Connect(function()
        local value = tonumber(input.Text)
        if not value then value = AI[key] * 100 end
        AI[key] = math.clamp(value, 0, 100) / 100
        input.Text = tostring(math.floor(AI[key] * 100 + 0.5))
        applySavedAppearance()
    end)
end
bindPercentInput(themeTransparencyInput, "ThemeTransparency")
bindPercentInput(themeGlossInput, "ThemeGloss")
bindPercentInput(themeGradientStrengthInput, "ThemeGradientStrength")
themeGradientRotationInput.FocusLost:Connect(function()
    local value = tonumber(themeGradientRotationInput.Text) or AI.ThemeGradientRotation
    AI.ThemeGradientRotation = math.clamp(math.floor(value), 0, 360)
    themeGradientRotationInput.Text = tostring(AI.ThemeGradientRotation)
    applySavedAppearance()
end)

local function colorFromRgbText(value)
    local red, green, blue = tostring(value or ""):match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
    if not red then return Color3.new(1, 1, 1) end
    return Color3.fromRGB(math.clamp(tonumber(red), 0, 255), math.clamp(tonumber(green), 0, 255), math.clamp(tonumber(blue), 0, 255))
end
local function rgbTextFromColor(color)
    return ("%d, %d, %d"):format(
        math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
    )
end

-- Compact HSV color picker with the same continuous rainbow rail shown in the reference.
GradientColorPickerBackdrop = create("TextButton", {
    Name = "GradientColorPickerBackdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 118,
}, UIRefs.MainFrame)
GradientColorPicker = create("Frame", {
    Name = "GradientColorPicker", Size = UDim2.fromOffset(280, 192), BackgroundColor3 = Theme.PanelRaised,
    BorderSizePixel = 0, Visible = false, ZIndex = 119,
}, UIRefs.MainFrame)
corner(GradientColorPicker, 12)
stroke(GradientColorPicker, Theme.Border, 1, 0.12)
local PickerTitle = create("TextLabel", {
    Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -60, 0, 20), BackgroundTransparency = 1,
    Text = "Gradient color", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 120,
}, GradientColorPicker)
local PickerCloseButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 7), Size = UDim2.fromOffset(24, 24),
    BackgroundColor3 = Theme.SegmentedBg, BorderSizePixel = 0, Text = "×", TextColor3 = Theme.MutedText,
    Font = Theme.FontBold, TextSize = 16, AutoButtonColor = false, ZIndex = 120,
}, GradientColorPicker)
corner(PickerCloseButton, 7)
local PickerColorPreview = create("Frame", {
    Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 24),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 120,
}, GradientColorPicker)
corner(PickerColorPreview, 7)
stroke(PickerColorPreview, Theme.Border, 1, 0.2)
local PickerRgbLabel = create("TextLabel", {
    Position = UDim2.new(0, 14, 0, 67), Size = UDim2.new(1, -28, 0, 16), BackgroundTransparency = 1,
    Text = "255, 255, 255", TextColor3 = Theme.MutedText, Font = Theme.FontCode, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 120,
}, GradientColorPicker)
local pickerHue, pickerSaturation, pickerValue = 0, 0, 1
local activePickerKey, activePickerButton, activePickerTrack
local pickerTracks = {}
local pickerRainbow = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})
local function makePickerTrack(label, y, gradientColors)
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, y - 1), Size = UDim2.fromOffset(18, 16), BackgroundTransparency = 1,
        Text = label, TextColor3 = Theme.MutedText, Font = Theme.FontBold, TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 120,
    }, GradientColorPicker)
    local track = create("Frame", {
        Position = UDim2.new(0, 38, 0, y), Size = UDim2.new(1, -54, 0, 14),
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 120,
    }, GradientColorPicker)
    corner(track, 7)
    local fill = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Active = false, ZIndex = 120,
    }, track)
    corner(fill, 7)
    local gradient = create("UIGradient", { Color = gradientColors }, fill)
    local thumb = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Theme.PrimaryText,
        BorderSizePixel = 0, Active = false, ZIndex = 121,
    }, track)
    corner(thumb, 8)
    stroke(thumb, Theme.SegmentedBg, 1.5, 0)
    local spec = { Track = track, Fill = fill, Gradient = gradient, Thumb = thumb }
    pickerTracks[label] = spec
    return spec
end
local hueTrack = makePickerTrack("H", 92, pickerRainbow)
local saturationTrack = makePickerTrack("S", 122, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 0, 0)))
local valueTrack = makePickerTrack("V", 152, ColorSequence.new(Color3.new(0, 0, 0), Color3.new(1, 1, 1)))
local function selectedPickerColor()
    return Color3.fromHSV(pickerHue, pickerSaturation, pickerValue)
end
local function updatePickerPreview()
    local color = selectedPickerColor()
    local gradientHue = Color3.fromHSV(pickerHue, 1, pickerValue)
    hueTrack.Thumb.Position = UDim2.new(pickerHue, 0, 0.5, 0)
    saturationTrack.Thumb.Position = UDim2.new(pickerSaturation, 0, 0.5, 0)
    valueTrack.Thumb.Position = UDim2.new(pickerValue, 0, 0.5, 0)
    saturationTrack.Gradient.Color = ColorSequence.new(Color3.fromHSV(pickerHue, 0, pickerValue), gradientHue)
    valueTrack.Gradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(pickerHue, pickerSaturation, 1))
    PickerColorPreview.BackgroundColor3 = color
    PickerRgbLabel.Text = rgbTextFromColor(color)
    if activePickerButton then activePickerButton.BackgroundColor3 = color end
    if activePickerKey == "ThemeGradientStartRGB" then
        AI.ThemeGradientStartRGB = rgbTextFromColor(color)
    elseif activePickerKey == "ThemeGradientEndRGB" then
        AI.ThemeGradientEndRGB = rgbTextFromColor(color)
    end
end
local function closeGradientColorPicker(apply)
    if not GradientColorPicker.Visible then return end
    activePickerTrack = nil
    GradientColorPicker.Visible = false
    GradientColorPickerBackdrop.Visible = false
    if apply then applySavedAppearance() end
    activePickerKey, activePickerButton = nil, nil
end
local function openGradientColorPicker(key, button)
    closeGradientColorPicker(false)
    activePickerKey, activePickerButton = key, button
    PickerTitle.Text = key == "ThemeGradientStartRGB" and "Gradient start color" or "Gradient end color"
    local color = colorFromRgbText(AI[key])
    pickerHue, pickerSaturation, pickerValue = color:ToHSV()
    updatePickerPreview()
    local buttonPosition, buttonSize = button.AbsolutePosition, button.AbsoluteSize
    local framePosition, frameSize = UIRefs.MainFrame.AbsolutePosition, UIRefs.MainFrame.AbsoluteSize
    local x = math.clamp(buttonPosition.X - framePosition.X + buttonSize.X - 280, 6, math.max(6, frameSize.X - 286))
    local y = buttonPosition.Y - framePosition.Y + buttonSize.Y + 6
    if y + 198 > frameSize.Y then y = math.max(6, buttonPosition.Y - framePosition.Y - 198) end
    GradientColorPicker.Position = UDim2.fromOffset(x, y)
    GradientColorPicker.Visible = true
    GradientColorPickerBackdrop.Visible = true
end
themeGradientStartButton.MouseButton1Click:Connect(function() openGradientColorPicker("ThemeGradientStartRGB", themeGradientStartButton) end)
themeGradientEndButton.MouseButton1Click:Connect(function() openGradientColorPicker("ThemeGradientEndRGB", themeGradientEndButton) end)
GradientColorPickerBackdrop.MouseButton1Click:Connect(function() closeGradientColorPicker(true) end)
PickerCloseButton.MouseButton1Click:Connect(function() closeGradientColorPicker(true) end)
local function setPickerTrack(track, input)
    local alpha = math.clamp((input.Position.X - track.Track.AbsolutePosition.X) / math.max(1, track.Track.AbsoluteSize.X), 0, 1)
    if track == hueTrack then pickerHue = alpha
    elseif track == saturationTrack then pickerSaturation = alpha
    else pickerValue = alpha end
    updatePickerPreview()
end
for _, spec in ipairs({ hueTrack, saturationTrack, valueTrack }) do
    spec.Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activePickerTrack = spec
            setPickerTrack(spec, input)
        end
    end)
end
UIRefs.UserInputService.InputChanged:Connect(function(input)
    if activePickerTrack and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        setPickerTrack(activePickerTrack, input)
    end
end)
UIRefs.UserInputService.InputEnded:Connect(function(input)
    if activePickerTrack and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        setPickerTrack(activePickerTrack, input)
        activePickerTrack = nil
        applySavedAppearance()
    end
end)
AITabButton.MouseButton1Click:Connect(function() closeGradientColorPicker(true) end)
ThemeTabButton.MouseButton1Click:Connect(function() closeGradientColorPicker(true) end)
SettingsView:GetPropertyChangedSignal("Visible"):Connect(function()
    if not SettingsView.Visible then closeGradientColorPicker(true) end
end)
themeAdvancedButton.MouseButton1Click:Connect(function()
    if not AI.ThemeAdvanced then closeGradientColorPicker(true) end
end)

local function bindPercentInput(input, key)
    input.FocusLost:Connect(function()
        local value = tonumber(input.Text)
        if not value then value = AI[key] * 100 end
        AI[key] = math.clamp(value, 0, 100) / 100
        input.Text = tostring(math.floor(AI[key] * 100 + 0.5))
        applySavedAppearance()
    end)
end
bindPercentInput(themeTransparencyInput, "ThemeTransparency")
bindPercentInput(themeGlossInput, "ThemeGloss")
bindPercentInput(themeGradientStrengthInput, "ThemeGradientStrength")
themeGradientRotationInput.FocusLost:Connect(function()
    local value = tonumber(themeGradientRotationInput.Text) or AI.ThemeGradientRotation
    AI.ThemeGradientRotation = math.clamp(math.floor(value), 0, 360)
    themeGradientRotationInput.Text = tostring(AI.ThemeGradientRotation)
    applySavedAppearance()
end)
refreshThemeControls = function()
    themeAdvancedControls.Visible = AI.ThemeAdvanced
    themeAdvancedControls.Size = UDim2.new(1, 0, 0, AI.ThemeAdvanced and 320 or 0)
    themeSimpleButton.Text = AI.ThemeSimple and "ON" or "OFF"
    themeSimpleButton.BackgroundColor3 = AI.ThemeSimple and Theme.Accent or Theme.SegmentedBg
    themeAdvancedButton.Text = AI.ThemeAdvanced and "ON" or "OFF"
    themeAdvancedButton.BackgroundColor3 = AI.ThemeAdvanced and Theme.Accent or Theme.SegmentedBg
    themeGlassButton.Text = AI.ThemeGlass and "ON" or "OFF"
    themeGlassButton.BackgroundColor3 = AI.ThemeGlass and Theme.Accent or Theme.SegmentedBg
    themeGradientButton.Text = AI.ThemeGradient and "ON" or "OFF"
    themeGradientButton.BackgroundColor3 = AI.ThemeGradient and Theme.Accent or Theme.SegmentedBg
    themeTransparencyInput.Text = tostring(math.floor(AI.ThemeTransparency * 100 + 0.5))
    themeGlossInput.Text = tostring(math.floor(AI.ThemeGloss * 100 + 0.5))
    themeGradientRotationInput.Text = tostring(AI.ThemeGradientRotation)
    themeGradientStrengthInput.Text = tostring(math.floor(AI.ThemeGradientStrength * 100 + 0.5))
    themeGradientStartButton.BackgroundColor3 = colorFromRgbText(AI.ThemeGradientStartRGB)
    themeGradientEndButton.BackgroundColor3 = colorFromRgbText(AI.ThemeGradientEndRGB)
end
refreshThemeControls()
applySavedAppearance()

-- AI Provider
local ProviderSection = makeSection("AI Provider", 2)
local providerRow = create("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 7 }, ProviderSection)
local ModelInput, EndpointInput
local providerList = { "DeepSeek", "Gemini", "Groq", "OpenRouter", "Token Harbor", "OpenAI", "Custom" }
local ProviderDropdownButton = create("TextButton", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 8,
}, providerRow)
corner(ProviderDropdownButton, 11)
stroke(ProviderDropdownButton, Theme.Border, 1, 0.28)
bindSoftButton(ProviderDropdownButton, { BackgroundColor3 = Theme.PanelRaised }, 1.008)

local ProviderIcon = create("Frame", {
    Position = UDim2.new(0, 11, 0.5, -17), Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = Theme.AccentSoft, BorderSizePixel = 0, ZIndex = 9,
}, ProviderDropdownButton)
corner(ProviderIcon, 10)
Theme.createHubGlyph(ProviderIcon, 20, 10, Theme.Accent, true)

create("TextLabel", {
    Position = UDim2.new(0, 55, 0, 10), Size = UDim2.new(1, -105, 0, 13),
    BackgroundTransparency = 1, Text = "AI PROVIDER", TextColor3 = Theme.QuietText,
    Font = Theme.FontBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
}, ProviderDropdownButton)
local SelectedProviderLabel = create("TextLabel", {
    Position = UDim2.new(0, 55, 0, 25), Size = UDim2.new(1, -105, 0, 20),
    BackgroundTransparency = 1, Text = AI.Provider, TextColor3 = Theme.PrimaryText,
    Font = Theme.FontBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
}, ProviderDropdownButton)
local ProviderChevron = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Theme.SegmentedBg,
    Text = "▼", TextColor3 = Theme.MutedText, Font = Theme.FontBold, TextSize = 9, ZIndex = 9,
}, ProviderDropdownButton)
corner(ProviderChevron, 8)

ProviderDropdownMenu = create("ScrollingFrame", {
    Name = "ProviderDropdownMenu", Size = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Theme.PanelRaised, BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true, Visible = false,
    ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4,
    LayoutOrder = 3, ZIndex = 8,
}, ProviderSection)
corner(ProviderDropdownMenu, 12)
stroke(ProviderDropdownMenu, Theme.Border, 1, 0.18)
padding(ProviderDropdownMenu, 7, 7, 7, 7)
styleScrollBar(ProviderDropdownMenu)
create("UIListLayout", {
    Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, ProviderDropdownMenu)

local providerOptions = {}
closeProviderDropdown = function(animate)
    ProviderChevron.Text = "▼"
    if animate and ProviderDropdownMenu.Visible then
        local closing = tween(ProviderDropdownMenu, {
            Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
        }, 0.14, Enum.EasingStyle.Quint)
        if closing then
            closing.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and ProviderDropdownMenu.Size.Y.Offset == 0 then
                    ProviderDropdownMenu.Visible = false
                end
            end)
        else
            ProviderDropdownMenu.Visible = false
        end
    else
        ProviderDropdownMenu.Visible = false
        ProviderDropdownMenu.Size = UDim2.new(1, 0, 0, 0)
        ProviderDropdownMenu.BackgroundTransparency = 1
    end
end

local function chooseProvider(prov)
    AI.Provider = prov
    if prov ~= "Custom" then
        AI.Endpoint = UIRefs.ProviderPresets[prov].endpoint
        AI.Model = UIRefs.ProviderPresets[prov].models[1]
    else
        AI.Endpoint = AI.CustomEndpoint
    end
    SelectedProviderLabel.Text = prov
    for name, option in pairs(providerOptions) do
        local active = name == prov
        option.BackgroundColor3 = active and Theme.Selected or Theme.PanelRaised
        option.TextColor3 = active and Theme.PrimaryText or Theme.MutedText
        local check = option:FindFirstChild("SelectedCheck")
        if check then check.Visible = active end
    end
    saveSettings()
    if ModelInput then ModelInput.Text = AI.Model end
    if EndpointInput then
        EndpointInput.Text = (AI.Provider == "Custom") and AI.CustomEndpoint or AI.Endpoint
        EndpointInput.TextEditable = AI.Provider == "Custom"
    end
    closeProviderDropdown(true)
end

for i, prov in ipairs(providerList) do
    local option = create("TextButton", {
        Name = "ProviderOption_" .. prov:gsub("%s", ""),
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.PanelRaised,
        BorderSizePixel = 0, Text = prov, TextColor3 = Theme.MutedText,
        Font = Theme.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, LayoutOrder = i, ZIndex = 9,
    }, ProviderDropdownMenu)
    corner(option, 8)
    padding(option, 11, 34, 0, 0)
    local check = create("TextLabel", {
        Name = "SelectedCheck", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1, Text = "✓", TextColor3 = Theme.Accent,
        Font = Theme.FontBold, TextSize = 13, Visible = prov == AI.Provider, ZIndex = 10,
    }, option)
    option.BackgroundColor3 = prov == AI.Provider and Theme.Selected or Theme.PanelRaised
    option.TextColor3 = prov == AI.Provider and Theme.PrimaryText or Theme.MutedText
    providerOptions[prov] = option
    option.MouseEnter:Connect(function()
        if prov ~= AI.Provider then tween(option, { BackgroundColor3 = Theme.Hover }, 0.1) end
    end)
    option.MouseLeave:Connect(function()
        if prov ~= AI.Provider then tween(option, { BackgroundColor3 = Theme.PanelRaised }, 0.1) end
    end)
    option.MouseButton1Click:Connect(function() chooseProvider(prov) end)
end

ProviderDropdownButton.MouseButton1Click:Connect(function()
    local open = not ProviderDropdownMenu.Visible
    if open then
        if closeThemeDropdown then closeThemeDropdown(false) end
        ProviderDropdownMenu.CanvasPosition = Vector2.new(0, 0)
        ProviderDropdownMenu.Size = UDim2.new(1, 0, 0, 0)
        ProviderDropdownMenu.BackgroundTransparency = 1
        ProviderDropdownMenu.Visible = true
        ProviderChevron.Text = "▲"
        tween(ProviderDropdownMenu, {
            Size = UDim2.new(1, 0, 0, 164), BackgroundTransparency = 0,
        }, 0.2, Enum.EasingStyle.Quint)
    else
        closeProviderDropdown(true)
    end
end)

-- Model
local ModelSection = makeSection("Model", 3)
ModelInput = create("TextBox", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = AI.Model,
    TextColor3 = Theme.PrimaryText, Font = Theme.FontCode, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false, LayoutOrder = 2, ZIndex = 7,
}, ModelSection)
corner(ModelInput, 10)
padding(ModelInput, 12, 12, 0, 0)
local modelStroke = stroke(ModelInput, Theme.Border, 1, 0.4)
ModelInput.Focused:Connect(function() tween(modelStroke, { Color = Theme.Accent, Transparency = 0 }, 0.16) end)
ModelInput.FocusLost:Connect(function()
    tween(modelStroke, { Color = Theme.Border, Transparency = 0.4 }, 0.16)
    AI.Model = ModelInput.Text
    saveSettings()
end)

-- API Key
local ApiSection = makeSection("API Key", 4)
local ApiInput = create("TextBox", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = AI.ApiKey,
    PlaceholderText = "sk-...", PlaceholderColor3 = Theme.QuietText, TextColor3 = Theme.PrimaryText,
    Font = Theme.FontCode, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false, LayoutOrder = 2, ZIndex = 7,
}, ApiSection)
corner(ApiInput, 10)
padding(ApiInput, 12, 12, 0, 0)
local apiStroke = stroke(ApiInput, Theme.Border, 1, 0.4)
ApiInput.Focused:Connect(function() tween(apiStroke, { Color = Theme.Accent, Transparency = 0 }, 0.16) end)
ApiInput.FocusLost:Connect(function()
    tween(apiStroke, { Color = Theme.Border, Transparency = 0.4 }, 0.16)
    AI.ApiKey = ApiInput.Text
    saveSettings()
end)

-- Endpoint
local EndpointSection = makeSection("Endpoint", 5)
EndpointInput = create("TextBox", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
    Text = (AI.Provider == "Custom") and AI.CustomEndpoint or AI.Endpoint,
    TextEditable = AI.Provider == "Custom", TextColor3 = Theme.PrimaryText, Font = Theme.FontCode,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, LayoutOrder = 2, ZIndex = 7,
}, EndpointSection)
corner(EndpointInput, 10)
padding(EndpointInput, 12, 12, 0, 0)
stroke(EndpointInput, Theme.Border, 1, 0.4)
EndpointInput.FocusLost:Connect(function()
    if AI.Provider == "Custom" then
        AI.CustomEndpoint = EndpointInput.Text
        AI.Endpoint = AI.CustomEndpoint
        saveSettings()
    end
end)

-- Generation
local GenerationSection = makeSection("Generation", 6)
local function makeFieldRow(section, titleText, initialText, placeholder, order, height)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 60),
        BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 7,
    }, section)
    create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
        Text = titleText, TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, row)
    local box = create("TextBox", {
        Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, (height or 60) - 22),
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = initialText or "",
        PlaceholderText = placeholder or "", PlaceholderColor3 = Theme.QuietText,
        TextColor3 = Theme.PrimaryText, Font = Theme.FontCode, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, MultiLine = false, ZIndex = 8,
    }, row)
    corner(box, 9)
    padding(box, 11, 11, 0, 0)
    stroke(box, Theme.Border, 1, 0.4)
    return box
end

local TemperatureInput = makeFieldRow(GenerationSection, "Temperature (0–2)", tostring(AI.Temperature), "0.7", 2)
TemperatureInput.FocusLost:Connect(function()
    local v = tonumber(TemperatureInput.Text) or 0.7
    AI.Temperature = math.clamp(v, 0, 2)
    TemperatureInput.Text = tostring(AI.Temperature)
    saveSettings()
end)

local MaxTokensInput = makeFieldRow(GenerationSection, "Maximum output tokens (128–16384)", tostring(AI.MaxTokens), "1024", 3)
MaxTokensInput.FocusLost:Connect(function()
    local v = tonumber(MaxTokensInput.Text) or 1024
    AI.MaxTokens = math.clamp(math.floor(v), 128, 16384)
    MaxTokensInput.Text = tostring(AI.MaxTokens)
    saveSettings()
end)

local ContextInput = makeFieldRow(GenerationSection, "Recent messages as context (2–100)", tostring(AI.ContextMessages), "30", 4)
ContextInput.FocusLost:Connect(function()
    local v = tonumber(ContextInput.Text) or 30
    AI.ContextMessages = math.clamp(math.floor(v), 2, 100)
    ContextInput.Text = tostring(AI.ContextMessages)
    saveSettings()
end)

local TimeoutInput = makeFieldRow(GenerationSection, "Request timeout seconds (5–120)", tostring(AI.RequestTimeout), "45", 5)
TimeoutInput.FocusLost:Connect(function()
    local v = tonumber(TimeoutInput.Text) or 45
    AI.RequestTimeout = math.clamp(math.floor(v), 5, 120)
    TimeoutInput.Text = tostring(AI.RequestTimeout)
    saveSettings()
end)

local MaxIterInput = makeFieldRow(GenerationSection, "Max tool-loop iterations (1–10)", tostring(AI.MaxToolIterations), "4", 6)
MaxIterInput.FocusLost:Connect(function()
    local v = tonumber(MaxIterInput.Text) or 4
    AI.MaxToolIterations = math.clamp(math.floor(v), 1, 10)
    MaxIterInput.Text = tostring(AI.MaxToolIterations)
    saveSettings()
end)

-- System prompt
local PromptSection = makeSection("System instructions", 7)
local PromptRow = create("Frame", { Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 7 }, PromptSection)
local SystemPromptInput = create("TextBox", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
    Text = AI.SystemPrompt or "", PlaceholderText = "Optional instructions applied to each request...",
    PlaceholderColor3 = Theme.QuietText, TextColor3 = Theme.PrimaryText, Font = Theme.Font,
    TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, ClearTextOnFocus = false, MultiLine = true, ZIndex = 8,
}, PromptRow)
corner(SystemPromptInput, 10)
padding(SystemPromptInput, 11, 11, 9, 9)
stroke(SystemPromptInput, Theme.Border, 1, 0.4)
SystemPromptInput.FocusLost:Connect(function()
    AI.SystemPrompt = SystemPromptInput.Text
    saveSettings()
end)

-- Behavior
local BehaviorSection = makeSection("Chat behavior", 8)
local toggleButtons = {}
local function addToggleRow(section, titleText, detailText, key, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0, LayoutOrder = order, ZIndex = 7,
    }, section)
    corner(row, 10)
    stroke(row, Theme.Border, 1, 0.55)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -98, 0, 18), BackgroundTransparency = 1,
        Text = titleText, TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, row)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 27), Size = UDim2.new(1, -98, 0, 17), BackgroundTransparency = 1,
        Text = detailText, TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8,
    }, row)
    local btn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(64, 28), BackgroundColor3 = AI[key] and Theme.Accent or Theme.SegmentedBg,
        BorderSizePixel = 0, Text = AI[key] and "ON" or "OFF",
        TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 10,
        AutoButtonColor = false, ZIndex = 9,
    }, row)
    corner(btn, 8)
    toggleButtons[key] = btn
    btn.MouseButton1Click:Connect(function()
        AI[key] = not AI[key]
        btn.Text = AI[key] and "ON" or "OFF"
        tween(btn, { BackgroundColor3 = AI[key] and Theme.Accent or Theme.SegmentedBg }, 0.15)
        saveSettings()
    end)
    return btn
end

addToggleRow(BehaviorSection, "Send on Enter", "Press Enter to send a message.", "EnterToSend", 2)
addToggleRow(BehaviorSection, "Auto-scroll chat", "Keep the newest message in view.", "AutoScroll", 3)
addToggleRow(BehaviorSection, "Save conversation history", "Uses local file storage when supported.", "SaveHistory", 4)
addToggleRow(BehaviorSection, "Disable conversation summarization",
    "Never send automatic requests to summarize older chat context.", "DisableSummarization", 5)
addToggleRow(BehaviorSection, "Auto-execute AI [EXECUTE] blocks",
    "Only tagged code runs. Untagged blocks just display.", "AutoExecute", 6)
addToggleRow(BehaviorSection, "Sandbox output capture",
    "Capture print/warn inside [EXECUTE] blocks.", "CaptureOutput", 7)
addToggleRow(BehaviorSection, "Include workspace snapshot",
    "Inject workspace tree into every request.", "IncludeWorkspace", 8)

-- Diagnostics
local DiagnosticsSection = makeSection("Debug & diagnostics", 9)
local ConnectionStatus = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
    Text = "Connection not tested.",
    TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 11,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = 2, ZIndex = 7,
}, DiagnosticsSection)

local ThemeDebugLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
    Text = "Theme engine: " .. RuntimeDiagnostics.LastThemeSwitch,
    TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 10,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = 3, ZIndex = 7,
}, DiagnosticsSection)
RuntimeDiagnostics.ThemeDebugLabel = ThemeDebugLabel

local RuntimeDebugLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 130), BackgroundTransparency = 1,
    Text = "Diagnostics have not been refreshed.",
    TextColor3 = Theme.QuietText, Font = Theme.FontCode, TextSize = 10,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 4, ZIndex = 7,
}, DiagnosticsSection)

local RefreshDebugButton = create("TextButton", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0, Text = "Refresh diagnostics", TextColor3 = Theme.PrimaryText,
    Font = Theme.FontBold, TextSize = 11, AutoButtonColor = false, LayoutOrder = 5, ZIndex = 7,
}, DiagnosticsSection)
corner(RefreshDebugButton, 9)
stroke(RefreshDebugButton, Theme.Border, 1, 0.35)
bindSoftButton(RefreshDebugButton, { BackgroundColor3 = Theme.Hover }, 1.02)

local function refreshRuntimeDiagnostics()
    local lines = {}
    lines[#lines + 1] = "Context: " .. (UIRefs.RunService:IsClient() and "client LocalScript" or "server Script")
    lines[#lines + 1] = "Theme: " .. ThemeEngine.CurrentThemeName ..
        " · switches: " .. tostring(RuntimeDiagnostics.ThemeSwitchCount) ..
        " · misses: " .. tostring(ThemeDebug.TotalMisses)
    local transport = (type(request) == "function") or (type(http_request) == "function") or
                      (type(syn) == "table" and type(syn.request) == "function") or
                      (type(http) == "table" and type(http.request) == "function")
    lines[#lines + 1] = "HTTP: " .. (transport and "available" or "MISSING")
    lines[#lines + 1] = "loadstring: " .. (type(loadstring) == "function" and "available" or "MISSING")
    lines[#lines + 1] = "file IO: " .. ((type(readfile) == "function" and type(writefile) == "function") and "available" or "MISSING")
    lines[#lines + 1] = "Sandbox runs: " .. tostring(#Sandbox.History) ..
        " · last ok: " .. tostring(Sandbox.History[#Sandbox.History] and Sandbox.History[#Sandbox.History].ok)
    lines[#lines + 1] = "Last log: " .. tostring(RuntimeDiagnostics.LastLog)
    lines[#lines + 1] = "Last error: " .. tostring(RuntimeDiagnostics.LastError)
    if #ThemeDebug.LastMisses > 0 then
        lines[#lines + 1] = "Theme misses:"
        for i, m in ipairs(ThemeDebug.LastMisses) do
            if i > 5 then break end
            lines[#lines + 1] = "  · " .. m.path .. "." .. m.prop
        end
    end
    RuntimeDebugLabel.Text = table.concat(lines, "\n")
    RuntimeDebugLabel.TextColor3 = RuntimeDiagnostics.LastError ~= "None" and Theme.Danger or Theme.QuietText
    print("[Dr4gonik Hub][DIAGNOSTICS]\n" .. RuntimeDebugLabel.Text)
end
RefreshDebugButton.MouseButton1Click:Connect(refreshRuntimeDiagnostics)

local TestConnectionButton = create("TextButton", {
    Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0, Text = "Test API connection", TextColor3 = Theme.White,
    Font = Theme.FontBold, TextSize = 12, AutoButtonColor = false, LayoutOrder = 6, ZIndex = 7,
}, DiagnosticsSection)
corner(TestConnectionButton, 9)
bindSoftButton(TestConnectionButton, { BackgroundColor3 = Theme.AccentHover }, 1.02)
TestConnectionButton.MouseButton1Click:Connect(function()
    if not AI.ApiKey or AI.ApiKey == "" then
        ConnectionStatus.Text = "Missing API key."
        ConnectionStatus.TextColor3 = Theme.Danger
        return
    end
    ConnectionStatus.Text = "Testing " .. AI.Provider .. " · " .. AI.Model .. "…"
    ConnectionStatus.TextColor3 = Theme.MutedText
    TestConnectionButton.Active = false
    task.spawn(function()
        local result, err = AI.CallAI({ { role = "user", content = "Reply with OK." } }, true)
        TestConnectionButton.Active = true
        if result then
            ConnectionStatus.Text = "OK · " .. tostring(result.content):sub(1, 90)
            ConnectionStatus.TextColor3 = Color3.fromRGB(88, 195, 135)
        else
            ConnectionStatus.Text = "Failed: " .. tostring(err):sub(1, 220)
            ConnectionStatus.TextColor3 = Theme.Danger
        end
    end)
end)

local ResetButton = create("TextButton", {
    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0, Text = "Restore default chat settings", TextColor3 = Theme.PrimaryText,
    Font = Theme.FontBold, TextSize = 12, AutoButtonColor = false, LayoutOrder = 7, ZIndex = 7,
}, DiagnosticsSection)
corner(ResetButton, 9)
stroke(ResetButton, Theme.Border, 1, 0.4)
bindSoftButton(ResetButton, { BackgroundColor3 = Theme.Hover }, 1.02)
ResetButton.MouseButton1Click:Connect(function()
    AI.Temperature = 0.7; AI.MaxTokens = 1024; AI.ContextMessages = 30; AI.RequestTimeout = 45
    AI.SystemPrompt = ""; AI.SaveHistory = true; AI.DisableSummarization = false; AI.EnterToSend = true; AI.AutoScroll = true
    AI.AutoExecute = true; AI.CaptureOutput = true; AI.IncludeWorkspace = false
    AI.MaxToolIterations = 4; AI.Effort = "Medium"
    TemperatureInput.Text = tostring(AI.Temperature)
    MaxTokensInput.Text = tostring(AI.MaxTokens)
    ContextInput.Text = tostring(AI.ContextMessages)
    TimeoutInput.Text = tostring(AI.RequestTimeout)
    MaxIterInput.Text = tostring(AI.MaxToolIterations)
    SystemPromptInput.Text = AI.SystemPrompt
    for key, btn in pairs(toggleButtons) do
        btn.Text = AI[key] and "ON" or "OFF"
        tween(btn, { BackgroundColor3 = AI[key] and Theme.Accent or Theme.SegmentedBg }, 0.15)
    end
    setEffortIndex(3)
    ConnectionStatus.Text = "Defaults restored."
    saveSettings()
end)

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1,
    Text = "Security: file-enabled runtimes may store your API key in plain text. Keep credentials on a trusted server/backend for published experiences.",
    TextColor3 = Theme.QuietText, Font = Theme.Font, TextSize = 10,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 10, ZIndex = 7,
}, AISettingsScroll)

end -- settings scope
