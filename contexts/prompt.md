# Stream Aggregator API セットアッププロンプト（Tsumiki AITDD + Supabase SDK 対応）

## 概要

Stream AggregatorプロジェクトのバックエンドAPI（FastAPI）リポジトリを新規作成してください。
AI支援型テスト駆動開発フレームワーク「Tsumiki」を活用し、品質ファーストの開発を行います。

## アーキテクチャ構成

```
フロントエンド (1分間隔リクエスト) → FastAPI → Supabase
                                        ↓
                                YouTube/Twitch API
```

## 要件

- 別リポジトリとして作成（フロントエンドとは分離）
- FastAPI + Railway CLI の組み合わせ使用
- Tsumiki AITDD（AI-assisted Test-Driven Development）フレームワーク活用
- Supabase Python SDK でのデータベース操作
- Supabase Auth JWT 認証
- YouTube/Twitch API からの配信データ取得（フロントエンドトリガー）
- Railway 単一インスタンスデプロイ対応

## データフロー

1. **フロントエンド**: 画面表示中のみ、1分間隔で `/api/streams/refresh` をコール
2. **FastAPI**: 外部API（YouTube/Twitch）から最新データを取得
3. **データ更新**: Supabase に最新の配信情報を保存
4. **レスポンス**: 更新された配信一覧をフロントエンドに返却

## Tsumiki AITDD フレームワーク導入

### 1. Tsumiki インストール

```bash
# Tsumiki Claude Codeスラッシュコマンドをインストール
npx @classmethod/tsumiki@latest
```

### 2. AITDD開発フロー

要件展開 → 設計 → タスク分割 → TDD実装（要件定義→テストケース作成→Red→Green→Refactor→Verify）の順序で進めます。

#### Kairoコマンド（包括的な開発フロー）

```bash
# 1. 要件定義
/kairo-requirements

# 2. 設計
/kairo-design

# 3. タスク分割
/kairo-tasks

# 4. 実装
/kairo-implement
```

## セットアップ手順

### 前提条件

- 事前に `mkdir stream-aggregator-api && cd stream-aggregator-api` でディレクトリ作成・移動済み
- ルートディレクトリ（stream-aggregator-api/）で作業開始
- Claude Code環境でTsumikiがインストール済み

### 1. Python仮想環境セットアップ

```bash
# Python仮想環境作成・有効化
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# FastAPIとUvicornをインストール
pip install "fastapi[standard]"

# プロジェクト固有ライブラリインストール
pip install supabase aiohttp python-jose passlib python-multipart pydantic-settings
pip install pytest pytest-asyncio httpx pytest-cov

# requirements.txt作成
pip freeze > requirements.txt

# Git初期化
git init
```

### 2. Railway CLI セットアップ

```bash
# Railway CLI インストール
npm install -g @railway/cli

# Railwayにログイン（ブラウザが開きます）
railway login

# 新しいプロジェクト作成
railway new
# プロンプトで:
# - プロジェクト名: stream-aggregator-api
# - チーム: 選択
```

### 3. Tsumiki AITDD プロセス開始

#### 3-1. 要件定義フェーズ

```bash
# Stream Aggregator API の要件定義を実行
/kairo-requirements
```

**要件定義の概要（プロンプトに含める情報）：**

- プロジェクト名: Stream Aggregator API
- 目的: YouTube・Twitch配信の統合管理API
- 主要機能:
  - Supabase Auth JWT認証
  - チャンネル管理（CRUD）
  - 配信情報の定期取得・更新（フロントエンドトリガー）
  - 外部API連携（YouTube Data API v3, Twitch API）
  - 検索機能・フィルタリング

#### 3-2. 設計フェーズ

```bash
# 要件定義書を基に設計を実行
/kairo-design
```

#### 3-3. タスク分割フェーズ

```bash
# 設計書を基にタスク分割を実行
/kairo-tasks
```

#### 3-4. TDD実装フェーズ

```bash
# タスク分割を基に実装を実行
/kairo-implement
```

### 4. プロジェクト構成作成（Tsumikiで自動生成される予定）

期待される構成：

```
stream-aggregator-api/
├── docs/                        # Tsumikiで自動生成される設計書
│   ├── requirements.md          # 要件定義書
│   ├── design.md               # 設計書
│   └── tasks.md                # タスク分割書
├── tests/                       # テストファイル（Tsumikiで自動生成）
│   ├── __init__.py
│   ├── test_auth.py
│   ├── test_platforms.py
│   ├── test_channels.py
│   ├── test_streams.py
│   └── test_external_api.py
├── .env.example                 # 環境変数テンプレート
├── .gitignore                  # Python用gitignore
├── README.md                   # セットアップ手順
├── requirements.txt            # 依存関係
├── railway.json               # Railway設定
├── pytest.ini                 # テスト設定
├── main.py                    # FastAPIアプリケーション
├── app/
│   ├── __init__.py
│   ├── config.py              # 設定管理
│   ├── database.py            # Supabase接続
│   ├── models/                # Pydanticモデル
│   │   ├── __init__.py
│   │   ├── user.py           # ユーザーモデル
│   │   ├── platform.py       # プラットフォームモデル
│   │   ├── channel.py        # チャンネルモデル
│   │   └── stream.py         # 配信モデル
│   ├── schemas/               # リクエスト/レスポンススキーマ
│   │   ├── __init__.py
│   │   ├── auth.py           # 認証スキーマ
│   │   ├── channel.py        # チャンネルスキーマ
│   │   └── stream.py         # 配信スキーマ
│   ├── api/
│   │   ├── __init__.py
│   │   ├── dependencies.py    # 依存性注入（認証など）
│   │   ├── auth.py           # 認証関連API
│   │   ├── platforms.py      # プラットフォーム管理API
│   │   ├── channels.py       # チャンネル管理API
│   │   └── streams.py        # 配信関連API
│   ├── core/
│   │   ├── __init__.py
│   │   ├── auth.py           # Supabase Auth 認証ロジック
│   │   └── security.py       # JWT検証・セキュリティ関数
│   └── services/
│       ├── __init__.py
│       ├── supabase_service.py  # Supabase操作サービス
│       ├── youtube_service.py   # YouTube API連携サービス
│       ├── twitch_service.py    # Twitch API連携サービス
│       └── stream_aggregator.py # 配信データ統合サービス
```

## 基本設定ファイル

### .env.example

```
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx

# JWT
JWT_SECRET_KEY=your-jwt-secret-key-here
JWT_ALGORITHM=HS256

# External APIs
YOUTUBE_API_KEY=
TWITCH_CLIENT_ID=
TWITCH_CLIENT_SECRET=

# Application
ENVIRONMENT=development
LOG_LEVEL=INFO
```

### .gitignore

```python
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
.env
.env.local

# Railway
.railway/

# Testing
.pytest_cache/
.coverage
htmlcov/
test-results/

# Tsumiki generated files
docs/generated/
.tsumiki/

# IDEs
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/
```

### railway.json

```json
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "fastapi run main.py --host 0.0.0.0 --port $PORT",
    "healthcheckPath": "/health"
  },
  "environments": {
    "production": {
      "variables": {
        "ENVIRONMENT": "production",
        "LOG_LEVEL": "WARNING"
      }
    }
  }
}
```

### pytest.ini（テスト設定）

```ini
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_functions = test_*
python_classes = Test*
addopts = 
    --verbose
    --cov=app
    --cov-report=html
    --cov-report=term-missing
    --cov-fail-under=80
asyncio_mode = auto
```

## 主要な実装コンポーネント

### 1. Supabase接続（app/database.py）

```python
from supabase import create_client, Client
from app.config import settings

def get_supabase_client() -> Client:
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)

def get_supabase_admin_client() -> Client:
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
```

### 2. 認証システム（app/core/auth.py）

```python
from supabase import Client
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer

security = HTTPBearer()

async def get_current_user(token: str = Depends(security)):
    # Supabase JWT検証ロジック
    pass
```

### 3. 外部APIサービス（app/services/youtube_service.py）

```python
import aiohttp
from typing import List
from app.models.stream import StreamModel

class YouTubeService:
    async def get_live_streams(self, channel_ids: List[str]) -> List[StreamModel]:
        # YouTube Data API v3 呼び出し
        pass
```

### 4. APIエンドポイント設計例

#### 主要エンドポイント

```python
# 認証
POST /api/auth/login          # Supabase Auth ログイン
GET  /api/auth/me            # 認証ユーザー情報取得
POST /api/auth/logout        # ログアウト

# チャンネル管理
GET    /api/channels         # 登録チャンネル一覧
POST   /api/channels         # チャンネル登録
DELETE /api/channels/{id}    # チャンネル削除

# 配信情報
GET  /api/streams           # 配信一覧取得（キャッシュ）
POST /api/streams/refresh   # 外部APIから最新データ取得・更新
GET  /api/streams/search    # 配信検索

# プラットフォーム
GET /api/platforms          # サポートプラットフォーム一覧
```

## 開発・デプロイコマンド

### ローカル開発（Tsumiki + FastAPI）

```bash
# テスト実行
pytest

# テストカバレッジ確認
pytest --cov=app --cov-report=html

# 開発サーバー起動
fastapi dev main.py

# または環境変数同期してローカル実行
railway run fastapi dev main.py
```

### Tsumiki TDD ワークフロー

```bash
# 個別のTDDサイクル実行
/tdd-red          # 失敗するテストを作成
/tdd-green        # テストを通すコードを実装
/tdd-refactor     # コードをリファクタリング
/tdd-verify-complete  # 実装完了確認
```

### デプロイ

```bash
# テスト実行後にデプロイ
pytest && railway up

# デプロイ後のログ確認
railway logs

# Railway ダッシュボードを開く
railway open
```

## README.md サンプル（Supabase SDK対応版）

```markdown
# Stream Aggregator API

YouTube・Twitch配信統合API（Tsumiki AITDD + Supabase SDK）

## アーキテクチャ

```

フロントエンド (1分間隔リクエスト) → FastAPI → Supabase
                                        ↓
                                YouTube/Twitch API

```

## 開発手法

本プロジェクトはAI支援型テスト駆動開発（AITDD）を採用しています。
- **仕様書ファースト**: 明確な要件定義
- **テストファースト**: 実装前にテスト作成
- **品質ファースト**: 継続的な品質確保

## 主要機能

- **認証**: Supabase Auth JWT
- **配信監視**: YouTube/Twitch API連携（フロントエンドトリガー）
- **リアルタイム更新**: 1分間隔での配信情報取得
- **チャンネル管理**: 登録・削除・検索機能

## セットアップ

### 前提条件
- Python 3.8+
- Node.js 18+ (Railway CLI用)
- Claude Code + Tsumiki フレームワーク
- Supabase プロジェクト

### 環境変数設定
```bash
cp .env.example .env
# .envファイルを編集してSupabaseの接続情報を設定
```

### 開発環境

```bash
# Tsumiki インストール
npx @classmethod/tsumiki@latest

# 仮想環境作成
python -m venv venv
source venv/bin/activate

# 依存関係インストール
pip install -r requirements.txt

# テスト実行
pytest

# 開発サーバー起動
fastapi dev main.py
```

## API仕様

- **Base URL**: `http://localhost:8000/api`
- **認証**: Bearer Token (Supabase JWT)
- **ドキュメント**: `/docs` (Swagger UI)

### 主要エンドポイント

| Method | Endpoint | 説明 |
|--------|----------|------|
| GET | `/streams` | 配信一覧取得 |
| POST | `/streams/refresh` | 外部APIから最新データ取得 |
| GET | `/channels` | 登録チャンネル一覧 |
| POST | `/channels` | チャンネル登録 |
| GET | `/auth/me` | 認証ユーザー情報 |

## デプロイ

```bash
# Railway デプロイ
pytest && railway up
```

```

## 完了後の確認事項

1. **Tsumikiインストール確認**: `npx @classmethod/tsumiki@latest` が実行されている
2. **AITDD文書生成**: `/kairo-requirements` で要件定義書が作成されている
3. **依存関係確認**: Supabase Python SDK がインストールされている
4. **テスト環境確認**: `pytest` でテストが実行される
5. **開発サーバー起動確認**: `fastapi dev main.py` でサーバーが起動する
6. **API確認**: `http://localhost:8000/docs` でSwagger UIが表示される
7. **認証テスト**: Supabase Auth JWT の検証ロジックがテスト済み
8. **外部API接続テスト**: YouTube/Twitch API の呼び出しがテスト済み
9. **デプロイ確認**: `railway up` でデプロイが成功する
10. **git commit完了**: 全ファイルがコミットされている

**重要**: このセットアップはSupabase Python SDKを使用した効率的なデータベース操作と、フロントエンドトリガー型の配信データ更新を実現します。WebSocketやリアルタイム通信は使用せず、シンプルで保守性の高い構成となっています。
