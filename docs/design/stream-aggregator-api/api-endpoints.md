# Stream Aggregator API エンドポイント設計

## 概要

Stream Aggregator APIのRESTfulエンドポイント設計です。実際のSupabaseデータベーススキーマ（contexts/sqls/）と、フロントエンド統合仕様（contexts/）に基づき、FastAPI + Next.jsの分離構成でのセキュアなAPI設計を行います。

## フロントエンド統合アーキテクチャ

```
Next.js Frontend (Vercel)  ←→  FastAPI Backend (Railway)
├── OAuth認証UI                    ├── OAuth処理API
├── 配信一覧表示                    ├── 外部API統合
├── ゲーム別フィルタリング              ├── データ正規化
└── リアルタイム更新                  └── Supabase RLS
```

## 基本設計方針

### RESTful原則

- **Resource-oriented**: リソース中心の設計
- **HTTP Methods**: 標準的なHTTPメソッド使用
- **Status Codes**: 適切なHTTPステータスコード
- **Idempotent**: 冪等性の保証

### 認証・認可

- **JWT Bearer Token**: Supabase Auth JWT使用
- **RLS Integration**: データベースレベルでの自動認可
- **User Context**: auth.uid() による自動ユーザーフィルタリング

### レスポンス形式

- **統一レスポンス**: ApiResponse<T> 型による統一
- **エラーハンドリング**: 構造化されたエラー情報
- **ページネーション**: offset/limit + meta情報

## API Base URL

```
Production:  https://stream-aggregator-api.railway.app
Development: http://localhost:8000
```

## 認証ヘッダー

```http
Authorization: Bearer {supabase_jwt_token}
Content-Type: application/json
```

---

## 🔐 OAuth認証・ユーザー管理

### POST /api/auth/twitch/callback

**Twitch OAuth コールバック処理（フロントエンド統合用）**

```http
POST /api/auth/twitch/callback
Content-Type: application/json

{
  "code": "authorization_code_from_twitch",
  "state": "random_state_string"
}
```

**Response Success (200):**

```json
{
  "access_token": "twitch_access_token",
  "refresh_token": "twitch_refresh_token",
  "expires_in": 3600,
  "expires_at": "2025-08-08T10:00:00.000Z",
  "user": {
    "id": "twitch_user_id",
    "login": "username",
    "display_name": "Display Name",
    "profile_image_url": "https://static-cdn.jtvnw.net/..."
  },
  "platform": "twitch"
}
```

### POST /api/auth/youtube/callback

**YouTube OAuth コールバック処理（フロントエンド統合用）**

```http
POST /api/auth/youtube/callback
Content-Type: application/json

{
  "code": "authorization_code_from_google",
  "state": "random_state_string"
}
```

**Response Success (200):**

```json
{
  "access_token": "google_access_token",
  "refresh_token": "google_refresh_token",
  "expires_in": 3600,
  "expires_at": "2025-08-08T10:00:00.000Z",
  "user": {
    "id": "google_user_id",
    "name": "User Name",
    "picture": "https://lh3.googleusercontent.com/...",
    "email": "user@gmail.com"
  },
  "platform": "youtube"
}
```

### POST /api/auth/twitch/refresh

**Twitchトークンリフレッシュ**

### POST /api/auth/youtube/refresh

**YouTubeトークンリフレッシュ**

### POST /api/auth/login

**ユーザーログイン（Supabase Auth連携）**

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response Success (200):**

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "user@example.com",
      "username": "user123",
      "display_name": "User Display Name",
      "is_admin": false
    },
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 3600,
    "refresh_token": "refresh_token_here"
  }
}
```

### POST /api/auth/register

**新規ユーザー登録**

```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "newuser@example.com",
  "password": "password123",
  "username": "newuser123",
  "display_name": "New User"
}
```

### POST /api/auth/refresh

**トークンリフレッシュ**

```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "refresh_token_here"
}
```

### GET /api/auth/me

**現在のユーザー情報取得**

```http
GET /api/auth/me
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "username": "user123",
    "display_name": "User Display Name",
    "is_admin": false
  }
}
```

### PUT /api/auth/me

**ユーザー情報更新**

```http
PUT /api/auth/me
Authorization: Bearer {token}
Content-Type: application/json

{
  "username": "updated_username",
  "display_name": "Updated Display Name"
}
```

### POST /api/auth/logout

**ログアウト**

```http
POST /api/auth/logout
Authorization: Bearer {token}
```

---

## 🏢 プラットフォーム管理

### GET /api/platforms

**サポート対象プラットフォーム一覧取得**

```http
GET /api/platforms
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "platforms": [
      {
        "id": "platform-uuid-youtube",
        "name": "youtube",
        "display_name": "YouTube",
        "api_base_url": "https://www.googleapis.com/youtube/v3",
        "oauth_url": "https://accounts.google.com/o/oauth2/auth",
        "required_scopes": ["https://www.googleapis.com/auth/youtube.readonly"],
        "is_active": true,
        "created_at": "2025-08-07T10:00:00Z"
      },
      {
        "id": "platform-uuid-twitch",
        "name": "twitch",
        "display_name": "Twitch",
        "api_base_url": "https://api.twitch.tv/helix",
        "oauth_url": "https://id.twitch.tv/oauth2/authorize",
        "required_scopes": ["user:read:follows"],
        "is_active": true,
        "created_at": "2025-08-07T10:00:00Z"
      }
    ]
  }
}
```

---

## 🔑 APIキー管理

### GET /api/user-api-keys

**ユーザーのAPIキー一覧取得**

```http
GET /api/user-api-keys?platform_id={uuid}&is_active=true
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "api_keys": [
      {
        "id": "api-key-uuid",
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "platform_id": "platform-uuid-youtube",
        "access_token": "ya29.a0AfH6SMC...", // 実際は暗号化またはマスク
        "refresh_token": "1//04...",
        "token_expires_at": "2025-08-08T10:00:00Z",
        "is_active": true,
        "created_at": "2025-08-07T10:00:00Z",
        "updated_at": "2025-08-07T10:00:00Z",
        "platform": {
          "name": "youtube",
          "display_name": "YouTube"
        }
      }
    ]
  }
}
```

### POST /api/user-api-keys

**新しいAPIキーの登録**

```http
POST /api/user-api-keys
Authorization: Bearer {token}
Content-Type: application/json

{
  "platform_id": "platform-uuid-youtube",
  "access_token": "ya29.a0AfH6SMC...",
  "refresh_token": "1//04...",
  "token_expires_at": "2025-08-08T10:00:00Z"
}
```

### PUT /api/user-api-keys/{api_key_id}

**APIキーの更新**

```http
PUT /api/user-api-keys/api-key-uuid
Authorization: Bearer {token}
Content-Type: application/json

{
  "access_token": "new_access_token",
  "token_expires_at": "2025-08-09T10:00:00Z",
  "is_active": true
}
```

### DELETE /api/user-api-keys/{api_key_id}

**APIキーの削除**

```http
DELETE /api/user-api-keys/api-key-uuid
Authorization: Bearer {token}
```

---

## 📺 チャンネル管理

### GET /api/channels

**登録チャンネル一覧取得**

```http
GET /api/channels?platform_id={uuid}&is_subscribed=true&is_active=true&page=1&per_page=20
Authorization: Bearer {token}
```

**Query Parameters:**

- `platform_id` (UUID, optional): プラットフォームでフィルタ
- `is_subscribed` (boolean, optional): 購読状態でフィルタ
- `is_active` (boolean, optional): アクティブ状態でフィルタ
- `page` (integer, optional): ページ番号 (default: 1)
- `per_page` (integer, optional): 1ページあたりの件数 (default: 20, max: 100)

**Response (200):**

```json
{
  "success": true,
  "data": {
    "channels": [
      {
        "id": "channel-uuid",
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "platform_id": "platform-uuid-youtube",
        "channel_id": "UCxxxxxxxxxxxxxxxxxxxxxx",
        "channel_name": "Example Gaming Channel",
        "display_name": "Example Gaming",
        "avatar_url": "https://yt3.ggpht.com/...",
        "is_subscribed": true,
        "is_active": true,
        "created_at": "2025-08-07T10:00:00Z",
        "updated_at": "2025-08-07T10:00:00Z",
        "platform": {
          "name": "youtube",
          "display_name": "YouTube"
        }
      }
    ],
    "meta": {
      "total_count": 25,
      "page": 1,
      "per_page": 20,
      "has_next": true,
      "has_prev": false
    }
  }
}
```

### GET /api/channels/{channel_id}

**特定チャンネル詳細取得**

```http
GET /api/channels/channel-uuid
Authorization: Bearer {token}
```

### POST /api/channels

**新しいチャンネル登録**

```http
POST /api/channels
Authorization: Bearer {token}
Content-Type: application/json

{
  "platform_id": "platform-uuid-youtube",
  "channel_id": "UCxxxxxxxxxxxxxxxxxxxxxx",
  "channel_name": "New Gaming Channel",
  "display_name": "New Gaming",
  "avatar_url": "https://yt3.ggpht.com/..."
}
```

**Response (201):**

```json
{
  "success": true,
  "data": {
    "channel": {
      "id": "new-channel-uuid",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "platform_id": "platform-uuid-youtube",
      "channel_id": "UCxxxxxxxxxxxxxxxxxxxxxx",
      "channel_name": "New Gaming Channel",
      "display_name": "New Gaming",
      "avatar_url": "https://yt3.ggpht.com/...",
      "is_subscribed": true,
      "is_active": true,
      "created_at": "2025-08-07T10:30:00Z",
      "updated_at": "2025-08-07T10:30:00Z"
    }
  }
}
```

### PUT /api/channels/{channel_id}

**チャンネル情報更新**

```http
PUT /api/channels/channel-uuid
Authorization: Bearer {token}
Content-Type: application/json

{
  "display_name": "Updated Channel Name",
  "is_subscribed": false,
  "is_active": true
}
```

### DELETE /api/channels/{channel_id}

**チャンネル削除**

```http
DELETE /api/channels/channel-uuid
Authorization: Bearer {token}
```

**Response (204):** No Content

---

## 📡 配信データ管理

### GET /api/streams

**配信一覧取得（フロントエンド統合仕様）**

```http
GET /api/streams?platform=all&category=Apex Legends&limit=20&offset=0&sort=viewers
Authorization: Bearer {token}
```

**Query Parameters（フロントエンド仕様準拠）:**

- `platform` (enum): `all` | `youtube` | `twitch`
- `category` (string, optional): ゲームカテゴリ名
- `limit` (integer, optional): 取得件数 (default: 20, max: 100)
- `offset` (integer, optional): オフセット (default: 0)
- `sort` (enum, optional): ソート方式 (`viewers`, `recent`)

**Response (200) - フロントエンド統合形式:**

```json
{
  "streams": [
    {
      "id": "dQw4w9WgXcQ",
      "title": "【Apex Legends】ランク配信やります！",
      "channelName": "Example Gaming Channel",
      "thumbnailUrl": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
      "viewerCount": 15234,
      "duration": "3:42:15",
      "platform": "youtube",
      "category": "Apex Legends",
      "isLive": true,
      "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "hasMore": true
  }
}
```

### GET /api/streams/{stream_id}

**特定配信詳細取得**

```http
GET /api/streams/stream-uuid
Authorization: Bearer {token}
```

### POST /api/streams/refresh

**配信データの強制更新**

```http
POST /api/streams/refresh
Authorization: Bearer {token}
Content-Type: application/json

{
  "channel_ids": ["channel-uuid-1", "channel-uuid-2"],
  "force_refresh": true
}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "refreshed_at": "2025-08-07T10:30:00Z",
    "total_channels_checked": 15,
    "total_streams_found": 25,
    "total_streams_updated": 8,
    "errors": [
      {
        "channel_id": "channel-uuid-error",
        "platform": "youtube",
        "error_code": "RATE_LIMITED",
        "error_message": "YouTube API rate limit exceeded"
      }
    ],
    "streams": [
      // 更新された配信データの配列
    ]
  }
}
```

---

## 🔍 検索機能

### GET /api/streams/search

**配信検索（全文検索対応）**

```http
GET /api/streams/search?query=gaming tournament&platform_id={uuid}&is_live=true&min_viewers=1000
Authorization: Bearer {token}
```

**Query Parameters:**

- `query` (string, optional): タイトル・説明・ゲーム名での全文検索
- `platform_id` (UUID, optional): プラットフォームでフィルタ
- `game_name` (string, optional): ゲーム名完全一致
- `tags` (string[], optional): タグでフィルタ（配列）
- `min_viewers` (integer, optional): 最小視聴者数
- `max_viewers` (integer, optional): 最大視聴者数
- `is_live` (boolean, optional): ライブ状態でフィルタ
- `started_after` (ISO datetime, optional): 開始時刻下限
- `started_before` (ISO datetime, optional): 開始時刻上限
- `limit` (integer, optional): 取得件数 (default: 20, max: 100)
- `offset` (integer, optional): オフセット (default: 0)

**Response (200):**

```json
{
  "success": true,
  "data": {
    "streams": [
      // 検索結果の配信データ配列
    ],
    "meta": {
      "total_count": 42,
      "page": 1,
      "per_page": 20,
      "has_next": true,
      "has_prev": false
    },
    "search_meta": {
      "query": "gaming tournament",
      "total_matches": 42,
      "search_time_ms": 156
    }
  }
}
```

---

## 🔗 OAuth連携

### GET /api/oauth/authorize/{platform}

**OAuth認証URL生成**

```http
GET /api/oauth/authorize/youtube?redirect_uri=https://example.com/callback
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "authorization_url": "https://accounts.google.com/o/oauth2/auth?client_id=...&redirect_uri=...&scope=...&state=...",
    "state": "random_state_string"
  }
}
```

### POST /api/oauth/callback/{platform}

**OAuth認証コールバック処理**

```http
POST /api/oauth/callback/youtube
Authorization: Bearer {token}
Content-Type: application/json

{
  "code": "authorization_code_from_oauth",
  "state": "random_state_string"
}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "user_api_key": {
      "id": "new-api-key-uuid",
      "platform_id": "platform-uuid-youtube",
      "access_token": "ya29.a0AfH6SMC...",
      "refresh_token": "1//04...",
      "token_expires_at": "2025-08-08T10:00:00Z",
      "is_active": true
    },
    "platform_user_info": {
      "channel_id": "UCxxxxxxxxxxxxxxxxxxxxxx",
      "title": "User's Channel",
      "description": "Channel description",
      "thumbnail_url": "https://yt3.ggpht.com/...",
      "subscriber_count": 1500
    }
  }
}
```

---

## ⚡ システム・ヘルスチェック

### GET /api/health

**システムヘルスチェック**

```http
GET /api/health
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "version": "1.0.0",
    "timestamp": "2025-08-07T10:30:00Z",
    "checks": {
      "database": {
        "status": "up",
        "response_time_ms": 15,
        "last_check_at": "2025-08-07T10:30:00Z"
      },
      "youtube_api": {
        "status": "up",
        "response_time_ms": 245,
        "last_check_at": "2025-08-07T10:30:00Z"
      },
      "twitch_api": {
        "status": "up",
        "response_time_ms": 180,
        "last_check_at": "2025-08-07T10:30:00Z"
      },
      "supabase_auth": {
        "status": "up",
        "response_time_ms": 95,
        "last_check_at": "2025-08-07T10:30:00Z"
      }
    },
    "uptime_seconds": 86400
  }
}
```

### GET /api/config

**アプリケーション設定取得（認証済みユーザー）**

```http
GET /api/config
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "success": true,
  "data": {
    "app_name": "Stream Aggregator API",
    "app_version": "1.0.0",
    "environment": "production",
    "api_base_url": "https://stream-aggregator-api.railway.app",
    "supported_platforms": ["youtube", "twitch", "kick"],
    "pagination": {
      "default_per_page": 20,
      "max_per_page": 100
    },
    "refresh": {
      "default_interval_minutes": 1,
      "max_channels_per_request": 50
    }
  }
}
```

---

## 📊 統計・分析 (Future Enhancement)

### GET /api/stats/user

**ユーザー統計情報**

```http
GET /api/stats/user
Authorization: Bearer {token}
```

### GET /api/stats/channels

**チャンネル統計情報**

```http
GET /api/stats/channels
Authorization: Bearer {token}
```

---

## ❌ エラーレスポンス例

### 400 Bad Request

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "validation_errors": [
        {
          "field": "email",
          "message": "Invalid email format",
          "code": "invalid_format"
        }
      ]
    }
  }
}
```

### 401 Unauthorized

```json
{
  "success": false,
  "error": {
    "code": "TOKEN_EXPIRED",
    "message": "JWT token has expired",
    "details": {
      "token_expires_at": "2025-08-07T10:00:00Z"
    }
  }
}
```

### 403 Forbidden (RLS Violation)

```json
{
  "success": false,
  "error": {
    "code": "RLS_VIOLATION",
    "message": "Access denied by row level security policy",
    "details": {
      "user_id": "550e8400-e29b-41d4-a716-446655440000"
    }
  }
}
```

### 404 Not Found

```json
{
  "success": false,
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Requested resource not found"
  }
}
```

### 429 Too Many Requests

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

### 500 Internal Server Error

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An internal server error occurred"
  }
}
```

### 503 Service Unavailable

```json
{
  "success": false,
  "error": {
    "code": "API_UNAVAILABLE",
    "message": "External API service temporarily unavailable",
    "details": {
      "platform": "youtube",
      "retry_after_seconds": 300
    }
  }
}
```

---

## 🎮 ゲーム・カテゴリ管理（フロントエンド統合仕様）

### GET /api/games/categories

**ゲームカテゴリ一覧取得**

```http
GET /api/games/categories
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "categories": [
    {
      "name": "Apex Legends",
      "streamCount": 150,
      "viewerCount": 45000
    },
    {
      "name": "Minecraft",
      "streamCount": 230,
      "viewerCount": 32000
    },
    {
      "name": "VALORANT",
      "streamCount": 89,
      "viewerCount": 28000
    }
  ]
}
```

### GET /api/games/{gameName}/streams

**特定ゲームの配信一覧**

```http
GET /api/games/Apex%20Legends/streams?limit=20&offset=0
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "game": "Apex Legends",
  "streams": [
    // Stream objects (同じ形式)
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "hasMore": true
  }
}
```

## 📊 データ正規化システム

### ゲーム名正規化

**YouTube タイトルからのゲーム抽出:**

```
【Apex Legends】ランク配信 → "Apex Legends"
【マイクラ】建築やります → "Minecraft"
```

### プラットフォーム統合

**異なるプラットフォームデータの統一:**

- Twitch: `category` フィールドを直接使用
- YouTube: タイトル解析でゲーム名抽出
- 共通: `Stream` インターフェースに変換

## 🌐 フロントエンド統合要件

### 必須エンドポイント

1. **配信データAPI**: `/api/streams` (フィルタ・ソート対応)
2. **OAuth認証**: `/api/auth/{platform}/callback`
3. **ゲームカテゴリ**: `/api/games/categories`
4. **トークン管理**: `/api/auth/{platform}/refresh`

### レスポンス形式統一

- フロントエンドの `Stream` インターフェースに準拠
- キャメルケース使用（`viewerCount`, `channelName`など）
- 配列データは `streams`、メタ情報は `pagination`

## 🚀 実装優先度（フロントエンド統合重視）

### Phase 1 (MVP - フロントエンド統合)

1. **OAuth認証API** - Twitch/YouTube コールバック処理
2. **配信データAPI** - `/api/streams` フロントエンド仕様準拠
3. **ゲームカテゴリAPI** - `/api/games/categories`
4. **データ正規化** - ゲーム名マッピングシステム

### Phase 2 (Enhanced - 運用最適化)

1. **リアルタイム更新** - 1-2分間隔キャッシュ
2. **エラーハンドリング** - フロントエンド対応エラー形式
3. **パフォーマンス** - 並列API呼び出し最適化
4. **監視・ログ** - Railway環境対応

### Phase 3 (Advanced - 機能拡張)

1. **統計・分析** - ダッシュボード用データ
2. **Webhook対応** - リアルタイム通知
3. **管理者機能** - システム設定管理
4. **スケーリング** - 複数インスタンス対応

---

**作成日**: 2025-08-07  
**バージョン**: 1.0  
**設計者**: Stream Aggregator開発チーム
