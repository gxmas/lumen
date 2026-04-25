# Lumen Onboarding Guide

Welcome to the Lumen codebase. This guide gets you from "never seen this repo" to "ready to contribute" as fast as possible. It is written for Haskell-literate engineers who are new to the project.

---

## 1. What is Lumen

Lumen is an AI coding agent implemented in Haskell. It runs as a terminal REPL: you type a message, it calls the Anthropic API, displays the response, and persists the conversation to disk. The primary goal is **educational** — the project is a learning vehicle for implementing the full landscape of agentic patterns (memory, tool execution, planning, multi-agent coordination) through a real, working system.

The codebase uses a local ecosystem of Anthropic API libraries (`anthropic-types`, `anthropic-protocol`, `anthropic-client`) developed alongside the agent itself, rather than a published package.

---

## 2. Project Status

**The MVP is complete.** The agent can hold a multi-turn conversation with Claude, execute a set of filesystem and shell tools, persist conversation history to disk, and resume it on restart.

Implemented capabilities:
- Multi-turn text conversation via the Anthropic API
- Five tools: `read_file`, `write_file`, `list_directory`, `search_files`, `execute_command`
- Safety guardrails: path traversal detection, system path blocking, operator-configured block lists
- JSON persistence: conversations saved to `~/.lumen/conversations/<id>.json` and resumed on startup

For the full phase plan, see [The Roadmap](#10-the-roadmap) below and the design documents at `~/Projects/design/lumen/`.

---

## 3. Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| GHC | 9.10.3+ | The project uses GHC2021 |
| Cabal | 3.10+ | Multi-package project via `cabal.project` |
| Anthropic API key | — | Set as `ANTHROPIC_API_KEY` in environment |
| Local Anthropic libraries | — | See [Local Dependencies](#11-local-dependencies) |

The local libraries must be checked out at the paths listed in `cabal.project`:

```
../../libs/anthropic-types
../../libs/anthropic-protocol
../../libs/anthropic-client
../../libs/json-schema-combinators
```

Relative to the project root at `~/Perso/software/apps/lumen`, these resolve to `~/Perso/software/libs/`.

---

## 4. Quick Start

```bash
# Build everything
cabal build all

# Set your API key
export ANTHROPIC_API_KEY=sk-ant-...

# Run the agent (default conversation ID "default")
cabal run lumen

# Run with explicit options
cabal run lumen -- --model claude-sonnet-4-20250514 --conversation-id my-session

# Have a conversation
> Hello, what can you do?
# Claude responds...
> Explain the purpose of PromptAssembly.hs
# Claude responds...
> quit
Goodbye!

# Run the test suite
cabal test

# Resume the same conversation later
cabal run lumen -- --conversation-id my-session
```

Conversations persist to `~/.lumen/conversations/<conversation-id>.json`. Quit commands: `quit`, `exit`, `q`, `:q`.

---

## 5. Project Layout

Lumen is a **multi-package Cabal project**. Each concern lives in its own package with its own `.cabal` file.

```
lumen/
├── cabal.project              # Multi-package build; lists all 8 packages + local library paths
├── cabal.project.ci           # CI variant (different relative paths for local libs)
├── Makefile                   # Convenience targets: test, test-verbose, test-full, build, clean
├── hie.yaml                   # HLS config: cradle: cabal
│
├── lumen-runtime-foundation/  # LEAF: no internal deps
│   ├── lumen-runtime-foundation.cabal
│   ├── src/Lumen/Foundation/
│   │   ├── Types.hs           # All shared types: AgentConfig, AgentState, SafetyConfig,
│   │   │                      #   ConversationFile, ValidationResult; re-exports from anthropic-types
│   │   └── Storage.hs         # IO: save/load conversation JSON to ~/.lumen/conversations/
│   ├── test-support/Test/
│   │   └── Generators.hs      # Sub-library: lumen-test-generators (shared Hedgehog generators)
│   │                          #   Depend as: lumen-runtime-foundation:lumen-test-generators
│   └── test/                  # test-suite: lumen-runtime-foundation-test
│       └── Test/{Types,Storage}.hs
│
├── lumen-conversation-system/ # deps: lumen-runtime-foundation
│   ├── lumen-conversation-system.cabal
│   ├── src/Lumen/Conversation/
│   │   └── Core.hs            # Pure: addMessage, addMessages, getRecent, getContextWindow,
│   │                          #   getAll, messageCount, isEmpty
│   └── test/                  # test-suite: lumen-conversation-system-test
│       └── Test/Conversation.hs
│
├── lumen-tool-framework/      # deps: lumen-runtime-foundation, anthropic-tools-common
│   ├── lumen-tool-framework.cabal
│   ├── src/Lumen/Tools/
│   │   ├── Guardrails.hs      # Pure: Action ADT, validateAction, isSafePath, isSystemPath,
│   │   │                      #   hasPathTraversal, isBlockedPath
│   │   ├── Catalog.hs         # Pure: allTools, allToolDefs, lookupTool
│   │   └── Runtime.hs         # IO: executeTool, mkReadAction, mkWriteAction, …, mkErrorResult
│   └── test/                  # test-suite: lumen-tool-framework-test
│       └── Test/{Guardrails,GuardrailsHelpers,ToolCatalog,ToolRuntime,
│                SchemaInputs,OrderedMap,SchemaSerialization}.hs
│
├── lumen-llm-core/            # deps: lumen-runtime-foundation, lumen-conversation-system,
│   │                          #   lumen-tool-framework (*), anthropic-client
│   ├── lumen-llm-core.cabal
│   ├── src/Lumen/LLM/
│   │   ├── Client.hs          # IO: createClient, ClientHandle, sendRequest, LLMError
│   │   └── PromptAssembly.hs  # Pure: assembleRequest, defaultSystemPrompt
│   │                          # (*) NOTE: the lumen-tool-framework dep is a known temporary
│   │                          #   coupling; will be removed in Phase 3 when assembleRequest
│   │                          #   is refactored to accept a PromptRequest value object.
│   └── test/                  # test-suite: lumen-llm-core-test
│       └── Test/PromptAssembly.hs
│
├── lumen-agent-core/          # TOP-LEVEL: deps on all above packages
│   ├── lumen-agent-core.cabal
│   ├── src/Lumen/Agent/
│   │   └── Core.hs            # IO: initialize, mainLoop, runTurn, processResponse,
│   │                          #   isQuitCommand, hasToolUse, getToolUseBlocks
│   ├── app/
│   │   └── Main.hs            # CLI entry point: arg parsing, env var reading, mainLoop invocation
│   └── test/                  # test-suite: lumen-test (AgentCore tests only)
│       ├── Main.hs
│       └── Test/AgentCore.hs  # Properties: isQuitCommand
│
├── lumen-planning/            # STUB: Phase 7 — Lumen.Planning.Core (empty module)
├── lumen-code-intelligence/   # STUB: Phase 8 — Lumen.Code.Intelligence (empty module)
├── lumen-external-integrations/ # STUB: Phase 9 — Lumen.External.Hub (empty module)
│
└── docs/
    ├── index.md               # Documentation index
    ├── onboarding/            # Onboarding: guide.md, getting-started.md
    ├── guides/                # Task-oriented: configuration, testing, contributing, adding-a-tool, extending-modules
    ├── explanation/           # Conceptual: architecture, testing-strategy, persistence
    ├── reference/             # API reference for every module
    └── diagrams/              # Mermaid diagrams: architecture, request-flow, persistence-flow
```

---

## 6. Architecture at a Glance

Lumen separates pure domain logic from IO effects across multiple packages. Modules fall into two groups:

| Module | Package | IO? | Role |
|---|---|---|---|
| `Lumen.Foundation.Types` | `lumen-runtime-foundation` | Pure | Foundation — shared types used by all modules |
| `Lumen.Foundation.Storage` | `lumen-runtime-foundation` | IO (filesystem) | Persists conversation history to JSON files |
| `Lumen.Conversation.Core` | `lumen-conversation-system` | Pure | Message list operations |
| `Lumen.Tools.Guardrails` | `lumen-tool-framework` | Pure | Safety validation for tool actions |
| `Lumen.Tools.Catalog` | `lumen-tool-framework` | Pure | Tool registry: enumerates all available tools |
| `Lumen.Tools.Runtime` | `lumen-tool-framework` | IO (filesystem/shell) | Dispatches validated tool calls to executors |
| `Lumen.LLM.PromptAssembly` | `lumen-llm-core` | Pure | Builds the `MessageRequest` sent to the LLM |
| `Lumen.LLM.Client` | `lumen-llm-core` | IO (network) | Calls the Anthropic API |
| `Lumen.Agent.Core` | `lumen-agent-core` | IO (terminal + all) | REPL loop; orchestrates all other modules |

The package-level dependency graph flows from top to bottom:

```
lumen-agent-core
├── lumen-runtime-foundation
├── lumen-llm-core
│   ├── lumen-runtime-foundation
│   ├── lumen-conversation-system
│   └── lumen-tool-framework  (temporary; see note in Section 5)
├── lumen-conversation-system
│   └── lumen-runtime-foundation
└── lumen-tool-framework
    └── lumen-runtime-foundation
```

Key observations:
- `Lumen.Agent.Core` is the only module that imports everything else. Nothing imports it.
- `Lumen.Foundation.Types` has no internal imports — it only re-exports from `anthropic-types` and defines domain types.
- `Lumen.LLM.Client` has no internal imports — it depends only on `anthropic-client`.
- The pure chain is: `Agent.Core → LLM.PromptAssembly → Conversation.Core → Foundation.Types`.
- `Foundation.Storage` and `LLM.Client` are independent of each other.

See [docs/diagrams/architecture.md](../diagrams/architecture.md) for the full annotated diagram.

---

## 7. Module-by-Module Walkthrough

### `Lumen.Foundation.Types` — Shared Type Definitions
**File:** `lumen-runtime-foundation/src/Lumen/Foundation/Types.hs`  **Package:** `lumen-runtime-foundation`

The foundation module. Defines all data types used across the agent; no other module defines domain types. All imports flow outward from here.

**Key types exported:**
- `AgentConfig` — static configuration: API key, model, maxTokens, systemPrompt, safetyConfig, conversationId
- `AgentState` — mutable runtime state: config, conversation history (`[Message]`), turnCount
- `SafetyConfig` — allowedPaths, blockedPaths, allowSystemPaths (used by Guardrails)
- `ConversationFile` — the JSON persistence format: conversationId, createdAt, lastUpdatedAt, messages
- `ValidationResult` — `Allowed | Blocked Text` (used by Guardrails)
- Re-exports from `anthropic-types`: `Message`, `MessageContent`, `ContentBlock`, `Role`, `SystemPrompt`, `StopReason`

---

### `Lumen.Conversation.Core` — Pure Message History
**File:** `lumen-conversation-system/src/Lumen/Conversation/Core.hs`  **Package:** `lumen-conversation-system`

All pure functions. Manages the `[Message]` list stored in `AgentState`. No IO, no external calls.

**Key exports:**
```haskell
addMessage       :: Message -> AgentState -> AgentState
addMessages      :: [Message] -> AgentState -> AgentState
getRecent        :: Int -> AgentState -> [Message]
getContextWindow :: AgentState -> [Message]   -- currently returns all; truncation is future work
getAll           :: AgentState -> [Message]
messageCount     :: AgentState -> Int
isEmpty          :: AgentState -> Bool
```

**Connections:** Imported by `LLM.PromptAssembly` (to get the context window) and `Agent.Core` (to add each turn's messages).

**Future:** `getContextWindow` currently returns all messages. A later phase will add token-budget-based truncation. Callers should use `getContextWindow` rather than `getAll` when building API requests to benefit from future truncation automatically.

---

### `Lumen.Foundation.Storage` — JSON Persistence
**File:** `lumen-runtime-foundation/src/Lumen/Foundation/Storage.hs`  **Package:** `lumen-runtime-foundation`

IO module. Serializes `AgentState` to `~/.lumen/conversations/<id>.json` and deserializes it on startup. Uses `aeson`'s `encodeFile`/`eitherDecodeFileStrict`.

**Key exports:**
```haskell
saveConversation    :: AgentState -> IO ()
loadConversation    :: Text -> IO (Maybe ConversationFile)
conversationExists  :: Text -> IO Bool
conversationPath    :: Text -> IO FilePath      -- ~/.lumen/conversations/<id>.json
ensureConversationDir :: FilePath -> IO ()
```

**Connections:** Called by `Agent.Core` — once in `initialize` (to load), and once per turn in `mainLoop` (to save).

**Future:** Phase 3 (Persistence & Memory) upgrades Storage to a namespaced key-value interface.

---

### `Lumen.Tools.Guardrails` — Safety Validation
**File:** `lumen-tool-framework/src/Lumen/Tools/Guardrails.hs`  **Package:** `lumen-tool-framework`

Pure module. Defines the `Action` type that classifies what a tool wants to do, and the validation logic that decides whether each action is permitted. All validation is pure — no IO occurs here. `Tools.Runtime` calls into `Guardrails` before dispatching to any executor.

**Key exports:**
```haskell
data Action
  = ReadFile  !FilePath
  | WriteFile !FilePath !Text
  | DeleteFile !FilePath
  | ExecuteCommand !Text

validateAction :: Action -> SafetyConfig -> ValidationResult
isSafePath     :: FilePath -> SafetyConfig -> Bool
isSystemPath   :: FilePath -> Bool
hasPathTraversal :: FilePath -> Bool
isBlockedPath  :: FilePath -> SafetyConfig -> Bool
```

**Validation rules:** `ReadFile`/`WriteFile` — allowed only if path passes `isSafePath`. `DeleteFile` — always blocked. `ExecuteCommand` — always allowed in MVP.

---

### `Lumen.Tools.Catalog` — Tool Registry
**File:** `lumen-tool-framework/src/Lumen/Tools/Catalog.hs`  **Package:** `lumen-tool-framework`

Pure module. The single place in the codebase that enumerates which tools the agent offers. Wraps pre-built definitions from `anthropic-tools-common`.

**Key exports:**
```haskell
allTools    :: [ToolDefinition]   -- wrapped for API requests
allToolDefs :: [CustomToolDef]    -- raw, for name-based lookup
lookupTool  :: Text -> Maybe CustomToolDef
```

**Registered tools:** `read_file`, `write_file`, `list_directory`, `search_files`, `execute_command`

---

### `Lumen.Tools.Runtime` — Tool Execution
**File:** `lumen-tool-framework/src/Lumen/Tools/Runtime.hs`  **Package:** `lumen-tool-framework`

IO module. Dispatches each `ToolUseBlock` from the LLM through the parse → validate → execute pipeline. The only IO-performing layer in the tool system.

**Key exports:**
```haskell
executeTool   :: SafetyConfig -> ToolUseBlock -> IO ToolResultBlock
mkReadAction  :: ToolUseBlock -> Either Text Action
mkWriteAction :: ToolUseBlock -> Either Text Action
mkListDirAction :: ToolUseBlock -> Either Text Action
mkSearchAction  :: ToolUseBlock -> Either Text Action
mkCommandAction :: ToolUseBlock -> Either Text Action
mkErrorResult   :: ToolUseBlock -> Text -> ToolResultBlock
```

**Connections:** Called by `Agent.Core.processResponse` once per `ToolUseBlock` via `mapM`. Never throws — all errors produce a `ToolResultBlock` with `isError = Just True`.

---

### `Lumen.LLM.PromptAssembly` — Request Construction
**File:** `lumen-llm-core/src/Lumen/LLM/PromptAssembly.hs`  **Package:** `lumen-llm-core`

Pure module. Takes an `AgentState` and produces a `MessageRequest` ready to send to the API. Handles system prompt injection, context window selection, and tool injection.

**Key exports:**
```haskell
assembleRequest     :: AgentState -> MessageRequest
defaultSystemPrompt :: SystemPrompt
```

`assembleRequest` calls `getContextWindow` to get the message list, builds the request, injects either the configured system prompt or `defaultSystemPrompt`, and calls `withTools allTools` to attach the 5 tool definitions.

**Connections:** Imports `Conversation.Core.getContextWindow` and `Tools.Catalog.allTools`. Called by `Agent.Core.processResponse`.

---

### `Lumen.LLM.Client` — API Wrapper
**File:** `lumen-llm-core/src/Lumen/LLM/Client.hs`  **Package:** `lumen-llm-core`

IO module. Thin wrapper over `anthropic-client`. Hides the library's `ClientError` type behind Lumen's own `LLMError` ADT, keeping library details out of `Agent.Core`.

**Key exports:**
```haskell
createClient :: Text -> IO ClientHandle
sendRequest  :: ClientHandle -> MessageRequest -> IO (Either LLMError MessageResponse)

data LLMError
  = APIError !Text | NetworkError !Text | TimeoutError | ParseError !Text | UnknownError !Text
```

**Connections:** `Main.hs` calls `createClient`; `Agent.Core.processResponse` calls `sendRequest`. No internal module imports.

---

### `Lumen.Agent.Core` — REPL Orchestration
**File:** `lumen-agent-core/src/Lumen/Agent/Core.hs`  **Package:** `lumen-agent-core`

IO module. The top-level orchestrator. Coordinates all other modules to implement the agent loop, including the tool execution loop.

**Key exports:**
```haskell
initialize      :: AgentConfig -> IO AgentState
mainLoop        :: ClientHandle -> AgentState -> IO ()
runTurn         :: ClientHandle -> Text -> AgentState -> IO AgentState
isQuitCommand   :: Text -> Bool
hasToolUse      :: [ContentBlock] -> Bool
getToolUseBlocks :: [ContentBlock] -> [ToolUseBlock]
```

**Tool loop:** `runTurn` calls `processResponse` (internal), which sends the request, checks for `tool_use` blocks, executes them via `Tools.Runtime.executeTool`, adds tool results to the conversation, and loops until the LLM produces a text-only response.

**Connections:** Imports every other package. `Main.hs` calls `initialize` and `mainLoop`.

---

### `app/Main.hs` — CLI Entry Point
**File:** `lumen-agent-core/app/Main.hs`  **Package:** `lumen-agent-core` (executable)

Parses `--api-key`, `--model`, `--conversation-id` flags; falls back to `ANTHROPIC_API_KEY` environment variable; builds `AgentConfig`; calls `LLM.Client.createClient` and `Agent.Core.initialize`/`mainLoop`.

Default values:
- Model: `claude-sonnet-4-20250514`
- Max tokens: `4096`
- Conversation ID: `"default"`

Wraps `mainLoop` in a `catch` for fatal exceptions. Prints a welcome banner and available tools on startup.

---

## 8. Data Flow: Anatomy of a Turn

When you type a message and press Enter, here is what happens:

1. **`Agent.Core.mainLoop`** reads the line from stdin.
2. **`Agent.Core.isQuitCommand`** checks if you typed `quit`/`exit`/`q`/`:q`. If so, saves and exits.
3. **`Agent.Core.runTurn`** is called with the input text, which delegates to `processResponse` (internal).
4. The input is wrapped as a `userMessage (TextMessage input)` via `anthropic-protocol`.
5. **`Conversation.Core.addMessage`** appends the user message to `AgentState.conversation`.
6. **`LLM.PromptAssembly.assembleRequest`** is called:
   - Calls `Conversation.Core.getContextWindow` to get all messages.
   - Builds a `MessageRequest`, injects the system prompt, and injects tool definitions via `withTools allTools`.
7. **`LLM.Client.sendRequest`** sends the `MessageRequest` to `POST /v1/messages`.
8. **If the response contains `tool_use` blocks** (i.e., the LLM wants to call a tool):
   - The assistant message (with tool use blocks) is added to the conversation.
   - `Tools.Runtime.executeTool` is called for each `ToolUseBlock` — it validates via `Tools.Guardrails.validateAction` then runs the appropriate executor.
   - Tool results are assembled into a user message and added to the conversation.
   - The loop repeats from step 6 (sends updated conversation back to the LLM).
9. **If the response is text only:**
   - Text blocks are printed to stdout.
   - The assistant message is added to the conversation, `turnCount` is incremented.
10. **`Foundation.Storage.saveConversation`** writes the updated state to `~/.lumen/conversations/<id>.json`.
11. `mainLoop` recurses with the new state.

See the full sequence diagram at [docs/diagrams/request-flow.md](../diagrams/request-flow.md).

---

## 9. Key Design Decisions

**Pure core / IO shell.** Pure modules (`Types`, `Conversation`, `PromptAssembly`) contain no IO and can be tested with property-based tests that run thousands of iterations cheaply. IO modules (`Storage`, `LLMClient`, `AgentCore`) are thin — they delegate logic to pure helpers. This makes the domain testable without mocking.

**Hedgehog for testing.** The test suite uses property-based testing exclusively. Properties express invariants (e.g., "adding a message always increases length by 1"; "getRecent n returns at most n messages") that hold for any well-formed input, not just the cases the author thought of. Generators live in `lumen-agent-core/test/Test/Generators.hs` and are shared across all test modules.

**JSON persistence.** Conversations are stored as plain JSON files, one per conversation ID. The format (`ConversationFile`) includes `createdAt`/`lastUpdatedAt` timestamps and the full message list. This is intentionally simple — Phase 3 (Persistence & Memory) will upgrade to a namespaced key-value interface, but the JSON format keeps Phase 1 observable and debuggable.

**No streaming.** All API calls are blocking. The `anthropic-client` library supports streaming, but the MVP uses the blocking `createMessage` call. This simplifies the REPL loop considerably — no `async`, no `STM`, no backpressure handling. Phase 6 (Performance & Streaming) adds streaming.

**`AgentConfig` is immutable.** Configuration is read once at startup and threaded through `AgentState.config`. There is no mutable global config. Runtime state changes (new messages, turn count) live in `AgentState`; config never mutates.

---

## 10. The Roadmap

The project implements a full 19-module architecture incrementally. Each phase adds new modules or enhances existing ones.

| Phase | Name | Status | What it adds |
|---|---|---|---|
| MVP | Walking Skeleton + Tools | **Complete** | Text REPL, LLM.Client, Foundation.Storage, Conversation.Core, LLM.PromptAssembly, Agent.Core, Tools.Catalog, Tools.Guardrails, Tools.Runtime, tool dispatch loop |
| 3 | Persistence & Memory | Not started | Memory module, Session Management, upgraded Storage (namespaced key-value) |
| 4 | Robust Infrastructure | Not started | Telemetry, Error Recovery, Configuration Management, enhanced Guardrails |
| 5 | Code Intelligence | Not started | Lumen.Code.Intelligence (stub exists), Diff Management, Validation, code-aware tools |
| 6 | Performance & Streaming | Not started | Caching, Stream Processing, streaming LLM output |
| 7 | Planning Mode | Not started | Lumen.Planning.Core (stub exists), planning workflow in Agent.Core, planning prompt templates |
| 8 | External Integrations | Not started | Lumen.External.Hub (stub exists), LSP servers, Git integration, build systems |
| 9 | Multi-Agent | Not started | Multi-Agent module, sub-agent spawning, delegation, result aggregation |

The stub packages (`lumen-planning`, `lumen-code-intelligence`, `lumen-external-integrations`) are already listed in `cabal.project` and contain empty modules. This means you can add code to them without changing the project structure.

The recommended order is sequential (MVP → 3 → ... → 9), but phases 3+ can be reordered based on pain points (e.g., jump to Phase 6 if streaming matters more than memory).

Full details: `~/Projects/design/lumen/roadmap.md`

---

## 11. Local Dependencies

Lumen depends on a local ecosystem of Anthropic API libraries, not published to Hackage. These are developed in the same repository ecosystem and referenced via paths in `cabal.project`.

| Library | Path (relative to project root) | Purpose |
|---|---|---|
| `anthropic-types` | `../../libs/anthropic-types` | Core types: `Message`, `ContentBlock`, `Role`, `StopReason`, `ApiKey`, `ApiError` |
| `anthropic-protocol` | `../../libs/anthropic-protocol` | Request/response types: `MessageRequest`, `MessageResponse`, `messageRequest`, `userMessage`, `assistantMessage`; `ToolDefinition`, `withTools` |
| `anthropic-client` | `../../libs/anthropic-client` | Full client SDK: `AnthropicClient`, `newClient`, `defaultConfig`, `createMessage`; handles HTTP, retry logic, rate limits |
| `anthropic-tools-common` | `../../libs/anthropic-tools-common` | Pre-built tool definitions (`read_file`, `write_file`, etc.) with typed input records (`ReadFileInput`, etc.) and executors (`executeReadFile`, etc.) |
| `json-schema-combinators` | `../../libs/json-schema-combinators` | Schema combinators used by `anthropic-protocol` for tool `input_schema` definitions |

**Division of responsibility:**
- API boundary types (Message, request/response structs) come from `anthropic-types` and `anthropic-protocol`.
- The HTTP client, retries, and connection management come from `anthropic-client`.
- Tool schemas and executors come from `anthropic-tools-common` — Lumen's `Tools.Catalog` and `Tools.Runtime` are thin wrappers over this library.
- Lumen defines its own types (`AgentConfig`, `AgentState`, `ConversationFile`) for domain and persistence concerns.

**CI layout:** `cabal.project.ci` is used in CI and references the same libraries at `libs/` (relative to the CI workspace root) rather than `../../libs/`. Do not use `cabal.project.ci` for local development.

---

## 12. How to Contribute

Read the full guide at [docs/guides/contributing.md](../guides/contributing.md). The short version:

**Pure/IO convention:** Keep IO out of `Foundation.Types`, `Conversation.Core`, `LLM.PromptAssembly`, `Tools.Guardrails`, and `Tools.Catalog`. If your feature has both pure logic and IO, split them into separate modules. `Agent.Core` is the only module that should orchestrate IO across packages.

**Testing approach:** Write Hedgehog property tests, not example-based unit tests. Add generators for new types in `lumen-agent-core/test/Test/Generators.hs`. Properties should express invariants, not just "output equals expected value." Run with `cabal test` (100 iterations default) or `make test-full` (10,000 iterations).

**Adding a new module:**
1. Determine which package it belongs to, or whether a new package is needed.
2. Define shared types in `Lumen.Foundation.Types` (if needed across packages) or in the module itself.
3. Create the module file as a pure module if possible.
4. Add it to `exposed-modules` in the package's `.cabal` file.
5. Add generators to `lumen-agent-core/test/Test/Generators.hs`.
6. Create `lumen-agent-core/test/Test/MyModule.hs` with properties.
7. Add the test module to `other-modules` in `lumen-agent-core.cabal` and import it in `test/Main.hs`.

**PR checklist:**
1. `cabal build all` — no warnings
2. `cabal test` — all properties pass
3. New types have generators
4. New logic has properties
5. Exported functions have Haddock comments
6. Documentation updated if behaviour changes

---

## 13. Where to Find Things

| I want to... | Go to |
|---|---|
| Understand the full planned architecture | `~/Projects/design/lumen/design/architecture.md` |
| Understand the incremental development approach | `~/Projects/design/lumen/incremental-approach.md` |
| Read the phase roadmap | `~/Projects/design/lumen/roadmap.md` |
| Find where a type is defined | `lumen-runtime-foundation/src/Lumen/Foundation/Types.hs` |
| Find message list operations | `lumen-conversation-system/src/Lumen/Conversation/Core.hs` |
| Find the API request builder | `lumen-llm-core/src/Lumen/LLM/PromptAssembly.hs` |
| Find the persistence code | `lumen-runtime-foundation/src/Lumen/Foundation/Storage.hs` |
| Find the HTTP client wrapper | `lumen-llm-core/src/Lumen/LLM/Client.hs` |
| Find the REPL loop | `lumen-agent-core/src/Lumen/Agent/Core.hs` |
| Find the tool registry | `lumen-tool-framework/src/Lumen/Tools/Catalog.hs` |
| Find the safety validation | `lumen-tool-framework/src/Lumen/Tools/Guardrails.hs` |
| Find tool execution dispatch | `lumen-tool-framework/src/Lumen/Tools/Runtime.hs` |
| Find the CLI entry point | `lumen-agent-core/app/Main.hs` |
| Find all test modules | `lumen-agent-core/test/Test/` |
| Run the agent | `cabal run lumen` |
| Run tests | `cabal test` |
| Configure the agent | [docs/guides/configuration.md](../guides/configuration.md) |
| Understand the pure/IO split in depth | [docs/explanation/architecture.md](../explanation/architecture.md) |
| See the module dependency diagram | [docs/diagrams/architecture.md](../diagrams/architecture.md) |
| See the per-turn data flow diagram | [docs/diagrams/request-flow.md](../diagrams/request-flow.md) |
| Understand why Hedgehog | [docs/explanation/testing-strategy.md](../explanation/testing-strategy.md) |
| Understand the JSON storage format | [docs/explanation/persistence.md](../explanation/persistence.md) |
| Look up a specific function | [docs/reference/](../reference/) |

---

## 14. Further Reading

- **[Architecture explanation](../explanation/architecture.md)** — Deep dive on the pure core / IO shell pattern, module roles, and why the boundaries are drawn where they are.
- **[Testing strategy explanation](../explanation/testing-strategy.md)** — Why property-based testing, how Hedgehog works, test categories and priority levels.
- **[Persistence explanation](../explanation/persistence.md)** — The `ConversationFile` JSON format, startup/save/resume lifecycle, file layout.
- **[Module reference pages](../reference/)** — Signatures and descriptions for every exported function.
- **Design documents** — The full architecture, technical design, and construction plans live outside the repo at `~/Projects/design/lumen/`.
