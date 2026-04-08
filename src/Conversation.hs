-- | Pure message history management.
--
-- This module provides functions for managing the conversation history
-- in memory. All functions are pure - no I/O operations.
module Conversation
  ( -- * Adding messages
    addMessage
  , addMessages

    -- * Retrieving messages
  , getRecent
  , getContextWindow
  , getAll

    -- * Conversation properties
  , messageCount
  , isEmpty
  ) where

import Types (Message, AgentState (..))

-- | Add a single message to the conversation history.
--
-- Appends to the end of the message list. Returns updated state.
addMessage :: Message -> AgentState -> AgentState
addMessage msg state = state { conversation = state.conversation ++ [msg] }

-- | Add multiple messages to the conversation history.
--
-- Useful when adding a user message and assistant response together.
addMessages :: [Message] -> AgentState -> AgentState
addMessages msgs state = state { conversation = state.conversation ++ msgs }

-- | Get the most recent N messages from the conversation.
--
-- Returns messages in chronological order (oldest first).
-- If N is greater than the total number of messages, returns all messages.
--
-- Useful for displaying recent conversation context to the user.
getRecent :: Int -> AgentState -> [Message]
getRecent n state
  | n <= 0    = []
  | otherwise = drop (length state.conversation - n) state.conversation

-- | Get all messages in the conversation.
--
-- Returns the full conversation history in chronological order.
getAll :: AgentState -> [Message]
getAll state = state.conversation

-- | Get messages that fit within a context window.
--
-- Phase 1: Returns all messages (no truncation yet).
-- Phase 2 will implement smart truncation based on token counts.
--
-- The context window is what gets sent to the LLM in each request.
getContextWindow :: AgentState -> [Message]
getContextWindow state = state.conversation

-- | Count the number of messages in the conversation.
messageCount :: AgentState -> Int
messageCount state = length state.conversation

-- | Check if the conversation is empty (no messages yet).
isEmpty :: AgentState -> Bool
isEmpty state = null state.conversation
