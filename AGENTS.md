# AGENTS.md

## Neovim Plugin Development Directives

This repository implements a **high-performance Neovim plugin**.
AI agents contributing code **MUST** follow these strict directives.  
**Non-compliance is a defect.**

---

## External File Loading

**CRITICAL**: When you encounter a file reference (e.g., @path/to/file.md), use your Read tool to load it on a need-to-know basis. They're relevant to the SPECIFIC task at hand.

**Instructions:**

- Do NOT preemptively load all references - use lazy loading based on actual need
- When loaded, treat content as mandatory instructions that override defaults
- Follow references recursively when needed

**For testing strategies and best practices:** Load the `mini-test-workflow` skill

---

## Core Principles

1. **Pure Lua** — No Vimscript. Use `vim.api` and `vim.uv`.
2. **Strict Type Safety** — Use EmmyLua annotations for all functions and classes.
3. **Lazy Initialization** — No logic execution on `require()`. Load logic only on demand.
4. **Process Isolation** — No global mutable state. Use buffer-local or namespaced state.
5. **Non-Blocking I/O** — All operations >10ms must be async or scheduled via `vim.system`.

---

## 1. Type Safety & API Usage

### ✅ Required

- **EmmyLua Annotations:** Every function must have `---@param`, `---@return`. Use `---@class` for config tables.
- **Modern APIs:** Use `vim.uv` (not `vim.loop`), `vim.system()`, and `vim.iter()`.
- **Health Checks:** Feature diagnostics must reside in `lua/plugin/health.lua`.

### ❌ Forbidden

- `vim.fn.system()` (blocking). Always use `vim.system()`.
- `vim.loop` (legacy alias). Always use `vim.uv`.
- Global variables (`_G` or `vim.g`).

---

## 2. Module Structure & Initialization

Modules must be side-effect free. Entry points only register intent, never execution.

```lua
-- lua/plugin/init.lua
local M = {}

---@class PluginConfig
---@field feature_enabled boolean
---@field timeout number

---@param opts? PluginConfig
function M.setup(opts)
    -- Only register lightweight hooks
    vim.api.nvim_create_user_command("MyAction", function()
        -- Core logic is required ONLY when command is run
        require("plugin.actions").execute()
    end, {})
end

return M
```

---

## 3. Testing with mini.test

**When writing tests:** Load the `mini-test-workflow` skill for comprehensive patterns and examples.

**Quick reference:**
- All tests MUST reside in `tests/` directory
- Test files MUST be named `test_*.lua`
- Use `new_child_neovim()` for strict process isolation
- Run tests: `make test` or `make test_file FILE=tests/test_foo.lua`

**For detailed patterns, examples, and troubleshooting:** Load the `mini-test-workflow` skill

---

## 4. State Management

- **Buffer-local:** Use `vim.b[bufnr].plugin_state` for document-specific data.
- **Namespaced:** Use `vim.api.nvim_create_namespace("plugin_name")` for virtual text/highlights.
- **Private State:** Use a dedicated `lua/plugin/state.lua` module with local variables.

---

## 5. Structured Parsing (Tree-sitter)

- **Forbidden:** Regex for code analysis.
- **Required:** Use `vim.treesitter` for all code-aware logic.

```lua
---@param bufnr number
function M.get_node_at_cursor(bufnr)
    local node = vim.treesitter.get_node({ bufnr = bufnr })
    if not node then return nil end
    return node:type()
end
```

---

## 6. Standard Directory Structure

```plaintext
lua/plugin/
├── init.lua          # Public API / setup()
├── health.lua        # Environment diagnostics (:checkhealth)
├── config.lua        # Default values and validation
├── actions.lua       # Business logic (Lazy loaded)
└── state.lua         # Internal state
tests/
├── minimal_init.lua  # Headless test environment config
└── test_*.lua        # Automated test suites
```

---

## 7. Contribution Checklist

- [ ] All functions have EmmyLua types.
- [ ] No blocking calls (`vim.fn.*`) in core logic.
- [ ] Code passes stylua and selene linting.
- [ ] Tests in `tests/` pass with 0 failures.
- [ ] No logic is executed during `require("plugin")`.

> **Stability is the priority. Never block the UI thread.**
