-- | Safety validation for tool actions.
module Lumen.Tools.Guardrails
  ( Action (..)
  , validateAction
  , isSafePath
  , isSystemPath
  , hasPathTraversal
  , isBlockedPath
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import System.FilePath (normalise)

import Lumen.Foundation.Types (SafetyConfig (..), ValidationResult (..))

data Action
  = ReadFile !FilePath
  | WriteFile !FilePath !Text
  | DeleteFile !FilePath
  | ExecuteCommand !Text
  deriving stock (Eq, Show)

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

isSafePath :: FilePath -> SafetyConfig -> Bool
isSafePath path config =
  not (hasPathTraversal path)
    && (config.allowSystemPaths || not (isSystemPath path))
    && not (isBlockedPath path config)

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

hasPathTraversal :: FilePath -> Bool
hasPathTraversal path = ".." `T.isInfixOf` T.pack path

isBlockedPath :: FilePath -> SafetyConfig -> Bool
isBlockedPath path config =
  let pathText = T.pack path
  in any (\blocked -> pathText == blocked || blocked `T.isPrefixOf` pathText)
         config.blockedPaths

hasPrefix :: String -> String -> Bool
hasPrefix str prefix = take (length prefix) str == prefix
