# Stream Aggregator API 仕様書

## 概要

Stream Aggregator のバックエンドAPI連携仕様書です。YouTube API と Twitch API からライブ配信データを取得し、フロントエンドに統合されたデータを提供するためのAPI設計仕様を記載しています。

## 認証システム

### OAuth 2.0 フロー

両プラットフォーム（YouTube、Twitch）でOAuth 2.0による認証を実装。

#### 環境変数
```
# Twitch
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret

# YouTube
YOUTUBE_CLIENT_ID=your_youtube_client_id
YOUTUBE_CLIENT_SECRET=your_youtube_client_secret

# 共通
NEXTAUTH_URL=http://localhost:3000
```

#### 認証エンドポイント

##### 1. Twitch OAuth コールバック
**Endpoint:** `POST /api/auth/twitch/callback`

**Request Body:**
```json
{
  "code": "string",
  "state": "string"
}
```

**Response:**
```json
{
  "access_token": "string",
  "refresh_token": "string", 
  "expires_in": 3600,
  "expires_at": "2024-01-01T00:00:00.000Z",
  "user": {
    "id": "string",
    "login": "string",
    "display_name": "string",
    "profile_image_url": "string"
  },
  "platform": "twitch"
}
```

##### 2. YouTube OAuth コールバック
**Endpoint:** `POST /api/auth/youtube/callback`

**Request Body:**
```json
{
  "code": "string",
  "state": "string"
}
```

**Response:**
```json
{
  "access_token": "string",
  "refresh_token": "string",
  "expires_in": 3600,
  "expires_at": "2024-01-01T00:00:00.000Z",
  "user": {
    "id": "string",
    "name": "string",
    "picture": "string",
    "email": "string"
  },
  "platform": "youtube"
}
```

##### 3. トークンリフレッシュエンドポイント
**Twitch:** `POST /api/auth/twitch/refresh`
**YouTube:** `POST /api/auth/youtube/refresh`

## 必要なAPI実装

### 1. ライブ配信一覧取得

#### Endpoint
`GET /api/streams`

#### Query Parameters
```
?platform=all|youtube|twitch
&category=string
&limit=20
&offset=0
&sort=viewers|recent
```

#### Response
```json
{
  "streams": [
    {
      "id": "string",
      "title": "string",
      "channelName": "string",
      "thumbnailUrl": "string",
      "viewerCount": 12543,
      "duration": "3:42:15",
      "platform": "youtube|twitch",
      "category": "string",
      "isLive": true,
      "url": "string"
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

### 2. ゲームカテゴリ一覧取得

#### Endpoint
`GET /api/games/categories`

#### Response
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
    }
  ]
}
```

### 3. 特定ゲームの配信一覧

#### Endpoint
`GET /api/games/{gameName}/streams`

#### Response
```json
{
  "game": "Apex Legends",
  "streams": [
    // Stream objects
  ],
  "pagination": {
    // Pagination info
  }
}
```

## 外部API統合仕様

### Twitch API Integration

#### 使用エンドポイント
- **ライブ配信取得:** `GET https://api.twitch.tv/helix/streams`
- **ゲーム情報取得:** `GET https://api.twitch.tv/helix/games`
- **ユーザー情報取得:** `GET https://api.twitch.tv/helix/users`

#### 必要ヘッダー
```
Authorization: Bearer {access_token}
Client-Id: {client_id}
```

### YouTube API Integration

#### 使用エンドポイント  
- **ライブ配信検索:** `GET https://www.googleapis.com/youtube/v3/search`
- **動画詳細取得:** `GET https://www.googleapis.com/youtube/v3/videos`
- **チャンネル情報取得:** `GET https://www.googleapis.com/youtube/v3/channels`

#### 必要パラメータ
```
key: {api_key}
part: snippet,liveStreamingDetails,statistics
type: video
eventType: live
```

## データ正規化仕様

### ゲーム名正規化

既存の `game-mapping.ts` に基づいたゲーム名マッピングシステム:

```typescript
// 例: YouTube タイトル「【Apex Legends】ランク配信」 → "Apex Legends"
// 例: Twitch カテゴリ「Apex Legends」 → "Apex Legends" 
```

### 配信データ統合

異なるプラットフォームのデータを統一 `Stream` インターフェースに変換:

```typescript
interface Stream {
  id: string;           // プラットフォーム固有ID
  title: string;        // 配信タイトル
  channelName: string;  // チャンネル名
  thumbnailUrl: string; // サムネイルURL
  viewerCount: number;  // 視聴者数
  duration: string;     // 配信時間 (HH:MM:SS)
  platform: Platform;  // "youtube" | "twitch"
  category?: string;    // ゲームカテゴリ
  isLive: boolean;      // ライブフラグ
  url: string;         // 配信URL
}
```

## エラーハンドリング

### 標準エラーレスポンス
```json
{
  "error": "エラーメッセージ",
  "code": "ERROR_CODE",
  "status": 400
}
```

### エラーコード一覧
- `AUTH_REQUIRED` - 認証が必要
- `TOKEN_EXPIRED` - トークンが期限切れ  
- `INVALID_PLATFORM` - 無効なプラットフォーム指定
- `API_RATE_LIMIT` - APIレート制限超過
- `EXTERNAL_API_ERROR` - 外部API エラー

## セキュリティ考慮事項

1. **トークン管理**: アクセストークンの安全な保存と定期的な更新
2. **CORS設定**: 適切なオリジン制限
3. **レート制限**: 外部API制限に応じた内部制限実装
4. **データ検証**: 全ての入力パラメータの検証
5. **ログ記録**: 認証エラーとAPI エラーの適切なログ記録

## パフォーマンス最適化

1. **キャッシュ戦略**: 配信データの適切なキャッシュ（1-2分間隔）
2. **並列処理**: 複数プラットフォームからの同時データ取得
3. **ページネーション**: 大量データの効率的な分割取得
4. **データ圧縮**: レスポンスデータのgzip圧縮