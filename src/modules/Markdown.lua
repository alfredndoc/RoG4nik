--============================================================
--// MARKDOWN RENDERER
--============================================================
local function parseCodeHeader(firstLine)
    firstLine = (firstLine or ""):gsub("%s+$", "")
    local lang, tag = firstLine:match("^(%w+)%s+%[([^%]]+)%]$")
    if lang then return lang, tag end
    local solo = firstLine:match("^(%w+)$")
    if solo then return solo, nil end
    local t = firstLine:match("%[([^%]]+)%]")
    if t then return "", t end
    return "", nil
end

local function createReasoningBlock(parent, reasoningText, startCollapsed, order)
    local container = create("Frame", {
        Name = "ReasoningBlock", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.35, BorderSizePixel = 0,
        LayoutOrder = order, ZIndex = 4,
    }, parent)
    corner(container, 9)
    stroke(container, Theme.Border, 1, 0.5)
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, container)
    padding(container, 0, 0, 4, 4)
    local header = create("TextButton", {
        Name = "ReasoningHeader", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = 1, ZIndex = 5,
    }, container)
    local chevron = create("TextLabel", {
        Position = UDim2.new(0, 8, 0, 0), Size = UDim2.fromOffset(14, 26), BackgroundTransparency = 1,
        Text = startCollapsed and "+" or "−", TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 14, ZIndex = 6,
    }, header)
    create("Frame", {
        Position = UDim2.new(0, 26, 0.5, -8), Size = UDim2.fromOffset(2, 16),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 6,
    }, header)
    create("TextLabel", {
        Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -110, 0, 26), BackgroundTransparency = 1,
        Text = "Reasoning", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, header)
    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(60, 26),
        BackgroundTransparency = 1, Text = "Details", TextColor3 = Theme.MutedText, Font = Theme.Font,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
    }, header)
    local body = create("TextLabel", {
        Name = "ReasoningBody", Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = reasoningText, TextColor3 = Theme.MutedText, Font = Theme.Font,
        TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Visible = not startCollapsed, LayoutOrder = 2, ZIndex = 6,
    }, container)
    padding(body, 12, 12, 0, 6)
    header.MouseButton1Click:Connect(function()
        if body then
            body.Visible = not body.Visible
            chevron.Text = body.Visible and "−" or "+"
        end
    end)
    return container
end

UIRefs.LuaKeywords = {
        ["and"] = "#C792EA", ["break"] = "#FF6B6B", ["do"] = "#C792EA", ["else"] = "#C792EA",
        ["elseif"] = "#C792EA", ["end"] = "#C792EA", ["false"] = "#F78C6C", ["for"] = "#C792EA",
        ["function"] = "#C792EA", ["if"] = "#C792EA", ["in"] = "#C792EA", ["local"] = "#FF6B6B",
        ["nil"] = "#F78C6C", ["not"] = "#C792EA", ["or"] = "#C792EA", ["repeat"] = "#C792EA",
        ["return"] = "#C792EA", ["then"] = "#C792EA", ["true"] = "#F78C6C", ["until"] = "#C792EA",
        ["while"] = "#C792EA", ["continue"] = "#C792EA",
}
UIRefs.LuaBuiltins = {
        assert = true, error = true, getmetatable = true, ipairs = true, next = true,
        pairs = true, pcall = true, print = true, rawequal = true, rawget = true,
        rawlen = true, rawset = true, select = true, setmetatable = true, tonumber = true,
        tostring = true, type = true, typeof = true, xpcall = true, game = true,
        Instance = true, Enum = true, Color3 = true, Vector2 = true, Vector3 = true,
        UDim = true, UDim2 = true, CFrame = true, math = true, string = true,
        table = true, task = true, workspace = true, script = true,
}

UIRefs.HighlightLua = function(source)
    source = tostring(source or "")
    local output, index = {}, 1
    local function escape(value)
        return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    end
    local function append(value, color)
        value = escape(value)
        if color then output[#output + 1] = '<font color="' .. color .. '">' .. value .. "</font>"
        else output[#output + 1] = value end
    end

    while index <= #source do
        local current = source:sub(index, index)
        if source:sub(index, index + 1) == "--" then
            local finish = source:find("\n", index, true) or (#source + 1)
            append(source:sub(index, finish - 1), "#7F8798")
            index = finish
        elseif current == "'" or current == '"' then
            local start, quote = index, current
            index = index + 1
            while index <= #source do
                local char = source:sub(index, index)
                if char == "\\" then index = index + 2
                elseif char == quote then index = index + 1; break
                else index = index + 1 end
            end
            append(source:sub(start, math.min(index - 1, #source)), "#A5D6A7")
        elseif current:match("[%a_]") then
            local start = index
            repeat index = index + 1 until index > #source or not source:sub(index, index):match("[%w_]")
            local token = source:sub(start, index - 1)
            local color = UIRefs.LuaKeywords[token] or (UIRefs.LuaBuiltins[token] and "#82AAFF")
            append(token, color)
        elseif current:match("%d") then
            local start = index
            if source:sub(index, index + 1):lower() == "0x" then
                index = index + 2
                while index <= #source and source:sub(index, index):match("[%da-fA-F]") do index = index + 1 end
            else
                while index <= #source and source:sub(index, index):match("%d") do index = index + 1 end
                if source:sub(index, index) == "." and source:sub(index + 1, index + 1):match("%d") then
                    index = index + 1
                    while index <= #source and source:sub(index, index):match("%d") do index = index + 1 end
                end
                if source:sub(index, index):match("[eE]") then
                    local exponent = index
                    index = index + 1
                    if source:sub(index, index):match("[%+%-]") then index = index + 1 end
                    local digits = index
                    while index <= #source and source:sub(index, index):match("%d") do index = index + 1 end
                    if index == digits then index = exponent end
                end
            end
            append(source:sub(start, index - 1), "#F78C6C")
        else
            append(current)
            index = index + 1
        end
    end
    return table.concat(output)
end

local function renderCodeBlock(parent, code, language, tag, order)
    local codeFrame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.SegmentedBg, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 4,
    }, parent)
    corner(codeFrame, 8)
    stroke(codeFrame, Theme.Border, 1, 0.5)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, codeFrame)
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
        LayoutOrder = 1, ZIndex = 5,
    }, codeFrame)
    corner(header, 8)
    local headerLabel = (language ~= "" and language:upper() or "CODE")
    if tag then
        local base = tag:match("^(%w+)") or tag
        headerLabel = headerLabel .. " · " .. base:upper()
    end
    create("TextLabel", {
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -130, 1, 0),
        BackgroundTransparency = 1, Text = headerLabel, TextColor3 = Theme.MutedText,
        Font = Theme.FontBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, header)
    local copyBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(50, 20), BackgroundColor3 = Theme.Accent, Text = "Copy",
        TextColor3 = Theme.White, Font = Theme.FontBold, TextSize = 10, AutoButtonColor = false, ZIndex = 6,
    }, header)
    corner(copyBtn, 6)
    local runBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0),
        Size = UDim2.fromOffset(50, 20), BackgroundColor3 = Theme.PanelRaised,
        Text = "Run", TextColor3 = Theme.PrimaryText, Font = Theme.FontBold,
        TextSize = 10, AutoButtonColor = false, ZIndex = 6,
    }, header)
    corner(runBtn, 6)
    runBtn.Visible = not (tag and tostring(tag):upper():match("^FINAL"))
    bindSoftButton(runBtn, { BackgroundColor3 = Theme.Accent, TextColor3 = Theme.White }, 1.06)
    local codeBox = create("TextLabel", {
        Name = "HighlightedCode", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 2, RichText = true,
        Text = UIRefs.HighlightLua(code), TextColor3 = Theme.PrimaryText,
        Font = Theme.FontCode, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, ZIndex = 5,
    }, codeFrame)
    padding(codeBox, 10, 10, 8, 8)
    local outputLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 3,
        Text = "", TextColor3 = Theme.MutedText, Font = Theme.FontCode,
        TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false, ZIndex = 5,
    }, codeFrame)
    padding(outputLabel, 10, 10, 6, 8)
    copyBtn.MouseButton1Click:Connect(function()
        local copied = false
        if type(setclipboard) == "function" then
            copied = pcall(setclipboard, code)
        end
        copyBtn.Text = copied and "Copied!" or "Select code"
        task.delay(1.2, function()
            if copyBtn.Parent then copyBtn.Text = "Copy" end
        end)
    end)
    runBtn.MouseButton1Click:Connect(function()
        local entry = runInSandbox(code)
        outputLabel.Visible = true
        if entry.ok then
            local out = entry.output
            if out == "" and entry.result then out = entry.result end
            outputLabel.Text = "▸ " .. (out ~= "" and out or "(no output)")
            outputLabel.TextColor3 = Theme.PrimaryText
        else
            outputLabel.Text = "✗ " .. tostring(entry.error)
            outputLabel.TextColor3 = Theme.Danger
        end
    end)
    return codeFrame
end

-- The editor remains a real TextBox for input and selection. A rich-text layer
-- beneath it colors tokens, while the gutter numbers the original source lines.
if UIRefs.CodeScroll and UIRefs.CodeTextBox then
    UIRefs.CodeScroll.ScrollingDirection = Enum.ScrollingDirection.XY
    UIRefs.CodeGutter = create("TextLabel", {
        Name = "LineNumbers", Position = UDim2.new(0, 0, 0, 4),
        Size = UDim2.new(0, 34, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = "1", TextColor3 = Theme.QuietText,
        Font = Theme.FontCode, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false, ZIndex = 6,
    }, UIRefs.CodeScroll)
    UIRefs.CodeHighlight = create("TextLabel", {
        Name = "SyntaxHighlight", Position = UDim2.new(0, 44, 0, 0),
        Size = UDim2.new(0, 320, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = "", RichText = true,
        TextColor3 = Theme.PrimaryText, Font = Theme.FontCode, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false, ZIndex = 6,
    }, UIRefs.CodeScroll)
    padding(UIRefs.CodeHighlight, 4, 4, 4, 4)
    UIRefs.CodeTextBox.Position = UDim2.new(0, 44, 0, 0)
    UIRefs.CodeTextBox.Size = UDim2.new(0, 320, 0, 0)
    UIRefs.CodeTextBox.AutomaticSize = Enum.AutomaticSize.Y
    UIRefs.CodeTextBox.TextWrapped = false
    UIRefs.CodeTextBox.TextTransparency = 1
    UIRefs.CodeTextBox.SelectionColor3 = Theme.Accent
    UIRefs.CodeTextBox.ZIndex = 7

    UIRefs.SyncCodeEditorMetrics = function()
        if not UIRefs.CodeTextBox or not UIRefs.CodeTextBox.Parent then return end
        local width = math.max(240, UIRefs.CodeScroll.AbsoluteSize.X - 54, UIRefs.CodeTextBox.TextBounds.X + 12)
        UIRefs.CodeHighlight.Size = UDim2.new(0, width, 0, 0)
        UIRefs.CodeTextBox.Size = UDim2.new(0, width, 0, 0)
        UIRefs.CodeScroll.CanvasSize = UDim2.new(0, width + 54,
            0, math.max(UIRefs.CodeScroll.AbsoluteSize.Y, UIRefs.CodeTextBox.TextBounds.Y + 16))
    end
    UIRefs.UpdateCodeEditor = function()
        if not UIRefs.CodeTextBox or not UIRefs.CodeTextBox.Parent then return end
        local source = UIRefs.CodeTextBox.Text or ""
        local lineCount = 1
        for _ in source:gmatch("\n") do lineCount = lineCount + 1 end
        local numbers = {}
        for line = 1, lineCount do numbers[line] = tostring(line) end
        UIRefs.CodeGutter.Text = table.concat(numbers, "\n")
        UIRefs.CodeHighlight.Text = UIRefs.HighlightLua(source)
        UIRefs.SyncCodeEditorMetrics()
    end

    UIRefs.CodeTextBox:GetPropertyChangedSignal("TextBounds"):Connect(UIRefs.SyncCodeEditorMetrics)
    UIRefs.CodeScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(UIRefs.SyncCodeEditorMetrics)

    UIRefs.CodeEditorPreviousText = UIRefs.CodeTextBox.Text
    UIRefs.CodeEditorGuard = false
    UIRefs.CodeTextBox:GetPropertyChangedSignal("Text"):Connect(function()
        if UIRefs.CodeEditorGuard then return end
        local box = UIRefs.CodeTextBox
        local text = box.Text or ""
        local previous = UIRefs.CodeEditorPreviousText or ""
        local cursor = box.CursorPosition
        local inserted = nil
        if cursor >= 2 and #text == #previous + 1 then
            local candidate = text:sub(cursor - 1, cursor - 1)
            if text:sub(1, cursor - 2) .. text:sub(cursor) == previous then inserted = candidate end
        end
        if inserted then
            local indent = ""
            if inserted == "\n" then
                local previousLine = text:sub(1, cursor - 2):match("([^\n]*)$") or ""
                indent = previousLine:match("^[ \t]*") or ""
                if previousLine:match("then%s*$") or previousLine:match("do%s*$")
                    or previousLine:match("function%s*[%w_%.:]*%s*%b()%s*$") or previousLine:match("{%s*$") then
                    indent = indent .. "    "
                end
            elseif inserted == "(" or inserted == "[" or inserted == "{" then
                local closing = inserted == "(" and ")" or (inserted == "[" and "]" or "}")
                UIRefs.CodeEditorGuard = true
                box.Text = text:sub(1, cursor - 1) .. closing .. text:sub(cursor)
                box.CursorPosition = cursor
                UIRefs.CodeEditorGuard = false
                text = box.Text
            end
            if inserted == "\n" and indent ~= "" then
                UIRefs.CodeEditorGuard = true
                box.Text = text:sub(1, cursor - 1) .. indent .. text:sub(cursor)
                box.CursorPosition = cursor + #indent
                UIRefs.CodeEditorGuard = false
                text = box.Text
            end
        end
        UIRefs.CodeEditorPreviousText = text
        task.defer(UIRefs.UpdateCodeEditor)
    end)

    UIRefs.CodeTextBox.InputBegan:Connect(function(input)
        if input.KeyCode ~= Enum.KeyCode.Tab then return end
        task.defer(function()
            local box = UIRefs.CodeTextBox
            if not box or not box.Parent then return end
            box:CaptureFocus()
            local text, cursor = box.Text or "", box.CursorPosition
            if cursor < 1 then return end
            local before = text:sub(1, cursor - 1)
            local prefix = before:match("([%a_][%w_]*)$")
            local completion = nil
            if prefix then
                local earlier = before:sub(1, #before - #prefix)
                for token in earlier:gmatch("[%a_][%w_]*") do
                    if #token > #prefix and token:sub(1, #prefix) == prefix then
                        completion = token
                        break
                    end
                end
            end
            UIRefs.CodeEditorGuard = true
            if completion then
                box.Text = text:sub(1, cursor - #prefix - 1) .. completion .. text:sub(cursor)
                box.CursorPosition = cursor + #completion - #prefix
                if UIRefs.CodeStatusLabel then
                    UIRefs.CodeStatusLabel.Text = "Completed from earlier code · " .. completion
                    UIRefs.CodeStatusLabel.TextColor3 = Theme.MutedText
                end
            else
                box.Text = text:sub(1, cursor - 1) .. "    " .. text:sub(cursor)
                box.CursorPosition = cursor + 4
            end
            UIRefs.CodeEditorPreviousText = box.Text
            UIRefs.CodeEditorGuard = false
            task.defer(UIRefs.UpdateCodeEditor)
        end)
    end)
    task.defer(UIRefs.UpdateCodeEditor)
end

local RichFormatter = {}

function RichFormatter.trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function RichFormatter.escape(value)
    return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

function RichFormatter.inline(value)
    local result = RichFormatter.escape(value)
    result = result:gsub("`([^`]+)`", '<font face="Code" color="#91B7FF">%1</font>')
    result = result:gsub("%*%*([^*]+)%*%*", "<b>%1</b>")
    result = result:gsub("~~([^~]+)~~", "<s>%1</s>")
    result = result:gsub("%*([^*]+)%*", "<i>%1</i>")
    return result
end

function RichFormatter.cells(line)
    line = tostring(line or ""):gsub("^%s*|", ""):gsub("|%s*$", "")
    local cells = {}
    for cell in (line .. "|"):gmatch("(.-)|") do
        cells[#cells + 1] = RichFormatter.trim(cell)
    end
    return cells
end

function RichFormatter.isTableSeparator(line)
    if not line or not line:find("|", 1, true) then return false end
    local remaining = line:gsub("[%s|:%-]", "")
    return remaining == "" and line:find("%-") ~= nil
end

function RichFormatter.addLabel(parent, text, order, opts)
    opts = opts or {}
    return create("TextLabel", {
        Name = opts.name or "FormattedText",
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = RichFormatter.inline(text), RichText = true,
        TextColor3 = opts.color or Theme.PrimaryText,
        Font = opts.font or Theme.Font,
        TextSize = opts.size or 14,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = order, ZIndex = opts.zIndex or 4,
    }, parent)
end

function RichFormatter.renderTable(parent, rows, order)
    if #rows == 0 then return end
    local columns = #rows[1]
    if columns == 0 then return end
    local frame = create("Frame", {
        Name = "MarkdownTable", Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = order, ZIndex = 4,
    }, parent)
    corner(frame, 8)
    stroke(frame, Theme.Border, 1, 0.25)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1),
    }, frame)

    for rowIndex, rowData in ipairs(rows) do
        local row = create("Frame", {
            Name = rowIndex == 1 and "TableHeader" or "TableRow",
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = rowIndex == 1 and Theme.PanelRaised or Theme.Background,
            BackgroundTransparency = rowIndex == 1 and 0 or 0.12,
            BorderSizePixel = 0, LayoutOrder = rowIndex, ZIndex = 5,
        }, frame)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1),
        }, row)
        for columnIndex = 1, columns do
            local value = rowData[columnIndex] or ""
            local cell = create("TextLabel", {
                Name = "Cell" .. columnIndex,
                Size = UDim2.new(1 / columns, -1, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = RichFormatter.inline(value), RichText = true,
                TextColor3 = rowIndex == 1 and Theme.PrimaryText or Theme.MutedText,
                Font = rowIndex == 1 and Theme.FontBold or Theme.Font,
                TextSize = 12, TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                LayoutOrder = columnIndex, ZIndex = 6,
            }, row)
            padding(cell, 9, 9, 7, 7)
        end
    end
end

function RichFormatter.render(parent, text, order)
    local lines = string.split((tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")), "\n")
    local index, currentOrder = 1, order or 1

    while index <= #lines do
        local line = lines[index]
        local trimmed = RichFormatter.trim(line)
        if trimmed == "" then
            index = index + 1
        elseif index < #lines and line:find("|", 1, true) and RichFormatter.isTableSeparator(lines[index + 1]) then
            local rows = { RichFormatter.cells(line) }
            index = index + 2 -- skip header and Markdown separator
            while index <= #lines do
                local tableLine = lines[index]
                if RichFormatter.trim(tableLine) == "" or not tableLine:find("|", 1, true) then break end
                rows[#rows + 1] = RichFormatter.cells(tableLine)
                index = index + 1
            end
            RichFormatter.renderTable(parent, rows, currentOrder)
            currentOrder = currentOrder + 1
        else
            local hashes, heading = line:match("^%s*(#+)%s+(.+)$")
            local bullet = line:match("^%s*[-%*+]%s+(.+)$")
            local number, numbered = line:match("^%s*(%d+)[%.%)]%s+(.+)$")
            local quote = line:match("^%s*>%s?(.*)$")
            local rule = trimmed:match("^[-*_][-*_][-*_]+$") ~= nil

            if rule then
                create("Frame", {
                    Name = "MarkdownDivider", Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
                    LayoutOrder = currentOrder, ZIndex = 4,
                }, parent)
                currentOrder = currentOrder + 1
                index = index + 1
            elseif heading then
                RichFormatter.addLabel(parent, heading, currentOrder, {
                    name = "MarkdownHeading", size = #hashes <= 2 and 15 or 13,
                    color = Theme.PrimaryText, font = Theme.FontBold,
                })
                currentOrder = currentOrder + 1
                index = index + 1
            elseif bullet or numbered then
                local itemText = bullet or numbered
                local row = create("Frame", {
                    Name = "MarkdownListItem", Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                    LayoutOrder = currentOrder, ZIndex = 4,
                }, parent)
                create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5),
                }, row)
                create("TextLabel", {
                    Name = "ListMarker", Size = UDim2.fromOffset(17, 18),
                    BackgroundTransparency = 1, Text = numbered and (number .. ".") or "•",
                    TextColor3 = Theme.Accent, Font = Theme.FontBold, TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = 1, ZIndex = 5,
                }, row)
                local item = RichFormatter.addLabel(row, itemText, 2, { name = "ListText" })
                item.Size = UDim2.new(1, -23, 0, 0)
                currentOrder = currentOrder + 1
                index = index + 1
            elseif quote ~= nil then
                RichFormatter.addLabel(parent, "┃  " .. quote, currentOrder, {
                    name = "MarkdownQuote", color = Theme.MutedText,
                })
                currentOrder = currentOrder + 1
                index = index + 1
            else
                local paragraph = { line }
                index = index + 1
                while index <= #lines do
                    local nextLine = lines[index]
                    local nextTrimmed = RichFormatter.trim(nextLine)
                    local nextHeading = nextLine:match("^%s*#+%s+.+$") ~= nil
                    local nextBullet = nextLine:match("^%s*[-%*+]%s+.+$") ~= nil
                    local nextNumber = nextLine:match("^%s*%d+[%.%)]%s+.+$") ~= nil
                    local nextQuote = nextLine:match("^%s*>") ~= nil
                    local nextRule = nextTrimmed:match("^[-*_][-*_][-*_]+$") ~= nil
                    local nextTable = index < #lines and nextLine:find("|", 1, true)
                        and RichFormatter.isTableSeparator(lines[index + 1])
                    if nextTrimmed == "" or nextHeading or nextBullet or nextNumber or nextQuote or nextRule or nextTable then break end
                    paragraph[#paragraph + 1] = nextLine
                    index = index + 1
                end
                RichFormatter.addLabel(parent, table.concat(paragraph, "\n"), currentOrder)
                currentOrder = currentOrder + 1
            end
        end
    end
    return currentOrder
end

local function renderMarkdown(text, parent, order)
    local normalized = (tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n"))
    local parts = string.split(normalized, "```")
    local currentOrder = order or 1
    for i, part in ipairs(parts) do
        if i % 2 == 1 then
            if part:match("%S") then
                currentOrder = RichFormatter.render(parent, part, currentOrder)
            end
        else
            local lines = string.split(part, "\n")
            local firstLine = (lines[1] or ""):gsub("%s+$", "")
            local language, tag = "", nil
            if #firstLine < 40 then language, tag = parseCodeHeader(firstLine) end
            if language ~= "" or tag ~= nil then table.remove(lines, 1) end
            local code = table.concat(lines, "\n")
            if code:match("%S") or tag then
                renderCodeBlock(parent, code, language, tag, currentOrder)
                currentOrder = currentOrder + 1
            end
        end
    end
    return currentOrder
end


