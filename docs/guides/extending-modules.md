# How to Extend Lumen's Architecture

This guide explains how to grow Lumen by adding new modules or enhancing existing ones. It is for contributors who want to implement the next phase of the roadmap or add a capability not yet planned.

**Prerequisites:** You have read [Onboarding Guide](../onboarding/guide.md) and understand the current six-module structure. You have GHC 9.10.3+, Cabal 3.10+, and a working build.

---

## The Mental Model

Lumen's full target architecture has 19 modules, documented in `~/Projects/design/lumen/design/architecture.md`. The current codebase implements 9 of them (the MVP). Each subsequent phase adds new modules or upgrades simplified ones to their full contracts.

The key principle: **the architecture document is your map, not your build plan.** You extract the relevant section from it, run it through a technical design step and a construction planning step, then implement. You do not redesign the architecture each time.

```
architecture.md (the full map — do not modify)
     ↓
  Extract the relevant module contracts
     ↓
  /technical-design  (projects contracts → Haskell types + module structure)
     ↓
  /construction-planning  (creates step-by-step build plan for this codebase)
     ↓
  Implement following the plan
     ↓
  Integrate with existing modules
```

---

## Two Patterns

### Pattern A: Adding a New Module

Use this when you want a capability that has no current code at all.

**Example:** Adding a `Memory` module so the agent remembers facts across sessions. `Memory` does not exist anywhere in the Phase 0 codebase — it is entirely new.

**Steps:**

1. **Identify the need.** "The agent forgets everything when I restart it."

2. **Find the contract in `architecture.md`.** Look for the `Memory` section. It defines the data types (`MemoryRecord`, `MemoryType`, `Query`), the operations (`save`, `retrieve`, `search`, `delete`), and design notes.

3. **Create a contracts file.** Extract the relevant contracts to a new file in the design directory:

   ```
   ~/Projects/design/lumen/design/phase1-persistence-contracts.md
   ```

   Copy the `Memory` contract verbatim. If Memory depends on other modules also being added or enhanced in this phase (e.g., Storage), include those contracts too with a note about their current state.

4. **Run `/technical-design`.** This projects the language-agnostic contract to Haskell-specific decisions: which types to define, how to handle errors (`Either` or `IO (Maybe a)`), which libraries to use, serialization format. The output is a new `phase1-technical-design.md`.

5. **Run `/construction-planning`.** This takes the technical design plus the existing codebase and produces a step-by-step build order with integration instructions. The output is a new `phase1-construction-plan.md`.

6. **Implement.** Follow the construction plan. For a new module:
   - Determine which package it belongs to, or create a new package (e.g., `lumen-memory/`).
   - Create the module file (e.g., `lumen-memory/src/Lumen/Memory/Core.hs`).
   - Add it to `exposed-modules` in the package's `.cabal` file.
   - If a new package: add it to `cabal.project` and add the dependency to `lumen-agent-core.cabal`.
   - Add generators to `lumen-agent-core/test/Test/Generators.hs`.
   - Create `lumen-agent-core/test/Test/Memory.hs` with Hedgehog properties.
   - Add to `other-modules` in `lumen-agent-core.cabal` and import in `test/Main.hs`.

7. **Integrate.** Connect the new module to `Agent.Core`. New domain modules are typically called from `Agent.Core.initialize` (to load state) and from `Agent.Core.runTurn` or `Agent.Core.mainLoop` (to use the capability mid-conversation).

8. **Verify.**

   ```bash
   cabal build all   # no warnings
   cabal test        # all properties pass
   ```

---

### Pattern B: Enhancing an Existing Module

Use this when a module already exists but is implemented at a simplified level — for example, `Storage` currently saves a single JSON file, but the full architecture calls for a namespaced key-value interface.

**Example:** Upgrading `Storage` from a single `ConversationFile` to a full namespaced key-value store.

The challenge here is **migration**: existing data must continue to work, and every existing callsite of `Storage` must be updated when the interface changes.

**Steps:**

1. **Identify the current state and the target state.** Look at the existing module's exported functions. Then look at the full contract in `architecture.md` for what it should eventually do.

2. **Create a contracts file** that includes both:
   - The full target contract from `architecture.md`.
   - A note on the current simplified state and what needs to change.

   ```markdown
   ## Storage (ENHANCE)
   
   Current state: Single JSON file at ~/.lumen/conversations/<id>.json
   Target state: Namespaced key-value store with file backend
   
   [Copy full Storage contract from architecture.md]
   ```

3. **Run `/technical-design` and `/construction-planning`** as in Pattern A. The construction plan will include a data migration step.

4. **Implement in order:**
   a. Implement the new interface alongside the old code.
   b. Migrate existing data if the on-disk format changes.
   c. Update all callsites (typically just `AgentCore`).
   d. Remove the old implementation.

5. **Update tests.** Existing properties must still pass. Add new properties for the new functionality.

---

## Concrete Example: Adding Memory (Phase 1)

Here is a worked example following Pattern A.

### 1. Identify need

After using the Phase 0 agent, you notice it forgets user preferences and project context on every restart. You want persistent memory.

### 2. Extract the contract

Open `~/Projects/design/lumen/design/architecture.md` and find the `Memory` section. It specifies:

- `MemoryRecord` with fields: `id`, `type`, `name`, `description`, `content`, `created`, `updated`, `metadata`
- `MemoryType` = `User | Feedback | Project | Reference`
- Operations: `save`, `retrieve`, `search`, `update`, `delete`, `get_project_context`

Create `~/Projects/design/lumen/design/phase1-persistence-contracts.md` with this content extracted verbatim.

### 3. Run technical design

The technical design output (`phase1-technical-design.md`) will specify:

- `data MemoryRecord = MemoryRecord { ... }` — strict fields, deriving Generic + ToJSON/FromJSON
- `data MemoryType = User | Feedback | Project | Reference` — deriving Enum/Bounded for iteration
- `type MemoryId = UUID` — using the `uuid` package
- Storage: each memory record stored as a JSON file in `~/.lumen/memory/<id>.json`
- Search: simple substring match on `name` and `description` fields for Phase 1

### 4. Run construction planning

The construction plan will specify:

1. Add `MemoryRecord`, `MemoryType`, `MemoryId` to `Lumen.Foundation.Types`
2. Create a new package `lumen-memory/` with `Lumen.Memory.Core` exposing `save`, `retrieve`, `search`, `update`, `delete`
3. Update `Lumen.Foundation.Storage` to create `~/.lumen/memory/` directory alongside conversations
4. Update `Lumen.Agent.Core.initialize` to load relevant memories at startup
5. Update `Lumen.Agent.Core.runTurn` (or `Lumen.LLM.PromptAssembly.assembleRequest`) to include memory context in the system prompt

### 5. Implement

```haskell
-- lumen-memory/src/Lumen/Memory/Core.hs

module Lumen.Memory.Core
  ( save
  , retrieve
  , search
  , update
  , delete
  , getProjectContext
  ) where

import Lumen.Foundation.Types (MemoryRecord (..), MemoryType (..), AgentConfig (..))

save :: MemoryRecord -> IO ()
save record = do
  path <- memoryPath record.memoryId
  ensureMemoryDir path
  encodeFile path record

retrieve :: MemoryId -> IO (Maybe MemoryRecord)
retrieve mid = do
  path <- memoryPath mid
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else eitherDecodeFileStrict path >>= \case
      Left _  -> pure Nothing
      Right r -> pure (Just r)

search :: Text -> IO [MemoryRecord]
search query = do
  -- list all files in ~/.lumen/memory/, decode each, filter by query
  ...
```

Add the new package to `cabal.project`:

```
packages:
    ...
    lumen-memory        -- add here
    ...
```

Add the dependency to `lumen-agent-core.cabal`:

```cabal
library
    build-depends:
        ...
        lumen-memory,   -- add here
        ...
```

### 6. Integrate

In `Lumen.Agent.Core.initialize`:

```haskell
initialize :: AgentConfig -> IO AgentState
initialize config = do
  mbConv <- loadConversation config.conversationId
  memories <- Memory.Core.search ""   -- load all on startup; or load selectively
  -- ... rest of initialization
```

In `Lumen.LLM.PromptAssembly.assembleRequest`, pass memories into the system prompt or as additional context.

---

## Concrete Example: Upgrading Storage (Phase 1)

Following Pattern B.

### 1. Current state

`Lumen.Foundation.Storage` (`lumen-runtime-foundation/src/Lumen/Foundation/Storage.hs`) exports:
```haskell
saveConversation    :: AgentState -> IO ()
loadConversation    :: Text -> IO (Maybe ConversationFile)
conversationExists  :: Text -> IO Bool
conversationPath    :: Text -> IO FilePath
ensureConversationDir :: FilePath -> IO ()
```

### 2. Target state

The full `Storage` contract from `architecture.md` specifies a namespaced key-value interface:

```
get(namespace, key) → Value | StorageError
put(namespace, key, value) → void | StorageError
delete(namespace, key) → void | StorageError
list(namespace, prefix) → [Key] | StorageError
exists(namespace, key) → bool
```

Namespaces would be `"conversations"`, `"memory"`, `"sessions"`.

### 3. Construction plan considerations

The plan must:
- Implement the new interface (`get`, `put`, `delete`, `list`, `exists`)
- Keep `saveConversation` and `loadConversation` as thin wrappers on the new interface (backwards compat during migration)
- Create `~/.lumen/` subdirectory structure: `conversations/`, `memory/`, `sessions/`
- Migrate any existing conversation files if the path format changes

### 4. Implement in order

Add the new interface alongside the old functions. Once all callsites are updated to use the new interface, remove the old functions.

---

## How to Organize Design Documents

Each phase or feature gets its own set of design files:

```
~/Projects/design/lumen/
├── design/
│   ├── architecture.md                     # Full 19-module architecture (never changes)
│   ├── problem-summary.md                  # Original problem statement (never changes)
│   ├── mvp-contracts.md                    # Simplified contracts for Phase 0
│   ├── technical-design.md                 # Haskell projection for Phase 0
│   │
│   ├── phase1-persistence-contracts.md     # Extracted: Memory, Storage, SessionManagement
│   ├── phase1-technical-design.md          # Haskell projection for Phase 1
│   │
│   ├── phase2-infrastructure-contracts.md  # Extracted: Telemetry, ErrorRecovery, Config, Guardrails
│   ├── phase2-technical-design.md
│   │
│   └── ...
│
└── implementation/
    ├── construction-plan.md                # Phase 0 build plan (current)
    ├── phase1-construction-plan.md         # Phase 1 build plan (when created)
    └── ...
```

Name contracts files after the phase or feature: `phase1-persistence-contracts.md`, `code-intelligence-contracts.md`, etc.

---

## When to Re-run Architectural Design

Almost never. The architecture document already covers all 19 modules. You only need a new architectural design if:

- **The problem changes fundamentally** — e.g., you decide to build a web service instead of a CLI agent.
- **You discover a major architectural flaw** — e.g., a module boundary is wrong and needs to be redrawn.
- **You want to add a domain not in the original architecture** — e.g., autonomous deployment capabilities.

For incremental feature additions within the existing architecture — implementing Memory, adding Telemetry, upgrading Storage — you only run `/technical-design` and `/construction-planning`. The architectural boundaries are already defined.

---

## Checklist for Any Extension

Before starting implementation:

- [ ] Found the module's full contract in `~/Projects/design/lumen/design/architecture.md`
- [ ] Created a contracts file in `~/Projects/design/lumen/design/`
- [ ] Ran `/technical-design` to get Haskell-specific decisions
- [ ] Ran `/construction-planning` to get a step-by-step build order with integration strategy

During implementation:

- [ ] New types added to `Lumen.Foundation.Types` (or to the module's own file if not shared)
- [ ] New module added to `exposed-modules` in the package's `.cabal` file
- [ ] New package (if any) added to `cabal.project` and as a dependency in `lumen-agent-core.cabal`
- [ ] Generators added to `lumen-agent-core/test/Test/Generators.hs`
- [ ] Properties written in `lumen-agent-core/test/Test/<ModuleName>.hs`
- [ ] Test module added to `other-modules` in `lumen-agent-core.cabal`
- [ ] Test module imported in `lumen-agent-core/test/Main.hs`

After implementation:

- [ ] `cabal build all` — no warnings
- [ ] `cabal test` — all properties pass
- [ ] Integration with `AgentCore` verified end-to-end

---

## Further Reading

- [docs/explanation/architecture.md](../explanation/architecture.md) — the pure/IO split and why module boundaries are drawn where they are
- [docs/guides/contributing.md](contributing.md) — code style, Haddock requirements, PR checklist
- [Onboarding Guide](../onboarding/guide.md) — the full phase roadmap table (section 10)
- `~/Projects/design/lumen/roadmap.md` — all 7 phases with success criteria and effort estimates
- `~/Projects/design/lumen/incremental-approach.md` — the workflow pattern in detail with a worked persistence example
- `~/Projects/design/lumen/design/architecture.md` — the full 19-module architecture (your north star)
