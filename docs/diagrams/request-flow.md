# Request Flow

Sequence diagram showing a single conversation turn — from user input to displayed response.

```mermaid
sequenceDiagram
    participant User
    participant AC as Agent.Core
    participant Conv as Conversation.Core
    participant PA as LLM.PromptAssembly
    participant LLC as LLM.Client
    participant API as Anthropic API
    participant TR as Tools.Runtime
    participant Store as Foundation.Storage

    User->>AC: types message
    AC->>AC: wrap as userMessage(TextMessage input)
    AC->>Conv: addMessage(userMsg, state)
    Conv-->>AC: stateWithUser

    AC->>PA: assembleRequest(stateWithUser)
    PA->>Conv: getContextWindow(stateWithUser)
    Conv-->>PA: [messages]
    PA-->>AC: MessageRequest (with tool definitions)

    AC->>LLC: sendRequest(client, request)
    LLC->>API: POST /v1/messages
    API-->>LLC: MessageResponse
    LLC-->>AC: Right response

    alt response has tool_use blocks
        AC->>Conv: addMessage(assistantMsg with tool_use)
        loop for each ToolUseBlock
            AC->>TR: executeTool(safetyConfig, toolUseBlock)
            TR-->>AC: ToolResultBlock
        end
        AC->>Conv: addMessage(user message with tool results)
        Note over AC,API: Loop: re-assemble and re-send
    else response is text only
        AC->>AC: displayResponse (print text blocks)
        AC->>AC: wrap as assistantMessage(BlockMessage content)
        AC->>Conv: addMessage(assistantMsg, stateWithUser)
        Conv-->>AC: finalState (turnCount + 1)
    end

    AC->>Store: saveConversation(finalState)
    Store->>Store: write JSON to ~/.lumen/conversations/

    AC->>User: display > prompt
```

## Error Path

When the API returns an error, the flow is shorter:

```mermaid
sequenceDiagram
    participant User
    participant AC as Agent.Core
    participant Conv as Conversation.Core
    participant PA as LLM.PromptAssembly
    participant LLC as LLM.Client
    participant API as Anthropic API

    User->>AC: types message
    AC->>AC: wrap as userMessage
    AC->>Conv: addMessage(userMsg, state)
    Conv-->>AC: stateWithUser

    AC->>PA: assembleRequest(stateWithUser)
    PA-->>AC: MessageRequest

    AC->>LLC: sendRequest(client, request)
    LLC->>API: POST /v1/messages
    API-->>LLC: error
    LLC-->>AC: Left LLMError

    AC->>AC: displayError
    Note over AC: Returns state unchanged<br/>(processResponse returns stateWithUser)
    AC->>User: display > prompt
```

On API error, `processResponse` returns the state as passed in (which includes the user message). The turn is not retried, and the orphaned user message is persisted on the next save.
