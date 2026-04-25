# Architecture

Lumen follows a classic functional architecture pattern: a **pure core** surrounded by an **IO shell**. This separation is the single most important design decision in the project, and everything else — testability, composability, error handling — flows from it.

## The Pure Core

Five modules contain no IO whatsoever:

- **[Lumen.Foundation.Types](../reference/types.md)** — All domain data types. No logic, just structure.
- **[Lumen.Conversation.Core](../reference/conversation.md)** — Message list operations: adding messages, retrieving recent messages, counting. Every function takes an `AgentState` and returns a value or an updated `AgentState`. No side effects.
- **[Lumen.LLM.PromptAssembly](../reference/prompt-assembly.md)** — Builds a `MessageRequest` from the current state. Selects the context window, attaches the system prompt, injects tool definitions. Pure transformation from state to request.
- **[Lumen.Tools.Guardrails](../reference/guardrails.md)** — Safety validation logic. Classifies tool actions into typed `Action` values and validates them against `SafetyConfig`. Pure: takes a value, returns a value.
- **[Lumen.Tools.Catalog](../reference/tool-catalog.md)** — Tool registry. Enumerates all tools and their definitions. No logic — just a list and a lookup function.

These modules are the heart of Lumen's logic. Because they are pure, they can be tested exhaustively with property-based testing — no mocking, no test fixtures, no cleanup. Pass in values, check outputs, repeat thousands of times.

## The IO Shell

Four modules handle the outside world:

- **[Lumen.Foundation.Storage](../reference/storage.md)** — Reads and writes JSON files to `~/.lumen/conversations/`. The only module that touches the conversation filesystem.
- **[Lumen.LLM.Client](../reference/llm-client.md)** — Sends requests to the Anthropic API and maps errors to a simplified `LLMError` type. The only module that makes network calls.
- **[Lumen.Tools.Runtime](../reference/tool-runtime.md)** — Executes tool calls after validation. Runs filesystem operations and shell commands via `anthropic-tools-common` executors.
- **[Lumen.Agent.Core](../reference/agent-core.md)** — The REPL orchestrator. Reads user input, drives the tool execution loop, coordinates calls to all other modules, displays output. The only module that interacts with the terminal.

Each IO module has a narrow responsibility. They depend on the pure core for logic, never the other way around.

## Module Dependencies

The dependency graph flows in one direction — from the orchestrator down to the types:

```
Lumen.Agent.Core
├── Lumen.Conversation.Core    (pure)
├── Lumen.LLM.PromptAssembly   (pure)
├── Lumen.Foundation.Storage   (IO)
├── Lumen.LLM.Client           (IO)
└── Lumen.Tools.Runtime        (IO)
    ├── Lumen.Tools.Guardrails (pure)
    └── Lumen.Foundation.Types (pure)

Lumen.LLM.PromptAssembly
├── Lumen.Conversation.Core    (pure)
└── Lumen.Tools.Catalog        (pure)  ← temporary coupling; see note below

Lumen.Conversation.Core
└── Lumen.Foundation.Types     (pure)

Lumen.Foundation.Storage
└── Lumen.Foundation.Types     (pure)

Lumen.LLM.Client
└── (anthropic-client library only)

Lumen.Foundation.Types
└── (anthropic-types / anthropic-protocol for re-exports)
```

**Note on `PromptAssembly → Tools.Catalog`:** This coupling is a known temporary issue. `assembleRequest` currently imports `allTools` directly from `Tools.Catalog` to inject tool definitions. Phase 3 will refactor `assembleRequest` to accept a `PromptRequest` value object, removing the direct dependency and allowing `lumen-llm-core` to depend only on `lumen-runtime-foundation` and `lumen-conversation-system`.

`Lumen.Agent.Core` is the only module that depends on everything else. No other module depends on `Agent.Core`. This means you can use `Conversation.Core`, `Foundation.Storage`, or `LLM.Client` independently — they don't pull in the REPL.

## Data Flow Through a Turn

A single conversation turn flows through the modules in a predictable sequence:

1. **Agent.Core** reads a line of text from the user
2. **Agent.Core** wraps it as a `Message` and calls **Conversation.Core.addMessage** to append it to state
3. **LLM.PromptAssembly.assembleRequest** transforms the state into a `MessageRequest`, including tool definitions (pure)
4. **LLM.Client.sendRequest** sends the request to the Anthropic API (IO)
5. **If the response requests tool use:**
   - **Agent.Core** calls **Tools.Runtime.executeTool** for each `ToolUseBlock` (IO)
   - `Tools.Runtime` calls **Tools.Guardrails.validateAction** to check each action (pure)
   - Results are assembled into a user message and the loop repeats from step 3
6. **If the response is text only:** **Agent.Core** extracts text blocks and prints them
7. **Agent.Core** wraps the response as a `Message` and calls **Conversation.Core.addMessage** again
8. **Foundation.Storage.saveConversation** writes the updated conversation to disk (IO)

Steps 2–3 are pure transformations. Steps 4, 5, and 8 are the points where the system touches the outside world. This makes the flow easy to reason about: given the same state and the same API response, the same output is produced every time.

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

**Testability.** The pure core can be tested with Hedgehog property-based tests that run thousands of random inputs per property. No test databases, no mock servers, no network stubs. The 110 properties in the test suite cover the pure modules exhaustively because there's nothing to mock.

**Composability.** Each module does one thing. Tool execution (`Tools.Runtime`, `Tools.Guardrails`, `Tools.Catalog`) slot into the architecture without changing `Conversation.Core`, `Foundation.Storage`, or `LLM.Client`.

**Readability.** When reading `Lumen.Conversation.Core`, you know it does not touch the filesystem, the network, or the terminal. Its type signatures prove it. This makes code review faster and bugs easier to locate — if a conversation is corrupted, you only need to look at `Foundation.Storage` (the IO boundary) or `Conversation.Core` (the logic), never both at once.
