-- | Property-based tests for the Guardrails module.
module Test.Guardrails (properties) where

import qualified Data.Text as T
import System.FilePath ((</>))

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Types (SafetyConfig (..), ValidationResult (..))
import Guardrails (Action (..), validateAction, isSafePath, isSystemPath)

import Test.Tasty (TestTree)
import Test.Tasty.Hedgehog (testProperty)

properties :: [TestTree]
properties =
  [ testProperty "P0: ReadFile with safe path is allowed"
      prop_readFile_safePath_allowed
  , testProperty "P1: WriteFile with safe path is allowed"
      prop_writeFile_safePath_allowed
  , testProperty "P2: DeleteFile is always blocked"
      prop_deleteFile_always_blocked
  , testProperty "P3: ExecuteCommand is always allowed"
      prop_executeCommand_always_allowed
  , testProperty "P4: System paths are blocked when allowSystemPaths is False"
      prop_systemPath_blocked
  , testProperty "P5: System paths are allowed when allowSystemPaths is True"
      prop_systemPath_allowed_when_configured
  , testProperty "P6: Blocked paths are denied"
      prop_blockedPaths_denied
  , testProperty "P7: Path traversal is blocked"
      prop_pathTraversal_blocked
  , testProperty "P8: isSystemPath recognises known system directories"
      prop_isSystemPath_known_dirs
  , testProperty "P9: isSystemPath rejects normal paths"
      prop_isSystemPath_rejects_normal
  ]

-- | A permissive config for testing (no blocked paths, no system path restriction).
permissiveConfig :: SafetyConfig
permissiveConfig = SafetyConfig
  { allowedPaths = []
  , blockedPaths = []
  , allowSystemPaths = True
  }

-- | A restrictive config (no system paths).
restrictiveConfig :: SafetyConfig
restrictiveConfig = SafetyConfig
  { allowedPaths = []
  , blockedPaths = []
  , allowSystemPaths = False
  }

-- | Generate a safe-looking file path (no traversal, not system).
genSafePath :: Gen FilePath
genSafePath = do
  segments <- Gen.list (Range.linear 1 5)
    (Gen.string (Range.linear 1 20) Gen.alphaNum)
  pure $ "/home/user" </> foldr1 (</>) segments

-- | ReadFile with a safe path should be Allowed.
prop_readFile_safePath_allowed :: Property
prop_readFile_safePath_allowed = property $ do
  path <- forAll genSafePath
  validateAction (ReadFile path) permissiveConfig === Allowed

-- | WriteFile with a safe path should be Allowed.
prop_writeFile_safePath_allowed :: Property
prop_writeFile_safePath_allowed = property $ do
  path <- forAll genSafePath
  content <- forAll $ Gen.text (Range.linear 0 100) Gen.unicode
  validateAction (WriteFile path content) permissiveConfig === Allowed

-- | DeleteFile should always be Blocked regardless of path or config.
prop_deleteFile_always_blocked :: Property
prop_deleteFile_always_blocked = property $ do
  path <- forAll genSafePath
  let result = validateAction (DeleteFile path) permissiveConfig
  case result of
    Blocked _ -> success
    Allowed   -> do
      annotate "DeleteFile should never be Allowed"
      failure

-- | ExecuteCommand should always be Allowed regardless of command.
prop_executeCommand_always_allowed :: Property
prop_executeCommand_always_allowed = property $ do
  cmd <- forAll $ Gen.text (Range.linear 1 100) Gen.unicode
  validateAction (ExecuteCommand cmd) restrictiveConfig === Allowed

-- | System paths should be blocked when allowSystemPaths is False.
prop_systemPath_blocked :: Property
prop_systemPath_blocked = property $ do
  sysDir <- forAll $ Gen.element
    ["/etc", "/bin", "/usr", "/var", "/sys", "/boot", "/sbin", "/proc", "/dev"]
  file <- forAll $ Gen.string (Range.linear 1 20) Gen.alphaNum
  let path = sysDir </> file
  let result = validateAction (ReadFile path) restrictiveConfig
  case result of
    Blocked _ -> success
    Allowed   -> do
      annotate $ "System path should be blocked: " <> path
      failure

-- | System paths should be allowed when allowSystemPaths is True.
prop_systemPath_allowed_when_configured :: Property
prop_systemPath_allowed_when_configured = property $ do
  sysDir <- forAll $ Gen.element ["/etc", "/bin", "/usr"]
  file <- forAll $ Gen.string (Range.linear 1 20) Gen.alphaNum
  let path = sysDir </> file
  validateAction (ReadFile path) permissiveConfig === Allowed

-- | Paths in blockedPaths should be denied.
prop_blockedPaths_denied :: Property
prop_blockedPaths_denied = property $ do
  path <- forAll genSafePath
  let config = permissiveConfig { blockedPaths = [T.pack path] }
  let result = validateAction (ReadFile path) config
  case result of
    Blocked _ -> success
    Allowed   -> do
      annotate $ "Blocked path should be denied: " <> path
      failure

-- | Paths containing ".." should be blocked.
prop_pathTraversal_blocked :: Property
prop_pathTraversal_blocked = property $ do
  prefix <- forAll $ Gen.string (Range.linear 1 10) Gen.alphaNum
  suffix <- forAll $ Gen.string (Range.linear 1 10) Gen.alphaNum
  let path = "/home/user/" <> prefix <> "/../" <> suffix
  assert $ not (isSafePath path restrictiveConfig)

-- | isSystemPath recognises all known system directories.
prop_isSystemPath_known_dirs :: Property
prop_isSystemPath_known_dirs = withTests 1 $ property $ do
  let sysDirs = ["/etc", "/bin", "/usr", "/var", "/sys", "/boot", "/sbin", "/lib", "/proc", "/dev"]
  mapM_ (\d -> assert $ isSystemPath d) sysDirs

-- | isSystemPath rejects normal user paths.
prop_isSystemPath_rejects_normal :: Property
prop_isSystemPath_rejects_normal = property $ do
  name <- forAll $ Gen.string (Range.linear 1 20) Gen.alphaNum
  let path = "/home/user/" <> name
  assert $ not (isSystemPath path)
