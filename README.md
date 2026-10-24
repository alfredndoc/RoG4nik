# Dr4gonik Hub — GitHub module split

This package splits the supplied `Dr4gonik Hub — Premium Desktop UI v3` source into eight ordered source fragments. The refactor keeps the shared lexical scope by placing each module's source at its marker in `src/Core.lua` before compiling the combined chunk.

## Files

- `loader.lua` — downloads `src/Core.lua` and all eight fragments from GitHub, resolves the source markers, compiles the combined script, and runs it.
- `src/Core.lua` — main UI / application code with eight module markers.
- `src/modules/Themes.lua` — pure preset and theme-display data (`Dark`, `White`, `Blue`, `MidnightBlue`).
- `src/modules/ThemeEngine.lua` — mutable theme state, `Theme`, `RuntimeDiagnostics`, `ThemeDebug`, `pathOf`, `debugTrace`, theme resolution/transition code, and shared UI helpers (`create`, `tween`, `corner`, `stroke`, `padding`, `bindSoftButton`, `styleScrollBar`, and `createHubGlyph`). It also exposes `ThemeEngine.applyThemePreset(name)` for a silent boot-time palette swap.
- `src/modules/SystemPrompt.lua` — system prompt and prompt builder.
- `src/modules/Sandbox.lua` — sandbox execution and script/workspace helpers.
- `src/modules/SettingsView.lua` — settings interface and controls.
- `src/modules/Markdown.lua` — Markdown rendering helpers.
- `src/modules/Messages.lua` — message rendering and conversation helpers.
- `src/modules/AIRequest.lua` — AI request and tool-loop logic.

## Setup

1. Create a GitHub repository.
2. Upload `loader.lua` and the entire `src/` folder, retaining the folder structure shown above.
3. Open `loader.lua` and replace `YOUR_GITHUB_USERNAME/YOUR_REPOSITORY` in `RAW_BASE` with your GitHub username and repository name. Keep the branch name (`main`) consistent with your repo.
4. Run the edited loader in the same executor/runtime used by the original script.

The loader downloads the source at launch. Push edits to GitHub and the next launch fetches the current version.

## Important design note

These files are **ordered source fragments**, not independent Roblox `ModuleScript`s. The app relies on shared Lua `local` variables and functions, so the loader injects each fragment at its corresponding marker and compiles the assembled source as one chunk. Do not call these files individually with `require()`; start with `loader.lua`.

`ThemeEngine.lua` is inserted immediately after `Themes.lua`, before `loadSettings()` runs. `saveSettings` is forward-declared before the theme engine so `setTheme` can call it after startup. During startup, `loadSettings()` writes the saved name to `ThemeEngine.CurrentThemeName` and calls `ThemeEngine.applyThemePreset()` to update the mutable palette without running an animation or writing settings again.

## Runtime requirements

The original script uses the same runtime capabilities as before, including `game:HttpGet`, `loadstring`, and (where supported) executor HTTP/file APIs. This split does not add compatibility for runtimes that lack those capabilities.

## Validation notes

The package was statically checked for all eight unique markers, successful source-fragment assembly without unresolved markers, and correct theme-state/helper ownership. The assembled Luau code has **not** been executed inside Roblox or a Roblox executor from this environment.
