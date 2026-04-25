module Main (main) where

import Test.Tasty

import qualified Test.AgentCore

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "lumen-agent-core"
  [ testGroup "AgentCore (MINIMAL)" Test.AgentCore.properties
  ]
