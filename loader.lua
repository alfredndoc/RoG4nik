local RAW_BASE = "https://raw.githubusercontent.com/alfredndoc/RoG4nik/main/src"
local CORE_PATH = "Core.lua" 
local MODULE_DIRECTORY = "modules/"

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
    
    assembled = assembled:sub(1, startIdx - 1) .. moduleSource .. assembled:sub(endIdx + 1)
end

print("Executing...")
local fn, err = loadstring(assembled, "Dr4gonikHub")
if not fn then
    error("Compile error: " .. tostring(err), 0)
end

fn()
