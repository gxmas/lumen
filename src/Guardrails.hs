-- | Safety validation for tool actions.
--
-- Validates actions before execution to prevent dangerous operations.
-- MVP implementation: path validation only, no secret detection or
-- resource limits.
module Guardrails
  ( -- * Action types
    Action (..)

    -- * Validation
  , validateAction
  , isSafePath
  , isSystemPath

    -- * Internal helpers (exported for testing)
  , hasPathTraversal
  , isBlockedPath
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import System.FilePath (normalise)

import Types (SafetyConfig (..), ValidationResult (..))

-- | An action the agent wants to perform.
--
-- Each tool use is classified as an action for validation.
data Action
  = ReadFile !FilePath
    -- ^ Read a file's contents
  | WriteFile !FilePath !Text
    -- ^ Write content to a file
  | DeleteFile !FilePath
    -- ^ Delete a file (always denied in MVP)
  | ExecuteCommand !Text
    -- ^ Run a shell command
  deriving stock (Eq, Show)

-- | Validate an action against the safety configuration.
--
-- Rules (MVP):
--   * ReadFile: allowed if path is safe
--   * WriteFile: allowed if path is safe
--   * DeleteFile: always denied
--   * ExecuteCommand: always allowed (trust the LLM)
validateAction :: Action -> SafetyConfig -> ValidationResult
validateAction action config = case action of
  ReadFile path
    | isSafePath path config -> Allowed
    | otherwise -> Blocked $ "Read blocked: " <> T.pack path
  WriteFile path _
    | isSafePath path config -> Allowed
    | otherwise -> Blocked $ "Write blocked: " <> T.pack path
  DeleteFile path ->
    Blocked $ "File deletion is not allowed: " <> T.pack path
  ExecuteCommand _ ->
    Allowed

-- | Check if a file path is safe to access.
--
-- A path is safe if:
--   * It does not contain path traversal (@..@)
--   * It is not a system path (unless @allowSystemPaths@ is set)
--   * It is not in the @blockedPaths@ list
isSafePath :: FilePath -> SafetyConfig -> Bool
isSafePath path config =
  not (hasPathTraversal path)
    && (config.allowSystemPaths || not (isSystemPath path))
    && not (isBlockedPath path config)

-- | Check if a path is a system directory.
--
-- Blocks access to critical system directories on Unix-like systems.
isSystemPath :: FilePath -> Bool
isSystemPath path =
  let normalised = normalise path
  in any (\prefix -> normalised == prefix || hasPrefix normalised (prefix <> "/"))
         systemPaths
  where
    systemPaths :: [FilePath]
    systemPaths =
      [ "/etc", "/bin", "/usr", "/var", "/sys"
      , "/boot", "/sbin", "/lib", "/proc", "/dev"
      ]

-- | Check if a path contains traversal components (@..@).
hasPathTraversal :: FilePath -> Bool
hasPathTraversal path = ".." `T.isInfixOf` T.pack path

-- | Check if a path is in the blocked paths list.
isBlockedPath :: FilePath -> SafetyConfig -> Bool
isBlockedPath path config =
  let pathText = T.pack path
  in any (\blocked -> pathText == blocked || blocked `T.isPrefixOf` pathText)
         config.blockedPaths

-- | Check if a string starts with a prefix.
hasPrefix :: String -> String -> Bool
hasPrefix str prefix = take (length prefix) str == prefix
