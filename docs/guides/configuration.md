# Configuration Guide

How to configure Lumen's API key, model, and conversation settings.

## Setting the API Key

**Option 1: Environment variable** (recommended)

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Add this to your shell profile (`~/.bashrc`, `~/.zshrc`) to make it permanent.

**Option 2: CLI flag**

```bash
cabal run lumen -- --api-key "sk-ant-..."
```

The CLI flag takes priority over the environment variable if both are set.

## Choosing a Model

Use the `--model` flag to select a Claude model:

```bash
cabal run lumen -- --model claude-opus-4
cabal run lumen -- --model claude-haiku-3
cabal run lumen -- --model claude-sonnet-4-20250514   # default
```

The model identifier is passed directly to the Anthropic API. Use any model name that your API key has access to.

## Managing Conversations

### Using Named Conversations

Each `--conversation-id` value maps to an independent conversation file:

```bash
cabal run lumen -- --conversation-id work
cabal run lumen -- --conversation-id research
cabal run lumen                                       # uses "default"
```

Conversations are stored at `~/.lumen/conversations/{id}.json`.

### Starting Fresh

To start a new conversation with a previously used ID, delete the file:

```bash
rm ~/.lumen/conversations/default.json
cabal run lumen
# Starting new conversation: default
```

### Viewing Saved Conversations

Conversation files are plain JSON. Inspect them with any JSON tool:

```bash
cat ~/.lumen/conversations/default.json | jq .
```

### Listing All Conversations

```bash
ls ~/.lumen/conversations/
# default.json  work.json  research.json
```

## Default Values

| Setting | Default | Override |
|---------|---------|---------|
| API key | `$ANTHROPIC_API_KEY` | `--api-key KEY` |
| Model | `claude-sonnet-4-20250514` | `--model MODEL` |
| Conversation ID | `default` | `--conversation-id ID` |
| Max tokens | `4096` | Not configurable via CLI |
| System prompt | Built-in default | Not configurable via CLI |
| Storage location | `~/.lumen/conversations/` | Not configurable |

The max tokens and system prompt are set in code. See [PromptAssembly reference](../reference/prompt-assembly.md) for the default system prompt text.
