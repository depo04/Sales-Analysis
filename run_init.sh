#!/bin/sh
set -eu

# Verifica che tutte le variabili di connessione al database siano state impostate.
: "${DB_HOST:?Variabile DB_HOST non impostata}"
: "${DB_PORT:=5432}"
: "${DB_NAME:?Variabile DB_NAME non impostata}"
: "${DB_USER:?Variabile DB_USER non impostata}"
: "${DB_PASSWORD:?Variabile DB_PASSWORD non impostata}"

export PGPASSWORD="$DB_PASSWORD"
export LC_ALL=C 

SQL_DIR="/app/database/sql"
FIRST_SQL_1="01_schema_creation.sql"
FIRST_SQL_2="02_sales_transactions.sql"
PYTHON_SCRIPT="/app/script/extract_cleaning_load.py"

# Esegue un file SQL contro il database configurato.
run_sql() {
    sql_file="$1"
    if [ ! -f "$sql_file" ]; then
        echo "ERRORE: file SQL non trovato: $sql_file" >&2
        exit 1
    fi
    echo "==> Esecuzione SQL: $(basename "$sql_file")"
    psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --set=ON_ERROR_STOP=1 \
        --pset=pager=off \
        --file="$sql_file"
}

# Esegue uno script Python che carica e trasforma i dati.
run_python() {
    python_file="$1"
    if [ ! -f "$python_file" ]; then
        echo "ERRORE: file Python non trovato: $python_file" >&2
        exit 1
    fi
    echo "==> Esecuzione Python: $(basename "$python_file")"
    python "$python_file"
}

# Avvio dell'initialization pipeline: crea schema e poi esegue il processo ETL.
echo "=========================================="
echo "Avvio inizializzazione Data Engineering"
echo "Database: $DB_NAME @ $DB_HOST:$DB_PORT"
echo "=========================================="

# Esecuzione dei file SQL principali prima del processo Python.
run_sql "$SQL_DIR/$FIRST_SQL_1"
run_sql "$SQL_DIR/$FIRST_SQL_2"

# Esecuzione del job ETL per pulire e caricare i dati.
run_python "$PYTHON_SCRIPT"

# Esegue tutti gli altri script SQL, evitando di rieseguire quelli già eseguiti.
for sql_file in "$SQL_DIR"/*.sql; do
    [ -f "$sql_file" ] || continue
    case "$(basename "$sql_file")" in
        "$FIRST_SQL_1"|"$FIRST_SQL_2") continue ;;
    esac
    run_sql "$sql_file"
done

echo "=========================================="
echo "Inizializzazione completata correttamente"
echo "=========================================="

# Pulizia: quando il container viene interrotto, elimina gli schemi creati in modo da poter riavviare pulito.
cleanup() {
    echo "=========================================="
    echo "Chiusura: eliminazione degli schemi dal database $DB_NAME"
    schemas=$(psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --tuples-only --no-align \
        --command="SELECT nspname FROM pg_namespace WHERE left(nspname, 3) <> 'pg_' AND nspname NOT IN ('information_schema', 'public') ORDER BY 1") || schemas=""
    for schema in $schemas; do
        echo "==> DROP SCHEMA $schema CASCADE"
        psql \
            --host="$DB_HOST" \
            --port="$DB_PORT" \
            --username="$DB_USER" \
            --dbname="$DB_NAME" \
            --command="DROP SCHEMA IF EXISTS \"$schema\" CASCADE" || true
    done
    echo "Pulizia completata"
    echo "=========================================="
    exit 0
}
trap cleanup TERM INT

# Mantiene il container attivo: il comando `docker compose down` rimuove gli schemi creati.
echo "Container in attesa (docker compose down per eliminare gli schemi)"
sleep infinity &
wait $!