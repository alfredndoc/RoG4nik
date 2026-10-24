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
local Sandbox = { Enabled = false, History = {}, MaxHistory = 40, _running = false }
_G.Sandbox = Sandbox

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
    env.runHubScript = _G.runHubScript
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
                        local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
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
            local encodeOk, encoded = pcall(function() return HttpService:JSONEncode(all) end)
            if encodeOk then saved = pcall(writeFn, notesPath, encoded) end
        end
        return true, saved and "Note saved to disk." or "Note saved in this session; file writing is unavailable or failed."
    end
    return env
end

local function runInSandbox(code)
    if Sandbox._running then return { ok = false, error = "Another sandbox execution is running.", output = "" } end
    Sandbox._running = true
    local captured = {}
    local loader = loadstring
    if type(loader) ~= "function" and type(getgenv) == "function" then
        local envOk, executorEnv = pcall(getgenv)
        if envOk and type(executorEnv) == "table" then loader = executorEnv.loadstring end
    end
    if type(loader) ~= "function" then
        Sandbox._running = false
        return { ok = false, error = "loadstring is not available in this runtime.", output = "" }
    end
    local loadOk, fn, compileErr = pcall(loader, code, "=sandbox")
    if not loadOk then
        Sandbox._running = false
        return { ok = false, error = "compile: " .. tostring(fn), output = "" }
    end
    if type(fn) ~= "function" then
        Sandbox._running = false
        return { ok = false, error = "compile: " .. tostring(compileErr or "loader returned no function"), output = "" }
    end
    local envOk, env = pcall(buildSandboxEnv, captured)
    if not envOk then
        Sandbox._running = false
        return { ok = false, error = "sandbox setup: " .. tostring(env), output = "" }
    end
    if type(setfenv) == "function" then pcall(setfenv, fn, env) end
    local ok, result = pcall(fn)
    Sandbox._running = false
    local entry = {
        code = code, ok = ok,
        output = table.concat(captured, "\n"),
        result = ok and safeSerialize(result) or nil,
        error = (not ok) and tostring(result) or nil,
        ts = os.clock(),
    }
    Sandbox.History[#Sandbox.History + 1] = entry
    if #Sandbox.History > Sandbox.MaxHistory then table.remove(Sandbox.History, 1) end
    debugTrace(ok and "INFO" or "WARN", ("sandbox %s · %d bytes · %d output lines%s")
        :format(ok and "OK" or "FAIL", #code, #captured, ok and "" or (" · " .. (entry.error or "?"))))
    return entry
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
