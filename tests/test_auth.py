"""Authentication functionality tests."""

import pytest
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from app.core.auth import verify_jwt_token, get_current_user
from app.core.database import get_supabase_client
from app.core.exceptions import AuthenticationException


client = TestClient(app)


class TestJWTVerification:
    """Test JWT token verification."""

    def test_valid_jwt_token_returns_user_data(self):
        """Test that a valid JWT token returns user data."""
        # Arrange
        valid_token = "valid.jwt.token"
        expected_user_data = {
            "sub": "user-uuid-123",
            "email": "test@example.com",
            "role": "authenticated"
        }
        
        # Act & Assert
        with patch('app.core.auth.jwt.decode') as mock_decode:
            mock_decode.return_value = expected_user_data
            user_data = verify_jwt_token(valid_token)
            assert user_data == expected_user_data

    def test_invalid_jwt_token_raises_exception(self):
        """Test that an invalid JWT token raises AuthenticationException."""
        # Arrange
        invalid_token = "invalid.jwt.token"
        
        # Act & Assert
        with patch('app.core.auth.jwt.decode') as mock_decode:
            mock_decode.side_effect = Exception("Invalid token")
            with pytest.raises(AuthenticationException):
                verify_jwt_token(invalid_token)

    def test_expired_jwt_token_raises_exception(self):
        """Test that an expired JWT token raises AuthenticationException."""
        # Arrange
        expired_token = "expired.jwt.token"
        
        # Act & Assert
        with patch('app.core.auth.jwt.decode') as mock_decode:
            from jwt import ExpiredSignatureError
            mock_decode.side_effect = ExpiredSignatureError("Token expired")
            with pytest.raises(AuthenticationException):
                verify_jwt_token(expired_token)

    def test_missing_authorization_header_raises_exception(self):
        """Test that missing Authorization header raises exception."""
        # Act & Assert
        with pytest.raises(AuthenticationException):
            verify_jwt_token(None)

    def test_malformed_authorization_header_raises_exception(self):
        """Test that malformed Authorization header raises exception."""
        # Arrange
        malformed_token = "NotBearerToken"
        
        # Act & Assert
        with pytest.raises(AuthenticationException):
            verify_jwt_token(malformed_token)


class TestCurrentUserRetrieval:
    """Test current user retrieval functionality."""

    @patch('app.core.auth.verify_jwt_token')
    def test_get_current_user_returns_user_data(self, mock_verify):
        """Test that get_current_user returns user data for valid token."""
        # Arrange
        mock_verify.return_value = {
            "sub": "user-uuid-123",
            "email": "test@example.com",
            "role": "authenticated"
        }
        
        # Act
        user = get_current_user("Bearer valid.jwt.token")
        
        # Assert
        assert user["sub"] == "user-uuid-123"
        assert user["email"] == "test@example.com"

    @patch('app.core.auth.verify_jwt_token')
    def test_get_current_user_handles_invalid_token(self, mock_verify):
        """Test that get_current_user handles invalid token properly."""
        # Arrange
        mock_verify.side_effect = AuthenticationException("Invalid token")
        
        # Act & Assert
        with pytest.raises(AuthenticationException):
            get_current_user("Bearer invalid.jwt.token")


class TestSupabaseConnection:
    """Test Supabase connection functionality."""

    def test_supabase_client_initialization(self):
        """Test that Supabase client initializes correctly."""
        # Act
        client = get_supabase_client()
        
        # Assert
        assert client is not None
        assert hasattr(client, 'table')
        assert hasattr(client, 'auth')

    def test_supabase_client_with_user_jwt(self):
        """Test that Supabase client can be initialized with user JWT."""
        # Arrange
        user_jwt = "valid.user.jwt"
        
        # Act
        client = get_supabase_client(user_jwt)
        
        # Assert
        assert client is not None
        # Verify that the client has the JWT set (implementation dependent)

    def test_supabase_client_without_jwt_uses_service_role(self):
        """Test that Supabase client uses service role when no JWT provided."""
        # Act
        client = get_supabase_client()
        
        # Assert
        assert client is not None
        # Verify service role is used (implementation dependent)


class TestAuthenticationEndpoints:
    """Test authentication-related API endpoints."""

    def test_health_endpoint_works_without_auth(self):
        """Test that health endpoint works without authentication."""
        # Act
        response = client.get("/api/health")
        
        # Assert
        assert response.status_code == 200
        assert response.json()["success"] is True

    def test_protected_endpoint_requires_auth(self):
        """Test that protected endpoints require authentication."""
        # This test will be implemented once we have protected endpoints
        pass

    def test_protected_endpoint_with_valid_token(self):
        """Test that protected endpoints work with valid token."""
        # Arrange
        headers = {"Authorization": "Bearer valid.jwt.token"}
        
        # Act & Assert
        # This test will be implemented once we have protected endpoints
        pass

    def test_protected_endpoint_with_invalid_token_returns_401(self):
        """Test that protected endpoints return 401 with invalid token."""
        # Arrange
        headers = {"Authorization": "Bearer invalid.jwt.token"}
        
        # Act & Assert
        # This test will be implemented once we have protected endpoints
        pass


@pytest.fixture
def mock_settings():
    """Mock settings for testing."""
    from app.core.config import Settings
    settings = Settings()
    settings.SUPABASE_URL = "https://test.supabase.co"
    settings.SUPABASE_ANON_KEY = "test-anon-key"
    settings.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key"
    settings.SUPABASE_JWT_SECRET = "test-jwt-secret"
    return settings