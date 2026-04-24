-- | Property-based tests for Guardrails internal helper functions.
--
-- Tests hasPathTraversal, isBlockedPath, and path normalization edge cases.
-- Category: CRITICAL (security boundary)
module Test.GuardrailsHelpers (properties) where

import qualified Data.Text as T

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Types (SafetyConfig (..))
import Guardrails (hasPathTraversal, isBlockedPath, isSystemPath)

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "hasPathTraversal"
      [ testProperty "P0: detects .. in middle of path"
          prop_hasPathTraversal_middle
      , testProperty "P0: detects .. at start"
          prop_hasPathTraversal_start
      , testProperty "P1: rejects clean paths"
          prop_hasPathTraversal_clean
      ]
  , testGroup "isBlockedPath"
      [ testProperty "P1: exact match is blocked"
          prop_isBlockedPath_exact_match
      , testProperty "P1: subdirectory of blocked is blocked"
          prop_isBlockedPath_subdirectory
      , testProperty "P2: order-independent"
          prop_isBlockedPath_order_independent
      , testProperty "P2: unrelated path is not blocked"
          prop_isBlockedPath_unrelated
      ]
  , testGroup "isSystemPath edge cases"
      [ testProperty "P3: trailing slash detected"
          prop_isSystemPath_trailing_slash
      , testProperty "P3: subdirectory of system path detected"
          prop_isSystemPath_subdirectory
      ]
  ]

-- Generators

genCleanSegment :: Gen String
genCleanSegment = Gen.string (Range.linear 1 15) Gen.alphaNum

genCleanPath :: Gen FilePath
genCleanPath = do
  segments <- Gen.list (Range.linear 1 5) genCleanSegment
  pure $ "/home/user/" <> foldr1 (\a b -> a <> "/" <> b) segments

-- hasPathTraversal

prop_hasPathTraversal_middle :: Property
prop_hasPathTraversal_middle = property $ do
  prefix <- forAll genCleanSegment
  suffix <- forAll genCleanSegment
  let path = "/home/" <> prefix <> "/../" <> suffix
  assert $ hasPathTraversal path

prop_hasPathTraversal_start :: Property
prop_hasPathTraversal_start = property $ do
  suffix <- forAll genCleanSegment
  let path = "../" <> suffix
  assert $ hasPathTraversal path

prop_hasPathTraversal_clean :: Property
prop_hasPathTraversal_clean = property $ do
  path <- forAll genCleanPath
  assert $ not (hasPathTraversal path)

-- isBlockedPath

prop_isBlockedPath_exact_match :: Property
prop_isBlockedPath_exact_match = property $ do
  path <- forAll genCleanPath
  let config = SafetyConfig [] [T.pack path] True
  assert $ isBlockedPath path config

prop_isBlockedPath_subdirectory :: Property
prop_isBlockedPath_subdirectory = property $ do
  basePath <- forAll genCleanPath
  subDir <- forAll genCleanSegment
  let fullPath = basePath <> "/" <> subDir
  let config = SafetyConfig [] [T.pack basePath] True
  assert $ isBlockedPath fullPath config

prop_isBlockedPath_order_independent :: Property
prop_isBlockedPath_order_independent = property $ do
  target <- forAll genCleanPath
  other1 <- forAll genCleanPath
  other2 <- forAll genCleanPath
  let paths1 = [T.pack target, T.pack other1, T.pack other2]
  let paths2 = [T.pack other2, T.pack target, T.pack other1]
  let config1 = SafetyConfig [] paths1 True
  let config2 = SafetyConfig [] paths2 True
  isBlockedPath target config1 === isBlockedPath target config2

prop_isBlockedPath_unrelated :: Property
prop_isBlockedPath_unrelated = property $ do
  let config = SafetyConfig [] ["/tmp/blocked"] True
  path <- forAll genCleanPath
  -- genCleanPath always starts with /home/user/ so never matches /tmp/blocked
  assert $ not (isBlockedPath path config)

-- isSystemPath edge cases

prop_isSystemPath_trailing_slash :: Property
prop_isSystemPath_trailing_slash = withTests 1 $ property $ do
  assert $ isSystemPath "/etc/"
  assert $ isSystemPath "/bin/"
  assert $ isSystemPath "/usr/"

prop_isSystemPath_subdirectory :: Property
prop_isSystemPath_subdirectory = property $ do
  sysDir <- forAll $ Gen.element ["/etc", "/bin", "/usr", "/var", "/sys"]
  subPath <- forAll genCleanSegment
  assert $ isSystemPath (sysDir <> "/" <> subPath)
