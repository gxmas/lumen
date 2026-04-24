# Guardrails

Safety validation for tool actions.

This module defines the `Action` type that classifies what a tool wants to do, and the validation logic that decides whether each action is permitted. All validation is pure — no IO occurs here. `ToolRuntime` calls into `Guardrails` before dispatching to any executor.

**Module:** `Guardrails` (`src/Guardrails.hs`)

## Action

An action the agent wants to perform, extracted from a `ToolUseBlock` before execution.

```haskell
data Action
  = ReadFile  !FilePath
  | WriteFile !FilePath !Text
  | DeleteFile !FilePath
  | ExecuteCommand !Text
  deriving stock (Eq, Show)
```

| Constructor | Fields | Description |
|-------------|--------|-------------|
| `ReadFile` | `FilePath` | Read a file or directory listing |
| `WriteFile` | `FilePath`, `Text` | Write content to a file |
| `DeleteFile` | `FilePath` | Delete a file — **always denied** in MVP |
| `ExecuteCommand` | `Text` | Run a shell command |

**Note:** `list_directory` and `search_files` both produce `ReadFile` actions for validation purposes — they access paths but do not modify them.

## validateAction

Validate an action against the current safety configuration.

```haskell
validateAction :: Action -> SafetyConfig -> ValidationResult
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | `Action` | The action to validate |
| `config` | `SafetyConfig` | Safety settings from `AgentConfig.safetyConfig` |
| **Returns** | `ValidationResult` | `Allowed` or `Blocked reason` |

**Validation rules:**

| Action | Condition | Result |
|--------|-----------|--------|
| `ReadFile path` | `isSafePath path config` | `Allowed` |
| `ReadFile path` | otherwise | `Blocked "Read blocked: {path}"` |
| `WriteFile path _` | `isSafePath path config` | `Allowed` |
| `WriteFile path _` | otherwise | `Blocked "Write blocked: {path}"` |
| `DeleteFile path` | always | `Blocked "File deletion is not allowed: {path}"` |
| `ExecuteCommand _` | always | `Allowed` |

**Pure function** — no IO. Safe to call from any context.

## isSafePath

Check if a file path is safe to access.

```haskell
isSafePath :: FilePath -> SafetyConfig -> Bool
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `FilePath` | The path to check |
| `config` | `SafetyConfig` | Safety settings |
| **Returns** | `Bool` | `True` if all checks pass |

A path is safe if **all three** of the following hold:

1. `not (hasPathTraversal path)` — no `..` components
2. `config.allowSystemPaths || not (isSystemPath path)` — not a system path (unless explicitly allowed)
3. `not (isBlockedPath path config)` — not in the operator-configured block list

## isSystemPath

Check if a path is a protected system directory.

```haskell
isSystemPath :: FilePath -> Bool
```

Blocks access to the following directories and their contents:

| Blocked path |
|--------------|
| `/etc` |
| `/bin` |
| `/usr` |
| `/var` |
| `/sys` |
| `/boot` |
| `/sbin` |
| `/lib` |
| `/proc` |
| `/dev` |

The path is normalised before checking (via `System.FilePath.normalise`). A path matches if it equals a blocked prefix exactly, or if the blocked prefix is a leading component of the path (e.g., `/etc/passwd` is blocked because `/etc` is blocked).

To allow system path access in a specific deployment, set `SafetyConfig.allowSystemPaths = True`. This bypasses `isSystemPath` but not `hasPathTraversal` or `isBlockedPath`.

## hasPathTraversal

Check if a path contains traversal components.

```haskell
hasPathTraversal :: FilePath -> Bool
```

Returns `True` if the path contains `..` anywhere — including embedded occurrences like `/home/user/../etc`. This check cannot be bypassed by any `SafetyConfig` setting.

**Example:**

```haskell
hasPathTraversal "/home/user/docs"          -- False
hasPathTraversal "/home/user/../etc/passwd" -- True
hasPathTraversal "../../secret"             -- True
```

## isBlockedPath

Check if a path is in the operator-configured block list.

```haskell
isBlockedPath :: FilePath -> SafetyConfig -> Bool
```

Returns `True` if the path equals any entry in `SafetyConfig.blockedPaths`, or if any blocked entry is a prefix of the path. This allows blocking entire subtrees by listing a directory path.

**Example:**

```haskell
-- SafetyConfig { blockedPaths = ["/home/user/.ssh"] }
isBlockedPath "/home/user/.ssh/id_rsa" config  -- True (prefix match)
isBlockedPath "/home/user/.ssh"        config  -- True (exact match)
isBlockedPath "/home/user/docs"        config  -- False
```

## Usage Example

```haskell
import Guardrails (Action (..), validateAction)
import Types (SafetyConfig (..), ValidationResult (..))

let config = SafetyConfig
      { allowedPaths    = []
      , blockedPaths    = ["/home/user/.ssh"]
      , allowSystemPaths = False
      }

validateAction (ReadFile "/home/user/docs/notes.md") config
-- Allowed

validateAction (ReadFile "/etc/passwd") config
-- Blocked "Read blocked: /etc/passwd"

validateAction (ReadFile "/home/user/../etc/passwd") config
-- Blocked "Read blocked: /home/user/../etc/passwd"

validateAction (DeleteFile "/tmp/scratch.txt") config
-- Blocked "File deletion is not allowed: /tmp/scratch.txt"

validateAction (ExecuteCommand "ls -la") config
-- Allowed
```

## MVP Limitations

- `ExecuteCommand` is always allowed — no filtering on command content or working directory
- No secret detection (the agent can read files containing API keys or credentials if the path passes validation)
- No resource limits (no file size cap for reads/writes, no timeout for commands)
- `allowedPaths` in `SafetyConfig` is defined but not enforced — only `blockedPaths` and the system path / traversal rules are active
