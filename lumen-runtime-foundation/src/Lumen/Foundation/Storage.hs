-- | JSON persistence for conversation history.
module Lumen.Foundation.Storage
  ( saveConversation
  , loadConversation
  , conversationExists
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

import Lumen.Foundation.Types (ConversationFile (..), AgentState (..), AgentConfig (..))

saveConversation :: AgentState -> IO ()
saveConversation state = do
  let convId = state.config.conversationId
  path <- conversationPath convId
  ensureConversationDir path
  now <- getCurrentTime
  exists <- doesFileExist path
  createdTime <- if exists
    then do
      result <- eitherDecodeFileStrict path
      case result of
        Left _ -> pure now
        Right (cf :: ConversationFile) -> pure cf.createdAt
    else pure now
  let convFile = ConversationFile
        { conversationId = convId
        , createdAt      = createdTime
        , lastUpdatedAt  = now
        , messages       = state.conversation
        }
  encodeFile path convFile

loadConversation :: Text -> IO (Maybe ConversationFile)
loadConversation convId = do
  path <- conversationPath convId
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      result <- eitherDecodeFileStrict path
      case result of
        Left _   -> pure Nothing
        Right cf -> pure (Just cf)

conversationExists :: Text -> IO Bool
conversationExists convId = do
  path <- conversationPath convId
  doesFileExist path

conversationPath :: Text -> IO FilePath
conversationPath convId = do
  home <- getEnvDefault "HOME" "."
  let dir = home </> ".lumen" </> "conversations"
  pure $ dir </> T.unpack convId ++ ".json"

ensureConversationDir :: FilePath -> IO ()
ensureConversationDir path = do
  let dir = takeDirectory path
  createDirectoryIfMissing True dir

getEnvDefault :: String -> String -> IO String
getEnvDefault key defaultVal =
  catch (System.Environment.getEnv key) handler
  where
    handler :: IOException -> IO String
    handler _ = pure defaultVal
