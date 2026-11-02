FROM python:3.14-slim

# Imposta la cartella di lavoro all'interno del container
WORKDIR /app

# Installa il client PostgreSQL (psql), necessario a run_init.sh per eseguire i file .sql
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copia il file requirements.txt nel container
COPY requirements.txt .

# Installa le librerie elencate in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copia il resto del codice dell'applicazione
COPY . .

# Rimuove eventuali fine riga Windows (CRLF) da run_init.sh e lo rende eseguibile
RUN sed -i 's/\r$//' /app/run_init.sh && chmod +x /app/run_init.sh