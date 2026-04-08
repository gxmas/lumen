-- | Shared generators for property-based testing.
--
-- This module provides Hedgehog generators for all domain types
-- used across the Lumen agent test suite.
module Test.Generators
  ( -- * Core generators
    genMessage
  , genMessageContent
  , genContentBlock
  , genRole
  , genAgentState
  , genAgentConfig
  , genSafetyConfig
  , genConversationFile
  , genValidationResult

    -- * Utility generators
  , genUTCTime
  , genText
  , genConversationId
  , genQuitCommand
  , genNonQuitCommand

    -- * Test fixtures
  , testConfig
  ) where

import Data.Text (Text)
import Data.Time (UTCTime (..), secondsToDiffTime)
import Data.Time.Calendar (Day (ModifiedJulianDay))

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Anthropic.Types
  ( MessageContent (..)
  , ContentBlock (..)
  , Role (..)
  )
import Anthropic.Types.Content.Text (TextBlock (..))
import Anthropic.Protocol.Message (Message (..))

import Types
  ( AgentState (..)
  , AgentConfig (..)
  , SafetyConfig (..)
  , ConversationFile (..)
  , ValidationResult (..)
  )

-- | Generate a Message with random role and content.
genMessage :: Gen Message
genMessage = do
  role <- genRole
  content <- genMessageContent
  pure $ Message role content

-- | Generate MessageContent (either TextMessage or BlockMessage).
genMessageContent :: Gen MessageContent
genMessageContent = Gen.choice
  [ TextMessage <$> genText (Range.linear 0 500)
  , BlockMessage <$> Gen.list (Range.linear 1 10) genContentBlock
  ]

-- | Generate a ContentBlock (Phase 1: only TextContent).
genContentBlock :: Gen ContentBlock
genContentBlock = do
  txt <- genText (Range.linear 0 200)
  pure $ TextContent $ TextBlock
    { text = txt
    , citations = Nothing
    , cacheControl = Nothing
    }

-- | Generate a Role (User or Assistant).
genRole :: Gen Role
genRole = Gen.element [User, Assistant]

-- | Generate AgentState with random conversation and config.
genAgentState :: Gen AgentState
genAgentState = do
  msgs <- Gen.list (Range.linear 0 100) genMessage
  turnCnt <- Gen.int (Range.linear 0 50)
  config <- genAgentConfig
  pure $ AgentState
    { config = config
    , conversation = msgs
    , turnCount = turnCnt
    }

-- | Generate AgentConfig with reasonable defaults.
genAgentConfig :: Gen AgentConfig
genAgentConfig = do
  key <- genText (Range.linear 10 100)
  model <- Gen.element
    [ "claude-sonnet-4-20250514"
    , "claude-opus-4"
    , "claude-haiku-3"
    ]
  tokens <- Gen.int (Range.linear 100 8192)
  convId <- genConversationId
  safetyConf <- genSafetyConfig
  -- Phase 1: systemPrompt is always Nothing
  pure $ AgentConfig
    { apiKey = key
    , model = model
    , maxTokens = tokens
    , systemPrompt = Nothing
    , safetyConfig = safetyConf
    , conversationId = convId
    }

-- | Generate SafetyConfig with random path lists.
genSafetyConfig :: Gen SafetyConfig
genSafetyConfig = do
  allowed <- Gen.list (Range.linear 0 10) genPath
  blocked <- Gen.list (Range.linear 0 10) genPath
  allowSys <- Gen.bool
  pure $ SafetyConfig
    { allowedPaths = allowed
    , blockedPaths = blocked
    , allowSystemPaths = allowSys
    }
  where
    genPath = genText (Range.linear 1 100)

-- | Generate ConversationFile with timestamps and messages.
genConversationFile :: Gen ConversationFile
genConversationFile = do
  convId <- genConversationId
  created <- genUTCTime
  updated <- genUTCTime
  msgs <- Gen.list (Range.linear 0 100) genMessage
  pure $ ConversationFile
    { conversationId = convId
    , createdAt = created
    , lastUpdatedAt = updated
    , messages = msgs
    }

-- | Generate ValidationResult (Allowed or Blocked).
genValidationResult :: Gen ValidationResult
genValidationResult = Gen.choice
  [ pure Allowed
  , Blocked <$> genText (Range.linear 1 200)
  ]

-- | Generate a UTCTime in a reasonable range.
genUTCTime :: Gen UTCTime
genUTCTime = do
  -- Days between 2020 and 2030
  day <- ModifiedJulianDay <$> Gen.integral (Range.linear 58849 62502)
  -- Seconds in a day
  secs <- Gen.integral (Range.linear 0 86400)
  pure $ UTCTime day (secondsToDiffTime secs)

-- | Generate random Text with the given length range.
genText :: Range Int -> Gen Text
genText range = Gen.text range Gen.unicode

-- | Generate a valid conversation ID.
genConversationId :: Gen Text
genConversationId = Gen.choice
  [ Gen.text (Range.linear 1 50) Gen.alphaNum
  , Gen.constant "default"
  , Gen.constant "test-123"
  ]

-- | Generate a known quit command.
genQuitCommand :: Gen Text
genQuitCommand = Gen.element ["quit", "exit", "q", ":q"]

-- | Generate text that is NOT a quit command.
genNonQuitCommand :: Gen Text
genNonQuitCommand = Gen.choice
  [ Gen.text (Range.linear 1 50) Gen.alpha
  , Gen.text (Range.linear 1 50) Gen.alphaNum
  , Gen.constant "help"
  , Gen.constant "status"
  , Gen.constant "quitter"  -- Contains "quit" but not exact
  , Gen.constant " quit "   -- Spacing variations (will get stripped)
  ]

-- | Fixed test configuration for deterministic tests.
testConfig :: AgentConfig
testConfig = AgentConfig
  { apiKey = "test-key-12345"
  , model = "claude-sonnet-4-20250514"
  , maxTokens = 4096
  , systemPrompt = Nothing
  , safetyConfig = SafetyConfig
      { allowedPaths = []
      , blockedPaths = []
      , allowSystemPaths = False
      }
  , conversationId = "test-conversation"
  }
