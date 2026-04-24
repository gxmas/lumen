-- | Tool execution with safety validation.
module Lumen.Tools.Runtime
  ( executeTool
  , mkReadAction
  , mkWriteAction
  , mkListDirAction
  , mkSearchAction
  , mkCommandAction
  , mkErrorResult
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Anthropic.Types.Content.ToolUse (ToolUseBlock (..))
import Anthropic.Types.Content.ToolResult (ToolResultBlock (..), ToolResultContent (..))
import Anthropic.Tools.Common.Parser (ParseError (..), parseToolInput)
import Anthropic.Tools.Common.Schema
  ( ReadFileInput (..)
  , WriteFileInput (..)
  , ListDirectoryInput (..)
  , SearchFilesInput (..)
  , ExecuteCommandInput (..)
  )
import Anthropic.Tools.Common.Executor
  ( ExecutionError (..)
  , executeReadFile
  , executeWriteFile
  , executeListDirectory
  , executeSearchFiles
  , executeCommand
  )

import Lumen.Foundation.Types (SafetyConfig (..), ValidationResult (..))
import Lumen.Tools.Guardrails (Action (..), validateAction)

executeTool :: SafetyConfig -> ToolUseBlock -> IO ToolResultBlock
executeTool safetyConfig tub = case tub.name of
  "read_file"       -> withValidation safetyConfig tub mkReadAction    executeReadFile
  "write_file"      -> withValidation safetyConfig tub mkWriteAction   executeWriteFile
  "list_directory"  -> withValidation safetyConfig tub mkListDirAction executeListDirectory
  "search_files"    -> withValidation safetyConfig tub mkSearchAction  executeSearchFiles
  "execute_command" -> withValidation safetyConfig tub mkCommandAction executeCommand
  other             -> pure $ mkErrorResult tub $ "Unknown tool: " <> other

withValidation
  :: SafetyConfig
  -> ToolUseBlock
  -> (ToolUseBlock -> Either Text Action)
  -> (ToolUseBlock -> IO (Either ExecutionError ToolResultBlock))
  -> IO ToolResultBlock
withValidation safetyConfig tub mkAction executor =
  case mkAction tub of
    Left parseErr ->
      pure $ mkErrorResult tub $ "Failed to parse input: " <> parseErr
    Right action ->
      case validateAction action safetyConfig of
        Blocked reason ->
          pure $ mkErrorResult tub reason
        Allowed -> do
          result <- executor tub
          case result of
            Right toolResult -> pure toolResult
            Left (ToolParseError err) ->
              pure $ mkErrorResult tub $ "Parse error: " <> T.pack (show err)
            Left (ToolIOError msg) ->
              pure $ mkErrorResult tub $ "IO error: " <> msg

mkReadAction :: ToolUseBlock -> Either Text Action
mkReadAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg}) -> Left msg
  Right (input :: ReadFileInput)     -> Right $ ReadFile (T.unpack input.path)

mkWriteAction :: ToolUseBlock -> Either Text Action
mkWriteAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg}) -> Left msg
  Right (input :: WriteFileInput)    -> Right $ WriteFile (T.unpack input.path) input.content

mkListDirAction :: ToolUseBlock -> Either Text Action
mkListDirAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg})   -> Left msg
  Right (input :: ListDirectoryInput)  -> Right $ ReadFile (T.unpack input.path)

mkSearchAction :: ToolUseBlock -> Either Text Action
mkSearchAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg})  -> Left msg
  Right (input :: SearchFilesInput)   -> Right $ ReadFile (T.unpack input.path)

mkCommandAction :: ToolUseBlock -> Either Text Action
mkCommandAction tub = case parseToolInput tub of
  Left (ParseError {errorMsg = msg})     -> Left msg
  Right (input :: ExecuteCommandInput)   -> Right $ ExecuteCommand input.command

mkErrorResult :: ToolUseBlock -> Text -> ToolResultBlock
mkErrorResult tub msg = ToolResultBlock
  { toolUseId    = tub.id
  , content      = Just (ToolResultText msg)
  , isError      = Just True
  , cacheControl = Nothing
  }
