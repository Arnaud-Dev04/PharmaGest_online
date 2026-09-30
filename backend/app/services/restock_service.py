"""
Restock Service - Logic for supplier orders and stock replenishment.
"""

from typing import List, Tuple, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, timedelta

from app.models.restock import RestockOrder, RestockItem, RestockStatus
from app.models.medicine import Medicine
from app.models.batch import Batch
from app.models.stock_movement import StockMovement
from app.models.supplier import Supplier
from app.schemas.restock import RestockOrderCreate
from app.services.medicine_service import sync_medicine_stock
from fastapi import HTTPException, status

def create_order(db: Session, order_data: RestockOrderCreate) -> RestockOrder:
    """
    Create a new restock order in DRAFT status.
    Calculates total amount based on items.
    """
    # Verify supplier
    supplier = db.query(Supplier).filter(Supplier.id == order_data.supplier_id).first()
    if not supplier:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {order_data.supplier_id} not found"
        )

    # Calculate total
    total_amount = 0.0
    items_to_create = []

    for item in order_data.items:
        # Verify medicine exists
        medicine = db.query(Medicine).filter(Medicine.id == item.medicine_id).first()
        if not medicine:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Medicine with ID {item.medicine_id} not found"
            )
        
        line_total = item.quantity * item.price_buy
        total_amount += line_total
        
        items_to_create.append(RestockItem(
            medicine_id=item.medicine_id,
            quantity=item.quantity,
            price_buy=item.price_buy,
            expiry_date=item.expiry_date
        ))

    # Create Order
    new_order = RestockOrder(
        supplier_id=order_data.supplier_id,
        date=order_data.date,
        total_amount=total_amount,
        status=RestockStatus.DRAFT,
        items=items_to_create
    )

    db.add(new_order)
    db.commit()
    db.refresh(new_order)
    return new_order


def confirm_order(db: Session, order_id: int) -> RestockOrder:
    """
    Confirm a restock order.
    Changes status to CONFIRMED (or RECEIVED) and INCREMENTS medicine stock.
    """
    order = db.query(RestockOrder).filter(RestockOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    if order.status != RestockStatus.DRAFT:
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot confirm order in state {order.status}. Must be DRAFT."
        )

    # Update Stock through batches (Batch is the POS source of truth)
    for item in order.items:
        medicine = db.query(Medicine).filter(Medicine.id == item.medicine_id).first()
        if medicine:
            batch_ref = f"RESTOCK-{order.id}-{item.id}"
            batch = Batch(
                medicine_id=medicine.id,
                batch_number=batch_ref,
                expiration_date=item.expiry_date or medicine.expiry_date or (date.today() + timedelta(days=730)),
                quantity=item.quantity,
                purchase_price=item.price_buy,
                is_active=True,
            )
            db.add(batch)
            db.flush()

            movement = StockMovement(
                medicine_id=medicine.id,
                batch_id=batch.id,
                type="entree",
                quantite=item.quantity,
                motif=f"Réapprovisionnement commande #{order.id}",
                reference=batch_ref,
            )
            db.add(movement)

            if item.price_buy > 0:
                 medicine.price_buy = item.price_buy
            
            if item.expiry_date:
                if medicine.expiry_date is None or item.expiry_date < medicine.expiry_date:
                    medicine.expiry_date = item.expiry_date

            sync_medicine_stock(db, medicine.id)
            
    order.status = RestockStatus.CONFIRMED
    db.commit()
    db.refresh(order)
    return order


def cancel_order(db: Session, order_id: int) -> RestockOrder:
    """
    Cancel a restock order.
    If order was CONFIRMED, revert stock increments.
    """
    order = db.query(RestockOrder).filter(RestockOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    if order.status == RestockStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Order already cancelled")

    # If already confirmed, we must revert the exact restock batches.
    if order.status == RestockStatus.CONFIRMED or order.status == RestockStatus.RECEIVED:
        for item in order.items:
            medicine = db.query(Medicine).filter(Medicine.id == item.medicine_id).first()
            if medicine:
                batch_ref = f"RESTOCK-{order.id}-{item.id}"
                batch = db.query(Batch).filter(
                    Batch.medicine_id == medicine.id,
                    Batch.batch_number == batch_ref,
                ).first()

                if not batch:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Lot de réapprovisionnement introuvable pour {medicine.name}"
                    )

                if batch.quantity < item.quantity:
                    raise HTTPException(
                        status_code=400,
                        detail=(
                            f"Impossible d'annuler la commande: le lot {batch.batch_number} "
                            f"a déjà été consommé partiellement"
                        )
                    )

                batch.quantity -= item.quantity
                if batch.quantity <= 0:
                    batch.quantity = 0
                    batch.is_active = False

                movement = StockMovement(
                    medicine_id=medicine.id,
                    batch_id=batch.id,
                    type="annulation_entree",
                    quantite=-item.quantity,
                    motif=f"Annulation réapprovisionnement #{order.id}",
                    reference=batch_ref,
                )
                db.add(movement)
                sync_medicine_stock(db, medicine.id)

    order.status = RestockStatus.CANCELLED
    db.commit()
    db.refresh(order)
    return order


def get_low_stock_medicines(db: Session) -> List[Medicine]:
    """
    Get medicines with quantity <= min_stock_alert.
    Helps in creating restock orders.
    """
    return db.query(Medicine).filter(
        Medicine.quantity <= Medicine.min_stock_alert
    ).all()


def get_order(db: Session, order_id: int) -> Optional[RestockOrder]:
    return db.query(RestockOrder).filter(RestockOrder.id == order_id).first()
