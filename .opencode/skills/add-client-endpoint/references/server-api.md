# OpenCode Server API Reference

This document provides a comprehensive reference for all OpenCode server HTTP endpoints. Use this to understand available endpoints when implementing new client methods.

**Base URL:** `http://127.0.0.1:4096` (configurable)

**Source Code Reference:**  
This documentation is based on OpenCode server source code. For the canonical schema definitions, see:
- **Route definitions**: `/packages/opencode/src/server/routes/*.ts`
- **Type schemas**: `/packages/opencode/src/session/*.ts`
- **Generated TypeScript types**: `/packages/sdk/js/src/gen/types.gen.ts`

**Note:** This documentation was last updated based on OpenCode v1.1.60. Always refer to the source code for the most accurate and up-to-date schemas.

---

## Table of Contents

- [Global](#global)
- [Project](#project)
- [Path & VCS](#path--vcs)
- [Instance](#instance)
- [Config](#config)
- [Provider](#provider)
- [Sessions](#sessions)
- [Messages](#messages)
- [Commands](#commands)
- [Files](#files)
- [Tools (Experimental)](#tools-experimental)
- [LSP, Formatters & MCP](#lsp-formatters--mcp)
- [Agents](#agents)
- [Logging](#logging)
- [TUI](#tui)
- [Auth](#auth)
- [Events](#events)
- [Docs](#docs)

---

## Global

### GET `/global/health`

Get server health and version.

**Response:**
```json
{
  "healthy": true,
  "version": "1.2.3"
}
```

**Response Type:**
```lua
---@class HealthResponse
---@field healthy boolean Server health status
---@field version string Server version
```

### GET `/global/event`

Get global events (SSE stream).

**Response:** Server-sent events stream

---

## Project

### GET `/project`

List all projects.

**Response:** Array of `Project` objects

**Response Type:** See [TypeScript definitions](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)

### GET `/project/current`

Get the current project.

**Response:** `Project` object

---

## Path & VCS

### GET `/path`

Get the current path.

**Response:** `Path` object

### GET `/vcs`

Get VCS info for the current project.

**Response:** `VcsInfo` object

---

## Instance

### POST `/instance/dispose`

Dispose the current instance.

**Response:** `boolean`

---

## Config

### GET `/config`

Get config info.

**Response:** `Config` object

### PATCH `/config`

Update config.

**Request Body:** Partial `Config` object

**Response:** Updated `Config` object

### GET `/config/providers`

List providers and default models.

**Response:**
```json
{
  "providers": [...],
  "default": {
    "provider_id": "default_model_id"
  }
}
```

---

## Provider

### GET `/provider`

List all providers.

**Response:**
```json
{
  "all": [...],
  "default": {...},
  "connected": ["provider_id1", "provider_id2"]
}
```

### GET `/provider/auth`

Get provider authentication methods.

**Response:**
```json
{
  "provider_id": [...]
}
```

### POST `/provider/{id}/oauth/authorize`

Authorize a provider using OAuth.

**Response:** `ProviderAuthAuthorization` object

### POST `/provider/{id}/oauth/callback`

Handle OAuth callback for a provider.

**Response:** `boolean`

---

## Sessions

### GET `/session`

List all sessions.

**Response:** Array of `Session` objects

### POST `/session`

Create a new session.

**Request Body:**
```json
{
  "parentID": "optional_parent_id",
  "title": "optional_title",
  "permission": {
    "bash": true,
    "read": true,
    "write": true,
    "edit": true,
    "grep": true,
    "glob": true
  }
}
```

All fields are optional. If not provided, defaults will be used.

**Response:** `Session` object

### GET `/session/status`

Get session status for all sessions.

**Response:**
```json
{
  "session_id": {
    "status": "idle|running|error",
    ...
  }
}
```

### GET `/session/:id`

Get session details.

**Response:** `Session` object

### DELETE `/session/:id`

Delete a session and all its data.

**Response:** `boolean`

### PATCH `/session/:id`

Update session properties.

**Request Body:**
```json
{
  "title": "New Title"
}
```

**Response:** Updated `Session` object

### GET `/session/:id/children`

Get a session's child sessions.

**Response:** Array of `Session` objects

### GET `/session/:id/todo`

Get the todo list for a session.

**Response:** Array of `Todo` objects

### POST `/session/:id/init`

Analyze app and create `AGENTS.md`.

**Request Body:**
```json
{
  "messageID": "message_id",
  "providerID": "provider_id",
  "modelID": "model_id"
}
```

**Response:** `boolean`

### POST `/session/:id/fork`

Fork an existing session at a message.

**Request Body:**
```json
{
  "messageID": "optional_message_id"
}
```

**Response:** `Session` object

### POST `/session/:id/abort`

Abort a running session.

**Response:** `boolean`

### POST `/session/:id/share`

Share a session.

**Response:** Updated `Session` object

### DELETE `/session/:id/share`

Unshare a session.

**Response:** Updated `Session` object

### GET `/session/:id/diff`

Get the diff for this session.

**Query Parameters:**
- `messageID` (optional): Get diff up to this message

**Response:** Array of `FileDiff` objects

### POST `/session/:id/summarize`

Summarize the session.

**Request Body:**
```json
{
  "providerID": "provider_id",
  "modelID": "model_id"
}
```

**Response:** `boolean`

### POST `/session/:id/revert`

Revert a message.

**Request Body:**
```json
{
  "messageID": "message_id",
  "partID": "optional_part_id"
}
```

**Response:** `boolean`

### POST `/session/:id/unrevert`

Restore all reverted messages.

**Response:** `boolean`

### POST `/session/:id/permissions/:permissionID`

Respond to a permission request.

**Request Body:**
```json
{
  "response": "allow|deny",
  "remember": true
}
```

**Response:** `boolean`

---

## Messages

### GET `/session/:id/message`

List messages in a session.

**Query Parameters:**
- `limit` (optional): Maximum number of messages to return

**Response:** Array of message objects with structure:
```json
{
  "info": {
    "id": "message_id",
    "role": "user|assistant",
    ...
  },
  "parts": [...]
}
```

### POST `/session/:id/message`

Send a message and wait for response.

**Request Body:**
```json
{
  "messageID": "optional_id",
  "model": {
    "providerID": "provider_id",
    "modelID": "model_id"
  },
  "agent": "optional_agent",
  "noReply": false,
  "system": "optional_system_message",
  "format": "optional_format",
  "variant": "optional_variant",
  "parts": [
    {
      "type": "text",
      "text": "Message text content"
    }
  ]
}
```

**Part Types:**

The `parts` array accepts multiple part types:

1. **TextPartInput** - Text content:
   ```json
   {
     "id": "optional_part_id",
     "type": "text",
     "text": "Message text content",
     "synthetic": false,
     "ignored": false,
     "time": {
       "start": 1234567890,
       "end": 1234567900
     },
     "metadata": {}
   }
   ```
   Required: `type`, `text`  
   Optional: `id`, `synthetic`, `ignored`, `time`, `metadata`

2. **FilePartInput** - File attachment:
   ```json
   {
     "id": "optional_part_id",
     "type": "file",
     "mime": "text/plain",
     "filename": "example.txt",
     "url": "file:///path/to/file",
     "source": {
       "text": {
         "value": "file content",
         "start": 0,
         "end": 100
       },
       "type": "file",
       "path": "/path/to/file"
     }
   }
   ```
   Required: `type`, `mime`, `url`  
   Optional: `id`, `filename`, `source`

3. **AgentPartInput** - Agent reference:
   ```json
   {
     "id": "optional_part_id",
     "type": "agent",
     "name": "agent_name",
     "source": {
       "value": "source text",
       "start": 0,
       "end": 10
     }
   }
   ```
   Required: `type`, `name`  
   Optional: `id`, `source`

4. **SubtaskPartInput** - Subtask definition:
   ```json
   {
     "id": "optional_part_id",
     "type": "subtask",
     "prompt": "Task prompt text",
     "description": "Task description",
     "agent": "agent_name"
   }
   ```
   Required: `type`, `prompt`, `description`, `agent`  
   Optional: `id`

**Response:**
```json
{
  "info": {...},
  "parts": [...]
}
```

### GET `/session/:id/message/:messageID`

Get message details.

**Response:**
```json
{
  "info": {...},
  "parts": [...]
}
```

### POST `/session/:id/prompt_async`

Send a message asynchronously (no wait).

**Request Body:** Same as `/session/:id/message` (see above for complete schema)

**Response:** `204 No Content`

**Usage Notes:**
- This endpoint returns immediately (204) without waiting for the AI response
- The AI response will be delivered asynchronously via Server-Sent Events (SSE)
- Subscribe to the `/event` endpoint to receive the response
- Useful for avoiding connection timeouts on slow networks (VPN/Tailscale)
- The `noReply` field in the request body is typically set to `true` for this endpoint

### POST `/session/:id/command`

Execute a slash command.

**Request Body:**
```json
{
  "messageID": "optional_id",
  "agent": "optional_agent",
  "model": "optional_model",
  "command": "command_name",
  "arguments": "command arguments"
}
```

**Response:**
```json
{
  "info": {...},
  "parts": [...]
}
```

### POST `/session/:id/shell`

Run a shell command.

**Request Body:**
```json
{
  "agent": "agent_name",
  "model": "optional_model",
  "command": "shell command to execute"
}
```

**Response:**
```json
{
  "info": {...},
  "parts": [...]
}
```

---

## Commands

### GET `/command`

List all commands.

**Response:** Array of `Command` objects

---

## Files

### GET `/find`

Search for text in files.

**Query Parameters:**
- `pattern` (required): Search pattern (regex)

**Response:** Array of match objects:
```json
[
  {
    "path": "file/path.lua",
    "lines": "matched line content",
    "line_number": 42,
    "absolute_offset": 1234,
    "submatches": [...]
  }
]
```

### GET `/find/file`

Find files and directories by name.

**Query Parameters:**
- `query` (required): Search string (fuzzy match)
- `type` (optional): Limit results to `"file"` or `"directory"`
- `directory` (optional): Override the project root for the search
- `limit` (optional): Max results (1-200)
- `dirs` (optional): Legacy flag (`"false"` returns only files)

**Response:** Array of file paths (strings)

### GET `/find/symbol`

Find workspace symbols.

**Query Parameters:**
- `query` (required): Symbol search query

**Response:** Array of `Symbol` objects

### GET `/file`

List files and directories.

**Query Parameters:**
- `path` (required): Directory path to list

**Response:** Array of `FileNode` objects

### GET `/file/content`

Read a file.

**Query Parameters:**
- `path` (required): File path to read

**Response:** `FileContent` object

### GET `/file/status`

Get status for tracked files.

**Response:** Array of `File` objects with VCS status

---

## Tools (Experimental)

### GET `/experimental/tool/ids`

List all tool IDs.

**Response:** `ToolIDs` object

### GET `/experimental/tool`

List tools with JSON schemas for a model.

**Query Parameters:**
- `provider` (required): Provider ID
- `model` (required): Model ID

**Response:** `ToolList` object

---

## LSP, Formatters & MCP

### GET `/lsp`

Get LSP server status.

**Response:** Array of `LSPStatus` objects

### GET `/formatter`

Get formatter status.

**Response:** Array of `FormatterStatus` objects

### GET `/mcp`

Get MCP server status.

**Response:**
```json
{
  "server_name": {
    "status": "running|stopped|error",
    ...
  }
}
```

### POST `/mcp`

Add MCP server dynamically.

**Request Body:**
```json
{
  "name": "server_name",
  "config": {...}
}
```

**Response:** MCP status object

---

## Agents

### GET `/agent`

List all available agents.

**Response:** Array of `Agent` objects

---

## Logging

### POST `/log`

Write log entry.

**Request Body:**
```json
{
  "service": "service_name",
  "level": "info|warn|error",
  "message": "Log message",
  "extra": {}
}
```

**Response:** `boolean`

---

## TUI

### POST `/tui/append-prompt`

Append text to the prompt.

**Request Body:**
```json
{
  "text": "Text to append"
}
```

**Response:** `boolean`

### POST `/tui/open-help`

Open the help dialog.

**Response:** `boolean`

### POST `/tui/open-sessions`

Open the session selector.

**Response:** `boolean`

### POST `/tui/open-themes`

Open the theme selector.

**Response:** `boolean`

### POST `/tui/open-models`

Open the model selector.

**Response:** `boolean`

### POST `/tui/submit-prompt`

Submit the current prompt.

**Response:** `boolean`

### POST `/tui/clear-prompt`

Clear the prompt.

**Response:** `boolean`

### POST `/tui/execute-command`

Execute a command.

**Request Body:**
```json
{
  "command": "command_string"
}
```

**Response:** `boolean`

### POST `/tui/show-toast`

Show toast notification.

**Request Body:**
```json
{
  "title": "Optional title",
  "message": "Toast message",
  "variant": "info|success|warning|error"
}
```

**Response:** `boolean`

### GET `/tui/control/next`

Wait for the next control request.

**Response:** Control request object (long-polling)

### POST `/tui/control/response`

Respond to a control request.

**Request Body:**
```json
{
  "body": {...}
}
```

**Response:** `boolean`

---

## Auth

### PUT `/auth/:id`

Set authentication credentials.

**Request Body:** Must match provider schema (varies by provider)

**Response:** `boolean`

---

## Events

### GET `/event`

Server-sent events stream.

**Response:** Server-sent events stream. First event is `server.connected`, then bus events.

---

## Docs

### GET `/doc`

OpenAPI 3.1 specification.

**Response:** HTML page with interactive OpenAPI spec viewer

---

## Type References

For detailed TypeScript type definitions, see:
- **GitHub (public)**: https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts
- **Local source**: `/packages/sdk/js/src/gen/types.gen.ts` (auto-generated from OpenAPI spec)
- **Schema source**: `/packages/opencode/src/session/message-v2.ts` and `/packages/opencode/src/session/prompt.ts`

Common types used across endpoints:
- `Session` - Session information
- `Message` / `UserMessage` / `AssistantMessage` - Message objects
- `Part` / `TextPart` / `FilePart` / `AgentPart` / `SubtaskPart` - Message parts
- `TextPartInput` / `FilePartInput` / `AgentPartInput` / `SubtaskPartInput` - Input types for parts
- `Project` - Project information
- `Config` - Configuration
- `Provider` - AI provider information
- `Command` - Slash command
- `Agent` - Agent definition
- `File` / `FileNode` / `FileContent` - File operations
- `FileDiff` - File diff information
- `Symbol` - Code symbol (LSP)
- `Todo` - Session todo item

**Part Type Hierarchy:**

Input types (used in requests):
- `TextPartInput` - Simple text message
- `FilePartInput` - File attachment
- `AgentPartInput` - Agent reference
- `SubtaskPartInput` - Subtask definition

Output types (received in responses):
- `TextPart` - Text content with metadata
- `ReasoningPart` - AI reasoning text
- `FilePart` - File reference
- `ToolPart` - Tool invocation
- `StepStartPart` / `StepFinishPart` - Step boundaries
- `SnapshotPart` - State snapshot
- `PatchPart` - Code patch
- `AgentPart` - Agent switch
- `RetryPart` - Retry marker
- `CompactionPart` - Compaction marker
