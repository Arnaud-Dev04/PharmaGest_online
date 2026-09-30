from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import date
from typing import Optional

from app.database import get_local_db
from app.models.user import User
from app.models.settings import Settings
from app.auth.dependencies import get_super_admin_user, get_current_active_user, get_admin_user

router = APIRouter()

class LicenseUpdate(BaseModel):
    expiry_date: date

class LicenseResponse(BaseModel):
    expiry_date: Optional[date]
    is_valid: bool
    days_remaining: Optional[int]

@router.get("/license", response_model=LicenseResponse)
async def get_license(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    setting = db.query(Settings).filter(Settings.key == "license_expiry_date").first()
    
    expiry_date = None
    if setting and setting.value:
        try:
            expiry_date = date.fromisoformat(setting.value)
        except ValueError:
            pass
            
    is_valid = False
    days_remaining = None
    
    if expiry_date:
        today = date.today()
        is_valid = expiry_date >= today
        days_remaining = (expiry_date - today).days
        
    return LicenseResponse(
        expiry_date=expiry_date,
        is_valid=is_valid,
        days_remaining=days_remaining
    )

@router.post("/license", response_model=LicenseResponse)
async def update_license(
    license_data: LicenseUpdate,
    current_user: User = Depends(get_super_admin_user),
    db: Session = Depends(get_local_db)
):
    setting = db.query(Settings).filter(Settings.key == "license_expiry_date").first()
    
    if setting:
        setting.value = license_data.expiry_date.isoformat()
    else:
        setting = Settings(key="license_expiry_date", value=license_data.expiry_date.isoformat())
        db.add(setting)
        
    db.commit()
    
    # Re-fetch logic (could be shared function)
    expiry_date = license_data.expiry_date
    today = date.today()
    is_valid = expiry_date >= today
    days_remaining = (expiry_date - today).days
    
    return LicenseResponse(
        expiry_date=expiry_date,
        is_valid=is_valid,
        days_remaining=days_remaining
    )

class ResetDataRequest(BaseModel):
    sales: bool = False
    products: bool = False
    users: bool = False

@router.post("/reset", status_code=status.HTTP_200_OK)
async def reset_data(
    reset_data: ResetDataRequest,
    current_user: User = Depends(get_super_admin_user),
    db: Session = Depends(get_local_db)
):
    from app.models.sales import Sale, SaleItem
    from app.models.medicine import Medicine
    from app.models.restock import RestockOrder, RestockItem
    
    deleted_counts = {}

    
    try:
        # Dependency enforcement:
        # 1. If we delete users, we MUST delete sales (FK: sales.user_id -> users.id)
        if reset_data.users:
            reset_data.sales = True
            
        # 1. Clear Sales (History)
        if reset_data.sales or reset_data.products:
            # If we delete products, we MUST delete sales to avoid orphan/FK errors
            # (unless we implemented soft delete, but here we do hard delete)
            sale_items_count = db.query(SaleItem).delete()
            sales_count = db.query(Sale).delete()
            deleted_counts['sales'] = sales_count
            deleted_counts['sale_items'] = sale_items_count
            
        # 2. Clear Products (Stock)
        if reset_data.products:
            # Also clear Restock history (purchases from suppliers)
            restock_items_count = db.query(RestockItem).delete()
            restock_orders_count = db.query(RestockOrder).delete()
            
            # Now clear medicines
            medicines_count = db.query(Medicine).delete()
            deleted_counts['medicines'] = medicines_count
            deleted_counts['restock_orders'] = restock_orders_count
            deleted_counts['restock_items'] = restock_items_count
            
        # 3. Clear Users (except super_admin)
        if reset_data.users:
            # Don't delete self or other super admins
            count = db.query(User).filter(User.role != "super_admin").delete()
            deleted_counts['users'] = count
            
        db.commit()
        
        return {"message": "Data reset successful", "deleted": deleted_counts}
        
    except Exception as e:
        db.rollback()
        print(f"Error resetting data: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error resetting data: {str(e)}"
        )


@router.get("/deletion-logs")
async def get_deletion_logs(
    entity_type: Optional[str] = None,
    action: Optional[str] = None,
    entity_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_local_db)
):
    """
    Get audit deletion and modification logs for medicines and cancelled sales.
    Accessible to Admin and Super Admin.
    """
    from app.services import audit_service
    result = audit_service.get_deletion_logs(
        db=db,
        entity_type=entity_type,
        action=action,
        entity_id=entity_id,
        start_date=start_date,
        end_date=end_date,
        search=search,
        limit=limit,
        offset=offset
    )
    return result


