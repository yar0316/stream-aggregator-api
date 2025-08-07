-- ============================================================================
-- Stream Aggregator API Database Schema Design
-- 
-- 既存のSupabaseスキーマ (contexts/sqls/*.sql) をベースとした
-- FastAPI実装向けの詳細設計とインデックス最適化
--
-- Created: 2025-08-07
-- Version: 1.0
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. テーブル構成概要
-- ----------------------------------------------------------------------------

/*
テーブル関係図:

auth.users (Supabase Auth)
    │
    └── users (1:1) ← handle_new_user() トリガーで自動作成
         ├── user_api_keys (1:N)
         │    └── platforms (N:1)
         ├── channels (1:N)
         │    ├── platforms (N:1)
         │    └── streams (1:N)
         └── [RLS] 各テーブルで user_id による行レベル制御

platforms (マスターテーブル)
    ├── user_api_keys (1:N)
    └── channels (1:N)

system_settings (設定テーブル - 管理者のみ)
*/

-- ----------------------------------------------------------------------------
-- 2. 実装時の重要な考慮事項
-- ----------------------------------------------------------------------------

/*
【FastAPI実装での重要ポイント】

1. RLS (Row Level Security) の活用
   - すべてのクエリで auth.uid() による自動フィルタリング
   - SupabaseクライアントでのJWT設定必須

2. UNIQUE制約の活用
   - user_api_keys: (user_id, platform_id)
   - channels: (user_id, platform_id, channel_id)
   - 重複チェックは制約に任せる

3. インデックス戦略
   - 複合インデックスで検索性能を最適化
   - 全文検索インデックス (GIN) で配信検索

4. 型安全性
   - TEXT[] 配列型の適切な処理
   - TIMESTAMPTZ の UTC管理
   - UUID の適切なバリデーション

5. トリガー連携
   - handle_new_user() による自動ユーザー作成
   - updated_at の自動更新
*/

-- ----------------------------------------------------------------------------
-- 3. テーブル定義 (既存スキーマの詳細説明)
-- ----------------------------------------------------------------------------

-- 3.1 Users Table
/*
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,           -- Supabase Auth と同期
    username VARCHAR(100) UNIQUE NOT NULL,        -- URL安全な一意識別子
    display_name VARCHAR(255),                    -- 表示用名前（NULL可）
    is_active BOOLEAN DEFAULT true,               -- アカウント有効性
    is_admin BOOLEAN DEFAULT false,               -- 管理者フラグ（RLS用）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

【FastAPI実装での注意点】
- id は auth.uid() と一致する必要がある
- email, username のユニーク制約エラーハンドリング必須
- display_name は NULL 許可（username をデフォルト表示）
- is_admin は管理機能実装時に使用
*/

-- 3.2 Platforms Table
/*
CREATE TABLE platforms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,             -- 'youtube', 'twitch', 'kick'
    display_name VARCHAR(100) NOT NULL,           -- 'YouTube', 'Twitch', 'Kick'
    api_base_url TEXT,                           -- API エンドポイント
    oauth_url TEXT,                              -- OAuth 認証URL
    required_scopes TEXT[],                      -- 必要権限スコープ
    is_active BOOLEAN DEFAULT true,              -- プラットフォーム有効性
    created_at TIMESTAMPTZ DEFAULT NOW()
);

【FastAPI実装での注意点】
- name は Platform 型の enum と一致させる
- required_scopes は OAuth実装で使用
- is_active = false で一時的な無効化が可能
- 初期データは migration で投入
*/

-- 3.3 System Settings Table
/*
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,            -- 設定キー
    value TEXT NOT NULL,                         -- 設定値
    description TEXT,                            -- 設定説明
    is_encrypted BOOLEAN DEFAULT false,          -- 暗号化フラグ
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

【FastAPI実装での注意点】
- APIキーなどの秘匿情報は is_encrypted = true
- 管理者のみアクセス可能 (RLS)
- 設定変更時の updated_at 更新
- 暗号化実装は app/core/security.py で対応
*/

-- 3.4 User API Keys Table
/*
CREATE TABLE user_api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    platform_id UUID REFERENCES platforms(id),
    access_token TEXT NOT NULL,                  -- OAuth アクセストークン
    refresh_token TEXT,                          -- OAuth リフレッシュトークン
    token_expires_at TIMESTAMPTZ,               -- トークン有効期限
    is_active BOOLEAN DEFAULT true,              -- トークン有効性
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform_id)               -- プラットフォーム毎に1つ
);

【FastAPI実装での注意点】
- UNIQUE制約により重複OAuth連携を防止
- token_expires_at での自動トークン更新ロジック
- 秘匿情報のログ出力禁止
- CASCADE削除でユーザー削除時に自動削除
*/

-- 3.5 Channels Table
/*
CREATE TABLE channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    platform_id UUID REFERENCES platforms(id),
    channel_id VARCHAR(100) NOT NULL,           -- プラットフォーム固有ID
    channel_name VARCHAR(255) NOT NULL,         -- チャンネル名
    display_name VARCHAR(255),                  -- 表示用名前
    avatar_url TEXT,                            -- アバター画像URL
    is_subscribed BOOLEAN DEFAULT true,          -- ユーザーが購読中か
    is_active BOOLEAN DEFAULT true,              -- チャンネル有効性
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform_id, channel_id)   -- ユーザー毎の重複防止
);

【FastAPI実装での注意点】
- channel_id はプラットフォーム固有の識別子
- is_subscribed = false で一時的な購読停止
- avatar_url は外部API取得時に更新
- 複合UNIQUE制約でユーザー毎の重複防止
*/

-- 3.6 Streams Table
/*
CREATE TABLE streams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID REFERENCES channels(id),
    platform_stream_id VARCHAR(100) NOT NULL,   -- 配信固有ID
    title TEXT NOT NULL,                        -- 配信タイトル
    description TEXT,                           -- 配信説明
    thumbnail_url TEXT,                         -- サムネイルURL
    viewer_count INTEGER DEFAULT 0,             -- 視聴者数
    game_name VARCHAR(255),                     -- ゲーム/カテゴリ名
    tags TEXT[],                               -- タグ配列
    started_at TIMESTAMPTZ NOT NULL,           -- 配信開始時刻
    is_live BOOLEAN DEFAULT true,               -- ライブ状態
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

【FastAPI実装での注意点】
- platform_stream_id はプラットフォーム固有の配信ID
- tags TEXT[] の配列操作（SQLAlchemy/Pydantic対応）
- is_live = false で終了した配信
- viewer_count はリアルタイム更新対象
*/

-- ----------------------------------------------------------------------------
-- 4. インデックス設計 (パフォーマンス最適化)
-- ----------------------------------------------------------------------------

-- 4.1 既存インデックス
/*
CREATE INDEX idx_user_api_keys_user_platform ON user_api_keys(user_id, platform_id);
CREATE INDEX idx_channels_user_platform ON channels(user_id, platform_id);
CREATE INDEX idx_streams_search ON streams USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '') || ' ' || COALESCE(game_name, '')));
CREATE INDEX idx_streams_live ON streams(is_live, started_at DESC);
*/

-- 4.2 追加推奨インデックス (FastAPI実装用)

-- ユーザー検索最適化
CREATE INDEX idx_users_active_email ON users(is_active, email);
CREATE INDEX idx_users_username ON users(username) WHERE is_active = true;

-- APIキー期限チェック最適化
CREATE INDEX idx_user_api_keys_expiry ON user_api_keys(token_expires_at, is_active) 
WHERE token_expires_at IS NOT NULL;

-- チャンネル検索最適化
CREATE INDEX idx_channels_subscribed ON channels(user_id, is_subscribed, is_active);
CREATE INDEX idx_channels_platform_active ON channels(platform_id, is_active);

-- 配信検索最適化（複数条件）
CREATE INDEX idx_streams_channel_live ON streams(channel_id, is_live, started_at DESC);
CREATE INDEX idx_streams_platform_live ON streams(channel_id, is_live) 
INCLUDE (platform_stream_id, title, viewer_count, started_at);

-- 配信統計用インデックス
CREATE INDEX idx_streams_stats ON streams(is_live, started_at, viewer_count DESC);

-- タグ検索最適化
CREATE INDEX idx_streams_tags ON streams USING gin(tags);

-- 4.3 部分インデックス (条件付きインデックス)

-- アクティブなチャンネルのみ
CREATE INDEX idx_channels_active_only ON channels(user_id, platform_id) 
WHERE is_active = true AND is_subscribed = true;

-- ライブ配信のみ
CREATE INDEX idx_streams_live_only ON streams(started_at DESC, viewer_count DESC) 
WHERE is_live = true;

-- 最近の配信（30日以内）
CREATE INDEX idx_streams_recent ON streams(channel_id, started_at DESC) 
WHERE started_at > (NOW() - INTERVAL '30 days');

-- ----------------------------------------------------------------------------
-- 5. Row Level Security (RLS) ポリシー解説
-- ----------------------------------------------------------------------------

/*
【RLS実装のポイント】

1. auth.uid() による自動フィルタリング
   - Supabase JWTから自動的にuser_idを取得
   - FastAPIでは Supabase Client に JWT設定が必須

2. ポリシーの種類
   - SELECT: データ参照権限
   - INSERT/UPDATE/DELETE: データ変更権限
   - ALL: 全操作権限

3. ユーザーデータの分離
   - users: 自分の情報のみアクセス
   - user_api_keys: 自分のAPIキーのみアクセス
   - channels: 自分の登録チャンネルのみアクセス
   - streams: 自分の登録チャンネルの配信のみアクセス

4. 管理者権限
   - is_admin = true のユーザーは全データアクセス可能
   - system_settings, platforms の管理権限

5. パブリックデータ
   - platforms: 認証済みユーザーは全員参照可能
*/

-- ----------------------------------------------------------------------------
-- 6. トリガー関数の実装詳細
-- ----------------------------------------------------------------------------

-- 6.1 handle_new_user() の動作
/*
1. auth.users に新規ユーザー作成時に自動実行
2. email, username, display_name を users テーブルに複製
3. username のデフォルト値: email の @ より前部分
4. display_name のデフォルト値: username と同じ

【FastAPI実装での考慮点】
- 新規ユーザー作成はSupabase Authで実行
- users テーブルへの直接INSERT は不要
- ユーザー情報更新は users テーブルで実行
*/

-- 6.2 updated_at 自動更新トリガー (実装推奨)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 各テーブルにトリガーを設定
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_api_keys_updated_at BEFORE UPDATE ON user_api_keys 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_channels_updated_at BEFORE UPDATE ON channels 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_streams_updated_at BEFORE UPDATE ON streams 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 7. データ制約とビジネスルール
-- ----------------------------------------------------------------------------

-- 7.1 CHECK制約の追加 (データ整合性向上)

-- ユーザー名の形式チェック
ALTER TABLE users ADD CONSTRAINT check_username_format 
CHECK (username ~ '^[a-z0-9_]{3,30}$');

-- メールアドレスの基本形式チェック
ALTER TABLE users ADD CONSTRAINT check_email_format 
CHECK (email ~ '^[^@]+@[^@]+\.[^@]+$');

-- プラットフォーム名の制限
ALTER TABLE platforms ADD CONSTRAINT check_platform_name 
CHECK (name ~ '^[a-z]+$');

-- チャンネルIDの非空チェック
ALTER TABLE channels ADD CONSTRAINT check_channel_id_not_empty 
CHECK (LENGTH(TRIM(channel_id)) > 0);

-- 配信タイトルの非空チェック
ALTER TABLE streams ADD CONSTRAINT check_title_not_empty 
CHECK (LENGTH(TRIM(title)) > 0);

-- 視聴者数の範囲チェック
ALTER TABLE streams ADD CONSTRAINT check_viewer_count_range 
CHECK (viewer_count >= 0 AND viewer_count <= 2147483647);

-- 配信開始時刻の妥当性チェック
ALTER TABLE streams ADD CONSTRAINT check_started_at_range 
CHECK (started_at >= '2020-01-01'::TIMESTAMPTZ AND started_at <= NOW() + INTERVAL '1 day');

-- 7.2 ビジネスルール関数

-- プラットフォーム毎のチャンネル数制限チェック
CREATE OR REPLACE FUNCTION check_channel_limit()
RETURNS TRIGGER AS $$
DECLARE
    channel_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO channel_count
    FROM channels 
    WHERE user_id = NEW.user_id 
    AND platform_id = NEW.platform_id 
    AND is_active = true;
    
    IF channel_count >= 100 THEN  -- プラットフォーム毎に最大100チャンネル
        RAISE EXCEPTION 'Maximum channel limit reached for this platform';
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER enforce_channel_limit 
BEFORE INSERT ON channels 
FOR EACH ROW EXECUTE FUNCTION check_channel_limit();

-- 古い配信データの自動削除関数 (定期実行用)
CREATE OR REPLACE FUNCTION cleanup_old_streams()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM streams 
    WHERE is_live = false 
    AND started_at < (NOW() - INTERVAL '30 days');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ language 'plpgsql';

-- ----------------------------------------------------------------------------
-- 8. ビュー定義 (クエリ最適化用)
-- ----------------------------------------------------------------------------

-- 8.1 アクティブチャンネル一覧ビュー
CREATE OR REPLACE VIEW active_channels AS
SELECT 
    c.id,
    c.user_id,
    c.channel_id,
    c.channel_name,
    c.display_name,
    c.avatar_url,
    c.created_at,
    c.updated_at,
    p.name as platform_name,
    p.display_name as platform_display_name
FROM channels c
JOIN platforms p ON c.platform_id = p.id
WHERE c.is_active = true 
AND c.is_subscribed = true 
AND p.is_active = true;

-- 8.2 ライブ配信一覧ビュー
CREATE OR REPLACE VIEW live_streams AS
SELECT 
    s.id,
    s.platform_stream_id,
    s.title,
    s.description,
    s.thumbnail_url,
    s.viewer_count,
    s.game_name,
    s.tags,
    s.started_at,
    s.created_at,
    c.channel_name,
    c.display_name as channel_display_name,
    c.avatar_url as channel_avatar,
    p.name as platform_name,
    p.display_name as platform_display_name,
    c.user_id
FROM streams s
JOIN channels c ON s.channel_id = c.id
JOIN platforms p ON c.platform_id = p.id
WHERE s.is_live = true
AND c.is_active = true
AND c.is_subscribed = true
AND p.is_active = true
ORDER BY s.viewer_count DESC, s.started_at DESC;

-- 8.3 ユーザー統計ビュー
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.id as user_id,
    u.username,
    u.display_name,
    COUNT(DISTINCT c.id) as total_channels,
    COUNT(DISTINCT CASE WHEN c.is_subscribed THEN c.id END) as subscribed_channels,
    COUNT(DISTINCT s.id) as total_streams,
    COUNT(DISTINCT CASE WHEN s.is_live THEN s.id END) as live_streams,
    MAX(s.started_at) as last_stream_at
FROM users u
LEFT JOIN channels c ON u.id = c.user_id
LEFT JOIN streams s ON c.id = s.channel_id
WHERE u.is_active = true
GROUP BY u.id, u.username, u.display_name;

-- ----------------------------------------------------------------------------
-- 9. データマイグレーション スクリプト
-- ----------------------------------------------------------------------------

-- 9.1 初期プラットフォームデータ
INSERT INTO platforms (name, display_name, api_base_url, oauth_url, required_scopes) 
VALUES
    ('youtube', 'YouTube', 'https://www.googleapis.com/youtube/v3', 
     'https://accounts.google.com/o/oauth2/auth', 
     ARRAY['https://www.googleapis.com/auth/youtube.readonly']),
    ('twitch', 'Twitch', 'https://api.twitch.tv/helix', 
     'https://id.twitch.tv/oauth2/authorize', 
     ARRAY['user:read:follows']),
    ('kick', 'Kick', 'https://kick.com/api/v1', 
     'https://kick.com/oauth/authorize', 
     ARRAY['read'])
ON CONFLICT (name) DO NOTHING;

-- 9.2 初期システム設定
INSERT INTO system_settings (key, value, description, is_encrypted) 
VALUES
    ('youtube_client_id', '', 'YouTube OAuth Client ID', false),
    ('youtube_client_secret', '', 'YouTube OAuth Client Secret', true),
    ('twitch_client_id', '', 'Twitch OAuth Client ID', false),
    ('twitch_client_secret', '', 'Twitch OAuth Client Secret', true),
    ('kick_client_id', '', 'Kick OAuth Client ID', false),
    ('kick_client_secret', '', 'Kick OAuth Client Secret', true),
    ('refresh_interval_minutes', '1', 'Default refresh interval in minutes', false),
    ('max_channels_per_user', '1000', 'Maximum channels per user', false),
    ('cleanup_old_streams_days', '30', 'Days to keep old stream data', false)
ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 10. パフォーマンスモニタリング用クエリ
-- ----------------------------------------------------------------------------

-- 10.1 スロークエリ検出用ビュー
CREATE OR REPLACE VIEW slow_queries AS
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation,
    most_common_vals,
    most_common_freqs
FROM pg_stats 
WHERE schemaname = 'public'
ORDER BY tablename, attname;

-- 10.2 インデックス使用状況確認
CREATE OR REPLACE VIEW index_usage AS
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_tup_read = 0 THEN 0
        ELSE (idx_tup_fetch::float / idx_tup_read::float * 100)::decimal(5,2)
    END as hit_rate
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'
ORDER BY hit_rate DESC;

-- 10.3 テーブルサイズ確認
CREATE OR REPLACE VIEW table_sizes AS
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY size_bytes DESC;

-- ============================================================================
-- 以上でデータベーススキーマ設計完了
-- ============================================================================

/*
【次のステップ: FastAPI実装】

1. app/models/ でPydanticモデル定義
2. app/database.py でSupabase接続設定
3. app/core/auth.py でJWT認証実装
4. app/services/ でビジネスロジック実装
5. app/api/ でAPIエンドポイント実装

【テスト実装】

1. tests/test_models.py でモデルテスト
2. tests/test_auth.py で認証テスト
3. tests/test_api.py でAPIテスト
4. tests/test_rls.py でRLSテスト

【運用監視】

1. ヘルスチェックエンドポイント
2. ログ構造化
3. メトリクス収集
4. アラート設定
*/