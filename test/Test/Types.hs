-- | Property-based tests for Types module.
--
-- Tests JSON serialization round-trips for all domain types.
-- Category: CRITICAL (data corruption risk)
module Test.Types (properties) where

import Data.Aeson (encode, eitherDecode)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Test.Generators
  ( genConversationFile
  , genAgentConfig
  , genSafetyConfig
  , genValidationResult
  , genMessage
  , genConversationId
  , genUTCTime
  )

import Types (ConversationFile (..))

-- | All properties for the Types module.
properties :: [TestTree]
properties =
  [ testGroup "JSON Round-trips"
      [ testProperty "ConversationFile" prop_conversationFile_json_roundtrip
      , testProperty "AgentConfig" prop_agentConfig_json_roundtrip
      , testProperty "SafetyConfig" prop_safetyConfig_json_roundtrip
      , testProperty "ValidationResult" prop_validationResult_json_roundtrip
      ]
  , testGroup "Message Serialization"
      [ testProperty "Messages survive conversation serialization"
          prop_messages_survive_conversation_serialization
      ]
  ]

-- | ConversationFile - JSON Round-trip (P8)
--
-- Ensures ConversationFile can be serialized and deserialized without loss.
prop_conversationFile_json_roundtrip :: Property
prop_conversationFile_json_roundtrip = property $ do
  cf <- forAll genConversationFile
  tripping cf encode eitherDecode

-- | AgentConfig - JSON Round-trip (P8)
--
-- Ensures AgentConfig can be serialized and deserialized without loss.
prop_agentConfig_json_roundtrip :: Property
prop_agentConfig_json_roundtrip = property $ do
  config <- forAll genAgentConfig
  tripping config encode eitherDecode

-- | SafetyConfig - JSON Round-trip (P8)
--
-- Ensures SafetyConfig can be serialized and deserialized without loss.
prop_safetyConfig_json_roundtrip :: Property
prop_safetyConfig_json_roundtrip = property $ do
  sc <- forAll genSafetyConfig
  tripping sc encode eitherDecode

-- | ValidationResult - JSON Round-trip (P8)
--
-- Ensures ValidationResult can be serialized and deserialized without loss.
prop_validationResult_json_roundtrip :: Property
prop_validationResult_json_roundtrip = property $ do
  vr <- forAll genValidationResult
  tripping vr encode eitherDecode

-- | Message - Round-trip through ConversationFile (P8)
--
-- Ensures messages survive the full save/load cycle through ConversationFile.
-- This is critical because conversation persistence is the main data path.
prop_messages_survive_conversation_serialization :: Property
prop_messages_survive_conversation_serialization = property $ do
  msgs <- forAll $ Gen.list (Range.linear 0 50) genMessage
  convId <- forAll genConversationId
  now <- forAll genUTCTime

  let cf = ConversationFile
        { conversationId = convId
        , createdAt = now
        , lastUpdatedAt = now
        , messages = msgs
        }

  let encoded = encode cf
  let decoded = eitherDecode encoded

  case decoded of
    Left err -> do
      annotate ("Decode failed: " <> err)
      failure
    Right (cf' :: ConversationFile) ->
      messages cf' === msgs
