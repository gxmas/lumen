-- | CLI entry point for the Lumen agent.
--
-- Usage:
--   lumen [--api-key KEY] [--model MODEL] [--conversation-id ID]
--
-- If --api-key is not provided, reads from ANTHROPIC_API_KEY environment variable.
module Main (main) where

import Control.Exception (catch, SomeException)
import Data.Text (Text)
import qualified Data.Text as T
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Types (AgentConfig (..), SafetyConfig (..))
import LLMClient (createClient)
import AgentCore (initialize, mainLoop)

-- | Main entry point.
main :: IO ()
main = do
  -- Parse command-line arguments
  args <- getArgs
  config <- parseArgsOrExit args

  -- Create LLM client
  client <- createClient config.apiKey

  -- Initialize agent state
  state <- initialize config

  -- Display welcome message
  displayWelcome config

  -- Run main loop
  mainLoop client state
    `catch` \(e :: SomeException) -> do
      hPutStrLn stderr $ "Fatal error: " <> show e
      exitFailure

-- | Parse command-line arguments into configuration.
--
-- Exits with usage message on error.
parseArgsOrExit :: [String] -> IO AgentConfig
parseArgsOrExit args = do
  case parseArgs args of
    Left err -> do
      hPutStrLn stderr err
      hPutStrLn stderr ""
      hPutStrLn stderr usage
      exitFailure
    Right (apiKeyMb, modelMb, convIdMb) -> do
      -- Get API key (from args or environment)
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

      -- Use provided model or default
      let model = maybe defaultModel T.pack modelMb

      -- Use provided conversation ID or default
      let convId = maybe defaultConversationId T.pack convIdMb

      pure AgentConfig
        { apiKey         = apiKey
        , model          = model
        , maxTokens      = defaultMaxTokens
        , systemPrompt   = Nothing  -- Use default from PromptAssembly
        , safetyConfig   = defaultSafetyConfig
        , conversationId = convId
        }

-- | Parse command-line arguments.
--
-- Returns (apiKey, model, conversationId) with Nothing for unspecified options.
parseArgs :: [String] -> Either String (Maybe String, Maybe String, Maybe String)
parseArgs args = go args Nothing Nothing Nothing
  where
    go [] apiKey model convId = Right (apiKey, model, convId)
    go ("--api-key" : key : rest) _ model convId =
      go rest (Just key) model convId
    go ("--model" : m : rest) apiKey _ convId =
      go rest apiKey (Just m) convId
    go ("--conversation-id" : cid : rest) apiKey model _ =
      go rest apiKey model (Just cid)
    go ("--help" : _) _ _ _ =
      Left usage
    go (unknown : _) _ _ _ =
      Left $ "Unknown argument: " <> unknown

-- | Usage message.
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

-- | Display welcome message.
displayWelcome :: AgentConfig -> IO ()
displayWelcome config = do
  putStrLn "==================================="
  putStrLn "    Lumen Agent (Phase 1)"
  putStrLn "==================================="
  putStrLn $ "Model: " <> T.unpack config.model
  putStrLn $ "Conversation: " <> T.unpack config.conversationId
  putStrLn ""
  putStrLn "Type 'quit' to exit"
  putStrLn ""

-- | Default configuration values
defaultModel :: Text
defaultModel = "claude-sonnet-4-20250514"

defaultMaxTokens :: Int
defaultMaxTokens = 4096

defaultConversationId :: Text
defaultConversationId = "default"

defaultSafetyConfig :: SafetyConfig
defaultSafetyConfig = SafetyConfig
  { allowedPaths    = []
  , blockedPaths    = []
  , allowSystemPaths = False
  }
