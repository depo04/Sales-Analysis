# Sales Analysis Project

## Obiettivo

Questo progetto ha l'obiettivo di trasformare dati di vendita grezzi in un data warehouse pronto per l'analisi aziendale e la costruzione di dashboard di business intelligence. L'idea è fornire una base dati pulita, normalizzata e modellata per rispondere a domande come:

- quali aree geografiche generano più fatturato;
- quali prodotti o categorie hanno la migliore redditività;
- come si comportano canali di vendita e segmenti di clientela;
- quali trend emergono nel tempo e per periodo;
- quali promozioni o metodi di pagamento influenzano il risultato.

---

## Panoramica del progetto

Il repository raccoglie un'intera pipeline ETL (Extract, Transform, Load) per:

1. leggere un dataset di transazioni di vendita in formato CSV;
2. validare e pulire i dati;
3. caricarli in uno schema di staging su PostgreSQL;
4. costruire dimensioni e tabella dei fatti in uno schema mart;
5. rendere i dati disponibili per analisi BI e dashboard in Power BI.

Il progetto è quindi diviso in due aree principali:

- Data Engineering: acquisizione, pulizia, trasformazione e modellazione dei dati;
- Data Analytics: analisi esplorativa e visualizzazione dei risultati tramite dashboard.

---

## Stack tecnologico

- Python 3.14
- PostgreSQL
- pgAdmin
- Docker
- Power BI
- dbdiagram
- Copilot

---

## Dataset di origine

Il dataset principale è:

- `dataset/Sales_transactions_2022_2025.csv`

Il file di dizionario dati è:

- `dataset/sales_data_dictionary.csv`

fonte dati: https://www.kaggle.com/datasets/danielsowah123/retail-sales-dataset

---

## Architettura dati

Il progetto usa un modello a stella / data warehouse con:

- schema `staging`: tabella di caricamento e prima validazione dei dati;
- schema `mart`: tabelle delle dimensioni e tabella dei fatti di analisi.

### Schema staging

La tabella principale è:

- `staging.sales_transactions`

Contiene tutte le transazioni originarie con vincoli di qualità dati e tipi SQL coerenti.

### Dimensioni

Sono create le seguenti tabelle dimensionali:

- `mart.dim_user`: dati clienti con gestione versioning SCD di tipo 2 (Slowly Changing Dimension)
- `mart.dim_product`: prodotti unici con categoria e sotto-categoria
- `mart.dim_store`: punti vendita con localizzazione geografica
- `mart.dim_date`: date uniche con colonne derivate (anno, mese, giorno)
- `mart.dim_time`: orari unici con colonne derivate (ora, minuti, secondi)

### Tabella fatti

- `mart.sales_transactions`

Questa tabella collega ogni transazione alle dimensioni tramite chiavi surrogate e consente analisi di vendita, margine, redditività e performance per canale, paese, prodotto e cliente.

---

## Pipeline ETL

### 1. Estrazione

Il file `script/extract_cleaning_load.py` legge il CSV dalla cartella `dataset/` usando `pandas`.

### 2. Pulizia e normalizzazione

Lo script effettua diverse trasformazioni:

- normalizzazione dei nomi delle colonne in lowercase;
- conversione di date e orari in formati coerenti;
- rimozione dei duplicati basati su `Transaction_ID`;
- controllo della coerenza tra `Product_ID` e `Product_Name`;
- validazione di range di `Discount_Percentage` e `Quantity`;
- normalizzazione di valori mancanti e gestione dei casi anomali.

### 3. Ingestione in staging

I dati puliti vengono caricati nella tabella `staging.sales_transactions` in PostgreSQL.

### 4. Creazione delle dimensioni

Gli script SQL in `database/sql/` creano le dimensioni principali:

- `03_dim_user.sql`
- `04_dim_product.sql`
- `05_dim_store.sql`
- `06_dim_date.sql`
- `07_dim_time.sql`

### 5. Creazione della fact table

Lo script `08_fact_sales_transactions.sql`:

- prepara `mart.sales_transactions`;
- collega i dati alle dimensioni tramite `user_sk`, `date_id`, `time_id`;
- aggiunge foreign key;
- verifica la qualità dei dati tramite check sul numero di record mancanti.

---

## Requisiti di esecuzione

### Prerequisiti

- Docker
- Accesso all'interfaccia web di pgAdmin
- Power BI per la visualizzazione finale

### Variabili di ambiente

Il progetto usa un file `.env` con le configurazioni del database e di pgAdmin.

---

## Avvio del progetto

Per avviare l'ambiente avvia Docker e posizionati all'interno della cartella del progetto con PowerShell/CMD e lancia il comando:

```bash
docker compose up --build
```

Questo comando avvia i container per:

- PostgreSQL;
- pgAdmin;
- Python ETL initializer.

La pipeline di inizializzazione viene eseguita da `run_init.sh` e ordina, in sequenza:

1. `01_schema_creation.sql`
2. `02_sales_transactions.sql`
3. `extract_cleaning_load.py`
4. resto degli script SQL di creazione delle dimensioni e della fact table

Per terminare l'applicazione eseguire il comando:

```bash
docker compose down
```
Con questo comando verranno rimossi tutti i container creati e verranno eliminati gli schemi in PostgreSQL.

---

## Accesso ai servizi

- URL: `http://localhost:5050`
- credenziali lette dal file `.env`

---

## Output attesi

Il risultato finale è un data warehouse accessibile per analisi di business, in particolare per:

- trend di fatturato e profitto;
- analisi per canale di vendita;
- performance per prodotto e categoria;
- analisi per regione, città e paese;
- segmentazione e comportamento clienti;
- monitoraggio promozioni e ritorni.

La dashboard Power BI (`dashboard/sales_dashboard.pbix`) è l'esito visuale di questa analisi.

---

## Domande di business supportate

Il progetto è stato pensato per rispondere a quesiti come:

- Qual è il fatturato totale per mese e anno?
- Quale categoria di prodotto genera il profitto maggiore?
- Quale canale di vendita ha il miglior rendimento?
- Dove si concentrano i clienti più redditizi?

---

## Qualità dei dati

Il progetto include controlli di qualità durante la pipeline, tra cui:

- eliminazione duplicati;
- validazione range numerici;
- controllo dimensioni / chiavi;
- gestione di valori mancanti;
- controllo di coerenza tra ID e nome del prodotto;
- versioning di clienti con `dim_user` per cambiare attributi nel tempo.

Questi controlli sono essenziali per evitare analisi scorrette e garantire affidabilità del reporting.

---

## Considerazioni e limiti

- Il dataset è pensato per un contesto di analisi di vendita, non per dati finanziari completi di regolamentazione contabile;
- la gestione delle credenziali è lasciata a variabili di ambiente e non a valori hardcoded;
- l'architettura è di tipo analitico e ottimizzata per BI, non per applicazioni OLTP;
- eventuali aggiornamenti incrementali richiedono un'estensione della pipeline ETL.

---

## File principali

- `script/extract_cleaning_load.py`: script ETL principale
- `database/sql/*.sql`: logica di creazione schema, dimensioni e fact table
- `dashboard/sales_dashboard.pbix`: dashboard di visualizzazione
- `dataset/sales_data_dictionary.csv`: dizionario dei campi
- `dataset/Sales_transactions_2022_2025.csv`: dataset operativo

---

## Conclusione

Questo progetto rappresenta una base solida per la costruzione di un data warehouse di vendite, con pipeline ETL automatizzata, modello analitico chiaro e una struttura pronta per la dashboarding. L'approccio combina dati grezzi, trasformazioni SQL/Python e analisi decisionali per supportare processi aziendali concreti.