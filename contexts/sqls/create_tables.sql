-- Stream Aggregator データベーステーブル作成

-- 1. ユーザーテーブル
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. プラットフォームマスター
CREATE TABLE platforms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL, -- 'youtube', 'twitch', 'kick' など
    display_name VARCHAR(100) NOT NULL,
    api_base_url TEXT,
    oauth_url TEXT,
    required_scopes TEXT[], -- 必要な権限スコープ
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. システム設定テーブル
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    is_encrypted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ユーザーAPIキー管理
CREATE TABLE user_api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    platform_id UUID REFERENCES platforms(id),
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform_id)
);

-- 5. チャンネル管理
CREATE TABLE channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    platform_id UUID REFERENCES platforms(id),
    channel_id VARCHAR(100) NOT NULL, -- プラットフォーム固有のID
    channel_name VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    avatar_url TEXT,
    is_subscribed BOOLEAN DEFAULT true, -- そのユーザーが登録しているか
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform_id, channel_id)
);

-- 6. 配信情報
CREATE TABLE streams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID REFERENCES channels(id),
    platform_stream_id VARCHAR(100) NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    viewer_count INTEGER DEFAULT 0,
    game_name VARCHAR(255),
    tags TEXT[],
    started_at TIMESTAMPTZ NOT NULL,
    is_live BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX idx_user_api_keys_user_platform ON user_api_keys(user_id, platform_id);
CREATE INDEX idx_channels_user_platform ON channels(user_id, platform_id);
CREATE INDEX idx_streams_search ON streams USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '') || ' ' || COALESCE(game_name, '')));
CREATE INDEX idx_streams_live ON streams(is_live, started_at DESC);

-- 初期データ投入: プラットフォーム
INSERT INTO platforms (name, display_name, api_base_url, oauth_url, required_scopes) VALUES
('youtube', 'YouTube', 'https://www.googleapis.com/youtube/v3', 'https://accounts.google.com/o/oauth2/auth', ARRAY['https://www.googleapis.com/auth/youtube.readonly']),
('twitch', 'Twitch', 'https://api.twitch.tv/helix', 'https://id.twitch.tv/oauth2/authorize', ARRAY['user:read:follows']);

-- 初期データ投入: システム設定
INSERT INTO system_settings (key, value, description) VALUES
('youtube_client_id', '', 'YouTube OAuth Client ID'),
('youtube_client_secret', '', 'YouTube OAuth Client Secret (暗号化)'),
('twitch_client_id', '', 'Twitch OAuth Client ID'),
('twitch_client_secret', '', 'Twitch OAuth Client Secret (暗号化)');