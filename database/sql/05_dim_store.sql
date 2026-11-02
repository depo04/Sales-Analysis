--creo tabella di destinazione finale
DROP TABLE IF EXISTS mart.dim_store;
CREATE TABLE mart.dim_store (
	store_id VARCHAR(20) PRIMARY KEY,
	name VARCHAR(100), 
	country VARCHAR(50),
	region VARCHAR(50),
	city VARCHAR(50)
);

--creo una prima tabella temporanea 
CREATE TEMP TABLE temp_dim_store AS
SELECT DISTINCT 
	store_id, 
	store_name, 
	country, 
	region, 
	city 
FROM staging.sales_transactions
WHERE store_id IS NOT NULL;

--creo una seconda tabella temporanea normalizzata a partire da quella precedente
CREATE TEMP TABLE tmp_dim_store2 AS
SELECT
    store_id,
	store_name,
	country,
    CASE
        WHEN region = 'Northeast' THEN 'North East'
        WHEN region = 'NRW' THEN 'North Rhine-Westphalia'
        WHEN region = 'British columbia' THEN 'British Columbia'
        ELSE region
    END AS region,
    CASE
        WHEN city = 'LOS ANGELES' THEN 'Los Angeles'
        WHEN city = 'munich' THEN 'Munich'
        ELSE city
    END AS city
FROM temp_dim_store;

--verifico la lunghezza dei campi per 'NYC-01'
SELECT 
	LENGTH(store_id),
	LENGTH(store_name),
	LENGTH(country),
	LENGTH(region),
	LENGTH(city)
FROM tmp_dim_store2
WHERE store_id = 'NYC-01';

--risultato da inserire nella tabella finale
INSERT INTO mart.dim_store (store_id, name, country, region, city)
SELECT DISTINCT store_id, store_name, country, region, TRIM(city) 
FROM tmp_dim_store2;