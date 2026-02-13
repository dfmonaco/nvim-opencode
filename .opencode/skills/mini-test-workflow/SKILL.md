---
name: mini-test-workflow
description: "Comprehensive mini.test testing patterns with process isolation and child processes for Neovim plugins. Use when: (1) Writing new test files, (2) Debugging test failures, (3) Adding test coverage to features, (4) Understanding test infrastructure, (5) Working with child Neovim processes, (6) Running tests via Makefile"
---

# Mini.test Testing Workflow

## Overview

This skill provides testing patterns for Neovim plugins using mini.test with strict process isolation. Each test runs in a fresh child Neovim instance to ensure reliability and prevent test pollution.

## Quick Start

Essential pattern for a test file with child process:

```lua
local MiniTest = require('mini.test')
local T = MiniTest.new_set()

-- Create child Neovim instance
local child = MiniTest.new_child_neovim()

-- Setup hooks for process management
T['Your Test Group'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      -- Restart with minimal init before each test
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      -- Load your plugin
      child.lua([[require('plugin').setup()]])
    end,
    post_once = function()
      -- Clean up after all tests in this set
      child.stop()
    end,
  },
})

-- Write test cases
T['Your Test Group']['test case name'] = function()
  -- Your test logic here using child.lua(), child.cmd(), etc.
  local result = child.lua_get([[vim.api.nvim_buf_get_name(0)]])
  MiniTest.expect.equality(result, 'expected_value')
end

return T
```

## Test Structure

**Location:** All tests MUST reside in `tests/` directory

**Naming:** Test files MUST be named `test_*.lua`

**Organization:** Mirror source structure for clarity
- `lua/plugin/commands/prompt.lua` → `tests/commands/test_prompt.lua`
- `lua/plugin/client.lua` → `tests/test_client.lua`

**Test set pattern:**
```lua
local MiniTest = require('mini.test')
local T = MiniTest.new_set()

-- Nested test sets for organization
T['Module name'] = MiniTest.new_set()
T['Module name']['function()'] = MiniTest.new_set()
T['Module name']['function()']['test case description'] = function()
  -- Test logic
end

return T
```

## Child Process Setup

### Why Child Processes?

Child processes provide **strict test isolation**:
- Each test starts with a clean Neovim state
- No state leakage between tests
- Tests can't affect each other
- Reproducible test results

### Basic Pattern

```lua
local child = MiniTest.new_child_neovim()

T['Test Group'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      child.lua([[require('plugin').setup()]])
    end,
    post_once = child.stop,
  },
})
```

### Interacting with Child Process

**Execute Lua code:**
```lua
-- Execute and discard result
child.lua([[vim.cmd('edit test.txt')]])

-- Execute and return result
local bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
```

**Execute Vim commands:**
```lua
child.cmd('OCPrompt')
local output = child.cmd_capture('messages')
```

**Access API directly:**
```lua
local buf_name = child.lua_get([[vim.api.nvim_buf_get_name(0)]])
local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
```

## Running Tests

**Run all tests:**
```bash
make test
```

**Run a specific test file:**
```bash
make test_file FILE=tests/test_client.lua
```

**Interactive testing (for debugging):**
```vim
:lua MiniTest.run_file('tests/test_client.lua')
```

The Makefile ensures tests use the correct headless environment and dependencies.

## Real Examples from This Codebase

### Example 1: Testing Command Registration

From `tests/commands/test_prompt.lua`:

```lua
T['OCPrompt command']['is registered after setup'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Check if command exists
  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands['OCPrompt'], nil)
  
  child.stop()
end
```

**Key patterns:**
- Create fresh child process for each test
- Load plugin with `setup()`
- Use `lua_get()` to retrieve Neovim state
- Use expectations to validate behavior
- Clean up with `child.stop()`

### Example 2: Testing Buffer Options

From `tests/commands/test_prompt.lua`:

```lua
T['OCPrompt command']['sets correct buffer options'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Check buffer-local options
  local buftype = child.lua_get([[vim.bo.buftype]])
  MiniTest.expect.equality(buftype, 'nofile')
  
  local filetype = child.lua_get([[vim.bo.filetype]])
  MiniTest.expect.equality(filetype, 'OCPrompt')
  
  child.stop()
end
```

**Key patterns:**
- Execute commands with `child.cmd()`
- Check buffer-local options with `vim.bo.*`
- Check window-local options with `vim.wo.*`
- Multiple expectations in single test case

### Example 3: Testing with Hooks (Reusable Pattern)

Efficient pattern when running multiple related tests:

```lua
local child = MiniTest.new_child_neovim()

T['Module tests'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      -- Runs before EACH test case
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      child.lua([[require('plugin').setup()]])
    end,
    post_once = function()
      -- Runs after ALL test cases in this set
      child.stop()
    end,
  },
})

-- All test cases in this set share the hook setup
T['Module tests']['first test'] = function()
  -- Child is already restarted and plugin loaded
  local result = child.lua_get([[_G.some_value]])
  MiniTest.expect.equality(result, expected)
end

T['Module tests']['second test'] = function()
  -- Child is restarted again (fresh state)
  -- Plugin is loaded again
end
```

**Benefits:**
- No repetition in test cases
- Guaranteed fresh state per test
- Clean separation of setup/teardown

## Common Patterns

### Pattern: Testing State Isolation

```lua
T['state isolation']['first test modifies state'] = function()
  child.lua([[_G.test_value = 123]])
  local val = child.lua_get([[_G.test_value]])
  MiniTest.expect.equality(val, 123)
end

T['state isolation']['second test sees clean state'] = function()
  -- pre_case hook restarted child, so _G.test_value is nil
  local val = child.lua_get([[_G.test_value]])
  MiniTest.expect.equality(val, nil)
end
```

### Pattern: Testing String Patterns

```lua
T['buffer name']['ends with OCPrompt'] = function()
  child.cmd('OCPrompt')
  local buf_name = child.lua_get([[vim.api.nvim_buf_get_name(0)]])
  local name_matches = buf_name:match('OCPrompt$') ~= nil
  MiniTest.expect.equality(name_matches, true)
end
```

### Pattern: Testing Options

```lua
-- Window options
local number = child.lua_get([[vim.wo.number]])
MiniTest.expect.equality(number, false)

-- Buffer options
local buftype = child.lua_get([[vim.bo.buftype]])
MiniTest.expect.equality(buftype, 'nofile')

-- Global options
local lines = child.lua_get([[vim.o.lines]])
```

## Troubleshooting

### Test Hangs or Times Out

**Cause:** Child process is waiting for input (hit-enter-prompt, operator-pending mode)

**Solutions:**
- Increase `cmdheight`: `child.o.cmdheight = 10`
- Exit operator-pending mode explicitly
- Check for unexpected prompts

### State Leaks Between Tests

**Cause:** Not restarting child process in `pre_case` hook

**Solution:** Always restart in `pre_case`:
```lua
hooks = {
  pre_case = function()
    child.restart({ '-u', 'scripts/minimal_init.lua' })
  end,
}
```

### "Cannot convert given lua type" Error

**Cause:** Trying to pass functions or userdata through RPC

**Solution:** Move logic to child process side:
```lua
-- ❌ Bad: Pass function
child.lua(my_function)

-- ✅ Good: Define function in child
child.lua([[
  local function my_function()
    -- implementation
  end
  my_function()
]])
```

### Child Process Not Found

**Cause:** Missing `post_once = child.stop` hook

**Solution:** Always clean up:
```lua
hooks = {
  post_once = child.stop,
}
```

## Deep Dive

For comprehensive mini.test patterns, advanced techniques, and testing philosophy:

**Read:** references/testing-guidelines.md

This comprehensive guide includes:
- **Screenshot testing** - UI validation and visual regression testing
- **Parametrization** - Testing with multiple inputs efficiently
- **Custom expectations** - Creating specialized assertions
- **Retry logic** - Handling flaky tests gracefully
- **Emulating typing keys** - Interactive behavior testing
- **Customizing test runs** - Advanced filtering and reporting
- **Case helpers** - skip(), finally(), add_note()
- **General tips** - Best practices and edge cases from mini.nvim development
