# Conversation

Pure message history management.

All functions in this module are pure — no I/O operations. They operate on `AgentState` to manage the in-memory conversation history.

**Module:** `Conversation` (`src/Conversation.hs`)

## addMessage

Append a single message to the conversation history.

```haskell
addMessage :: Message -> AgentState -> AgentState
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `msg` | `Message` | The message to append |
| `state` | `AgentState` | Current agent state |
| **Returns** | `AgentState` | Updated state with the message appended to the end |

Appends to the end of the message list. All other fields of `AgentState` are preserved.

### Example

```haskell
let userMsg = userMessage (TextMessage "Hello")
let state' = addMessage userMsg state
-- messageCount state' == messageCount state + 1
```

## addMessages

Append multiple messages to the conversation history.

```haskell
addMessages :: [Message] -> AgentState -> AgentState
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `msgs` | `[Message]` | Messages to append, in order |
| `state` | `AgentState` | Current agent state |
| **Returns** | `AgentState` | Updated state with all messages appended |

Useful when adding a user message and assistant response together. Messages are appended in the order given.

Passing an empty list returns the state unchanged.

## getRecent

Get the most recent N messages from the conversation.

```haskell
getRecent :: Int -> AgentState -> [Message]
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `n` | `Int` | Number of recent messages to retrieve |
| `state` | `AgentState` | Current agent state |
| **Returns** | `[Message]` | Last N messages in chronological order (oldest first) |

**Edge cases:**
- If `n <= 0`, returns an empty list.
- If `n` exceeds the total message count, returns all messages.

## getAll

Get the entire conversation history.

```haskell
getAll :: AgentState -> [Message]
```

Returns the full conversation history in chronological order (oldest first). Equivalent to accessing `state.conversation` directly.

## getContextWindow

Get messages that fit within a context window for sending to the LLM.

```haskell
getContextWindow :: AgentState -> [Message]
```

Returns the messages to include in the next API request.

> **Phase 1 note:** Currently returns all messages (identical to `getAll`). Phase 2 will implement smart truncation based on token counts, so callers should use `getContextWindow` rather than `getAll` when building API requests. This ensures they automatically benefit from future truncation logic.

## messageCount

Count the number of messages in the conversation.

```haskell
messageCount :: AgentState -> Int
```

Returns `0` for a fresh conversation.

## isEmpty

Check if the conversation has no messages.

```haskell
isEmpty :: AgentState -> Bool
```

Returns `True` for a fresh conversation, `False` after any message has been added.
