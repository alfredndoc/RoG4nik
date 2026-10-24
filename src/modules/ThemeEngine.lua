--============================================================
--// THEME ENGINE STATE / DIAGNOSTICS
--============================================================
local ThemeEngine = {
    CurrentThemeName = "Dark",
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
    ActiveThemeTween = nil,
    ActiveThemeConnection = nil,
    ActiveThemeProgress = nil,
}
ThemeEngine.RuntimeDiagnostics = RuntimeDiagnostics

local ThemeDebug = { History = {}, LastMisses = {}, TotalUpdates = 0, TotalMisses = 0 }
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

local function debugTrace(level, message)
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
    RuntimeDiagnostics.LastThemeSwitch = "Initial theme: " .. name
    return true
end

--============================================================
--// BASE HELPERS
--============================================================
local themeKeyForColor
local ThemeRoleRegistry = setmetatable({}, { __mode = "k" })
local ThemeBaseTransparency = setmetatable({}, { __mode = "k" })
local ThemeStrokeBase = setmetatable({}, { __mode = "k" })
local ThemeAppearance = { Advanced = false, Transparency = 0.14, Gloss = 0.25, Gradient = true }
local ThemeSurfaceRoles = {
    Background = true, Sidebar = true, Panel = true, PanelRaised = true, RightBg = true,
    Selected = true, SegmentedBg = true,
}
local function applyAppearanceToObject(obj) end
local ThemeColorProperties = {
    BackgroundColor3 = true, TextColor3 = true, ImageColor3 = true, Color = true,
    PlaceholderColor3 = true, ScrollBarImageColor3 = true, BorderColor3 = true,
    TextStrokeColor3 = true,
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
        local ok, value = pcall(function() return inst[propName] end)
        if ok and typeof(value) == "Color3" and themeKeyForColor then
            local role = themeKeyForColor(value, propName, Theme)
            if role then roles[propName] = role end
        end
    end
    if next(roles) then ThemeRoleRegistry[inst] = roles end
    if inst:IsA("GuiObject") then
        ThemeBaseTransparency[inst] = inst.BackgroundTransparency
    elseif inst:IsA("UIStroke") then
        ThemeStrokeBase[inst] = { Transparency = inst.Transparency, Thickness = inst.Thickness }
    end
    if parent then inst.Parent = parent end
    if applyAppearanceToObject then applyAppearanceToObject(inst) end
    return inst
end

local function tween(instance, goals, duration, style, direction)
    if not instance or not instance.Parent then return end
    local info = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
    local anim = TweenService:Create(instance, info, goals)
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

local function resolvedAppearance()
    if not ThemeAppearance.Advanced then
        return { Transparency = 0.14, Gloss = 0.25, Gradient = true }
    end
    return {
        Transparency = math.clamp(tonumber(ThemeAppearance.Transparency) or 0.14, 0, 1),
        Gloss = math.clamp(tonumber(ThemeAppearance.Gloss) or 0.25, 0, 1),
        Gradient = ThemeAppearance.Gradient == true,
    }
end

applyAppearanceToObject = function(obj)
    local appearance = resolvedAppearance()
    local roles = ThemeRoleRegistry[obj]
    if roles and roles.BackgroundColor3 and ThemeSurfaceRoles[roles.BackgroundColor3] and obj:IsA("GuiObject") then
        local baseTransparency = ThemeBaseTransparency[obj] or 0
        if baseTransparency < 0.75 then
            obj.BackgroundTransparency = baseTransparency + ((1 - baseTransparency) * appearance.Transparency)
            if obj:IsA("Frame") then
                local gradient = obj:FindFirstChild("ThemeSurfaceGradient")
                if appearance.Gradient then
                    if not gradient and obj:FindFirstChildOfClass("UIGradient") then
                        return
                    end
                    if not gradient then
                        gradient = Instance.new("UIGradient")
                        gradient.Name = "ThemeSurfaceGradient"
                        gradient.Rotation = 90
                        gradient.Parent = obj
                    end
                    gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(224, 228, 240))
                    gradient.Transparency = NumberSequence.new(0.92 - (appearance.Gloss * 0.5), 0.99 - (appearance.Gloss * 0.2))
                elseif gradient then
                    gradient:Destroy()
                end
            end
        end
    elseif obj:IsA("UIStroke") then
        local base = ThemeStrokeBase[obj]
        local parentRoles = obj.Parent and ThemeRoleRegistry[obj.Parent]
        if base and parentRoles and parentRoles.BackgroundColor3 and ThemeSurfaceRoles[parentRoles.BackgroundColor3] then
            obj.Transparency = math.clamp(base.Transparency - (appearance.Gloss * 0.3), 0, 1)
            obj.Thickness = base.Thickness + (appearance.Gloss * 0.5)
        end
    end
end

function ThemeEngine.setAppearanceSettings(settings)
    settings = settings or {}
    ThemeAppearance.Advanced = settings.Advanced == true
    ThemeAppearance.Transparency = math.clamp(tonumber(settings.Transparency) or 0.14, 0, 1)
    ThemeAppearance.Gloss = math.clamp(tonumber(settings.Gloss) or 0.25, 0, 1)
    ThemeAppearance.Gradient = settings.Gradient ~= false
    for obj in pairs(ThemeRoleRegistry) do
        if obj and obj.Parent then applyAppearanceToObject(obj) end
    end
    -- Reapply stroke styling after their parent surfaces have been visited.
    for obj in pairs(ThemeStrokeBase) do
        if obj and obj.Parent then applyAppearanceToObject(obj) end
    end
end
ThemeEngine.getAppearanceSettings = function()
    local appearance = resolvedAppearance()
    return { Advanced = ThemeAppearance.Advanced, Transparency = appearance.Transparency, Gloss = appearance.Gloss, Gradient = appearance.Gradient }
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
    Color = { "Accent", "AccentHover", "Border", "Danger", "MutedText", "QuietText", "PrimaryText", "White" },
}

themeKeyForColor = function(c, propName, sourceTheme)
    if typeof(c) ~= "Color3" then return nil end
    sourceTheme = sourceTheme or Theme
    local priority = THEME_KEY_PRIORITY[propName]
    if priority then
        for _, key in ipairs(priority) do
            if sourceTheme[key] == c then return key end
        end
    end
    local keys = {}
    for key in pairs(sourceTheme) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        if typeof(sourceTheme[key]) == "Color3" and sourceTheme[key] == c then return key end
    end
    return nil
end

local function collectThemeChanges(root, oldTheme, newTheme)
    local changes, misses = {}, {}
    if not root then return changes, misses end
    -- Some controls update their colors after construction, so the creation-time
    -- role registry alone is incomplete. Scan once when switching themes and infer
    -- roles from the colors actually on screen; the large-change path below avoids
    -- repeating this work during every animation frame.
    local objects = { root }
    for _, obj in ipairs(root:GetDescendants()) do objects[#objects + 1] = obj end

    for _, obj in ipairs(objects) do
        local roles = ThemeRoleRegistry[obj]
        for propName in pairs(ThemeColorProperties) do
            local readOk, current = pcall(function() return obj[propName] end)
            if readOk and typeof(current) == "Color3" then
                local role = roles and roles[propName]
                -- If the property was changed to a different palette color after
                -- creation, prefer its current exact role. Keep the saved role when
                -- the current value is an in-between transition color.
                if role and oldTheme[role] ~= current then
                    local redetected = themeKeyForColor(current, propName, oldTheme)
                    if redetected then role = redetected end
                end
                if role and not newTheme[role] then role = nil end
                if not role then role = themeKeyForColor(current, propName, oldTheme) end

                if role and newTheme[role] then
                    if not roles then
                        roles = {}
                        ThemeRoleRegistry[obj] = roles
                    end
                    roles[propName] = role
                    local target = newTheme[role]
                    if target ~= current then
                        changes[#changes + 1] = {
                            object = obj,
                            property = propName,
                            from = current,
                            to = target,
                            role = role,
                        }
                    end
                elseif #misses < 60 then
                    misses[#misses + 1] = {
                        path = pathOf(obj), prop = propName, color = current,
                        reason = "no theme role match",
                    }
                end
            end
        end
    end
    return changes, misses
end


local function setTheme(name)
    if not Themes[name] then
        debugTrace("WARN", "Unknown theme: " .. tostring(name))
        return false
    end
    if name == ThemeEngine.CurrentThemeName then
        debugTrace("INFO", "Theme already active: " .. name)
        return true
    end

    local oldName = ThemeEngine.CurrentThemeName
    local oldTheme = {}
    for k, v in pairs(Theme) do oldTheme[k] = v end

    local newThemeSnapshot = {}
    for k, v in pairs(Theme) do newThemeSnapshot[k] = v end
    for k, v in pairs(Themes[name]) do newThemeSnapshot[k] = v end
    -- Theme includes font entries as well as colors. Keep the active theme table's
    -- extra fields (fonts) and only replace the theme values from the selected preset.
    for k, v in pairs(Themes[name]) do Theme[k] = v end
    ThemeEngine.CurrentThemeName = name
    saveSettings()

    local root = playerGui:FindFirstChild("DeepSeekUI")
    if not root then
        debugTrace("ERROR", "Theme root DeepSeekUI not found")
        return false
    end

    RuntimeDiagnostics.ThemeTransitionToken += 1
    local generation = RuntimeDiagnostics.ThemeTransitionToken

    -- Cancel the previous animation cleanly. An interrupted transition starts from
    -- the actual on-screen colors, not from a stale theme snapshot.
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

    local changes, misses = collectThemeChanges(root, oldTheme, newThemeSnapshot)
    local overlay = RuntimeDiagnostics.ThemeTransitionOverlay
    local overlayStartBg = overlay and overlay.BackgroundColor3 or oldTheme.Background
    local overlayGoalBg = newThemeSnapshot.Background or Theme.Background
    local overlayGradient = overlay and overlay:FindFirstChildOfClass("UIGradient")
    local oldAccent = oldTheme.Accent or Theme.Accent
    local oldAccentHover = oldTheme.AccentHover or oldAccent
    local newAccent = newThemeSnapshot.Accent or Theme.Accent
    local newAccentHover = newThemeSnapshot.AccentHover or newAccent

    local function finishThemeTransition(colorsAlreadyApplied)
        if generation ~= RuntimeDiagnostics.ThemeTransitionToken then return end
        if not colorsAlreadyApplied then
            for _, change in ipairs(changes) do
                if change.object and change.object.Parent then
                    pcall(function() change.object[change.property] = change.to end)
                end
            end
        end
        if overlay and overlay.Parent then
            overlay.BackgroundTransparency = 1
            overlay.BackgroundColor3 = overlayGoalBg
            -- Hide the transition surface explicitly. UIGradient transparency can
            -- still render independently of the frame's BackgroundTransparency.
            overlay.Visible = false
        end
        if overlayGradient then
            overlayGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, newAccent),
                ColorSequenceKeypoint.new(0.5, newAccentHover),
                ColorSequenceKeypoint.new(1, newAccent),
            })
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
        debugTrace(#misses > 0 and "WARN" or "INFO", "Theme switch: " .. RuntimeDiagnostics.LastThemeSwitch)
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
    end

    if #changes == 0 then
        finishThemeTransition()
        return #misses == 0
    end

    if overlay and overlay.Parent then overlay.Visible = true end

    -- Large interfaces can have hundreds of registered color properties. Updating
    -- every property on every animation frame stalls the render thread. Apply those
    -- colors once, then animate the lightweight full-window wash for a smooth
    -- transition. Small changes retain the precise per-property interpolation.
    local useOverlayOnly = #changes > 120
    if useOverlayOnly then
        for _, change in ipairs(changes) do
            if change.object and change.object.Parent then
                pcall(function() change.object[change.property] = change.to end)
            end
        end
        if overlay and overlay.Parent then
            overlay.BackgroundColor3 = overlayStartBg
            overlay.BackgroundTransparency = 0.62
        end
        if overlayGradient then
            overlayGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, oldAccent),
                ColorSequenceKeypoint.new(0.5, oldAccentHover),
                ColorSequenceKeypoint.new(1, oldAccent),
            })
        end
    end

    -- One shared progress tween drives every affected color. This avoids creating
    -- hundreds of individual property tweens and ensures the entire UI transitions
    -- together instead of changing control-by-control.
    local progress = Instance.new("NumberValue")
    progress.Name = "ThemeTransitionProgress"
    progress.Value = 0
    RuntimeDiagnostics.ActiveThemeProgress = progress

    local function applyProgress(alpha)
        if generation ~= RuntimeDiagnostics.ThemeTransitionToken then return end
        if not useOverlayOnly then
            for _, change in ipairs(changes) do
                local obj = change.object
                if obj and obj.Parent then
                    pcall(function()
                        obj[change.property] = change.from:Lerp(change.to, alpha)
                    end)
                end
            end
        end
        if overlay and overlay.Parent then
            overlay.BackgroundColor3 = overlayStartBg:Lerp(overlayGoalBg, alpha)
            -- A subtle wash gives the transition a cohesive gradient feel without
            -- hiding the UI or blocking input.
            overlay.BackgroundTransparency = (useOverlayOnly and 0.62 or 0.965) + ((useOverlayOnly and 0.38 or 0.035) * alpha)
        end
        if overlayGradient then
            overlayGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, oldAccent:Lerp(newAccent, alpha)),
                ColorSequenceKeypoint.new(0.5, oldAccentHover:Lerp(newAccentHover, alpha)),
                ColorSequenceKeypoint.new(1, oldAccent:Lerp(newAccent, alpha)),
            })
        end
    end

    RuntimeDiagnostics.ActiveThemeConnection = progress:GetPropertyChangedSignal("Value"):Connect(function()
        applyProgress(progress.Value)
    end)
    RuntimeDiagnostics.ActiveThemeTween = TweenService:Create(
        progress,
        TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
        { Value = 1 }
    )
    RuntimeDiagnostics.ActiveThemeTween.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            finishThemeTransition(useOverlayOnly)
        end
    end)
    RuntimeDiagnostics.ActiveThemeTween:Play()
    return true
end

ThemeEngine.setTheme = setTheme
