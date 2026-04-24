module Test.Generators
  ( genMessage, genMessageContent, genContentBlock, genRole
  , genAgentState, genAgentConfig, genSafetyConfig
  , genConversationFile, genValidationResult
  , genUTCTime, genText, genConversationId
  , genQuitCommand, genNonQuitCommand
  , testConfig
  ) where

import Data.Text (Text)
import Data.Time (UTCTime (..), secondsToDiffTime)
import Data.Time.Calendar (Day (ModifiedJulianDay))

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Anthropic.Types (MessageContent (..), ContentBlock (..), Role (..))
import Anthropic.Types.Content.Text (TextBlock (..))
import Anthropic.Protocol.Message (Message (..))

import Lumen.Foundation.Types
  ( AgentState (..), AgentConfig (..), SafetyConfig (..)
  , ConversationFile (..), ValidationResult (..)
  )

genMessage :: Gen Message
genMessage = Message <$> genRole <*> genMessageContent

genMessageContent :: Gen MessageContent
genMessageContent = Gen.choice
  [ TextMessage <$> genText (Range.linear 0 500)
  , BlockMessage <$> Gen.list (Range.linear 1 10) genContentBlock
  ]

genContentBlock :: Gen ContentBlock
genContentBlock = do
  txt <- genText (Range.linear 0 200)
  pure $ TextContent $ TextBlock { text = txt, citations = Nothing, cacheControl = Nothing }

genRole :: Gen Role
genRole = Gen.element [User, Assistant]

genAgentState :: Gen AgentState
genAgentState = do
  msgs <- Gen.list (Range.linear 0 100) genMessage
  turnCnt <- Gen.int (Range.linear 0 50)
  config <- genAgentConfig
  pure AgentState { config = config, conversation = msgs, turnCount = turnCnt }

genAgentConfig :: Gen AgentConfig
genAgentConfig = do
  key    <- genText (Range.linear 10 100)
  model  <- Gen.element ["claude-sonnet-4-20250514", "claude-opus-4", "claude-haiku-3"]
  tokens <- Gen.int (Range.linear 100 8192)
  convId <- genConversationId
  safety <- genSafetyConfig
  pure AgentConfig
    { apiKey = key, model = model, maxTokens = tokens
    , systemPrompt = Nothing, safetyConfig = safety, conversationId = convId
    }

genSafetyConfig :: Gen SafetyConfig
genSafetyConfig = do
  allowed  <- Gen.list (Range.linear 0 10) genPath
  blocked  <- Gen.list (Range.linear 0 10) genPath
  allowSys <- Gen.bool
  pure SafetyConfig { allowedPaths = allowed, blockedPaths = blocked, allowSystemPaths = allowSys }
  where genPath = genText (Range.linear 1 100)

genConversationFile :: Gen ConversationFile
genConversationFile = do
  convId  <- genConversationId
  created <- genUTCTime
  updated <- genUTCTime
  msgs    <- Gen.list (Range.linear 0 100) genMessage
  pure ConversationFile
    { conversationId = convId, createdAt = created
    , lastUpdatedAt = updated, messages = msgs
    }

genValidationResult :: Gen ValidationResult
genValidationResult = Gen.choice
  [ pure Allowed
  , Blocked <$> genText (Range.linear 1 200)
  ]

genUTCTime :: Gen UTCTime
genUTCTime = do
  day  <- ModifiedJulianDay <$> Gen.integral (Range.linear 58849 62502)
  secs <- Gen.integral (Range.linear 0 86400)
  pure $ UTCTime day (secondsToDiffTime secs)

genText :: Range Int -> Gen Text
genText range = Gen.text range Gen.unicode

genConversationId :: Gen Text
genConversationId = Gen.choice
  [ Gen.text (Range.linear 1 50) Gen.alphaNum
  , Gen.constant "default"
  , Gen.constant "test-123"
  ]

genQuitCommand :: Gen Text
genQuitCommand = Gen.element ["quit", "exit", "q", ":q"]

genNonQuitCommand :: Gen Text
genNonQuitCommand = Gen.choice
  [ Gen.text (Range.linear 1 50) Gen.alpha
  , Gen.text (Range.linear 1 50) Gen.alphaNum
  , Gen.constant "help"
  , Gen.constant "status"
  , Gen.constant "quitter"
  , Gen.constant " quit "
  ]

testConfig :: AgentConfig
testConfig = AgentConfig
  { apiKey = "test-key-12345"
  , model = "claude-sonnet-4-20250514"
  , maxTokens = 4096
  , systemPrompt = Nothing
  , safetyConfig = SafetyConfig { allowedPaths = [], blockedPaths = [], allowSystemPaths = False }
  , conversationId = "test-conversation"
  }
