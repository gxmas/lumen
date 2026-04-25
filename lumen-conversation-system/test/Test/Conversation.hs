module Test.Conversation (properties) where

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Test.Generators (genAgentState, genMessage)
import Lumen.Conversation.Core
  (addMessage, addMessages, getRecent, getContextWindow, getAll, messageCount, isEmpty)
import Lumen.Foundation.Types (AgentState (..))

properties :: [TestTree]
properties =
  [ testGroup "Generator Validity"
      [ testProperty "genAgentState produces valid states" prop_genAgentState_valid ]
  , testGroup "addMessage"
      [ testProperty "Increases length by 1"   prop_addMessage_increases_length
      , testProperty "Appends to end"           prop_addMessage_appends ]
  , testGroup "addMessages"
      [ testProperty "Equivalent to foldr addMessage" prop_addMessages_equivalent_to_foldr ]
  , testGroup "getRecent"
      [ testProperty "Returns correct count"     prop_getRecent_returns_correct_count
      , testProperty "Returns suffix"            prop_getRecent_is_suffix
      , testProperty "Idempotent"                prop_getRecent_idempotent ]
  , testGroup "Conversation properties"
      [ testProperty "messageCount equals length" prop_messageCount_equals_length
      , testProperty "isEmpty iff zero length"    prop_isEmpty_iff_zero_length
      , testProperty "getAll returns all messages" prop_getAll_returns_all ]
  , testGroup "getContextWindow"
      [ testProperty "Phase 1: returns all messages" prop_getContextWindow_returns_all_phase1 ]
  , testGroup "Round-trip properties"
      [ testProperty "addMessage then getRecent 1" prop_addMessage_getRecent_1_returns_added ]
  ]

prop_genAgentState_valid :: Property
prop_genAgentState_valid = property $ do
  state <- forAll genAgentState
  assert $ turnCount state >= 0

prop_addMessage_increases_length :: Property
prop_addMessage_increases_length = property $ do
  state <- forAll genAgentState
  msg   <- forAll genMessage
  length (conversation (addMessage msg state)) === length (conversation state) + 1

prop_addMessage_appends :: Property
prop_addMessage_appends = property $ do
  state <- forAll genAgentState
  msg   <- forAll genMessage
  conversation (addMessage msg state) === conversation state ++ [msg]

prop_addMessages_equivalent_to_foldr :: Property
prop_addMessages_equivalent_to_foldr = property $ do
  state <- forAll genAgentState
  msgs  <- forAll $ Gen.list (Range.linear 0 20) genMessage
  conversation (addMessages msgs state) === conversation (foldl (flip addMessage) state msgs)

prop_getRecent_returns_correct_count :: Property
prop_getRecent_returns_correct_count = property $ do
  state <- forAll genAgentState
  n     <- forAll $ Gen.int (Range.linear 0 150)
  length (getRecent n state) === min n (length $ conversation state)

prop_getRecent_is_suffix :: Property
prop_getRecent_is_suffix = property $ do
  state <- forAll genAgentState
  n     <- forAll $ Gen.int (Range.linear 1 100)
  let all' = conversation state
  getRecent n state === drop (length all' - min n (length all')) all'

prop_getRecent_idempotent :: Property
prop_getRecent_idempotent = property $ do
  state <- forAll genAgentState
  n     <- forAll $ Gen.int (Range.linear 0 100)
  getRecent n state === getRecent n state

prop_messageCount_equals_length :: Property
prop_messageCount_equals_length = property $ do
  state <- forAll genAgentState
  messageCount state === length (conversation state)

prop_isEmpty_iff_zero_length :: Property
prop_isEmpty_iff_zero_length = property $ do
  state <- forAll genAgentState
  isEmpty state === null (conversation state)

prop_getAll_returns_all :: Property
prop_getAll_returns_all = property $ do
  state <- forAll genAgentState
  getAll state === conversation state

prop_getContextWindow_returns_all_phase1 :: Property
prop_getContextWindow_returns_all_phase1 = property $ do
  state <- forAll genAgentState
  getContextWindow state === conversation state

prop_addMessage_getRecent_1_returns_added :: Property
prop_addMessage_getRecent_1_returns_added = property $ do
  state <- forAll genAgentState
  msg   <- forAll genMessage
  getRecent 1 (addMessage msg state) === [msg]
