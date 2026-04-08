-- | JSON persistence for conversation history.
--
-- This module handles saving and loading conversations to/from disk
-- as JSON files. Each conversation is stored in its own file.
module Storage
  ( -- * Saving
    saveConversation

    -- * Loading
  , loadConversation
  , conversationExists

    -- * File paths
  , conversationPath
  , ensureConversationDir
  ) where

import Control.Exception (IOException, catch)
import Data.Aeson (eitherDecodeFileStrict, encodeFile)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (getCurrentTime)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import qualified System.Environment
import System.FilePath ((</>), takeDirectory)

import Types (ConversationFile (..), AgentState (..), AgentConfig (..))

-- | Save the conversation to a JSON file.
--
-- Creates the conversation directory if it doesn't exist.
-- Updates the lastUpdatedAt timestamp before saving.
saveConversation :: AgentState -> IO ()
saveConversation state = do
  let convId = state.config.conversationId
  path <- conversationPath convId
  ensureConversationDir path

  -- Get current timestamp
  now <- getCurrentTime

  -- Check if file exists to determine if this is a new or updated conversation
  exists <- doesFileExist path
  createdTime <- if exists
    then do
      -- Load existing file to get original createdAt timestamp
      result <- eitherDecodeFileStrict path
      case result of
        Left _ -> pure now  -- If we can't read it, treat as new
        Right (cf :: ConversationFile) -> pure cf.createdAt
    else pure now

  -- Create conversation file structure
  let convFile = ConversationFile
        { conversationId = convId
        , createdAt      = createdTime
        , lastUpdatedAt  = now
        , messages       = state.conversation
        }

  -- Write to disk
  encodeFile path convFile

-- | Load a conversation from a JSON file.
--
-- Returns Nothing if the file doesn't exist or can't be parsed.
loadConversation :: Text -> IO (Maybe ConversationFile)
loadConversation convId = do
  path <- conversationPath convId
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      result <- eitherDecodeFileStrict path
      case result of
        Left _ -> do
          -- Failed to parse - return Nothing
          -- In production, might want to log this error
          pure Nothing
        Right cf -> pure (Just cf)

-- | Check if a conversation file exists on disk.
conversationExists :: Text -> IO Bool
conversationExists convId = do
  path <- conversationPath convId
  doesFileExist path

-- | Get the file path for a conversation ID.
--
-- Conversations are stored in ~/.lumen/conversations/<conversation-id>.json
conversationPath :: Text -> IO FilePath
conversationPath convId = do
  home <- getEnvDefault "HOME" "."
  let dir = home </> ".lumen" </> "conversations"
  pure $ dir </> T.unpack convId ++ ".json"

-- | Ensure the conversation directory exists.
--
-- Creates ~/.lumen/conversations/ if needed.
ensureConversationDir :: FilePath -> IO ()
ensureConversationDir path = do
  let dir = takeDirectory path
  createDirectoryIfMissing True dir

-- | Get environment variable with a default value.
getEnvDefault :: String -> String -> IO String
getEnvDefault key defaultVal = do
  catch (System.Environment.getEnv key) handler
  where
    handler :: IOException -> IO String
    handler _ = pure defaultVal
