--creo tabella finale dim_date
DROP TABLE IF EXISTS mart.dim_date;
CREATE TABLE mart.dim_date (
	date_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	date DATE UNIQUE NOT NULL,
	year INT,
	month INT,
	day INT
);

--estraggo le date uniche dalla tabella delle transazioni
--inserisco i risultati e le colonne derivate nella tabella finale
INSERT INTO mart.dim_date (date, year, month, day)
SELECT DISTINCT 
	order_date, 
	EXTRACT(YEAR FROM order_date),
	EXTRACT(MONTH FROM order_date),
	EXTRACT(DAY FROM order_date)
FROM staging.sales_transactions
ORDER BY order_date;