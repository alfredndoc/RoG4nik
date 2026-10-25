--============================================================
--// SCRIPT LIBRARY (executor file APIs with session fallback)
--============================================================
do
local HubScriptLibrary = { Items = {}, Folder = "Dr4gonikHub/Scripts" }
_G.HubScriptLibrary = HubScriptLibrary
local function safeScriptName(name)
    name = tostring(name or "Untitled"):gsub("[^%w%-%_ ]", ""):gsub("%s+", "_")
    if name == "" then name = "Untitled" end
    return name:sub(1, 64)
end
local function scriptPath(name) return HubScriptLibrary.Folder .. "/" .. safeScriptName(name) .. ".lua" end
local function ensureScriptFolder()
    if type(makefolder) ~= "function" then return false end
    pcall(makefolder, "Dr4gonikHub")
    pcall(makefolder, HubScriptLibrary.Folder)
    return true
end
function _G.listHubScripts()
    local out, seen = {}, {}
    for name, item in pairs(HubScriptLibrary.Items) do out[#out+1] = {name=name, description=item.description or "Saved Lua script", source=item.source or ""}; seen[name]=true end
    if type(listfiles) == "function" then
        ensureScriptFolder()
        local ok, files = pcall(listfiles, HubScriptLibrary.Folder)
        if ok and type(files)=="table" then
            for _, path in ipairs(files) do
                local name = tostring(path):match("([^/\\]+)%.lua$")
                if name and not seen[name] then
                    local source = ""
                    if type(readfile)=="function" then local rok, data=pcall(readfile,path); if rok and type(data)=="string" then source=data end end
                    out[#out+1]={name=name,description="Saved Lua script",source=source}; seen[name]=true
                end
            end
        end
    end
    table.sort(out,function(a,b) return a.name:lower()<b.name:lower() end)
    return out
end
function _G.readHubScript(name)
    name=safeScriptName(name)
    local item=HubScriptLibrary.Items[name]
    if item then return item.source end
    if type(readfile)=="function" and type(isfile)=="function" then
        local path=scriptPath(name); local ok, exists=pcall(isfile,path)
        if ok and exists then local rok, data=pcall(readfile,path); if rok then return data end end
    end
    return nil, "Script not found: "..name
end
function _G.saveHubScript(name, source, description)
    name=safeScriptName(name); source=tostring(source or "")
    if source=="" then return false,"Script source is empty." end
    HubScriptLibrary.Items[name]={source=source,description=tostring(description or "Saved Lua script"),updated=os.time()}
    local persisted=false
    if type(writefile)=="function" then
        ensureScriptFolder(); local ok, err=pcall(writefile,scriptPath(name),source)
        if ok then persisted=true else return true,"Saved for this session; disk write failed: "..tostring(err) end
    end
    return true, persisted and ("Saved to "..scriptPath(name)) or "Saved for this session (executor writefile unavailable)."
end
function _G.editHubScript(name, source, description)
    local existing= _G.readHubScript(name)
    if not existing then return false,"Script not found. Save it first." end
    return _G.saveHubScript(name,source,description or "Edited Lua script")
end
function _G.editHubScriptLine(name, lineNumber, newText)
    local source, err = _G.readHubScript(name); if not source then return false,err end
    lineNumber=tonumber(lineNumber); if not lineNumber or lineNumber<1 or lineNumber%1~=0 then return false,"Line number must be a positive integer." end
    local lines={}; for line in (source.."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
    if lineNumber>#lines then return false,"Line "..lineNumber.." is outside the script ("..#lines.." lines)." end
    lines[lineNumber]=tostring(newText or "")
    return _G.saveHubScript(name,table.concat(lines,"\n"),"Edited line "..lineNumber)
end
function _G.runHubScript(name)
    local source,err=_G.readHubScript(name); if not source then return {ok=false,error=err,output=""} end
    if type(_G.runInSandbox) ~= "function" then return {ok=false,error="Sandbox is not initialized yet.",output=""} end
    return _G.runInSandbox(source)
end
end -- script-library helper scope

--============================================================
--// SANDBOX
--============================================================
local Sandbox = {
    Enabled = false,
    History = {},
    MaxHistory = 40,
    _running = false,
    _runningThread = nil,
    _runningDepth = 0,
    MaxNestedDepth = 6,
}
_G.Sandbox = Sandbox

-- Stable fallback for runtimes where coroutine.running() returns nil.
local SANDBOX_MAIN_THREAD = {}

local function currentSandboxThread()
    if type(coroutine) == "table" and type(coroutine.running) == "function" then
        local ok, thread = pcall(coroutine.running)
        if ok and thread ~= nil then return thread end
    end
    return SANDBOX_MAIN_THREAD
end

local function safeSerialize(value, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    local t = typeof(value)
    if t == "nil" or t == "boolean" or t == "number" or t == "string" then
        return tostring(value)
    elseif t == "Instance" then
        return value:GetFullName()
    elseif t == "Vector3" or t == "CFrame" or t == "Color3" or t == "UDim2"
        or t == "Vector2" or t == "UDim" or t == "EnumItem" then
        return tostring(value)
    elseif t == "table" then
        local parts, count = {}, 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 25 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. " = " .. safeSerialize(v, depth + 1)
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return "<" .. t .. ">"
end

local function buildSandboxEnv(captured)
    local baseEnv
    if getgenv then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then baseEnv = env end
    end
    if not baseEnv and getfenv then
        local ok, env = pcall(getfenv, 0)
        if ok and type(env) == "table" then baseEnv = env end
    end
    baseEnv = baseEnv or _G
    local env = setmetatable({}, { __index = baseEnv })
    local function capture(prefix)
        return function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = safeSerialize((select(i, ...))) end
            captured[#captured + 1] = prefix .. table.concat(parts, " ")
            return nil
        end
    end
    if AI.CaptureOutput ~= false then
        env.print = capture("")
        env.warn = capture("[warn] ")
    else
        env.print = type(baseEnv.print) == "function" and baseEnv.print or print
        env.warn = type(baseEnv.warn) == "function" and baseEnv.warn or warn
    end
    env.error = function(msg, level) error(msg, (level or 1) + 1) end
    env.serialize = safeSerialize
    -- Expose the script-library API explicitly: executor global environments do
    -- not always share the same table as _G.
    env.listHubScripts = _G.listHubScripts
    env.readHubScript = _G.readHubScript
    env.saveHubScript = _G.saveHubScript
    env.editHubScript = _G.editHubScript
    env.editHubScriptLine = _G.editHubScriptLine
    -- Run a saved script as a nested sandbox operation. Include its real status,
    -- captured output, and error in the parent tool output so the AI cannot mistake
    -- pcall success (the helper call itself) for successful script execution.
    env.runHubScript = function(name)
        local scriptRunner = _G.runHubScript
        if type(scriptRunner) ~= "function" then
            local failure = { ok = false, error = "runHubScript is unavailable.", output = "" }
            captured[#captured + 1] = "[runHubScript] FAILED: " .. failure.error
            return failure
        end

        local callOk, result = pcall(scriptRunner, name)
        if not callOk then
            local failure = { ok = false, error = tostring(result), output = "" }
            captured[#captured + 1] = ("[runHubScript %s] FAILED: %s"):format(tostring(name), failure.error)
            return failure
        end

        if type(result) ~= "table" then
            captured[#captured + 1] = ("[runHubScript %s] returned an unexpected %s value"):format(tostring(name), typeof(result))
            return { ok = false, error = "runHubScript returned an invalid result.", output = "" }
        end

        captured[#captured + 1] = ("[runHubScript %s] %s"):format(
            tostring(name), result.ok and "EXECUTED" or "FAILED"
        )
        if type(result.output) == "string" and result.output ~= "" then
            captured[#captured + 1] = "[runHubScript output] " .. result.output
        end
        if result.result ~= nil then
            captured[#captured + 1] = "[runHubScript result] " .. tostring(result.result)
        end
        if result.error ~= nil and tostring(result.error) ~= "" then
            captured[#captured + 1] = "[runHubScript error] " .. tostring(result.error)
        end
        return result
    end
    env.inspect = function(obj, depth)
        if typeof(obj) ~= "Instance" then
            captured[#captured + 1] = safeSerialize(obj)
            return obj
        end
        local function walk(node, d)
            if d > (depth or 3) then return end
            captured[#captured + 1] = string.rep("  ", d) .. node.ClassName .. " \"" .. node.Name .. "\""
            for _, c in ipairs(node:GetChildren()) do walk(c, d + 1) end
        end
        walk(obj, 0)
        return obj
    end
    env.getprops = function(inst, props)
        if typeof(inst) ~= "Instance" then
            return { error = "getprops expects a Roblox Instance" }
        end
        local defaults = { "Name", "ClassName", "Size", "Position", "Color", "Material" }
        local requested = type(props) == "table" and props or defaults
        local out, count = {}, 0
        for _, propName in ipairs(requested) do
            if count >= 20 then out.__truncated = true; break end
            if type(propName) == "string" and propName:match("^[%a_][%w_]*$") then
                count = count + 1
                local ok, value = pcall(function() return inst[propName] end)
                if ok then out[propName] = safeSerialize(value) else out[propName] = "<unavailable>" end
            end
        end
        return out
    end
    -- DuckDuckGo's Instant Answer endpoint returns summaries and related-topic
    -- data, not a general web-results page. Keep requests read-only and bound the
    -- amount of remote text returned to the model.
    env.duckduckgoInstantAnswer = function(query)
        query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then return { ok = false, error = "A search query is required." } end
        query = query:sub(1, 300)
        if type(AI.HttpRequest) ~= "function" then
            return { ok = false, error = "HTTP requests are unavailable in this runtime." }
        end

        local encodeOk, encodedQuery = pcall(function()
            return UIRefs.HttpService:UrlEncode(query)
        end)
        if not encodeOk or type(encodedQuery) ~= "string" then
            encodedQuery = query:gsub("([^%w%-_%.~])", function(char)
                return string.format("%%%02X", string.byte(char))
            end)
        end

        local url = "https://api.duckduckgo.com/?q=" .. encodedQuery
            .. "&format=json&no_html=1&no_redirect=1&t=dr4gonik_hub"
        local body, status = AI.HttpRequest({
            Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" }, Timeout = 15,
        })
        local numericStatus = tonumber(status)
        if type(body) ~= "string" then
            return { ok = false, error = tostring(status or "DuckDuckGo request failed.") }
        end
        if numericStatus and (numericStatus < 200 or numericStatus >= 300) then
            return { ok = false, error = "DuckDuckGo returned HTTP " .. tostring(numericStatus) }
        end
        local decodeOk, data = pcall(function() return UIRefs.HttpService:JSONDecode(body) end)
        if not decodeOk or type(data) ~= "table" then
            return { ok = false, error = "DuckDuckGo returned invalid JSON." }
        end

        local result = {
            ok = true,
            query = query,
            heading = tostring(data.Heading or ""):sub(1, 200),
            answer = tostring(data.Answer or ""):sub(1, 700),
            answerType = tostring(data.AnswerType or ""),
            abstract = tostring(data.AbstractText or ""):sub(1, 1200),
            abstractSource = tostring(data.AbstractSource or ""):sub(1, 120),
            abstractURL = tostring(data.AbstractURL or ""):sub(1, 400),
            definition = tostring(data.Definition or ""):sub(1, 700),
            definitionSource = tostring(data.DefinitionSource or ""):sub(1, 120),
            definitionURL = tostring(data.DefinitionURL or ""):sub(1, 400),
            attribution = "Results from DuckDuckGo",
            searchURL = "https://duckduckgo.com/?q=" .. encodedQuery,
            relatedTopics = {},
            results = {},
        }
        local function addTopic(item)
            if #result.relatedTopics >= 8 or type(item) ~= "table" then return end
            if type(item.Topics) == "table" then
                for _, nested in ipairs(item.Topics) do addTopic(nested) end
                return
            end
            local text = tostring(item.Text or "")
            local link = tostring(item.FirstURL or "")
            if text ~= "" then
                result.relatedTopics[#result.relatedTopics + 1] = {
                    text = text:sub(1, 300), url = link:sub(1, 400),
                }
            end
        end
        if type(data.RelatedTopics) == "table" then
            for _, item in ipairs(data.RelatedTopics) do addTopic(item) end
        end
        if type(data.Results) == "table" then
            for _, item in ipairs(data.Results) do
                if #result.results >= 5 then break end
                if type(item) == "table" then
                    local text = tostring(item.Text or "")
                    local link = tostring(item.FirstURL or "")
                    if text ~= "" then
                        result.results[#result.results + 1] = {
                            text = text:sub(1, 300), url = link:sub(1, 400),
                        }
                    end
                end
            end
        end
        if result.answer == "" and result.abstract == "" and result.definition == ""
            and #result.relatedTopics == 0 and #result.results == 0 then
            result.noInstantAnswer = true
            result.note = "No instant answer was available. This endpoint is not full web search; try a topic/entity query or open the DuckDuckGo search URL."
        end
        return result
    end
    env.remember = function(key, value)
        key = tostring(key or ""):sub(1, 100)
        if key == "" then return nil, "A note key is required." end
        local placeKey = "unknown"
        pcall(function() placeKey = tostring(game.PlaceId) end)
        local cache = _G.Dr4gonikHubNotes
        if type(cache) ~= "table" then cache = {}; _G.Dr4gonikHubNotes = cache end
        local notesPath = "Dr4gonikHub/notes.json"
        local function loadNotes()
            if type(cache[placeKey]) == "table" then return cache[placeKey] end
            local all = {}
            local readFn = type(readfile) == "function" and readfile or baseEnv.readfile
            local isFileFn = type(isfile) == "function" and isfile or baseEnv.isfile
            if type(readFn) == "function" and type(isFileFn) == "function" then
                local existsOk, exists = pcall(isFileFn, notesPath)
                if existsOk and exists then
                    local readOk, raw = pcall(readFn, notesPath)
                    if readOk and type(raw) == "string" and raw ~= "" then
                        local decodeOk, decoded = pcall(function() return UIRefs.HttpService:JSONDecode(raw) end)
                        if decodeOk and type(decoded) == "table" then all = decoded end
                    end
                end
            end
            if type(all[placeKey]) ~= "table" then all[placeKey] = {} end
            cache.__all = all
            cache[placeKey] = all[placeKey]
            return cache[placeKey]
        end
        local notes = loadNotes()
        if value == nil then return notes[key] end
        notes[key] = tostring(value):sub(1, 2000)
        local all = cache.__all or { [placeKey] = notes }
        all[placeKey] = notes
        cache.__all = all
        local saved = false
        local writeFn = type(writefile) == "function" and writefile or baseEnv.writefile
        local makeFolderFn = type(makefolder) == "function" and makefolder or baseEnv.makefolder
        if type(writeFn) == "function" then
            pcall(function() if type(makeFolderFn) == "function" then makeFolderFn("Dr4gonikHub") end end)
            local encodeOk, encoded = pcall(function() return UIRefs.HttpService:JSONEncode(all) end)
            if encodeOk then saved = pcall(writeFn, notesPath, encoded) end
        end
        return true, saved and "Note saved to disk." or "Note saved in this session; file writing is unavailable or failed."
    end
    return env
end

local function runInSandbox(code)
    -- A tagged [EXECUTE] block may call runHubScript(), which itself invokes
    -- runInSandbox(). Permit that *synchronous nested call on the same coroutine*,
    -- while still refusing independent/concurrent executions and runaway recursion.
    local thread = currentSandboxThread()
    local wasRunning = Sandbox._running == true

    if wasRunning and Sandbox._runningThread ~= thread then
        return { ok = false, error = "Another sandbox execution is running in a different task.", output = "" }
    end

    local depthBefore = tonumber(Sandbox._runningDepth)
    if depthBefore == nil then depthBefore = wasRunning and 1 or 0 end
    if wasRunning and depthBefore >= (tonumber(Sandbox.MaxNestedDepth) or 6) then
        return { ok = false, error = "Maximum nested sandbox depth reached.", output = "" }
    end

    if not wasRunning then
        Sandbox._running = true
        Sandbox._runningThread = thread
        depthBefore = 0
    end
    Sandbox._runningDepth = depthBefore + 1

    local function releaseExecutionSlot()
        local depth = math.max(0, (tonumber(Sandbox._runningDepth) or 1) - 1)
        Sandbox._runningDepth = depth
        if depth == 0 then
            Sandbox._running = false
            Sandbox._runningThread = nil
        end
    end

    -- Keep releaseExecutionSlot outside this protected body so every return and
    -- unexpected internal error releases the lock correctly.
    local bodyOk, bodyResult = pcall(function()
        if type(code) ~= "string" then
            return { ok = false, error = "Sandbox code must be a string.", output = "" }
        end

        local captured = {}
        local loader = type(loadstring) == "function" and loadstring or nil
        if not loader and type(getgenv) == "function" then
            local envOk, executorEnv = pcall(getgenv)
            if envOk and type(executorEnv) == "table" and type(executorEnv.loadstring) == "function" then
                loader = executorEnv.loadstring
            end
        end
        if type(loader) ~= "function" then
            return { ok = false, error = "loadstring is not available in this runtime.", output = "" }
        end

        local loadOk, fn, compileErr = pcall(loader, code, "=sandbox")
        if not loadOk then
            return { ok = false, error = "compile: " .. tostring(fn), output = "" }
        end
        if type(fn) ~= "function" then
            return { ok = false, error = "compile: " .. tostring(compileErr or "loader returned no function"), output = "" }
        end

        local envOk, env = pcall(buildSandboxEnv, captured)
        if not envOk then
            return { ok = false, error = "sandbox setup: " .. tostring(env), output = "" }
        end
        if type(setfenv) == "function" then
            local setEnvOk, setEnvError = pcall(setfenv, fn, env)
            if not setEnvOk then
                return { ok = false, error = "sandbox environment setup: " .. tostring(setEnvError), output = "" }
            end
        end

        local executionOk, value = pcall(fn)
        local entry = {
            code = code,
            ok = executionOk,
            output = table.concat(captured, "\n"),
            result = executionOk and safeSerialize(value) or nil,
            error = (not executionOk) and tostring(value) or nil,
            ts = os.clock(),
        }
        Sandbox.History[#Sandbox.History + 1] = entry
        if #Sandbox.History > Sandbox.MaxHistory then table.remove(Sandbox.History, 1) end
        debugTrace(executionOk and "INFO" or "WARN", ("sandbox %s · %d bytes · %d output lines%s")
            :format(executionOk and "OK" or "FAIL", #code, #captured,
                executionOk and "" or (" · " .. (entry.error or "?"))))
        return entry
    end)

    releaseExecutionSlot()
    if not bodyOk then
        return { ok = false, error = "sandbox internal error: " .. tostring(bodyResult), output = "" }
    end
    return bodyResult
end
_G.runInSandbox = runInSandbox

--============================================================
--// WORKSPACE INSPECTOR
--============================================================
local WorkspaceInspector = {}
function WorkspaceInspector.Snapshot(depth)
    depth = depth or 3
    local lines, total = {}, 0
    local LIMIT = 400
    local function walk(node, d)
        if d > depth or total >= LIMIT then return end
        total = total + 1
        lines[#lines + 1] = string.rep("  ", d) .. node.ClassName .. " [" .. node.Name .. "]"
        for _, c in ipairs(node:GetChildren()) do walk(c, d + 1) end
    end
    walk(game.Workspace, 0)
    return table.concat(lines, "\n")
end
function WorkspaceInspector.Summary()
    local out = {}
    for _, c in ipairs(game.Workspace:GetChildren()) do
        out[#out + 1] = ("%s (%s) · %d children"):format(c.ClassName, c.Name, #c:GetChildren())
    end
    return table.concat(out, "\n")
end
_G.WorkspaceInspector = WorkspaceInspector

