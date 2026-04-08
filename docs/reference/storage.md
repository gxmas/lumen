# Storage

JSON persistence for conversation history.

This module handles saving and loading conversations to and from disk as JSON files. Each conversation is stored in its own file under `~/.lumen/conversations/`.

**Module:** `Storage` (`src/Storage.hs`)

## saveConversation

Save the current conversation to a JSON file.

```haskell
saveConversation :: AgentState -> IO ()
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `state` | `AgentState` | Agent state containing the conversation to save |

**Behavior:**

1. Derives the file path from `state.config.conversationId`
2. Creates the conversation directory if it doesn't exist
3. Gets the current timestamp for `lastUpdatedAt`
4. If the file already exists, reads the existing `createdAt` timestamp and preserves it
5. If the file is new (or unreadable), sets `createdAt` to the current time
6. Writes the `ConversationFile` as JSON

**File location:** `~/.lumen/conversations/{conversationId}.json`

**Called by:** `AgentCore.mainLoop` after every turn and on quit.

## loadConversation

Load a conversation from a JSON file.

```haskell
loadConversation :: Text -> IO (Maybe ConversationFile)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `convId` | `Text` | Conversation ID to load |
| **Returns** | `Maybe ConversationFile` | `Just convFile` on success, `Nothing` if the file doesn't exist or can't be parsed |

**Error handling:** Returns `Nothing` silently on parse failure. Does not throw exceptions.

## conversationExists

Check if a conversation file exists on disk.

```haskell
conversationExists :: Text -> IO Bool
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `convId` | `Text` | Conversation ID to check |
| **Returns** | `Bool` | `True` if the file exists |

## conversationPath

Get the file path for a conversation ID.

```haskell
conversationPath :: Text -> IO FilePath
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `convId` | `Text` | Conversation ID |
| **Returns** | `FilePath` | Absolute path: `~/.lumen/conversations/{convId}.json` |

Uses the `HOME` environment variable. Falls back to `"."` if `HOME` is not set.

## ensureConversationDir

Ensure the parent directory for a conversation file exists.

```haskell
ensureConversationDir :: FilePath -> IO ()
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `FilePath` | Path to the conversation file (the parent directory is created) |

Creates `~/.lumen/conversations/` (and any intermediate directories) if they don't already exist. Uses `createDirectoryIfMissing True`.
