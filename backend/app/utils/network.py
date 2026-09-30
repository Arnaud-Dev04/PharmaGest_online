"""
Network Utility.
Helper to check internet/database connection status.
"""

import socket
from app.database import check_database_connection

def is_online(check_remote_db: bool = True) -> bool:
    """
    Check if the system is online.
    
    Args:
        check_remote_db: If True, specifically checks connection to the configured Remote MySQL DB.
                         If False, just checks basic internet connectivity (e.g. Google DNS).
    
    Returns:
        bool: True if online/connected, False otherwise.
    """
    if check_remote_db:
        # Check actual DB connection using the core database util
        return check_database_connection(use_remote=True)
    
    # Fallback: Simple DNS check
    try:
        # Check google DNS (8.8.8.8) on port 53
        socket.create_connection(("8.8.8.8", 53), timeout=3)
        return True
    except OSError:
        pass
        
    return False
