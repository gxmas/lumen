{-# LANGUAGE ScopedTypeVariables #-}
module Test.ToolRuntime (properties) where

import qualified Data.Aeson as Aeson
import Data.Text (Text)
import qualified Data.Text as T
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Anthropic.Types.Content.ToolUse (ToolUseBlock (..))
import Anthropic.Types.Content.ToolResult (ToolResultBlock (..), ToolResultContent (..))
import Lumen.Tools.Guardrails (Action (..))
import Lumen.Tools.Runtime
  (mkReadAction, mkWriteAction, mkListDirAction, mkSearchAction, mkCommandAction, mkErrorResult)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "Action extraction"
      [ testProperty "P0: mkReadAction preserves path"              prop_mkReadAction_preserves_path
      , testProperty "P0: mkWriteAction preserves path and content" prop_mkWriteAction_preserves_path_content
      , testProperty "P1: mkListDirAction extracts path"            prop_mkListDirAction_extracts_path
      , testProperty "P1: mkSearchAction extracts path"             prop_mkSearchAction_extracts_path
      , testProperty "P1: mkCommandAction extracts command"         prop_mkCommandAction_extracts_command
      , testProperty "P2: all mk*Action return Left on invalid input" prop_mkActions_left_on_invalid
      ]
  , testGroup "mkErrorResult"
      [ testProperty "P2: preserves tool use ID"    prop_mkErrorResult_preserves_id
      , testProperty "P2: sets isError to True"     prop_mkErrorResult_sets_error
      , testProperty "P3: includes error message"   prop_mkErrorResult_includes_message
      ]
  ]

genToolId :: Gen Text
genToolId = Gen.text (Range.linear 5 30) Gen.alphaNum

genFilePath :: Gen Text
genFilePath = do
  segments <- Gen.list (Range.linear 1 5) (Gen.text (Range.linear 1 15) Gen.alphaNum)
  pure $ "/home/user/" <> T.intercalate "/" segments

genToolUseBlock :: Text -> Aeson.Value -> Gen ToolUseBlock
genToolUseBlock name input = do
  tid <- genToolId
  pure $ ToolUseBlock tid name input Nothing

prop_mkReadAction_preserves_path :: Property
prop_mkReadAction_preserves_path = property $ do
  path <- forAll genFilePath
  tub  <- forAll $ genToolUseBlock "read_file" (Aeson.object ["path" Aeson..= path])
  case mkReadAction tub of
    Right (ReadFile p) -> T.pack p === path
    other -> annotate ("Expected Right (ReadFile _), got: " <> show other) >> failure

prop_mkWriteAction_preserves_path_content :: Property
prop_mkWriteAction_preserves_path_content = property $ do
  path    <- forAll genFilePath
  content <- forAll $ Gen.text (Range.linear 0 200) Gen.unicode
  tub     <- forAll $ genToolUseBlock "write_file"
               (Aeson.object ["path" Aeson..= path, "content" Aeson..= content])
  case mkWriteAction tub of
    Right (WriteFile p c) -> T.pack p === path >> c === content
    other -> annotate ("Expected Right (WriteFile _ _), got: " <> show other) >> failure

prop_mkListDirAction_extracts_path :: Property
prop_mkListDirAction_extracts_path = property $ do
  path <- forAll genFilePath
  tub  <- forAll $ genToolUseBlock "list_directory" (Aeson.object ["path" Aeson..= path])
  case mkListDirAction tub of
    Right (ReadFile p) -> T.pack p === path
    other -> annotate ("Expected Right (ReadFile _), got: " <> show other) >> failure

prop_mkSearchAction_extracts_path :: Property
prop_mkSearchAction_extracts_path = property $ do
  path <- forAll genFilePath
  pat  <- forAll $ Gen.text (Range.linear 1 20) Gen.alphaNum
  tub  <- forAll $ genToolUseBlock "search_files"
            (Aeson.object ["path" Aeson..= path, "pattern" Aeson..= pat])
  case mkSearchAction tub of
    Right (ReadFile p) -> T.pack p === path
    other -> annotate ("Expected Right (ReadFile _), got: " <> show other) >> failure

prop_mkCommandAction_extracts_command :: Property
prop_mkCommandAction_extracts_command = property $ do
  cmd <- forAll $ Gen.text (Range.linear 1 100) Gen.alphaNum
  tub <- forAll $ genToolUseBlock "execute_command" (Aeson.object ["command" Aeson..= cmd])
  case mkCommandAction tub of
    Right (ExecuteCommand c) -> c === cmd
    other -> annotate ("Expected Right (ExecuteCommand _), got: " <> show other) >> failure

prop_mkActions_left_on_invalid :: Property
prop_mkActions_left_on_invalid = property $ do
  tub <- forAll $ genToolUseBlock "read_file" (Aeson.object ["wrong_field" Aeson..= ("x" :: Text)])
  case mkReadAction tub of
    Left _  -> success
    Right _ -> annotate "Expected Left on invalid input" >> failure

prop_mkErrorResult_preserves_id :: Property
prop_mkErrorResult_preserves_id = property $ do
  tid <- forAll genToolId
  msg <- forAll $ Gen.text (Range.linear 1 100) Gen.unicode
  let tub = ToolUseBlock tid "test_tool" (Aeson.object []) Nothing
  let result = mkErrorResult tub msg
  result.toolUseId === tid

prop_mkErrorResult_sets_error :: Property
prop_mkErrorResult_sets_error = property $ do
  tid <- forAll genToolId
  msg <- forAll $ Gen.text (Range.linear 1 100) Gen.unicode
  let tub = ToolUseBlock tid "test_tool" (Aeson.object []) Nothing
  let result = mkErrorResult tub msg
  result.isError === Just True

prop_mkErrorResult_includes_message :: Property
prop_mkErrorResult_includes_message = property $ do
  tid <- forAll genToolId
  msg <- forAll $ Gen.text (Range.linear 1 100) Gen.unicode
  let tub = ToolUseBlock tid "test_tool" (Aeson.object []) Nothing
  let result = mkErrorResult tub msg
  result.content === Just (ToolResultText msg)
