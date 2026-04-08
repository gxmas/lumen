# Architecture

Lumen follows a classic functional architecture pattern: a **pure core** surrounded by an **IO shell**. This separation is the single most important design decision in the project, and everything else — testability, composability, error handling — flows from it.

## The Pure Core

Three modules contain no IO whatsoever:

- **[Types](../reference/types.md)** — All domain data types. No logic, just structure.
- **[Conversation](../reference/conversation.md)** — Message list operations: adding messages, retrieving recent messages, counting. Every function takes an `AgentState` and returns a value or an updated `AgentState`. No side effects.
- **[PromptAssembly](../reference/prompt-assembly.md)** — Builds a `MessageRequest` from the current state. Selects the context window, attaches the system prompt, sets model parameters. Pure transformation from state to request.

These modules are the heart of Lumen's logic. Because they are pure, they can be tested exhaustively with property-based testing — no mocking, no test fixtures, no cleanup. Pass in values, check outputs, repeat thousands of times.

## The IO Shell

Three modules handle the outside world:

- **[Storage](../reference/storage.md)** — Reads and writes JSON files to `~/.lumen/conversations/`. The only module that touches the filesystem.
- **[LLMClient](../reference/llm-client.md)** — Sends requests to the Anthropic API and maps errors to a simplified `LLMError` type. The only module that makes network calls.
- **[AgentCore](../reference/agent-core.md)** — The REPL orchestrator. Reads user input, coordinates calls to all other modules, displays output. The only module that interacts with the terminal.

Each IO module has a narrow responsibility: one talks to files, one talks to the network, one talks to the user. They depend on the pure core for logic, never the other way around.

## Module Dependencies

The dependency graph flows in one direction — from the orchestrator down to the types:

```
AgentCore
├── Conversation     (pure)
├── PromptAssembly   (pure)
├── Storage          (IO)
└── LLMClient        (IO)

PromptAssembly
└── Conversation     (pure)

Conversation
└── Types            (pure)

Storage
└── Types            (pure)

LLMClient
└── (anthropic libraries only)

Types
└── (anthropic libraries for re-exports)
```

`AgentCore` is the only module that depends on everything else. No other module depends on `AgentCore`. This means you can use `Conversation`, `Storage`, or `LLMClient` independently — they don't pull in the REPL.

## Data Flow Through a Turn

A single conversation turn flows through the modules in a predictable sequence:

1. **AgentCore** reads a line of text from the user
2. **AgentCore** wraps it as a `Message` and calls **Conversation.addMessage** to append it to state
3. **PromptAssembly.assembleRequest** transforms the state into a `MessageRequest` (pure)
4. **LLMClient.sendRequest** sends the request to the Anthropic API (IO)
5. **AgentCore** extracts text blocks from the response and prints them
6. **AgentCore** wraps the response as a `Message` and calls **Conversation.addMessage** again
7. **Storage.saveConversation** writes the updated conversation to disk (IO)

Steps 2–3 are pure transformations. Steps 4 and 7 are the only points where the system touches the outside world. This makes the flow easy to reason about: given the same state and the same API response, the same output is produced every time.

## Error Handling Philosophy

Lumen follows a **graceful degradation** strategy — it never crashes, always continues the conversation:

| Error Source | Behavior |
|--------------|----------|
| API error | Display message, discard the user's turn, continue REPL |
| Network error | Display message, discard the user's turn, continue REPL |
| Timeout | Display message, discard the user's turn, continue REPL |
| Parse error | Display message, discard the user's turn, continue REPL |
| File load error | Start a fresh conversation — no error shown to user |
| File save error | Retry is handled by the OS-level write |

On API failure, the user's message is **not** added to the conversation history. This prevents orphaned messages without responses, keeping the conversation state consistent.

## Why This Design

The pure/IO split is not accidental — it's motivated by three concrete benefits:

**Testability.** The pure core can be tested with Hedgehog property-based tests that run thousands of random inputs per property. No test databases, no mock servers, no network stubs. The 31 properties in the test suite cover the pure modules exhaustively because there's nothing to mock.

**Composability.** Each module does one thing. If Phase 2 adds tool execution, it slots in as a new module that `AgentCore` orchestrates — without changing `Conversation`, `Storage`, or `LLMClient`.

**Readability.** When reading `Conversation.hs`, you know it does not touch the filesystem, the network, or the terminal. Its type signatures prove it. This makes code review faster and bugs easier to locate — if a conversation is corrupted, you only need to look at `Storage` (the IO boundary) or `Conversation` (the logic), never both at once.
