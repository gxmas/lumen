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

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Lumen Agent Tests"
  [ testGroup "Conversation (CRITICAL)" Test.Conversation.properties
  , testGroup "Types - JSON Round-trips (CRITICAL)" Test.Types.properties
  , testGroup "PromptAssembly (STANDARD)" Test.PromptAssembly.properties
  , testGroup "AgentCore (MINIMAL)" Test.AgentCore.properties
  , testGroup "Storage (MINIMAL)" Test.Storage.properties
  ]
