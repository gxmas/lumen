-- | Build MessageRequest from conversation state.
--
-- Includes tool definitions so Claude can use them.
-- Phase 3 will refactor assembleRequest to accept a PromptRequest,
-- removing the direct dependency on lumen-tool-framework and
-- lumen-conversation-system.
module Lumen.LLM.PromptAssembly
  ( assembleRequest
  , defaultSystemPrompt
  ) where

import Data.Function ((&))
import qualified Data.Text as T

import Anthropic.Protocol.Message
  ( MessageRequest
  , messageRequest
  , withSystem
  , withTools
  )
import Anthropic.Types (ModelId (..), SystemPrompt (..))

import Lumen.Foundation.Types (AgentState (..), AgentConfig (..))
import Lumen.Conversation.Core (getContextWindow)
import Lumen.Tools.Catalog (allTools)

assembleRequest :: AgentState -> MessageRequest
assembleRequest state =
  let config = state.config
      msgs = getContextWindow state
      baseRequest = messageRequest
        (ModelId config.model)
        msgs
        config.maxTokens
      withSys = case config.systemPrompt of
        Nothing -> baseRequest & withSystem defaultSystemPrompt
        Just sp -> baseRequest & withSystem sp
  in withSys & withTools allTools

defaultSystemPrompt :: SystemPrompt
defaultSystemPrompt = SimpleSystem $ T.unlines
  [ "You are Lumen, a helpful AI assistant."
  , ""
  , "You communicate clearly and concisely."
  , "You think step-by-step when solving problems."
  , "You ask clarifying questions when needed."
  ]
