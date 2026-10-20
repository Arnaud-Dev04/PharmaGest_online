"""Server-side feature entitlements based on the authenticated pharmacy plan."""

from datetime import date, datetime, timedelta

from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.dependencies import PharmacyContext, get_current_pharmacy_context
from app.models.pharmacy import Pharmacy
from app.models.user import User


PLAN_LEVELS = {"basic": 0, "pro": 1, "enterprise": 2}
FEATURE_MINIMUM_PLANS = {
    "customer_management": "pro",
    "cloud_sync": "pro",
    "sales_discounts": "pro",
    "insurance_sales": "pro",
    "sales_reports": "pro",
    "report_exports": "pro",
    "financial_reports": "pro",
    "stock_movements": "pro",
    "inventory_reconciliation": "pro",
    "audit_logs": "pro",
    "extended_sales_history": "pro",
    "customer_loyalty": "enterprise",
}
PLAN_FEATURES = {
    "basic": frozenset(),
    "pro": frozenset(
        feature for feature, minimum in FEATURE_MINIMUM_PLANS.items()
        if minimum == "pro"
    ),
    "enterprise": frozenset(FEATURE_MINIMUM_PLANS),
}


def ensure_user_capacity(db: Session, pharmacy_id: int) -> None:
    pharmacy = (
        db.query(Pharmacy)
        .filter(Pharmacy.id == pharmacy_id)
        .with_for_update()
        .populate_existing()
        .first()
    )
    if pharmacy is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Pharmacy is unavailable",
        )

    active_user_count = db.query(User).filter(
        User.pharmacy_id == pharmacy_id,
        User.is_active.is_(True),
    ).count()
    if pharmacy.max_users < 1000 and active_user_count >= pharmacy.max_users:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User limit reached for this pharmacy",
        )


def require_plan(minimum_plan: str):
    required_plan = minimum_plan.lower()
    if required_plan not in PLAN_LEVELS:
        raise ValueError(f"Unknown minimum plan: {minimum_plan}")

    async def enforce_plan(
        context: PharmacyContext = Depends(get_current_pharmacy_context),
    ) -> PharmacyContext:
        if context.is_platform_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Platform administrators do not have pharmacy plan access",
            )

        current_plan = (context.pharmacy.plan or "").lower() if context.pharmacy else ""
        if current_plan not in PLAN_LEVELS:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "PLAN_CONFIGURATION_INVALID",
                    "message": "This pharmacy has an unsupported plan configuration.",
                },
            )

        if PLAN_LEVELS[current_plan] < PLAN_LEVELS[required_plan]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "PLAN_UPGRADE_REQUIRED",
                    "message": f"This feature requires the '{required_plan}' plan or higher.",
                    "current_plan": current_plan,
                    "required_plan": required_plan,
                },
            )
        return context

    return enforce_plan


def ensure_feature_access(context: PharmacyContext, feature: str) -> None:
    minimum_plan = FEATURE_MINIMUM_PLANS.get(feature)
    if minimum_plan is None:
        raise ValueError(f"Unknown pharmacy feature: {feature}")
    if context.is_platform_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform administrators do not have pharmacy feature access",
        )

    current_plan = (context.pharmacy.plan or "").lower() if context.pharmacy else ""
    if current_plan not in PLAN_LEVELS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "PLAN_CONFIGURATION_INVALID",
                "message": "This pharmacy has an unsupported plan configuration.",
            },
        )
    if not feature_is_available(current_plan, feature):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "PLAN_UPGRADE_REQUIRED",
                "message": f"This feature requires the '{minimum_plan}' plan or higher.",
                "current_plan": current_plan,
                "required_plan": minimum_plan,
            },
        )


def feature_is_available(plan: str | None, feature: str) -> bool:
    minimum_plan = FEATURE_MINIMUM_PLANS.get(feature)
    current_plan = (plan or "").lower()
    return (
        minimum_plan is not None
        and current_plan in PLAN_LEVELS
        and PLAN_LEVELS[current_plan] >= PLAN_LEVELS[minimum_plan]
    )


def require_feature(feature: str):
    if feature not in FEATURE_MINIMUM_PLANS:
        raise ValueError(f"Unknown pharmacy feature: {feature}")

    async def enforce_feature(
        context: PharmacyContext = Depends(get_current_pharmacy_context),
    ) -> PharmacyContext:
        ensure_feature_access(context, feature)
        return context

    return enforce_feature


def apply_sales_history_limit(
    context: PharmacyContext,
    start_date: str | None,
    end_date: str | None,
    days: int = 30,
) -> str | None:
    if context.is_platform_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform administrators do not have pharmacy plan access",
        )
    current_plan = (context.pharmacy.plan or "").lower() if context.pharmacy else ""
    if current_plan not in PLAN_LEVELS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "PLAN_CONFIGURATION_INVALID",
                "message": "This pharmacy has an unsupported plan configuration.",
            },
        )
    if PLAN_LEVELS[current_plan] >= PLAN_LEVELS["pro"]:
        return start_date

    try:
        period_end = date.fromisoformat(end_date) if end_date else date.today()
        oldest_for_period = period_end - timedelta(days=days - 1)
        oldest_allowed = max(
            oldest_for_period,
            date.today() - timedelta(days=days - 1),
        )
        requested_start = date.fromisoformat(start_date) if start_date else None
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Dates must use YYYY-MM-DD",
        ) from exc

    if period_end < date.today() - timedelta(days=days - 1):
        ensure_feature_access(context, "extended_sales_history")
    if requested_start is not None and requested_start < oldest_allowed:
        ensure_feature_access(context, "extended_sales_history")
    return start_date or oldest_allowed.isoformat()


def ensure_sales_record_access(
    context: PharmacyContext,
    sale_date: date | datetime | None,
    days: int = 30,
) -> None:
    if context.is_platform_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform administrators do not have pharmacy plan access",
        )
    if sale_date is None:
        return
    current_plan = (context.pharmacy.plan or "").lower() if context.pharmacy else ""
    if current_plan not in PLAN_LEVELS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "PLAN_CONFIGURATION_INVALID",
                "message": "This pharmacy has an unsupported plan configuration.",
            },
        )
    if PLAN_LEVELS[current_plan] >= PLAN_LEVELS["pro"]:
        return

    sale_day = sale_date.date() if isinstance(sale_date, datetime) else sale_date
    if sale_day < date.today() - timedelta(days=days - 1):
        ensure_feature_access(context, "extended_sales_history")