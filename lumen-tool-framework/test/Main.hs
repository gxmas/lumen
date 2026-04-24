module Main (main) where

import Test.Tasty

import qualified Test.Guardrails
import qualified Test.GuardrailsHelpers
import qualified Test.ToolCatalog
import qualified Test.ToolRuntime
import qualified Test.SchemaInputs
import qualified Test.OrderedMap
import qualified Test.SchemaSerialization

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "lumen-tool-framework"
  [ testGroup "Guardrails (CRITICAL)"          Test.Guardrails.properties
  , testGroup "Guardrails Helpers (CRITICAL)"  Test.GuardrailsHelpers.properties
  , testGroup "ToolCatalog (STANDARD)"         Test.ToolCatalog.properties
  , testGroup "ToolRuntime (CRITICAL)"         Test.ToolRuntime.properties
  , testGroup "Schema Inputs (CRITICAL)"       Test.SchemaInputs.properties
  , testGroup "OrderedMap (STANDARD)"          Test.OrderedMap.properties
  , testGroup "Schema Serialization (CRITICAL)" Test.SchemaSerialization.properties
  ]
