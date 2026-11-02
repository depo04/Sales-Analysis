--creazione schema per la tabella dim_user con CHECK per data quality
DROP TABLE IF EXISTS mart.dim_user;
CREATE TABLE mart.dim_user (
    user_sk      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  VARCHAR(30) NOT NULL,
    name         VARCHAR(200),
    age          SMALLINT,
    gender       VARCHAR(30),
    segment      VARCHAR(100),

    valid_from   TIMESTAMP NOT NULL,
    valid_to     TIMESTAMP,
    is_current   BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT ck_dim_user_dates
        CHECK (valid_to IS NULL OR valid_to >= valid_from),

    CONSTRAINT ck_dim_user_current
        CHECK (is_current = (valid_to IS NULL))
);

--una sola versione corrente per cliente
CREATE UNIQUE INDEX ux_dim_user_current
    ON mart.dim_user (customer_id)
    WHERE is_current = TRUE;

--ricerca della versione valida per un cliente e una data
CREATE INDEX ix_dim_user_asof
    ON mart.dim_user (customer_id, valid_from, valid_to);

--creazione tabella temporanea con i dati distinti dei clienti
CREATE TEMP TABLE stg_user_state AS
SELECT DISTINCT
    customer_id,
    order_date,
    customer_name,
    customer_age,
    customer_gender,
    customer_segment
FROM staging.sales_transactions
WHERE customer_id IS NOT NULL
  AND order_date IS NOT NULL;

 --segmentazione dei dati per identificare le modifiche tra le versioni dei clienti
CREATE TEMP TABLE stg_user_changes AS
WITH ordered AS (
    SELECT
        s.*,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS rn,

        LAG(customer_name) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS prev_name,

        LAG(customer_age) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS prev_age,

        LAG(customer_gender) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS prev_gender,

        LAG(customer_segment) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS prev_segment

    FROM stg_user_state s
)
SELECT
    customer_id,
    order_date AS valid_from,
    customer_name,
    customer_age,
    customer_gender,
    customer_segment
FROM ordered
WHERE rn = 1
   OR customer_name    IS DISTINCT FROM prev_name
   OR customer_age     IS DISTINCT FROM prev_age
   OR customer_gender  IS DISTINCT FROM prev_gender
   OR customer_segment IS DISTINCT FROM prev_segment;

--creazione tabella temporanea finale con le date di validità per ogni versione dei clienti
CREATE TEMP TABLE stg_dim_user_final AS
SELECT
    customer_id,
    customer_name,
    customer_age,
    customer_gender,
    customer_segment,
    valid_from,

    LEAD(valid_from) OVER (
        PARTITION BY customer_id
        ORDER BY valid_from
    ) AS valid_to

FROM stg_user_changes;

--inserimento dei dati nella tabella dim_user con gestione delle versioni
TRUNCATE TABLE mart.dim_user RESTART IDENTITY;
INSERT INTO mart.dim_user (
    customer_id,
    name,
    age,
    gender,
    segment,
    valid_from,
    valid_to,
    is_current
)
SELECT
    customer_id,
    customer_name,
    customer_age,
    customer_gender,
    customer_segment,
    valid_from,
    valid_to,
    (valid_to IS NULL) AS is_current
FROM stg_dim_user_final
ORDER BY customer_id, valid_from;