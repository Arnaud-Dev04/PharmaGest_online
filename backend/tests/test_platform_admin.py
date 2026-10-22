"""Platform administrator API tests."""

from datetime import datetime, timedelta

from app.models.pharmacy import Pharmacy
from app.models.pos_sale import POSSale
from app.models.user import User, UserRole
from app.utils.security import create_access_token, hash_password, verify_password


def _headers_for(user):
    token = create_access_token(
        data={"sub": user.username},
        expires_delta=timedelta(minutes=60),
    )
    return {"Authorization": f"Bearer {token}"}


def test_platform_routes_reject_pharmacy_admin(client, db, admin_user, admin_headers):
    response = client.get("/platform/pharmacies", headers=admin_headers)

    assert response.status_code == 403


def test_platform_admin_can_create_and_list_platform_accounts(client, db):
    platform_admin = User(
        username="platform_account_manager",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add(platform_admin)
    db.commit()
    headers = _headers_for(platform_admin)

    created = client.post(
        "/platform/accounts/platform-admin",
        headers=headers,
        json={"username": "platform_account_new", "password": "Temporary@123!"},
    )
    assert created.status_code == 201, created.text
    assert created.json()["must_change_password"] is True
    assert "password" not in created.json()
    assert "password_hash" not in created.json()

    listed = client.get("/platform/accounts", headers=headers)
    assert listed.status_code == 200, listed.text
    assert {account["username"] for account in listed.json()} == {
        "platform_account_manager",
        "platform_account_new",
    }
    assert all("password_hash" not in account for account in listed.json())

    duplicate = client.post(
        "/platform/accounts/platform-admin",
        headers=headers,
        json={"username": "platform_account_new", "password": "Another@123!"},
    )
    assert duplicate.status_code == 409


def test_platform_admin_can_reset_admin_passwords_temporarily(
    client, db, pharmacy, admin_user
):
    platform_admin = User(
        username="platform_password_manager",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    other_platform_admin = User(
        username="platform_password_target",
        password_hash=hash_password("OldPlatform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    pharmacy_admin = User(
        username="platform_reset_pharmacy_admin",
        password_hash=hash_password("OldPharmacy@123!"),
        role=UserRole.ADMIN,
        is_active=True,
        pharmacy_id=pharmacy.id,
    )
    db.add_all([platform_admin, other_platform_admin, pharmacy_admin])
    db.commit()
    headers = _headers_for(platform_admin)

    for target, new_password in (
        (other_platform_admin, "NewPlatform@123!"),
        (pharmacy_admin, "NewPharmacy@123!"),
    ):
        response = client.put(
            f"/platform/accounts/{target.id}/password",
            headers=headers,
            json={"temporary_password": new_password},
        )
        assert response.status_code == 200, response.text
        db.info["pharmacy_scope_enabled"] = False
        db.refresh(target)
        from app.utils.security import verify_password
        assert verify_password(new_password, target.password_hash)
        assert target.must_change_password is True

    cannot_reset_self = client.put(
        f"/platform/accounts/{platform_admin.id}/password",
        headers=headers,
        json={"temporary_password": "SelfReset@123!"},
    )
    assert cannot_reset_self.status_code == 400

    self_reset = client.put(
        f"/platform/accounts/{platform_admin.id}/password",
        headers=headers,
        json={
            "current_password": "Platform@123!",
            "temporary_password": "PlatformSelf@123!",
        },
    )
    assert self_reset.status_code == 200, self_reset.text
    db.info["pharmacy_scope_enabled"] = False
    db.refresh(platform_admin)
    assert verify_password("PlatformSelf@123!", platform_admin.password_hash)
    assert platform_admin.must_change_password is True


def test_platform_account_management_rejects_pharmacy_admin(
    client, admin_headers, admin_user
):
    response = client.get("/platform/accounts", headers=admin_headers)
    assert response.status_code == 403

    response = client.post(
        "/platform/accounts/platform-admin",
        headers=admin_headers,
        json={"username": "forbidden_platform_user", "password": "Temporary@123!"},
    )
    assert response.status_code == 403


def test_platform_pharmacy_list_is_paginated_and_searchable(client, db):
    platform_admin = User(
        username="platform_pharmacy_pagination_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    pharmacies = [
        Pharmacy(name=f"Page Pharmacy {index:02d}", code=f"PAGE-{index:02d}", city="Abidjan")
        for index in range(30)
    ]
    pharmacies.append(Pharmacy(name="Unique Search Target", code="UNIQUE-SEARCH", city="Bouake"))
    db.add_all([platform_admin, *pharmacies])
    db.commit()
    headers = _headers_for(platform_admin)

    first_page = client.get("/platform/pharmacies?page=1&page_size=10", headers=headers)
    assert first_page.status_code == 200, first_page.text
    body = first_page.json()
    assert body["total"] == 31
    assert body["page"] == 1
    assert body["page_size"] == 10
    assert body["total_pages"] == 4
    assert len(body["items"]) == 10

    second_page = client.get("/platform/pharmacies?page=2&page_size=10", headers=headers)
    assert second_page.status_code == 200, second_page.text
    assert len(second_page.json()["items"]) == 10
    assert body["items"][0]["id"] != second_page.json()["items"][0]["id"]

    search_result = client.get(
        "/platform/pharmacies?search=UNIQUE-SEARCH",
        headers=headers,
    )
    assert search_result.status_code == 200, search_result.text
    assert search_result.json()["total"] == 1
    assert search_result.json()["items"][0]["code"] == "UNIQUE-SEARCH"


def test_platform_pharmacy_list_rejects_invalid_pagination(client, db):
    platform_admin = User(
        username="platform_pharmacy_bad_page_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add(platform_admin)
    db.commit()

    response = client.get(
        "/platform/pharmacies?page=0&page_size=1000",
        headers=_headers_for(platform_admin),
    )
    assert response.status_code == 422


def test_platform_onboarding_creates_pharmacy_and_admin(client, db):
    platform_admin = User(
        username="platform_onboard_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add(platform_admin)
    db.commit()

    response = client.post(
        "/platform/pharmacies",
        headers=_headers_for(platform_admin),
        json={
            "name": "Pharmacie Koumassi",
            "code": "PHARMA-KOUMASSI",
            "country": "Cote d'Ivoire",
            "city": "Abidjan",
            "plan": "pro",
            "max_users": 10,
            "admin_username": "admin_koumassi",
            "admin_password": "Initial@123!",
        },
    )

    assert response.status_code == 201, response.text
    body = response.json()
    pharmacy_id = body["pharmacy"]["id"]
    pharmacy_admin = db.query(User).filter(User.username == "admin_koumassi").one()
    assert pharmacy_admin.role == UserRole.ADMIN
    assert pharmacy_admin.pharmacy_id == pharmacy_id
    assert pharmacy_admin.must_change_password is True
    assert pharmacy_admin.password_hash != "Initial@123!"
    assert body["pharmacy"]["plan"] == "pro"


def test_onboarding_rejects_basic_user_limit_above_plan(client, db):
    platform_admin = User(
        username="platform_basic_limit_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add(platform_admin)
    db.commit()

    response = client.post(
        "/platform/pharmacies",
        headers=_headers_for(platform_admin),
        json={
            "name": "Pharmacie Basic Limite",
            "code": "BASIC-OVER-LIMIT",
            "plan": "basic",
            "max_users": 4,
            "admin_username": "admin_basic_limit",
            "admin_password": "Initial@123!",
        },
    )

    assert response.status_code == 422


def test_update_rejects_user_limit_above_plan(client, db, pharmacy):
    platform_admin = User(
        username="platform_update_limit_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add(platform_admin)
    db.commit()

    response = client.put(
        f"/platform/pharmacies/{pharmacy.id}",
        headers=_headers_for(platform_admin),
        json={"max_users": 4},
    )

    assert response.status_code == 422


def test_platform_cannot_lower_user_limit_below_active_users(
    client, db, pharmacy, admin_user
):
    db.add(User(
        username="active_pharmacy_user",
        password_hash=hash_password("Pharmacy@123!"),
        role=UserRole.PHARMACIST,
        is_active=True,
        pharmacy_id=pharmacy.id,
    ))
    platform_admin = User(
        username="platform_limit_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add(platform_admin)
    db.commit()

    response = client.put(
        f"/platform/pharmacies/{pharmacy.id}",
        headers=_headers_for(platform_admin),
        json={"max_users": 1},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "max_users cannot be lower than active user count"


def test_platform_metrics_aggregate_all_pharmacies(client, db):
    first = Pharmacy(name="Metrics A", code="METRICS-A")
    second = Pharmacy(name="Metrics B", code="METRICS-B")
    platform_admin = User(
        username="platform_metrics_test",
        password_hash=hash_password("Platform@123!"),
        role=UserRole.PLATFORM_ADMIN,
        is_active=True,
        pharmacy_id=None,
    )
    db.add_all([first, second, platform_admin])
    db.commit()
    db.refresh(first)
    db.refresh(second)
    db.add_all([
        POSSale(
            sale_uuid="3b556788-2bb4-4a6b-bde4-3893bc926810",
            code="METRICS-SALE-A",
            total_amount=125,
            date=datetime(2026, 10, 1),
            user_id=1,
            pharmacy_id=first.id,
        ),
        POSSale(
            sale_uuid="3b556788-2bb4-4a6b-bde4-3893bc926811",
            code="METRICS-SALE-B",
            total_amount=275,
            date=datetime(2026, 10, 1),
            user_id=2,
            pharmacy_id=second.id,
        ),
    ])
    db.commit()

    response = client.get("/platform/metrics", headers=_headers_for(platform_admin))

    assert response.status_code == 200, response.text
    metrics = response.json()
    assert metrics["pharmacy_count"] == 2
    assert metrics["active_pharmacy_count"] == 2
    assert metrics["sale_count"] == 2
    assert metrics["total_revenue"] == 400
