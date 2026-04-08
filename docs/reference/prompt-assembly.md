# PromptAssembly

Request construction for the LLM API.

This module builds `MessageRequest` values from the current agent state, assembling the model, messages, token limit, and system prompt into a request ready to send.

**Module:** `PromptAssembly` (`src/PromptAssembly.hs`)

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

**Note:** This is a pure function — it does not perform any IO.

> **Phase 1 note:** No tool definitions are included in the request. Phase 2 will add tool definitions here.

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
