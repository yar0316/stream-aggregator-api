"""Database connection and Supabase client management."""

from typing import Optional
from supabase import create_client, Client

from app.core.config import get_settings

settings = get_settings()


def get_supabase_client(user_jwt: Optional[str] = None) -> Client:
    """
    Create and return Supabase client.
    
    Args:
        user_jwt: Optional user JWT token for RLS authentication
                 If provided, client will use user context for RLS
                 If None, client will use service role for admin operations
                 
    Returns:
        Configured Supabase client instance
        
    Note:
        - With user_jwt: RLS policies apply, user sees only their data
        - Without user_jwt: Service role access, can see all data
    """
    supabase_url = settings.SUPABASE_URL
    
    if user_jwt:
        # Use anon key with user JWT for RLS-enabled access
        client = create_client(supabase_url, settings.SUPABASE_ANON_KEY)
        # Set the user's JWT token for RLS context
        try:
            # Supabase Python SDK方式でJWTを設定
            client.auth.set_session(user_jwt, "")
        except Exception:
            # 別の方式でJWTを設定 (ヘッダー直接設定)
            client.auth._session = {"access_token": user_jwt}
        return client
    else:
        # Use service role key for admin/system operations
        client = create_client(supabase_url, settings.SUPABASE_SERVICE_ROLE_KEY)
        return client


def get_supabase_admin_client() -> Client:
    """
    Get Supabase client with admin (service role) privileges.
    
    Returns:
        Supabase client with full database access
        
    Note:
        Use this for:
        - System operations
        - Admin functions
        - Operations that need to bypass RLS
        - Background tasks/cron jobs
    """
    return get_supabase_client(user_jwt=None)


def get_supabase_user_client(user_jwt: str) -> Client:
    """
    Get Supabase client with user context for RLS.
    
    Args:
        user_jwt: User's JWT token from Supabase Auth
        
    Returns:
        Supabase client with user context (RLS applies)
        
    Note:
        Use this for:
        - User-specific operations
        - API endpoints that serve user data
        - Operations where RLS should apply
    """
    return get_supabase_client(user_jwt=user_jwt)