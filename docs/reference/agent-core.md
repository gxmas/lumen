# AgentCore

REPL loop orchestration.

This module coordinates the main agent loop: initialize, then repeatedly run turns until the user quits. It ties together all other modules.

**Module:** `AgentCore` (`src/AgentCore.hs`)

## initialize

Initialize agent state from configuration.

```haskell
initialize :: AgentConfig -> IO AgentState
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `config` | `AgentConfig` | Agent configuration |
| **Returns** | `AgentState` | Initial state, either fresh or loaded from disk |

**Behavior:**

1. Calls `Storage.loadConversation` with the configured conversation ID
2. If no saved conversation exists:
   - Prints `"Starting new conversation: {id}"`
   - Returns a fresh `AgentState` with empty conversation and `turnCount = 0`
3. If a saved conversation is found:
   - Prints `"Resuming conversation: {id}"`
   - Prints `"Loaded N messages"`
   - Returns an `AgentState` with the loaded messages and `turnCount = length messages ÷ 2`

## mainLoop

Main REPL loop — runs until the user quits.

```haskell
mainLoop :: ClientHandle -> AgentState -> IO ()
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `client` | `ClientHandle` | LLM client handle |
| `state` | `AgentState` | Current agent state |

**Loop behavior (each iteration):**

1. Displays the `> ` prompt and flushes stdout
2. Reads a line of user input
3. If input is a quit command (`isQuitCommand`):
   - Prints `"Goodbye!"`
   - Saves the conversation via `Storage.saveConversation`
   - Returns (loop ends)
4. Otherwise:
   - Calls `runTurn` to process the input
   - Saves the conversation via `Storage.saveConversation`
   - Recurses with the updated state

**Note:** The conversation is saved after every turn and on quit, ensuring no data is lost.

## runTurn

Run a single turn of conversation.

```haskell
runTurn :: ClientHandle -> Text -> AgentState -> IO AgentState
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `client` | `ClientHandle` | LLM client handle |
| `userInput` | `Text` | The user's message text |
| `state` | `AgentState` | Current agent state |
| **Returns** | `AgentState` | Updated state after the full turn (including any tool loops) |

**Behavior:**

1. Wraps user input as a `Message` using `userMessage (TextMessage userInput)`
2. Adds the user message to conversation via `Conversation.addMessage`
3. Delegates to `processResponse` to send the request and handle the response

`runTurn` itself is a thin entry point. The tool execution loop lives in `processResponse`.

**Error handling:** On API error, `processResponse` displays the error and returns the state as it was passed in — which for the initial call from `runTurn` is `stateWithUser` (the user message IS included). The failed user message is persisted by `mainLoop`, and the next iteration receives this state with the orphaned user message in history.

## processResponse (internal)

Send the current conversation to the LLM and process the response, looping if the model requests tool use.

```haskell
processResponse :: ClientHandle -> AgentState -> IO AgentState
```

This function is not exported but drives the tool execution loop:

1. Assembles the request via `PromptAssembly.assembleRequest` and sends it
2. On **API error**: displays the error, returns the state unchanged
3. On **success with tool use** (`hasToolUse response.content = True`):
   - Adds the assistant message (containing `tool_use` blocks) to the conversation
   - Displays `[tool] {name}` for each tool the model requested
   - Calls `ToolRuntime.executeTool` for each tool use block (validated against `SafetyConfig`)
   - Displays `[result] …` or `[error] …` preview for each result
   - Adds tool results as a user message with `BlockMessage` content
   - **Loops** — calls `processResponse` again with the updated state
4. On **success with text only**:
   - Displays the text response
   - Adds the assistant message to the conversation
   - Increments `turnCount`
   - Returns the updated state

The loop continues until the model produces a response with no `tool_use` blocks. In practice this is bounded by the model's reasoning — there is no hard loop limit in MVP.

## hasToolUse

Check whether a list of content blocks contains any tool use requests.

```haskell
hasToolUse :: [ContentBlock] -> Bool
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `blocks` | `[ContentBlock]` | Content blocks from an LLM response |
| **Returns** | `Bool` | `True` if any block is a `ToolUseContent` |

Used by `processResponse` to decide whether to enter the tool execution branch or the text display branch.

## getToolUseBlocks

Extract `ToolUseBlock` values from a list of content blocks.

```haskell
getToolUseBlocks :: [ContentBlock] -> [ToolUseBlock]
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `blocks` | `[ContentBlock]` | Content blocks from an LLM response |
| **Returns** | `[ToolUseBlock]` | All `ToolUseContent` blocks, in order |

Returns an empty list if no tool use blocks are present. `processResponse` passes this list to `mapM (executeTool safetyConfig)` to execute all requested tools before looping.

## isQuitCommand

Check if user input is a quit command.

```haskell
isQuitCommand :: Text -> Bool
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | `Text` | Raw user input |
| **Returns** | `Bool` | `True` if the input is a recognized quit command |

**Recognized commands:** `quit`, `exit`, `q`, `:q`

Input is stripped of leading/trailing whitespace and lowercased before comparison, so `"  QUIT  "` and `":Q"` are both recognized.
