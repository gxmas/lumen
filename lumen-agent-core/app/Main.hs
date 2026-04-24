-- | CLI entry point for the Lumen agent.
module Main (main) where

import Control.Exception (catch, SomeException)
import Data.Text (Text)
import qualified Data.Text as T
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Lumen.Foundation.Types (AgentConfig (..), SafetyConfig (..))
import Lumen.LLM.Client (createClient)
import Lumen.Agent.Core (initialize, mainLoop)

main :: IO ()
main = do
  args <- getArgs
  config <- parseArgsOrExit args
  client <- createClient config.apiKey
  state <- initialize config
  displayWelcome config
  mainLoop client state
    `catch` \(e :: SomeException) -> do
      hPutStrLn stderr $ "Fatal error: " <> show e
      exitFailure

parseArgsOrExit :: [String] -> IO AgentConfig
parseArgsOrExit args = do
  case parseArgs args of
    Left err -> do
      hPutStrLn stderr err
      hPutStrLn stderr ""
      hPutStrLn stderr usage
      exitFailure
    Right (apiKeyMb, modelMb, convIdMb) -> do
      apiKey <- case apiKeyMb of
        Just k  -> pure $ T.pack k
        Nothing -> do
          mbEnv <- lookupEnv "ANTHROPIC_API_KEY"
          case mbEnv of
            Just k  -> pure $ T.pack k
            Nothing -> do
              hPutStrLn stderr "Error: API key not provided"
              hPutStrLn stderr "Set ANTHROPIC_API_KEY environment variable or use --api-key flag"
              exitFailure
      let model  = maybe defaultModel T.pack modelMb
      let convId = maybe defaultConversationId T.pack convIdMb
      pure AgentConfig
        { apiKey         = apiKey
        , model          = model
        , maxTokens      = defaultMaxTokens
        , systemPrompt   = Nothing
        , safetyConfig   = defaultSafetyConfig
        , conversationId = convId
        }

parseArgs :: [String] -> Either String (Maybe String, Maybe String, Maybe String)
parseArgs args = go args Nothing Nothing Nothing
  where
    go [] a m c = Right (a, m, c)
    go ("--api-key"        : k   : rest) _ m c = go rest (Just k)   m c
    go ("--model"          : m   : rest) a _ c = go rest a (Just m)  c
    go ("--conversation-id": cid : rest) a m _ = go rest a m (Just cid)
    go ("--help" : _) _ _ _                    = Left usage
    go (unknown  : _) _ _ _                    = Left $ "Unknown argument: " <> unknown

usage :: String
usage = unlines
  [ "Usage: lumen [OPTIONS]"
  , ""
  , "Options:"
  , "  --api-key KEY           Anthropic API key (or set ANTHROPIC_API_KEY)"
  , "  --model MODEL           Model to use (default: claude-sonnet-4-20250514)"
  , "  --conversation-id ID    Conversation ID for persistence (default: default)"
  , "  --help                  Show this help message"
  , ""
  , "Commands during conversation:"
  , "  quit, exit, q, :q       Exit the conversation"
  ]

displayWelcome :: AgentConfig -> IO ()
displayWelcome config = do
  putStrLn "==================================="
  putStrLn "    Lumen Agent (MVP)"
  putStrLn "==================================="
  putStrLn $ "Model: " <> T.unpack config.model
  putStrLn $ "Conversation: " <> T.unpack config.conversationId
  putStrLn "Tools: read_file, write_file, list_directory, search_files, execute_command"
  putStrLn ""
  putStrLn "Type 'quit' to exit"
  putStrLn ""

defaultModel :: Text
defaultModel = "claude-sonnet-4-20250514"

defaultMaxTokens :: Int
defaultMaxTokens = 4096

defaultConversationId :: Text
defaultConversationId = "default"

defaultSafetyConfig :: SafetyConfig
defaultSafetyConfig = SafetyConfig
  { allowedPaths     = []
  , blockedPaths     = []
  , allowSystemPaths = False
  }
