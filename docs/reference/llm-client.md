# LLMClient

API client wrapper for the Anthropic Claude API.

This module provides a simplified interface over `anthropic-client`, handling client creation, request sending, and error mapping.

**Module:** `Lumen.LLM.Client` (`lumen-llm-core/src/Lumen/LLM/Client.hs`)  
**Package:** `lumen-llm-core`

## ClientHandle

Opaque handle to an LLM client.

```haskell
newtype ClientHandle = ClientHandle AnthropicClient
```

Wraps the `AnthropicClient` from `anthropic-client`. The underlying client manages an HTTP connection pool and rate limit state.

Not exported as a constructor — create via `createClient`.

## createClient

Create a new LLM client from an API key.

```haskell
createClient :: Text -> IO ClientHandle
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `apiKeyText` | `Text` | Anthropic API key |
| **Returns** | `ClientHandle` | Opaque handle for sending requests |

Creates an `AnthropicClient` using `defaultConfig` and `newClient` from `anthropic-client`. The client maintains an HTTP connection pool internally.

## sendRequest

Send a message request to the LLM and return the response.

```haskell
sendRequest :: ClientHandle -> MessageRequest -> IO (Either LLMError MessageResponse)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `client` | `ClientHandle` | Client handle from `createClient` |
| `req` | `MessageRequest` | Request assembled by `PromptAssembly.assembleRequest` |
| **Returns** | `Either LLMError MessageResponse` | `Right response` on success, `Left error` on failure |

Delegates to `createMessage` from `anthropic-client` and maps any `ClientError` to `LLMError` via `convertError`.

## LLMError

Simplified error type for agent-level error handling.

```haskell
data LLMError
  = APIError !Text
  | NetworkError !Text
  | TimeoutError
  | ParseError !Text
  | UnknownError !Text
```

| Constructor | Fields | Mapped From |
|-------------|--------|-------------|
| `APIError` | Error message (`Text`) | `ApiErrorResponse` — the API returned an error |
| `NetworkError` | Error details (`Text`) | `Anthropic.Client.Config.NetworkError` — connection or HTTP issue |
| `TimeoutError` | — | `Anthropic.Client.Config.TimeoutError` — request timed out |
| `ParseError` | Error message (`Text`) | `DeserializationError` — failed to parse response JSON |
| `UnknownError` | Error details (`Text`) | Catch-all (not currently produced, reserved for future use) |

**Instances:** `Eq`, `Show`

All errors are non-fatal at the agent level — `AgentCore` displays the error and continues the REPL loop.
