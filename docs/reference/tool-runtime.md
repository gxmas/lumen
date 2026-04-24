# ToolRuntime

Tool execution with safety validation.

This module wires `Guardrails` validation to the `anthropic-tools-common` executors. It is the only IO-performing layer in the tool system — `Guardrails` and `ToolCatalog` are pure. Every tool use goes through `executeTool`, which parses the input, validates the action, and either executes it or returns an error result.

**Module:** `Lumen.Tools.Runtime` (`lumen-tool-framework/src/Lumen/Tools/Runtime.hs`)  
**Package:** `lumen-tool-framework`

## executeTool

Execute a tool use request with safety validation.

```haskell
executeTool :: SafetyConfig -> ToolUseBlock -> IO ToolResultBlock
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `safetyConfig` | `SafetyConfig` | Safety settings from `AgentConfig.safetyConfig` |
| `tub` | `ToolUseBlock` | The tool use request from the LLM response |
| **Returns** | `ToolResultBlock` | Success or error result, always returned (never throws) |

**Execution flow:**

```
ToolUseBlock
    │
    ▼ (1) dispatch on tub.name
    │
    ├── "read_file"      → mkReadAction
    ├── "write_file"     → mkWriteAction
    ├── "list_directory" → mkListDirAction
    ├── "search_files"   → mkSearchAction
    ├── "execute_command"→ mkCommandAction
    └── unknown          → mkErrorResult "Unknown tool: {name}"
                               │
                               ▼ (2) parse typed input from JSON
                               │
                        Left parseErr → mkErrorResult "Failed to parse input: …"
                        Right action  │
                               │      ▼ (3) validate via Guardrails
                               │
                        Blocked msg → mkErrorResult msg  (is_error = true)
                        Allowed     │
                               │    ▼ (4) execute via anthropic-tools-common
                               │
                        Right result → ToolResultBlock  (success)
                        Left ToolParseError → mkErrorResult "Parse error: …"
                        Left ToolIOError    → mkErrorResult "IO error: …"
```

**Error handling:** All errors — unknown tool name, parse failure, guardrail block, IO error — produce a `ToolResultBlock` with `isError = Just True`. The function never throws an exception. The LLM receives the error as a tool result and can decide how to proceed.

**Called by:** `AgentCore.processResponse`, once per `ToolUseBlock` in the response, via `mapM (executeTool state.config.safetyConfig) toolBlocks`.

## Action Extraction Helpers

These functions parse a `ToolUseBlock`'s JSON input into a typed `Action` for validation. They are exported for testing but called internally by `withValidation`.

### mkReadAction

```haskell
mkReadAction :: ToolUseBlock -> Either Text Action
```

Parses `ReadFileInput` from the block's input JSON and produces `ReadFile path`.

### mkWriteAction

```haskell
mkWriteAction :: ToolUseBlock -> Either Text Action
```

Parses `WriteFileInput` and produces `WriteFile path content`.

### mkListDirAction

```haskell
mkListDirAction :: ToolUseBlock -> Either Text Action
```

Parses `ListDirectoryInput` and produces `ReadFile path` — a directory listing is treated as a read for validation purposes.

### mkSearchAction

```haskell
mkSearchAction :: ToolUseBlock -> Either Text Action
```

Parses `SearchFilesInput` and produces `ReadFile path` — the root path of the search is validated as a read.

### mkCommandAction

```haskell
mkCommandAction :: ToolUseBlock -> Either Text Action
```

Parses `ExecuteCommandInput` and produces `ExecuteCommand command`.

**Common return type:**

```haskell
Either Text Action
-- Left  Text   -- parse error message
-- Right Action -- validated action ready for Guardrails
```

## mkErrorResult

Build an error `ToolResultBlock`.

```haskell
mkErrorResult :: ToolUseBlock -> Text -> ToolResultBlock
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `tub` | `ToolUseBlock` | The original tool use block (provides the `id`) |
| `msg` | `Text` | Error message to include in the result |
| **Returns** | `ToolResultBlock` | Error result with `isError = Just True` |

**Output:**

```haskell
ToolResultBlock
  { toolUseId    = tub.id         -- matches the original tool use ID
  , content      = Just (ToolResultText msg)
  , isError      = Just True
  , cacheControl = Nothing
  }
```

The LLM uses `toolUseId` to correlate results with requests. Setting `isError = True` signals to Claude that the tool failed, allowing it to explain the error or try a different approach.

## Usage Example

`AgentCore.processResponse` calls `executeTool` after detecting tool use blocks:

```haskell
-- Execute each tool and collect results
let toolBlocks = getToolUseBlocks response.content
results <- mapM (executeTool state.config.safetyConfig) toolBlocks

-- Send results back as a user message
let resultBlocks = map ToolResultContent results
let resultMsg = userMessage (BlockMessage resultBlocks)
let stateWithResults = addMessage resultMsg stateWithAssistant

-- Loop: send results back to LLM for next response
processResponse client stateWithResults
```

## Dependency Map

```
ToolRuntime
    ├── Guardrails          (pure — validateAction)
    ├── Types               (SafetyConfig, ValidationResult)
    └── anthropic-tools-common
            ├── Parser      (parseToolInput)
            ├── Schema      (ReadFileInput, WriteFileInput, …)
            └── Executor    (executeReadFile, executeWriteFile, …)
```
