module Test.AgentCore (properties) where

import Control.Monad (when)
import qualified Data.Text as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Lumen.Agent.Core (isQuitCommand)

genQuitCommand :: Gen T.Text
genQuitCommand = Gen.element ["quit", "exit", "q", ":q"]

genNonQuitCommand :: Gen T.Text
genNonQuitCommand = Gen.choice
  [ Gen.text (Range.linear 1 50) Gen.alpha
  , Gen.text (Range.linear 1 50) Gen.alphaNum
  , Gen.constant "help"
  , Gen.constant "status"
  , Gen.constant "quitter"
  , Gen.constant " quit "
  ]

properties :: [TestTree]
properties =
  [ testGroup "isQuitCommand"
      [ testProperty "Recognizes known quit commands"  prop_isQuitCommand_accepts_quit_variants
      , testProperty "Case insensitive"                prop_isQuitCommand_case_insensitive
      , testProperty "Strips whitespace"               prop_isQuitCommand_strips_whitespace
      , testProperty "Rejects non-quit commands"       prop_isQuitCommand_rejects_non_quit
      , testProperty "Exhaustive truth table"          prop_isQuitCommand_truth_table
      ]
  ]

prop_isQuitCommand_accepts_quit_variants :: Property
prop_isQuitCommand_accepts_quit_variants = property $ do
  cmd <- forAll genQuitCommand
  assert $ isQuitCommand cmd

prop_isQuitCommand_case_insensitive :: Property
prop_isQuitCommand_case_insensitive = property $ do
  cmd <- forAll genQuitCommand
  transformed <- forAll $ Gen.choice [pure (T.toUpper cmd), pure (T.toLower cmd), pure cmd]
  assert $ isQuitCommand transformed

prop_isQuitCommand_strips_whitespace :: Property
prop_isQuitCommand_strips_whitespace = property $ do
  cmd    <- forAll genQuitCommand
  spaces <- forAll $ Gen.text (Range.linear 0 10) (Gen.element [' ', '\t', '\n'])
  assert $ isQuitCommand (spaces <> cmd <> spaces)

prop_isQuitCommand_rejects_non_quit :: Property
prop_isQuitCommand_rejects_non_quit = property $ do
  cmd <- forAll genNonQuitCommand
  when (T.strip (T.toLower cmd) `notElem` ["quit", "exit", "q", ":q"]) $
    assert $ not $ isQuitCommand cmd

prop_isQuitCommand_truth_table :: Property
prop_isQuitCommand_truth_table = property $ do
  assert $ isQuitCommand "quit"
  assert $ isQuitCommand "exit"
  assert $ isQuitCommand "q"
  assert $ isQuitCommand ":q"
  assert $ isQuitCommand "QUIT"
  assert $ isQuitCommand "  exit  "
  assert $ not $ isQuitCommand ""
  assert $ not $ isQuitCommand "help"
  assert $ not $ isQuitCommand "quit me"
  assert $ not $ isQuitCommand "quitter"
