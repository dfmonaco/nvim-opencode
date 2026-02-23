# OpenCode Server API Reference

This document describes all HTTP endpoints exposed by the OpenCode server (OpenAPI 3.1.1 / latest),
their request/response shapes, and how to use them.

## Source Locations

| Source | Purpose |
|--------|---------|
| `packages/sdk/openapi.json` | **Authoritative** OpenAPI 3.1.1 spec. Canonical definitions for all endpoints and schemas. Use this as primary reference. |
| `packages/web/src/content/docs/server.mdx` | Official documentation page. Useful for narrative structure but **incomplete** — missing ~30 endpoints compared to the spec. |
| `packages/sdk/js/src/v2/gen/types.gen.ts` | Auto-generated types (v2 / latest). Cross-reference for field names and response shapes. |

To check for updates, monitor `packages/sdk/openapi.json` in the upstream opencode repository.

> **Note on `server.mdx` accuracy:** The mdx page references the v1 type file and omits many endpoints: `global.config`, `global.dispose`, `instance.dispose`, `path.get`, `vcs.get`, `app.*`, MCP auth/connect/disconnect, `permission.list`, `question.list/reject`, `part.delete/update`, all `tui.publish/selectSession/openHelp/openModels/openThemes` endpoints, `experimental.session.list`, `experimental.resource.list`, and `worktree.*`. Always validate against `openapi.json`.

---

## Transport & Base URL

```
http://<hostname>:<port>
```

Default: `http://127.0.0.1:4096`

The server can be launched standalone with `opencode serve [--port N] [--hostname H]`.
When the TUI is running it also exposes a server on a randomly assigned port (pass `--port` to fix it).

### Authentication

Set `OPENCODE_SERVER_PASSWORD` for HTTP Basic auth. Username defaults to `opencode`
(override with `OPENCODE_SERVER_USERNAME`).

### `directory` query parameter

Nearly every endpoint accepts an optional `?directory=<path>` query parameter that scopes
the request to a specific project working directory. When omitted, the server uses its
own working directory. This is how multi-project setups are addressed.

---

## Complete Endpoint Reference

### Global

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/global/health` | `global.health` | Server health and version | `{ healthy: true, version: string }` |
| `GET` | `/global/event` | `global.event` | Global SSE event stream (all directories) | SSE stream of `GlobalEvent` |
| `GET` | `/global/config` | `global.config.get` | Get global configuration | `Config` |
| `PATCH` | `/global/config` | `global.config.update` | Update global configuration | `Config` |
| `POST` | `/global/dispose` | `global.dispose` | Dispose all instances | `boolean` |

**`GlobalEvent` wrapper** (used by `/global/event`):
```json
{
  "directory": "string",  // working directory the event belongs to
  "payload": {}           // the actual Event object
}
```

---

### Events (SSE)

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/event` | `event.subscribe` | Subscribe to directory-scoped SSE events | SSE stream of `Event` |

For the full event catalogue, see `docs/opencode-events.md`.

---

### Instance

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `POST` | `/instance/dispose` | `instance.dispose` | Dispose the current directory-scoped instance | `boolean` |

---

### Path & VCS

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/path` | `path.get` | Get working directory paths | `Path` |
| `GET` | `/vcs` | `vcs.get` | Get VCS info for the current project | `VcsInfo` |

**`Path` schema:**
```json
{
  "home": "string",       // home directory
  "state": "string",      // state/data directory
  "config": "string",     // config directory
  "worktree": "string",   // current worktree path
  "directory": "string"   // current working directory
}
```

**`VcsInfo` schema:**
```json
{
  "branch": "string"      // current git branch name
}
```

---

### Project

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/project` | `project.list` | List all projects | `Project[]` |
| `GET` | `/project/current` | `project.current` | Get the current project | `Project` |
| `PATCH` | `/project/{projectID}` | `project.update` | Update project properties | `Project` |

**`PATCH /project/{projectID}` body:**
```json
{
  "name": "string",                      // optional
  "icon": {                              // optional
    "url": "string",                     // optional
    "override": "string",               // optional
    "color": "string"                   // optional
  },
  "commands": {                          // optional
    "start": "string"                   // optional; startup script for new worktrees
  }
}
```

**`Project` schema:**
```json
{
  "id": "string",
  "worktree": "string",
  "vcs": "git",                          // optional; currently only "git"
  "name": "string",                      // optional
  "icon": {                              // optional
    "url": "string",
    "override": "string",
    "color": "string"
  },
  "commands": {                          // optional
    "start": "string"
  },
  "time": {
    "created": 0,                        // unix milliseconds
    "updated": 0,                        // unix milliseconds
    "initialized": 0                    // optional; unix milliseconds
  },
  "sandboxes": ["string"]
}
```

---

### Config

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/config` | `config.get` | Get directory-scoped config | `Config` |
| `PATCH` | `/config` | `config.update` | Update directory-scoped config | `Config` |
| `GET` | `/config/providers` | `config.providers` | List configured providers and default models | `{ providers: Provider[], default: Record<string, string> }` |

**Note:** `/config` is directory-scoped; `/global/config` operates globally. Both accept `PATCH`
with a partial `Config` body.

---

### Provider

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/provider` | `provider.list` | List all providers | `{ all: Provider[], default: Record<string, string>, connected: string[] }` |
| `GET` | `/provider/auth` | `provider.auth` | Get auth methods for each provider | `Record<string, ProviderAuthMethod[]>` |
| `POST` | `/provider/{providerID}/oauth/authorize` | `provider.oauth.authorize` | Start OAuth flow | `ProviderAuthAuthorization` |
| `POST` | `/provider/{providerID}/oauth/callback` | `provider.oauth.callback` | Handle OAuth callback | `boolean` |

**`POST /provider/{providerID}/oauth/authorize` body:**
```json
{
  "method": 0             // index into ProviderAuthMethod array
}
```

**`POST /provider/{providerID}/oauth/callback` body:**
```json
{
  "method": 0,            // index into ProviderAuthMethod array
  "code": "string"        // optional
}
```

---

### Auth

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `PUT` | `/auth/{providerID}` | `auth.set` | Set provider credentials | `boolean` |
| `DELETE` | `/auth/{providerID}` | `auth.remove` | Remove provider credentials | `boolean` |

Body for `PUT` must match the provider's auth schema (varies per provider).

---

### Sessions

| Method | Path | Operation ID | Description | Notes |
|--------|------|-------------|-------------|-------|
| `GET` | `/session` | `session.list` | List sessions | query: `directory?`, `roots?`, `start?`, `search?`, `limit?` |
| `POST` | `/session` | `session.create` | Create a new session | body: `{ parentID?, title?, permission? }` |
| `GET` | `/session/status` | `session.status` | Get status for all sessions | Returns `Record<string, SessionStatus>` |
| `GET` | `/session/{sessionID}` | `session.get` | Get session details | `sessionID` pattern: `^ses.*` |
| `DELETE` | `/session/{sessionID}` | `session.delete` | Delete session and all data | Returns `boolean` |
| `PATCH` | `/session/{sessionID}` | `session.update` | Update session metadata | body: `{ title?, time?: { archived?: number } }` |
| `GET` | `/session/{sessionID}/children` | `session.children` | Get child sessions | Returns `Session[]` |
| `GET` | `/session/{sessionID}/todo` | `session.todo` | Get session todo list | Returns `Todo[]` |
| `POST` | `/session/{sessionID}/init` | `session.init` | Analyze app and create `AGENTS.md` | body: `{ messageID, providerID, modelID }` (all required) |
| `POST` | `/session/{sessionID}/fork` | `session.fork` | Fork session at a message | body: `{ messageID? }` |
| `POST` | `/session/{sessionID}/abort` | `session.abort` | Abort an active session | Returns `boolean` |
| `POST` | `/session/{sessionID}/share` | `session.share` | Create shareable link | Returns `Session` |
| `DELETE` | `/session/{sessionID}/share` | `session.unshare` | Remove shareable link | Returns `Session` |
| `GET` | `/session/{sessionID}/diff` | `session.diff` | Get file diff for session | query: `messageID?`; returns `FileDiff[]` |
| `POST` | `/session/{sessionID}/summarize` | `session.summarize` | Compact session context | body: `{ providerID, modelID, auto?: boolean }` |
| `POST` | `/session/{sessionID}/revert` | `session.revert` | Revert a message | body: `{ messageID, partID? }` |
| `POST` | `/session/{sessionID}/unrevert` | `session.unrevert` | Restore all reverted messages | Returns `boolean` |

**`Session` schema:**
```json
{
  "id": "string",           // pattern: ^ses.*
  "slug": "string",
  "projectID": "string",
  "directory": "string",
  "parentID": "string",     // optional
  "summary": "string",      // optional
  "share": {                // optional
    "url": "string"
  },
  "title": "string",
  "version": 0,
  "time": {
    "created": 0,           // unix milliseconds
    "updated": 0,           // unix milliseconds
    "archived": 0           // optional; unix milliseconds
  }
}
```

**`FileDiff` schema:**
```json
{
  "file": "string",
  "before": "string",
  "after": "string",
  "additions": 0,
  "deletions": 0,
  "status": "modified"      // optional; "added" | "deleted" | "modified"
}
```

**`Todo` schema:**
```json
{
  "content": "string",
  "status": "pending",      // "pending" | "in_progress" | "completed" | "cancelled"
  "priority": "medium"      // "high" | "medium" | "low"
}
```

---

### Messages

| Method | Path | Operation ID | Description | Notes |
|--------|------|-------------|-------------|-------|
| `GET` | `/session/{sessionID}/message` | `session.messages` | List messages in a session | query: `limit?`; returns `{ info: Message, parts: Part[] }[]` |
| `POST` | `/session/{sessionID}/message` | `session.prompt` | Send message, wait for response | body: see below; returns `{ info: AssistantMessage, parts: Part[] }` |
| `GET` | `/session/{sessionID}/message/{messageID}` | `session.message` | Get a specific message | Returns `{ info: Message, parts: Part[] }` |
| `POST` | `/session/{sessionID}/prompt_async` | `session.prompt_async` | Send message without waiting | Same body as `session.prompt`; returns `204 No Content` |
| `POST` | `/session/{sessionID}/command` | `session.command` | Execute a slash command | body: `{ command, arguments, messageID?, agent?, model?, variant?, parts? }` |
| `POST` | `/session/{sessionID}/shell` | `session.shell` | Run a shell command | body: `{ agent, command, model? }` |

**`POST /session/{sessionID}/message` body:**
```json
{
  "parts": [],              // required; array of TextPartInput | FilePartInput | AgentPartInput | SubtaskPartInput
  "messageID": "string",   // optional; pattern: ^msg.*
  "model": {               // optional
    "providerID": "string",
    "modelID": "string"
  },
  "agent": "string",       // optional
  "noReply": false,        // optional
  "format": "string",      // optional; OutputFormat value
  "system": "string",      // optional
  "variant": "string",     // optional
  "tools": {}              // optional; Record<string, boolean> — deprecated, use session-level permissions instead
}
```

`POST /session/{sessionID}/prompt_async` accepts the same body but returns `204 No Content` immediately. Responses arrive via `message.updated` / `message.part.*` SSE events.

**`AssistantMessage` schema (key fields):**
```json
{
  "id": "string",
  "sessionID": "string",
  "role": "assistant",
  "time": {
    "created": 0,           // unix milliseconds
    "completed": 0          // optional; unix milliseconds; set when fully generated
  },
  "modelID": "string",
  "providerID": "string",
  "mode": "string",
  "agent": "string",
  "parentID": "string",
  "error": {},              // optional; set if generation failed
  "cost": 0,                // optional
  "tokens": {},             // optional
  "finish": "string"        // optional; LLM finish reason
}
```

**`UserMessage` schema (key fields):**
```json
{
  "id": "string",
  "sessionID": "string",
  "role": "user",
  "time": {
    "created": 0            // unix milliseconds
  },
  "agent": "string",
  "model": {
    "providerID": "string",
    "modelID": "string"
  },
  "format": "string",       // optional
  "summary": "string",      // optional
  "system": "string"        // optional
}
```

---

### Message Parts

| Method | Path | Operation ID | Description | Notes |
|--------|------|-------------|-------------|-------|
| `DELETE` | `/session/{sessionID}/message/{messageID}/part/{partID}` | `part.delete` | Delete a part | Returns `boolean` |
| `PATCH` | `/session/{sessionID}/message/{messageID}/part/{partID}` | `part.update` | Update a part | body: `Part`; returns `Part` |

---

### Permissions

| Method | Path | Operation ID | Description | Notes |
|--------|------|-------------|-------------|-------|
| `GET` | `/permission` | `permission.list` | List all pending permission requests | Returns `PermissionRequest[]` |
| `POST` | `/permission/{requestID}/reply` | `permission.reply` | Reply to a permission request | body: `{ reply: "once" \| "always" \| "reject", message? }` |
| `POST` | `/session/{sessionID}/permissions/{permissionID}` | `permission.respond` | (**deprecated**) Old permission reply | body: `{ response: "once" \| "always" \| "reject" }` |

**`PermissionRequest` schema:**
```json
{
  "id": "string",
  "sessionID": "string",
  "permission": "string",   // e.g. "bash", "edit"
  "patterns": ["string"],
  "metadata": {},           // arbitrary key/value map
  "always": ["string"],     // already permanently allowed patterns
  "tool": {                 // optional
    "messageID": "string",
    "callID": "string"
  }
}
```

Poll `GET /permission` on startup to handle any requests that arrived before the SSE subscription was established. On `permission.asked` event, call `POST /permission/{requestID}/reply`.

---

### Questions

| Method | Path | Operation ID | Description | Notes |
|--------|------|-------------|-------------|-------|
| `GET` | `/question` | `question.list` | List all pending question requests | Returns `QuestionRequest[]` |
| `POST` | `/question/{requestID}/reply` | `question.reply` | Reply to a question | body: `{ answers: string[][] }` |
| `POST` | `/question/{requestID}/reject` | `question.reject` | Reject (dismiss) a question | Returns `boolean` |

**`QuestionRequest` schema:**
```json
{
  "id": "string",
  "sessionID": "string",
  "questions": [
    {
      "question": "string",
      "header": "string",
      "options": [
        {
          "label": "string",
          "description": "string"
        }
      ],
      "multiple": false,    // optional
      "custom": true        // optional
    }
  ],
  "tool": {                 // optional
    "messageID": "string",
    "callID": "string"
  }
}
```

**`POST /question/{requestID}/reply` body:**
```json
{
  "answers": [["string"]]   // one array of selected labels per question
}
```

Poll `GET /question` on startup for any missed requests.

---

### Commands

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/command` | `command.list` | List all available slash commands | `Command[]` |

**`Command` schema:**
```json
{
  "name": "string",
  "description": "string",  // optional
  "agent": "string",         // optional
  "model": "string",         // optional
  "source": "string",        // optional
  "template": "string",
  "hints": [],
  "subtask": false           // optional
}
```

---

### Agents & Skills

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/agent` | `app.agents` | List all available agents | `Agent[]` |
| `GET` | `/skill` | `app.skills` | List all available skills | `Skill[]` |

**`Agent` schema (key fields):**
```json
{
  "name": "string",
  "description": "string",  // optional
  "mode": "string",
  "native": false,           // optional
  "hidden": false,           // optional
  "color": "string",         // optional
  "permission": {},
  "model": {                 // optional
    "providerID": "string",  // optional
    "modelID": "string"      // optional
  }
}
```

**`Skill` schema:**
```json
{
  "name": "string",
  "description": "string",
  "location": "string",
  "content": "string"
}
```

---

### Files

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/file?path=<path>` | `file.list` | List files/directories at path | `FileNode[]` |
| `GET` | `/file/content?path=<path>` | `file.read` | Read file content | `FileContent` |
| `GET` | `/file/status` | `file.status` | Get git status for tracked files | `File[]` |
| `GET` | `/find?pattern=<regex>` | `find.text` | Search file contents (ripgrep) | `TextMatch[]` |
| `GET` | `/find/file?query=<q>` | `find.files` | Find files/directories by name | `string[]` |
| `GET` | `/find/symbol?query=<q>` | `find.symbols` | Find workspace symbols (LSP) | `Symbol[]` |

**`/find/file` query parameters:**
- `query` (required) — fuzzy search string
- `type` (optional) — `"file"` or `"directory"`
- `limit` (optional) — 1–200
- `dirs` (optional) — legacy flag: `"false"` returns only files

**`TextMatch` schema:**
```json
{
  "path": { "text": "string" },
  "lines": { "text": "string" },
  "line_number": 0,
  "absolute_offset": 0,
  "submatches": [
    {
      "match": { "text": "string" },
      "start": 0,
      "end": 0
    }
  ]
}
```

---

### LSP, Formatters & MCP

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/lsp` | `lsp.status` | Get LSP server status | `LSPStatus[]` |
| `GET` | `/formatter` | `formatter.status` | Get formatter status | `FormatterStatus[]` |
| `GET` | `/mcp` | `mcp.status` | Get MCP server status | `Record<string, MCPStatus>` |
| `POST` | `/mcp` | `mcp.add` | Add an MCP server dynamically | body: `{ name, config: McpLocalConfig \| McpRemoteConfig }` |
| `POST` | `/mcp/{name}/connect` | `mcp.connect` | Connect an MCP server | Returns `boolean` |
| `POST` | `/mcp/{name}/disconnect` | `mcp.disconnect` | Disconnect an MCP server | Returns `boolean` |
| `POST` | `/mcp/{name}/auth` | `mcp.auth.start` | Start OAuth for MCP server | Returns `{ authorizationUrl: string }` |
| `POST` | `/mcp/{name}/auth/callback` | `mcp.auth.callback` | Complete MCP OAuth | body: `{ code: string }`; returns `MCPStatus` |
| `POST` | `/mcp/{name}/auth/authenticate` | `mcp.auth.authenticate` | Start OAuth and wait for browser callback | Returns `MCPStatus` |
| `DELETE` | `/mcp/{name}/auth` | `mcp.auth.remove` | Remove MCP OAuth credentials | Returns `{ success: true }` |

**`LSPStatus` schema:**
```json
{
  "id": "string",
  "name": "string",
  "root": "string",
  "status": "string"
}
```

**`FormatterStatus` schema:**
```json
{
  "name": "string",
  "extensions": ["string"],
  "enabled": true
}
```

---

### PTY (Pseudo-terminals)

| Method | Path | Operation ID | Description | Response |
|--------|------|-------------|-------------|----------|
| `GET` | `/pty` | `pty.list` | List active PTY sessions | `Pty[]` |
| `POST` | `/pty` | `pty.create` | Create a new PTY session | body: `{ command?, args?, cwd?, title?, env? }`; returns `Pty` |
| `GET` | `/pty/{ptyID}` | `pty.get` | Get PTY session info | `Pty` |
| `PUT` | `/pty/{ptyID}` | `pty.update` | Update PTY session (resize) | body: `{ title?, size?: { rows, cols } }`; returns `Pty` |
| `DELETE` | `/pty/{ptyID}` | `pty.remove` | Terminate and remove PTY session | Returns `boolean` |
| `GET` | `/pty/{ptyID}/connect` | `pty.connect` | Connect to PTY via WebSocket | Returns `boolean` |

**`Pty` schema:**
```json
{
  "id": "string",
  "title": "string",
  "command": "string",
  "args": ["string"],
  "cwd": "string",
  "status": "running",      // "running" | "exited"
  "pid": 0
}
```

---

### TUI Control

These endpoints drive the TUI when a client is connected to a running opencode TUI instance.
They are the HTTP equivalents of the `tui.*` SSE events.

| Method | Path | Operation ID | Description | Body |
|--------|------|-------------|-------------|------|
| `POST` | `/tui/append-prompt` | `tui.appendPrompt` | Append text to prompt input | `{ text: string }` |
| `POST` | `/tui/submit-prompt` | `tui.submitPrompt` | Submit the current prompt | — |
| `POST` | `/tui/clear-prompt` | `tui.clearPrompt` | Clear the prompt input | — |
| `POST` | `/tui/execute-command` | `tui.executeCommand` | Execute a TUI command | `{ command: string }` |
| `POST` | `/tui/show-toast` | `tui.showToast` | Show a toast notification | `{ message, variant, title?, duration? }` |
| `POST` | `/tui/select-session` | `tui.selectSession` | Navigate TUI to a session | `{ sessionID: string }` |
| `POST` | `/tui/open-help` | `tui.openHelp` | Open the help dialog | — |
| `POST` | `/tui/open-sessions` | `tui.openSessions` | Open the session selector | — |
| `POST` | `/tui/open-themes` | `tui.openThemes` | Open the theme selector | — |
| `POST` | `/tui/open-models` | `tui.openModels` | Open the model selector | — |
| `POST` | `/tui/publish` | `tui.publish` | Publish a raw TUI event | body: `tui.*` event object (see events doc) |
| `GET` | `/tui/control/next` | `tui.control.next` | Dequeue next TUI control request (long-poll) | Returns `{ path: string, body: any }` |
| `POST` | `/tui/control/response` | `tui.control.response` | Respond to a control request | arbitrary body |

**`tui.executeCommand` known command values:**

| Command | Description |
|---------|-------------|
| `session.list` | Open session list |
| `session.new` | Create new session |
| `session.share` | Share current session |
| `session.interrupt` | Interrupt running session |
| `session.compact` | Compact session context |
| `session.page.up/down` | Scroll messages one page |
| `session.line.up/down` | Scroll messages one line |
| `session.half.page.up/down` | Scroll half page |
| `session.first/last` | Jump to first/last message |
| `prompt.clear` | Clear prompt |
| `prompt.submit` | Submit prompt |
| `agent.cycle` | Cycle available agents |

**`tui.showToast` body:**
```json
{
  "message": "string",
  "variant": "info",        // "info" | "success" | "warning" | "error"
  "title": "string",        // optional
  "duration": 5000          // optional; milliseconds; default 5000
}
```

---

### Logging

| Method | Path | Operation ID | Description | Body |
|--------|------|-------------|-------------|------|
| `POST` | `/log` | `app.log` | Write a log entry to the server | `{ service, level, message, extra? }` |

```json
{
  "service": "string",      // required; log source identifier
  "level": "info",          // required; "debug" | "info" | "warn" | "error"
  "message": "string",      // required
  "extra": {}               // optional; arbitrary key/value map
}
```

---

### Docs

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/doc` | OpenAPI 3.1.1 spec (HTML + Swagger UI) |

---

## Experimental Endpoints

These are prefixed with `/experimental/` and may change without notice.

| Method | Path | Operation ID | Description | Notes |
|--------|------|-------------|-------------|-------|
| `GET` | `/experimental/session` | `experimental.session.list` | List sessions across all projects | query: `directory?`, `roots?`, `start?`, `cursor?`, `search?`, `limit?`, `archived?` |
| `GET` | `/experimental/resource` | `experimental.resource.list` | List MCP resources from all servers | Returns `Record<string, McpResource>` |
| `GET` | `/experimental/tool/ids` | `tool.ids` | List all tool IDs | Returns `ToolIDs` |
| `GET` | `/experimental/tool?provider=<p>&model=<m>` | `tool.list` | List tools with JSON schemas | query: `provider` + `model` required |
| `GET` | `/experimental/worktree` | `worktree.list` | List sandbox worktrees | Returns `string[]` (paths) |
| `POST` | `/experimental/worktree` | `worktree.create` | Create a new git worktree | body: `WorktreeCreateInput` |
| `DELETE` | `/experimental/worktree` | `worktree.remove` | Remove a worktree and its branch | body: `WorktreeRemoveInput` |
| `POST` | `/experimental/worktree/reset` | `worktree.reset` | Reset worktree to default branch | body: `WorktreeResetInput` |

**`experimental.session.list` vs `session.list`:** The experimental version returns
`GlobalSession[]` (which includes a `project` field) and supports `cursor`-based pagination
and `archived` filtering. Use this for cross-project session listings.

---

## Deprecated Endpoints

| Endpoint | Operation ID | Replacement |
|----------|-------------|-------------|
| `POST /session/{sessionID}/permissions/{permissionID}` | `permission.respond` | `POST /permission/{requestID}/reply` (`permission.reply`) |

The old endpoint only accepted `{ response: "once" \| "always" \| "reject" }`.
The new one accepts `{ reply: ..., message? }` and uses a top-level `/permission/` path.

---

## Summary Table

| Operation ID | Method | Path | Description |
|-------------|--------|------|-------------|
| `global.health` | GET | `/global/health` | Startup health check |
| `event.subscribe` | GET | `/event` | Directory-scoped SSE stream |
| `global.event` | GET | `/global/event` | Global SSE stream |
| `session.list` | GET | `/session` | List all sessions |
| `session.create` | POST | `/session` | Create new session |
| `session.get` | GET | `/session/{id}` | Fetch single session |
| `session.delete` | DELETE | `/session/{id}` | Delete session |
| `session.update` | PATCH | `/session/{id}` | Rename / archive session |
| `session.abort` | POST | `/session/{id}/abort` | Interrupt AI response |
| `session.status` | GET | `/session/status` | Bulk status sync |
| `session.messages` | GET | `/session/{id}/message` | Load message history |
| `session.prompt` | POST | `/session/{id}/message` | Send prompt (blocking) |
| `session.prompt_async` | POST | `/session/{id}/prompt_async` | Send prompt (non-blocking) |
| `session.command` | POST | `/session/{id}/command` | Execute slash command |
| `session.revert` | POST | `/session/{id}/revert` | Undo message |
| `session.diff` | GET | `/session/{id}/diff` | Get file changes for session |
| `permission.list` | GET | `/permission` | List pending permissions |
| `permission.reply` | POST | `/permission/{id}/reply` | Answer permission request |
| `question.list` | GET | `/question` | List pending questions |
| `question.reply` | POST | `/question/{id}/reply` | Answer question |
| `question.reject` | POST | `/question/{id}/reject` | Dismiss question |
| `app.agents` | GET | `/agent` | List agents |
| `command.list` | GET | `/command` | Load available slash commands |
| `tui.appendPrompt` | POST | `/tui/append-prompt` | Prefill TUI prompt |
| `tui.submitPrompt` | POST | `/tui/submit-prompt` | Submit TUI prompt |
| `tui.selectSession` | POST | `/tui/select-session` | Navigate TUI to session |
| `tui.showToast` | POST | `/tui/show-toast` | Show notification in TUI |
| `tui.executeCommand` | POST | `/tui/execute-command` | Trigger TUI actions |
| `app.log` | POST | `/log` | Write log entry to server |
| `path.get` | GET | `/path` | Resolve working directory paths |
| `vcs.get` | GET | `/vcs` | Get current git branch |
| `config.get` | GET | `/config` | Read directory config |
| `provider.list` | GET | `/provider` | List providers and models |
| `lsp.status` | GET | `/lsp` | LSP server info |
| `mcp.status` | GET | `/mcp` | MCP server info |
| `pty.list` | GET | `/pty` | List terminal sessions |
| `pty.create` | POST | `/pty` | Open a terminal |
