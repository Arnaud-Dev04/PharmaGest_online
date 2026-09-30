import sys
sys.path.insert(0, '.')
from app.database.core import engine_local
from sqlalchemy.orm import Session
from app.models.user import User
from app.utils.security import hash_password

session = Session(bind=engine_local)
user = session.query(User).filter(User.username == 'arnaud').first()
if user:
    user.password_hash = hash_password('arnaud123')
    session.commit()
    print(f"OK: mot de passe de '{user.username}' reinitialise a 'arnaud123'")
else:
    print("ERREUR: user 'arnaud' non trouve")
session.close()
