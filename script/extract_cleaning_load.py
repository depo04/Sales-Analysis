#estrazione dati da csv
from pathlib import Path
import pandas as pd
import os
from dotenv import load_dotenv
from sqlalchemy import Date, Time, URL, create_engine, inspect, text

def extract_data(file_path):
    try:
        data = pd.read_csv(file_path)
        return data
    except FileNotFoundError:
        print(f"Error: The file at {file_path} was not found.")
        return None
    except pd.errors.EmptyDataError:
        print("Error: The file is empty.")
        return None
    except pd.errors.ParserError:
        print("Error: There was a parsing error while reading the file.")
        return None

filename = "Sales_transactions_2022_2025.csv"
project_root = Path(__file__).resolve().parent.parent
csv_path = project_root / "dataset" / filename
if not csv_path.is_file():
    raise FileNotFoundError(f"Could not find dataset file: {csv_path}")

df = extract_data(csv_path)
if df is None:
    raise RuntimeError("Non è stato possibile leggere il file CSV; caricamento annullato.")

# Carica il DataFrame nella tabella PostgreSQL staging.sales_transactions
env_path = project_root / ".env"
if env_path.is_file():
    load_dotenv(env_path)

db_config = {
    "host": os.getenv("DB_HOST") or os.getenv("POSTGRES_HOST") or "localhost",
    "port": os.getenv("DB_PORT") or os.getenv("POSTGRES_PORT"),
    "database": os.getenv("DB_NAME") or os.getenv("POSTGRES_DB"),
    "username": os.getenv("DB_USER") or os.getenv("POSTGRES_USER"),
    "password": os.getenv("DB_PASSWORD") or os.getenv("POSTGRES_PASSWORD"),
}
missing_vars = [
    name for name, value in db_config.items()
    if value is None
]
if missing_vars:
    raise ValueError(f"Configurazione PostgreSQL mancante: {', '.join(missing_vars)}")

db_url = URL.create(
    drivername="postgresql+pg8000",
    username=db_config["username"],
    password=db_config["password"],
    host=db_config["host"],
    port=int(db_config["port"]),
    database=db_config["database"],
)
engine = create_engine(db_url)

try:
    with engine.begin() as connection:
        if not inspect(connection).has_table("sales_transactions", schema="staging"):
            raise RuntimeError(
                "La tabella staging.sales_transactions non esiste. "
                "Esegui prima database/sales_transactions.sql."
            )
        #fase di pulizia e normalizzazione dei dati prima del caricamento
        df_to_load = df.copy()

        #renaming delle colonne in minuscolo per uniformità
        df_to_load.columns = [column.lower() for column in df_to_load.columns]

        #conversione delle colonne Order_Date e Order_Time in formato datetime
        df_to_load["order_date"] = pd.to_datetime(
            df_to_load["order_date"], errors="raise"
        ).dt.date
        df_to_load["order_time"] = pd.to_datetime(
            df_to_load["order_time"], format="%H:%M:%S", errors="raise"
        ).dt.time

        #eliminazione dei duplicati basati su Transaction_ID, mantenendo la prima occorrenza
        df_to_load = df_to_load.drop_duplicates(subset='transaction_id', keep='first')
        
        # Verifica che ogni Product_ID abbia un solo nome noto
        nomi_noti = df_to_load.dropna(subset=["product_name"])
        conflitti = nomi_noti.groupby("product_id")["product_name"].nunique()
        if (conflitti > 1).any():
            raise ValueError(f"Product_ID associati a più nomi: {conflitti[conflitti > 1].index.tolist()}")
        # Crea la corrispondenza ID → nome e completa i valori mancanti
        mappa_nomi = nomi_noti.drop_duplicates("product_id").set_index("product_id")["product_name"]
        df_to_load["product_name"] = df_to_load["product_name"].fillna(df_to_load["product_id"].map(mappa_nomi))

        #normalizzazione dei valori della colonna Discount_Percentage
        df_to_load = df_to_load[(df_to_load['discount_percentage'] <= 100) & (df_to_load['discount_percentage'] >= 0)]

        #rimozioni dei valori negativi nella colonna quantity rendendoli positivi
        df_to_load['quantity'] = df_to_load['quantity'].abs()

        connection.execute(
            text("TRUNCATE TABLE staging.sales_transactions RESTART IDENTITY")
        )
        rows_loaded = df_to_load.to_sql(
            name="sales_transactions",
            schema="staging",
            con=connection,
            if_exists="append",
            index=False,
            chunksize=500,
            dtype={"order_date": Date(), "order_time": Time()},
        )
finally:
    engine.dispose()

print(f"Caricate {rows_loaded or 0} righe in staging.sales_transactions.")