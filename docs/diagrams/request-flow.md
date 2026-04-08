# Request Flow

Sequence diagram showing a single conversation turn — from user input to displayed response.

```mermaid
sequenceDiagram
    participant User
    participant AC as AgentCore
    participant Conv as Conversation
    participant PA as PromptAssembly
    participant LLC as LLMClient
    participant API as Anthropic API
    participant Store as Storage

    User->>AC: types message
    AC->>AC: wrap as userMessage(TextMessage input)
    AC->>Conv: addMessage(userMsg, state)
    Conv-->>AC: stateWithUser

    AC->>PA: assembleRequest(stateWithUser)
    PA->>Conv: getContextWindow(stateWithUser)
    Conv-->>PA: [messages]
    PA-->>AC: MessageRequest

    AC->>LLC: sendRequest(client, request)
    LLC->>API: POST /v1/messages
    API-->>LLC: MessageResponse
    LLC-->>AC: Right response

    AC->>AC: displayResponse (print text blocks)
    AC->>AC: wrap as assistantMessage(BlockMessage content)
    AC->>Conv: addMessage(assistantMsg, stateWithUser)
    Conv-->>AC: finalState (turnCount + 1)

    AC->>Store: saveConversation(finalState)
    Store->>Store: write JSON to ~/.lumen/conversations/

    AC->>User: display > prompt
```

## Error Path

When the API returns an error, the flow is shorter:

```mermaid
sequenceDiagram
    participant User
    participant AC as AgentCore
    participant Conv as Conversation
    participant PA as PromptAssembly
    participant LLC as LLMClient
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
    Note over AC: Returns ORIGINAL state<br/>(user message discarded)
    AC->>User: display > prompt
```

The user's message is **not** saved to the conversation on error. This prevents orphaned messages without responses.
