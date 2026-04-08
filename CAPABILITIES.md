# Lumen Agent - Current Capabilities

**Project Code Name:** Dawn  
**Current Phase:** Phase 1 (Text-only conversation with persistence)  
**Last Updated:** 2026-04-07

## Overview

Lumen is a conversational AI agent built in Haskell with Claude API integration. This document describes what Lumen can and cannot do in its current state.

## ✅ Core Features

### 1. Interactive Conversation
- Start a REPL and chat with Claude
- Send text messages and receive text responses
- Clean, line-by-line text display
- Maintains conversation context across turns

### 2. Conversation Persistence
- Automatically saves conversations to `~/.lumen/conversations/{id}.json`
- Resumes previous conversations on restart
- Tracks conversation metadata:
  - `conversationId`: Unique identifier
  - `createdAt`: When conversation was first created
  - `lastUpdatedAt`: When last modified
  - `messages`: Full conversation history

### 3. Configuration Options

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

### 4. Default Configuration

| Setting | Default Value |
|---------|---------------|
| Model | `claude-sonnet-4-20250514` |
| Max Tokens | 4096 |
| Conversation ID | `default` |
| System Prompt | "You are Lumen, a helpful AI assistant..." |
| Storage Location | `~/.lumen/conversations/` |

### 5. REPL Commands

| Command | Action |
|---------|--------|
| `quit` | Exit the REPL |
| `exit` | Exit the REPL |
| `q` | Exit the REPL |
| `:q` | Exit the REPL (vim-style) |

All commands are case-insensitive and whitespace-tolerant.

## 🏗️ Architecture Strengths

### Pure Functional Core

**Conversation Management** (`src/Conversation.hs`)
- `addMessage`: Append single message
- `addMessages`: Append multiple messages
- `getRecent`: Get last N messages
- `getAll`: Get entire conversation
- `messageCount`: Count messages
- `isEmpty`: Check if empty
- All operations tested with property-based tests

**Request Assembly** (`src/PromptAssembly.hs`)
- Assembles MessageRequest from agent state
- Includes model, maxTokens, messages, system prompt
- Tested to ensure correct field population

### Clean Separation of Concerns

```
┌─────────────────────────────────────────┐
│           AgentCore (REPL)              │
│  - mainLoop, runTurn, initialize        │
└─────────────┬───────────────────────────┘
              │
      ┌───────┴────────┐
      │                │
┌─────▼─────┐    ┌────▼─────────┐
│ LLMClient │    │ Conversation │
│ (API I/O) │    │  (Pure Fns)  │
└───────────┘    └──────────────┘
      │                │
┌─────▼─────┐    ┌────▼──────────┐
│  Storage  │    │PromptAssembly │
│ (File I/O)│    │   (Pure Fns)  │
└───────────┘    └───────────────┘
      │
┌─────▼─────┐
│   Types   │
│  (Domain) │
└───────────┘
```

### Robust Error Handling

| Error Type | Behavior |
|------------|----------|
| API Error | Display error message, continue REPL |
| Network Error | Display error message, continue REPL |
| Timeout Error | Display error message, continue REPL |
| Parse Error | Display error message, continue REPL |
| File I/O Error | Silent fallback (load) or retry (save) |

**Philosophy:** Graceful degradation - never crash, always continue conversation.

### Test Coverage

**31 property-based tests** across 5 modules:

| Module | Category | Properties | What's Tested |
|--------|----------|------------|---------------|
| **Types** | CRITICAL | 5 | JSON serialization round-trips |
| **Conversation** | CRITICAL | 12 | Message list operations |
| **PromptAssembly** | STANDARD | 5 | Request assembly validation |
| **AgentCore** | MINIMAL | 5 | Command recognition |
| **Storage** | MINIMAL | 4 | Path safety checks |

**Test strategies:**
- Round-trip properties (serialization preserves data)
- Invariants (structural constraints always hold)
- Postconditions (outputs meet specifications)
- Idempotence (repeated operations produce same result)
- Composition (complex ops equal simpler compositions)

**Default:** 100 iterations per property  
**CI (main branch):** 10,000 iterations per property

## 🚫 Phase 1 Limitations

### What Lumen **Cannot** Do (Yet)

#### No Tool Execution
- ❌ Cannot read files from disk
- ❌ Cannot write files to disk
- ❌ Cannot execute shell commands
- ❌ Cannot browse the web
- ❌ Cannot call external APIs

The `SafetyConfig` type is defined but unused in Phase 1.

#### No Context Window Management
- ❌ Sends entire conversation history every request
- ❌ No token counting
- ❌ No smart truncation
- ❌ Can hit token limits on long conversations

Current behavior: `getContextWindow` returns all messages.

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
- ❌ Single request-response cycle only

## 📊 Example Session

```bash
$ cabal run lumen
===================================
    Lumen Agent (Phase 1)
===================================
Model: claude-sonnet-4-20250514
Conversation: default

Type 'quit' to exit

> What's the capital of France?
Paris is the capital of France. It has been the capital since 
987 CE and is the most populous city in France.

> Thanks!
You're welcome! Feel free to ask if you have any other questions.

> quit
Goodbye!

# --- Restart later ---

$ cabal run lumen
Resuming conversation: default
Loaded 4 messages

> What did we just talk about?
We just discussed the capital of France. You asked about it, 
and I confirmed that Paris is the capital.

> quit
Goodbye!
```

### Multiple Conversations

```bash
# Work conversation
$ lumen --conversation-id work
Starting new conversation: work
> Let's discuss the project roadmap...

# Personal conversation  
$ lumen --conversation-id personal
Starting new conversation: personal
> What are some good books to read?

# Each conversation maintains separate history
```

## 🎯 Use Cases

### ✅ What Lumen is Good For (Now)

- **Chatbot prototyping**: Test conversation flows
- **Model comparison**: Try different Claude models
- **Conversation experiments**: Persistent context across sessions
- **Educational**: Learn Haskell + PBT patterns
- **Architecture demo**: Clean functional design

### ⏳ What Lumen Will Be Good For (Phase 2)

- **File analysis**: Read and analyze codebases
- **Code generation**: Write files based on conversation
- **Shell automation**: Execute commands with safety checks
- **Research assistant**: Search and summarize information
- **Development workflows**: Git operations, testing, deployment

## 🔮 Phase 2 Roadmap

Planned enhancements:

### Tool Execution Framework
- [ ] File system operations (read/write)
- [ ] Shell command execution
- [ ] Safety guardrails (path validation)
- [ ] Tool result handling
- [ ] State machine testing for tool execution

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

## 🔧 Technical Details

### Storage Format

Conversations stored as JSON in `~/.lumen/conversations/{id}.json`:

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

### API Integration

Uses `anthropic-client` library:
- HTTP connection pooling
- Automatic retry with backoff
- Rate limit handling
- Proper error mapping

### Type Safety

All domain types have:
- `ToJSON` / `FromJSON` instances (tested with round-trip properties)
- Strict field evaluation (`!`)
- Comprehensive documentation

## 📈 Success Metrics

**Current achievements:**
- ✅ 31/31 property tests passing
- ✅ 100% test success rate at 1,000 iterations
- ✅ Zero crashes in normal operation
- ✅ Graceful error handling
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

## 📚 Related Documentation

- [README.md](README.md) - Project overview and setup
- [.github/workflows/ci.yml](.github/workflows/ci.yml) - CI/CD configuration

---

**Bottom Line:** Lumen Phase 1 is a solid, well-tested conversational agent with persistent memory. It's not yet a practical assistant (no tools), but it's an excellent foundation for Phase 2 enhancements.
