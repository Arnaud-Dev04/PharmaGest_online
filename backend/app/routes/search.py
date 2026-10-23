"""
Global Unified Search endpoint (Ctrl+K Command Palette).
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Dict, Any

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user
from app.models.medicine import Medicine
from app.models.customer import Customer
from app.models.pos_sale import POSSale
from app.models.supplier import Supplier

router = APIRouter(prefix="/search", tags=["Global Search"])


@router.get("", summary="Recherche globale unifiée")
def global_search(
    q: str = Query(..., min_length=2, description="Terme de recherche"),
    limit_per_category: int = Query(5, ge=1, le=20),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
) -> Dict[str, Any]:
    """
    Effectue une recherche textuelle rapide sur :
    - Médicaments (nom, DCI, code)
    - Clients (nom, prénom, téléphone)
    - Ventes POS (code, nom client, téléphone)
    - Fournisseurs (nom, email, téléphone)

    Tous les résultats sont automatiquement cloisonnés au tenant de l'utilisateur.
    """
    pattern = f"%{q}%"

    # Médicaments
    medicines = (
        db.query(Medicine)
        .filter(
            (Medicine.name.ilike(pattern))
            | (Medicine.dci.ilike(pattern))
            | (Medicine.code.ilike(pattern))
        )
        .limit(limit_per_category)
        .all()
    )

    # Clients
    customers = (
        db.query(Customer)
        .filter(
            (Customer.first_name.ilike(pattern))
            | (Customer.last_name.ilike(pattern))
            | (Customer.phone.ilike(pattern))
        )
        .limit(limit_per_category)
        .all()
    )

    # Ventes POS
    sales = (
        db.query(POSSale)
        .filter(
            (POSSale.code.ilike(pattern))
            | (POSSale.customer_name.ilike(pattern))
            | (POSSale.customer_phone.ilike(pattern))
        )
        .order_by(POSSale.date.desc())
        .limit(limit_per_category)
        .all()
    )

    # Fournisseurs
    suppliers = (
        db.query(Supplier)
        .filter(
            (Supplier.name.ilike(pattern))
            | (Supplier.phone.ilike(pattern))
            | (Supplier.email.ilike(pattern))
        )
        .limit(limit_per_category)
        .all()
    )

    return {
        "query": q,
        "results": {
            "medicines": [
                {
                    "id": m.id,
                    "code": m.code,
                    "name": m.name,
                    "dci": m.dci,
                    "quantity": m.quantity,
                    "price_sell": m.price_sell,
                }
                for m in medicines
            ],
            "customers": [
                {
                    "id": c.id,
                    "name": f"{c.first_name or ''} {c.last_name or ''}".strip(),
                    "phone": c.phone,
                    "points": c.total_points,
                }
                for c in customers
            ],
            "sales": [
                {
                    "id": s.id,
                    "code": s.code,
                    "total_amount": s.total_amount,
                    "date": s.date.isoformat() if s.date else None,
                    "status": s.status,
                    "payment_method": s.payment_method,
                }
                for s in sales
            ],
            "suppliers": [
                {
                    "id": sp.id,
                    "name": sp.name,
                    "phone": sp.phone,
                    "email": sp.email,
                }
                for sp in suppliers
            ],
        },
        "total_matches": len(medicines) + len(customers) + len(sales) + len(suppliers),
    }
