--============================================================
--// MESSAGE BUBBLES
--============================================================
local function addMessageBubble(text, role, saveToHistory, reasoning, modelName, toolKind, toolSuccess, targetConversationOverride)
    role = role or "user"
    text = tostring(text or "")
    messageOrder = messageOrder + 1
    local targetConversation = targetConversationOverride or currentConversation()
    if targetConversationOverride and targetConversationOverride.id ~= selectedConversationId then
        -- An in-flight reply belongs to the conversation that started it, not whichever chat is open now.
        if saveToHistory ~= false then
            table.insert(targetConversationOverride.history, {
                role = role, text = text, reasoning = reasoning, model = modelName,
                toolKind = toolKind, toolSuccess = toolSuccess,
            })
            pcall(function()
                if AI.SaveHistory and writefile then writefile(CONVOS_FILE, HttpService:JSONEncode(conversations)) end
            end)
        end
        return nil
    end

    if role == "tool" then
        local row = create("Frame", {
            Name = "MessageRow", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = messageOrder, ZIndex = 2,
        }, ChatDisplay)
        local panel = create("Frame", {
            Name = "ToolResultPanel", Size = UDim2.new(0.94, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 3,
        }, row)
        corner(panel, 10)
        stroke(panel, toolSuccess == false and Theme.Danger or Theme.Border, 1, toolSuccess == false and 0.18 or 0.35)
        create("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
        local header = create("TextButton", {
            Name = "ToolResultHeader", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.PanelRaised,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = 1, ZIndex = 4,
        }, panel)
        corner(header, 9)
        local chevron = create("TextLabel", {
            Position = UDim2.new(0, 12, 0, 0), Size = UDim2.fromOffset(16, 34), BackgroundTransparency = 1,
            Text = "›", TextColor3 = Theme.MutedText, Font = Theme.FontBold, TextSize = 20, ZIndex = 5,
        }, header)
        local lineCount = 1
        for _ in text:gmatch("\n") do lineCount = lineCount + 1 end
        local kindLabel = string.upper(tostring(toolKind or "TOOL"))
        local statusLabel = toolSuccess == false and "FAILED" or "COMPLETE"
        create("TextLabel", {
            Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -144, 1, 0),
            BackgroundTransparency = 1, Text = statusLabel .. " · " .. kindLabel,
            TextColor3 = toolSuccess == false and Theme.Danger or Theme.PrimaryText,
            Font = Theme.FontBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
        }, header)
        local detailLabel = create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(94, 34),
            BackgroundTransparency = 1, Text = tostring(lineCount) .. (lineCount == 1 and " line" or " lines") .. " · Show",
            TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5,
        }, header)
        local body = create("Frame", {
            Name = "ToolResultBody", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Visible = false, LayoutOrder = 2, ZIndex = 4,
        }, panel)
        create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)
        padding(body, 12, 12, 10, 10)
        renderMarkdown(text, body, 1)
        header.MouseButton1Click:Connect(function()
            body.Visible = not body.Visible
            chevron.Text = body.Visible and "⌄" or "›"
            detailLabel.Text = tostring(lineCount) .. (lineCount == 1 and " line" or " lines") .. (body.Visible and " · Hide" or " · Show")
            tween(header, { BackgroundColor3 = body.Visible and Theme.Selected or Theme.PanelRaised }, 0.12)
            scrollChatToBottom()
        end)
        if saveToHistory ~= false then
            local conversation = targetConversation or currentConversation()
            if conversation then
                table.insert(conversation.history, {
                    role = "tool", text = text, toolKind = toolKind, toolSuccess = toolSuccess,
                })
                pcall(function()
                    if AI.SaveHistory and writefile then
                        writefile(CONVOS_FILE, HttpService:JSONEncode(conversations))
                    end
                end)
            end
        end
        local scale = create("UIScale", { Scale = 0.97 }, row)
        tween(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back)
        chatHasContent = true
        if EmptyChatLabel then EmptyChatLabel.Visible = false end
        scrollChatToBottom()
        return row
    elseif role == "error" then
        local row = create("Frame", {
            Name = "MessageRow", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = messageOrder, ZIndex = 2,
        }, ChatDisplay)
        local panel = create("Frame", {
            Name = "ErrorPanel", Size = UDim2.new(0.94, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 3,
        }, row)
        corner(panel, 10)
        stroke(panel, Theme.Danger, 1, 0.15)
        create("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.PanelRaised,
            BackgroundTransparency = 0.15, Text = "  ⚠  REQUEST FAILED", TextColor3 = Theme.Danger,
            Font = Theme.FontBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1, ZIndex = 4,
        }, panel)
        local content = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 4,
        }, panel)
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
        padding(content, 12, 12, 5, 10)
        renderMarkdown(text, content, 1)
        local scale = create("UIScale", { Scale = 0.98 }, row)
        tween(scale, { Scale = 1 }, 0.2, Enum.EasingStyle.Quad)
        chatHasContent = true
        if EmptyChatLabel then EmptyChatLabel.Visible = false end
        scrollChatToBottom()
        return row
    end

    local isUser = role == "user"
    local row = create("Frame", {
        Name = "MessageRow", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = messageOrder, ZIndex = 2,
    }, ChatDisplay)

    if isUser then
        local bubble = create("Frame", {
            Name = "Bubble", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.80, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.AccentSoft, BorderSizePixel = 0, ZIndex = 3,
        }, row)
        corner(bubble, 13)
        stroke(bubble, Theme.Accent, 1, 0.58)
        padding(bubble, 14, 14, 11, 11)
        create("TextLabel", {
            Name = "MessageText", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = text, TextColor3 = Theme.PrimaryText, Font = Theme.Font,
            TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4,
        }, bubble)
    else
        local wrapper = create("Frame", {
            Name = "Bubble", Size = UDim2.new(0.96, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, ZIndex = 3,
        }, row)
        create("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }, wrapper)
        local model = modelName or AI.Model or "assistant"
        local headerRow = create("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 4 }, wrapper)
        Theme.createHubGlyph(headerRow, 18, 5, Theme.Accent, false)
        create("TextLabel", {
            Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -24, 0, 20), BackgroundTransparency = 1,
            Text = "Assistant · " .. model, TextColor3 = Theme.MutedText, Font = Theme.FontBold,
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
        }, headerRow)
        if reasoning and reasoning ~= "" then
            createReasoningBlock(wrapper, reasoning, true, 2)
        end
        local msgContainer = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 4,
        }, wrapper)
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, msgContainer)
        renderMarkdown(text, msgContainer, 1)
    end

    if saveToHistory ~= false then
        local conversation = targetConversation or currentConversation()
        if conversation then
            if role == "user" and (not conversation.title or conversation.title == "New conversation") then
                local firstLine = text:match("([^\r\n]+)") or text
                firstLine = firstLine:gsub("^%s+", ""):gsub("%s+$", "")
                if #firstLine > 30 then firstLine = firstLine:sub(1, 29) .. "…" end
                conversation.title = firstLine ~= "" and firstLine or "New conversation"
                if ChatTitle and selectedConversationId == conversation.id then ChatTitle.Text = conversation.title end
                local rowButton = conversationRows[conversation.id]
                local selectButton = rowButton and rowButton:FindFirstChild("SelectConversationButton")
                local titleLabel = selectButton and selectButton:FindFirstChild("ConversationTitle")
                if titleLabel then titleLabel.Text = conversation.title end
            end
            table.insert(conversation.history, { role = role, text = text, reasoning = reasoning, model = modelName })
            pcall(function()
                if AI.SaveHistory and writefile then
                    writefile(CONVOS_FILE, HttpService:JSONEncode(conversations))
                end
            end)
        end
    end
    if saveToHistory ~= false then
        local scale = create("UIScale", { Scale = 0.97 }, row)
        tween(scale, { Scale = 1 }, 0.23, Enum.EasingStyle.Back)
    end
    chatHasContent = true
    if EmptyChatLabel then EmptyChatLabel.Visible = false end
    scrollChatToBottom()
    return row
end

local function addThinkingIndicator()
    messageOrder = messageOrder + 1
    local row = create("Frame", {
        Name = "MessageRow", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = messageOrder, ZIndex = 2,
    }, ChatDisplay)
    local wrapper = create("Frame", { Size = UDim2.new(0.94, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 3 }, row)
    create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, wrapper)
    local headerRow = create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 4 }, wrapper)
    Theme.createHubGlyph(headerRow, 18, 5, Theme.Accent, false)
    create("TextLabel", {
        Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -22, 0, 18), BackgroundTransparency = 1,
        Text = "Assistant · " .. (AI.Model or "…"), TextColor3 = Theme.MutedText, Font = Theme.FontBold,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, headerRow)
    local label = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = "Thinking", TextColor3 = Theme.MutedText, Font = Theme.Font, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 4,
    }, wrapper)
    chatHasContent = true
    if EmptyChatLabel then EmptyChatLabel.Visible = false end
    scrollChatToBottom()
    local dots, running, fixedStatus = 0, true, nil
    task.spawn(function()
        while running do
            if fixedStatus then
                label.Text = fixedStatus
            else
                dots = (dots + 1) % 4
                label.Text = "Thinking" .. string.rep(".", dots)
            end
            task.wait(0.35)
        end
    end)
    return {
        row = row,
        stop = function() running = false end,
        setText = function(value)
            fixedStatus = tostring(value)
            if label and label.Parent then label.Text = fixedStatus end
        end,
    }
end

local setMenuOpen

local function showConversation(id)
    local conversation = getConversation(id)
    if not conversation then return end
    selectedConversationId = id
    if ChatTitle then ChatTitle.Text = conversation.title end
    refreshConversationStyles()
    clearRenderedMessages()
    chatHasContent = #conversation.history > 0
    if EmptyChatLabel then EmptyChatLabel.Visible = not chatHasContent end
    for _, message in ipairs(conversation.history) do
        addMessageBubble(message.text, message.role, false, message.reasoning, message.model, message.toolKind, message.toolSuccess)
    end
end

local function createConversationRow(conversation)
    local id = conversation.id
    if conversationRows[id] then return end
    local row = create("Frame", {
        Name = "ConversationRow_" .. id, Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = Theme.Hover,
        BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 20, ZIndex = 4,
    }, SidebarScroll)
    corner(row, 8)
    row:SetAttribute("Hovered", false)
    local selectButton = create("TextButton", {
        Name = "SelectConversationButton", Size = UDim2.new(1, -34, 1, 0),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5,
    }, row)
    local dot = create("Frame", {
        Position = UDim2.new(0, 11, 0.5, -2), Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Theme.QuietText, BorderSizePixel = 0, ZIndex = 6,
    }, selectButton)
    corner(dot, 4)
    create("TextLabel", {
        Name = "ConversationTitle", Position = UDim2.new(0, 23, 0, 0), Size = UDim2.new(1, -27, 1, 0),
        BackgroundTransparency = 1, Text = conversation.title, TextColor3 = Theme.MutedText,
        Font = Theme.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
    }, selectButton)
    local more = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(25, 25),
        BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "···", TextColor3 = Theme.MutedText, Font = Theme.FontBold, TextSize = 16,
        AutoButtonColor = false, Visible = false, ZIndex = 7,
    }, row)
    corner(more, 7)
    bindSoftButton(more, { BackgroundTransparency = 0.08, TextColor3 = Theme.PrimaryText }, 1.06)
    row.MouseEnter:Connect(function()
        row:SetAttribute("Hovered", true)
        if id ~= selectedConversationId then tween(row, { BackgroundTransparency = 0.38 }, 0.12) end
        more.Visible = true
    end)
    row.MouseLeave:Connect(function()
        row:SetAttribute("Hovered", false)
        if id ~= selectedConversationId then tween(row, { BackgroundTransparency = 1 }, 0.12) end
        more.Visible = id == selectedConversationId
    end)
    selectButton.MouseButton1Click:Connect(function()
        showConversation(id)
        if activeView == "settings" then
            activeView = "chat"
            if SettingsView then SettingsView.Visible = false end
            if ChatDisplay then ChatDisplay.Visible = true end
            if InputBar then InputBar.Visible = true end
        end
    end)
    more.MouseButton1Click:Connect(function()
        if setMenuOpen then setMenuOpen("conversation", id) end
    end)
    conversationRows[id] = row
    conversationButtons[id] = selectButton
    conversationOptions[id] = more
end

local function refreshConversationOrder()
    for index, conversation in ipairs(conversations) do
        createConversationRow(conversation)
        local row = conversationRows[conversation.id]
        if row then
            row.LayoutOrder = 20 + index
            local sb = row:FindFirstChild("SelectConversationButton")
            local lbl = sb and sb:FindFirstChild("ConversationTitle")
            if lbl then lbl.Text = conversation.title end
        end
    end
    refreshConversationStyles()
end

local function loadConversations()
    conversations = {}
    if not AI.SaveHistory or type(readfile) ~= "function" then return end

    local ok, raw = pcall(readfile, CONVOS_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not decodeOk or type(decoded) ~= "table" then
        debugTrace("WARN", "Conversation history is invalid JSON; starting with an empty history.")
        return
    end

    local valid = {}
    for _, item in ipairs(decoded) do
        if type(item) == "table" and type(item.id) == "string" and item.id ~= "" and type(item.history) == "table" then
            local conversation = {
                id = item.id,
                title = type(item.title) == "string" and item.title or "New conversation",
                history = {},
            }
            for _, message in ipairs(item.history) do
                if type(message) == "table"
                    and type(message.text) == "string"
                    and (message.role == "user" or message.role == "assistant") then
                    table.insert(conversation.history, {
                        role = message.role,
                        text = message.text,
                        reasoning = type(message.reasoning) == "string" and message.reasoning or nil,
                        model = type(message.model) == "string" and message.model or nil,
                    })
                end
            end
            table.insert(valid, conversation)
        end
    end
    conversations = valid
end
loadConversations()
refreshConversationOrder()

