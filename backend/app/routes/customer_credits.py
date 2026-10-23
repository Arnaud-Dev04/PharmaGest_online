"""
Customer Credits API endpoints.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional, List

from app.database import get_local_db
from app.models.user import User
from app.auth.dependencies import get_current_active_user, get_current_pharmacy_context, PharmacyContext
from app.core.license_guard import require_feature
from app.schemas.customer_credit import (
    CustomerCreditCreate,
    CustomerCreditResponse,
    CreditPaymentCreate,
    CreditSummaryResponse,
)
from app.schemas.common import PaginatedResponse
from app.services import customer_credit_service

router = APIRouter(
    dependencies=[Depends(require_feature("customer_management"))]
)


@router.post(
    "/",
    response_model=CustomerCreditResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer un crédit client",
)
def create_customer_credit(
    payload: CustomerCreditCreate,
    current_user: User = Depends(get_current_active_user),
    pharmacy_context: PharmacyContext = Depends(get_current_pharmacy_context),
    db: Session = Depends(get_local_db),
):
    try:
        credit = customer_credit_service.create_credit(
            db=db,
            pharmacy_id=pharmacy_context.pharmacy_id,
            payload=payload,
        )
        return credit
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/",
    response_model=PaginatedResponse[CustomerCreditResponse],
    summary="Lister les crédits clients",
)
def list_customer_credits(
    customer_id: Optional[int] = Query(None, description="Filtrer par ID client"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filtrer par statut"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    skip = (page - 1) * page_size
    records, total = customer_credit_service.list_credits(
        db=db,
        customer_id=customer_id,
        status=status_filter,
        skip=skip,
        limit=page_size,
    )
    return PaginatedResponse.create(
        items=records,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/summary",
    response_model=CreditSummaryResponse,
    summary="Résumé et statistiques des crédits",
)
def get_credit_summary(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    return customer_credit_service.get_credits_summary(db=db)


@router.get(
    "/{credit_id}",
    response_model=CustomerCreditResponse,
    summary="Détails d'un crédit client",
)
def get_customer_credit(
    credit_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_local_db),
):
    credit = customer_credit_service.get_credit_by_id(db=db, credit_id=credit_id)
    if not credit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Crédit avec ID {credit_id} introuvable",
        )
    return credit


@router.post(
    "/{credit_id}/payments",
    response_model=CustomerCreditResponse,
    summary="Enregistrer un remboursement de crédit",
)
def pay_customer_credit(
    credit_id: int,
    payload: CreditPaymentCreate,
    current_user: User = Depends(get_current_active_user),
    pharmacy_context: PharmacyContext = Depends(get_current_pharmacy_context),
    db: Session = Depends(get_local_db),
):
    try:
        credit = customer_credit_service.record_payment(
            db=db,
            credit_id=credit_id,
            pharmacy_id=pharmacy_context.pharmacy_id,
            user_id=current_user.id,
            payload=payload,
        )
        return credit
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
