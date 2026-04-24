module Main (main) where

import Test.Tasty

import qualified Test.PromptAssembly

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "lumen-llm-core"
  [ testGroup "PromptAssembly (STANDARD)" Test.PromptAssembly.properties
  ]
