--creo tabella finale dim_time
DROP TABLE IF EXISTS mart.dim_time;
CREATE TABLE mart.dim_time (
	time_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	time TIME UNIQUE NOT NULL,
	hour INT,
	minute INT,
	second INT
);

--estraggo gli orari unici dalla tabella delle transazioni
--inserisco i risultati e le colonne derivate nella tabella finale
INSERT INTO mart.dim_time (time, hour, minute, second)
SELECT DISTINCT 
	order_time, 
	EXTRACT(HOUR FROM order_time),
	EXTRACT(MINUTE FROM order_time),
	EXTRACT(SECOND FROM order_time)
FROM staging.sales_transactions
ORDER BY order_time;