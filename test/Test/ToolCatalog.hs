-- | Property-based tests for the ToolCatalog module.
module Test.ToolCatalog (properties) where

import Data.Maybe (isJust, isNothing)

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Anthropic.Protocol.Tool (CustomToolDef (..))

import ToolCatalog (allTools, allToolDefs, lookupTool)

import Test.Tasty (TestTree)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testProperty "P0: allTools has exactly 5 tools"
      prop_allTools_has_five
  , testProperty "P1: allToolDefs has exactly 5 definitions"
      prop_allToolDefs_has_five
  , testProperty "P2: lookupTool finds all known tool names"
      prop_lookupTool_known_names
  , testProperty "P3: lookupTool returns Nothing for unknown names"
      prop_lookupTool_unknown_returns_nothing
  , testProperty "P4: all tool definitions have non-empty names"
      prop_allToolDefs_have_names
  ]

-- | The catalog contains exactly 5 tools.
prop_allTools_has_five :: Property
prop_allTools_has_five = withTests 1 $ property $ do
  length allTools === 5

-- | The raw definitions list also has 5 entries.
prop_allToolDefs_has_five :: Property
prop_allToolDefs_has_five = withTests 1 $ property $ do
  length allToolDefs === 5

-- | Every known tool name can be looked up.
prop_lookupTool_known_names :: Property
prop_lookupTool_known_names = withTests 1 $ property $ do
  let knownNames = ["read_file", "write_file", "list_directory", "search_files", "execute_command"]
  mapM_ (\n -> assert $ isJust (lookupTool n)) knownNames

-- | Unknown tool names return Nothing.
prop_lookupTool_unknown_returns_nothing :: Property
prop_lookupTool_unknown_returns_nothing = property $ do
  name <- forAll $ Gen.text (Range.linear 1 50) Gen.alpha
  -- Exclude the known names
  let knownNames = ["read_file", "write_file", "list_directory", "search_files", "execute_command"]
  case name `elem` knownNames of
    True  -> success
    False -> assert $ isNothing (lookupTool name)

-- | All tool definitions have non-empty names.
prop_allToolDefs_have_names :: Property
prop_allToolDefs_have_names = withTests 1 $ property $ do
  mapM_ (\td -> assert $ td.name /= "") allToolDefs
