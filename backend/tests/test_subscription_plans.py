"""
Unit test for subscription plans, 4-part license key format & registration
"""
import sys
import re

backend_dir = r"E:\Project\PharmaGest_online\backend"
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.core.license_guard import (
    PLAN_LEVELS,
    PLAN_FEATURES,
    FEATURE_MINIMUM_PLANS,
    feature_is_available,
)
from app.schemas.pharmacy import (
    PLAN_MAX_AGENCIES,
    PLAN_MAX_USERS,
    PharmacyRegisterRequest,
    PharmacyOnboardRequest,
)
from app.routes.license import _generate_key_string, _format_duration_segment

def test_plans_and_new_key_format():
    print("=== 1. Testing Subscription Plans & Features ===")
    all_features = set(FEATURE_MINIMUM_PLANS.keys())
    for p in ["basic", "pro", "enterprise", "diamond"]:
        assert p in PLAN_LEVELS, f"Missing {p} in PLAN_LEVELS"
        assert p in PLAN_MAX_AGENCIES, f"Missing {p} in PLAN_MAX_AGENCIES"
        assert PLAN_FEATURES[p] == all_features, f"Plan {p} must have 100% features"
    
    assert PLAN_MAX_AGENCIES["basic"] == 2
    assert PLAN_MAX_AGENCIES["pro"] == 5
    assert PLAN_MAX_AGENCIES["enterprise"] == 10
    assert PLAN_MAX_AGENCIES["diamond"] >= 9999
    print("[PASS] Plans and agency limits: Basic (2), Pro (5), Entreprise (10), Diamond (Unlimited)")

    print("\n=== 2. Testing 4-Part License Key Format ===")
    # Format: [3 lettres nom]-[4 chiffres]-[Durée: 14J, 6M, 12M, 24M]-[5 caractères alphanum]
    
    test_cases = [
        ("Pharmacie Centrale", 14, "PHA", "14J"),
        ("Pharmacie Saint Luc", 365, "PHA", "12M"),
        ("Alpha MediCare", 180, "ALP", "6M"),
        ("Bwiza Care", 730, "BWI", "24M"),
        (None, 30, "PHA", "1M"),
    ]

    for name, days, expected_p1, expected_p3 in test_cases:
        key = _generate_key_string(name, days)
        parts = key.split("-")
        assert len(parts) == 4, f"Key {key} must have exactly 4 parts separated by '-'"
        
        # 1ère partie: 3 premières lettres
        assert len(parts[0]) == 3 and parts[0] == expected_p1, f"Part 1 error: got {parts[0]}, expected {expected_p1}"
        
        # 2ème partie: 4 chiffres aléatoires
        assert len(parts[1]) == 4 and parts[1].isdigit(), f"Part 2 must be 4 digits: got {parts[1]}"
        
        # 3ème partie: Durée
        assert parts[2] == expected_p3, f"Part 3 must be duration segment: got {parts[2]}, expected {expected_p3}"
        
        # 4ème partie: 5 caractères combinés (lettres et chiffres)
        assert len(parts[3]) == 5, f"Part 4 must have 5 chars: got {parts[3]}"
        assert any(c.isalpha() for c in parts[3]) and any(c.isdigit() for c in parts[3]), f"Part 4 must combine letters and digits: {parts[3]}"
        
        print(f"  Generated key for '{name}' ({days} days) -> {key} [OK]")

    print("[PASS] 4-part key format verified successfully!")

    print("\n=== 3. Testing Registration without OBR NIF (Client Side) ===")
    reg_req = PharmacyRegisterRequest(
        name="Nouvelle Pharmacie Populaire",
        phone="+257 71 23 45 67",
        email="populaire@pharma.bi",
        admin_username="admin_pop",
        admin_password="Password123",
        plan="basic",
        # nif is NOT provided
    )
    assert reg_req.nif is None, "NIF must be optional on registration"
    assert reg_req.plan == "basic"
    print("[PASS] Client self-registration accepts requests without fiscal OBR fields")

    print("\n>>> ALL TESTS PASSED (100%) <<<")

if __name__ == "__main__":
    test_plans_and_new_key_format()
