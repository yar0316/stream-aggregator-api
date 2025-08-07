# Stream Aggregator API - タスク分割

## 概要

Stream Aggregator API の実装を段階的に進めるためのタスク分割です。Tsumiki AITDD (AI-assisted Test-Driven Development) 手法に基づき、テスト駆動開発で実装します。

## タスク分割戦略

### 実装優先度

1. **Phase 1 (MVP)**: フロントエンド統合に必要な最小機能
2. **Phase 2 (Enhanced)**: 運用最適化・エラーハンドリング強化
3. **Phase 3 (Advanced)**: 機能拡張・スケーリング対応

### テスト戦略

- **単体テスト**: 各関数・メソッドレベル
- **統合テスト**: APIエンドポイントレベル
- **E2Eテスト**: フロントエンド統合レベル

---

## Phase 1: MVP実装 (フロントエンド統合重視)

### 1. 基盤設定・プロジェクト初期化

#### Task 1.1: FastAPI アプリケーション基盤構築
- **概要**: FastAPIアプリの基本構造を作成
- **成果物**: `main.py`, `app/` ディレクトリ構造
- **テスト**: ヘルスチェックエンドポイント動作確認
- **優先度**: High
- **工数**: 0.5日

```python
# 期待される構造
stream-aggregator-api/
├── main.py
├── app/
│   ├── __init__.py
│   ├── core/
│   │   ├── config.py
│   │   └── security.py
│   ├── models/
│   ├── routers/
│   └── services/
```

#### Task 1.2: Supabase 接続・認証設定
- **概要**: Supabase Python SDK統合、JWTトークン検証
- **成果物**: `app/core/database.py`, `app/core/auth.py`
- **テスト**: 認証ミドルウェアの単体テスト
- **優先度**: High
- **工数**: 1日

#### Task 1.3: 基本ミドルウェア・例外ハンドラー設定
- **概要**: CORS、ロギング、例外処理の設定
- **成果物**: `app/middleware/`, `app/core/exceptions.py`
- **テスト**: ミドルウェア動作確認テスト
- **優先度**: High
- **工数**: 0.5日

### 2. データモデル・Pydantic スキーマ定義

#### Task 2.1: Pydantic データモデル作成
- **概要**: 実際のSupabase スキーマに基づくPydantic モデル定義
- **成果物**: `app/models/user.py`, `app/models/stream.py`, `app/models/platform.py`
- **テスト**: モデル validation テスト
- **優先度**: High
- **工数**: 1日

```python
# 期待されるモデル例
class StreamModel(BaseModel):
    id: str
    title: str
    channel_name: str = Field(alias="channelName")
    thumbnail_url: str = Field(alias="thumbnailUrl") 
    viewer_count: int = Field(alias="viewerCount")
    duration: str
    platform: PlatformType
    category: str
    is_live: bool = Field(alias="isLive")
    url: str
```

#### Task 2.2: API レスポンス共通スキーマ定義
- **概要**: フロントエンド期待形式に準拠したレスポンススキーマ
- **成果物**: `app/models/responses.py`
- **テスト**: レスポンス形式validation テスト
- **優先度**: High
- **工数**: 0.5日

### 3. OAuth認証システム実装

#### Task 3.1: Twitch OAuth コールバック API
- **概要**: `/api/auth/twitch/callback` エンドポイント実装
- **成果物**: `app/routers/auth.py` (Twitch部分)
- **テスト**: 認証フロー統合テスト、エラーケーステスト
- **優先度**: High
- **工数**: 1.5日

**テストケース**:
- 有効な認証コード処理
- 無効認証コード時のエラーハンドリング
- トークンリフレッシュ処理

#### Task 3.2: YouTube OAuth コールバック API
- **概要**: `/api/auth/youtube/callback` エンドポイント実装
- **成果物**: `app/routers/auth.py` (YouTube部分)
- **テスト**: Google OAuth フロー統合テスト
- **優先度**: High
- **工数**: 1.5日

#### Task 3.3: トークンリフレッシュ API
- **概要**: `/api/auth/{platform}/refresh` エンドポイント実装
- **成果物**: `app/services/oauth.py`
- **テスト**: トークン更新・有効期限チェックテスト
- **優先度**: Medium
- **工数**: 1日

### 4. 外部API統合サービス実装

#### Task 4.1: Twitch API サービス
- **概要**: Twitch Helix API統合、配信データ取得
- **成果物**: `app/services/twitch_api.py`
- **テスト**: API呼び出し・レート制限・エラーハンドリングテスト
- **優先度**: High
- **工数**: 2日

**実装範囲**:
- 配信一覧取得 (`/streams`)
- チャンネル情報取得 (`/users`, `/channels`)
- カテゴリ情報取得 (`/games`)

#### Task 4.2: YouTube API サービス
- **概要**: YouTube Data API v3統合、配信データ取得
- **成果物**: `app/services/youtube_api.py`
- **テスト**: API呼び出し・Quota管理テスト
- **優先度**: High
- **工数**: 2日

**実装範囲**:
- ライブ配信検索 (`/search`)
- チャンネル詳細取得 (`/channels`)
- 動画情報取得 (`/videos`)

#### Task 4.3: データ正規化サービス
- **概要**: プラットフォーム間データ統一、ゲーム名正規化
- **成果物**: `app/services/data_normalizer.py`
- **テスト**: ゲーム名抽出・データ変換テスト
- **優先度**: High
- **工数**: 1.5日

**実装機能**:
- YouTube タイトル解析 (`【Apex Legends】` → `"Apex Legends"`)
- プラットフォーム統一Stream形式変換
- ゲーム名マッピング辞書

### 5. 配信データ管理 API実装

#### Task 5.1: 配信一覧取得 API
- **概要**: `/api/streams` エンドポイント (フロントエンド統合仕様準拠)
- **成果物**: `app/routers/streams.py`
- **テスト**: フィルタ・ソート・ページネーション統合テスト
- **優先度**: High
- **工数**: 2日

**実装機能**:
- プラットフォームフィルタ (`platform=all|youtube|twitch`)
- ゲームカテゴリフィルタ (`category`)
- ソート機能 (`sort=viewers|recent`)
- ページネーション (`limit`, `offset`)

#### Task 5.2: ゲームカテゴリ管理 API
- **概要**: `/api/games/categories` エンドポイント実装
- **成果物**: `app/routers/games.py`
- **テスト**: カテゴリ集計・統計データテスト
- **優先度**: High
- **工数**: 1日

#### Task 5.3: 配信データ更新・キャッシュサービス
- **概要**: 外部APIからの定期データ取得・更新機能
- **成果物**: `app/services/stream_updater.py`
- **テスト**: バッチ処理・エラー回復テスト
- **優先度**: High
- **工数**: 2日

### 6. システム管理 API

#### Task 6.1: ヘルスチェック API
- **概要**: `/api/health` エンドポイント、システム状態監視
- **成果物**: `app/routers/health.py`
- **テスト**: 各種サービス接続確認テスト
- **優先度**: Medium
- **工数**: 0.5日

#### Task 6.2: 設定管理 API
- **概要**: `/api/config` エンドポイント、アプリケーション設定取得
- **成果物**: `app/routers/config.py`
- **テスト**: 設定情報取得・権限チェックテスト
- **優先度**: Medium
- **工数**: 0.5日

---

## Phase 2: Enhanced実装 (運用最適化)

### 7. エラーハンドリング・ログ強化

#### Task 7.1: 構造化ログシステム
- **概要**: JSON形式ログ、ログレベル管理、外部監視連携
- **成果物**: `app/core/logging.py`
- **テスト**: ログ出力・フィルタリングテスト
- **優先度**: Medium
- **工数**: 1日

#### Task 7.2: カスタム例外・エラーレスポンス
- **概要**: API特有例外クラス、フロントエンド対応エラー形式
- **成果物**: `app/core/exceptions.py` 拡張
- **テスト**: 各種エラーケース網羅テスト
- **優先度**: Medium  
- **工数**: 1日

### 8. パフォーマンス最適化

#### Task 8.1: レート制限・API制御
- **概要**: 外部API呼び出し制限、ユーザーレート制限
- **成果物**: `app/services/rate_limiter.py`
- **テスト**: レート制限動作・回復テスト
- **優先度**: Medium
- **工数**: 1.5日

#### Task 8.2: 並列処理・非同期最適化
- **概要**: 複数プラットフォーム並列取得、asyncio活用
- **成果物**: `app/services/concurrent_fetcher.py`
- **テスト**: 並列処理・タイムアウト処理テスト
- **優先度**: Medium
- **工数**: 2日

#### Task 8.3: データベース最適化
- **概要**: クエリ最適化、インデックス活用、接続プール管理
- **成果物**: `app/core/database.py` 拡張
- **テスト**: パフォーマンステスト
- **優先度**: Medium
- **工数**: 1.5日

---

## 実装工程表

### Week 1-2: Phase 1 Core (14日)
- Task 1.1-1.3: 基盤構築 (2日)
- Task 2.1-2.2: データモデル (1.5日)
- Task 3.1-3.3: OAuth認証 (4日)
- Task 4.1-4.3: 外部API統合 (5.5日)
- バッファ・テスト調整 (1日)

### Week 3: Phase 1 API (7日)
- Task 5.1-5.3: 配信データAPI (5日)
- Task 6.1-6.2: システム管理API (1日)
- 統合テスト・デバッグ (1日)

### Week 4: Phase 2 Enhancement (7日)
- Task 7.1-7.2: エラーハンドリング (2日)
- Task 8.1-8.3: パフォーマンス (5日)

---

**作成日**: 2025-08-07  
**バージョン**: 1.0  
**更新者**: Stream Aggregator開発チーム