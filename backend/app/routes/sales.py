"""

Sales routes - POS endpoints for creating sales and generating invoices.

"""



from fastapi import APIRouter, Depends, HTTPException, status

from fastapi.responses import StreamingResponse

from sqlalchemy.orm import Session

import logging

import traceback



from app.database import get_local_db

from app.models.user import User

from app.auth.dependencies import get_current_active_user

from app.schemas.sales import SaleCreate, SaleResponse, SaleItemResponse

from app.schemas.customer import CustomerResponse

from app.services import sales_service, pdf_service



# Create router

router = APIRouter()

logger = logging.getLogger("sales_routes")





def enrich_sale_response(sale, db: Session) -> dict:

    """Enrich sale response with calculated fields and nested data."""

    # Helper for full name

    def get_full_name(user):

        if not user:

            return None

        try:

            if user.first_name and user.last_name:

                return f"{user.first_name} {user.last_name}"

            return user.username

        except Exception:

            return "Unknown"



    # Get items with medicine details

    items = []

    for item in sale.items:

        try:

            med_name = item.medicine.name if item.medicine else "Produit supprimé"

            med_code = item.medicine.code if item.medicine else "N/A"

        except Exception:

            med_name = "Produit supprimé"

            med_code = "N/A"



        try:

            items.append(SaleItemResponse(

                id=item.id,

                medicine_id=item.medicine_id,

                medicine_name=med_name,

                medicine_code=med_code,

                quantity=item.quantity,

                unit_price=item.unit_price,

                total_price=item.total_price,

                sale_type=getattr(item, 'sale_type', 'packaging') or 'packaging',

                discount_percent=getattr(item, 'discount_percent', 0.0) or 0.0,

            ).model_dump())

        except Exception as e:

            logger.warning(f"SaleItemResponse failed for item #{item.id}: {e}")

            items.append({

                "id": item.id,

                "medicine_id": item.medicine_id,

                "medicine_name": med_name,

                "medicine_code": med_code,

                "quantity": item.quantity,

                "unit_price": item.unit_price,

                "total_price": item.total_price,

                "sale_type": "packaging",

                "discount_percent": 0.0,

            })



    # Calculate bonus earned

    bonus_earned = 0

    try:

        if sale.customer:

            bonus_earned = sales_service.calculate_bonus_points(sale.total_amount)

    except Exception:

        pass



    # Customer data

    customer_data = None

    if sale.customer:

        try:

            customer_data = {

                "id": sale.customer.id,

                "first_name": sale.customer.first_name or "",

                "last_name": sale.customer.last_name or "",

                "phone": getattr(sale.customer, 'phone', '') or "",

                "total_points": getattr(sale.customer, 'total_points', 0) or 0,

                "created_at": str(getattr(sale.customer, 'created_at', '')),

                "updated_at": str(getattr(sale.customer, 'updated_at', '')),

            }

        except Exception as e:

            logger.warning(f"Customer serialize failed for sale #{sale.id}: {e}")



    # User name

    user_name = "Unknown"

    try:

        user_name = get_full_name(sale.user) or "Unknown"

    except Exception:

        pass



    response_data = {

        "id": sale.id,

        "code": sale.code,

        "total_amount": sale.total_amount,

        "payment_method": sale.payment_method or "cash",

        "date": sale.date,

        "user_id": sale.user_id,

        "user_name": user_name,

        "status": getattr(sale, 'status', 'completed') or 'completed',

        "cancelled_at": getattr(sale, 'cancelled_at', None),

        "customer_id": sale.customer_id,

        "items": items,

        "customer": customer_data,

        "bonus_earned": bonus_earned,

        "cancelled_by": get_full_name(getattr(sale, 'cancelled_by_user', None)),

    }



    return response_data







@router.post(

    "/create",

    response_model=dict,

    status_code=status.HTTP_201_CREATED,

    summary="Create a new sale (POS)"

)

async def create_sale(

    sale_data: SaleCreate,

    current_user: User = Depends(get_current_active_user),

    db: Session = Depends(get_local_db)

):

    """

    Create a new sale transaction.

    

    This endpoint:

    - Validates stock availability

    - Creates or retrieves customer (if phone provided)

    - Generates invoice code

    - Creates sale and items

    - Decrements stock

    - Adds bonus points to customer

    

    **Accessible to**: All authenticated users (Admin, Pharmacist)

    

    **Errors**:

    - 400: Insufficient stock or validation error

    - 404: Medicine not found

    """

    try:

        sale = sales_service.create_sale(

            db=db,

            user_id=current_user.id,

            sale_data=sale_data

        )

        

        return enrich_sale_response(sale, db)

        

    except ValueError as e:

        raise HTTPException(

            status_code=status.HTTP_400_BAD_REQUEST,

            detail=str(e)

        )

    except Exception as e:

        raise HTTPException(

            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,

            detail=f"Error creating sale: {str(e)}"

        )







@router.get(

    "/history",

    summary="Get sales history with filters"

)

async def get_sales_history(

    page: int = 1,

    page_size: int = 50,

    start_date: str = None,

    end_date: str = None,

    min_amount: float = None,

    max_amount: float = None,

    user_id: int = None,

    status_filter: str = None,

    current_user: User = Depends(get_current_active_user),

    db: Session = Depends(get_local_db)

):

    """

    Get paginated sales history with optional filters.

    

    filters:

    - start_date (YYYY-MM-DD)

    - end_date (YYYY-MM-DD)

    - min_amount / max_amount

    - user_id

    - status_filter ("cancelled" or "completed")

    """

    from datetime import datetime

    

    # Process filters

    filters = {}

    if start_date:

        try:

            filters["start_date"] = datetime.strptime(start_date, "%Y-%m-%d").date()

        except ValueError:

            pass

            

    if end_date:

        try:

            filters["end_date"] = datetime.strptime(end_date, "%Y-%m-%d").date()

        except ValueError:

            pass

            

    if min_amount is not None:

        filters["min_amount"] = min_amount

        

    if max_amount is not None:

        filters["max_amount"] = max_amount

        

    if user_id:

        filters["user_id"] = user_id

        

    if status_filter:

        filters["status"] = status_filter

    

    # Get history

    try:

        sales, total = sales_service.get_sales_history(

            db=db,

            page=page,

            page_size=page_size,

            filters=filters

        )

    except Exception as e:

        logger.error(f"get_sales_history failed: {type(e).__name__}: {e}")

        logger.error(traceback.format_exc())

        raise HTTPException(status_code=500, detail=f"Erreur chargement historique: {str(e)}")

    

    # Format response

    from app.schemas.common import PaginatedResponse

    

    # Enrich items - with error handling per sale

    enriched_sales = []

    for sale in sales:

        try:

            enriched_sales.append(enrich_sale_response(sale, db))

        except Exception as e:

            logger.error(f"enrich_sale_response failed for sale #{sale.id}: {type(e).__name__}: {e}")

            logger.error(traceback.format_exc())

            # Ajouter une version minimale plutôt que crasher

            enriched_sales.append({

                "id": sale.id,

                "code": sale.code or "N/A",

                "total_amount": sale.total_amount or 0,

                "payment_method": sale.payment_method or "cash",

                "date": sale.date,

                "user_id": sale.user_id,

                "user_name": "Erreur",

                "status": getattr(sale, 'status', 'completed'),

                "cancelled_at": None,

                "customer_id": sale.customer_id,

                "items": [],

                "customer": None,

                "bonus_earned": 0,

                "cancelled_by": None,

            })

    

    return PaginatedResponse(

        total=total,

        page=page,

        page_size=page_size,

        total_pages=(total + page_size - 1) // page_size,

        items=enriched_sales

    )







@router.post(

    "/{sale_id}/cancel",

    response_model=dict,

    summary="Cancel a sale (Restock items)"

)

async def cancel_sale(

    sale_id: int,

    current_user: User = Depends(get_current_active_user),

    db: Session = Depends(get_local_db)

):

    """

    Cancel a sale, refund items to stock, and mark as cancelled.

    

    **Side effects**:

    - Updates Sale status to 'cancelled'

    - Increases Medicine stock by item quantity

    """

    from datetime import datetime

    

    # Get sale

    sale = sales_service.get_sale_by_id(db, sale_id)

    if not sale:

        raise HTTPException(

            status_code=status.HTTP_404_NOT_FOUND,

            detail=f"Sale with ID {sale_id} not found"

        )

        

    if sale.status == "cancelled":

        raise HTTPException(

            status_code=status.HTTP_400_BAD_REQUEST,

            detail="Sale is already cancelled"

        )

    

    from app.services.medicine_service import adjust_stock_to_quantity



    def _base_units_for_item(item) -> float:

        medicine = item.medicine

        total_units = medicine.units_per_packaging or 1

        sale_type = getattr(item, "sale_type", "packaging") or "packaging"

        if sale_type == "unit":

            return float(item.quantity)

        if sale_type == "blister":

            return float(item.quantity) * (medicine.units_per_blister or 1)

        if sale_type == "carton":

            return float(item.quantity) * (medicine.boxes_per_carton or 1) * total_units

        return float(item.quantity) * total_units



    # Restore stock for each item in base units and create adjustment batches

    for item in sale.items:

        medicine = item.medicine  # Access relationship

        if medicine:

            base_units = _base_units_for_item(item)

            adjust_stock_to_quantity(

                db,

                medicine,

                float(medicine.quantity or 0) + base_units,

                motif=f"Annulation vente {sale.code}",

                reference=f"CANCEL-{sale.code}",

                expiry_date=medicine.expiry_date,

            )

            

    # Update sale status

    sale.status = "cancelled"

    sale.cancelled_at = datetime.utcnow()

    sale.cancelled_by = current_user.id

    

    # If customer involved, should we revert points? 

    # For now, let's keep it simple. Usually points are deducted.

    # TODO: Implement point deduction if loyal program is strict.

    

    db.commit()

    db.refresh(sale)

    

    from app.services import audit_service

    audit_service.log_deletion(

        db=db,

        action="CANCEL_SALE",

        entity_type="sale",

        entity_id=sale.id,

        entity_name=f"Facture {sale.code}",

        user=current_user,

        details=f"Annulation vente de {sale.total_amount:.0f} FBu",

    )

    return {"message": "Sale cancelled successfully", "sale_id": sale.id}





_med_stats_cache = {}
_MED_STATS_CACHE_TTL = 30  # secondes


@router.get(
    "/medicine-stats",
    summary="Get medicine sales statistics by period"
)
async def get_medicine_sales_stats(
    start_date: str = None,
    end_date: str = None,
    limit: int = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db)
):
    """
    Get aggregated sales statistics per medicine for a given period.
    Mis en cache pendant 30s pour éviter des agrégations lentes répétées sur Aiven.
    """
    import time
    cache_key = f"{start_date}_{end_date}_{limit}"
    now = time.time()
    if cache_key in _med_stats_cache and (now - _med_stats_cache[cache_key]["ts"]) < _MED_STATS_CACHE_TTL:
        return _med_stats_cache[cache_key]["data"]

    from datetime import datetime, timedelta
    from app.models.pos_sale import POSSaleItem, POSSale
    from app.models.medicine import Medicine
    from sqlalchemy import func
    
    query = db.query(
        Medicine.id,
        Medicine.name,
        Medicine.code,
        func.sum(POSSaleItem.quantity).label('total_quantity'),
        func.sum(POSSaleItem.total_price).label('total_revenue')
    ).join(
        POSSaleItem, POSSaleItem.medicine_id == Medicine.id
    ).join(
        POSSale, POSSale.id == POSSaleItem.sale_id
    ).filter(
        POSSale.status != "cancelled"
    )
    
    if start_date:
        try:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            query = query.filter(POSSale.date >= start)
        except ValueError:
            pass
    
    if end_date:
        try:
            end = datetime.strptime(end_date, "%Y-%m-%d")
            end = end + timedelta(days=1)
            query = query.filter(POSSale.date < end)
        except ValueError:
            pass
    
    query = query.group_by(
        Medicine.id, Medicine.name, Medicine.code
    ).order_by(
        func.sum(POSSaleItem.quantity).desc()
    )
    
    if limit:
        query = query.limit(limit)
        
    results = query.all()
    
    data = [
        {
            "id": r.id,
            "name": r.name,
            "code": r.code,
            "total_quantity": int(r.total_quantity or 0),
            "total_revenue": float(r.total_revenue or 0.0)
        }
        for r in results
    ]
    _med_stats_cache[cache_key] = {"data": data, "ts": now}
    return data





@router.get(

    "/{sale_id}",

    response_model=dict,

    summary="Get sale details"

)

async def get_sale(

    sale_id: int,

    current_user: User = Depends(get_current_active_user),

    db: Session = Depends(get_local_db)

):

    """

    Get details of a specific sale.

    

    **Accessible to**: All authenticated users

    """

    sale = sales_service.get_sale_by_id(db, sale_id)

    if not sale:

        raise HTTPException(

            status_code=status.HTTP_404_NOT_FOUND,

            detail=f"Sale with ID {sale_id} not found"

        )

    

    return enrich_sale_response(sale, db)





@router.get(

    "/{sale_id}/invoice",

    summary="Download sale invoice as PDF"

)

async def download_invoice(

    sale_id: int,

    current_user: User = Depends(get_current_active_user),

    db: Session = Depends(get_local_db)

):

    """

    Generate and download a PDF invoice for a sale.

    

    **Accessible to**: All authenticated users

    """

    try:

        # Get sale details

        sale = sales_service.get_sale_by_id(db, sale_id)

        if not sale:

            raise HTTPException(

                status_code=status.HTTP_404_NOT_FOUND,

                detail=f"Sale with ID {sale_id} not found"

            )

        

        # Prepare invoice data

        invoice_data = {

            "invoice_code": sale.code,

            "date": sale.date,  # Keep as datetime object

            "seller": sale.user.username if sale.user else "N/A",

            "customer": {

                "name": f"{sale.customer.first_name} {sale.customer.last_name}",

                "phone": sale.customer.phone,

                "points_earned": 0  # Calculate if needed

            } if sale.customer else None,

            "payment_method": sale.payment_method,

            "items": [

                {

                    "medicine_name": item.medicine.name,

                    "quantity": item.quantity,

                    "unit_price": item.unit_price,

                    "total_price": item.total_price

                }

                for item in sale.items

            ],

            "total_amount": sale.total_amount

        }

        

        # Generate PDF

        pdf_buffer = pdf_service.generate_invoice_pdf(invoice_data)

        

        # Return as streaming response

        return StreamingResponse(

            pdf_buffer,

            media_type="application/pdf",

            headers={

                "Content-Disposition": f"attachment; filename=invoice_{invoice_data['invoice_code']}.pdf"

            }

        )

    except Exception as e:

        raise HTTPException(

            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,

            detail=f"Error generating PDF: {str(e)}"

        )







