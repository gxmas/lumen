-- | API wrapper around anthropic-client.
module Lumen.LLM.Client
  ( createClient
  , ClientHandle
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

newtype ClientHandle = ClientHandle AnthropicClient

createClient :: Text -> IO ClientHandle
createClient apiKeyText = do
  let apiKey = ApiKey apiKeyText
  let config = defaultConfig apiKey
  client <- newClient config
  pure $ ClientHandle client

sendRequest :: ClientHandle -> MessageRequest -> IO (Either LLMError MessageResponse)
sendRequest (ClientHandle client) req = do
  result <- createMessage client req
  case result of
    Right response -> pure $ Right response
    Left err       -> pure $ Left (convertError err)

data LLMError
  = APIError !Text
  | NetworkError !Text
  | TimeoutError
  | ParseError !Text
  | UnknownError !Text
  deriving stock (Eq, Show)

convertError :: ClientError -> LLMError
convertError = \case
  ApiErrorResponse apiErr _ ->
    APIError apiErr.errorMessage
  Anthropic.Client.Config.NetworkError httpExc ->
    Lumen.LLM.Client.NetworkError (T.pack $ show httpExc)
  Anthropic.Client.Config.TimeoutError ->
    Lumen.LLM.Client.TimeoutError
  DeserializationError msg _ ->
    ParseError msg
