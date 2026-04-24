{-# LANGUAGE ScopedTypeVariables #-}

-- | Property-based tests for tool input type JSON round-trips.
--
-- These types are the data boundary between LLM output and tool execution.
-- Category: CRITICAL
module Test.SchemaInputs (properties) where

import Data.Aeson (eitherDecode, encode)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Anthropic.Tools.Common.Schema
  ( ReadFileInput (..)
  , WriteFileInput (..)
  , ListDirectoryInput (..)
  , SearchFilesInput (..)
  , ExecuteCommandInput (..)
  )

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "JSON round-trips"
      [ testProperty "P0: ReadFileInput round-trip"
          prop_readFileInput_roundtrip
      , testProperty "P0: WriteFileInput round-trip"
          prop_writeFileInput_roundtrip
      , testProperty "P0: ListDirectoryInput round-trip"
          prop_listDirectoryInput_roundtrip
      , testProperty "P0: SearchFilesInput round-trip"
          prop_searchFilesInput_roundtrip
      , testProperty "P0: ExecuteCommandInput round-trip"
          prop_executeCommandInput_roundtrip
      ]
  , testGroup "Optional fields"
      [ testProperty "P1: WriteFileInput optional createDirs round-trips"
          prop_writeFileInput_optional_createDirs
      , testProperty "P1: ListDirectoryInput optional fields round-trip"
          prop_listDirectoryInput_optional_fields
      ]
  ]

-- Generators

genPath :: Gen Text
genPath = Gen.text (Range.linear 1 100) Gen.alphaNum

genContent :: Gen Text
genContent = Gen.text (Range.linear 0 500) Gen.unicode

genReadFileInput :: Gen ReadFileInput
genReadFileInput = ReadFileInput <$> genPath

genWriteFileInput :: Gen WriteFileInput
genWriteFileInput = WriteFileInput
  <$> genPath
  <*> genContent
  <*> Gen.maybe Gen.bool

genListDirectoryInput :: Gen ListDirectoryInput
genListDirectoryInput = ListDirectoryInput
  <$> genPath
  <*> Gen.maybe Gen.bool
  <*> Gen.maybe (Gen.text (Range.linear 1 20) Gen.alphaNum)

genSearchFilesInput :: Gen SearchFilesInput
genSearchFilesInput = SearchFilesInput
  <$> genPath
  <*> Gen.text (Range.linear 1 50) Gen.alphaNum
  <*> Gen.maybe Gen.bool
  <*> Gen.maybe (Gen.int (Range.linear 1 1000))

genEnvMap :: Gen (Map Text Text)
genEnvMap = Map.fromList <$> Gen.list (Range.linear 0 5)
  ((,) <$> Gen.text (Range.linear 1 10) Gen.alpha
       <*> Gen.text (Range.linear 0 20) Gen.alphaNum)

genExecuteCommandInput :: Gen ExecuteCommandInput
genExecuteCommandInput = ExecuteCommandInput
  <$> Gen.text (Range.linear 1 100) Gen.alphaNum
  <*> Gen.maybe genPath
  <*> Gen.maybe genEnvMap

-- Properties

prop_readFileInput_roundtrip :: Property
prop_readFileInput_roundtrip = property $ do
  input <- forAll genReadFileInput
  tripping input encode eitherDecode

prop_writeFileInput_roundtrip :: Property
prop_writeFileInput_roundtrip = property $ do
  input <- forAll genWriteFileInput
  tripping input encode eitherDecode

prop_listDirectoryInput_roundtrip :: Property
prop_listDirectoryInput_roundtrip = property $ do
  input <- forAll genListDirectoryInput
  tripping input encode eitherDecode

prop_searchFilesInput_roundtrip :: Property
prop_searchFilesInput_roundtrip = property $ do
  input <- forAll genSearchFilesInput
  tripping input encode eitherDecode

prop_executeCommandInput_roundtrip :: Property
prop_executeCommandInput_roundtrip = property $ do
  input <- forAll genExecuteCommandInput
  tripping input encode eitherDecode

prop_writeFileInput_optional_createDirs :: Property
prop_writeFileInput_optional_createDirs = property $ do
  path <- forAll genPath
  content <- forAll genContent
  -- Test with Nothing
  let inputNone = WriteFileInput path content Nothing
  tripping inputNone encode eitherDecode
  -- Test with Just
  b <- forAll Gen.bool
  let inputSome = WriteFileInput path content (Just b)
  tripping inputSome encode eitherDecode

prop_listDirectoryInput_optional_fields :: Property
prop_listDirectoryInput_optional_fields = property $ do
  path <- forAll genPath
  -- All Nothing
  let inputNone = ListDirectoryInput path Nothing Nothing
  tripping inputNone encode eitherDecode
  -- All Just
  let inputAll = ListDirectoryInput path (Just True) (Just "*.hs")
  tripping inputAll encode eitherDecode
