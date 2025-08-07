# Stream Aggregator API アーキテクチャ設計

## システム概要

Stream Aggregator APIは、YouTube・Twitch配信の統合管理を行うRESTful APIサービスです。フロントエンドからの定期的なリクエストに応じて外部API（YouTube Data API v3, Twitch API）から最新配信データを取得し、Supabaseデータベースで永続化します。Supabase Auth JWTによるステートレス認証を採用し、Railway環境での単一インスタンスデプロイをサポートします。

## アーキテクチャパターン

- **パターン**: レイヤードアーキテクチャ + Repository Pattern + Dependency Injection
- **理由**:
  - FastAPIの特性を活かした関心の分離
  - テスタビリティと保守性の向上
  - 外部API依存の抽象化による変更容易性

## コンポーネント構成

### フロントエンド（外部システム）

- **リクエストパターン**: 1分間隔でのポーリング
- **認証方式**: Bearer Token (Supabase JWT)
- **データ形式**: JSON over HTTPS

### バックエンド（Stream Aggregator API）

- **フレームワーク**: FastAPI 0.116+
- **認証方式**: Supabase Auth JWT検証
- **非同期処理**: asyncio + aiohttp
- **設定管理**: pydantic-settings
- **ログ**: 構造化ログ（JSON形式）

### データベース

- **DBMS**: Supabase (PostgreSQL)
- **接続方式**: Supabase Python SDK
- **スキーマ管理**: Supabaseマイグレーション
- **キャッシュ**: なし（シンプル構成を維持）

### 外部API連携

- **YouTube**: YouTube Data API v3
- **Twitch**: Twitch Helix API
- **レート制限**: プラットフォーム固有の制限を考慮
- **エラーハンドリング**: 個別プラットフォーム障害への耐性

## レイヤー構成

```
┌─────────────────────────────────────────────┐
│               Presentation Layer             │
│          (FastAPI Routers)                  │
├─────────────────────────────────────────────┤
│               Application Layer              │
│       (Business Logic Services)            │
├─────────────────────────────────────────────┤
│               Domain Layer                   │
│        (Models & Schemas)                   │
├─────────────────────────────────────────────┤
│             Infrastructure Layer             │
│   (Database, External APIs, Auth)          │
└─────────────────────────────────────────────┘
```

### Presentation Layer

- **責務**: HTTPリクエスト/レスポンス処理、バリデーション
- **コンポーネント**:
  - `app/api/auth.py` - 認証関連エンドポイント
  - `app/api/channels.py` - チャンネル管理エンドポイント
  - `app/api/streams.py` - 配信関連エンドポイント
  - `app/api/platforms.py` - プラットフォーム管理エンドポイント

### Application Layer

- **責務**: ビジネスロジック、オーケストレーション
- **コンポーネント**:
  - `app/services/stream_aggregator.py` - 配信データ統合
  - `app/services/supabase_service.py` - データベース操作
  - `app/services/youtube_service.py` - YouTube API連携
  - `app/services/twitch_service.py` - Twitch API連携

### Domain Layer

- **責務**: エンティティ、値オブジェクト、ドメインルール
- **コンポーネント**:
  - `app/models/` - Pydanticエンティティモデル
  - `app/schemas/` - リクエスト/レスポンススキーマ

### Infrastructure Layer

- **責務**: 外部システム連携、技術的詳細
- **コンポーネント**:
  - `app/database.py` - Supabase接続
  - `app/core/auth.py` - JWT認証
  - `app/core/security.py` - セキュリティ機能
  - `app/config.py` - 設定管理

## デプロイメント構成

### Railway環境

```
┌─────────────────────────────────────────────┐
│                Railway Cloud                │
│                                            │
│  ┌─────────────────────────────────────┐   │
│  │        Stream Aggregator API         │   │
│  │                                     │   │
│  │  ┌───────────┐ ┌─────────────────┐  │   │
│  │  │ FastAPI   │ │   Environment   │  │   │
│  │  │ Container │ │   Variables     │  │   │
│  │  └───────────┘ └─────────────────┘  │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│               External Services              │
│                                            │
│ ┌─────────────┐ ┌──────────────────────────┐ │
│ │  Supabase   │ │    External APIs         │ │
│ │ PostgreSQL  │ │ ┌──────────┐ ┌─────────┐ │ │
│ │    Auth     │ │ │ YouTube  │ │ Twitch  │ │ │
│ │             │ │ │ Data API │ │ Helix   │ │ │
│ └─────────────┘ │ └──────────┘ └─────────┘ │ │
└─────────────────────────────────────────────┘
```

## セキュリティ考慮事項

### 認証・認可

- **JWT検証**: Supabase Auth による署名検証
- **トークン管理**: フロントエンドでのトークン更新
- **CORS**: 適切なオリジン設定

### API セキュリティ

- **HTTPS**: 全通信の暗号化
- **レート制限**: FastAPI middleware による制限
- **入力検証**: Pydantic バリデーション

### データ保護

- **環境変数**: 秘匿情報の環境変数管理
- **ログ**: 秘匿情報のログ出力除外
- **データベース**: Supabase RLS (Row Level Security)

## パフォーマンス戦略

### 外部API最適化

- **並行処理**: asyncio による非同期リクエスト
- **タイムアウト**: プラットフォーム別タイムアウト設定
- **エラー処理**: プラットフォーム個別障害への対応

### データベース最適化

- **インデックス**: チャンネルID、ユーザーIDにインデックス
- **クエリ**: N+1問題の回避
- **接続管理**: Supabase SDKによる接続プール

### キャッシュ戦略

- **方針**: 初期段階ではキャッシュなし（シンプル構成維持）
- **将来拡張**: Redis導入の可能性（パフォーマンス要件次第）

## 監視・ログ

### ログ戦略

```python
# 構造化ログ例
{
    "timestamp": "2025-08-07T10:00:00Z",
    "level": "INFO",
    "service": "stream-aggregator-api",
    "module": "youtube_service",
    "message": "Successfully fetched streams",
    "data": {
        "channel_count": 5,
        "stream_count": 12,
        "duration_ms": 1250
    }
}
```

### メトリクス

- **ヘルスチェック**: `/health` エンドポイント
- **外部API**: レスポンス時間、エラー率
- **データベース**: クエリ実行時間

## 拡張可能性

### 水平スケーリング

- **ステートレス**: JWT認証によるステートレス設計
- **データベース**: Supabaseの自動スケーリング
- **Railway**: 複数インスタンス展開への拡張可能性

### 新プラットフォーム追加

- **抽象化**: `StreamPlatformService` 基底クラス
- **設定**: プラットフォーム別設定の外部化
- **テスト**: プラットフォーム別テストの分離

## 技術的負債と制約

### 現在の制約

- **単一インスタンス**: Railway環境での制約
- **キャッシュなし**: パフォーマンス vs シンプルさのトレードオフ
- **リアルタイム無し**: ポーリングによる準リアルタイム

### 将来の改善点

- **マイクロサービス**: 機能ごとのサービス分離
- **イベント駆動**: Webhook対応による真のリアルタイム
- **GraphQL**: より柔軟なデータ取得API

---

**作成日**: 2025-08-07
**バージョン**: 1.0
**設計者**: Stream Aggregator開発チーム
