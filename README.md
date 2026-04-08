# Lumen Agent

A conversational AI agent built in Haskell with Claude API integration.

**Project Code Name:** Dawn  
**Current Phase:** Phase 1 (Text-only conversation with persistence)

## Overview

Lumen is a text-based REPL agent that maintains conversation history across sessions. It demonstrates clean functional architecture with comprehensive property-based testing.

### Features

- ✅ Interactive REPL with conversation history
- ✅ JSON-based conversation persistence
- ✅ Anthropic Claude API integration
- ✅ Comprehensive property-based testing (31 properties)
- 🚧 Phase 2: Tool execution with safety guardrails (planned)

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
Starting new conversation: default
> Hello, who are you?
I'm Lumen, a helpful AI assistant...

> quit
Goodbye!
```

### Commands

- `quit`, `exit`, `q`, `:q` - Exit the REPL
- Regular text - Send a message to the agent

### Conversation Management

Conversations are automatically saved to `~/.lumen/conversations/` after each turn. On restart, Lumen resumes the previous conversation.

## Architecture

```
lumen/
├── src/
│   ├── Types.hs              # Core data types
│   ├── Conversation.hs       # Pure conversation management
│   ├── Storage.hs            # JSON persistence
│   ├── PromptAssembly.hs     # Request construction
│   ├── LLMClient.hs          # Claude API client wrapper
│   └── AgentCore.hs          # REPL orchestration
├── test/
│   ├── Main.hs               # Test runner
│   └── Test/
│       ├── Generators.hs     # Hedgehog generators
│       ├── Types.hs          # JSON round-trip tests
│       ├── Conversation.hs   # Conversation logic tests
│       ├── PromptAssembly.hs # Request assembly tests
│       ├── AgentCore.hs      # Command parsing tests
│       └── Storage.hs        # Path safety tests
└── app/
    └── Main.hs               # Entry point
```

## Testing

Lumen uses **property-based testing** with [Hedgehog](https://hedgehog.qa/) to ensure correctness across a wide range of inputs.

### Test Coverage

**31 properties across 5 modules:**

| Module | Category | Properties | Description |
|--------|----------|------------|-------------|
| **Types** | CRITICAL | 5 | JSON serialization round-trips |
| **Conversation** | CRITICAL | 12 | Pure message list operations |
| **PromptAssembly** | STANDARD | 5 | Request assembly validation |
| **AgentCore** | MINIMAL | 5 | Command recognition |
| **Storage** | MINIMAL | 4 | Path safety checks |

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
cabal test --test-options="--pattern Conversation"
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

Example property from `Test.Conversation`:

```haskell
-- addMessage increases conversation length by exactly 1
prop_addMessage_increases_length :: Property
prop_addMessage_increases_length = property $ do
  state <- forAll genAgentState
  msg <- forAll genMessage
  let state' = addMessage msg state
  length (conversation state') === length (conversation state) + 1
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

- **Pure functions** (Conversation, PromptAssembly): Fully tested with PBT
- **I/O boundaries** (Storage, LLMClient, AgentCore): Tested where possible
- **Domain types** (Types): Comprehensive JSON round-trip tests

### Adding New Features

1. Define types in `src/Types.hs`
2. Implement pure logic in dedicated modules
3. Add generators to `test/Test/Generators.hs`
4. Write properties in corresponding test module
5. Update this README

### Code Style

- Follow [Haskell Style Guide](https://kowainik.github.io/posts/2019-02-06-style-guide)
- Use GHC2021 language extensions
- Enable all warnings (`-Wall -Wcompat`)
- Document modules and exported functions

## Phase 2 Roadmap

Future enhancements planned:

- [ ] Tool execution framework
- [ ] File system operations (read/write)
- [ ] Shell command execution
- [ ] Safety guardrails (path validation)
- [ ] State machine testing for tool execution
- [ ] Context window management (token-based truncation)

## Dependencies

### Core Libraries
- **anthropic-types**: Type definitions for Claude API
- **anthropic-protocol**: Message protocol implementation
- **anthropic-client**: HTTP client for Anthropic API
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
