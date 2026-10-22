"""
Tests for Phase 2 (Concurrency, Atomic Invoice Sequence, Idempotency)
and Phase 5 (Distributed Tenant-Aware Cache).
"""

import pytest
from datetime import datetime, date
from app.models.pos_sale import POSSale, POSSaleItem, InvoiceSequence
from app.models.batch import Batch
from app.models.medicine import Medicine
from app.services.pos_service import generate_pos_invoice_code, checkout
from app.schemas.pos import POSCheckoutRequest, CheckoutItem, BatchAllocation
from app.core.distributed_cache import (
    get_cache, set_cache, delete_cache, tenant_key, invalidate_tenant_namespace
)


class TestInvoiceSequenceConcurrency:
    def test_invoice_sequence_generation_monotonic(self, db, admin_user):
        """Test that generate_pos_invoice_code generates strictly monotonic numbers per pharmacy."""
        pharmacy_id = admin_user.pharmacy_id
        db.info.update({"pharmacy_scope_enabled": True, "pharmacy_id": pharmacy_id})

        current_year = datetime.now().year
        code1 = generate_pos_invoice_code(db)
        code2 = generate_pos_invoice_code(db)
        code3 = generate_pos_invoice_code(db)

        assert code1 == f"POS-{current_year}-0001"
        assert code2 == f"POS-{current_year}-0002"
        assert code3 == f"POS-{current_year}-0003"

        # Verify DB sequence record was created
        seq = db.query(InvoiceSequence).filter(
            InvoiceSequence.pharmacy_id == pharmacy_id,
            InvoiceSequence.year == current_year,
        ).first()
        assert seq is not None
        assert seq.current_number == 3


class TestCheckoutIdempotencyAndLocks:
    def test_checkout_idempotent_with_sale_uuid(self, db, admin_user):
        """Checkout with same sale_uuid must return existing sale without double stock deduction."""
        pharmacy_id = admin_user.pharmacy_id
        db.info.update({"pharmacy_scope_enabled": True, "pharmacy_id": pharmacy_id})

        # Create medicine and batch
        med = Medicine(
            name="Amoxicilline 500mg Test",
            code="MED-CONCUR-01",
            quantity=50.0,
            price_sell=5000.0,
            is_active=True,
            pharmacy_id=pharmacy_id,
        )
        db.add(med)
        db.flush()

        batch = Batch(
            batch_number="LOT-CONCUR-01",
            medicine_id=med.id,
            expiration_date=date(2028, 12, 31),
            quantity=50.0,
            purchase_price=3000.0,
            is_active=True,
            pharmacy_id=pharmacy_id,
        )
        db.add(batch)
        db.commit()

        sale_uuid = "11111111-2222-3333-4444-555555555555"
        checkout_req = POSCheckoutRequest(
            sale_uuid=sale_uuid,
            items=[
                CheckoutItem(
                    medicine_id=med.id,
                    quantity=5,
                    unit_price=5000.0,
                    allocations=[
                        BatchAllocation(
                            batch_id=batch.id,
                            batch_number=batch.batch_number,
                            quantity=5,
                        )
                    ],
                )
            ],
            payment_method="other",
        )

        # 1st checkout
        sale1 = checkout(db, admin_user.id, checkout_req)
        assert sale1.sale_uuid == sale_uuid
        assert sale1.total_amount == 25000.0

        # Stock should be reduced by 5
        db.refresh(med)
        db.refresh(batch)
        assert med.quantity == 45.0
        assert batch.quantity == 45.0

        # 2nd checkout with the SAME sale_uuid (idempotent call)
        sale2 = checkout(db, admin_user.id, checkout_req)
        assert sale2.id == sale1.id
        assert sale2.sale_uuid == sale_uuid

        # Stock must NOT be deducted a second time
        db.refresh(med)
        db.refresh(batch)
        assert med.quantity == 45.0
        assert batch.quantity == 45.0


class TestDistributedCache:
    def test_tenant_key_formatting(self):
        assert tenant_key(12, "pos", "products") == "pharma:12:pos:products"
        assert tenant_key(None, "global", "metrics") == "pharma:global:global:metrics"

    def test_cache_set_get_delete(self):
        k = tenant_key(42, "test", "mykey")
        set_cache(k, {"hello": "world", "count": 10}, ttl_seconds=60)

        val = get_cache(k)
        assert val == {"hello": "world", "count": 10}

        delete_cache(k)
        assert get_cache(k) is None

    def test_invalidate_tenant_namespace(self):
        k1 = tenant_key(99, "pos", "search_a")
        k2 = tenant_key(99, "pos", "search_b")
        k3 = tenant_key(100, "pos", "search_a")

        set_cache(k1, "res_a", ttl_seconds=60)
        set_cache(k2, "res_b", ttl_seconds=60)
        set_cache(k3, "res_other", ttl_seconds=60)

        invalidate_tenant_namespace(99, "pos")

        assert get_cache(k1) is None
        assert get_cache(k2) is None
        assert get_cache(k3) == "res_other"
