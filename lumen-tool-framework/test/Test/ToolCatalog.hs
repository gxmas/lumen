module Test.ToolCatalog (properties) where

import Data.Maybe (isJust, isNothing)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Anthropic.Protocol.Tool (CustomToolDef (..))
import Lumen.Tools.Catalog (allTools, allToolDefs, lookupTool)
import Test.Tasty (TestTree)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testProperty "P0: allTools has exactly 5 tools"           prop_allTools_has_five
  , testProperty "P1: allToolDefs has exactly 5 definitions"  prop_allToolDefs_has_five
  , testProperty "P2: lookupTool finds all known tool names"  prop_lookupTool_known_names
  , testProperty "P3: lookupTool returns Nothing for unknown" prop_lookupTool_unknown_returns_nothing
  , testProperty "P4: all tool definitions have non-empty names" prop_allToolDefs_have_names
  ]

prop_allTools_has_five :: Property
prop_allTools_has_five = withTests 1 $ property $ length allTools === 5

prop_allToolDefs_has_five :: Property
prop_allToolDefs_has_five = withTests 1 $ property $ length allToolDefs === 5

prop_lookupTool_known_names :: Property
prop_lookupTool_known_names = withTests 1 $ property $ do
  let knownNames = ["read_file", "write_file", "list_directory", "search_files", "execute_command"]
  mapM_ (\n -> assert $ isJust (lookupTool n)) knownNames

prop_lookupTool_unknown_returns_nothing :: Property
prop_lookupTool_unknown_returns_nothing = property $ do
  name <- forAll $ Gen.text (Range.linear 1 50) Gen.alpha
  let knownNames = ["read_file", "write_file", "list_directory", "search_files", "execute_command"]
  case name `elem` knownNames of
    True  -> success
    False -> assert $ isNothing (lookupTool name)

prop_allToolDefs_have_names :: Property
prop_allToolDefs_have_names = withTests 1 $ property $
  mapM_ (\td -> assert $ td.name /= "") allToolDefs
