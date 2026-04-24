{-# LANGUAGE DeriveAnyClass #-}

-- | Shared type definitions for the Lumen agent.
--
-- This module consolidates all data types used across the agent:
-- configuration, state, storage formats, and validation results.
module Types
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

    -- * Tool types (re-exports)
  , ToolUseBlock (..)
  , ToolResultBlock (..)
  , ToolResultContent (..)
  , ToolDefinition (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- Re-exports from anthropic libraries
import Anthropic.Types
  ( MessageContent (..)
  , ContentBlock (..)
  , Role (..)
  , SystemPrompt (..)
  , StopReason (..)
  )
import Anthropic.Protocol.Message (Message (..))
import Anthropic.Types.Content.ToolUse (ToolUseBlock (..))
import Anthropic.Types.Content.ToolResult (ToolResultBlock (..), ToolResultContent (..))
import Anthropic.Protocol.Tool (ToolDefinition (..))

-- | Agent configuration.
--
-- Holds static configuration loaded at startup, including API credentials,
-- model selection, and safety settings.
data AgentConfig = AgentConfig
  { apiKey         :: !Text
    -- ^ Anthropic API key for authenticating requests
  , model          :: !Text
    -- ^ Model identifier (e.g., "claude-sonnet-4-20250514")
  , maxTokens      :: !Int
    -- ^ Maximum tokens to generate in a single response
  , systemPrompt   :: !(Maybe SystemPrompt)
    -- ^ Optional system prompt to guide the agent's behavior
  , safetyConfig   :: !SafetyConfig
    -- ^ Safety validation configuration
  , conversationId :: !Text
    -- ^ Unique identifier for this conversation session
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Safety configuration.
--
-- Controls which operations are allowed during tool execution.
-- Phase 1 doesn't use this yet, but the type is defined for Phase 2.
data SafetyConfig = SafetyConfig
  { allowedPaths    :: ![Text]
    -- ^ Whitelist of file paths the agent can access
  , blockedPaths    :: ![Text]
    -- ^ Blacklist of file paths the agent must never access
  , allowSystemPaths :: !Bool
    -- ^ Whether to allow access to system directories (/etc, /sys, etc.)
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Agent runtime state.
--
-- Tracks the current conversation history and other mutable state
-- during a session.
data AgentState = AgentState
  { config       :: !AgentConfig
    -- ^ Immutable configuration
  , conversation :: ![Message]
    -- ^ Full conversation history (all messages so far)
  , turnCount    :: !Int
    -- ^ Number of turns completed (incremented after each user/assistant pair)
  }
  deriving stock (Eq, Show, Generic)

-- | Conversation file format for JSON persistence.
--
-- This is what gets saved to disk and loaded on startup.
-- Contains metadata plus the message history.
data ConversationFile = ConversationFile
  { conversationId :: !Text
    -- ^ Unique identifier matching AgentConfig.conversationId
  , createdAt      :: !UTCTime
    -- ^ When this conversation was first created
  , lastUpdatedAt  :: !UTCTime
    -- ^ When this conversation was last modified
  , messages       :: ![Message]
    -- ^ All messages in the conversation
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Result of a validation check.
--
-- Used by guardrails to approve or reject an action.
-- Phase 1 doesn't use this yet, but defined for Phase 2.
data ValidationResult
  = Allowed
    -- ^ Action is permitted
  | Blocked !Text
    -- ^ Action is forbidden, with reason
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)
