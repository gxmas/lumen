# Getting Started with Lumen

This tutorial walks you through installing Lumen, having your first conversation, and seeing conversation persistence in action. By the end, you'll have a working chatbot that remembers what you talked about.

## Prerequisites

You need:

- **GHC 9.10.3** or later
- **Cabal 3.10** or later
- **An Anthropic API key** — get one at [console.anthropic.com](https://console.anthropic.com/)

Verify your Haskell toolchain:

```bash
ghc --version
# The Glorious Glasgow Haskell Compilation System, version 9.10.3

cabal --version
# cabal-install version 3.10.x.x
```

## Step 1: Build Lumen

Clone the repository and build:

```bash
git clone <repository-url>
cd lumen
cabal build
```

The first build will download and compile dependencies, which may take a few minutes.

## Step 2: Set Your API Key

Lumen needs an Anthropic API key. Set it as an environment variable:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

To make this permanent, add the export line to your `~/.bashrc` or `~/.zshrc`.

Alternatively, you can pass the key directly on each run:

```bash
cabal run lumen -- --api-key "sk-ant-..."
```

## Step 3: Start a Conversation

Run Lumen:

```bash
cabal run lumen
```

You'll see the welcome banner:

```
===================================
    Lumen Agent (MVP)
===================================
Model: claude-sonnet-4-20250514
Conversation: default
Tools: read_file, write_file, list_directory, search_files, execute_command

Type 'quit' to exit

>
```

Type a message and press Enter:

```
> What's the capital of France?
Paris is the capital of France. It has been the capital since
987 CE and is the most populous city in France.

> Thanks!
You're welcome! Feel free to ask if you have any other questions.
```

## Step 4: Quit and Resume

Exit the REPL by typing `quit` (or `exit`, `q`, or `:q`):

```
> quit
Goodbye!
```

Now start Lumen again:

```bash
cabal run lumen
```

This time you'll see:

```
Resuming conversation: default
Loaded 4 messages
```

The previous conversation is loaded. You can verify by asking about it:

```
> What did we just talk about?
We just discussed the capital of France. You asked about it,
and I confirmed that Paris is the capital.
```

Lumen remembers — your conversation was saved to `~/.lumen/conversations/default.json` and reloaded on startup.

## Step 5: Use Named Conversations

You can maintain separate conversation histories with the `--conversation-id` flag:

```bash
# A conversation for work topics
cabal run lumen -- --conversation-id work

# A separate conversation for personal questions
cabal run lumen -- --conversation-id personal
```

Each conversation ID gets its own file and independent history. When you omit the flag, Lumen uses the `"default"` conversation.

## What's Next

- **[Configuration Guide](../guides/configuration.md)** — Choose a different model, manage multiple conversations
- **[CLI Reference](../reference/cli.md)** — All available flags and commands
- **[Architecture](../explanation/architecture.md)** — How Lumen is designed under the hood
