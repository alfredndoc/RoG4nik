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


function _G.deleteHubScript(name)
    name = safeScriptName(name)
    HubScriptLibrary.Items[name] = nil
    if type(delfile) == "function" then
        local path = scriptPath(name)
        pcall(delfile, path)
    end
    return true
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
