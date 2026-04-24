# Lumen Agent

A Haskell AI coding agent with tool execution and safety guardrails.

**Project Code Name:** Dawn  
**Current Phase:** MVP (conversation with tool execution)

## Overview

Lumen is a text-based REPL agent that converses with Claude and executes tools on your behalf — reading files, writing files, listing directories, searching, and running shell commands. All file operations are validated by a safety guardrails layer before execution. Conversation history persists across sessions.

The project demonstrates clean functional architecture with comprehensive property-based testing: a pure core surrounded by a thin IO shell, with each layer independently tested.

### Features

- ✅ Interactive REPL with persistent conversation history
- ✅ Tool execution: `read_file`, `write_file`, `list_directory`, `search_files`, `execute_command`
- ✅ Safety guardrails: path traversal blocking, system path blocking, file deletion denial
- ✅ JSON-based conversation persistence (resumes on restart)
- ✅ Anthropic Claude API integration
- ✅ 110 property-based tests across 12 modules

## Quick Start

### Prerequisites

- GHC 9.10.3 or later
- Cabal 3.10 or later
- Anthropic API key

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd lumen

# Build the project
cabal build

# Run the agent
cabal run lumen
```

### Configuration

Lumen requires an Anthropic API key. Set it as an environment variable:

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

## Usage

Start the agent and begin conversing:

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
[result] README.md lumen.cabal src/ test/ app/

Here are the files in the current directory: ...

> quit
Goodbye!
```

### Commands

- `quit`, `exit`, `q`, `:q` — Exit the REPL
- Regular text — Send a message to the agent

### Conversation Management

Conversations are automatically saved to `~/.lumen/conversations/` after each turn, including tool use and tool result turns. On restart, Lumen resumes the previous conversation.

Use `--conversation-id` to maintain separate conversations:

```bash
lumen --conversation-id work
lumen --conversation-id personal
```

## Tools

The agent has access to 5 tools, all from the `anthropic-tools-common` library:

| Tool | Description |
|------|-------------|
| `read_file` | Read a file's contents |
| `write_file` | Write content to a file |
| `list_directory` | List entries in a directory |
| `search_files` | Search for files matching a pattern |
| `execute_command` | Run a shell command |

All file and directory operations are validated by `Guardrails` before execution. File deletion is always denied. Paths containing `..` or pointing to system directories (`/etc`, `/bin`, `/usr`, etc.) are blocked by default.

## Architecture

9 source modules across two layers:

```
lumen/
├── src/
│   ├── Types.hs              # Core data types (AgentConfig, AgentState, SafetyConfig, …)
│   ├── Conversation.hs       # Pure conversation management
│   ├── Storage.hs            # JSON persistence
│   ├── PromptAssembly.hs     # Request construction (injects tool definitions)
│   ├── LLMClient.hs          # Claude API client wrapper
│   ├── AgentCore.hs          # REPL orchestration and tool loop
│   ├── ToolCatalog.hs        # Tool registry (allTools, lookupTool)
│   ├── Guardrails.hs         # Safety validation (pure)
│   └── ToolRuntime.hs        # Tool execution (wires Guardrails to executors)
├── test/
│   ├── Main.hs               # Test runner
│   └── Test/
│       ├── Generators.hs       # Hedgehog generators
│       ├── Types.hs            # JSON round-trip tests
│       ├── Conversation.hs     # Conversation logic tests
│       ├── PromptAssembly.hs   # Request assembly tests
│       ├── AgentCore.hs        # Command parsing and tool detection tests
│       ├── Storage.hs          # Path safety tests
│       ├── ToolCatalog.hs      # Tool registry tests
│       ├── Guardrails.hs       # Validation rule tests
│       ├── GuardrailsHelpers.hs# Path helper tests
│       ├── ToolRuntime.hs      # Action extraction tests
│       ├── OrderedMap.hs       # Ordered map invariant tests
│       ├── SchemaInputs.hs     # Tool input schema tests
│       └── SchemaSerialization.hs # Schema JSON round-trip tests
└── app/
    └── Main.hs               # Entry point and CLI parsing
```

**Design principle:** Pure functions (Conversation, PromptAssembly, Guardrails, ToolCatalog) are separated from IO (Storage, LLMClient, ToolRuntime, AgentCore). The pure core is fully exercised by property-based tests; IO boundaries are tested where possible.

## Testing

Lumen uses **property-based testing** with [Hedgehog](https://hedgehog.qa/) to ensure correctness across a wide range of inputs.

### Test Coverage

**110 properties across 13 test modules:**

| Module | Category | Properties | Description |
|--------|----------|------------|-------------|
| **Types** | CRITICAL | 5 | JSON serialization round-trips |
| **Conversation** | CRITICAL | 12 | Pure message list operations |
| **PromptAssembly** | STANDARD | 6 | Request assembly validation |
| **AgentCore** | MINIMAL | 8 | Command recognition, tool detection |
| **Storage** | MINIMAL | 4 | Path safety checks |
| **ToolCatalog** | STANDARD | 5 | Tool registry lookup and completeness |
| **Guardrails** | CRITICAL | 10 | Path validation, action rules |
| **GuardrailsHelpers** | CRITICAL | 9 | Path traversal and system path detection |
| **ToolRuntime** | CRITICAL | 9 | Action extraction, error result construction |
| **OrderedMap** | STANDARD | 16 | Ordered map invariants |
| **SchemaInputs** | STANDARD | 7 | Tool input schema parsing |
| **SchemaSerialization** | STANDARD | 19 | Tool schema JSON round-trips |

### Running Tests

```bash
# Run all tests (100 iterations per property)
cabal test

# Run with verbose output
cabal test --test-show-details=streaming

# Run with 1,000 iterations
cabal test --test-options="--hedgehog-tests 1000"

# Run comprehensive tests (10,000 iterations - recommended for CI)
cabal test --test-options="--hedgehog-tests 10000"

# Run specific test group
cabal test --test-options="--pattern Guardrails"
```

### Using Make

A Makefile is provided for convenience:

```bash
make test              # Run tests (100 iterations)
make test-verbose      # Run with streaming output  
make test-full         # Run with 10,000 iterations (CI-level)
make build             # Build all components
make clean             # Clean build artifacts
```

### Property-Based Testing Strategy

The test suite uses several PBT strategies:

- **Round-trip properties**: Serialization/deserialization preserves data
- **Invariants**: Structural constraints always hold
- **Postconditions**: Function outputs meet specifications
- **Idempotence**: Repeated operations produce same result
- **Composition**: Complex operations equal simpler compositions

Example property from `Test.Guardrails`:

```haskell
-- A path containing ".." is always blocked, regardless of SafetyConfig
prop_pathTraversal_alwaysBlocked :: Property
prop_pathTraversal_alwaysBlocked = property $ do
  base <- forAll genSafePath
  let traversalPath = base <> "/../etc/passwd"
  config <- forAll genSafetyConfig
  isSafePath traversalPath config === False
```

### Continuous Integration

Tests run automatically on:
- Every push to `main` or `develop`
- Every pull request

**Quick tests** (100 iterations) run on all commits.  
**Comprehensive tests** (10,000 iterations) run on pushes to `main`.

See [.github/workflows/ci.yml](.github/workflows/ci.yml) for details.

## Development

### Project Structure

- **Pure functions** (Conversation, PromptAssembly, Guardrails, ToolCatalog): Fully tested with PBT
- **I/O boundaries** (Storage, LLMClient, AgentCore, ToolRuntime): Tested where possible
- **Domain types** (Types): Comprehensive JSON round-trip tests

### Adding New Features

1. Define types in `src/Types.hs`
2. Implement pure logic in dedicated modules
3. Add generators to `test/Test/Generators.hs`
4. Write properties in corresponding test module
5. Update this README

To add a new tool specifically, see [docs/guides/adding-a-tool.md](docs/guides/adding-a-tool.md).

### Code Style

- Follow [Haskell Style Guide](https://kowainik.github.io/posts/2019-02-06-style-guide)
- Use GHC2021 language extensions
- Enable all warnings (`-Wall -Wcompat`)
- Document modules and exported functions

## Dependencies

### Core Libraries
- **anthropic-types**: Type definitions for Claude API
- **anthropic-protocol**: Message protocol implementation
- **anthropic-client**: HTTP client for Anthropic API
- **anthropic-tools-common**: Pre-built tool definitions and executors
- **aeson**: JSON serialization
- **text**: Text processing

### Testing Libraries
- **hedgehog**: Property-based testing framework
- **tasty**: Test framework
- **tasty-hedgehog**: Hedgehog integration for Tasty

## License

BSD-3-Clause

## Contributing

Contributions welcome! Please:
1. Add tests for new features
2. Ensure all tests pass: `make test-full`
3. Follow existing code style
4. Update documentation

## Author

gnoel5
