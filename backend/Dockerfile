FROM python:3.12-slim

WORKDIR /app

# Dépendances système minimales
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-libmysqlclient-dev gcc curl && \
    rm -rf /var/lib/apt/lists/*

# Installation des dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY . .

# Port exposé
EXPOSE 8000

# Commande de démarrage (workers configurables par env)
CMD uvicorn main:app --host 0.0.0.0 --port 8000 --workers ${WORKERS:-2}
