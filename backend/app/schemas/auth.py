"""
Authentication schemas for request/response validation.
"""

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from app.models.user import UserRole


# ============================================================================
# LOGIN SCHEMAS
# ============================================================================

class UserLogin(BaseModel):
    """Schema for user login request."""
    username: str = Field(..., min_length=3, max_length=50, description="Username")
    password: str = Field(..., min_length=4, description="Password")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "username": "admin",
                    "password": "admin123"
                }
            ]
        }
    }


# ============================================================================
# REGISTRATION SCHEMAS
# ============================================================================

class UserCreate(BaseModel):
    """Schema for creating a new user (admin only)."""
    username: str = Field(..., min_length=3, max_length=50, description="Username (unique)")
    password: str = Field(..., min_length=4, description="Password")
    role: UserRole = Field(default=UserRole.PHARMACIST, description="User role")
    is_active: bool = Field(default=True, description="Account active status")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "username": "pharmacist1",
                    "password": "securepass123",
                    "role": "pharmacist",
                    "is_active": True
                }
            ]
        }
    }


# ============================================================================
# TOKEN SCHEMAS
# ============================================================================

class Token(BaseModel):
    """Schema for JWT token response."""
    access_token: str = Field(..., description="JWT access token")
    token_type: str = Field(default="bearer", description="Token type")
    must_change_password: bool = Field(default=False, description="User must change password on first login")
    is_first_setup: bool = Field(default=False, description="System is in first-time setup mode")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                    "token_type": "bearer",
                    "must_change_password": False,
                    "is_first_setup": False
                }
            ]
        }
    }


class TokenData(BaseModel):
    """Schema for decoded token data."""
    username: Optional[str] = None


# ============================================================================
# USER RESPONSE SCHEMAS
# ============================================================================

class UserResponse(BaseModel):
    """Schema for user data in responses."""
    id: int
    username: str
    role: UserRole
    is_active: bool
    must_change_password: bool = False
    created_at: datetime
    updated_at: datetime
    
    model_config = {
        "from_attributes": True,  # Enable ORM mode for SQLAlchemy models
        "json_schema_extra": {
            "examples": [
                {
                    "id": 1,
                    "username": "arnaud",
                    "role": "super_admin",
                    "is_active": True,
                    "must_change_password": False,
                    "created_at": "2025-12-11T09:00:00Z",
                    "updated_at": "2025-12-11T09:00:00Z"
                }
            ]
        }
    }


class UserInDB(UserResponse):
    """Schema for user data including password hash (internal use only)."""
    password_hash: str


class UserUpdatePassword(BaseModel):
    """Schema for updating user password."""
    password: str = Field(..., min_length=4, description="New password")


class ChangeInitialPassword(BaseModel):
    """Schema for first-login password change."""
    new_password: str = Field(..., min_length=4, description="New password")
    confirm_password: str = Field(..., min_length=4, description="Password confirmation")
