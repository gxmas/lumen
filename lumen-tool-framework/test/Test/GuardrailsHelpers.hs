module Test.GuardrailsHelpers (properties) where

import qualified Data.Text as T
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Lumen.Foundation.Types (SafetyConfig (..))
import Lumen.Tools.Guardrails (hasPathTraversal, isBlockedPath, isSystemPath)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "hasPathTraversal"
      [ testProperty "P0: detects .. in middle of path" prop_hasPathTraversal_middle
      , testProperty "P0: detects .. at start"          prop_hasPathTraversal_start
      , testProperty "P1: rejects clean paths"          prop_hasPathTraversal_clean
      ]
  , testGroup "isBlockedPath"
      [ testProperty "P1: exact match is blocked"              prop_isBlockedPath_exact_match
      , testProperty "P1: subdirectory of blocked is blocked"  prop_isBlockedPath_subdirectory
      , testProperty "P2: order-independent"                   prop_isBlockedPath_order_independent
      , testProperty "P2: unrelated path is not blocked"       prop_isBlockedPath_unrelated
      ]
  , testGroup "isSystemPath edge cases"
      [ testProperty "P3: trailing slash detected"       prop_isSystemPath_trailing_slash
      , testProperty "P3: subdirectory detected"         prop_isSystemPath_subdirectory
      ]
  ]

genCleanSegment :: Gen String
genCleanSegment = Gen.string (Range.linear 1 15) Gen.alphaNum

genCleanPath :: Gen FilePath
genCleanPath = do
  segments <- Gen.list (Range.linear 1 5) genCleanSegment
  pure $ "/home/user/" <> foldr1 (\a b -> a <> "/" <> b) segments

prop_hasPathTraversal_middle :: Property
prop_hasPathTraversal_middle = property $ do
  prefix <- forAll genCleanSegment
  suffix <- forAll genCleanSegment
  assert $ hasPathTraversal ("/home/" <> prefix <> "/../" <> suffix)

prop_hasPathTraversal_start :: Property
prop_hasPathTraversal_start = property $ do
  suffix <- forAll genCleanSegment
  assert $ hasPathTraversal ("../" <> suffix)

prop_hasPathTraversal_clean :: Property
prop_hasPathTraversal_clean = property $ do
  path <- forAll genCleanPath
  assert $ not (hasPathTraversal path)

prop_isBlockedPath_exact_match :: Property
prop_isBlockedPath_exact_match = property $ do
  path <- forAll genCleanPath
  assert $ isBlockedPath path (SafetyConfig [] [T.pack path] True)

prop_isBlockedPath_subdirectory :: Property
prop_isBlockedPath_subdirectory = property $ do
  basePath <- forAll genCleanPath
  subDir   <- forAll genCleanSegment
  assert $ isBlockedPath (basePath <> "/" <> subDir) (SafetyConfig [] [T.pack basePath] True)

prop_isBlockedPath_order_independent :: Property
prop_isBlockedPath_order_independent = property $ do
  target <- forAll genCleanPath
  other1 <- forAll genCleanPath
  other2 <- forAll genCleanPath
  let cfg1 = SafetyConfig [] [T.pack target, T.pack other1, T.pack other2] True
  let cfg2 = SafetyConfig [] [T.pack other2, T.pack target, T.pack other1] True
  isBlockedPath target cfg1 === isBlockedPath target cfg2

prop_isBlockedPath_unrelated :: Property
prop_isBlockedPath_unrelated = property $ do
  path <- forAll genCleanPath
  assert $ not (isBlockedPath path (SafetyConfig [] ["/tmp/blocked"] True))

prop_isSystemPath_trailing_slash :: Property
prop_isSystemPath_trailing_slash = withTests 1 $ property $ do
  assert $ isSystemPath "/etc/"
  assert $ isSystemPath "/bin/"
  assert $ isSystemPath "/usr/"

prop_isSystemPath_subdirectory :: Property
prop_isSystemPath_subdirectory = property $ do
  sysDir  <- forAll $ Gen.element ["/etc", "/bin", "/usr", "/var", "/sys"]
  subPath <- forAll genCleanSegment
  assert $ isSystemPath (sysDir <> "/" <> subPath)
