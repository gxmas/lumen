-- | REPL loop orchestration with tool execution.
--
-- This module coordinates the main agent loop:
-- initialize -> mainLoop -> runTurn (repeatedly)
--
-- Tool execution: When the LLM responds with tool_use blocks,
-- the agent validates and executes each tool, sends results back,
-- and loops until the LLM responds with text only.
module AgentCore
  ( -- * Initialization
    initialize

    -- * Main loop
  , mainLoop

    -- * Single turn
  , runTurn

    -- * Utilities
  , isQuitCommand
  , hasToolUse
  , getToolUseBlocks
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
import Anthropic.Types.Content.ToolUse (ToolUseBlock (..))
import Anthropic.Types.Content.ToolResult (ToolResultBlock (..), ToolResultContent (..))

import qualified Types
import Types (AgentState (..), AgentConfig (..))
import Conversation (addMessage)
import Storage (saveConversation, loadConversation)
import LLMClient (ClientHandle, sendRequest, LLMError (..))
import PromptAssembly (assembleRequest)
import ToolRuntime (executeTool)

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
-- Takes user input, sends to LLM, handles tool use loops,
-- displays final response, and updates state.
runTurn :: ClientHandle -> Text -> AgentState -> IO AgentState
runTurn client userInput state = do
  -- Add user message to conversation
  let userMsg = userMessage (TextMessage userInput)
  let stateWithUser = addMessage userMsg state

  -- Send to LLM and handle response (possibly with tool use loop)
  processResponse client stateWithUser

-- | Send the current conversation to the LLM and process the response.
--
-- If the response contains tool use blocks, executes them and loops.
-- Otherwise, displays the text response and returns.
processResponse :: ClientHandle -> AgentState -> IO AgentState
processResponse client state = do
  -- Assemble request and send
  let request = assembleRequest state
  result <- sendRequest client request

  case result of
    Left err -> do
      -- Display error and return state before user message was added
      displayError err
      pure state

    Right response
      | hasToolUse response.content -> do
          -- Add assistant message (with tool_use blocks) to conversation
          let assistantContent = BlockMessage response.content
          let assistantMsg = assistantMessage assistantContent
          let stateWithAssistant = addMessage assistantMsg state

          -- Display what tools the model wants to use
          displayToolUseIntent response.content

          -- Execute each tool and collect results
          let toolBlocks = getToolUseBlocks response.content
          results <- mapM (executeTool state.config.safetyConfig) toolBlocks

          -- Display tool results
          mapM_ displayToolResult results

          -- Add tool results as a user message
          let resultBlocks = map ToolResultContent results
          let resultMsg = userMessage (BlockMessage resultBlocks)
          let stateWithResults = addMessage resultMsg stateWithAssistant

          -- Loop: send results back to LLM
          processResponse client stateWithResults

      | otherwise -> do
          -- Text-only response — display and finish
          let assistantContent = BlockMessage response.content
          let assistantMsg = assistantMessage assistantContent

          displayResponse response

          let finalState = (addMessage assistantMsg state)
                { turnCount = state.turnCount + 1 }
          pure finalState

-- | Check if content blocks contain any tool use requests.
hasToolUse :: [ContentBlock] -> Bool
hasToolUse = any isToolUseBlock
  where
    isToolUseBlock (ToolUseContent _) = True
    isToolUseBlock _                  = False

-- | Extract ToolUseBlock values from content blocks.
getToolUseBlocks :: [ContentBlock] -> [ToolUseBlock]
getToolUseBlocks blocks = [tb | ToolUseContent tb <- blocks]

-- | Display the assistant's text response.
displayResponse :: MessageResponse -> IO ()
displayResponse response = do
  let textBlocks = [tb.text | TextContent tb <- response.content]
  mapM_ TIO.putStrLn textBlocks
  putStrLn ""  -- Extra newline for readability

-- | Display which tools the model wants to use.
displayToolUseIntent :: [ContentBlock] -> IO ()
displayToolUseIntent blocks = do
  let toolUses = getToolUseBlocks blocks
  mapM_ (\tb -> putStrLn $ "[tool] " <> T.unpack tb.name) toolUses

-- | Display a tool result summary.
displayToolResult :: ToolResultBlock -> IO ()
displayToolResult result = do
  let prefix = case result.isError of
        Just True -> "[error] "
        _         -> "[result] "
  case result.content of
    Just (ToolResultText txt) -> do
      let preview = if T.length txt > 200
            then T.take 200 txt <> "..."
            else txt
      putStrLn $ prefix <> T.unpack preview
    _ -> putStrLn $ prefix <> "(no content)"

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
