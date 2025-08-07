# Stream Aggregator API データフロー図

## システム全体データフロー

```mermaid
flowchart TD
    A[Frontend Application] --> B[Stream Aggregator API]
    B --> C[Supabase Database]
    B --> D[YouTube Data API v3]
    B --> E[Twitch Helix API]
    B --> F[Supabase Auth]
    
    C --> G[(Users Table)]
    C --> H[(Channels Table)]
    C --> I[(Streams Table)]
    C --> J[(Platforms Table)]
    
    subgraph "External APIs"
        D
        E
    end
    
    subgraph "Supabase"
        F
        C
        G
        H
        I
        J
    end
    
    subgraph "Railway Deployment"
        B
    end
```

## ユーザーインタラクションフロー

### 1. 認証フロー

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant API as Stream Aggregator API  
    participant Auth as Supabase Auth
    participant DB as Supabase DB
    
    U->>F: Login Request
    F->>Auth: Login with credentials
    Auth-->>F: JWT Token
    F->>API: API Request with Bearer Token
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid + User Info
    API->>DB: Query user data
    DB-->>API: User data
    API-->>F: Protected resource
    F-->>U: Display data
```

### 2. チャンネル管理フロー

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant API as Stream Aggregator API
    participant DB as Supabase DB
    
    Note over U,DB: チャンネル登録フロー
    U->>F: Add Channel Request
    F->>API: POST /api/channels
    API->>DB: Insert channel
    DB-->>API: Channel created
    API-->>F: Success response
    F-->>U: Channel added confirmation
    
    Note over U,DB: チャンネル一覧取得フロー
    U->>F: View channels
    F->>API: GET /api/channels
    API->>DB: Query user channels
    DB-->>API: Channels list
    API-->>F: Channels data
    F-->>U: Display channels
```

### 3. 配信データ更新フロー（1分間隔）

```mermaid
sequenceDiagram
    participant F as Frontend
    participant API as Stream Aggregator API
    participant DB as Supabase DB
    participant YT as YouTube API
    participant TW as Twitch API
    
    Note over F,TW: 定期更新プロセス（1分間隔）
    loop Every 1 minute
        F->>API: POST /api/streams/refresh
        API->>DB: Get registered channels
        DB-->>API: Channels list
        
        par YouTube Streams
            API->>YT: Get live streams for YouTube channels
            YT-->>API: Live streams data
        and Twitch Streams
            API->>TW: Get live streams for Twitch channels
            TW-->>API: Live streams data
        end
        
        API->>API: Aggregate & process stream data
        API->>DB: Update streams table
        DB-->>API: Update confirmation
        API-->>F: Updated streams data
    end
```

## データ処理パイプライン

### 配信データ取得・統合パイプライン

```mermaid
flowchart LR
    A[Refresh Request] --> B{Get User Channels}
    B --> C[YouTube Channels]
    B --> D[Twitch Channels]
    
    C --> E[YouTube API Call]
    D --> F[Twitch API Call]
    
    E --> G[Parse YouTube Response]
    F --> H[Parse Twitch Response]
    
    G --> I[Normalize Data Structure]
    H --> I
    
    I --> J[Validate Stream Data]
    J --> K{Data Valid?}
    K -->|Yes| L[Save to Database]
    K -->|No| M[Log Error & Skip]
    
    L --> N[Return Aggregated Data]
    M --> N
```

### エラーハンドリングフロー

```mermaid
flowchart TD
    A[API Request] --> B{Authentication Valid?}
    B -->|No| C[Return 401 Unauthorized]
    B -->|Yes| D{External API Available?}
    
    D -->|No| E{Cache Available?}
    E -->|Yes| F[Return Cached Data]
    E -->|No| G[Return 503 Service Unavailable]
    
    D -->|Yes| H[Process Request]
    H --> I{Database Available?}
    I -->|No| J[Return 500 Internal Server Error]
    I -->|Yes| K[Return Success Response]
    
    H --> L{Rate Limited?}
    L -->|Yes| M[Return 429 Too Many Requests]
    L -->|No| K
```

## リアルタイムデータ同期

### フロントエンド側ポーリング戦略

```mermaid
gantt
    title Frontend Polling Strategy
    dateFormat X
    axisFormat %M:%S
    
    section Polling Cycle
    Request Streams    :milestone, m1, 0, 0m
    Process Response   :task1, 0, 5s
    Display Update     :task2, after task1, 2s
    Wait Period        :task3, after task2, 53s
    Next Request       :milestone, m2, after task3, 0m
```

### データ鮮度管理

```mermaid
flowchart TD
    A[Stream Data Request] --> B{Data Age < 1min?}
    B -->|Yes| C[Return Cached Data]
    B -->|No| D[Fetch Fresh Data]
    D --> E[Update Cache]
    E --> F[Return Fresh Data]
    
    subgraph "Data Lifecycle"
        G[Create] --> H[Fresh: 0-30s]
        H --> I[Stale: 30s-1min]
        I --> J[Expired: >1min]
        J --> G
    end
```

## データベース操作フロー

### CRUD操作パターン

```mermaid
flowchart LR
    subgraph "Create Operations"
        A1[Register User] --> B1[Insert Users Table]
        A2[Add Channel] --> B2[Insert Channels Table]
        A3[Save Stream] --> B3[Insert/Update Streams Table]
    end
    
    subgraph "Read Operations"
        C1[Get User Profile] --> D1[Query Users Table]
        C2[List Channels] --> D2[Query Channels Table + JOIN]
        C3[Get Streams] --> D3[Query Streams Table + JOIN]
    end
    
    subgraph "Update Operations"
        E1[Update Stream Status] --> F1[Update Streams Table]
        E2[Modify Channel] --> F2[Update Channels Table]
    end
    
    subgraph "Delete Operations"
        G1[Remove Channel] --> H1[Delete Channels Table]
        G2[Cleanup Old Streams] --> H2[Delete Streams Table]
    end
```

## セキュリティデータフロー

### JWT トークン検証フロー

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Stream Aggregator API
    participant Auth as Supabase Auth
    
    C->>API: Request with Bearer Token
    API->>API: Extract JWT from Header
    API->>Auth: Validate JWT Signature
    Auth-->>API: Token Validation Result
    
    alt Token Valid
        API->>Auth: Get User Claims
        Auth-->>API: User Information
        API->>API: Process Request
        API-->>C: Success Response
    else Token Invalid
        API-->>C: 401 Unauthorized
    else Token Expired
        API-->>C: 401 Unauthorized (Token Expired)
    end
```

### データアクセス制御フロー

```mermaid
flowchart TD
    A[API Request] --> B[Extract User ID from JWT]
    B --> C{Resource Ownership Check}
    C -->|Own Resource| D[Allow Access]
    C -->|Not Own Resource| E[Deny Access - 403 Forbidden]
    C -->|Public Resource| F[Allow Access]
    
    D --> G[Execute Database Query with User Filter]
    F --> H[Execute Database Query]
    E --> I[Return Error Response]
```

## パフォーマンス最適化フロー

### 並行処理によるAPI呼び出し最適化

```mermaid
flowchart TD
    A[Refresh Request] --> B[Get All Channels]
    B --> C{Group by Platform}
    C --> D[YouTube Channels Group]
    C --> E[Twitch Channels Group]
    
    subgraph "Concurrent Processing"
        D --> F[Async YouTube API Calls]
        E --> G[Async Twitch API Calls]
    end
    
    F --> H[Collect Results]
    G --> H
    H --> I[Merge & Normalize Data]
    I --> J[Batch Database Update]
    J --> K[Return Aggregated Response]
```

---

**作成日**: 2025-08-07
**バージョン**: 1.0
**設計者**: Stream Aggregator開発チーム