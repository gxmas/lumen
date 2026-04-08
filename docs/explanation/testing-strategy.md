# Testing Strategy

Lumen uses **property-based testing** (PBT) with [Hedgehog](https://hedgehog.qa/) as its primary testing approach. Rather than writing individual test cases with specific inputs and expected outputs, PBT defines properties that must hold for *all* valid inputs, then generates hundreds or thousands of random inputs to verify them.

## Why Property-Based Testing

Traditional unit tests check specific examples: "if I add message X to empty state, I get state with one message." Property-based tests check universal truths: "for *any* message added to *any* state, the count increases by exactly one."

This matters for Lumen because:

- **Conversation operations** must work correctly for any message content, any conversation length, any combination of user/assistant messages. A handful of hand-picked examples can't cover the space.
- **JSON serialization** must round-trip perfectly. PBT generates messages with edge-case content — empty strings, Unicode, deeply nested structures — that a human test writer would likely miss.
- **Pure functions are ideal PBT targets.** Since the core modules have no IO, generators can produce random inputs and properties can check outputs without any test infrastructure.

## Hedgehog Generators

Generators produce random values for testing. Lumen's generators live in `test/Test/Generators.hs` and build up from simple types to complex structures:

- `genRole` — generates `User` or `Assistant`
- `genMessage` — generates a `Message` with random role and content
- `genAgentState` — generates a full `AgentState` with random config and conversation history
- `genConversationFile` — generates a `ConversationFile` with timestamps and messages

Each generator produces well-formed values — the types constrain what can be generated, and the generators respect those constraints.

## Test Categories

Tests are organized by module and classified by criticality:

| Category | Modules | What It Means |
|----------|---------|---------------|
| **CRITICAL** | Types, Conversation | Failure here means data corruption or logic bugs. These must always pass. |
| **STANDARD** | PromptAssembly | Failure means requests are assembled incorrectly. Important but less likely to cause data loss. |
| **MINIMAL** | AgentCore, Storage | Tests for simple behaviors (command parsing, path construction). Fewer properties because the logic is straightforward. |

The categorization reflects where bugs would cause the most damage. Conversation and Types are CRITICAL because they manage the data that persists across sessions — a bug there could corrupt saved conversations.

## Property Strategies

The test suite employs five distinct property strategies:

### Round-Trip Properties

Verify that serialization and deserialization are inverses:

```haskell
-- For any Message, encoding then decoding produces the same Message
prop_message_roundtrip = property $ do
  msg <- forAll genMessage
  decode (encode msg) === Just msg
```

Used in: `Test.Types` for all domain types with `ToJSON`/`FromJSON` instances.

### Invariant Properties

Verify that structural constraints always hold:

```haskell
-- The conversation is never negative length
-- addMessage always appends to the end, never the beginning
```

Used in: `Test.Conversation` for message ordering and list structure.

### Postcondition Properties

Verify that function outputs meet their specification:

```haskell
-- addMessage increases conversation length by exactly 1
prop_addMessage_increases_length = property $ do
  state <- forAll genAgentState
  msg <- forAll genMessage
  let state' = addMessage msg state
  length (conversation state') === length (conversation state) + 1
```

Used in: `Test.Conversation`, `Test.PromptAssembly`.

### Idempotence Properties

Verify that repeated operations produce the same result:

```haskell
-- getRecent n applied twice yields the same result
-- (the function observes state but doesn't modify it)
```

Used in: `Test.Conversation` for read-only operations.

### Composition Properties

Verify that complex operations equal simpler compositions:

```haskell
-- addMessages [a, b] == addMessage b . addMessage a
```

Used in: `Test.Conversation` to verify that batch operations match sequential ones.

## Running Tests

```bash
cabal test                                        # 100 iterations per property (default)
cabal test --test-show-details=streaming           # with verbose output
cabal test --test-options="--hedgehog-tests 1000"  # 1,000 iterations
cabal test --test-options="--hedgehog-tests 10000" # 10,000 iterations (CI-level)
cabal test --test-options="--pattern Conversation" # run one test group
```

Or via Make:

```bash
make test          # 100 iterations
make test-verbose  # streaming output
make test-full     # 10,000 iterations
```

## CI Configuration

GitHub Actions runs tests on every push and PR:

- **All commits:** 100 iterations per property (fast feedback)
- **Pushes to main:** 10,000 iterations per property (thorough verification)

Tests run on both Ubuntu and macOS with GHC 9.10.3. A separate lint job builds with `-Werror` to catch warnings.

See `.github/workflows/ci.yml` for the full configuration.

## Test Count Summary

**31 properties across 5 modules:**

| Module | Category | Properties |
|--------|----------|------------|
| Conversation | CRITICAL | 12 |
| Types | CRITICAL | 5 |
| PromptAssembly | STANDARD | 5 |
| AgentCore | MINIMAL | 5 |
| Storage | MINIMAL | 4 |
