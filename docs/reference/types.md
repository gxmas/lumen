# Types

Core data types shared across the Lumen agent.

This module consolidates all data types used across the agent: configuration, state, storage formats, and validation results. It also re-exports key types from the `anthropic-types` and `anthropic-protocol` libraries.

**Module:** `Lumen.Foundation.Types` (`lumen-runtime-foundation/src/Lumen/Foundation/Types.hs`)  
**Package:** `lumen-runtime-foundation`

## AgentConfig

Agent configuration loaded at startup.

```haskell
data AgentConfig = AgentConfig
  { apiKey         :: !Text
  , model          :: !Text
  , maxTokens      :: !Int
  , systemPrompt   :: !(Maybe SystemPrompt)
  , safetyConfig   :: !SafetyConfig
  , conversationId :: !Text
  }
```

| Field | Type | Description |
|-------|------|-------------|
| `apiKey` | `Text` | Anthropic API key for authenticating requests |
| `model` | `Text` | Model identifier (e.g., `"claude-sonnet-4-20250514"`) |
| `maxTokens` | `Int` | Maximum tokens to generate in a single response |
| `systemPrompt` | `Maybe SystemPrompt` | Optional system prompt to guide agent behavior. When `Nothing`, `PromptAssembly.defaultSystemPrompt` is used. |
| `safetyConfig` | `SafetyConfig` | Safety validation configuration |
| `conversationId` | `Text` | Unique identifier for this conversation session |

**Instances:** `Eq`, `Show`, `Generic`, `ToJSON`, `FromJSON`

**JSON fields:** Match Haskell field names exactly (e.g., `"apiKey"`, `"model"`).

## SafetyConfig

Safety configuration for tool execution guardrails.

```haskell
data SafetyConfig = SafetyConfig
  { allowedPaths     :: ![Text]
  , blockedPaths     :: ![Text]
  , allowSystemPaths :: !Bool
  }
```

| Field | Type | Description |
|-------|------|-------------|
| `allowedPaths` | `[Text]` | Whitelist of file paths the agent can access |
| `blockedPaths` | `[Text]` | Blacklist of file paths the agent must never access |
| `allowSystemPaths` | `Bool` | Whether to allow access to system directories (`/etc`, `/sys`, etc.) |

**Instances:** `Eq`, `Show`, `Generic`, `ToJSON`, `FromJSON`

## AgentState

Agent runtime state tracking the current conversation and mutable state during a session.

```haskell
data AgentState = AgentState
  { config       :: !AgentConfig
  , conversation :: ![Message]
  , turnCount    :: !Int
  }
```

| Field | Type | Description |
|-------|------|-------------|
| `config` | `AgentConfig` | Immutable configuration (set at startup) |
| `conversation` | `[Message]` | Full conversation history — all messages so far, in chronological order |
| `turnCount` | `Int` | Number of completed turns (incremented after each user/assistant pair) |

**Instances:** `Eq`, `Show`, `Generic`

**Note:** `AgentState` does not derive `ToJSON`/`FromJSON`. It is not serialized directly — conversation persistence uses `ConversationFile` instead.

## ConversationFile

Conversation file format for JSON persistence. This is what gets saved to disk and loaded on startup.

```haskell
data ConversationFile = ConversationFile
  { conversationId :: !Text
  , createdAt      :: !UTCTime
  , lastUpdatedAt  :: !UTCTime
  , messages       :: ![Message]
  }
```

| Field | Type | JSON Key | Description |
|-------|------|----------|-------------|
| `conversationId` | `Text` | `"conversationId"` | Unique identifier matching `AgentConfig.conversationId` |
| `createdAt` | `UTCTime` | `"createdAt"` | When this conversation was first created |
| `lastUpdatedAt` | `UTCTime` | `"lastUpdatedAt"` | When this conversation was last modified |
| `messages` | `[Message]` | `"messages"` | All messages in the conversation |

**Instances:** `Eq`, `Show`, `Generic`, `ToJSON`, `FromJSON`

### Example JSON

```json
{
  "conversationId": "default",
  "createdAt": "2026-04-07T12:00:00Z",
  "lastUpdatedAt": "2026-04-07T12:05:30Z",
  "messages": [
    {
      "role": "user",
      "content": { "type": "text", "text": "Hello!" }
    },
    {
      "role": "assistant",
      "content": {
        "type": "blocks",
        "blocks": [{ "type": "text", "text": "Hello! How can I help?" }]
      }
    }
  ]
}
```

## ValidationResult

Result of a validation check, used by guardrails to approve or reject an action.

```haskell
data ValidationResult
  = Allowed
  | Blocked !Text
```

| Constructor | Fields | Description |
|-------------|--------|-------------|
| `Allowed` | — | Action is permitted |
| `Blocked` | `Text` (reason) | Action is forbidden, with an explanation |

**Instances:** `Eq`, `Show`, `Generic`, `ToJSON`, `FromJSON`

## Re-exported Types

The following types are re-exported from the `anthropic-types` and `anthropic-protocol` libraries for convenience. Downstream modules import them from `Types` rather than the library packages directly.

### Message

```haskell
data Message = Message
  { role    :: !Role
  , content :: !MessageContent
  }
```

From `Anthropic.Protocol.Message`. Represents a single message in a conversation.

### MessageContent

```haskell
data MessageContent
  = TextMessage !Text
  | BlockMessage ![ContentBlock]
```

From `Anthropic.Types`. User messages typically use `TextMessage`; assistant responses use `BlockMessage` containing one or more `ContentBlock` values.

### ContentBlock

```haskell
data ContentBlock
  = TextContent !TextBlock
  | ...
```

From `Anthropic.Types`. MVP uses `TextContent` blocks (text responses) and `ToolUseContent` blocks (tool use requests from the LLM).

### Role

```haskell
data Role = User | Assistant
```

From `Anthropic.Types`. Identifies the sender of a message.

### SystemPrompt

```haskell
data SystemPrompt
  = SimpleSystem !Text
  | ...
```

From `Anthropic.Types`. Used to set the system prompt for API requests.

### StopReason

```haskell
data StopReason = EndTurn | MaxTokens | StopSequence | ...
```

From `Anthropic.Types`. Indicates why the model stopped generating.

### ToolUseBlock

```haskell
data ToolUseBlock = ToolUseBlock
  { id    :: !Text
  , name  :: !Text
  , input :: !Value  -- JSON object
  }
```

From `Anthropic.Types.Content.ToolUse`. Represents a single tool use request from the LLM. The `id` field links this request to its corresponding `ToolResultBlock`. The `input` field is the JSON object the LLM produced as arguments; `ToolRuntime` parses it into the appropriate typed input (e.g., `ReadFileInput`).

### ToolResultBlock

```haskell
data ToolResultBlock = ToolResultBlock
  { toolUseId    :: !Text
  , content      :: !(Maybe ToolResultContent)
  , isError      :: !(Maybe Bool)
  , cacheControl :: !(Maybe CacheControl)
  }
```

From `Anthropic.Types.Content.ToolResult`. Represents the result of executing a tool, sent back to the LLM as part of a user message. `toolUseId` must match the `id` of the originating `ToolUseBlock`. Set `isError = Just True` to signal a failed execution; Claude will incorporate the error into its next response.

### ToolResultContent

```haskell
data ToolResultContent
  = ToolResultText !Text
  | ToolResultBlocks ![ContentBlock]
```

From `Anthropic.Types.Content.ToolResult`. The payload of a tool result. MVP always uses `ToolResultText` — the executor output is a single text string. `ToolRuntime.mkErrorResult` also uses `ToolResultText` for error messages.

### ToolDefinition

```haskell
data ToolDefinition
  = CustomTool !CustomToolDef
  | ComputerUseTool !ComputerUseToolDef
  | ...
```

From `Anthropic.Protocol.Tool`. Wraps a tool definition for inclusion in a `MessageRequest`. `ToolCatalog.allTools` produces `[ToolDefinition]` by mapping `CustomTool` over `allToolDefs`. `PromptAssembly.assembleRequest` passes this list to `withTools`.
