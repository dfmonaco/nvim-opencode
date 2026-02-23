# OpenCode Events Reference

This document describes all events available in the OpenCode API (v2 / latest), their payloads, and how they should be used in the nvim-opencode plugin.

## Source Locations

| Source | Purpose |
|--------|---------|
| `packages/sdk/openapi.json` | Authoritative OpenAPI 3.1.1 spec; check `components/schemas/Event.*` for canonical definitions |
| `packages/sdk/js/src/v2/gen/types.gen.ts` | Auto-generated TypeScript types for API v2 (latest). **Use this as primary reference.** |
| `packages/opencode/src/cli/cmd/tui/event.ts` | TUI-specific events with their Zod schemas and runtime defaults |
| `packages/sdk/js/src/gen/types.gen.ts` | Auto-generated types for API v1 (older, fewer events — do not use for new work) |

To check for updates, monitor `packages/sdk/js/src/v2/gen/types.gen.ts` and `packages/sdk/openapi.json` in the upstream opencode repository.

---

## Transport

Events are delivered via **Server-Sent Events (SSE)**.

| Endpoint | Operation ID | Description |
|----------|--------------|-------------|
| `GET /event?directory=<dir>` | `event.subscribe` | Subscribe to events scoped to a specific working directory |
| `GET /global/event` | `global.event` | Subscribe to global events across all directories (wraps each event in `GlobalEvent`) |

### GlobalEvent wrapper

When using `/global/event`, each event is wrapped:

```typescript
type GlobalEvent = {
  directory: string  // working directory the event belongs to
  payload: Event     // the actual event
}
```

---

## Event Structure

Every event has this top-level shape:

```typescript
{
  type: "<category>.<action>"  // discriminant field
  properties: { ... }          // event-specific payload
}
```

---

## Complete Event List (v2 / latest)

### Installation Events

#### `installation.updated`
Fired when the OpenCode installation has been updated.

```typescript
type EventInstallationUpdated = {
  type: "installation.updated"
  properties: {
    version: string
  }
}
```

#### `installation.update-available`
Fired when a newer version of OpenCode is available but not yet installed.

```typescript
type EventInstallationUpdateAvailable = {
  type: "installation.update-available"
  properties: {
    version: string
  }
}
```

---

### Server Events

#### `server.connected`
Fired when a client successfully connects to the OpenCode server. Properties are empty (reserved for future use).

```typescript
type EventServerConnected = {
  type: "server.connected"
  properties: {}
}
```

**Plugin use:** Trigger initial state sync (sessions, messages) after this event.

#### `server.instance.disposed`
Fired when a server instance for a specific working directory is torn down.

```typescript
type EventServerInstanceDisposed = {
  type: "server.instance.disposed"
  properties: {
    directory: string
  }
}
```

#### `global.disposed`
Fired when the global OpenCode process is shutting down. Properties are empty.

```typescript
type EventGlobalDisposed = {
  type: "global.disposed"
  properties: {}
}
```

**Plugin use:** Clean up all state, close UI elements, display a disconnected notice.

---

### Project Events

#### `project.updated`
Fired when project metadata changes.

```typescript
type EventProjectUpdated = {
  type: "project.updated"
  properties: {
    id: string
    worktree: string
    vcs?: "git"
    name?: string
    icon?: { url?: string; override?: string; color?: string }
    commands?: { start?: string }
    time: { created: number; updated: number; initialized?: number }
    sandboxes: string[]
  }
}
```

---

### Session Events

#### `session.created`
Fired when a new session is created.

```typescript
type EventSessionCreated = {
  type: "session.created"
  properties: {
    info: Session
  }
}
```

#### `session.updated`
Fired when session metadata (title, share URL, summary, etc.) changes.

```typescript
type EventSessionUpdated = {
  type: "session.updated"
  properties: {
    info: Session
  }
}
```

#### `session.deleted`
Fired when a session is deleted.

```typescript
type EventSessionDeleted = {
  type: "session.deleted"
  properties: {
    info: Session
  }
}
```

#### `session.status`
Fired when a session's busy/idle/retry state changes.

```typescript
type EventSessionStatus = {
  type: "session.status"
  properties: {
    sessionID: string
    status:
      | { type: "idle" }
      | { type: "busy" }
      | { type: "retry"; attempt: number; message: string; next: number }
  }
}
```

**Plugin use:** Show/hide loading indicators; `retry` status includes the next retry timestamp in milliseconds.

#### `session.idle`
Simplified event fired when a session transitions to idle (complement to `session.status`).

```typescript
type EventSessionIdle = {
  type: "session.idle"
  properties: {
    sessionID: string
  }
}
```

#### `session.compacted`
Fired when a session's context has been compacted (summarized to reduce token usage).

```typescript
type EventSessionCompacted = {
  type: "session.compacted"
  properties: {
    sessionID: string
  }
}
```

#### `session.diff`
Fired with the current file diff summary for a session.

```typescript
type EventSessionDiff = {
  type: "session.diff"
  properties: {
    sessionID: string
    diff: FileDiff[]
  }
}
```

Where `FileDiff`:
```typescript
type FileDiff = {
  file: string
  before: string
  after: string
  additions: number
  deletions: number
  status?: "added" | "deleted" | "modified"
}
```

#### `session.error`
Fired when a session-level error occurs (e.g., provider auth failure, context overflow).

```typescript
type EventSessionError = {
  type: "session.error"
  properties: {
    sessionID?: string
    error?: ProviderAuthError | UnknownError | MessageOutputLengthError
           | MessageAbortedError | StructuredOutputError | ContextOverflowError | ApiError
  }
}
```

---

### Message Events

#### `message.updated`
Fired when a message (user or assistant) is created or updated.

```typescript
type EventMessageUpdated = {
  type: "message.updated"
  properties: {
    info: UserMessage | AssistantMessage
  }
}
```

Key fields on `AssistantMessage`:
- `role: "assistant"`, `modelID`, `providerID`, `cost`, `tokens`
- `time.completed` — set when the message is fully generated
- `error` — set if generation failed
- `finish` — LLM finish reason

Key fields on `UserMessage`:
- `role: "user"`, `agent`, `model.providerID`, `model.modelID`

#### `message.removed`
Fired when a message is deleted (e.g., undo operation).

```typescript
type EventMessageRemoved = {
  type: "message.removed"
  properties: {
    sessionID: string
    messageID: string
  }
}
```

---

### Message Part Events

Message parts are the streaming building blocks of an assistant message.

#### `message.part.updated`
Fired when a part is created or fully replaced. The `part` discriminant `type` field identifies the part kind.

```typescript
type EventMessagePartUpdated = {
  type: "message.part.updated"
  properties: {
    part: Part  // see Part union below
  }
}
```

**Part union:**

| `part.type` | Description |
|-------------|-------------|
| `"text"` | Plain text content from the assistant |
| `"reasoning"` | Chain-of-thought / thinking block |
| `"tool"` | A tool call with its state (pending → running → completed/error) |
| `"file"` | A file attachment (image, PDF, etc.) |
| `"subtask"` | A sub-agent task spawned by the assistant |
| `"step-start"` | Marks the start of an agentic step |
| `"step-finish"` | Marks the end of a step with cost/token summary |
| `"snapshot"` | A filesystem snapshot reference |
| `"patch"` | A set of file patches applied in this step |
| `"agent"` | Identifies which agent produced this content |
| `"retry"` | A retry attempt record |
| `"compaction"` | Marks a context compaction point |

**ToolPart state machine:** `pending` → `running` → `completed` or `error`

```typescript
type ToolPart = {
  id: string; sessionID: string; messageID: string
  type: "tool"
  callID: string
  tool: string           // tool name
  state: ToolStatePending | ToolStateRunning | ToolStateCompleted | ToolStateError
}
```

#### `message.part.delta`
Incremental text delta for a streaming part (avoids re-sending the full part on every keystroke).

```typescript
type EventMessagePartDelta = {
  type: "message.part.delta"
  properties: {
    sessionID: string
    messageID: string
    partID: string
    field: string   // field being updated, e.g. "text"
    delta: string   // the incremental string to append
  }
}
```

**Plugin use:** Append `delta` to the local buffer for `partID.field` rather than waiting for the full `message.part.updated`.

#### `message.part.removed`
Fired when a part is deleted.

```typescript
type EventMessagePartRemoved = {
  type: "message.part.removed"
  properties: {
    sessionID: string
    messageID: string
    partID: string
  }
}
```

---

### Permission Events

#### `permission.asked`
Fired when the AI requests permission to perform an action (e.g., run a bash command, edit a file).

```typescript
type EventPermissionAsked = {
  type: "permission.asked"
  properties: {
    id: string
    sessionID: string
    permission: string      // e.g. "bash", "edit"
    patterns: string[]      // file patterns or command patterns
    metadata: Record<string, unknown>
    always: string[]        // patterns already permanently allowed
    tool?: { messageID: string; callID: string }
  }
}
```

**Plugin use:** Present a prompt to the user; reply via the `POST /permission/{id}` endpoint.

#### `permission.replied`
Fired after a permission request has been answered.

```typescript
type EventPermissionReplied = {
  type: "permission.replied"
  properties: {
    sessionID: string
    requestID: string
    reply: "once" | "always" | "reject"
  }
}
```

---

### Question Events

#### `question.asked`
Fired when the AI asks the user a structured question (multiple-choice or free-text).

```typescript
type EventQuestionAsked = {
  type: "question.asked"
  properties: {
    id: string
    sessionID: string
    questions: Array<{
      question: string
      header: string         // short label (max 30 chars)
      options: Array<{ label: string; description: string }>
      multiple?: boolean
      custom?: boolean       // allow free-text answer (default: true)
    }>
    tool?: { messageID: string; callID: string }
  }
}
```

#### `question.replied`
Fired after a question has been answered.

```typescript
type EventQuestionReplied = {
  type: "question.replied"
  properties: {
    sessionID: string
    requestID: string
    answers: string[][]   // one array of selected labels per question
  }
}
```

#### `question.rejected`
Fired when the user dismisses a question without answering.

```typescript
type EventQuestionRejected = {
  type: "question.rejected"
  properties: {
    sessionID: string
    requestID: string
  }
}
```

---

### File Events

#### `file.edited`
Fired when a file is edited by the AI.

```typescript
type EventFileEdited = {
  type: "file.edited"
  properties: {
    file: string
  }
}
```

#### `file.watcher.updated`
Fired by the filesystem watcher when an external change is detected.

```typescript
type EventFileWatcherUpdated = {
  type: "file.watcher.updated"
  properties: {
    file: string
    event: "add" | "change" | "unlink"
  }
}
```

---

### LSP Events

#### `lsp.client.diagnostics`
Fired when LSP diagnostics are updated for a file.

```typescript
type EventLspClientDiagnostics = {
  type: "lsp.client.diagnostics"
  properties: {
    serverID: string
    path: string
  }
}
```

#### `lsp.updated`
Fired when the LSP client state changes (e.g., a server connects or restarts). Properties are empty (use as a refresh signal).

```typescript
type EventLspUpdated = {
  type: "lsp.updated"
  properties: {}
}
```

---

### Todo Events

#### `todo.updated`
Fired when the AI's todo list changes within a session.

```typescript
type EventTodoUpdated = {
  type: "todo.updated"
  properties: {
    sessionID: string
    todos: Array<{
      content: string
      status: string   // "pending" | "in_progress" | "completed" | "cancelled"
      priority: string // "high" | "medium" | "low"
    }>
  }
}
```

---

### VCS Events

#### `vcs.branch.updated`
Fired when the active VCS branch changes.

```typescript
type EventVcsBranchUpdated = {
  type: "vcs.branch.updated"
  properties: {
    branch?: string
  }
}
```

---

### PTY Events

PTY events cover terminal sessions spawned by OpenCode.

#### `pty.created`
```typescript
type EventPtyCreated = {
  type: "pty.created"
  properties: {
    info: { id: string; title: string; command: string; args: string[]; cwd: string; status: "running" | "exited"; pid: number }
  }
}
```

#### `pty.updated`
```typescript
type EventPtyUpdated = {
  type: "pty.updated"
  properties: {
    info: Pty  // same shape as pty.created
  }
}
```

#### `pty.exited`
```typescript
type EventPtyExited = {
  type: "pty.exited"
  properties: {
    id: string
    exitCode: number
  }
}
```

#### `pty.deleted`
```typescript
type EventPtyDeleted = {
  type: "pty.deleted"
  properties: {
    id: string
  }
}
```

---

### Worktree Events

#### `worktree.ready`
Fired when a new git worktree is fully initialized.

```typescript
type EventWorktreeReady = {
  type: "worktree.ready"
  properties: {
    name: string
    branch: string
  }
}
```

#### `worktree.failed`
Fired when worktree initialization fails.

```typescript
type EventWorktreeFailed = {
  type: "worktree.failed"
  properties: {
    message: string
  }
}
```

---

### MCP Events

#### `mcp.tools.changed`
Fired when the tool list for an MCP server changes (server restarted, tools added/removed).

```typescript
type EventMcpToolsChanged = {
  type: "mcp.tools.changed"
  properties: {
    server: string
  }
}
```

#### `mcp.browser.open.failed`
Fired when an MCP server requires browser-based OAuth but the browser could not be opened (e.g., headless environment).

```typescript
type EventMcpBrowserOpenFailed = {
  type: "mcp.browser.open.failed"
  properties: {
    mcpName: string
    url: string
  }
}
```

---

### Command Events

#### `command.executed`
Fired after a slash command has been executed.

```typescript
type EventCommandExecuted = {
  type: "command.executed"
  properties: {
    name: string
    sessionID: string
    arguments: string
    messageID: string
  }
}
```

---

### TUI Events

TUI events are sent **to** the OpenCode server (published by external clients such as this plugin) to drive the TUI. They are defined in `packages/opencode/src/cli/cmd/tui/event.ts`.

#### `tui.prompt.append`
Append text to the TUI prompt input field.

```typescript
type EventTuiPromptAppend = {
  type: "tui.prompt.append"
  properties: {
    text: string
  }
}
```

#### `tui.command.execute`
Trigger a TUI command programmatically.

```typescript
type EventTuiCommandExecute = {
  type: "tui.command.execute"
  properties: {
    command:
      | "session.list"       // open session list
      | "session.new"        // create new session
      | "session.share"      // share current session
      | "session.interrupt"  // interrupt running session
      | "session.compact"    // compact session context
      | "session.page.up"    // scroll messages up one page
      | "session.page.down"  // scroll messages down one page
      | "session.line.up"    // scroll messages up one line
      | "session.line.down"  // scroll messages down one line
      | "session.half.page.up"
      | "session.half.page.down"
      | "session.first"      // jump to first message
      | "session.last"       // jump to last message
      | "prompt.clear"       // clear the prompt input
      | "prompt.submit"      // submit the current prompt
      | "agent.cycle"        // cycle through available agents
      | string               // custom/future commands
  }
}
```

#### `tui.toast.show`
Display a toast notification in the TUI.

```typescript
type EventTuiToastShow = {
  type: "tui.toast.show"
  properties: {
    title?: string
    message: string
    variant: "info" | "success" | "warning" | "error"
    duration?: number  // milliseconds; default 5000
  }
}
```

#### `tui.session.select`
Navigate the TUI to a specific session.

```typescript
type EventTuiSessionSelect = {
  type: "tui.session.select"
  properties: {
    sessionID: string  // must match /^ses/
  }
}
```

---

## Summary Table

| Event Type | Direction | Category | Key Payload Fields |
|------------|-----------|----------|--------------------|
| `installation.updated` | server→client | Installation | `version` |
| `installation.update-available` | server→client | Installation | `version` |
| `server.connected` | server→client | Server | — |
| `server.instance.disposed` | server→client | Server | `directory` |
| `global.disposed` | server→client | Server | — |
| `project.updated` | server→client | Project | `id`, `worktree`, `name` |
| `session.created` | server→client | Session | `info` (Session) |
| `session.updated` | server→client | Session | `info` (Session) |
| `session.deleted` | server→client | Session | `info` (Session) |
| `session.status` | server→client | Session | `sessionID`, `status` |
| `session.idle` | server→client | Session | `sessionID` |
| `session.compacted` | server→client | Session | `sessionID` |
| `session.diff` | server→client | Session | `sessionID`, `diff[]` |
| `session.error` | server→client | Session | `sessionID`, `error` |
| `message.updated` | server→client | Message | `info` (Message) |
| `message.removed` | server→client | Message | `sessionID`, `messageID` |
| `message.part.updated` | server→client | Message | `part` (Part) |
| `message.part.delta` | server→client | Message | `partID`, `field`, `delta` |
| `message.part.removed` | server→client | Message | `sessionID`, `messageID`, `partID` |
| `permission.asked` | server→client | Permission | `id`, `permission`, `patterns` |
| `permission.replied` | server→client | Permission | `requestID`, `reply` |
| `question.asked` | server→client | Question | `id`, `questions[]` |
| `question.replied` | server→client | Question | `requestID`, `answers` |
| `question.rejected` | server→client | Question | `requestID` |
| `file.edited` | server→client | File | `file` |
| `file.watcher.updated` | server→client | File | `file`, `event` |
| `lsp.client.diagnostics` | server→client | LSP | `serverID`, `path` |
| `lsp.updated` | server→client | LSP | — |
| `todo.updated` | server→client | Todo | `sessionID`, `todos[]` |
| `vcs.branch.updated` | server→client | VCS | `branch` |
| `pty.created` | server→client | PTY | `info` (Pty) |
| `pty.updated` | server→client | PTY | `info` (Pty) |
| `pty.exited` | server→client | PTY | `id`, `exitCode` |
| `pty.deleted` | server→client | PTY | `id` |
| `worktree.ready` | server→client | Worktree | `name`, `branch` |
| `worktree.failed` | server→client | Worktree | `message` |
| `mcp.tools.changed` | server→client | MCP | `server` |
| `mcp.browser.open.failed` | server→client | MCP | `mcpName`, `url` |
| `command.executed` | server→client | Command | `name`, `sessionID`, `messageID` |
| `tui.prompt.append` | client→server | TUI | `text` |
| `tui.command.execute` | client→server | TUI | `command` |
| `tui.toast.show` | client→server | TUI | `message`, `variant` |
| `tui.session.select` | client→server | TUI | `sessionID` |

> **Note on v1 vs v2:** The v1 SDK (`packages/sdk/js/src/gen/types.gen.ts`) has fewer event types and some missing fields (e.g., no `status` field on `FileDiff`, no `EventSessionCreated/Updated/Deleted`, no question/todo/PTY/worktree events). Always target the v2 API.
