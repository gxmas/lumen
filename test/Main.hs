-- | Main test runner for the Lumen agent test suite.
--
-- Runs all property-based tests using Tasty + Hedgehog.
module Main (main) where

import Test.Tasty

import qualified Test.Conversation
import qualified Test.Types
import qualified Test.PromptAssembly
import qualified Test.AgentCore
import qualified Test.Storage
import qualified Test.ToolCatalog
import qualified Test.Guardrails
import qualified Test.ToolRuntime
import qualified Test.GuardrailsHelpers
import qualified Test.SchemaInputs
import qualified Test.OrderedMap
import qualified Test.SchemaSerialization

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Lumen Agent Tests"
  [ testGroup "Conversation (CRITICAL)" Test.Conversation.properties
  , testGroup "Types - JSON Round-trips (CRITICAL)" Test.Types.properties
  , testGroup "PromptAssembly (STANDARD)" Test.PromptAssembly.properties
  , testGroup "AgentCore (MINIMAL)" Test.AgentCore.properties
  , testGroup "Storage (MINIMAL)" Test.Storage.properties
  , testGroup "ToolCatalog (STANDARD)" Test.ToolCatalog.properties
  , testGroup "Guardrails (CRITICAL)" Test.Guardrails.properties
  , testGroup "ToolRuntime (CRITICAL)" Test.ToolRuntime.properties
  , testGroup "Guardrails Helpers (CRITICAL)" Test.GuardrailsHelpers.properties
  , testGroup "Schema Inputs (CRITICAL)" Test.SchemaInputs.properties
  , testGroup "OrderedMap (STANDARD)" Test.OrderedMap.properties
  , testGroup "Schema Serialization (CRITICAL)" Test.SchemaSerialization.properties
  ]
