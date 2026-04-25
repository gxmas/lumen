module Test.PromptAssembly (properties) where

import Data.Maybe (isJust)
import qualified Data.Text as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Hedgehog

import Test.Generators (genAgentState)
import Lumen.LLM.PromptAssembly (assembleRequest, defaultSystemPrompt)
import Lumen.Conversation.Core (getContextWindow)
import Lumen.Foundation.Types (AgentState (..), AgentConfig (..), SystemPrompt (..))
import Anthropic.Types (ModelId (..))
import Anthropic.Protocol.Message (MessageRequest (..))

properties :: [TestTree]
properties =
  [ testGroup "assembleRequest"
      [ testProperty "Model field matches config"         prop_assembleRequest_has_model
      , testProperty "Max tokens matches config"          prop_assembleRequest_has_max_tokens
      , testProperty "Messages from context window"       prop_assembleRequest_messages_from_context
      , testProperty "System prompt is set"               prop_assembleRequest_includes_system_prompt
      ]
  , testGroup "tools"
      [ testProperty "Tools are included in assembled request" prop_assembleRequest_includes_tools ]
  , testGroup "defaultSystemPrompt"
      [ testProperty "Default system prompt is non-empty" prop_defaultSystemPrompt_nonempty ]
  ]

prop_assembleRequest_has_model :: Property
prop_assembleRequest_has_model = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  req.model === ModelId (model $ config state)

prop_assembleRequest_has_max_tokens :: Property
prop_assembleRequest_has_max_tokens = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  req.maxTokens === maxTokens (config state)

prop_assembleRequest_messages_from_context :: Property
prop_assembleRequest_messages_from_context = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  req.messages === getContextWindow state

prop_assembleRequest_includes_system_prompt :: Property
prop_assembleRequest_includes_system_prompt = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  case req.system of
    Nothing -> annotate "Expected system prompt to be set" >> failure
    Just sp ->
      case systemPrompt (config state) of
        Nothing     -> sp === defaultSystemPrompt
        Just custom -> sp === custom

prop_assembleRequest_includes_tools :: Property
prop_assembleRequest_includes_tools = property $ do
  state <- forAll genAgentState
  let req = assembleRequest state
  assert $ isJust req.tools
  case req.tools of
    Just tools -> length tools === 5
    Nothing    -> annotate "Expected tools to be set" >> failure

prop_defaultSystemPrompt_nonempty :: Property
prop_defaultSystemPrompt_nonempty = property $ do
  case defaultSystemPrompt of
    SimpleSystem txt -> assert (not $ T.null txt)
    _                -> success
