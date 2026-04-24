# Testing Guide

How to run, configure, and interpret Lumen's property-based test suite.

## Running Tests

### Quick Run (Default)

```bash
cabal test
```

Runs all 110 properties across 12 test modules with 100 random inputs each. Takes a few seconds.

### Verbose Output

```bash
cabal test --test-show-details=streaming
```

Shows each property name and result as it runs, rather than a summary at the end.

### Comprehensive Run

```bash
cabal test --test-options="--hedgehog-tests 10000"
```

Runs 10,000 random inputs per property. This is what CI runs on pushes to `main`. Takes longer but provides much higher confidence.

### Using Make

```bash
make test          # 100 iterations (quick)
make test-verbose  # streaming output
make test-full     # 10,000 iterations (CI-level)
```

## Running Specific Test Groups

Filter by test group name using `--pattern`:

```bash
cabal test --test-options="--pattern Guardrails"
cabal test --test-options="--pattern ToolRuntime"
cabal test --test-options="--pattern SchemaInputs"
cabal test --test-options="--pattern OrderedMap"
cabal test --test-options="--pattern Conversation"
cabal test --test-options="--pattern Types"
cabal test --test-options="--pattern PromptAssembly"
cabal test --test-options="--pattern AgentCore"
```

The pattern matches against the test group name in the Tasty tree.

## Adjusting Iteration Count

The `--hedgehog-tests` option controls how many random inputs each property receives:

```bash
cabal test --test-options="--hedgehog-tests 100"    # fast, default
cabal test --test-options="--hedgehog-tests 1000"   # moderate
cabal test --test-options="--hedgehog-tests 10000"  # thorough (CI)
```

Higher counts catch rarer edge cases but take longer. For local development, 100 is usually sufficient. Run 10,000 before merging.

## Interpreting Output

### Passing Test

```
Guardrails (CRITICAL)
  P0: ReadFile with safe path is allowed: OK (0.02s)
      ✓ 100 tests completed
```

The property held for all generated inputs.

### Failing Test

```
Guardrails (CRITICAL)
  P0: ReadFile with safe path is allowed: FAIL (0.01s)
      ✗ failed at test 42
        ...shrunk input shown here...
```

Hedgehog shows the **shrunk** input — the smallest input that still triggers the failure. This makes debugging much easier than working with the original random input.

## Test Organization

Tests live in `test/Test/` with one module per source module (or library component). Shared generators for domain types live in `test/Test/Generators.hs`. Tool-specific generators are defined inline in each test module.

| Test Module | Source / Component | Category | Properties |
|---|---|---|---|
| `Test.Conversation` | `Conversation` | CRITICAL | 12 |
| `Test.Types` | `Types` | CRITICAL | 5 |
| `Test.PromptAssembly` | `PromptAssembly` | STANDARD | 6 |
| `Test.AgentCore` | `AgentCore` | MINIMAL | 8 |
| `Test.Storage` | `Storage` | MINIMAL | 4 |
| `Test.ToolCatalog` | `ToolCatalog` | STANDARD | 5 |
| `Test.Guardrails` | `Guardrails` | CRITICAL | 10 |
| `Test.GuardrailsHelpers` | `Guardrails` (internals) | CRITICAL | 9 |
| `Test.ToolRuntime` | `ToolRuntime` | CRITICAL | 9 |
| `Test.SchemaInputs` | `anthropic-tools-common Schema` | CRITICAL | 7 |
| `Test.OrderedMap` | `json-schema OrderedMap` | STANDARD | 16 |
| `Test.SchemaSerialization` | `json-schema encode/decode` | CRITICAL | 19 |
| **Total** | | | **110** |

## Test Categories

### CRITICAL

Properties that guard security boundaries or data correctness. A failure here is a blocker.

- **`Test.Conversation`** — Conversation history invariants: message ordering, context window truncation, round-trip serialization.
- **`Test.Types`** — JSON round-trips for all wire-format types (`Message`, `ContentBlock`, etc.).
- **`Test.Guardrails`** — Safety rules: `ReadFile`/`WriteFile` path validation, `DeleteFile` always blocked, `ExecuteCommand` always allowed, system path blocking, path traversal detection.
- **`Test.GuardrailsHelpers`** — Internal guardrail functions: `hasPathTraversal`, `isBlockedPath`, `isSystemPath` edge cases (subdirectories, trailing slashes).
- **`Test.ToolRuntime`** — Action extraction functions (`mkReadAction`, `mkWriteAction`, etc.) at the LLM→Action boundary: path/content preservation, failure on invalid JSON, `mkErrorResult` format.
- **`Test.SchemaInputs`** — JSON round-trips for all five tool input types (`ReadFileInput`, `WriteFileInput`, `ListDirectoryInput`, `SearchFilesInput`, `ExecuteCommandInput`), including optional fields.
- **`Test.SchemaSerialization`** — JSON Schema encode/decode round-trips: primitives, objects, arrays, composition (`allOf`/`anyOf`/`oneOf`), modifiers (`withTitle`, `withDescription`, constraints), `nullable`, `ref`.

### STANDARD

Properties for important logic that isn't a security boundary.

- **`Test.PromptAssembly`** — Request assembly: model and token fields match config, messages come from the context window, system prompt is always set, tool definitions are included.
- **`Test.ToolCatalog`** — Catalog integrity: exactly 5 tools registered, all known names resolve, unknown names return `Nothing`, all definitions have non-empty names.
- **`Test.OrderedMap`** — Monoid laws (identity, associativity), insertion-order invariants (unique keys, size, membership), lookup after insert, union left-biasing, equality is order-insensitive.

### MINIMAL

Smoke-level tests for simple functions where a property test adds confidence without exhaustive coverage.

- **`Test.AgentCore`** — `isQuitCommand` truth table (known commands, case insensitivity, whitespace stripping), `hasToolUse` and `getToolUseBlocks` detection.
- **`Test.Storage`** — Conversation file persistence: write/read round-trips, ID isolation.

## CI Behavior

GitHub Actions runs tests automatically:

- **Every push to `main` or `develop`:** Quick tests (100 iterations) + comprehensive tests (10,000 iterations on `main` only)
- **Every pull request:** Quick tests (100 iterations)
- **Lint job:** Builds with `-Werror` to catch warnings

Tests run on both Ubuntu and macOS with GHC 9.10.3.

For details, see [the testing strategy explanation](../explanation/testing-strategy.md) or `.github/workflows/ci.yml`.

## Adding Tests for a New Tool

When you add a new tool, add properties in two places:

1. **`test/Test/Guardrails.hs`** — Test that the new `Action` constructor is validated correctly: allowed when safe, blocked when not.
2. **`test/Test/ToolRuntime.hs`** — Test that `mk*Action` preserves the relevant fields and returns `Left` on invalid JSON input.

Inline generators for `ToolUseBlock` values belong in the test module (following the pattern of `genToolUseBlock` in `Test.ToolRuntime`). Generators for domain types (types defined in `Types.hs`) belong in `test/Test/Generators.hs`.

See [How to Add a Tool](adding-a-tool.md) for the full step-by-step.
