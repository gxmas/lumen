-- | REPL loop orchestration.
--
-- This module coordinates the main agent loop:
-- initialize -> mainLoop -> runTurn (repeatedly)
--
-- Phase 1: Text-only responses, no tool execution.
-- Phase 2 will add tool execution handling.
module AgentCore
  ( -- * Initialization
    initialize

    -- * Main loop
  , mainLoop

    -- * Single turn
  , runTurn

    -- * Utilities
  , isQuitCommand
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.IO (hFlush, stdout)

import Anthropic.Protocol.Message
  ( userMessage
  , assistantMessage
  , MessageResponse (..)
  )
import Anthropic.Types
  ( ContentBlock (..)
  , MessageContent (..)
  )
import Anthropic.Types.Content.Text (TextBlock (..))

import qualified Types
import Types (AgentState (..), AgentConfig (..))
import Conversation (addMessage)
import Storage (saveConversation, loadConversation)
import LLMClient (ClientHandle, sendRequest, LLMError (..))
import PromptAssembly (assembleRequest)

-- | Initialize agent state from configuration.
--
-- Attempts to load existing conversation from disk.
-- If none exists, starts a fresh conversation.
initialize :: AgentConfig -> IO AgentState
initialize config = do
  mbConv <- loadConversation config.conversationId
  case mbConv of
    Nothing -> do
      -- Fresh conversation
      putStrLn $ "Starting new conversation: " <> T.unpack config.conversationId
      pure AgentState
        { config       = config
        , conversation = []
        , turnCount    = 0
        }
    Just (convFile :: Types.ConversationFile) -> do
      -- Resume existing conversation
      putStrLn $ "Resuming conversation: " <> T.unpack config.conversationId
      let msgs = convFile.messages
      putStrLn $ "Loaded " <> show (length msgs) <> " messages"
      pure AgentState
        { config       = config
        , conversation = msgs
        , turnCount    = length msgs `div` 2
        }

-- | Main REPL loop.
--
-- Repeatedly:
-- 1. Get user input
-- 2. Call runTurn to process it
-- 3. Save conversation
-- 4. Repeat until user quits
mainLoop :: ClientHandle -> AgentState -> IO ()
mainLoop client state = do
  -- Display prompt
  putStr "> "
  hFlush stdout

  -- Read user input
  userInput <- TIO.getLine

  -- Check for quit command
  if isQuitCommand userInput
    then do
      putStrLn "Goodbye!"
      saveConversation state
    else do
      -- Process the turn
      newState <- runTurn client userInput state

      -- Save after each turn
      saveConversation newState

      -- Continue loop
      mainLoop client newState

-- | Run a single turn of conversation.
--
-- Takes user input, sends to LLM, displays response, updates state.
-- Phase 1: Text-only. Phase 2 will handle tool use blocks.
runTurn :: ClientHandle -> Text -> AgentState -> IO AgentState
runTurn client userInput state = do
  -- Add user message to conversation
  let userMsg = userMessage (TextMessage userInput)
  let stateWithUser = addMessage userMsg state

  -- Assemble request
  let request = assembleRequest stateWithUser

  -- Send to LLM
  result <- sendRequest client request

  case result of
    Left err -> do
      -- Display error and return unchanged state
      displayError err
      pure state

    Right response -> do
      -- Extract assistant's reply
      let assistantContent = BlockMessage response.content
      let assistantMsg = assistantMessage assistantContent

      -- Display the response
      displayResponse response

      -- Add assistant message and increment turn count
      let finalState = (addMessage assistantMsg stateWithUser)
            { turnCount = stateWithUser.turnCount + 1 }

      pure finalState

-- | Display the assistant's response.
--
-- Phase 1: Just print text blocks.
-- Phase 2 will handle tool use blocks differently.
displayResponse :: MessageResponse -> IO ()
displayResponse response = do
  let textBlocks = [tb.text | TextContent tb <- response.content]
  mapM_ TIO.putStrLn textBlocks
  putStrLn ""  -- Extra newline for readability

-- | Display an LLM error to the user.
displayError :: LLMError -> IO ()
displayError = \case
  APIError msg ->
    putStrLn $ "API Error: " <> T.unpack msg
  NetworkError msg ->
    putStrLn $ "Network Error: " <> T.unpack msg
  TimeoutError ->
    putStrLn "Request timed out"
  ParseError msg ->
    putStrLn $ "Parse Error: " <> T.unpack msg
  UnknownError msg ->
    putStrLn $ "Unknown Error: " <> T.unpack msg

-- | Check if user input is a quit command.
isQuitCommand :: Text -> Bool
isQuitCommand input =
  let cleaned = T.strip $ T.toLower input
  in cleaned `elem` ["quit", "exit", "q", ":q"]
