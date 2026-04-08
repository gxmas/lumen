# CLI Reference

Command-line interface for the Lumen agent.

**Executable:** `lumen` (defined in `app/Main.hs`)

## Usage

```
lumen [OPTIONS]
```

## Options

| Flag | Argument | Default | Description |
|------|----------|---------|-------------|
| `--api-key` | `KEY` | `$ANTHROPIC_API_KEY` | Anthropic API key |
| `--model` | `MODEL` | `claude-sonnet-4-20250514` | Claude model to use |
| `--conversation-id` | `ID` | `default` | Conversation ID for persistence |
| `--help` | — | — | Show usage message and exit |

### API Key

The API key can be provided in two ways (in priority order):

1. `--api-key KEY` flag
2. `ANTHROPIC_API_KEY` environment variable

If neither is set, Lumen prints an error and exits with a non-zero status.

### Model Selection

Any valid Claude model identifier can be used:

```bash
lumen --model claude-opus-4
lumen --model claude-haiku-3
lumen --model claude-sonnet-4-20250514   # default
```

### Conversation ID

Each conversation ID maps to a separate JSON file on disk. Use different IDs to maintain independent conversation histories:

```bash
lumen --conversation-id work
lumen --conversation-id personal
lumen                                    # uses "default"
```

## Default Configuration

| Setting | Value |
|---------|-------|
| Model | `claude-sonnet-4-20250514` |
| Max tokens | `4096` |
| Conversation ID | `default` |
| System prompt | Built-in (see [PromptAssembly](prompt-assembly.md#defaultsystemprompt)) |
| Storage location | `~/.lumen/conversations/` |
| Safety config | Empty allowedPaths/blockedPaths, `allowSystemPaths = False` |

## REPL Commands

Once inside the REPL, the following commands are recognized:

| Command | Action |
|---------|--------|
| `quit` | Save and exit |
| `exit` | Save and exit |
| `q` | Save and exit |
| `:q` | Save and exit (vim-style) |

All commands are case-insensitive and whitespace-tolerant.

Any other input is sent as a message to the Claude API.

## Exit Behavior

- **Normal exit** (quit command): Conversation is saved, exit code 0
- **Fatal error** (uncaught exception): Error printed to stderr, exit code 1
- **Missing API key**: Error printed to stderr, exit code 1
- **Unknown argument**: Error and usage printed to stderr, exit code 1

## Startup Output

```
===================================
    Lumen Agent (Phase 1)
===================================
Model: claude-sonnet-4-20250514
Conversation: default

Type 'quit' to exit
```

If resuming an existing conversation:

```
Resuming conversation: default
Loaded 4 messages
```

If starting fresh:

```
Starting new conversation: default
```
