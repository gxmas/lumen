-- | Property-based tests for Conversation module.
--
-- Tests pure conversation management functions.
-- Category: CRITICAL (foundational domain logic)
module Test.Conversation (properties) where

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Test.Generators (genAgentState, genMessage)

import Conversation
  ( addMessage
  , addMessages
  , getRecent
  , getContextWindow
  , getAll
  , messageCount
  , isEmpty
  )
import Types (AgentState (..))

-- | All properties for the Conversation module.
properties :: [TestTree]
properties =
  [ testGroup "Generator Validity"
      [ testProperty "genAgentState produces valid states"
          prop_genAgentState_valid
      ]
  , testGroup "addMessage"
      [ testProperty "Increases length by 1"
          prop_addMessage_increases_length
      , testProperty "Appends to end"
          prop_addMessage_appends
      ]
  , testGroup "addMessages"
      [ testProperty "Equivalent to foldr addMessage"
          prop_addMessages_equivalent_to_foldr
      ]
  , testGroup "getRecent"
      [ testProperty "Returns correct count"
          prop_getRecent_returns_correct_count
      , testProperty "Returns suffix of conversation"
          prop_getRecent_is_suffix
      , testProperty "Idempotent"
          prop_getRecent_idempotent
      ]
  , testGroup "Conversation properties"
      [ testProperty "messageCount equals length"
          prop_messageCount_equals_length
      , testProperty "isEmpty iff zero length"
          prop_isEmpty_iff_zero_length
      , testProperty "getAll returns all messages"
          prop_getAll_returns_all
      ]
  , testGroup "getContextWindow"
      [ testProperty "Phase 1: returns all messages"
          prop_getContextWindow_returns_all_phase1
      ]
  , testGroup "Round-trip properties"
      [ testProperty "addMessage then getRecent 1 returns added message"
          prop_addMessage_getRecent_1_returns_added
      ]
  ]

-- | Generator Validity (P0)
--
-- Ensure generated AgentStates are structurally valid.
prop_genAgentState_valid :: Property
prop_genAgentState_valid = property $ do
  state <- forAll genAgentState
  -- Basic structural validity
  assert $ turnCount state >= 0
  assert $ length (conversation state) >= 0

-- | addMessage - Length Invariant (P3)
--
-- Adding a message increases conversation length by exactly 1.
prop_addMessage_increases_length :: Property
prop_addMessage_increases_length = property $ do
  state <- forAll genAgentState
  msg <- forAll genMessage
  let state' = addMessage msg state
  length (conversation state') === length (conversation state) + 1

-- | addMessage - Order Preservation (P3)
--
-- Added message appears at the end of the conversation.
prop_addMessage_appends :: Property
prop_addMessage_appends = property $ do
  state <- forAll genAgentState
  msg <- forAll genMessage
  let state' = addMessage msg state
  conversation state' === conversation state ++ [msg]

-- | addMessages - Composition (P7)
--
-- addMessages is equivalent to folding addMessage.
prop_addMessages_equivalent_to_foldr :: Property
prop_addMessages_equivalent_to_foldr = property $ do
  state <- forAll genAgentState
  msgs <- forAll $ Gen.list (Range.linear 0 20) genMessage
  let state1 = addMessages msgs state
  let state2 = foldl (flip addMessage) state msgs
  conversation state1 === conversation state2

-- | getRecent - Postcondition (P2)
--
-- getRecent returns at most N messages.
prop_getRecent_returns_correct_count :: Property
prop_getRecent_returns_correct_count = property $ do
  state <- forAll genAgentState
  n <- forAll $ Gen.int (Range.linear 0 150)
  let recent = getRecent n state
  length recent === min n (length $ conversation state)

-- | getRecent - Suffix Property (P2)
--
-- getRecent returns the last N messages.
prop_getRecent_is_suffix :: Property
prop_getRecent_is_suffix = property $ do
  state <- forAll genAgentState
  n <- forAll $ Gen.int (Range.linear 1 100)
  let recent = getRecent n state
  let allMsgs = conversation state
  -- recent should be a suffix of allMsgs
  recent === drop (length allMsgs - min n (length allMsgs)) allMsgs

-- | getRecent - Idempotence (P4)
--
-- Calling getRecent twice with same args returns same result.
prop_getRecent_idempotent :: Property
prop_getRecent_idempotent = property $ do
  state <- forAll genAgentState
  n <- forAll $ Gen.int (Range.linear 0 100)
  getRecent n state === getRecent n state

-- | messageCount - Postcondition (P2)
--
-- messageCount equals the length of the conversation.
prop_messageCount_equals_length :: Property
prop_messageCount_equals_length = property $ do
  state <- forAll genAgentState
  messageCount state === length (conversation state)

-- | isEmpty - Postcondition (P2)
--
-- isEmpty is true iff conversation is empty.
prop_isEmpty_iff_zero_length :: Property
prop_isEmpty_iff_zero_length = property $ do
  state <- forAll genAgentState
  isEmpty state === null (conversation state)

-- | getAll - Identity (P2)
--
-- getAll returns the entire conversation.
prop_getAll_returns_all :: Property
prop_getAll_returns_all = property $ do
  state <- forAll genAgentState
  getAll state === conversation state

-- | getContextWindow - Currently No-Op (P2)
--
-- Phase 1: getContextWindow returns all messages.
prop_getContextWindow_returns_all_phase1 :: Property
prop_getContextWindow_returns_all_phase1 = property $ do
  state <- forAll genAgentState
  -- Phase 1: returns everything
  getContextWindow state === conversation state

-- | addMessage then getRecent - Round-trip (P8)
--
-- The most recently added message can be retrieved with getRecent 1.
prop_addMessage_getRecent_1_returns_added :: Property
prop_addMessage_getRecent_1_returns_added = property $ do
  state <- forAll genAgentState
  msg <- forAll genMessage
  let state' = addMessage msg state
  let recent = getRecent 1 state'
  recent === [msg]
