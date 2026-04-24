{-# LANGUAGE DeriveAnyClass #-}

-- | Shared type definitions for the Lumen agent.
--
-- This module consolidates all data types used across the agent:
-- configuration, state, storage formats, and validation results.
module Lumen.Foundation.Types
  ( -- * Configuration
    AgentConfig (..)
  , SafetyConfig (..)

    -- * State
  , AgentState (..)

    -- * Storage
  , ConversationFile (..)

    -- * Validation
  , ValidationResult (..)

    -- * Re-exports from anthropic libraries
  , Message (..)
  , MessageContent (..)
  , ContentBlock (..)
  , Role (..)
  , SystemPrompt (..)
  , StopReason (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

import Anthropic.Types
  ( MessageContent (..)
  , ContentBlock (..)
  , Role (..)
  , SystemPrompt (..)
  , StopReason (..)
  )
import Anthropic.Protocol.Message (Message (..))

-- | Agent configuration.
data AgentConfig = AgentConfig
  { apiKey         :: !Text
  , model          :: !Text
  , maxTokens      :: !Int
  , systemPrompt   :: !(Maybe SystemPrompt)
  , safetyConfig   :: !SafetyConfig
  , conversationId :: !Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Safety configuration.
data SafetyConfig = SafetyConfig
  { allowedPaths    :: ![Text]
  , blockedPaths    :: ![Text]
  , allowSystemPaths :: !Bool
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Agent runtime state.
data AgentState = AgentState
  { config       :: !AgentConfig
  , conversation :: ![Message]
  , turnCount    :: !Int
  }
  deriving stock (Eq, Show, Generic)

-- | Conversation file format for JSON persistence.
data ConversationFile = ConversationFile
  { conversationId :: !Text
  , createdAt      :: !UTCTime
  , lastUpdatedAt  :: !UTCTime
  , messages       :: ![Message]
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Result of a validation check.
data ValidationResult
  = Allowed
  | Blocked !Text
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)
