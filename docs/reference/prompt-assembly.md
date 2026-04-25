# PromptAssembly

Request construction for the LLM API.

This module builds `MessageRequest` values from the current agent state, assembling the model, messages, token limit, and system prompt into a request ready to send.

**Module:** `Lumen.LLM.PromptAssembly` (`lumen-llm-core/src/Lumen/LLM/PromptAssembly.hs`)  
**Package:** `lumen-llm-core`

## assembleRequest

Assemble a `MessageRequest` from the current agent state.

```haskell
assembleRequest :: AgentState -> MessageRequest
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `state` | `AgentState` | Current agent state (config + conversation) |
| **Returns** | `MessageRequest` | Fully assembled request for the Anthropic API |

**Behavior:**

1. Extracts the model, max tokens, and system prompt from `state.config`
2. Calls `getContextWindow` to get the messages to include
3. Builds a `MessageRequest` using `messageRequest` from `anthropic-protocol`
4. Attaches the system prompt:
   - If `config.systemPrompt` is `Just sp`, uses `sp`
   - If `config.systemPrompt` is `Nothing`, uses `defaultSystemPrompt`
5. Injects all registered tool definitions via `withTools allTools`

**Note:** This is a pure function — it does not perform any IO.

**Tool injection:** `withTools allTools` adds the 5 tool definitions (`read_file`, `write_file`, `list_directory`, `search_files`, `execute_command`) to every request. This tells Claude which tools are available and provides their input schemas. Without this step, the model would not produce `tool_use` blocks.

**Note on coupling:** `assembleRequest` currently imports `allTools` directly from `Lumen.Tools.Catalog`, which creates a dependency from `lumen-llm-core` on `lumen-tool-framework`. This is a known temporary coupling that will be removed in Phase 3 when `assembleRequest` is refactored to accept a `PromptRequest` value object containing the tool list.

## defaultSystemPrompt

The default system prompt used when no custom prompt is configured.

```haskell
defaultSystemPrompt :: SystemPrompt
```

**Value:**

```
You are Lumen, a helpful AI assistant.

You communicate clearly and concisely.
You think step-by-step when solving problems.
You ask clarifying questions when needed.
```

Constructed as `SimpleSystem` with the above text. Used automatically when `AgentConfig.systemPrompt` is `Nothing`.
