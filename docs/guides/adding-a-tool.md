# How to Add a Tool

This guide explains how to add a new tool to Lumen.

**Prerequisites:** You have completed the [Getting Started guide](../onboarding/getting-started.md). You understand the pure/IO module split described in [docs/explanation/architecture.md](../explanation/architecture.md). You have read the [Onboarding Guide](../onboarding/guide.md).

By the end of this guide you will have:
- Defined a new tool using `anthropic-tools-common`'s schema types
- Added a typed `Action` variant to `Guardrails`
- Wired the tool into `ToolRuntime`'s dispatch loop
- Written property tests for the new tool

---

## Background: How Tool Execution Works

When the LLM wants to use a tool, it returns a response with `stop_reason = "tool_use"` and a list of `ToolUse` content blocks. Each block contains:
- `id` — a unique identifier for this invocation
- `name` — the tool name (e.g., `"read_file"`)
- `input` — a JSON object matching the tool's declared schema

`AgentCore.runTurn` detects this stop reason, extracts the `ToolUseBlock` list, and calls `ToolRuntime.executeTool` for each one. Each call validates the action through `Guardrails` before executing anything.

The data flow for a tool-using turn:

```
LLM returns stop_reason=tool_use
  → AgentCore extracts ToolUseBlock list
  → For each ToolUseBlock:
      ToolRuntime.executeTool
        → mkMyToolAction tub         -- extract typed Action
        → Guardrails.validateAction  -- check safety rules (pure)
        → executor tub               -- run the IO operation
  → AgentCore adds ToolResult messages to conversation
  → AgentCore sends updated conversation back to LLM
  → LLM returns final text response
```

---

## The Three Modules You Touch

### `src/ToolCatalog.hs` — Tool Registry

`ToolCatalog` exports two things used in every API request:

- `allToolDefs :: [CustomToolDef]` — raw definitions for name-based lookup
- `allTools :: [ToolDefinition]` — the same list wrapped for the API

Tool definitions are built with `customToolDef` and `withDescription` from `Anthropic.Protocol.Tool`, and JSON schemas from `Data.JsonSchema`:

```haskell
import Anthropic.Protocol.Tool (CustomToolDef, customToolDef, withDescription)
import Data.JsonSchema (objectSchema, stringSchema, required, optional, withDescription)
import Data.Function ((&))

myNewToolDef :: CustomToolDef
myNewToolDef = customToolDef "my_new_tool" myNewToolSchema
  & withDescription "Does X. Use this when Y. Returns Z."

myNewToolSchema :: Schema
myNewToolSchema = objectSchema
  [ required "param_one" $ stringSchema
      & withDescription "The first parameter"
  , optional "param_two" $ stringSchema
      & withDescription "An optional second parameter"
  ]
```

The description is read by the LLM to decide when to invoke the tool and how to format the `input` JSON. Be specific about what the tool does, what each parameter means, and what the output looks like.

### `src/Guardrails.hs` — Safety Validation

`Guardrails` exposes a typed `Action` ADT. Each tool use is first parsed into an `Action`, which is then validated against `SafetyConfig`. Validation is **pure** — no IO.

```haskell
-- Current Action type
data Action
  = ReadFile !FilePath
  | WriteFile !FilePath !Text
  | DeleteFile !FilePath
  | ExecuteCommand !Text
  deriving stock (Eq, Show)

validateAction :: Action -> SafetyConfig -> ValidationResult
```

To add a new tool, you add a constructor to `Action` and a case to `validateAction`. For a tool that accesses files, reuse `isSafePath`. For tools that don't touch the filesystem, `Allowed` is sufficient.

### `src/ToolRuntime.hs` — Execution

`ToolRuntime` dispatches each validated `ToolUseBlock` to the appropriate executor. The `withValidation` helper handles the parse → validate → execute pipeline:

```haskell
executeTool :: SafetyConfig -> ToolUseBlock -> IO ToolResultBlock

withValidation
  :: SafetyConfig
  -> ToolUseBlock
  -> (ToolUseBlock -> Either Text Action)  -- mkAction function
  -> (ToolUseBlock -> IO (Either ExecutionError ToolResultBlock))  -- executor
  -> IO ToolResultBlock
```

Each tool needs a `mk*Action` function that parses the `ToolUseBlock` input into a typed `Action` value. The existing tools use `parseToolInput` from `Anthropic.Tools.Common.Parser` for this:

```haskell
mkReadAction :: ToolUseBlock -> Either Text Action
mkReadAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg}) -> Left msg
  Right (input :: ReadFileInput)     -> Right $ ReadFile (T.unpack input.path)
```

---

## Step-by-Step: Adding a New Tool

This example adds a `fetch_url` tool that fetches the contents of a URL.

### Step 1: Define the input type and schema

The `anthropic-tools-common` library already provides `FetchUrlInput` and `fetchUrlSchema` in `Anthropic.Tools.Common.Schema`. For a custom tool, you add these to `src/Types.hs` or a new module:

```haskell
-- In src/Types.hs or a new src/Tools/MyNewTool.hs

data MyNewToolInput = MyNewToolInput
  { paramOne :: !Text
  , paramTwo :: !(Maybe Text)
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON MyNewToolInput where
  toJSON = Aeson.genericToJSON customOptions  -- use camelTo2 '_' like other Schema types
  toEncoding = Aeson.genericToEncoding customOptions

instance FromJSON MyNewToolInput where
  parseJSON = Aeson.genericParseJSON customOptions

myNewToolSchema :: Schema
myNewToolSchema = objectSchema
  [ required "param_one" $ stringSchema
      & withDescription "Description of param_one"
  , optional "param_two" $ stringSchema
      & withDescription "Description of param_two (optional)"
  ]
```

**Field names must match.** The schema uses `snake_case` (`"param_one"`). The `FromJSON` instance with `camelTo2 '_'` converts `paramOne` → `"param_one"` automatically. If you write the instances by hand, use the same snake_case names in both.

### Step 2: Write the tool definition

Add `myNewToolDef :: CustomToolDef` to `src/ToolCatalog.hs` and add it to `allToolDefs`:

```haskell
-- src/ToolCatalog.hs

import Anthropic.Protocol.Tool (CustomToolDef, customToolDef, withDescription)
import Data.Function ((&))

myNewToolDef :: CustomToolDef
myNewToolDef = customToolDef "my_new_tool" myNewToolSchema
  & withDescription "Does X. Use this when Y. Returns Z."

allToolDefs :: [CustomToolDef]
allToolDefs =
  let fs = fileSystemTools
      sh = shellTools
  in [ fs.readFile
     , fs.writeFile
     , fs.listDirectory
     , fs.searchFiles
     , sh.executeCommand
     , myNewToolDef       -- add here
     ]
```

The `allTools` export (used in API requests) is derived from `allToolDefs` automatically — you don't need to update it separately.

### Step 3: Add a typed Action constructor

In `src/Guardrails.hs`, add a constructor to the `Action` type and a case to `validateAction`:

```haskell
-- src/Guardrails.hs

data Action
  = ReadFile !FilePath
  | WriteFile !FilePath !Text
  | DeleteFile !FilePath
  | ExecuteCommand !Text
  | MyNewAction !Text   -- add your constructor
  deriving stock (Eq, Show)

validateAction :: Action -> SafetyConfig -> ValidationResult
validateAction action config = case action of
  ReadFile path
    | isSafePath path config -> Allowed
    | otherwise -> Blocked $ "Read blocked: " <> T.pack path
  -- ... existing cases ...
  MyNewAction param
    | isValidParam param -> Allowed
    | otherwise -> Blocked "Invalid parameter for my_new_tool"
```

If your tool accesses files, validate the path with `isSafePath`:

```haskell
  MyNewAction path
    | isSafePath (T.unpack path) config -> Allowed
    | otherwise -> Blocked $ "Path blocked: " <> path
```

If your tool doesn't touch the filesystem or run processes, `Allowed` is sufficient:

```haskell
  MyNewAction _ -> Allowed
```

### Step 4: Add the action extractor and executor case

In `src/ToolRuntime.hs`, add a `mk*Action` function and a case to `executeTool`:

```haskell
-- src/ToolRuntime.hs

-- Add to executeTool's case expression:
executeTool :: SafetyConfig -> ToolUseBlock -> IO ToolResultBlock
executeTool safetyConfig tub = case tub.name of
  "read_file"    -> withValidation safetyConfig tub mkReadAction executeReadFile
  -- ... existing cases ...
  "my_new_tool"  -> withValidation safetyConfig tub mkMyNewAction executeMyNewTool
  other          -> pure $ mkErrorResult tub $ "Unknown tool: " <> other

-- Add the action extractor:
mkMyNewAction :: ToolUseBlock -> Either Text Action
mkMyNewAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg}) -> Left msg
  Right (input :: MyNewToolInput)    -> Right $ MyNewAction input.paramOne
```

For the executor, implement the IO operation and return `IO (Either ExecutionError ToolResultBlock)`:

```haskell
import Anthropic.Tools.Common.Executor (ExecutionError (..))

executeMyNewTool :: ToolUseBlock -> IO (Either ExecutionError ToolResultBlock)
executeMyNewTool tub =
  case parseToolInput tub of
    Left err -> pure $ Left (ToolParseError err)
    Right (input :: MyNewToolInput) -> do
      result <- myOperation (T.unpack input.paramOne) input.paramTwo
      case result of
        Left ioErr -> pure $ Left (ToolIOError ioErr)
        Right out  -> pure $ Right ToolResultBlock
          { toolUseId    = tub.id
          , content      = Just (ToolResultText out)
          , isError      = Nothing
          , cacheControl = Nothing
          }
```

The `withValidation` function handles the parse error and validation failure cases for you — your executor only needs to handle success and IO errors.

### Step 5: Write property tests

Add tests for the new action extractor in `test/Test/ToolRuntime.hs`:

```haskell
-- In Test.ToolRuntime.properties:
, testProperty "P1: mkMyNewAction extracts param"
    prop_mkMyNewAction_extracts_param

-- Property:
prop_mkMyNewAction_extracts_param :: Property
prop_mkMyNewAction_extracts_param = property $ do
  param <- forAll $ Gen.text (Range.linear 1 100) Gen.unicode
  tub <- forAll $ genToolUseBlock "my_new_tool"
    (Aeson.object ["param_one" Aeson..= param])
  case mkMyNewAction tub of
    Right (MyNewAction extracted) -> extracted === param
    other -> do
      annotate $ "Expected Right (MyNewAction _), got: " <> show other
      failure
```

Add tests for the guardrails validation in `test/Test/Guardrails.hs`:

```haskell
, testProperty "P5: MyNewAction with valid param is allowed"
    prop_myNewAction_valid_allowed

prop_myNewAction_valid_allowed :: Property
prop_myNewAction_valid_allowed = property $ do
  param <- forAll $ Gen.text (Range.linear 1 100) Gen.unicode
  validateAction (MyNewAction param) permissiveConfig === Allowed
```

Generators for domain types (like `MyNewToolInput`) belong in `test/Test/Generators.hs`. Tool-specific generators (like `genToolUseBlock` for a specific tool) can live inline in the test module.

### Step 6: Verify

```bash
cabal build all     # must build with no warnings
cabal test          # all properties must pass
```

Then run the agent and ask it to use your new tool to confirm end-to-end behavior.

---

## Common Pitfalls

**Schema field names must match the input type.** If your schema has `"param_one"` but your `FromJSON` instance expects `"paramOne"` (camelCase), deserialization will fail silently at runtime. Use `camelTo2 '_'` options in your JSON instances, as all existing schema types do.

**Guardrails must parse input in the Action extractor, not in validateAction.** The `mk*Action` function in `ToolRuntime` extracts the path or parameter from the raw JSON. `validateAction` receives a fully-typed `Action` and never sees the `ToolUseBlock` directly. This separation keeps guardrails pure and testable without JSON.

**Add a constructor to the Action ADT.** Forgetting to add a case to `validateAction` for your new `Action` constructor causes a GHC warning (`-Werror` in CI will catch this). The case expression must be exhaustive.

**Error results must include the tool use ID.** `mkErrorResult tub msg` requires the original `ToolUseBlock` to populate `toolUseId`. The API requires `tool_use_id` in every `tool_result` content block.

**Tool descriptions are read by the LLM.** A vague description leads to the LLM calling the tool at wrong times or with wrong parameters. Be specific about what the tool does, what each parameter means, and what the output looks like.

---

## Further Reading

- [Architecture explanation](../explanation/architecture.md) — the pure/IO split and why `ToolRuntime` is an IO module
- [Types reference](../reference/types.md) — `ValidationResult`, `SafetyConfig`
- [Contributing guide](contributing.md) — full PR checklist, code style, test requirements
- `anthropic-tools-common` — `Schema.hs` for input types, `Executor.hs` for execution helpers, `Parser.hs` for `parseToolInput`
