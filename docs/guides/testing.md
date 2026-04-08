# Testing Guide

How to run, configure, and interpret Lumen's property-based test suite.

## Running Tests

### Quick Run (Default)

```bash
cabal test
```

Runs all 31 properties with 100 random inputs each. Takes a few seconds.

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
cabal test --test-options="--pattern Conversation"
cabal test --test-options="--pattern Types"
cabal test --test-options="--pattern PromptAssembly"
cabal test --test-options="--pattern AgentCore"
cabal test --test-options="--pattern Storage"
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
Conversation (CRITICAL)
  prop_addMessage_increases_length: OK (0.02s)
      ✓ 100 tests completed
```

The property held for all generated inputs.

### Failing Test

```
Conversation (CRITICAL)
  prop_addMessage_increases_length: FAIL (0.01s)
      ✗ failed at test 42
        ...shrunk input shown here...
```

Hedgehog shows the **shrunk** input — the smallest input that still triggers the failure. This makes debugging much easier than working with the original random input.

## Test Organization

Tests are organized in `test/Test/` with one module per source module:

| Test Module | Source Module | Category | Properties |
|-------------|-------------|----------|------------|
| `Test.Types` | `Types` | CRITICAL | 5 |
| `Test.Conversation` | `Conversation` | CRITICAL | 12 |
| `Test.PromptAssembly` | `PromptAssembly` | STANDARD | 5 |
| `Test.AgentCore` | `AgentCore` | MINIMAL | 5 |
| `Test.Storage` | `Storage` | MINIMAL | 4 |

Generators for all test data live in `Test.Generators`.

## CI Behavior

GitHub Actions runs tests automatically:

- **Every push to `main` or `develop`:** Quick tests (100 iterations) + comprehensive tests (10,000 iterations on `main` only)
- **Every pull request:** Quick tests (100 iterations)
- **Lint job:** Builds with `-Werror` to catch warnings

Tests run on both Ubuntu and macOS with GHC 9.10.3.

For details, see [the testing strategy explanation](../explanation/testing-strategy.md) or `.github/workflows/ci.yml`.
