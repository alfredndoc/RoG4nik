--============================================================
--// THEME ENGINE STATE / DIAGNOSTICS
--============================================================
local ThemeEngine = {
    CurrentThemeName = "Dark",
    AppliedThemeName = "Dark",
    DropdownChevronOffset = 21,
}

local RuntimeDiagnostics = {
    ThemeSwitchCount = 0,
    LastThemeSwitch = "Initial theme: " .. ThemeEngine.CurrentThemeName,
    LastThemeColorUpdates = 0,
    LastError = "None",
    LastLog = "UI boot sequence started",
    ThemeDebugLabel = nil,
    ThemeTransitionOverlay = nil,
    ThemeTransitionToken = 0,
    ThemeSaveToken = 0,
    ActiveThemeTween = nil,
    ActiveThemeConnection = nil,
    ActiveThemeProgress = nil,
    ActiveThemeObjectTweens = nil,
}
ThemeEngine.RuntimeDiagnostics = RuntimeDiagnostics

local ThemeDebug = {
    History = {}, LastMisses = {}, TotalUpdates = 0, TotalMisses = 0,
    LastScan = nil, LastRoleRecoveries = 0, LastRoleDrops = 0,
}
ThemeEngine.ThemeDebug = ThemeDebug
_G.ThemeDebug = ThemeDebug

local function pathOf(obj)
    local parts = { obj.ClassName, obj.Name }
    local cur = obj
    while cur and cur.Parent and cur.Parent ~= playerGui do
        cur = cur.Parent
        table.insert(parts, 1, cur.Name)
    end
    return table.concat(parts, " > ")
end
ThemeEngine.pathOf = pathOf

ThemeEngine.DebugLoggingEnabled = true

local function debugTrace(level, message)
    if not ThemeEngine.DebugLoggingEnabled then return end
    local line = ("[Dr4gonik Hub][%s] %s"):format(tostring(level), tostring(message))
    RuntimeDiagnostics.LastLog = line
    if level == "ERROR" or level == "WARN" then
        warn(line)
        if level == "ERROR" then RuntimeDiagnostics.LastError = tostring(message) end
    else
        print(line)
    end
end
ThemeEngine.debugTrace = debugTrace

local Theme = {}
for k, v in pairs(Themes[ThemeEngine.CurrentThemeName]) do Theme[k] = v end
Theme.Font = Enum.Font.GothamMedium
Theme.FontBold = Enum.Font.GothamBold
Theme.FontCode = Enum.Font.Code
ThemeEngine.Theme = Theme

-- Apply a preset without animation, persistence, or diagnostics. Used during boot
-- while loadSettings runs before the GUI exists.
function ThemeEngine.applyThemePreset(name)
    local preset = Themes[name]
    if not preset then return false end
    for key, value in pairs(preset) do
        Theme[key] = value
    end
    ThemeEngine.CurrentThemeName = name
    ThemeEngine.AppliedThemeName = name
    RuntimeDiagnostics.LastThemeSwitch = "Initial theme: " .. name
    return true
end

--============================================================
--// BASE HELPERS
--============================================================
local themeKeyForColor
local ThemeRoleRegistry = setmetatable({}, { __mode = "k" })
local ThemeGradientRoleRegistry = setmetatable({}, { __mode = "k" })
local ThemeBaseTransparency = setmetatable({}, { __mode = "k" })
local ThemeStrokeBase = setmetatable({}, { __mode = "k" })
local ThemeAppearance = {
    Simple = false, Advanced = false, Transparency = 0.14, Gloss = 0.25, Gradient = true,
    GradientRotation = 90, GradientStrength = 0.18,
    GradientStartRGB = "255, 255, 255", GradientEndRGB = "224, 228, 240",
}
local ThemeSurfaceRoles = {
    Background = true, Sidebar = true, Panel = true, PanelRaised = true, RightBg = true,
    Hover = true, Selected = true, Accent = true, AccentHover = true, AccentSoft = true,
    SegmentedBg = true,
}
local function applyAppearanceToObject(obj) end
local ThemeColorProperties = {
    BackgroundColor3 = true, TextColor3 = true, ImageColor3 = true, Color = true,
    PlaceholderColor3 = true, ScrollBarImageColor3 = true, BorderColor3 = true,
    TextStrokeColor3 = true, Ambient = true, LightColor = true,
}

local function create(className, props, parent)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        local ok, err = pcall(function() inst[k] = v end)
        if not ok then
            debugTrace("WARN", ("Could not set %s.%s: %s"):format(className, tostring(k), tostring(err)))
        end
    end
    local roles = {}
    for propName in pairs(ThemeColorProperties) do
        local value = props and props[propName]
        if typeof(value) == "Color3" and themeKeyForColor then
            local role = themeKeyForColor(value, propName, Theme)
            if role then roles[propName] = role end
        end
    end
    if next(roles) then ThemeRoleRegistry[inst] = roles end
    if inst:IsA("UIGradient") and props and typeof(props.Color) == "ColorSequence" and themeKeyForColor then
        local gradientRoles = {}
        for index, keypoint in ipairs(props.Color.Keypoints) do
            local role = themeKeyForColor(keypoint.Value, "Color", Theme)
            if role then gradientRoles[index] = role end
        end
        if next(gradientRoles) then
            ThemeGradientRoleRegistry[inst] = {
                roles = gradientRoles,
                keypointCount = #props.Color.Keypoints,
            }
        end
    end
    if inst:IsA("GuiObject") then
        ThemeBaseTransparency[inst] = inst.BackgroundTransparency
    elseif inst:IsA("UIStroke") then
        ThemeStrokeBase[inst] = { Transparency = inst.Transparency, Thickness = inst.Thickness }
    end
    if parent then inst.Parent = parent end
    if applyAppearanceToObject then applyAppearanceToObject(inst) end
    return inst
end

local ActiveColorTweens = setmetatable({}, { __mode = "k" })

local function removeTrackedColorTween(instance, record)
    local records = ActiveColorTweens[instance]
    if not records then return end
    for index = #records, 1, -1 do
        if records[index] == record then
            table.remove(records, index)
            break
        end
    end
    if #records == 0 then ActiveColorTweens[instance] = nil end
end

local function trackColorTween(instance, anim, goals)
    local properties = {}
    for property in pairs(goals) do
        if ThemeColorProperties[property] then properties[property] = true end
    end
    if not next(properties) then return end

    local record = { tween = anim, properties = properties }
    local records = ActiveColorTweens[instance]
    if not records then
        records = {}
        ActiveColorTweens[instance] = records
    end
    records[#records + 1] = record
    anim.Completed:Connect(function()
        removeTrackedColorTween(instance, record)
    end)
end

local function tween(instance, goals, duration, style, direction)
    if not instance or not instance.Parent then return end
    local info = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
    local anim = TweenService:Create(instance, info, goals)
    trackColorTween(instance, anim, goals)
    anim:Play()
    return anim
end

local function corner(parent, radius) return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent) end
local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", { Color = color or Theme.Border, Thickness = thickness or 1,
        Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end
local function padding(parent, l, r, t, b)
    return create("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0) }, parent)
end
local function viewportSize()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

ThemeEngine.create = create
ThemeEngine.tween = tween
ThemeEngine.corner = corner
ThemeEngine.stroke = stroke
ThemeEngine.padding = padding
ThemeEngine.viewportSize = viewportSize

-- Minimalist custom Hub mark: a geometric diamond crossed by a clean slash.
-- Native Roblox UI shapes keep it sharp at small sizes and avoid external assets.
Theme.createHubGlyph = function(parent, size, zIndex, color, centered)
    local glyphColor = color or Theme.Accent
    local host = create("Frame", {
        Name = "Dr4gonikGlyph", AnchorPoint = centered and Vector2.new(0.5, 0.5) or Vector2.new(0, 0),
        Position = centered and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = zIndex,
    }, parent)

    local diamondSize = math.max(7, size * 0.5)
    local diamond = create("Frame", {
        Name = "GlyphDiamond", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(diamondSize, diamondSize),
        BackgroundTransparency = 1, BorderSizePixel = 0, Rotation = 45, ZIndex = zIndex + 1,
    }, host)
    corner(diamond, math.max(1, math.floor(size * 0.09)))
    stroke(diamond, glyphColor, math.max(1, size * 0.075), 0)

    local slash = create("Frame", {
        Name = "GlyphSlash", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size * 0.62, math.max(1.5, size * 0.08)),
        BackgroundColor3 = glyphColor, BorderSizePixel = 0, Rotation = -45, ZIndex = zIndex + 2,
    }, host)
    corner(slash, 1)
    return host
end
ThemeEngine.createHubGlyph = Theme.createHubGlyph

local function bindSoftButton(button, hoverProps, hoverScale)
    hoverScale = hoverScale or 1.035
    local scale = create("UIScale", { Scale = 1 }, button)
    local resting, hoveringProps = {}, {}
    for propName in pairs(hoverProps or {}) do
        local current = button[propName]
        local themeKey = themeKeyForColor(current, propName, Theme)
        resting[propName] = { value = current, themeKey = themeKey }
        if themeKey then
            if not ThemeRoleRegistry[button] then ThemeRoleRegistry[button] = {} end
            ThemeRoleRegistry[button][propName] = themeKey
        end
        local hoverValue = hoverProps[propName]
        hoveringProps[propName] = { value = hoverValue, themeKey = themeKeyForColor(hoverValue, propName, Theme) }
    end
    local function computeGoals(source)
        local goals = {}
        for propName, data in pairs(source) do
            goals[propName] = (data.themeKey and Theme[data.themeKey]) or data.value
        end
        return goals
    end
    local hovering = false
    button.MouseEnter:Connect(function()
        hovering = true
        tween(scale, { Scale = hoverScale }, 0.16, Enum.EasingStyle.Back)
        tween(button, computeGoals(hoveringProps), 0.16)
    end)
    button.MouseLeave:Connect(function()
        hovering = false
        tween(scale, { Scale = 1 }, 0.16)
        tween(button, computeGoals(resting), 0.16)
    end)
    button.MouseButton1Down:Connect(function() tween(scale, { Scale = 0.965 }, 0.07, Enum.EasingStyle.Quad) end)
    button.MouseButton1Up:Connect(function() tween(scale, { Scale = hovering and hoverScale or 1 }, 0.13, Enum.EasingStyle.Back) end)
    return scale
end
ThemeEngine.bindSoftButton = bindSoftButton

local function styleScrollBar(scroller)
    scroller.ScrollBarThickness = 4
    scroller.ScrollBarImageColor3 = Theme.Border
    scroller.ScrollBarImageTransparency = 0.52
    scroller.MouseEnter:Connect(function() tween(scroller, { ScrollBarImageTransparency = 0.12 }, 0.18) end)
    scroller.MouseLeave:Connect(function() tween(scroller, { ScrollBarImageTransparency = 0.52 }, 0.18) end)
end
ThemeEngine.styleScrollBar = styleScrollBar

local function parseAppearanceRgb(value, fallback)
    local red, green, blue = tostring(value or ""):match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
    if not red then return fallback end
    return Color3.fromRGB(
        math.clamp(tonumber(red), 0, 255),
        math.clamp(tonumber(green), 0, 255),
        math.clamp(tonumber(blue), 0, 255)
    )
end

local function resolvedAppearance()
    if ThemeAppearance._ResolvedCache then return ThemeAppearance._ResolvedCache end

    local appearance
    if ThemeAppearance.Simple then
        appearance = {
            Glass = true, Transparency = 0.08, Gloss = 0.55, Gradient = false,
            GradientRotation = 90, GradientStrength = 0,
            GradientStart = Color3.new(1, 1, 1), GradientEnd = Color3.fromRGB(224, 228, 240),
        }
    elseif ThemeAppearance.Advanced then
        appearance = {
            Glass = ThemeAppearance.Glass == true,
            Transparency = ThemeAppearance.Glass and math.clamp(tonumber(ThemeAppearance.Transparency) or 0.1, 0, 1) or 0,
            Gloss = ThemeAppearance.Glass and math.clamp(tonumber(ThemeAppearance.Gloss) or 0.35, 0, 1) or 0,
            Gradient = ThemeAppearance.Gradient == true,
            GradientRotation = math.clamp(math.floor(tonumber(ThemeAppearance.GradientRotation) or 90), 0, 360),
            GradientStrength = math.clamp(tonumber(ThemeAppearance.GradientStrength) or 0.18, 0, 1),
            GradientStart = parseAppearanceRgb(ThemeAppearance.GradientStartRGB, Color3.new(1, 1, 1)),
            GradientEnd = parseAppearanceRgb(ThemeAppearance.GradientEndRGB, Color3.fromRGB(224, 228, 240)),
        }
    else
        appearance = { Glass = false, Transparency = 0, Gloss = 0, Gradient = false }
    end
    ThemeAppearance._ResolvedCache = appearance
    return appearance
end

local function updateGlassEdge(obj, appearance)
    local edge = obj:FindFirstChild("ThemeGlassStroke")
    if not appearance.Glass then
        if edge then edge:Destroy() end
        return
    end
    local function styleEdge(strokeObject, currentAppearance)
        currentAppearance = currentAppearance or appearance
        strokeObject.Color = Theme.Border
        strokeObject.Thickness = 1
        strokeObject.Transparency = math.clamp(0.75 - (currentAppearance.Gloss * 0.45), 0.2, 0.9)
    end
    if edge then
        styleEdge(edge)
    elseif not obj:FindFirstChildOfClass("UIStroke") then
        -- Wait one scheduler turn so a control's explicit border can be created first.
        task.defer(function()
            local currentAppearance = resolvedAppearance()
            if not obj.Parent or not currentAppearance.Glass or obj:FindFirstChildOfClass("UIStroke") then return end
            if obj.AbsoluteSize.X < 28 or obj.AbsoluteSize.Y < 20 then return end
            local glassStroke = Instance.new("UIStroke")
            glassStroke.Name = "ThemeGlassStroke"
            glassStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            glassStroke.Parent = obj
            ThemeStrokeBase[glassStroke] = { Transparency = 0.75, Thickness = 1 }
            ThemeRoleRegistry[glassStroke] = { Color = "Border" }
            styleEdge(glassStroke, currentAppearance)
        end)
    end
end

applyAppearanceToObject = function(obj, appearance)
    if not obj then return end
    if obj:IsA("UIStroke") then
        local base = ThemeStrokeBase[obj]
        local parentRoles = obj.Parent and ThemeRoleRegistry[obj.Parent]
        if not base or not parentRoles or not parentRoles.BackgroundColor3
            or not ThemeSurfaceRoles[parentRoles.BackgroundColor3] then return end
        appearance = appearance or resolvedAppearance()
        obj.Transparency = math.clamp(base.Transparency - (appearance.Gloss * 0.3), 0, 1)
        obj.Thickness = base.Thickness + (appearance.Gloss * 0.5)
        return
    end

    if not obj:IsA("GuiObject") then return end
    local roles = ThemeRoleRegistry[obj]
    if not roles or not roles.BackgroundColor3 or not ThemeSurfaceRoles[roles.BackgroundColor3] then return end
    local baseTransparency = ThemeBaseTransparency[obj]
    if baseTransparency == nil or baseTransparency >= 0.75 then return end

    appearance = appearance or resolvedAppearance()
    obj.BackgroundTransparency = baseTransparency + ((1 - baseTransparency) * appearance.Transparency)
    updateGlassEdge(obj, appearance)
    if obj:IsA("Frame") then
        local gradient = obj:FindFirstChild("ThemeSurfaceGradient")
        if appearance.Gradient then
            if not gradient and obj:FindFirstChildOfClass("UIGradient") then return end
            if not gradient then
                gradient = Instance.new("UIGradient")
                gradient.Name = "ThemeSurfaceGradient"
                gradient.Parent = obj
            end
            gradient.Rotation = appearance.GradientRotation
            gradient.Color = ColorSequence.new(appearance.GradientStart, appearance.GradientEnd)
            local strength = appearance.GradientStrength
            gradient.Transparency = NumberSequence.new(1 - strength, 1 - (strength * 0.4))
        elseif gradient then
            gradient:Destroy()
        end
    end
end

function ThemeEngine.setAppearanceSettings(settings)
    settings = settings or {}
    local wasAppearanceEnabled = ThemeAppearance.Simple or ThemeAppearance.Advanced
    ThemeAppearance.Simple = settings.Simple == true
    ThemeAppearance.Advanced = settings.Advanced == true and not ThemeAppearance.Simple
    ThemeAppearance.Glass = settings.Glass == true
    ThemeAppearance.Transparency = math.clamp(tonumber(settings.Transparency) or 0.1, 0, 1)
    ThemeAppearance.Gloss = math.clamp(tonumber(settings.Gloss) or 0.35, 0, 1)
    ThemeAppearance.Gradient = settings.Gradient ~= false
    ThemeAppearance.GradientRotation = math.clamp(math.floor(tonumber(settings.GradientRotation) or 90), 0, 360)
    ThemeAppearance.GradientStrength = math.clamp(tonumber(settings.GradientStrength) or 0.18, 0, 1)
    ThemeAppearance.GradientStartRGB = tostring(settings.GradientStartRGB or "255, 255, 255")
    ThemeAppearance.GradientEndRGB = tostring(settings.GradientEndRGB or "224, 228, 240")
    ThemeAppearance._ResolvedCache = nil
    if not wasAppearanceEnabled and not ThemeAppearance.Simple and not ThemeAppearance.Advanced then return end
    local appearance = resolvedAppearance()
    for obj in pairs(ThemeRoleRegistry) do
        if obj and obj.Parent and not obj:IsA("UIStroke") then
            applyAppearanceToObject(obj, appearance)
        end
    end
    -- Reapply stroke styling after their parent surfaces have been visited.
    for obj in pairs(ThemeStrokeBase) do
        if obj and obj.Parent then applyAppearanceToObject(obj, appearance) end
    end
end
ThemeEngine.getAppearanceSettings = function()
    local appearance = resolvedAppearance()
    return {
        Simple = ThemeAppearance.Simple, Advanced = ThemeAppearance.Advanced, Glass = appearance.Glass,
        Transparency = appearance.Transparency, Gloss = appearance.Gloss, Gradient = appearance.Gradient,
        GradientRotation = appearance.GradientRotation, GradientStrength = appearance.GradientStrength,
        GradientStartRGB = ThemeAppearance.GradientStartRGB, GradientEndRGB = ThemeAppearance.GradientEndRGB,
    }
end


--============================================================
--// THEME RESOLUTION
--============================================================
local THEME_KEY_PRIORITY = {
    BackgroundColor3 = { "Background", "Sidebar", "Panel", "PanelRaised", "Hover", "Selected", "Accent", "AccentHover", "AccentSoft", "RightBg", "SegmentedBg", "Danger", "White" },
    TextColor3 = { "PrimaryText", "MutedText", "QuietText", "Accent", "AccentHover", "Danger", "White" },
    ImageColor3 = { "MutedText", "PrimaryText", "QuietText", "Accent", "AccentHover", "White", "Danger" },
    PlaceholderColor3 = { "QuietText", "MutedText", "PrimaryText" },
    ScrollBarImageColor3 = { "Border", "MutedText", "QuietText" },
    BorderColor3 = { "Border", "Accent", "Danger" },
    TextStrokeColor3 = { "Border", "Accent", "Danger", "PrimaryText", "White" },
    Color = { "Accent", "AccentHover", "AccentSoft", "Border", "Danger", "MutedText", "QuietText", "PrimaryText", "White" },
    Ambient = { "Background", "Sidebar", "Panel", "PanelRaised", "RightBg" },
    LightColor = { "PrimaryText", "White", "Accent", "AccentHover" },
}

-- Preset keys are stable, so build the deterministic fallback order once rather
-- than sorting and allocating a key list for every color inspected at switch time.
local THEME_COLOR_KEY_FALLBACK = {}
for key, value in pairs(Themes.Dark or Theme) do
    if typeof(value) == "Color3" then
        THEME_COLOR_KEY_FALLBACK[#THEME_COLOR_KEY_FALLBACK + 1] = key
    end
end
table.sort(THEME_COLOR_KEY_FALLBACK)

themeKeyForColor = function(c, propName, sourceTheme)
    if typeof(c) ~= "Color3" then return nil end
    sourceTheme = sourceTheme or Theme
    local priority = THEME_KEY_PRIORITY[propName]
    if priority then
        for _, key in ipairs(priority) do
            if sourceTheme[key] == c then return key end
        end
    end
    for _, key in ipairs(THEME_COLOR_KEY_FALLBACK) do
        if sourceTheme[key] == c then return key end
    end
    return nil
end

local THEME_PRESET_NAMES = {}
for presetName in pairs(Themes) do
    THEME_PRESET_NAMES[#THEME_PRESET_NAMES + 1] = presetName
end
table.sort(THEME_PRESET_NAMES)

local function themeKeyForPaletteColor(color, propName, preferredRole)
    if typeof(color) ~= "Color3" then return nil end
    if preferredRole then
        for _, presetName in ipairs(THEME_PRESET_NAMES) do
            if Themes[presetName][preferredRole] == color then
                return preferredRole
            end
        end
    end
    for _, presetName in ipairs(THEME_PRESET_NAMES) do
        local role = themeKeyForColor(color, propName, Themes[presetName])
        if role then return role end
    end
    return nil
end

local function collectThemeChanges(root, oldTheme, newTheme, preserveInFlightRoles)
    local changes, misses = {}, {}
    local stats = {
        descendants = 0, colorPropertiesRead = 0, nonColorProperties = 0,
        unsupportedPropertyReads = 0, gradientsScanned = 0, gradientUpdates = 0,
        resolvedColorRoles = 0, recoveredRoles = 0, droppedRoles = 0,
        recoveryExamples = {}, droppedExamples = {},
    }
    if not root then return changes, misses, stats end

    local function addRoleExample(list, obj, property, previousRole, resolvedRole, color)
        if #list >= 5 then return end
        list[#list + 1] = {
            path = pathOf(obj), property = property, previousRole = previousRole,
            resolvedRole = resolvedRole, color = tostring(color),
        }
    end

    local function recordRecovery(obj, property, previousRole, resolvedRole, color)
        stats.recoveredRoles += 1
        addRoleExample(stats.recoveryExamples, obj, property, previousRole, resolvedRole, color)
    end

    local function collectProperty(obj, property)
        stats.colorPropertiesRead += 1
        -- A bad or unsupported property name must never abort the whole theme scan.
        local ok, current = pcall(function() return obj[property] end)
        if not ok then
            stats.unsupportedPropertyReads += 1
            return
        end
        if typeof(current) ~= "Color3" then
            stats.nonColorProperties += 1
            return
        end

        local roles = ThemeRoleRegistry[obj]
        local role = roles and roles[property]
        local registeredRole = role
        local currentRole = themeKeyForColor(current, property, oldTheme)
        if role and oldTheme[role] ~= current then
            if currentRole then
                role = currentRole
                if role ~= registeredRole then
                    recordRecovery(obj, property, registeredRole, role, current)
                end
            elseif not preserveInFlightRoles then
                role = themeKeyForPaletteColor(current, property, role)
                if role then
                    recordRecovery(obj, property, registeredRole, role, current)
                else
                    roles[property] = nil
                    stats.droppedRoles += 1
                    addRoleExample(stats.droppedExamples, obj, property, registeredRole, nil, current)
                end
            end
        end
        if not role then
            role = currentRole
            if not role then
                role = themeKeyForPaletteColor(current, property)
                if role then recordRecovery(obj, property, nil, role, current) end
            end
        end

        if role and newTheme[role] then
            stats.resolvedColorRoles += 1
            if not roles then
                roles = {}
                ThemeRoleRegistry[obj] = roles
            end
            roles[property] = role
            local target = newTheme[role]
            if target ~= current then
                changes[#changes + 1] = {
                    object = obj,
                    property = property,
                    from = current,
                    to = target,
                }
            end
        elseif role and #misses < 60 then
            misses[#misses + 1] = {
                path = pathOf(obj), prop = property, color = current,
                role = role, reason = "theme preset is missing a registered role",
            }
        end
    end

    local function collectGradient(obj)
        stats.gradientsScanned += 1
        local current = obj.Color
        if typeof(current) ~= "ColorSequence" then return end

        local keypoints = current.Keypoints
        local registered = ThemeGradientRoleRegistry[obj]
        local registeredRoles = registered and registered.roles
        local nextRoles = {}
        local targets = {}
        local changed = false

        for index, keypoint in ipairs(keypoints) do
            local role = registeredRoles and registeredRoles[index]
            local registeredRole = role
            local currentRole = themeKeyForColor(keypoint.Value, "Color", oldTheme)
            if role and oldTheme[role] ~= keypoint.Value then
                if currentRole then
                    role = currentRole
                    if role ~= registeredRole then
                        recordRecovery(obj, "Color[" .. index .. "]", registeredRole, role, keypoint.Value)
                    end
                elseif not preserveInFlightRoles then
                    role = themeKeyForPaletteColor(keypoint.Value, "Color", role)
                    if role then
                        recordRecovery(obj, "Color[" .. index .. "]", registeredRole, role, keypoint.Value)
                    else
                        stats.droppedRoles += 1
                        addRoleExample(stats.droppedExamples, obj, "Color[" .. index .. "]", registeredRole, nil, keypoint.Value)
                    end
                end
            end
            if not role then
                role = currentRole
                if not role then
                    role = themeKeyForPaletteColor(keypoint.Value, "Color")
                    if role then
                        recordRecovery(obj, "Color[" .. index .. "]", nil, role, keypoint.Value)
                    end
                end
            end

            local targetColor = keypoint.Value
            if role and newTheme[role] then
                nextRoles[index] = role
                targetColor = newTheme[role]
                if targetColor ~= keypoint.Value then changed = true end
            end
            targets[index] = ColorSequenceKeypoint.new(keypoint.Time, targetColor)
        end

        if next(nextRoles) then
            ThemeGradientRoleRegistry[obj] = { roles = nextRoles, keypointCount = #keypoints }
            if changed then
                stats.gradientUpdates += 1
                changes[#changes + 1] = {
                    object = obj,
                    property = "Color",
                    from = current,
                    to = ColorSequence.new(targets),
                }
            end
        else
            ThemeGradientRoleRegistry[obj] = nil
        end
    end

    for _, obj in ipairs(root:GetDescendants()) do
        stats.descendants += 1
        if obj:IsA("GuiObject") then
            collectProperty(obj, "BackgroundColor3")
            collectProperty(obj, "BorderColor3")
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                collectProperty(obj, "TextColor3")
                collectProperty(obj, "TextStrokeColor3")
            end
            if obj:IsA("TextBox") then
                collectProperty(obj, "PlaceholderColor3")
            end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("ViewportFrame") then
                collectProperty(obj, "ImageColor3")
            end
            if obj:IsA("ViewportFrame") then
                collectProperty(obj, "Ambient")
                collectProperty(obj, "LightColor")
            end
            if obj:IsA("ScrollingFrame") then
                collectProperty(obj, "ScrollBarImageColor3")
            end
        elseif obj:IsA("UIStroke") then
            collectProperty(obj, "Color")
        elseif obj:IsA("UIGradient") then
            collectGradient(obj)
        end
    end
    return changes, misses, stats
end

local function cancelThemeColorTweens(changes)
    local toCancel = {}
    for _, change in ipairs(changes) do
        local records = ActiveColorTweens[change.object]
        if records then
            for _, record in ipairs(records) do
                if record.properties[change.property] then
                    toCancel[record.tween] = true
                end
            end
        end
    end
    for activeTween in pairs(toCancel) do
        pcall(function() activeTween:Cancel() end)
    end
end

local function interpolateThemeValue(from, to, alpha)
    local valueType = typeof(from)
    if valueType == "Color3" and typeof(to) == "Color3" then
        return from:Lerp(to, alpha)
    end
    if valueType == "ColorSequence" and typeof(to) == "ColorSequence" then
        local fromPoints, toPoints = from.Keypoints, to.Keypoints
        if #fromPoints ~= #toPoints then
            return alpha >= 1 and to or from
        end
        local keypoints = table.create(#fromPoints)
        for index, fromPoint in ipairs(fromPoints) do
            local toPoint = toPoints[index]
            local time = fromPoint.Time + ((toPoint.Time - fromPoint.Time) * alpha)
            keypoints[index] = ColorSequenceKeypoint.new(time, fromPoint.Value:Lerp(toPoint.Value, alpha))
        end
        return ColorSequence.new(keypoints)
    end
    return alpha >= 1 and to or from
end

local function setTheme(name)
    if not Themes[name] then
        debugTrace("WARN", "Unknown theme: " .. tostring(name))
        return false
    end

    local previousTargetName = ThemeEngine.CurrentThemeName
    local activeThemeTransition = RuntimeDiagnostics.ActiveThemeTween ~= nil
        or RuntimeDiagnostics.ActiveThemeConnection ~= nil
    debugTrace("INFO", ("Theme request · selected=%s · applied=%s · requested=%s · inFlight=%s"):format(
        tostring(previousTargetName), tostring(ThemeEngine.AppliedThemeName),
        tostring(name), tostring(activeThemeTransition)
    ))
    if name == previousTargetName and activeThemeTransition then
        debugTrace("INFO", "Theme request kept current transition target: " .. name)
        return true
    end

    -- Keep the last fully rendered preset as the comparison baseline. The selected
    -- name can advance before an animation finishes or after an interrupted switch.
    local oldName = Themes[ThemeEngine.AppliedThemeName] and ThemeEngine.AppliedThemeName
        or previousTargetName
    local oldTheme = {}
    for k, v in pairs(Theme) do oldTheme[k] = v end
    for k, v in pairs(Themes[oldName]) do oldTheme[k] = v end

    local newThemeSnapshot = {}
    for k, v in pairs(Theme) do newThemeSnapshot[k] = v end
    for k, v in pairs(Themes[name]) do newThemeSnapshot[k] = v end

    local root = playerGui:FindFirstChild("DeepSeekUI")
    if not root then
        debugTrace("ERROR", "Theme root DeepSeekUI not found")
        return false
    end

    -- Collect first. If a property or object causes a scan failure, the current
    -- animation and selected/applied theme state remain intact.
    local activeObjectTweens = RuntimeDiagnostics.ActiveThemeObjectTweens
    local preserveInFlightRoles = RuntimeDiagnostics.ActiveThemeTween ~= nil
        or RuntimeDiagnostics.ActiveThemeConnection ~= nil
        or (activeObjectTweens ~= nil and #activeObjectTweens > 0)
    local scanStartedAt = os.clock()
    local collected, changes, misses, scanStats = pcall(
        collectThemeChanges, root, oldTheme, newThemeSnapshot, preserveInFlightRoles
    )
    if not collected then
        debugTrace("ERROR", "Theme color scan failed · " .. tostring(changes))
        return false
    end
    scanStats.durationMs = (os.clock() - scanStartedAt) * 1000
    ThemeDebug.LastScan = scanStats
    ThemeDebug.LastRoleRecoveries = scanStats.recoveredRoles
    ThemeDebug.LastRoleDrops = scanStats.droppedRoles
    debugTrace("INFO", ("Theme scan · %s → %s · descendants=%d · properties=%d · gradients=%d · updates=%d (gradients=%d) · %.1fms"):format(
        oldName, name, scanStats.descendants, scanStats.colorPropertiesRead,
        scanStats.gradientsScanned, #changes, scanStats.gradientUpdates, scanStats.durationMs
    ))
    debugTrace("INFO", ("Theme roles · resolved=%d · recovered=%d · dropped=%d · unsupported=%d · misses=%d"):format(
        scanStats.resolvedColorRoles, scanStats.recoveredRoles, scanStats.droppedRoles,
        scanStats.unsupportedPropertyReads, #misses
    ))
    for _, example in ipairs(scanStats.recoveryExamples) do
        debugTrace("INFO", ("Theme role recovered · %s.%s · %s → %s"):format(
            example.path, example.property, tostring(example.previousRole or "unregistered"),
            tostring(example.resolvedRole)
        ))
    end
    for _, example in ipairs(scanStats.droppedExamples) do
        debugTrace("WARN", ("Theme role dropped · %s.%s · previous=%s · color=%s"):format(
            example.path, example.property, tostring(example.previousRole), example.color
        ))
    end
    if scanStats.unsupportedPropertyReads > 0 then
        debugTrace("WARN", ("Theme scan skipped %d unsupported property reads"):format(
            scanStats.unsupportedPropertyReads
        ))
    end
    for index = 1, math.min(#misses, 5) do
        local miss = misses[index]
        debugTrace("WARN", ("Theme preset miss · %s.%s · role=%s"):format(
            miss.path, miss.prop, tostring(miss.role)
        ))
    end

    if name == previousTargetName and name == oldName and #changes == 0
        and not preserveInFlightRoles then
        debugTrace("INFO", "Theme already synchronized · " .. name)
        return true
    end

    -- Only commit the target after a complete scan succeeds. This avoids leaving
    -- Theme/current-name state ahead of the actual UI when an error occurs.
    RuntimeDiagnostics.ThemeTransitionToken += 1
    local generation = RuntimeDiagnostics.ThemeTransitionToken

    if activeObjectTweens then
        for _, objectTween in ipairs(activeObjectTweens) do
            pcall(function() objectTween:Cancel() end)
        end
        RuntimeDiagnostics.ActiveThemeObjectTweens = nil
    end
    if RuntimeDiagnostics.ActiveThemeTween then
        pcall(function() RuntimeDiagnostics.ActiveThemeTween:Cancel() end)
        RuntimeDiagnostics.ActiveThemeTween = nil
    end
    if RuntimeDiagnostics.ActiveThemeConnection then
        pcall(function() RuntimeDiagnostics.ActiveThemeConnection:Disconnect() end)
        RuntimeDiagnostics.ActiveThemeConnection = nil
    end
    if RuntimeDiagnostics.ActiveThemeProgress then
        pcall(function() RuntimeDiagnostics.ActiveThemeProgress:Destroy() end)
        RuntimeDiagnostics.ActiveThemeProgress = nil
    end

    for k, v in pairs(Themes[name]) do Theme[k] = v end
    ThemeEngine.CurrentThemeName = name
    RuntimeDiagnostics.ThemeSaveToken += 1
    local saveToken = RuntimeDiagnostics.ThemeSaveToken
    -- Coalesce file writes so rapid theme changes persist only the final choice.
    task.delay(0.15, function()
        if RuntimeDiagnostics.ThemeSaveToken == saveToken then saveSettings() end
    end)

    cancelThemeColorTweens(changes)
    local overlay = RuntimeDiagnostics.ThemeTransitionOverlay
    local transitionDuration = preserveInFlightRoles and 0.28 or 0.42
    local transitionStartedAt = os.clock()
    local changeGroups, changesByObject = {}, {}
    for _, change in ipairs(changes) do
        local object = change.object
        if object and object.Parent then
            local group = changesByObject[object]
            if not group then
                group = { object = object, changes = {} }
                changesByObject[object] = group
                changeGroups[#changeGroups + 1] = group
            end
            group.changes[#group.changes + 1] = change
        end
    end
    local transitionFinished = false
    debugTrace("INFO", ("Theme transition start · id=%d · %s → %s · duration=%.2fs · updates=%d · groups=%d · interrupted=%s"):format(
        generation, oldName, name, transitionDuration, #changes,
        #changeGroups, tostring(preserveInFlightRoles)
    ))

    local function finishThemeTransition()
        if generation ~= RuntimeDiagnostics.ThemeTransitionToken or transitionFinished then return end
        transitionFinished = true
        ThemeEngine.AppliedThemeName = name
        if overlay and overlay.Parent then
            -- Progress reaches full transparency before the transition surface is hidden.
            overlay.Visible = false
        end

        ThemeDebug.TotalUpdates += #changes
        ThemeDebug.TotalMisses += #misses
        ThemeDebug.LastMisses = misses
        ThemeDebug.History[#ThemeDebug.History + 1] = {
            from = oldName, to = name, updates = #changes, misses = #misses,
            timestamp = os.clock(), detail = misses,
        }
        if #ThemeDebug.History > 30 then table.remove(ThemeDebug.History, 1) end

        RuntimeDiagnostics.ThemeSwitchCount += 1
        RuntimeDiagnostics.LastThemeColorUpdates = #changes
        RuntimeDiagnostics.LastThemeSwitch = ("%s → %s · %d animated · %d missed"):format(oldName, name, #changes, #misses)
        debugTrace(#misses > 0 and "WARN" or "INFO", ("Theme transition complete · id=%d · %s → %s · updates=%d · misses=%d · elapsed=%.1fms"):format(
            generation, oldName, name, #changes, #misses, (os.clock() - transitionStartedAt) * 1000
        ))
        if RuntimeDiagnostics.ThemeDebugLabel and RuntimeDiagnostics.ThemeDebugLabel.Parent then
            RuntimeDiagnostics.ThemeDebugLabel.Text = "Theme engine: " .. RuntimeDiagnostics.LastThemeSwitch
            RuntimeDiagnostics.ThemeDebugLabel.TextColor3 = #misses > 0 and Theme.Danger or Theme.MutedText
        end
        if RuntimeDiagnostics.ActiveThemeConnection then
            RuntimeDiagnostics.ActiveThemeConnection:Disconnect()
            RuntimeDiagnostics.ActiveThemeConnection = nil
        end
        if RuntimeDiagnostics.ActiveThemeProgress then
            RuntimeDiagnostics.ActiveThemeProgress:Destroy()
            RuntimeDiagnostics.ActiveThemeProgress = nil
        end
        RuntimeDiagnostics.ActiveThemeTween = nil
        RuntimeDiagnostics.ActiveThemeObjectTweens = nil
    end

    if #changes == 0 then
        debugTrace("INFO", "Theme transition has no color updates; synchronizing applied-theme state.")
        finishThemeTransition()
        return #misses == 0
    end

    if overlay and overlay.Parent then overlay.Visible = true end

    -- A single eased progress value drives every tracked color on the same frame.
    -- This keeps the whole palette synchronized without creating one tween per UI object.
    local progress = Instance.new("NumberValue")
    progress.Name = "ThemeTransitionProgress"
    progress.Value = 0
    RuntimeDiagnostics.ActiveThemeProgress = progress

    local function applyProgress(alpha)
        if generation ~= RuntimeDiagnostics.ThemeTransitionToken then return end
        for _, group in ipairs(changeGroups) do
            local object = group.object
            if object and object.Parent then
                for _, change in ipairs(group.changes) do
                    object[change.property] = interpolateThemeValue(change.from, change.to, alpha)
                end
            end
        end
        if overlay and overlay.Parent then
            -- Keep the subtle wash synchronized with the same shared progress value.
            overlay.BackgroundTransparency = 0.965 + (0.035 * alpha)
        end
    end

    RuntimeDiagnostics.ActiveThemeConnection = progress:GetPropertyChangedSignal("Value"):Connect(function()
        applyProgress(progress.Value)
    end)

    RuntimeDiagnostics.ActiveThemeTween = TweenService:Create(
        progress,
        TweenInfo.new(transitionDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { Value = 1 }
    )
    RuntimeDiagnostics.ActiveThemeTween.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            finishThemeTransition()
        end
    end)
    RuntimeDiagnostics.ActiveThemeTween:Play()
    return true
end

ThemeEngine.setTheme = setTheme
