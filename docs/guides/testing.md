# Testing Guide

How to run, configure, and interpret Lumen's property-based test suite.

## Running Tests

Tests live in their respective packages. Run them all at once or package by package.

### Quick Run (Default)

```bash
make test
# or directly:
cabal test all
```

Runs all 110 properties across 12 test modules with 100 random inputs each. Takes a few seconds.

### Verbose Output

```bash
make test-verbose
# or:
cabal test all --test-show-details=streaming
```

Shows each property name and result as it runs, rather than a summary at the end.

### Comprehensive Run

```bash
make test-full
# or:
cabal test all --test-options="--hedgehog-tests 10000"
```

Runs 10,000 random inputs per property. This is what CI runs on pushes to `main`. Takes longer but provides much higher confidence.

### Using Make

```bash
make test          # 100 iterations (quick)
make test-verbose  # streaming output
make test-full     # 10,000 iterations (CI-level)
```

### Running a Single Package's Tests

```bash
cabal test lumen-tool-framework-testcabal test lumen-runtime-foundation-testcabal test lumen-conversation-system-testcabal test lumen-llm-core-testcabal test lumen-test```

## Running Specific Test Groups

Filter by test group name using `--pattern` (applies within the selected test suite):

```bash
cabal test lumen-tool-framework-test --test-options="--pattern Guardrails"
cabal test lumen-tool-framework-test --test-options="--pattern ToolRuntime"
cabal test lumen-runtime-foundation-test --test-options="--pattern Types"
```

## Adjusting Iteration Count

The `--hedgehog-tests` option controls how many random inputs each property receives:

```bash
cabal test all --test-options="--hedgehog-tests 100"    # fast, default
cabal test all --test-options="--hedgehog-tests 1000"   # moderate
cabal test all --test-options="--hedgehog-tests 10000"  # thorough (CI)
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

Each package has its own test suite. Shared generators for domain types live in the `lumen-test-generators` sub-library of `lumen-runtime-foundation` (`test-support/Test/Generators.hs`). Tool-specific generators (e.g. `genToolUseBlock`) are defined inline in each test module.

| Test Module | Package / Test Suite | Category | Properties |
|---|---|---|---|
| `Test.Types` | `lumen-runtime-foundation-test` | CRITICAL | 5 |
| `Test.Storage` | `lumen-runtime-foundation-test` | MINIMAL | 4 |
| `Test.Conversation` | `lumen-conversation-system-test` | CRITICAL | 12 |
| `Test.Guardrails` | `lumen-tool-framework-test` | CRITICAL | 10 |
| `Test.GuardrailsHelpers` | `lumen-tool-framework-test` | CRITICAL | 9 |
| `Test.ToolCatalog` | `lumen-tool-framework-test` | STANDARD | 5 |
| `Test.ToolRuntime` | `lumen-tool-framework-test` | CRITICAL | 9 |
| `Test.SchemaInputs` | `lumen-tool-framework-test` | CRITICAL | 7 |
| `Test.OrderedMap` | `lumen-tool-framework-test` | STANDARD | 16 |
| `Test.SchemaSerialization` | `lumen-tool-framework-test` | CRITICAL | 19 |
| `Test.PromptAssembly` | `lumen-llm-core-test` | STANDARD | 6 |
| `Test.AgentCore` | `lumen-test` | MINIMAL | 8 |
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
