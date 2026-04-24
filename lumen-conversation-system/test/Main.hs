module Main (main) where

import Test.Tasty

import qualified Test.Conversation

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "lumen-conversation-system"
  [ testGroup "Conversation (CRITICAL)" Test.Conversation.properties
  ]
