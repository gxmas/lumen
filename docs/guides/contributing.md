# Contributing Guide

How to add features, write tests, and submit changes to Lumen.

## Adding a New Feature

Follow this five-step process:

### 1. Define Types

If the types are needed across multiple packages, add them to `Lumen.Foundation.Types` (`lumen-runtime-foundation/src/Lumen/Foundation/Types.hs`). If they are local to one package, define them in that package's module. Use strict fields (`!`) and derive instances:

```haskell
data MyNewType = MyNewType
  { fieldOne :: !Text
  , fieldTwo :: !Int
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)
```

Export the type from the module header.

### 2. Implement Pure Logic

Determine which package the feature belongs to (or create a new package for a new architectural concern). Create a dedicated module for the feature's logic. Keep it pure (no IO) wherever possible:

```haskell
module Lumen.MyFeature (myFunction) where

import Lumen.Foundation.Types (MyNewType (..))

myFunction :: MyNewType -> SomeResult
myFunction input = ...
```

Add the module to the package's `.cabal` file under `exposed-modules` in the `library` section.

### 3. Add Hedgehog Generators

Add generators for your new types in `lumen-runtime-foundation/test-support/Test/Generators.hs`:

```haskell
genMyNewType :: Gen MyNewType
genMyNewType = do
  fieldOne <- Gen.text (Range.linear 0 100) Gen.unicode
  fieldTwo <- Gen.int (Range.linear 0 1000)
  pure MyNewType {..}
```

Generators should produce well-formed values that cover the interesting parts of the input space.

### 4. Write Properties

Create a test module in the same package as the code under test, e.g. `<package>/test/Test/MyFeature.hs`:

```haskell
module Test.MyFeature (properties) where

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Tasty.Hedgehog (testProperty)

import Test.Generators (genMyNewType)
import Lumen.MyFeature (myFunction)

properties :: [TestTree]
properties =
  [ testProperty "my function does X" prop_myFunction_does_x
  ]

prop_myFunction_does_x :: Property
prop_myFunction_does_x = property $ do
  input <- forAll genMyNewType
  -- assert some property about myFunction input
```

Add the test module to the package's `.cabal` file under `other-modules` in the `test-suite` section, and import it in that package's `test/Main.hs`:

```haskell
import qualified Test.MyFeature

-- Add to the tests list:
, testGroup "MyFeature" Test.MyFeature.properties
```

### 5. Verify and Update Documentation

```bash
make test-full    # Run all tests at 10,000 iterations
cabal build all   # Ensure it builds with no warnings
```

Update relevant documentation to cover the new feature.

## Code Style

Lumen uses GHC2021 with these extensions enabled by default:

- `DerivingStrategies`
- `DuplicateRecordFields`
- `LambdaCase`
- `OverloadedRecordDot`
- `OverloadedStrings`

Additional requirements:

- All warnings enabled: `-Wall -Wcompat -Widentities -Wincomplete-record-updates -Wincomplete-uni-patterns -Wmissing-home-modules -Wpartial-fields -Wredundant-constraints -Wunused-packages`
- Document all modules and exported functions with Haddock comments
- Use `!` (strict) annotations on all record fields
- Follow the [Kowainik Haskell Style Guide](https://kowainik.github.io/posts/2019-02-06-style-guide)

## Project Structure Conventions

- **Pure logic** goes in dedicated modules (`Conversation.Core`, `LLM.PromptAssembly`, `Tools.Guardrails`, `Tools.Catalog`)
- **IO boundaries** are isolated in their own modules (`Foundation.Storage`, `LLM.Client`, `Tools.Runtime`)
- **Orchestration** stays in `Agent.Core`
- **Shared types** are consolidated in `Foundation.Types`
- **Package boundaries** reflect architectural concerns — if you're unsure which package a module belongs to, check the dependency graph in `docs/diagrams/architecture.md`

When adding a feature, keep the pure/IO separation. If your feature has both pure logic and IO, split them into separate modules.

## Pull Request Checklist

Before submitting:

1. All tests pass: `make test-full`
2. No warnings: `cabal build all` with `-Wall`
3. New types have generators in `test/Test/Generators.hs`
4. New logic has properties in `test/Test/`
5. Documentation is updated
6. Commit messages are clear and concise
