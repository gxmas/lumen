-- | Build MessageRequest from conversation state.
--
-- This module constructs the prompts and requests sent to the LLM.
-- Phase 1: text-only, no tools.
-- Phase 2 will add tool definitions.
module PromptAssembly
  ( -- * Request assembly
    assembleRequest
  , defaultSystemPrompt
  ) where

import Data.Function ((&))
import qualified Data.Text as T

import Anthropic.Protocol.Message
  ( MessageRequest
  , messageRequest
  , withSystem
  )
import Anthropic.Types (ModelId (..), SystemPrompt (..))

import Types (AgentState (..), AgentConfig (..))
import Conversation (getContextWindow)

-- | Assemble a MessageRequest from the current agent state.
--
-- Phase 1: Uses all messages in the conversation as context.
-- Phase 2 will add tool definitions.
assembleRequest :: AgentState -> MessageRequest
assembleRequest state =
  let config = state.config
      msgs = getContextWindow state
      baseRequest = messageRequest
        (ModelId config.model)
        msgs
        config.maxTokens
  in case config.systemPrompt of
       Nothing -> baseRequest & withSystem defaultSystemPrompt
       Just sp -> baseRequest & withSystem sp

-- | Default system prompt for the Lumen agent.
--
-- Used when no custom system prompt is provided in configuration.
defaultSystemPrompt :: SystemPrompt
defaultSystemPrompt = SimpleSystem $ T.unlines
  [ "You are Lumen, a helpful AI assistant."
  , ""
  , "You communicate clearly and concisely."
  , "You think step-by-step when solving problems."
  , "You ask clarifying questions when needed."
  ]
