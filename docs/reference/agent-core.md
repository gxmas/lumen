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
| **Returns** | `AgentState` | Updated state after the turn |

**Behavior:**

1. Wraps user input as a `Message` using `userMessage (TextMessage userInput)`
2. Adds the user message to conversation via `Conversation.addMessage`
3. Assembles the API request via `PromptAssembly.assembleRequest`
4. Sends the request via `LLMClient.sendRequest`
5. On **error**: displays the error message and returns the **original** state (user message is discarded)
6. On **success**:
   - Wraps the response as `assistantMessage (BlockMessage response.content)`
   - Displays text blocks from the response
   - Adds the assistant message to the conversation
   - Increments `turnCount`
   - Returns the updated state

**Error handling:** On API error, the user's message is not persisted — the conversation rolls back to its state before the turn. This prevents orphaned user messages without responses.

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
