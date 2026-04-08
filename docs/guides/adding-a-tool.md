# How to Add a Tool

This guide explains how to add a new tool to Lumen once Phase 2 (Tool Execution) is implemented.

**Prerequisites:** You have completed the Phase 0 walking skeleton (text-only REPL). You understand the pure/IO module split described in [docs/explanation/architecture.md](../explanation/architecture.md). You have read the [Onboarding Guide](../onboarding/guide.md).

**Phase 2 is not yet implemented.** The modules described here (`ToolCatalog`, `Guardrails`, `ToolRuntime`) are planned but do not exist yet. This guide describes the planned architecture so contributors know where to add tools when Phase 2 lands. The construction plan is at `~/Projects/design/lumen/implementation/construction-plan.md`.

By the end of this guide you will know:
- How tools are defined using `anthropic-tools-common`
- How to write a tool executor
- How to add guardrails validation for the tool
- How to wire the tool into `AgentCore`'s dispatch loop
- How to test the new tool

---

## Background: How Tool Execution Works

When the LLM wants to use a tool, it returns a response with `stop_reason = "tool_use"` and a list of `ToolUse` content blocks. Each block contains:
- `id` — a unique identifier for this invocation
- `name` — the tool name (e.g., `"read_file"`)
- `input` — a JSON object matching the tool's declared schema

`AgentCore.runTurn` (in Phase 2) will detect this stop reason, validate each tool use through `Guardrails`, execute it through `ToolRuntime`, and send the results back to the LLM in a new turn.

The data flow for a tool-using turn:

```
LLM returns stop_reason=tool_use
  → AgentCore extracts ToolUseBlock list
  → For each ToolUseBlock:
      Guardrails.validateAction → Allowed | Blocked
      ToolRuntime.executeTool  → ToolResultBlock
  → AgentCore adds ToolResult messages to conversation
  → AgentCore sends updated conversation back to LLM
  → LLM returns final text response
```

---

## The Three Modules You Touch

### `src/ToolCatalog.hs` — Tool Definitions

This module exports the list of `CustomToolDef` values that get sent to the API in every request. The Anthropic API uses these definitions to decide which tools it can call and how to format the `input` JSON object.

In Phase 2, `ToolCatalog` re-exports pre-built definitions from `anthropic-tools-common` for the five standard tools. A custom tool definition looks like:

```haskell
import Anthropic.Tools.Common (CustomToolDef (..), mkToolDef)
import Data.JsonSchema (object, property, string, description, required)

myNewToolDef :: CustomToolDef
myNewToolDef = mkToolDef
  { toolName        = "my_new_tool"
  , toolDescription = "A brief description the LLM uses to decide when to call this tool."
  , toolInputSchema = object
      [ property "param_one" (string `description` "The first parameter")
      , property "param_two" (string `description` "The second parameter")
      , required ["param_one"]
      ]
  }
```

The `toolDescription` field is read by the LLM to decide when to invoke the tool. Write it in plain English. Be specific about what the tool does, what parameters it expects, and any important constraints.

The `toolInputSchema` is a JSON schema using `json-schema-combinators`. The schema is serialized to the `input_schema` field in the Anthropic API request. Every property listed in `required` must be present in the LLM's `input` JSON.

### `src/Guardrails.hs` — Safety Validation

`Guardrails` checks each `ToolUseBlock` before execution and returns `Allowed` or `Blocked reason`. It enforces path restrictions, blocks system directories, and prevents file deletion.

For a new tool, you add a case to `validateAction`:

```haskell
-- src/Guardrails.hs

import Types (SafetyConfig (..), ValidationResult (..))
import Anthropic.Protocol.Message (ToolUseBlock (..))

validateAction :: ToolUseBlock -> SafetyConfig -> IO ValidationResult
validateAction tub config = case tub.name of
  "read_file"    -> validateReadFile tub config
  "write_file"   -> validateWriteFile tub config
  "my_new_tool"  -> validateMyNewTool tub config   -- add your case here
  _              -> pure (Blocked "Unknown tool")

validateMyNewTool :: ToolUseBlock -> SafetyConfig -> IO ValidationResult
validateMyNewTool tub config = do
  -- Parse the input to extract relevant parameters
  -- Apply safety rules
  -- Return Allowed or Blocked "reason"
  pure Allowed  -- or: pure (Blocked "reason")
```

If your tool does not touch the filesystem or execute processes, a simple `pure Allowed` is sufficient. If it accesses files, apply the same path-checking logic as `validateReadFile` and `validateWriteFile`: use `isSafePath` to verify the path is within `config.allowedPaths` and not in `config.blockedPaths`.

### `src/ToolRuntime.hs` — Execution

`ToolRuntime` dispatches a validated `ToolUseBlock` to the appropriate executor and returns a `ToolResultBlock`. In Phase 2, the five standard tools delegate to `anthropic-tools-common` executors (`executeReadFile`, `executeWriteFile`, etc.).

Add your tool's executor here:

```haskell
-- src/ToolRuntime.hs

executeTool :: ToolUseBlock -> IO ToolResultBlock
executeTool tub = case tub.name of
  "read_file"   -> Anthropic.Tools.Common.executeReadFile tub
  "write_file"  -> Anthropic.Tools.Common.executeWriteFile tub
  "my_new_tool" -> executeMyNewTool tub   -- add your case here
  name          -> pure $ errorResult tub ("Unknown tool: " <> name)

executeMyNewTool :: ToolUseBlock -> IO ToolResultBlock
executeMyNewTool tub = do
  -- 1. Parse typed input using the library helper
  case parseToolInput tub of
    Left err -> pure $ errorResult tub (T.pack $ show err)
    Right (MyNewToolInput { paramOne, paramTwo }) -> do
      -- 2. Execute the operation
      result <- performMyNewToolOperation paramOne paramTwo
      -- 3. Return a ToolResultBlock with the output
      pure $ successResult tub result
```

`parseToolInput` is from `anthropic-tools-common`. It deserializes `tub.input` as JSON into your typed input record. `successResult` and `errorResult` are helpers that construct the `ToolResultBlock` format the API expects.

---

## Step-by-Step: Adding a New Tool

### Step 1: Define the input type

Add a typed input record to `src/Types.hs` or to the tool's own module:

```haskell
-- In src/Types.hs or a new src/Tools/MyNewTool.hs

data MyNewToolInput = MyNewToolInput
  { paramOne :: !Text
  , paramTwo :: !(Maybe Text)   -- optional parameter
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON)
```

The `FromJSON` instance is what `parseToolInput` uses to deserialize the LLM's `input` JSON. Field names must match the `property` names in the JSON schema exactly.

### Step 2: Write the tool definition

Add `myNewToolDef :: CustomToolDef` to `src/ToolCatalog.hs` using `json-schema-combinators`:

```haskell
myNewToolDef :: CustomToolDef
myNewToolDef = mkToolDef
  { toolName        = "my_new_tool"
  , toolDescription = "Does X. Use this when Y. Returns Z."
  , toolInputSchema = object
      [ property "param_one" (string `description` "Description of param_one")
      , property "param_two" (string `description` "Description of param_two (optional)")
      , required ["param_one"]
      ]
  }
```

Then add it to the exported catalog:

```haskell
toolCatalog :: [CustomToolDef]
toolCatalog =
  [ readFileDef
  , writeFileDef
  , listDirectoryDef
  , executeCommandDef
  , searchFilesDef
  , myNewToolDef    -- add here
  ]
```

### Step 3: Add guardrails validation

In `src/Guardrails.hs`, add a case to `validateAction` and implement `validateMyNewTool`. For filesystem-touching tools, reuse `isSafePath`:

```haskell
validateMyNewTool :: ToolUseBlock -> SafetyConfig -> IO ValidationResult
validateMyNewTool tub config =
  case parseToolInput tub of
    Left _ -> pure (Blocked "Invalid tool input")
    Right (MyNewToolInput { paramOne }) ->
      if isSafePath (T.unpack paramOne) config
        then pure Allowed
        else pure (Blocked "Path outside allowed directories")
```

If your tool does not touch files or run processes, you may not need any validation beyond confirming the input parses correctly.

### Step 4: Implement the executor

In `src/ToolRuntime.hs`, add the case and implement `executeMyNewTool`:

```haskell
executeMyNewTool :: ToolUseBlock -> IO ToolResultBlock
executeMyNewTool tub =
  case parseToolInput tub of
    Left err -> pure $ errorResult tub (T.pack $ show err)
    Right input -> do
      -- Perform the operation
      result <- myOperation input.paramOne input.paramTwo
      case result of
        Left err  -> pure $ errorResult tub err
        Right out -> pure $ successResult tub out
```

The output passed to `successResult` should be a human-readable `Text` that the LLM can interpret as the tool's result. For file contents, return the raw content. For command output, return stdout. For errors, include enough context for the LLM to respond sensibly to the user.

### Step 5: Write a Hedgehog generator

Add a generator for `MyNewToolInput` in `test/Test/Generators.hs`:

```haskell
genMyNewToolInput :: Gen MyNewToolInput
genMyNewToolInput = do
  paramOne <- Gen.text (Range.linear 1 100) Gen.unicode
  paramTwo <- Gen.maybe $ Gen.text (Range.linear 0 100) Gen.unicode
  pure MyNewToolInput { paramOne, paramTwo }
```

### Step 6: Write property tests

Create `test/Test/Tools/MyNewTool.hs`:

```haskell
module Test.Tools.MyNewTool (properties) where

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import Test.Generators (genMyNewToolInput)
import Tools.MyNewTool (executeMyNewTool)

properties :: [TestTree]
properties =
  [ testGroup "MyNewTool"
      [ testProperty "valid input succeeds" prop_valid_input_succeeds
      , testProperty "JSON round-trip" prop_json_roundtrip
      ]
  ]

-- Example: if paramOne is always non-empty, the tool should not return an error
prop_valid_input_succeeds :: Property
prop_valid_input_succeeds = property $ do
  input <- forAll genMyNewToolInput
  -- assert something about executeMyNewTool input
  -- ...
```

Add the module to `other-modules` in `lumen.cabal` and import it in `test/Main.hs`.

### Step 7: Verify

```bash
cabal build all     # must build with no warnings
cabal test          # all properties must pass
```

Then run the agent and ask it to use your new tool to confirm end-to-end behavior.

---

## Common Pitfalls

**Schema field names must match the input type.** If your schema has `"param_one"` but your `FromJSON` instance expects `paramOne` (camelCase), deserialization will fail silently at runtime. Use `snake_case` in both the schema and the JSON field names, and add `Options { fieldLabelModifier = camelToSnake }` to your `FromJSON` instance if needed.

**Guardrails must parse input safely.** If `parseToolInput` fails in `validateMyNewTool`, return `Blocked "Invalid tool input"` rather than crashing. The LLM can send malformed input.

**Error results must include the tool use ID.** Both `successResult` and `errorResult` require the original `ToolUseBlock` to extract `tub.id`. The API requires the `tool_use_id` in every `tool_result` content block.

**Tool descriptions are read by the LLM.** A vague description leads to the LLM calling the tool at wrong times or with wrong parameters. Be specific about what the tool does, what each parameter means, and what the output looks like.

---

## Further Reading

- [Architecture explanation](../explanation/architecture.md) — the pure/IO split and why `ToolRuntime` is an IO module
- [Contributing guide](contributing.md) — full PR checklist, code style, test requirements
- [Types reference](../reference/types.md) — `ValidationResult`, `SafetyConfig`
- Design documents at `~/Projects/design/lumen/design/mvp-contracts.md` — the full Guardrails and Tool Runtime contracts
- `~/Projects/design/lumen/implementation/construction-plan.md` — Phase 2 build order
