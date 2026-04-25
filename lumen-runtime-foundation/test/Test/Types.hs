module Test.Types (properties) where

import Data.Aeson (encode, eitherDecode)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Test.Generators
  (genConversationFile, genAgentConfig, genSafetyConfig, genValidationResult
  , genMessage, genConversationId, genUTCTime)
import Lumen.Foundation.Types (ConversationFile (..))

properties :: [TestTree]
properties =
  [ testGroup "JSON Round-trips"
      [ testProperty "ConversationFile"  prop_conversationFile_json_roundtrip
      , testProperty "AgentConfig"       prop_agentConfig_json_roundtrip
      , testProperty "SafetyConfig"      prop_safetyConfig_json_roundtrip
      , testProperty "ValidationResult"  prop_validationResult_json_roundtrip
      ]
  , testGroup "Message Serialization"
      [ testProperty "Messages survive conversation serialization"
          prop_messages_survive_conversation_serialization ]
  ]

prop_conversationFile_json_roundtrip :: Property
prop_conversationFile_json_roundtrip = property $ do
  cf <- forAll genConversationFile
  tripping cf encode eitherDecode

prop_agentConfig_json_roundtrip :: Property
prop_agentConfig_json_roundtrip = property $ do
  config <- forAll genAgentConfig
  tripping config encode eitherDecode

prop_safetyConfig_json_roundtrip :: Property
prop_safetyConfig_json_roundtrip = property $ do
  sc <- forAll genSafetyConfig
  tripping sc encode eitherDecode

prop_validationResult_json_roundtrip :: Property
prop_validationResult_json_roundtrip = property $ do
  vr <- forAll genValidationResult
  tripping vr encode eitherDecode

prop_messages_survive_conversation_serialization :: Property
prop_messages_survive_conversation_serialization = property $ do
  msgs   <- forAll $ Gen.list (Range.linear 0 50) genMessage
  convId <- forAll genConversationId
  now    <- forAll genUTCTime
  let cf = ConversationFile { conversationId = convId, createdAt = now, lastUpdatedAt = now, messages = msgs }
  case eitherDecode (encode cf) of
    Left err  -> annotate ("Decode failed: " <> err) >> failure
    Right cf' -> messages cf' === msgs
