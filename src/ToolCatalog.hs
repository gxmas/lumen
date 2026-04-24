-- | Tool registry for the Lumen agent.
--
-- Wraps pre-built tool definitions from @anthropic-tools-common@.
-- Phase 2 (MVP): Hardcoded 5 tools for file system and shell operations.
module ToolCatalog
  ( -- * Tool listing
    allTools
  , allToolDefs

    -- * Tool lookup
  , lookupTool
  ) where

import Data.List (find)
import Data.Text (Text)

import Anthropic.Protocol.Tool
  ( ToolDefinition (..)
  , CustomToolDef (..)
  )
import Anthropic.Tools.Common.FileSystem
  ( FileSystemTools (..)
  , fileSystemTools
  )
import Anthropic.Tools.Common.Shell
  ( ShellTools (..)
  , shellTools
  )

-- | All available tool definitions as @CustomToolDef@ values.
--
-- These are the raw definitions used for lookup by name.
allToolDefs :: [CustomToolDef]
allToolDefs =
  let fs = fileSystemTools
      sh = shellTools
  in [ fs.readFile
     , fs.writeFile
     , fs.listDirectory
     , fs.searchFiles
     , sh.executeCommand
     ]

-- | All tools wrapped as 'ToolDefinition' for inclusion in API requests.
--
-- Pass this list to 'withTools' when assembling a 'MessageRequest'.
allTools :: [ToolDefinition]
allTools = map CustomTool allToolDefs

-- | Look up a tool definition by name.
--
-- Returns 'Nothing' if no tool with the given name is registered.
lookupTool :: Text -> Maybe CustomToolDef
lookupTool toolName = find (\t -> t.name == toolName) allToolDefs
