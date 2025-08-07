"""Custom application exceptions."""

from typing import Any, Dict, Optional


class AppException(Exception):
    """Base application exception."""
    
    def __init__(
        self,
        message: str,
        status_code: int = 500,
        error_code: str = "INTERNAL_ERROR",
        details: Optional[Dict[str, Any]] = None
    ):
        """Initialize exception."""
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}
        super().__init__(self.message)


class ValidationException(AppException):
    """Validation error exception."""
    
    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        """Initialize validation exception."""
        super().__init__(
            message=message,
            status_code=400,
            error_code="VALIDATION_ERROR",
            details=details
        )


class AuthenticationException(AppException):
    """Authentication error exception."""
    
    def __init__(self, message: str = "Authentication required", details: Optional[Dict[str, Any]] = None):
        """Initialize authentication exception."""
        super().__init__(
            message=message,
            status_code=401,
            error_code="AUTHENTICATION_REQUIRED",
            details=details
        )


class AuthorizationException(AppException):
    """Authorization error exception."""
    
    def __init__(self, message: str = "Access denied", details: Optional[Dict[str, Any]] = None):
        """Initialize authorization exception."""
        super().__init__(
            message=message,
            status_code=403,
            error_code="ACCESS_DENIED",
            details=details
        )


class NotFoundException(AppException):
    """Resource not found exception."""
    
    def __init__(self, message: str = "Resource not found", details: Optional[Dict[str, Any]] = None):
        """Initialize not found exception."""
        super().__init__(
            message=message,
            status_code=404,
            error_code="RESOURCE_NOT_FOUND",
            details=details
        )


class ConflictException(AppException):
    """Resource conflict exception."""
    
    def __init__(self, message: str = "Resource conflict", details: Optional[Dict[str, Any]] = None):
        """Initialize conflict exception."""
        super().__init__(
            message=message,
            status_code=409,
            error_code="RESOURCE_CONFLICT",
            details=details
        )


class RateLimitException(AppException):
    """Rate limit exceeded exception."""
    
    def __init__(self, message: str = "Rate limit exceeded", retry_after: int = 60):
        """Initialize rate limit exception."""
        super().__init__(
            message=message,
            status_code=429,
            error_code="RATE_LIMITED",
            details={"retry_after_seconds": retry_after}
        )


class ExternalAPIException(AppException):
    """External API error exception."""
    
    def __init__(self, message: str, platform: str, details: Optional[Dict[str, Any]] = None):
        """Initialize external API exception."""
        details = details or {}
        details["platform"] = platform
        super().__init__(
            message=message,
            status_code=503,
            error_code="API_UNAVAILABLE",
            details=details
        )