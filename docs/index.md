# Lumen Documentation

Lumen is a conversational AI agent built in Haskell with Claude API integration. It provides a text-based REPL with persistent conversation history.

**Current phase:** Phase 1 (text-only conversation with persistence)

## Start Here

- **[Onboarding](onboarding/index.md)** — Go from "never seen this repo" to "ready to contribute" — project structure, architecture, data flow, and the full phase roadmap

## How-to Guides

- **[Configuration](guides/configuration.md)** — API key, model selection, conversation management
- **[Testing](guides/testing.md)** — Run and interpret the property-based test suite
- **[Contributing](guides/contributing.md)** — Add features, write tests, submit changes
- **[Adding a Tool](guides/adding-a-tool.md)** — Define, validate, and implement a new tool for Phase 2
- **[Extending Modules](guides/extending-modules.md)** — Add new modules or enhance existing ones following the architecture roadmap

## Understand

- **[Architecture](explanation/architecture.md)** — Pure core vs IO shell, module design, data flow
- **[Testing Strategy](explanation/testing-strategy.md)** — Why property-based testing, Hedgehog, test categories
- **[Persistence](explanation/persistence.md)** — JSON storage format, conversation lifecycle

## Reference

- **[Types](reference/types.md)** — AgentConfig, AgentState, ConversationFile, and all domain types
- **[Conversation](reference/conversation.md)** — addMessage, getRecent, messageCount, and message list operations
- **[Storage](reference/storage.md)** — saveConversation, loadConversation, file path management
- **[PromptAssembly](reference/prompt-assembly.md)** — assembleRequest, defaultSystemPrompt
- **[LLMClient](reference/llm-client.md)** — createClient, sendRequest, LLMError
- **[AgentCore](reference/agent-core.md)** — initialize, mainLoop, runTurn, isQuitCommand
- **[CLI](reference/cli.md)** — Command-line flags, REPL commands, defaults

## Diagrams

- **[Architecture Diagram](diagrams/architecture.md)** — Module dependency graph
- **[Request Flow](diagrams/request-flow.md)** — Sequence diagram of a single conversation turn
- **[Persistence Flow](diagrams/persistence-flow.md)** — Startup, save, and resume lifecycle
