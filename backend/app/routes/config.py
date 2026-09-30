"""
Configuration routes - Medicine families and types CRUD.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_admin_user
from app.schemas.medicine import (
    MedicineFamilyCreate, MedicineFamilyUpdate, MedicineFamilyResponse,
    MedicineTypeCreate, MedicineTypeUpdate, MedicineTypeResponse
)
from app.services import medicine_service

# Create router
router = APIRouter()


# ============================================================================
# MEDICINE FAMILIES
# ============================================================================

@router.get(
    "/families",
    response_model=List[MedicineFamilyResponse],
    summary="List all medicine families"
)
async def list_families(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get all medicine families.
    
    **Accessible to**: All authenticated users
    """
    families = medicine_service.get_families(db)
    return families


@router.post(
    "/families",
    response_model=MedicineFamilyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a medicine family (Admin only)"
)
async def create_family(
    family_data: MedicineFamilyCreate,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new medicine family.
    
    **Accessible to**: Admin only
    """
    try:
        family = medicine_service.create_family(db, family_data)
        return family
    except Exception as e:
        # Handle unique constraint violation
        if "UNIQUE constraint" in str(e) or "Duplicate entry" in str(e):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Family '{family_data.name}' already exists"
            )
        raise


@router.put(
    "/families/{family_id}",
    response_model=MedicineFamilyResponse,
    summary="Update a medicine family (Admin only)"
)
async def update_family(
    family_id: int,
    family_data: MedicineFamilyUpdate,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Update a medicine family.
    
    **Accessible to**: Admin only
    """
    family = medicine_service.update_family(db, family_id, family_data)
    if not family:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Family with ID {family_id} not found"
        )
    return family


@router.delete(
    "/families/{family_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a medicine family (Admin only)"
)
async def delete_family(
    family_id: int,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Delete a medicine family (only if not used by medicines).
    
    **Accessible to**: Admin only
    """
    success = medicine_service.delete_family(db, family_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Family not found or is still used by medicines"
        )


# ============================================================================
# MEDICINE TYPES
# ============================================================================

@router.get(
    "/types",
    response_model=List[MedicineTypeResponse],
    summary="List all medicine types"
)
async def list_types(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get all medicine types.
    
    **Accessible to**: All authenticated users
    """
    types = medicine_service.get_types(db)
    return types


@router.post(
    "/types",
    response_model=MedicineTypeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a medicine type (Admin only)"
)
async def create_type(
    type_data: MedicineTypeCreate,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Create a new medicine type.
    
    **Accessible to**: Admin only
    """
    try:
        med_type = medicine_service.create_type(db, type_data)
        return med_type
    except Exception as e:
        # Handle unique constraint violation
        if "UNIQUE constraint" in str(e) or "Duplicate entry" in str(e):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Type '{type_data.name}' already exists"
            )
        raise


@router.put(
    "/types/{type_id}",
    response_model=MedicineTypeResponse,
    summary="Update a medicine type (Admin only)"
)
async def update_type(
    type_id: int,
    type_data: MedicineTypeUpdate,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Update a medicine type.
    
    **Accessible to**: Admin only
    """
    med_type = medicine_service.update_type(db, type_id, type_data)
    if not med_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Type with ID {type_id} not found"
        )
    return med_type


@router.delete(
    "/types/{type_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a medicine type (Admin only)"
)
async def delete_type(
    type_id: int,
    current_admin: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Delete a medicine type (only if not used by medicines).
    
    **Accessible to**: Admin only
    """
    success = medicine_service.delete_type(db, type_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type not found or is still used by medicines"
        )
