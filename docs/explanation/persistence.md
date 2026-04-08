# Persistence

Lumen persists conversations as JSON files so that sessions survive restarts. This page explains how the persistence system works, what gets stored, and the lifecycle of a conversation on disk.

## File Layout

All conversations are stored under a single directory:

```
~/.lumen/
└── conversations/
    ├── default.json
    ├── work.json
    └── project-x.json
```

Each conversation ID maps to one file: `{conversationId}.json`. The directory is created automatically on first save if it doesn't exist.

The path is derived from the `HOME` environment variable. If `HOME` is not set, the current directory is used as a fallback (this is primarily a safety net — in practice, `HOME` is always available).

## JSON Format

Each file is a `ConversationFile` serialized as JSON:

```json
{
  "conversationId": "default",
  "createdAt": "2026-04-07T12:00:00Z",
  "lastUpdatedAt": "2026-04-07T12:05:30Z",
  "messages": [
    {
      "role": "user",
      "content": {
        "type": "text",
        "text": "Hello!"
      }
    },
    {
      "role": "assistant",
      "content": {
        "type": "blocks",
        "blocks": [
          {
            "type": "text",
            "text": "Hello! How can I help you today?"
          }
        ]
      }
    }
  ]
}
```

**Key fields:**

- `conversationId` — matches the `--conversation-id` CLI flag (or `"default"`)
- `createdAt` — set once when the conversation is first saved, never changed after
- `lastUpdatedAt` — updated on every save
- `messages` — the full message history, alternating user and assistant messages

User messages use `"type": "text"` with a `text` field. Assistant messages use `"type": "blocks"` with an array of content blocks (Phase 1 only produces `TextContent` blocks).

## Conversation Lifecycle

### Creation

When Lumen starts with a conversation ID that has no matching file on disk:

1. `AgentCore.initialize` calls `Storage.loadConversation` → returns `Nothing`
2. A fresh `AgentState` is created with an empty conversation and `turnCount = 0`
3. The conversation file is created on disk after the first turn completes (via `saveConversation`)

### Updating

After every turn in the REPL:

1. `AgentCore.mainLoop` calls `Storage.saveConversation`
2. `saveConversation` reads the existing file to preserve the original `createdAt` timestamp
3. Sets `lastUpdatedAt` to the current time
4. Writes the full `ConversationFile` (overwriting the previous file)

The conversation is also saved when the user quits, ensuring the final state is persisted even if no new turns occurred.

### Resumption

When Lumen starts with a conversation ID that has an existing file:

1. `AgentCore.initialize` calls `Storage.loadConversation` → returns `Just convFile`
2. The messages are loaded into `AgentState.conversation`
3. `turnCount` is set to `length messages ÷ 2` (integer division, estimating user/assistant pairs)
4. The REPL continues from where it left off — the full history is included in the next API request

### Error Recovery

The persistence layer is designed for resilience:

| Scenario | Behavior |
|----------|----------|
| File doesn't exist | Start fresh — no error shown |
| File exists but can't be parsed | Start fresh — no error shown, old file will be overwritten on next save |
| Directory doesn't exist | Created automatically via `createDirectoryIfMissing` |
| `HOME` not set | Falls back to current directory |

This "silent fallback" approach means Lumen never fails to start due to a storage issue. The trade-off is that a corrupted file will be silently overwritten — there is no backup or recovery mechanism in Phase 1.

## Timestamp Management

The `createdAt` and `lastUpdatedAt` fields serve different purposes:

- **`createdAt`** is immutable after first write. On every subsequent save, the existing file is read to extract and preserve this value. If the read fails, `createdAt` is reset to the current time (treating it as a new conversation).
- **`lastUpdatedAt`** is always set to `getCurrentTime` at the moment of saving.

This means you can inspect a conversation file to see when a conversation started and when it was last active.

## Design Decisions

**Why JSON?** Simplicity. JSON is human-readable, debuggable with standard tools (`jq`, text editors), and Haskell's `aeson` library provides automatic serialization via `Generic` + `ToJSON`/`FromJSON` derivation. There's no need for a database in Phase 1.

**Why save the full history every time?** Simplicity again. Appending individual messages would be more efficient but requires handling partial writes, file corruption recovery, and format versioning. Overwriting the whole file is atomic enough for Phase 1's needs and keeps `Storage.hs` under 50 lines.

**Why no backups?** Phase 1 is a prototype. The conversation data is not critical — it's a chatbot history, not financial records. Adding backup rotation would complicate the storage module without meaningfully improving the user experience at this stage.
