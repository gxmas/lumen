-- | Property-based tests for JSON Schema encode/decode round-trip. (unchanged from MVP)
module Test.SchemaSerialization (properties) where

import Data.Function ((&))
import Data.Scientific (fromFloatDigits)
import Data.Text (Text)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Data.JsonSchema
  ( Schema, emptySchema
  , encode, decode
  , stringSchema, numberSchema, integerSchema, booleanSchema, nullSchema
  , objectSchema, arraySchema
  , allOf, anyOf, oneOf
  , required, optional
  , withTitle, withDescription
  , withMinLength, withMaxLength
  , withMinimum, withMaximum
  , withMinItems, withMaxItems, withUniqueItems
  , nullable, ref
  )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "Primitive round-trips"
      [ testProperty "P0: stringSchema"   prop_stringSchema_roundtrip
      , testProperty "P0: numberSchema"   prop_numberSchema_roundtrip
      , testProperty "P0: integerSchema"  prop_integerSchema_roundtrip
      , testProperty "P0: booleanSchema"  prop_booleanSchema_roundtrip
      , testProperty "P0: nullSchema"     prop_nullSchema_roundtrip
      ]
  , testGroup "Composite round-trips"
      [ testProperty "P0: objectSchema"   prop_objectSchema_roundtrip
      , testProperty "P0: arraySchema"    prop_arraySchema_roundtrip
      , testProperty "P1: emptySchema"    prop_emptySchema_roundtrip
      ]
  , testGroup "Composition round-trips"
      [ testProperty "P1: allOf"  prop_allOf_roundtrip
      , testProperty "P1: anyOf"  prop_anyOf_roundtrip
      , testProperty "P1: oneOf"  prop_oneOf_roundtrip
      ]
  , testGroup "Modifier round-trips"
      [ testProperty "P2: withTitle"               prop_withTitle_roundtrip
      , testProperty "P2: withDescription"         prop_withDescription_roundtrip
      , testProperty "P2: string constraints"      prop_string_constraints_roundtrip
      , testProperty "P2: numeric constraints"     prop_numeric_constraints_roundtrip
      , testProperty "P2: array constraints"       prop_array_constraints_roundtrip
      ]
  , testGroup "Complex schemas"
      [ testProperty "P1: nullable"                prop_nullable_roundtrip
      , testProperty "P2: ref"                     prop_ref_roundtrip
      , testProperty "P1: generated schema"        prop_generated_schema_roundtrip
      ]
  ]

genPrimitiveSchema :: Gen Schema
genPrimitiveSchema = Gen.element [stringSchema, numberSchema, integerSchema, booleanSchema, nullSchema]

genAnnotatedSchema :: Gen Schema
genAnnotatedSchema = do
  base  <- genPrimitiveSchema
  title <- Gen.maybe $ Gen.text (Range.linear 1 30) Gen.alphaNum
  desc  <- Gen.maybe $ Gen.text (Range.linear 1 50) Gen.alphaNum
  pure $ maybe base (\d -> maybe base (\t -> base & withTitle t) title & withDescription d) desc

genPropertyName :: Gen Text
genPropertyName = Gen.text (Range.linear 1 10) Gen.alpha

genObjectSchema :: Gen Schema
genObjectSchema = do
  numProps <- Gen.int (Range.linear 0 4)
  props <- Gen.list (Range.singleton numProps) $ do
    name  <- genPropertyName
    isReq <- Gen.bool
    schema <- genPrimitiveSchema
    pure $ if isReq then required name schema else optional name schema
  pure $ objectSchema props

genSchema :: Gen Schema
genSchema = Gen.choice
  [ genPrimitiveSchema
  , genAnnotatedSchema
  , genObjectSchema
  , arraySchema <$> genPrimitiveSchema
  , allOf <$> Gen.list (Range.linear 1 3) genPrimitiveSchema
  , anyOf <$> Gen.list (Range.linear 1 3) genPrimitiveSchema
  , oneOf <$> Gen.list (Range.linear 1 3) genPrimitiveSchema
  , nullable <$> genPrimitiveSchema
  ]

roundTrips :: Schema -> PropertyT IO ()
roundTrips s = case decode (encode s) of
  Right s' -> s' === s
  Left err -> annotate ("Decode failed: " <> show err) >> failure

prop_stringSchema_roundtrip :: Property
prop_stringSchema_roundtrip = withTests 1 $ property $ roundTrips stringSchema

prop_numberSchema_roundtrip :: Property
prop_numberSchema_roundtrip = withTests 1 $ property $ roundTrips numberSchema

prop_integerSchema_roundtrip :: Property
prop_integerSchema_roundtrip = withTests 1 $ property $ roundTrips integerSchema

prop_booleanSchema_roundtrip :: Property
prop_booleanSchema_roundtrip = withTests 1 $ property $ roundTrips booleanSchema

prop_nullSchema_roundtrip :: Property
prop_nullSchema_roundtrip = withTests 1 $ property $ roundTrips nullSchema

prop_objectSchema_roundtrip :: Property
prop_objectSchema_roundtrip = property $ do
  s <- forAll genObjectSchema; roundTrips s

prop_arraySchema_roundtrip :: Property
prop_arraySchema_roundtrip = property $ do
  items <- forAll genPrimitiveSchema; roundTrips (arraySchema items)

prop_emptySchema_roundtrip :: Property
prop_emptySchema_roundtrip = withTests 1 $ property $ roundTrips emptySchema

prop_allOf_roundtrip :: Property
prop_allOf_roundtrip = property $ do
  schemas <- forAll $ Gen.list (Range.linear 1 3) genPrimitiveSchema; roundTrips (allOf schemas)

prop_anyOf_roundtrip :: Property
prop_anyOf_roundtrip = property $ do
  schemas <- forAll $ Gen.list (Range.linear 1 3) genPrimitiveSchema; roundTrips (anyOf schemas)

prop_oneOf_roundtrip :: Property
prop_oneOf_roundtrip = property $ do
  schemas <- forAll $ Gen.list (Range.linear 1 3) genPrimitiveSchema; roundTrips (oneOf schemas)

prop_withTitle_roundtrip :: Property
prop_withTitle_roundtrip = property $ do
  title <- forAll $ Gen.text (Range.linear 1 50) Gen.alphaNum
  base  <- forAll genPrimitiveSchema
  roundTrips (base & withTitle title)

prop_withDescription_roundtrip :: Property
prop_withDescription_roundtrip = property $ do
  desc <- forAll $ Gen.text (Range.linear 1 50) Gen.alphaNum
  base <- forAll genPrimitiveSchema
  roundTrips (base & withDescription desc)

prop_string_constraints_roundtrip :: Property
prop_string_constraints_roundtrip = property $ do
  minLen <- forAll $ Gen.integral (Range.linear 0 10)
  maxLen <- forAll $ Gen.integral (Range.linear 10 100)
  roundTrips (stringSchema & withMinLength minLen & withMaxLength maxLen)

prop_numeric_constraints_roundtrip :: Property
prop_numeric_constraints_roundtrip = property $ do
  minVal <- forAll $ fromFloatDigits <$> Gen.double (Range.linearFrac 0 100)
  maxVal <- forAll $ fromFloatDigits <$> Gen.double (Range.linearFrac 100 1000)
  roundTrips (integerSchema & withMinimum minVal & withMaximum maxVal)

prop_array_constraints_roundtrip :: Property
prop_array_constraints_roundtrip = property $ do
  minItems <- forAll $ Gen.integral (Range.linear 0 5)
  maxItems <- forAll $ Gen.integral (Range.linear 5 50)
  unique   <- forAll Gen.bool
  roundTrips (arraySchema stringSchema & withMinItems minItems & withMaxItems maxItems & withUniqueItems unique)

prop_nullable_roundtrip :: Property
prop_nullable_roundtrip = property $ do
  base <- forAll genPrimitiveSchema; roundTrips (nullable base)

prop_ref_roundtrip :: Property
prop_ref_roundtrip = property $ do
  refName <- forAll $ Gen.text (Range.linear 1 20) Gen.alpha
  roundTrips (ref ("#/$defs/" <> refName))

prop_generated_schema_roundtrip :: Property
prop_generated_schema_roundtrip = property $ do
  s <- forAll genSchema; roundTrips s
