-- | Property-based tests for PromptAssembly module.
--
-- Tests request assembly from agent state.
-- Category: STANDARD (important but less critical than data layer)
module Test.PromptAssembly (properties) where

import qualified Data.Text as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog

import Test.Generators (genAgentState)

import PromptAssembly (assembleRequest, defaultSystemPrompt)
import Conversation (getContextWindow)
import Types (AgentState (..), AgentConfig (..), SystemPrompt (..))
import Anthropic.Types (ModelId (..))
import Anthropic.Protocol.Message (MessageRequest (..))

-- | All properties for the PromptAssembly module.
properties :: [TestTree]
properties =
  [ testGroup "assembleRequest"
      [ testProperty "Model field matches config"
          prop_assembleRequest_has_model
      , testProperty "Max tokens matches config"
          prop_assembleRequest_has_max_tokens
      , testProperty "Messages from context window"
          prop_assembleRequest_messages_from_context
      , testProperty "System prompt is set"
          prop_assembleRequest_includes_system_prompt
      ]
  , testGroup "defaultSystemPrompt"
      [ testProperty "Default system prompt is non-empty"
          prop_defaultSystemPrompt_nonempty
      ]
  ]

-- | assembleRequest - Model Field Populated (P2)
--
-- The request should contain the model from config.
prop_assembleRequest_has_model :: Property
prop_assembleRequest_has_model = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  req.model === ModelId (model $ config state)

-- | assembleRequest - Max Tokens Matches Config (P2)
--
-- The request should use maxTokens from config.
prop_assembleRequest_has_max_tokens :: Property
prop_assembleRequest_has_max_tokens = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  req.maxTokens === maxTokens (config state)

-- | assembleRequest - Messages Match Context Window (P2)
--
-- The request should include messages from the context window.
prop_assembleRequest_messages_from_context :: Property
prop_assembleRequest_messages_from_context = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  let expectedMsgs = getContextWindow state
  req.messages === expectedMsgs

-- | assembleRequest - System Prompt Included (P3)
--
-- The request should always have a system prompt set.
prop_assembleRequest_includes_system_prompt :: Property
prop_assembleRequest_includes_system_prompt = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  -- System prompt should be set (either custom or default)
  case req.system of
    Nothing -> do
      annotate "Expected system prompt to be set"
      failure
    Just sp ->
      -- Should be either the config's custom prompt or default
      case systemPrompt (config state) of
        Nothing -> sp === defaultSystemPrompt
        Just custom -> sp === custom

-- | defaultSystemPrompt - Is Non-Empty (P3)
--
-- The default system prompt should contain actual text.
prop_defaultSystemPrompt_nonempty :: Property
prop_defaultSystemPrompt_nonempty = property $ do
  case defaultSystemPrompt of
    SimpleSystem txt -> assert (not $ T.null txt)
    _ -> success  -- Other variants acceptable
