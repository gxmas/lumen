# ToolCatalog

Tool registry for the Lumen agent.

This module wraps the pre-built tool definitions from `anthropic-tools-common` and exposes them as a single list for injection into API requests. It is the only place in the codebase that enumerates which tools the agent offers.

**Module:** `Lumen.Tools.Catalog` (`lumen-tool-framework/src/Lumen/Tools/Catalog.hs`)  
**Package:** `lumen-tool-framework`

## allTools

All tool definitions wrapped as `ToolDefinition` values, ready for inclusion in an API request.

```haskell
allTools :: [ToolDefinition]
allTools = map CustomTool allToolDefs
```

Pass this list to `withTools` when assembling a `MessageRequest`. `PromptAssembly.assembleRequest` does this automatically — most callers never need to reference `allTools` directly.

**Current contents:** 5 tools — `read_file`, `write_file`, `list_directory`, `search_files`, `execute_command`.

## allToolDefs

All tool definitions as raw `CustomToolDef` values.

```haskell
allToolDefs :: [CustomToolDef]
```

Used internally for name-based lookup. Prefer `allTools` when building requests; use `allToolDefs` only when you need to inspect definition metadata (name, description, schema) without wrapping.

## lookupTool

Find a tool definition by name.

```haskell
lookupTool :: Text -> Maybe CustomToolDef
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `toolName` | `Text` | The tool name as sent by the LLM (e.g., `"read_file"`) |
| **Returns** | `Maybe CustomToolDef` | The definition, or `Nothing` if no tool with that name is registered |

**Note:** `ToolRuntime.executeTool` does not use `lookupTool` — it dispatches on tool name directly with a `case` expression. `lookupTool` is available for callers that need to inspect a definition before executing.

## Registered Tools

The 5 tools registered in `allToolDefs`, sourced from the `anthropic-tools-common` library:

### read_file

Read a file's contents from disk.

**Input schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Path to the file to read |

**Guardrails:** Path must pass `isSafePath` — no traversal, no system paths.

### write_file

Write content to a file on disk.

**Input schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Path to the file to write |
| `content` | string | yes | Content to write to the file |
| `create_dirs` | boolean | no | Create parent directories if they do not exist |

**Guardrails:** Path must pass `isSafePath`. `DeleteFile` actions (separate from write) are always denied.

### list_directory

List the entries in a directory.

**Input schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Path to the directory to list |
| `include_hidden` | boolean | no | Include hidden (dot-prefixed) entries |
| `pattern` | string | no | Glob filter to apply to results |

**Guardrails:** Path is validated as a `ReadFile` action (directory read), must pass `isSafePath`.

### search_files

Search for files matching a pattern under a root directory.

**Input schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Root directory to search under |
| `pattern` | string | yes | Pattern to search for (glob or text) |
| `recursive` | boolean | no | Search recursively into subdirectories |
| `max_results` | integer | no | Maximum number of results to return |

**Guardrails:** Root path is validated as a `ReadFile` action, must pass `isSafePath`.

### execute_command

Run a shell command and capture its output.

**Input schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `command` | string | yes | Shell command to execute |
| `working_directory` | string | no | Working directory for the command |
| `env` | object | no | Additional environment variables (`{"KEY": "VALUE"}`) |

**Guardrails:** `ExecuteCommand` actions are always allowed in MVP — no path or command filtering is applied.

## Adding a New Tool

To register an additional tool:

1. Add its `CustomToolDef` to the `allToolDefs` list in `src/ToolCatalog.hs`
2. Add a matching `Action` variant to `Guardrails` if path validation is needed
3. Add a `case` branch to `ToolRuntime.executeTool`
4. Write properties for the new action extraction helper

See [Adding a Tool](../guides/adding-a-tool.md) for a step-by-step walkthrough.
