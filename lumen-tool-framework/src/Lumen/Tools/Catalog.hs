-- | Tool registry for the Lumen agent.
module Lumen.Tools.Catalog
  ( allTools
  , allToolDefs
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

allTools :: [ToolDefinition]
allTools = map CustomTool allToolDefs

lookupTool :: Text -> Maybe CustomToolDef
lookupTool toolName = find (\t -> t.name == toolName) allToolDefs
