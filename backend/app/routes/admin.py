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

class ResetDataRequest(BaseModel):
    sales: bool = False
    products: bool = False
    users: bool = False

@router.post("/reset", status_code=status.HTTP_200_OK)
def reset_data(
    reset_data: ResetDataRequest,
    current_user: User = Depends(get_super_admin_user),
    db: Session = Depends(get_local_db)
):
    import os
    if os.getenv("ENVIRONMENT") == "production":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Reset operation is disabled in production"
        )

    from app.models.sales import Sale, SaleItem
    from app.models.medicine import Medicine
    from app.models.restock import RestockOrder, RestockItem
    from app.models.pos_sale import POSSale, POSSaleItem
    from app.models.cash_register import CashRegisterSession, CashRegisterMovement
    from app.models.medicine_pricing import MedicinePricing
    from app.models.batch import Batch
    from app.models.stock_movement import StockMovement
    
    deleted_counts = {}
    
    try:
        # Dependency enforcement:
        # 1. If we delete users, we MUST delete sales (FK: sales.user_id -> users.id)
        if reset_data.users:
            reset_data.sales = True
            
        # 1. Clear Sales (History)
        if reset_data.sales or reset_data.products:
            db.query(POSSaleItem).delete()
            db.query(POSSale).delete()
            db.query(CashRegisterMovement).delete()
            db.query(CashRegisterSession).delete()
            sale_items_count = db.query(SaleItem).delete()
            sales_count = db.query(Sale).delete()
            deleted_counts['sales'] = sales_count
            deleted_counts['sale_items'] = sale_items_count
            
        # 2. Clear Products (Stock)
        if reset_data.products:
            db.query(StockMovement).delete()
            db.query(MedicinePricing).delete()
            db.query(Batch).delete()
            restock_items_count = db.query(RestockItem).delete()
            restock_orders_count = db.query(RestockOrder).delete()
            
            # Now clear medicines
            medicines_count = db.query(Medicine).delete()
            deleted_counts['medicines'] = medicines_count
            deleted_counts['restock_orders'] = restock_orders_count
            deleted_counts['restock_items'] = restock_items_count
            
        # 3. Clear Users (except super_admin)
        if reset_data.users:
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
def get_deletion_logs(
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


