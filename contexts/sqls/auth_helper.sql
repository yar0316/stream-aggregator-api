-- Auth Helper関数

-- 現在のユーザー情報を取得する関数
CREATE OR REPLACE FUNCTION get_current_user()
RETURNS TABLE (
    id UUID,
    email VARCHAR,
    username VARCHAR,
    display_name VARCHAR,
    is_admin BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        users.id,
        users.email,
        users.username,
        users.display_name,
        users.is_admin
    FROM users
    WHERE users.id = auth.uid();
END;
$$;

-- 新規ユーザー作成時にusersテーブルにレコード作成するトリガー関数
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO users (id, email, username, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$;

-- トリガー作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();