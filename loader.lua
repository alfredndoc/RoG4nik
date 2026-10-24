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

local function fetchText(path)
    local url = RAW_BASE .. "/" .. path
    local ok, result = pcall(game.HttpGet, game, url)
    if not ok or type(result) ~= "string" or result == "" or result:find("404: Not Found") then
        error("Failed to fetch: " .. url, 0)
    end
    local required = REQUIRED_SIGNATURES[path]
    if required then
        for _, signature in ipairs(required) do
            if not result:find(signature, 1, true) then
                error("Outdated or mismatched remote source: " .. url .. " is missing required startup code. Update the GitHub main/src files or run the standalone full build.", 0)
            end
        end
    end
    local forbidden = FORBIDDEN_SIGNATURES[path]
    if forbidden then
        for _, signature in ipairs(forbidden) do
            if result:find(signature, 1, true) then
                error("Outdated or malformed remote source: " .. url .. " contains stale startup code. Update the GitHub main/src files or run the standalone full build.", 0)
            end
        end
    end
    return result
end

print("Fetching modules...")
local assembled = fetchText(CORE_PATH)

for _, moduleName in ipairs(MODULES) do
    local moduleSource = fetchText(MODULE_DIRECTORY .. moduleName)
    local marker = "--[[GITHUB_MODULE:" .. moduleName .. "]]"
    
    local startIdx, endIdx = string.find(assembled, marker, 1, true)
    if not startIdx then
        error("Missing marker: " .. marker, 0)
    end
    if string.find(assembled, marker, endIdx + 1, true) then
        error("Duplicate marker: " .. marker, 0)
    end

    assembled = assembled:sub(1, startIdx - 1) .. moduleSource .. assembled:sub(endIdx + 1)
end

if assembled:find("GITHUB_MODULE:", 1, true) then
    error("Assembly failed: unresolved module marker remains.", 0)
end

print("Executing...")
local fn, err = loadstring(assembled, "Dr4gonikHub")
if not fn then
    error("Compile error: " .. tostring(err), 0)
end

fn()
