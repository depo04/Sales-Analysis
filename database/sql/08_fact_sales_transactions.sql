--creazione tabella mart di sales_transactions
DROP TABLE IF EXISTS mart.sales_transactions;
CREATE TABLE mart.sales_transactions AS
SELECT 
	transaction_id,
	order_id,
	NULL::integer AS user_sk,
	store_id,
	product_id,
	NULL::integer AS date_id,
	NULL::integer AS time_id,
	sales_channel,
	quantity,
	unit_price,
	discount_percentage,
	sales_amount,
	cost_amount,
	profit,
	payment_method,
	order_status,
	shipping_method,
	delivery_days,
	inventory_level,
	promotion_code,
	customer_rating,
	sales_representative,
	return_flag,
	return_reason
FROM staging.sales_transactions;


SELECT * FROM mart.sales_transactions;


--ricreare colonne foreign key mancanti per staging.sales_transactions
ALTER TABLE staging.sales_transactions
ADD CONSTRAINT date_fk FOREIGN KEY (order_date)
REFERENCES mart.dim_date (date);

ALTER TABLE staging.sales_transactions
ADD CONSTRAINT time_fk FOREIGN KEY (order_time)
REFERENCES mart.dim_time (time);

--popolazione di date_id
UPDATE mart.sales_transactions AS ms
SET date_id = d.date_id
FROM staging.sales_transactions AS ss
JOIN mart.dim_date AS d
    ON d.date::date = ss.order_date::date
WHERE ms.transaction_id = ss.transaction_id;

--popolazione di time_id
UPDATE mart.sales_transactions AS ms
SET time_id = t.time_id
FROM staging.sales_transactions AS ss
JOIN mart.dim_time AS t
	ON t.time::time = ss.order_time::time
WHERE ms.transaction_id = ss.transaction_id;

--popolazione di user_sk
UPDATE mart.sales_transactions AS ms
SET user_sk = c.user_sk
FROM staging.sales_transactions AS ss
JOIN mart.dim_user AS c
    ON c.customer_id = ss.customer_id
   AND (ss.order_date::date + ss.order_time::time) >= c.valid_from
   AND (
       c.valid_to IS NULL
       OR (ss.order_date::date + ss.order_time::time) < c.valid_to
   )
WHERE ms.transaction_id = ss.transaction_id;

--verifica data quality
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE user_sk IS NULL) AS missing_user_sk,
    COUNT(*) FILTER (WHERE date_id IS NULL) AS missing_date_id,
    COUNT(*) FILTER (WHERE time_id IS NULL) AS missing_time_id
FROM mart.sales_transactions;

--creazione FK per la tabella mart.sales_transactions
ALTER TABLE mart.sales_transactions
    ADD CONSTRAINT fk_sales_customer
    FOREIGN KEY (user_sk)
    REFERENCES mart.dim_user (user_sk);

ALTER TABLE mart.sales_transactions
    ADD CONSTRAINT fk_sales_date
    FOREIGN KEY (date_id)
    REFERENCES mart.dim_date (date_id);

ALTER TABLE mart.sales_transactions
    ADD CONSTRAINT fk_sales_time
    FOREIGN KEY (time_id)
    REFERENCES mart.dim_time (time_id);

ALTER TABLE mart.sales_transactions
    ADD CONSTRAINT fk_sales_product
    FOREIGN KEY (product_id)
    REFERENCES mart.dim_product (product_id);

ALTER TABLE mart.sales_transactions
    ADD CONSTRAINT fk_sales_store
    FOREIGN KEY (store_id)
    REFERENCES mart.dim_store (store_id);