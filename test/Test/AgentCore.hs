-- | Property-based tests for AgentCore module.
--
-- Tests the isQuitCommand function for correct command recognition.
-- Category: MINIMAL (simple function, low risk)
module Test.AgentCore (properties) where

import Control.Monad (when)
import qualified Data.Text as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Test.Generators (genQuitCommand, genNonQuitCommand)
import AgentCore (isQuitCommand)

-- | All properties for the AgentCore module.
properties :: [TestTree]
properties =
  [ testGroup "isQuitCommand"
      [ testProperty "Recognizes known quit commands"
          prop_isQuitCommand_accepts_quit_variants
      , testProperty "Case insensitive"
          prop_isQuitCommand_case_insensitive
      , testProperty "Strips whitespace"
          prop_isQuitCommand_strips_whitespace
      , testProperty "Rejects non-quit commands"
          prop_isQuitCommand_rejects_non_quit
      , testProperty "Exhaustive truth table"
          prop_isQuitCommand_truth_table
      ]
  ]

-- | isQuitCommand - Recognizes Known Quit Commands (P2)
--
-- All known quit commands should be recognized.
prop_isQuitCommand_accepts_quit_variants :: Property
prop_isQuitCommand_accepts_quit_variants = property $ do
  cmd <- forAll genQuitCommand
  assert $ isQuitCommand cmd

-- | isQuitCommand - Case Insensitive (P2)
--
-- Quit commands should work regardless of case.
prop_isQuitCommand_case_insensitive :: Property
prop_isQuitCommand_case_insensitive = property $ do
  cmd <- forAll genQuitCommand
  transformed <- forAll $ Gen.choice
    [ pure (T.toUpper cmd)
    , pure (T.toLower cmd)
    , pure cmd
    ]
  assert $ isQuitCommand transformed

-- | isQuitCommand - Strips Whitespace (P2)
--
-- Quit commands should work with leading/trailing whitespace.
prop_isQuitCommand_strips_whitespace :: Property
prop_isQuitCommand_strips_whitespace = property $ do
  cmd <- forAll genQuitCommand
  spaces <- forAll $ Gen.text (Range.linear 0 10) (Gen.element [' ', '\t', '\n'])
  assert $ isQuitCommand (spaces <> cmd <> spaces)

-- | isQuitCommand - Rejects Non-Quit (P2)
--
-- Non-quit commands should not be recognized as quit commands.
prop_isQuitCommand_rejects_non_quit :: Property
prop_isQuitCommand_rejects_non_quit = property $ do
  cmd <- forAll genNonQuitCommand
  -- Should reject unless it happens to be a quit command
  -- (which can happen with random generation)
  when (T.strip (T.toLower cmd) `notElem` ["quit", "exit", "q", ":q"]) $
    assert $ not $ isQuitCommand cmd

-- | isQuitCommand - Exhaustive Truth Table (P2)
--
-- Test specific known cases to ensure exact behavior.
prop_isQuitCommand_truth_table :: Property
prop_isQuitCommand_truth_table = property $ do
  -- Should accept
  assert $ isQuitCommand "quit"
  assert $ isQuitCommand "exit"
  assert $ isQuitCommand "q"
  assert $ isQuitCommand ":q"
  assert $ isQuitCommand "QUIT"
  assert $ isQuitCommand "  exit  "

  -- Should reject
  assert $ not $ isQuitCommand ""
  assert $ not $ isQuitCommand "help"
  assert $ not $ isQuitCommand "quit me"
  assert $ not $ isQuitCommand "quitter"
