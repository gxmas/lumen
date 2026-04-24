-- | Property-based tests for OrderedMap algebraic laws and invariants.
--
-- Tests monoid laws, insertion order preservation, lookup consistency,
-- and union properties. Category: STANDARD
module Test.OrderedMap (properties) where

import Prelude hiding (lookup, null)

import Data.List (nub)
import Data.Text (Text)

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Data.JsonSchema.OrderedMap

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testGroup "Monoid laws"
      [ testProperty "P0: left identity (mempty <> m == m)"
          prop_monoid_left_identity
      , testProperty "P0: right identity (m <> mempty == m)"
          prop_monoid_right_identity
      , testProperty "P0: associativity ((a <> b) <> c == a <> (b <> c))"
          prop_monoid_associativity
      ]
  , testGroup "Invariants"
      [ testProperty "P1: size equals keys length"
          prop_size_equals_keys_length
      , testProperty "P1: keys have no duplicates"
          prop_keys_no_duplicates
      , testProperty "P1: all keys are members"
          prop_all_keys_members
      ]
  , testGroup "Lookup"
      [ testProperty "P1: lookup after insert finds value"
          prop_lookup_after_insert
      , testProperty "P2: lookup missing key returns Nothing"
          prop_lookup_missing
      ]
  , testGroup "Insert"
      [ testProperty "P2: insert new key increases size"
          prop_insert_new_increases_size
      , testProperty "P2: insert existing key preserves size"
          prop_insert_existing_preserves_size
      , testProperty "P3: insert existing key preserves order"
          prop_insert_existing_preserves_order
      ]
  , testGroup "fromList / toList"
      [ testProperty "P1: fromList duplicate key: last value wins"
          prop_fromList_last_value_wins
      , testProperty "P1: toList preserves first-occurrence order"
          prop_toList_first_occurrence_order
      ]
  , testGroup "Union"
      [ testProperty "P2: union left-biased values"
          prop_union_left_biased_values
      , testProperty "P3: union left-biased ordering"
          prop_union_left_biased_ordering
      ]
  , testGroup "Equality"
      [ testProperty "P1: equality is order-insensitive"
          prop_equality_order_insensitive
      ]
  ]

-- Generators: small key space for collisions

genSmallKey :: Gen Text
genSmallKey = Gen.text (Range.linear 1 3) Gen.alpha

genValue :: Gen Int
genValue = Gen.int (Range.linear 0 100)

genKV :: Gen (Text, Int)
genKV = (,) <$> genSmallKey <*> genValue

genOM :: Gen (OrderedMap Text Int)
genOM = fromList <$> Gen.list (Range.linear 0 20) genKV

-- Monoid laws

prop_monoid_left_identity :: Property
prop_monoid_left_identity = property $ do
  m <- forAll genOM
  (mempty <> m) === m

prop_monoid_right_identity :: Property
prop_monoid_right_identity = property $ do
  m <- forAll genOM
  (m <> mempty) === m

prop_monoid_associativity :: Property
prop_monoid_associativity = property $ do
  a <- forAll genOM
  b <- forAll genOM
  c <- forAll genOM
  ((a <> b) <> c) === (a <> (b <> c))

-- Invariants

prop_size_equals_keys_length :: Property
prop_size_equals_keys_length = property $ do
  m <- forAll genOM
  size m === length (keys m)

prop_keys_no_duplicates :: Property
prop_keys_no_duplicates = property $ do
  m <- forAll genOM
  keys m === nub (keys m)

prop_all_keys_members :: Property
prop_all_keys_members = property $ do
  m <- forAll genOM
  mapM_ (\k -> assert $ member k m) (keys m)

-- Lookup

prop_lookup_after_insert :: Property
prop_lookup_after_insert = property $ do
  m <- forAll genOM
  k <- forAll genSmallKey
  v <- forAll genValue
  lookup k (insert k v m) === Just v

prop_lookup_missing :: Property
prop_lookup_missing = property $ do
  -- Use a key that's definitely not in the map
  let m = fromList [("a", 1), ("b", 2)] :: OrderedMap Text Int
  lookup "zzz" m === Nothing

-- Insert

prop_insert_new_increases_size :: Property
prop_insert_new_increases_size = property $ do
  m <- forAll genOM
  k <- forAll genSmallKey
  v <- forAll genValue
  case member k m of
    True  -> success  -- skip if key exists
    False -> size (insert k v m) === size m + 1

prop_insert_existing_preserves_size :: Property
prop_insert_existing_preserves_size = property $ do
  kvs <- forAll $ Gen.list (Range.linear 1 10) genKV
  let m = fromList kvs
  case keys m of
    []    -> success
    (k:_) -> do
      v <- forAll genValue
      size (insert k v m) === size m

prop_insert_existing_preserves_order :: Property
prop_insert_existing_preserves_order = property $ do
  kvs <- forAll $ Gen.list (Range.linear 1 10) genKV
  let m = fromList kvs
  case keys m of
    []    -> success
    (k:_) -> do
      v <- forAll genValue
      keys (insert k v m) === keys m

-- fromList / toList

prop_fromList_last_value_wins :: Property
prop_fromList_last_value_wins = property $ do
  k <- forAll genSmallKey
  v1 <- forAll genValue
  v2 <- forAll genValue
  let m = fromList [(k, v1), (k, v2)]
  lookup k m === Just v2

prop_toList_first_occurrence_order :: Property
prop_toList_first_occurrence_order = property $ do
  -- Insert a, b, c. Duplicate a at end. Order should be a, b, c.
  let m = fromList [("a", 1), ("b", 2), ("c", 3), ("a", 99)] :: OrderedMap Text Int
  keys m === ["a", "b", "c"]
  lookup "a" m === Just 99  -- last value wins

-- Union

prop_union_left_biased_values :: Property
prop_union_left_biased_values = property $ do
  k <- forAll genSmallKey
  v1 <- forAll genValue
  v2 <- forAll genValue
  let m1 = singleton k v1
  let m2 = singleton k v2
  lookup k (m1 <> m2) === Just v1  -- left wins

prop_union_left_biased_ordering :: Property
prop_union_left_biased_ordering = property $ do
  let m1 = fromList [("a", 1), ("b", 2)] :: OrderedMap Text Int
  let m2 = fromList [("c", 3), ("d", 4)] :: OrderedMap Text Int
  -- Left keys should come first
  let combined = m1 <> m2
  take 2 (keys combined) === ["a", "b"]

-- Equality

prop_equality_order_insensitive :: Property
prop_equality_order_insensitive = property $ do
  k1 <- forAll genSmallKey
  k2 <- forAll $ Gen.filter (/= k1) genSmallKey
  v1 <- forAll genValue
  v2 <- forAll genValue
  let m1 = fromList [(k1, v1), (k2, v2)]
  let m2 = fromList [(k2, v2), (k1, v1)]
  m1 === m2
