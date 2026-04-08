# Persistence Flow

Data flow diagram showing how conversations are loaded at startup, updated during the session, and saved to disk.

## Startup: Initialize

```mermaid
flowchart TD
    Start([lumen starts]) --> Init[initialize config]
    Init --> Load[loadConversation convId]
    Load --> Exists{file exists?}

    Exists -->|No| Fresh[Create fresh AgentState<br/>conversation = empty<br/>turnCount = 0]
    Fresh --> Print1[/"Starting new conversation: {id}"/]

    Exists -->|Yes| Parse{JSON parse OK?}
    Parse -->|No| Fresh
    Parse -->|Yes| Resume[Create AgentState<br/>conversation = loaded messages<br/>turnCount = length ÷ 2]
    Resume --> Print2[/"Resuming conversation: {id}<br/>Loaded N messages"/]

    Print1 --> Ready([enter REPL loop])
    Print2 --> Ready

    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    classDef action fill:#d4edda,stroke:#28a745,color:#155724
    classDef io fill:#cce5ff,stroke:#004085,color:#004085

    class Exists,Parse decision
    class Fresh,Resume action
    class Load,Print1,Print2 io
```

## Turn Cycle: Save After Each Turn

```mermaid
flowchart TD
    Prompt[/display > prompt/] --> Read[read user input]
    Read --> Quit{quit command?}

    Quit -->|Yes| SaveQuit[saveConversation state]
    SaveQuit --> Bye[/"Goodbye!"/]
    Bye --> End([exit])

    Quit -->|No| Turn[runTurn client input state]
    Turn --> Result{API success?}

    Result -->|Error| Display[display error]
    Display --> SaveOrig[saveConversation original state]
    SaveOrig --> Prompt

    Result -->|Success| Update[update state with<br/>user + assistant messages]
    Update --> SaveNew[saveConversation updated state]
    SaveNew --> Prompt

    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    classDef action fill:#d4edda,stroke:#28a745,color:#155724
    classDef io fill:#cce5ff,stroke:#004085,color:#004085

    class Quit,Result decision
    class Turn,Update action
    class Read,SaveQuit,SaveOrig,SaveNew,Display,Prompt,Bye io
```

## Save Operation Detail

```mermaid
flowchart TD
    Save([saveConversation]) --> Path[conversationPath convId]
    Path --> EnsureDir[ensureConversationDir]
    EnsureDir --> Now[getCurrentTime]
    Now --> FileExists{file exists?}

    FileExists -->|No| SetCreated[createdAt = now]
    FileExists -->|Yes| ReadOld[read existing file]
    ReadOld --> ParseOK{parse OK?}
    ParseOK -->|Yes| Preserve[createdAt = existing value]
    ParseOK -->|No| SetCreated

    SetCreated --> Build[build ConversationFile<br/>lastUpdatedAt = now]
    Preserve --> Build
    Build --> Write[encodeFile path convFile]
    Write --> Done([done])

    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    classDef action fill:#d4edda,stroke:#28a745,color:#155724

    class FileExists,ParseOK decision
    class SetCreated,Preserve,Build action
```
