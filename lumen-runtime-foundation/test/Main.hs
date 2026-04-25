module Main (main) where

import Test.Tasty

import qualified Test.Types
import qualified Test.Storage

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "lumen-runtime-foundation"
  [ testGroup "Types - JSON Round-trips (CRITICAL)" Test.Types.properties
  , testGroup "Storage (MINIMAL)"                   Test.Storage.properties
  ]
