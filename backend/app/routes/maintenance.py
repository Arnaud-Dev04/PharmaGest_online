from fastapi import APIRouter, Depends, HTTPException
from app.auth.dependencies import get_super_admin_user
import os
import datetime

router = APIRouter()

# Marker file placed at project root to indicate maintenance mode
MAINT_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'MAINTENANCE_MODE'))

def _is_maintenance_enabled() -> bool:
    return os.path.exists(MAINT_FILE)

@router.get('/maintenance/status')
async def maintenance_status():
    return { 'maintenance': _is_maintenance_enabled() }

@router.post('/maintenance/enable')
async def enable_maintenance(current_user = Depends(get_super_admin_user)):
    try:
        with open(MAINT_FILE, 'w') as f:
            f.write(f"enabled_by={current_user.username}\n")
            f.write(f"enabled_at={datetime.datetime.utcnow().isoformat()}\n")
        return {'ok': True, 'maintenance': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post('/maintenance/disable')
async def disable_maintenance(current_user = Depends(get_super_admin_user)):
    try:
        if os.path.exists(MAINT_FILE):
            os.remove(MAINT_FILE)
        return {'ok': True, 'maintenance': False}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
