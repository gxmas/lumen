-- | REPL loop orchestration with tool execution.
--
-- Phase 1 MVP: initialize -> mainLoop -> runTurn (repeatedly).
-- Tool execution loop: handles ToolUse responses, executes tools,
-- returns results to the LLM, and loops until text response.
module Lumen.Agent.Core
  ( initialize
  , mainLoop
  , runTurn
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

import qualified Lumen.Foundation.Types as Types
import Lumen.Foundation.Types (AgentState (..), AgentConfig (..))
import Lumen.Foundation.Storage (saveConversation, loadConversation)
import Lumen.Conversation.Core (addMessage)
import Lumen.LLM.Client (ClientHandle, sendRequest, LLMError (..))
import Lumen.LLM.PromptAssembly (assembleRequest)
import Lumen.Tools.Runtime (executeTool)

initialize :: AgentConfig -> IO AgentState
initialize config = do
  mbConv <- loadConversation config.conversationId
  case mbConv of
    Nothing -> do
      putStrLn $ "Starting new conversation: " <> T.unpack config.conversationId
      pure AgentState
        { config       = config
        , conversation = []
        , turnCount    = 0
        }
    Just (convFile :: Types.ConversationFile) -> do
      putStrLn $ "Resuming conversation: " <> T.unpack config.conversationId
      let msgs = convFile.messages
      putStrLn $ "Loaded " <> show (length msgs) <> " messages"
      pure AgentState
        { config       = config
        , conversation = msgs
        , turnCount    = length msgs `div` 2
        }

mainLoop :: ClientHandle -> AgentState -> IO ()
mainLoop client state = do
  putStr "> "
  hFlush stdout
  userInput <- TIO.getLine
  if isQuitCommand userInput
    then do
      putStrLn "Goodbye!"
      saveConversation state
    else do
      newState <- runTurn client userInput state
      saveConversation newState
      mainLoop client newState

runTurn :: ClientHandle -> Text -> AgentState -> IO AgentState
runTurn client userInput state = do
  let userMsg = userMessage (TextMessage userInput)
  let stateWithUser = addMessage userMsg state
  processResponse client stateWithUser

processResponse :: ClientHandle -> AgentState -> IO AgentState
processResponse client state = do
  let request = assembleRequest state
  result <- sendRequest client request
  case result of
    Left err -> do
      displayError err
      pure state

    Right response
      | hasToolUse response.content -> do
          let assistantContent = BlockMessage response.content
          let assistantMsg = assistantMessage assistantContent
          let stateWithAssistant = addMessage assistantMsg state

          displayToolUseIntent response.content

          let toolBlocks = getToolUseBlocks response.content
          results <- mapM (executeTool state.config.safetyConfig) toolBlocks

          mapM_ displayToolResult results

          let resultBlocks = map ToolResultContent results
          let resultMsg = userMessage (BlockMessage resultBlocks)
          let stateWithResults = addMessage resultMsg stateWithAssistant

          processResponse client stateWithResults

      | otherwise -> do
          let assistantContent = BlockMessage response.content
          let assistantMsg = assistantMessage assistantContent

          displayResponse response

          let finalState = (addMessage assistantMsg state)
                { turnCount = state.turnCount + 1 }
          pure finalState

hasToolUse :: [ContentBlock] -> Bool
hasToolUse = any isToolUseBlock
  where
    isToolUseBlock (ToolUseContent _) = True
    isToolUseBlock _                  = False

getToolUseBlocks :: [ContentBlock] -> [ToolUseBlock]
getToolUseBlocks blocks = [tb | ToolUseContent tb <- blocks]

displayResponse :: MessageResponse -> IO ()
displayResponse response = do
  let textBlocks = [tb.text | TextContent tb <- response.content]
  mapM_ TIO.putStrLn textBlocks
  putStrLn ""

displayToolUseIntent :: [ContentBlock] -> IO ()
displayToolUseIntent blocks = do
  let toolUses = getToolUseBlocks blocks
  mapM_ (\tb -> putStrLn $ "[tool] " <> T.unpack tb.name) toolUses

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

displayError :: LLMError -> IO ()
displayError = \case
  APIError msg    -> putStrLn $ "API Error: " <> T.unpack msg
  NetworkError msg -> putStrLn $ "Network Error: " <> T.unpack msg
  TimeoutError    -> putStrLn "Request timed out"
  ParseError msg  -> putStrLn $ "Parse Error: " <> T.unpack msg
  UnknownError msg -> putStrLn $ "Unknown Error: " <> T.unpack msg

isQuitCommand :: Text -> Bool
isQuitCommand input =
  let cleaned = T.strip $ T.toLower input
  in cleaned `elem` ["quit", "exit", "q", ":q"]
