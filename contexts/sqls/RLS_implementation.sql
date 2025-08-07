-- Row Level Security (RLS) ポリシー設定

-- 1. RLS有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE streams ENABLE ROW LEVEL SECURITY;

-- platforms, system_settingsは管理者のみなのでRLS不要

-- 2. usersテーブルのポリシー
-- ユーザーは自分の情報のみ参照可能
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

-- ユーザーは自分の情報のみ更新可能
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

-- 新規ユーザー登録時の挿入を許可
CREATE POLICY "Enable insert for authenticated users" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. user_api_keysテーブルのポリシー
-- ユーザーは自分のAPIキーのみ参照可能
CREATE POLICY "Users can view own API keys" ON user_api_keys
    FOR SELECT USING (auth.uid() = user_id);

-- ユーザーは自分のAPIキーのみ挿入・更新・削除可能
CREATE POLICY "Users can manage own API keys" ON user_api_keys
    FOR ALL USING (auth.uid() = user_id);

-- 4. channelsテーブルのポリシー
-- ユーザーは自分の登録チャンネルのみ参照可能
CREATE POLICY "Users can view own channels" ON channels
    FOR SELECT USING (auth.uid() = user_id);

-- ユーザーは自分のチャンネルのみ管理可能
CREATE POLICY "Users can manage own channels" ON channels
    FOR ALL USING (auth.uid() = user_id);

-- 5. streamsテーブルのポリシー
-- 配信情報は、そのユーザーが登録しているチャンネルのもののみ参照可能
CREATE POLICY "Users can view streams from subscribed channels" ON streams
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM channels 
            WHERE channels.id = streams.channel_id 
            AND channels.user_id = auth.uid()
            AND channels.is_subscribed = true
        )
    );

-- 配信情報の挿入・更新・削除は、そのユーザーのチャンネルのもののみ
CREATE POLICY "Users can manage streams from own channels" ON streams
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM channels 
            WHERE channels.id = streams.channel_id 
            AND channels.user_id = auth.uid()
        )
    );

-- 6. 管理者権限の設定（将来的な拡張用）
-- 管理者フラグをusersテーブルに追加
ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT false;

-- 管理者は全てのデータにアクセス可能なポリシーを追加
CREATE POLICY "Admins can view all users" ON users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users admin_user 
            WHERE admin_user.id = auth.uid() 
            AND admin_user.is_admin = true
        )
    );

-- system_settingsは管理者のみアクセス可能
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins can manage system settings" ON system_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.is_admin = true
        )
    );

-- platformsテーブルは全ユーザーが読み取り可能、管理者のみ変更可能
ALTER TABLE platforms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can view platforms" ON platforms
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Only admins can manage platforms" ON platforms
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.is_admin = true
        )
    );