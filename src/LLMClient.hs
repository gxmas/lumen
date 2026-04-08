-- | API wrapper around anthropic-client.
--
-- This module provides a simplified interface to the Anthropic API,
-- handling client creation, error handling, and message sending.
module LLMClient
  ( -- * Client management
    createClient
  , ClientHandle

    -- * Sending messages
  , sendRequest
  , LLMError (..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Anthropic.Client.Config
  ( AnthropicClient
  , ClientError (..)
  , defaultConfig
  , newClient
  )
import Anthropic.Client.Messages (createMessage)
import Anthropic.Protocol.Message (MessageRequest, MessageResponse)
import Anthropic.Types (ApiKey (..), ApiError (..))

-- | Opaque handle to an LLM client.
--
-- Wraps the anthropic-client but provides a cleaner interface.
newtype ClientHandle = ClientHandle AnthropicClient

-- | Create a new LLM client from an API key.
--
-- The client manages an HTTP connection pool and rate limit state.
createClient :: Text -> IO ClientHandle
createClient apiKeyText = do
  let apiKey = ApiKey apiKeyText
  let config = defaultConfig apiKey
  client <- newClient config
  pure $ ClientHandle client

-- | Send a message request to the LLM.
--
-- Returns either an error or the response.
sendRequest :: ClientHandle -> MessageRequest -> IO (Either LLMError MessageResponse)
sendRequest (ClientHandle client) req = do
  result <- createMessage client req
  case result of
    Right response -> pure $ Right response
    Left err       -> pure $ Left (convertError err)

-- | LLM error type.
--
-- Simplifies the ClientError type for agent-level error handling.
data LLMError
  = APIError !Text
    -- ^ API returned an error. Includes error message.
  | NetworkError !Text
    -- ^ Network/connection issue
  | TimeoutError
    -- ^ Request timed out
  | ParseError !Text
    -- ^ Failed to parse response
  | UnknownError !Text
    -- ^ Catch-all for unexpected errors
  deriving stock (Eq, Show)

-- | Convert ClientError to LLMError.
convertError :: ClientError -> LLMError
convertError = \case
  ApiErrorResponse apiErr _ ->
    APIError apiErr.errorMessage
  Anthropic.Client.Config.NetworkError httpExc ->
    LLMClient.NetworkError (T.pack $ show httpExc)
  Anthropic.Client.Config.TimeoutError ->
    LLMClient.TimeoutError
  DeserializationError msg _ ->
    ParseError msg
