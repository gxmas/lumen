-- | Pure message history management.
--
-- All functions are pure — no I/O operations.
module Lumen.Conversation.Core
  ( addMessage
  , addMessages
  , getRecent
  , getContextWindow
  , getAll
  , messageCount
  , isEmpty
  ) where

import Lumen.Foundation.Types (Message, AgentState (..))

addMessage :: Message -> AgentState -> AgentState
addMessage msg state = state { conversation = state.conversation ++ [msg] }

addMessages :: [Message] -> AgentState -> AgentState
addMessages msgs state = state { conversation = state.conversation ++ msgs }

getRecent :: Int -> AgentState -> [Message]
getRecent n state
  | n <= 0    = []
  | otherwise = drop (length state.conversation - n) state.conversation

getAll :: AgentState -> [Message]
getAll state = state.conversation

-- | Phase 1: returns all messages. Phase 3 will apply token budgeting.
getContextWindow :: AgentState -> [Message]
getContextWindow state = state.conversation

messageCount :: AgentState -> Int
messageCount state = length state.conversation

isEmpty :: AgentState -> Bool
isEmpty state = null state.conversation
