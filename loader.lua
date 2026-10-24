-- Dr4gonik Hub GitHub loader
-- Upload this file's matching src/ folder to the configured GitHub repository.
-- Run this loader in the same supported Roblox executor/runtime as the original script.

local RAW_BASE = "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY/main"
local CORE_PATH = "src/Core.lua"
local MODULE_DIRECTORY = "src/modules/"
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
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        error(("[Dr4gonik Hub] Failed to fetch %s: %s"):format(url, tostring(result)), 0)
    end
    if type(result) ~= "string" or result == "" then
        error(("[Dr4gonik Hub] Empty response from %s"):format(url), 0)
    end
    return result
end

local assembled = fetchText(CORE_PATH)
for _, moduleName in ipairs(MODULES) do
    local marker = "--[[GITHUB_MODULE:" .. moduleName .. "]]\n"
    local first, last = string.find(assembled, marker, 1, true)
    if not first then
        error("[Dr4gonik Hub] Module marker is missing from Core.lua: " .. moduleName, 0)
    end

    local moduleSource = fetchText(MODULE_DIRECTORY .. moduleName)
    assembled = string.sub(assembled, 1, first - 1)
        .. moduleSource
        .. string.sub(assembled, last + 1)
end

local leftoverStart = string.find(assembled, "--[[GITHUB_MODULE:", 1, true)
if leftoverStart then
    error("[Dr4gonik Hub] An unresolved GitHub module marker remains in Core.lua.", 0)
end

local compiler = loadstring
if type(compiler) ~= "function" then
    error("[Dr4gonik Hub] loadstring is unavailable in this runtime.", 0)
end

local chunk, compileError = compiler(assembled, "@Dr4gonikHub/Core.lua")
if type(chunk) ~= "function" then
    error("[Dr4gonik Hub] Combined script failed to compile: " .. tostring(compileError), 0)
end

return chunk()
