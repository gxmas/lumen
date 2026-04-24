module Test.Storage (properties) where

import qualified Data.Text as T
import Data.List (isInfixOf, isSuffixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog

import Test.Generators (genConversationId)
import Lumen.Foundation.Storage (conversationPath)

properties :: [TestTree]
properties =
  [ testGroup "conversationPath"
      [ testProperty "Contains conversation ID"   prop_conversationPath_contains_id
      , testProperty "In .lumen directory"        prop_conversationPath_in_lumen_dir
      , testProperty "Has .json extension"        prop_conversationPath_json_extension
      , testProperty "Deterministic (idempotent)" prop_conversationPath_deterministic
      ]
  ]

prop_conversationPath_contains_id :: Property
prop_conversationPath_contains_id = property $ do
  convId <- forAll genConversationId
  path   <- evalIO $ conversationPath convId
  assert $ T.unpack convId `isInfixOf` path

prop_conversationPath_in_lumen_dir :: Property
prop_conversationPath_in_lumen_dir = property $ do
  convId <- forAll genConversationId
  path   <- evalIO $ conversationPath convId
  assert $ ".lumen/conversations" `isInfixOf` path

prop_conversationPath_json_extension :: Property
prop_conversationPath_json_extension = property $ do
  convId <- forAll genConversationId
  path   <- evalIO $ conversationPath convId
  assert $ ".json" `isSuffixOf` path

prop_conversationPath_deterministic :: Property
prop_conversationPath_deterministic = property $ do
  convId <- forAll genConversationId
  path1  <- evalIO $ conversationPath convId
  path2  <- evalIO $ conversationPath convId
  path1 === path2
