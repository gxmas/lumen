# Lumen Agent - Current Capabilities

**Project Code Name:** Dawn  
**Current Phase:** MVP (conversation with tool execution)  
**Last Updated:** 2026-04-24

## Overview

Lumen is a conversational AI agent built in Haskell with Claude API integration. The MVP adds a full tool execution layer to the Phase 1 conversation foundation: the agent can now read files, write files, list directories, search files, and run shell commands — all validated through a safety guardrails layer before execution.

## ✅ Core Features

### 1. Interactive Conversation
- Start a REPL and chat with Claude
- Send text messages and receive text responses
- Clean, line-by-line text display
- Maintains conversation context across turns

### 2. Tool Execution

The agent exposes 5 tools to the LLM and executes them automatically as part of the conversation loop:

| Tool | Description |
|------|-------------|
| `read_file` | Read a file's contents from disk |
| `write_file` | Write content to a file on disk |
| `list_directory` | List entries in a directory |
| `search_files` | Search for files matching a pattern under a root path |
| `execute_command` | Run a shell command and capture output |

**How it works:** When Claude decides to use a tool, `AgentCore` detects the `tool_use` blocks in the response, validates each action via `Guardrails`, executes it via `ToolRuntime`, sends the results back to Claude, and loops until Claude returns a text-only response.

### 3. Safety Guardrails

All file and directory actions are validated before execution:

| Guardrail | Behaviour |
|-----------|-----------|
| Path traversal blocking | Any path containing `..` is denied |
| System path blocking | Paths under `/etc`, `/bin`, `/usr`, `/var`, `/sys`, `/boot`, `/sbin`, `/lib`, `/proc`, `/dev` are denied (unless `allowSystemPaths` is set) |
| Blocked path list | Operator-configured list of paths that are always denied |
| File deletion denial | `DeleteFile` actions are always denied regardless of configuration |
| Shell commands | `execute_command` is always allowed (guardrail defers to the LLM) |

### 4. Conversation Persistence
- Automatically saves conversations to `~/.lumen/conversations/{id}.json`
- Resumes previous conversations on restart
- Tracks conversation metadata:
  - `conversationId`: Unique identifier
  - `createdAt`: When conversation was first created
  - `lastUpdatedAt`: When last modified
  - `messages`: Full conversation history (including tool use and tool result turns)

### 5. Configuration Options

```bash
# API Key (required)
lumen --api-key YOUR_KEY              # Override API key
# Or set environment variable
export ANTHROPIC_API_KEY="your-key"

# Model Selection
lumen --model claude-opus-4           # Use Opus 4
lumen --model claude-haiku-3          # Use Haiku 3
# Default: claude-sonnet-4-20250514

# Conversation Management
lumen --conversation-id work-chat     # Use named conversation
lumen --conversation-id project-x     # Different conversation context
# Default: "default"

# Help
lumen --help                          # Show usage
```

### 6. Default Configuration

| Setting | Default Value |
|---------|---------------|
| Model | `claude-sonnet-4-20250514` |
| Max Tokens | 4096 |
| Conversation ID | `default` |
| System Prompt | Injected by `PromptAssembly` with tool descriptions |
| Storage Location | `~/.lumen/conversations/` |
| Allow System Paths | `False` |
| Blocked Paths | `[]` (empty — deny list is opt-in) |

### 7. REPL Commands

| Command | Action |
|---------|--------|
| `quit` | Exit the REPL |
| `exit` | Exit the REPL |
| `q` | Exit the REPL |
| `:q` | Exit the REPL (vim-style) |

All commands are case-insensitive and whitespace-tolerant.

## 🏗️ Architecture

### Module Map

9 source modules across two layers:

```
┌─────────────────────────────────────────────────────────┐
│                   AgentCore (REPL)                      │
│  initialize, mainLoop, runTurn, processResponse         │
│  hasToolUse, getToolUseBlocks                           │
└──────────────┬──────────────────────────────────────────┘
               │
       ┌───────┴──────────┐
       │                  │
┌──────▼──────┐    ┌──────▼──────────┐
│  LLMClient  │    │  Conversation   │
│  (API I/O)  │    │  (Pure Fns)     │
└─────────────┘    └──────────────────┘
       │                  │
┌──────▼──────┐    ┌──────▼──────────┐
│   Storage   │    │ PromptAssembly  │
│  (File I/O) │    │  (Pure Fns)     │
└─────────────┘    └──────────────────┘
                          │
               ┌──────────┴──────────────┐
               │                         │
       ┌───────▼───────┐       ┌─────────▼───────┐
       │  ToolCatalog  │       │   ToolRuntime    │
       │  (Registry)   │       │  (Executor)      │
       └───────────────┘       └─────────┬────────┘
                                         │
                               ┌─────────▼────────┐
                               │    Guardrails     │
                               │  (Validation)     │
                               └──────────────────┘
                                         │
                               ┌─────────▼────────┐
                               │      Types        │
                               │    (Domain)       │
                               └──────────────────┘
```

### Pure Functional Core

**Conversation Management** (`src/Conversation.hs`)
- `addMessage`, `addMessages`: Append messages
- `getRecent`: Get last N messages
- `getAll`, `messageCount`, `isEmpty`
- All operations tested with property-based tests

**Request Assembly** (`src/PromptAssembly.hs`)
- `assembleRequest`: Builds `MessageRequest` from agent state
- Injects tool definitions from `ToolCatalog` via `withTools`
- Tested to ensure correct field population

**Tool Registry** (`src/ToolCatalog.hs`)
- `allTools`: All 5 tool definitions wrapped for API requests
- `allToolDefs`: Raw definitions for lookup
- `lookupTool`: Find a definition by name

**Safety Validation** (`src/Guardrails.hs`)
- `Action` ADT: `ReadFile`, `WriteFile`, `DeleteFile`, `ExecuteCommand`
- `validateAction`: Pure validation against `SafetyConfig`
- `isSafePath`, `hasPathTraversal`, `isSystemPath`, `isBlockedPath`
- All validation logic is pure and fully testable

### Tool Execution Pipeline

`ToolRuntime` wires validation to execution in a single function:

```
ToolUseBlock
    │
    ▼
mkXxxAction          -- parse typed input from JSON
    │
    ▼
validateAction       -- Guardrails check (pure)
    │
    ├── Blocked ──▶  mkErrorResult  ──▶  ToolResultBlock (is_error=true)
    │
    └── Allowed ──▶  executeXxx     ──▶  ToolResultBlock (success or IO error)
```

### Robust Error Handling

| Error Type | Behaviour |
|------------|-----------|
| API Error | Display error message, continue REPL |
| Network Error | Display error message, continue REPL |
| Timeout Error | Display error message, continue REPL |
| Parse Error | Display error message, continue REPL |
| File I/O Error | Silent fallback (load) or retry (save) |
| Tool parse error | Error result returned to LLM, conversation continues |
| Tool IO error | Error result returned to LLM, conversation continues |
| Guardrail block | Error result returned to LLM, conversation continues |

**Philosophy:** Graceful degradation — never crash, always continue conversation.

### Test Coverage

**110 property-based tests** across 12 test modules:

| Module | Category | Properties | What's Tested |
|--------|----------|------------|---------------|
| **Types** | CRITICAL | 5 | JSON serialization round-trips |
| **Conversation** | CRITICAL | 12 | Message list operations |
| **PromptAssembly** | STANDARD | 6 | Request assembly validation |
| **AgentCore** | MINIMAL | 8 | Command recognition, tool detection |
| **Storage** | MINIMAL | 4 | Path safety checks |
| **ToolCatalog** | STANDARD | 5 | Tool registry lookup and completeness |
| **Guardrails** | CRITICAL | 10 | Path validation, action rules |
| **GuardrailsHelpers** | CRITICAL | 9 | Path traversal and system path detection |
| **ToolRuntime** | CRITICAL | 9 | Action extraction, error result construction |
| **OrderedMap** | STANDARD | 16 | Ordered map invariants (underlying library) |
| **SchemaInputs** | STANDARD | 7 | Tool input schema parsing |
| **SchemaSerialization** | STANDARD | 19 | Tool schema JSON round-trips |

**Test strategies:**
- Round-trip properties (serialization preserves data)
- Invariants (structural constraints always hold)
- Postconditions (outputs meet specifications)
- Idempotence (repeated operations produce same result)
- Composition (complex ops equal simpler compositions)

**Default:** 100 iterations per property  
**CI (main branch):** 10,000 iterations per property

## 🚫 MVP Limitations

### What Lumen **Cannot** Do (Yet)

#### No Context Window Management
- ❌ Sends entire conversation history every request
- ❌ No token counting
- ❌ No smart truncation
- ❌ Can hit token limits on long conversations

Current behaviour: `getContextWindow` returns all messages.

#### No Streaming
- ❌ Responses appear all at once after completion
- ❌ No incremental display for long responses
- ❌ Must wait for full response

#### No Advanced REPL Features
- ❌ Cannot list conversations from REPL
- ❌ Cannot switch conversations mid-session
- ❌ Cannot delete conversations from REPL
- ❌ No multi-line input
- ❌ No command history (readline)
- ❌ No auto-completion

#### No Planning or Multi-Turn Features
- ❌ No task decomposition
- ❌ No multi-step workflows
- ❌ No reflection or self-correction loops

#### Guardrails Scope
- ❌ No secret detection (API keys, tokens in files)
- ❌ No resource limits (file size, command timeout)
- ❌ `execute_command` is fully trusted — the LLM can run arbitrary shell commands

## 📊 Example Session

```bash
$ cabal run lumen
===================================
    Lumen Agent (MVP)
===================================
Model: claude-sonnet-4-20250514
Conversation: default
Tools: read_file, write_file, list_directory, search_files, execute_command

Type 'quit' to exit

> What files are in the current directory?
[tool] list_directory
[result] README.md
lumen.cabal
src/
test/
app/
...

Here are the files in the current directory: README.md, lumen.cabal, src/, test/, app/

> Read the README.md file
[tool] read_file
[result] # Lumen Agent...

Here is the content of README.md: ...

> quit
Goodbye!
```

## 🎯 Use Cases

### ✅ What Lumen is Good For (Now)

- **File analysis**: Read and summarize files or codebases
- **Code generation**: Write files based on conversation
- **Shell automation**: Execute commands and interpret output
- **Directory exploration**: Browse and search a project
- **Educational**: Learn Haskell + PBT patterns + tool loop design

### ⏳ What Lumen Will Be Good For (Next)

- **Context management**: Token-aware conversation truncation
- **Streaming**: Incremental response display
- **Advanced REPL**: List, switch, and manage conversations

## 🔮 Next Phase Roadmap

Planned enhancements:

### Context Management
- [ ] Token counting
- [ ] Smart conversation truncation
- [ ] Message summarization
- [ ] Context window optimization

### REPL Enhancements
- [ ] `/list` - List all conversations
- [ ] `/switch <id>` - Switch to different conversation
- [ ] `/delete <id>` - Delete conversation
- [ ] `/new <id>` - Start new conversation
- [ ] Multi-line input support
- [ ] Command history (readline integration)

### Response Streaming
- [ ] Server-Sent Events (SSE) support
- [ ] Incremental response display
- [ ] Cancel mid-stream

### Guardrails Hardening
- [ ] Secret detection in file contents
- [ ] Command timeout limits
- [ ] File size limits for reads/writes

## 🔧 Technical Details

### Storage Format

Conversations stored as JSON in `~/.lumen/conversations/{id}.json`. Tool use turns are stored as regular assistant messages with `blocks` content; tool results are stored as user messages with `blocks` content containing `tool_result` blocks.

### API Integration

Uses `anthropic-client` library:
- HTTP connection pooling
- Automatic retry with backoff
- Rate limit handling
- Proper error mapping

Tool definitions from `anthropic-tools-common` library:
- `fileSystemTools`: `read_file`, `write_file`, `list_directory`, `search_files`
- `shellTools`: `execute_command`

### Type Safety

All domain types have:
- `ToJSON` / `FromJSON` instances (tested with round-trip properties)
- Strict field evaluation (`!`)
- Comprehensive documentation

`SafetyConfig` and `ValidationResult` (defined in `Types.hs`) flow from configuration through `Guardrails` validation to `ToolRuntime` execution — the validation path is entirely pure and separately testable.

## 📈 Success Metrics

**Current achievements:**
- ✅ 110/110 property tests passing
- ✅ 100% test success rate at 1,000 iterations
- ✅ 5 tools integrated and validated
- ✅ Safety guardrails on all file operations
- ✅ Zero crashes in normal operation
- ✅ Graceful error handling (including guardrail blocks and tool IO errors)
- ✅ Clean separation of pure/IO code

**Quality indicators:**
- All warnings enabled (`-Wall -Wcompat`)
- GHC2021 modern Haskell
- Comprehensive documentation
- CI/CD pipeline
- Cross-platform (Linux, macOS)

## 🤝 Contributing

To add new capabilities:

1. Define types in `src/Types.hs`
2. Implement pure logic in dedicated modules
3. Add generators to `test/Test/Generators.hs`
4. Write properties in corresponding test module
5. Ensure `make test-full` passes
6. Update this document

To add a new tool:

1. Add its `CustomToolDef` to `allToolDefs` in `src/ToolCatalog.hs`
2. Add an `Action` variant to `src/Guardrails.hs` if it needs path validation
3. Add a case to `executeTool` in `src/ToolRuntime.hs`
4. Write properties for the new action extraction helper
5. See `docs/guides/adding-a-tool.md` for the full walkthrough

## 📚 Related Documentation

- [README.md](README.md) - Project overview and setup
- [docs/index.md](docs/index.md) - Full documentation index
- [docs/guides/adding-a-tool.md](docs/guides/adding-a-tool.md) - Step-by-step tool addition guide
- [.github/workflows/ci.yml](.github/workflows/ci.yml) - CI/CD configuration

---

**Bottom Line:** Lumen MVP is a working Haskell AI coding agent with a validated tool execution layer. The agent can read, write, search, and execute — safely — while maintaining the clean pure/IO separation and comprehensive PBT coverage established in Phase 1.
