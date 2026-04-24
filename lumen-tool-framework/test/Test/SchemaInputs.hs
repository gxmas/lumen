{-# LANGUAGE ScopedTypeVariables #-}
-- | Property-based tests for tool input type JSON round-trips. (unchanged from MVP)
module Test.SchemaInputs (properties) where

import Data.Aeson (eitherDecode, encode)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Anthropic.Tools.Common.Schema
  ( ReadFileInput (..), WriteFileInput (..), ListDirectoryInput (..)
  , SearchFilesInput (..), ExecuteCommandInput (..)
  )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "JSON round-trips"
      [ testProperty "P0: ReadFileInput round-trip"         prop_readFileInput_roundtrip
      , testProperty "P0: WriteFileInput round-trip"        prop_writeFileInput_roundtrip
      , testProperty "P0: ListDirectoryInput round-trip"    prop_listDirectoryInput_roundtrip
      , testProperty "P0: SearchFilesInput round-trip"      prop_searchFilesInput_roundtrip
      , testProperty "P0: ExecuteCommandInput round-trip"   prop_executeCommandInput_roundtrip
      ]
  , testGroup "Optional fields"
      [ testProperty "P1: WriteFileInput optional createDirs"       prop_writeFileInput_optional_createDirs
      , testProperty "P1: ListDirectoryInput optional fields"       prop_listDirectoryInput_optional_fields
      ]
  ]

genPath :: Gen Text
genPath = Gen.text (Range.linear 1 100) Gen.alphaNum

genContent :: Gen Text
genContent = Gen.text (Range.linear 0 500) Gen.unicode

genEnvMap :: Gen (Map Text Text)
genEnvMap = Map.fromList <$> Gen.list (Range.linear 0 5)
  ((,) <$> Gen.text (Range.linear 1 10) Gen.alpha
       <*> Gen.text (Range.linear 0 20) Gen.alphaNum)

prop_readFileInput_roundtrip :: Property
prop_readFileInput_roundtrip = property $ do
  input <- forAll $ ReadFileInput <$> genPath
  tripping input encode eitherDecode

prop_writeFileInput_roundtrip :: Property
prop_writeFileInput_roundtrip = property $ do
  input <- forAll $ WriteFileInput <$> genPath <*> genContent <*> Gen.maybe Gen.bool
  tripping input encode eitherDecode

prop_listDirectoryInput_roundtrip :: Property
prop_listDirectoryInput_roundtrip = property $ do
  input <- forAll $ ListDirectoryInput <$> genPath <*> Gen.maybe Gen.bool
    <*> Gen.maybe (Gen.text (Range.linear 1 20) Gen.alphaNum)
  tripping input encode eitherDecode

prop_searchFilesInput_roundtrip :: Property
prop_searchFilesInput_roundtrip = property $ do
  input <- forAll $ SearchFilesInput <$> genPath
    <*> Gen.text (Range.linear 1 50) Gen.alphaNum
    <*> Gen.maybe Gen.bool
    <*> Gen.maybe (Gen.int (Range.linear 1 1000))
  tripping input encode eitherDecode

prop_executeCommandInput_roundtrip :: Property
prop_executeCommandInput_roundtrip = property $ do
  input <- forAll $ ExecuteCommandInput
    <$> Gen.text (Range.linear 1 100) Gen.alphaNum
    <*> Gen.maybe genPath
    <*> Gen.maybe genEnvMap
  tripping input encode eitherDecode

prop_writeFileInput_optional_createDirs :: Property
prop_writeFileInput_optional_createDirs = property $ do
  path    <- forAll genPath
  content <- forAll genContent
  tripping (WriteFileInput path content Nothing) encode eitherDecode
  b <- forAll Gen.bool
  tripping (WriteFileInput path content (Just b)) encode eitherDecode

prop_listDirectoryInput_optional_fields :: Property
prop_listDirectoryInput_optional_fields = property $ do
  path <- forAll genPath
  tripping (ListDirectoryInput path Nothing Nothing) encode eitherDecode
  tripping (ListDirectoryInput path (Just True) (Just "*.hs")) encode eitherDecode
