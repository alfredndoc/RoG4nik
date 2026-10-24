**Dr4gonik Hub** is an advanced, AI-powered software overlay and script executor designed specifically for Roblox. It operates as a fully functional, draggable desktop-style window inside the game, acting as a personal AI coding assistant and a powerful Lua execution environment. 

Instead of relying on external software to write and test scripts, this tool brings the entire workflow into one unified interface.

### What it does:
*   **AI-Powered Scripting:** It integrates with major AI APIs (DeepSeek, OpenAI, Gemini, Groq, etc.). You can chat with the AI to generate code, fix errors, or explain how the game works.
*   **Automated Tool-Loop (Auto-Execution):** The AI doesn't just show you code; it can run it. By using special tags (like `[EXECUTE]`), the AI writes a script, the hub runs it in the game, captures the output/errors, and feeds the results back to the AI so it can adjust its approach in real-time.
*   **Sandbox Environment:** It includes a built-in code editor equipped with a safe execution sandbox. It captures `print()` and `warn()` outputs so you can debug scripts visually without needing to check the developer console.
*   **Rich Chat Interface:** The UI renders AI responses using Markdown. It supports syntax highlighting, and automatically generates code blocks with interactive **"Copy"** and **"Run"** buttons.
*   **Session & Script Persistence:** It uses the executor's file system to save your API keys, custom themes, chat histories, and written scripts, ensuring you don't lose your work when you leave the game.
*   **Dynamic Theme Engine:** A highly optimized UI engine that smoothly animates color transitions across every element of the interface (Dark, Light, Blue, and Midnight modes) without lag.

### How the GitHub version works:
Because the original application is a massive 4,000+ line monolith that is difficult to maintain, it has been split into this modular GitHub package. 
*   The `loader.lua` script acts as a downloader. 
*   When executed, it fetches the main `Core.lua` file and eight separate module files (Themes, Sandbox, AI logic, etc.) from GitHub.
*   It stitches the separate files back together in memory using marker tags, and compiles them into a single, unified script before launching the UI. This allows developers to edit specific features (like adding a new AI provider or fixing a UI bug) in small, 50-line files without having to scroll through 4,000 lines of code.

### Requirements:
*   A Roblox executor with `loadstring`, `game:HttpGet`, and file I/O capabilities (e.g., `writefile`, `readfile`).
*   An API key from an AI provider (like DeepSeek or OpenAI).
