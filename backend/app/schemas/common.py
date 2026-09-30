"""
Common schemas for pagination and reusable components.
"""

from pydantic import BaseModel, Field
from typing import List, TypeVar, Generic
from math import ceil

# Generic type for paginated responses
T = TypeVar('T')


class PaginationParams(BaseModel):
    """
    Pagination parameters for list endpoints.
    """
    page: int = Field(default=1, ge=1, description="Page number (starts at 1)")
    page_size: int = Field(default=50, ge=1, le=100, description="Items per page (max 100)")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "page": 1,
                    "page_size": 50
                }
            ]
        }
    }


class PaginatedResponse(BaseModel, Generic[T]):
    """
    Generic paginated response wrapper.
    """
    items: List[T] = Field(..., description="List of items for current page")
    total: int = Field(..., description="Total number of items")
    page: int = Field(..., description="Current page number")
    page_size: int = Field(..., description="Number of items per page")
    total_pages: int = Field(..., description="Total number of pages")
    
    @classmethod
    def create(cls, items: List[T], total: int, page: int, page_size: int):
        """
        Create a paginated response.
        
        Args:
            items: List of items for the current page
            total: Total number of items
            page: Current page number
            page_size: Items per page
        """
        total_pages = ceil(total / page_size) if page_size > 0 else 0
        return cls(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages
        )
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "items": [],
                    "total": 150,
                    "page": 1,
                    "page_size": 50,
                    "total_pages": 3
                }
            ]
        }
    }
