"""Authentication and JWT handling."""

import jwt
from typing import Dict, Any, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import get_settings
from app.core.exceptions import AuthenticationException

# Security scheme for FastAPI
security = HTTPBearer()
settings = get_settings()


def verify_jwt_token(token: Optional[str]) -> Dict[str, Any]:
    """
    Verify JWT token and return user data.
    
    Args:
        token: JWT token string
        
    Returns:
        Dict containing user data from token
        
    Raises:
        AuthenticationException: If token is invalid or expired
    """
    if not token:
        raise AuthenticationException("Missing authorization token")
    
    try:
        # Remove 'Bearer ' prefix if present
        if token.startswith('Bearer '):
            token = token[7:]
        
        # JWT形式チェックは削除 - jwt.decode()に任せる
        decoded = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_aud": False}  # Supabase doesn't always include aud
        )
        
        return decoded
        
    except jwt.ExpiredSignatureError:
        raise AuthenticationException("Token has expired")
    except jwt.InvalidTokenError as e:
        raise AuthenticationException(f"Invalid token: {str(e)}")
    except Exception as e:
        raise AuthenticationException(f"Token verification failed: {str(e)}")


def get_current_user(authorization: str) -> Dict[str, Any]:
    """
    Get current user from authorization header.
    
    Args:
        authorization: Authorization header value (Bearer token)
        
    Returns:
        Dict containing user data
        
    Raises:
        AuthenticationException: If authentication fails
    """
    return verify_jwt_token(authorization)


def get_current_user_dependency(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict[str, Any]:
    """
    FastAPI dependency for getting current authenticated user.
    
    Args:
        credentials: HTTP Authorization credentials from FastAPI
        
    Returns:
        Dict containing user data
        
    Raises:
        AuthenticationException: If authentication fails
    """
    if not credentials:
        raise AuthenticationException("Missing authorization credentials")
    
    return verify_jwt_token(credentials.credentials)


async def get_current_user_async(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict[str, Any]:
    """
    Async version of get_current_user_dependency.
    
    Args:
        credentials: HTTP Authorization credentials from FastAPI
        
    Returns:
        Dict containing user data
        
    Raises:
        AuthenticationException: If authentication fails
    """
    return get_current_user_dependency(credentials)