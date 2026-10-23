"""Tenant-aware synchronization tests."""

from datetime import date, datetime
import uuid

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.database.core import Base
from app.models.batch import Batch
from app.models.cash_register import CashRegisterMovement, CashRegisterSession
from app.models.customer import Customer
from app.models.medicine import Medicine, MedicineFamily, MedicineType
from app.models.medicine_pricing import MedicinePricing
from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale, POSSaleItem
from app.models.settings import Settings
from app.models.user import User, UserRole
from app.sync import sync_manager
from app.sync.sync_manager import SyncManager


def _session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return engine, Session(engine)


def test_sync_maps_remote_ids_by_tenant_and_is_idempotent():
    local_engine, local_db = _session()
    remote_engine, remote_db = _session()
    try:
        local_pharmacy = Pharmacy(id=12, name="Local", code="SYNC-TENANT")
        local_user = User(
            id=23,
            username="sync-user",
            password_hash="hash",
            role=UserRole.PHARMACIST,
            pharmacy_id=12,
        )
        local_medicine = Medicine(
            id=88,
            code="SYNC-MED-01",
            name="Sync Medicine",
            pharmacy_id=12,
        )
        local_batch = Batch(
            id=42,
            batch_number="SYNC-LOT-01",
            medicine_id=88,
            expiration_date=date(2030, 1, 1),
            quantity=8,
            pharmacy_id=12,
        )
        local_customer = Customer(
            id=99,
            first_name="Local",
            last_name="Customer",
            phone="22512345678",
            pharmacy_id=12,
        )
        local_item = POSSaleItem(
            id=66,
            medicine=local_medicine,
            batch=local_batch,
            quantity=2,
            unit_price=100,
            total_price=200,
            pharmacy_id=12,
        )
        local_sale = POSSale(
            id=77,
            sale_uuid="4c06c862-1db3-4f3e-a751-c224d7a03d4e",
            code="SYNC-POS-01",
            total_amount=200,
            date=datetime(2026, 10, 1),
            user=local_user,
            customer=local_customer,
            items=[local_item],
            pharmacy_id=12,
        )
        local_db.add_all([
            local_pharmacy,
            local_user,
            local_medicine,
            local_batch,
            local_customer,
            local_sale,
        ])
        local_db.commit()
        local_db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": local_pharmacy.id,
            "is_platform_admin": False,
        })

        remote_pharmacy = Pharmacy(id=7, name="Remote", code="SYNC-TENANT")
        remote_user = User(
            id=5,
            username="sync-user",
            password_hash="hash",
            role=UserRole.PHARMACIST,
            pharmacy_id=7,
        )
        remote_medicine = Medicine(
            id=52,
            code="SYNC-MED-01",
            name="Sync Medicine",
            pharmacy_id=7,
        )
        remote_batch = Batch(
            id=44,
            batch_number="SYNC-LOT-01",
            medicine_id=52,
            expiration_date=date(2030, 1, 1),
            quantity=8,
            pharmacy_id=7,
        )
        remote_db.add_all([remote_pharmacy, remote_user, remote_medicine, remote_batch])
        remote_db.commit()

        assert SyncManager._configure_remote_scope(local_db, remote_db) == 7
        SyncManager._push_pos_sale(local_sale, remote_db)
        SyncManager._push_pos_sale(local_sale, remote_db)

        remote_sale = remote_db.query(POSSale).filter(
            POSSale.sale_uuid == local_sale.sale_uuid
        ).one()
        assert remote_sale.pharmacy_id == 7
        assert remote_sale.user_id == remote_user.id
        assert remote_sale.customer.phone == local_customer.phone
        assert len(remote_sale.items) == 1
        assert remote_sale.items[0].pharmacy_id == 7
        assert remote_sale.items[0].medicine_id == remote_medicine.id
        assert remote_sale.items[0].batch_id == remote_batch.id
        assert remote_db.query(POSSale).filter(
            POSSale.sale_uuid == local_sale.sale_uuid
        ).count() == 1
    finally:
        local_db.close()
        remote_db.close()
        local_engine.dispose()
        remote_engine.dispose()


def test_sync_retries_failed_cash_sale_before_closing_cash_session(monkeypatch):
    local_engine, local_db = _session()
    remote_engine, remote_db = _session()
    try:
        local_pharmacy = Pharmacy(id=12, name="Local Cash", code="CASH-SYNC-TENANT")
        local_cashier = User(
            id=23,
            username="cash-sync-user",
            password_hash="hash",
            role=UserRole.PHARMACIST,
            pharmacy_id=12,
        )
        session_uuid = str(uuid.uuid4())
        local_session = CashRegisterSession(
            id=77,
            session_uuid=session_uuid,
            active_key=None,
            cashier_id=23,
            opened_at=datetime(2026, 10, 1, 8),
            closed_at=datetime(2026, 10, 1, 18),
            opening_amount=100,
            expected_amount=150,
            counted_amount=150,
            variance=0,
            status="closed",
            sync_status="pending",
            pharmacy_id=12,
        )
        movement = CashRegisterMovement(
            movement_uuid=str(uuid.uuid4()),
            session_uuid=session_uuid,
            session_id=77,
            cashier_id=23,
            movement_type="cash_in",
            amount=25,
            reason="Change fund",
            occurred_at=datetime(2026, 10, 1, 9),
            pharmacy_id=12,
        )
        local_sale = POSSale(
            sale_uuid=str(uuid.uuid4()),
            code="CASH-SYNC-SALE",
            total_amount=50,
            payment_method="cash",
            date=datetime(2026, 10, 1, 10),
            user=local_cashier,
            cash_session_uuid=session_uuid,
            sync_status="pending",
            pharmacy_id=12,
            items=[],
        )
        local_db.add_all([local_pharmacy, local_cashier, local_session, movement, local_sale])
        local_db.commit()
        local_db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": 12,
            "is_platform_admin": False,
        })

        remote_pharmacy = Pharmacy(id=7, name="Remote Cash", code="CASH-SYNC-TENANT")
        remote_cashier = User(
            id=5,
            username="cash-sync-user",
            password_hash="hash",
            role=UserRole.PHARMACIST,
            pharmacy_id=7,
        )
        remote_db.add_all([remote_pharmacy, remote_cashier])
        remote_db.commit()

        monkeypatch.setattr(sync_manager, "_remote_available", lambda: True)
        monkeypatch.setattr(sync_manager, "SessionRemote", lambda: remote_db)
        push_sale = SyncManager._push_pos_sale
        attempts = 0

        def fail_first_attempt(sale, session):
            nonlocal attempts
            attempts += 1
            if attempts == 1:
                raise RuntimeError("temporary remote failure")
            return push_sale(sale, session)

        monkeypatch.setattr(
            SyncManager,
            "_push_pos_sale",
            staticmethod(fail_first_attempt),
        )

        first_report = SyncManager.sync_up(local_db)
        remote_session = remote_db.query(CashRegisterSession).filter_by(
            session_uuid=session_uuid,
            pharmacy_id=7,
        ).one()
        assert remote_session.id != local_session.id
        assert remote_session.status == "open"
        assert remote_session.closed_at is None
        assert first_report["errors"] == 1
        assert first_report["synced"] == 0
        assert local_sale.sync_status == "error"
        remote_movement = remote_db.query(CashRegisterMovement).filter_by(
            movement_uuid=movement.movement_uuid,
            pharmacy_id=7,
        ).one()
        assert remote_movement.session_id == remote_session.id

        second_report = SyncManager.sync_up(local_db)

        remote_sale = remote_db.query(POSSale).filter_by(
            sale_uuid=local_sale.sale_uuid,
            pharmacy_id=7,
        ).one()
        remote_session = remote_db.query(CashRegisterSession).filter_by(
            session_uuid=session_uuid,
            pharmacy_id=7,
        ).one()
        assert second_report["errors"] == 0
        assert second_report["synced"] == 1
        assert attempts == 2
        assert local_sale.sync_status == "synced"
        assert remote_sale.cash_session_uuid == session_uuid
        assert remote_session.status == "closed"
        assert remote_session.closed_at == local_session.closed_at
    finally:
        local_db.close()
        remote_db.close()
        local_engine.dispose()
        remote_engine.dispose()


def test_sync_settings_only_pulls_matching_pharmacy():
    local_engine, local_db = _session()
    remote_engine, remote_db = _session()
    try:
        local_pharmacy = Pharmacy(id=12, name="Local", code="SETTINGS-TENANT")
        other_pharmacy = Pharmacy(id=13, name="Other", code="SETTINGS-OTHER")
        local_db.add_all([local_pharmacy, other_pharmacy])
        local_db.commit()
        local_db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": 12,
            "is_platform_admin": False,
        })
        local_db.add(Settings(key="pharmacy_name", value="Local Name", pharmacy_id=12))
        local_db.commit()

        remote_pharmacy = Pharmacy(id=7, name="Remote", code="SETTINGS-TENANT")
        other_remote_pharmacy = Pharmacy(id=8, name="Other", code="SETTINGS-OTHER")
        remote_db.add_all([remote_pharmacy, other_remote_pharmacy])
        remote_db.commit()
        remote_db.add_all([
            Settings(key="pharmacy_name", value="Cloud Name", pharmacy_id=7),
            Settings(key="private_setting", value="Other Tenant", pharmacy_id=8),
        ])
        remote_db.commit()

        updated_count = SyncManager._sync_settings(local_db, remote_db)

        local_settings = {
            setting.key: setting.value
            for setting in local_db.query(Settings).all()
        }
        assert updated_count == 1
        assert local_settings == {"pharmacy_name": "Cloud Name"}
    finally:
        local_db.close()
        remote_db.close()
        local_engine.dispose()
        remote_engine.dispose()


def test_sync_status_cache_is_per_pharmacy(monkeypatch):
    engine, setup_db = _session()
    first_db = Session(engine)
    second_db = Session(engine)
    try:
        first_pharmacy = Pharmacy(id=1, name="First", code="STATUS-FIRST")
        second_pharmacy = Pharmacy(id=2, name="Second", code="STATUS-SECOND")
        setup_db.add_all([first_pharmacy, second_pharmacy])
        setup_db.commit()
        setup_db.add_all([
            POSSale(
                sale_uuid="fd4862bf-4d69-40bc-86c5-24d961dcb801",
                code="STATUS-FIRST-SALE",
                total_amount=10,
                date=datetime(2026, 10, 1),
                user_id=1,
                sync_status="pending",
                pharmacy_id=1,
            ),
            POSSale(
                sale_uuid="fd4862bf-4d69-40bc-86c5-24d961dcb802",
                code="STATUS-SECOND-SALE",
                total_amount=20,
                date=datetime(2026, 10, 1),
                user_id=2,
                sync_status="synced",
                pharmacy_id=2,
            ),
        ])
        setup_db.commit()

        for db, pharmacy_id in ((first_db, 1), (second_db, 2)):
            db.info.update({
                "pharmacy_scope_enabled": True,
                "pharmacy_id": pharmacy_id,
                "is_platform_admin": False,
            })
        monkeypatch.setattr(sync_manager, "_remote_available", lambda: True)
        sync_manager._status_cache.clear()

        first_status = SyncManager.get_status(first_db)
        second_status = SyncManager.get_status(second_db)

        assert first_status["pending_count"] == 1
        assert first_status["synced_count"] == 0
        assert second_status["pending_count"] == 0
        assert second_status["synced_count"] == 1
    finally:
        first_db.close()
        second_db.close()
        setup_db.close()
        engine.dispose()


def test_sync_down_pulls_catalog_batches_pricing_and_customers():
    local_engine, local_db = _session()
    remote_engine, remote_db = _session()
    try:
        # Pharmacies
        local_pharmacy = Pharmacy(id=1, name="Pharmacie Centrale", code="PHARM-01", is_active=True)
        remote_pharmacy = Pharmacy(id=10, name="Pharmacie Centrale Cloud", code="PHARM-01", is_active=True)
        local_db.add(local_pharmacy)
        remote_db.add(remote_pharmacy)
        local_db.commit()
        remote_db.commit()

        # Remote catalog data
        remote_family = MedicineFamily(id=5, name="Antibiotiques", pharmacy_id=10)
        remote_type = MedicineType(id=7, name="Boîte", pharmacy_id=10)
        remote_db.add_all([remote_family, remote_type])
        remote_db.flush()

        remote_medicine = Medicine(
            id=100,
            code="MED-AMOX-500",
            name="Amoxicilline 500mg",
            family_id=remote_family.id,
            type_id=remote_type.id,
            price_buy=1500.0,
            price_sell=2200.0,
            pharmacy_id=10,
        )
        remote_db.add(remote_medicine)
        remote_db.flush()

        remote_batch = Batch(
            id=200,
            batch_number="LOT-2026-X1",
            medicine_id=remote_medicine.id,
            expiration_date=date(2028, 6, 30),
            quantity=100,
            purchase_price=1500.0,
            pharmacy_id=10,
        )
        remote_pricing = MedicinePricing(
            id=300,
            medicine_id=remote_medicine.id,
            nom="Amoxicilline 500mg",
            lot="LOT-2026-X1",
            achat_boite=1500.0,
            vente_boite=2200.0,
            pharmacy_id=10,
        )
        remote_customer = Customer(
            id=400,
            first_name="Alice",
            last_name="Kouassi",
            phone="0505123456",
            total_points=250,
            pharmacy_id=10,
        )
        remote_db.add_all([remote_batch, remote_pricing, remote_customer])
        remote_db.commit()

        # Configure local scope
        local_db.info.update({
            "pharmacy_scope_enabled": True,
            "pharmacy_id": local_pharmacy.id,
            "is_platform_admin": False,
        })
        SyncManager._configure_remote_scope(local_db, remote_db)

        # Run sync_down helpers
        med_count = SyncManager._sync_medicines(local_db, remote_db)
        batch_count = SyncManager._sync_batches(local_db, remote_db)
        pricing_count = SyncManager._sync_pricing(local_db, remote_db)
        customer_count = SyncManager._sync_customers(local_db, remote_db)

        assert med_count == 1
        assert batch_count == 1
        assert pricing_count == 1
        assert customer_count == 1

        # Verify local DB content
        local_fam = local_db.query(MedicineFamily).filter_by(name="Antibiotiques").first()
        assert local_fam is not None
        assert local_fam.pharmacy_id == local_pharmacy.id

        local_med = local_db.query(Medicine).filter_by(code="MED-AMOX-500").first()
        assert local_med is not None
        assert local_med.name == "Amoxicilline 500mg"
        assert local_med.family_id == local_fam.id
        assert local_med.pharmacy_id == local_pharmacy.id

        local_b = local_db.query(Batch).filter_by(batch_number="LOT-2026-X1").first()
        assert local_b is not None
        assert local_b.medicine_id == local_med.id
        assert local_b.pharmacy_id == local_pharmacy.id

        local_p = local_db.query(MedicinePricing).filter_by(lot="LOT-2026-X1").first()
        assert local_p is not None
        assert local_p.vente_boite == 2200.0
        assert local_p.pharmacy_id == local_pharmacy.id

        local_c = local_db.query(Customer).filter_by(phone="0505123456").first()
        assert local_c is not None
        assert local_c.total_points == 250
        assert local_c.pharmacy_id == local_pharmacy.id
    finally:
        local_db.close()
        remote_db.close()
        local_engine.dispose()
        remote_engine.dispose()


def test_batch_upload_sales_idempotent(client, db, admin_user, admin_headers, pharmacy):
    from app.models.medicine import Medicine
    from app.models.pos_sale import POSSale

    pharmacy.plan = "pro"
    db.commit()

    # Créer un médicament pour la vente
    med = Medicine(
        code="BATCH-MED-01",
        name="Paracétamol Batch 500mg",
        price_buy=500,
        price_sell=800,
        quantity=100,
        pharmacy_id=pharmacy.id,
    )
    db.add(med)
    db.commit()

    batch_payload = {
        "sales": [
            {
                "sale_uuid": "batch-uuid-test-001",
                "code": "POS-BATCH-001",
                "total_amount": 1600.0,
                "payment_method": "cash",
                "customer_name": "Client Batch A",
                "customer_phone": "+25779123456",
                "items": [
                    {
                        "medicine_code": "BATCH-MED-01",
                        "quantity": 2,
                        "unit_price": 800.0,
                        "total_price": 1600.0,
                    }
                ],
            },
            {
                "sale_uuid": "batch-uuid-test-002",
                "code": "POS-BATCH-002",
                "total_amount": 800.0,
                "payment_method": "ecocash",
                "items": [
                    {
                        "medicine_code": "BATCH-MED-01",
                        "quantity": 1,
                        "unit_price": 800.0,
                        "total_price": 800.0,
                    }
                ],
            },
        ]
    }

    # 1er envoi : les 2 ventes doivent être insérées
    resp1 = client.post("/sync/batch-up", json=batch_payload, headers=admin_headers)
    assert resp1.status_code == 200, resp1.text
    data1 = resp1.json()
    assert data1["total_received"] == 2
    assert data1["total_inserted"] == 2
    assert data1["total_skipped"] == 0

    # Vérification DB
    s1 = db.query(POSSale).filter(POSSale.sale_uuid == "batch-uuid-test-001").first()
    assert s1 is not None
    assert s1.total_amount == 1600.0
    assert len(s1.items) == 1

    # 2eme envoi des mêmes ventes : idempotence totale, 0 doublon inséré
    resp2 = client.post("/sync/batch-push", json=batch_payload, headers=admin_headers)
    assert resp2.status_code == 200, resp2.text
    data2 = resp2.json()
    assert data2["total_received"] == 2
    assert data2["total_inserted"] == 0
    assert data2["total_skipped"] == 2


def test_incremental_sync_down_filters_by_since():
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from app.database.core import Base
    from app.sync.sync_manager import SyncManager
    from app.models.medicine import Medicine
    from app.models.pharmacy import Pharmacy
    from datetime import datetime, timedelta

    local_engine = create_engine("sqlite:///:memory:")
    remote_engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=local_engine)
    Base.metadata.create_all(bind=remote_engine)

    SessionLocal = sessionmaker(bind=local_engine)
    SessionRemoteFactory = sessionmaker(bind=remote_engine)
    local_db = SessionLocal()
    remote_db = SessionRemoteFactory()

    try:
        pharma = Pharmacy(id=1, name="Pharma Incr", code="PHARMA-INCR")
        remote_db.add(pharma)
        remote_db.commit()

        local_pharma = Pharmacy(id=1, name="Pharma Incr", code="PHARMA-INCR")
        local_db.add(local_pharma)
        local_db.commit()
        local_db.info.update({"pharmacy_scope_enabled": True, "pharmacy_id": 1})
        remote_db.info.update({"pharmacy_scope_enabled": True, "pharmacy_id": 1})

        # Médicament ancien (hier)
        yesterday = datetime.utcnow() - timedelta(days=1)
        med_old = Medicine(
            code="MED-OLD",
            name="Ancien Médicament",
            price_buy=100,
            price_sell=150,
            pharmacy_id=1,
            updated_at=yesterday,
        )
        # Médicament récent (aujourd'hui)
        med_new = Medicine(
            code="MED-NEW",
            name="Nouveau Médicament",
            price_buy=200,
            price_sell=300,
            pharmacy_id=1,
            updated_at=datetime.utcnow(),
        )
        remote_db.add_all([med_old, med_new])
        remote_db.commit()

        # Sync avec since = 1 heure avant maintenant (ne doit prendre QUE le nouveau)
        since_cutoff = datetime.utcnow() - timedelta(hours=1)
        count = SyncManager._sync_medicines(local_db, remote_db, since=since_cutoff)
        assert count == 1

        local_med_new = local_db.query(Medicine).filter_by(code="MED-NEW").first()
        assert local_med_new is not None
        local_med_old = local_db.query(Medicine).filter_by(code="MED-OLD").first()
        assert local_med_old is None
    finally:
        local_db.close()
        remote_db.close()
        local_engine.dispose()
        remote_engine.dispose()